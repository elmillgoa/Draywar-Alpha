# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E4 Opening & cast code complete** (E4.1–E4.6). **[GATE] E4.7** open. **[GATE] E2.7** open. **[GATE] E3.6** open. E1 feel **signed**. Roadmap **approved**. Next build phase after gates: **E5 Content scale** (or play any open gate).

| Doc | Role |
|-----|------|
| `docs/BETA_E4_OPENING_CAST.md` | E4 contracts (code done; E4.7 gate open) |
| `docs/BETA_E3_ECONOMY.md` | E3 code done; E3.6 gate open |
| `docs/BETA_E2_COMBAT_HULL.md` | E2 code done; E2.7 gate open |
| `docs/BETA_ROADMAP.md` | Post-Alpha queue (approved) |
| `docs/gates.md` | E1 signed; E2.7 / E3.6 / E4.7 open |
| `docs/reputation_and_standing.md` | Standing law |

## Phase progress

| Phase | Status |
|-------|--------|
| E1 Legible Sector | **closed** (gate signed) |
| E2 Combat & hull | **code done** — gate open |
| E3 Economy pressure | **code done** — gate open |
| E4 Opening & cast | **code done** — gate open |
| E5 Content scale | not started |

## E4 contracts

| Contract | Status |
|----------|--------|
| E4.1 Life path data + apply | **done** |
| E4.2 Create UI | **done** |
| E4.3 Annexation beat | **done** |
| E4.4 Second recovery (Jax/Drift) | **done** |
| E4.5 Named presentation pass 2 | **done** |
| E4.6 Integration / save | **done** |
| **[GATE] E4.7 Opening feel** | **open** — `docs/gates.md` |

## What the game can do now

- **New Game:** create (origin/trade/mark) → annexation (“corridor claimed”) → fly tip → docked Alpha Port. Continue/load skips create + annexation.
- **Life path teeth:** 9 options; standing via StandingService; debt mark = Free Haulers loan.
- **Two recovery footholds:** Mendi (Reach docks) + Cut Jax (Drift / Beta docks).
- **Captain sheet:** path labels + credits/fuel/hull/debt/job.
- **Economy (E3):** undocked upkeep, loan, munitions contraband at Reach, smuggle jobs.
- **Combat/hull (E2):** skirmisher/gunboat, encounters, kill toast, Hauler/Fighter switch, 12-ship budget.
- **E1 sector:** 3 systems, 6 docks, courier + bounty + smuggle, trade, standing teeth, save/load.

## Evidence

- Lint green. GUT **478/478**.
- E4 tests: `test_e4_life_path`, `test_e4_create_ui`, `test_e4_opening`, `test_e4_recovery_jax`, `test_e4_integration`.
- HEAD at wrap will be current commit after push.

## Next session starts here

1. `/start` — confirm 478 green and gates still open.
2. **Play any open gate** (E2.7 / E3.6 / E4.7) when you want feel sign-off — scripts in `docs/gates.md`.
3. **Or build E5** Content scale (systems/stations/map toward multi-hour vetting) if driving phases without waiting on gates (same rule as this session).
4. Do not invent standing rules. Do not open Ops/Holding.

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1 feel signed; roadmap approved.
- Two-hull interlock thin proof shipped (E2).
- E3: upkeep undocked only; one Free Haulers loan; munitions Reach-only contraband; smuggle third job.
- E4: create → annexation → tip → dock; Continue skips opening; recovery budget 2 (Mendi + Jax).
- Never free() UI mid-pressed; free-fire aim on camera ray; bounty ensures prey in lock range.

## Session history

- **2026-07-31 (this wrap)** — E2 + E3 + E4 code complete in one drive; gates E2.7/E3.6/E4.7 open for later play.
- **2026-07-31** — E1 signed; E1 play fixes; Final Alpha signed earlier same day.
