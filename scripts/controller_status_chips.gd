extends VBoxContainer
## A focused actor borrows only the status pills already laid out on the board.

const TileTooltip = preload("res://scripts/board_tile_tooltip.gd")
const FocusTooltip = preload("res://scripts/controller_focus_tooltip.gd")
const LoopContext = preload("res://scripts/tooltip_loop_context.gd")
const MOUSE_TOOLTIP_OFFSET: String = "display/mouse_cursor/tooltip_position_offset"

var _texts := PackedStringArray()
var _terms := PackedStringArray()
var _source: Dictionary = {}

static func attach(cursor: Control) -> VBoxContainer:
	var stack := new()
	stack.name = "ControllerStatusChips"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.z_as_relative = false
	stack.z_index = FocusTooltip.FOCUS_TOOLTIP_Z
	stack.add_theme_constant_override("separation", TileTooltip.PANEL_GAP)
	stack.hide()
	cursor.add_child(stack)
	return stack

func sync(board: Control, tile: Vector2i) -> void:
	var unit: Dictionary = _focused_unit(board, tile)
	if unit.is_empty():
		clear()
		return
	var key: String = unit["key"]
	var layout: Dictionary = board._status_plate_layout.cached_group(key)
	var texts := PackedStringArray()
	var terms := PackedStringArray()
	var anchor := Vector2.ZERO
	# Layout fills each row from left to right before wrapping to the next row.
	for entry: Dictionary in layout.get("statuses", []):
		var tooltip: String = entry["tooltip"]
		if tooltip.is_empty(): continue
		if texts.is_empty(): anchor = (entry["rect"] as Rect2).get_center()
		texts.append(tooltip)
		terms.append(str(entry["icon"]))
	if texts.is_empty():
		clear()
		return
	var source: Dictionary = LoopContext.actor_source(board, key)
	if texts != _texts or terms != _terms or source != _source:
		clear()
		_texts = texts
		_terms = terms
		_source = source
		for index: int in texts.size():
			var panel: Control = board.call("_make_custom_tooltip", texts[index], {"loop_source": source, "loop_term": terms[index]}) as Control
			panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			add_child(panel)
	# Use the same cursor offset as mouse hover at the first chip's centre.
	var viewport_anchor: Vector2 = board.get_global_transform_with_canvas() * anchor
	viewport_anchor += Vector2(ProjectSettings.get_setting(MOUSE_TOOLTIP_OFFSET))
	position = get_parent().get_global_transform_with_canvas().affine_inverse() * viewport_anchor
	show()

func clear() -> void:
	if not visible: return
	hide()
	for panel: Node in get_children():
		remove_child(panel)
		panel.queue_free()
	_texts.clear()
	_terms.clear()
	_source = {}

static func _focused_unit(board: Control, tile: Vector2i) -> Dictionary:
	if tile.x < 0 or not board._tooltips_enabled or not board._board_tile_is_visible_to_player(tile): return {}
	for unit: Dictionary in board._visible_units():
		if unit.get("role") not in ["enemy", "player"] or int(unit.get("hp", 0)) <= 0: continue
		if bool(unit.get("boss_bar", false)) or bool(unit.get("death_animation", false)) or board._unit_is_preview_echo(unit): continue
		if board._unit_footprint_tiles(unit).has(tile) and board._umbra_actor_clip_for_unit(unit).is_empty(): return unit
	return {}
