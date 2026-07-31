# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **Pre-A0 complete setup.** Project skeleton, EventBus autoload, GUT, Godot MCP Pro addon (local, gitignored), session skills, docs authority chain. **No Alpha contracts implemented yet.**

**Next contract:** **A0 — Foundation** (per `Alpha/ALPHA_PHASE_PLAN.md`)

- Project skeleton ✓ (minimal)
- Strict typing ✓ (project settings)
- EventBus ✓ (empty catalog)
- Data pipeline — not yet
- Save schema — not yet
- Debug console — not yet
- Basic time control — not yet
- Acceptance: empty systems can load, console can set values, save/load round-trips a trivial state

## Open decisions

- None blocking A0. Ready for "go on A0" / "go on Phase 0".

## Standing decisions that bind upcoming work

- **This folder is the only build surface.** Greenfield Alpha. Older `Desktop\Draywar` may be mined; it is not this codebase.
- **Alpha is source of truth.** Full plan is after Final Alpha Gate.
- **Standing law:** `docs/reputation_and_standing.md`. Alpha population from Alpha Scope (4–6 / 12–18).
- **Godot 4.6.1** at `C:\Godot\`. Do not upgrade without asking.
- **MCP Pro proprietary** — `addons/godot_mcp/` gitignored.
- **Talk plain / short / blunt to Elliot.** Subagents build; main chat verifies.
- **Memory system on disk** — state + journal + traps + eras + compact hooks. Files beat chat memory.
- **Full phase per go.** "Go on Phase N / A0" means finish the whole phase, then stop. Ask all blockers **before** build. Applies to every phase. Plan-marked human gates still need his play/sign-off.

## Next session starts here

1. `/start` (or he says go).
2. If he says go on A0: finish **entire A0** (data pipeline, save v1, debug console, time control, tests proving acceptance). Subagents build. Do not stop mid-phase for a status check unless blocked or room dies (then wrap).
3. Report A0 done with proof; wait for next phase go.

## Session history

- **2026-07-30** — Setup session: greenfield project, tooling and skills. See journal when created.
