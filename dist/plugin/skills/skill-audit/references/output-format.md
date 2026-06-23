# Output format and apply flow

How the merged, ranked finding set (from `SKILL.md` Phase 5) is rendered and applied.

## The report

Render in this order:

### 1. Ledger summary (one line)

A single header line counting units by value-ledger flag, so the reader sees the shape before the detail:

```
skill-audit: frontend-patterns — 23 units · 1 contradiction · 2 redundant · 3 low-value · guard kept 2
```

Include the target name, total unit count, counts per flag, and how many candidates the guard downgraded to `keep`. (The "guard kept" count is the visible signal that the guard did its job — if it is 0 on a skill with many candidates, that is worth noticing.)

### 2. Confidence caveat (verbatim intent)

State the mechanical/judgment boundary every run (KTD5). Use this wording or close to it:

> Caveat: contradiction *detection* is high-confidence closed-world — the clash is present in the text. Dispositions, redundancy, dilution, and load-bearing verdicts are *inferred judgments*, not proofs. Treat them as a senior reviewer's recommendations, not facts; the apply step keeps you in the loop.

### 3. Findings, grouped by disposition class

Grouped and ordered **contradictions → redundancy → dilution** (Phase 5 already ranked them). Each finding shows:

- **Unit IDs + location** — `U7` (`references/EXAMPLES.md` § Strict Locals, lines 40–58), and every other unit it spans.
- **Lens(es)** that flagged it.
- **Evidence** — the quoted clash / duplicate / dilution rationale.
- **Proposed disposition** — `align` / `merge` / `cut` / `relocate` / `trim` / `keep`.
- **Guard verdict** — survived, downgraded-to-keep (with the named regression), or retargeted (to which unit, and why).

Suggested per-finding shape:

```
[C1] contradiction · confidence: high · CONFIRM-ONLY
  Units: U7 (SKILL.md § Slim, l.22) ↔ U41 (references/EXAMPLES.md § Forms, l.110)
  Evidence: U7 says "always declare strict locals"; U41's partial omits the magic comment.
  Proposed: align — favor U7 (rule restated in 3 places; U41 is the lone drift).
  Guard: both sides assessed; U7 more load-bearing. Routed to your confirmation.
```

### 4. No-findings report

When no lens emitted a non-`keep` candidate (the guard never ran), render the clean report instead of the groups:

```
skill-audit: <target> — <N> units · no findings.
The skill is internally coherent: no contradictions, no same-altitude redundancy, no dilution candidates.
```

Still include the ledger summary line and skip the apply offer.

## Apply flow

After the report, offer three modes (R19):

| Mode | Behavior |
|---|---|
| **Apply all** | Bulk-apply every **non-contradiction** disposition (`merge`/`cut`/`relocate`/`trim`/`align` on dilution & redundancy findings). Then fall through to per-item confirmation for **every contradiction** — contradictions are *never* in the bulk set (R14). |
| **Walk through** | Per-finding confirmation for all findings, contradictions included. Show each, apply on a yes. |
| **Report only** | Write nothing. Done. |

**Contradictions always require per-item confirmation, even under "apply all"** (R14). This is non-negotiable: a contradiction fix picks a side, and picking the wrong side silently teaches wrong behavior. Present the proposed direction, but make the human choose.

### Writing edits

- Edits write to the canonical **`src/skills/<target>/`** source files — never `dist/` (KTD7). `dist/` is generated and checked in; editing it is reverted on the next build.
- After applying any edit, remind the user plainly: **"Run `bin/build` to regenerate `dist/` for both targets."**
- Re-run is cheap: the audit is idempotent against a clean skill, so a user can re-audit after applying to confirm the findings cleared.

### Optional `md-audit` handoff (R20/R21)

When changes were applied, close with a plain-prose suggestion:

> Applied N change(s). For a mechanical cleanup pass — formatting and unambiguous typos, with all normative text left untouched — consider running `/md-audit <target>`. `skill-audit` deliberately leaves mechanical hygiene to `md-audit`.

Surface the suggestion as text and **stop** — do not invoke `md-audit` in the same turn. The handoff is a recommendation for the user to act on, not an automatic chained call; auto-running a second skill the user didn't ask for is exactly the over-reach to avoid, and it matters more now that `md-audit` exists and auto-activates on phrases like "fix formatting".
