# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E2 code complete** (E2.1–E2.6). **[GATE] E2.7** open for later play. **E3 Economy** starting (Elliot: drive phases; test when built). E1 feel **signed**. Roadmap **approved**.

| Doc | Role |
|-----|------|
| `docs/BETA_E2_COMBAT_HULL.md` | E2 contracts (code done; gate open) |
| `docs/BETA_E3_ECONOMY.md` | E3 contracts (active) |
| `docs/BETA_ROADMAP.md` | Post-Alpha queue (approved) |
| `docs/gates.md` | E1 signed; E2.7 open |
| `docs/reputation_and_standing.md` | Standing law |

## E1 progress — CLOSED

| Contract | Status |
|----------|--------|
| E1.1–E1.6 + play fixes | **done** |
| **[GATE] E1 feel** | **signed** 2026-07-31 |

## E2 progress

| Contract | Status |
|----------|--------|
| E2.1 Hostile profiles | **done** |
| E2.2 Encounter rules | **done** |
| E2.3 Attribution feedback | **done** |
| E2.4 Hauler hull law data | **done** |
| E2.5 Fighter + station switch | **done** |
| E2.6 Performance densify | **done** |
| **[GATE] E2 combat/hull feel** | **open** — play script in `docs/gates.md` |

**E2 defaults (no ask):** Pay once for Fighter · block switch if cargo too heavy · `hull_courier` stays id, display Hauler.

## What the game can do now

- E1 baseline + **two pirate fight shapes**: Skirmisher (fast glass) and Gunboat (slow hard)
- **Encounter rules (E2.2):** Alpha undock stays pirate-free; Beta places 1 skirmisher; Gamma places 2 gunboats
- Live hostiles in one system never exceed **3** (balance cap)
- Bounty ensure still places soft Skirmisher prey outside station safe airspace, inside lock range (if under cap)
- Lock line shows profile name (Skirmisher / Gunboat)
- **Kill feedback (E2.3):** HUD toast names local controller when standing fell; plain “not recorded” when it did not
- **Witnesses:** live ambient traffic ship count (not a fixed 1). Patrolled still always attributes; contested needs traffic or evidence; lawless needs evidence
- Kill still only through AttributionService → StandingService (no new standing rules)
- **Hauler hull law (E2.4):** starter ship is **Hauler** (id `hull_courier`); hold capacity and guns come from that hull data; cargo free space follows the active hull
- **Fighter + station switch (E2.5):** buy Fighter once for **1000** credits at Services while docked; switch between owned hulls while docked; switch refuses if cargo volume is too heavy for the target hold; Fighter = high guns / cargo 1 / steel fin silhouette; Hauler = cargo 20 / gold wings; captain sheet shows current hull name; optional save `ship` section (active + owned); missing section = Hauler only. One player ship in space. No Ops.
- **Denser traffic (E2.6):** orbit freighters raised — patrolled **8**, contested **8**, lawless **5**. Performance budget **12** ships max (1 player + traffic + hostiles). Densest layout is contested Beta at max hostiles: **1 + 8 + 3 = 12**. Orbit traffic still non-combat; hostiles still combat-only.

## Evidence

- Lint green. GUT **386/386** (was 381; +5 E2 adversary gap tests).
- Traffic: **8 / 8 / 5** (was 6 / 4 / 2). `PERF_BUDGET_SHIPS = 12`.
- Densest: contested `1 + NPC_COUNT_CONTESTED + MAX_CONCURRENT_HOSTILES = 12`.
- E2 adversary close-out: silhouette assert, Services buy/switch path, undock-grace fire block, load-time cargo clamp to Hauler.
- Tests: `tests/test_e2_fighter_switch.gd`, `tests/test_e2_encounters.gd`, `tests/test_e2_performance.gd`.

## E3 progress

| Contract | Status |
|----------|--------|
| E3.1 Career pressure | **next** |
| E3.2 Debt seed | pending |
| E3.3 Contraband | pending |
| E3.4 Smuggle job | pending |
| E3.5 Integration | pending |
| **[GATE] E3 economy feel** | after code |

## Next session starts here

1. Continue E3 from first incomplete contract.
2. E2.7 gate script in `docs/gates.md` — Elliot signs when he plays; code does not wait.
3. Refuse path only if he lists E2 fixes after play.
3. Do not invent standing rules. Do not open Ops/Holding.

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1 feel signed; roadmap approved.
- Two-hull interlock is E2 thin proof (Dest §6), not deferred to Ops.
- Never free() UI mid-pressed; free-fire aim on camera ray; bounty ensures prey in lock range.
- D3: keep content id `hull_courier`, display **Hauler**.
- D1: pay once for Fighter. D2: block switch until cargo fits.

## Session history

- **2026-07-31 (this session)** — E2.6 Performance densify implemented.
- **2026-07-31 (prior)** — E2.5 Fighter + station switch green.
- **2026-07-31 (prior)** — E2.4 Hauler hull law data green.
- **2026-07-31 (prior)** — E2.3 attribution feedback green (HUD toast + live witnesses).
- **2026-07-31 (prior)** — E2.2 encounter rules green (counts, denser lawless, concurrent cap).
- **2026-07-31 (prior)** — E2.1 hostile profiles green (skirmisher + gunboat).
- **2026-07-31 (prior)** — E1 gate signed; E2 plan locked; building E2+.
- **2026-07-31 (prior wrap)** — E1 built; play fixes; formal gate was open.
- **2026-07-31** — Final Alpha signed; Path C closed.
