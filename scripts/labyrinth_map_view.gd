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
const COMPACT_EDGE_BUFFER: float = 12.0
const EXPANDED_EDGE_BUFFER: float = 44.0
const COMPACT_NODE_MAX_SIZE: float = 32.0
const COMPACT_NODE_MIN_SIZE: float = 20.0
const EXPANDED_NODE_SIZE: float = 84.0
const EXPANDED_RING_SPACING: float = 142.0
const CAMERA_MIN_ZOOM: float = 0.58
const CAMERA_MAX_ZOOM: float = 1.70
const CAMERA_ZOOM_FACTOR: float = 1.12
const TRACKPAD_PAN_SCALE: float = 18.0
const COMPACT_GRAPH_RADIUS: int = 2
const DEPTH_RING_LABEL_SIZE: Vector2 = Vector2(104.0, 20.0)
const LEGEND_GAP: float = 18.0
const LEGEND_WIDTH: float = 296.0
const LEGEND_PADDING: float = 30.0
const LEGEND_ROW_HEIGHT: float = 30.0
const LEGEND_SECTION_GAP: float = 10.0
const LEGEND_SECTION_HEIGHT: float = 25.0
const HOVER_CARD_SIZE: Vector2 = Vector2(282.0, 140.0)
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
const MAP_BACKGROUND_PATH: String = "res://assets/art/backgrounds/map_labyrinth_depths_v1.png"
const MAP_LEGEND_FRAME_PATH: String = "res://assets/art/ui/map_legend_frame_v2.png"
const MAP_DETAIL_FRAME_PATH: String = "res://assets/art/ui/map_detail_frame_v2.png"
const MAP_ROOM_FRAME_PATHS := {
	ROUTE_CURRENT: "res://assets/art/ui/map_room_frame_current_v2.png",
	ROUTE_REACHABLE: "res://assets/art/ui/map_room_frame_reachable_v2.png",
	ROUTE_VISITED: "res://assets/art/ui/map_room_frame_visited_v2.png",
	ROUTE_UNAVAILABLE: "res://assets/art/ui/map_room_frame_blocked_v2.png"
}
const MAP_BACKGROUND_MODULATE: Color = Color(0.84, 0.77, 0.69, 0.88)
const MAP_BACKGROUND_COMPACT_MODULATE: Color = Color(0.70, 0.64, 0.59, 0.72)
const MAP_BACKGROUND_LABYRINTH_CENTER: Vector2 = Vector2(0.397, 0.472)
const MAP_BRASS: Color = Color("b88b4a")
const MAP_PARCHMENT: Color = Color("dbc9a6")
const MAP_PANEL_FILL: Color = Color(0.030, 0.022, 0.020, 0.94)

var run_state: Dictionary = {}
@export var interactive: bool = true:
	set(value):
		if interactive == value:
			return
		interactive = value
		_camera_auto_initialized = false
		_sync_interactivity()
		_rebuild_state_caches()
		queue_redraw()
@export var show_legend: bool = true:
	set(value):
		if show_legend == value:
			return
		show_legend = value
		_invalidate_layout_cache()
		queue_redraw()
@export var draw_background: bool = true:
	set(value):
		if draw_background == value:
			return
		draw_background = value
		queue_redraw()
var _hover_coord: Vector2i = INVALID_COORD
var _room_icon_textures: Dictionary = {}
var _room_frame_textures: Dictionary = {}
var _recovery_marker_texture: Texture2D = null
var _map_background_texture: Texture2D = null
var _legend_frame_texture: Texture2D = null
var _detail_frame_texture: Texture2D = null
var _run_state_signature: String = ""
var _state_cache_valid: bool = false
var _state_cache_revision: int = 0
var _rooms_by_coord: Dictionary = {}
var _drawable_rooms_cache: Array[Dictionary] = []
var _visible_rooms_cache: Array[Dictionary] = []
var _visible_connections_cache: Array[Dictionary] = []
var _compact_focus_coord_set: Dictionary = {}
var _available_move_coords_cache: Array[Vector2i] = []
var _available_move_coord_set: Dictionary = {}
var _coord_bounds_cache: Rect2i = Rect2i(0, 0, 1, 1)
var _legend_entries_cache: Array[Dictionary] = []
var _layout_cache_valid: bool = false
var _layout_cache_size: Vector2 = Vector2(-1.0, -1.0)
var _layout_cache_interactive: bool = true
var _layout_cache_show_legend: bool = true
var _layout_cache_state_revision: int = -1
var _layout_cache_revision: int = 0
var _map_rect_cache: Rect2 = Rect2()
var _legend_rect_cache: Rect2 = Rect2()
var _grid_spacing_cache: float = 22.0
var _base_node_size_cache: float = EXPANDED_NODE_SIZE
var _radial_center_cache: Vector2 = Vector2.ZERO
var _radial_max_radius_cache: float = 1.0
var _depth_ring_count_cache: int = 1
var _depth_ring_step_cache: float = 1.0
var _world_ring_spacing_cache: float = EXPANDED_RING_SPACING
var _max_visible_depth_cache: int = 0
var _world_positions_cache: Dictionary = {}
var _coord_positions_cache: Dictionary = {}
var _background_world_rect_cache: Rect2 = Rect2()
var _available_hit_rects_cache: Array[Dictionary] = []
var _visible_hit_rects_cache: Array[Dictionary] = []
var _visible_node_rects_cache: Array[Dictionary] = []
var _camera_focus_world: Vector2 = Vector2.ZERO
var _camera_zoom: float = 1.0
var _camera_auto_initialized: bool = false
var _pan_pointer_down: bool = false
var _pan_last_position: Vector2 = Vector2.ZERO
var _travel_from_coord: Vector2i = INVALID_COORD
var _travel_to_coord: Vector2i = INVALID_COORD
var _travel_active: bool = false
var _travel_tween: Tween = null
var _travel_visual_cache_valid: bool = false
var _travel_visual_cache_progress: float = -1.0
var _travel_visual_cache_layout_revision: int = -1
var _travel_trace_commands_cache: Array[Dictionary] = []
var _travel_token_commands_cache: Array[Dictionary] = []
var _travel_progress: float = 0.0:
	set(value):
		_travel_progress = clampf(value, 0.0, 1.0)
		_invalidate_travel_visual_cache()
		queue_redraw()

func _ready() -> void:
	clip_contents = true
	_sync_interactivity()

func _sync_interactivity() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120.0, 120.0) if not interactive else Vector2(640.0, 400.0)

func set_run_state(next_state: Dictionary) -> void:
	var next_signature: String = _map_state_signature(next_state)
	if next_signature == _run_state_signature:
		return
	var previous_current: Vector2i = run_state.get("current_room", INVALID_COORD)
	var next_current: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	_run_state_signature = next_signature
	run_state = _compact_map_state(next_state)
	if not _camera_auto_initialized or previous_current != next_current:
		_camera_auto_initialized = false
	_rebuild_state_caches()
	if _hover_coord.x > -900:
		var hovered_room: Dictionary = _room_ref_at(_hover_coord)
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

func _rebuild_state_caches() -> void:
	_state_cache_valid = true
	_state_cache_revision += 1
	_rooms_by_coord.clear()
	_drawable_rooms_cache.clear()
	_visible_rooms_cache.clear()
	_visible_connections_cache.clear()
	_compact_focus_coord_set.clear()
	_available_move_coords_cache.clear()
	_available_move_coord_set.clear()
	var rooms: Dictionary = run_state.get("rooms", {})
	for room_var: Variant in rooms.values():
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_var
		_rooms_by_coord[room.get("coord", Vector2i.ZERO)] = room
		if _room_visible_on_this_map(room):
			_drawable_rooms_cache.append(room)
			_visible_rooms_cache.append(room)
	if _visible_rooms_cache.is_empty():
		_visible_rooms_cache.append({"coord": run_state.get("current_room", Vector2i.ZERO)})
	_rebuild_coord_bounds_cache()
	_rebuild_available_move_cache()
	_rebuild_visible_connection_cache(rooms)
	_rebuild_compact_focus_cache()
	_invalidate_layout_cache()

func _ensure_state_caches() -> void:
	if not _state_cache_valid:
		_rebuild_state_caches()

func _rebuild_coord_bounds_cache() -> void:
	var min_x: int = 0
	var max_x: int = 0
	var min_y: int = 0
	var max_y: int = 0
	for room: Dictionary in _visible_rooms_cache:
		var coord: Vector2i = room.get("coord", Vector2i.ZERO)
		min_x = mini(min_x, coord.x)
		max_x = maxi(max_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_y = maxi(max_y, coord.y)
	_coord_bounds_cache = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _rebuild_available_move_cache() -> void:
	if str(run_state.get("mode", "room")) != "room":
		return
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = _room_ref_at(current)
	var current_depth: int = int(current_room.get("depth", 0))
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var candidate: Vector2i = (connection_var as Dictionary).get("coord", Vector2i(999, 999))
		if _available_move_coord_set.has(candidate):
			continue
		var room: Dictionary = _room_ref_at(candidate)
		if room.is_empty() or not bool(room.get("revealed", false)):
			continue
		if int(room.get("depth", 0)) < current_depth or bool(room.get("sealed", false)):
			continue
		_available_move_coord_set[candidate] = true
		_available_move_coords_cache.append(candidate)

func _rebuild_visible_connection_cache(rooms: Dictionary) -> void:
	var drawn_connections: Dictionary = {}
	for room_key_var: Variant in rooms.keys():
		var room_key: String = str(room_key_var)
		var room: Dictionary = rooms.get(room_key_var, {}) as Dictionary
		if not _room_visible_on_this_map(room):
			continue
		var coord: Vector2i = room.get("coord", Vector2i.ZERO)
		for connection_var: Variant in room.get("connections", []):
			if typeof(connection_var) != TYPE_DICTIONARY:
				continue
			var neighbor: Vector2i = (connection_var as Dictionary).get("coord", Vector2i(999, 999))
			var neighbor_key: String = _room_key(neighbor)
			var pair_key: String = "%s|%s" % [room_key, neighbor_key] if room_key < neighbor_key else "%s|%s" % [neighbor_key, room_key]
			if drawn_connections.has(pair_key):
				continue
			var neighbor_room: Dictionary = _room_ref_at(neighbor)
			if neighbor_room.is_empty() or not _room_visible_on_this_map(neighbor_room):
				continue
			drawn_connections[pair_key] = true
			_visible_connections_cache.append({
				"from": coord,
				"to": neighbor,
				"revealed": bool(room.get("revealed", false)) and bool(neighbor_room.get("revealed", false))
			})

func _rebuild_compact_focus_cache() -> void:
	_compact_focus_coord_set.clear()
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	if _room_ref_at(current).is_empty():
		return
	var frontier: Array[Dictionary] = [{"coord": current, "distance": 0}]
	_compact_focus_coord_set[current] = true
	var cursor: int = 0
	while cursor < frontier.size():
		var entry: Dictionary = frontier[cursor]
		cursor += 1
		var coord: Vector2i = entry.get("coord", current)
		var distance: int = int(entry.get("distance", 0))
		if distance >= COMPACT_GRAPH_RADIUS:
			continue
		var room: Dictionary = _room_ref_at(coord)
		for connection_var: Variant in room.get("connections", []):
			if typeof(connection_var) != TYPE_DICTIONARY:
				continue
			var neighbor: Vector2i = (connection_var as Dictionary).get("coord", INVALID_COORD)
			if neighbor.x <= -900 or _compact_focus_coord_set.has(neighbor):
				continue
			var neighbor_room: Dictionary = _room_ref_at(neighbor)
			if neighbor_room.is_empty() or not _room_visible_on_this_map(neighbor_room):
				continue
			_compact_focus_coord_set[neighbor] = true
			frontier.append({"coord": neighbor, "distance": distance + 1})
	for available_coord: Vector2i in _available_move_coords_cache:
		_compact_focus_coord_set[available_coord] = true

func _invalidate_layout_cache() -> void:
	_layout_cache_valid = false
	_invalidate_travel_visual_cache()

func _ensure_layout_cache() -> void:
	_ensure_state_caches()
	if _layout_cache_valid \
			and _layout_cache_size == size \
			and _layout_cache_interactive == interactive \
			and _layout_cache_show_legend == show_legend \
			and _layout_cache_state_revision == _state_cache_revision:
		return
	_layout_cache_valid = true
	_layout_cache_size = size
	_layout_cache_interactive = interactive
	_layout_cache_show_legend = show_legend
	_layout_cache_state_revision = _state_cache_revision
	_layout_cache_revision += 1
	var padding: float = COMPACT_EDGE_BUFFER if not interactive else EXPANDED_EDGE_BUFFER
	var legend_width: float = LEGEND_WIDTH + LEGEND_GAP if show_legend else 0.0
	_map_rect_cache = Rect2(
		Vector2(padding, padding),
		Vector2(
			maxf(12.0, size.x - padding * 2.0 - legend_width),
			maxf(12.0, size.y - padding * 2.0)
		)
	)
	var room_rows: int = int(ceil(float(_legend_entries_ref().size()) * 0.5))
	var legend_content_height: float = LEGEND_PADDING * 2.0 + LEGEND_SECTION_HEIGHT * 2.0 + LEGEND_ROW_HEIGHT * 2.0 + LEGEND_SECTION_GAP + float(room_rows) * LEGEND_ROW_HEIGHT
	var legend_height: float = maxf(438.0, legend_content_height + 24.0)
	_legend_rect_cache = Rect2(
		Vector2(size.x - padding - LEGEND_WIDTH, padding),
		Vector2(LEGEND_WIDTH, minf(legend_height, maxf(12.0, size.y - padding * 2.0)))
	)
	_max_visible_depth_cache = 0
	for room: Dictionary in _visible_rooms_cache:
		_max_visible_depth_cache = maxi(_max_visible_depth_cache, int(room.get("depth", _coord_depth(room.get("coord", Vector2i.ZERO)))))
	_depth_ring_count_cache = maxi(1, _max_visible_depth_cache)
	_world_ring_spacing_cache = EXPANDED_RING_SPACING
	_world_positions_cache.clear()
	_coord_positions_cache.clear()
	var layout_rooms: Array = _visible_rooms_cache.duplicate()
	layout_rooms.sort_custom(Callable(self, "_radial_room_layout_before"))
	var placed_positions: Array = []
	for room_var: Variant in layout_rooms:
		var room: Dictionary = room_var
		var coord: Vector2i = room.get("coord", Vector2i.ZERO)
		var world_position: Vector2 = _resolved_world_position(room, placed_positions)
		_world_positions_cache[coord] = world_position
		placed_positions.append(world_position)
	var current_coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	if not _world_positions_cache.has(current_coord):
		_world_positions_cache[current_coord] = _world_position_for_room(_room_ref_at(current_coord))
	_background_world_rect_cache = _calculate_background_world_rect()
	if interactive and not _camera_auto_initialized:
		_camera_zoom = 1.0
		_camera_focus_world = _world_positions_cache.get(current_coord, Vector2.ZERO)
		_camera_auto_initialized = true
	elif not interactive:
		_fit_compact_camera()
		_camera_auto_initialized = true
	_clamp_camera_focus()
	_depth_ring_step_cache = _world_ring_spacing_cache * _camera_zoom
	_grid_spacing_cache = _depth_ring_step_cache
	_base_node_size_cache = EXPANDED_NODE_SIZE * _camera_zoom if interactive else clampf(EXPANDED_NODE_SIZE * _camera_zoom, COMPACT_NODE_MIN_SIZE, COMPACT_NODE_MAX_SIZE)
	_radial_max_radius_cache = float(_depth_ring_count_cache) * _depth_ring_step_cache
	_radial_center_cache = _world_to_screen(Vector2.ZERO)
	for coord_var: Variant in _world_positions_cache.keys():
		var cached_coord: Vector2i = coord_var
		_coord_positions_cache[cached_coord] = _world_to_screen(_world_positions_cache.get(cached_coord, Vector2.ZERO))
	_available_hit_rects_cache.clear()
	_visible_hit_rects_cache.clear()
	_visible_node_rects_cache.clear()
	var hit_radius: float = maxf(20.0 if interactive else 8.0, _base_node_size_cache * 0.72)
	for coord: Vector2i in _available_move_coords_cache:
		var center: Vector2 = _cached_coord_position(coord)
		if _room_is_displayed(coord) and _map_rect_cache.grow(-hit_radius * 0.82).has_point(center):
			_available_hit_rects_cache.append({"coord": coord, "rect": Rect2(center - Vector2.ONE * hit_radius, Vector2.ONE * hit_radius * 2.0)})
	var node_half_size: float = _base_node_size_cache * 0.66
	for room: Dictionary in _visible_rooms_cache:
		var coord: Vector2i = room.get("coord", INVALID_COORD)
		if coord.x <= -900:
			continue
		if not _room_is_displayed(coord):
			continue
		var center: Vector2 = _cached_coord_position(coord)
		if not _map_rect_cache.grow(node_half_size * 1.25).has_point(center):
			continue
		_visible_hit_rects_cache.append({"coord": coord, "rect": Rect2(center - Vector2.ONE * hit_radius, Vector2.ONE * hit_radius * 2.0)})
		_visible_node_rects_cache.append({"coord": coord, "rect": Rect2(center - Vector2.ONE * node_half_size, Vector2.ONE * node_half_size * 2.0).grow(6.0)})
	_invalidate_travel_visual_cache()

func _calculate_background_world_rect() -> Rect2:
	var map_radius: float = (float(_depth_ring_count_cache) + 2.20) * _world_ring_spacing_cache
	var minimum_half_height: float = _map_rect_cache.size.y * 0.62 / CAMERA_MIN_ZOOM
	var half_height: float = maxf(map_radius, minimum_half_height)
	var half_width: float = maxf(half_height * 1.7777778, _map_rect_cache.size.x * 0.62 / CAMERA_MIN_ZOOM)
	var world_size := Vector2(half_width * 2.0, half_height * 2.0)
	return Rect2(-world_size * MAP_BACKGROUND_LABYRINTH_CENTER, world_size)

func _fit_compact_camera() -> void:
	var focus_bounds := Rect2()
	var has_focus_room: bool = false
	for coord_var: Variant in _compact_focus_coord_set.keys():
		var coord: Vector2i = coord_var
		if not _world_positions_cache.has(coord):
			continue
		var world_position: Vector2 = _world_positions_cache.get(coord, Vector2.ZERO)
		if not has_focus_room:
			focus_bounds = Rect2(world_position, Vector2.ZERO)
			has_focus_room = true
		else:
			focus_bounds = focus_bounds.expand(world_position)
	if not has_focus_room:
		_camera_focus_world = _world_positions_cache.get(run_state.get("current_room", Vector2i.ZERO), Vector2.ZERO)
		_camera_zoom = 1.0
		return
	focus_bounds = focus_bounds.grow(EXPANDED_NODE_SIZE * 0.70)
	_camera_focus_world = focus_bounds.get_center()
	var fit_x: float = _map_rect_cache.size.x / maxf(1.0, focus_bounds.size.x)
	var fit_y: float = _map_rect_cache.size.y / maxf(1.0, focus_bounds.size.y)
	_camera_zoom = clampf(minf(fit_x, fit_y) * 0.92, 0.18, 0.62)

func _room_is_displayed(coord: Vector2i) -> bool:
	return interactive or _compact_focus_coord_set.has(coord)

func _cached_coord_position(coord: Vector2i) -> Vector2:
	if _coord_positions_cache.has(coord):
		return _coord_positions_cache.get(coord, Vector2.ZERO)
	var room: Dictionary = _room_ref_at(coord)
	if room.is_empty():
		room = {"coord": coord, "depth": _coord_depth(coord)}
	var world_position: Vector2 = _world_position_for_room(room)
	_world_positions_cache[coord] = world_position
	var position: Vector2 = _world_to_screen(world_position)
	_coord_positions_cache[coord] = position
	return position

func _world_position_for_room(room: Dictionary) -> Vector2:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var depth: int = maxi(0, int(room.get("depth", _coord_depth(coord))))
	if depth <= 0 or coord == Vector2i.ZERO:
		return Vector2.ZERO
	var radius_jitter: float = _layout_jitter(coord, 17) * _world_ring_spacing_cache * 0.030
	var radius: float = float(depth) * _world_ring_spacing_cache + radius_jitter
	var angle: float = atan2(float(coord.y), float(coord.x))
	angle += _layout_jitter(coord, 41) * 0.090
	return Vector2(cos(angle), sin(angle)) * radius

func _radial_room_layout_before(a: Dictionary, b: Dictionary) -> bool:
	var a_coord: Vector2i = a.get("coord", Vector2i.ZERO)
	var b_coord: Vector2i = b.get("coord", Vector2i.ZERO)
	var a_depth: int = maxi(0, int(a.get("depth", _coord_depth(a_coord))))
	var b_depth: int = maxi(0, int(b.get("depth", _coord_depth(b_coord))))
	if a_depth != b_depth:
		return a_depth < b_depth
	if a_coord.x != b_coord.x:
		return a_coord.x < b_coord.x
	return a_coord.y < b_coord.y

func _resolved_world_position(room: Dictionary, placed_positions: Array) -> Vector2:
	var desired: Vector2 = _world_position_for_room(room)
	if desired.length() < 1.0 or placed_positions.is_empty():
		return desired
	var desired_radius: float = desired.length()
	var desired_direction: Vector2 = desired.normalized()
	var minimum_clearance: float = EXPANDED_NODE_SIZE * 1.06
	var angular_step: float = clampf(minimum_clearance / maxf(1.0, desired_radius) * 1.08, 0.12, 0.82)
	var radial_offsets: Array = [0.0, -0.035, 0.035, -0.065, 0.065]
	for radial_factor_var: Variant in radial_offsets:
		var candidate_radius: float = maxf(_world_ring_spacing_cache * 0.50, desired_radius + float(radial_factor_var) * _world_ring_spacing_cache)
		for offset_index: int in range(13):
			var signed_index: int = 0
			if offset_index > 0:
				signed_index = int(ceil(float(offset_index) * 0.5)) * (1 if offset_index % 2 == 1 else -1)
			var candidate: Vector2 = desired_direction.rotated(float(signed_index) * angular_step) * candidate_radius
			if _radial_position_is_clear(candidate, placed_positions, minimum_clearance):
				return candidate
	return desired

func _world_to_screen(world_position: Vector2) -> Vector2:
	return _map_rect_cache.get_center() + (world_position - _camera_focus_world) * _camera_zoom

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return _camera_focus_world + (screen_position - _map_rect_cache.get_center()) / maxf(0.01, _camera_zoom)

func _clamp_camera_focus() -> void:
	if not interactive:
		return
	var half_viewport_world: Vector2 = _map_rect_cache.size * 0.5 / maxf(0.01, _camera_zoom)
	var minimum_focus: Vector2 = _background_world_rect_cache.position + half_viewport_world
	var maximum_focus: Vector2 = _background_world_rect_cache.end - half_viewport_world
	if minimum_focus.x > maximum_focus.x:
		_camera_focus_world.x = _background_world_rect_cache.get_center().x
	else:
		_camera_focus_world.x = clampf(_camera_focus_world.x, minimum_focus.x, maximum_focus.x)
	if minimum_focus.y > maximum_focus.y:
		_camera_focus_world.y = _background_world_rect_cache.get_center().y
	else:
		_camera_focus_world.y = clampf(_camera_focus_world.y, minimum_focus.y, maximum_focus.y)

func _radial_position_is_clear(candidate: Vector2, placed_positions: Array, minimum_clearance: float) -> bool:
	for placed_var: Variant in placed_positions:
		var placed: Vector2 = placed_var
		if candidate.distance_to(placed) < minimum_clearance:
			return false
	return true

func _layout_jitter(coord: Vector2i, salt: int) -> float:
	var value: int = posmod(coord.x * 92821 + coord.y * 68917 + salt * 31337, 2001)
	return float(value) / 1000.0 - 1.0

func _coord_depth(coord: Vector2i) -> int:
	return maxi(absi(coord.x), absi(coord.y))

func _invalidate_travel_visual_cache() -> void:
	_travel_visual_cache_valid = false

func center_on_current(reset_zoom: bool = true) -> void:
	if reset_zoom:
		_camera_zoom = 1.0
	_camera_auto_initialized = false
	_invalidate_layout_cache()
	_ensure_layout_cache()
	queue_redraw()

func set_camera_zoom(next_zoom: float, anchor: Vector2 = Vector2.INF) -> void:
	if not interactive:
		return
	_ensure_layout_cache()
	var clamped_zoom: float = clampf(next_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	if is_equal_approx(clamped_zoom, _camera_zoom):
		return
	var zoom_anchor: Vector2 = _map_rect_cache.get_center() if not is_finite(anchor.x) or not is_finite(anchor.y) else anchor
	zoom_anchor.x = clampf(zoom_anchor.x, _map_rect_cache.position.x, _map_rect_cache.end.x)
	zoom_anchor.y = clampf(zoom_anchor.y, _map_rect_cache.position.y, _map_rect_cache.end.y)
	var world_under_anchor: Vector2 = _screen_to_world(zoom_anchor)
	_camera_zoom = clamped_zoom
	_camera_focus_world = world_under_anchor - (zoom_anchor - _map_rect_cache.get_center()) / _camera_zoom
	_clamp_camera_focus()
	_invalidate_layout_cache()
	queue_redraw()

func pan_camera(screen_delta: Vector2) -> void:
	if not interactive or screen_delta.length_squared() <= 0.001:
		return
	_ensure_layout_cache()
	_camera_focus_world -= screen_delta / maxf(0.01, _camera_zoom)
	_clamp_camera_focus()
	_invalidate_layout_cache()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive or run_state.is_empty():
		return
	if event is InputEventMagnifyGesture:
		set_camera_zoom(_camera_zoom * event.factor, event.position)
		accept_event()
		return
	if event is InputEventPanGesture:
		pan_camera(-event.delta * TRACKPAD_PAN_SCALE)
		if _hover_coord != INVALID_COORD:
			_hover_coord = INVALID_COORD
		accept_event()
		return
	if event is InputEventMouseMotion:
		if _pan_pointer_down:
			pan_camera(event.position - _pan_last_position)
			_pan_last_position = event.position
			if _hover_coord != INVALID_COORD:
				_hover_coord = INVALID_COORD
			accept_event()
			return
		var next_hover: Vector2i = _hover_coord_at_point(event.position)
		if next_hover != _hover_coord:
			_hover_coord = next_hover
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_zoom(_camera_zoom * CAMERA_ZOOM_FACTOR, event.position)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_camera_zoom(_camera_zoom / CAMERA_ZOOM_FACTOR, event.position)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_pointer_down = true
			_pan_last_position = event.position
			accept_event()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_pointer_down = false
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var coord: Vector2i = _coord_at_point(event.position)
			if coord.x > -900:
				room_selected.emit(coord)
				accept_event()
			elif _hover_coord_at_point(event.position).x <= -900 and _map_rect_cache.has_point(event.position):
				_pan_pointer_down = true
				_pan_last_position = event.position
				accept_event()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _pan_pointer_down:
			_pan_pointer_down = false
			accept_event()

func cursor_feedback_context_at(local_position: Vector2) -> String:
	if not interactive or run_state.is_empty():
		return "inert"
	if _coord_at_point(local_position).x > -900:
		return "action"
	return "move" if _map_rect_cache.has_point(local_position) else "inert"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("090706"), true)
	if run_state.is_empty():
		return
	_ensure_layout_cache()
	if draw_background:
		_draw_background_layer()
	_draw_depth_rings()
	for connection: Dictionary in _visible_connections_cache:
		_draw_connector(connection.get("from", Vector2i.ZERO), connection.get("to", Vector2i.ZERO), bool(connection.get("revealed", false)))
	for room: Dictionary in _drawable_rooms_cache:
		_draw_room_shell(room)
	_draw_travel_trace()
	for room: Dictionary in _drawable_rooms_cache:
		_draw_room_node(room)
	_draw_travel_token()
	if show_legend:
		_draw_map_legend()
	if interactive:
		_draw_hover_card()

func _draw_background_layer() -> void:
	var texture: Texture2D = _map_background()
	if texture != null and size.x > 0.0 and size.y > 0.0:
		var source_size := Vector2(texture.get_width(), texture.get_height())
		var source_rect := Rect2(Vector2.ZERO, source_size)
		var modulate: Color = MAP_BACKGROUND_MODULATE if interactive else MAP_BACKGROUND_COMPACT_MODULATE
		draw_texture_rect_region(texture, _background_screen_rect(), source_rect, modulate)
	var veil_alpha: float = 0.20 if interactive else 0.34
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.009, 0.008, veil_alpha), true)
	if interactive:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.055, 0.018, 0.026), true)

func _background_screen_rect() -> Rect2:
	var screen_position: Vector2 = _world_to_screen(_background_world_rect_cache.position)
	var screen_end: Vector2 = _world_to_screen(_background_world_rect_cache.end)
	return Rect2(screen_position, screen_end - screen_position)

func _background_labyrinth_center_screen() -> Vector2:
	var screen_rect: Rect2 = _background_screen_rect()
	return screen_rect.position + screen_rect.size * MAP_BACKGROUND_LABYRINTH_CENTER

func _background_world_rect() -> Rect2:
	_ensure_layout_cache()
	return _background_world_rect_cache

func _map_background() -> Texture2D:
	if _map_background_texture == null:
		_map_background_texture = AssetLoader.load_texture(MAP_BACKGROUND_PATH)
	return _map_background_texture

func _draw_depth_rings() -> void:
	if _depth_ring_count_cache <= 0:
		return
	for depth: int in range(1, _depth_ring_count_cache + 1):
		var radius: float = float(depth) * _depth_ring_step_cache
		if not _ring_intersects_map(radius):
			continue
		var point_count: int = clampi(int(radius * 0.22), 80, 240)
		draw_arc(_radial_center_cache, radius, 0.0, TAU, point_count, Color(0.0, 0.0, 0.0, 0.46), 3.2 if interactive else 1.6, true)
		draw_arc(_radial_center_cache, radius, 0.0, TAU, point_count, Color(MAP_BRASS.r, MAP_BRASS.g, MAP_BRASS.b, 0.17 if interactive else 0.12), 1.1 if interactive else 0.7, true)
		if interactive:
			_draw_depth_ring_label(depth, radius)

func _ring_intersects_map(radius: float) -> bool:
	var closest := Vector2(
		clampf(_radial_center_cache.x, _map_rect_cache.position.x, _map_rect_cache.end.x),
		clampf(_radial_center_cache.y, _map_rect_cache.position.y, _map_rect_cache.end.y)
	)
	var minimum_distance: float = _radial_center_cache.distance_to(closest)
	var maximum_distance: float = 0.0
	for corner: Vector2 in [
		_map_rect_cache.position,
		Vector2(_map_rect_cache.end.x, _map_rect_cache.position.y),
		_map_rect_cache.end,
		Vector2(_map_rect_cache.position.x, _map_rect_cache.end.y)
	]:
		maximum_distance = maxf(maximum_distance, _radial_center_cache.distance_to(corner))
	return radius >= minimum_distance - 2.0 and radius <= maximum_distance + 2.0

func _draw_depth_ring_label(depth: int, radius: float) -> void:
	var font: Font = UiTypography.body_font()
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	var label_rect := Rect2()
	var best_score: float = INF
	var angle_seed: float = float(depth) * 0.71
	for sample_index: int in range(96):
		var angle: float = angle_seed + TAU * float(sample_index) / 96.0
		var anchor: Vector2 = _radial_center_cache + Vector2(cos(angle), sin(angle)) * radius
		var candidate := Rect2(anchor - DEPTH_RING_LABEL_SIZE * 0.5, DEPTH_RING_LABEL_SIZE)
		if not _map_rect_cache.grow(-12.0).encloses(candidate):
			continue
		if not _rect_intersects_visible_node(candidate.grow(5.0)):
			var score: float = candidate.position.y + absf(candidate.get_center().x - _map_rect_cache.get_center().x) * 0.06
			if score >= best_score:
				continue
			label_rect = candidate
			best_score = score
	if label_rect.size == Vector2.ZERO:
		return
	var label: String = "DEPTH %d" % depth
	var baseline: Vector2 = label_rect.position + Vector2(0.0, 14.5)
	draw_string(font, baseline + Vector2(1.0, 2.0), label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, UiTypography.scaled_size(self, UiTypography.SIZE_CAPTION), Color(0.0, 0.0, 0.0, 0.88))
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, UiTypography.scaled_size(self, UiTypography.SIZE_CAPTION), Color(MAP_PARCHMENT.r, MAP_PARCHMENT.g, MAP_PARCHMENT.b, 0.62))

func _rect_intersects_visible_node(rect: Rect2) -> bool:
	for node_entry: Dictionary in _visible_node_rects_cache:
		if rect.intersects(node_entry.get("rect", Rect2())):
			return true
	return false

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
	var from_room: Dictionary = _room_ref_at(from_coord)
	var to_room: Dictionary = _room_ref_at(to_coord)
	if from_room.is_empty() or to_room.is_empty():
		return false
	return _room_visible_on_this_map(from_room) and _room_visible_on_this_map(to_room)

func _draw_travel_trace() -> void:
	if not _travel_active:
		return
	_ensure_travel_visual_cache()
	for command_var: Variant in _travel_trace_commands_cache:
		_draw_travel_visual_command(command_var as Dictionary)

func _draw_travel_token() -> void:
	if not _travel_active:
		return
	_ensure_travel_visual_cache()
	for command_var: Variant in _travel_token_commands_cache:
		_draw_travel_visual_command(command_var as Dictionary)

func _travel_visual_commands(layer: String = "") -> Array:
	if not _travel_active:
		return []
	_ensure_travel_visual_cache()
	if layer == "trace":
		return _travel_trace_commands_cache.duplicate(true)
	if layer == "token":
		return _travel_token_commands_cache.duplicate(true)
	var commands: Array = []
	commands.append_array(_travel_trace_commands_cache)
	commands.append_array(_travel_token_commands_cache)
	return commands

func _ensure_travel_visual_cache() -> void:
	_ensure_layout_cache()
	if _travel_visual_cache_valid \
			and is_equal_approx(_travel_visual_cache_progress, _travel_progress) \
			and _travel_visual_cache_layout_revision == _layout_cache_revision:
		return
	_travel_visual_cache_valid = true
	_travel_visual_cache_progress = _travel_progress
	_travel_visual_cache_layout_revision = _layout_cache_revision
	_travel_trace_commands_cache.clear()
	_travel_token_commands_cache.clear()
	var route_points: PackedVector2Array = _route_curve_points(_travel_from_coord, _travel_to_coord)
	if route_points.size() < 2:
		return
	var from_pos: Vector2 = route_points[0]
	var to_pos: Vector2 = route_points[route_points.size() - 1]
	var end_pos: Vector2 = _curve_position_at(route_points, _travel_progress)
	var base_width: float = clampf(_base_node_size() * 0.13, 2.0, 7.0)
	if from_pos.distance_to(end_pos) > 0.5:
		_append_partial_curve_commands(route_points, _travel_progress, Color(0.035, 0.018, 0.004, 0.66), base_width + 5.0)
		_append_partial_curve_commands(route_points, _travel_progress, Color(TRAVEL_TRACE_COLOR.r, TRAVEL_TRACE_COLOR.g, TRAVEL_TRACE_COLOR.b, 0.62), base_width + 1.6)
		_append_partial_curve_commands(route_points, _travel_progress, Color(TRAVEL_TRACE_CORE_COLOR.r, TRAVEL_TRACE_CORE_COLOR.g, TRAVEL_TRACE_CORE_COLOR.b, 0.84), maxf(1.2, base_width * 0.46))
	var hint_radius: float = _base_node_size() * (0.64 + 0.08 * sin(_travel_progress * PI))
	_travel_trace_commands_cache.append({"layer": "trace", "type": "arc", "center": to_pos, "radius": hint_radius, "color": Color(1.0, 0.70, 0.27, 0.18 + 0.30 * _travel_progress), "width": 2.0 if interactive else 1.2})
	var mote_count: int = 5 if interactive else 3
	for index: int in range(mote_count):
		var mote_t: float = clampf(_travel_progress - float(index) * 0.085, 0.0, 1.0)
		if mote_t <= 0.0:
			continue
		var center: Vector2 = _curve_position_at(route_points, mote_t)
		var alpha: float = clampf((1.0 - float(index) * 0.13) * _travel_progress, 0.0, 0.78)
		_travel_trace_commands_cache.append({"layer": "trace", "type": "circle", "center": center, "radius": maxf(1.4, base_width * (0.48 - float(index) * 0.035)), "color": Color(1.0, 0.74, 0.28, alpha)})
	var token_pos: Vector2 = _travel_token_position()
	var token_radius: float = clampf(_base_node_size() * 0.16, 3.0, 9.0)
	var flare: float = sin(_travel_progress * PI)
	_travel_token_commands_cache.append({"layer": "token", "type": "circle", "center": token_pos, "radius": token_radius * 1.95, "color": Color(1.0, 0.34, 0.08, 0.18 + 0.16 * flare)})
	_travel_token_commands_cache.append({"layer": "token", "type": "circle", "center": token_pos, "radius": token_radius * 1.18, "color": Color(TRAVEL_TRACE_COLOR.r, TRAVEL_TRACE_COLOR.g, TRAVEL_TRACE_COLOR.b, 0.88)})
	_travel_token_commands_cache.append({"layer": "token", "type": "circle", "center": token_pos, "radius": token_radius * 0.56, "color": TRAVEL_TOKEN_COLOR})
	var direction: Vector2 = _curve_tangent_at(route_points, _travel_progress)
	if direction.length() > 0.1:
		direction = direction.normalized()
		_travel_token_commands_cache.append({"layer": "token", "type": "line", "from": token_pos - direction * token_radius * 2.3, "to": token_pos - direction * token_radius * 0.8, "color": Color(1.0, 0.54, 0.13, 0.42), "width": maxf(1.2, token_radius * 0.52)})

func _append_partial_curve_commands(points: PackedVector2Array, progress: float, color: Color, width: float) -> void:
	if points.size() < 2 or progress <= 0.0:
		return
	var scaled_progress: float = clampf(progress, 0.0, 1.0) * float(points.size() - 1)
	var whole_segments: int = mini(points.size() - 1, int(floor(scaled_progress)))
	for index: int in range(whole_segments):
		_travel_trace_commands_cache.append({"layer": "trace", "type": "line", "from": points[index], "to": points[index + 1], "color": color, "width": width})
	if whole_segments < points.size() - 1:
		var fraction: float = scaled_progress - float(whole_segments)
		if fraction > 0.001:
			_travel_trace_commands_cache.append({"layer": "trace", "type": "line", "from": points[whole_segments], "to": points[whole_segments].lerp(points[whole_segments + 1], fraction), "color": color, "width": width})

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
	return _curve_position_at(_route_curve_points(_travel_from_coord, _travel_to_coord), _travel_progress)

func _draw_room_shell(room: Dictionary) -> void:
	if not _room_is_onscreen(room):
		return
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var center: Vector2 = _coord_position(coord)
	var route_state: String = _node_route_state(room) if interactive else ROUTE_VISITED
	var node_size: float = _node_size_for_state(route_state)
	_draw_room_frame(center + Vector2(0.0, node_size * 0.075), node_size * 1.13, route_state, Color(0.0, 0.0, 0.0, 0.62 if interactive else 0.44))
	if route_state == ROUTE_REACHABLE:
		_draw_room_frame(center, node_size * 1.18, route_state, Color(1.0, 0.76, 0.39, 0.22))
	elif route_state == ROUTE_CURRENT:
		_draw_room_frame(center, node_size * 1.24, route_state, Color(1.0, 0.73, 0.30, 0.30))

func _draw_room_node(room: Dictionary) -> void:
	if not _room_is_onscreen(room):
		return
	if not interactive:
		_draw_compact_room_node(room)
		return
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var center: Vector2 = _coord_position(coord)
	var route_state: String = _node_route_state(room)
	var node_size: float = _node_size_for_state(route_state)
	var fill: Color = _room_fill_color(room)
	if route_state == ROUTE_UNAVAILABLE:
		fill = fill.lerp(Color("1b1917"), 0.74).darkened(0.10)
	elif route_state == ROUTE_CURRENT:
		fill = fill.lightened(0.08)
	elif coord == _hover_coord:
		fill = fill.lightened(0.14)
	draw_circle(center, node_size * 0.34, Color(0.012, 0.010, 0.009, 0.98))
	draw_circle(center, node_size * 0.30, fill)
	var icon_modulate: Color = _room_icon_modulate(room) if route_state != ROUTE_UNAVAILABLE else Color(0.58, 0.56, 0.53, 0.58)
	_draw_room_icon(room, center, node_size * 0.245, icon_modulate)
	var frame_modulate: Color = Color(1.10, 1.06, 0.98, 1.0) if coord == _hover_coord else Color.WHITE
	_draw_room_frame(center, node_size, route_state, frame_modulate)
	if route_state == ROUTE_VISITED:
		_draw_cleared_badge(center, node_size)
	elif route_state == ROUTE_UNAVAILABLE:
		_draw_blocked_badge(center, node_size)
	if bool(room.get("recovery_marker", false)):
		_draw_recovery_marker_badge(center, node_size)

func _draw_compact_room_node(room: Dictionary) -> void:
	_ensure_state_caches()
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var center: Vector2 = _coord_position(coord)
	var route_state: String = _node_route_state(room)
	var node_size: float = _node_size_for_state(route_state)
	draw_circle(center, node_size * 0.30, _room_fill_color(room))
	_draw_room_icon(room, center, node_size * 0.24, _room_icon_modulate(room))
	_draw_room_frame(center, node_size, route_state, Color.WHITE)
	if bool(room.get("cleared", false)):
		_draw_cleared_badge(center, node_size)

func _node_size_for_state(route_state: String) -> float:
	var node_size: float = _base_node_size()
	if route_state == ROUTE_CURRENT:
		node_size *= 1.12
	elif route_state == ROUTE_REACHABLE:
		node_size *= 1.05
	elif route_state == ROUTE_UNAVAILABLE:
		node_size *= 0.94
	return node_size

func _room_is_onscreen(room: Dictionary) -> bool:
	var coord: Vector2i = room.get("coord", INVALID_COORD)
	if coord.x <= -900:
		return false
	if not _room_is_displayed(coord):
		return false
	return _map_rect_cache.grow(_base_node_size_cache * 0.75).has_point(_coord_position(coord))

func _draw_room_frame(center: Vector2, side: float, route_state: String, modulate: Color) -> void:
	var texture: Texture2D = _room_frame_texture(route_state)
	if texture == null:
		draw_arc(center, side * 0.48, 0.0, TAU, 24, modulate, maxf(1.0, side * 0.035), true)
		return
	var rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	draw_texture_rect(texture, rect, false, modulate)

func _room_frame_texture(route_state: String) -> Texture2D:
	if not _room_frame_textures.has(route_state):
		var path: String = str(MAP_ROOM_FRAME_PATHS.get(route_state, MAP_ROOM_FRAME_PATHS[ROUTE_UNAVAILABLE]))
		_room_frame_textures[route_state] = AssetLoader.load_texture(path)
	return _room_frame_textures.get(route_state, null)

func _draw_blocked_badge(center: Vector2, node_size: float) -> void:
	var radius: float = clampf(node_size * 0.13, 4.0, 7.5)
	var badge_center: Vector2 = center + Vector2(node_size * 0.31, node_size * 0.31)
	draw_circle(badge_center, radius, Color(0.035, 0.030, 0.028, 0.94))
	draw_arc(badge_center, radius, 0.0, TAU, 18, Color(0.62, 0.56, 0.49, 0.72), 1.2, true)
	var inset: float = radius * 0.42
	draw_line(badge_center - Vector2(inset, inset), badge_center + Vector2(inset, inset), Color(0.72, 0.64, 0.55, 0.78), 1.5, true)
	draw_line(badge_center + Vector2(-inset, inset), badge_center + Vector2(inset, -inset), Color(0.72, 0.64, 0.55, 0.78), 1.5, true)

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

func _draw_section_divider(rect: Rect2, y: float) -> void:
	var left: float = rect.position.x + LEGEND_PADDING
	var right: float = rect.end.x - LEGEND_PADDING
	var center_x: float = (left + right) * 0.5
	draw_line(Vector2(left, y), Vector2(center_x - 8.0, y), Color(MAP_BRASS.r, MAP_BRASS.g, MAP_BRASS.b, 0.24), 1.0, true)
	draw_line(Vector2(center_x + 8.0, y), Vector2(right, y), Color(MAP_BRASS.r, MAP_BRASS.g, MAP_BRASS.b, 0.24), 1.0, true)
	var diamond := PackedVector2Array([
		Vector2(center_x, y - 4.0),
		Vector2(center_x + 4.0, y),
		Vector2(center_x, y + 4.0),
		Vector2(center_x - 4.0, y)
	])
	draw_colored_polygon(diamond, Color(MAP_BRASS.r, MAP_BRASS.g, MAP_BRASS.b, 0.58))

func _draw_legend_room_badge(center: Vector2, room: Dictionary, side: float) -> void:
	draw_rect(Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), Color(0.035, 0.025, 0.020, 0.94), true)
	draw_rect(Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), Color(MAP_BRASS.r, MAP_BRASS.g, MAP_BRASS.b, 0.62), false, 1.0)
	_draw_room_icon(room, center, side * 0.34, Color.WHITE)

func _draw_map_legend() -> void:
	var font: Font = UiTypography.body_font()
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	var entries: Array[Dictionary] = _legend_entries_ref()
	if entries.is_empty():
		return
	var legend_rect: Rect2 = _legend_rect()
	draw_rect(legend_rect.grow(-4.0), MAP_PANEL_FILL, true)
	var frame_texture: Texture2D = _map_legend_frame()
	if frame_texture != null:
		draw_texture_rect(frame_texture, legend_rect, false, Color.WHITE)
	var column_width: float = (legend_rect.size.x - LEGEND_PADDING * 2.0) * 0.5
	var label_size: int = UiTypography.scaled_size(self, UiTypography.SIZE_CAPTION)
	var cursor_y: float = legend_rect.position.y + 58.0
	draw_string(font, Vector2(legend_rect.position.x + LEGEND_PADDING, cursor_y + 13.0), "ROUTES", HORIZONTAL_ALIGNMENT_CENTER, legend_rect.size.x - LEGEND_PADDING * 2.0, label_size, Color(0.86, 0.73, 0.52, 0.94))
	cursor_y += LEGEND_SECTION_HEIGHT
	var route_entries: Array = [
		{"label": "Current", "state": ROUTE_CURRENT},
		{"label": "Reachable", "state": ROUTE_REACHABLE},
		{"label": "Visited", "state": ROUTE_VISITED},
		{"label": "Blocked", "state": ROUTE_UNAVAILABLE}
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
	cursor_y += LEGEND_ROW_HEIGHT * 2.0 + LEGEND_SECTION_GAP * 0.5
	_draw_section_divider(legend_rect, cursor_y)
	cursor_y += LEGEND_SECTION_GAP * 0.5
	draw_string(font, Vector2(legend_rect.position.x + LEGEND_PADDING, cursor_y + 13.0), "ROOMS", HORIZONTAL_ALIGNMENT_CENTER, legend_rect.size.x - LEGEND_PADDING * 2.0, label_size, Color(0.86, 0.73, 0.52, 0.94))
	cursor_y += LEGEND_SECTION_HEIGHT
	var icon_side: float = 21.0
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var room: Dictionary = entry.get("room", {})
		var column: int = index % 2
		var row: int = index / 2
		var icon_center := Vector2(
			legend_rect.position.x + LEGEND_PADDING + float(column) * column_width + icon_side * 0.5,
			cursor_y + float(row) * LEGEND_ROW_HEIGHT + icon_side * 0.5
		)
		_draw_legend_room_badge(icon_center, room, icon_side)
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
	_draw_room_frame(center, 19.0, route_state, Color.WHITE)
	if route_state == ROUTE_VISITED:
		draw_line(center + Vector2(-3.5, 0.0), center + Vector2(-1.0, 2.8), CLEARED_BADGE_COLOR, 1.5, true)
		draw_line(center + Vector2(-1.0, 2.8), center + Vector2(4.0, -3.5), CLEARED_BADGE_COLOR, 1.5, true)
	elif route_state == ROUTE_UNAVAILABLE:
		draw_line(center - Vector2(2.5, 2.5), center + Vector2(2.5, 2.5), Color(0.72, 0.65, 0.55, 0.78), 1.2, true)
		draw_line(center + Vector2(-2.5, 2.5), center + Vector2(2.5, -2.5), Color(0.72, 0.65, 0.55, 0.78), 1.2, true)

func _map_legend_frame() -> Texture2D:
	if _legend_frame_texture == null:
		_legend_frame_texture = AssetLoader.load_texture(MAP_LEGEND_FRAME_PATH)
	return _legend_frame_texture

func _map_detail_frame() -> Texture2D:
	if _detail_frame_texture == null:
		_detail_frame_texture = AssetLoader.load_texture(MAP_DETAIL_FRAME_PATH)
	return _detail_frame_texture

func _legend_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _legend_entries_ref():
		entries.append(entry.duplicate(true))
	return entries

func _legend_entries_ref() -> Array[Dictionary]:
	if not _legend_entries_cache.is_empty():
		return _legend_entries_cache
	_legend_entries_cache.append({"label": "Start", "room": {"type": "start", "element": ElementData.NONE}})
	for element_id: String in ElementData.all_elements():
		_legend_entries_cache.append({
			"label": ElementData.name(element_id),
			"room": {"type": "combat", "element": element_id}
		})
	_legend_entries_cache.append({"label": "Campfire", "room": {"type": "campfire", "element": ElementData.NONE}})
	_legend_entries_cache.append({"label": "Relic", "room": {"type": "treasure", "element": ElementData.NONE}})
	_legend_entries_cache.append({"label": "Smith", "room": {"type": "blacksmith", "element": ElementData.NONE}})
	_legend_entries_cache.append({"label": "Arcanist", "room": {"type": "arcanist", "element": ElementData.NONE}})
	_legend_entries_cache.append({"label": "Scavenger", "room": {"type": "scavenger", "element": ElementData.NONE}})
	_legend_entries_cache.append({"label": "Boss", "room": {"type": "boss", "element": ElementData.LIGHTNING}})
	return _legend_entries_cache

func _draw_hover_card() -> void:
	if _hover_coord.x <= -900:
		return
	var room: Dictionary = _room_ref_at(_hover_coord)
	if room.is_empty() or not _room_visible_on_this_map(room):
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var card_data: Dictionary = _hover_card_data(room)
	var rect: Rect2 = _hover_card_rect(_hover_coord)
	var shadow_rect: Rect2 = rect
	shadow_rect.position += Vector2(0.0, 7.0)
	draw_rect(shadow_rect.grow(-3.0), Color(0.0, 0.0, 0.0, 0.58), true)
	draw_rect(rect.grow(-4.0), Color(0.024, 0.018, 0.016, 0.985), true)
	var frame_texture: Texture2D = _map_detail_frame()
	if frame_texture != null:
		draw_texture_rect(frame_texture, rect, false, Color.WHITE)
	var icon_center := rect.position + Vector2(31.0, 31.0)
	_draw_legend_room_badge(icon_center, room, 30.0)
	var text_x: float = rect.position.x + 56.0
	draw_string(font, Vector2(text_x, rect.position.y + 34.0), str(card_data.get("name", "Room")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 74.0, UiTypography.scaled_size(self, UiTypography.SIZE_BODY), Color("fff0ce"))
	_draw_section_divider(rect, rect.position.y + 48.0)
	_draw_hover_card_row(font, rect, 73.0, "TYPE", str(card_data.get("type", "Room")))
	_draw_hover_card_row(font, rect, 98.0, "ELEMENT", str(card_data.get("element", "None")))
	_draw_hover_card_row(font, rect, 123.0, "DEPTH", str(card_data.get("depth", 0)))

func _draw_hover_card_row(font: Font, rect: Rect2, y_offset: float, label: String, value: String) -> void:
	var text_x: float = rect.position.x + 16.0
	draw_string(font, Vector2(text_x, rect.position.y + y_offset), label, HORIZONTAL_ALIGNMENT_LEFT, 70.0, UiTypography.scaled_size(self, UiTypography.SIZE_CAPTION), Color(0.70, 0.62, 0.51, 0.92))
	draw_string(font, Vector2(text_x + 76.0, rect.position.y + y_offset), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 104.0, UiTypography.scaled_size(self, UiTypography.SIZE_CAPTION), Color("d9cbb2"))

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
			return "Emberlit Campfire"
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
		for iteration: int in range(_visible_rooms_cache.size()):
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
	_ensure_layout_cache()
	for node_entry: Dictionary in _visible_node_rects_cache:
		if node_entry.get("coord", INVALID_COORD) == hovered_coord:
			continue
		var node_rect: Rect2 = node_entry.get("rect", Rect2())
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
	_ensure_state_caches()
	var coords: Array[Vector2i] = []
	for coord: Vector2i in _available_move_coords_cache:
		coords.append(coord)
	return coords

func _coord_position(coord: Vector2i) -> Vector2:
	_ensure_layout_cache()
	return _cached_coord_position(coord)

func _coord_at_point(point: Vector2) -> Vector2i:
	_ensure_layout_cache()
	var hit_radius: float = maxf(20.0 if interactive else 8.0, _base_node_size_cache * 0.72)
	var best_coord: Vector2i = INVALID_COORD
	var best_distance: float = INF
	for hit_entry: Dictionary in _available_hit_rects_cache:
		var coord: Vector2i = hit_entry.get("coord", INVALID_COORD)
		var distance: float = point.distance_to(_cached_coord_position(coord))
		if distance <= hit_radius and distance < best_distance:
			best_coord = coord
			best_distance = distance
	return best_coord

func _hover_coord_at_point(point: Vector2) -> Vector2i:
	if not interactive:
		return INVALID_COORD
	_ensure_layout_cache()
	var hit_radius: float = maxf(20.0, _base_node_size_cache * 0.72)
	var best_coord: Vector2i = INVALID_COORD
	var best_distance: float = INF
	for hit_entry: Dictionary in _visible_hit_rects_cache:
		var coord: Vector2i = hit_entry.get("coord", INVALID_COORD)
		var distance: float = point.distance_to(_cached_coord_position(coord))
		if distance <= hit_radius and distance < best_distance:
			best_coord = coord
			best_distance = distance
	return best_coord

func _draw_connector(a: Vector2i, b: Vector2i, revealed: bool = true) -> void:
	if not interactive and (not _compact_focus_coord_set.has(a) or not _compact_focus_coord_set.has(b)):
		return
	var points: PackedVector2Array = _route_curve_points(a, b)
	if points.size() < 2:
		return
	if not _map_rect_cache.grow(16.0).intersects(_curve_bounds(points)):
		return
	if not interactive:
		var compact_route_state: String = _connector_route_state(a, b)
		if compact_route_state == ROUTE_UNAVAILABLE:
			return
		var compact_thickness: float = maxf(1.0, _base_node_size() * 0.13)
		draw_polyline(points, Color(0.025, 0.020, 0.016, 0.66), compact_thickness + 1.4, true)
		var compact_route_color: Color = Color("d4a052") if compact_route_state == ROUTE_REACHABLE else Color("bd8140") if compact_route_state == ROUTE_CURRENT else Color("8b7860")
		draw_polyline(points, compact_route_color if revealed else Color(0.27, 0.23, 0.20, 0.50), compact_thickness, true)
		return
	var route_state: String = _connector_route_state(a, b)
	match route_state:
		ROUTE_REACHABLE:
			draw_polyline(points, Color(0.02, 0.014, 0.008, 0.88), 7.0, true)
			draw_polyline(points, Color("d4a052"), 3.4, true)
			draw_polyline(points, Color(1.0, 0.88, 0.62, 0.84), 1.0, true)
		ROUTE_CURRENT:
			draw_polyline(points, Color(0.02, 0.014, 0.008, 0.82), 5.6, true)
			draw_polyline(points, Color("bd8140"), 2.6, true)
		ROUTE_VISITED:
			draw_polyline(points, Color(0.02, 0.018, 0.016, 0.72), 4.2, true)
			draw_polyline(points, Color(0.48, 0.40, 0.31, 0.78), 1.7, true)
		_:
			_draw_dashed_curve(points, Color(0.39, 0.35, 0.31, 0.56), 1.4)

func _route_curve_points(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var a_pos: Vector2 = _coord_position(a)
	var b_pos: Vector2 = _coord_position(b)
	return _quadratic_route_points(a_pos, b_pos, a, b)

func _quadratic_route_points(from_pos: Vector2, to_pos: Vector2, a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var direction: Vector2 = (to_pos - from_pos).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var bend_seed: float = _layout_jitter(a + b, 89)
	var bend_sign: float = -1.0 if bend_seed < 0.0 else 1.0
	var bend_amount: float = 0.0 if absf(bend_seed) < 0.22 else minf(18.0, from_pos.distance_to(to_pos) * 0.09) * (0.45 + absf(bend_seed) * 0.55)
	var control: Vector2 = from_pos.lerp(to_pos, 0.5) + perpendicular * bend_sign * bend_amount
	var points := PackedVector2Array()
	var sample_count: int = 18 if interactive else 10
	for index: int in range(sample_count + 1):
		var progress: float = float(index) / float(sample_count)
		var inverse: float = 1.0 - progress
		points.append(from_pos * inverse * inverse + control * 2.0 * inverse * progress + to_pos * progress * progress)
	return points

func _curve_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum).grow(2.0)

func _curve_position_at(points: PackedVector2Array, progress: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var scaled: float = clampf(progress, 0.0, 1.0) * float(points.size() - 1)
	var index: int = mini(points.size() - 2, int(floor(scaled)))
	return points[index].lerp(points[index + 1], scaled - float(index))

func _curve_tangent_at(points: PackedVector2Array, progress: float) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var scaled: float = clampf(progress, 0.0, 1.0) * float(points.size() - 1)
	var index: int = mini(points.size() - 2, int(floor(scaled)))
	return points[index + 1] - points[index]

func _draw_dashed_curve(points: PackedVector2Array, color: Color, width: float) -> void:
	for index: int in range(points.size() - 1):
		if index % 3 != 2:
			draw_line(points[index], points[index + 1], color, width, true)

func _node_route_state(room: Dictionary) -> String:
	_ensure_state_caches()
	return _route_state_for_room(room)

func _route_state_for_room(room: Dictionary) -> String:
	var coord: Vector2i = room.get("coord", INVALID_COORD)
	if coord == run_state.get("current_room", Vector2i.ZERO):
		return ROUTE_CURRENT
	if _available_move_coord_set.has(coord):
		return ROUTE_REACHABLE
	if bool(room.get("visited", false)) or bool(room.get("cleared", false)):
		return ROUTE_VISITED
	return ROUTE_UNAVAILABLE

func _connector_route_state(a: Vector2i, b: Vector2i) -> String:
	var a_room: Dictionary = _room_ref_at(a)
	var b_room: Dictionary = _room_ref_at(b)
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

func _room_at(coord: Vector2i) -> Dictionary:
	var room: Dictionary = _room_ref_at(coord)
	if room.is_empty():
		return {}
	return room.duplicate(true)

func _room_ref_at(coord: Vector2i) -> Dictionary:
	_ensure_state_caches()
	if _rooms_by_coord.has(coord):
		return _rooms_by_coord.get(coord, {}) as Dictionary
	return (run_state.get("rooms", {}) as Dictionary).get(_room_key(coord), {}) as Dictionary

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _base_node_size() -> float:
	_ensure_layout_cache()
	return _base_node_size_cache

func _grid_spacing() -> float:
	_ensure_layout_cache()
	return _grid_spacing_cache

func _radial_center() -> Vector2:
	_ensure_layout_cache()
	return _radial_center_cache

func _depth_ring_step() -> float:
	_ensure_layout_cache()
	return _depth_ring_step_cache

func _depth_ring_count() -> int:
	_ensure_layout_cache()
	return _depth_ring_count_cache

func _camera_zoom_value() -> float:
	_ensure_layout_cache()
	return _camera_zoom

func _camera_focus() -> Vector2:
	_ensure_layout_cache()
	return _camera_focus_world

func _world_position(coord: Vector2i) -> Vector2:
	_ensure_layout_cache()
	return _world_positions_cache.get(coord, Vector2.ZERO)

func _coord_bounds() -> Rect2i:
	_ensure_state_caches()
	return _coord_bounds_cache

func _visible_rooms() -> Array[Dictionary]:
	_ensure_state_caches()
	var results: Array[Dictionary] = []
	for room: Dictionary in _visible_rooms_cache:
		results.append(room)
	return results

func _compact_focus_coords() -> Array[Vector2i]:
	_ensure_state_caches()
	var coords: Array[Vector2i] = []
	for coord_var: Variant in _compact_focus_coord_set.keys():
		var coord: Vector2i = coord_var
		coords.append(coord)
	return coords

func _room_visible_on_this_map(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	if bool(room.get("revealed", false)):
		return true
	if room.get("coord", Vector2i.ZERO) == run_state.get("current_room", Vector2i.ZERO):
		return true
	return interactive and bool(room.get("recovery_marker", false))

func _map_rect() -> Rect2:
	_ensure_layout_cache()
	return _map_rect_cache

func _legend_rect() -> Rect2:
	_ensure_layout_cache()
	return _legend_rect_cache

func _legend_content_rect() -> Rect2:
	_ensure_layout_cache()
	return _legend_rect_cache.grow(-LEGEND_PADDING)
