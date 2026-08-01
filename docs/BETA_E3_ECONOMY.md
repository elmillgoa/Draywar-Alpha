# Beta E3 — Economy pressure

**Status:** **Closed** — code complete; **[GATE] E3.6 signed** 2026-07-31  
**Date:** 2026-07-31  
**Authority:** Destination §6–7 + `docs/BETA_ROADMAP.md` E3 + standing law  
**Gates:** E2.7 and E3.6 both signed 2026-07-31.

## Job

Money stops being optional: bills, risk, and a thin debt escape hatch force real choices.

## Locked defaults (no ask)

| ID | Lock |
|----|------|
| D1 | Undocked life-support credit drain; off while docked |
| D2 | One Free Haulers loan: +400, repay 480, 25% job garnish, manual repay, grace standing hit only |
| D3 | Munitions contraband for Reach; fine + standing on Reach dock with hold |
| D4 | Third job kind = **smuggle** (not escort) |
| D5 | Optional wallet keys; no envelope bump |
| D6 | Fighter still cash-only |
| D7 | Idle free-fly + travel must spend; broke ≠ dead |

## Caps

Stay at 3 systems / 6 stations / 4 entities. Job kinds ≤3. Contract templates budget → 12. Commodities ≤10. Hulls 2. Perf 12 ships.

## Contracts

| ID | Name | Status |
|----|------|--------|
| E3.1 | Career pressure (upkeep + fuel) | **done** |
| E3.2 | Debt seed | **done** |
| E3.3 | Contraband jurisdiction | **done** |
| E3.4 | Smuggle job kind | **done** |
| E3.5 | Integration / balance pass | **done** |
| E3.6 | **[GATE] Economy pressure feel** | **signed** 2026-07-31 |

### E3.1 Career pressure

1. Undocked scaled time burns credits at balance rate; docked does not. ✅  
2. Credits never go negative. ✅  
3. Fuel still gates thrust/jumps; retune only in balance. ✅  
4. Headless: fixed seconds undocked → known delta; docked → zero. ✅  
5. Lint + GUT. No new standing. ✅  

**Done 2026-07-31.** `WalletService.tick_upkeep(delta_scaled, is_docked)` is the
single money path for life-support. PlayerShip ticks it each physics frame with
`TimeScale.scaled_delta`. Rate: `BalanceEconomy.UPKEEP_CREDITS_PER_SECOND = 1.0`.
Fuel light retune: burn 0.4/s (was 0.35), jump 14 (was 12). HUD shows LOW + warn
color at ≤ `UPKEEP_LOW_FUNDS_THRESHOLD` (50). Tests: `tests/test_e3_upkeep.gd`.

### E3.2 Debt seed

1. Borrow once to cap; no second loan. ✅  
2. Job pay auto-garnish 25% to debt. ✅  
3. Manual repay; save round-trips debt. ✅  
4. Missing keys → no debt. ✅  
5. Grace expiry → Free Haulers standing hit only via StandingService. ✅  
6. Debt ≠ repossess / game-over. ✅  
7. Lint + GUT + save_schema note. ✅  

**Done 2026-07-31.** Free Haulers thin loan (D2): receive
`BalanceEconomy.LOAN_PRINCIPAL` (400), owe `LOAN_REPAY_TOTAL` (480). No stack
while debt open. Mission complete pays through
`WalletService.apply_job_pay_with_garnish` (25% seize, player gets remainder).
Manual repay on station Services. Fee-charging docks while debt unpaid and
credits < `MIN_PAYMENT_FLOOR` (20) burn grace (`GRACE_DOCKS` = 3); expiry hits
Free Haulers only via `StandingService` (`DEBT_GRACE_EXPIRED_DELTA` = -12,
`REASON_DEBT_GRACE_EXPIRED`) — no dock ban invent, no ship loss. Optional
wallet keys `debt_owed` / `debt_lender_id` / `debt_grace_docks_left` (no
envelope bump). Services: Borrow / Repay. Captain sheet debt line. Tests:
`tests/test_e3_debt.gd`.

### E3.3 Contraband

1. Munitions not buy/sell at Reach stations. ✅  
2. Tradeable at ≥1 non-Reach dock. ✅  
3. Reach dock with munitions → fine + standing hit. ✅  
4. No new tiers. Validation on commodity field. ✅  
5. Lint + GUT. ✅  

**Done 2026-07-31.** Jurisdictional contraband (D3): `Commodity.contraband_for_entity_ids`
lists Entities that restrict open-market trade. Munitions lists
`entity_reach_authority` only — blocked at Alpha Port/Yard; legal at Beta Hub
(and other non-Reach docks). Fee-charging dock with restricted hold → flat fine
`BalanceEconomy.CONTRABAND_FINE_BASE` (100, partial if broke), standing hit
`BalanceStanding.CONTRABAND_STANDING_DELTA` (-10) via StandingService only
(`REASON_CONTRABAND`), seize-all when `CONTRABAND_SEIZE_ALL` (true). Session
restore does not re-inspect. Trade UI shows RESTRICTED here. Content validation
rejects empty/nobody/invalid/duplicate list entries. Status moment unchanged.
Tests: `tests/test_e3_contraband.gd`.

### E3.4 Smuggle

1. Three kinds: delivery, bounty, smuggle. ✅  
2. Accept loads cargo; complete needs dest + cargo; pays. ✅  
3. Reach inspection still applies. ✅  
4. Fighter refuses oversized; Hauler can. ✅  
5. Board/HUD readable. ✅  
6. Lint + GUT; budget ≤12 contracts. ✅  

**Done 2026-07-31.** Third job kind (D4, not escort). `BalanceStanding.MISSION_KIND_SMUGGLE`
=`&"smuggle"`. `ContractType` cargo fields: `cargo_commodity_id`, `cargo_quantity`
(validated for smuggle). Two templates (munitions, qty 5):
`contract_smuggle_beta_to_gamma` (pay 240 → Gamma Outpost) and
`contract_smuggle_gamma_to_beta` (pay 260 → Beta Hub). Dest is gray station — not
a Reach market turn-in. Accept refuses if free volume < load; complete requires
dest dock + cargo still held, then removes cargo and pays (garnish path).
Abandon leaves cargo. Fighter hold (1) cannot accept; Hauler (20) can. Reach dock
with munitions still runs E3.3 inspect (fine/seize/standing). Mission save
restores without double-loading cargo. Budget `contract_types` → 12. Tests:
`tests/test_e3_smuggle.gd`.

### E3.5 Integration

Scenario tests for pressure math; no softlock new game → first job (loan OK); full suite green.

**Done 2026-07-31.** Integration scenarios in `tests/test_e3_integration.gd`
use named `BalanceEconomy` windows:
`SCENARIO_FREE_FLY_SLICE_SECONDS` (60), `SCENARIO_PRESSURE_JUMP_COUNT` (3),
`SCENARIO_SHORT_UPKEEP_SECONDS` (30), `SCENARIO_FIRST_JOB_UNDOCK_SECONDS` (20).

**Scenario numbers (no retune required):**

| Check | Math | Result |
|-------|------|--------|
| Never-earn travel > one courier | 3× jump fuel replace (105) + 60s upkeep (60) + free-fly fuel (60) = **225** vs courier **120** | pass |
| Upkeep + jumps alone > courier | 60 + 105 = **165** vs **120** | pass |
| Smuggle min pay covers fine + short bills | pay **240** − fine **100** − short upkeep **30** − one jump fuel **35** = margin **75** | pass |
| Start → first dock job | 500 − 20s upkeep − Alpha fee 30 → still **> low-funds (50)**; broke → loan **400** covers fee + refuel chunk | pass |

Captain sheet: credits, fuel, hull, debt, active job (verified live). Station
Services: Borrow / Repay beside refuel/repair. No Ops/Holding. No balance rate
retune — existing E3.1–E3.4 constants already satisfied pressure + softlock.

### E3.6 Gate

Feel: do bills and risk force choices? Play script in `docs/gates.md`.
Sign → E4.

## OUT

Full debt ladder, escort, Ops, Holding, dynamic economy, customs minigames, 2nd recovery, new systems.
