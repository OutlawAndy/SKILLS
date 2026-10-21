# Sourced by the rails hooks. Maps a project-relative path to the Rails
# skill that governs it, printing "<skill> <category>" or nothing.
#
# Source of truth for trigger patterns: this file. Edit it and the Phase 3
# table in src/skills/work/SKILL.md together.

rails_skill_for() {
  case "$1" in
    app/controllers/*)                                                 echo "controller-patterns controller" ;;
    config/routes.rb|config/routes/*)                                  echo "routing-patterns routes" ;;
    app/models/*|app/services/*|app/policies/*|app/forms/*|app/queries/*) echo "layered-rails model-service-policy" ;;
    app/views/*|app/components/*)                                      echo "frontend-patterns view-component" ;;
  esac
}
