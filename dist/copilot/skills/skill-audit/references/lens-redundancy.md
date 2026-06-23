# Lens: redundancy

You are reviewing the **whole skill** for content that repeats something already said *at the same altitude*. You see the full ledger, never a shard. Emit findings in the shared schema (see `decomposition.md` → "Shared findings schema").

## The altitude rule (read first)

Progressive disclosure is the skill format's intended design: a **brief rule in `SKILL.md` paired with its fuller example or treatment in `references/` is not redundancy** — it is the format working as designed. Never flag a summary-and-detail pair. The summary lives on the decision path; the detail lives where the agent goes when it needs depth. They are at different altitudes and both earn their place.

You flag only **same-altitude duplicates**: two units that teach the *same concept* to the *same depth*, such that a reader gains nothing from the second.

Altitude is about depth-of-treatment, not which file. **Within a single file**, a section's brief summary and a later paragraph that *details* the same concept are still at different altitudes — the same progressive-disclosure exemption applies, so do not flag a summary-then-elaboration pair just because both live in `SKILL.md`. Only flag a same-file pair when the second genuinely restates the first at the same depth with no added case or nuance.

## How to review

1. Cluster units by `concept` tag.
2. Within each cluster, compare units of the **same type and altitude**:
   - Two `example` units illustrating the identical point with no added nuance → redundant.
   - Two `directive` units stating the same rule in different words, same scope → redundant.
   - A `data-point` whose content is fully contained in another `data-point` → redundant.
3. For each genuine duplicate, ask: *does the second unit add any nuance, edge case, or altitude the first lacks?* If yes, it is not redundant — it is elaboration. Only flag when the answer is a clean "no."

## The table-vs-example trap (AE1)

A common false target: a **table enumerates several cases** and a **separate example illustrates one** of them. The example is *not* redundant with the table — it teaches the one case to a different depth (concrete vs. enumerated). If anything is redundant here it is a *second* example duplicating the *same* row the first already illustrated. Flag the duplicate example, never the enumerating table. (The guard enforces this too; you set it up by targeting the right unit.)

## Output

- `ledger_flag: redundant`. `lens: redundancy`.
- `proposed_disposition: merge` (fold two duplicates into one) when both carry a little unique phrasing worth preserving; `cut` when one is wholly contained in the other.
- `unit_ids` lists the duplicate set; `evidence` quotes the overlapping content and states explicitly that they share altitude.
- `confidence: medium` for most — duplication is a judgment. Drop to `low` when you are unsure whether the second unit adds nuance.
- When in doubt between "redundant" and "intended progressive disclosure," do **not** flag. The cost of a wrong redundancy cut (losing a real elaboration) outweighs the cost of leaving a mild duplicate.
