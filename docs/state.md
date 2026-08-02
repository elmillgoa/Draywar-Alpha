# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E6.2 Package C complete** (celestial sky: sun disc, planets, moons, belt rocks). Next: **E6.3 Package B** (every ship a target — lock/fire traffic) unless told otherwise.

| Doc | Role |
|-----|------|
| `docs/BETA_E6_LIVED_IN_SPACE.md` | **E6 plan** — authority for this phase |
| `docs/gates.md` | E5.7 signed; E6.6 play script ready |
| `docs/BETA_ROADMAP.md` | Post-Alpha queue |
| `docs/reputation_and_standing.md` | Standing law |

## Phase progress

| Phase | Status |
|-------|--------|
| E1 Legible Sector | **closed** (gate signed) |
| E2 Combat & hull | **closed** (gate signed 2026-07-31) |
| E3 Economy pressure | **closed** (gate signed 2026-07-31) |
| E4 Opening & cast | **closed** (gate signed 2026-07-31) |
| E5 Content scale | **closed** (E5.7 signed 2026-08-02) |
| E6 Lived-in space | **E6.2 done** — next E6.3 lock/kill traffic |

## What the game can do now

- Full E4–E5 slice plus **solid space** (E6.1) and **lived-in sky** (E6.2).
- Soft bump + impact damage by mass class; layout pad→gate ≥ 1200 m.
- Every system has a sun cue + at least one planet-scale body; layouts differ (Alpha twin ice + moon, Epsilon belt rocks, Zeta single ash world, etc.).
- Belt rocks (Gamma sparse / Epsilon dense) use mass class `rock` and static colliders; far from pad/gate.
- Ship budget still **12**. Traffic not lock/kill yet (E6.3). Density 20 is E6.4.

## Evidence

- Lint green. GUT **541/541** after E6.2 (+6 sky tests).
- New: `src/world/CelestialSky.gd`, `tests/test_e6_sky.gd`; celestial tables in `BalanceFlight`.

## Next session starts here

1. `/start` — confirm green; position = **E6.2 complete**, next **E6.3**.
2. Build **E6.3** (Package B — every ship a target) only unless told to continue the phase.
3. Package order locked: **A → C → B → D** → E6.5 → E6.6 gate.
4. No Ops/Holding. No invented standing rules.

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1–E5 feel gates all signed (E5.7 on 2026-08-02).
- E6 locks: soft bump; damage scales by obstacle mass class; order A→C→B→D; perf cap 20 ships; celestials are backdrop not landing; every ship attackable after Package B.
- Ramming kills use existing attribution when B is live.

## Session history

- **2026-08-02 (E6.2)** — Lived-in sky: sun disc, per-system planets/moons, belt rocks.
- **2026-08-02 (E6.1)** — Solid space: colliders, soft bump, impact damage, layout stretch, ecology.
- **2026-08-02 (E6 plan)** — E5.7 signed; E6 Lived-in space plan locked (A→C→B→D).
- **2026-08-02 (opening scroll)** — Create/annexation scroll + pin footer; unblocked play.
- **2026-08-02 (E5.2–E5.6)** — Content pack, branch graph, logistics, sector map, integration.
- **2026-08-02 (E5.1)** — Content budget lift 8/10/24.
- **2026-07-31 (E5 plan)** — Locked plan; gates E2–E4 signed same day.
