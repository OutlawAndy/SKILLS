---
name: md-audit
description: Mechanical-only markdown hygiene for one skill — its SKILL.md plus references/ — fixing formatting (via markdownlint-cli2) and unambiguous typos while treating all normative text as immutable. Use when asked to "clean up this skill's markdown", "fix formatting", "run markdown hygiene", "tidy this skill", or as the mechanical cleanup pass after skill-audit applies semantic changes. Never rephrases, tightens, or trims — that is skill-audit's job.
argument-hint: "[skill name or path to a skill dir/SKILL.md; blank to ask]"
license: MIT
metadata:
  triggers:
    - clean up this skill's markdown
    - fix formatting
    - markdown hygiene
    - tidy this skill
    - md audit
    - mechanical cleanup
---

# md-audit

Mechanical-only markdown hygiene for a single skill — its `SKILL.md` plus everything under `references/` — analyzed as one unit. `md-audit` fixes **presentation and unambiguous spelling**: formatting (via a deterministic, version-pinned `markdownlint-cli2`) and clear typos (via a gated LLM pass). It is the mechanical complement to `skill-audit`: where `skill-audit` makes closed-world *semantic* judgments (contradictions, redundancy, dilution) and never touches formatting, `md-audit` makes *mechanical* fixes and **never touches meaning**.

The hard invariant: **normative text is immutable.** `md-audit` never rephrases a directive, never changes a modal (`must`/`should`/`may`), never reorders or trims for concision, and never edits content inside fenced code blocks. Conciseness and rephrasing stay with `skill-audit`'s dilution lens. When in doubt, it skips and reports rather than edits.

## What it does (and what it does not)

It **does**: run `markdownlint-cli2 --fix` (deterministic formatting) and a gated LLM typo pass, present a reviewable diff with formatting and typo fixes in separate labeled sections, and apply the user's chosen subset to `src/skills/<target>/`.

It **does not**: rephrase, tighten, reorder, or trim (that is `skill-audit`); judge whether content earns its tokens; touch fenced-code content; fix typos *inside* a normative directive (those are reported, not applied); or audit anything but skill markdown (`SKILL.md` + `references/*.md`).

## Requirements

- [`markdownlint-cli2`](https://github.com/DavidAnson/markdownlint-cli2) for the formatting pass. Prefer it installed globally (`npm i -g markdownlint-cli2`); when absent, `md-audit` runs it via `npx --yes markdownlint-cli2@<pinned-version>` — pinned, never floating, so the formatter's behavior is deterministic across runs. This is the skill's one Node/npm dependency (the repo is otherwise Ruby). If neither a global binary nor `npx` can obtain it, `md-audit` reports the failure and offers a typo-only pass rather than failing silently. See `references/safe-formatting.md`.

## How this works

Like `skill-audit`/`brave-breakdown`, `md-audit` is a prose orchestrator: this file reads its `references/*.md` inline and runs the phases in its own context. The only external tool is `markdownlint-cli2`.

Phases, in order:

1. **Resolve target** — turn the argument into a concrete skill directory.
2. **Format pass** — run `markdownlint-cli2 --fix` with the bundled config. See `references/safe-formatting.md`.
3. **Typo pass** — run the gated LLM typo check over the formatted text. See `references/typo-gate.md`.
4. **Diff & apply** — present formatting and typo fixes in labeled sections; apply per mode; write to `src/`; remind `bin/build`.

---

## Phase 1: Resolve target

Resolve `$ARGUMENTS` into one skill directory (identical to `skill-audit`):

- **A skill name** (e.g. `frontend-patterns`) → resolve to `src/skills/<name>/` when run inside an outlaw-skills checkout. If that path does not exist, fall back to a sibling-installed copy (`<name>/SKILL.md` alongside this skill, as `skill-diff` does).
- **An explicit path** to a skill directory or a `SKILL.md` file → use it directly; if a `SKILL.md` path is given, the skill directory is its parent.
- **Blank** → list the skills you can see and ask which one to audit. Do not guess.

Collect the target's markdown files: `SKILL.md` and every `*.md` under `references/`. A target with no `references/` is fully supported — operate on `SKILL.md` alone. Confirm the resolved target before running the passes. Edits always target the canonical `src/skills/<target>/` source, never `dist/` (see Phase 4).

---

## Phase 2: Format pass

Read `references/safe-formatting.md` and run the deterministic formatting pass over the collected files. The formatter is `markdownlint-cli2 --fix` driven by the bundled `references/markdownlint-cli2.jsonc` config (always passed explicitly via `--config`, never ambient-discovered). Collect the resulting changes as a reviewable diff — do not write yet.

---

## Phase 3: Typo pass

Read `references/typo-gate.md` and run the gated LLM typo check over the (now formatted) text. Propose only context-free fixes; report-and-skip anything inside a normative directive, any context-dependent case, and any domain term, product name, or code identifier. Collect proposals as diffs — do not write yet.

---

## Phase 4: Diff & apply

Run the apply interaction (detailed in `references/safe-formatting.md` and `references/typo-gate.md` for what's in each section): present one diff with two clearly labeled sections — **deterministic formatting fixes** and **proposed typo fixes** (and a third **reported, not fixed** list for skipped items). Offer:

- **report-only** — write nothing.
- **walk through** — confirm each fix individually.
- **apply all** — apply formatting as a reviewed batch and typo fixes as a confirmable batch.

Write applied edits to `src/skills/<target>/` files, remind the user to run `bin/build`, and stop. If invoked as `skill-audit`'s handoff, the same flow applies.

---

## Key principles

- **Mechanical only.** Formatting and unambiguous spelling. Never wording, structure, meaning, or concision.
- **Normative text is immutable.** A typo inside a `must`/`never` directive is reported, not fixed. Default to skip.
- **Deterministic, but reviewed.** `markdownlint-cli2` is pinned and config-pinned; a few fixes still alter rendered output, so the user always sees the diff before anything is written.
- **Edit `src/`, never `dist/`.** `dist/` is generated; remind the user to run `bin/build`.
