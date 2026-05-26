# outlaw-skills

A personal cross-tool layer of AI coding-agent skills and reviewer personas. Canonical source lives in `src/`; `bin/build` transpiles it into tool-specific plugin distributions under `dist/` for both Claude Code and GitHub Copilot.

## Project Layout

```
outlaw-skills/
  src/                 # canonical, tool-agnostic source of truth
    skills/            # skill directories with SKILL.md + optional assets
    agents/            # reviewer/persona agents as plain markdown
  bin/
    build              # Ruby script that produces dist/*
  lib/outlaw_skills/   # build logic
  dist/                # generated plugin distributions (checked in)
    claude/            # Claude Code plugin layout
    copilot/           # Copilot plugin layout (see docs/research/copilot-plugin-format.md)
  VERSION              # single source of version truth (semver, currently 0.1.0)
  LICENSE              # MIT
  AGENTS.md            # this file
```

`docs/` paths in tooling and plans resolve to `$HOME/compound-engineering/outlaw-skills/docs/`, not a `docs/` directory inside this tree. Project-external by convention.

## Build

```
bin/build              # builds both targets (default)
bin/build claude       # builds dist/claude/ only
bin/build copilot      # builds dist/copilot/ only
```

The build is idempotent — running it twice on unchanged source produces byte-identical output.

## Install

After building, install the appropriate `dist/` into your tool.

### Claude Code

The repo ships a local marketplace manifest at `.claude-plugin/marketplace.json` that points at `dist/claude/`. From any Claude Code session:

```
/plugin marketplace add /Users/andy/CODE/outlaw-skills
/plugin install outlaw-skills@outlaw-skills
```

After the install, restart the session (or run `/plugin` to confirm). Upstream plugins (compound-engineering, layered-rails, ruby-lsp, microsoft-docs) remain installed alongside without modification — coexistence is the intentional MVP posture.

To update after rebuilding: `bin/build claude` regenerates `dist/claude/` in place; Claude Code re-reads the plugin contents on session start. If skills or agents don't refresh, run `/plugin marketplace update outlaw-skills` and reinstall.

### GitHub Copilot

`dist/copilot/` is a `.github/` directory layout (instruction file, prompts, chatmodes). VS Code Copilot Chat auto-discovers it when present in the workspace.

**Per-workspace install** (single project):

```
ln -s /Users/andy/CODE/outlaw-skills/dist/copilot/.github /path/to/project/.github
```

(Or copy if the project already has its own `.github/`.)

**User-profile install** (global): copy the contents of `dist/copilot/.github/prompts/` and `dist/copilot/.github/chatmodes/` into your VS Code user profile's prompt/chatmode locations. See `docs/research/copilot-plugin-format.md` §"User-level install paths" for current VS Code conventions.

Reload the VS Code window after install for Copilot Chat to pick up new files.

## Verification Checklist

Run after each install to confirm the MVP success criteria (AE2, AE3, AE4):

**Claude Code (AE2):**

- [ ] `/find-skills` invokes successfully
- [ ] `/controller-patterns` invokes successfully
- [ ] `/ruby-version` invokes successfully
- [ ] `/brave-breakdown` invokes successfully
- [ ] `/routing-patterns` invokes successfully
- [ ] `dhh-rails-reviewer` agent is dispatchable
- [ ] `kieran-rails-reviewer` agent is dispatchable

**GitHub Copilot (AE3):**

- [ ] `/find-skills` prompt is discoverable
- [ ] `/controller-patterns` prompt is discoverable
- [ ] `/ruby-version` prompt is discoverable
- [ ] `/brave-breakdown` prompt is discoverable
- [ ] `/routing-patterns` prompt is discoverable
- [ ] `dhh-rails-reviewer` chatmode is selectable
- [ ] `kieran-rails-reviewer` chatmode is selectable

**Coexistence (AE4):**

- [ ] After Claude install, `compound-engineering`, `layered-rails`, `ruby-lsp`, `microsoft-docs` still load and function
- [ ] Any command-name collisions are listed here:
  - _(none observed, or list them — e.g., `/foo` exists in both X and outlaw-skills)_

## Canonical Source Conventions

Skill files follow the Anthropic skill spec: YAML frontmatter with `name:` and `description:`, plus optional `metadata:` and `license:`. Agent persona files follow the Claude Code agent spec: `name:`, `description:`, `model:`, `tools:`, `color:`.

### Target filtering

Skill and agent frontmatter may include an optional `targets:` field controlling which tool distributions include the item. Absent means both:

```yaml
---
name: my-skill
description: ...
targets: [claude, copilot]    # default when omitted
---
```

Use `targets: [claude]` for content that relies on Claude-specific capabilities with no Copilot analogue (e.g., Claude Code hooks, certain `tools:` declarations). See `docs/research/copilot-plugin-format.md` for the list of features that do not map.

## Status

Solo personal tooling, MIT-licensed. Designed to be public-release-ready, but not currently distributed.

The implementation plan that established this structure lives in `docs/plans/2026-05-24-001-feat-cross-tool-entrypoint-and-build-plan.md`.
