extends Node

## Single writer for player standing with Entities and People — Alpha A2.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A2
## Law: docs/reputation_and_standing.md
##
## Autoload named `StandingService`. Nothing else writes standing. All mutations
## clamp to the balance scale and emit on EventBus. Status moments fire on
## system entry and successful dock.

const StandingConsoleCommands = preload("res://src/systems/standing/StandingConsoleCommands.gd")

## Status dictionary keys (stable for callers and tests).
const STATUS_KEY_ENTITY_ID: StringName = &"entity_id"
const STATUS_KEY_STANDING: StringName = &"standing"
const STATUS_KEY_TIER: StringName = &"tier"
const STATUS_KEY_TIER_DISPLAY: StringName = &"tier_display"
const STATUS_KEY_ENTITY_DISPLAY: StringName = &"entity_display"
const STATUS_KEY_UNCONTROLLED: StringName = &"uncontrolled"
const STATUS_KEY_LINE: StringName = &"line"

var _entity_standing: Dictionary[StringName, float] = {}
var _person_standing: Dictionary[StringName, float] = {}
var _console_commands: RefCounted = null


func _ready() -> void:
	_console_commands = StandingConsoleCommands.new()
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_docked.connect(_on_docked)
	reset_to_defaults()


## Clear career entries so content defaults apply again.
func reset_to_defaults() -> void:
	_entity_standing.clear()
	_person_standing.clear()


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
	return standing > threshold


## Career section for save (only explicit overrides; missing = defaults).
func to_section() -> Dictionary:
	var entities: Dictionary = {}
	for id: StringName in _entity_standing:
		entities[id] = _entity_standing[id]
	var people: Dictionary = {}
	for id: StringName in _person_standing:
		people[id] = _person_standing[id]
	return {
		BalanceStanding.SAVE_KEY_ENTITIES: entities,
		BalanceStanding.SAVE_KEY_PEOPLE: people,
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


func _on_system_entered(system_id: StringName) -> void:
	var status: Dictionary = status_for_system(system_id)
	EventBus.on_status_moment.emit(
		BalanceStanding.STATUS_KIND_SYSTEM,
		system_id,
		status[STATUS_KEY_ENTITY_ID],
		status[STATUS_KEY_STANDING],
		status[STATUS_KEY_TIER]
	)


func _on_docked(station_id: StringName) -> void:
	var status: Dictionary = status_for_station(station_id)
	EventBus.on_status_moment.emit(
		BalanceStanding.STATUS_KIND_STATION,
		station_id,
		status[STATUS_KEY_ENTITY_ID],
		status[STATUS_KEY_STANDING],
		status[STATUS_KEY_TIER]
	)
