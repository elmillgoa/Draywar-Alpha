# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** Path C. **B0 + B1 complete** (world travel + presentation floor). Next: **B2 Session shell**. Final Alpha **not signed**.

| Doc | Role |
|-----|------|
| `Alpha/ALPHA_DECISION_BAR.md` | What Alpha done means (ratified) |
| `Alpha/ALPHA_DECISION_PHASE_PLAN.md` | B0–B5 order + worktree parallel tracks (**agreed**) |
| `docs/reputation_and_standing.md` | Standing law |

**Last closed:** **B0 — World you can actually travel** + **B1 — Presentation floor** (same session, main tree).

## Honest now

| Area | Status |
|------|--------|
| Multi-system **in play** | **Pass** — Alpha/Beta/Gamma linked; HUD NAV + world gate labels; F jump |
| Presentation floor | **Pass** — starfield, per-system tint, distinct silhouettes, shared UI theme |
| Menu / sheet / trade / combat | Missing (B2+) |
| Flight / standing / recovery / thin money-jobs | Partial (A0–A5 mechanical debt) |

## B0 / B1 evidence

**B0 acceptance**

- Cold boot multi-system path (no console): undock → fly to cyan gate / follow HUD NAV → F jump → dock → next system → return. Guided by SYSTEM title, NAV (HERE + GATES), world `GATE → …` labels, status moment on entry.
- Player can name system from HUD SYSTEM / NAV HERE without editor.
- Tests: `tests/test_b0_travel.gd` (gate graph, jump rebuild α→β→γ→α, gate labels, distinct backdrops, HUD nav, fuel block, arrival). Suite **203/203**.
- **Play smoke (recorded):** Automated rebuild loop + nav/label proof stands in for human cold-boot until Elliot flies; path above is the manual smoke.

**B1 acceptance**

- Scene reads as game: starfield (220), not pure black; per-system space/ambient/station colours; station cylinder+disc, gate torus+beacon, player prism, NPC capsules.
- Theme: `DraywarUiTheme` / `BalanceUi` on **StationMenu** and **FlightHUD**.
- Tests: `tests/test_b1_presentation.gd`.

**Verify-red:** broke gate-graph assert → red (202 pass); restored → 203 green.

## Gates

- A1 flight feel **signed** · A4 recovery feel **signed**
- Final Alpha **open** until B5 + checklist green + Elliot sign

## Open decisions

- None blocking B2. Save schema changes still need ask if required fields change.

## Standing decisions

- Path C hybrid; worktrees when tracks do not thrash Main/EventBus/Standing/save.
- B0+B1 landed in main tree (SystemWorld + HUD thrash made worktree split costly).
- Godot 4.6.1 at `C:\Godot\`. Remote: `origin/main` → `https://github.com/elmillgoa/Draywar-Alpha`

## Next session starts here

1. `/start` — orient; plan is **B2 Session shell**.
2. **Go on B2** (main menu / pause / captain sheet / job tracking / save UX per phase plan).
3. Do not skip to B3/B4 until B2 lands shared HUD/sheet and wallet/cargo seams.
4. Final Alpha only after B5 checklist green.

## Session history

- **2026-07-31** — B0+B1: multi-system discoverable travel + presentation floor; lint/tests green; wrap.
- **2026-07-30–31** — A0–A5 mechanical; Final Alpha refused (tech demonstrator); Path C + decision bar; B0–B5 plan agreed.
