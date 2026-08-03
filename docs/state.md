# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S3a done 2026-08-03. S3b next** — space life + news
(incidents, news feed v1, traffic purpose lite). Maturity = **tech demo**.
Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; S2 economy feel signed; next Steam gate = **S3b** |

## Phase progress

| Phase | Status |
|-------|--------|
| E1–E6 (project labels) | **closed** — tech-demo shell |
| **S0** Plan freeze | **done** |
| Outside review | **absorbed** → plan v1.1 |
| Plan v1.2 model routing | **done** |
| **S1** World clock & sim foundation | **done** 2026-08-03 — lint + 595 tests green |
| **S2** Economy simulator | **done** 2026-08-03 — headless + feel gate signed |
| **S3a** Radiant work surface | **done** 2026-08-03 — lint + 699 tests green |
| S3b–S10 | queued (S3 human gate after S3b) |

## What the game can do now

- Everything from the tech-demo shell and S1/S2 economy, **plus:**
- **Living job boards** at every controlled dock. Boards restock on the world
  clock (same step math as the market: jump away-time and live time match).
- **Hand jobs + radiant fills.** A dock lists a mix of authored contracts and
  generated work driven by market shortages, local policing, and risk legs.
- **Escort jobs** end-to-end: accept → freighter appears in space → keep it
  alive → turn in at destination. Freighter death fails the job (standing hit).
- Accept works for **board offer ids** and legacy content template ids; one
  active mission still enforced. Radiant missions save/load fully.
- Courier / bounty / smuggle content jobs still work.

- **Not yet:** incidents, full news system, traffic purpose rewrite, Ops,
  campaign, Holding, black market (law change deferred), S3 feel gate.

## Next session starts here

1. Start **S3b**: opportunistic incidents (separate from the one-mission slot),
   news/rumor feed v1, traffic purpose lite.
2. **Do not** call the S3 human gate done until after S3b.
3. Out of S3b scope: Ops, campaign, inventing standing law, black market.
4. Design of record for economy still `docs/economy_sim.md`.

### Locked decisions

- All 11 Fable amendments accepted (plan v1.1).
- Combat: world clock always runs; combat caps time-scale to 1x only.
- Space events: incidents separate from MissionService (S3b).
- S1: `JUMP_AWAY_HOURS = 8.0`; bulk advance emits bus; live frames use category subscribers only.
- S3a: boards deterministic (no RNG); escort freighter is thin (spawn + die), not convoy AI.

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; product still thin until S3b+.

## Session history

- **2026-08-03 (S3a)** — Radiant work surface. BoardService autoload, WorldClock
  restock steps, RadiantJobGenerator (market + policing), MissionService runtime
  offers + save, escort kind + MissionEscortShip, UI labels. Adversary holes
  closed (board accept, escort spawn/death, market pay, CareerSave). 699 tests.
  S3 gate not signed.
- **2026-08-03 (S2 gate)** — Elliot signed economy feel; S3a authorized.
- **2026-08-03 (S2)** — Economy simulator. MarketService, per-station stock pricing,
  marginal ladder, production/consumption/freight on the world clock, trade UI with
  quantity + reason, news ticker, money telemetry, `market` save section. 677 tests.
  Adversary pass caught a live sell-then-buy money pump and a production taper that
  was silently starving 25 markets. Feel gate handed to Elliot.
- **2026-08-03 (S1)** — WorldClock, upkeep on clock, registry, CI, encoding; 595 tests; S2 Hard handoff.
- **2026-08-02 (wrap)** — Planning closed; plan v1.2; S1 ready on go.
- **2026-08-02 (v1.2)** — Model routing + kickoff prompts.
- **2026-08-02 (plan absorb)** — Fable → v1.1 amendments.
- **2026-08-02 (S0)** — Steam plan accepted.
- **2026-07-31–08-02** — E1–E6 closed.
