# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A4 — Personal Recovery Path mechanics complete; human feel gate OPEN.**

- A0–A3 complete (foundation, flight, standing, attribution/missions)
- **A4 mechanics:** one recovery chain via Dockhand Mendi (`person_ra_mendi` / Reach Authority); deniable first job + 3 follow-ons; betrayal closes route; favor/console bootstrap; station “Talk to…” when offered
- GUT **176/176** · lint clean

**Blocked on:** **A4 recovery-feel gate** — Elliot must play and sign (or reject).

**Next after gate:** if signed → A5 Minimal Playable Slice; if not → iterate recovery feel.

## Proof (A4 mechanical acceptance)

| Criterion | Evidence |
|-----------|----------|
| Deep negative Entity + Friendly personal → deniable job → small Entity climb | `test_deniable_complete_from_deep_negative_improves_entity` |
| Betray closes recovery | `test_betray_closes_recovery_route` |
| Chain progresses; Entity climbs slowly | `test_chain_progresses_all_steps_entity_climbs_slowly` |

## Gates

- `scripts/lint.ps1` exit 0
- GUT **176/176**
- A1 flight feel **signed**
- **A4 recovery feel — OPEN**

## Open decisions

- A4 history bootstrap: first deniable needs Friendly personal only; follow-ons need prior success (Alpha reading of reputation §5).
- Active recovery step session-only; person success/closed + chain progress in standing save section.

## Standing decisions that bind upcoming work

- **This folder is the only build surface.** Greenfield Alpha.
- **Alpha is source of truth.** Full plan after Final Alpha Gate.
- **Standing law:** `docs/reputation_and_standing.md`. Caps from Alpha Scope.
- **Godot 4.6.1** at `C:\Godot\`.
- **Talk plain / short / blunt.** Subagents build; main verifies.
- **Full phase per go.** Phase end = commit + wrap when closed (gate signed if required).
- **Save schema v1** with optional sections.

## Next session starts here

1. `/start` if cold.
2. Play A4 recovery gate (recipe in chat / gates prep).
3. Record verdict in `docs/gates.md`. Signed → A5. Not signed → iterate.

## Session history

- **2026-07-30** — Setup; A0 Foundation; A1 mechanical.
- **2026-07-31** — A1 gate signed. A2 Standing Core. A3 Attribution & missions. A4 recovery mechanics; gate open.
