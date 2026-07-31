# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** Path C. **B0–B2 complete**. Next: **B3 Station depth + trade**. Final Alpha **not signed**.

| Doc | Role |
|-----|------|
| `Alpha/ALPHA_DECISION_BAR.md` | What Alpha done means (ratified) |
| `Alpha/ALPHA_DECISION_PHASE_PLAN.md` | B0–B5 order + worktree parallel tracks (**agreed**) |
| `docs/reputation_and_standing.md` | Standing law |

**Last closed:** **B2 — Session shell** (main menu / pause / captain sheet / job tracking / save UX).

## Honest now

| Area | Status |
|------|--------|
| Multi-system **in play** | **Pass** — Alpha/Beta/Gamma linked; HUD NAV + world gate labels; F jump |
| Presentation floor | **Pass** — starfield, per-system tint, distinct silhouettes, shared UI theme |
| Session shell | **Pass** — main menu, pause, captain sheet, career save/load UX, job HUD |
| Trade / station depth / combat | Missing (B3+) |
| Flight / standing / recovery / thin money-jobs | Partial (A0–A5 mechanical + B0–B2 shell) |

## B2 evidence

**Acceptance**

- Boot → main menu (not straight into flight). New Game → play. Esc pause → Save / Load / Captain sheet / Quit to menu. Continue restores career via optional sections.
- Active job: HUD `JOB name → destination` (display name).
- Tests: `tests/test_b2_session_shell.gd` (gather sections, round-trip wallet/mission/world, menu buttons, theme, mission section, named save, HUD dest). Suite **210/210**.
- Verify-red: broke post-load credits assert → 1 fail; restored → green.
- **Play smoke:** headless Main boot prints banner and lands on menu; full click loop is code path + unit composition (same style as B0).

**Implementation**

- `CareerSave` shared by console + menu; optional `world` + `mission` sections (schema v1, no envelope bump).
- Free-fly position restore; docked-state restore deferred.

## Gates

- A1 flight feel **signed** · A4 recovery feel **signed**
- Final Alpha **open** until B5 + checklist green + Elliot sign

## Open decisions

- None blocking B3. Save schema: still ask if new **required** fields.

## Standing decisions

- Path C hybrid; B0–B2 in main tree.
- Godot 4.6.1 at `C:\Godot\`. Remote: `origin/main` → `https://github.com/elmillgoa/Draywar-Alpha`
- Elliot: after phase wrap, free to start next phase in same chat.

## Next session starts here

1. `/start` — orient; plan is **B3 Station depth + trade + money loop**.
2. **Go on B3** (station sections, commodities, buy/sell, cargo, money visible on sheet).
3. B3 and B4 may parallel after B2 (B2 landed shared HUD/sheet and wallet seams).
4. Final Alpha only after B5 checklist green.

## Session history

- **2026-07-31** — B2: session shell (menu/pause/sheet/jobs/save UX); lint/tests green; wrap.
- **2026-07-31** — B0+B1: multi-system travel + presentation floor.
- **2026-07-30–31** — A0–A5 mechanical; Final Alpha refused (tech demonstrator); Path C + decision bar; B0–B5 plan agreed.
