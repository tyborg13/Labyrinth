extends RefCounted

## Texture padding, a lifted pelvis and a destination tile are not floor depth.
## Sample authored forward travel on the resolved board path. The four-facing
## artwork projection is not the path axis for diagonal moves, and lift is not
## ground travel. Inverting that body offset can select a culled boundary host.
const Action = preload("action.gd")
const Timing = preload("playback_timing.gd")
const POSITION_EPSILON: float = 0.000001

static func moving(type: String, key: String, shown: Dictionary) -> bool:
	return shown.get("unit_footprint_world_positions", {}).has(key) and (Timing.uses_parity(Action.data_for(type)) or not shown.get(type + "_motion", {}).get(key, {}).get("root_forward_override", {}).is_empty())

static func tile(board: Control, unit: Dictionary, shown: Dictionary) -> Vector2i:
	var key: String = str(unit.get("key", ""))
	var type: String = str(unit.get("type", ""))
	var ground: Vector2 = position(board, unit, shown)
	var footprint: Vector2i = board._resolved_unit_footprint(unit)
	var footprint_offset: Vector2i = footprint - Vector2i.ONE
	var to: Vector2i = shown.get("unit_draw_tiles", {}).get(key, board.draw_tile_for_unit_origin(unit, unit.get("pos", Vector2i.ZERO))) - footprint_offset
	var motion: Dictionary = shown.get(type + "_motion", {}).get(key, {})
	var from: Vector2i = to - motion["direction"] if motion.get("clip", "") == "move" else unit.get("pos", to)
	var root_path: Dictionary = motion.get("root_forward_override", {})
	if root_path.has("path_from"):
		from = root_path["path_from"]
		to = root_path["path_to"]
	var start: Vector2 = board.world_position_for_unit_origin(unit, from)
	var segment: Vector2 = board.world_position_for_unit_origin(unit, to) - start
	if segment.length_squared() > 0.0:
		# Equal-depth diagonal ties keep the start host. On depth-changing
		# segments that would conflict with strict ground-Y prop order, so the
		# ground slot takes precedence. Never round axes independently.
		var progress: float = (ground - start).dot(segment) / segment.length_squared()
		if segment.y == 0.0:
			return board.draw_tile_for_unit_origin(unit, to if progress > 0.5 + POSITION_EPSILON else from)
		if progress >= 1.0 - POSITION_EPSILON:
			return board.draw_tile_for_unit_origin(unit, to)
		return _ground_host(board, ground, board.draw_tile_for_unit_origin(unit, from))
	# Stationary footprint overrides (including shared-tile occupant crossings).
	return board.draw_tile_for_unit_origin(unit, from)

static func _ground_host(board: Control, ground: Vector2, fallback: Vector2i) -> Vector2i:
	# A body between ground rows belongs after the entire preceding row,
	# before any prop in the next row. Nearest endpoint selection can still
	# put it in front of the next row's props on depth-changing diagonals.
	var tiles: Array[Vector2i] = board._rendered_tiles_in_draw_order()
	var centres: Dictionary = board._board_layout_cache_tile_centers
	var low: int = 0
	var high: int = tiles.size()
	while low < high:
		var middle: int = (low + high) / 2
		var centre: Vector2 = centres[tiles[middle]]
		if centre.y < ground.y or (centre.y == ground.y and centre.x <= ground.x):
			low = middle + 1
		else:
			high = middle
	return tiles[low - 1] if low > 0 else fallback

static func position(board: Control, unit: Dictionary, shown: Dictionary) -> Vector2:
	var key: String = str(unit.get("key", ""))
	var type: String = str(unit.get("type", ""))
	var ground: Vector2 = shown.get("unit_footprint_world_positions", {}).get(key, board.world_position_for_unit_origin(unit, unit.get("pos", Vector2i.ZERO)))
	var motion: Dictionary = shown.get(type + "_motion", {}).get(key, {})
	var origins: Dictionary = shown.get("unit_texture_origins", {})
	if not moving(type, key, shown) or motion.get("clip", "") != "move" or not origins.has(key): return ground
	var override: Dictionary = motion.get("root_forward_override", {})
	if not override.is_empty(): return origins[key] + (override["axis"] as Vector2) * float(override["forward_px"])
	var direction: Vector2i = motion["direction"]
	var view: Dictionary = preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(direction)
	var forward: float = 0.0
	# Depth needs only root travel, not every joint/channel of the drawn pose.
	for track: Dictionary in Action.data_for(type)["view_tracks"][view["facing"]]["move"]:
		if track["bone"] != "root" or track["channel"] != "forward_px": continue
		forward = Action.Motion.value_at(track["keys"], clampf(motion["phase"], 0.0, 1.0))
		if track["forward_mode"] == "fraction_of_step": forward *= motion["step_distance_px"]
	return origins[key] + board._tile_step_offset(direction).normalized() * forward

static func sort_occupants(board: Control, units: Array, shown: Dictionary) -> void:
	var has_moving_rig: bool = false
	for unit: Dictionary in units:
		if moving(str(unit.get("type", "")), str(unit.get("key", "")), shown): has_moving_rig = true
	if has_moving_rig:
		units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return position(board, a, shown).y < position(board, b, shown).y)
