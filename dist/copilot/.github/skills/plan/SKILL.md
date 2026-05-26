---
name: plan
description: Create a Rails-aware implementation plan by priming pattern skills and delegating to ce-plan. Use whenever planning Ruby on Rails work — features, refactors, or architectural decisions. Replaces the generic ce-plan workflow for Rails-only environments. Triggers on phrases like "plan this", "create a plan", "write a tech plan", "plan the implementation", "how should we build", "what's the approach for", or "break this down".
argument-hint: "[optional: feature description, requirements doc path, plan path to deepen]"
based_on: 'CompoundEngineering:plan'
---

# /plan — Rails-Aware Planning

This skill is a thin wrapper around `ce-plan`. It exists to ensure that planning happens with your Rails pattern skills already primed in context, so the resulting plan reflects layered-rails decisions, DHH-style conventions, and your controller/routing/frontend patterns from the start — not as a retrofit during `/work`.

The downstream `/work` skill reads the frontmatter marker this skill writes and uses it to decide whether to skip its heavy pre-flight gate. A plan produced by `/plan` is a trust signal: pattern thinking has already happened.

---

## Input

<input_document> #$ARGUMENTS </input_document>

---

## Phase 1: Domain Check

Before priming Rails context, decide whether this is a Rails planning task.

| Signal | Action |
|---|---|
| The request mentions Ruby, Rails, a model, controller, route, view, ActiveRecord, Hotwire, etc. | Continue to Phase 2 (Rails priming). |
| The request points to a file under `app/`, `config/`, `db/`, `lib/` of a Rails project | Continue to Phase 2. |
| The request is plainly non-software (trip plan, study plan, event plan) | Skip Phase 2. Delegate directly to `ce-plan` via Skill tool; it routes to `universal-planning.md`. |
| The request is software but not Rails (Python, JS-only, infra-only) | Skip Phase 2. Delegate directly to `ce-plan`. The pattern skills do not apply. |
| Ambiguous | Ask the user one targeted question, then route. |

---

## Phase 2: Prime Rails Context

Load these via the Skill tool, in this order, before invoking `ce-plan`. Each load injects guidance into the conversation; subsequent reasoning has access to all of them.

1. **Skill `rails-context`** — Rails posture primer shared with `/work`. Tells the planner *when* to reach for which pattern skill.
2. **Skill `ce-dhh-rails-style`** — ambient framing for every Rails decision.
3. **Skill `layered-rails`** — layer assignments are a planning-time decision, not an execution-time one. The planner must think in layers from the start.
4. **Skill `controller-patterns`** — load if the work plausibly touches a controller. When uncertain, load anyway; planning context is cheap.
5. **Skill `routing-patterns`** — load if the work plausibly touches `config/routes.rb` or introduces new endpoints.
6. **Skill `frontend-patterns`** — load if the work plausibly touches views, partials, components, or Stimulus controllers. Skip silently if the skill is not installed.

**When uncertain about which pattern skills apply, load all of them.** Planning happens once; the context cost is one-time and small compared to producing a plan that misses a pattern decision.

Self-attest before continuing. Produce a visible block in this exact format:

```
## /plan pre-flight
- Skills loaded: <comma-separated names>  # must include rails-context
```

---

## Phase 3: Delegate to ce-plan

Invoke `ce-plan` via the Skill tool, forwarding the original `<input_document>` arguments. `ce-plan` will run its full workflow (resume detection, requirements lookup, research, structuring, deepening) — but it does so with the Rails pattern skills already primed, so every layer/controller/routing/view decision is shaped by them.

Before invoking, set these expectations for the plan output:

### Required additions to the standard ce-plan output

1. **Frontmatter marker.** The plan's YAML frontmatter must include:

   ```yaml
   planned_with: outlaw-plan
   pattern_skills_loaded:
     - ce-dhh-rails-style
     - layered-rails
     - controller-patterns      # only if loaded
     - routing-patterns         # only if loaded
     - frontend-patterns        # only if loaded
   ```

   This marker is what `/work` reads to decide whether to run in light or heavy mode.

2. **Pattern Decisions section.** Add a section titled `## Pattern Decisions` between the research summary and the implementation units. It captures the architecture-shaping decisions that flowed from the pattern skills, *before* per-unit detail. Each decision should:

   - Name the decision (e.g., "Authorization via Pundit policy", "Logic lives in the model, not a service", "Use `resources` with shallow nesting, not custom routes")
   - Cite which pattern skill rule drove it (e.g., "see `layered-rails` §callback scoring", "see `controller-patterns` standard controller")
   - Note any deviation from the pattern skill's default *and* the justification (deviations should be rare)

   Skip this section only when the plan is genuinely pattern-trivial (e.g., a typo fix that somehow needed a plan). In that case, write `## Pattern Decisions\n\nNone — work is pattern-neutral.` rather than omitting the heading, so `/work` can still detect the marker structure.

3. **Per-unit `Patterns to follow`.** `ce-plan` already supports this field. Require it to be populated with skill-grounded references (e.g., "Mirror `controller-patterns` standard `set_*` before_action structure"), not generic phrases like "follow existing conventions".

### Pressure tests during planning

While `ce-plan` runs, apply these silently. If any trigger, surface the decision in `## Pattern Decisions` rather than letting `/work` rediscover it later:

- **Callback creep** — any plan to add an `after_save` / `after_commit` that orchestrates business operations. Score the callback per `layered-rails` and prefer a domain method or operation.
- **Service-object reflex** — any plan to introduce `app/services/` for logic the model could own. Justify or relocate.
- **Custom routes** — any plan that adds non-RESTful routes. Justify or restructure.
- **Skinny models, fat controllers** — any controller action carrying logic beyond standard RESTful glue. Move to model or query object.

---

## Phase 4: Post-Flight Verification

After `ce-plan` produces or updates the plan file:

1. **Read back the plan file.**
2. **Check frontmatter** contains `planned_with: outlaw-plan` and the `pattern_skills_loaded` list reflecting what was actually loaded in Phase 2. If missing, add it via Edit.
3. **Check for `## Pattern Decisions` section.** If missing, add it — either with the substantive decisions made during planning, or with the `None — work is pattern-neutral.` placeholder.
4. **Spot-check at least one implementation unit** for a populated `Patterns to follow` field. If units lack it, add references to the relevant pattern skill rules.

Report the final plan path to the user and note that `/work <plan-path>` will execute it in light mode (skipping the heavy pre-flight gate because pattern thinking has been carried forward).

---

## Key Principles

- **Plan with patterns primed, not retrofit.** A plan that named its pattern decisions up front is dramatically cheaper to execute than one that punts every layer question to implementation.
- **Delegate, do not fork.** `ce-plan` is 855 lines of careful planning workflow. This skill adds Rails priming and an output contract — nothing more. If `ce-plan` improves, `/plan` improves with it.
- **The frontmatter marker is a trust contract with `/work`.** Only write `planned_with: outlaw-plan` when the pattern skills were actually loaded and the Pattern Decisions section reflects real thinking. A plan with a marker but no pattern thought defeats the whole point.
- **Universal planning still routes through `ce-plan` cleanly.** Non-software tasks skip Phase 2; nothing here forces Rails priming on a trip plan.

## Common Pitfalls

- **Loading skills, then never letting them shape the plan.** The skills must influence Pattern Decisions, not just sit in context as decoration. If the resulting plan reads identical to a vanilla `ce-plan` output, the priming was wasted.
- **Marker without substance.** Writing `planned_with: outlaw-plan` on a plan that didn't actually consider patterns will silently break `/work`'s light mode — `/work` will trust the marker and skip its gate, producing pattern-blind code from a pattern-blind plan.
- **Forking ce-plan instead of delegating.** Tempting when ce-plan does something you'd do differently. Resist; surface the disagreement upstream or document a local override, but keep `/plan` thin.
- **Loading the wrong subset.** When in doubt, load all five pattern skills. A planning session is one-time context cost; missing a pattern means re-planning or, worse, a plan that misses a layer decision.
