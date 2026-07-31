extends GutTest

## A1 mechanical play loop â€” producers, not bus echoes.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1
##
## Guards: SystemWorld places station + emits enter; DockingService range scan
## + F-key dock; StationMenu undock; FlightHUD system name from bus.

var _system_events: Array[StringName] = []
var _dock_requested: Array[StringName] = []
var _docked: Array[StringName] = []
var _undock_requested: Array[StringName] = []
var _undocked: Array[StringName] = []
var _prompt_stations: Array[StringName] = []
var _prompt_can_dock: Array[bool] = []
var _throttle_heard: Array[float] = []


func before_each() -> void:
	FlightInput.ensure_actions()
	_system_events = []
	_dock_requested = []
	_docked = []
	_undock_requested = []
	_undocked = []
	_prompt_stations = []
	_prompt_can_dock = []
	_throttle_heard = []
	EventBus.on_system_entered.connect(_on_system_entered)
	EventBus.on_dock_requested.connect(_on_dock_requested)
	EventBus.on_docked.connect(_on_docked)
	EventBus.on_undock_requested.connect(_on_undock_requested)
	EventBus.on_undocked.connect(_on_undocked)
	EventBus.on_dock_prompt_changed.connect(_on_dock_prompt_changed)
	EventBus.on_player_throttle_changed.connect(_on_throttle)


func after_each() -> void:
	EventBus.on_system_entered.disconnect(_on_system_entered)
	EventBus.on_dock_requested.disconnect(_on_dock_requested)
	EventBus.on_docked.disconnect(_on_docked)
	EventBus.on_undock_requested.disconnect(_on_undock_requested)
	EventBus.on_undocked.disconnect(_on_undocked)
	EventBus.on_dock_prompt_changed.disconnect(_on_dock_prompt_changed)
	EventBus.on_player_throttle_changed.disconnect(_on_throttle)
	if Input.is_action_pressed(FlightInput.ACTION_DOCK):
		Input.action_release(FlightInput.ACTION_DOCK)


func test_system_world_places_station_and_emits_system_entered() -> void:
	var world: SystemWorld = SystemWorld.new()
	world.system_id = BalanceFlight.PLAYABLE_SYSTEM_ID
	add_child_autofree(world)
	world.build()

	assert_eq(_system_events.size(), 1, "build must emit on_system_entered")
	assert_eq(_system_events[0], BalanceFlight.PLAYABLE_SYSTEM_ID)

	var positions: Dictionary[StringName, Vector3] = world.station_positions()
	assert_true(
		positions.has(&"station_alpha_port"),
		"playable system must expose station_alpha_port position"
	)
	assert_gt(world.get_child_count(), 0, "gray-box meshes must be parented under the world")


func test_begin_session_docked_parks_without_fee_prompt() -> void:
	var station: StringName = &"station_alpha_port"
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	ship.global_position = Vector3(0.0, 8.0, 130.0)
	ship.visible = true
	ship.set_flight_enabled(true)

	var service: DockingService = DockingService.new()
	add_child_autofree(service)
	service.setup(ship, {station: Vector3.ZERO})

	assert_true(service.begin_session_docked(station))
	assert_true(service.controller().is_docked())
	assert_eq(service.docked_station_id(), station)
	assert_false(ship.visible)
	assert_eq(_docked.size(), 1)
	assert_eq(_docked[0], station)


func test_docking_service_range_scan_emits_prompt_then_f_key_docks() -> void:
	var station: StringName = &"station_alpha_port"
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	# Inside interact radius of station at origin.
	ship.global_position = Vector3(0.0, 0.0, 10.0)

	var service: DockingService = DockingService.new()
	add_child_autofree(service)
	service.setup(ship, {station: Vector3.ZERO})

	service._physics_process(0.0)
	assert_gt(_prompt_stations.size(), 0, "range scan must emit a dock prompt")
	var last: int = _prompt_stations.size() - 1
	assert_eq(_prompt_stations[last], station)
	assert_true(_prompt_can_dock[last], "10 m must be in-range for dock")

	Input.action_press(FlightInput.ACTION_DOCK)
	service._physics_process(0.0)
	Input.action_release(FlightInput.ACTION_DOCK)

	assert_eq(_dock_requested.size(), 1, "F in range must emit on_dock_requested")
	assert_eq(_dock_requested[0], station)
	assert_eq(_docked.size(), 1, "DockingService must complete dock from its own request")
	assert_eq(_docked[0], station)
	assert_true(service.controller().is_docked())
	assert_false(ship.visible)


func test_approach_prompt_outside_interact_but_inside_approach() -> void:
	var station: StringName = &"station_alpha_port"
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	# Between interact (45) and approach (90).
	var mid: float = (BalanceFlight.DOCK_INTERACT_RADIUS + BalanceFlight.DOCK_APPROACH_RADIUS) * 0.5
	ship.global_position = Vector3(0.0, 0.0, mid)

	var service: DockingService = DockingService.new()
	add_child_autofree(service)
	service.setup(ship, {station: Vector3.ZERO})
	service._physics_process(0.0)

	assert_gt(_prompt_stations.size(), 0)
	var last: int = _prompt_stations.size() - 1
	assert_eq(_prompt_stations[last], station)
	assert_false(_prompt_can_dock[last], "approach bubble is not yet dockable")

	Input.action_press(FlightInput.ACTION_DOCK)
	service._physics_process(0.0)
	Input.action_release(FlightInput.ACTION_DOCK)
	assert_eq(_docked.size(), 0, "F outside interact radius must not dock")


func test_station_menu_undock_is_outside_scroll_and_always_present() -> void:
	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	var undock: Button = menu.undock_button()
	assert_ne(undock, null, "Undock must exist")
	assert_eq(undock.text, BalanceEconomy.STATION_UNDOCK_LABEL)
	# Undock is a footer child of the panel layout, not buried in the trade list.
	var parent: Node = undock.get_parent()
	assert_false(parent is ScrollContainer, "Undock must not live inside the scroll body")
	# Walk up: undock must not be a descendant of any ScrollContainer.
	var walk: Node = undock
	var in_scroll: bool = false
	while walk != null and walk != menu:
		if walk is ScrollContainer:
			in_scroll = true
			break
		walk = walk.get_parent()
	assert_false(in_scroll, "Undock footer must stay outside scroll so it is never cut off")


func test_station_menu_shows_on_dock_and_undock_button_requests_leave() -> void:
	var station: StringName = &"station_alpha_port"
	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)
	assert_false(menu.visible)

	EventBus.on_docked.emit(station)
	assert_true(menu.visible, "menu must open on on_docked")

	var undock: Button = _find_button(menu, "Undock")
	assert_not_null(undock, "Undock button must exist")
	undock.pressed.emit()

	assert_eq(_undock_requested.size(), 1)
	assert_eq(_undock_requested[0], station)

	EventBus.on_undocked.emit(station)
	assert_false(menu.visible, "menu must close on on_undocked")


func test_flight_hud_shows_system_name_from_enter_signal() -> void:
	var hud: FlightHUD = FlightHUD.new()
	add_child_autofree(hud)

	EventBus.on_system_entered.emit(BalanceFlight.PLAYABLE_SYSTEM_ID)
	var system_label: Label = _find_label_containing(hud, "ALPHA REACH")
	assert_not_null(
		system_label, "HUD must show the playable system display name after on_system_entered"
	)


func test_full_service_loop_dock_then_menu_undock_frees_ship() -> void:
	var station: StringName = &"station_alpha_port"
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	ship.global_position = Vector3(0.0, 0.0, 10.0)

	var service: DockingService = DockingService.new()
	add_child_autofree(service)
	service.setup(ship, {station: Vector3.ZERO})

	var menu: StationMenu = StationMenu.new()
	add_child_autofree(menu)

	service._physics_process(0.0)
	Input.action_press(FlightInput.ACTION_DOCK)
	service._physics_process(0.0)
	Input.action_release(FlightInput.ACTION_DOCK)

	assert_true(service.controller().is_docked())
	assert_true(menu.visible)

	var undock: Button = _find_button(menu, BalanceEconomy.STATION_UNDOCK_LABEL)
	assert_not_null(undock)
	undock.pressed.emit()

	assert_eq(_undocked.size(), 1)
	assert_false(service.controller().is_docked())
	assert_true(ship.visible)
	assert_false(menu.visible)


func test_player_ship_set_throttle_announces_on_the_bus() -> void:
	var ship: PlayerShip = PlayerShip.new()
	add_child_autofree(ship)
	# _ready seeds 0.0; clear and force a real change.
	_throttle_heard.clear()
	ship.set_throttle(0.4)
	assert_eq(_throttle_heard.size(), 1)
	assert_almost_eq(_throttle_heard[0], 0.4, 0.0001)


func _find_button(root: Node, text: String) -> Button:
	if root is Button:
		var button: Button = root as Button
		if button.text == text:
			return button
	for child: Node in root.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


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


func _on_system_entered(system_id: StringName) -> void:
	_system_events.append(system_id)


func _on_dock_requested(station_id: StringName) -> void:
	_dock_requested.append(station_id)


func _on_docked(station_id: StringName) -> void:
	_docked.append(station_id)


func _on_undock_requested(station_id: StringName) -> void:
	_undock_requested.append(station_id)


func _on_undocked(station_id: StringName) -> void:
	_undocked.append(station_id)


func _on_dock_prompt_changed(station_id: StringName, can_dock: bool) -> void:
	_prompt_stations.append(station_id)
	_prompt_can_dock.append(can_dock)


func _on_throttle(throttle: float) -> void:
	_throttle_heard.append(throttle)
