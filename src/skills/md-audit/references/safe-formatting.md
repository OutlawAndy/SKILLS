# Safe formatting: the deterministic pass

The formatting pass is a deterministic tool run, not an LLM judgment. It applies `markdownlint-cli2 --fix` over the target's markdown using the bundled config, and collects the result as a reviewable diff. The tool does structure; it never reflows prose paragraphs and never edits content inside fenced code blocks (both empirically confirmed).

## Files to format

- The target's `SKILL.md`.
- Every `*.md` under `references/` (recursively).
- Nothing else — not bundled scripts, not non-markdown assets, not the target repo's other files.

A target with no `references/` is fully supported: format `SKILL.md` alone.

## Invocation

Always pass the bundled config explicitly with `--config`. This is the load-bearing detail: `markdownlint` walks up from each linted file looking for an ambient `.markdownlint.*`, so without an explicit `--config` a stray config in the target's host repo would silently change the rule set. The bundled config lives next to this file at `references/markdownlint-cli2.jsonc`.

Resolve the formatter in this order, and **check the exit status** before trusting the output:

1. **Installed binary** — if `markdownlint-cli2` is on `PATH`, use it directly.
2. **Pinned npx fallback** — otherwise `npx --yes markdownlint-cli2@0.22.1` (pinned, never `@latest`, so behavior is deterministic across runs and a future default-rule change can't silently alter results).
3. **Unavailable** — if there is no binary and `npx` is absent, or the npx invocation exits non-zero (network, registry, or cache failure — surface the actual stderr), do **not** fail silently: report that formatting could not run and offer to continue with the typo pass alone (see `typo-gate.md`).

Conceptual invocation (resolve `<md-audit-dir>` to this skill's own directory; glob the target's markdown):

```
markdownlint-cli2 --config <md-audit-dir>/references/markdownlint-cli2.jsonc --fix \
  <target>/SKILL.md <target>/references/**/*.md
```

`--fix` rewrites the files in place. Because `md-audit` writes only to `src/` after the user approves (see the apply flow), run the formatter against the resolved `src/skills/<target>/` files and capture the diff for review rather than treating the in-place rewrite as final. The Node/npm requirement is the skill's one external dependency — state it plainly if the environment lacks it.

## What the config does

The bundled `markdownlint-cli2.jsonc` enables markdownlint's defaults (the auto-fixable rules are the safe formatting set) and disables the prose-noise rules that are not auto-fixable and carry no hygiene value (`MD013` line-length, `MD033` inline-HTML, `MD041` first-line-heading, `MD036` emphasis-as-heading, and `MD024` relaxed to `siblings_only`). The effect: `--fix` only ever touches whitespace and structure, and the report does not flood with un-fixable opinion warnings on normal skill prose.

## Fixes that alter rendered output — always show these in the diff

`--fix` is deterministic but a handful of in-scope fixes change how the document renders. These are **not** silently applied — they appear in the formatting section of the diff (see the apply flow) so the user sees them before any write:

| Rule | What it changes | Note |
|---|---|---|
| MD004 | Normalizes unordered-list bullet markers (`*`/`+` → first-seen, default "consistent") | First-marker-wins; the diff makes the chosen marker visible. |
| MD047 | Ensures a single trailing newline at end of file | Adds or removes the final newline. |
| MD009 | Strips trailing whitespace — **but a two-space hard line-break is preserved** | Default is "0 or 2 trailing spaces", so intentional `<br>`-via-two-spaces survives; only 1 or 3+ trailing spaces are trimmed. |
| MD012 | Collapses multiple consecutive blank lines to one | A blank-line "section break" gets normalized. |

This is why the safety model is **deterministic and reviewed**, not "meaning-preserving by construction": the diff, not a correctness proof, is the guarantee. Everything else `--fix` does (heading-space normalization, hard-tab→space, list-indent) is pure whitespace and not meaning-affecting.

## Boundary

The formatter never:

- Reflows or rewraps prose paragraph text (confirmed: long lines are left intact).
- Edits content inside fenced code blocks or inline code spans (confirmed: code bytes are preserved).
- Touches frontmatter values.
- Changes any word — formatting is whitespace and structure only. Word-level changes are the typo pass's job, under its own stricter gate (`typo-gate.md`).
