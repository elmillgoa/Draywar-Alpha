# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E5.1 complete.** Next contract: **E5.2 Systems + stations pack**.

| Doc | Role |
|-----|------|
| `docs/BETA_E5_CONTENT_SCALE.md` | **E5 plan (active)** — E5.1 done; E5.2–E5.7 remain |
| `docs/BETA_E4_OPENING_CAST.md` | E4 closed (gate signed) |
| `docs/BETA_E3_ECONOMY.md` | E3 closed (gate signed) |
| `docs/BETA_E2_COMBAT_HULL.md` | E2 closed (gate signed) |
| `docs/BETA_ROADMAP.md` | Post-Alpha queue (approved) |
| `docs/gates.md` | E5.7 play script added; open until code complete |
| `docs/reputation_and_standing.md` | Standing law |

## Phase progress

| Phase | Status |
|-------|--------|
| E1 Legible Sector | **closed** (gate signed) |
| E2 Combat & hull | **closed** (gate signed 2026-07-31) |
| E3 Economy pressure | **closed** (gate signed 2026-07-31) |
| E4 Opening & cast | **closed** (gate signed 2026-07-31) |
| E5 Content scale | **in progress** — E5.1 done; next E5.2 |

## What the game can do now

- Same playable slice as E4 close: New Game → annexation → tip → docked Alpha Port; life path; two recovery footholds; Hauler/Fighter; pirate profiles; economy pressure; E1 sector loop.
- **E5.1:** content ceilings raised so packs can load later — `star_systems` **8**, `stations` **10**, `people` **24**. Live content still **3 systems / 6 stations / 15 people**. No new map yet.
- Sector still linear gates, **text NAV only** (E5.2+ expands).

## Evidence

- Lint + GUT green at E5.1 complete (`tests/test_e5_content_budget.gd` + full suite).
- Gates E2.7 / E3.6 / E4.7 signed 2026-07-31. E5.7 open (script ready).

## Next session starts here

1. `/start` — confirm green; position = E5.1 done, build **E5.2**.
2. **Build E5.2** Systems + stations pack (Delta/Epsilon/Zeta + docks to ~9–10) per `docs/BETA_E5_CONTENT_SCALE.md`.
3. Then E5.3 → (E5.4 ∥ E5.5) → E5.6 → gate E5.7.
4. Do not invent standing rules. Do not open Ops/Holding early.

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1–E4 feel gates all signed 2026-07-31.
- E5 locks: ship **6** systems (budget 8), ~10 stations, branched graph, functional map, no new job kind required.
- E5.1 lift done: budgets 8 / 10 / 24 for systems / stations / people.
- Never free() UI mid-pressed; free-fire aim on camera ray; bounty ensures prey in lock range.

## Session history

- **2026-08-02 (E5.1)** — Content budget lift: `Balance.CONTENT_BUDGET` systems 8, stations 10, people 24; E5.1 tests; no new play content.
- **2026-07-31 (E5 plan)** — Locked `docs/BETA_E5_CONTENT_SCALE.md`; E5.7 gate script; no code build (usage).
- **2026-07-31 (gate clear)** — Elliot signed E2.7, E3.6, E4.7; open list cleared.
- **2026-07-31 (wrap)** — E2 + E3 + E4 code complete; gates had been open for later play.
- **2026-07-31** — E1 signed; Final Alpha signed earlier same day.
