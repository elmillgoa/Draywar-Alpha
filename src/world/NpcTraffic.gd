class_name NpcTraffic
extends Node3D

## Gray-box NPC traffic that reflects local policing — Alpha A5 + E6.3/E6.4 + S3b.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5, docs/BETA_E6_LIVED_IN_SPACE.md E6.3–E6.4,
## docs/STEAM_PHASE_PLAN.md Phase S3 S3b
##
## Spawns orbiting TrafficShip hulls; count from system.policing; mix of
## civilian freighters and non-hostile patrol boats. Multi-dock systems park a
## share of traffic on secondary pads (E6.4 density). Display + damageable.
## Live ship count feeds combat kill witness_count (E2.3 / E6.3).
##
## S3b purpose lite (not full AI): some civilians dock/undock cycle; when the
## market shows a shortage at a station, retask up to one freighter toward it.
## Escort freighters stay MissionEscortShip — traffic death never fails escorts.

var _ships: Array[Node3D] = []
var _angles: Array[float] = []
var _radii: Array[float] = []
var _heights: Array[float] = []
var _omegas: Array[float] = []
## Orbit centre per ship (primary origin or secondary dock world position).
var _centers: Array[Vector3] = []
## S3b purpose per ship.
var _purposes: Array[StringName] = []
## Dock-cycle phase timer (seconds into current phase).
var _purpose_timers: Array[float] = []
## Dock-cycle phase: 0 approach, 1 hold, 2 depart.
var _purpose_phases: Array[int] = []
## Home orbit radius (restore after dock cycle / shortage).
var _home_radii: Array[float] = []
## Target station world position for shortage runs (or dock pad).
var _purpose_targets: Array[Vector3] = []
var _system_id: StringName = &""


func _enter_tree() -> void:
	add_to_group(BalanceEconomy.GROUP_NPC_TRAFFIC)


## How many ambient traffic ships are currently alive (attribution witnesses).
func live_ship_count() -> int:
	var count: int = 0
	for ship: Node3D in _ships:
		if ship == null or not is_instance_valid(ship):
			continue
		if ship.has_method(&"is_alive") and ship.call(&"is_alive") != true:
			continue
		count += 1
	return count


## How many ships currently use this purpose (tests / diagnostics).
func count_with_purpose(purpose: StringName) -> int:
	var n: int = 0
	for i: int in _ships.size():
		if i >= _purposes.size():
			continue
		var ship: Node3D = _ships[i]
		if ship == null or not is_instance_valid(ship):
			continue
		if _purposes[i] == purpose:
			n += 1
	return n


## Drop a destroyed ship from the orbit lists (called from TrafficShip._die).
func unregister_ship(ship: Node3D) -> void:
	if ship == null:
		return
	var idx: int = _ships.find(ship)
	if idx < 0:
		return
	_ships.remove_at(idx)
	if idx < _angles.size():
		_angles.remove_at(idx)
	if idx < _radii.size():
		_radii.remove_at(idx)
	if idx < _heights.size():
		_heights.remove_at(idx)
	if idx < _omegas.size():
		_omegas.remove_at(idx)
	if idx < _centers.size():
		_centers.remove_at(idx)
	if idx < _purposes.size():
		_purposes.remove_at(idx)
	if idx < _purpose_timers.size():
		_purpose_timers.remove_at(idx)
	if idx < _purpose_phases.size():
		_purpose_phases.remove_at(idx)
	if idx < _home_radii.size():
		_home_radii.remove_at(idx)
	if idx < _purpose_targets.size():
		_purpose_targets.remove_at(idx)


## Clear previous traffic and spawn for this system.
func rebuild_for_system(system_id: StringName) -> void:
	_clear()
	_system_id = system_id
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return
	var count: int = _count_for_policing(system.policing)
	var patrol_count: int = BalanceCombat.traffic_patrol_count(count, system.policing)
	var dock_centers: Array[Vector3] = _dock_centers_for_system(system)
	var secondary_slots: int = 0
	if dock_centers.size() > 1:
		secondary_slots = BalanceEconomy.secondary_dock_traffic_slots(count)
	var dock_cycle_slots: int = 0
	var civilian_count: int = maxi(0, count - patrol_count)
	if civilian_count > 0:
		var cycle_f: float = float(civilian_count) * BalanceIncident.TRAFFIC_DOCK_CYCLE_FRACTION
		dock_cycle_slots = floori(cycle_f)
	var dock_cycle_assigned: int = 0
	for i: int in count:
		var role: StringName = BalanceCombat.ROLE_CIVILIAN
		if i < patrol_count:
			role = BalanceCombat.ROLE_PATROL
		var color: Color = _color_for_role(role, system.policing)
		var ship: Node3D = _make_npc(role, color)
		var t: float = float(i) / float(maxi(count, 1))
		var angle: float = t * TAU
		var center: Vector3 = dock_centers[0] if not dock_centers.is_empty() else Vector3.ZERO
		var radius: float = lerpf(BalanceEconomy.NPC_ORBIT_MIN, BalanceEconomy.NPC_ORBIT_MAX, t)
		# First `secondary_slots` ships orbit secondary docks (round-robin).
		if i < secondary_slots and dock_centers.size() > 1:
			var sec_idx: int = 1 + (i % (dock_centers.size() - 1))
			center = dock_centers[sec_idx]
			radius = lerpf(
				BalanceEconomy.NPC_SECONDARY_ORBIT_MIN, BalanceEconomy.NPC_SECONDARY_ORBIT_MAX, t
			)
		var height: float = lerpf(
			-BalanceEconomy.NPC_HEIGHT_SPREAD, BalanceEconomy.NPC_HEIGHT_SPREAD, t
		)
		var omega: float = (
			BalanceEconomy.NPC_ORBIT_OMEGA * (1.0 + t * BalanceEconomy.NPC_ORBIT_OMEGA_SPREAD)
		)
		if i % BalanceEconomy.NPC_ORBIT_REVERSE_EVERY == 1:
			omega = -omega
		ship.position = center + Vector3(cos(angle) * radius, height, sin(angle) * radius)
		add_child(ship)
		_ships.append(ship)
		_angles.append(angle)
		_radii.append(radius)
		_heights.append(height)
		_omegas.append(omega)
		_centers.append(center)
		_home_radii.append(radius)
		_purpose_timers.append(0.0)
		_purpose_phases.append(0)
		_purpose_targets.append(center)
		var purpose: StringName = BalanceIncident.PURPOSE_ORBIT
		if (
			role == BalanceCombat.ROLE_CIVILIAN
			and dock_cycle_assigned < dock_cycle_slots
			and not dock_centers.is_empty()
		):
			purpose = BalanceIncident.PURPOSE_DOCK_CYCLE
			_purpose_targets[i] = dock_centers[0]
			dock_cycle_assigned += 1
		_purposes.append(purpose)
		if ship is TrafficShip:
			(ship as TrafficShip).set_purpose(purpose)
	_maybe_retask_shortage_freighter(system, dock_centers)


## Force a shortage retask for tests (uses current market stock).
func retask_shortage_from_market() -> bool:
	var system: StarSystem = _load_system(_system_id)
	if system == null:
		return false
	var dock_centers: Array[Vector3] = _dock_centers_for_system(system)
	return _maybe_retask_shortage_freighter(system, dock_centers)


## Retask freighter index to fly toward world target (tests).
func force_shortage_run(ship_index: int, target: Vector3) -> bool:
	if ship_index < 0 or ship_index >= _ships.size():
		return false
	var ship: Node3D = _ships[ship_index]
	if ship == null or not is_instance_valid(ship):
		return false
	if ship is TrafficShip:
		var ts: TrafficShip = ship as TrafficShip
		if ts.role_id == BalanceCombat.ROLE_PATROL:
			return false
	_purposes[ship_index] = BalanceIncident.PURPOSE_SHORTAGE_RUN
	_purpose_targets[ship_index] = target
	_purpose_timers[ship_index] = 0.0
	if ship is TrafficShip:
		(ship as TrafficShip).set_purpose(BalanceIncident.PURPOSE_SHORTAGE_RUN)
	return true


func _process(delta: float) -> void:
	var dt: float = TimeScale.scaled_delta(delta)
	for i: int in _ships.size():
		if (
			i >= _angles.size()
			or i >= _radii.size()
			or i >= _heights.size()
			or i >= _omegas.size()
			or i >= _centers.size()
			or i >= _purposes.size()
		):
			continue
		var ship: Node3D = _ships[i]
		if ship == null or not is_instance_valid(ship):
			continue
		var purpose: StringName = _purposes[i]
		if purpose == BalanceIncident.PURPOSE_SHORTAGE_RUN:
			_process_shortage(i, dt)
			continue
		if purpose == BalanceIncident.PURPOSE_DOCK_CYCLE:
			_process_dock_cycle(i, dt)
			continue
		_process_orbit(i, dt)


func _process_orbit(i: int, dt: float) -> void:
	_angles[i] = _angles[i] + _omegas[i] * dt
	var angle: float = _angles[i]
	var radius: float = _radii[i]
	var height: float = _heights[i]
	var center: Vector3 = _centers[i]
	var ship: Node3D = _ships[i]
	ship.position = center + Vector3(cos(angle) * radius, height, sin(angle) * radius)
	var tangent: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
	if _omegas[i] < 0.0:
		tangent = -tangent
	if tangent.length_squared() > BalanceFlight.DIRECTION_EPSILON:
		ship.look_at(ship.position + tangent, Vector3.UP)


func _process_dock_cycle(i: int, dt: float) -> void:
	_purpose_timers[i] = _purpose_timers[i] + dt
	var phase: int = _purpose_phases[i]
	var ship: Node3D = _ships[i]
	var center: Vector3 = _centers[i]
	var home_r: float = _home_radii[i] if i < _home_radii.size() else _radii[i]
	var pad: Vector3 = _purpose_targets[i]
	var height: float = _heights[i]
	var angle: float = _angles[i]
	var hold_h: float = height * BalanceIncident.TRAFFIC_DOCK_HOLD_HEIGHT_FACTOR
	if phase == BalanceIncident.TRAFFIC_DOCK_PHASE_APPROACH:
		# Approach pad.
		var approach_secs: float = BalanceIncident.TRAFFIC_DOCK_APPROACH_SECONDS
		var t: float = clampf(_purpose_timers[i] / approach_secs, 0.0, 1.0)
		var orbit_pos: Vector3 = center + Vector3(cos(angle) * home_r, height, sin(angle) * home_r)
		var pad_pos: Vector3 = pad + Vector3(0.0, hold_h, 0.0)
		ship.position = orbit_pos.lerp(pad_pos, t)
		if _purpose_timers[i] >= approach_secs:
			_purpose_phases[i] = BalanceIncident.TRAFFIC_DOCK_PHASE_HOLD
			_purpose_timers[i] = 0.0
	elif phase == BalanceIncident.TRAFFIC_DOCK_PHASE_HOLD:
		# Hold at pad (docked lite).
		ship.position = pad + Vector3(0.0, hold_h, 0.0)
		if _purpose_timers[i] >= BalanceIncident.TRAFFIC_DOCK_HOLD_SECONDS:
			_purpose_phases[i] = BalanceIncident.TRAFFIC_DOCK_PHASE_DEPART
			_purpose_timers[i] = 0.0
	else:
		# Depart back to orbit.
		var depart_secs: float = BalanceIncident.TRAFFIC_DOCK_DEPART_SECONDS
		var t2: float = clampf(_purpose_timers[i] / depart_secs, 0.0, 1.0)
		var pad_pos2: Vector3 = pad + Vector3(0.0, hold_h, 0.0)
		var orbit_pos2: Vector3 = center + Vector3(cos(angle) * home_r, height, sin(angle) * home_r)
		ship.position = pad_pos2.lerp(orbit_pos2, t2)
		if _purpose_timers[i] >= depart_secs:
			_purpose_phases[i] = BalanceIncident.TRAFFIC_DOCK_PHASE_APPROACH
			_purpose_timers[i] = 0.0
			_radii[i] = home_r
	var face: Vector3 = pad - ship.position
	if face.length_squared() > BalanceFlight.DIRECTION_EPSILON:
		ship.look_at(ship.position + face.normalized(), Vector3.UP)


func _process_shortage(i: int, dt: float) -> void:
	var ship: Node3D = _ships[i]
	var target: Vector3 = _purpose_targets[i]
	var to_target: Vector3 = target - ship.position
	var dist: float = to_target.length()
	if dist <= BalanceIncident.TRAFFIC_SHORTAGE_ARRIVE_DIST:
		# Park into orbit at arrival.
		_purposes[i] = BalanceIncident.PURPOSE_ORBIT
		_centers[i] = target
		_radii[i] = BalanceEconomy.NPC_SECONDARY_ORBIT_MIN
		if ship is TrafficShip:
			(ship as TrafficShip).set_purpose(BalanceIncident.PURPOSE_ORBIT)
		return
	var step: float = BalanceIncident.TRAFFIC_SHORTAGE_SPEED * dt
	if step >= dist:
		ship.position = target
	else:
		ship.position = ship.position + to_target.normalized() * step
	if to_target.length_squared() > BalanceFlight.DIRECTION_EPSILON:
		ship.look_at(ship.position + to_target.normalized(), Vector3.UP)


func _maybe_retask_shortage_freighter(system: StarSystem, dock_centers: Array[Vector3]) -> bool:
	if system == null or dock_centers.is_empty():
		return false
	if (
		count_with_purpose(BalanceIncident.PURPOSE_SHORTAGE_RUN)
		>= (BalanceIncident.TRAFFIC_SHORTAGE_FREIGHTERS_MAX)
	):
		return false
	var best_station: StringName = &""
	var best_ratio: float = 1.0
	var station_index: int = 0
	for s: int in system.station_ids.size():
		var station_id: StringName = system.station_ids[s]
		var ratio: float = _worst_shortage_ratio(station_id)
		if ratio < best_ratio:
			best_ratio = ratio
			best_station = station_id
			station_index = s
	if String(best_station).is_empty():
		return false
	if best_ratio > BalanceIncident.TRAFFIC_SHORTAGE_RATIO:
		return false
	var target: Vector3 = dock_centers[0]
	if station_index < dock_centers.size():
		target = dock_centers[station_index]
	# Prefer a civilian still on orbit.
	for i: int in _ships.size():
		if i >= _purposes.size():
			continue
		if _purposes[i] != BalanceIncident.PURPOSE_ORBIT:
			continue
		var ship: Node3D = _ships[i]
		if ship == null or not is_instance_valid(ship):
			continue
		if ship is TrafficShip and (ship as TrafficShip).role_id == BalanceCombat.ROLE_PATROL:
			continue
		return force_shortage_run(i, target)
	return false


func _worst_shortage_ratio(station_id: StringName) -> float:
	# 1.0 = no shortage; lower is worse. MarketService is bare autoload.
	var worst: float = 1.0
	for commodity_id: StringName in ContentLibrary.ids_in(
		BalanceEconomy.COMMODITY_CONTENT_CATEGORY
	):
		var stock: int = MarketService.stock(station_id, commodity_id)
		var target: float = MarketService.target_stock(station_id, commodity_id)
		if target <= 0.0:
			continue
		var ratio: float = float(stock) / target
		if ratio < worst:
			worst = ratio
	return worst


func _clear() -> void:
	for ship: Node3D in _ships:
		if ship != null and is_instance_valid(ship):
			remove_child(ship)
			ship.free()
	_ships.clear()
	_angles.clear()
	_radii.clear()
	_heights.clear()
	_omegas.clear()
	_centers.clear()
	_purposes.clear()
	_purpose_timers.clear()
	_purpose_phases.clear()
	_home_radii.clear()
	_purpose_targets.clear()


func _load_system(id: StringName) -> StarSystem:
	if not ContentLibrary.has_item(id):
		return null
	var item: ContentItem = ContentLibrary.item(id)
	return item as StarSystem


func _count_for_policing(policing: StringName) -> int:
	# BalanceEconomy.npc_count_for_policing is the single source for density.
	return BalanceEconomy.npc_count_for_policing(policing)


## World positions for each station in system order (primary first).
func _dock_centers_for_system(system: StarSystem) -> Array[Vector3]:
	var centers: Array[Vector3] = []
	for station_id: StringName in system.station_ids:
		var offset: Vector3 = Vector3.ZERO
		if ContentLibrary.has_item(station_id):
			var item: ContentItem = ContentLibrary.item(station_id)
			var station: Station = item as Station
			if station != null:
				offset = station.position_offset
		centers.append(BalanceFlight.STATION_POSITION + offset)
	if centers.is_empty():
		centers.append(BalanceFlight.STATION_POSITION)
	return centers


func _color_for_role(role: StringName, policing: StringName) -> Color:
	if role == BalanceCombat.ROLE_PATROL:
		return BalanceCombat.COLOR_TRAFFIC_PATROL
	# Civilians tint by policing so systems still read differently at a glance.
	match policing:
		StarSystem.POLICED_BY_PATROLS:
			return BalanceEconomy.NPC_COLOR_PATROLLED
		StarSystem.POLICED_BY_CONTESTED:
			return BalanceEconomy.NPC_COLOR_CONTESTED
		StarSystem.POLICED_BY_NOBODY:
			return BalanceEconomy.NPC_COLOR_LAWLESS
		_:
			return BalanceCombat.COLOR_TRAFFIC_CIVILIAN


func _make_npc(role: StringName, color: Color) -> Node3D:
	var ship: TrafficShip = TrafficShip.new()
	ship.name = "TrafficShip"
	ship.apply_role(role)
	ship.build_visual(color)
	return ship
