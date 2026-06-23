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

## Release Preconditions and behavior

- Refuses to run with uncommitted **tracked** changes (untracked scratch like `ref/` is ignored) — commit or stash first.
- Refuses to run off `main` unless `--override` is passed, and aborts if the target `vX.Y.Z` tag already exists.
- If the test suite fails (or collects zero tests), the bump is rolled back so the tree is left clean and the command is re-runnable.
- If `gh` is missing or unauthenticated, the local commit/tag/push still complete and the exact `gh release create ...` command is printed to run by hand.
- Do not hand-edit `VERSION` or the marketplace version fields — `bin/release` keeps every version location (VERSION, both marketplace manifests, and the built `plugin.json`) in sync and a test asserts they agree.

**Why a version bump is required:** Claude Code caches the installed plugin by version at `~/.claude/plugins/cache/outlaw-skills/outlaw-skills/<version>/` and serves that cached copy. Rebuilding `dist/` in place does **not** refresh a running install while the version is unchanged — the cache is keyed on the version string (alongside the recorded commit SHA). Bumping the version is what forces a re-copy. Copilot CLI behaves the same way via its own plugin cache.

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
