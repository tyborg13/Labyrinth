extends RefCounted

# Path inputs are shared by the board's depth slices; tint remains local.
# Snapshot values, not container identity: tools and callers can edit arrays in
# place. Only lookup/occlusion preparation is retained; paint and clocks stay live.
const MAX_TINT_QUERIES: int = 16
var _path_inputs: Array = []
var _paths: Array = []
var _paths_by_tile: Dictionary = {}
var _path_revision: int = -1
var _arrow_revision: int = -1
var _arrow_inputs: Array = []
var _arrows_by_tile: Dictionary = {}
var _stationary_units_by_tile: Dictionary = {}
var _stationary_batch: bool = false
var _stationary_index_ready: bool = false
var _obstructions: Array = []
var _tints: Dictionary = {}
var _cacheable_obstructions: bool = true
var path_builds: int = 0
var path_hits: int = 0
var tint_builds: int = 0
var tint_hits: int = 0

func paths_at(board: Control, tile: Vector2i, revision: int = -1) -> Array:
	if revision < 0 or revision != _path_revision:
		_sync_paths(board)
		_path_revision = revision
	else:
		path_hits += 1
	return _paths_by_tile.get(tile, [])

func _sync_paths(board: Control) -> void:
	var inputs: Array = [board.presentation.get("displacement_paths", []),
		board.presentation.get("path_tiles", []), board.presentation.get("path_color", board.MOVE_PATH_COLOR),
		board.presentation.get("enemy_threat_previews", [])]
	if inputs == _path_inputs:
		path_hits += 1
		return
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
	_paths_by_tile.clear()
	for entry: Array in _paths:
		# A path that revisits a tile still contributes just one clipped command.
		var visited: Dictionary = {}
		for tile: Vector2i in entry[0]:
			if visited.has(tile): continue
			visited[tile] = true
			(_paths_by_tile.get_or_add(tile, []) as Array).append(entry)
	path_builds += 1

func arrows_at(board: Control, tile: Vector2i, revision: int = -1) -> Array:
	if revision < 0 or revision != _arrow_revision:
		_arrow_revision = revision
		var inputs: Array = [board.presentation.get("illusion_echo_previews", []), board.presentation.get("enemy_threat_previews", [])]
		if inputs != _arrow_inputs:
			_arrow_inputs = inputs.duplicate(true)
			_arrows_by_tile.clear()
			# Keep echoes before threats and preserve the source order on each tile.
			for echo: Dictionary in _arrow_inputs[0]:
				(_arrows_by_tile.get_or_add(board._ranged_preview_depth_tile(echo), []) as Array).append([echo, []])
			for threat: Dictionary in _arrow_inputs[1]:
				var effect: Dictionary = board._enemy_threat_ranged_effect(threat)
				if effect.is_empty(): continue
				(_arrows_by_tile.get_or_add(board._ranged_preview_depth_tile(effect), []) as Array).append([effect, [str(threat.get("enemy_key", ""))]])
	return _arrows_by_tile.get(tile, [])

func begin_redraw_batch(shown: Dictionary) -> void:
	_stationary_batch = (shown.get("unit_footprint_world_positions", {}) as Dictionary).is_empty()

func finish_redraw_batch() -> void:
	_stationary_batch = false
	_stationary_index_ready = false
	_stationary_units_by_tile.clear()

func units_at(layer: Control, tile: Vector2i) -> Array:
	if _stationary_batch:
		if not _stationary_index_ready:
			_index_stationary_units(layer)
			_stationary_index_ready = true
		return _stationary_units_by_tile.get(tile, [])
	# A moving rig can select a host from the layer's resolved depth geometry.
	var units: Array[Dictionary]
	for unit: Dictionary in layer._visible_units():
		if layer._effective_unit_tile(unit) == tile: units.append(unit)
	return units

func _index_stationary_units(layer: Control) -> void:
	# Use the same roster order as scene paint, including shared-tile occupants.
	for unit: Dictionary in layer._visible_units():
		var tile: Vector2i = layer._effective_unit_tile(unit)
		(_stationary_units_by_tile.get_or_add(tile, []) as Array).append(unit)

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
