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

After building, install the appropriate `dist/` into your tool:

- **Claude Code:** install `dist/claude/` per Claude Code's local plugin mechanism (verified install steps appear at the bottom of this file once U7 of the original plan has been executed).
- **GitHub Copilot:** install `dist/copilot/` per `docs/research/copilot-plugin-format.md`.

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
