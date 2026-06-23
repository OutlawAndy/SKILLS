# outlaw-skills

A personal cross-tool layer of AI coding-agent skills and reviewer personas. Canonical source lives in `src/`; `bin/build` transpiles it into a single plugin distribution under `dist/plugin/` that both Claude Code and GitHub Copilot CLI consume natively.

## Project Layout

```text
outlaw-skills/
  src/                 # canonical, tool-agnostic source of truth
    skills/            # skill directories with SKILL.md + optional assets
    agents/            # reviewer/persona agents as plain markdown
    hooks/             # plugin hooks: hooks.json + scripts (e.g. rails-gate.sh)
  bin/
    build              # Ruby script that produces dist/plugin/
    release            # Ruby script that bumps the version, rebuilds, tags, and publishes a release
  lib/outlaw_skills/   # build logic
  dist/                # generated plugin distribution (checked in)
    plugin/            # the single tree: .claude-plugin/plugin.json, skills/,
                       #   agents/, hooks/, AGENTS.md, LICENSE — read natively by
                       #   both Claude Code and Copilot CLI
  .claude-plugin/marketplace.json   # Claude marketplace, source -> ./dist/plugin
  .github/plugin/marketplace.json   # Copilot marketplace, source -> ./dist/plugin
  VERSION              # single source of version truth (semver; bump via bin/release)
  LICENSE              # MIT
  AGENTS.md            # this file
```

`docs/` paths in tooling and plans resolve to `$HOME/compound-engineering/outlaw-skills/docs/`, not a `docs/` directory inside this tree. Project-external by convention.

## Build

```sh
bin/build              # builds the single dist/plugin/ tree
```

The build is idempotent — running it twice on unchanged source produces byte-identical output. Skills, agents, and the `hooks/` directory are copied verbatim; no per-tool conversion is performed. Both Claude Code and Copilot CLI read the same layout (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, `agents/*.agent.md`, `hooks/hooks.json`).

## Release

`bin/release` is the only sanctioned way to change the version. It bumps `VERSION`, syncs the version fields in **both** marketplace manifests (`.claude-plugin/marketplace.json` and `.github/plugin/marketplace.json`), rebuilds `dist/plugin/` (which re-stamps `dist/plugin/.claude-plugin/plugin.json`), runs the test suite, commits and tags `vX.Y.Z`, pushes, and creates a GitHub release.

```sh
bin/release patch            # 0.1.0 -> 0.1.1 (default level)
bin/release minor            # 0.1.0 -> 0.2.0
bin/release major            # 0.1.0 -> 1.0.0
bin/release --dry-run        # preview the bump + release without changing anything
bin/release --no-gh-release  # commit/tag/push but skip the GitHub release
bin/release --override       # allow releasing from a branch other than main
```

Preconditions and behavior:

- Refuses to run with uncommitted **tracked** changes (untracked scratch like `ref/` is ignored) — commit or stash first.
- Refuses to run off `main` unless `--override` is passed, and aborts if the target `vX.Y.Z` tag already exists.
- If the test suite fails (or collects zero tests), the bump is rolled back so the tree is left clean and the command is re-runnable.
- If `gh` is missing or unauthenticated, the local commit/tag/push still complete and the exact `gh release create ...` command is printed to run by hand.
- Do not hand-edit `VERSION` or the marketplace version fields — `bin/release` keeps every version location (VERSION, both marketplace manifests, and the built `plugin.json`) in sync and a test asserts they agree.

**Why a version bump is required:** Claude Code caches the installed plugin by version at `~/.claude/plugins/cache/outlaw-skills/outlaw-skills/<version>/` and serves that cached copy. Rebuilding `dist/` in place does **not** refresh a running install while the version is unchanged — the cache is keyed on the version string (alongside the recorded commit SHA). Bumping the version is what forces a re-copy. Copilot CLI behaves the same way via its own plugin cache.

## Install

After building, both tools install from the same `dist/plugin/` tree via their own marketplace manifest.

### Claude Code

The repo ships a local marketplace manifest at `.claude-plugin/marketplace.json` that points at `dist/plugin/`. From any Claude Code session:

```text
/plugin marketplace add /Users/andy/CODE/outlaw-skills
/plugin install outlaw-skills@outlaw-skills
```

After the install, restart the session (or run `/plugin` to confirm). Upstream plugins (compound-engineering, layered-rails, ruby-lsp, microsoft-docs) remain installed alongside without modification — coexistence is the intentional posture.

To ship changes: run `bin/release <level>` (see [Release](#release)), then in Claude Code run `/plugin update outlaw-skills@outlaw-skills` or relaunch the session. A bare `bin/build` rebuild does **not** refresh a running install — Claude Code serves a version-keyed cached copy and only re-copies when the version changes, which is exactly what `bin/release` bumps.

### GitHub Copilot CLI

`dist/plugin/` is a valid Copilot CLI plugin: Copilot reads `.claude-plugin/plugin.json` (last in its manifest search order), `skills/`, and `agents/` natively. The repo ships a Copilot-discoverable marketplace at `.github/plugin/marketplace.json`, also pointing at `dist/plugin/`. Install via the Copilot CLI:

```bash
copilot plugin marketplace add /Users/andy/CODE/outlaw-skills
copilot plugin install outlaw-skills@outlaw-skills
```

`copilot plugin list` confirms it loaded; skills and agents come from the one tree. To update after a release: `copilot plugin update outlaw-skills`.

**Skills** ship as the open Agent Skills (`SKILL.md`) format Copilot reads natively — bundled scripts and resources intact, auto-activated by description (and invocable as `/<name>`). **Agents** are copied verbatim with Claude-native `tools:` (`Read, Grep, Glob, Bash`); Copilot maps these case-insensitively (`Read`→`read`, `Bash`→`execute`) and a non-empty `tools:` list *restricts* rather than grants, so the read-only reviewer personas stay read-only there.

**Hook caveat:** the plugin ships a Claude-format `hooks/hooks.json` (the rails-gate `PreToolUse` gate, running `hooks/rails-gate.sh`). It is effective in Claude Code. Copilot loads the plugin cleanly with it present, but Copilot's plugin-level `preToolUse` support differs (camelCase events, a different entry shape, and an open upstream gap), so the gate is Claude-only in practice.

## Verification Checklist

Run after each install to confirm skills and agents are live.

**Claude Code:**

- [ ] `/find-skills`, `/controller-patterns`, `/ruby-version`, `/brave-breakdown`, `/routing-patterns`, `/skill-audit`, `/md-audit` each invoke successfully
- [ ] `dhh-rails-reviewer` and `kieran-rails-reviewer` agents are dispatchable
- [ ] `claude plugin validate ./dist/plugin` passes

**GitHub Copilot CLI:**

- [ ] `copilot plugin install outlaw-skills@outlaw-skills` reports the skills installed
- [ ] `copilot plugin list` shows `outlaw-skills@outlaw-skills`
- [ ] a skill's bundled resource is present in the installed tree (e.g. `ruby-version/scripts/check.sh`)
- [ ] `dhh-rails-reviewer` and `kieran-rails-reviewer` agents are selectable

**Coexistence:**

- [ ] After Claude install, `compound-engineering`, `layered-rails`, `ruby-lsp`, `microsoft-docs` still load and function

## Canonical Source Conventions

Skill files follow the Anthropic skill spec: YAML frontmatter with `name:` and `description:`, plus optional `metadata:` and `license:`. Agent persona files follow the Claude Code agent spec: `name:`, `description:`, `model:`, `tools:`, `color:`.

### Single distribution

There is one distribution (`dist/plugin/`) consumed by both tools, so there is no per-target filtering — every skill and agent ships to both. This is possible because both tools read the same open plugin layout and tolerate each other's extra fields (Claude ignores unrecognized manifest fields; Copilot accepts the `.claude-plugin/plugin.json` location and Claude-style agent tool names). The only tool-specific edge is the hook (see the Copilot hook caveat above).

## Status

Solo personal tooling, MIT-licensed. Designed to be public-release-ready, but not currently distributed.

The plan that collapsed the two former distributions (`dist/claude/` + `dist/copilot/`) into the single `dist/plugin/` tree lives in `docs/plans/2026-06-22-001-refactor-collapse-plugin-dist-plan.md`.
