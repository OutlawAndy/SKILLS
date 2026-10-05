#!/usr/bin/env bash
#
# outlaw-skills driving-speak
#
# Stop hook that reads the assistant's turn aloud while driving mode is on.
#
# Contract with the `driving` skill:
#   - The skill turns the mode on by writing its session id into the flag
#     file; with no flag, or a flag left behind by another session, this
#     hook exits immediately and the session is silent.
#   - The assistant ends each message with a `Spoken:` line written for the
#     ear. Only that line is spoken -- reading raw markdown aloud is
#     unlistenable, and the whole point of the mode is that the audio was
#     composed to be heard.
#   - No `Spoken:` line means the assistant forgot. A short nudge is spoken
#     instead of silence, because silence is indistinguishable from the mode
#     being off when you are looking at the road.
#
# Never blocks the turn: `say` is detached, and the previous utterance for
# this session is cut off first so answers don't queue up behind each other.

set -uo pipefail

FLAG="${OUTLAW_DRIVING_FLAG:-$HOME/.claude/driving-mode}"
[ -f "$FLAG" ] || exit 0

command -v say >/dev/null 2>&1 || exit 0   # not macOS, nothing to speak with
command -v jq  >/dev/null 2>&1 || exit 0

input=$(cat)
session=$(jq -r '.session_id // "unknown"' <<<"$input")
[ "$(cat "$FLAG")" = "$session" ] || exit 0
message=$(jq -r '.last_assistant_message // ""' <<<"$input")

# Everything after the last `Spoken:` marker, so a message may mention the
# word in passing and still be read from the real one.
spoken=$(awk '
  /^[[:space:]]*(\*\*)?Spoken:?(\*\*)?:?[[:space:]]*/ { capturing = 1; sub(/^[^:]*:/, ""); buffer = $0; next }
  capturing { buffer = buffer " " $0 }
  END { print buffer }
' <<<"$message")

# Strip the markdown that survives: emphasis, backticks, link syntax, bullets.
spoken=$(sed -e 's/\[\([^]]*\)\](\([^)]*\))/\1/g' \
             -e 's/[`*_#>]//g' \
             -e 's/^[[:space:]]*-[[:space:]]*//' \
             -e 's/[[:space:]]\{2,\}/ /g' <<<"$spoken" | sed -e 's/^ *//' -e 's/ *$//')

[ -n "$spoken" ] || spoken="No spoken summary in that one."

# 1200 characters is about ninety seconds at the default rate -- long enough
# for a real answer, short enough that a runaway message can't hold the car
# hostage.
spoken=${spoken:0:1200}

pidfile="${TMPDIR:-/tmp}/outlaw-driving-$session.pid"
[ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null

say -r "${OUTLAW_DRIVING_RATE:-175}" ${OUTLAW_DRIVING_VOICE:+-v "$OUTLAW_DRIVING_VOICE"} "$spoken" &
echo $! > "$pidfile"

exit 0
