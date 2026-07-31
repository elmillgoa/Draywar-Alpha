---
name: verify
description: Audit whether a Draywar Alpha contract is genuinely finished against the full definition of done. Adversarial — assume the claim is wrong. Use before marking any contract complete. /verify
---

# Is it actually done?

Assume the claim is wrong. Try to break it.

Run `/adversary` first when the contract has non-trivial logic. This skill is the
compliance audit; adversary is the hunt. Neither replaces the other.

## The nine points (all must hold)

1. Every acceptance criterion demonstrably passes — named evidence.
2. Strict typing + lint pass (`scripts/lint.ps1`).
3. Every new tunable is in the balance layer.
4. Content via data pipeline.
5. EventBus-only cross-system; `docs/events.md` current.
6. New persistent state save/load round-trips (once save exists).
7. Headless smoke + tests pass.
8. `docs/state.md` updated.
9. Nothing quietly narrowed to make a criterion pass.

## How to check

Run checks yourself. Agent summary is not evidence.

- Break what a new test guards; confirm red; restore; green.
- Grep changed files for magic numbers.
- Search for cross-layer static refs.
- Save, quit, load when save exists.

## Verdict (exactly one)

> **DONE** — evidence per criterion.
>
> **NOT DONE** — which criteria fail.
>
> **BLOCKED** — what would unblock.

Wrong "done" is the only bad report.
