# Beta E2 — Combat & hull law

**Status:** Active work queue  
**Date:** 2026-07-31  
**Authority:** Destination §6 interlock (LOCKED) + `docs/BETA_ROADMAP.md` E2  
**Approved defaults (Elliot: only stop for decisions):** D1 Pay once for Fighter · D2 Block switch until cargo fits · D3 Keep `hull_courier` id, display **Hauler**

## Job

Prove Destination combat identity without Operations/Holding: two hostile fight shapes, security-aware encounters, attribution feedback in the HUD, thin two-hull interlock (Hauler + Fighter), denser traffic within the 12-ship budget.

## Caps (E2)

| Element | Cap |
|---------|-----|
| Systems | ≤5 (stay at 3 unless needed) |
| Stations | ≤7 (stay at 6) |
| Entities | ≤6 |
| People | ≤20 |
| Job kinds | ≤3 (keep 2) |
| Player hulls | **2** (Hauler, Fighter) |
| Hostile profiles | 2–3 |
| Concurrent hostiles / system | ≤3 |
| Performance | 60 fps with ~12 ships |

## Contracts

| ID | Name | Status |
|----|------|--------|
| E2.1 | Hostile profiles | **done** |
| E2.2 | Encounter rules | **done** |
| E2.3 | Attribution feedback | **done** |
| E2.4 | Hauler hull law data | **done** |
| E2.5 | Fighter + station switch | **done** |
| E2.6 | Performance densify | **done** |
| E2.7 | **[GATE] Combat & hull feel** | **signed** 2026-07-31 |

### E2.1 Hostile profiles

**Status:** done (2026-07-31)

**Shapes:** `skirmisher` (default / bounty) and `gunboat`. Contested ambient → skirmisher; lawless ambient → gunboat. Bounty ensure → skirmisher.

**Acceptance:**

1. At least two hostile profile ids in balance/data with different HP, damage, speed, engage range, and/or fire cooldown. ✅
2. Headless tests: profile A dies in N player hits; profile B differs under fixed damage — numbers from balance. ✅ (`tests/test_e2_hostile_profiles.gd`)
3. Contested or lawless can meet both shapes in one session (ambient and/or bounty). ✅
4. Lock HUD shows a distinct name per profile. ✅ ("Skirmisher" / "Gunboat")
5. Bounty ensure still places prey outside safe radius and within lock range. ✅
6. No new standing rules; kill via AttributionService only. ✅
7. Lint + full GUT green. ✅

### E2.2 Encounter rules

**Status:** done (2026-07-31)

**Rules:** Ambient count by policing from balance (patrolled 0 / contested 1 / lawless 2). Lawless also uses gunboat (meaner). Concurrent live hostiles capped at `MAX_CONCURRENT_HOSTILES` (3). Ambient offsets + safe-radius push; bounty ensure still places skirmisher in lock range when prey empty/far, and refuses at the cap.

**Acceptance:**

1. Patrolled (Alpha): zero ambient combat hostiles on undock. ✅
2. Contested (Beta): ambient hostiles allowed; counts/offsets from balance. ✅
3. Lawless (Gamma): denser or meaner than contested — difference asserted. ✅ (count 2 + gunboat)
4. Station safe radius + undock grace still prevent pad ganking. ✅ (`test_undock_grace_blocks_hostile_fire`)
5. Active bounty ensures one live hostile in lock range if ambient died/far. ✅
6. Concurrent hostiles ≤ balance cap (≤3). ✅
7. Lint + GUT green. ✅ (`tests/test_e2_encounters.gd`)

### E2.3 Attribution feedback

**Status:** done (2026-07-31)

**Feedback:** FlightHUD temporary toast from existing kill bus signals. Pure formatters in BalanceStanding. Witness count = live `NpcTraffic.live_ship_count()` (not fixed 1). No new standing rules.

**Acceptance:**

1. Attributed kill: short HUD line naming local controller / that standing fell. ✅ (`Kill recorded — %s standing fell.`)
2. Unattributed kill: plain line that kill was not recorded. ✅ (`Kill not recorded — no standing change.`)
3. Headless tests for formatters / HUD state from kill bus signals. ✅ (`tests/test_e2_attribution_feedback.gd`)
4. Witness count from live ambient traffic (not permanent lie of 1). ✅ Patrolled still attributes at 0; contested needs traffic/evidence; lawless needs evidence.
5. Status moment still local controller only. ✅
6. Standing mutations only via StandingService. ✅
7. Lint + GUT; events.md listeners updated (no new signals). ✅

### E2.4 Hauler hull law data

**Status:** done (2026-07-31)

**Shape:** Starter content id stays `hull_courier` (D3); display **Hauler**. Full play fields on `Hull`: cargo_capacity, weapon_damage / weapon_cooldown / projectile_speed, role (`hauler` | `fighter`). `ShipService` (Main child, session-only) is single writer for `active_hull_id` (default Hauler). Cargo hold capacity follows active hull; no-hull fallback is `BalanceEconomy.CARGO_CAPACITY`. Fighter baseline lives as `BalanceCombat.FIGHTER_BASELINE_*` math constants until E2.5 content. Active hull id is **not** saved yet — E2.5 owns optional `ship` section + ownership/switch.

**Acceptance:**

1. Hull gains cargo_capacity, weapon fields, role/tag; validation fails invalid. ✅
2. CargoService uses active hull capacity. ✅
3. Starter is Hauler-class (`hull_courier`, display Hauler); cargo supports grain/scrap routes. ✅ (capacity 20)
4. Automated: Hauler DPS/TTK vs hard profile worse than Fighter baseline math. ✅ (`tests/test_e2_hauler_hull.gd`)
5. Save/load cargo still works; active hull session-only (E2.5 persists). ✅
6. Lint + GUT; hull budget ≤2. ✅

### E2.5 Fighter + station switch

**Status:** done (2026-07-31)

**Shape:** `hull_fighter` content (display Fighter, role fighter, cargo 1, weapons =
`FIGHTER_BASELINE_*`). Pay once `FIGHTER_PURCHASE_COST` (1000) while docked;
Services shows Buy Fighter / Switch hull. Switch blocked when cargo volume >
target capacity (D2). Optional save `ship` section; missing → Hauler only.
Silhouette: steel + tall fin vs Hauler gold wings. One active hull in space.

**Acceptance:**

1. `hull_fighter` content: high combat, cargo 0 or 1. ✅
2. New game: Hauler only; Fighter bought once for credits (balance cost). ✅
3. Docked Services: Buy Fighter / Switch hull without console. ✅ (`test_station_services_buy_and_switch_path`)
4. Switch refuses if cargo volume > target capacity. ✅ (D2: `switch_hull` only player path; `apply_section` / career load clamp overweight active to largest owned that fits)
5. Switch applies flight + weapon + cargo immediately; silhouette differs. ✅ (`role_silhouette` + mesh albedo; `test_switch_changes_role_silhouette`)
6. Fighter beats hard profile; Hauler worse (test). ✅
7. Fighter cannot load grain-route volume (capacity test). ✅
8. Optional save `ship` section: active_hull_id, owned_hull_ids; missing → Hauler only. ✅
9. Captain sheet shows current hull name. ✅
10. No Ops / dual ships in space. ✅
11. Lint + GUT + save round-trip. ✅ (`tests/test_e2_fighter_switch.gd`)

### E2.6 Performance densify

**Status:** done (2026-07-31)

**Shape:** `PERF_BUDGET_SHIPS = 12` in BalanceEconomy. Traffic raised for multi-ship
feel: patrolled **8** / contested **8** / lawless **5** (was 6/4/2). Densest legal
layout is **contested** at concurrent hostile cap:
`1 player + 8 traffic + 3 hostiles = 12`. Orbit traffic still display-only;
hostiles still combat-group only. Witness count remains live traffic ships.

**Acceptance:**

1. Traffic + hostiles + player densest layout ≤12 (balance constant + test). ✅
2. Spawn smoke for densest system — no hard error. ✅ (`tests/test_e2_performance.gd`)
3. Orbit traffic non-combat; hostiles combat-only. ✅
4. Attribution witnesses still sane with denser traffic. ✅ Contested traffic ≥ threshold.
5. Lint + GUT green. ✅

### E2.7 Gate — Combat & hull feel

**Status:** **signed** 2026-07-31. Play script in `docs/gates.md`.

## Explicitly OUT

Operations, Holding, debt/upkeep (E3), opening cast (E4), escort/smuggle, 2nd recovery, hybrid hulls, damage matrix, greenfield combat rewrite.

## Sequencing

```
E2.1 → E2.2 → E2.3
         ↘ E2.4 → E2.5 → E2.6 → E2.7 gate
```
