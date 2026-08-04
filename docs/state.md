# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S8 code complete 2026-08-04** — Holding path + Act III
spines + ignition (feel gate open). Maturity = **tech demo**.
Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; S2–**S7** signed |
| `docs/S8_ENDGAME_PLAYTEST.md` | Holding / climax / sandbox brief (**gate open**) |
| `docs/S7_COLD_START_PLAYTEST.md` | Story / freeroam + cold-start brief (gate closed) |
| `docs/S6_OPS_PLAYTEST.md` | Ops feel playtest brief (gate closed) |
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
| **S6** Operations | **done** 2026-08-04 — code + Ops feel signed |
| **S7** Campaign I–II | **done** 2026-08-04 — code + feel gate signed |
| **S8** Holding + Act III | **code complete** 2026-08-04 — **feel gate open** |
| S9–S10 | queued |

## What the game can do now

- Everything from S7 (campaign I–II, journal, Story UI, ops, economy…), **plus:**
- **Act III spine** — 5 Holding milestones + 2 ignition crises (Epsilon / Zeta).
- **Holding purchase** — candidates Epsilon Belt / Zeta Spur; debt clear; milestones
  cut price; station **Holding** UI; player Holding entity + status moment override.
- **Ignition** — authored contest mission after claim (not buy-as-ending); epitaph.
- **Sandbox continue** — boards/markets/Ops still live after `flag_campaign_complete`.
- **Save** — `campaign.holding` keys + controller override reapplied on load.

- **Not yet:** S8 feel gate; Steam-page art floor; content fill (S9).

## Next session starts here

1. **S8 feel gate** — Elliot playtests `docs/S8_ENDGAME_PLAYTEST.md` (endgame + rhyme).
2. After gate: S9 content complete when authorized.
3. Out of scope: standing law invention, empire sim, ship budget raise.

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
- S7: spine = ContractType flags (not second mission slot); debt beat does **not**
  hard-require open loan (clean life path); lane exclusivity; ops intro needs any
  lane + Friendly Reach.
- S8: Holding candidates Epsilon/Zeta; milestones pay via price cut; debt clear for
  purchase + ignition; purchase requires docked at candidate; ignition is dual-path
  crisis (papers if prior Neutral+, force bounty if contested + Friendly Haulers/Reach
  backing) not buy button; controller override via StandingService only; owner
  dock_refusal -100.

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; S2–**S7** signed. **S8 feel gate open** (endgame + structural rhyme).

## Session history

- **2026-08-04 (S8 code)** — BalanceHolding, CampaignService purchase/ignition,
  station controller overrides, Act III spines + player Holding entity, Station
  Holding UI, tests, S8_ENDGAME_PLAYTEST. **S8 feel gate open.**
- **2026-08-04 (S7 gate)** — Elliot signed S7 cold start / story-freeroam (“Pass”).
  S7 phase closed. S8 queued until authorized.
- **2026-08-04 (S7 code)** — CampaignService + spine ContractType fields; 9 Act
  I–II beats; journal + station Story UI; CareerSave `campaign`; board hand skips
  spine; tests + cold-start brief. **S7 feel gate open.**
- **2026-08-04 (S6 gate + S7 start)** — Elliot signed S6 Ops feel. S7 authorized
  full (framework + content this chat unless Content tier forced).
- **2026-08-03 (S6)** — OperationService: hire/fire, upkeep, orders, warehouse,
  standing charter breach, CareerSave `operation`, station Ops UI, 18 ops tests
  (adversary-hardened). Lint green; full suite green.
- **2026-08-03 (S5B)** — WalletService split: WalletService (credits/debt),
  FuelService, HullConditionService. Single save key `wallet` via CareerSave
  merge. Callers + tests updated. Lint/tests green.
- **2026-08-03 (S5A)** — Weapon/Equipment shapes; 12+10 content; ShipService
  loadouts + ShipOutfit; station Outfitting UI; damage/fuel mult wire; PerfProbe;
  screenshot floor doc.
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
