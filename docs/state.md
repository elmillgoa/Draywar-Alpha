# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S2 code complete — Elliot's feel gate is OPEN.** Every headless
criterion in plan §5.6 is green (72 test scripts, 677 tests, lint clean, pushed as
`3963d84`). Nothing else starts until Elliot plays the trade route and passes or fails
it. Maturity = **tech demo**. Elliot = playtest + ideas only; LLMs program everything.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.2; **§22 model routing** |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (v1.1 source) |
| `docs/gates.md` | E6.6 signed; first Steam play gate = **S2** |

## Phase progress

| Phase | Status |
|-------|--------|
| E1–E6 (project labels) | **closed** — tech-demo shell |
| **S0** Plan freeze | **done** |
| Outside review | **absorbed** → plan v1.1 |
| Plan v1.2 model routing | **done** |
| **S1** World clock & sim foundation | **done** 2026-08-03 — lint + 595 tests green |
| **S2** Economy simulator | **code complete** 2026-08-03 — lint + 677 tests green; **feel gate open** |
| S3–S10 | queued after the S2 gate is signed |

## What the game can do now

- Everything from the tech-demo shell, **plus:**
- Real **WorldClock** (elapsed game time, independent of ship physics / world teardown)
- Wallet **upkeep** ticks on the clock (not the ship); jump advances **8 hours** away-time
- `world_clock` save section round-trips
- **ServiceRegistry** for career reset
- **CI** on push (GitHub Actions GUT)
- Encoding cleanup on station recovery button + gates doc

- A **living economy**. Stations are economic actors: every dock holds real stock of
  each good, and the price it quotes comes from that stock against what the station
  wants. The old per-system price table is deleted.
- **Buying moves the price** while you buy — a trade walks the shelf a unit at a time,
  so twenty units cost more than twenty times the first one. Same in reverse when
  selling. A buy-then-sell or sell-then-buy at one dock always loses money.
- **The sector runs without you.** Stations produce and consume on the world clock;
  background freight relays goods up to four gates, weakening with distance, and is
  deliberately too weak to satisfy demand — the far spur always pays a premium.
- **Two docks in one system quote different prices** for the same good (Alpha Yard
  sells alloy at 28, Alpha Port buys it at 56).
- Trade screen with a **quantity control**, live quoted total, stock, and a per-row
  **reason line** ("Made here — 200 in stock, wants 100"). One-line **news ticker**.
- **Money telemetry** — every credit movement logged to
  `user://telemetry/money_events.csv`, tagged by activity. Balance fuel for S9.
- `market` **save section**, byte-deterministic, coupled to the world clock.

- **Not yet:** radiant jobs, Ops, campaign, Holding, black-market stock (deliberately
  deferred — it is a law change, see `docs/economy_sim.md` §3).

## Next session starts here

1. **The S2 feel gate is open and blocks everything.** Do not start S3.
2. If Elliot has **passed** it: mark the gate in `docs/gates.md`, set S2 done above,
   then open a **Standard-tier** chat and paste `docs/STEAM_PHASE_PLAN.md` §22.6 S3a.
3. If Elliot has **failed** it: fix only what he named, re-run lint + tests, hand the
   gate back. Do not redesign the economy off one playtest note.
4. The playtest route and what to look for are in the gate report; the design of
   record is `docs/economy_sim.md`.
5. No invented standing rules. Black market stays deferred until a phase owns the law.

### Locked decisions

- All 11 Fable amendments accepted (plan v1.1).
- Combat: world clock always runs; combat caps time-scale to 1x only.
- Space events: incidents separate from MissionService (S3).
- S1: `JUMP_AWAY_HOURS = 8.0`; bulk advance emits bus; live frames use category subscribers only.

## Standing decisions

- Steam plan v1.2 is the build queue.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h.
- E6.6 signed; product still thin until S2+.

## Session history

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
