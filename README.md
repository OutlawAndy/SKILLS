# outlaw-skills

A multi-harness skill pipeline & my personal customization layer atop the growing pile of excellent open-source skills that I use & appreciate, ***but also disagree with at one level or another*** 😉

## Skill Diff

Enables comparisons of the upstream version of forked skills in this repo.

e.g. /work
![work](./assets/skill-diff-example.png)

## Quick start

The `dist` directory already contains prebuilt plugins for all supported targets. Though they are not available on any official marketplace currently.  So you'll need to clone this repo and then run `bin/install --target=<DESIRED-TARGET>` to setup global (user level) symlinks in the appropriate location.

```sh
bin/build                     # builds dist/claude/ and dist/copilot/
bin/install                   # installs the Claude Code Rails PreToolUse hook
bin/install --target=copilot  # symlinks the Copilot dist into VS Code
```

Wire the built distributions into your tools:

- **Claude Code:** in any session, run `/plugin marketplace add /absolute/path/to/outlaw-skills` then `/plugin install outlaw-skills@outlaw-skills`, and restart.
- **GitHub Copilot (VS Code):** `bin/install --target=copilot` symlinks each skill directory into `$HOME/.copilot/skills/` and `*.agent.md` into `$HOME/.copilot/agents/`. Copilot reads the open Agent Skills (`SKILL.md`) format natively, so skills are copied verbatim — no conversion — and auto-activate by description (re-run after `bin/build` is unnecessary — symlinks flow through). Reload the VS Code window afterward.

Full install details, target filtering, and the verification checklist live in [AGENTS.md](AGENTS.md).

## Releasing & updating

Cut a release with `bin/release` (bumps `VERSION`, syncs the marketplace manifest, rebuilds `dist/`, runs tests, tags `vX.Y.Z`, pushes, and creates a GitHub release):

```sh
bin/release patch        # or: minor | major
bin/release --dry-run    # preview without changing anything
```

Claude Code caches the plugin by version, so a bare `bin/build` rebuild won't refresh a running install — you must bump the version with `bin/release`, then run `/plugin update outlaw-skills@outlaw-skills` (or relaunch). See [AGENTS.md](AGENTS.md#release) for preconditions and flags.

## Running the tests

The test suite is plain Minitest with no Gemfile or Rakefile:

```sh
minitest
```

Tests cover the build pipeline, target filtering, the Copilot target, and build idempotency.

## License

MIT. See [LICENSE](LICENSE).
