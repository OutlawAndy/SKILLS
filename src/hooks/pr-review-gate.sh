#!/usr/bin/env bash
#
# outlaw-skills pr-review-gate
#
# PreToolUse hook that blocks the first `gh pr create` for each commit in a
# Rails repo until the branch's diff has been reviewed against the Rails
# skills governing the paths it touches.
#
# Soft-gate semantics, like rails-gate.sh:
#   - Fires ONCE per HEAD commit. A retry at the same commit passes through;
#     a commit made to fix findings changes HEAD and fires the gate again.
#   - Markers live in $TMPDIR (default /tmp) keyed by commit SHA.
#   - A nudge, not a verification: hooks can't see whether a review ran.
#   - Diffs touching no Rails-shaped paths pass through silently.
#
# Dependencies: bash, jq, git.

set -euo pipefail

input="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

command_line="$(echo "$input" | jq -r '.tool_input.command // empty')"
[[ "$command_line" =~ (^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create ]] || exit 0

cwd="$(echo "$input" | jq -r '.cwd // empty')"
cd "${cwd:-.}" 2>/dev/null || exit 0

project_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
grep -qE "^[[:space:]]*gem ['\"]rails['\"]" "$project_root/Gemfile" 2>/dev/null || exit 0

head_sha="$(git rev-parse HEAD 2>/dev/null)" || exit 0
base="$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo origin/main)"
merge_base="$(git merge-base "$base" HEAD 2>/dev/null)" || exit 0

source "$(dirname "$0")/rails-skills.sh"

skills="$(
  git diff --name-only "$merge_base" HEAD | while read -r path; do
    read -r skill _ <<<"$(rails_skill_for "$path")" || true
    if [ -n "$skill" ]; then echo "$skill"; fi
  done | sort -u | paste -sd, - | sed 's/,/, /g'
)"

[ -z "$skills" ] && exit 0

marker_dir="${TMPDIR:-/tmp}/outlaw-pr-review-gate"
mkdir -p "$marker_dir" 2>/dev/null || true
marker_file="$marker_dir/$head_sha"

[ -f "$marker_file" ] && exit 0

touch "$marker_file"
find "$marker_dir" -type f -mtime +7 -delete 2>/dev/null || true

jq -n \
  --arg skills "$skills" \
  --arg range "${merge_base:0:12}..HEAD" \
  '{
    decision: "block",
    reason: ("outlaw-skills pr-review-gate: before opening this PR, invoke " + $skills + " via the Skill tool and review `git diff " + $range + "` against them. Fix what you find (a fix commit re-arms this gate), then retry `gh pr create`.")
  }'
