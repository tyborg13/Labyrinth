extends Control
class_name LabyrinthMapView

const ElementData = preload("res://scripts/element_data.gd")

signal room_selected(coord: Vector2i)

const ROOM_COLORS := {
	"start": Color("d8b96f"),
	"combat": Color("8c7462"),
	"campfire": Color("d9854c"),
	"treasure": Color("89a862"),
	"boss": Color("b75643")
}
const CLEARED_TINT: Color = Color("92b17c")
const UNCLEARED_SHADE: float = 0.10

const LEGEND_ORDER: Array[String] = ["start", "combat", "campfire", "treasure", "boss"]
const LEGEND_LABELS := {
	"start": "Start",
	"combat": "Fight",
	"campfire": "Fire",
	"treasure": "Relic",
	"boss": "Boss"
}

var run_state: Dictionary = {}
@export var interactive: bool = true
@export var show_legend: bool = true
var _hover_coord: Vector2i = Vector2i(-999, -999)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120.0, 120.0) if not interactive else Vector2(820.0, 620.0)

func set_run_state(next_state: Dictionary) -> void:
	run_state = next_state.duplicate(true)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive or run_state.is_empty():
		return
	if event is InputEventMouseMotion:
		_hover_coord = _coord_at_point(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var coord: Vector2i = _coord_at_point(event.position)
		if coord.x > -900:
			room_selected.emit(coord)

func _draw() -> void:
	if interactive:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.05, 0.94), true)
	if run_state.is_empty():
		return
	var rooms: Dictionary = run_state.get("rooms", {})
	var drawn_connections: Dictionary = {}
	for room_key: String in rooms.keys():
		var room: Dictionary = rooms[room_key] as Dictionary
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
			if neighbor_room.is_empty():
				continue
			drawn_connections[pair_key] = true
			_draw_connector(coord, neighbor, bool(room.get("revealed", false)) and bool(neighbor_room.get("revealed", false)))
	for room_key: String in rooms.keys():
		_draw_room_shell(rooms[room_key])
	for room_key: String in rooms.keys():
		var room: Dictionary = rooms[room_key]
		if not bool(room.get("revealed", false)) and room.get("coord", Vector2i.ZERO) != run_state.get("current_room", Vector2i.ZERO):
			continue
		_draw_room_node(room)
	if show_legend:
		_draw_map_legend()

func _draw_room_shell(room: Dictionary) -> void:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var position: Vector2 = _coord_position(coord)
	var node_size: float = _base_node_size() * 0.82
	var rect := Rect2(position - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	draw_rect(rect, Color(0.18, 0.15, 0.13, 0.48), true)
	draw_rect(rect, Color(0.42, 0.35, 0.31, 0.44), false, 1.0)

func _draw_room_node(room: Dictionary) -> void:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var position: Vector2 = _coord_position(coord)
	var accessible: bool = _available_move_coords().has(coord)
	var node_size: float = _base_node_size()
	if coord == current:
		node_size *= 1.22
	elif accessible and interactive:
		node_size *= 1.08
	var room_type: String = str(room.get("type", "combat"))
	var fill: Color = ROOM_COLORS.get(room_type, Color("8c7462"))
	if room_type == "combat":
		fill = ElementData.room_tint(str(room.get("element", ElementData.NONE)))
	if bool(room.get("cleared", false)):
		fill = fill.lerp(CLEARED_TINT, 0.55)
	else:
		fill = fill.darkened(UNCLEARED_SHADE)
	if coord == _hover_coord and accessible:
		fill = fill.lightened(0.22)
	var rect := Rect2(position - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color("f3e6c5"), false, 2.0 if interactive else 1.3)
	if coord == current:
		draw_rect(rect.grow(4.0 if interactive else 2.5), Color("f2c978"), false, 2.0)
	_draw_room_icon(room_type, position, node_size * 0.5, Color("17120d"))

func _draw_room_icon(room_type: String, center: Vector2, radius: float, color: Color) -> void:
	match room_type:
		"start":
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0)
			])
			draw_colored_polygon(diamond, color)
		"campfire":
			var flame := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius * 0.52, 0.0),
				center + Vector2(0.0, radius * 0.95),
				center + Vector2(-radius * 0.52, 0.0)
			])
			draw_colored_polygon(flame, color)
			draw_line(center + Vector2(-radius * 0.7, radius * 0.78), center + Vector2(radius * 0.7, radius * 0.78), color, 2.0, true)
		"treasure":
			var chest_rect := Rect2(center + Vector2(-radius, -radius * 0.15), Vector2(radius * 2.0, radius * 1.1))
			draw_rect(chest_rect, color, false, 2.0)
			draw_line(center + Vector2(-radius, -radius * 0.15), center + Vector2(0.0, -radius * 0.85), color, 2.0, true)
			draw_line(center + Vector2(0.0, -radius * 0.85), center + Vector2(radius, -radius * 0.15), color, 2.0, true)
		"boss":
			draw_line(center + Vector2(-radius, radius * 0.5), center + Vector2(-radius * 0.55, -radius), color, 2.0, true)
			draw_line(center + Vector2(-radius * 0.55, -radius), center + Vector2(0.0, radius * 0.05), color, 2.0, true)
			draw_line(center + Vector2(0.0, radius * 0.05), center + Vector2(radius * 0.55, -radius), color, 2.0, true)
			draw_line(center + Vector2(radius * 0.55, -radius), center + Vector2(radius, radius * 0.5), color, 2.0, true)
			draw_line(center + Vector2(-radius, radius * 0.5), center + Vector2(radius, radius * 0.5), color, 2.0, true)
		_:
			draw_line(center + Vector2(-radius * 0.8, -radius * 0.8), center + Vector2(radius * 0.8, radius * 0.8), color, 2.0, true)
			draw_line(center + Vector2(radius * 0.8, -radius * 0.8), center + Vector2(-radius * 0.8, radius * 0.8), color, 2.0, true)

func _draw_map_legend() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var legend_rect: Rect2 = _legend_rect()
	draw_rect(legend_rect, Color(0.08, 0.06, 0.05, 0.74), true)
	draw_rect(legend_rect, Color(0.93, 0.85, 0.70, 0.36), false, 1.0)
	var current_room: Dictionary = _room_at(run_state.get("current_room", Vector2i.ZERO))
	draw_string(font, legend_rect.position + Vector2(0.0, 10.0), "D %d" % int(current_room.get("depth", 0)), HORIZONTAL_ALIGNMENT_CENTER, legend_rect.size.x, 8, Color("f2e7d4"))
	for index: int in range(LEGEND_ORDER.size()):
		var room_type: String = LEGEND_ORDER[index]
		var icon_center: Vector2 = legend_rect.position + Vector2(12.0, 28.0 + float(index) * 18.0)
		var fill_rect := Rect2(icon_center - Vector2(6.0, 6.0), Vector2(12.0, 12.0))
		draw_rect(fill_rect, ROOM_COLORS.get(room_type, Color("8c7462")), true)
		draw_rect(fill_rect, Color("f3e6c5"), false, 1.0)
		_draw_room_icon(room_type, icon_center, 4.0, Color("17120d"))
		draw_string(
			font,
			icon_center + Vector2(10.0, 4.0),
			str(LEGEND_LABELS.get(room_type, room_type)),
			HORIZONTAL_ALIGNMENT_LEFT,
			legend_rect.size.x - 24.0,
			7,
			Color("d9cbb2")
		)

func _available_move_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
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
	var span_x: int = maxi(1, bounds.size.x)
	var span_y: int = maxi(1, bounds.size.y)
	var x_ratio: float = 0.5 if span_x <= 1 else float(coord.x - bounds.position.x) / float(span_x - 1)
	var y_ratio: float = 0.5 if span_y <= 1 else float(coord.y - bounds.position.y) / float(span_y - 1)
	return Vector2(
		map_rect.position.x + x_ratio * map_rect.size.x,
		map_rect.position.y + y_ratio * map_rect.size.y
	)

func _coord_at_point(point: Vector2) -> Vector2i:
	var hit_radius: float = _base_node_size() * 0.72
	for coord: Vector2i in _available_move_coords():
		var room: Dictionary = _room_at(coord)
		if room.is_empty() or not bool(room.get("revealed", false)):
			continue
		var rect := Rect2(_coord_position(coord) - Vector2.ONE * hit_radius, Vector2.ONE * hit_radius * 2.0)
		if rect.has_point(point):
			return coord
	return Vector2i(-999, -999)

func _draw_connector(a: Vector2i, b: Vector2i, revealed: bool = true) -> void:
	var a_pos: Vector2 = _coord_position(a)
	var b_pos: Vector2 = _coord_position(b)
	var thickness: float = maxf(2.0, _base_node_size() * 0.34)
	draw_line(a_pos, b_pos, Color("7b6a5b") if revealed else Color(0.27, 0.23, 0.20, 0.56), thickness, true)

func _room_at(coord: Vector2i) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {})
	var key: String = _room_key(coord)
	if not rooms.has(key):
		return {}
	return (rooms[key] as Dictionary).duplicate(true)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _base_node_size() -> float:
	var map_rect: Rect2 = _map_rect()
	var bounds: Rect2i = _coord_bounds()
	var span_x: int = maxi(1, bounds.size.x)
	var span_y: int = maxi(1, bounds.size.y)
	var spacing_x: float = map_rect.size.x / float(maxi(1, span_x - 1))
	var spacing_y: float = map_rect.size.y / float(maxi(1, span_y - 1))
	var base: float = minf(spacing_x, spacing_y) * 0.38
	return clampf(base, 8.0 if not interactive else 10.0, 18.0 if not interactive else 22.0)

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
	if min_x == max_x:
		min_x -= 1
		max_x += 1
	if min_y == max_y:
		min_y -= 1
		max_y += 1
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _visible_rooms() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var rooms: Dictionary = run_state.get("rooms", {})
	for room_var: Variant in rooms.values():
		var room: Dictionary = room_var
		if bool(room.get("revealed", false)) or room.get("coord", Vector2i.ZERO) == run_state.get("current_room", Vector2i.ZERO):
			results.append(room)
	if results.is_empty():
		results.append({"coord": run_state.get("current_room", Vector2i.ZERO)})
	return results

func _map_rect() -> Rect2:
	var padding: float = 18.0 if not interactive else 28.0
	var legend_width: float = 82.0 if show_legend else 0.0
	return Rect2(
		Vector2(padding, padding),
		Vector2(
			maxf(12.0, size.x - padding * 2.0 - legend_width),
			maxf(12.0, size.y - padding * 2.0)
		)
	)

func _legend_rect() -> Rect2:
	var padding: float = 18.0 if not interactive else 28.0
	var width: float = 74.0
	return Rect2(
		Vector2(size.x - padding - width, padding),
		Vector2(width, maxf(12.0, size.y - padding * 2.0))
	)
