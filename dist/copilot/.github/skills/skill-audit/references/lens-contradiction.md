# Lens: contradiction

You are reviewing the **whole skill** — every unit in the ledger, across `SKILL.md` and all of `references/` — for internal clashes. You see the full ledger, never a shard. Emit findings in the shared schema (see `decomposition.md` → "Shared findings schema").

## What a contradiction is

Two units that cannot both be followed as written. The clash is **present in the text** — you are not guessing about the world, you are reading two directives (or a directive and an example) that point in opposite directions.

Common shapes:

- **Directive ↔ directive.** "Always X" in one section, "never X" in another.
- **Directive ↔ example.** A rule says one thing; a worked example in `references/` does the opposite. This is the highest-value catch — examples drift from rules as skills are edited, and a contradicting example silently teaches the wrong behavior.
- **Directive ↔ data-point.** A rule references a value, version, or path that a table elsewhere contradicts.
- **Stated ↔ implied default.** A directive overrides a framework default the skill elsewhere tells the agent to honor.

Not contradictions: a `SKILL.md` summary and its fuller `references/` treatment (that is progressive disclosure — redundancy lens territory at most); two units at different altitudes that are consistent; a rule with a stated, scoped exception.

## How to review

1. Walk concept clusters: group units by their `concept` tag, then check whether any two units sharing or bridging a concept clash.
2. Then sweep cross-concept for directives that constrain the same action, file, value, or state from different sections.
3. For each clash, name **both** units (`unit_ids: [Ua, Ub]`) and quote the conflicting text in `evidence`.

## Output

- Flag **every** internal clash. Contradiction detection is closed-world: do not suppress a real clash because it seems minor.
- `ledger_flag: contradicts`, `confidence: high` (the clash is in the text).
- **Propose a fix direction, do not apply it.** In `proposed_disposition` use `align`, and in `evidence` state which side you'd favor and why — favor the **more load-bearing or more repeated** side (the rule restated in three places outranks the lone example that drifted). This is a *proposal*; contradictions always route to human confirmation downstream (never bulk-applied), so the direction is advice for the human, not an instruction to auto-resolve.
- If genuinely symmetric (no side is clearly more load-bearing), say so and present both directions for the human to pick.
