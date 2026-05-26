---
name: work
description: Execute Rails work with mandatory dispatch to layered-rails, ce-dhh-rails-style, controller-patterns, routing-patterns, and frontend-patterns. Use whenever implementing, modifying, or debugging Ruby on Rails code — features, refactors, bug fixes, or focused changes. Replaces the generic ce-work workflow for Rails-only environments. Triggers on phrases like "work this", "implement this", "ship this", or any direct request to do Rails work.
argument-hint: "[Plan doc path or description of work. Blank to auto-use latest plan doc]"
---

# /work — Rails Execution

Execute Rails work efficiently while honoring layered-architecture, DHH/37signals conventions, and the existing Rails skill ecosystem.

> **Mandatory:** Before substantive work, load [references/rails-context.md](references/rails-context.md). It is the always-on Rails framing for this skill. Do not paraphrase it from memory — read it.

## Input

<input_document> #$ARGUMENTS </input_document>

---

## Phase 0: Load Context

Before triaging input, do both:

1. **Read `references/rails-context.md`** in full. It contains operating assumptions, the repo-shape probe checklist, posture rules, DHH defaults, and the dispatch table. Everything below assumes its content is loaded.

2. **Invoke `ce-dhh-rails-style` via the Skill tool** to load the ambient code-style framing for the session. This is the ambient mandatory dispatch (R7). Do this once at session start; reload if voice drifts mid-session.

---

## Phase 1: Input Triage

Determine how to proceed based on `<input_document>`.

- **Plan document** (file path to an existing plan/specification) → read it fully, then go to Phase 2.
- **Bare prompt** (description of work, not a file path) → assess complexity:

  | Complexity | Signals | Action |
  |---|---|---|
  | **Trivial** | 1–2 files, no behavioral change (typo, config, rename) | Skip task-list ceremony. Implement directly. Still honor mandatory triggers when applicable. |
  | **Small / Medium** | Clear scope, under ~10 files | Build a task list. Continue to Phase 2. |
  | **Large** | Cross-cutting, architectural decisions, 10+ files, touches auth/payments/migrations/auth or anything touching layered-rails boundaries | Recommend `/ce-brainstorm` or `/ce-plan` first. Honor user's choice; if proceeding, build a task list. |

If the input mentions a controller, route, model callback, service/form/query/policy object, or view/partial/component, the work is **not trivial** regardless of file count — the mandatory triggers apply.

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
- "App is on Solid Queue, not Sidekiq — background work goes through `ApplicationJob`."
- "No `app/services/` directory exists; layered-rails will say to extract one only when justified."

Do not skip this probe. Bad Rails advice almost always comes from assuming a generic Rails shape.

---

## Phase 3: Mandatory Dispatches

These are hard rules. Each fires **before** the named work begins, not after. Invoke the named skill via the Skill tool. Do not paraphrase its content from memory.

| Before you... | Invoke |
|---|---|
| Design or modify a controller (any file in `app/controllers/`) | `controller-patterns` |
| Add or modify routes (`config/routes.rb`) | `routing-patterns` |
| Add or move business logic in a model, callback, service, form object, query object, or policy | `layered-rails` |
| Write or modify a view, partial, or view component (`app/views/`, `app/components/`) | `frontend-patterns` |
| Write or modify any Ruby/Rails code (ambient) | `ce-dhh-rails-style` (already loaded in Phase 0; reload if voice has drifted) |

If a single change touches multiple trigger categories, invoke each relevant skill before authoring.

Optional / topic-arises dispatches are listed in `rails-context.md` §6. Fire those on judgment.

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

   When dispatching subagents for Rails work, **explicitly pass the mandatory-trigger table from Phase 3** into the subagent's prompt. Subagents do not inherit the dispatch obligations otherwise.

---

## Phase 5: Execute

For each task in priority order:

1. Mark in-progress.
2. Read referenced files from the plan or discovered during the probe.
3. **Check if the work is already done.** If files exist with the expected capability and the unit's `Verification` is satisfied, mark complete and move on — do not silently reimplement.
4. **Honor the mandatory triggers from Phase 3.** Before authoring the change, invoke the relevant skill(s).
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

- **Rails conventions first.** Reach for custom patterns only when the convention demonstrably falls short.
- **Dispatch, do not duplicate.** `layered-rails`, `ce-dhh-rails-style`, `controller-patterns`, `routing-patterns`, and `frontend-patterns` are authoritative for their topics. This skill orchestrates them.
- **Probe before proposing.** The repo-shape probe is not optional. Bad Rails advice almost always comes from assuming a generic shape.
- **Finish the feature.** A shipped Rails feature beats a perfect one stuck at 80%.
- **Test as you go.** Run after each change, not at the end.

## Common Pitfalls

- **Skipping the repo-shape probe** — leads to advice that doesn't match the actual stack (recommending Sidekiq when the app uses Solid Queue, Pundit patterns when the app uses Action Policy).
- **Forgetting mandatory triggers** — authoring a controller without consulting `controller-patterns`, or moving model logic without consulting `layered-rails`. The triggers in Phase 3 are not suggestions.
- **Paraphrasing dispatched skills from memory** — re-invoke them; do not summarize from training data.
- **Hand-writing what a generator would scaffold** — `bin/rails g` first.
- **Service-object reflex** — extracting a service when the model could own the logic without becoming a god object.
- **Callback creep** — using `after_save` to orchestrate business operations. Score callbacks via `layered-rails`.
- **Testing only with mocks** — mocked tests prove logic in isolation; integration tests prove layers work together. Rails changes that touch callbacks, middleware, or error handling need both.
