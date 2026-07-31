# Draywar Alpha — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **A5 mechanical landed; Final Alpha Gate failed (not signed).**

- A0 Foundation ✓
- A1 Flight & One System ✓ (feel gate signed)
- A2 Standing Core ✓
- A3 Attribution & Everyday Change ✓
- A4 Personal Recovery ✓ (feel gate signed)
- A5 Minimal Playable Slice — **mechanical** (systems/money/loop wired); **not accepted as Alpha**
- **Final Alpha Gate** — **not signed** (2026-07-31): tech demonstrator, not Alpha

**Next:** Close the gap to Elliot’s Alpha bar, then re-run Final Alpha Gate. Do not expand to full plan.

**Alpha bar (Elliot, post–Final Alpha refuse):** playable game with **core systems working**, **actual graphics** (not black + colored boxes), **more than flying shapes**, **minimal content for real vetting**. Current = less than the basics / tech demonstrator.

## Proof (A5)

| Criterion | Evidence |
|-----------|----------|
| Coherent short session without debug console | Station menu accept/turn-in/abandon, favor/talk/complete recovery, refuel/repair, gate F-jump; destinations on accept button + HUD JOB line; `test_a5_play_slice.gd` |
| Status moment + recovery lever in normal play | FlightHUD status line; StationMenu Talk/Ask favor/Complete recovery; deep-negative dock still open while Mendi recovery open (`test_deep_negative_still_allows_dock_for_open_recovery_contact`) |
| 3 systems distinct controllers/security | alpha patrolled / beta contested / gamma lawless + stations |
| NPC traffic reflects security | `NpcTraffic` counts by policing |
| Money loop | WalletService: pay, fuel, dock fees, refuel, repair; optional save `wallet` |

## Gates

- lint exit 0 · GUT **188/188**
- A1 flight feel **signed**
- A4 recovery feel **signed**
- **Final Alpha Gate** — attempt 1 **not signed** (tech demonstrator). Re-gate after iterate.

## Open decisions

- None blocking Final Alpha play.

## Standing decisions that bind upcoming work

- **This folder is the only build surface.** Greenfield Alpha.
- **Alpha is source of truth.** Full plan after Final Alpha Gate.
- **Standing law:** `docs/reputation_and_standing.md`. Caps from Alpha Scope.
- **Godot 4.6.1** at `C:\Godot\`.
- **Talk plain / short / blunt.** Subagents build; main verifies.
- **Full phase per go.** Phase end = commit + wrap when closed.
- **Save schema v1** with optional sections (`standing`, `wallet`).

## Next session starts here

1. `/start` — A5 mechanical exists; Final Alpha refused (demo, not Alpha).
2. Decide iterate target with Elliot (feel / content / loop / presentation).
3. Build that slice; re-run Final Alpha Gate.
4. Only on sign: wrap Alpha and open full-plan expansion.

## Session history

- **2026-07-30** — Setup; A0; A1 mechanical.
- **2026-07-31** — A1 gate signed. A2 Standing. A3 Attribution/missions. A4 recovery + gate signed. **A5 minimal playable slice** (multi-system, money, NPC, normal play). Final Alpha gate open.
