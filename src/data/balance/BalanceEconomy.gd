class_name BalanceEconomy
extends RefCounted

## Money, fuel, fees, repairs, trade cargo, and NPC traffic tunables — A5 / B3.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5, Alpha/ALPHA_DECISION_PHASE_PLAN.md B3
##
## Wallet, fuel burn, docking fees, refuel/repair station services, mission pay
## defaults, jump fuel cost, cargo capacity / trade copy, and gray-box NPC
## traffic density live here.

# --- Wallet / fuel boot ----------------------------------------------------

## Starting credits for a new session (enough for fees + one refuel).
const STARTING_CREDITS: int = 500

## One-time Fighter hull purchase at a station Services desk (E2.5 / D1).
## Affordable after a few jobs (MISSION_PAY_DEFAULT 120) from the 500 start.
const FIGHTER_PURCHASE_COST: int = 1000

## Life-support / free-fly upkeep while undocked (E3.1 / D1).
## Credits burned per second of scaled game time. Docked = off.
## 1.0 → ~30–60s free-fly is a clear bite vs STARTING_CREDITS (500);
## broke stops drain at 0 (never negative; debt is E3.2).
const UPKEEP_CREDITS_PER_SECOND: float = 1.0

## HUD warns on the credits line at or below this balance (E3.1 optional).
const UPKEEP_LOW_FUNDS_THRESHOLD: int = 50

# --- E3.5 pressure scenario windows (integration / balance pass) ------------
# Named so tests and balance share one free-fly / hop / short-travel definition.
# Rates above are the real levers; these only size the scenario math.

## Free-fly scaled seconds used in "idle costs more than a courier" checks.
const SCENARIO_FREE_FLY_SLICE_SECONDS: float = 60.0

## Gate hops in multi-system travel pressure (Alpha → Beta → Gamma style).
const SCENARIO_PRESSURE_JUMP_COUNT: int = 3

## Short travel upkeep window for smuggle margin vs fine + bills.
const SCENARIO_SHORT_UPKEEP_SECONDS: float = 30.0

## Brief undock window before first dock/job on a new career (softlock path).
const SCENARIO_FIRST_JOB_UNDOCK_SECONDS: float = 20.0

# --- Emergency loan (E3.2 / D2) --------------------------------------------
# One Free Haulers thin loan. No repossession, no game-over. Grace → standing
# hit on Free Haulers only (via StandingService). Optional wallet save keys.

## Credits the player receives when borrowing (principal paid out).
const LOAN_PRINCIPAL: int = 400

## Flat amount owed after borrow (principal + 20% fee → 480).
const LOAN_REPAY_TOTAL: int = 480

## Fraction of job pay seized toward debt until clear (25%).
const GARNISH_RATE: float = 0.25

## Dock events with unpaid debt and credits below MIN_PAYMENT_FLOOR before
## Free Haulers standing hit. Decrements only on real fee-charging docks.
const GRACE_DOCKS: int = 3

## If docked with debt and credits below this, one grace dock is burned.
## Small floor so a broke player still feels pressure without needing a full
## installment ready every stop.
const MIN_PAYMENT_FLOOR: int = 20

## Lender Entity content id (Free Haulers).
const LOAN_LENDER_ENTITY_ID: StringName = &"entity_free_haulers"

## Wallet mutation / log reason tags (money path; standing uses BalanceStanding).
const REASON_LOAN_BORROW: StringName = &"loan_borrow"
const REASON_LOAN_REPAY: StringName = &"loan_repay"
const REASON_LOAN_GARNISH: StringName = &"loan_garnish"

## Fuel tank capacity (units). Full at boot.
const FUEL_MAX: float = 100.0

## Starting fuel (full tank).
const STARTING_FUEL: float = 100.0

## Fuel units burned per second at full throttle (scaled by throttle).
## E3.1 light retune: free-fly + travel must spend (D7); was 0.35.
const FUEL_BURN_PER_SECOND_AT_FULL: float = 0.4

## Extra fuel burn multiplier while afterburner is held.
const FUEL_AFTERBURNER_MULTIPLIER: float = 1.8

## Near-zero fuel; ship motion treats this as empty.
const FUEL_EMPTY_EPSILON: float = 0.001

# --- Docking fees by system policing ---------------------------------------

## Docking fee (credits) in patrolled space.
## E1.4: mild bump so dock fees stay a real credit sink.
const DOCK_FEE_PATROLLED: int = 30

## Docking fee in contested space.
const DOCK_FEE_CONTESTED: int = 18

## Docking fee in lawless space (cheaper, riskier).
const DOCK_FEE_LAWLESS: int = 5

## Default fee when policing is unknown.
const DOCK_FEE_DEFAULT: int = 18

# --- E1.5 enforcement lite (standing surcharge / service friction) ---------
# Applied from station controller standing via StandingService.tier_for only.
# No new tiers or standing math — docs/reputation_and_standing.md is law.

## Dock fee multiplier when controller standing is Neutral or better.
const DOCK_FEE_STANDING_MULT_DEFAULT: float = 1.0

## Dock fee multiplier at Unfriendly (controller).
const DOCK_FEE_STANDING_MULT_UNFRIENDLY: float = 1.5

## Dock fee multiplier at Hostile (controller).
const DOCK_FEE_STANDING_MULT_HOSTILE: float = 2.0

## Dock fee multiplier at Hated (controller) — worse than Hostile.
const DOCK_FEE_STANDING_MULT_HATED: float = 2.5

## Refuel/repair cost multiplier when Neutral or better.
const SERVICE_COST_MULT_DEFAULT: float = 1.0

## Refuel/repair cost multiplier at Unfriendly (controller).
const SERVICE_COST_MULT_UNFRIENDLY: float = 1.35

## Refuel cost multiplier at Hostile (repair is refused at Hostile+).
const SERVICE_COST_MULT_HOSTILE: float = 2.0

## Refuel cost multiplier at Hated (repair refused; leave-path fuel only).
const SERVICE_COST_MULT_HATED: float = 2.5

# --- Station services ------------------------------------------------------

## Credits per fuel unit when refueling.
## E1.4: slight raise — fuel remains a real money pressure without trapping the player.
const REFUEL_CREDITS_PER_UNIT: float = 2.5

## Minimum fuel units purchased in one refuel action (or remaining capacity).
const REFUEL_CHUNK: float = 25.0

## Full repair cost when condition is empty.
## E1.4: mild bump; full repair still affordable after a few jobs.
const REPAIR_FULL_COST: int = 100

## Ship condition range.
const CONDITION_MAX: float = 100.0
const CONDITION_MIN: float = 0.0

## Starting ship condition.
const STARTING_CONDITION: float = 100.0

## Condition lost per second while afterburning.
const CONDITION_WEAR_PER_SECOND_AFTERBURN: float = 0.4

## Speed multiplier when condition is at minimum (still flyable).
const CONDITION_MIN_SPEED_FACTOR: float = 0.55

# --- Jump / gate -----------------------------------------------------------

## Fuel cost to jump through a gate.
## E3.1 light retune: gate hops stay a real fuel tax with upkeep pressure; was 12.
const JUMP_FUEL_COST: float = 14.0

## Distance at which the HUD shows a jump prompt (metres).
const GATE_APPROACH_RADIUS: float = 90.0

## Distance at which the jump action is accepted (metres).
const GATE_INTERACT_RADIUS: float = 45.0

## Where the ship appears after a jump (relative to destination gate).
const JUMP_ARRIVAL_OFFSET: Vector3 = Vector3(0.0, 8.0, 70.0)

## Angular step (degrees) between multiple gate markers around GATE_POSITION.
const GATE_ARC_STEP_DEGREES: float = 40.0

## Radius of the gate placement arc (metres from GATE_POSITION).
## Raised E6.1 with stretched multi-gate layout so arcs are not knotted.
const GATE_ARC_RADIUS: float = 100.0

# --- Mission pay defaults --------------------------------------------------

## Credits paid on mission complete when ContractType does not override.
const MISSION_PAY_DEFAULT: int = 120

## Credits paid on recovery step complete (personal work stipend).
const RECOVERY_STEP_PAY: int = 40

# --- Cargo / trade (B3) ----------------------------------------------------

## Content category directory for commodities.
const COMMODITY_CONTENT_CATEGORY: StringName = &"commodities"

## Hold capacity fallback when no active hull is available (tests / pre-boot).
## Live play prefers Hull.cargo_capacity from the active ShipService hull (E2.4).
## Mirrors starter Hauler content (`hull_courier` cargo_capacity = 20).
const CARGO_CAPACITY: int = 20

## Default trade button quantity.
const TRADE_QTY_UNIT: int = 1

## Trade sides for on_trade_completed.
const TRADE_SIDE_BUY: StringName = &"buy"
const TRADE_SIDE_SELL: StringName = &"sell"

# --- Contraband jurisdiction (E3.3 / D3) -----------------------------------
# Munitions restricted for Reach Authority. Open market blocked at Reach
# stations; legal elsewhere. Fee-charging dock with restricted hold → fine +
# standing hit (via StandingService) + optional seize. Session restore does
# not re-inspect (same path as debt grace: real docks only).

## Flat fine (credits) charged once per inspection when restricted cargo found.
## Partial if broke (floors at remaining credits); standing + seize still apply.
const CONTRABAND_FINE_BASE: int = 100

## When true, all restricted goods for the controller are removed from hold.
## Prefer seize-all for Alpha (locked D3 preference).
const CONTRABAND_SEIZE_ALL: bool = true

## Wallet / log reason tag for the fine (standing uses BalanceStanding.REASON_CONTRABAND).
const REASON_CONTRABAND_FINE: StringName = &"contraband_fine"

## Floor for resolved unit prices after modifiers (credits). Mirrored by
## `BalanceMarket.PRICE_FLOOR_CREDITS`, which is what the live market applies.
const TRADE_PRICE_MIN: int = 1

# --- Trade row contract (CargoService.trade_row → station trade UI) ---------
# One dictionary per commodity at the docked station: everything the row shows
# and the caps that decide what the buttons may do. The UI reads these keys; it
# never works a price or a cap out for itself (docs/economy_sim.md §8).

## True when the docked station keeps a market in this commodity at all.
const TRADE_ROW_KEY_TRADED: StringName = &"traded"

## Whole units on this station's shelf right now.
const TRADE_ROW_KEY_STOCK: StringName = &"stock"

## Credits for the next single unit bought here.
const TRADE_ROW_KEY_UNIT_BUY: StringName = &"unit_buy"

## Credits paid for the next single unit sold here.
const TRADE_ROW_KEY_UNIT_SELL: StringName = &"unit_sell"

## The market's own plain-language line explaining this price.
const TRADE_ROW_KEY_REASON: StringName = &"reason"

## Most units the player may buy here now — market cap, hold and wallet.
const TRADE_ROW_KEY_MAX_BUY: StringName = &"max_buy"

## Most units the player may sell here now — market cap and what is held.
const TRADE_ROW_KEY_MAX_SELL: StringName = &"max_sell"

## Which of the three limits actually bit on the buy side (TRADE_LIMIT_*).
const TRADE_ROW_KEY_BUY_LIMIT: StringName = &"buy_limit"

## Which limit bit on the sell side (TRADE_LIMIT_*).
const TRADE_ROW_KEY_SELL_LIMIT: StringName = &"sell_limit"

## Limit tag: the station's own weight caps stopped the trade.
const TRADE_LIMIT_MARKET: StringName = &"market"

## Limit tag: the cargo hold stopped it (full when buying, empty when selling).
const TRADE_LIMIT_HOLD: StringName = &"hold"

## Limit tag: the wallet stopped it.
const TRADE_LIMIT_CREDITS: StringName = &"credits"

# --- Save (optional sections, schema v1) -----------------------------------

const SAVE_SECTION_KEY: StringName = &"wallet"
const SAVE_KEY_CREDITS: StringName = &"credits"
const SAVE_KEY_FUEL: StringName = &"fuel"
const SAVE_KEY_CONDITION: StringName = &"condition"
## Optional E3.2 debt keys (missing → no debt; no envelope version bump).
const SAVE_KEY_DEBT_OWED: StringName = &"debt_owed"
const SAVE_KEY_DEBT_LENDER_ID: StringName = &"debt_lender_id"
const SAVE_KEY_DEBT_GRACE_DOCKS_LEFT: StringName = &"debt_grace_docks_left"
## Fractional upkeep owed but not yet charged as a whole credit. Without it a
## reload forgives whatever part-credit the player had already run up.
const SAVE_KEY_UPKEEP_DEBT: StringName = &"upkeep_debt"

## Optional cargo section key (inventory map is the section body).
const SAVE_SECTION_CARGO: StringName = &"cargo"

# --- NPC traffic -----------------------------------------------------------

## Scene-tree group for ambient orbit traffic (attribution witnesses).
const GROUP_NPC_TRAFFIC: StringName = &"npc_traffic"

## Performance budget: player + orbit traffic + combat hostiles in one system.
## E6.4 target: 20 concurrent ships (60 fps goal on dev machine).
## Densest legal layout must stay ≤ this (asserted in tests). Do not silently drop.
const PERF_BUDGET_SHIPS: int = 20

## Pre-E6 / E5 densify bar (kept for regression asserts — density must exceed this).
const PERF_BUDGET_SHIPS_E5_BASELINE: int = 12

## Always one player hull in space (no dual-ship Ops).
const PERF_BUDGET_PLAYER_COUNT: int = 1

## NPC ship count for patrolled systems (busy government lanes).
## E6.4: densest patrolled → 1 player + this + 0 hostiles ≤ PERF_BUDGET.
const NPC_COUNT_PATROLLED: int = 16

## NPC ship count for contested systems.
## Densest legal layout: 1 player + this + MAX_CONCURRENT_HOSTILES ≤ PERF_BUDGET.
const NPC_COUNT_CONTESTED: int = 16

## NPC ship count for lawless systems (thinnest freighter traffic; hostiles meaner).
const NPC_COUNT_LAWLESS: int = 10

## Min live non-player ships in densest patrolled system (traffic; hostiles 0).
## Must exceed pre-E6 typical (8) so space reads busier after E6.4.
const DENSITY_FLOOR_PATROLLED_NON_PLAYER: int = 12

## Share of ambient traffic that orbits a secondary dock when multi-dock exists.
const NPC_SECONDARY_DOCK_TRAFFIC_SHARE: float = 0.25

## Local orbit radius around a secondary dock (metres from that pad).
const NPC_SECONDARY_ORBIT_MIN: float = 50.0
const NPC_SECONDARY_ORBIT_MAX: float = 140.0

## Test/feel: traffic "near" secondary if within this of the pad centre.
const NPC_SECONDARY_NEAR_RADIUS: float = 200.0

## Orbit radius range for NPC wander (metres from primary/system origin).
## Raised E6.1 so traffic uses stretched space; count raised E6.4.
const NPC_ORBIT_MIN: float = 120.0
const NPC_ORBIT_MAX: float = 600.0

## NPC wander speed (m/s).
const NPC_SPEED: float = 12.0

## NPC mesh size.
const NPC_MESH_SIZE: Vector3 = Vector3(2.0, 0.7, 3.8)

## NPC colour by policing (unshaded).
const NPC_COLOR_PATROLLED: Color = Color(0.35, 0.55, 0.85)
const NPC_COLOR_CONTESTED: Color = Color(0.75, 0.55, 0.25)
const NPC_COLOR_LAWLESS: Color = Color(0.55, 0.35, 0.35)
const NPC_COLOR_DEFAULT: Color = Color(0.5, 0.5, 0.55)

## Vertical spread for NPC orbits.
const NPC_HEIGHT_SPREAD: float = 20.0

## Angular speed base (radians per second) for orbiting NPCs.
const NPC_ORBIT_OMEGA: float = 0.08

## Extra omega spread factor across the NPC ring (t * this).
const NPC_ORBIT_OMEGA_SPREAD: float = 0.5

## Parity divisor for reversing every other NPC orbit.
const NPC_ORBIT_REVERSE_EVERY: int = 2

## Mid-index half factor for multi-gate arc centering.
const GATE_ARC_MID_HALF: float = 0.5

# --- HUD / station copy ----------------------------------------------------

const HUD_LINE_CREDITS: float = 4.0
const HUD_LINE_FUEL: float = 5.0
const HUD_LINE_MISSION: float = 6.0

const HUD_CREDITS_FORMAT: String = "CREDITS  %d"
const HUD_CREDITS_LOW_FORMAT: String = "CREDITS  %d  LOW"
const HUD_FUEL_FORMAT: String = "FUEL  %d%%"
const HUD_CONDITION_FORMAT: String = "HULL  %d%%"

## Jump prompt when in range and fuel is enough.
const JUMP_PROMPT_FORMAT: String = "PRESS F TO JUMP — %s"

## Jump prompt when fuel is too low.
const JUMP_PROMPT_NO_FUEL_FORMAT: String = "JUMP BLOCKED — need %s fuel for %s"

# --- Nav panel (B0 discoverable gates without console) ---------------------

## HUD line slots for nav block (right column; floats below title block).
const HUD_LINE_NAV_TITLE: float = 0.0
const HUD_LINE_NAV_HERE: float = 1.0
const HUD_LINE_NAV_GATES: float = 2.0

## Right-edge margin for the nav column.
const NAV_PANEL_RIGHT_MARGIN: float = 18.0

## Max gate lines listed on the HUD nav panel.
const NAV_MAX_GATE_LINES: int = 4

const NAV_TITLE_TEXT: String = "NAV"
const NAV_HERE_FORMAT: String = "HERE  %s"
const NAV_GATES_HEADER: String = "GATES"
const NAV_GATE_LINE_FORMAT: String = "→ %s"
const NAV_NO_GATES: String = "→ (none)"
const GATE_WORLD_LABEL_FORMAT: String = "GATE → %s"

## NPC capsule silhouette (distinct from station/gate/player).
const NPC_CAPSULE_RADIUS_FACTOR: float = 0.45
const NPC_MESH_PITCH_DEGREES: float = 90.0
const NPC_CAPSULE_RADIAL_SEGMENTS: int = 8

## Small dorsal fin / box so traffic ≠ hostile at a glance (E1.1).
const NPC_FIN_SIZE: Vector3 = Vector3(0.35, 1.1, 1.4)
const NPC_FIN_OFFSET: Vector3 = Vector3(0.0, 0.85, 0.15)
const NPC_FIN_LIGHTEN: float = 0.2

## Station service button labels.
const STATION_REFUEL_LABEL: String = "Refuel"
const STATION_REFUEL_MARKUP_LABEL: String = "Refuel (standing markup)"
const STATION_REPAIR_LABEL: String = "Repair ship"
## E3.2 emergency loan (Services desk, docked only).
const STATION_BORROW_FORMAT: String = "Borrow %d credits (owe %d)"
const STATION_REPAY_FORMAT: String = "Repay debt (%d owed)"
const STATION_REPAY_LABEL: String = "Repay debt"
const STATION_BORROW_OK_FORMAT: String = "Borrowed %d. Owe %d to Free Haulers."
const STATION_BORROW_DENIED: String = "Cannot borrow — already in debt."
const STATION_REPAY_OK_FORMAT: String = "Paid %d toward debt. %d left."
const STATION_REPAY_CLEARED: String = "Debt cleared."
const STATION_REPAY_BROKE: String = "No credits to put toward debt."
## E2.5 hull buy / switch (Services desk, docked only).
const STATION_BUY_FIGHTER_FORMAT: String = "Buy Fighter (%d credits)"
const STATION_BUY_FIGHTER_OWNED_LABEL: String = "Fighter owned"
const STATION_SWITCH_HULL_FORMAT: String = "Switch to %s"
const STATION_SWITCH_BLOCKED_CARGO: String = "Sell cargo down to switch hull"
const STATION_BUY_FIGHTER_OK: String = "Fighter purchased."
const STATION_BUY_FIGHTER_BROKE: String = "Not enough credits for Fighter."
const STATION_SWITCH_OK_FORMAT: String = "Now flying %s."
const STATION_SWITCH_FAILED: String = "Cannot switch hull here."
## Repair button when Hostile/Hated with controller (still docked via recovery).
const STATION_REPAIR_DENIED_LABEL: String = "Repair refused — standing"
## Trade section banner when Hostile/Hated with controller.
const STATION_TRADE_DENIED_MESSAGE: String = "Trade closed — standing too low"
## Dock fee readout while docked (base rate for this system + standing mult).
const STATION_DOCK_FEE_FORMAT: String = "Dock fee here: %d credits"
const STATION_DOCK_FEE_SURCHARGE_FORMAT: String = "Dock fee here: %d credits (standing surcharge)"
const STATION_TURN_IN_JOB_LABEL: String = "Turn in job"
const STATION_ABANDON_JOB_LABEL: String = "Abandon job"
const STATION_COMPLETE_RECOVERY_LABEL: String = "Complete recovery work"
const STATION_ABANDON_RECOVERY_LABEL: String = "Abandon recovery work"
const STATION_ASK_FAVOR_FORMAT: String = "Ask favor of %s"
const STATION_BETRAY_FORMAT: String = "Betray %s"
const STATION_UNDOCK_LABEL: String = "Undock"

## Station menu job turn-in feedback (no silent no-ops).
const STATION_TURN_IN_OK_FORMAT: String = "Job complete. +%d credits."
const STATION_TURN_IN_WRONG_STATION_FORMAT: String = "Deliver to %s first."
const STATION_TURN_IN_NO_JOB: String = "No active job to turn in."
const STATION_TURN_IN_FAILED: String = "Could not turn in job here."

## Station menu section headers (B3 / B5 drama).
const STATION_SECTION_JOBS: String = "Jobs"
const STATION_SECTION_SERVICES: String = "Services"
const STATION_SECTION_TRADE: String = "Trade"
const STATION_SECTION_CONTACTS: String = "Contacts"
## Contacts row: display name + rank (E1.2 density — people used on board).
const STATION_CONTACT_LINE_FORMAT: String = "%s — %s"
## Shown instead of Contacts when local controller standing is sticky-deep.
const STATION_SECTION_RECOVERY_DRAMA: String = "Recovery foothold"
## Hint under recovery header — %s = person display name.
const STATION_RECOVERY_DRAMA_HINT_FORMAT: String = (
	"%s still deals under the table. " + "Ask a favor, then take their work."
)

## Trade row headline. Args: display name, stock here, unit buy, unit sell, hold qty.
const STATION_TRADE_LINE_FORMAT: String = "%s   stock %d   buy %d   sell %d   hold %d"
## Trade row when commodity is restricted for the dock controller (E3.3).
## Args: display name, hold qty.
const STATION_TRADE_RESTRICTED_FORMAT: String = "%s  RESTRICTED here  hold %d"
## Trade row for a good this station keeps no market in. Args: name, hold qty.
const STATION_TRADE_NO_MARKET_FORMAT: String = "%s  —  no market here   hold %d"

## Buy / sell buttons carry the live total for the chosen quantity, straight
## from the quote: the marginal ladder means it is not unit price × quantity
## (docs/economy_sim.md §5). Args: units, credits.
const STATION_TRADE_BUY_FORMAT: String = "Buy %d — %d c"
const STATION_TRADE_SELL_FORMAT: String = "Sell %d — %d c"

## Fill-the-quantity buttons beside the amount box.
const STATION_TRADE_MAX_BUY_LABEL: String = "Max buy"
const STATION_TRADE_MAX_SELL_LABEL: String = "Max sell"

## Why a trade is capped below the amount asked for. Args: the cap.
## Which one shows is decided by the TRADE_LIMIT_* tag on the trade row, so
## "the shelf is thin" and "your hold is full" never get confused for each other.
const STATION_TRADE_CAP_MARKET_FORMAT: String = "The shelf only has %d."
const STATION_TRADE_CAP_HOLD_FORMAT: String = "You cannot carry more than %d."
const STATION_TRADE_CAP_CREDITS_FORMAT: String = "You can only afford %d."
const STATION_TRADE_CAP_SELL_MARKET_FORMAT: String = "This dock will only take %d."
const STATION_TRADE_CAP_SELL_HOLD_FORMAT: String = "You are only carrying %d."

## Same three reasons when the cap is zero — a count reads wrong there.
const STATION_TRADE_NONE_MARKET: String = "Nothing left on the shelf."
const STATION_TRADE_NONE_HOLD: String = "Your hold is full."
const STATION_TRADE_NONE_CREDITS: String = "You cannot afford any."
const STATION_TRADE_NONE_SELL_MARKET: String = "This dock will not take any more."
const STATION_TRADE_NONE_SELL_HOLD: String = "You are not carrying any."

## One-line sector headline on the station screen (S2 news ticker). Arg: line.
const STATION_NEWS_PREFIX_FORMAT: String = "SECTOR — %s"
## Dock inspection feedback (console / toast). Args: station name, fine, entity name.
const CONSOLE_CONTRABAND_SEIZED_FORMAT: String = (
	"Contraband seized at %s — fine %d credits. " + "Standing fell with %s."
)
## Dock inspection when fine applied but nothing left to seize (flag off / empty).
const CONSOLE_CONTRABAND_FINE_FORMAT: String = (
	"Contraband fine at %s — %d credits. " + "Standing fell with %s."
)

## Station menu size for A5 service buttons (kept for older references).
const STATION_MENU_HEIGHT_A5: float = 420.0
const STATION_MENU_HALF_HEIGHT_A5: float = 210.0

## Station menu size for B3 sections + trade list.
## Height uses viewport anchors so Undock stays on screen; body scrolls.
const STATION_MENU_WIDTH_B3: float = 440.0
const STATION_MENU_HALF_WIDTH_B3: float = 220.0
## Horizontal center anchor (0.5 = middle of viewport).
const STATION_MENU_ANCHOR_CENTER: float = 0.5
## Top / bottom anchors (fraction of viewport) for the station panel.
const STATION_MENU_ANCHOR_TOP: float = 0.05
const STATION_MENU_ANCHOR_BOTTOM: float = 0.95
## Minimum body scroll height so trade list is usable on small windows.
const STATION_MENU_SCROLL_MIN_HEIGHT: float = 220.0
## Both side content margins when sizing the undock footer button width.
const STATION_MENU_SIDE_MARGINS: float = 2.0
## Kept for older size references / tests that only need a panel present.
const STATION_MENU_HEIGHT_B3: float = 640.0
const STATION_MENU_HALF_HEIGHT_B3: float = 320.0
const STATION_MENU_SCROLL_HEIGHT: float = 460.0
const STATION_TRADE_BUTTON_WIDTH: float = 72.0
const STATION_SECTION_SPACER: float = 6.0
const STATION_UNDOCK_SPACER: float = 10.0

## Quantity control (S2 trade UI — one-unit-per-click is gone).
## The amount box accepts more than the station will allow on purpose: typing
## 100 into a shelf that holds 42 is how the row gets to say why.
const STATION_TRADE_QTY_MIN: float = 1.0
const STATION_TRADE_QTY_MAX: float = 999.0
const STATION_TRADE_QTY_STEP: float = 1.0
const STATION_TRADE_QTY_WIDTH: float = 92.0
const STATION_TRADE_MAX_BUTTON_WIDTH: float = 86.0
const STATION_TRADE_ACTION_BUTTON_WIDTH: float = 150.0
## Gap under each trade row so rows read as separate cards, not one wall.
const STATION_TRADE_ROW_SPACER: float = 8.0
## Reason and cap lines are quieter than the headline they explain.
const STATION_TRADE_SMALL_FONT_SIZE: int = 12

# --- Console ---------------------------------------------------------------

const CREDITS_COMMAND: StringName = &"credits"
const CONSOLE_CREDITS_SET_ARGS: int = 2
const CONSOLE_CREDITS_SHOW_ARGS: int = 1
const CONSOLE_CREDITS_VALUE_INDEX: int = 1
const CONSOLE_CREDITS_SHOW_FORMAT: String = "Credits: %d  Fuel: %s  Hull: %s"
const CONSOLE_CREDITS_SET_FORMAT: String = "Credits set to %d."

const CARGO_COMMAND: StringName = &"cargo"
const CONSOLE_CARGO_EMPTY: String = "Cargo empty (%d/%d free volume)."
const CONSOLE_CARGO_LINE_FORMAT: String = "  %s  x%d  (vol %d)"
const CONSOLE_CARGO_HEADER_FORMAT: String = "Cargo %d/%d:"

## Percent scale for fuel/hull console and HUD (0..1 → 0..100).
const PERCENT_SCALE: float = 100.0

## Refuel cost rounding ceiling uses this unit floor when credits are partial.
const REFUEL_MIN_UNITS: float = 0.01

# --- Standing-tier service multipliers (E1.5) ------------------------------
#
# Trade prices are NOT here any more. Before Steam S2 this file carried a
# per-system buy/sell multiplier table and resolved unit prices from it; since
# S2 every price comes from stock at a station via MarketService
# (docs/economy_sim.md §1, §4). The tables were deleted rather than left as a
# fallback: a second source of truth for what a good costs is exactly the split
# that opens a same-station money pump.


## Dock fee standing multiplier for a display tier id (StandingService.tier_for).
static func dock_fee_mult_for_tier(tier: StringName) -> float:
	if tier == BalanceStanding.TIER_UNFRIENDLY:
		return DOCK_FEE_STANDING_MULT_UNFRIENDLY
	if tier == BalanceStanding.TIER_HOSTILE:
		return DOCK_FEE_STANDING_MULT_HOSTILE
	if tier == BalanceStanding.TIER_HATED:
		return DOCK_FEE_STANDING_MULT_HATED
	return DOCK_FEE_STANDING_MULT_DEFAULT


## Station service cost multiplier (refuel always; repair only when allowed).
static func service_cost_mult_for_tier(tier: StringName) -> float:
	if tier == BalanceStanding.TIER_UNFRIENDLY:
		return SERVICE_COST_MULT_UNFRIENDLY
	if tier == BalanceStanding.TIER_HOSTILE:
		return SERVICE_COST_MULT_HOSTILE
	if tier == BalanceStanding.TIER_HATED:
		return SERVICE_COST_MULT_HATED
	return SERVICE_COST_MULT_DEFAULT


## True when repair is refused at this controller standing tier.
static func service_repair_denied_for_tier(tier: StringName) -> bool:
	return tier == BalanceStanding.TIER_HOSTILE or tier == BalanceStanding.TIER_HATED


## True when buy/sell is refused at this controller standing tier.
static func trade_denied_for_tier(tier: StringName) -> bool:
	return service_repair_denied_for_tier(tier)


# --- Performance densify (E2.6 / E6.4) -------------------------------------


## Ambient orbit traffic count for a policing tag (patrolled/contested/lawless).
static func npc_count_for_policing(policing: StringName) -> int:
	if policing == &"patrolled":
		return NPC_COUNT_PATROLLED
	if policing == &"contested":
		return NPC_COUNT_CONTESTED
	if policing == &"lawless":
		return NPC_COUNT_LAWLESS
	return NPC_COUNT_CONTESTED


## Max combat hostiles that can legally exist under this policing.
## Patrolled: 0 (no ambient, no bounty ensure). Contested/lawless: concurrent cap.
static func max_hostiles_for_policing(policing: StringName) -> int:
	if policing == &"patrolled":
		return 0 if not BalanceCombat.SPAWN_IN_PATROLLED else BalanceCombat.MAX_CONCURRENT_HOSTILES
	if policing == &"contested":
		return BalanceCombat.MAX_CONCURRENT_HOSTILES if BalanceCombat.SPAWN_IN_CONTESTED else 0
	if policing == &"lawless":
		return BalanceCombat.MAX_CONCURRENT_HOSTILES if BalanceCombat.SPAWN_IN_LAWLESS else 0
	return 0


## Player + traffic + max hostiles for one policing tier (budget math).
static func densest_ships_for_policing(policing: StringName) -> int:
	return (
		PERF_BUDGET_PLAYER_COUNT
		+ npc_count_for_policing(policing)
		+ max_hostiles_for_policing(policing)
	)


## Worst-case ship count across known policing tiers (must be ≤ PERF_BUDGET_SHIPS).
static func densest_ships_layout() -> int:
	var densest: int = densest_ships_for_policing(&"patrolled")
	densest = maxi(densest, densest_ships_for_policing(&"contested"))
	densest = maxi(densest, densest_ships_for_policing(&"lawless"))
	return densest


## Policing tag that produces densest_ships_layout() (ties prefer contested).
static func densest_layout_policing() -> StringName:
	var densest: int = densest_ships_layout()
	if densest_ships_for_policing(&"contested") == densest:
		return &"contested"
	if densest_ships_for_policing(&"lawless") == densest:
		return &"lawless"
	return &"patrolled"


## How many of `total` traffic slots orbit secondary docks (multi-dock systems).
## Always leaves at least one primary-orbit ship when total ≥ 2.
static func secondary_dock_traffic_slots(total: int) -> int:
	if total <= 1:
		return 0
	var slots: int = int(roundf(float(total) * NPC_SECONDARY_DOCK_TRAFFIC_SHARE))
	return clampi(slots, 0, total - 1)
