extends RefCounted
## Score the board's own painter order, rest masks, and visible floor contents.

const Area = preload("res://scripts/boss_area_marks.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const DeathBurst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const ThreatTiles = preload("res://scripts/threat_tiles.gd")
const MIN_UNIT_COVERAGE := 0.25


static func measure(board: Control) -> Dictionary:
	var silhouettes: Node = board.get("_occlusion_silhouettes")
	var reveal: Node = board.get("_occlusion_reveal")
	var sources: Array = silhouettes.current_sources()
	var contents: Dictionary = _contents(board, sources)
	var stacked: int = 0
	var covered: int = 0
	var rows: Array[Dictionary]
	var focus: Dictionary = {}
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if not contents.has(tile): continue
		var things: Array = contents[tile]
		var blockers: Array[Dictionary]
		var fraction: float = 0.0
		for entry: Dictionary in reveal.occluders_for(tile).values():
			blockers.append({"id": entry["id"], "tile": _point(entry["tile"]), "fraction": entry["coverage"]})
			fraction = maxf(fraction, entry["coverage"])
		var is_stacked: bool = things.size() >= 2
		stacked += int(is_stacked)
		covered += int(not blockers.is_empty())
		if not is_stacked and blockers.is_empty(): continue
		var row: Dictionary = {"tile": _point(tile), "contents": things, "occluders": blockers, "stacked": is_stacked}
		rows.append(row)
		if not blockers.is_empty():
			if focus.is_empty() or things.size() > focus["count"] or (things.size() == focus["count"] and fraction > focus["fraction"]):
				focus = {"tile": row["tile"], "count": things.size(), "fraction": fraction}
	var units: Array[Dictionary]
	var masks: RefCounted = silhouettes.get("alpha_masks")
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		if source["kind"] != "unit" or not source.get("eligible", false): continue
		var fraction: float = masks.coverage_for(sources, index)
		if fraction > MIN_UNIT_COVERAGE:
			units.append({"unit": _label(source), "tile": _point(source["data"]["pos"]), "fraction": fraction})
	return {"stacked": stacked, "covered_tiles": covered, "covered_units": units.size(),
		"score": stacked + covered + 2 * units.size(), "tiles": rows, "units": units, "focus": focus}


static func _contents(board: Control, sources: Array) -> Dictionary:
	var result: Dictionary = {}
	var state: Dictionary = board.get("combat_state")
	for source: Dictionary in sources:
		match source["kind"]:
			"unit":
				if not source.get("eligible", false): continue
				for tile: Vector2i in board.call("_unit_footprint_tiles", source["data"]):
					_add(board, result, tile, _label(source))
			"prop":
				if source.get("prop_kind") != "wall":
					_add(board, result, source["tile"], _label(source))
			"terrain":
				_add(board, result, source["tile"], _label(source))
	# The x-ray pass only needs certain loot. Read the floor painter's full roster.
	for loot: Dictionary in state.get("loot", []):
		if not loot.get("claimed", false) and board.call("_loot_texture", loot) != null:
			_add(board, result, loot["pos"], _object_label("loot", loot))
	for trap: Dictionary in state.get("traps", []):
		_add(board, result, trap["pos"], _object_label("trap", trap))
	var surfaces: Dictionary = state.get("surfaces", {})
	var paint_inputs: RefCounted = board.get("_tile_paint_inputs")
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		var surface: Dictionary = surfaces.get(paint_inputs.surface_key(tile), {})
		var elemental: String = Surface.kind(str(surface.get("elemental", "")))
		if not elemental.is_empty(): _add(board, result, tile, "surface " + elemental)
		if surface.get("rubble", false): _add(board, result, tile, "surface rubble")
	_add_telegraphs(board, result, state)
	return result


static func _add_telegraphs(board: Control, contents: Dictionary, state: Dictionary) -> void:
	# A fixed mark has several paint passes. Count it once, even when the
	# floor-threat renderer underlays the same warning with a red diamond.
	var marks: Dictionary = {}
	for mark: Dictionary in state.get("meteor_marks", []):
		_add_area(board, marks, mark.get("tiles", []), "Meteorfall mark")
	for tile: Vector2i in Lob.floor_marks(board):
		_add(board, marks, tile, "Lob telegraph")
	for tile: Vector2i in Icefall.marks(board):
		_add(board, marks, tile, "Icefall telegraph")
	for mark: Dictionary in Burrow.marks(state):
		_add(board, marks, mark["tile"], "Burrow mark %s" % mark["enemy_id"])
	_add_area(board, marks, DeathBurst.focused_tiles(board), "Death Burst telegraph")
	for enemy: Dictionary in state.get("enemies", []):
		if enemy.get("hp", 0) > 0:
			_add_area(board, marks, Area.tiles(state, enemy), "boss area telegraph")
	var floor: Dictionary = board.get("_floor_threat_coverage")
	var rules: Dictionary = floor.get("rules", {})
	for tile: Vector2i in floor.get("alphas", {}):
		if not ThreatTiles.visible_at(board, tile): continue
		if rules.has(tile):
			_record(marks, tile, "battlefield hazard")
		elif not marks.has(tile):
			var owners: Array = floor.get("owners", {}).get(tile, [])
			_record(marks, tile, "floor telegraph [" + ", ".join(owners) + "]")
	var presentation: Dictionary = board.get("presentation")
	for threat: Dictionary in presentation.get("enemy_threat_previews", []):
		_add_area(board, marks, threat.get("projected_attack", []), "intent area %s" % threat.get("enemy_key"))
	for tile: Vector2i in marks:
		for label: String in marks[tile]: _record(contents, tile, label)


static func _add_area(board: Control, contents: Dictionary, tiles: Array, label: String) -> void:
	for tile: Vector2i in tiles: _add(board, contents, tile, label)


static func _add(board: Control, contents: Dictionary, tile: Vector2i, label: String) -> void:
	if not board.call("_board_tile_is_visible_to_player", tile): return
	_record(contents, tile, label)


static func _record(contents: Dictionary, tile: Vector2i, label: String) -> void:
	var things: Array = contents.get_or_add(tile, [])
	if not things.has(label): things.append(label)


static func _label(source: Dictionary) -> String:
	var kind: String = source["kind"]
	if kind == "prop": return str(source.get("prop_kind", "prop"))
	var data: Dictionary = source["data"]
	if kind == "unit": return "%s [%s]" % [data.get("name", data.get("type")), data.get("key")]
	return _object_label(kind, data)


static func _object_label(kind: String, data: Dictionary) -> String:
	var identity: String = str(data.get("element", data.get("kind", "")))
	var id: String = str(data.get("id", ""))
	return "%s %s%s" % [kind, identity, " [" + id + "]" if not id.is_empty() else ""]


static func _point(tile: Vector2i) -> Array:
	return [tile.x, tile.y]
