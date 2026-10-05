# outlaw-skills

A personal cross-tool layer of AI coding-agent skills and reviewer personas. Canonical source lives in `src/`; `bin/build` transpiles it into the main `rails` plugin under `dist/rails/`, plus one standalone plugin per `src/plugins/<name>/` under `dist/<name>/` (currently `driving`), all consumed natively by both Claude Code and GitHub Copilot CLI.

## Project Layout

```text
outlaw-skills/
  src/                 # canonical, tool-agnostic source of truth
    skills/            # skill directories with SKILL.md + optional assets
    agents/            # reviewer/persona agents as plain markdown
    hooks/             # plugin hooks: hooks.json + scripts (e.g. rails-gate.sh)
    plugins/<name>/    # standalone plugins (skills/, hooks/), built to dist/<name>/
  bin/
    build              # Ruby script that produces dist/<name>/ for each plugin
    release            # Ruby script that bumps the version, rebuilds, tags, and publishes a release
  lib/outlaw_skills/   # build logic
  dist/                # generated plugin distribution (checked in)
    rails/             # the main tree: .claude-plugin/plugin.json, skills/,
                       #   agents/, hooks/, AGENTS.md, LICENSE — read natively by
                       #   both Claude Code and Copilot CLI
    driving/           # standalone driving plugin: skill + Stop hook
  .claude-plugin/marketplace.json   # Claude marketplace `outlawandy`: rails -> ./dist/rails, driving -> ./dist/driving
  .github/plugin/marketplace.json   # Copilot marketplace `outlawandy`: rails -> ./dist/rails
  VERSION              # single source of version truth (semver; bump via bin/release)
  LICENSE              # MIT
  AGENTS.md            # this file
```

`docs/` paths in tooling and plans resolve to `$HOME/compound-engineering/outlaw-skills/docs/`, not a `docs/` directory inside this tree. Project-external by convention.

## Release Preconditions and behavior

- Refuses to run with uncommitted **tracked** changes (untracked scratch like `ref/` is ignored) — commit or stash first.
- Refuses to run off `main` unless `--override` is passed, and aborts if the target `vX.Y.Z` tag already exists.
- If the test suite fails (or collects zero tests), the bump is rolled back so the tree is left clean and the command is re-runnable.
- If `gh` is missing or unauthenticated, the local commit/tag/push still complete and the exact `gh release create ...` command is printed to run by hand.
- Do not hand-edit `VERSION` or the marketplace version fields — `bin/release` keeps every version location (VERSION, both marketplace manifests, and the built `plugin.json`) in sync and a test asserts they agree.

**Why a version bump is required:** Claude Code caches the installed plugin by version at `~/.claude/plugins/cache/outlawandy/<plugin>/<version>/` and serves that cached copy. Rebuilding `dist/` in place does **not** refresh a running install while the version is unchanged — the cache is keyed on the version string (alongside the recorded commit SHA). Bumping the version is what forces a re-copy. Copilot CLI behaves the same way via its own plugin cache.

**Skills** ship as the open Agent Skills (`SKILL.md`) format Copilot reads natively — bundled scripts and resources intact, auto-activated by description (and invocable as `/<name>`). **Agents** are copied verbatim with Claude-native `tools:` (`Read, Grep, Glob, Bash`); Copilot maps these case-insensitively (`Read`→`read`, `Bash`→`execute`) and a non-empty `tools:` list *restricts* rather than grants, so the read-only reviewer personas stay read-only there.

**Hook caveat:** the main plugin ships a Claude-format `hooks/hooks.json` with the rails-gate `PreToolUse` gate (`hooks/rails-gate.sh`); the `driving` plugin ships its own with the `Stop` hook (`hooks/driving-speak.sh`, inert unless `~/.claude/driving-mode` holds the current session id). Both are effective in Claude Code; `driving` is listed in the Claude marketplace only. Copilot loads the plugin cleanly with it present, but Copilot's plugin-level `preToolUse` support differs (camelCase events, a different entry shape, and an open upstream gap), so the gate is Claude-only in practice.

## Verification Checklist

Run after each install to confirm skills and agents are live.

**Claude Code:**

- [ ] `/find-skills`, `/controller-patterns`, `/ruby-version`, `/brave-breakdown`, `/routing-patterns`, `/skill-audit`, `/md-audit`, `/driving` each invoke successfully
- [ ] `/driving` speaks a response, `/driving off` restores silence
- [ ] `dhh-rails-reviewer` and `kieran-rails-reviewer` agents are dispatchable
- [ ] `claude plugin validate ./dist/rails` and `claude plugin validate ./dist/driving` pass

**GitHub Copilot CLI:**

- [ ] `copilot plugin install rails@outlawandy` reports the skills installed
- [ ] `copilot plugin list` shows `rails@outlawandy`
- [ ] a skill's bundled resource is present in the installed tree (e.g. `ruby-version/scripts/check.sh`)
- [ ] `dhh-rails-reviewer` and `kieran-rails-reviewer` agents are selectable

**Coexistence:**

- [ ] After Claude install, `compound-engineering`, `layered-rails`, `ruby-lsp`, `microsoft-docs` still load and function

## Canonical Source Conventions

Skill files follow the Anthropic skill spec: YAML frontmatter with `name:` and `description:`, plus optional `metadata:` and `license:`. Agent persona files follow the Claude Code agent spec: `name:`, `description:`, `model:`, `tools:`, `color:`.

### One distribution per plugin

The `rails` distribution (`dist/rails/`) is consumed by both tools, so there is no per-target filtering — every skill and agent ships to both. This is possible because both tools read the same open plugin layout and tolerate each other's extra fields (Claude ignores unrecognized manifest fields; Copilot accepts the `.claude-plugin/plugin.json` location and Claude-style agent tool names). The only tool-specific edge is the hook (see the Copilot hook caveat above).
