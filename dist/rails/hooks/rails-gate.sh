#!/usr/bin/env bash
#
# outlaw-skills rails-gate
#
# PreToolUse hook that nags the agent to load the matching Rails skill
# before its first Edit/Write/MultiEdit on a Rails-shaped path.
#
# Soft-gate semantics:
#   - The gate fires ONCE per session per category. After the first nag,
#     subsequent edits in the same category pass through on the assumption
#     that the agent honored the instruction.
#   - The marker file lives in $TMPDIR (default /tmp) keyed by session_id
#     and category.
#   - This is intentionally a nudge, not a hard verification — Claude's
#     hook system has no visibility into Skill tool loads, so we cannot
#     prove the skill is in context. The nag at the moment of impulse is
#     enough to recover the dropped instruction.
#
# Behavior summary:
#   - Reads PreToolUse JSON from stdin
#   - Allows everything outside Rails repos (no Gemfile mentioning rails)
#   - Allows tools other than Edit/Write/MultiEdit/NotebookEdit
#   - For Rails-shaped edits, emits a `decision: block` JSON on first
#     encounter per (session, category); allows on subsequent encounters
#
# Dependencies: bash, jq.
#
# Source of truth for trigger patterns: this file. Edit both this script
# and the Phase 3 table in src/skills/work/SKILL.md together.

set -euo pipefail

# --- Read & parse stdin --------------------------------------------------

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  # No jq available — fail open so we never break the user's session.
  exit 0
fi

tool_name="$(echo "$input" | jq -r '.tool_name // empty')"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // empty')"
session_id="$(echo "$input" | jq -r '.session_id // "no-session"')"

# --- Filter to code-mutating tools ---------------------------------------

case "$tool_name" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

[ -z "$file_path" ] && exit 0

# --- Find the project root (must contain Gemfile) ------------------------

case "$file_path" in
  /*) start_dir="$(dirname "$file_path")" ;;
  *)  start_dir="$(pwd)/$(dirname "$file_path")" ;;
esac

project_root=""
dir="$start_dir"
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  if [ -f "$dir/Gemfile" ]; then
    project_root="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done

[ -z "$project_root" ] && exit 0

if ! grep -qE "^[[:space:]]*gem ['\"]rails['\"]" "$project_root/Gemfile" 2>/dev/null; then
  exit 0
fi

# --- Compute the path relative to the project root ----------------------

case "$file_path" in
  /*) abs_path="$file_path" ;;
  *)  abs_path="$(pwd)/$file_path" ;;
esac

rel_path="${abs_path#$project_root/}"

# --- Match against Rails triggers ----------------------------------------

skill=""
category=""

case "$rel_path" in
  app/controllers/*)
    skill="controller-patterns"
    category="controller"
    ;;
  config/routes.rb|config/routes/*)
    skill="routing-patterns"
    category="routes"
    ;;
  app/models/*|app/services/*|app/policies/*|app/forms/*|app/queries/*)
    skill="layered-rails"
    category="model-service-policy"
    ;;
  app/views/*|app/components/*)
    skill="frontend-patterns"
    category="view-component"
    ;;
esac

[ -z "$skill" ] && exit 0

# --- Session marker: nag once per session per category -------------------

marker_dir="${TMPDIR:-/tmp}/outlaw-rails-gate"
mkdir -p "$marker_dir" 2>/dev/null || true
marker_file="$marker_dir/${session_id}-${category}"

if [ -f "$marker_file" ]; then
  # Already nagged this session for this category → allow.
  exit 0
fi

# First encounter — mark and block.
touch "$marker_file"

# Best-effort cleanup of markers older than 7 days, so /tmp doesn't fill.
find "$marker_dir" -type f -mtime +7 -delete 2>/dev/null || true

# --- Emit block decision -------------------------------------------------

jq -n \
  --arg path "$rel_path" \
  --arg skill "$skill" \
  --arg category "$category" \
  '{
    decision: "block",
    reason: ("outlaw-skills rails-gate: refusing the first " + $category + " edit (`" + $path + "`) until the `" + $skill + "` skill is loaded. Invoke `" + $skill + "` via the Skill tool now, then retry this edit. This gate fires once per session per category — subsequent " + $category + " edits will pass through.")
  }'

exit 0
