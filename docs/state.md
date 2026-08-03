# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S4 code complete 2026-08-03** — Enforcement & standing
career surface. Lint green, **726 tests**. Feel gate **open, not signed**.
Maturity = **tech demo**. Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; S2–S3 signed; **S4 feel gate open** |

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
| **S4** Enforcement & standing surface | **code done** 2026-08-03 — feel gate open |
| S5–S10 | queued |

## What the game can do now

- Everything from S3 (living boards, radiant jobs, escort, incidents, news,
  traffic purpose), **plus:**
- **Per-Entity heat** (not global wanted). Crime in patrolled space raises heat
  on the enforcer (e.g. Reach in Alpha). Lawless (Gamma) adds **no** heat.
- **Customs flee** raises heat; **[1]/[2]** answer free-flight incident prompts.
- **Pressure / hunt** in patrolled systems only — more intercepts; high heat can
  force a patrol-response intercept ("you are wanted here").
- **Four recovery chains** — Mendi/Reach, Jax/Drift, Wren/Haulers, Kade/Fringe.
- **Network betrayal lite** — betraying a contact nicks their network personally
  (small hit; does not close them).
- Standing still only via StandingService. Status moment unchanged.

- **Not yet:** Ops, Holding, campaign spine, economy redesign, inventing standing
  law, S4 feel gate signed.

## Next session starts here

1. **Blocked on Elliot:** S4 feel gate — playtest brief in `docs/gates.md` (S4
   section). New Game; try crime in Alpha vs Gamma; customs [1]/[2]; recovery.
2. If **pass**: mark gate in `docs/gates.md`, set S4 done, then open next phase
   per `docs/STEAM_PHASE_PLAN.md` §22.
3. If **fail**: fix only what he named; re-run lint + tests; hand gate back.
4. Out of scope until authorized: Ops, campaign, standing law invention.

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

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; S2–S3 signed; S4 gate open.

## Session history

- **2026-08-03 (S4)** — EnforcementService + BalanceEnforcement; heat from kill /
  customs flee / contraband; pressure/hunt in IncidentService; customs [1]/[2]
  on FlightHUD; Wren + Kade recovery chains; network betrayal lite; save section
  `enforcement`. S4 feel gate open, not signed.
- **2026-08-03 (wrap)** — S2 signed + full S3 code (a+b) pushed; S3 feel gate
  later signed same day.
- **2026-08-03 (S3b)** — Space life + news. IncidentService, MarketNews, traffic.
- **2026-08-03 (S3a)** — Radiant work surface.
- **2026-08-03 (S2)** — Economy simulator. Feel gate signed.
- **2026-08-03 (S1)** — WorldClock.
- **2026-08-02** — Plan freeze / v1.1 / v1.2 routing.
- **2026-07-31–08-02** — E1–E6 closed.
