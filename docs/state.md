# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** Path C. **B0–B3 complete**. Next: **B4 Thin combat**. Final Alpha **not signed**.

| Doc | Role |
|-----|------|
| `Alpha/ALPHA_DECISION_BAR.md` | What Alpha done means (ratified) |
| `Alpha/ALPHA_DECISION_PHASE_PLAN.md` | B0–B5 order + worktree parallel tracks (**agreed**) |
| `docs/reputation_and_standing.md` | Standing law |

**Last closed:** **B3 — Station depth + trade + money loop**.

## Honest now

| Area | Status |
|------|--------|
| Multi-system **in play** | **Pass** |
| Presentation floor | **Pass** |
| Session shell | **Pass** |
| Trade / station depth | **Pass** — 6 commodities, buy/sell at dock, cargo hold, legal trade standing soft |
| Combat | Missing (B4) |
| Content drama / Final Alpha | Missing (B5) |

## B3 evidence

**Acceptance**

- Dock → Trade section → Buy 1 / Sell 1 → credits + cargo change without console.
- Sell price < buy price → same-station flip nets credit change (visible money loop).
- Station menu sectioned (Jobs / Services / Trade / Contacts / Undock) with B1 theme.
- Cargo optional save section; Captain sheet shows cargo used/capacity.
- Tests: `tests/test_b3_trade.gd` (10). Suite **220/220**. Lint green.
- Verify-red: broke cargo qty assert → 1 fail; restored green.

## Gates

- A1 flight feel **signed** · A4 recovery feel **signed**
- Final Alpha **open** until B5 + checklist green + Elliot sign

## Open decisions

- None blocking B4. Save: ask only for new **required** fields.

## Standing decisions

- Path C; B0–B3 main tree. Godot 4.6.1. Remote `origin/main`.
- After phase wrap, free to chain next phase in same chat.

## Next session starts here

1. `/start` — orient; plan is **B4 Thin combat**.
2. **Go on B4** (weapons, hostile NPC, damage, attribution standing).
3. B5 content + drama + Final Alpha after B4.
4. Final Alpha only after B5 checklist green.

## Session history

- **2026-07-31** — B3: trade + cargo + station sections; 220 tests; wrap.
- **2026-07-31** — B2: session shell.
- **2026-07-31** — B0+B1: travel + presentation.
- **2026-07-30–31** — A0–A5 mechanical; Path C plan.
