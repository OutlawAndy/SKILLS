---
name: skill-diff
description: Compare one local skill to its upstream equivalent, fetched fresh from GitHub, and show a raw diff with a summary header. Works on a skill in a source checkout (src/skills/) or one installed alongside skill-diff (e.g. ~/.copilot/skills/, ~/.claude/skills/). Use when asked to "compare a skill to upstream", "diff this skill against its source", "what changed upstream", "is my fork behind upstream", or to check whether a customized skill has drifted from the open-source skill it is based on.
license: MIT
metadata:
  triggers:
    - compare upstream
    - diff against upstream
    - compare skill to upstream
    - what changed upstream
    - is my fork behind
    - skill drift
    - based_on
---

# skill-diff

Single-script skill that compares one local skill against the upstream skill it was forked from. It reads the local skill's `based_on:` frontmatter, fetches the upstream `SKILL.md` **fresh from GitHub** (never from a local marketplace copy, which may be stale), and prints a raw textual diff preceded by a short summary header.

## What it shows (and what it does not)

The diff is a **two-way comparison** between your local `SKILL.md` and the current upstream HEAD — i.e. *current divergence*. For skills that track upstream closely this is effectively "what changed upstream." For skills that are substantial rewrites (e.g. `plan`, `work`), the diff is a full comparison, not a "since-fork delta"; the header flags this so the output is not misread. A true three-way "what changed upstream since I forked" view is a future addition (see "Fork-point ref", below).

The tool only **reports** drift. It never edits a skill, never applies upstream changes, and never rewrites `based_on`. It compares `SKILL.md` only — bundled `scripts/` and `references/` are not diffed (the header notes when upstream has them).

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

The local skill's `based_on:` frontmatter points at the upstream source. Two grammars are supported:

| Grammar | Example | Meaning |
|---|---|---|
| `owner/repo@skill` | `RoleModel/RoleModel-Skills@controller-patterns` | GitHub `owner/repo`, upstream skill dir `controller-patterns` |
| `Alias:skill` | `CompoundEngineering:plan` | Marketplace alias resolved via the inline alias map, upstream skill `plan` |

An optional trailing `@<ref>` (e.g. `owner/repo@skill@<sha>`) is tolerated and currently ignored — it reserves the grammar slot for the future fork-point diff.

Resolution queries the upstream repo's git tree once (`gh api .../git/trees/HEAD?recursive=1`), filters to skill roots, and matches the upstream directory by **exact equality** in three tiers: the exact name, then `ce-<name>`, then a unique token match. This handles the local-name/upstream-name skew (e.g. local `plan` → upstream `ce-plan`, local `work` → upstream `ce-work` and not the sibling `ce-work-beta`/`ce-worktree`).

A skill with no `based_on:` (an original skill, like this one) reports "no upstream recorded" and exits cleanly.

## The alias map (extension point)

Marketplace-style `based_on` values (`Alias:skill`) resolve through a small inline map at the top of `scripts/compare.sh`:

```sh
# alias  ->  owner/repo
CompoundEngineering   EveryInc/compound-engineering-plugin
```

To support a new marketplace alias, add one line mapping the **literal alias token used in `based_on:` values** to its GitHub `owner/repo`. The `owner/repo@skill` grammar needs no alias entry.

## Output

A summary header followed by the raw `SKILL.md` diff, for example:

```
skill-diff: controller-patterns
  upstream: RoleModel/RoleModel-Skills @ skills/controller-patterns/SKILL.md (HEAD a1b2c3d)
  frontmatter: differs (local-only: based_on)
  body: 4 changed hunks
--- (raw diff follows) ---
```

The header separates expected frontmatter-only differences (a local fork may add `based_on` and/or `targets`) from body divergence, so you can tell intentional customizations apart from upstream changes worth adopting.

## Fork-point ref (future)

Recording the upstream commit each skill was forked at (via the reserved `based_on: owner/repo@skill@<sha>` slot) would enable a three-way diff showing *only* new upstream changes. Not implemented yet; the parser already tolerates the slot so existing values keep working.
