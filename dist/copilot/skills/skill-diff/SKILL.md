---
name: skill-diff
description: Compare one local skill to its upstream equivalent, fetched fresh from GitHub, and produce a dual-drift report (local customizations vs upstream changes worth adopting) grounded in the raw diff.
license: MIT
metadata:
  triggers:
    - compare with original
    - diff against upstream
    - compare skill to upstream
    - skill drift
    - based_on
---

# skill-diff

Single-script skill that compares a customized skill against the original. It reads the local skill's `based_on:` frontmatter, fetches the upstream `SKILL.md` **fresh from GitHub** (never from a local marketplace copy, which may be stale), and prints a raw textual diff preceded by a short summary header. Claude then interprets that output into a markdown comparison table plus a dual summary: local customizations and upstream changes worth adopting.

## What it shows (and what it does not)

The diff is a **two-way comparison** between your local `SKILL.md` and the current upstream HEAD — i.e. *current divergence*. For skills that track upstream closely this is effectively "what changed upstream." For skills that are substantial rewrites (e.g. `plan`, `work`), the diff is a full comparison, not a "since-fork delta"; the header flags this so the output is not misread. A true three-way "what changed upstream since I forked" view is a future addition (see "Fork-point ref", below).

The tool only **reports** drift. It never edits a skill, never applies upstream changes, and never rewrites `based_on`. It compares `SKILL.md` only — bundled `scripts/` and `references/` are not diffed (though substantially different file counts are reported in the header). The upstream skill is fetched fresh on each run, so the diff always reflects the latest upstream state, not a cached or local copy.

## Requirements

- [`gh`](https://cli.github.com/) installed and authenticated (`gh auth status`). The script fetches upstream content through `gh api`, so private upstreams resolve transparently under your GitHub auth.

## Usage

```bash
bash skills/skill-diff/scripts/compare.sh <skill-name>
```

Example:

```bash
bash skills/skill-diff/scripts/compare.sh controller-patterns
```

Resolve only — print the resolved upstream `owner/repo` and path without fetching or diffing (no network):

```bash
bash skills/skill-diff/scripts/compare.sh --resolve-only plan
```

## How the local skill is located

The script finds the local `SKILL.md` to compare in two ways, in order:

1. If the current directory is inside an outlaw-skills checkout, it uses `src/skills/<name>/SKILL.md` — so editing the source and checking drift always compares what you're editing.
2. Otherwise it compares the copy installed **alongside** skill-diff. Because skill-diff ships as a sibling of every other skill, this resolves `<name>/SKILL.md` in `~/.copilot/skills/`, `~/.claude/skills/`, or wherever the distribution lives — no need to be in the source repo.

## How upstream is resolved

The local skill's `based_on:` frontmatter points at the upstream source. One grammar is supported:

| Grammar | Example | Meaning |
|---|---|---|
| `owner/repo@skill` | `RoleModel/RoleModel-Skills@controller-patterns` | GitHub `owner/repo`, upstream skill dir `controller-patterns` |

An optional trailing `@<ref>` (e.g. `owner/repo@skill@<sha>`) is tolerated and currently ignored — it reserves the grammar slot for the future fork-point diff.

Resolution queries the upstream repo's git tree once (`gh api .../git/trees/HEAD?recursive=1`), filters to skill roots, and matches the upstream directory by **exact equality** in three tiers: the exact name, then `ce-<name>`, then a unique token match. This handles the local-name/upstream-name skew (e.g. local `plan` → upstream `ce-plan`, local `work` → upstream `ce-work` and not the sibling `ce-work-beta`/`ce-worktree`).

A skill with no `based_on:` (an original skill, like this one) reports "no upstream recorded" and exits cleanly.

## Output

The script emits a summary header and the raw `SKILL.md` diff. Then Claude interprets that output into a structured dual-drift report.

Script output example:

```
skill-diff: controller-patterns
  upstream: RoleModel/RoleModel-Skills @ skills/controller-patterns/SKILL.md (HEAD a1b2c3d)
  frontmatter: differs (local-only: based_on)
  body: 4 changed hunks

┌─────────────────────┬─────────────────────┬─────────────────────┐
│ Area                │ Local (your fork)   │ Upstream            │
├─────────────────────┼─────────────────────┼─────────────────────┤
--- (one row per meaningful divergence area, not one row per diff line) ---

--- raw diff (local vs upstream) ---
+ ...
- ...

```

Claude interpretation protocol:

1. Run `compare.sh` and read both the header and raw diff.
2. Build a markdown table with columns: `Area`, `Local (your fork)`, `Upstream`, `Likely category`.
3. Add one row per meaningful divergence area (frontmatter and each changed section/concern), not one row per diff line.
4. Write two short summaries:
  - `Local customizations`: what diverges locally and why it is likely intentional.
  - `Upstream changes worth adopting`: what likely changed upstream and may be worth porting.
5. Include this caveat verbatim:
  - `Caveat: categories are inferred from content in a two-way local-vs-HEAD diff; they are not git-proven provenance. A recorded fork-point SHA (see "Fork-point ref (future)") would make this exact.`

Categorization heuristics:

- Local-only frontmatter keys like `based_on` and `targets`, and repo-specific workflow tailoring prose, usually indicate `Local customization`.
- New upstream sections/features absent locally usually indicate `Upstream change worth adopting`.
- Use the script header signals (`frontmatter: ...`, `substantial rewrite` note) as weighting hints.
- If a row is genuinely ambiguous, mark it as `Ambiguous` and explain why.

Rendered-report example:

| Area | Local (your fork) | Upstream | Likely category |
|---|---|---|---|
| Frontmatter | Adds `based_on` for traceability | No `based_on` key | Local customization |
| Trigger phrasing | Includes repo-specific trigger wording | Uses generic upstream trigger set | Local customization |
| New upstream section | Missing locally | Adds new section on workflow guardrails | Upstream change worth adopting |

Local customizations:
- The fork adds `based_on` and workflow-specific wording to fit local usage conventions.

Upstream changes worth adopting:
- Upstream introduced a guardrail section not present locally; consider porting if it aligns with this repo's workflow.

Caveat: categories are inferred from content in a two-way local-vs-HEAD diff; they are not git-proven provenance. A recorded fork-point SHA (see "Fork-point ref (future)") would make this exact.

## Fork-point ref (future)

Recording the upstream commit each skill was forked at (via the reserved `based_on: owner/repo@skill@<sha>` slot) would enable a three-way diff showing *only* new upstream changes. Not implemented yet; the parser already tolerates the slot so existing values keep working.
