---
name: vet
description: Interactively surface and prune the strong opinions encoded in an adopted skill — one directive at a time — so you can accept, veto, or replace each before it silently shapes your workflow. Use when you've adopted (or inherited) a skill and want to align it with your own philosophy before trusting it.
argument-hint: "[skill name or path to skill dir/SKILL.md; blank to ask]"
license: MIT
metadata:
  triggers:
    - vet this skill
    - vet skill
    - review opinions in this skill
    - I adopted this skill
    - challenge this skill
    - prune this skill
    - align this skill with my preferences
    - what opinions does this skill encode
---

# vet

Surface and prune the **strong opinions** baked into an adopted skill — the directives that encode someone else's philosophy, justified or not. Works through them one at a time: you accept, veto, or replace each. Applies your decisions to `src/skills/<target>/` and suggests a `skill-audit` coherence pass when done.

This is **open-world** review: you are the ground truth, not the skill. There is no internal-consistency check here — that is `skill-audit`'s job. The question for every directive is not "does this contradict itself?" but "is this how *I* would approach it?"

## What it does (and what it does not)

It **does**: extract all directive units from the target skill, score and rank each for opinionatedness, walk you through strong opinions first then softer ones, collect a verdict per item (accept / veto / modify / skip), apply your decisions, and suggest a `skill-audit` follow-up to catch any coherence issues your edits introduced.

It **does not**: surface examples or data-point units (those encode how the skill teaches, not what it demands), auto-apply any change, judge whether an opinion is objectively right or wrong, or run coherence checking.

## How this works

Single-context sequential passes — same convention as `skill-audit`. No subagent fan-out. The reference files are read and run inline against one shared ledger, not dispatched.

Phases, in order:

1. **Resolve target** — turn the argument into a concrete skill directory.
2. **Extract** — build the opinion ledger: all directive units, tiered and ranked by opinionatedness. See `references/opinion-extraction.md`.
3. **Walk through** — present one directive at a time in ranked order; collect verdicts. See `references/vetting-loop.md`.
4. **Apply** — write decisions to `src/skills/<target>/`; remind to run `bin/build`.
5. **Handoff** — suggest `skill-audit` for a coherence pass on the edited skill.

---

## Phase 1: Resolve target

Resolve `$ARGUMENTS` into one skill directory:

- **A skill name** (e.g. `controller-patterns`) → `src/skills/<name>/` when inside an outlaw-skills checkout; otherwise the sibling-installed copy alongside this skill.
- **An explicit path** to a skill directory or `SKILL.md` → use it directly; if a `SKILL.md` path is given, the skill directory is its parent.
- **Blank** → list the skills you can see and ask which one to vet. Do not guess.

Confirm the resolved directory (and whether a `references/` subdirectory exists) before extracting. Edits always target the canonical `src/skills/<target>/` source, never `dist/`.

---

## Phase 2: Extract

Read `references/opinion-extraction.md` and follow it to build the **opinion ledger** — the ranked set of directive units the walk-through presents.

Read the target's `SKILL.md` and every file under `references/`. Extract directive units only; ignore examples and data-points. Each entry gets a stable `V<N>` ID (distinct from `skill-audit`'s `U<N>` series, to avoid confusion if both are discussed in the same session). Produce the ledger summary line before starting the walk-through.

---

## Phase 3: Walk through

Read `references/vetting-loop.md` and run the interactive walk-through over the opinion ledger in ranked order (strong opinions with no rationale first; strong opinions with rationale second; soft opinions last).

Present one directive per turn. Wait for a verdict before advancing. The walk-through handles all verdict types: accept, veto (cut or soften), modify (user-supplied replacement), skip (defer to end), and done (stop early, treat remaining as accepted).

---

## Phase 4: Apply

Write all non-accepted verdicts to `src/skills/<target>/` source files — never `dist/`. Preserve exact surrounding whitespace and file structure; change only the directive lines being cut, softened, or replaced.

After writing, remind the user plainly: **"Run `bin/build` to regenerate `dist/` for both targets."**

If no changes were made (all accepted, all skipped, or all deferred and not revisited), state that clearly and omit the build reminder.

---

## Phase 5: Handoff

After apply, close with this suggestion or close to it:

> Applied N change(s) to `<target>`. Pruning directives can introduce gaps or inconsistencies. Consider running `/skill-audit <target>` to check internal coherence after your edits — contradictions and redundancies sometimes only become visible after opinions are removed.

Omit the handoff suggestion when no changes were made.

Surface as text and stop — do not invoke `skill-audit` automatically.

---

## Key principles

- **Open world only.** You are the arbiter. The skill's internal logic is not a counter-argument to a veto.
- **Directives only.** Examples and data-points are not surfaced — they encode how the skill teaches, not what it demands.
- **No auto-apply.** Every change requires an explicit verdict. Accept is the default; a veto or modification is always a deliberate act.
- **One at a time.** Never present multiple directives at once. The pacing is intentional.
- **Edit `src/`, never `dist/`.** `dist/` is generated; remind the user to run `bin/build`.
- **Strong opinions first.** The ordering ensures the most consequential decisions don't get buried in softer preferences.
