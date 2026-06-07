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
2. **Pinned npx fallback** — otherwise `npx --yes markdownlint-cli2@0.22.1` (pinned, never `@latest`). Note: pinning the CLI wrapper does **not** pin the underlying `markdownlint` rule *engine* (a transitive dependency npx may resolve to a newer version). Determinism therefore comes from the **explicit-allowlist config** (below), not from the version pin alone — the config enables a fixed set of rules by name, so a newer engine cannot switch on rules the config didn't ask for.
3. **Unavailable** — if there is no binary and `npx` is absent, or the npx invocation exits non-zero (network, registry, or cache failure — surface the actual stderr), do **not** fail silently: report that formatting could not run and offer to continue with the typo pass alone (see `typo-gate.md`).

Conceptual invocation (resolve `<md-audit-dir>` to this skill's own directory; glob the target's markdown):

```
markdownlint-cli2 --config <md-audit-dir>/references/markdownlint-cli2.jsonc --fix \
  <target>/SKILL.md <target>/references/**/*.md
```

`--fix` rewrites the files in place. Because `md-audit` writes only to `src/` after the user approves (see the apply flow), run the formatter against the resolved `src/skills/<target>/` files and capture the diff for review rather than treating the in-place rewrite as final. The Node/npm requirement is the skill's one external dependency — state it plainly if the environment lacks it.

## What the config does

The bundled `markdownlint-cli2.jsonc` sets `default: false` and enables **only an explicit allowlist** of whitespace-class, auto-fixable rules (trailing spaces, hard tabs, blank-line normalization, heading/blockquote/list-marker spacing, blanks around fences and lists, single trailing newline, and bullet-marker style). This is deliberate, not `default: true`, for two reasons:

1. **Version stability.** The npx pin fixes the CLI wrapper but not the rule engine; an explicit allowlist makes the rule set identical across engine versions — a newer engine cannot switch on rules the config never named.
2. **No structural rewrites.** Rules that renumber or re-indent lists (`MD029`, `MD005`, `MD007`), edit heading text (`MD026`), or rewrite words (`MD044`) can change rendered meaning, so they are **not** in the allowlist. A "never change meaning" tool must not run them. (A dry-run caught `MD029` renumbering a normative ordered list when `default: true` was used — exactly the failure this design prevents.)

The prose-noise opinion rules (`MD013` line-length, `MD033` inline-HTML, `MD041` first-line-heading, `MD036` emphasis-as-heading, table/fence-language rules) are simply never enabled, so the report stays clean on normal skill prose.

## Fixes that alter rendered output — always show these in the diff

Most allowlisted rules only add or strip whitespace. Two make a **visible** change, so they always appear in the formatting section of the diff (see the apply flow) for review before any write:

| Rule | What it changes | Note |
|---|---|---|
| MD004 | Normalizes unordered-list bullet markers (`*`/`+`/`-` → first-seen) | First-marker-wins; the diff makes the chosen marker visible. |
| MD047 | Ensures a single trailing newline at end of file | Adds or removes the final newline. |

And one allowlisted rule has a preservation subtlety worth stating:

| Rule | Behavior |
|---|---|
| MD009 | Strips trailing whitespace, **but a two-space hard line-break is preserved** (default `br_spaces: 2`) — intentional `<br>`-via-two-spaces survives; only 1 or 3+ trailing spaces are trimmed. |

This is why the safety model is **deterministic and reviewed**, not "meaning-preserving by construction": the allowlist makes the rule set safe and stable, and the diff — not a correctness proof — is the final guarantee. Everything else the allowlist does (heading-space normalization, hard-tab→space, blank-line collapse, blanks around fences/lists) is pure whitespace and not meaning-affecting.

## Boundary

The formatter never:

- Reflows or rewraps prose paragraph text (confirmed: long lines are left intact).
- Edits content inside fenced code blocks or inline code spans (confirmed: code bytes are preserved).
- Touches frontmatter values.
- Changes any word — formatting is whitespace and structure only. Word-level changes are the typo pass's job, under its own stricter gate (`typo-gate.md`).
