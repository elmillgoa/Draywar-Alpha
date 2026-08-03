# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S3b done 2026-08-03. S3 feel gate open (not signed)** —
space life + news shipped; Elliot playtest + external playtest planning next.
Maturity = **tech demo**. Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; S2 signed; **S3 feel gate open (not signed)** |

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
| **S3b** Space life + news | **done** 2026-08-03 — lint + 717 tests; gate open, not signed |
| S4–S10 | queued |

## What the game can do now

- Everything from S3a (living boards, radiant jobs, escort), **plus:**
- **Opportunistic incidents** in free flight (distress, intercept, customs light).
  Separate from the one-mission slot. Help on distress promotes to a short
  mission when free; if a mission is already active, help still pays a small
  credit reward without clobbering the job.
- **Customs light** in patrolled space when you hold restricted cargo: cooperate
  reuses the existing contraband fine/seize path; same trip does not double-punish
  at the dock.
- **News feed thickened** — market shortage/glut plus policing lines and real
  incident echoes on one ticker; flight toast while undocked.
- **Traffic purpose lite** — some freighters dock/undock cycle; when a station is
  short, one freighter retasks toward it. Escort freighter death still only fails
  escort missions (ambient traffic does not).

- **Not yet:** Ops, campaign, inventing standing law, black market, S4 full patrol,
  S3 feel gate signed.

## Next session starts here

1. **Elliot S3 feel gate** — playtest brief in `docs/gates.md` (S3 section).
2. After gate: plan **external strangers** touch before trusting 30h claims.
3. Then S4 (enforcement & standing career surface) per plan — Hard tier.
4. Out of scope until authorized: Ops, campaign, standing law invention.

### Locked decisions

- All 11 Fable amendments accepted (plan v1.1).
- Combat: world clock always runs; combat caps time-scale to 1x only.
- Space events: incidents separate from MissionService (S3b) — promote optional.
- S1: `JUMP_AWAY_HOURS = 8.0`; bulk advance emits bus; live frames use category subscribers only.
- S3a: boards deterministic (no RNG); escort freighter is thin (spawn + die).
- S3b: distress help with active mission = wallet pay only (no standing invent);
  offered incidents expire on load; customs same-trip skip after cooperate.

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; S2 signed; S3 gate open.

## Session history

- **2026-08-03 (S3b)** — Space life + news. IncidentService autoload, distress/
  intercept/customs, promote-to-mission path, MarketNews thickened, traffic
  purpose lite, FlightHUD news/incident toast, save steps-only expire-on-load.
  S3 gate playtest brief written; **not signed**.
- **2026-08-03 (S3a)** — Radiant work surface. BoardService, RadiantJobGenerator,
  escort, MissionService runtime. 699 tests. S3 gate not signed.
- **2026-08-03 (S2 gate)** — Elliot signed economy feel; S3a authorized.
- **2026-08-03 (S2)** — Economy simulator. 677 tests. Feel gate signed.
- **2026-08-03 (S1)** — WorldClock; 595 tests.
- **2026-08-02** — Plan freeze / v1.1 / v1.2 routing.
- **2026-07-31–08-02** — E1–E6 closed.
