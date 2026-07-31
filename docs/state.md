# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **E3 Economy code-complete** — **E3.1–E3.5 done**. **[GATE] E3.6** open (economy feel). **[GATE] E2.7** still open for later play. E1 feel **signed**. Roadmap **approved**.

| Doc | Role |
|-----|------|
| `docs/BETA_E2_COMBAT_HULL.md` | E2 contracts (code done; gate open) |
| `docs/BETA_E3_ECONOMY.md` | E3 contracts (code done; E3.6 gate open) |
| `docs/BETA_ROADMAP.md` | Post-Alpha queue (approved; E3 code complete) |
| `docs/gates.md` | E1 signed; E2.7 open; E3.6 open |
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

- **Career pressure (E3.1):** while undocked, life-support burns credits over scaled time (1 credit/sec game time). Docked = free. Credits stop at 0. Fuel burn and jump cost slightly higher so travel still costs. HUD marks LOW funds at ≤50 credits.
- **Emergency loan (E3.2):** once while clear, borrow 400 from Free Haulers at Services (owe 480 flat). No second loan while debt open. Job pay auto-takes 25% toward debt; player keeps the rest. Manual repay at Services. Three broke docks with unpaid debt → Free Haulers standing hit only (no ship loss, no dock ban). Save keeps debt fields; old saves without them = no debt. Captain sheet shows debt.
- **Contraband (E3.3):** Munitions are restricted for **Reach Authority** only. Cannot buy or sell them at Alpha Port/Yard open market (row shows RESTRICTED). Legal at non-Reach docks (e.g. Beta Hub). Docking at Reach with munitions in hold → 100-credit fine (partial if broke), Reach standing −10 (via StandingService only), all munitions seized. Session restore does not re-inspect. Grain and other goods still trade at Reach. Status moment unchanged.
- **Integration (E3.5):** scenario pressure math locked — three jumps + free-fly slice costs more than one courier if you never earn; smuggle min pay covers Reach fine + short upkeep with margin; start 500 does not softlock before first dock job (loan is the broke escape). Captain sheet shows credits/fuel/hull/debt/job; Services has Borrow/Repay. No rate retune needed this pass.
- **Smuggle jobs (E3.4):** Third job kind. Accept loads munitions (5 units) into the hold; complete only at the destination gray station while that cargo is still held — then cargo is removed and you get paid (240 Beta→Gamma / 260 Gamma→Beta) plus standing. Abandon leaves the crates. Fighter hold is too small to accept; Hauler can. Docking at Reach with the load still triggers the E3.3 fine/seize. Board / HUD / captain sheet say “smuggle” plainly. One active mission max. Contract budget raised to 12 (10 used).
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

- E3.5: scenario tests `tests/test_e3_integration.gd` (7). Named windows: free-fly 60s, 3 jumps, short upkeep 30s, first undock 20s. Never-earn 225 > courier 120; smuggle 240 margin 75 after fine/bills; start path no softlock; loan 400 escape. No balance rate retune. Lint + full GUT green (434).
- E3.4: kinds delivery/bounty/smuggle; templates `contract_smuggle_beta_to_gamma` (240) + `contract_smuggle_gamma_to_beta` (260); qty 5 munitions; budget 12. Tests `tests/test_e3_smuggle.gd` (12). Lint + full GUT green (427).
- E3.3: entity `entity_reach_authority`; fine 100; standing −10; seize all munitions. Tests `tests/test_e3_contraband.gd` (11).
- E3.2: principal 400 / repay 480 / garnish 25% / grace 3 docks / standing hit Free Haulers -12. Tests `tests/test_e3_debt.gd`.
- E3.1: upkeep 1.0 credit/s undocked; fuel burn 0.4/s; jump 14. Tests `tests/test_e3_upkeep.gd` (7).
- Traffic: **8 / 8 / 5**. `PERF_BUDGET_SHIPS = 12`.
- Densest: contested `1 + NPC_COUNT_CONTESTED + MAX_CONCURRENT_HOSTILES = 12`.

## E3 progress

| Contract | Status |
|----------|--------|
| E3.1 Career pressure | **done** |
| E3.2 Debt seed | **done** |
| E3.3 Contraband | **done** |
| E3.4 Smuggle job | **done** |
| E3.5 Integration | **done** |
| **[GATE] E3.6 economy feel** | **open** — play script in `docs/gates.md` |

## Next session starts here

1. **[GATE] E3.6** economy feel — Elliot play script in `docs/gates.md`; sign → E4.
2. E2.7 combat/hull feel still open when he wants that play pass.
3. Do not invent standing rules. Do not open Ops/Holding. Do not start E4 until E3.6 is signed (or he explicitly drives past).

## Standing decisions

- Final Alpha signed. Destination filters govern.
- E1 feel signed; roadmap approved.
- Two-hull interlock is E2 thin proof (Dest §6), not deferred to Ops.
- Never free() UI mid-pressed; free-fire aim on camera ray; bounty ensures prey in lock range.
- D3: keep content id `hull_courier`, display **Hauler**.
- D1: pay once for Fighter. D2: block switch until cargo fits.
- E3.2 D2: one active Free Haulers loan; grace standing only; may borrow again after full repay (no stack while open).

## Session history

- **2026-07-31 (this session)** — E3.5 Integration / balance pass (scenario tests; gate script; code-complete).
- **2026-07-31 (prior)** — E3.4 Smuggle job kind (munitions Beta↔Gamma; Reach risk real).
- **2026-07-31 (prior)** — E3.3 Contraband jurisdiction (munitions + Reach).
- **2026-07-31 (prior)** — E3.2 Debt seed (Free Haulers thin loan).
- **2026-07-31 (prior)** — E3.1 Career pressure (upkeep + fuel retune).
- **2026-07-31 (prior)** — E2.6 Performance densify implemented.
- **2026-07-31 (prior)** — E2.5 Fighter + station switch green.
- **2026-07-31 (prior)** — E2.4 Hauler hull law data green.
- **2026-07-31 (prior)** — E2.3 attribution feedback green (HUD toast + live witnesses).
- **2026-07-31 (prior)** — E2.2 encounter rules green (counts, denser lawless, concurrent cap).
- **2026-07-31 (prior)** — E2.1 hostile profiles green (skirmisher + gunboat).
- **2026-07-31 (prior)** — E1 gate signed; E2 plan locked; building E2+.
- **2026-07-31 (prior wrap)** — E1 built; play fixes; formal gate was open.
- **2026-07-31** — Final Alpha signed; Path C closed.
