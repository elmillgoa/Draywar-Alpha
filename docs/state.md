# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A1 — Flight & One System complete** (gate signed 2026-07-31).

- Project skeleton ✓
- Strict typing ✓
- EventBus ✓ (A0 + A1 flight/dock signals catalogued)
- Data pipeline ✓ — ContentItem, StarSystem, Station, Hull; ContentLibrary; 3 systems (alpha playable)
- Save schema v1 ✓ — envelope only; flight state is session-only
- Debug console ✓
- Basic time control ✓
- **A1 flight:** mouse-aim courier, chase camera, throttle/strafe/afterburner
- **A1 world:** Alpha Reach gray-box with station (Alpha Port) + gate mesh (visual only)
- **A1 dock loop:** approach prompt → F dock → station menu Undock/Launch → free flight
- **A1 HUD:** system name, speed, throttle, dock prompt / docked status
- **A1 gate:** flight feel signed — good enough to move on; fine-tune later with art

**Next contract:** **A2 — Standing Core** (per `Alpha/ALPHA_PHASE_PLAN.md`)

## Proof (A1 acceptance)

| Criterion | Evidence |
|-----------|----------|
| Mouse-aim flight, one ship profile | `PlayerShip` + `hull_courier.tres`; `FlightMath` tests |
| One system with station + gate | `system_alpha.tres`; `SystemWorld.build`; content tests |
| Fly → dock → undock loop | `test_a1_play_loop.gd`; `DockingController` SM |
| Chase camera + readable HUD | `ChaseCamera` (real-frame lag); `FlightHUD` |
| Controllable / not nauseating | **[GATE: ELLIOT] signed** — attempt 2, `docs/gates.md` |

## Gates

- `scripts/lint.ps1` exit 0
- GUT **117/117** pass (as of A1 close)
- A1 flight feel **signed** (2026-07-31)

## Open decisions

- None blocking A2.

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
- **Flight feel:** good enough for Alpha; retune `BalanceFlight` later as visual assets land (not a gate reopen).

## Next session starts here

1. `/start` — orient; current position is **A1 complete**, next is **A2**.
2. If he says go on A2 / Phase 2: finish **entire A2** (Entities, People, standing service, status moment, docking refusal). Subagents build.
3. Standing rules only from `docs/reputation_and_standing.md` — do not invent.

## Session history

- **2026-07-30** — Setup: greenfield project, tooling, skills, memory system.
- **2026-07-30** — A0 Foundation complete and pushed (`74d99f8`): data pipeline, save v1, console, time. GUT 93/93.
- **2026-07-30** — A1 Flight & One System implemented (mechanical). GUT 117/117.
- **2026-07-31** — A1 flight-feel gate signed; soft pass + camera fix. A1 closed. Next A2.
