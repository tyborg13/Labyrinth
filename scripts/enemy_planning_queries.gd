extends RefCounted

# Lightning queries live for one standard plan. Future-route fields can also
# be owned by an engine and shared while their exact board inputs stay equal.
const Surface = preload("res://scripts/board_surface_rules.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
var _lightning_components: Dictionary = {}

func lightning_component(state: Dictionary, target: Vector2i) -> Array[Vector2i]:
	if not _lightning_components.has(target):
		# Preserve the target-rooted traversal order: equal-distance impact tiles
		# keep the component's first tile, so components cannot share other roots.
		_lightning_components[target] = Surface.connected_component(state, target)
	return TypedArrays.vector2i(_lightning_components[target])

static func state_at_anchor(state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> Dictionary:
	# Standard-plan finalization only queries this view. Own the changed outer
	# containers and actor; nested state remains read-only. Forecast resolvers
	# that mutate geometry still make their own deep copies.
	var preview: Dictionary = state.duplicate(false)
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(false)
	var enemy_id: int = int(enemy.get("id", -1))
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY or int((enemies[index] as Dictionary).get("id", -1)) != enemy_id:
			continue
		var moved: Dictionary = enemy.duplicate(false)
		moved["pos"] = anchor
		enemies[index] = moved
		break
	preview["enemies"] = enemies
	return preview

# Retain only the latest geometry epoch, never attach caches to combat/save data.
# Snapshot the key: callers mutate containers in place, including during previews.
var _future_board: Array = []
var future_contexts: Dictionary = {}
var _distances: Dictionary = {}
var _reach: Dictionary = {}
var _movement: Dictionary = {}
var route_heap: RefCounted
var best_by_tile: Dictionary = {}
var closed_tiles: Dictionary = {}
var _route_records: Array[Dictionary]
var _route_record_count: int = 0

func prepare_future_board(state: Dictionary, targets: Array[Dictionary]) -> void:
	var actors: Array = []
	for value: Variant in state.get("enemies", []):
		if typeof(value) != TYPE_DICTIONARY:
			actors.append(null)
			continue
		var actor: Dictionary = value
		actors.append([actor.get("id", -1), actor.get("type", ""), actor.get("pos", null), int(actor.get("hp", 0)) > 0, actor.get("burrowed", false), actor.get("footprint", null)])
	var board: Array = [state.get("grid", []), state.get("terrain", []), state.get("traps", []), state.get("surfaces", {}), state.get("surface_rule_overrides", {}), state.get("objective", {}), actors, targets]
	if board == _future_board: return
	_future_board = board.duplicate(true)
	future_contexts.clear()
	_distances.clear()
	_reach.clear()
	_movement.clear()

func distance_field(footprint: Vector2i, target: Vector2i) -> Dictionary:
	var key: Array = [footprint, target]
	if not _distances.has(key): _distances[key] = {}
	return _distances[key]

func reach_field(footprint: Vector2i, action: Dictionary, target: Dictionary) -> Dictionary:
	var key: Array = [footprint, action, target]
	if not _reach.has(key): _reach[key.duplicate(true)] = {}
	return _reach[key]

func movement_field(enemy: Dictionary) -> Dictionary:
	# Surface movement reads the authored flying flag, footprint and id presence.
	var key: Array = [enemy.get("type", ""), enemy.get("footprint", Vector2i.ONE), enemy.has("id")]
	if not _movement.has(key): _movement[key] = {}
	return _movement[key]

func begin_routes(compare: Callable) -> void:
	if route_heap == null: route_heap = preload("res://scripts/enemy_route_heap.gd").new(compare)
	route_heap.clear()
	best_by_tile.clear()
	closed_tiles.clear()
	_route_record_count = 0

func route_record() -> Dictionary:
	if _route_record_count == _route_records.size():
		var route: Array[Vector2i]
		_route_records.append({"tile": Vector2i.ZERO, "cost": 0, "steps": 0, "route": route, "open_prefix_steps": 0, "prefix_blocked": false, "regression_cost": 0, "prefix_distance_cost": 0})
	var record: Dictionary = _route_records[_route_record_count]
	(record["route"] as Array[Vector2i]).clear()
	return record

func keep_route_record() -> void:
	_route_record_count += 1

func set_route_record(record: Dictionary, tile: Vector2i, cost: int, steps: int, open_prefix_steps: int, prefix_blocked: bool, regression_cost: int, prefix_distance_cost: int) -> void:
	record["tile"] = tile
	record["cost"] = cost
	record["steps"] = steps
	record["open_prefix_steps"] = open_prefix_steps
	record["prefix_blocked"] = prefix_blocked
	record["regression_cost"] = regression_cost
	record["prefix_distance_cost"] = prefix_distance_cost
