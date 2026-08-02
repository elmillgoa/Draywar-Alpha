class_name NpcTraffic
extends Node3D

## Gray-box NPC traffic that reflects local policing — Alpha A5 + E6.3/E6.4.
##
## Implements: Alpha/ALPHA_PHASE_PLAN.md A5, docs/BETA_E6_LIVED_IN_SPACE.md E6.3–E6.4
##
## Spawns orbiting TrafficShip hulls; count from system.policing; mix of
## civilian freighters and non-hostile patrol boats. Multi-dock systems park a
## share of traffic on secondary pads (E6.4 density). Display + damageable.
## Live ship count feeds combat kill witness_count (E2.3 / E6.3).

var _ships: Array[Node3D] = []
var _angles: Array[float] = []
var _radii: Array[float] = []
var _heights: Array[float] = []
var _omegas: Array[float] = []
## Orbit centre per ship (primary origin or secondary dock world position).
var _centers: Array[Vector3] = []


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


## Clear previous traffic and spawn for this system.
func rebuild_for_system(system_id: StringName) -> void:
	_clear()
	var system: StarSystem = _load_system(system_id)
	if system == null:
		return
	var count: int = _count_for_policing(system.policing)
	var patrol_count: int = BalanceCombat.traffic_patrol_count(count, system.policing)
	var dock_centers: Array[Vector3] = _dock_centers_for_system(system)
	var secondary_slots: int = 0
	if dock_centers.size() > 1:
		secondary_slots = BalanceEconomy.secondary_dock_traffic_slots(count)
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


func _process(delta: float) -> void:
	var dt: float = TimeScale.scaled_delta(delta)
	for i: int in _ships.size():
		if (
			i >= _angles.size()
			or i >= _radii.size()
			or i >= _heights.size()
			or i >= _omegas.size()
			or i >= _centers.size()
		):
			continue
		_angles[i] = _angles[i] + _omegas[i] * dt
		var angle: float = _angles[i]
		var radius: float = _radii[i]
		var height: float = _heights[i]
		var center: Vector3 = _centers[i]
		var ship: Node3D = _ships[i]
		if ship == null or not is_instance_valid(ship):
			continue
		ship.position = center + Vector3(cos(angle) * radius, height, sin(angle) * radius)
		# Face along orbit tangent.
		var tangent: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
		if _omegas[i] < 0.0:
			tangent = -tangent
		if tangent.length_squared() > BalanceFlight.DIRECTION_EPSILON:
			ship.look_at(ship.position + tangent, Vector3.UP)


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
