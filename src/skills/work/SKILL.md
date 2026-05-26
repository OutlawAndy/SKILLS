---
name: work
description: Execute Rails work with mandatory dispatch to layered-rails, ce-dhh-rails-style, controller-patterns, routing-patterns, and frontend-patterns. Use whenever implementing, modifying, or debugging Ruby on Rails code — features, refactors, bug fixes, or focused changes. Replaces the generic ce-work workflow for Rails-only environments. Triggers on phrases like "work this", "implement this", "ship this", or any direct request to do Rails work.
argument-hint: "[Plan doc path or description of work. Blank to auto-use latest plan doc]"
---

# /work — Rails Execution

> ## ⛔ STOP. Mandatory Pre-Flight Gate.
>
> **You may not call Edit, Write, MultiEdit, or any code-modifying tool until this gate is passed.**
>
> This gate exists because previous sessions skipped the Rails skill loads and authored code without them. Soft instructions deeper in this file are not enough. The gate is here, at the top, before any planning, because the agent (you) cannot be trusted to scroll down and obey a Phase 3 instruction once the implementation impulse has taken over.
>
> ### Pre-flight checklist
>
> 1. **Read** [references/rails-context.md](references/rails-context.md) — in full, not paraphrased.
> 2. **Invoke `ce-dhh-rails-style` via the Skill tool** — ambient framing, every session.
> 3. **Classify the work.** Read the user's request and identify which of these categories it touches. Multiple categories can apply.
>
>    | If the work touches... | You must load (Skill tool) |
>    |---|---|
>    | Any Ruby or Rails code (always applies if any code is written) | `ce-dhh-rails-style` |
>    | A controller — any file in `app/controllers/**` | `controller-patterns` |
>    | Routes — `config/routes.rb` | `routing-patterns` |
>    | Business logic in a model, callback, service, form, query, or policy | `layered-rails` |
>    | A view, partial, or view component — `app/views/**`, `app/components/**` | `frontend-patterns` |
>
> 4. **Load every applicable skill** via the Skill tool, *before* doing any planning or code authoring. Do not paraphrase loaded skills from memory; load them fresh each session.
>
> 5. **Self-attest in your response.** Before your first Edit/Write/MultiEdit call, produce a visible acknowledgment block in this exact format:
>
>    ```
>    ## /work pre-flight
>    - Work touches: <comma-separated category names>
>    - Loaded skills: <comma-separated skill names>
>    - rails-context.md: read
>    ```
>
>    If the acknowledgment block is missing, the gate is not passed. A hook-based gate (`bin/install` in outlaw-skills) may additionally block your Edit/Write calls on Rails-shaped paths until the relevant skill has been loaded this session.
>
> ### When the gate does NOT apply
>
> - The work is purely documentation (`README.md`, `docs/**`, comments) and no Ruby/Rails code will be edited.
> - The work is purely git/shell operations with no source-file edits.
> - The user is asking a question, not requesting code changes.
>
> When in doubt, assume the gate applies.

---

## Input

<input_document> #$ARGUMENTS </input_document>

---

## Phase 1: Input Triage

(The pre-flight gate above has already loaded `rails-context.md` and the relevant skills. If it has not, return to the gate.)

Determine how to proceed based on `<input_document>`.

- **Plan document** (file path to an existing plan/specification) → read it fully, then go to Phase 2.
- **Bare prompt** (description of work, not a file path) → assess complexity:

  | Complexity | Signals | Action |
  |---|---|---|
  | **Trivial** | 1–2 files, no behavioral change (typo, config, rename) | Skip task-list ceremony. Implement directly. Pre-flight gate still applies if any Ruby/Rails code is touched. |
  | **Small / Medium** | Clear scope, under ~10 files | Build a task list. Continue to Phase 2. |
  | **Large** | Cross-cutting, architectural decisions, 10+ files, touches auth/payments/migrations or anything touching layered-rails boundaries | Recommend `/ce-brainstorm` or `/ce-plan` first. Honor user's choice; if proceeding, build a task list. |

---

## Phase 2: Repo-Shape Probe

Before designing or writing anything Rails-specific, run the probe from `rails-context.md` §2. At minimum:

- Read `Gemfile` to identify Rails version, auth, authz, jobs, testing framework, frontend stack.
- Read `.ruby-version`.
- Glance at `app/` for layered-architecture markers (`app/services/`, `app/policies/`, `app/forms/`, `app/queries/`, `app/components/`).
- Glance at `config/routes.rb` to read the existing routing style.
- Check `db/schema.rb` only for tables/columns this work will touch — do not load the whole schema.

Surface findings that change your approach. Examples:
- "App uses Pundit, so authorization goes through a policy."
- "App is on GoodJob — background work goes through `ApplicationJob`."
- "No `app/services/` directory exists; layered-rails will say to extract one only when justified."

Do not skip this probe. Bad Rails advice almost always comes from assuming a generic Rails shape.

---

## Phase 3: Recheck Triggers After Probe

The pre-flight gate classified the work from the user's request. The repo-shape probe may reveal additional trigger categories the user did not mention — e.g., the work the user described as "add an archive button" may require a new route, a controller change, and a callback rewrite.

**If the probe reveals new trigger categories, return to the pre-flight gate and load the additional skills before proceeding.** Re-emit the `## /work pre-flight` block with the updated category and skill list.

---

## Phase 4: Branch & Task Setup

1. **Branch check.** If on the default branch, create a feature branch (`feat/<meaningful-name>`) or use a worktree. If on a feature branch with an opaque name (e.g., `worktree-jolly-beaming-raven`), suggest renaming before continuing. Never commit to the default branch without explicit user confirmation.

2. **Task list.** Use the platform's task-tracking tool. Derive tasks from the plan's implementation units (when working from a plan) or from the bare-prompt complexity assessment. Preserve plan U-IDs as task prefixes (e.g., "U3: Add parser coverage") when present. Carry each unit's `Execution note` into the task.

3. **Execution strategy.**

   | Strategy | When to use |
   |---|---|
   | **Inline** | 1–2 small tasks, or tasks needing user interaction mid-flight. Default for bare-prompt work. |
   | **Serial subagents** | 3+ tasks with dependencies. Each subagent gets a fresh context window. Requires plan-unit metadata. |
   | **Parallel subagents** | 3+ independent tasks with no file overlap. Build a file-to-unit map first; any overlap → downgrade to serial. |

   When dispatching subagents for Rails work, **explicitly pass the pre-flight gate (categories + skill loads) into the subagent's prompt.** Subagents do not inherit the gate otherwise — they start fresh and will skip it just like the parent would have.

---

## Phase 5: Execute

For each task in priority order:

1. Mark in-progress.
2. Read referenced files from the plan or discovered during the probe.
3. **Check if the work is already done.** If files exist with the expected capability and the unit's `Verification` is satisfied, mark complete and move on — do not silently reimplement.
4. **Honor the pre-flight gate.** If new files come into scope that match a trigger category whose skill was not yet loaded, load it now before authoring the change.
5. Follow existing patterns. Match naming, structure, and conventions of the surrounding code. When the user's existing code conflicts with DHH defaults, follow the existing code's voice — consistency beats correctness here.
6. Use generators where they apply. `bin/rails g` produces the structure Rails expects; do not hand-write what a generator would scaffold.
7. **Test Discovery.** Find existing test files for implementation files being changed. New behavior → new tests. Changed behavior → updated tests. Removed behavior → removed tests.
8. **Test Scenario Completeness.** Cover the relevant categories:

   | Category | When |
   |---|---|
   | Happy path | Always for feature-bearing units |
   | Edge cases | Boundary values, empty/nil inputs, concurrency |
   | Error / failure paths | Validation, external calls, permission denials |
   | Integration | Cross-layer chains (callbacks, middleware, multi-service). Use real objects, not mocks. |

9. **Run tests** (`bin/rails test`, `bundle exec rspec`, or whatever the probe revealed) after the change. Fix failures immediately.
10. Mark complete. Evaluate for incremental commit.

### Execution posture

- For test-first units, write the failing test before implementation.
- For characterization-first units, capture existing behavior before changing it.
- Skip test-first discipline for trivial renames, pure config, and pure styling.

### Pressure tests (run silently)

Use `rails-context.md` §7 before proposing each implementation. If a pressure test triggers, route to the relevant mandatory skill before continuing.

---

## Phase 6: Incremental Commits

Commit after each logical unit completes. Heuristic: "Can I write a commit message that describes a complete, valuable change?" If yes → commit. If the message would be "WIP" or "partial X" → wait.

Workflow:

```bash
# 1. Verify tests pass
bin/rails test  # or bundle exec rspec, etc.

# 2. Stage only files for this logical unit (not git add .)
git add <files for this unit>

# 3. Commit with conventional message
git commit -m "feat(scope): description"
```

Incremental commits use clean conventional messages without attribution footers. The final shipping commit/PR carries full attribution.

**Parallel subagent mode:** Subagents do not commit. The orchestrator stages and commits after the parallel batch completes.

---

## Phase 7: Simplify

After completing a cluster of related units (every 2–3 units, or at a natural phase boundary), review recently changed files for simplification — consolidate duplicated patterns, extract shared helpers. This is especially valuable after parallel subagent dispatch, since each agent worked with isolated context.

Don't simplify after every unit — early patterns may look duplicated but diverge intentionally later.

If `/simplify` is available, use it. Otherwise, review changed files manually.

---

## Phase 8: Ship

When all Phase 5 tasks are complete:

1. **Final test run** — full suite, not just affected files.
2. **Lint / format** — `bin/rubocop`, `bin/standardrb`, or whatever the project uses (check `Gemfile`).
3. **Review the diff** — inline review for additive trivial work; full review (consider `/ce-code-review`) for anything substantive.
4. **Commit + push + PR** — use `/ce-commit-push-pr` if available, otherwise commit with attribution and open the PR via `gh pr create`.
5. **Verify behavior** — for UI changes, start the app and exercise the feature. Type checking and tests verify correctness, not feature behavior.

If the plan carried R-IDs / U-IDs / AE-IDs, reference them in the PR description for traceability.

---

## Key Principles

- **The pre-flight gate is not optional.** It exists because past sessions failed without it. Re-read it whenever you're tempted to skip.
- **Rails conventions first.** Reach for custom patterns only when the convention demonstrably falls short.
- **Dispatch, do not duplicate.** `layered-rails`, `ce-dhh-rails-style`, `controller-patterns`, `routing-patterns`, and `frontend-patterns` are authoritative for their topics. This skill orchestrates them.
- **Probe before proposing.** The repo-shape probe is not optional. Bad Rails advice almost always comes from assuming a generic shape.
- **Finish the feature.** A shipped Rails feature beats a perfect one stuck at 80%.
- **Test as you go.** Run after each change, not at the end.

## Common Pitfalls

- **Skipping the pre-flight gate.** The most common failure mode. The gate is at the top of this file specifically because Phase-3-style placement was empirically unreliable.
- **Skipping the repo-shape probe** — leads to advice that doesn't match the actual stack.
- **Paraphrasing dispatched skills from memory** — re-invoke them; do not summarize from training data.
- **Hand-writing what a generator would scaffold** — `bin/rails g` first.
- **Service-object reflex** — extracting a service when the model could own the logic without becoming a god object.
- **Callback creep** — using `after_save` to orchestrate business operations. Score callbacks via `layered-rails`.
- **Testing only with mocks** — mocked tests prove logic in isolation; integration tests prove layers work together. Rails changes that touch callbacks, middleware, or error handling need both.
