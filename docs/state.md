# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S6 code complete 2026-08-03** — Operations layer.
**Ops feel gate OPEN** (not signed). Maturity = **tech demo**.
Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; S2–S5 signed; **S6 open** |
| `docs/S6_OPS_PLAYTEST.md` | Ops feel playtest brief |
| `docs/S5_SCREENSHOT_FLOOR.md` | Honest gray-box presentation inventory |

## Phase progress

| Phase | Status |
|-------|--------|
| E1–E6 (project labels) | **closed** — tech-demo shell |
| **S0** Plan freeze | **done** |
| Outside review | **absorbed** → plan v1.1 |
| Plan v1.2 model routing | **done** |
| **S1** World clock & sim foundation | **done** 2026-08-03 |
| **S2** Economy simulator | **done** 2026-08-03 — headless + feel gate signed |
| **S3a** Radiant work surface | **done** 2026-08-03 |
| **S3b** Space life + news | **done** 2026-08-03 — gate signed |
| **S4** Enforcement & standing surface | **done** 2026-08-03 — gate signed |
| **S5** Ship layer | **done** 2026-08-03 — Sessions A+B + feel gate signed |
| **S6** Operations | **code complete** 2026-08-03 — **Ops feel gate open** |
| S7–S10 | queued (after S6 gate) |

## What the game can do now

- Everything from S5 (outfitting, loadouts, split wallet, heat/customs/recovery,
  living boards, economy, space life), **plus:**
- **Operations** — hire up to 2 abstract ships (hauler / escort) at a Friendly
  dock; fire; retainer upkeep every game-hour (docked or free-fly).
- **Orders** — park, haul route (MarketService buy origin / sell dest), escort
  player (label only — no combat spawn).
- **Warehouse** — off-ship cargo per station (40 volume); deposit/withdraw while
  docked.
- **Standing-gated hire** — needs Friendly with dock controller; 3 missed upkeep
  cycles → charter breach standing hit + ship released (StandingService only).
- **Save** — optional `operation` section (fleet + warehouse).
- **Station UI** — Operations section (dashboard, hire/fire, orders, warehouse).

- **Not yet:** Ops feel signed; campaign spine; Holding; Steam-page art floor.

## Next session starts here

1. **S6 Ops feel gate** — play `docs/S6_OPS_PLAYTEST.md`; Elliot signs or rejects.
2. After sign: **S7** campaign framework — follow `docs/STEAM_PHASE_PLAN.md` §22.
3. Out of scope until authorized: standing law invention, raising the 20-ship
   budget, empire sim.

### Locked decisions

- All 11 Fable amendments accepted (plan v1.1).
- Combat: world clock always runs; combat caps time-scale to 1x only.
- Space events: incidents separate from MissionService (S3b) — promote optional.
- S1: `JUMP_AWAY_HOURS = 8.0`; bulk advance emits bus; live frames use category subscribers only.
- S3a: boards deterministic (no RNG); escort freighter is thin (spawn + die).
- S3b: distress help with active mission = wallet pay only (no standing invent);
  offered incidents expire on load; customs same-trip skip after cooperate.
- S4: heat per-Entity; pressure/hunt only in patrolled; no standing writes from
  EnforcementService; recovery budget 4.
- S5: slots by role (BalanceOutfit), not hull fields; hull weapon fields = baseline
  when no weapon installed; 20-ship budget unchanged without evidence.
- S6: fleet abstract (no world spawn); max 2; hire standing = Friendly floor
  (`TIER_FRIENDLY_MIN`); haul is market buy/sell legs not MissionService.

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; S2–S5 signed; S6 feel open.

## Session history

- **2026-08-03 (S6)** — OperationService: hire/fire, upkeep, orders, warehouse,
  standing charter breach, CareerSave `operation`, station Ops UI, 18 ops tests
  (adversary-hardened). Lint green; full suite green. **Ops feel gate open.**
- **2026-08-03 (S5B)** — WalletService split: WalletService (credits/debt),
  FuelService, HullConditionService. Single save key `wallet` via CareerSave
  merge. Callers + tests updated. Lint/tests green. S5 feel gate still open.
- **2026-08-03 (S5A)** — Weapon/Equipment shapes; 12+10 content; ShipService
  loadouts + ShipOutfit; station Outfitting UI; damage/fuel mult wire; PerfProbe;
  screenshot floor doc; S5 feel gate open.
- **2026-08-03 (S4)** — EnforcementService + heat / pressure / recovery lift.
  Feel gate signed same day.
- **2026-08-03 (wrap)** — S2 signed + full S3 code (a+b) pushed; S3 feel gate
  later signed same day.
- **2026-08-03 (S3b)** — Space life + news. IncidentService, MarketNews, traffic.
- **2026-08-03 (S3a)** — Radiant work surface.
- **2026-08-03 (S2)** — Economy simulator. Feel gate signed.
- **2026-08-03 (S1)** — WorldClock.
- **2026-08-02** — Plan freeze / v1.1 / v1.2 routing.
- **2026-07-31–08-02** — E1–E6 closed.
