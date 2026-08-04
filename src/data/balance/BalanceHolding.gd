class_name BalanceHolding
extends RefCounted

## Holding purchase path, candidates, and UI copy — Steam S8.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S8 + §8.3
##
## Milestone flag names live in BalanceCampaign. Money, candidates, spine ids,
## and Holding UI strings live here.

# --- Candidates / entity ----------------------------------------------------

const CANDIDATE_STATION_IDS: Array[StringName] = [
	&"station_epsilon_belt",
	&"station_zeta_spur",
]

const ENTITY_PLAYER_HOLDING: StringName = &"entity_player_holding"

## Standing written for the player Holding entity on claim (owner foothold).
const OWNER_STANDING: float = 50.0

# --- Price ------------------------------------------------------------------

const BASE_PRICE: int = 3500
## Per completed milestone flag (five max).
const MILESTONE_DISCOUNT: int = 400
## Floor after all discounts.
const MIN_PRICE: int = 1500

# --- Holding dict keys (campaign.holding) -----------------------------------

const KEY_STATION_ID: StringName = &"station_id"
const KEY_CLAIMED: StringName = &"claimed"
const KEY_IGNITED: StringName = &"ignited"
const KEY_PRICE_PAID: StringName = &"price_paid"
const KEY_PRIOR_CONTROLLER: StringName = &"prior_controller"

# --- Milestone flags (names owned by BalanceCampaign) -----------------------

const MILESTONE_FLAGS: Array[StringName] = [
	BalanceCampaign.FLAG_HOLDING_CLAIM,
	BalanceCampaign.FLAG_HOLDING_POWER,
	BalanceCampaign.FLAG_HOLDING_SUPPLY,
	BalanceCampaign.FLAG_HOLDING_PROTECT,
	BalanceCampaign.FLAG_HOLDING_PEOPLE,
]

const MILESTONE_COUNT: int = 5

# --- Money ------------------------------------------------------------------

const REASON_HOLDING_PURCHASE: StringName = &"holding_purchase"

# --- Spine content ids ------------------------------------------------------

const SPINE_CLAIM: StringName = &"spine_act3_claim"
const SPINE_POWER: StringName = &"spine_act3_power"
const SPINE_SUPPLY: StringName = &"spine_act3_supply"
const SPINE_PROTECT: StringName = &"spine_act3_protect"
const SPINE_PEOPLE: StringName = &"spine_act3_people"
## Peaceful papers path — prior controller Neutral+; deliver claim papers off-dock.
const SPINE_IGNITION_EPSILON: StringName = &"spine_act3_ignition_epsilon"
const SPINE_IGNITION_ZETA: StringName = &"spine_act3_ignition_zeta"
## Contested force path — prior Unfriendly or worse; needs Friendly backing; bounty in system.
const SPINE_IGNITION_EPSILON_FORCE: StringName = &"spine_act3_ignition_epsilon_force"
const SPINE_IGNITION_ZETA_FORCE: StringName = &"spine_act3_ignition_zeta_force"

const IGNITION_PAPERS_IDS: Array[StringName] = [
	SPINE_IGNITION_EPSILON,
	SPINE_IGNITION_ZETA,
]
const IGNITION_FORCE_IDS: Array[StringName] = [
	SPINE_IGNITION_EPSILON_FORCE,
	SPINE_IGNITION_ZETA_FORCE,
]

## Entities that can back a contested claim (Friendly floor).
const STANDOFF_BACKING_ENTITY_IDS: Array[StringName] = [
	&"entity_free_haulers",
	&"entity_reach_authority",
]

## Standing floor for prior controller to take the peaceful papers path.
const STANDOFF_PAPERS_STANDING_MIN: float = BalanceStanding.TIER_NEUTRAL_MIN
## Friendly floor for Free Haulers / Reach to back a contested standoff.
const STANDOFF_BACKING_STANDING_MIN: float = BalanceStanding.TIER_FRIENDLY_MIN

# --- EventBus unbind arg counts ---------------------------------------------

const BUS_ARGS_PURCHASE_REQUESTED: int = 1
const BUS_ARGS_CLAIMED: int = 2
const BUS_ARGS_IGNITED: int = 1
const BUS_ARGS_CREDITS_CHANGED: int = 1
const BUS_ARGS_DEBT_CHANGED: int = 3

# --- UI copy ----------------------------------------------------------------

const STATION_SECTION_HOLDING: String = "Holding"
const STATION_HOLDING_PRICE_FORMAT: String = "Price: %s cr (base %s, milestones −%s)"
const STATION_HOLDING_MILESTONES_FORMAT: String = "Milestones: %s / %s"
const STATION_HOLDING_DEBT_BLOCKED: String = "Clear all debt before purchase or ignition"
const STATION_HOLDING_NEED_MILESTONES: String = "Finish Holding milestones first"
const STATION_HOLDING_NEED_CREDITS: String = "Need more credits"
const STATION_HOLDING_PURCHASE_FORMAT: String = "Purchase Holding — %s cr"
const STATION_HOLDING_CLAIMED_LINE: String = "Your Holding — dock is yours"
const STATION_HOLDING_IGNITED_CELEBRATION: String = "Campaign complete. Holding ignited."
const STATION_HOLDING_NOT_HERE: String = "Holding path is not offered at this dock"
const STATION_HOLDING_ALREADY_ELSEWHERE: String = "You already claimed a Holding elsewhere"

## Epitaph after ignition — peaceful (prior controller Neutral or better).
const EPITAPH_PEACEFUL_FORMAT: String = "You hold %s. %s left the claim uncontested."
## Epitaph after ignition — contested (prior controller Unfriendly or worse).
const EPITAPH_CONTESTED_FORMAT: String = "You hold %s. %s contested the claim and lost."

## Standing vs prior controller at or above this → peaceful epitaph.
const EPITAPH_PEACEFUL_STANDING_MIN: float = BalanceStanding.TIER_NEUTRAL_MIN


## True when this station is a Holding purchase candidate.
static func is_candidate_station(station_id: StringName) -> bool:
	return CANDIDATE_STATION_IDS.has(station_id)


## Effective purchase price after milestone discounts (never below MIN_PRICE).
static func price_for_milestone_count(count: int) -> int:
	var safe_count: int = maxi(0, count)
	var discounted: int = BASE_PRICE - (MILESTONE_DISCOUNT * safe_count)
	return maxi(discounted, MIN_PRICE)


static func is_papers_ignition(template_id: StringName) -> bool:
	return IGNITION_PAPERS_IDS.has(template_id)


static func is_force_ignition(template_id: StringName) -> bool:
	return IGNITION_FORCE_IDS.has(template_id)


static func is_ignition_spine(template_id: StringName) -> bool:
	return is_papers_ignition(template_id) or is_force_ignition(template_id)
