# Lens: dilution

You are reviewing the **whole skill** for content that doesn't earn its place — detail that dilutes the decision path or wastes tokens without teaching anything the skill's purpose needs. You see the full ledger, never a shard. Emit findings in the shared schema (see `decomposition.md` → "Shared findings schema").

## The baseline: progressive-disclosure norms + the description anchor

Two reference points govern this lens:

1. **Progressive disclosure.** `SKILL.md` is the decision path — what the agent reads to decide what to do. `references/` is depth — what it consults once it needs detail. Content in `SKILL.md` that the agent does **not** need *at decision time* belongs in `references/`, not the main file.
2. **The frontmatter `description`** (the usefulness anchor, extracted in decomposition). Judge "does this earn its tokens?" relative to what the skill claims to be *for*. Detail the description's purpose clearly needs is load-bearing; detail that serves nothing the description promises is a dilution candidate.

## What dilution looks like

- **Belongs-in-references.** A long worked example, an exhaustive enumeration, or deep background sitting in `SKILL.md`'s decision path, when the decision only needs a one-line rule + a pointer. → `relocate` (but see the no-`references/` degenerate rule below).
- **Restating framework defaults.** Telling the agent something it already does by default, or re-explaining a well-known convention the description's audience already knows. → `trim` or `cut`.
- **Low marginal value.** A unit that, read in context, adds no decision-relevant information beyond what surrounds it — filler, throat-clearing, a caveat already implied. → `trim` or `cut`.
- **Over-specified detail.** A directive carrying more precision than the decision needs (exact counts, exhaustive sub-cases) where a general rule would drive the same behavior. → `trim`.

## What is NOT dilution

- A short rule on the decision path that prevents a known failure, even if terse and "obvious." Terse load-bearing rules are the cheapest tokens in the skill.
- Nuance that looks like filler but encodes a hard-won edge case. If you cannot tell, flag at `low` confidence and let the guard adjudicate — do **not** cut confidently.
- Depth that correctly lives in `references/`. Depth in references is the format working; only flag reference content if it is *also* redundant or contradictory (other lenses).

## No-`references/` degenerate rule (R22)

If the target has no `references/` directory: **disable `relocate`.** There is nowhere to relocate to. A belongs-in-references candidate becomes a `trim` (shorten in place) or `keep` decision, and you note "no `references/` target exists" rather than proposing a relocate. Do not flag the skill for *lacking* a `references/` split — a correctly small single-file skill is the neutral baseline.

## Output

- `ledger_flag: low-marginal-value` (or `contradicts`/`redundant` only if you stray into another lens — prefer to leave those to their lens).
- `proposed_disposition`: `relocate` (decision-path detail that belongs in references), `trim` (partly bloat), or `cut` (earns nothing anywhere).
- `confidence: medium` typically; `low` when the cut is contestable. Dilution findings are *inferred*, never closed-world — every one is a candidate the guard must clear.
- Remember the standing danger: this lens is where terseness-maximizing creeps in. When unsure whether something earns its tokens, the honest disposition is `keep` and let the guard demand the regression name.
