# Beta E4 — Opening & cast

**Status:** **Closed** — E4.1–E4.6 done; **[GATE] E4.7 signed** 2026-07-31  
**Date:** 2026-07-31  
**Authority:** Destination opening rhyme + character axes + standing law

## Job

Career starts as a story: life-path picks with teeth, annexation opening, second recovery foothold, clearer names.

## Locked defaults

| ID | Lock |
|----|------|
| D1 | 3 axes × 3 options (9 rows) |
| D2 | Axes: Origin · Former trade · The mark |
| D3 | Teeth = standing + credits + optional debt only |
| D4 | Default headless: periphery + merchant + clean |
| D5 | Annexation is presentation only (Alpha already Reach) |
| D6 | Re-fire status moment after path apply |
| D7 | Starter dock Alpha Port |
| D8 | 2nd recovery: Drift / Cut Jax |
| D9 | Recovery budget 2 |
| D10 | Optional save career keys; no envelope bump |
| D11 | Continue skips create + annexation |
| D12 | No typed captain name |
| D13 | Presentation = copy/flavor, not art |
| D14 | StandingService single writer |

## Caps

3 systems, 6 stations, 4 entities, people ≤20, recovery 2, 9 path options, job kinds 3, hulls 2, perf 12.

## Contracts

| ID | Name | Status |
|----|------|--------|
| E4.1 | Life path data + apply | **done** 2026-07-31 |
| E4.2 | Create UI | **done** 2026-07-31 |
| E4.3 | Annexation beat | **done** 2026-07-31 |
| E4.4 | Second recovery (Jax/Drift) | **done** 2026-07-31 |
| E4.5 | Named presentation pass 2 | **done** 2026-07-31 |
| E4.6 | Integration / save | **done** 2026-07-31 |
| E4.7 | **[GATE] Opening feel** | **signed** 2026-07-31 |

## E4.1 done — Life path data + apply

**What the game does:** nine life-path options; `CareerStart.apply` / `apply_default`; standing only via StandingService; debt mark reuses E3 loan; status moment re-fires after path.

| Option id | Display | Teeth |
|-----------|---------|-------|
| origin_core | Core World | Reach +15; Free Haulers −5 |
| origin_periphery | Periphery-born | Fringe Collective +15 |
| origin_charterfall | Stateless Charterfall refugee | Free Haulers +12; Reach −10; Grease Wren +8 |
| trade_navy | Ex-Navy | Reach +18; Drift −12 |
| trade_merchant | Merchant marine | Free Haulers +15; Mate Dace +10 |
| trade_smuggler | Smuggler | Drift +18; Reach −15; Cut Jax +12 |
| mark_cancelled | Cancelled charter | Reach −25; Free Haulers +5 |
| mark_debt | Debt | Start E3 loan (owe 480, principal 400) |
| mark_clean | Clean | no extra |

**Evidence:** `tests/test_e4_life_path.gd` (9).

## E4.2 done — Create UI

**What the game does on New Game:**

- Shows **WHO WERE YOU** create screen with three columns (Origin / Former trade / The mark).
- Each option shows name, blurb, and teeth summary.
- Confirm disabled until all three picked; Cancel → main menu with clean teardown (no half career).
- Confirm emits `on_life_path_confirmed` → Main calls `CareerStart.apply` → annexation.

**Does not** auto-apply default on human New Game. Headless/tests still call `apply_default` directly.

**Evidence:** `tests/test_e4_create_ui.gd`.

## E4.3 done — Annexation beat

**What the game does after path confirm:**

- Dismissible panel: title **The corridor is claimed**; body that Reach runs the pad.
- Baggage line from post-path local standing (tier + controller).
- Status moment for Alpha system + starter station after path apply.
- Continue → tip → docked play.
- Continue/load never shows annexation (D11). Presentation only (D5) — no world-control mutate.

**Evidence:** `tests/test_e4_opening.gd`.

## E4.4 done — Second recovery (Drift / Cut Jax)

**What the game does:**

- Two personal recovery chains (`recovery_chains` budget **2**).
- **Dockhand Mendi** at Reach docks; **Cut Jax** at Drift docks.
- Same Friendly personal + deniable rules; StandingService only.

| Chain id | Person | Entity | Steps |
|----------|--------|--------|-------|
| `recovery_reach_mendi` | `person_ra_mendi` | `entity_reach_authority` | 4 |
| `recovery_drift_jax` | `person_bs_jax` | `entity_beta_syndicate` | 4 |

**Evidence:** `tests/test_e4_recovery_jax.gd` (12).

## E4.5 done — Named presentation pass 2

**What the game does:**

- Captain sheet shows **Origin / Trade / Mark** when path is set; hides lines for old saves.
- Main menu tagline under DRAYWAR.
- Alpha Port / Yard flavor mentions Reach-run pad / claimed corridor (copy only).

**Evidence:** `tests/test_e4_integration.gd` (sheet + tagline + flavor).

## E4.6 done — Integration / save

**What the game does:**

- Optional save section `career`: `origin_id`, `trade_id`, `mark_id`, `opening_complete`.
- `CareerPathState` holds ids (data layer); `CareerStart` applies teeth + updates state.
- Round-trip save; missing keys = old saves.
- Softlocks: default playable (not all-neutral); debt start has debt; cancelled+smuggler still has Mendi/Jax recovery content open.

**Evidence:** `tests/test_e4_integration.gd`. Lint + full GUT **478/478**. **Not committed.**

## New Game order (locked)

create UI (3 picks) → annexation → fly tip → station menu docked.

Continue/load skips create + annexation.

## OUT

Ops, Holding, new systems, 3rd recovery, live annexation sim, production art, escort, typed name.
