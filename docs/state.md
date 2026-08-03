# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S5 Session A code complete 2026-08-03** — ship layer
(weapons/equipment outfitting, sinks, perf probe, screenshot notes). Lint +
tests green after S5. Feel gate **open, not signed**. Maturity = **tech demo**.
Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; S2–S4 signed; **S5 feel gate open** |
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
| **S5** Ship layer | **Session A code done** 2026-08-03 — feel gate open; **Wallet split Session B still required before S6** |
| S6–S10 | queued (blocked on S5 gate + wallet split) |

## What the game can do now

- Everything from S4 (heat, customs, recovery, living boards, economy), **plus:**
- **Outfitting at stations** — 12 weapons, 10 equipment modules. Install/remove
  while docked; role gates (hauler vs fighter); sell-back at 50%.
- **Per-hull loadouts** saved under `ship.loadouts`. Empty hardpoint = hull
  baseline guns. Cargo racks raise hold; armor cuts incoming damage; fuel /
  thruster / afterburner modules stack as designed.
- **Money sinks** — outfit buy/sell tagged `outfit_buy` / `outfit_sell` on the
  money log. Fighter purchase + endgame guns are multi-start-wallet spends.
- **PerfProbe** — densest-scene FPS instrument (budget still 20 ships).

- **Not yet:** Ops, Holding, campaign spine, **WalletService split** (Session B),
  S5 feel gate signed, Steam-page art floor.

## Next session starts here

1. **Blocked on Elliot:** S5 feel gate — playtest brief in `docs/gates.md` (S5
   section). New Game; Outfitting; hauler racks vs fighter guns; save/load gear.
2. **Before S6:** **WalletService split** (Session B — money/debt vs fuel vs
   hull-condition). Do not start Ops on the god-wallet.
3. If **S5 pass**: mark gate, then Session B wallet split, then S6 per §22.
4. If **fail**: fix only what he named; re-run lint + tests; hand gate back.
5. Out of scope until authorized: Ops, campaign, standing law invention, raising
   the 20-ship budget.

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

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; S2–S4 signed; S5 gate open.

## Session history

- **2026-08-03 (S5A)** — Weapon/Equipment shapes; 12+10 content; ShipService
  loadouts + ShipOutfit; station Outfitting UI; damage/fuel mult wire; PerfProbe;
  screenshot floor doc; S5 feel gate open. Wallet split still required before S6.
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
