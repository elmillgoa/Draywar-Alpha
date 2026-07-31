# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A2 — Standing Core complete** (2026-07-31).

- Project skeleton ✓
- Strict typing ✓
- EventBus ✓ (A0–A2 standing/status/dock-refused catalogued)
- Data pipeline ✓ — ContentItem, StarSystem, Station, Hull, **Entity, Person, EntityLink**
- Content: 3 systems, Alpha Port, courier hull, **4 Entities, 12 People**
- Save schema v1 ✓ — envelope + optional `sections.standing`
- Debug console ✓ — includes `standing` commands
- Basic time control ✓
- **A1 flight:** mouse-aim courier, chase camera, throttle/strafe/afterburner, dock loop
- **A2 standing:** StandingService single writer; continuous −100..+100 + tiers; status moment on system/station entry (local controller only); docking refusal ≤ threshold; console set by value/tier; save/load standing section

**Next contract:** **A3 — Attribution & Everyday Change** (per `Alpha/ALPHA_PHASE_PLAN.md`)

## Proof (A2 acceptance)

| Criterion | Evidence |
|-----------|----------|
| Status moment on system + station entry (local controller only) | `test_system_enter_emits_status_moment`, `test_dock_emits_station_status_moment`, `test_status_for_*_uses_*_only`, `test_flight_hud_shows_status_moment` |
| Dock refused/allowed by standing | `test_can_dock_respects_threshold_and_nobody`, `test_docking_service_refuses_when_hostile`, `test_docking_service_allows_when_friendly` |
| Console drives standing; world reacts | `test_console_sets_entity_standing_by_value_and_tier` + dock/HUD tests |

## Gates

- `scripts/lint.ps1` exit 0
- GUT **139/139** pass (as of A2 close)
- A1 flight feel **signed** (2026-07-31)
- No human gate on A2

## Open decisions

- None blocking A3.
- Dock refusal default: standing **at or below −50** (Hostile) refuses; per-Entity override on content.
- Nobody controller: Uncontrolled / always allows dock.
- Standing save is optional section inside schema v1 (no envelope version bump).

## Standing decisions that bind upcoming work

- **This folder is the only build surface.** Greenfield Alpha. Older `Desktop\Draywar` may be mined; it is not this codebase.
- **Alpha is source of truth.** Full plan is after Final Alpha Gate.
- **Standing law:** `docs/reputation_and_standing.md`. Alpha population from Alpha Scope (4–6 / 12–18).
- **Godot 4.6.1** at `C:\Godot\`. Do not upgrade without asking.
- **MCP Pro proprietary** — `addons/godot_mcp/` gitignored.
- **Talk plain / short / blunt to Elliot.** Subagents build; main chat verifies.
- **Memory system on disk** — state + journal + traps + eras + compact hooks. Files beat chat memory.
- **Full phase per go.** "Go on Phase N / A0" means finish the whole phase, then stop.
- **Phase end = commit + wrap, automatic.** When phase is closed (DoD + verify; gates signed if any), commit, `/wrap` (push), last line exactly `Chat ready to close.` Do not wait for him to say wrap.
- **Save schema is v1.** Optional sections OK; envelope bump only with migration.
- **Flight feel:** good enough for Alpha; retune `BalanceFlight` later as visual assets land (not a gate reopen).

## Next session starts here

1. `/start` — orient; current position is **A2 complete**, next is **A3**.
2. If he says go on A3: combat attribution, mission standing outcomes, at least one mission type that moves standing.
3. Standing mutations only through StandingService + EventBus.

## Session history

- **2026-07-30** — Setup: greenfield project, tooling, skills, memory system.
- **2026-07-30** — A0 Foundation complete and pushed (`74d99f8`): data pipeline, save v1, console, time. GUT 93/93.
- **2026-07-30** — A1 Flight & One System implemented (mechanical). GUT 117/117.
- **2026-07-31** — A1 flight-feel gate signed; soft pass + camera fix. A1 closed. Next A2.
- **2026-07-31** — A2 Standing Core complete. GUT 139/139. Next A3.
