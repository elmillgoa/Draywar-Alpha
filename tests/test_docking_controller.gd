extends GutTest

## Docking state machine â€” Alpha A1.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A1

const STATION: StringName = &"station_alpha_port"
const OTHER: StringName = &"station_other"
const INTERACT: float = 45.0


func test_starts_undocked() -> void:
	var dock: DockingController = DockingController.new()
	assert_eq(dock.state, DockingController.State.UNDOCKED)
	assert_false(dock.can_dock())
	assert_false(dock.is_docked())
	assert_eq(dock.prompt_station_id(), &"")


func test_range_enters_in_range_and_leaves() -> void:
	var dock: DockingController = DockingController.new()
	dock.update_range(STATION, 10.0, INTERACT)
	assert_eq(dock.state, DockingController.State.IN_RANGE)
	assert_true(dock.can_dock())
	assert_eq(dock.prompt_station_id(), STATION)

	dock.update_range(STATION, 100.0, INTERACT)
	assert_eq(dock.state, DockingController.State.UNDOCKED)
	assert_false(dock.can_dock())


func test_full_undocked_to_docked_to_undocked_loop() -> void:
	var dock: DockingController = DockingController.new()
	# undocked
	assert_eq(dock.state, DockingController.State.UNDOCKED)
	# in range
	dock.update_range(STATION, 5.0, INTERACT)
	assert_eq(dock.state, DockingController.State.IN_RANGE)
	# dock
	var docked_id: StringName = dock.request_dock()
	assert_eq(docked_id, STATION)
	assert_eq(dock.state, DockingController.State.DOCKED)
	assert_true(dock.is_docked())
	assert_eq(dock.docked_station_id(), STATION)
	# range updates while docked are ignored
	dock.update_range(OTHER, 1.0, INTERACT)
	assert_eq(dock.state, DockingController.State.DOCKED)
	assert_eq(dock.docked_station_id(), STATION)
	# undock
	var left: StringName = dock.request_undock()
	assert_eq(left, STATION)
	assert_eq(dock.state, DockingController.State.UNDOCKED)
	assert_false(dock.is_docked())
	assert_eq(dock.docked_station_id(), &"")


func test_dock_refused_out_of_range() -> void:
	var dock: DockingController = DockingController.new()
	assert_eq(dock.request_dock(), &"")
	dock.update_range(STATION, 200.0, INTERACT)
	assert_eq(dock.request_dock(), &"")


func test_undock_refused_when_not_docked() -> void:
	var dock: DockingController = DockingController.new()
	assert_eq(dock.request_undock(), &"")


func test_force_dock_starts_career_at_station() -> void:
	var dock: DockingController = DockingController.new()
	assert_eq(dock.force_dock(STATION), STATION)
	assert_true(dock.is_docked())
	assert_eq(dock.docked_station_id(), STATION)
	assert_eq(dock.request_undock(), STATION)
	assert_false(dock.is_docked())
