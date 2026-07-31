# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A0 — Foundation complete.**

- Project skeleton ✓
- Strict typing ✓
- EventBus ✓ (A0 signals catalogued)
- Data pipeline ✓ — ContentItem, StarSystem (full-sized), ContentLibrary, 3 empty gray-box systems
- Save schema v1 ✓ — envelope + binary codec + empty migrations + SaveService
- Debug console ✓ — ConsoleService + DebugConsole (backtick)
- Basic time control ✓ — TimeScale autoload, combat lock, load reset
- Acceptance: empty systems load, console sets time, save/load byte-exact round-trip

**Next contract:** **A1 — Flight & One System** (per `Alpha/ALPHA_PHASE_PLAN.md`)

## Proof (A0 acceptance)

| Criterion | Evidence |
|-----------|----------|
| Empty systems can load | 3 `.tres` under `src/data/content/star_systems/`; `test_content_library.gd` (shipped valid + discovery); boot loads ContentLibrary without error |
| Console can set values | `time 4` / `time 16` via ConsoleService → TimeScale; `test_time_scale.gd::test_console_time_command_sets_the_scale` |
| Save/load round-trips trivial state | Hostile fixture in `scripts/save_fixture.gd`; `test_save_roundtrip.gd` byte-exact; schema v1 |

**Gates:** `scripts/lint.ps1` exit 0. GUT 93/93 pass (adversary tightened empty-systems + twin-encode + near-miss tests).

## Open decisions

- None blocking A1.

## Standing decisions that bind upcoming work

- **This folder is the only build surface.** Greenfield Alpha. Older `Desktop\Draywar` may be mined; it is not this codebase.
- **Alpha is source of truth.** Full plan is after Final Alpha Gate.
- **Standing law:** `docs/reputation_and_standing.md`. Alpha population from Alpha Scope (4–6 / 12–18).
- **Godot 4.6.1** at `C:\Godot\`. Do not upgrade without asking.
- **MCP Pro proprietary** — `addons/godot_mcp/` gitignored.
- **Talk plain / short / blunt to Elliot.** Subagents build; main chat verifies.
- **Memory system on disk** — state + journal + traps + eras + compact hooks. Files beat chat memory.
- **Full phase per go.** "Go on Phase N / A0" means finish the whole phase, then stop.
- **Save schema is v1.** Bump only with a migration step when real sections arrive.

## Next session starts here

1. `/start` (or he says go).
2. If he says go on A1: finish **entire A1** (flight, one system with station+gate, dock loop, camera, HUD). Subagents build.
3. Report A1 done with proof; wait for human flight gate.

## Session history

- **2026-07-30** — Setup session: greenfield project, tooling and skills.
- **2026-07-30** — A0 Foundation complete: data pipeline, save v1, console, time.
