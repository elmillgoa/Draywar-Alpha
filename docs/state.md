# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E6.5 Integration complete** (impact retune + cold-path tests). Next: **E6.6 human gate** (do not sign until played).

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
| E6 Lived-in space | **E6.5 done** — next **E6.6 [GATE]** |

## What the game can do now

- Full E4–E5 slice plus solid space (E6.1), lived-in sky (E6.2), attackable traffic (E6.3), density (E6.4), and **integration retune** (E6.5).
- Soft bump + impact damage by mass class; layout pad→gate ≥ 1200 m.
- **Impact threshold 14 m/s** — undock cruise (~10.5 m/s) is bump-only; deliberate ram still hurts; station > light freighter.
- Every system has a sun cue + at least one planet-scale body; layouts differ.
- **Tab locks any live ship in range** (traffic + pirates). Bolts and rams damage traffic to 0 hull → despawn.
- Lock line shows role: **Civilian / Patrol / Pirate**.
- Traffic kills use **AttributionService** only (same law as combat).
- **Ship budget 20** (player + traffic + hostiles). Densest contested: 1 + 16 traffic + 3 hostiles = 20.
- Patrolled Alpha: **16** traffic (floor ≥12 non-player), 0 hostiles. Lawless: **10** traffic + ≤3 hostiles.
- Dual-dock systems park ~25% of traffic on secondary pads (local orbit).
- Opening cast + Continue skip, E3 money teeth, E2 lead/bolts fairness still hold under E6.

## Evidence

- Lint green. GUT **571/571** after E6.5 (+11 integration tests).
- New: `tests/test_e6_integration.gd`; `IMPACT_SPEED_THRESHOLD` 8 → **14**.

## Next session starts here

1. `/start` — confirm green; position = **E6.5 complete**, next **E6.6 human gate**.
2. Run **E6.6** play script from `docs/gates.md` — human feel only; **do not auto-sign**.
3. No Ops/Holding. No invented standing rules. Do not open Ops to “fix” empty space if gate refuses.

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1–E5 feel gates all signed (E5.7 on 2026-08-02).
- E6 locks: soft bump; damage scales by obstacle mass class; order A→C→B→D; perf cap 20 ships; celestials are backdrop not landing; every ship attackable after Package B.
- Ramming kills use existing attribution (live as of E6.3).
- Density raised deliberately; if 20 fails do not silently drop — report and stop.
- E6.5: casual undock/dock approach below impact threshold; deliberate high-speed ram still damages.

## Session history

- **2026-08-02 (E6.5)** — Integration: impact threshold 14 m/s; cold-path GUT; opening/E2/E3 hold asserts; no Ops/Holding.
- **2026-08-02 (E6.4)** — Density: PERF_BUDGET 20; traffic 16/16/10; secondary-dock orbits; density floors.
- **2026-08-02 (E6.3)** — Every ship a target: TrafficShip HP/roles, GROUP_LOCKABLE, attribution on traffic kill.
- **2026-08-02 (E6.2)** — Lived-in sky: sun disc, per-system planets/moons, belt rocks.
- **2026-08-02 (E6.1)** — Solid space: colliders, soft bump, impact damage, layout stretch, ecology.
- **2026-08-02 (E6 plan)** — E5.7 signed; E6 Lived-in space plan locked (A→C→B→D).
- **2026-08-02 (opening scroll)** — Create/annexation scroll + pin footer; unblocked play.
- **2026-08-02 (E5.2–E5.6)** — Content pack, branch graph, logistics, sector map, integration.
- **2026-08-02 (E5.1)** — Content budget lift 8/10/24.
- **2026-07-31 (E5 plan)** — Locked plan; gates E2–E4 signed same day.
