# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A3 — Attribution & Everyday Change complete** (2026-07-31).

- Project skeleton ✓
- Strict typing ✓
- EventBus ✓ (A0–A3; kill + mission signals catalogued)
- Data pipeline ✓ — + **ContractType** (`contract_types`)
- Content: 3 systems (patrolled/contested/lawless), Alpha Port, courier hull, 4 Entities, 12 People, **2 courier contracts**
- Save schema v1 ✓ — standing section; missions session-only (A3)
- Debug console ✓ — `standing`, `kill`, `trade legal`, `mission …`
- **A1 flight** ✓ · **A2 standing** ✓
- **A3:** AttributionService (security/witnesses/evidence); MissionService (one active); StandingService deltas + stickiness + one-hop ripple; light legal trade soft-cap

**Next contract:** **A4 — Personal Recovery Path** (per `Alpha/ALPHA_PHASE_PLAN.md`)

## Proof (A3 acceptance)

| Criterion | Evidence |
|-----------|----------|
| Patrolled kill hits standing; clean lawless does not; evidence does | `test_patrolled_kill_drops_controller_standing`, `test_lawless_kill_without_evidence_no_standing_change`, `test_lawless_kill_with_evidence_hits_controller`, contested witness tests |
| Mission complete / fail / abandon direction + magnitude | `test_mission_complete_positive_delta`, `test_mission_fail_milder_negative_than_abandon`, `test_mission_complete_magnitude_matches_balance_default` |
| Stickiness on deep negative | `test_stickiness_reduces_positive_at_deep_negative` |

## Gates

- `scripts/lint.ps1` exit 0
- GUT **160/160** pass (as of A3 close)
- A1 flight feel **signed** (2026-07-31)
- No human gate on A3

## Open decisions

- None blocking A4.
- Dock refusal default: standing **at or below −50** (Hostile) refuses; per-Entity override on content.
- Nobody controller: Uncontrolled / always allows dock.
- Standing save is optional section inside schema v1 (no envelope version bump).
- Active mission is **session-only** for A3 (not in save).

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
