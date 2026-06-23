# Decomposition: building the canonical unit ledger

This pass turns the target skill into one **canonical unit ledger** — the single artifact every later pass (the three lenses and the guard) scores. Decomposition **extracts structure; it does not judge value.** Naming what each piece of content *is* and *where it lives* is mechanical and high-confidence. Deciding whether a piece earns its tokens is the lenses' and guard's job, and those judgments are inferred, not closed-world. Keep the split clean: do not pre-emptively flag anything here.

## Inputs

- The target's `SKILL.md`.
- Every file under `references/` (and any bundled assets that carry normative prose, e.g. a checklist in `scripts/`). Ignore binary assets and code that is purely executed, not read by the agent.
- The target's frontmatter `description` — extracted separately as the **usefulness anchor** (see below).

## Two-pass extraction

**Pass A — structural location.** Walk each file top to bottom and record its structure: file path, heading hierarchy (section / subsection), and line ranges. This is the coordinate system every unit is pinned to.

**Pass B — typed semantic units.** Within that structure, segment the prose into typed units. Each unit gets a stable ID and is one of three types:

| Type | What it is | Examples |
|---|---|---|
| `directive` | A normative instruction the agent is told to follow — a rule, a step, a "must"/"never", a gate, a phase instruction. | "Always declare strict locals." "Never edit `dist/`." A numbered phase step. |
| `example` | A concrete illustration of a directive — a code block, a sample dialogue, a worked scenario, a before/after. | A Slim snippet showing strict locals. A sample report. |
| `data-point` | A reference fact or enumeration consulted at need, not a rule to obey. | A table of grammars, a list of supported versions, a mapping table. |

Granularity rule (resolves the merge-correctness risk): **a table or list is one `data-point` unit, not one unit per row.** When a finding needs row-level precision, it references the table's single unit ID and names the specific rows in its `evidence`. This keeps merge-by-ID unambiguous (every pass refers to the same table by the same ID) while preserving the precision a finding needs — e.g. "the table enumerates four cases; only row 3 is duplicated by U17."

When a single passage is genuinely two things (a rule stated *and* illustrated inline), split it: the rule is a `directive`, the inline illustration is an `example`, each with its own ID. This is what lets the redundancy lens distinguish a summary+detail pair (intended) from a true duplicate.

## Unit schema

Each ledger entry:

```yaml
id: U7                              # stable per-run identifier, U1..Un, assigned in reading order
type: directive | example | data-point
location:
  file: references/EXAMPLES.md      # path relative to the skill dir
  section: "Slim Templates > Strict Locals"
  lines: "40-58"                    # range within that file
concept: strict-locals             # the single idea this unit serves (the merge/cluster key)
snippet: "Every partial declares its interface on the first line…"   # verbatim or lightly trimmed
```

The `concept` tag is the connective tissue: the redundancy lens clusters by it, and merge groups findings that touch the same concept across files. Tag conservatively — one concept per unit, named for the idea it teaches (`strict-locals`, `dist-is-generated`, `counterfactual-test`), not the section it sits in. IDs are **per-run only**; they are not persisted across audits.

## The frontmatter `description` anchor

Extract the `description` as a distinguished input, not a numbered unit. It serves two roles:

1. **Usefulness anchor.** The dilution lens judges "does this earn its tokens?" *relative to what the skill claims to be for.* The `description` is that claim. A directive that serves nothing the description promises is a dilution candidate; detail that the description's purpose clearly needs is load-bearing.
2. **Auditable itself (R17).** If the `description` is too vague to anchor those judgments — generic verbs, no trigger surface, no statement of what the skill is *for* — emit that as a finding (lens: `dilution`, flag: `low-marginal-value`, disposition: `align`, targeting the description). A description that cannot anchor usefulness judgments is a defect, not a neutral baseline.

## Shared findings schema

Every lens and the guard emit findings in this one schema, so the orchestrator can dedup, merge by unit ID, and rank without translation:

```yaml
finding_id: F3
unit_ids: [U7, U22]                # the unit(s) this finding is about; >1 when it spans a clash/cluster
lens: contradiction | redundancy | dilution
ledger_flag: contradicts | redundant | low-marginal-value | load-bearing
proposed_disposition: align | merge | cut | relocate | trim | keep
evidence:                          # concrete, quotable; burden of proof lives here
  - "U7 says 'always X'; U22 shows an example doing 'not X'."
confidence: high | medium | low    # see bands below
```

### Disposition vocabulary (fixed)

| Disposition | Meaning |
|---|---|
| `align` | Reconcile a clash or a too-vague anchor by editing one side toward the other. |
| `merge` | Fold two same-altitude duplicates into one. |
| `cut` | Remove a unit that earns nothing. |
| `relocate` | Move decision-time-unneeded detail from `SKILL.md` into `references/`. |
| `trim` | Shorten a unit that is partly load-bearing, partly bloat. |
| `keep` | No change — the unit earns its tokens. The guard's default verdict. |

### Value-ledger flags (fixed)

`contradicts` (two units clash) · `redundant` (same-altitude duplicate) · `low-marginal-value` (teaches nothing new at its altitude) · `load-bearing` (removal/relocation causes a nameable behavior regression — the guard's keep flag).

### Confidence bands

Three discrete bands, not a numeric score — the merge/rank step only needs ordering, and a band states the mechanical/judgment boundary honestly:

- `high` — closed-world and checkable. Contradiction detections are `high` by default: the clash is present in the text.
- `medium` — a defensible inferred judgment (most redundancy and dilution findings).
- `low` — a plausible but contestable judgment; surfaced for human attention, never bulk-applied.

## Degenerate path: no `references/` directory

The majority case in this repo (8 of 12 skills). When the target has no `references/`:

- Decompose `SKILL.md` alone. The ledger is valid with units from one file.
- **Within-file contradiction and same-altitude redundancy stay active** — a `SKILL.md` can contradict or repeat itself.
- **Disable `relocate`.** There is no `references/` to relocate into. The dilution lens and the guard's load-timing check (AE5) note "no `references/` target exists" instead of emitting `relocate` findings; a relocation candidate becomes a `trim`-or-`keep` decision, not a relocate.
- **Absence of `references/` is a neutral baseline, not a defect.** Do not flag a single-file skill for "missing progressive disclosure." Many skills are correctly small.
