# outlaw-skills

A multi-harness skill pipeline & my personal customization layer atop the growing pile of excellent open-source skills that I use & appreciate, ***but also disagree with at one level or another*** 😉

## Quick start

- **Claude Code:**
  ```sh
  claude plugin marketplace add OutlawAndy/SKILLS
  claude plugin install outlaw-skills@outlaw-skills
  claude plugin install driving@outlaw-skills   # hands-free mode, also installable on its own
  ```
- **GitHub Copilot:**
  ```sh
  copilot plugin marketplace add OutlawAndy/SKILLS
  copilot plugin install outlaw-skills@outlaw-skills
  ```

## What is Included

### RAILS WORKFLOW CLUSTER

    user: "plan this"              user: "work this"
          │                              │
          ▼                              ▼
     ┌─────────┐                    ┌─────────┐
     │  plan   │                    │  work   │
     └────┬────┘                    └────┬────┘
          │                              │
          │   loads first ┌──────────────┤ loads first
          │               ▼              │
          │       ┌───────────────┐      │
          ├──────▶│ rails-context │◀─────┤
          │       │   (primer)    │      │
          │       └───────┬───────┘      │     ┌── also cited
          │               │ dispatch triggers  │   standalone
          │               ▼              │     ▼
          │   ┌───────────────────────────────────────┐
          ├──▶│  controller-patterns                  │
          ├──▶│  routing-patterns                     │
          ├──▶│  frontend-patterns                    │
          │   │  [layered-rails]      (external)      │
          │   │  [ce-dhh-rails-style] (external)      │
          │   │  ruby-version  (when version unsure)  │
          │   └───────────────────────────────────────┘
          │
          │ delegates core engine to
          ▼
      [ce-plan]       ◀╌╌ plan "replaces" generic ce-plan
      [ce-work]       ◀╌╌ work "replaces" generic ce-work
      [ce-brainstorm] ◀╌╌ work hands off for vague scope

### SKILL-MAINTENANCE CLUSTER

    user: "vet this skill"
         │
         ▼
      ┌─────┐
      │ vet │                  ◀╌╌ opinion vetting   (Does this do what I want?)
      └──┬──┘
         │ hands off to
         ▼ (coherence cleanup)
      ┌───────┐
    ┌─│ audit │                ◀╌╌ semantic pass     (Does it do so efficiently?)
    │ └──┬────┘
    │    │ hands off to
    │    ▼ (mechanical cleanup)
    │ ┌──────┐
    ├─│ tidy │                 ◀╌╌ syntactic tidy    (Is the content formatted correctly?)
    │ └──────┘
    │
    │ both reference
    ▼ (as sibling tools)
    ┌────────────┐
    │ skill-diff │             ◀╌╌ local vs. upstream drift
    └────────────┘

### STANDALONE

  find-skills      — no internal deps (discovery/install helper)
  brave-breakdown  — no internal deps (BRAVE ticket breakdown)
  driving          — hands-free mode, its own `driving` plugin (skill + Stop hook, see below)

### DRIVING MODE

    /driving                        /driving off
        │                                │
        ▼                                ▼
   session id → flag file         rm ~/.claude/driving-mode
        │                                │
        │  flag read at runtime by       │
        ▼                                ▼
    ┌──────────────────────────────────────────┐
    │  Stop hook: hooks/driving-speak.sh       │
    │  no flag, or another session's → silent  │
    │  this session's flag → say(`Spoken:`)    │
    └──────────────────────────────────────────┘

`/driving` is for working while you can't look at the screen. It ships as its own
`driving` plugin in this marketplace, so it can be installed without the rest of
the suite. It does two
things that are deliberately separate:

- **The hook speaks.** A `Stop` hook fires after every response and reads the
  message's `Spoken:` line through macOS `say`. Mechanical — the model can't
  forget to speak, because it isn't the one calling `say`.
- **The skill decides what's worth hearing.** It tells the model to write that
  `Spoken:` line for the ear (no paths, no code, short sentences), and to
  present decisions **one at a time**, waiting for explicit approval between
  each instead of dumping a list you can't read.

Only the `Spoken:` line is read aloud, never the whole message — raw markdown
is unlistenable, and the point is that the audio was composed to be heard. A
message with no `Spoken:` line gets a short nudge spoken instead, because
silence is indistinguishable from the mode being off when you're watching the
road.

Tuning, if the default voice is wrong for the car:

| Variable | Default | Notes |
| --- | --- | --- |
| `OUTLAW_DRIVING_RATE` | `175` | words per minute |
| `OUTLAW_DRIVING_VOICE` | system voice | any name from `say -v '?'` |
| `OUTLAW_DRIVING_FLAG` | `~/.claude/driving-mode` | flag file path |

Caveats worth knowing: the flag holds the id of the session that turned the mode
on, so only that session speaks and a forgotten flag goes quiet with it; `say` is macOS-only and the hook exits quietly
elsewhere; and each response cuts off the previous utterance for that session
rather than queueing behind it.

### DEPENDENCIES

- **rails-context** is the shared spine — both work and plan load it before anything else so they reason from one Rails framing. It's the only "load first" dependency and is never invoked directly.
- **work**/**plan** → pattern skills (**controller-patterns**, **routing-patterns**, **frontend-patterns**) is the mandatory dispatch fan-out; **rails-context** defines the triggers that fire them.
- *External delegation*: **work**→[*ce-work*], **plan**→[*ce-plan*] (engines they wrap), plus [**layered-rails**] and [**ce-dhh-rails-style**] in the dispatch set.
- *Maintenance chain*: **vet** (opinion vetting) → **skill-audit** (coherence) → **md-audit** (mechanical), with **skill-diff** as the upstream-comparison sibling. `vet` is the entry point when adopting a skill; `skill-audit` can also be invoked standalone for coherence-only audits.
- **find-skills** and **brave-breakdown** stand alone — no cross-skill wiring.
- **driving** stands alone too, but is the only skill paired with a hook: it owns the flag file that `hooks/driving-speak.sh` reads, which is why the two ship together as the `driving` plugin. Neither half does anything useful without the other.

## Local Development & Building from Source

The `dist/plugin/` directory holds a prebuilt plugin consumed by both Claude Code and GitHub Copilot CLI.

All changes should be localized within the `src/` directory **only**.  After making a change, rebuild the plugin with the `bin/build` script.

```sh
bin/build   # builds dist/plugin/ plus dist/<name>/ for each src/plugins/<name>/
```

> [!IMPORTANT]
> Plugins are cached by version number, so a bare `bin/build` rebuild won't refresh your installed copy — you must bump the version and then run `plugin update`.

Enable installation of your local clone by passing your repository's absolute file path to the `marketplace add` command of your AI harness of choice.

```sh
claude plugin marketplace add <absolute-path-to-repository-root>
copilot plugin marketplace add <absolute-path-to-repository-root>
```

With the marketplaces added, plugins can be installed by name just as before.

> [!Important]
> Marketplace Entries are **unique by name**, so you can swap a locally sourced entry for a GitHub entry & vice versa, but you cannot run both at once.

See [AGENTS.md](AGENTS.md) for full install details, a caveat about hooks, and the verification checklist.

## Releasing & updating

```sh
bin/release patch        # or: minor | major
bin/release --dry-run    # preview without changing anything
```

Running `bin/release` executes the following steps

1. bump `VERSION`
2. sync marketplace manifests for each harness
3. rebuild `dist/plugin/`
4. run the tests
5. create and push a tag `vX.Y.Z`
6. generate a GitHub release 🎉

See [AGENTS.md](AGENTS.md#release) for preconditions and flags.

## Running the tests

The test suite is plain Minitest with no Gemfile or Rakefile:

```sh
minitest
```

Tests cover the build pipeline, the single-tree output (skills, agents, hooks), build idempotency, and the release version-sync invariant.

## MIT License

See [LICENSE](LICENSE).
