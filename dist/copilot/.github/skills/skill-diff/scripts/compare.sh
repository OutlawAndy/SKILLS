#!/usr/bin/env bash
#
# compare.sh — compare one local skill to its upstream equivalent on GitHub.
#
# Reads the local skill's `based_on:` frontmatter, fetches the upstream SKILL.md
# fresh from GitHub (via gh), and prints a raw diff preceded by a summary header.
#
# Usage:
#   compare.sh <skill-name>                 full compare (resolve + fetch + diff)
#   compare.sh --resolve-only <skill-name>  print resolved owner/repo + path, no fetch
#   compare.sh --match-only <target>        internal: read SKILL.md paths on stdin,
#                                           print matched path | NONE | AMBIGUOUS
#
# Exit codes:
#   0  success — diff produced, resolved, or a clean "nothing to compare" report
#   1  usage / invalid input
#   2  environment or fetch error (gh missing/unauthenticated, gh call failed,
#      local skill not found, upstream fetch failed)

set -uo pipefail

# --- alias map: literal `based_on` alias token -> GitHub owner/repo -----------
# Add a line here to support a new marketplace-style based_on alias. The key is
# the exact token used in based_on values (e.g. `CompoundEngineering:plan`), NOT
# a marketplace manifest name.
resolve_alias() {
  case "$1" in
    CompoundEngineering) echo "EveryInc/compound-engineering-plugin" ;;
    *) return 1 ;;
  esac
}

# --- helpers -----------------------------------------------------------------
prog=${0##*/}
die()  { echo "$prog: error: $1" >&2; exit "${2:-2}"; }
usage() {
  echo "$prog: usage: $prog [--resolve-only] <skill-name>" >&2
  exit 1
}
info() { echo "$prog: $*" >&2; }

NAME_RE='^[a-z0-9][a-z0-9-]*$'          # skill names (local + upstream component)
OWNER_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$' # GitHub owner / repo

# Find the outlaw-skills repo root by walking up until a dir contains src/skills.
find_repo_root() {
  local d=$1
  while [ "$d" != "/" ]; do
    [ -d "$d/src/skills" ] && { echo "$d"; return 0; }
    d=$(dirname "$d")
  done
  return 1
}

# Locate the local skill's SKILL.md across the layouts skill-diff runs in:
#   1. a source checkout you're working in: <root>/src/skills/<name>/SKILL.md
#      (preferred when the cwd is inside an outlaw-skills checkout)
#   2. installed alongside skill-diff:      <skills-dir>/<name>/SKILL.md
# skill-diff always sits as a sibling of the other skill dirs, so case 2 covers
# every install target — ~/.copilot/skills/<name>, ~/.claude/skills/<name>, and
# src/skills/<name> when run from a checkout — without knowing the target name.
find_local_skill() {
  local name=$1 root cand script_dir skills_dir
  if root=$(find_repo_root "$PWD"); then
    cand="$root/src/skills/$name/SKILL.md"
    [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
  fi
  script_dir=$(cd "$(dirname "$0")" && pwd)   # .../<skill-diff>/scripts
  skills_dir=${script_dir%/*}; skills_dir=${skills_dir%/*}  # -> .../<skills>
  cand="$skills_dir/$name/SKILL.md"
  [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
  return 1
}

# Extract the based_on value from a SKILL.md frontmatter block (quotes stripped).
extract_based_on() {
  local v
  v=$(awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next}
           f && /^---[[:space:]]*$/ {exit}
           f && /^based_on:/ {print; exit}' "$1")
  [ -n "$v" ] || return 1
  v=${v#based_on:}
  v=$(printf '%s' "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  v=${v#\"}; v=${v%\"}
  v=${v#\'}; v=${v%\'}
  printf '%s' "$v"
}

# --- the tiered matcher (pure: stdin = candidate SKILL.md paths) --------------
# Filters paths to skill roots (skills/<dir>/SKILL.md, excluding tests/fixtures),
# then matches <dir> against the target by EXACT equality in three tiers:
#   1. dir == target          2. dir == "ce-"+target      3. unique hyphen-token
# Prints the single matched path, or NONE, or AMBIGUOUS.
match_from_paths() {
  local target=$1 line dir
  local -a roots=() dirs=()

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "/$line/" in */tests/*|*/fixtures/*) continue ;; esac
    [[ "$line" =~ (^|/)skills/[^/]+/SKILL\.md$ ]] || continue
    dir=${line%/SKILL.md}; dir=${dir##*/}
    roots+=("$line"); dirs+=("$dir")
  done

  _tier_collect() {  # predicate fn name -> sets MATCHES array
    local pred=$1 i; MATCHES=()
    for i in "${!dirs[@]}"; do
      "$pred" "${dirs[$i]}" "$target" && MATCHES+=("${roots[$i]}")
    done
  }
  _eq()     { [ "$1" = "$2" ]; }
  _ce()     { [ "$1" = "ce-$2" ]; }
  _token()  { case "-$1-" in *-"$2"-*) return 0 ;; *) return 1 ;; esac; }

  local -a MATCHES
  local pred
  for pred in _eq _ce _token; do
    _tier_collect "$pred"
    case "${#MATCHES[@]}" in
      0) continue ;;
      1) printf '%s\n' "${MATCHES[0]}"; return 0 ;;
      *) echo "AMBIGUOUS"; return 0 ;;
    esac
  done
  echo "NONE"
}

# --- resolution: based_on -> owner/repo + upstream SKILL.md path -------------
# Sets globals: R_OWNER R_REPO R_PATH. Returns non-empty status only on hard
# errors; "expected" misses (no based_on, unknown alias, no/ambiguous match)
# are reported via info() and signalled by a 10+ return so the caller can exit 0.
R_OWNER=""; R_REPO=""; R_PATH=""
resolve_upstream() {
  local name=$1 skill_md=$2 based_on owner repo uskill rest

  based_on=$(extract_based_on "$skill_md") || { info "no upstream recorded for '$name' (no based_on:)"; return 10; }

  if [[ "$based_on" == */*@* ]]; then            # owner/repo@skill[@ref]
    owner=${based_on%%/*}
    rest=${based_on#*/}                          # repo@skill[@ref]
    repo=${rest%%@*}
    rest=${rest#*@}                              # skill[@ref]
    uskill=${rest%%@*}                           # trailing @ref tolerated, ignored
  elif [[ "$based_on" == *:* && "$based_on" != */* ]]; then  # Alias:skill[@ref]
    local alias=${based_on%%:*}
    rest=${based_on#*:}                          # skill[@ref]
    uskill=${rest%%@*}
    local ownerrepo
    ownerrepo=$(resolve_alias "$alias") || { info "unknown based_on alias '$alias' for '$name' (add it to the alias map)"; return 11; }
    owner=${ownerrepo%%/*}; repo=${ownerrepo#*/}
  else
    info "unrecognized based_on format '$based_on' for '$name'"; return 12
  fi

  [[ "$owner"  =~ $OWNER_RE ]] || die "invalid owner in based_on: '$owner'" 1
  [[ "$repo"   =~ $OWNER_RE ]] || die "invalid repo in based_on: '$repo'" 1
  [[ "$uskill" =~ $NAME_RE  ]] || die "invalid skill component in based_on: '$uskill'" 1

  local paths matched
  paths=$(gh api "repos/$owner/$repo/git/trees/HEAD?recursive=1" --jq '.tree[].path | select(test("SKILL.md$"))' 2>/dev/null) \
    || die "failed to fetch upstream tree for $owner/$repo (check gh auth and repo access)"
  matched=$(printf '%s\n' "$paths" | match_from_paths "$uskill")

  case "$matched" in
    NONE)      info "no upstream skill matching '$uskill' found in $owner/$repo (upstream may have moved, renamed, or removed it)"; return 13 ;;
    AMBIGUOUS) info "multiple upstream skills match '$uskill' in $owner/$repo; refusing to guess"; return 14 ;;
  esac

  R_OWNER=$owner; R_REPO=$repo; R_PATH=$matched
}

# --- frontmatter / body splitting (for the summary header) -------------------
fm_block()   { awk 'NR==1 && /^---[[:space:]]*$/ {f=1; print; next}
                    f {print} f && /^---[[:space:]]*$/ && NR>1 {exit}' "$1"; }
body_block() { awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next}
                    NR==1 {b=1}
                    f && /^---[[:space:]]*$/ {f=0; b=1; next}
                    b {print}' "$1"; }

# Keys present in local frontmatter but absent upstream (reports based_on/targets).
local_only_keys() {
  local lfm=$1 ufm=$2 k out=""
  for k in based_on targets; do
    if grep -q "^$k:" "$lfm" 2>/dev/null && ! grep -q "^$k:" "$ufm" 2>/dev/null; then
      out="${out:+$out, }$k"
    fi
  done
  printf '%s' "$out"
}

# --- modes -------------------------------------------------------------------
mode="full"
case "${1:-}" in
  --resolve-only) mode="resolve"; shift ;;
  --match-only)   shift; [ $# -eq 1 ] || usage; match_from_paths "$1"; exit 0 ;;
  --help|-h)      usage ;;
  -*)             usage ;;
esac

[ $# -eq 1 ] || usage
name=$1
[[ "$name" =~ $NAME_RE ]] || die "invalid skill name '$name' (expected ${NAME_RE})" 1

command -v gh >/dev/null 2>&1 || die "gh (GitHub CLI) is required but not installed — see https://cli.github.com/"

skill_md=$(find_local_skill "$name") \
  || die "no local skill named '$name' found (looked in ./src/skills/$name and alongside skill-diff)" 1

resolve_upstream "$name" "$skill_md"; rc=$?
[ "$rc" -eq 0 ] || { [ "$rc" -ge 10 ] && exit 0 || exit "$rc"; }

if [ "$mode" = "resolve" ]; then
  echo "$name -> $R_OWNER/$R_REPO @ $R_PATH"
  exit 0
fi

# --- full mode: fetch upstream, build header, print raw diff -----------------
tmp=$(mktemp) || die "could not create temp file"
trap 'rm -f "$tmp"' EXIT INT TERM

gh api "repos/$R_OWNER/$R_REPO/contents/$R_PATH" -H "Accept: application/vnd.github.raw" >"$tmp" 2>/dev/null \
  || die "failed to fetch upstream SKILL.md at $R_OWNER/$R_REPO:$R_PATH"

head_sha=$(gh api "repos/$R_OWNER/$R_REPO/commits/HEAD" --jq '.sha' 2>/dev/null | cut -c1-7)

lfm=$(mktemp); ufm=$(mktemp); lbody=$(mktemp); ubody=$(mktemp)
trap 'rm -f "$tmp" "$lfm" "$ufm" "$lbody" "$ubody"' EXIT INT TERM
fm_block   "$skill_md" >"$lfm";  fm_block   "$tmp" >"$ufm"
body_block "$skill_md" >"$lbody"; body_block "$tmp" >"$ubody"

# Header line: frontmatter classification
if diff -q "$lfm" "$ufm" >/dev/null 2>&1; then
  fm_line="identical"
else
  only=$(local_only_keys "$lfm" "$ufm")
  fm_line="differs${only:+ (local-only: $only)}"
fi

# Header line: body hunk count
hunks=$(diff -u "$lbody" "$ubody" 2>/dev/null | grep -c '^@@')

# Substantial-rewrite caveat: fires when the bodies share little. `changed`
# counts removed+added lines, so common lines = (lcount+ucount-changed)/2.
# Flag when common < 30% of the larger body (i.e. >70% divergent).
lcount=$(wc -l <"$lbody"); ucount=$(wc -l <"$ubody")
changed=$(diff "$lbody" "$ubody" 2>/dev/null | grep -c '^[<>]')
larger=$(( lcount > ucount ? lcount : ucount )); [ "$larger" -gt 0 ] || larger=1
common=$(( (lcount + ucount - changed) / 2 )); [ "$common" -ge 0 ] || common=0

echo "$prog: $name"
echo "  upstream: $R_OWNER/$R_REPO @ $R_PATH${head_sha:+ (HEAD $head_sha)}"
echo "  frontmatter: $fm_line"
echo "  body: $hunks changed hunk(s)"
if [ "$(( common * 10 ))" -lt "$(( larger * 3 ))" ]; then
  echo "  note: substantial rewrite — this is a full comparison vs upstream HEAD, not a since-fork delta"
fi
upstream_dir=${R_PATH%/SKILL.md}
if gh api "repos/$R_OWNER/$R_REPO/contents/$upstream_dir" --jq '.[].name' 2>/dev/null | grep -qE '^(scripts|references)$'; then
  echo "  note: upstream has bundled scripts/ or references/ — those were NOT compared (SKILL.md only)"
fi
echo "--- raw diff (local vs upstream) ---"

diff -u -L "local: $name/SKILL.md" -L "upstream: $R_OWNER/$R_REPO @ $R_PATH" "$skill_md" "$tmp"
exit 0
