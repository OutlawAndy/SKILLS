# outlaw-skills

A personal cross-tool layer of AI coding-agent skills and reviewer personas, building into both Claude Code and GitHub Copilot from one canonical source.

## Quick start

Clone, then build the per-tool distributions and install:

```sh
bin/build                # builds dist/claude/ and dist/copilot/
bin/install              # installs the Claude Code Rails PreToolUse hook
```

Wire the built distributions into your tools:

- **Claude Code:** in any session, run `/plugin marketplace add /absolute/path/to/outlaw-skills` then `/plugin install outlaw-skills@outlaw-skills`, and restart.
- **GitHub Copilot (VS Code):** symlink `dist/copilot/.github/prompts/*.prompt.md` and `dist/copilot/.github/chatmodes/*.chatmode.md` into your VS Code user profile (`$HOME/Library/Application Support/Code/User/{prompts,chatmodes}/`), then reload the window.

Full install details, target filtering, and the verification checklist live in [AGENTS.md](AGENTS.md).

## Running the tests

The test suite is plain Minitest with no Gemfile or Rakefile:

```sh
minitest
```

Tests cover the build pipeline, target filtering, the Copilot target, and build idempotency.

## License

MIT. See [LICENSE](LICENSE).
