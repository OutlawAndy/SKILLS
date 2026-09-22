---
name: driving
description: Hands-free working mode — reads each response aloud through macOS `say` and presents decisions one at a time, waiting for spoken approval between each. Use when the user says "driving", "I'm driving", "read it to me", "read that aloud", "hands free", "talk me through it", "/driving", or asks to turn the mode off again. Not for a single one-off "say this out loud" request, which is just a `say` command.
argument-hint: "[on | off; blank means on]"
license: MIT
metadata:
  triggers:
    - driving
    - im driving
    - read aloud
    - read it to me
    - hands free
    - talk me through it
    - driving off
---

# Driving

The user is not looking at the screen. Everything they get from this turn, they
get through the speakers, and everything they send back they have to say or
thumb-type at a stoplight. Work accordingly.

## Turning it on

```bash
touch ~/.claude/driving-mode
```

That flag is the whole switch. The plugin's `Stop` hook checks for it after
every response and speaks the `Spoken:` line; with no flag the hook exits and
the session is silent. Confirm in one short line, then follow the protocol
below until told otherwise.

## Turning it off

Invoked as `/driving off`, or when the user says they've parked, arrived, or
wants to go back to normal:

```bash
rm -f ~/.claude/driving-mode
```

Then drop the protocol and answer normally.

## The protocol

**End every message with a `Spoken:` line.** It is the only thing the user
hears. No `Spoken:` line means they hear a nudge that you forgot — which is
better than silence, and worse than remembering.

```markdown
Spoken: Fix two of seven is applied and the tests are green. Approve the next one?
```

Write that line for the ear, not the eye:

- No code, no file paths, no line numbers, no URLs. "The form builder" — not
  `lib/turbo_form/form_builder.rb:78`.
- Spell out what a listener can't see: "skip underscore authorization", not
  `skip_authorization`.
- Short sentences. A listener can't re-read a clause.
- Put the ask last, so it's the freshest thing when they answer.
- Everything visual — diffs, tables, code — still goes in the written message.
  The screen is the reference; the audio is the conversation.

**One decision per message.** Never present a list of things to approve. Say
which one this is out of how many ("fix two of seven"), describe it, ask, stop.
Apply it only after they approve, then move to the next.

**Approval is explicit.** "Approved", "yes", "go" means do it. Silence,
ambiguity, or an answer to a different question does not. If a reply doesn't
clearly approve, ask again — cheaper than undoing work they didn't want.

**Skip means skip.** Don't re-argue a skipped item or fold it into a later one.

**Re-read on request.** "Say that again", "repeat", "I missed it" means speak it
again, slower and shorter — not a longer explanation. The car was loud.

**Keep the tail short.** Two or three sentences of audio per turn. If something
genuinely needs more, say so and offer to read it in parts rather than
delivering a monologue they can't skim.

## Working while they drive

Long stretches of tool work are fine and don't need narrating — the hook only
speaks when you finish a turn. Don't manufacture check-ins to fill the silence,
and don't stop to ask what you could reasonably decide. Batch the work, then
surface one decision.

Never start something destructive or outward-facing on a verbal "yeah" alone.
Publishing, pushing, deleting, or anything that touches someone else waits for
the user to be looking at a screen unless they were unmistakably specific.

## Tuning

Environment variables, if the default voice is wrong for the car:

- `OUTLAW_DRIVING_RATE` — words per minute, default `175`.
- `OUTLAW_DRIVING_VOICE` — any voice from `say -v '?'`.
- `OUTLAW_DRIVING_FLAG` — flag file path, default `~/.claude/driving-mode`.
