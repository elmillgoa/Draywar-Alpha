# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S1 complete** (WorldClock & sim foundation). **S2 next** — economy sim — **Hard-tier model** per plan §22. Maturity = **tech demo**. Elliot = playtest + ideas only; LLMs program everything.

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
| **S2** Economy simulator | **next** — open **Hard** chat; paste §22.6 S2 |
| S3–S10 | queued after S2 |

## What the game can do now

- Everything from the tech-demo shell, **plus:**
- Real **WorldClock** (elapsed game time, independent of ship physics / world teardown)
- Wallet **upkeep** ticks on the clock (not the ship); jump advances **8 hours** away-time
- `world_clock` save section round-trips
- **ServiceRegistry** for career reset
- **CI** on push (GitHub Actions GUT)
- Encoding cleanup on station recovery button + gates doc

- **Not yet:** living economy / MarketService, radiant jobs, Ops, campaign, Holding.

## Next session starts here

1. **`/start`** if cold.
2. Open a **new Hard-tier** chat (Claude Opus or strongest reasoning coding model).
3. Paste **`docs/STEAM_PHASE_PLAN.md` §22.6 S2** kickoff prompt; say go.
4. Do **not** freestyle S3+. No invented standing rules.
5. S2 has an **Elliot feel gate** when code claims green: trade route / market fights back.

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

- **2026-08-03 (S1)** — WorldClock, upkeep on clock, registry, CI, encoding; 595 tests; S2 Hard handoff.
- **2026-08-02 (wrap)** — Planning closed; plan v1.2; S1 ready on go.
- **2026-08-02 (v1.2)** — Model routing + kickoff prompts.
- **2026-08-02 (plan absorb)** — Fable → v1.1 amendments.
- **2026-08-02 (S0)** — Steam plan accepted.
- **2026-07-31–08-02** — E1–E6 closed.
