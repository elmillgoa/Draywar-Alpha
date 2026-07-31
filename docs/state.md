# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A1 — Flight & One System built. Awaiting [GATE: ELLIOT] flight feel.**

- Project skeleton ✓
- Strict typing ✓
- EventBus ✓ (A0 + A1 flight/dock signals catalogued)
- Data pipeline ✓ — ContentItem, StarSystem, Station, Hull; ContentLibrary; 3 systems (alpha playable)
- Save schema v1 ✓ — envelope only; flight state is session-only (no schema change)
- Debug console ✓
- Basic time control ✓
- **A1 flight:** mouse-aim courier, chase camera, throttle/strafe/afterburner
- **A1 world:** Alpha Reach gray-box with station (Alpha Port) + gate mesh (visual only)
- **A1 dock loop:** approach prompt → F dock → station menu Undock/Launch → free flight
- **A1 HUD:** system name, speed, throttle, dock prompt / docked status

**Next:** Human flight-feel gate, then A2 once signed.

## Proof (A1 acceptance — mechanical)

| Criterion | Evidence |
|-----------|----------|
| Mouse-aim flight, one ship profile | `PlayerShip` + `hull_courier.tres`; `FlightMath` tests; throttle bus test |
| One system with station + gate | `system_alpha.tres` station + gate dest; `SystemWorld.build` places station; content tests |
| Fly → dock → undock loop | `test_a1_play_loop.gd`: range scan + F dock + menu Launch undock; `DockingController` SM |
| Chase camera + readable HUD | `ChaseCamera`; `FlightHUD` system name test; HUD listens to bus |
| No combat | Not implemented |
| Controllable / not nauseating | **[GATE: ELLIOT] open** — human only |

## Gates

- `scripts/lint.ps1` exit 0
- GUT **117/117** pass
- Adversary: weak bus-echo tests replaced by producer loop tests; HUD boot-order fixed (UI before `build()`)
- **Open:** Elliot confirms basic flight is not nauseating and is controllable

## Open decisions

- None blocking the flight-feel gate.

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
- **Save schema is v1.** Bump only with a migration step when real sections arrive.

## Next session starts here

1. **[GATE: ELLIOT] flight feel** — play fly → dock → undock; confirm controllable and not nauseating.
2. If gate fails: retune `BalanceFlight` (turn rate, camera lag, speeds) and re-gate.
3. If gate passes: record in `docs/gates.md` + journal; mark A1 closed; wrap; next is **A2 — Standing Core**.

## Session history

- **2026-07-30** — Setup: greenfield project, tooling, skills, memory system.
- **2026-07-30** — A0 Foundation complete and pushed (`74d99f8`): data pipeline, save v1, console, time. GUT 93/93.
- **2026-07-30** — A1 Flight & One System implemented (mechanical). Awaiting flight-feel gate. GUT 117/117.
