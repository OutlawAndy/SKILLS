---
name: frontend-patterns
description: Frontend patterns for Rails applications using Slim templates with strict locals, Simple Form (always resource-backed, including form objects), Stimulus, Turbo (frames/streams/confirm), and the Optics CSS design system with BEM and design tokens. Use when building views, adding interactivity, styling components, or when the user mentions Slim, Simple Form, Stimulus, Turbo, JavaScript, CSS, or frontend development.
based_on: RoleModel/RoleModel-Skills@frontend-patterns
---

# Frontend Patterns

Build Rails frontend using Slim templates, Simple Form, Stimulus controllers, Turbo, and Optics CSS.

**Tech Stack:** Slim (HTML) • Simple Form + form objects (forms) • Stimulus (JavaScript) • Turbo (navigation/updates) • Optics (CSS)

See [references/EXAMPLES.md](references/EXAMPLES.md) for detailed code examples.

## Slim Templates

### Core Conventions
- Use Ruby 3+ syntax ( e.g. keyword arguments with `:`)
- Keep view logic minimal - extract to helpers/partials
- Always add policy checks around actions (e.g. edit/delete links)
- **Never use inline styles**
- **Extract repeated markup into partials (DRY principle)**
- Always use locals with keyword arguments: `render 'partial', user:, active: true`
- **Declare every partial's locals with a strict-locals magic comment** (see below)

### Strict Locals

Every partial declares its interface on the first line with Rails strict locals. This makes the partial's contract explicit and fails loudly on a missing or misspelled local instead of silently reading an instance variable.

```slim
-# locals: (resource:)
= simple_form_for resource do |f|
  ...
```

- Required locals have no default: `(resource:)`
- Optional locals supply a default, and the default may be any Ruby expression:

```slim
-# locals: (estimate:, tanks:)
-# locals: (resource:, turbo_fetch_url_value: turbo_fetch_materials_url, should_render_company_attributes: false)
-# locals: (f:, can_delete_layer: policy(f.object).destroy? && 1 < f.index.to_i)
```

Render the partial with matching keyword locals: `render 'form', resource:` or `render 'fieldset', f:, can_delete_layer: true`.

### Helpers vs Partials

**Use Helpers for:**
- Single elements with conditional text/classes
- Data formatting (dates, currency)
- Stateless logic
- Example: `status_badge(status)`

**Use Partials for:**
- Multi-element structures
- Reusable UI components
- Collection rendering
- Example: `_form.html.slim`, `_user_card.html.slim`

**Rule:** Single element = helper. Structure/layout = partial.

### Partial Organization
```
app/views/
  resource_name/
    index.html.slim           # Main views
    _form.html.slim           # Forms (shared by new/edit)
    _resource_name.html.slim  # Individual item
  shared/
    _status_badge.html.slim   # Cross-feature components
```

### Common Patterns
```slim
-# Conditional classes
.card class=class_names('card--active': active, 'card--urgent': urgent)

-# Partial with locals
= render 'user_card', user:, show_actions: true

-# Collection rendering
= render partial: 'item', collection: @items

-# Conditional rendering
- if policy(@resource).update?
  = link_to 'Edit', edit_path(@resource)
```

## Simple Form

**Always use Simple Form.** Never use `form_with` or `form_for`.

### The one rule: pass a resource

Every form is built by passing a **resource** to `simple_form_for`. Never set `url:` by hand, and never build a form from a bare `:symbol`. Simple Form derives the action URL and HTTP method from the resource's persistence state — a hand-set `url:` is a smell that the wrong thing is being passed.

A resource is one of:

| Resource | Form line |
|----------|-----------|
| Model instance | `simple_form_for resource` |
| Nested route | `simple_form_for [@tank, @ring]` |
| Form object (non-CRUD) | `simple_form_for @filter` |

For anything that isn't a single persisted record — search, filters, bulk actions — build a plain Ruby **form object** (`ActiveModel::Model`) and pass *it* as the resource. The rule has no exceptions. (See the layered-rails skill for building form objects.)

### Keep it minimal

Real forms carry almost no top-level options and almost no per-input options. The opening line is usually bare, inputs are grouped in `.form-row`, and you let Simple Form + Optics supply labels, wrappers, and styling:

```slim
-# locals: (resource:)
= simple_form_for resource do |f|
  .form-row
    = f.input :name
    = f.input :email
  .form-row
    = f.input :phone
```

Add a top-level option only for a concrete need — `data:` to wire a Stimulus controller, occasionally `html: { class: 'flex' }`:

```slim
= simple_form_for resource, data: { controller: 'turbo-fetch', turbo_fetch_url_value: } do |f|
```

Add per-input options only when the default is wrong (a custom `label:`, a `collection:`, a `hint:`, an `as:` type). Don't restate defaults.

### Common Input Types

| Type | Example |
|------|---------|
| Text | `= f.input :name` |
| Textarea | `= f.input :description, as: :text, input_html: { rows: 4 }` |
| Association | `= f.association :project, collection: policy_scope(Project)` |
| Select | `= f.input :type, collection: @project_types, prompt: 'Select...'` |
| Boolean | `= f.input :active, as: :boolean` |
| Date | `= f.input :start_date, as: :date` |
| Hidden | `= f.hidden_field :organization_id, value: current_user.organization_id` |

### Input Options
- `placeholder:` - Placeholder text
- `label:` - Custom label
- `hint:` - Help text below input
- `required: true` - Mark as required
- `disabled: true` - Disable input
- `input_html: {}` - HTML attributes for input element
- `wrapper_html: {}` - HTML attributes for wrapper div

### Collections
```slim
/ Basic collection
= f.input :category_id, collection: @categories

/ Custom label/value methods
= f.input :project_id,
  collection: @projects,
  label_method: :name,
  value_method: :id,
  prompt: 'Select project...'
```

### Special Form Patterns

**Bulk action form (form object as resource):**
```slim
-# @bulk_action is a form object whose route handles the bulk operation
= simple_form_for @bulk_action, html: { id: 'bulk-form' } do |f|
  = f.button :submit, 'Approve Selected', class: 'btn btn--primary'

-# Checkboxes reference the form by id
= check_box_tag 'bulk_action[entry_ids][]', entry.id, false, form: 'bulk-form'
```

**Modal form with external submit:**
```slim
= simple_form_for @record, html: { id: 'modal-form' }, data: { turbo_frame: '_top' } do |f|
  = f.input :reason, as: :text, input_html: { rows: 3, required: true }

-# In modal footer
= button_tag 'Submit', type: 'submit', form: 'modal-form', class: 'btn btn--primary'
```

### Form Options
- `html: {}` - HTML attributes for form element (e.g., `id`, `class`)
- `data: {}` - Data attributes (e.g., Turbo, Stimulus)
- **No `url:`** - the resource determines the URL; if you need `url:`, the resource is wrong (use a form object)

See [references/EXAMPLES.md](references/EXAMPLES.md) for complex form examples.

## Stimulus Controllers

JavaScript interactions using Stimulus framework.

### Controller Structure
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "input"]
  static values = { url: String, delay: Number }
  static classes = ["hidden", "active"]

  connect() {
    // Initialization when controller connects to DOM
  }

  disconnect() {
    // Cleanup when controller disconnects
  }

  action(event) {
    // Action methods called from HTML
  }
}
```

### Usage in Slim
```slim
.component data-controller="example" data-example-url-value="/api/endpoint"
  input data-example-target="input" data-action="input->example#search"
  .results data-example-target="output"
```

### Best Practices
- One controller per behavior (focused, composable)
- Use data attributes for configuration
- Name controllers in kebab-case in HTML
- Keep controllers simple and testable
- Clean up in `disconnect()` (timers, listeners)

See [references/EXAMPLES.md](references/EXAMPLES.md) for complete controller examples.

## CSS & Optics

Styling is built on **Optics** (RoleModel's design system) using **BEM** class names. Optics ships design tokens as CSS custom properties and base components; the app layers its own BEM components on top, one SCSS file per component.

### Guidelines
- Keep custom CSS minimal and component-scoped
- **Never use inline styles**
- Use of utility classes is strongly discouraged. BEM (Block Element Modifier) structure should be used instead.
- **Always style with Optics design tokens, never hard-coded values** — `var(--op-space-large)`, `var(--op-color-primary-base)`, `var(--op-font-small)`
- One component = one SCSS file, imported from the main manifest
- Use `class_names` helper for conditional classes

### Design Tokens

| Token family | Examples |
|--------------|----------|
| Spacing | `var(--op-space-x-small)` … `var(--op-space-3x-large)` |
| Color | `var(--op-color-primary-base)`, `var(--op-color-neutral-plus-eight)` |
| Typography | `var(--op-font-small)` |

### Component SCSS (BEM + tokens)
```scss
// app/assets/stylesheets/components/comments.scss
.comment {
  display: flex;
  flex-direction: column;
  gap: var(--op-space-x-small);
}

.comment__header {
  display: flex;
  align-items: center;
}

.comment__body {
  gap: var(--op-space-medium);
}
```

Import Optics and each component from the manifest:
```scss
// application.scss
@import '@rolemodel/optics/dist/scss/optics';
@import 'components/comments';
```

### Markup (BEM)
```slim
/ Custom component with BEM
.time-entry.time-entry--running
  .time-entry__header
    h3.time-entry__title = entry.description
  .time-entry__body
    span.time-entry__duration = entry.duration
```

### Conditional Classes
```slim
/ Using class_names helper
.card class=class_names(
  'card--active': @record.active?,
  'card--featured': @record.featured?
)
```

## Turbo

Turbo Drive is on by default. Reach for these patterns before writing custom JavaScript or forcing full-page reloads.

### Frames

Wrap an independently-updatable region in a frame, then re-render the same frame (from a partial or a turbo_stream) to swap just that region:
```slim
= turbo_frame_tag comment
  = render comment
```

Lazy-load expensive content with `src:` so the page paints first:
```slim
= turbo_frame_tag :dashboard_stats, src: stats_path, loading: :lazy
  | Loading…
```

### Streams

Respond with a `*.turbo_stream.slim` view to update multiple targets in one response:
```slim
= turbo_stream.replace dom_id(@comment) do
  = render @comment
= turbo_stream.update :comment_count, @post.comments.size
```

Forms re-rendered inside a stream (e.g. live-recalculating forms) still pass a resource — pair them with a Stimulus controller that re-submits, rather than hand-setting URLs.

### Confirmations (@rolemodel/turbo-confirm)

Use `data: { turbo_confirm: ... }` on destructive actions; add `confirm_details:` for a richer dialog:
```slim
= button_to 'Delete', path, method: :delete,
  data: { turbo_confirm: 'Delete this?', confirm_details: 'This cannot be undone.' }
```

## Quick Reference

**Form actions pattern:**
```slim
.form__actions
  = link_to 'Cancel', :back, class: 'btn btn--outline'
  = f.submit 'Save', class: 'btn btn--primary'
```

**Empty state:**
```slim
- if @items.empty?
  = render 'shared/empty_state', title: 'No items', message: 'Create your first item.'
```

**Authorization check:**
```slim
- if policy(@resource).update?
  = link_to 'Edit', edit_path(@resource), class: 'btn'
```

**Strict locals (first line of every partial):**
```slim
-# locals: (resource:, show_actions: true)
```
