# outlaw-skills

A multi-harness skill pipeline & my personal customization layer atop the growing pile of excellent open-source skills that I use & appreciate, ***but also disagree with at one level or another*** 😉

## Quick start

The `dist` directory already contains prebuilt plugins for all supported targets. Though they are not available on any official marketplace currently.  So you'll need to clone this repo and then run `bin/install --target=<DESIRED-TARGET>` to setup global (user level) symlinks in the appropriate location.

```sh
bin/build                     # builds dist/claude/ and dist/copilot/
bin/install                   # installs the Claude Code Rails PreToolUse hook
bin/install --target=copilot  # symlinks the Copilot dist into VS Code
```

Wire the built distributions into your tools:

- **Claude Code:** in any session, run `/plugin marketplace add /absolute/path/to/outlaw-skills` then `/plugin install outlaw-skills@outlaw-skills`, and restart.
- **GitHub Copilot (VS Code):** `bin/install --target=copilot` symlinks `*.prompt.md` into `$HOME/Library/Application Support/Code/User/prompts/` and `*.agent.md` into `$HOME/.copilot/agents/` (re-run after `bin/build` is unnecessary — symlinks flow through). Reload the VS Code window afterward.

Full install details, target filtering, and the verification checklist live in [AGENTS.md](AGENTS.md).

## Running the tests

The test suite is plain Minitest with no Gemfile or Rakefile:

```sh
minitest
```

Tests cover the build pipeline, target filtering, the Copilot target, and build idempotency.

## License

MIT. See [LICENSE](LICENSE).
