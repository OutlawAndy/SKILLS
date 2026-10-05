# Vetting loop: interactive walk-through protocol

This is the interactive core of the skill. Present one directive at a time, in the ranked order the opinion ledger specifies, and wait for a verdict before advancing. The user is the ground truth; no verdict requires justification.

## Walk-through header

Before presenting the first directive, render the ledger summary line and a one-line framing:

```
vet: skill-audit — 14 directives · 5 strong opinions · 9 soft opinions

Strong opinions first. Accept to keep, veto to remove (or soften), modify to rewrite, skip to defer.
```

## Directive card format

For each directive, render:

```
[V3] strong opinion · no rationale
  "Always build the unit ledger in one context — never dispatch to subagents."
  Source: SKILL.md § How this works, lines 32–33

  Encodes a specific architectural choice (in-context vs. fan-out) with no stated reason.

  → accept · veto · modify · skip
```

- **ID and tier** on the first line, including the `no rationale` flag when applicable.
- **Verbatim text** in quotes — the exact directive, not a paraphrase. If the directive is long, trim to the load-bearing sentence and note it is trimmed.
- **Source** — file, section, and line range so the user can read surrounding context if needed.
- **Opinionatedness signal** — one sentence from the ledger's `signal` field. Describe the structural reason this is opinionated; do not advocate for or against it.
- **Verdicts** on the last line.

For `soft` tier directives, the first line reads `[V7] soft opinion` (no "no rationale" flag needed since soft opinions with rationale are expected).

## Verdicts

**accept** — keep the directive as-is. Record the verdict and move to next. No confirmation needed.

**veto** — remove or soften the directive. Two sub-options:

1. **Cut**: remove the directive entirely from the skill file.
2. **Soften**: reduce the modal force to advisory. Show the proposed softer version before applying:
   - "always X" → "prefer X where possible"
   - "never Y" → "avoid Y"
   - "must Z" → "consider Z"
   - "only W" → "prefer W"
   Confirm with the user before writing. If the proposed softening doesn't capture what they want, fall through to **modify**.

Before executing either sub-option, check the `depends_on` field: if any other directive in the ledger lists this one as a dependency, warn first:

> Note: [V5] references this directive — removing it may leave [V5] inconsistent. Proceed with [cut / soften]?

Let the user confirm or cancel. If they cancel, treat as skip.

**modify** — replace the directive with user-supplied text. Show the current text and ask:

> Replace with: ___

Apply verbatim. Do not paraphrase or clean up the user's replacement.

**skip** — defer this directive. Add to the deferred list and move to next without recording a disposition. At the end of the main pass, offer to revisit deferred items (see below).

**done** — stop the walk-through immediately. Treat all remaining unvisited directives (and any deferred ones not yet revisited) as accepted. Proceed to apply.

## Pacing

One directive per turn. Do not batch multiple directives into a single message. After recording a verdict, show a brief progress indicator and present the next:

```
(4 of 14 · 2 accepted · 1 vetoed · 1 softened)
```

This keeps the user oriented without requiring them to track state mentally.

Exception: if the ledger has only one directive, skip the counter.

## Deferred directives

After the main pass completes (all non-skipped directives processed), if any were deferred:

```
Walk-through complete. You skipped 2 directives:

  [V2] soft opinion · "prefer early return over deep nesting"
  [V9] strong opinion · no rationale · "never inline styles"

Review them now, or apply what you've decided so far?
```

If the user opts to review, loop through the deferred items using the same card format. If they skip again or choose apply, treat remaining deferred items as accepted.

## Early exit

The user can say "stop", "that's enough", or "just apply" at any point. Immediately record verdicts collected so far, treat everything else as accepted, and proceed to apply.
