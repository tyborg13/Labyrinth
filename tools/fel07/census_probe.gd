extends "res://tools/fel06/hover_probe.gd"
## Reuse the census picks and actual GUI hover. Check stack origin from the
## displayed panel metadata when the old rectangle tracer disagrees.

const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const INVALID_TILE := Vector2i(-1, -1)
const WITNESSES := {
	"04-s0-seed8-0--3_2-t5": {"tile": Vector2i(5, 6), "title": "Wooden crate"},
	"12-s1-seed1-1-7_-3-t3": {"tile": Vector2i(7, 5), "title": "item:thunderstone"},
}

var _off_board_regions: Dictionary
var _base_tooltip_script: GDScript
var _capture_bounds: FileAccess


func _initialize() -> void:
	var base_tooltip_path: String = OS.get_environment("FEL07_BASE_TOOLTIP_SCRIPT")
	if not base_tooltip_path.is_empty():
		_base_tooltip_script = GDScript.new()
		_base_tooltip_script.source_code = FileAccess.get_file_as_string(base_tooltip_path)
		if _base_tooltip_script.source_code.is_empty() or _base_tooltip_script.reload() != OK:
			_fail("cannot load the fel-06 tooltip implementation")
			return
	super._initialize()


func _instantiate_run_scene() -> Node:
	var scene: Node = super._instantiate_run_scene()
	if _base_tooltip_script != null:
		scene.get_node("BoardUnderlay/CombatBoard").set_script(_base_tooltip_script)
	return scene


func _fixture(id: String) -> Dictionary:
	_off_board_regions = {}
	var fixture: Dictionary = await super._fixture(id)
	if not fixture.is_empty():
		print("FEL07 OFF-BOARD REGISTRATIONS %s count=%d %s" % [id, _off_board_regions.size(), _off_board_regions.keys()])
	return fixture


func _hover(scene: Node, board: Control, id: String, pick: Dictionary) -> Dictionary:
	var sample: Dictionary = await super._hover(scene, board, id, pick)
	if sample.is_empty(): return sample
	var hover: Dictionary = sample["hover"]
	var tile: Vector2i = pick["tile"]
	if _base_tooltip_script == null and hover["tooltip_tile"] != tile and _displayed_stack_matches_focus(board, tile):
		hover["tooltip_tile"] = tile
		var lob: Dictionary = Evidence.Lob.marks(board).get(tile, {}).get("enemy", {})
		var icefall: Dictionary = Evidence.Icefall.marks(board).get(tile, {})
		hover["lob_tooltip_owner"] = "enemy_%d" % int(lob["id"]) if not lob.is_empty() else ""
		hover["icefall_tooltip_owner"] = "enemy_%d" % int(icefall["id"]) if not icefall.is_empty() else ""
	_record_off_board_regions(board)
	var frame: String = "%s-%s-hover.png" % [id, pick["category"]] if _dry else sample["frame"]
	if not _record_capture_bounds(board, tile, frame):
		return _fail(id + " cannot record the capture bounds")
	if _dry and _base_tooltip_script == null and pick["category"] == "A" and WITNESSES.has(id):
		var problem: String = _witness(board, tile, WITNESSES[id])
		if not problem.is_empty(): return _fail(id + " " + problem)
	return sample


func _record_capture_bounds(board: Control, tile: Vector2i, frame: String) -> bool:
	if _capture_bounds == null:
		_capture_bounds = FileAccess.open(_destination.path_join("pair_bounds.jsonl"), FileAccess.WRITE)
		if _capture_bounds == null: return false
	var polygon: PackedVector2Array = board.call("_tile_polygon", tile)
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var highlight := Rect2(transform * polygon[0], Vector2.ZERO)
	for vertex: Vector2 in polygon:
		highlight = highlight.expand(transform * vertex)
	var popups: Array[Array]
	for popup: Window in _viewport.get_embedded_subwindows():
		if not popup.visible or popup.theme_type_variation != &"TooltipPanel": continue
		var rect := Rect2(Vector2(popup.position), Vector2(popup.size))
		if rect.intersects(_viewport.get_visible_rect()):
			popups.append(_rect_edges(rect))
	return _capture_bounds.store_line(JSON.stringify({
		"frame": frame, "highlight": _rect_edges(highlight), "popups": popups,
	}))


func _rect_edges(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.end.x, rect.end.y]


func _displayed_stack_matches_focus(board: Control, tile: Vector2i) -> bool:
	var expected: Array[Dictionary] = TileTooltip.decode(board.call("controller_tooltip_for_tile", tile))
	if expected.is_empty(): return false
	for popup: Window in _viewport.get_embedded_subwindows():
		if not popup.visible or popup.get_parent() != board: continue
		var stack: Node = popup.get_node_or_null("BoardTileTooltipStack")
		if stack == null or stack.get_child_count() != expected.size(): continue
		var actual: Array[Dictionary]
		for panel: Control in stack.get_children():
			if panel.is_visible_in_tree() and panel.has_meta("tile_tooltip_entry"):
				actual.append(panel.get_meta("tile_tooltip_entry"))
		if actual == expected: return true
	return false


func _record_off_board_regions(board: Control) -> void:
	var rendered: Array[Vector2i] = board.call("_rendered_tiles_in_draw_order")
	var sources: Array = board.call("_retained_render_layers")
	sources.append(board)
	for source: Control in sources:
		for entry: Dictionary in (source.get("_tile_tooltip_regions") as Dictionary).values():
			var tile: Vector2i = entry["tile"]
			if not rendered.has(tile):
				_off_board_regions["%s %s" % [tile, str(entry["tooltip"]).get_slice("\n", 0)]] = true


func _witness(board: Control, behind_tile: Vector2i, witness: Dictionary) -> String:
	var own_tile: Vector2i = witness["tile"]
	var own: Vector2 = board.call("world_position_for_tile", own_tile)
	var behind: Vector2 = board.call("world_position_for_tile", behind_tile)
	var transform: Transform2D = board.get_global_transform_with_canvas()
	if board.call("tile_at_global_position", transform * own) != own_tile:
		return "object center did not pick its own square"
	if board.call("tile_at_global_position", transform * behind) != behind_tile:
		return "overlap did not pick the square behind the object"
	var own_tooltip: String = board.call("_get_tooltip", own)
	var behind_tooltip: String = board.call("_get_tooltip", behind)
	var own_entries: Array[Dictionary] = TileTooltip.decode(own_tooltip)
	var behind_entries: Array[Dictionary] = TileTooltip.decode(behind_tooltip)
	if not own_entries.any(func(entry: Dictionary) -> bool: return entry["title"] == witness["title"]):
		return "own square did not show %s: %s" % [witness["title"], own_tooltip]
	if behind_entries.size() != 1 or behind_entries[0]["title"] != "Fire":
		return "square behind did not show only Fire"
	if own_tooltip != board.call("controller_tooltip_for_tile", own_tile) or behind_tooltip != board.call("controller_tooltip_for_tile", behind_tile):
		return "pointer and board focus returned different stacks"
	var off_board: Vector2 = _off_board_point(board, transform)
	if off_board == Vector2.INF or not str(board.call("_get_tooltip", off_board)).is_empty():
		return "off-board point did not return an empty popup"
	print("FEL07 WITNESS PASS own=%s %s behind=%s Fire off_board=empty focus=equal" % [own_tile, witness["title"], behind_tile])
	return ""


func _off_board_point(board: Control, transform: Transform2D) -> Vector2:
	for y: int in range(1, REST_SEARCH_DIVISIONS):
		for x: int in range(1, REST_SEARCH_DIVISIONS):
			var point: Vector2 = board.size * Vector2(x, y) / float(REST_SEARCH_DIVISIONS)
			if _viewport.get_visible_rect().has_point(transform * point) and board.call("tile_at_global_position", transform * point) == INVALID_TILE:
				return point
	return Vector2.INF
