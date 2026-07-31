# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** Path C. **B0–B5 code complete.** Post-B5 **playability fixes** landed (spawn, station UI, jobs, combat aim). **Final Alpha Gate open** — Elliot must play and sign. Not signed.

| Doc | Role |
|-----|------|
| `Alpha/ALPHA_DECISION_BAR.md` | Checklist (Present / good enough to judge) |
| `Alpha/ALPHA_DECISION_PHASE_PLAN.md` | B0–B5 order |
| `docs/gates.md` | Final Alpha play script + verdicts |
| `docs/reputation_and_standing.md` | Standing law |

**Last closed (code):** B5 + play-fix pack through combat reticle/lead. **Not** Final Alpha sign.

## Honest now — decision bar

| # | System | Status |
|---|--------|--------|
| 1 | Flight | Present (A1 signed) |
| 2 | World / travel | Present (B0) |
| 3 | Station menus | Present (scroll body; **Undock footer always visible**) |
| 4 | Main menu / pause | Present (B2; settings thin) |
| 5 | Captain sheet | Present (B2) |
| 6 | Job tracking | Present; **Turn In** uses docked station + feedback |
| 7 | Standing + status moment | Present |
| 8 | Personal recovery | Present (Mendi foothold) |
| 9 | Trade | Present (B3 + price contrast) |
| 10 | Combat | Present — **no auto-aim**; Tab lock + reticle + lead pip + travel bolts |
| 11 | Money loop | Present |
| 12 | NPC traffic | Present (placeholder density) |
| 13 | Save / load | Present (menu/pause) |
| 14 | Presentation floor | Present (B1; not final art) |
| 15 | Minimal content pack | Present |

**Residual:** settings stub; art/audio placeholders; thin trade/combat by design; one recovery chain.

## Playability fixes this session (post-B5)

| Fix | What changed |
|-----|----------------|
| Spawn | New Game starts **docked** at Alpha Port (storyboard berth) |
| Alpha safety | **No combat hostiles** in patrolled government space |
| Station menu | Viewport-tall panel; body scrolls; **Undock always on footer** |
| Job turn-in | `try_complete_at(docked station)`; status “Job complete +credits” |
| Combat fairness | Pirates near **gate**, station safe zone, undock grace, softer DPS |
| Fire | Space / LMB; works free-flying even if crippled |
| Target lock | **Tab** nearest → cycle far → wrap; cyan brackets on target |
| Aim | Mouse **reticle**; red **lead diamond**; bolts **travel** (no lock auto-hit) |

## Evidence

- Suite **252/252**. Lint green. `origin/main` at `ed91f39`.
- Play script: `docs/gates.md` Final Alpha section (docked start, combat on Beta/Gamma).

## Gates

- A1 / A4 **signed**
- **Final Alpha open** — Attempt 2 not played/signed this session

## Open decisions

- None blocking play. Save: ask only for new **required** schema fields.

## Standing decisions

- Path C hybrid. Godot 4.6.1. Remote `origin/main` → `https://github.com/elmillgoa/Draywar-Alpha`
- After phase wrap free to chain next phase (Elliot); Final Alpha still human gate.

## Next session starts here

1. `/start` — orient; tree should be clean on `main`.
2. **Elliot plays Final Alpha** cold script in `docs/gates.md` (no console).
3. Record Attempt 2 verdict **verbatim** in `docs/gates.md` + journal `GATE`.
4. If signed → Path C Alpha closed. If refused → iterate from his list only.
5. Do **not** start full-plan Destination work until Final Alpha signs.

## Session history

- **2026-07-31 (this wrap)** — Play fixes: docked start, undock footer, turn-in, combat lock/reticle/lead/bolts; 252 tests; Final Alpha still open.
- **2026-07-31** — B2 session shell → B3 trade → B4 combat → B5 content/gate prep.
- **2026-07-30–31** — A0–A5 mechanical; Path C; Final Alpha Attempt 1 refused (tech demo).
