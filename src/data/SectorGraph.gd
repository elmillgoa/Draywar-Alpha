class_name SectorGraph
extends RefCounted

## Gate-graph helpers over live ContentLibrary systems — E5.3 / E5.4.
##
## Pure reads; no mutations. Used by sector map, logistics hop tests, and
## integration scenarios.


## Destination system ids listed on this system's gates.
static func neighbors(system_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if not ContentLibrary.has_item(system_id):
		return out
	var system: StarSystem = ContentLibrary.item(system_id) as StarSystem
	if system == null:
		return out
	for dest: StringName in system.gate_destination_ids:
		out.append(dest)
	return out


## Shortest gate-hop count between systems. 0 if same; -1 if unreachable.
static func hop_distance(from_id: StringName, to_id: StringName) -> int:
	if from_id == to_id:
		return 0
	if not ContentLibrary.has_item(from_id) or not ContentLibrary.has_item(to_id):
		return -1
	var queue: Array[StringName] = [from_id]
	var dist: Dictionary[StringName, int] = {from_id: 0}
	var head: int = 0
	while head < queue.size():
		var current: StringName = queue[head]
		head += 1
		var current_dist: int = dist[current]
		for next_id: StringName in neighbors(current):
			if dist.has(next_id):
				continue
			var step: int = current_dist + 1
			if next_id == to_id:
				return step
			dist[next_id] = step
			queue.append(next_id)
	return -1


## System id for a station content id, or empty if missing.
static func system_of_station(station_id: StringName) -> StringName:
	if not ContentLibrary.has_item(station_id):
		return &""
	var station: Station = ContentLibrary.item(station_id) as Station
	if station == null:
		return &""
	return station.system_id


## Hops between the systems hosting two stations. -1 if either is bad.
static func hop_distance_stations(from_station: StringName, to_station: StringName) -> int:
	var from_sys: StringName = system_of_station(from_station)
	var to_sys: StringName = system_of_station(to_station)
	if from_sys == &"" or to_sys == &"":
		return -1
	return hop_distance(from_sys, to_sys)


## True when every loaded star system is reachable from origin via gates.
static func is_connected_from(origin_id: StringName) -> bool:
	var all_ids: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	if all_ids.is_empty():
		return false
	if not ContentLibrary.has_item(origin_id):
		return false
	var seen: Dictionary[StringName, bool] = {origin_id: true}
	var queue: Array[StringName] = [origin_id]
	var head: int = 0
	while head < queue.size():
		var current: StringName = queue[head]
		head += 1
		for next_id: StringName in neighbors(current):
			if seen.has(next_id):
				continue
			if not ContentLibrary.has_item(next_id):
				continue
			seen[next_id] = true
			queue.append(next_id)
	return seen.size() == all_ids.size()


## Highest gate-destination count among loaded systems.
static func max_gate_degree() -> int:
	var best: int = 0
	for id: StringName in ContentLibrary.ids_in(&"star_systems"):
		var n: int = neighbors(id).size()
		if n > best:
			best = n
	return best


## True if the undirected graph is a pure path (no branches).
##
## A path on N nodes has N-1 undirected edges and exactly two degree-1 ends.
static func is_pure_path() -> bool:
	var ids: Array[StringName] = ContentLibrary.ids_in(&"star_systems")
	var n: int = ids.size()
	if n <= 1:
		return true
	var undirected: Dictionary[String, bool] = {}
	var degree: Dictionary[StringName, int] = {}
	for id: StringName in ids:
		degree[id] = 0
	for id: StringName in ids:
		for dest: StringName in neighbors(id):
			if not ContentLibrary.has_item(dest):
				continue
			var a: String = String(id)
			var b: String = String(dest)
			var key: String = a + "|" + b if a < b else b + "|" + a
			if undirected.has(key):
				continue
			undirected[key] = true
			degree[id] = degree[id] + 1
			if not degree.has(dest):
				degree[dest] = 0
			degree[dest] = degree[dest] + 1
	if undirected.size() != n - 1:
		return false
	var ends: int = 0
	var internal_degree: int = BalanceSession.GRAPH_PATH_INTERNAL_DEGREE
	for id: StringName in ids:
		var d: int = degree[id]
		if d == 1:
			ends += 1
		elif d != internal_degree:
			return false
	return ends == BalanceSession.GRAPH_PATH_INTERNAL_DEGREE
