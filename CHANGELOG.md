# Changelog

## 0.7.0 — 2026-10-05

- The marketplace is now `outlawandy` and the main plugin is now `rails`.
  Existing installs must remove the `outlaw-skills` marketplace, add it again,
  and install `rails@outlawandy` (plus `driving@outlawandy` for hands-free mode).

## 0.6.0 — 2026-10-05

- **driving** is now its own plugin: `claude plugin install driving@outlaw-skills`
  installs hands-free mode without the rest of the suite. It no longer ships in
  `outlaw-skills`, so existing users should install `driving` alongside it.
- **driving** mode is scoped to the session that turned it on. A flag left
  behind by a forgotten `/driving off` no longer makes a later session speak.

## 0.5.0 — 2026-10-04

- Add **compound**: a `ce-compound` wrapper that writes learnings outside the repo.

## 0.4.0 — 2026-09-22

- Add **driving** mode: a `Stop` hook that speaks, and a skill that decides what to say.
- **controller-patterns** warns against multiple `authorize!` calls per action.

## 0.3.1 — 2026-07-04

- Update **frontend-patterns**.

## 0.3.0 — 2026-06-25

- Add **vet** for interactive opinion vetting of adopted skills.

## 0.2.1 — 2026-06-22

- Collapse the per-tool distributions into one plugin tree read by both Claude
  Code and Copilot CLI.

## 0.1.2 — 2026-06-19

- "Make the change easy, then make the easy change" across **rails-context**,
  **plan**, and **work**.

## 0.1.1 — 2026-06-19

- Initial release: **skill-diff**, **skill-audit**, **md-audit**,
  **frontend-patterns**, **brave-breakdown**, the Rails workflow skills, and
  `bin/release`.
