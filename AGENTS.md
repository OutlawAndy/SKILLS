# outlaw-skills

A personal cross-tool layer of AI coding-agent skills and reviewer personas. Canonical source lives in `src/`; `bin/build` transpiles it into tool-specific plugin distributions under `dist/` for both Claude Code and GitHub Copilot.

## Project Layout

```text
outlaw-skills/
  src/                 # canonical, tool-agnostic source of truth
    skills/            # skill directories with SKILL.md + optional assets
    agents/            # reviewer/persona agents as plain markdown
  bin/
    build              # Ruby script that produces dist/*
  lib/outlaw_skills/   # build logic
  dist/                # generated plugin distributions (checked in)
    claude/            # Claude Code plugin layout
    copilot/           # Copilot layout: .github/skills/ (native SKILL.md dirs), agents/, copilot-instructions.md
  VERSION              # single source of version truth (semver, currently 0.1.0)
  LICENSE              # MIT
  AGENTS.md            # this file
```

`docs/` paths in tooling and plans resolve to `$HOME/compound-engineering/outlaw-skills/docs/`, not a `docs/` directory inside this tree. Project-external by convention.

## Build

```sh
bin/build              # builds both targets (default)
bin/build claude       # builds dist/claude/ only
bin/build copilot      # builds dist/copilot/ only
```

The build is idempotent — running it twice on unchanged source produces byte-identical output.

## Install

After building, install the appropriate `dist/` into your tool.

### Claude Code

The repo ships a local marketplace manifest at `.claude-plugin/marketplace.json` that points at `dist/claude/`. From any Claude Code session:

```text
/plugin marketplace add /Users/andy/CODE/outlaw-skills
/plugin install outlaw-skills@outlaw-skills
```

After the install, restart the session (or run `/plugin` to confirm). Upstream plugins (compound-engineering, layered-rails, ruby-lsp, microsoft-docs) remain installed alongside without modification — coexistence is the intentional MVP posture.

To update after rebuilding: `bin/build claude` regenerates `dist/claude/` in place; Claude Code re-reads the plugin contents on session start. If skills or agents don't refresh, run `/plugin marketplace update outlaw-skills` and reinstall.

### GitHub Copilot

`dist/copilot/` is a `.github/` directory layout: native skill directories under `.github/skills/`, custom agents under `.github/agents/`, and an always-on `.github/copilot-instructions.md` digest. GitHub Copilot added native support for the open Agent Skills (`SKILL.md`) format on 2025-12-18, so skills are copied verbatim — bundled scripts and resources intact — and Copilot **auto-activates them by description** (it also exposes each as a `/<name>` command). No conversion is performed; the layout is identical to the Claude target's skill copy.

Copilot scans `SKILL.md` directories from project locations (`.github/skills/`, `.claude/skills/`, `.agents/skills/`) and personal locations (`~/.copilot/skills/`, `~/.claude/skills/`). Native scanning is confirmed on stable VS Code (Jan 2026), VS Code Insiders, and the Copilot coding agent; github.com web chat, the JetBrains plugin, and Copilot CLI are unconfirmed.

> **Note:** custom chat modes (`.chatmode.md` / `.github/chatmodes/`) were renamed to custom agents (`.agent.md` / `.github/agents/`) in VS Code 1.106. The build emits the current surface; profile paths below are for current VS Code on macOS and vary by OS/version (`chat.agentSkillsLocations`, `chat.agentFilesLocations`).

**Global install** (recommended): `bin/install --target=copilot`. It symlinks the built dist into your personal Copilot directory so later `bin/build copilot` runs flow through automatically:

```bash
bin/build                      # ensure dist/copilot/ is current
bin/install --target=copilot   # symlink skills + agents into ~/.copilot/
```

This links `dist/copilot/.github/skills/*` → `~/.copilot/skills/` and `dist/copilot/.github/agents/*.agent.md` → `~/.copilot/agents/`. The install is idempotent and `--uninstall` removes only the symlinks that point back into this repo — and additionally sweeps any stale `*.prompt.md` symlinks left in `~/Library/Application Support/Code/User/prompts/` by versions that predated native skill support, so upgrading does not orphan links. Reload the VS Code window (`Cmd+Shift+P` → "Reload Window") and the skills + agents are globally available in any Copilot Chat session.

The top-level `copilot-instructions.md` in `dist/copilot/.github/` is an always-on human-readable index (skill/agent names) for workspace installs — it does not need to be copied to the personal directory.

**Per-workspace install** (single project, alternative):

```bash
ln -s /Users/andy/CODE/outlaw-skills/dist/copilot/.github /path/to/project/.github
```

(Only if the project has no existing `.github/`.)

## Verification Checklist

Run after each install to confirm the MVP success criteria (AE2, AE3, AE4):

**Claude Code (AE2):**

- [ ] `/find-skills` invokes successfully
- [ ] `/controller-patterns` invokes successfully
- [ ] `/ruby-version` invokes successfully
- [ ] `/brave-breakdown` invokes successfully
- [ ] `/routing-patterns` invokes successfully
- [ ] `/skill-audit` invokes successfully
- [ ] `dhh-rails-reviewer` agent is dispatchable
- [ ] `kieran-rails-reviewer` agent is dispatchable

**GitHub Copilot (AE3):**

- [ ] `find-skills` skill is listed / auto-activates (also invocable as `/find-skills`)
- [ ] `controller-patterns` skill is listed / auto-activates
- [ ] `ruby-version` skill is listed / auto-activates
- [ ] `brave-breakdown` skill is listed / auto-activates
- [ ] `routing-patterns` skill is listed / auto-activates
- [ ] `skill-audit` skill is listed / auto-activates
- [ ] a skill's bundled resource loads (e.g. `ruby-version/scripts/check.sh` is present in the linked dir)
- [ ] `dhh-rails-reviewer` agent is selectable
- [ ] `kieran-rails-reviewer` agent is selectable

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

Use `targets: [claude]` for content that relies on Claude-specific capabilities with no Copilot analogue (e.g., Claude Code hooks). Since Copilot reads `SKILL.md` natively, most skills need no filtering — the same directory serves both tools. See `docs/research/copilot-plugin-format.md` for the agent-mapping details and the remaining Claude-only features.

## Status

Solo personal tooling, MIT-licensed. Designed to be public-release-ready, but not currently distributed.

The implementation plan that established this structure lives in `docs/plans/2026-05-24-001-feat-cross-tool-entrypoint-and-build-plan.md`.
