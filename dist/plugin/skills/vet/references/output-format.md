# Output format and apply flow

How the vetting session opens, closes, and writes its results.

## Opening (before Phase 3)

Render the ledger summary line from `opinion-extraction.md` and the one-line instruction. That is the full preamble — no confidence caveat is needed. The user is the arbiter; the only inference is the tier classification, and that is communicated per-card via the `signal` field.

## Apply summary (after all verdicts are collected)

Render a one-line summary before writing any files:

```
Vetted: 14 of 14 · 3 cut · 1 softened · 2 replaced · 8 accepted
```

If nothing changed (all accepted, all skipped and not revisited, or session ended with `done` immediately):

```
No changes made — all directives accepted (or session ended before any vetoes).
```

Skip the build reminder and handoff suggestion in this case.

## Writing edits

Edits write to `src/skills/<target>/` source files — never `dist/` (dist/ is generated and will be overwritten on the next build). Change only the directive lines being cut, softened, or replaced. Preserve surrounding whitespace, adjacent content, and file structure exactly.

After writing any changes, remind the user:

> Run `bin/build` to regenerate `dist/` for both targets.

## Handoff suggestion

After the build reminder, close with the `skill-audit` suggestion from `SKILL.md` Phase 5. Surface as text and stop.

Do not invoke `skill-audit` automatically, even when changes were applied. The handoff is a recommendation — the user may want to review the diff first, or the skill may be small enough that a coherence pass is unnecessary. Let them decide.

## Session-end shape (full example)

```
Vetted: 6 of 8 · 2 cut · 1 softened · 3 accepted · 2 skipped (not revisited, treated as accepted)

Run `bin/build` to regenerate `dist/` for both targets.

Applied 3 change(s) to `skill-audit`. Pruning directives can introduce gaps or inconsistencies.
Consider running `/skill-audit skill-audit` to check internal coherence after your edits —
contradictions and redundancies sometimes only become visible after opinions are removed.
```
