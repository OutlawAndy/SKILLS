# Opinion extraction: building the opinion ledger

This pass reads the target skill and produces the **opinion ledger** — the tiered, ranked set of directive units the vetting walk-through presents. Extraction is mechanical; tiering is judgment. Keep the split clean: classify honestly, but do not pre-judge whether an opinion is good or bad. That is the user's job in Phase 3.

## What counts as a directive

A directive is a normative instruction the agent is told to follow: a rule, a step, a "must"/"never", a gate, a phase instruction. It is **not**:

- An **example** — a concrete illustration, code block, sample dialogue, or worked scenario.
- A **data-point** — a reference fact, enumeration, or table consulted at need, not a rule to obey.

When a passage mixes rule and illustration inline, extract only the rule as the directive and note that an example is attached. When a passage states a rule and then immediately explains why, the rule is the directive and the rationale is an attribute of it (captured in `rationale_present`), not a separate unit.

## Extraction pass

Walk every file — `SKILL.md` first, then each file under `references/` in reading order. For each directive unit, record an entry in the shared ledger schema:

```yaml
id: V3
source:
  file: SKILL.md
  section: "How this works"
  lines: "32-33"
text: "Always build the unit ledger in one context — never dispatch to subagents."
strength: strong          # strong | soft | mechanical — see tiers below
rationale_present: false  # is an explicit justification given in surrounding text?
signal: "unjustified modal verbs (always/never); encodes an architectural choice among alternatives"
depends_on: []            # V-IDs of any directives this one explicitly references or requires
```

The `signal` field is one sentence explaining *what makes this directive opinionated* — it drives the explanation shown to the user during the walk-through. Do not editorialize about whether the opinion is good; describe only the structural signal (modal verb without rationale, preference among alternatives, etc.).

## Strength tiers

### Strong opinion — surface first

Classify as `strong` when the directive uses strong modal force **AND** at least one additional signal:

**Modal force indicators:** "always", "never", "must", "only", "do not", "must not", "required", "forbidden"

**Additional signals (any one suffices):**
- No rationale given anywhere in the skill for this choice
- Encodes a style or philosophical preference rather than a factual constraint
- Makes a specific choice among reasonable alternatives (not the only sensible option)
- Contradicts a common default or well-known convention in the domain

### Soft opinion — surface second

Classify as `soft` when the directive expresses a preference with weaker force or has a rationale that is itself a judgment call rather than a fact:

**Weaker force indicators:** "prefer", "avoid", "consider", "try to", "where possible", "generally", "by default"

OR: strong modal force with a stated rationale — but the rationale is a philosophical position, an aesthetic preference, or a debatable tradeoff rather than a factual constraint.

### Mechanical step — do NOT include

Classify as `mechanical` and **exclude from the ledger** when the directive enforces a factual constraint, a documented tool behavior, or a step with only one sensible option given the codebase context.

Examples of mechanical directives to exclude:
- "Edit `src/`, never `dist/`." — `dist/` is generated; this is a factual constraint with no alternative.
- "Read the file before editing." — a tool requirement.
- "Run `bin/build` after changes." — a documented build step.

**When unsure between soft and mechanical:** classify as `soft` and surface it. The user is the ground truth; let them decide.

## Dependency tracking

For each directive, note any other directive in the **same skill** that **explicitly references or depends on** it — e.g. "as described above", "given the rule in Phase 2", or a directive that would produce wrong behavior if the current one were removed.

Record as `depends_on: [V1, V4]` on the dependent unit. The walk-through uses this to warn the user before a veto cascades to orphan a dependent directive.

Dependency tracking is best-effort: flag explicit textual references and obvious structural dependencies. Do not attempt to infer all possible behavioral dependencies — that is not closed-world.

## Ranking

Rank the final ledger in this order:

1. **Strong, no rationale** — highest priority. Unjustified strong-force directives are the most likely source of unexamined assumptions.
2. **Strong, rationale present** — strong force but the rationale is there; the user can read it during vetting.
3. **Soft opinions** — weaker force; less likely to be load-bearing surprises.

Within each tier, preserve reading order (the order the directive appears across files).

## Degenerate case: no directives found

If the skill has no directive units at all, report:

> No directives found — this skill is a reference document with no normative instructions. Nothing to vet.

Do not proceed to the walk-through.

## Ledger summary line

After building the ledger, produce one summary line for the walk-through header:

```
vet: <target> — <N> directives · <S> strong opinions · <T> soft opinions
```

Where N = S + T (mechanicals are excluded and not counted).
