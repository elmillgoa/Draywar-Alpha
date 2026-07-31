extends GutTest

## StandingService ledger, tiers, status, dock rules, console — Alpha A2.

const ENTITY_REACH: StringName = &"entity_reach_authority"
const ENTITY_BETA: StringName = &"entity_beta_syndicate"
const PERSON_HALE: StringName = &"person_ra_hale"
const STATION_PORT: StringName = &"station_alpha_port"
const SYSTEM_ALPHA: StringName = &"system_alpha"
const TOLERANCE: float = 0.0001

var _entity_tiers: Array[StringName] = []
var _entity_new_values: Array[float] = []
var _person_tiers: Array[StringName] = []
var _status_kinds: Array[StringName] = []
var _status_places: Array[StringName] = []
var _status_entities: Array[StringName] = []
var _status_tiers: Array[StringName] = []
var _refused_stations: Array[StringName] = []
var _refused_entities: Array[StringName] = []
var _console: ConsoleService = null
var _output: PackedStringArray = []


func before_each() -> void:
	StandingService.reset_to_defaults()
	_entity_tiers = []
	_entity_new_values = []
	_person_tiers = []
	_status_kinds = []
	_status_places = []
	_status_entities = []
	_status_tiers = []
	_refused_stations = []
	_refused_entities = []
	_output = []
	_console = ConsoleService.new()
	EventBus.on_entity_standing_changed.connect(_on_entity_changed)
	EventBus.on_person_standing_changed.connect(_on_person_changed)
	EventBus.on_status_moment.connect(_on_status_moment)
	EventBus.on_dock_refused.connect(_on_dock_refused)
	EventBus.on_console_output.connect(_on_console_output)


func after_each() -> void:
	EventBus.on_entity_standing_changed.disconnect(_on_entity_changed)
	EventBus.on_person_standing_changed.disconnect(_on_person_changed)
	EventBus.on_status_moment.disconnect(_on_status_moment)
	EventBus.on_dock_refused.disconnect(_on_dock_refused)
	EventBus.on_console_output.disconnect(_on_console_output)
	StandingService.reset_to_defaults()
	_console = null


func test_service_is_registered_as_singleton_autoload() -> void:
	var raw: Variant = ProjectSettings.get_setting("autoload/StandingService", "")
	var value: String = str(raw)
	assert_gt(value.length(), 0, "project.godot must declare autoload/StandingService")
	assert_true(value.begins_with("*"), "StandingService must be a singleton")
	assert_file_exists(value.trim_prefix("*"))
	assert_eq(StandingService.get_path(), NodePath("/root/StandingService"))


func test_tier_boundaries() -> void:
	assert_eq(StandingService.tier_for(-50.0), BalanceStanding.TIER_HOSTILE)
	assert_eq(StandingService.tier_for(-49.0), BalanceStanding.TIER_UNFRIENDLY)
	assert_eq(StandingService.tier_for(19.0), BalanceStanding.TIER_NEUTRAL)
	assert_eq(StandingService.tier_for(20.0), BalanceStanding.TIER_FRIENDLY)
	assert_eq(StandingService.tier_for(50.0), BalanceStanding.TIER_ALLIED)
	assert_eq(StandingService.tier_for(80.0), BalanceStanding.TIER_REVERED)
	assert_eq(StandingService.tier_for(-80.0), BalanceStanding.TIER_HATED)
	assert_eq(StandingService.tier_for(-79.0), BalanceStanding.TIER_HOSTILE)
	assert_eq(StandingService.tier_for(-20.0), BalanceStanding.TIER_UNFRIENDLY)
	assert_eq(StandingService.tier_for(0.0), BalanceStanding.TIER_NEUTRAL)


func test_set_get_clamp_and_emit() -> void:
	# Non-zero start path: never trust only zero fixtures.
	StandingService.set_entity_standing(ENTITY_REACH, 35.0)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), 35.0, TOLERANCE)
	assert_eq(_entity_tiers.size(), 1)
	assert_eq(_entity_tiers[0], BalanceStanding.TIER_FRIENDLY)

	StandingService.set_entity_standing(ENTITY_REACH, 999.0)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH), BalanceStanding.STANDING_MAX, TOLERANCE
	)
	assert_eq(_entity_tiers.size(), 2)
	assert_almost_eq(_entity_new_values[1], BalanceStanding.STANDING_MAX, TOLERANCE)

	StandingService.set_entity_standing(ENTITY_REACH, -999.0)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH), BalanceStanding.STANDING_MIN, TOLERANCE
	)

	StandingService.set_person_standing(PERSON_HALE, -55.0)
	assert_almost_eq(StandingService.get_person_standing(PERSON_HALE), -55.0, TOLERANCE)
	assert_eq(_person_tiers.size(), 1)
	assert_eq(_person_tiers[0], BalanceStanding.TIER_HOSTILE)


func test_status_for_system_uses_held_by_only() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, -55.0)
	StandingService.set_entity_standing(ENTITY_BETA, 60.0)
	var status: Dictionary = StandingService.status_for_system(SYSTEM_ALPHA)
	var entity_id: StringName = status[StandingService.STATUS_KEY_ENTITY_ID]
	var standing: float = status[StandingService.STATUS_KEY_STANDING]
	var tier: StringName = status[StandingService.STATUS_KEY_TIER]
	var uncontrolled: bool = status[StandingService.STATUS_KEY_UNCONTROLLED]
	var line: String = status[StandingService.STATUS_KEY_LINE]
	assert_eq(entity_id, ENTITY_REACH)
	assert_almost_eq(standing, -55.0, TOLERANCE)
	assert_eq(tier, BalanceStanding.TIER_HOSTILE)
	assert_false(uncontrolled)
	assert_string_contains(line, "Hostile")
	assert_string_contains(line, "Reach Authority")


func test_status_for_station_uses_controller_only() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 25.0)
	var status: Dictionary = StandingService.status_for_station(STATION_PORT)
	var entity_id: StringName = status[StandingService.STATUS_KEY_ENTITY_ID]
	var standing: float = status[StandingService.STATUS_KEY_STANDING]
	var tier: StringName = status[StandingService.STATUS_KEY_TIER]
	assert_eq(entity_id, ENTITY_REACH)
	assert_almost_eq(standing, 25.0, TOLERANCE)
	assert_eq(tier, BalanceStanding.TIER_FRIENDLY)


func test_status_nobody_is_uncontrolled_neutral() -> void:
	var status: Dictionary = StandingService._status_for_controller(StarSystem.HELD_BY_NOBODY)
	var uncontrolled: bool = status[StandingService.STATUS_KEY_UNCONTROLLED]
	var tier: StringName = status[StandingService.STATUS_KEY_TIER]
	var entity_display: String = status[StandingService.STATUS_KEY_ENTITY_DISPLAY]
	assert_true(uncontrolled)
	assert_eq(tier, BalanceStanding.TIER_NEUTRAL)
	assert_eq(entity_display, BalanceStanding.STATUS_UNCONTROLLED_LABEL)


func test_can_dock_respects_threshold_and_nobody() -> void:
	# Default neutral (0) is above -50 → may dock.
	assert_true(StandingService.can_dock_at_station(STATION_PORT))

	StandingService.set_entity_standing(
		ENTITY_REACH, BalanceStanding.DEFAULT_DOCK_REFUSAL_THRESHOLD
	)
	assert_false(
		StandingService.can_dock_at_station(STATION_PORT),
		"standing at threshold must refuse (at or below)"
	)

	StandingService.set_entity_standing(
		ENTITY_REACH, BalanceStanding.DEFAULT_DOCK_REFUSAL_THRESHOLD + 1.0
	)
	assert_true(StandingService.can_dock_at_station(STATION_PORT))

	StandingService.set_entity_standing(ENTITY_REACH, -80.0)
	assert_false(StandingService.can_dock_at_station(STATION_PORT))

	# Missing content / unknown station: treat as open (no controller to enforce).
	assert_true(StandingService.can_dock_at_station(&"station_does_not_exist"))


func test_system_enter_emits_status_moment() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, -60.0)
	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	assert_eq(_status_kinds.size(), 1)
	assert_eq(_status_kinds[0], BalanceStanding.STATUS_KIND_SYSTEM)
	assert_eq(_status_places[0], SYSTEM_ALPHA)
	assert_eq(_status_entities[0], ENTITY_REACH)
	assert_eq(_status_tiers[0], BalanceStanding.TIER_HOSTILE)


func test_dock_emits_station_status_moment() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, 22.0)
	EventBus.on_docked.emit(STATION_PORT)
	assert_eq(_status_kinds.size(), 1)
	assert_eq(_status_kinds[0], BalanceStanding.STATUS_KIND_STATION)
	assert_eq(_status_places[0], STATION_PORT)
	assert_eq(_status_entities[0], ENTITY_REACH)


func test_console_sets_entity_standing_by_value_and_tier() -> void:
	_console.start()
	EventBus.on_console_command_invoked.emit(
		&"standing", PackedStringArray(["entity", String(ENTITY_REACH), "-42"])
	)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), -42.0, TOLERANCE)
	assert_eq(StandingService.tier_for(-42.0), BalanceStanding.TIER_UNFRIENDLY)

	EventBus.on_console_command_invoked.emit(
		&"standing", PackedStringArray(["entity", String(ENTITY_REACH), "hostile"])
	)
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.TIER_HOSTILE_MIN,
		TOLERANCE
	)
	assert_eq(
		StandingService.tier_for(StandingService.get_entity_standing(ENTITY_REACH)),
		BalanceStanding.TIER_HOSTILE
	)

	EventBus.on_console_command_invoked.emit(
		&"standing", PackedStringArray(["person", String(PERSON_HALE), "friendly"])
	)
	assert_almost_eq(
		StandingService.get_person_standing(PERSON_HALE),
		BalanceStanding.TIER_FRIENDLY_MIN,
		TOLERANCE
	)


func test_save_section_round_trip_nonzero() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, -66.0)
	StandingService.set_person_standing(PERSON_HALE, 41.0)
	var section: Dictionary = StandingService.to_section()
	StandingService.reset_to_defaults()
	assert_almost_eq(
		StandingService.get_entity_standing(ENTITY_REACH),
		BalanceStanding.DEFAULT_STANDING,
		TOLERANCE
	)
	StandingService.apply_section(section)
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), -66.0, TOLERANCE)
	assert_almost_eq(StandingService.get_person_standing(PERSON_HALE), 41.0, TOLERANCE)


func test_save_service_round_trip_standing_section() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, -71.0)
	var path: String = "user://a2_standing_roundtrip.sav"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var service: SaveService = SaveService.new()
	var sections: Dictionary = {
		BalanceStanding.SAVE_SECTION_KEY: StandingService.to_section(),
	}
	var written: SaveResult = service.save_to(path, SaveService.envelope(sections, "a2stand"))
	assert_true(written.ok(), written.summary())
	StandingService.reset_to_defaults()
	var loaded: SaveResult = service.load_from(path)
	assert_true(loaded.ok(), loaded.summary())
	var envelope: Dictionary = loaded.envelope
	var sections_raw: Variant = envelope[SaveService.KEY_SECTIONS]
	var loaded_sections: Dictionary = sections_raw
	StandingService.apply_section(loaded_sections[BalanceStanding.SAVE_SECTION_KEY])
	assert_almost_eq(StandingService.get_entity_standing(ENTITY_REACH), -71.0, TOLERANCE)
	DirAccess.remove_absolute(path)


func test_docking_service_refuses_when_hostile() -> void:
	FlightInput.ensure_actions()
	StandingService.set_entity_standing(ENTITY_REACH, -60.0)
	assert_false(StandingService.can_dock_at_station(STATION_PORT))

	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	ship.global_position = Vector3(0.0, 0.0, 10.0)

	var docking: DockingService = DockingService.new()
	add_child_autofree(docking)
	docking.setup(ship, {STATION_PORT: Vector3.ZERO})

	docking._physics_process(0.0)
	Input.action_press(FlightInput.ACTION_DOCK)
	docking._physics_process(0.0)
	Input.action_release(FlightInput.ACTION_DOCK)

	assert_false(docking.controller().is_docked(), "hostile standing must block dock")
	assert_eq(_refused_stations.size(), 1, "must emit on_dock_refused")
	assert_eq(_refused_stations[0], STATION_PORT)
	assert_eq(_refused_entities[0], ENTITY_REACH)


func test_docking_service_allows_when_friendly() -> void:
	FlightInput.ensure_actions()
	StandingService.set_entity_standing(ENTITY_REACH, 30.0)

	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	ship.global_position = Vector3(0.0, 0.0, 10.0)

	var docking: DockingService = DockingService.new()
	add_child_autofree(docking)
	docking.setup(ship, {STATION_PORT: Vector3.ZERO})

	docking._physics_process(0.0)
	Input.action_press(FlightInput.ACTION_DOCK)
	docking._physics_process(0.0)
	Input.action_release(FlightInput.ACTION_DOCK)

	assert_true(docking.controller().is_docked())
	assert_eq(_refused_stations.size(), 0)


func test_flight_hud_shows_status_moment() -> void:
	StandingService.set_entity_standing(ENTITY_REACH, -55.0)
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)
	EventBus.on_system_entered.emit(SYSTEM_ALPHA)
	var label: Label = _find_label_containing(hud, "HOSTILE")
	assert_not_null(label, "HUD must show Hostile standing after system entry")
	assert_true(label.text.to_upper().contains("REACH AUTHORITY"))


func _find_label_containing(root: Node, needle: String) -> Label:
	if root is Label:
		var label: Label = root as Label
		if label.text.to_upper().contains(needle.to_upper()):
			return label
	for child: Node in root.get_children():
		var found: Label = _find_label_containing(child, needle)
		if found != null:
			return found
	return null


func _on_entity_changed(
	_entity_id: StringName, _old_value: float, new_value: float, tier: StringName
) -> void:
	_entity_tiers.append(tier)
	_entity_new_values.append(new_value)


func _on_person_changed(
	_person_id: StringName, _old_value: float, _new_value: float, tier: StringName
) -> void:
	_person_tiers.append(tier)


func _on_status_moment(
	kind: StringName,
	place_id: StringName,
	entity_id: StringName,
	_standing: float,
	tier: StringName
) -> void:
	_status_kinds.append(kind)
	_status_places.append(place_id)
	_status_entities.append(entity_id)
	_status_tiers.append(tier)


func _on_dock_refused(
	station_id: StringName, entity_id: StringName, _standing: float, _tier: StringName
) -> void:
	_refused_stations.append(station_id)
	_refused_entities.append(entity_id)


func _on_console_output(line: String) -> void:
	_output.append(line)
