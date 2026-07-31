# Beta E3 — Economy pressure

**Status:** Next after E2 code-complete  
**Date:** 2026-07-31  
**Authority:** Destination §6–7 + `docs/BETA_ROADMAP.md` E3 + standing law  
**Gate E2.7:** open for Elliot play later; E3 code may proceed per session order (test later).

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
| E3.1 | Career pressure (upkeep + fuel) | pending |
| E3.2 | Debt seed | pending |
| E3.3 | Contraband jurisdiction | pending |
| E3.4 | Smuggle job kind | pending |
| E3.5 | Integration / balance pass | pending |
| E3.6 | **[GATE] Economy pressure feel** | after code |

### E3.1 Career pressure

1. Undocked scaled time burns credits at balance rate; docked does not.  
2. Credits never go negative.  
3. Fuel still gates thrust/jumps; retune only in balance.  
4. Headless: fixed seconds undocked → known delta; docked → zero.  
5. Lint + GUT. No new standing.

### E3.2 Debt seed

1. Borrow once to cap; no second loan.  
2. Job pay auto-garnish 25% to debt.  
3. Manual repay; save round-trips debt.  
4. Missing keys → no debt.  
5. Grace expiry → Free Haulers standing hit only via StandingService.  
6. Debt ≠ repossess / game-over.  
7. Lint + GUT + save_schema note.

### E3.3 Contraband

1. Munitions not buy/sell at Reach stations.  
2. Tradeable at ≥1 non-Reach dock.  
3. Reach dock with munitions → fine + standing hit.  
4. No new tiers. Validation on commodity field.  
5. Lint + GUT.

### E3.4 Smuggle

1. Three kinds: delivery, bounty, smuggle.  
2. Accept loads cargo; complete needs dest + cargo; pays.  
3. Reach inspection still applies.  
4. Fighter refuses oversized; Hauler can.  
5. Board/HUD readable.  
6. Lint + GUT; budget ≤12 contracts.

### E3.5 Integration

Scenario tests for pressure math; no softlock new game → first job (loan OK); full suite green.

### E3.6 Gate

Feel: do bills and risk force choices? Sign → E4.

## OUT

Full debt ladder, escort, Ops, Holding, dynamic economy, customs minigames, 2nd recovery, new systems.
