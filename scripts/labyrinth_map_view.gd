extends Control
class_name LabyrinthMapView

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

signal room_selected(coord: Vector2i)

const ROOM_COLORS := {
	"start": Color("d8b96f"),
	"combat": Color("8c7462"),
	"campfire": Color("d9854c"),
	"treasure": Color("89a862"),
	"boss": Color("b75643"),
	"blacksmith": Color("b06a42"),
	"arcanist": Color("7e65b7"),
	"scavenger": Color("b47a4e")
}
const CLEARED_TINT: Color = Color("5f6462")
const CLEARED_ICON_MODULATE: Color = Color(0.70, 0.73, 0.69, 0.78)
const CLEARED_BADGE_COLOR: Color = Color("d8c79d")
const UNCLEARED_SHADE: float = 0.02
const COMPACT_EDGE_BUFFER: float = 26.0
const EXPANDED_EDGE_BUFFER: float = 44.0
const COMPACT_GRID_SPACING: float = 34.0
const COMPACT_NODE_MAX_SIZE: float = 24.0
const EXPANDED_NODE_MAX_SIZE: float = 72.0
const EXPANDED_NODE_MIN_SIZE: float = 24.0
const EXPANDED_MIN_FIT_SPAN: float = 2.5
const EXPANDED_FIT_RATIO: float = 0.92
const LEGEND_GAP: float = 18.0
const LEGEND_WIDTH: float = 260.0
const LEGEND_PADDING: float = 14.0
const LEGEND_ROW_HEIGHT: float = 28.0
const LEGEND_SECTION_GAP: float = 8.0
const LEGEND_SECTION_HEIGHT: float = 21.0
const HOVER_CARD_SIZE: Vector2 = Vector2(224.0, 116.0)
const HOVER_CARD_GAP: float = 18.0
const HOVER_CARD_EDGE_PADDING: float = 10.0
const INVALID_COORD: Vector2i = Vector2i(-999, -999)
const ROUTE_CURRENT: String = "current"
const ROUTE_REACHABLE: String = "reachable"
const ROUTE_VISITED: String = "visited"
const ROUTE_UNAVAILABLE: String = "unavailable"
const RECOVERY_MARKER_ICON_PATH: String = "res://assets/art/tiles/dropped_embers.png"
const RECOVERY_MARKER_ACCENT: Color = Color("ff9d39")
const TRAVEL_ANIMATION_SECONDS: float = 0.34
const TRAVEL_SETTLE_SECONDS: float = 0.08
const TRAVEL_TRACE_COLOR: Color = Color("ff9d39")
const TRAVEL_TRACE_CORE_COLOR: Color = Color("ffe39a")
const TRAVEL_TOKEN_COLOR: Color = Color("fff0b8")

var run_state: Dictionary = {}
@export var interactive: bool = true
@export var show_legend: bool = true
@export var draw_background: bool = true
var _hover_coord: Vector2i = INVALID_COORD
var _room_icon_textures: Dictionary = {}
var _recovery_marker_texture: Texture2D = null
var _run_state_signature: String = ""
var _travel_from_coord: Vector2i = INVALID_COORD
var _travel_to_coord: Vector2i = INVALID_COORD
var _travel_active: bool = false
var _travel_tween: Tween = null
var _travel_progress: float = 0.0:
	set(value):
		_travel_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120.0, 120.0) if not interactive else Vector2(640.0, 400.0)

func set_run_state(next_state: Dictionary) -> void:
	var next_signature: String = _map_state_signature(next_state)
	if next_signature == _run_state_signature:
		return
	_run_state_signature = next_signature
	run_state = _compact_map_state(next_state)
	if _hover_coord.x > -900:
		var hovered_room: Dictionary = _room_at(_hover_coord)
		if hovered_room.is_empty() or not _room_visible_on_this_map(hovered_room):
			_hover_coord = INVALID_COORD
	queue_redraw()

func _compact_map_state(source_state: Dictionary) -> Dictionary:
	return {
		"mode": str(source_state.get("mode", "room")),
		"current_room": source_state.get("current_room", Vector2i.ZERO),
		"rooms": (source_state.get("rooms", {}) as Dictionary).duplicate(true)
	}

func _map_state_signature(source_state: Dictionary) -> String:
	if source_state.is_empty():
		return ""
	var rooms: Dictionary = source_state.get("rooms", {})
	var keys: Array[String] = []
	for key_var: Variant in rooms.keys():
		keys.append(str(key_var))
	keys.sort()
	var parts: Array[String] = []
	parts.append("mode:%s" % str(source_state.get("mode", "room")))
	parts.append("cur:%s" % _coord_signature(source_state.get("current_room", Vector2i.ZERO)))
	for key: String in keys:
		var room: Dictionary = rooms.get(key, {}) as Dictionary
		parts.append("%s:%s:%s:%s:%d:%d:%d:%d" % [
			key,
			_coord_signature(room.get("coord", Vector2i.ZERO)),
			str(room.get("type", "")),
			str(room.get("element", "")),
			1 if bool(room.get("revealed", false)) else 0,
			1 if bool(room.get("visited", false)) else 0,
			1 if bool(room.get("cleared", false)) else 0,
			1 if bool(room.get("sealed", false)) else 0
		])
		parts.append("known:%s:%s:%d" % [key, str(room.get("name", "")), int(room.get("depth", 0))])
		if bool(room.get("recovery_marker", false)):
			parts.append("recovery:%s:%d" % [key, int(room.get("recovery_amount", 0))])
	return "|".join(parts)

func _coord_signature(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _gui_input(event: InputEvent) -> void:
	if not interactive or run_state.is_empty():
		return
	if event is InputEventMouseMotion:
		var next_hover: Vector2i = _hover_coord_at_point(event.position)
		if next_hover != _hover_coord:
			_hover_coord = next_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var coord: Vector2i = _coord_at_point(event.position)
		if coord.x > -900:
			room_selected.emit(coord)

func _draw() -> void:
	if draw_background:
		if interactive:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.055, 0.045, 0.56), true)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.055, 0.045, 0.58), true)
	if run_state.is_empty():
		return
	var rooms: Dictionary = run_state.get("rooms", {})
	var drawn_connections: Dictionary = {}
	for room_key: String in rooms.keys():
		var room: Dictionary = rooms[room_key] as Dictionary
		if not _room_visible_on_this_map(room):
			continue
		var coord: Vector2i = room.get("coord", Vector2i.ZERO)
		for connection_var: Variant in room.get("connections", []):
			if typeof(connection_var) != TYPE_DICTIONARY:
				continue
			var connection: Dictionary = connection_var
			var neighbor: Vector2i = connection.get("coord", Vector2i(999, 999))
			var neighbor_key: String = _room_key(neighbor)
			var pair_key: String = "%s|%s" % [room_key, neighbor_key] if room_key < neighbor_key else "%s|%s" % [neighbor_key, room_key]
			var neighbor_room: Dictionary = _room_at(neighbor)
			if drawn_connections.has(pair_key):
				continue
			if neighbor_room.is_empty() or not _room_visible_on_this_map(neighbor_room):
				continue
			drawn_connections[pair_key] = true
			_draw_connector(coord, neighbor, bool(room.get("revealed", false)) and bool(neighbor_room.get("revealed", false)))
	for room_key: String in rooms.keys():
		if not _room_visible_on_this_map(rooms[room_key]):
			continue
		_draw_room_shell(rooms[room_key])
	_draw_travel_trace()
	for room_key: String in rooms.keys():
		var room: Dictionary = rooms[room_key]
		if not _room_visible_on_this_map(room):
			continue
		_draw_room_node(room)
	_draw_travel_token()
	if show_legend:
		_draw_map_legend()
	if interactive:
		_draw_hover_card()

func begin_travel_animation(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	clear_travel_animation()
	if not _can_play_travel_animation(from_coord, to_coord):
		return false
	_travel_from_coord = from_coord
	_travel_to_coord = to_coord
	_travel_active = true
	_travel_progress = 0.0
	if is_inside_tree():
		_travel_tween = create_tween()
		_travel_tween.tween_property(self, "_travel_progress", 1.0, TRAVEL_ANIMATION_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_travel_tween.tween_interval(TRAVEL_SETTLE_SECONDS)
		_travel_tween.tween_callback(Callable(self, "_finish_travel_animation"))
	queue_redraw()
	return true

func clear_travel_animation() -> void:
	if _travel_tween != null and _travel_tween.is_valid():
		_travel_tween.kill()
	_travel_tween = null
	_finish_travel_animation()

func travel_animation_seconds() -> float:
	return TRAVEL_ANIMATION_SECONDS + TRAVEL_SETTLE_SECONDS

func _finish_travel_animation() -> void:
	_travel_tween = null
	_travel_active = false
	_travel_from_coord = INVALID_COORD
	_travel_to_coord = INVALID_COORD
	_travel_progress = 0.0
	queue_redraw()

func _can_play_travel_animation(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if run_state.is_empty() or from_coord == to_coord:
		return false
	if from_coord.x <= -900 or to_coord.x <= -900:
		return false
	var from_room: Dictionary = _room_at(from_coord)
	var to_room: Dictionary = _room_at(to_coord)
	if from_room.is_empty() or to_room.is_empty():
		return false
	return _room_visible_on_this_map(from_room) and _room_visible_on_this_map(to_room)

func _draw_travel_trace() -> void:
	for command_var: Variant in _travel_visual_commands("trace"):
		_draw_travel_visual_command(command_var as Dictionary)

func _draw_travel_token() -> void:
	for command_var: Variant in _travel_visual_commands("token"):
		_draw_travel_visual_command(command_var as Dictionary)

func _travel_visual_commands(layer: String = "") -> Array:
	var commands: Array = []
	if not _travel_active:
		return commands
	var from_pos: Vector2 = _coord_position(_travel_from_coord)
	var to_pos: Vector2 = _coord_position(_travel_to_coord)
	var end_pos: Vector2 = from_pos.lerp(to_pos, _travel_progress)
	var base_width: float = clampf(_base_node_size() * 0.13, 2.0, 7.0)
	if from_pos.distance_to(end_pos) > 0.5:
		commands.append({"layer": "trace", "type": "line", "from": from_pos, "to": end_pos, "color": Color(0.035, 0.018, 0.004, 0.66), "width": base_width + 5.0})
		commands.append({"layer": "trace", "type": "line", "from": from_pos, "to": end_pos, "color": Color(TRAVEL_TRACE_COLOR.r, TRAVEL_TRACE_COLOR.g, TRAVEL_TRACE_COLOR.b, 0.62), "width": base_width + 1.6})
		commands.append({"layer": "trace", "type": "line", "from": from_pos, "to": end_pos, "color": Color(TRAVEL_TRACE_CORE_COLOR.r, TRAVEL_TRACE_CORE_COLOR.g, TRAVEL_TRACE_CORE_COLOR.b, 0.84), "width": maxf(1.2, base_width * 0.46)})
	var hint_radius: float = _base_node_size() * (0.64 + 0.08 * sin(_travel_progress * PI))
	commands.append({"layer": "trace", "type": "arc", "center": to_pos, "radius": hint_radius, "color": Color(1.0, 0.70, 0.27, 0.18 + 0.30 * _travel_progress), "width": 2.0 if interactive else 1.2})
	var mote_count: int = 5 if interactive else 3
	for index: int in range(mote_count):
		var mote_t: float = clampf(_travel_progress - float(index) * 0.085, 0.0, 1.0)
		if mote_t <= 0.0:
			continue
		var center: Vector2 = from_pos.lerp(to_pos, mote_t)
		var alpha: float = clampf((1.0 - float(index) * 0.13) * _travel_progress, 0.0, 0.78)
		commands.append({"layer": "trace", "type": "circle", "center": center, "radius": maxf(1.4, base_width * (0.48 - float(index) * 0.035)), "color": Color(1.0, 0.74, 0.28, alpha)})
	var token_pos: Vector2 = _travel_token_position()
	var token_radius: float = clampf(_base_node_size() * 0.16, 3.0, 9.0)
	var flare: float = sin(_travel_progress * PI)
	commands.append({"layer": "token", "type": "circle", "center": token_pos, "radius": token_radius * 1.95, "color": Color(1.0, 0.34, 0.08, 0.18 + 0.16 * flare)})
	commands.append({"layer": "token", "type": "circle", "center": token_pos, "radius": token_radius * 1.18, "color": Color(TRAVEL_TRACE_COLOR.r, TRAVEL_TRACE_COLOR.g, TRAVEL_TRACE_COLOR.b, 0.88)})
	commands.append({"layer": "token", "type": "circle", "center": token_pos, "radius": token_radius * 0.56, "color": TRAVEL_TOKEN_COLOR})
	var direction: Vector2 = to_pos - from_pos
	if direction.length() > 0.1:
		direction = direction.normalized()
		commands.append({"layer": "token", "type": "line", "from": token_pos - direction * token_radius * 2.3, "to": token_pos - direction * token_radius * 0.8, "color": Color(1.0, 0.54, 0.13, 0.42), "width": maxf(1.2, token_radius * 0.52)})
	if layer.is_empty():
		return commands
	var filtered: Array = []
	for command_var: Variant in commands:
		var command: Dictionary = command_var
		if str(command.get("layer", "")) == layer:
			filtered.append(command)
	return filtered

func _draw_travel_visual_command(command: Dictionary) -> void:
	match str(command.get("type", "")):
		"line":
			draw_line(command.get("from", Vector2.ZERO), command.get("to", Vector2.ZERO), command.get("color", Color.WHITE), float(command.get("width", 1.0)), true)
		"arc":
			draw_arc(command.get("center", Vector2.ZERO), float(command.get("radius", 0.0)), 0.0, TAU, 32, command.get("color", Color.WHITE), float(command.get("width", 1.0)), true)
		"circle":
			draw_circle(command.get("center", Vector2.ZERO), float(command.get("radius", 0.0)), command.get("color", Color.WHITE))

func _travel_token_position() -> Vector2:
	if not _travel_active:
		return Vector2.ZERO
	return _coord_position(_travel_from_coord).lerp(_coord_position(_travel_to_coord), _travel_progress)

func _draw_room_shell(room: Dictionary) -> void:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var position: Vector2 = _coord_position(coord)
	var node_size: float = _base_node_size() * 0.92
	var rect := Rect2(position - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	draw_rect(rect.grow(2.0 if interactive else 1.0), Color(0.02, 0.015, 0.012, 0.42), true)
	draw_rect(rect, Color(0.18, 0.15, 0.13, 0.60), true)
	draw_rect(rect, Color(0.42, 0.35, 0.31, 0.54), false, 1.0)

func _draw_room_node(room: Dictionary) -> void:
	if not interactive:
		_draw_compact_room_node(room)
		return
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var position: Vector2 = _coord_position(coord)
	var route_state: String = _node_route_state(room)
	var accessible: bool = route_state == ROUTE_REACHABLE
	var node_size: float = _base_node_size()
	if route_state == ROUTE_CURRENT:
		node_size *= 1.16
	elif route_state == ROUTE_REACHABLE:
		node_size *= 1.08
	elif route_state == ROUTE_UNAVAILABLE:
		node_size *= 0.92
	var fill: Color = _room_fill_color(room)
	if route_state == ROUTE_UNAVAILABLE:
		fill = fill.lerp(Color("302a26"), 0.55)
	elif coord == _hover_coord:
		fill = fill.lightened(0.18)
	var rect := Rect2(position - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.34), true)
	draw_rect(rect, fill, true)
	if route_state == ROUTE_UNAVAILABLE:
		_draw_dashed_rect(rect, Color(0.69, 0.63, 0.55, 0.76), 2.0, 6.0)
		_draw_unavailable_hatch(rect)
	else:
		draw_rect(rect, _room_border_color(room, accessible), false, 2.4)
	if route_state == ROUTE_CURRENT:
		draw_rect(rect.grow(5.0), Color("f2c978"), false, 2.0)
		_draw_corner_brackets(rect.grow(10.0), Color("fff1c8"), 2.2, 12.0)
	elif route_state == ROUTE_REACHABLE:
		draw_rect(rect.grow(4.0), Color("ffe1a3"), false, 1.4)
		_draw_reachable_ticks(rect.grow(8.0), Color("fff1c8"), 2.4, 8.0)
	if coord == _hover_coord:
		draw_rect(rect.grow(7.0), Color(1.0, 0.94, 0.78, 0.72), false, 1.3)
	_draw_room_icon(room, position, node_size * 0.62, _room_icon_modulate(room))
	if route_state == ROUTE_VISITED:
		_draw_cleared_badge(position, node_size)
	if bool(room.get("recovery_marker", false)):
		_draw_recovery_marker_badge(position, node_size)

func _draw_compact_room_node(room: Dictionary) -> void:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var position: Vector2 = _coord_position(coord)
	var accessible: bool = _available_move_coords().has(coord)
	var node_size: float = _base_node_size()
	if coord == current:
		node_size *= 1.22
	var rect := Rect2(position - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.24), true)
	draw_rect(rect, _room_fill_color(room), true)
	draw_rect(rect, _room_border_color(room, accessible), false, 1.6)
	if coord == current:
		draw_rect(rect.grow(2.5), Color("f2c978"), false, 2.0)
	_draw_room_icon(room, position, node_size * 0.62, _room_icon_modulate(room))
	if bool(room.get("cleared", false)):
		_draw_cleared_badge(position, node_size)

func _draw_corner_brackets(rect: Rect2, color: Color, width: float, length: float) -> void:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	for segment: PackedVector2Array in [
		PackedVector2Array([Vector2(left, top + length), Vector2(left, top), Vector2(left + length, top)]),
		PackedVector2Array([Vector2(right - length, top), Vector2(right, top), Vector2(right, top + length)]),
		PackedVector2Array([Vector2(right, bottom - length), Vector2(right, bottom), Vector2(right - length, bottom)]),
		PackedVector2Array([Vector2(left + length, bottom), Vector2(left, bottom), Vector2(left, bottom - length)])
	]:
		draw_polyline(segment, color, width, true)

func _draw_reachable_ticks(rect: Rect2, color: Color, width: float, length: float) -> void:
	var center: Vector2 = rect.get_center()
	draw_line(Vector2(center.x, rect.position.y - length), Vector2(center.x, rect.position.y), color, width, true)
	draw_line(Vector2(center.x, rect.end.y), Vector2(center.x, rect.end.y + length), color, width, true)
	draw_line(Vector2(rect.position.x - length, center.y), Vector2(rect.position.x, center.y), color, width, true)
	draw_line(Vector2(rect.end.x, center.y), Vector2(rect.end.x + length, center.y), color, width, true)

func _draw_unavailable_hatch(rect: Rect2) -> void:
	var color := Color(0.82, 0.76, 0.67, 0.34)
	var start: Vector2 = rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.82)
	for index: int in range(3):
		var offset := Vector2(float(index) * 8.0, 0.0)
		draw_line(start + offset, start + offset + Vector2(12.0, -12.0), color, 1.4, true)

func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash: float) -> void:
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width, dash, true, true)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width, dash, true, true)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width, dash, true, true)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width, dash, true, true)

func _draw_room_icon(room: Dictionary, center: Vector2, radius: float, modulate: Color) -> void:
	var texture: Texture2D = _room_icon_texture_for_room(room)
	if texture != null:
		var icon_size: float = radius * 1.70
		var rect := Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		draw_texture_rect(texture, rect, false, modulate)
		return
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.72),
		center + Vector2(radius * 0.72, 0.0),
		center + Vector2(0.0, radius * 0.72),
		center + Vector2(-radius * 0.72, 0.0)
	])
	draw_colored_polygon(diamond, Color("17120d"))

func _room_fill_color(room: Dictionary) -> Color:
	var room_type: String = str(room.get("type", "combat"))
	var fill: Color = ROOM_COLORS.get(room_type, Color("8c7462"))
	if room_type == "combat":
		fill = ElementData.room_tint(str(room.get("element", ElementData.NONE)))
	if bool(room.get("cleared", false)):
		return fill.lerp(CLEARED_TINT, 0.86).darkened(0.10)
	return fill.darkened(UNCLEARED_SHADE)

func _room_border_color(room: Dictionary, accessible: bool) -> Color:
	if interactive and bool(room.get("recovery_marker", false)):
		return RECOVERY_MARKER_ACCENT.lightened(0.12)
	if bool(room.get("cleared", false)):
		return Color(0.72, 0.70, 0.64, 0.72)
	if accessible and interactive:
		return Color("ffe1a3")
	return Color("f3e6c5")

func _room_icon_modulate(room: Dictionary) -> Color:
	return CLEARED_ICON_MODULATE if bool(room.get("cleared", false)) else Color.WHITE

func _draw_cleared_badge(center: Vector2, node_size: float) -> void:
	var radius: float = clampf(node_size * 0.15, 3.8, 7.8)
	var badge_center: Vector2 = center + Vector2(node_size * 0.30, node_size * 0.30)
	draw_circle(badge_center, radius, Color(0.055, 0.050, 0.045, 0.88))
	draw_arc(badge_center, radius, 0.0, TAU, 18, CLEARED_BADGE_COLOR, 1.2, true)
	var left: Vector2 = badge_center + Vector2(-radius * 0.48, -radius * 0.02)
	var mid: Vector2 = badge_center + Vector2(-radius * 0.14, radius * 0.34)
	var right: Vector2 = badge_center + Vector2(radius * 0.52, -radius * 0.42)
	draw_line(left, mid, CLEARED_BADGE_COLOR, 1.8, true)
	draw_line(mid, right, CLEARED_BADGE_COLOR, 1.8, true)

func _draw_recovery_marker_badge(center: Vector2, node_size: float) -> void:
	var badge_size: float = clampf(node_size * 0.38, 13.0, 24.0)
	var badge_center: Vector2 = center + Vector2(node_size * 0.30, -node_size * 0.30)
	var radius: float = badge_size * 0.56
	draw_circle(badge_center, radius, Color(0.06, 0.035, 0.02, 0.92))
	draw_arc(badge_center, radius, 0.0, TAU, 24, RECOVERY_MARKER_ACCENT, 1.8, true)
	var texture: Texture2D = _recovery_marker_icon_texture()
	if texture != null:
		draw_texture_rect(texture, Rect2(badge_center - Vector2.ONE * badge_size * 0.5, Vector2.ONE * badge_size), false)
		return
	draw_circle(badge_center, badge_size * 0.22, RECOVERY_MARKER_ACCENT)

func _recovery_marker_icon_texture() -> Texture2D:
	if _recovery_marker_texture == null:
		_recovery_marker_texture = AssetLoader.load_texture(RECOVERY_MARKER_ICON_PATH)
	return _recovery_marker_texture

func _room_icon_texture_for_room(room: Dictionary) -> Texture2D:
	var icon_id: String = RoomIcons.icon_id_for_room(room)
	if not _room_icon_textures.has(icon_id):
		_room_icon_textures[icon_id] = RoomIcons.icon_texture(icon_id)
	return _room_icon_textures.get(icon_id, null)

func _draw_map_legend() -> void:
	var font: Font = UiTypography.body_font()
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	var entries: Array[Dictionary] = _legend_entries()
	if entries.is_empty():
		return
	var legend_rect: Rect2 = _legend_rect()
	draw_rect(legend_rect, Color(0.08, 0.06, 0.05, 0.82), true)
	draw_rect(legend_rect, Color(0.93, 0.85, 0.70, 0.36), false, 1.0)
	var column_width: float = (legend_rect.size.x - LEGEND_PADDING * 2.0) * 0.5
	var label_size: int = UiTypography.scaled_size(self, UiTypography.SIZE_CAPTION)
	var cursor_y: float = legend_rect.position.y + LEGEND_PADDING
	draw_string(font, Vector2(legend_rect.position.x + LEGEND_PADDING, cursor_y + 12.0), "ROUTES", HORIZONTAL_ALIGNMENT_LEFT, legend_rect.size.x - LEGEND_PADDING * 2.0, label_size, Color(0.82, 0.72, 0.57, 0.92))
	cursor_y += LEGEND_SECTION_HEIGHT
	var route_entries: Array = [
		{"label": "Current", "state": ROUTE_CURRENT},
		{"label": "Reachable", "state": ROUTE_REACHABLE},
		{"label": "Visited", "state": ROUTE_VISITED},
		{"label": "Unavailable", "state": ROUTE_UNAVAILABLE}
	]
	for index: int in range(route_entries.size()):
		var entry: Dictionary = route_entries[index]
		var column: int = index % 2
		var row: int = index / 2
		var center := Vector2(
			legend_rect.position.x + LEGEND_PADDING + float(column) * column_width + 10.0,
			cursor_y + float(row) * LEGEND_ROW_HEIGHT + 10.0
		)
		_draw_route_state_sample(center, str(entry.get("state", ROUTE_UNAVAILABLE)))
		draw_string(font, center + Vector2(16.0, 5.0), str(entry.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, column_width - 28.0, label_size, Color("d9cbb2"))
	cursor_y += LEGEND_ROW_HEIGHT * 2.0 + LEGEND_SECTION_GAP
	draw_string(font, Vector2(legend_rect.position.x + LEGEND_PADDING, cursor_y + 12.0), "ROOMS", HORIZONTAL_ALIGNMENT_LEFT, legend_rect.size.x - LEGEND_PADDING * 2.0, label_size, Color(0.82, 0.72, 0.57, 0.92))
	cursor_y += LEGEND_SECTION_HEIGHT
	var icon_side: float = 20.0
	var icon_radius: float = 8.0
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var room: Dictionary = entry.get("room", {})
		var column: int = index % 2
		var row: int = index / 2
		var icon_center := Vector2(
			legend_rect.position.x + LEGEND_PADDING + float(column) * column_width + icon_side * 0.5,
			cursor_y + float(row) * LEGEND_ROW_HEIGHT + icon_side * 0.5
		)
		var fill_rect := Rect2(icon_center - Vector2.ONE * icon_side * 0.5, Vector2.ONE * icon_side)
		draw_rect(fill_rect, _room_fill_color(room), true)
		draw_rect(fill_rect, Color("f3e6c5"), false, 1.0)
		_draw_room_icon(room, icon_center, icon_radius, Color.WHITE)
		draw_string(
			font,
			icon_center + Vector2(16.0, 5.0),
			str(entry.get("label", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			column_width - 30.0,
			label_size,
			Color("d9cbb2")
		)

func _draw_route_state_sample(center: Vector2, route_state: String) -> void:
	var rect := Rect2(center - Vector2.ONE * 7.0, Vector2.ONE * 14.0)
	draw_rect(rect, Color(0.21, 0.18, 0.15, 0.94), true)
	match route_state:
		ROUTE_CURRENT:
			draw_rect(rect, Color("f2c978"), false, 1.4)
			draw_rect(rect.grow(2.5), Color("fff1c8"), false, 1.0)
		ROUTE_REACHABLE:
			draw_rect(rect, Color("ffe1a3"), false, 2.0)
			draw_line(Vector2(center.x, rect.position.y - 4.0), Vector2(center.x, rect.position.y), Color("fff1c8"), 1.5, true)
		ROUTE_VISITED:
			draw_rect(rect, Color(0.66, 0.64, 0.59, 0.84), false, 1.0)
			draw_line(center + Vector2(-4.0, 0.0), center + Vector2(-1.0, 3.0), CLEARED_BADGE_COLOR, 1.7, true)
			draw_line(center + Vector2(-1.0, 3.0), center + Vector2(4.0, -4.0), CLEARED_BADGE_COLOR, 1.7, true)
		_:
			_draw_dashed_rect(rect, Color(0.62, 0.57, 0.50, 0.82), 1.0, 4.0)

func _legend_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"label": "Start", "room": {"type": "start", "element": ElementData.NONE}}
	]
	for element_id: String in ElementData.all_elements():
		entries.append({
			"label": ElementData.name(element_id),
			"room": {"type": "combat", "element": element_id}
		})
	entries.append({"label": "Campfire", "room": {"type": "campfire", "element": ElementData.NONE}})
	entries.append({"label": "Relic", "room": {"type": "treasure", "element": ElementData.NONE}})
	entries.append({"label": "Smith", "room": {"type": "blacksmith", "element": ElementData.NONE}})
	entries.append({"label": "Arcanist", "room": {"type": "arcanist", "element": ElementData.NONE}})
	entries.append({"label": "Scavenger", "room": {"type": "scavenger", "element": ElementData.NONE}})
	entries.append({"label": "Boss", "room": {"type": "boss", "element": ElementData.LIGHTNING}})
	return entries

func _draw_hover_card() -> void:
	if _hover_coord.x <= -900:
		return
	var room: Dictionary = _room_at(_hover_coord)
	if room.is_empty() or not _room_visible_on_this_map(room):
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var card_data: Dictionary = _hover_card_data(room)
	var rect: Rect2 = _hover_card_rect(_hover_coord)
	draw_rect(rect.grow(5.0), Color(0.0, 0.0, 0.0, 0.36), true)
	draw_rect(rect, Color(0.075, 0.055, 0.043, 0.97), true)
	draw_rect(rect, Color(0.91, 0.80, 0.62, 0.72), false, 1.4)
	draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), Vector2(4.0, rect.size.y - 2.0)), _room_fill_color(room).lightened(0.18), true)
	var text_x: float = rect.position.x + 16.0
	draw_string(font, Vector2(text_x, rect.position.y + 25.0), str(card_data.get("name", "Room")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 30.0, 15, Color("fff0ce"))
	_draw_hover_card_row(font, rect, 50.0, "TYPE", str(card_data.get("type", "Room")))
	_draw_hover_card_row(font, rect, 73.0, "ELEMENT", str(card_data.get("element", "None")))
	_draw_hover_card_row(font, rect, 96.0, "DEPTH", str(card_data.get("depth", 0)))

func _draw_hover_card_row(font: Font, rect: Rect2, y_offset: float, label: String, value: String) -> void:
	var text_x: float = rect.position.x + 16.0
	draw_string(font, Vector2(text_x, rect.position.y + y_offset), label, HORIZONTAL_ALIGNMENT_LEFT, 66.0, 10, Color(0.70, 0.62, 0.51, 0.92))
	draw_string(font, Vector2(text_x + 70.0, rect.position.y + y_offset), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 100.0, 12, Color("d9cbb2"))

func _hover_card_data(room: Dictionary) -> Dictionary:
	return {
		"name": _room_display_name(room),
		"type": _room_type_label(str(room.get("type", "combat"))),
		"element": ElementData.name(str(room.get("element", ElementData.NONE))) if ElementData.is_elemental(str(room.get("element", ElementData.NONE))) else "None",
		"depth": int(room.get("depth", 0))
	}

func _room_display_name(room: Dictionary) -> String:
	var known_name: String = str(room.get("name", "")).strip_edges()
	if not known_name.is_empty():
		return known_name
	var room_type: String = str(room.get("type", "combat"))
	match room_type:
		"start":
			return "Central Waypoint"
		"campfire":
			return "Ashen Campfire"
		"treasure":
			return "Relic Cache"
		"boss":
			return "Outer Sanctum"
		"blacksmith":
			return "Blacksmith"
		"arcanist":
			return "Arcanist"
		"scavenger":
			return "Scavenger"
		_:
			var element_id: String = str(room.get("element", ElementData.NONE))
			return "%s Chamber" % ElementData.name(element_id) if ElementData.is_elemental(element_id) else "Unknown Chamber"

func _room_type_label(room_type: String) -> String:
	match room_type:
		"start":
			return "Start"
		"combat":
			return "Combat"
		"campfire":
			return "Campfire"
		"treasure":
			return "Relic"
		"boss":
			return "Boss"
		"blacksmith":
			return "Blacksmith"
		"arcanist":
			return "Arcanist"
		"scavenger":
			return "Scavenger"
		_:
			return room_type.capitalize()

func _hover_card_rect(coord: Vector2i) -> Rect2:
	var node_center: Vector2 = _coord_position(coord)
	var node_half_size: float = _base_node_size() * 0.66
	var node_safe_rect := Rect2(node_center - Vector2.ONE * node_half_size, Vector2.ONE * node_half_size * 2.0).grow(HOVER_CARD_GAP)
	var bounds: Rect2 = _hover_card_bounds()
	var candidates: Array = [
		Vector2(node_safe_rect.end.x, node_center.y - HOVER_CARD_SIZE.y * 0.5),
		Vector2(node_safe_rect.position.x - HOVER_CARD_SIZE.x, node_center.y - HOVER_CARD_SIZE.y * 0.5),
		Vector2(node_center.x - HOVER_CARD_SIZE.x * 0.5, node_safe_rect.end.y),
		Vector2(node_center.x - HOVER_CARD_SIZE.x * 0.5, node_safe_rect.position.y - HOVER_CARD_SIZE.y)
	]
	for candidate_index: int in range(candidates.size()):
		var rect := Rect2(candidates[candidate_index], HOVER_CARD_SIZE)
		for iteration: int in range(_visible_rooms().size()):
			var overlap: Rect2 = _hover_card_other_node_overlap(rect, coord)
			if overlap.size == Vector2.ZERO:
				break
			match candidate_index:
				0:
					rect.position.x = overlap.end.x + 6.0
				1:
					rect.position.x = overlap.position.x - HOVER_CARD_SIZE.x - 6.0
				2:
					rect.position.y = overlap.end.y + 6.0
				_:
					rect.position.y = overlap.position.y - HOVER_CARD_SIZE.y - 6.0
		if bounds.encloses(rect) and not rect.intersects(node_safe_rect) and not _hover_card_intersects_other_node(rect, coord):
			return rect
	for candidate: Vector2 in candidates:
		var rect := Rect2(candidate, HOVER_CARD_SIZE)
		if bounds.encloses(rect) and not rect.intersects(node_safe_rect):
			return rect
	var fallback_position := Vector2(
		clampf(candidates[0].x, bounds.position.x, bounds.end.x - HOVER_CARD_SIZE.x),
		clampf(candidates[0].y, bounds.position.y, bounds.end.y - HOVER_CARD_SIZE.y)
	)
	var fallback := Rect2(fallback_position, HOVER_CARD_SIZE)
	if fallback.intersects(node_safe_rect):
		fallback.position.x = clampf(node_safe_rect.position.x - HOVER_CARD_SIZE.x, bounds.position.x, bounds.end.x - HOVER_CARD_SIZE.x)
	return fallback

func _hover_card_intersects_other_node(card_rect: Rect2, hovered_coord: Vector2i) -> bool:
	return _hover_card_other_node_overlap(card_rect, hovered_coord).size != Vector2.ZERO

func _hover_card_other_node_overlap(card_rect: Rect2, hovered_coord: Vector2i) -> Rect2:
	var node_half_size: float = _base_node_size() * 0.66
	for room: Dictionary in _visible_rooms():
		var coord: Vector2i = room.get("coord", INVALID_COORD)
		if coord == hovered_coord or coord.x <= -900:
			continue
		var node_center: Vector2 = _coord_position(coord)
		var node_rect := Rect2(node_center - Vector2.ONE * node_half_size, Vector2.ONE * node_half_size * 2.0).grow(6.0)
		if card_rect.intersects(node_rect):
			return node_rect
	return Rect2()

func _hover_card_bounds() -> Rect2:
	var right_edge: float = size.x - HOVER_CARD_EDGE_PADDING
	if show_legend:
		right_edge = minf(right_edge, _legend_rect().position.x - LEGEND_GAP)
	return Rect2(
		Vector2(HOVER_CARD_EDGE_PADDING, HOVER_CARD_EDGE_PADDING),
		Vector2(
			maxf(HOVER_CARD_SIZE.x, right_edge - HOVER_CARD_EDGE_PADDING),
			maxf(HOVER_CARD_SIZE.y, size.y - HOVER_CARD_EDGE_PADDING * 2.0)
		)
	)

func _available_move_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if str(run_state.get("mode", "room")) != "room":
		return coords
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = _room_at(current)
	var current_depth: int = int(current_room.get("depth", 0))
	var seen: Dictionary = {}
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var candidate: Vector2i = connection.get("coord", Vector2i(999, 999))
		if seen.has(candidate):
			continue
		var room: Dictionary = _room_at(candidate)
		if room.is_empty() or not bool(room.get("revealed", false)):
			continue
		if int(room.get("depth", 0)) < current_depth:
			continue
		if bool(room.get("sealed", false)):
			continue
		seen[candidate] = true
		coords.append(candidate)
	return coords

func _coord_position(coord: Vector2i) -> Vector2:
	var map_rect: Rect2 = _map_rect()
	var bounds: Rect2i = _coord_bounds()
	var bounds_center := Vector2(
		float(bounds.position.x) + float(bounds.size.x - 1) * 0.5,
		float(bounds.position.y) + float(bounds.size.y - 1) * 0.5
	)
	var spacing: float = _grid_spacing()
	var coord_offset := Vector2(float(coord.x), float(coord.y)) - bounds_center
	return map_rect.get_center() + coord_offset * spacing

func _coord_at_point(point: Vector2) -> Vector2i:
	var hit_radius: float = _base_node_size() * 0.72
	for coord: Vector2i in _available_move_coords():
		var room: Dictionary = _room_at(coord)
		if room.is_empty() or not bool(room.get("revealed", false)):
			continue
		var rect := Rect2(_coord_position(coord) - Vector2.ONE * hit_radius, Vector2.ONE * hit_radius * 2.0)
		if rect.has_point(point):
			return coord
	return INVALID_COORD

func _hover_coord_at_point(point: Vector2) -> Vector2i:
	if not interactive:
		return INVALID_COORD
	var hit_radius: float = _base_node_size() * 0.72
	for room: Dictionary in _visible_rooms():
		var coord: Vector2i = room.get("coord", INVALID_COORD)
		if coord.x <= -900:
			continue
		var rect := Rect2(_coord_position(coord) - Vector2.ONE * hit_radius, Vector2.ONE * hit_radius * 2.0)
		if rect.has_point(point):
			return coord
	return INVALID_COORD

func _draw_connector(a: Vector2i, b: Vector2i, revealed: bool = true) -> void:
	var a_pos: Vector2 = _coord_position(a)
	var b_pos: Vector2 = _coord_position(b)
	if not interactive:
		var compact_thickness: float = maxf(3.0, _base_node_size() * 0.28)
		draw_line(a_pos, b_pos, Color(0.025, 0.020, 0.016, 0.58), compact_thickness + 2.0, true)
		draw_line(a_pos, b_pos, Color("9a8062") if revealed else Color(0.27, 0.23, 0.20, 0.56), compact_thickness, true)
		return
	var route_state: String = _connector_route_state(a, b)
	match route_state:
		ROUTE_REACHABLE:
			draw_line(a_pos, b_pos, Color(0.03, 0.02, 0.01, 0.90), 10.0, true)
			draw_line(a_pos, b_pos, Color("d9a955"), 6.0, true)
			draw_line(a_pos, b_pos, Color("ffe4a8"), 1.8, true)
			_draw_route_chevron(a, b, Color("fff1c8"))
		ROUTE_CURRENT:
			draw_line(a_pos, b_pos, Color(0.03, 0.02, 0.01, 0.82), 8.0, true)
			draw_line(a_pos, b_pos, Color("b99663"), 4.0, true)
		ROUTE_VISITED:
			draw_line(a_pos, b_pos, Color(0.03, 0.025, 0.02, 0.68), 5.0, true)
			draw_line(a_pos, b_pos, Color(0.49, 0.47, 0.43, 0.74), 2.4, true)
		_:
			draw_dashed_line(a_pos, b_pos, Color(0.37, 0.33, 0.29, 0.64), 2.2, 10.0, true, true)

func _node_route_state(room: Dictionary) -> String:
	var coord: Vector2i = room.get("coord", INVALID_COORD)
	if coord == run_state.get("current_room", Vector2i.ZERO):
		return ROUTE_CURRENT
	if _available_move_coords().has(coord):
		return ROUTE_REACHABLE
	if bool(room.get("visited", false)) or bool(room.get("cleared", false)):
		return ROUTE_VISITED
	return ROUTE_UNAVAILABLE

func _connector_route_state(a: Vector2i, b: Vector2i) -> String:
	var a_room: Dictionary = _room_at(a)
	var b_room: Dictionary = _room_at(b)
	if a_room.is_empty() or b_room.is_empty():
		return ROUTE_UNAVAILABLE
	var a_state: String = _node_route_state(a_room)
	var b_state: String = _node_route_state(b_room)
	if (a_state == ROUTE_CURRENT and b_state == ROUTE_REACHABLE) or (b_state == ROUTE_CURRENT and a_state == ROUTE_REACHABLE):
		return ROUTE_REACHABLE
	if (a_state == ROUTE_CURRENT and b_state == ROUTE_VISITED) or (b_state == ROUTE_CURRENT and a_state == ROUTE_VISITED):
		return ROUTE_CURRENT
	if a_state == ROUTE_VISITED and b_state == ROUTE_VISITED:
		return ROUTE_VISITED
	return ROUTE_UNAVAILABLE

func _draw_route_chevron(a: Vector2i, b: Vector2i, color: Color) -> void:
	var a_room: Dictionary = _room_at(a)
	var b_room: Dictionary = _room_at(b)
	var from_pos: Vector2 = _coord_position(a)
	var to_pos: Vector2 = _coord_position(b)
	if _node_route_state(a_room) == ROUTE_REACHABLE:
		from_pos = _coord_position(b)
		to_pos = _coord_position(a)
	elif _node_route_state(b_room) != ROUTE_REACHABLE:
		return
	var direction: Vector2 = (to_pos - from_pos).normalized()
	if direction.length_squared() <= 0.01:
		return
	var perpendicular := Vector2(-direction.y, direction.x)
	var tip: Vector2 = from_pos.lerp(to_pos, 0.62)
	var back: Vector2 = tip - direction * 12.0
	draw_line(back + perpendicular * 7.0, tip, color, 2.5, true)
	draw_line(back - perpendicular * 7.0, tip, color, 2.5, true)

func _room_at(coord: Vector2i) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {})
	var key: String = _room_key(coord)
	if not rooms.has(key):
		return {}
	return (rooms[key] as Dictionary).duplicate(true)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _base_node_size() -> float:
	var base: float = _grid_spacing() * 0.56
	return clampf(base, 14.0 if not interactive else EXPANDED_NODE_MIN_SIZE, COMPACT_NODE_MAX_SIZE if not interactive else EXPANDED_NODE_MAX_SIZE)

func _grid_spacing() -> float:
	var map_rect: Rect2 = _map_rect()
	var bounds: Rect2i = _coord_bounds()
	var span_x: int = maxi(0, bounds.size.x - 1)
	var span_y: int = maxi(0, bounds.size.y - 1)
	if not interactive:
		var compact_spacing: float = COMPACT_GRID_SPACING
		if span_x > 0:
			compact_spacing = minf(compact_spacing, map_rect.size.x / float(span_x))
		if span_y > 0:
			compact_spacing = minf(compact_spacing, map_rect.size.y / float(span_y))
		return maxf(12.0, compact_spacing)
	var fit_x: float = map_rect.size.x / maxf(float(span_x), EXPANDED_MIN_FIT_SPAN)
	var fit_y: float = map_rect.size.y / maxf(float(span_y), EXPANDED_MIN_FIT_SPAN)
	return maxf(22.0, minf(fit_x, fit_y) * EXPANDED_FIT_RATIO)

func _coord_bounds() -> Rect2i:
	var rooms: Array[Dictionary] = _visible_rooms()
	var min_x: int = 0
	var max_x: int = 0
	var min_y: int = 0
	var max_y: int = 0
	for room: Dictionary in rooms:
		var coord: Vector2i = room.get("coord", Vector2i.ZERO)
		min_x = mini(min_x, coord.x)
		max_x = maxi(max_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_y = maxi(max_y, coord.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _visible_rooms() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var rooms: Dictionary = run_state.get("rooms", {})
	for room_var: Variant in rooms.values():
		var room: Dictionary = room_var
		if _room_visible_on_this_map(room):
			results.append(room)
	if results.is_empty():
		results.append({"coord": run_state.get("current_room", Vector2i.ZERO)})
	return results

func _room_visible_on_this_map(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	if bool(room.get("revealed", false)):
		return true
	if room.get("coord", Vector2i.ZERO) == run_state.get("current_room", Vector2i.ZERO):
		return true
	return interactive and bool(room.get("recovery_marker", false))

func _map_rect() -> Rect2:
	var padding: float = COMPACT_EDGE_BUFFER if not interactive else EXPANDED_EDGE_BUFFER
	var legend_width: float = LEGEND_WIDTH + LEGEND_GAP if show_legend else 0.0
	return Rect2(
		Vector2(padding, padding),
		Vector2(
			maxf(12.0, size.x - padding * 2.0 - legend_width),
			maxf(12.0, size.y - padding * 2.0)
		)
	)

func _legend_rect() -> Rect2:
	var padding: float = COMPACT_EDGE_BUFFER if not interactive else EXPANDED_EDGE_BUFFER
	var width: float = LEGEND_WIDTH
	var room_rows: int = int(ceil(float(_legend_entries().size()) * 0.5))
	var height: float = LEGEND_PADDING * 2.0 + LEGEND_SECTION_HEIGHT * 2.0 + LEGEND_ROW_HEIGHT * 2.0 + LEGEND_SECTION_GAP + float(room_rows) * LEGEND_ROW_HEIGHT
	return Rect2(
		Vector2(size.x - padding - width, padding),
		Vector2(width, minf(height, maxf(12.0, size.y - padding * 2.0)))
	)
