# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** Path C. **B0–B5 code complete.** **Combat Fairness Pass code complete** (C0–C5). Final Alpha **open** — Elliot must re-play combat + full cold script. Attempt 1 refused (tech demo). Combat feedback (aim/dodge/hull) addressed in code; **not** signed by him yet.

| Doc | Role |
|-----|------|
| `Alpha/ALPHA_DECISION_BAR.md` | Checklist (Present / good enough to judge) |
| `Alpha/ALPHA_DECISION_PHASE_PLAN.md` | B0–B5 order |
| `docs/gates.md` | Final Alpha play script + verdicts + combat feedback |
| `docs/reputation_and_standing.md` | Standing law |

**Last closed (code):** Combat Fairness Pass (target hull %, hostile travel bolts, locked aim depth, jink AI, hit flash). **Not** Final Alpha sign.

## Honest now — decision bar

| # | System | Status |
|---|--------|--------|
| 1 | Flight | Present (A1 signed) |
| 2 | World / travel | Present (B0) |
| 3 | Station menus | Present (scroll body; Undock footer always visible) |
| 4 | Main menu / pause | Present (B2; settings thin) |
| 5 | Captain sheet | Present (B2) |
| 6 | Job tracking | Present; Turn In uses docked station + feedback |
| 7 | Standing + status moment | Present |
| 8 | Personal recovery | Present (Mendi foothold) |
| 9 | Trade | Present (B3 + price contrast) |
| 10 | Combat | Present — fairness pass landed; **Elliot re-play decides if good enough** |
| 11 | Money loop | Present |
| 12 | NPC traffic | Present (placeholder density) |
| 13 | Save / load | Present (menu/pause) |
| 14 | Presentation floor | Present (B1; not final art) |
| 15 | Minimal content pack | Present |

**Residual:** settings stub; art/audio placeholders; thin trade by design; one recovery chain; combat still one pirate type (by design).

## Combat Fairness Pass (code done)

| What | Behavior |
|------|----------|
| Target lock | Tab → HUD `LOCK name range HULL %` updates on damage |
| Your guns | Travel bolts; aim reticle at red lead; no auto-hit |
| Their guns | Travel bolts (lead on you); **strafe to dodge** |
| Aim | With lock, mouse aim depth uses the target plane |
| Hostile AI | Close / hold band / **jink**; fires only when facing you |
| Fairness kept | Alpha no hostiles; station safe zone; undock grace; cripple→repair; kill→attribution only |

## Evidence

- Suite **265/265**. Lint green.
- New/updated: `test_hostile_projectiles.gd` (physics hit, strafe dodge, jink), hull lock HUD, lead aim plane.

## Gates

- A1 / A4 **signed**
- **Final Alpha open** — Attempt 1 refused; combat feedback list implemented in code; Attempt 2 not played/signed

## Open decisions

- None blocking play. Save: ask only for new **required** schema fields.

## Standing decisions

- Path C hybrid. Godot 4.6.1. Remote `origin/main` → `https://github.com/elmillgoa/Draywar-Alpha`
- Do **not** start Destination / full-plan until Final Alpha signs.

## Next session starts here

1. **Elliot plays combat** (Beta/Gamma): lock → hull %, aim lead, dodge bolts, kill or limp home.
2. Then full Final Alpha cold script in `docs/gates.md` (or combat-only re-check first).
3. Record verdict **verbatim** in `docs/gates.md` + journal `GATE`.
4. If signed → Path C Alpha closed. If refused → iterate from his list only.

## Session history

- **2026-07-31 (this session)** — Combat refuse; fairness pass planned and implemented (hull %, travel enemy bolts, aim depth, jink); 261 tests.
- **2026-07-31** — Play fixes: docked start, undock footer, turn-in, combat lock/reticle/lead/bolts; Final Alpha still open.
- **2026-07-31** — B2 → B3 → B4 → B5 content/gate prep.
- **2026-07-30–31** — A0–A5 mechanical; Path C; Final Alpha Attempt 1 refused (tech demo).
