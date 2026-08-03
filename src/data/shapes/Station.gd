class_name Station
extends ContentItem

## A dockable station as data — full-sized Alpha shape, S2 economic identity.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1, docs/STEAM_PHASE_PLAN.md Phase S2
##
## `system_id` is the star system this station sits in. `controller_entity_id`
## is who holds the dock (Entity id, or `CONTROLLER_NOBODY` until A2). World
## placement is `BalanceFlight.STATION_POSITION` (the system anchor) plus this
## station's `position_offset`, which every station now declares distinctly —
## S2 ends the all-docks-on-the-anchor stacking (docs/economy_sim.md §3).

## What `controller_entity_id` says when nobody holds this station.
const CONTROLLER_NOBODY: StringName = &"nobody"

## Star system content id this station is sited in.
@export var system_id: StringName = &""

## Controlling Entity id, or `CONTROLLER_NOBODY`.
@export var controller_entity_id: StringName = CONTROLLER_NOBODY

## Local offset from the system's station anchor (`BalanceFlight.STATION_POSITION`).
## Every station's world position must be distinct from every other station's —
## S2 ends the zero-offset stacking that put every first dock on the anchor.
@export var position_offset: Vector3 = Vector3.ZERO

## Optional one-line dock flavor under the station title (empty is fine).
@export var flavor_line: String = ""

## Economy content tag (`BalanceMarket.KNOWN_ROLES`). Drives the market's
## reason line and this station's opening-stock seeding per commodity.
@export var economy_role: StringName = &""

## commodity id -> target stock (the price-neutral level, before
## `market_scale`). Every commodity in `produces` or `consumes` needs a row
## here — that is what "this station trades it" means (docs/economy_sim.md §3).
@export var stock_targets: Dictionary[StringName, float] = {}

## commodity id -> units produced per game hour, before `market_scale`.
@export var produces: Dictionary[StringName, float] = {}

## commodity id -> units consumed per game hour, before `market_scale`.
@export var consumes: Dictionary[StringName, float] = {}

## Size multiplier on stock targets and capacity. A hub absorbs a full cargo
## hold without blinking; a spur does not (docs/economy_sim.md §3).
@export var market_scale: float = 1.0


## Everything wrong with this station. Empty means valid.
func validation_errors() -> PackedStringArray:
	var problems: PackedStringArray = super()

	if String(system_id).strip_edges().is_empty():
		problems.append(
			(
				"`system_id` is empty. Every station declares the system it sits in "
				+ "so the world builder and standing service can resolve place."
			)
		)

	if String(controller_entity_id).strip_edges().is_empty():
		problems.append(
			(
				"`controller_entity_id` is empty. Every station says who holds the dock; "
				+ "write '%s' when nobody does." % CONTROLLER_NOBODY
			)
		)

	problems.append_array(_economy_problems())
	return problems


## Everything wrong with this station's S2 economic identity.
func _economy_problems() -> PackedStringArray:
	var problems: PackedStringArray = []

	if String(economy_role).strip_edges().is_empty():
		problems.append(
			(
				"`economy_role` is empty. Every station declares an economic identity "
				+ "so the market can seed it and explain its prices."
			)
		)
	elif not BalanceMarket.KNOWN_ROLES.has(economy_role):
		problems.append(
			(
				"`economy_role` is '%s'; the roles that exist are: %s."
				% [String(economy_role), _known_roles_named()]
			)
		)

	if market_scale <= 0.0:
		problems.append("`market_scale` must be greater than zero.")

	if stock_targets.is_empty():
		problems.append(
			"`stock_targets` is empty. Every station trades something, or it is not a dock."
		)

	for commodity_id: StringName in stock_targets:
		if stock_targets[commodity_id] <= 0.0:
			problems.append(
				"`stock_targets['%s']` must be greater than zero." % String(commodity_id)
			)

	problems.append_array(_flow_problems(produces, "produces"))
	problems.append_array(_flow_problems(consumes, "consumes"))
	return problems


## Membership-in-`stock_targets` and sign checks shared by `produces`/`consumes`.
func _flow_problems(flow: Dictionary[StringName, float], field: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	for commodity_id: StringName in flow:
		if not stock_targets.has(commodity_id):
			problems.append(
				(
					(
						"`%s` lists '%s', which has no row in `stock_targets`. A station "
						% [field, String(commodity_id)]
					)
					+ "cannot make or eat a good it keeps no market in."
				)
			)
		if flow[commodity_id] < 0.0:
			problems.append("`%s['%s']` must not be negative." % [field, String(commodity_id)])
	return problems


## Every role `economy_role` may declare, for a complaint about one that is not.
func _known_roles_named() -> String:
	var names: PackedStringArray = []
	for role: StringName in BalanceMarket.KNOWN_ROLES:
		names.append(String(role))
	return ", ".join(names)
