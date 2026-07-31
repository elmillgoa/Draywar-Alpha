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

- None for tooling. Build plan freeze after first successful `/start`.

## Standing decisions that bind upcoming work

- **This folder is the only build surface.** Greenfield Alpha. The older `Desktop\Draywar` Claude project may be mined for patterns/tools; it is not the codebase.
- **Alpha is source of truth.** Full Destination / Phase Plan v2 are post–Final Alpha Gate.
- **`docs/reputation_and_standing.md` is standing law.** Do not invent standing rules. Population for Alpha follows **Alpha Scope** (4–6 Entities, 12–18 People), not the full-doc 8–12 / 20–35.
- **Godot 4.6.1** at `C:\Godot\`. Do not upgrade without asking.
- **MCP Pro is proprietary** — `addons/godot_mcp/` is gitignored; reinstall from local copy if missing.

## Next session starts here

1. Run `/start` (or ask to start session).
2. Confirm toolchain: checkin, lint, headless boot.
3. Begin **A0 Foundation** remaining pieces: data pipeline, save schema v1, debug console, time control, first headless tests — unless Elliot redirects.

## Session history

- **2026-07-30** — Setup session: greenfield project, tooling and skills. See journal when created.
