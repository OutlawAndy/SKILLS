# Frontend Patterns - Detailed Examples

## Slim Template Examples

### Basic Partial with Locals
```slim
-# app/views/users/_user_card.html.slim
-# locals: (user:, active: false, show_actions: true)

.user-card class=class_names('user-card--active': active)
  .user-card__header
    h3.user-card__name = user.name
    = render 'shared/status_badge', status: user.status if user.status

  .user-card__body
    p.user-card__email = user.email
    p.user-card__role = user.role.titleize

  - if show_actions
    .user-card__actions
      = link_to 'Edit', edit_user_path(user), class: 'btn btn--sm btn--outline'
      = button_to 'Delete', user_path(user), method: :delete, class: 'btn btn--sm btn--danger', 
        data: { turbo_confirm: 'Are you sure?' }
```

### Collection Rendering with Empty State
```slim
-# app/views/time_entries/index.html.slim

.time-entries
  h1.page-title Time Entries

  - if @time_entries.any?
    .time-entries__list
      = render partial: 'time_entry', collection: @time_entries
  - else
    = render 'shared/empty_state', 
      title: 'No time entries yet', 
      message: 'Start tracking your time by creating your first entry.',
      action: { text: 'New Entry', path: new_time_entry_path }
```

### Representative Form Example

Pass the resource, group inputs in `.form-row`, and add options only where the default is wrong. Note how few options each input carries — let Simple Form + Optics do the rest.

```slim
-# app/views/projects/_form.html.slim
-# locals: (resource:)

= simple_form_for resource do |f|
  .form-row
    = f.input :name
    = f.association :client, collection: policy_scope(Client)
  .form-row
    = f.input :status, collection: Project.statuses.keys, label_method: :titleize
  .form-row
    = f.input :description, as: :text, input_html: { rows: 4 }
  .form-row
    = f.input :start_date
    = f.input :end_date, hint: 'Optional'
  .form-row
    = f.input :billable, as: :boolean
```

When the form needs live recalculation or other behavior, wire a Stimulus controller through `data:` — still no `url:`:

```slim
= simple_form_for resource, data: { controller: 'turbo-fetch', turbo_fetch_url_value: } do |f|
  ...
```

### Conditional Rendering Patterns
```slim
-# Show/hide based on authorization
- if policy(@project).update?
  = link_to 'Edit', edit_project_path(@project), class: 'btn btn--primary'

-# Show/hide based on state
- if @time_entry.running?
  = button_to 'Stop', stop_time_entry_path(@time_entry), class: 'btn btn--danger'
- else
  = button_to 'Start', start_time_entry_path(@time_entry), class: 'btn btn--primary'

-# Conditional classes
.time-entry class=class_names(
  'time-entry--running': @time_entry.running?,
  'time-entry--billable': @time_entry.billable?,
  'time-entry--approved': @time_entry.approved?
)
  / ... content
```

## Simple Form Examples

### Search/Filter Form (form object as resource)

A filter is not a persisted record, so back it with a plain form object and pass *that* as the resource — no `url:`, no `:symbol`. The object's `model_name` resolves the route; the controller reads its attributes.

```ruby
# app/forms/time_entry_filter.rb
class TimeEntryFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :project_id, :integer
  attribute :date_from, :date
  attribute :date_to, :date
  attribute :status, :string
end
```

```slim
-# app/views/time_entries/_filters.html.slim
-# locals: (filter:)

= simple_form_for filter, data: { controller: 'auto-submit' } do |f|
  .form-row
    = f.input :project_id, collection: policy_scope(Project), label: 'Project'
    = f.input :status, collection: TimeEntry.statuses.keys, label_method: :titleize
  .form-row
    = f.input :date_from, label: 'From'
    = f.input :date_to, label: 'To'
```

### Bulk Action Form (form object as resource)

Bulk operations are also non-CRUD — wrap them in a form object whose route performs the action.

```slim
-# app/views/time_entries/index.html.slim

= simple_form_for @bulk_approval, html: { id: 'bulk-form' } do |f|
  .bulk-actions
    = f.button :submit, 'Approve Selected', class: 'btn btn--sm btn--primary'

table.time-entries-table
  thead
    tr
      th
        = check_box_tag 'select_all', '1', false,
          data: { controller: 'bulk-select', action: 'bulk-select#toggleAll' }
      th Description
      th Date

  tbody
    - @time_entries.each do |entry|
      tr
        td
          -# Checkboxes reference the form by id and nest under the form object
          = check_box_tag 'bulk_approval[entry_ids][]', entry.id, false,
            form: 'bulk-form',
            data: { bulk_select_target: 'checkbox' }
        td = entry.description
        td = entry.date
```

### Modal Form with External Submit
```slim
-# app/views/time_entries/_reject_modal.html.slim

.modal data-controller="modal"
  .modal__dialog
    .modal__header
      h2.modal__title Reject Time Entry
      button.modal__close type="button" data-action="modal#close" ×

    .modal__body
      -# A rejection isn't the time entry itself — back the custom action with a
      -# form object (e.g. TimeEntryRejection.new(time_entry:)) so there's no url:.
      = simple_form_for @rejection,
        html: { id: 'reject-form' },
        data: { turbo_frame: '_top' } do |f|

        = f.input :reason, as: :text, input_html: { rows: 3, required: true }

    .modal__footer
      = button_tag 'Cancel', 
        type: 'button',
        class: 'btn btn--outline',
        data: { action: 'modal#close' }
      
      = button_tag 'Reject Entry',
        type: 'submit',
        form: 'reject-form',
        class: 'btn btn--danger',
        data: { disable_with: 'Rejecting...' }
```

### Nested Attributes Form
```slim
-# app/views/invoices/_form.html.slim

= simple_form_for resource do |f|
  = f.association :client, collection: policy_scope(Client)
  = f.input :due_date

  .invoice-lines
    h3 Line Items
    
    .invoice-lines__list data-controller="nested-fields"
      = f.simple_fields_for :line_items do |line_form|
        .invoice-line data-nested_fields_target="item"
          = line_form.input :description, wrapper_html: { class: 'form__field--inline' }
          = line_form.input :quantity, wrapper_html: { class: 'form__field--narrow' }
          = line_form.input :rate, wrapper_html: { class: 'form__field--narrow' }
          = line_form.input :_destroy, as: :hidden
          
          = button_tag 'Remove',
            type: 'button',
            class: 'btn btn--sm btn--danger',
            data: { action: 'nested-fields#remove' }
      
      = button_tag 'Add Line Item',
        type: 'button',
        class: 'btn btn--sm btn--outline',
        data: { action: 'nested-fields#add' }

  .form__actions
    = link_to 'Cancel', :back, class: 'btn btn--outline'
    = f.submit 'Save Invoice', class: 'btn btn--primary'
```

## Stimulus Controller Examples

### Auto-Submit Controller
```javascript
// app/javascript/controllers/auto_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  submit() {
    clearTimeout(this.timeout)
    
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

Usage (the search is backed by a form object, so still no `url:`):
```slim
= simple_form_for @search, data: { controller: 'auto-submit' } do |f|
  = f.input :query,
    input_html: { data: { action: 'input->auto-submit#submit' } }
```

### Bulk Select Controller
```javascript
// app/javascript/controllers/bulk_select_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll"]

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })
  }

  updateSelectAll() {
    if (!this.hasSelectAllTarget) return
    
    const allChecked = this.checkboxTargets.every(cb => cb.checked)
    const someChecked = this.checkboxTargets.some(cb => cb.checked)
    
    this.selectAllTarget.checked = allChecked
    this.selectAllTarget.indeterminate = someChecked && !allChecked
  }
}
```

Usage:
```slim
.bulk-select data-controller="bulk-select"
  = check_box_tag 'select_all', '1', false,
    data: { 
      bulk_select_target: 'selectAll',
      action: 'bulk-select#toggleAll'
    }
  
  - @items.each do |item|
    = check_box_tag 'item_ids[]', item.id, false,
      data: { 
        bulk_select_target: 'checkbox',
        action: 'change->bulk-select#updateSelectAll'
      }
```

### Toggle Controller
```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static classes = ["hidden"]

  toggle() {
    this.contentTargets.forEach(content => {
      content.classList.toggle(this.hiddenClass)
    })
  }

  show() {
    this.contentTargets.forEach(content => {
      content.classList.remove(this.hiddenClass)
    })
  }

  hide() {
    this.contentTargets.forEach(content => {
      content.classList.add(this.hiddenClass)
    })
  }
}
```

Usage:
```slim
.expandable data-controller="toggle" data-toggle-hidden-class="hidden"
  button.expandable__trigger data-action="toggle#toggle" Toggle Details
  
  .expandable__content.hidden data-toggle-target="content"
    p Additional details here...
```

## Layout Patterns

### Page Header with Actions
```slim
-# app/views/projects/show.html.slim

.page-header
  .page-header__content
    h1.page-title = @project.name
    p.page-subtitle = @project.client.name
  
  .page-header__actions
    - if policy(@project).update?
      = link_to 'Edit', edit_project_path(@project), class: 'btn btn--outline'
    - if policy(@project).destroy?
      = button_to 'Delete', project_path(@project), 
        method: :delete,
        class: 'btn btn--danger',
        data: { turbo_confirm: 'Are you sure?' }
```

### Tabbed Navigation
```slim
-# app/views/projects/show.html.slim

nav.tabs
  = link_to 'Overview', project_path(@project), 
    class: class_names('tabs__tab', 'tabs__tab--active': current_page?(project_path(@project)))
  
  = link_to 'Time Entries', project_time_entries_path(@project),
    class: class_names('tabs__tab', 'tabs__tab--active': current_page?(project_time_entries_path(@project)))
  
  = link_to 'Team', project_team_path(@project),
    class: class_names('tabs__tab', 'tabs__tab--active': current_page?(project_team_path(@project)))
  
  = link_to 'Settings', edit_project_path(@project),
    class: class_names('tabs__tab', 'tabs__tab--active': current_page?(edit_project_path(@project)))
```

### Card Grid Layout
```slim
-# app/views/projects/index.html.slim

.projects
  .projects__header
    h1.page-title Projects
    = link_to 'New Project', new_project_path, class: 'btn btn--primary'

  .card-grid
    - @projects.each do |project|
      = render 'project_card', project: project
```

```slim
-# app/views/projects/_project_card.html.slim
-# locals: (project:)

.card
  .card__header
    h3.card__title = link_to project.name, project_path(project)
    = render 'shared/status_badge', status: project.status
  
  .card__body
    p.card__client = project.client.name
    p.card__date = "Created #{time_ago_in_words(project.created_at)} ago"
  
  .card__footer
    .card__stats
      span.stat
        strong = project.time_entries_count
        |  entries
      span.stat
        strong = number_to_currency(project.total_revenue)
        |  revenue
```
