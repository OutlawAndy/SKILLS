---
name: compound
description: Document a recently solved problem as a durable learning in the project-external notes folder (`~/compound-engineering/<project>/docs/solutions/`) by delegating to ce-compound with its claims validated against the project repo. Use instead of ce-compound whenever capturing a learning after work, or when the user says "compound this", "capture this learning", or "write this up as a solution".
argument-hint: "[optional: brief context] [mode:non-interactive] [depth:lightweight|full]"
based_on: 'EveryInc/compound-engineering-plugin@ce-compound'
---

# /compound — Project-External Learnings

A thin wrapper around `ce-compound`. The installed CE plugin is patched by `ce-doc-path-override` (dotfiles) to resolve its artifact root to `~/compound-engineering/<project>/docs`, so learnings already land outside the repo, where `ce-compound-refresh`, `ce-plan`, and the review learnings researcher look for them. That patch does not cover what follows from the doc living outside the repo, so this skill runs `ce-compound` with the two overrides below.

## Input

<input_document> #$ARGUMENTS </input_document>

## Resolve before delegating

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")
NOTES_ROOT="$HOME/compound-engineering/$PROJECT/docs"
```

`NOTES_ROOT` is the artifact root the patched install resolves. If `ce-compound` resolves `<root>` to anything else, the patch is missing (re-run `ce-doc-path-override` after a CE update): stop and say so rather than writing inside the repo.

## Overrides

These take precedence over the named `ce-compound` steps. Everything else runs exactly as upstream says.

1. **Claims validator repo.** `validate-doc-claims.py` finds the repo by running git from the doc's directory, which resolves to the notes repo rather than the project. Every time a step runs it, prefix the invocation so git reads the project:

   ```bash
   GIT_DIR=$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir) GIT_WORK_TREE="$REPO_ROOT" "$PY" "$SKILL_DIR/scripts/validate-doc-claims.py" <doc-path>
   ```

   The semantic grounding subagent also checks claims against `$REPO_ROOT`, not the notes folder.
2. **No repo writes.** `CONCEPTS.md` lives at `$NOTES_ROOT/CONCEPTS.md` wherever upstream says "repo root". Skip the instruction-file discoverability edit in every mode, and report it as `Instruction-file edit: skipped (project-external notes)`.

## Delegate

Invoke `ce-compound` via the Skill tool, forwarding `<input_document>` verbatim, with the overrides above in force for the whole run.
