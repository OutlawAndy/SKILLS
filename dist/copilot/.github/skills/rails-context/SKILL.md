---
name: rails-context
description: Internal Rails posture primer loaded by outlaw-skills workflow skills (`/work`, `/plan`, and future `/brainstorm`, `/ideate`). Not meant to be invoked standalone — provides operating assumptions, repo-shape probe steps, posture defaults, mandatory dispatch triggers, and pressure tests that orient subsequent Rails work. Workflow skills load this before pattern skills so they share a single Rails framing.
---

# Rails Context

Always-on framing for outlaw-skills workflow skills (`work`, `plan`, and future `brainstorm`/`ideate`). Loaded near session start by those skills. Reusable verbatim across all of them.

This file is not a Rails tutorial. It is a *posture* document: how to think about a Rails task before reaching for code. The substantive Rails knowledge lives in the dispatch targets (`layered-rails`, `ce-dhh-rails-style`, `controller-patterns`, `routing-patterns`, `frontend-patterns`). This file tells you when and why to reach for them.

---

## 1. Operating Assumptions

- The codebase is Ruby on Rails. Default to Rails conventions before reaching for anything custom.
- The user has installed `layered-rails`, `ce-dhh-rails-style`, `controller-patterns`, `routing-patterns`, `frontend-patterns`. These are available as Skill-tool invocations.
- The user values clarity over cleverness, REST over RPC, fat models over service-object-everywhere, Hotwire over SPAs, and convention over configuration. When in doubt, choose the more conventional path.
- The user works exclusively in Rails. Do not propose stack changes, alternative frameworks, or non-Rails patterns unless explicitly invited.

---

## 2. Repo-Shape Probe

Before substantive work, take a quick read of what this Rails app actually looks like. Do not assume; check. The probe is cheap and prevents bad advice.

Check these in order, stop when you have enough signal:

1. **`Gemfile` / `Gemfile.lock`** — Rails version, Ruby version, key gems:
   - Auth: Devise? Clearance? OmniAuth? Built-in `has_secure_password`?
   - Authorization: Pundit or ActionPolicy?
   - Background jobs: GoodJob!
   - Testing: RSpec!
   - Frontend: Hotwire (Turbo/Stimulus)? ViewComponent? Phlex? jsbundling/cssbundling?
   - Asset pipeline: Propshaft? Sprockets? importmap?
2. **`config/application.rb`** and **`config/environments/*.rb`** — load defaults version, autoloader (Zeitwerk assumed), enabled frameworks.
3. **`db/schema.rb`** (or `db/structure.sql`) — table shape; do not assume tables exist.
4. **`app/` directory layout** — presence of `app/services/`, `app/policies/`, `app/forms/`, `app/queries/`, `app/components/`, `app/jobs/` reveals layered-architecture adoption.
5. **`config/routes.rb`** — current routing style (resourceful vs custom, depth of nesting, use of concerns).
6. **`.ruby-version`** — pin in use.

Probe findings shape every downstream decision. Mention them when they change what you would otherwise propose.

---

## 3. Posture: How to Think About Rails Work

These are not rules to recite. They are the lens through which Rails work should be evaluated. Internalize them, then dispatch to the specialized skills for the substantive judgments.

### REST first, RPC last
A new endpoint should map to a CRUD verb on a resource before it becomes a custom action. If the verb is not CRUD, the resource is probably wrong. Sub-resources (`POST /articles/:id/publishings`) often beat custom actions (`POST /articles/:id/publish`). Consult `routing-patterns` before adding routes.

### Models are where logic lives by default
Fat models are not a sin; service-object-everywhere is. Reach for a service object, form object, query object, or policy only when the model is doing genuinely different work that benefits from extraction. The bar is "does this *clearly* belong in a different layer," not "could this be extracted." Consult `layered-rails` before introducing or modifying these layers.

### Callbacks are a smell, not a tool
Callbacks for cross-cutting persistence concerns (timestamps, normalization) are fine. Callbacks that orchestrate business operations (sending emails, creating related records, calling external APIs) are wrong. If the operation has a name, it deserves a method or an object. `layered-rails` has the callback-scoring rubric.

### Controllers are skimmable
A controller should read like a table of contents for what the actions do, not a script of what they do. If a controller action is more than ~10 lines, the work belongs elsewhere. Consult `controller-patterns` before authoring or modifying.

### Views render; they do not decide
Views should not branch on business logic. Helpers, presenters, or view components carry conditional rendering. Partials are reused, not nested into pyramids. Consult `frontend-patterns` before writing or modifying views.

### Generators are the default starting point
`bin/rails generate` produces the structure Rails expects. Do not hand-write what a generator would scaffold. Modify what the generator produced; do not work around it.

### Migrations are append-only history
Never edit a committed migration. Roll forward with a new one. Reversibility is required where realistic; data migrations should be idempotent and safe to re-run.

### Tests follow the layer
- Models → unit tests against the model
- Controllers → request specs / integration tests, not controller specs
- Services / forms / policies → unit tests against the object
- Views → system tests for behavior; do not unit-test rendered HTML

---

## 4. The DHH / 37signals Defaults

When proposing or writing Ruby/Rails code, default to the style `ce-dhh-rails-style` enforces. The shorthand:

- Plain Ruby objects over framework abstractions when both work.
- `Current.user` and `Current.account` over passing context through every method.
- Hotwire (Turbo Frames, Streams, Stimulus) over JSON APIs + client frameworks.
- Concerns for shared model behavior; no shared inheritance hierarchies.
- Strong parameters always; no `permit!` in real controllers.
- `before_action` for setup, not for branching logic.
- Method names that read like English. `article.published?` not `article.is_published`.

When the user's existing code conflicts with these defaults, follow the existing code's voice. Consistency beats correctness here.

---

## 5. Mandatory Dispatch Triggers

These fire as hard rules in the workflow skill. The Rails-context file documents them so the rationale is visible in one place; the `SKILL.md` of each workflow restates the imperative form.

| Trigger | Skill to invoke | When |
|---|---|---|
| About to write/modify Ruby or Rails code | `ce-dhh-rails-style` | Ambient — load at session start; reload if voice drifts |
| About to add or move business logic in a model, callback, service, form object, query object, or policy | `layered-rails` | Before designing the change |
| About to design or modify a controller | `controller-patterns` | Before writing the action |
| About to add or modify `config/routes.rb` | `routing-patterns` | Before editing the routes file |
| About to write or modify a view, partial, or view component | `frontend-patterns` | Before authoring the template |

Invoke via the Skill tool. Do not paraphrase the target skill's content from memory — re-load it.

---

## 6. Optional / Topic-Arises Dispatches

Fire on judgment when the named topic surfaces. Not mandatory.

- **`ruby-version`** — before asserting any Ruby version exists, is current, or is missing; before bumping `.ruby-version`.
- **`action-cable`** — before designing real-time / WebSocket features.
- **`form-auto-save`** — before building autosaving forms.
- **`bem-structure`** — before authoring or restructuring CSS.
- **`json-typed-attributes`** — before designing JSON-column attribute storage on AR models.
- **`dynamic-nested-attributes`** — before designing nested-form attribute handling.
- **`ai-ux-enhancements`** — before designing AI-driven UX surfaces.
- **`rails-audit`** — before or during a broader codebase health review.

---

## 7. Pressure Tests to Run Silently

Before proposing an implementation, ask yourself:

- **Is this CRUD?** If so, RESTful resource. If not, why not — and is the resource boundary wrong?
- **Where does the logic want to live?** Model first. Justify moving it elsewhere.
- **Am I about to add a callback?** Score it via `layered-rails`. Most callbacks lose.
- **Am I about to add a service object?** Could the model own this directly without becoming a god object? If yes, prefer the model.
- **Am I building an API when Turbo would do?** Default to Hotwire unless there is a specific need for JSON.
- **Am I writing a custom controller action?** Could it be a new resource instead?
- **Am I about to write a generator from scratch?** `bin/rails g` first.
- **Am I claiming infrastructure is missing?** Verify against `Gemfile`, schema, or config before saying so.

If a pressure test triggers, route to the relevant mandatory skill before continuing.

---

## 8. What This File Is Not

- Not a substitute for `layered-rails`, `ce-dhh-rails-style`, `controller-patterns`, `routing-patterns`, or `frontend-patterns`. Those are authoritative for their topics; this file dispatches to them.
- Not a Rails reference manual. Rails docs and source are authoritative.
- Not a place for project-specific conventions. Project-specific guidance belongs in the project's `AGENTS.md` / `CLAUDE.md`.
