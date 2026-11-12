extends RefCounted

# Owned by one scene-tile canvas, never synchronized from set_combat_state.
# Snapshot values, not container identity: tools and callers can edit arrays in
# place. Only lookup/occlusion preparation is retained; paint and clocks stay live.
const MAX_TINT_QUERIES: int = 16
var _path_inputs: Array = []
var _paths: Array = []
var _obstructions: Array = []
var _tints: Dictionary = {}
var _cacheable_obstructions: bool = true
var path_builds: int = 0
var path_hits: int = 0
var tint_builds: int = 0
var tint_hits: int = 0

func paths(board: Control) -> Array:
	var inputs: Array = [board.presentation.get("displacement_paths", []),
		board.presentation.get("path_tiles", []), board.presentation.get("path_color", board.MOVE_PATH_COLOR),
		board.presentation.get("enemy_threat_previews", [])]
	if inputs == _path_inputs:
		path_hits += 1
		return _paths
	_path_inputs = inputs.duplicate(true)
	_paths = []
	for path: Array in inputs[0]:
		_paths.append([board._vector2i_array(path), board.ENEMY_PATH_PREVIEW_COLOR, false])
	var path_tiles: Array[Vector2i] = board._vector2i_array(inputs[1])
	var color: Color = inputs[2]
	var threats: Array = inputs[3]
	var focused: bool = false
	if threats.size() == 1 and typeof(threats[0]) == TYPE_DICTIONARY:
		focused = color.is_equal_approx(board.ENEMY_PATH_PREVIEW_COLOR) and path_tiles == board._vector2i_array(threats[0].get("projected_path", []))
	if not focused:
		_paths.append([path_tiles, color, true])
	for threat: Variant in threats:
		if typeof(threat) != TYPE_DICTIONARY or not board._threat_has_projected_movement(threat): continue
		_paths.append([board._vector2i_array(threat.get("projected_path", [])), board.ENEMY_PATH_PREVIEW_COLOR, false])
	path_builds += 1
	return _paths

func tint(board: Control, tile_id: String, tile: Vector2i, rect: Rect2, entries: Array) -> Color:
	if entries != _obstructions:
		_obstructions = entries.duplicate(true)
		_tints.clear()
		_cacheable_obstructions = true
		# Legacy callers can supply units instead of prepared rectangles. Their
		# geometry may animate without a changed dictionary; keep that path live.
		for entry: Variant in entries:
			if entry is Dictionary and not entry.has("rect"):
				_cacheable_obstructions = false
	var key: Array = [tile_id, tile, rect]
	if _cacheable_obstructions and _tints.has(key):
		tint_hits += 1
		return _tints[key]
	var result: Color = board._foreground_blocker_tint_uncached(tile_id, tile, rect, entries)
	if _cacheable_obstructions:
		# Geometry edits without actors must not accumulate old pan/zoom queries.
		if _tints.size() >= MAX_TINT_QUERIES: _tints.clear()
		_tints[key] = result
	tint_builds += 1
	return result
