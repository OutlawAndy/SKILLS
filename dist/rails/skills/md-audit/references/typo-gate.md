# Typo gate: the immutability protocol

This is the one LLM judgment in `md-audit`, and it is deliberately the narrowest one possible. You scan the formatted markdown for typos and propose fixes — but the burden is on the *fix*, not the keep. The default on any doubt is **skip and report**, never edit. Mechanical spelling is in remit; meaning is not, ever.

You run after the formatting pass, over the already-normalized text. You propose; you never write — the apply flow (in `SKILL.md` Phase 4) handles writing after the user chooses.

## The allowlist: forms that cannot change meaning regardless of context

Propose a fix **only** when it belongs to one of these context-free classes — where the correction is the same no matter what the sentence means:

- **Letter-transpositions / clear misspellings of common English words** in ordinary prose: `teh → the`, `recieve → receive`, `seperate → separate`.
- **Doubled words**: `the the → the`, `to to → to` (only when the repetition is plainly accidental, not intentional emphasis or a quoted string).
- **Obvious punctuation slips**: a missing sentence-final period at the end of a clearly-terminal sentence, a doubled comma `,,`.

That is the whole allowlist. If a candidate is not unambiguously in one of these classes, it is out of remit.

## Hard exclusions (the immutability invariant)

Never propose, regardless of how "obvious" the fix looks:

- **Anything inside a normative directive.** This is the precedence rule (R3b) and it wins over the allowlist. If a misspelling sits in a sentence that carries a modal (`must`/`never`/`should`/`may`/`shall`), states a rule, or contains a code identifier, **report it for human attention — do not propose an edit.** Fixing spelling inside a directive is editing normative text, which is forbidden. Example: in "the agent must `nevar` set `url:`", `nevar` is a real misspelling, but it lives in a `must` directive → report, never auto-fix.
- **Context-dependent "fixes."** Anything whose correctness depends on what the sentence means is out — it is a semantic judgment masquerading as a typo. Report, never apply: `can not → cannot` (can carry stressed "can *not*"), `a part ↔ apart`, `everyday ↔ every day`, `its ↔ it's`, `affect ↔ effect`.
- **Domain terms, product names, code identifiers, and jargon.** Never "correct" a Stimulus controller name, a gem name, a CLI flag, a config key, an API term, or a deliberately coined term. A word that looks misspelled but is a technical identifier is not a typo.
- **Content inside fenced code blocks or inline code spans.** Literal — never touched (the formatter leaves it alone too).
- **Style, not spelling.** `utilise → utilize`, Oxford-comma changes, British/American variants, capitalization preferences — these are style, not typos. Skip.
- **Anything structural.** Never reorder, merge, or split sentences; never reword; never tighten for concision. Concision is `skill-audit`'s dilution lens, not yours.

## Output

For each candidate, produce one of two outcomes — never a silent edit:

- **Proposed fix** (in-allowlist, not excluded): record before/after with a few words of surrounding context so the diff is reviewable. These land in the "proposed typo fixes" section of the apply diff.
- **Reported, not fixed** (excluded — in a directive, context-dependent, identifier, or style): record it as a one-line note ("possible typo `nevar` inside a `must` directive — left for you, not auto-fixed"). These land in the "reported, not fixed" list. Reporting is not a failure; it is the gate working — it surfaces the candidate for a human without crossing the immutability line.

When uncertain whether something is a typo at all, or whether it is in a directive, treat it as excluded and report it. Skip-and-report is always safe; a wrong auto-fix to normative text is the one outcome this skill exists to prevent.

## Worked examples

| Candidate | In context | Outcome |
|---|---|---|
| `teh` in "open `teh` file" | ordinary prose | **Propose** `teh → the` |
| `the the` in "run the the build" | accidental doubling | **Propose** `the the → the` |
| `nevar` in "you must `nevar` edit dist/" | inside a `must` directive | **Report**, not fixed (R3b) |
| `can not` in "you can not skip this" | context-dependent | **Report**, not fixed |
| `Stimlus` | a coined/technical-looking identifier | **Report** (could be intentional) — never auto-fix an identifier |
| `utilise` | British spelling | **Skip** — style, not a typo |
| `recieve` in "agents recieve the payload" | ordinary prose, no modal | **Propose** `recieve → receive` |
