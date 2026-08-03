# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **S0 complete.** **Outside review absorbed** into plan **v1.1**. **S1 ready** — **no code until Elliot says go**. Maturity = **tech demo**.

| Doc | Role |
|-----|------|
| `docs/STEAM_PHASE_PLAN.md` | **Build queue S0–S10** — v1.1 (Fable amendments) |
| `docs/PRODUCT_DIRECTION.md` | Steam 1.0 intent locks |
| `docs/reputation_and_standing.md` | Standing law |
| `docs/OUTSIDE_REVIEW_2026-08-02.md` | Fable findings (source of v1.1) |
| `docs/gates.md` | E6.6 signed; Steam gates TBD |

## Phase progress

| Phase | Status |
|-------|--------|
| E1–E6 (project labels) | **closed** — tech-demo shell |
| **S0** Plan freeze | **done** 2026-08-02 |
| Outside review (Fable) | **absorbed** 2026-08-02 → plan v1.1 |
| **S1** World clock & sim foundation | **ready** — blocked only on Elliot **go** |
| S2–S10 | queued after S1 (S2/S3 scopes thickened in v1.1) |

## What the game can do now

- Thin career shell: open, fly, dock, jobs, static trade, standing, combat, multi-system map, lived-in solids/sky/traffic.
- **Not yet:** world clock, economy sim, radiant jobs, Ops, campaign spine, Holding.

## Next session starts here

1. **`/start`** if cold — orient from this file + Steam plan v1.1.
2. When Elliot says **go** (or “go on S1” / “build S1”): implement **S1** per plan Phase S1 (WorldClock, not TimeScale reuse; CI; service registry; encoding fix; upkeep on clock).
3. Do **not** freestyle S2+ or Ops/Holding.
4. No invented standing rules.

### Locked decisions (review absorb)

- All 11 Fable amendments accepted.
- Combat: world clock always runs; combat caps time-scale to 1x only.
- Space events: **incidents** separate from MissionService; may promote to mission on accept.

## Standing decisions

- Steam plan accepted 2026-08-02; **v1.1 amendments** accepted 2026-08-02.
- Campaign through debts + Holding → sandbox; real economy sim; 30h/80h; space Skyrim under Freelancer filters.
- Story + dynamic economy unlocked for Steam plan only.
- E6.6 signed; product still thin.
- **S1 code requires explicit go** (planning complete is not a build order).

## Session history

- **2026-08-02 (plan absorb)** — Fable review → plan v1.1; all 11 amendments + combat/incident locks; S1 ready on go.
- **2026-08-02 (start)** — Fable review on disk; S1 blocked pending absorb.
- **2026-08-02 (wrap)** — S0 docs committed; Fable review pending.
- **2026-08-02 (S0)** — Steam product plan accepted; AGENTS authority → Steam queue.
- **2026-08-02 (product bar)** — E6.6 signed; PRODUCT_DIRECTION locked.
- **2026-08-02 (E6)** — Lived-in space closed.
- **2026-07-31–08-02** — E1–E5 closed.
