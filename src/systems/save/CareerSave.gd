class_name CareerSave
extends RefCounted

## Shared career gather / apply for console and menu — Path C B2.
##
## Implements: Alpha/ALPHA_DECISION_PHASE_PLAN.md B2
##
## Collects optional sections (standing + recovery, wallet, cargo, ship, world,
## mission) and applies meta sections after load. World placement is applied
## by Main.

const SaveServiceScript = preload("res://src/systems/save/SaveService.gd")


## Gather every present optional section for a save write.
static func gather_sections(tree: SceneTree) -> Dictionary:
	var sections: Dictionary = {}
	var standing_section: Dictionary = StandingService.to_section()
	_merge_recovery_progress(tree, standing_section)
	sections[BalanceStanding.SAVE_SECTION_KEY] = standing_section

	# S1: world clock always written (elapsed seconds; empty sim scaffold later).
	sections[BalanceWorldClock.SAVE_SECTION_KEY] = WorldClock.to_section()

	# S2: market always written (stocks are live state even with an empty hold).
	sections[BalanceMarket.SAVE_SECTION_KEY] = MarketService.to_section()

	# S3a: board steps + mid-cycle claims (offers re-derive from step + market).
	sections[BalanceBoard.SAVE_SECTION_KEY] = BoardService.to_section()

	# S3b: incident security steps only (offered incidents expire on load).
	sections[BalanceIncident.SAVE_SECTION_KEY] = IncidentService.to_section()

	# S4: per-Entity heat (standing is separate; heat is enforcement pressure).
	sections[BalanceEnforcement.SAVE_SECTION_KEY] = EnforcementService.to_section()

	var wallet_section: Dictionary = _wallet_section(tree)
	if not wallet_section.is_empty():
		sections[BalanceEconomy.SAVE_SECTION_KEY] = wallet_section

	_merge_cargo_section(tree, sections)
	_merge_ship_section(tree, sections)

	var world_section: Dictionary = _world_section(tree)
	if not world_section.is_empty():
		sections[BalanceSession.SAVE_SECTION_WORLD] = world_section

	var mission_section: Dictionary = _mission_section(tree)
	if not mission_section.is_empty():
		sections[BalanceSession.SAVE_SECTION_MISSION] = mission_section

	# E4.6 optional career path ids (data-layer memory — no systems/career ref).
	var career_section: Dictionary = CareerPathState.to_section()
	if not career_section.is_empty():
		sections[BalanceSession.SAVE_SECTION_CAREER] = career_section

	return sections


## Apply standing (+ recovery), world clock, wallet, cargo, ship, mission, career.
## Not world placement (Main owns that).
static func apply_meta_sections(tree: SceneTree, sections: Dictionary) -> void:
	_apply_standing_from_sections(tree, sections)
	_apply_world_clock_from_sections(sections)
	# Market after the clock and before money/cargo: it resolves its own step
	# count against the restored elapsed time, and trade prices off it.
	_apply_market_from_sections(sections)
	# Boards after market: radiant shortage reads match restored shelves.
	_apply_boards_from_sections(sections)
	# Incidents after boards: security step continuity; offers expire on load.
	_apply_incidents_from_sections(sections)
	# Enforcement heat after incidents (same security cadence; independent steps).
	_apply_enforcement_from_sections(sections)
	_apply_wallet_from_sections(tree, sections)
	# Ship before cargo so capacity path matches restored active hull.
	_apply_ship_from_sections(tree, sections)
	_apply_cargo_from_sections(tree, sections)
	# D2: cargo applied after ship — re-clamp if hold is overweight for active.
	_clamp_ship_to_cargo_fit(tree)
	_apply_mission_from_sections(tree, sections)
	_apply_career_from_sections(sections)


## Write a named career save under user://saves/.
static func save_to_name(
	tree: SceneTree, file_name: String, profile_name: String = ""
) -> SaveResult:
	var service: SaveService = SaveServiceScript.new()
	var path: String = SaveService.path_for(file_name)
	var sections: Dictionary = gather_sections(tree)
	return service.save_to(path, SaveService.envelope(sections, profile_name))


## Load an envelope from a full path (does not apply sections).
static func load_envelope(path: String) -> SaveResult:
	var service: SaveService = SaveServiceScript.new()
	return service.load_from(path)


## Build a world section dictionary from explicit values.
static func make_world_section(
	system_id: StringName, position: Vector3, docked_station_id: StringName = &""
) -> Dictionary:
	return {
		BalanceSession.WORLD_KEY_SYSTEM_ID: String(system_id),
		BalanceSession.WORLD_KEY_POS_X: position.x,
		BalanceSession.WORLD_KEY_POS_Y: position.y,
		BalanceSession.WORLD_KEY_POS_Z: position.z,
		BalanceSession.WORLD_KEY_DOCKED_STATION_ID: String(docked_station_id),
	}


## Read world fields from a sections map (empty dict if missing/invalid).
static func world_from_sections(sections: Dictionary) -> Dictionary:
	if not sections.has(BalanceSession.SAVE_SECTION_WORLD):
		return {}
	var raw: Variant = sections[BalanceSession.SAVE_SECTION_WORLD]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


## Read mission template id from sections (empty if none).
static func mission_template_from_sections(sections: Dictionary) -> StringName:
	if not sections.has(BalanceSession.SAVE_SECTION_MISSION):
		return &""
	var raw: Variant = sections[BalanceSession.SAVE_SECTION_MISSION]
	if typeof(raw) != TYPE_DICTIONARY:
		return &""
	var data: Dictionary = raw
	if not data.has(BalanceSession.MISSION_KEY_TEMPLATE_ID):
		return &""
	return StringName(str(data[BalanceSession.MISSION_KEY_TEMPLATE_ID]))


static func _wallet_section(tree: SceneTree) -> Dictionary:
	var wallet: Node = _node_in_group(tree, &"wallet_service")
	if wallet == null or not wallet.has_method(&"to_section"):
		return {}
	var section: Variant = wallet.call(&"to_section")
	if typeof(section) != TYPE_DICTIONARY:
		return {}
	return section


static func _merge_cargo_section(tree: SceneTree, sections: Dictionary) -> void:
	# Always write when cargo service exists (empty hold is valid state).
	var cargo: Node = _node_in_group(tree, &"cargo_service")
	if cargo == null or not cargo.has_method(&"to_section"):
		return
	var section: Variant = cargo.call(&"to_section")
	if typeof(section) != TYPE_DICTIONARY:
		sections[BalanceEconomy.SAVE_SECTION_CARGO] = {}
		return
	sections[BalanceEconomy.SAVE_SECTION_CARGO] = section


static func _apply_cargo_from_sections(tree: SceneTree, sections: Dictionary) -> void:
	var cargo: Node = _node_in_group(tree, &"cargo_service")
	if cargo == null:
		return
	if sections.has(BalanceEconomy.SAVE_SECTION_CARGO) and cargo.has_method(&"apply_section"):
		cargo.call(&"apply_section", sections[BalanceEconomy.SAVE_SECTION_CARGO])
	elif cargo.has_method(&"reset"):
		cargo.call(&"reset")


static func _merge_ship_section(tree: SceneTree, sections: Dictionary) -> void:
	var ships: Node = _node_in_group(tree, BalanceFlight.GROUP_SHIP_SERVICE)
	if ships == null or not ships.has_method(&"to_section"):
		return
	var section: Variant = ships.call(&"to_section")
	if typeof(section) != TYPE_DICTIONARY:
		return
	sections[BalanceFlight.SAVE_SECTION_SHIP] = section


static func _apply_ship_from_sections(tree: SceneTree, sections: Dictionary) -> void:
	var ships: Node = _node_in_group(tree, BalanceFlight.GROUP_SHIP_SERVICE)
	if ships == null:
		return
	if sections.has(BalanceFlight.SAVE_SECTION_SHIP) and ships.has_method(&"apply_section"):
		ships.call(&"apply_section", sections[BalanceFlight.SAVE_SECTION_SHIP])
	elif ships.has_method(&"reset"):
		ships.call(&"reset")


static func _clamp_ship_to_cargo_fit(tree: SceneTree) -> void:
	var ships: Node = _node_in_group(tree, BalanceFlight.GROUP_SHIP_SERVICE)
	if ships == null or not ships.has_method(&"clamp_active_to_cargo_fit"):
		return
	ships.call(&"clamp_active_to_cargo_fit")


static func _mission_section(tree: SceneTree) -> Dictionary:
	var mission: Node = _node_in_group(tree, &"mission_service")
	if mission == null:
		return {}
	if mission.has_method(&"has_active") and mission.call(&"has_active") != true:
		return {}
	if not mission.has_method(&"to_section"):
		return {}
	var section: Variant = mission.call(&"to_section")
	if typeof(section) != TYPE_DICTIONARY:
		return {}
	return section


static func _world_section(tree: SceneTree) -> Dictionary:
	if tree == null:
		return {}
	var world: Node = tree.get_first_node_in_group(BalanceSession.GROUP_SYSTEM_WORLD)
	if world == null:
		return {}
	var system_id: StringName = &""
	if world.get("system_id") != null:
		system_id = StringName(str(world.get("system_id")))
	if String(system_id).is_empty():
		system_id = BalanceFlight.PLAYABLE_SYSTEM_ID

	var ship: Node = tree.get_first_node_in_group(BalanceSession.GROUP_PLAYER_SHIP)
	if ship == null:
		ship = _find_character_body(world)
	if ship == null or not (ship is Node3D):
		return {}
	var body: Node3D = ship as Node3D
	var docked: StringName = _docked_station_id(tree)
	return make_world_section(system_id, body.global_position, docked)


static func _find_character_body(root: Node) -> Node:
	if root is CharacterBody3D:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_character_body(child)
		if found != null:
			return found
	return null


static func _docked_station_id(tree: SceneTree) -> StringName:
	var dock: Node = _node_in_group(tree, &"docking_service")
	if dock == null or not dock.has_method(&"docked_station_id"):
		return &""
	var raw: Variant = dock.call(&"docked_station_id")
	if typeof(raw) == TYPE_STRING_NAME:
		var as_name: StringName = raw
		return as_name
	if typeof(raw) == TYPE_STRING:
		var as_text: String = raw
		return StringName(as_text)
	return &""


static func _merge_recovery_progress(tree: SceneTree, standing_section: Dictionary) -> void:
	var service: Node = _node_in_group(tree, &"recovery_service")
	if service == null or not service.has_method(&"progress_to_section"):
		return
	var progress: Variant = service.call(&"progress_to_section")
	if typeof(progress) == TYPE_DICTIONARY:
		standing_section[BalanceStanding.SAVE_KEY_RECOVERY_PROGRESS] = progress


static func _apply_standing_from_sections(tree: SceneTree, sections: Dictionary) -> void:
	if sections.has(BalanceStanding.SAVE_SECTION_KEY):
		var standing_raw: Variant = sections[BalanceStanding.SAVE_SECTION_KEY]
		StandingService.apply_section(standing_raw)
		_apply_recovery_progress(tree, standing_raw)
	else:
		StandingService.reset_to_defaults()
		_reset_recovery_progress(tree)


static func _apply_world_clock_from_sections(sections: Dictionary) -> void:
	if sections.has(BalanceWorldClock.SAVE_SECTION_KEY):
		WorldClock.apply_section(sections[BalanceWorldClock.SAVE_SECTION_KEY])
	else:
		# Old saves / missing section → career clock starts at zero.
		WorldClock.reset()


static func _apply_market_from_sections(sections: Dictionary) -> void:
	if sections.has(BalanceMarket.SAVE_SECTION_KEY):
		MarketService.apply_section(sections[BalanceMarket.SAVE_SECTION_KEY])
	else:
		# Old saves / missing section → markets seeded from station profiles.
		MarketService.reset()


static func _apply_boards_from_sections(sections: Dictionary) -> void:
	if sections.has(BalanceBoard.SAVE_SECTION_KEY):
		BoardService.apply_section(sections[BalanceBoard.SAVE_SECTION_KEY])
	else:
		# Old saves / missing section → boards re-derive from clock at step 0+.
		BoardService.reset()


static func _apply_incidents_from_sections(sections: Dictionary) -> void:
	if sections.has(BalanceIncident.SAVE_SECTION_KEY):
		IncidentService.apply_section(sections[BalanceIncident.SAVE_SECTION_KEY])
	else:
		# Old saves / missing section → security steps re-derive from clock.
		IncidentService.reset()


static func _apply_enforcement_from_sections(sections: Dictionary) -> void:
	if sections.has(BalanceEnforcement.SAVE_SECTION_KEY):
		EnforcementService.apply_section(sections[BalanceEnforcement.SAVE_SECTION_KEY])
	else:
		# Old saves / missing section → no heat.
		EnforcementService.reset()


static func _apply_wallet_from_sections(tree: SceneTree, sections: Dictionary) -> void:
	var wallet: Node = _node_in_group(tree, &"wallet_service")
	if wallet == null:
		return
	if sections.has(BalanceEconomy.SAVE_SECTION_KEY) and wallet.has_method(&"apply_section"):
		wallet.call(&"apply_section", sections[BalanceEconomy.SAVE_SECTION_KEY])
	elif wallet.has_method(&"reset"):
		wallet.call(&"reset")


static func _apply_mission_from_sections(tree: SceneTree, sections: Dictionary) -> void:
	var mission: Node = _node_in_group(tree, &"mission_service")
	if mission == null:
		return
	if sections.has(BalanceSession.SAVE_SECTION_MISSION) and mission.has_method(&"apply_section"):
		mission.call(&"apply_section", sections[BalanceSession.SAVE_SECTION_MISSION])
	elif mission.has_method(&"reset"):
		mission.call(&"reset")


static func _apply_career_from_sections(sections: Dictionary) -> void:
	if sections.has(BalanceSession.SAVE_SECTION_CAREER):
		CareerPathState.apply_section(sections[BalanceSession.SAVE_SECTION_CAREER])
	else:
		# Old saves: no path memory (sheet hides Origin/Trade/Mark).
		CareerPathState.reset()


static func _apply_recovery_progress(tree: SceneTree, standing_raw: Variant) -> void:
	if typeof(standing_raw) != TYPE_DICTIONARY:
		_reset_recovery_progress(tree)
		return
	var data: Dictionary = standing_raw
	var service: Node = _node_in_group(tree, &"recovery_service")
	if service == null or not service.has_method(&"apply_progress_section"):
		return
	if data.has(BalanceStanding.SAVE_KEY_RECOVERY_PROGRESS):
		service.call(&"apply_progress_section", data[BalanceStanding.SAVE_KEY_RECOVERY_PROGRESS])
	else:
		service.call(&"apply_progress_section", {})


static func _reset_recovery_progress(tree: SceneTree) -> void:
	var service: Node = _node_in_group(tree, &"recovery_service")
	if service != null and service.has_method(&"apply_progress_section"):
		service.call(&"apply_progress_section", {})


static func _node_in_group(tree: SceneTree, group: StringName) -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group(group)
