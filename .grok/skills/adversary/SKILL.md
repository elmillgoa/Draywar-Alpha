---
name: adversary
description: Attack a finished contract to prove it is NOT done — hunts for untested criteria, tests that cannot fail, and seams. Reports only; never fixes. /adversary
---

# Try to break it

Not a second test run. Hunt **the case nobody thought to fly.**

`/verify` is the checklist. This is the attack. Run this first; feed findings into verify.

## Three hunts (separate agents when non-trivial)

1. **Criterion with no evidence** — quote criteria; demand evidence per clause.
2. **Test that cannot fail** — break what each assertion guards; confirm red.
3. **Seam that does not meet** — when parallel work joined; callers vs implementers.

## Rules

- **Report only; never fix.**
- **All-clear with no attempts is not a report.**
- Orchestrator reproduces findings before acting.
- False alarms are cheap and expected.

## Verdict

> **SURVIVED** — what was tried and held.
>
> **HOLED** — reproduction and which criterion dies.
