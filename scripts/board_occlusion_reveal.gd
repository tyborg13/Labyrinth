extends Node

# occ-02 (owner 2026-11-13): the board's focus tile stays readable. Every
# sprite painted after it whose rest-pose opaque pixels cover at least 15% of
# its floor diamond draws at 30% while the tile has focus: units of any team,
# terrain, scene props, pillars/interior walls and doors. Purely a transparency
# change; the tile's own contents, anything behind it and the HUD stay opaque.
# Coverage reuses the x-ray rest masks (25% resolution) and the silhouettes'
# painter-order sources, and runs only when the focus tile or the board
# geometry changes. Fades touch only the occluders' own canvases, and nothing
# runs once every fade has settled.
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const REVEAL_ALPHA: float = 0.30
const MIN_COVERAGE: float = 0.15
# Linear, like the plate fades.
const FADE_IN: float = 0.12
const FADE_OUT: float = 0.20
# Area-uniform lattice over the floor diamond (an affine image of a square).
const SAMPLES: int = 16
var board: Control
var focus_tile := Vector2i(-1, -1)
# id -> {"id", "category", "key", "tile", "coverage", "on", "progress"}
var targets: Dictionary = {}
var coverage_builds: int = 0
var _occluders: Dictionary = {}
var _order: Dictionary = {}
var _retarget_pending: bool = false
var _unit_alphas: Dictionary = {}
var _prop_alphas: Dictionary = {}

func attach(owner_board: Control) -> void:
	board = owner_board
	name = "OcclusionReveal"
	owner_board.add_child(self)
	set_process(false)

func set_focus(tile: Vector2i) -> void:
	if tile == focus_tile: return
	focus_tile = tile
	_retarget()

# The source roster or board geometry changed: cached coverage is stale. Work
# waits for the next frame and happens only while a tile has focus or fades.
func invalidate() -> void:
	_occluders.clear()
	_order.clear()
	if focus_tile.x < 0 and targets.is_empty(): return
	_retarget_pending = true
	set_process(true)

static func category_for(source: Dictionary) -> String:
	match str(source["kind"]):
		"unit": return "unit"
		"terrain": return "terrain"
		"prop":
			var prop_kind: String = str(source.get("prop_kind", ""))
			# Outer boundary walls never stand in front of a floor tile.
			if prop_kind == "wall": return ""
			if prop_kind in ["pillar", "door"]: return prop_kind
			return "scene_prop"
	return "" # Traps and loot lie on the floor; they are what the reveal shows.

static func target_id(category: String, key: String, tile: Vector2i) -> String:
	return "unit:" + key if category == "unit" else "%s:%d,%d" % [category, tile.x, tile.y]

static func diamond_points(polygon: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	if polygon.size() < 4: return points
	var top: Vector2 = polygon[0]
	for row: int in range(SAMPLES):
		for column: int in range(SAMPLES):
			points.append(top + (polygon[1] - top) * ((column + 0.5) / SAMPLES) + (polygon[3] - top) * ((row + 0.5) / SAMPLES))
	return points

# Occluders of one tile, keyed by target id. Cached until the geometry changes.
func occluders_for(tile: Vector2i) -> Dictionary:
	if tile.x < 0 or not is_instance_valid(board) or (board.get("combat_state") as Dictionary).is_empty(): return {}
	if _occluders.has(tile): return _occluders[tile]
	var silhouettes: Node = board.get("_occlusion_silhouettes")
	if not is_instance_valid(silhouettes): return {}
	var sources: Array = silhouettes.call("current_sources")
	if _order.is_empty():
		var tiles: Array = board.call("_rendered_tiles_in_draw_order")
		for index: int in range(tiles.size()): _order[tiles[index]] = index
	var result: Dictionary = {}
	# Off-board tiles have no floor diamond to reveal.
	if _order.has(tile):
		var polygon: PackedVector2Array = board.call("_tile_polygon", tile)
		var points: PackedVector2Array = diamond_points(polygon)
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for corner: Vector2 in polygon: bounds = bounds.expand(corner)
		var focus_index: int = _order[tile]
		for source: Dictionary in sources:
			var category: String = category_for(source)
			# Only sprites painted later than the tile; its own contents stay.
			if category.is_empty() or int(_order.get(source["tile"], -1)) <= focus_index: continue
			if not (source["rect"] as Rect2).intersects(bounds): continue
			var key: String = ""
			if category == "unit":
				var unit: Dictionary = source["data"]
				# Umbra-clipped and burrowed units are never sources (privacy).
				if bool(unit.get("death_animation", false)) or (board.call("_unit_footprint_tiles", unit) as Array).has(tile): continue
				key = str(source["key"])
			var covered: int = 0
			for point: Vector2 in points:
				if Alpha.opaque_at(source, point): covered += 1
			var coverage: float = float(covered) / float(maxi(1, points.size()))
			if coverage < MIN_COVERAGE: continue
			var id: String = target_id(category, key, source["tile"])
			var previous: Dictionary = result.get(id, {})
			result[id] = {"id": id, "category": category, "key": key, "tile": source["tile"], "coverage": maxf(coverage, float(previous.get("coverage", 0.0)))}
	_occluders[tile] = result
	coverage_builds += 1
	return result

func _retarget() -> void:
	_retarget_pending = false
	var wanted: Dictionary = occluders_for(focus_tile)
	# Cross-fade: old occluders return while the new ones fade; shared stay.
	for id: String in targets:
		targets[id]["on"] = wanted.has(id)
	for id: String in wanted:
		if not targets.has(id): targets[id] = (wanted[id] as Dictionary).merged({"on": true, "progress": 0.0})
	set_process(not targets.is_empty())

func _process(delta: float) -> void:
	if _retarget_pending: _retarget()
	var settled: bool = true
	var changed: bool = false
	var finished: Array[String]
	var tiles: Dictionary = {}
	for id: String in targets:
		var target: Dictionary = targets[id]
		var on: bool = bool(target["on"])
		var goal: float = 1.0 if on else 0.0
		var progress: float = move_toward(float(target["progress"]), goal, delta / (FADE_IN if on else FADE_OUT))
		if progress != float(target["progress"]):
			target["progress"] = progress
			_apply(target, tiles)
			changed = true
		if progress != goal: settled = false
		elif not on: finished.append(id)
	for id: String in finished: targets.erase(id)
	for tile: Vector2i in tiles: board.call("_queue_occlusion_reveal_redraw", tile)
	if changed:
		var silhouettes: Node = board.get("_occlusion_silhouettes")
		if is_instance_valid(silhouettes): silhouettes.call("reveal_changed")
	set_process(not settled or _retarget_pending)

func _apply(target: Dictionary, tiles: Dictionary) -> void:
	var alpha: float = lerpf(1.0, REVEAL_ALPHA, float(target["progress"]))
	if str(target["category"]) == "unit":
		var key: String = target["key"]
		if alpha >= 1.0: _unit_alphas.erase(key)
		else: _unit_alphas[key] = alpha
		(board.get("_aim_focus") as RefCounted).call("set_body_alpha", key, alpha)
		return
	if alpha >= 1.0: _prop_alphas.erase(target["id"])
	else: _prop_alphas[target["id"]] = alpha
	tiles[target["tile"]] = true

# Body alpha of a unit (1.0 when not revealed through).
func unit_alpha(key: String) -> float:
	return float(_unit_alphas.get(key, 1.0)) if not _unit_alphas.is_empty() else 1.0

func prop_alpha(category: String, tile: Vector2i) -> float:
	if _prop_alphas.is_empty(): return 1.0
	return float(_prop_alphas.get(target_id(category, "", tile), 1.0))

# A pillar keeps the lower of its own alpha and the reveal on its shaft (its
# cap and foot bands keep their readable floors in _draw_pillar_body). Every
# other occluder takes the reveal as a multiplier.
func tint(category: String, tile: Vector2i, color: Color) -> Color:
	var alpha: float = prop_alpha(category, tile)
	if alpha >= 1.0: return color
	if category == "pillar": color.a = minf(color.a, alpha)
	else: color.a *= alpha
	return color
