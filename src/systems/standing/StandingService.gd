extends Node

## Single writer for player standing with Entities and People — Alpha A4.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2–A4
## Law: docs/reputation_and_standing.md
##
## Autoload named `StandingService`. Nothing else writes standing. All mutations
## clamp to the balance scale and emit on EventBus. Status moments fire on
## system entry and successful dock. Deltas apply stickiness and optional
## one-hop Entity ripples (combat/mission only). Personal history flags support
## the A4 recovery path (success count + closed/betrayed).

const StandingConsoleCommands = preload("res://src/systems/standing/StandingConsoleCommands.gd")

## Status dictionary keys (stable for callers and tests).
const STATUS_KEY_ENTITY_ID: StringName = &"entity_id"
const STATUS_KEY_STANDING: StringName = &"standing"
const STATUS_KEY_TIER: StringName = &"tier"
const STATUS_KEY_TIER_DISPLAY: StringName = &"tier_display"
const STATUS_KEY_ENTITY_DISPLAY: StringName = &"entity_display"
const STATUS_KEY_UNCONTROLLED: StringName = &"uncontrolled"
const STATUS_KEY_LINE: StringName = &"line"

## Last reason tag passed to apply_entity_delta / apply_person_delta (debug/tests).
var last_delta_reason: StringName = &""

var _entity_standing: Dictionary[StringName, float] = {}
var _person_standing: Dictionary[StringName, float] = {}
## Person id → count of successful personal work (recovery completes, etc.).
var _person_success_count: Dictionary[StringName, int] = {}
## Person id → close reason (non-empty means recovery route closed).
var _person_closed: Dictionary[StringName, StringName] = {}
var _console_commands: RefCounted = null


func _ready() -> void:
	_console_commands = StandingConsoleCommands.new()
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_docked.connect(_on_docked)
	ServiceRegistry.register_resettable(reset_to_defaults)
	reset_to_defaults()


## Clear career entries so content defaults apply again.
func reset_to_defaults() -> void:
	_entity_standing.clear()
	_person_standing.clear()
	_person_success_count.clear()
	_person_closed.clear()


## Player standing with this Entity (content default if unset).
func get_entity_standing(entity_id: StringName) -> float:
	if _entity_standing.has(entity_id):
		return _entity_standing[entity_id]
	return _default_entity_standing(entity_id)


## Player standing with this Person (content default if unset).
func get_person_standing(person_id: StringName) -> float:
	if _person_standing.has(person_id):
		return _person_standing[person_id]
	return _default_person_standing(person_id)


## Write Entity standing, clamp, emit. No-op emit if value unchanged after clamp.
func set_entity_standing(entity_id: StringName, value: float) -> void:
	var old_value: float = get_entity_standing(entity_id)
	var new_value: float = clampf(value, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX)
	_entity_standing[entity_id] = new_value
	if is_equal_approx(old_value, new_value):
		return
	var tier: StringName = tier_for(new_value)
	EventBus.on_entity_standing_changed.emit(entity_id, old_value, new_value, tier)


## Write Person standing, clamp, emit. No-op emit if value unchanged after clamp.
func set_person_standing(person_id: StringName, value: float) -> void:
	var old_value: float = get_person_standing(person_id)
	var new_value: float = clampf(value, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX)
	_person_standing[person_id] = new_value
	if is_equal_approx(old_value, new_value):
		return
	var tier: StringName = tier_for(new_value)
	EventBus.on_person_standing_changed.emit(person_id, old_value, new_value, tier)


## Apply a raw Entity delta with stickiness. Returns the applied delta
## (after stickiness and clamp). When `with_ripple` is true, one-hop echoes
## fire on direct relationship_links (no multi-hop).
func apply_entity_delta(
	entity_id: StringName, raw_delta: float, reason: StringName, with_ripple: bool = false
) -> float:
	last_delta_reason = reason
	var old_value: float = get_entity_standing(entity_id)
	var adjusted: float = adjust_for_stickiness(old_value, raw_delta)
	var new_value: float = clampf(
		old_value + adjusted, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX
	)
	var applied: float = new_value - old_value
	set_entity_standing(entity_id, new_value)
	if with_ripple and not is_equal_approx(applied, 0.0):
		_apply_one_hop_ripple(entity_id, applied)
	return applied


## Apply a raw Person delta with stickiness. No Entity ripple on person layer.
func apply_person_delta(person_id: StringName, raw_delta: float, reason: StringName) -> float:
	last_delta_reason = reason
	var old_value: float = get_person_standing(person_id)
	var adjusted: float = adjust_for_stickiness(old_value, raw_delta)
	var new_value: float = clampf(
		old_value + adjusted, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX
	)
	var applied: float = new_value - old_value
	set_person_standing(person_id, new_value)
	return applied


## Record one successful piece of personal work with this Person (history flag).
func record_personal_success(person_id: StringName) -> void:
	var prior: int = personal_success_count(person_id)
	_person_success_count[person_id] = prior + 1


## How many successful personal jobs this Person has credited the player with.
func personal_success_count(person_id: StringName) -> int:
	if _person_success_count.has(person_id):
		return _person_success_count[person_id]
	return 0


## Whether this Person's recovery route is closed (betrayal, etc.).
func is_person_closed(person_id: StringName) -> bool:
	if not _person_closed.has(person_id):
		return false
	return not String(_person_closed[person_id]).is_empty()


## Reason tag for a closed Person, or empty when open.
func person_close_reason(person_id: StringName) -> StringName:
	if _person_closed.has(person_id):
		return _person_closed[person_id]
	return BalanceStanding.RECOVERY_CLOSE_REASON_NONE


## Permanently close recovery with this Person (law §6). Emits person_closed.
func close_person(person_id: StringName, reason: StringName) -> void:
	var tag: StringName = reason
	if String(tag).is_empty():
		tag = BalanceStanding.RECOVERY_CLOSE_REASON_BETRAYAL
	_person_closed[person_id] = tag
	EventBus.on_person_closed.emit(person_id, tag)


## Alpha §5 offer gate (standing layer only).
##
## Bootstrap reading of law §5: "Friendly personal + history of successful work"
## would lock the deniable first job forever if history required success first.
## Alpha uses (a): Friendly personal standing alone unlocks offerability here;
## RecoveryService requires prior chain success only for follow-on steps. Closed
## People never offer. History count is still tracked for follow-on / future use.
func can_offer_recovery(person_id: StringName) -> bool:
	if is_person_closed(person_id):
		return false
	var personal: float = get_person_standing(person_id)
	return personal >= BalanceStanding.TIER_FRIENDLY_MIN


## Small legal-trade gain, soft-capped so trade alone cannot exceed the cap.
## Returns applied delta (0 when already at/above soft cap).
func record_legal_trade(entity_id: StringName) -> float:
	var old_value: float = get_entity_standing(entity_id)
	if old_value >= BalanceStanding.TRADE_STANDING_SOFT_CAP:
		return 0.0
	var adjusted: float = adjust_for_stickiness(old_value, BalanceStanding.TRADE_LEGAL_DELTA)
	var uncapped: float = old_value + adjusted
	var new_value: float = minf(uncapped, BalanceStanding.TRADE_STANDING_SOFT_CAP)
	new_value = clampf(new_value, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX)
	var applied: float = new_value - old_value
	set_entity_standing(entity_id, new_value)
	return applied


## Stickiness: positives shrink when standing is deeply negative; negatives full.
func adjust_for_stickiness(current: float, raw_delta: float) -> float:
	if raw_delta > 0.0 and current <= BalanceStanding.STICKY_NEGATIVE_FLOOR:
		return raw_delta * BalanceStanding.STICKY_POSITIVE_FACTOR
	return raw_delta


## Display tier id for a raw standing value.
func tier_for(value: float) -> StringName:
	var clamped: float = clampf(value, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX)
	var tier: StringName = BalanceStanding.TIER_HATED
	# Inclusive bounds from docs/reputation_and_standing.md. Walk high → low.
	if clamped >= BalanceStanding.TIER_REVERED_MIN:
		tier = BalanceStanding.TIER_REVERED
	elif clamped >= BalanceStanding.TIER_ALLIED_MIN:
		tier = BalanceStanding.TIER_ALLIED
	elif clamped >= BalanceStanding.TIER_FRIENDLY_MIN:
		tier = BalanceStanding.TIER_FRIENDLY
	elif clamped >= BalanceStanding.TIER_NEUTRAL_MIN:
		tier = BalanceStanding.TIER_NEUTRAL
	elif clamped >= BalanceStanding.TIER_UNFRIENDLY_MAX:
		# Unfriendly -20..-49 (algebraic floor is TIER_UNFRIENDLY_MAX = -49).
		tier = BalanceStanding.TIER_UNFRIENDLY
	elif clamped >= BalanceStanding.TIER_HOSTILE_MAX:
		# Hostile -50..-79 (algebraic floor is TIER_HOSTILE_MAX = -79).
		tier = BalanceStanding.TIER_HOSTILE
	return tier


## Human label for a tier id.
func tier_display_name(tier: StringName) -> String:
	var label: String = String(tier).capitalize()
	if tier == BalanceStanding.TIER_REVERED:
		label = BalanceStanding.TIER_DISPLAY_REVERED
	elif tier == BalanceStanding.TIER_ALLIED:
		label = BalanceStanding.TIER_DISPLAY_ALLIED
	elif tier == BalanceStanding.TIER_FRIENDLY:
		label = BalanceStanding.TIER_DISPLAY_FRIENDLY
	elif tier == BalanceStanding.TIER_NEUTRAL:
		label = BalanceStanding.TIER_DISPLAY_NEUTRAL
	elif tier == BalanceStanding.TIER_UNFRIENDLY:
		label = BalanceStanding.TIER_DISPLAY_UNFRIENDLY
	elif tier == BalanceStanding.TIER_HOSTILE:
		label = BalanceStanding.TIER_DISPLAY_HOSTILE
	elif tier == BalanceStanding.TIER_HATED:
		label = BalanceStanding.TIER_DISPLAY_HATED
	return label


## Representative standing used when the console sets a tier by name.
## Uses the inclusive lower bound of each positive tier and of each negative
## tier floor so the result sits clearly inside that band.
func value_for_tier(tier: StringName) -> float:
	var value: float = BalanceStanding.DEFAULT_STANDING
	if tier == BalanceStanding.TIER_REVERED:
		value = BalanceStanding.TIER_REVERED_MIN
	elif tier == BalanceStanding.TIER_ALLIED:
		value = BalanceStanding.TIER_ALLIED_MIN
	elif tier == BalanceStanding.TIER_FRIENDLY:
		value = BalanceStanding.TIER_FRIENDLY_MIN
	elif tier == BalanceStanding.TIER_NEUTRAL:
		value = BalanceStanding.DEFAULT_STANDING
	elif tier == BalanceStanding.TIER_UNFRIENDLY:
		value = BalanceStanding.TIER_UNFRIENDLY_MIN
	elif tier == BalanceStanding.TIER_HOSTILE:
		value = BalanceStanding.TIER_HOSTILE_MIN
	elif tier == BalanceStanding.TIER_HATED:
		value = BalanceStanding.TIER_HATED_MIN
	return value


## Status moment payload for the Entity that holds this system.
func status_for_system(system_id: StringName) -> Dictionary:
	var controller: StringName = StarSystem.HELD_BY_NOBODY
	if ContentLibrary.has_item(system_id):
		var item: ContentItem = ContentLibrary.item(system_id)
		if item is StarSystem:
			var system: StarSystem = item as StarSystem
			controller = system.held_by
	return _status_for_controller(controller)


## Status moment payload for the Entity that controls this station.
func status_for_station(station_id: StringName) -> Dictionary:
	var controller: StringName = Station.CONTROLLER_NOBODY
	if ContentLibrary.has_item(station_id):
		var item: ContentItem = ContentLibrary.item(station_id)
		if item is Station:
			var station: Station = item as Station
			controller = station.controller_entity_id
	return _status_for_controller(controller)


## Whether the player may dock at this station under standing rules.
## Nobody controller always allows. Otherwise standing must be strictly above
## the controlling Entity's dock_refusal_threshold.
##
## Exception (reputation law Example B / §5): an open personal recovery contact
## for this station's controller still lets the player dock so they can seek
## that Person out while Entity standing is Hostile/Hated.
func can_dock_at_station(station_id: StringName) -> bool:
	if not ContentLibrary.has_item(station_id):
		return true
	var item: ContentItem = ContentLibrary.item(station_id)
	if not (item is Station):
		return true
	var station: Station = item as Station
	var controller_id: StringName = station.controller_entity_id
	if controller_id == Station.CONTROLLER_NOBODY or String(controller_id).is_empty():
		return true
	var threshold: float = BalanceStanding.DEFAULT_DOCK_REFUSAL_THRESHOLD
	if ContentLibrary.has_item(controller_id):
		var controller_item: ContentItem = ContentLibrary.item(controller_id)
		if controller_item is Entity:
			var entity: Entity = controller_item as Entity
			threshold = entity.dock_refusal_threshold
	var standing: float = get_entity_standing(controller_id)
	if standing > threshold:
		return true
	return has_open_recovery_contact_for_controller(controller_id)


## True when a recovery-chain Person for this Entity is still open (not closed).
## Used so Hostile/Hated players can still dock to seek that foothold.
func has_open_recovery_contact_for_controller(controller_id: StringName) -> bool:
	if String(controller_id).is_empty() or controller_id == Station.CONTROLLER_NOBODY:
		return false
	for chain_id: StringName in ContentLibrary.ids_in(BalanceStanding.RECOVERY_CONTENT_CATEGORY):
		if not ContentLibrary.has_item(chain_id):
			continue
		var item: ContentItem = ContentLibrary.item(chain_id)
		if item == null:
			continue
		var entity_raw: Variant = item.get("entity_id")
		var person_raw: Variant = item.get("person_id")
		if entity_raw == null or person_raw == null:
			continue
		var entity_id: StringName = &""
		var person_id: StringName = &""
		if typeof(entity_raw) == TYPE_STRING_NAME:
			entity_id = entity_raw
		elif typeof(entity_raw) == TYPE_STRING:
			var entity_text: String = entity_raw
			entity_id = StringName(entity_text)
		if typeof(person_raw) == TYPE_STRING_NAME:
			person_id = person_raw
		elif typeof(person_raw) == TYPE_STRING:
			var person_text: String = person_raw
			person_id = StringName(person_text)
		if entity_id != controller_id:
			continue
		if is_person_closed(person_id):
			continue
		return true
	return false


## Career section for save (only explicit overrides; missing = defaults).
## Optional A4 keys: person_success, person_closed (recovery progress is owned
## by RecoveryService when present — see save_schema.md).
func to_section() -> Dictionary:
	var entities: Dictionary = {}
	for id: StringName in _entity_standing:
		entities[id] = _entity_standing[id]
	var people: Dictionary = {}
	for id: StringName in _person_standing:
		people[id] = _person_standing[id]
	var success: Dictionary = {}
	for id: StringName in _person_success_count:
		success[id] = _person_success_count[id]
	var closed: Dictionary = {}
	for id: StringName in _person_closed:
		closed[id] = String(_person_closed[id])
	return {
		BalanceStanding.SAVE_KEY_ENTITIES: entities,
		BalanceStanding.SAVE_KEY_PEOPLE: people,
		BalanceStanding.SAVE_KEY_PERSON_SUCCESS: success,
		BalanceStanding.SAVE_KEY_PERSON_CLOSED: closed,
	}


## Restore from a save section. Missing or malformed keys clear to defaults.
func apply_section(section: Variant) -> void:
	reset_to_defaults()
	if typeof(section) != TYPE_DICTIONARY:
		return
	var data: Dictionary = section
	if data.has(BalanceStanding.SAVE_KEY_ENTITIES):
		_apply_standing_map(data[BalanceStanding.SAVE_KEY_ENTITIES], true)
	if data.has(BalanceStanding.SAVE_KEY_PEOPLE):
		_apply_standing_map(data[BalanceStanding.SAVE_KEY_PEOPLE], false)
	if data.has(BalanceStanding.SAVE_KEY_PERSON_SUCCESS):
		_apply_success_map(data[BalanceStanding.SAVE_KEY_PERSON_SUCCESS])
	if data.has(BalanceStanding.SAVE_KEY_PERSON_CLOSED):
		_apply_closed_map(data[BalanceStanding.SAVE_KEY_PERSON_CLOSED])


func _apply_standing_map(raw_map: Variant, is_entity: bool) -> void:
	if typeof(raw_map) != TYPE_DICTIONARY:
		return
	var map: Dictionary = raw_map
	for key: Variant in map:
		var id: StringName = StringName(str(key))
		var raw_value: Variant = map[key]
		var number: float = 0.0
		var kind: int = typeof(raw_value)
		if kind == TYPE_FLOAT:
			number = raw_value
		elif kind == TYPE_INT:
			var as_int: int = raw_value
			number = float(as_int)
		else:
			continue
		var clamped: float = clampf(
			number, BalanceStanding.STANDING_MIN, BalanceStanding.STANDING_MAX
		)
		if is_entity:
			_entity_standing[id] = clamped
		else:
			_person_standing[id] = clamped


func _apply_success_map(raw_map: Variant) -> void:
	if typeof(raw_map) != TYPE_DICTIONARY:
		return
	var map: Dictionary = raw_map
	for key: Variant in map:
		var id: StringName = StringName(str(key))
		var raw_value: Variant = map[key]
		var count: int = 0
		if typeof(raw_value) == TYPE_INT:
			count = raw_value
		elif typeof(raw_value) == TYPE_FLOAT:
			var as_float: float = raw_value
			count = int(as_float)
		else:
			continue
		if count < 0:
			count = 0
		_person_success_count[id] = count


func _apply_closed_map(raw_map: Variant) -> void:
	if typeof(raw_map) != TYPE_DICTIONARY:
		return
	var map: Dictionary = raw_map
	for key: Variant in map:
		var id: StringName = StringName(str(key))
		var raw_value: Variant = map[key]
		var reason: StringName = StringName(str(raw_value))
		if String(reason).is_empty():
			continue
		_person_closed[id] = reason


func _status_for_controller(controller_id: StringName) -> Dictionary:
	if (
		controller_id == StarSystem.HELD_BY_NOBODY
		or controller_id == Station.CONTROLLER_NOBODY
		or String(controller_id).strip_edges().is_empty()
	):
		var neutral_tier: StringName = BalanceStanding.TIER_NEUTRAL
		return {
			STATUS_KEY_ENTITY_ID: StarSystem.HELD_BY_NOBODY,
			STATUS_KEY_STANDING: BalanceStanding.DEFAULT_STANDING,
			STATUS_KEY_TIER: neutral_tier,
			STATUS_KEY_TIER_DISPLAY: tier_display_name(neutral_tier),
			STATUS_KEY_ENTITY_DISPLAY: BalanceStanding.STATUS_UNCONTROLLED_LABEL,
			STATUS_KEY_UNCONTROLLED: true,
			STATUS_KEY_LINE:
			(
				BalanceStanding.STATUS_LINE_FORMAT
				% [
					tier_display_name(neutral_tier),
					BalanceStanding.STATUS_UNCONTROLLED_LABEL,
				]
			),
		}

	var standing: float = get_entity_standing(controller_id)
	var tier: StringName = tier_for(standing)
	var entity_display: String = String(controller_id)
	if ContentLibrary.has_item(controller_id):
		var item: ContentItem = ContentLibrary.item(controller_id)
		if item != null and not item.display_name.is_empty():
			entity_display = item.display_name
	var tier_display: String = tier_display_name(tier)
	return {
		STATUS_KEY_ENTITY_ID: controller_id,
		STATUS_KEY_STANDING: standing,
		STATUS_KEY_TIER: tier,
		STATUS_KEY_TIER_DISPLAY: tier_display,
		STATUS_KEY_ENTITY_DISPLAY: entity_display,
		STATUS_KEY_UNCONTROLLED: false,
		STATUS_KEY_LINE: BalanceStanding.STATUS_LINE_FORMAT % [tier_display, entity_display],
	}


func _default_entity_standing(entity_id: StringName) -> float:
	if ContentLibrary.has_item(entity_id):
		var item: ContentItem = ContentLibrary.item(entity_id)
		if item is Entity:
			var entity: Entity = item as Entity
			return entity.default_player_standing
	return BalanceStanding.DEFAULT_STANDING


func _default_person_standing(person_id: StringName) -> float:
	if ContentLibrary.has_item(person_id):
		var item: ContentItem = ContentLibrary.item(person_id)
		if item is Person:
			var person: Person = item as Person
			return person.default_player_standing
	return BalanceStanding.DEFAULT_STANDING


## Re-fire the system status moment (E4.1 D6 after life-path apply).
func emit_status_for_system(system_id: StringName) -> void:
	_emit_system_status(system_id)


## Re-fire the station status moment (E4.1 D6 after life-path apply).
func emit_status_for_station(station_id: StringName) -> void:
	_emit_station_status(station_id)


func _on_system_entered(system_id: StringName) -> void:
	_emit_system_status(system_id)


func _on_docked(station_id: StringName) -> void:
	_emit_station_status(station_id)


func _emit_system_status(system_id: StringName) -> void:
	var status: Dictionary = status_for_system(system_id)
	EventBus.on_status_moment.emit(
		BalanceStanding.STATUS_KIND_SYSTEM,
		system_id,
		status[STATUS_KEY_ENTITY_ID],
		status[STATUS_KEY_STANDING],
		status[STATUS_KEY_TIER]
	)


func _emit_station_status(station_id: StringName) -> void:
	var status: Dictionary = status_for_station(station_id)
	EventBus.on_status_moment.emit(
		BalanceStanding.STATUS_KIND_STATION,
		station_id,
		status[STATUS_KEY_ENTITY_ID],
		status[STATUS_KEY_STANDING],
		status[STATUS_KEY_TIER]
	)


## Direct relationship_links only: ally same-sign echo, rival inverse. No hop-2.
func _apply_one_hop_ripple(source_entity_id: StringName, source_applied: float) -> void:
	if not ContentLibrary.has_item(source_entity_id):
		return
	var item: ContentItem = ContentLibrary.item(source_entity_id)
	if not (item is Entity):
		return
	var entity: Entity = item as Entity
	for link: EntityLink in entity.relationship_links:
		if link == null:
			continue
		var target_id: StringName = link.target_id
		if String(target_id).strip_edges().is_empty():
			continue
		if target_id == source_entity_id:
			continue
		var fraction: float = _ripple_fraction_for(link.relation_type)
		if is_equal_approx(fraction, 0.0):
			continue
		var raw_ripple: float = source_applied * fraction
		raw_ripple = clampf(
			raw_ripple, -BalanceStanding.RIPPLE_MAX_ABS, BalanceStanding.RIPPLE_MAX_ABS
		)
		if is_equal_approx(raw_ripple, 0.0):
			continue
		# No multi-hop: ripple applies without further ripple.
		apply_entity_delta(target_id, raw_ripple, BalanceStanding.REASON_RIPPLE, false)


func _ripple_fraction_for(relation_type: StringName) -> float:
	if (
		relation_type == EntityLink.RELATION_ALLIED
		or relation_type == EntityLink.RELATION_SUBSIDIARY
		or relation_type == EntityLink.RELATION_MEMBER_OF
	):
		return BalanceStanding.RIPPLE_ALLY_FRACTION
	if relation_type == EntityLink.RELATION_RIVAL or relation_type == EntityLink.RELATION_ENEMY:
		return -BalanceStanding.RIPPLE_RIVAL_FRACTION
	return 0.0
