---
name: compound
description: Document a recently solved problem as a durable learning in the project-external notes folder (`~/compound-engineering/<project>/solutions/`) by delegating to ce-compound with a relocated artifact root. Use instead of ce-compound whenever capturing a learning after work, or when the user says "compound this", "capture this learning", or "write this up as a solution".
argument-hint: "[optional: brief context] [mode:non-interactive] [depth:lightweight|full]"
based_on: 'EveryInc/compound-engineering-plugin@ce-compound'
---

# /compound — Project-External Learnings

A thin wrapper around `ce-compound`. Upstream writes learnings inside the repo and refuses any `docs_root` that resolves outside it. Project docs here live outside the repo by convention, so this skill runs `ce-compound` unchanged except for the three overrides below.

## Input

<input_document> #$ARGUMENTS </input_document>

## Resolve before delegating

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")
NOTES_ROOT="$HOME/compound-engineering/$PROJECT"
mkdir -p "$NOTES_ROOT/solutions"
```

`PROJECT` comes from the main checkout, so a worktree's learnings land in the same folder.

## Overrides

These take precedence over the named `ce-compound` steps. Everything else runs exactly as upstream says.

1. **Artifact root.** Skip upstream's `docs_root` resolution and validation entirely. `<root>` is `$NOTES_ROOT`, so learnings go to `$NOTES_ROOT/solutions/`. Pass that resolved path to every subagent. Never create or write `docs/solutions/` inside the repo.
2. **Claims validator repo.** `validate-doc-claims.py` finds the repo by running git from the doc's directory, which would resolve to the notes folder rather than the project. Every time a step runs it, prefix the invocation so git reads the project:

   ```bash
   GIT_DIR=$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir) GIT_WORK_TREE="$REPO_ROOT" "$PY" "$SKILL_DIR/scripts/validate-doc-claims.py" <doc-path>
   ```

   The semantic grounding subagent also checks claims against `$REPO_ROOT`, not the notes folder.
3. **No repo writes.** `CONCEPTS.md` lives at `$NOTES_ROOT/CONCEPTS.md` wherever upstream says "repo root". Skip the instruction-file discoverability edit in every mode, and report it as `Instruction-file edit: skipped (project-external notes)`.

## Delegate

Invoke `ce-compound` via the Skill tool, forwarding `<input_document>` verbatim, with the overrides above in force for the whole run.

## Known gap

Other CE skills (`ce-compound-refresh`, `ce-plan`, the code-review learnings researcher) still search the repo's `docs/solutions/`, so they will not find these learnings. Point them at `$NOTES_ROOT/solutions/` by hand when it matters.
