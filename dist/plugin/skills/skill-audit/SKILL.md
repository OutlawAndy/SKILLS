---
name: skill-audit
description: Audit one skill — its SKILL.md plus references/ as a single closed world — for internal contradictions, redundant or low-value examples, and detail that dilutes the decision path or wastes tokens. Use when asked to "audit this skill", "is this skill internally consistent", "what can I cut from this skill", "review this skill for drift", or "tighten this skill". Reports findings and offers to apply them; never auto-applies contradictions.
argument-hint: "[skill name or path to a skill dir/SKILL.md; blank to ask]"
license: MIT
metadata:
  triggers:
    - audit this skill
    - skill audit
    - is this skill internally consistent
    - what can I cut from this skill
    - review this skill for drift
    - tighten this skill
    - skill redundancy
    - skill contradictions
---

# skill-audit

Audit a single skill as a **closed world** — its `SKILL.md` plus everything under `references/` (and bundled assets), analyzed together — and report where it contradicts itself, repeats itself, or carries detail that doesn't earn its tokens. This is internal-consistency review, not correctness review: it never judges whether the skill's advice is *right* about any codebase, only whether the skill is coherent and lean against its own stated purpose.

The unifying question for every unit of content is **"does this earn its tokens?"** — and the standing danger is becoming a terseness-maximizer that strips the hard-won nuance preventing known failures. A dedicated adversarial guard exists to stop exactly that (see `references/load-bearing-guard.md`).

## What it does (and what it does not)

It **does**: decompose the target into a typed unit ledger, run three lens reviews (contradiction / redundancy / dilution) and an adversarial load-bearing guard over that ledger, merge findings by unit ID, and emit a prioritized, apply-able report.

It **does not**: compare against upstream (that is `skill-diff`'s job), audit more than one skill at a time, review arbitrary markdown, or auto-apply contradiction fixes. Contradiction *detection* is high-confidence closed-world; dispositions and load-bearing verdicts are *inferred* judgments — the report states this boundary.

## How this works

The orchestrator (this file) owns the whole pipeline in **one context**. The lenses and guard are prompt files under `references/` that the orchestrator **reads and runs as sequential in-context passes** over a single shared ledger — they are not dispatched to subagents. Because every pass scores the same unit IDs by construction, merge-by-ID has no cross-context drift. This is the `brave-breakdown` read-references-inline convention, not a subagent fan-out.

Phases, in order:

1. **Resolve target** — turn the argument into a concrete skill directory.
2. **Decompose** — build the canonical unit ledger. See `references/decomposition.md`.
3. **Lens passes** — run contradiction, then redundancy, then dilution, each over the whole ledger. See `references/lens-contradiction.md`, `references/lens-redundancy.md`, `references/lens-dilution.md`.
4. **Guard pass** — run the load-bearing guard over every non-`keep` candidate. Skipped entirely when there are none. See `references/load-bearing-guard.md`.
5. **Merge & rank** — dedup and merge findings by unit ID, assign final dispositions, order contradictions → redundancy → dilution.
6. **Report** — render the prioritized report with a ledger summary and confidence caveat. See `references/output-format.md`.
7. **Apply** — offer apply all / walk through / report-only; write edits to `src/skills/<target>/`; remind to run `bin/build`; suggest the optional `md-audit` handoff.

---

## Phase 1: Resolve target

Resolve `$ARGUMENTS` into one skill directory:

- **A skill name** (e.g. `frontend-patterns`) → resolve to `src/skills/<name>/` when run inside an outlaw-skills checkout. If that path does not exist, fall back to a sibling-installed copy (`<name>/SKILL.md` alongside this skill, as `skill-diff` does).
- **An explicit path** to a skill directory or a `SKILL.md` file → use it directly; if a `SKILL.md` path is given, the skill directory is its parent.
- **Blank** → list the skills you can see and ask which one to audit. Do not guess.

Confirm the resolved target (its directory and whether a `references/` subdirectory exists) before decomposing. Edits always target the canonical `src/skills/<target>/` source, never `dist/` (see Phase 7).

---

## Phase 2: Decompose

Read `references/decomposition.md` and follow it to build the canonical **unit ledger** — the single in-context artifact every later pass scores. Each unit is `{id, type, location, concept, snippet}` with a stable `U<N>` ID. Also read the target's frontmatter `description`; it is both the usefulness anchor for the dilution lens and itself auditable (R17).

When the target has no `references/` directory, decompose `SKILL.md` alone and apply the degenerate-path rules in `references/decomposition.md` (within-file contradiction and same-altitude redundancy stay active; `relocate` is disabled).

---

## Phase 3: Lens passes

Read each lens prompt file in turn and run it as a sequential in-context pass over the whole ledger, collecting findings in the shared schema (defined in `references/decomposition.md`). Run them in this fixed order so the report's grouping falls out naturally:

1. `references/lens-contradiction.md` — every internal clash, high-confidence, with a proposed fix direction.
2. `references/lens-redundancy.md` — same-altitude duplicates only; intended progressive disclosure is not a finding.
3. `references/lens-dilution.md` — content that doesn't earn its place in the decision path.

Each lens sees the **whole skill**, never a shard — running them as in-context passes (not dispatched subagents) is what guarantees this and what keeps every pass scoring the same `U<N>` IDs. Hold all findings together; do not adjudicate yet (that is the guard's job).

---

## Phase 4: Guard pass

If no lens emitted a non-`keep` candidate, skip this phase and render the no-findings report. Otherwise read `references/load-bearing-guard.md` and run it once over all non-`keep` candidates, producing a per-finding verdict. The guard's burden of proof is on the cut.

---

## Phase 5: Merge & rank

Reconcile the lens findings and the guard's verdicts into one ranked set:

1. **Apply guard verdicts.** For each candidate the guard reviewed, take its verdict as final: a downgraded finding becomes `keep` (drop it from the report's actionable set, but it may be worth a one-line "considered and kept" note when the guard named a regression); a retargeted finding moves its disposition to the unit the guard chose. Surviving cuts/trims/relocates keep their disposition.
2. **Merge by unit ID.** Group findings that reference the same `unit_ids`. Because every pass scored the same canonical ledger, two findings about `U7` are genuinely about the same unit — merge them into one finding that lists every lens that flagged it and the union of their evidence. A unit flagged by two lenses (e.g. redundant *and* diluting) produces one merged finding, not two.
3. **Dedup.** Collapse findings whose `unit_ids` and disposition are identical; keep the highest-confidence evidence.
4. **Rank.** Order strictly by lens class: **contradictions first, then redundancy, then dilution** (R18). Within a class, order by confidence (high → low).
5. **Flag contradictions confirm-only.** Mark every contradiction finding as never-auto-apply (R14), regardless of any bulk-apply choice downstream.

The result is one merged, de-duplicated, ranked finding set keyed to ledger unit IDs. Hand it to Phase 6. The report/apply *shape* lives in `references/output-format.md`; the merge logic above lives here.

---

## Phase 6: Report

Render the prioritized report per `references/output-format.md`: a one-line ledger summary, the confidence caveat, findings grouped by disposition, then the apply offer.

---

## Phase 7: Apply

Run the apply interaction from `references/output-format.md`: apply all / walk through / report-only. Bulk apply may cover non-contradiction dispositions; contradictions always require per-item confirmation. Write edits to `src/skills/<target>/` files, remind the user to run `bin/build`, and surface the optional `md-audit` mechanical-cleanup suggestion.

---

## Key principles

- **Closed-world only.** Internal consistency, never correctness against the codebase the skill describes.
- **Each unit must earn its tokens** — but the burden of proof is on the cut, not the keep. A silent wrong cut is the worst outcome.
- **Read references inline; do not dispatch.** All passes run in this one context against one ledger.
- **Contradictions never auto-apply.** They always route to human confirmation, even under "apply all".
- **Edit `src/`, never `dist/`.** `dist/` is generated; remind the user to run `bin/build`.
