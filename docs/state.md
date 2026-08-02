# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E5 code complete (E5.1–E5.6).** Next: **[GATE] E5.7 Content scale feel** — needs Elliot play + sign.

| Doc | Role |
|-----|------|
| `docs/BETA_E5_CONTENT_SCALE.md` | **E5 plan** — E5.1–E5.6 code done; E5.7 open |
| `docs/gates.md` | E5.7 play script + attempt log |
| `docs/BETA_ROADMAP.md` | Post-Alpha queue |
| `docs/reputation_and_standing.md` | Standing law |

## Phase progress

| Phase | Status |
|-------|--------|
| E1 Legible Sector | **closed** (gate signed) |
| E2 Combat & hull | **closed** (gate signed 2026-07-31) |
| E3 Economy pressure | **closed** (gate signed 2026-07-31) |
| E4 Opening & cast | **closed** (gate signed 2026-07-31) |
| E5 Content scale | **code complete** — gate E5.7 open |

## What the game can do now

- Full E4 slice plus **6 systems** (Alpha–Zeta), **10 stations**, branched gates (Beta hub to Delta; Gamma→Epsilon→Zeta).
- **Long-haul jobs** (Reach→Zeta, Fringe→Delta Yard) and **trade contrast** grain Alpha buy → Zeta sell.
- **Sector chart:** open with **M** in flight or **Sector map** on pause — all systems, gate links, current highlight.
- Compact text NAV strip still on flight HUD. No Ops/Holding. Status moment still local controller only.

## Evidence

- Lint all gates green. GUT **507/507** at E5.6 complete.
- E5.1–E5.6 tests: `test_e5_content_budget`, `test_e5_content_pack`, `test_e5_gate_graph`, `test_e5_logistics`, `test_e5_map_nav`, `test_e5_integration`.

## Next session starts here

1. `/start` — confirm green; position = E5 code complete, **gate E5.7**.
2. **Play E5.7** per `docs/gates.md` — long session, routes, map, “big enough without Ops?”
3. Sign or refuse; if refuse, iterate E5.1–E5.6 only (no Ops early).
4. Do not invent standing rules. Do not open Ops/Holding early.

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1–E4 feel gates all signed 2026-07-31.
- E5 locks: ship **6** systems (budget 8), ~10 stations, branched graph, functional map, no new job kind.
- Budgets: systems 8 / stations 10 / people 24.
- Map: M key + pause button; no click-to-jump.

## Session history

- **2026-08-02 (E5.2–E5.6)** — Content pack, branch graph, logistics, sector map, integration; code complete pending E5.7.
- **2026-08-02 (E5.1)** — Content budget lift 8/10/24.
- **2026-07-31 (E5 plan)** — Locked plan; gates E2–E4 signed same day.
