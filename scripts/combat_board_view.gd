extends Control
class_name CombatBoardView

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")

signal tile_clicked(tile: Vector2i)
signal tile_hovered(tile: Vector2i)
signal cancel_requested

const GRID_OUTLINE: Color = Color("1f1713")
const MOVE_HIGHLIGHT: Color = Color(0.29, 0.82, 0.91, 0.36)
const ATTACK_HIGHLIGHT: Color = Color(0.96, 0.47, 0.27, 0.38)
const HOVER_HIGHLIGHT: Color = Color(1.0, 0.96, 0.82, 0.22)
const SELECT_HIGHLIGHT: Color = Color(0.97, 0.81, 0.43, 0.36)
const EXIT_HIGHLIGHT: Color = Color(0.95, 0.78, 0.31, 0.34)
const FOCUS_HIGHLIGHT: Color = Color(0.99, 0.92, 0.57, 0.24)
const MOVE_PATH_COLOR: Color = Color("80e4f2")
const PLAYER_FOCUS_COLOR: Color = Color("f1d18b")
const ENEMY_FOCUS_COLOR: Color = Color("f08c53")
const PLAYER_BAR_FILL: Color = Color("8ec26c")
const ENEMY_BAR_FILL: Color = Color("d06752")
const STATUS_BURN: Color = Color("f28a42")
const STATUS_FREEZE: Color = Color("7dd4ff")
const STATUS_SHOCK: Color = Color("f3d762")
const STATUS_STUN: Color = Color("82d6c7")
const STATUS_POISON: Color = Color("86bf63")
const PLAYER_HEALTH_BAR_SIZE: Vector2 = Vector2(78.0, 12.0)
const ENEMY_HEALTH_BAR_SIZE: Vector2 = Vector2(84.0, 14.0)
const INTENT_POPUP_WIDTH: float = 136.0
const INTENT_POPUP_PADDING_X: float = 8.0
const INTENT_POPUP_TITLE_FONT_SIZE: int = 9
const INTENT_POPUP_ROW_FONT_SIZE: int = 11
const INTENT_POPUP_ICON_SIZE: float = 16.0
const UNIT_ART_HUD_CLEARANCE: float = 10.0
const HUD_STACK_GAP: float = 0.0
const ENEMY_HUD_VIEWPORT_MARGIN: float = 6.0
const ENEMY_HUD_OFFSET_X_STEPS := [0.0, -24.0, 24.0, -48.0, 48.0, -72.0, 72.0]
const ENEMY_HUD_OFFSET_Y_STEPS := [0.0, -18.0, 18.0, -36.0, 36.0, -54.0, 54.0, -72.0, 72.0]
const FOREGROUND_OBSTRUCTION_TINT: Color = Color(1.0, 1.0, 1.0, 0.54)
const IDLE_FRAME_SECONDS: float = 0.10
const IDLE_SHEET_COLUMNS: int = 4
const IDLE_SHEET_ROWS: int = 2
const IDLE_SHEET_ORDER_ROW_MAJOR: String = "row_major"
const IDLE_SHEET_ORDER_COLUMN_MAJOR: String = "column_major"
const OUTER_WALL_RENDERING_ENABLED: bool = false
const BOARD_SIDE_MARGIN: float = 36.0
const BOARD_VERTICAL_MARGIN: float = 8.0
const BOARD_TOP_CLEARANCE_SCALE: float = 0.74
const BOARD_BOTTOM_CLEARANCE_SCALE: float = 0.30
const BOARD_VERTICAL_BIAS: float = 0.22
const BOARD_MAX_TILE_WIDTH: float = 190.0
const DOOR_FRAME_WIDTH_SCALE: float = 1.4
const DOOR_FRAME_HEIGHT_SCALE: float = 1.7
const DOOR_BASELINE_OFFSET_SCALE: float = 0.425
const DOOR_BACK_EDGE_OFFSET_SCALE: float = 0.5
const DOOR_TOP_BACK_EDGE_OFFSET_SCALE: float = 0.3
const DOOR_ICON_SIZE_SCALE: float = 0.30
const DOOR_ICON_MIN_SIZE: float = 36.0
const DOOR_ICON_MAX_SIZE: float = 52.0
const DOOR_ICON_FLOAT_GAP_SCALE: float = 0.08
const DOOR_OPENING_SHEET_PATH: String = "res://assets/placeholders/tiles/door_opening.png"
const DOOR_OPENING_FRAME_REGIONS := [
	Rect2i(111, 34, 236, 381),
	Rect2i(526, 35, 231, 382),
	Rect2i(912, 35, 231, 382),
	Rect2i(1307, 34, 228, 383),
	Rect2i(109, 461, 231, 382),
	Rect2i(516, 462, 241, 381),
	Rect2i(895, 463, 256, 378),
	Rect2i(1274, 462, 252, 379)
]
const PILLAR_MOSS_OFFSET_X_SCALE: float = -0.04
const PILLAR_MOSS_OFFSET_Y_SCALE: float = 0.16
const ASH_FLOOR_VARIANT_PATHS: PackedStringArray = [
	"res://assets/placeholders/tiles/base_floor_tile_01.png",
	"res://assets/placeholders/tiles/base_floor_tile_02.png",
	"res://assets/placeholders/tiles/base_floor_tile_03.png",
	"res://assets/placeholders/tiles/base_floor_tile_04.png",
	"res://assets/placeholders/tiles/base_floor_tile_05.png",
	"res://assets/placeholders/tiles/base_floor_tile_06.png",
	"res://assets/placeholders/tiles/base_floor_tile_07.png"
]
const MOSS_FLOOR_OVERLAY_PATHS: PackedStringArray = [
	"res://assets/placeholders/tiles/moss_overlays/moss_floor_overlay_01.png",
	"res://assets/placeholders/tiles/moss_overlays/moss_floor_overlay_02.png"
]
const MOSS_WALL_OVERLAY_PATHS: PackedStringArray = [
	"res://assets/placeholders/tiles/moss_overlays/moss_wall_overlay_01.png"
]
const MOSS_PILLAR_OVERLAY_PATHS: PackedStringArray = [
	"res://assets/placeholders/tiles/moss_overlays/moss_pillar_overlay_01.png"
]
const CAMPFIRE_BONFIRE_PATH: String = "res://assets/art/tiles/campfire_bonfire.png"
const CAMPFIRE_BONFIRE_WIDTH_SCALE: float = 1.2925
const CAMPFIRE_BONFIRE_BASELINE_SCALE: float = 0.48
const TRAP_DRAW_WIDTH_SCALE: float = 1.0
const TRAP_DRAW_HEIGHT_SCALE: float = 1.0
const TRAP_DRAW_Y_OFFSET_SCALE: float = 0.0

var combat_state: Dictionary = {}
var move_tiles: Array[Vector2i] = []
var attack_tiles: Array[Vector2i] = []
var selected_tile: Vector2i = Vector2i(-1, -1)
var status_label: String = ""
var status_detail: String = ""
var exit_tiles: Dictionary = {}
var exit_icon_ids: Dictionary = {}
var presentation: Dictionary = {}
var _hover_tile: Vector2i = Vector2i(-1, -1)
var _tile_textures: Dictionary = {}
var _floor_texture_variants: Dictionary = {}
var _floor_variant_by_tile: Dictionary = {}
var _moss_texture_variants: Dictionary = {}
var _moss_tiles_by_surface: Dictionary = {}
var _prop_textures: Dictionary = {}
var _scene_prop_textures: Dictionary = {}
var _loot_textures: Dictionary = {}
var _unit_textures: Dictionary = {}
var _element_textures: Dictionary = {}
var _trap_textures: Dictionary = {}
var _door_icon_textures: Dictionary = {}
var _keyword_icon_textures: Dictionary = {}
var _door_opening_frames: Array[Texture2D] = []
var _door_opening_flipped_frames: Array[Texture2D] = []
var _tooltip_regions: Array[Dictionary] = []
var _idle_frames_by_type: Dictionary = {}
var _idle_animating: bool = false
var _idle_elapsed: float = 0.0
var _idle_tick: int = 0
var _board_layout_cache_valid: bool = false
var _board_layout_cache_size: Vector2 = Vector2(-1.0, -1.0)
var _board_layout_cache_tiles: Array[Vector2i] = []
var _board_layout_cache_extents: Dictionary = {}
var _board_layout_cache_tile_width: float = 90.0
var _board_layout_cache_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(960.0, 680.0)
	set_process(true)
	_load_assets()

func _process(delta: float) -> void:
	var animating: bool = _any_idle_animation_active()
	if animating != _idle_animating:
		_idle_animating = animating
		_idle_elapsed = 0.0
		_idle_tick = 0
		queue_redraw()
	if not animating or _idle_frames_by_type.is_empty():
		return
	var tick_seconds: float = _active_idle_frame_seconds()
	_idle_elapsed = wrapf(_idle_elapsed + delta, 0.0, tick_seconds * 1024.0)
	var next_tick: int = int(floor(_idle_elapsed / tick_seconds))
	if next_tick != _idle_tick:
		_idle_tick = next_tick
		queue_redraw()

func _any_idle_animation_active() -> bool:
	if not visible or combat_state.is_empty() or _idle_frames_by_type.is_empty():
		return false
	for unit: Dictionary in _visible_units():
		if str(unit.get("role", "")) != "npc" and int(unit.get("hp", 0)) <= 0:
			continue
		if _unit_idle_animation_active(unit):
			return true
	return false

func set_combat_state(next_state: Dictionary, next_move_tiles: Array = [], next_attack_tiles: Array = [], next_selected_tile: Vector2i = Vector2i(-1, -1), next_status_label: String = "", next_status_detail: String = "", next_exit_tiles: Dictionary = {}, next_exit_icon_ids: Dictionary = {}, next_presentation: Dictionary = {}) -> void:
	combat_state = next_state.duplicate(true)
	move_tiles = _vector2i_array(next_move_tiles)
	attack_tiles = _vector2i_array(next_attack_tiles)
	selected_tile = next_selected_tile
	status_label = next_status_label
	status_detail = next_status_detail
	exit_tiles = next_exit_tiles.duplicate(true)
	exit_icon_ids = next_exit_icon_ids.duplicate(true)
	presentation = next_presentation.duplicate(true)
	_invalidate_board_layout_cache()
	_floor_variant_by_tile = _build_floor_variant_lookup(combat_state.get("grid", []))
	_moss_tiles_by_surface = _build_moss_tile_lookup(combat_state.get("moss", {}))
	_update_cursor_shape()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover: Vector2i = _tile_at_point(event.position)
		if next_hover != _hover_tile:
			_hover_tile = next_hover
			tile_hovered.emit(_hover_tile)
			_update_cursor_shape()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked: Vector2i = _tile_at_point(event.position)
		if clicked.x >= 0:
			tile_clicked.emit(clicked)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_requested.emit()

func _get_tooltip(at_position: Vector2) -> String:
	for index: int in range(_tooltip_regions.size() - 1, -1, -1):
		var region: Dictionary = _tooltip_regions[index]
		var rect: Rect2 = region.get("rect", Rect2())
		if rect.has_point(at_position):
			return str(region.get("tooltip", ""))
	return ""

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges().is_empty():
		return null
	return UiTooltipPanel.make_text(for_text)

func _draw() -> void:
	_tooltip_regions.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color("18120f"), true)
	if combat_state.is_empty():
		_draw_empty_state()
		return
	var grid: Array = combat_state.get("grid", [])
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	for tile: Vector2i in tiles:
		_draw_floor_tile(grid, tile)
	for tile: Vector2i in tiles:
		_draw_tile_overlays(tile)
	_draw_path_preview()
	var units_to_draw: Array[Dictionary] = _visible_units()
	_draw_scene_objects(grid, tiles, units_to_draw)
	_draw_unit_huds(units_to_draw)
	_draw_effect_overlay()
	_draw_status_text()
	_draw_floating_texts()

func _draw_empty_state() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(34, 52), "No active combat.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("f0e5cf"))

func _draw_floor_moss_overlay(tile: Vector2i) -> void:
	if not _tile_has_moss("floor", tile):
		return
	var texture: Texture2D = _moss_texture_for_surface("floor", tile)
	if texture == null:
		return
	var rect := Rect2(
		_tile_center(tile) - Vector2(_tile_width() * 0.5, _tile_height() * 0.5),
		Vector2(_tile_width(), _tile_height())
	)
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.94))

func _draw_floor_tile(grid: Array, tile: Vector2i) -> void:
	var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
	var polygon: PackedVector2Array = _tile_polygon(tile)
	var base_color: Color = _tile_color(tile_id)
	draw_colored_polygon(polygon, base_color)
	var texture: Texture2D = _floor_texture_for_tile(tile_id, tile)
	if texture != null:
		var tile_width: float = _tile_width()
		var tile_height: float = _tile_height()
		var rect := Rect2(_tile_center(tile) - Vector2(tile_width * 0.5, tile_height * 0.5), Vector2(tile_width, tile_height))
		draw_texture_rect(texture, rect, false)
	_draw_floor_moss_overlay(tile)
	draw_polyline(polygon, GRID_OUTLINE, 2.0, true)

func _draw_tile_overlays(tile: Vector2i) -> void:
	var polygon: PackedVector2Array = _tile_polygon(tile)
	if exit_tiles.has(tile):
		draw_colored_polygon(polygon, EXIT_HIGHLIGHT)
	for focus_tile_var: Variant in presentation.get("focus_tiles", []):
		if focus_tile_var == tile:
			draw_colored_polygon(polygon, presentation.get("focus_color", FOCUS_HIGHLIGHT))
	if move_tiles.has(tile):
		draw_colored_polygon(polygon, MOVE_HIGHLIGHT)
	if attack_tiles.has(tile):
		draw_colored_polygon(polygon, ATTACK_HIGHLIGHT)
	if tile == selected_tile:
		draw_colored_polygon(polygon, SELECT_HIGHLIGHT)
	if tile == _hover_tile:
		draw_colored_polygon(polygon, HOVER_HIGHLIGHT)

func _draw_scene_objects(grid: Array, tiles: Array[Vector2i], units_to_draw: Array[Dictionary]) -> void:
	for tile: Vector2i in tiles:
		_draw_scene_props_for_tile(tile)
		_draw_tile_props(grid, tile, units_to_draw)
		_draw_unit_bodies_for_tile(tile, units_to_draw)

func _draw_scene_props_for_tile(tile: Vector2i) -> void:
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		if prop.get("tile", Vector2i(-1, -1)) != tile:
			continue
		var texture: Texture2D = _scene_prop_textures.get(str(prop.get("kind", "")), null)
		if texture == null:
			continue
		draw_texture_rect(texture, _scene_prop_rect(texture, prop), false)

func _scene_prop_rect(texture: Texture2D, prop: Dictionary) -> Rect2:
	var tile: Vector2i = prop.get("tile", Vector2i(4, 4))
	var center: Vector2 = _tile_center(tile)
	var width_scale: float = float(prop.get("width_scale", CAMPFIRE_BONFIRE_WIDTH_SCALE))
	var draw_width: float = _tile_width() * width_scale
	var texture_size: Vector2 = texture.get_size()
	var draw_height: float = draw_width
	if texture_size.x > 0.0:
		draw_height = draw_width * texture_size.y / texture_size.x
	var baseline_scale: float = float(prop.get("baseline_scale", CAMPFIRE_BONFIRE_BASELINE_SCALE))
	var bottom_y: float = center.y + _tile_height() * baseline_scale
	return Rect2(Vector2(center.x - draw_width * 0.5, bottom_y - draw_height), Vector2(draw_width, draw_height))

func _draw_prop_moss_overlay(tile_id: String, grid: Array, tile: Vector2i, units_to_draw: Array) -> void:
	if tile_id == "pillar":
		if not _tile_has_moss("pillar", tile):
			return
		var pillar_texture: Texture2D = _prop_textures.get("pillar", null)
		if pillar_texture == null:
			return
		var frame_rect: Rect2 = _prop_rect_for_tile(tile)
		var draw_rect: Rect2 = _prop_draw_rect(pillar_texture, frame_rect)
		var texture: Texture2D = _moss_texture_for_surface("pillar", tile)
		if texture == null:
			return
		var moss_rect: Rect2 = _pillar_moss_rect(draw_rect)
		draw_texture_rect(texture, moss_rect, false, _foreground_blocker_tint(tile_id, tile, moss_rect, units_to_draw))
		return
	if tile_id != "wall" or not _tile_has_moss("wall", tile):
		return
	var orientation: String = _wall_orientation_for_tile(grid, tile)
	if orientation.is_empty():
		return
	var wall_texture: Texture2D = _prop_textures.get("wall_%s" % orientation, _prop_textures.get("wall", null))
	if wall_texture == null:
		return
	var frame_rect: Rect2 = _prop_rect_for_tile(tile)
	var draw_rect: Rect2 = _prop_draw_rect(wall_texture, frame_rect)
	var texture: Texture2D = _moss_texture_for_surface("wall", tile, orientation == "col")
	if texture == null:
		return
	var moss_rect: Rect2 = _wall_moss_rect(draw_rect)
	draw_texture_rect(texture, moss_rect, false, _foreground_blocker_tint(tile_id, tile, moss_rect, units_to_draw))

func _draw_tile_props(grid: Array, tile: Vector2i, units_to_draw: Array = []) -> void:
	var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
	if tile_id == "wall" and not _is_outer_boundary_tile(grid, tile):
		tile_id = "pillar"
	if tile_id == "pillar":
		var texture: Texture2D = _prop_textures.get("pillar", null)
		if texture != null:
			var frame_rect: Rect2 = _prop_rect_for_tile(tile)
			var draw_rect: Rect2 = _prop_draw_rect(texture, frame_rect)
			draw_texture_rect(texture, draw_rect, false, _foreground_blocker_tint(tile_id, tile, draw_rect, units_to_draw))
	elif tile_id == "wall":
		var segments: Array[Dictionary] = _boundary_prop_segments(tile_id, grid, tile)
		for segment: Dictionary in segments:
			var texture: Texture2D = segment.get("texture", null)
			if texture == null:
				continue
			var draw_rect: Rect2 = segment.get("draw_rect", Rect2())
			var source_rect: Rect2 = segment.get("source_rect", Rect2(Vector2.ZERO, texture.get_size()))
			var tint: Color = _foreground_blocker_tint(tile_id, tile, draw_rect, units_to_draw)
			if source_rect.position == Vector2.ZERO and source_rect.size == texture.get_size():
				draw_texture_rect(texture, draw_rect, false, tint)
			else:
				draw_texture_rect_region(texture, draw_rect, source_rect, tint)
	elif tile_id == "door":
		var door_texture: Texture2D = _door_texture_for_tile(grid, tile)
		if door_texture != null:
			var draw_rect: Rect2 = _prop_draw_rect(door_texture, _door_rect_for_tile(tile, grid))
			var opening_texture: Texture2D = _door_opening_texture_for_tile(grid, tile)
			if opening_texture != null:
				draw_texture_rect(opening_texture, _door_opening_draw_rect(opening_texture, door_texture, draw_rect, _door_uses_flipped_orientation(grid, tile)), false)
			else:
				draw_texture_rect(door_texture, draw_rect, false)
				var icon_id: String = str(exit_icon_ids.get(tile, ""))
				var icon_texture: Texture2D = _door_icon_texture(icon_id)
				if icon_texture != null:
					_draw_door_icon(icon_texture, icon_id, door_texture, draw_rect)
	_draw_prop_moss_overlay(tile_id, grid, tile, units_to_draw)
	for loot: Dictionary in combat_state.get("loot", []):
		if bool(loot.get("claimed", false)):
			continue
		if loot.get("pos", Vector2i(-1, -1)) != tile:
			continue
		var loot_texture: Texture2D = _loot_textures.get(str(loot.get("kind", "")), null)
		if loot_texture == null:
			continue
		var loot_rect: Rect2 = _loot_rect_for_tile(tile)
		draw_texture_rect(loot_texture, loot_rect, false)
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if trap.get("pos", Vector2i(-1, -1)) != tile:
			continue
		_draw_trap_marker(trap)

func _foreground_blocker_tint(tile_id: String, tile: Vector2i, prop_rect: Rect2, units_to_draw: Array) -> Color:
	if not _is_tall_obstructive_tile(tile_id):
		return Color.WHITE
	for unit_var: Variant in units_to_draw:
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		var unit_tile: Vector2i = _effective_unit_tile(unit)
		if not _tile_draws_before(unit_tile, tile):
			continue
		if prop_rect.intersects(_unit_draw_rect(unit), true):
			return FOREGROUND_OBSTRUCTION_TINT
	return Color.WHITE

func _is_tall_obstructive_tile(tile_id: String) -> bool:
	return tile_id == "pillar" or tile_id == "wall"

func _prop_rect_for_tile(tile: Vector2i) -> Rect2:
	var center: Vector2 = _tile_center(tile)
	var prop_size: Vector2 = _prop_size()
	return Rect2(center - Vector2(prop_size.x * 0.5, prop_size.y * 0.84), prop_size)

func _door_rect_for_tile(tile: Vector2i, grid: Array = []) -> Rect2:
	var center: Vector2 = _tile_center(tile) + _door_back_edge_offset_for_tile(tile, grid)
	var tile_width: float = _tile_width()
	var frame_size := Vector2(tile_width * DOOR_FRAME_WIDTH_SCALE, tile_width * DOOR_FRAME_HEIGHT_SCALE)
	var bottom_y: float = center.y + tile_width * DOOR_BASELINE_OFFSET_SCALE
	return Rect2(
		Vector2(center.x - frame_size.x * 0.5, bottom_y - frame_size.y),
		frame_size
	)

func _door_back_edge_offset_for_tile(tile: Vector2i, grid: Array = []) -> Vector2:
	var effective_grid: Array = grid
	if effective_grid.is_empty():
		effective_grid = combat_state.get("grid", [])
	if effective_grid.is_empty():
		return Vector2.ZERO
	var height: int = effective_grid.size()
	var width: int = (effective_grid[0] as Array).size()
	if tile.y == 0 and tile.x > 0 and tile.x < width - 1:
		return _tile_step_offset(Vector2i(0, -1)) * DOOR_TOP_BACK_EDGE_OFFSET_SCALE
	if tile.x == width - 1 and tile.y > 0 and tile.y < height - 1:
		return _tile_step_offset(Vector2i(1, 0)) * DOOR_BACK_EDGE_OFFSET_SCALE
	if tile.y == height - 1 and tile.x > 0 and tile.x < width - 1:
		return _tile_step_offset(Vector2i(0, 1)) * DOOR_BACK_EDGE_OFFSET_SCALE
	if tile.x == 0 and tile.y > 0 and tile.y < height - 1:
		return _tile_step_offset(Vector2i(-1, 0)) * DOOR_TOP_BACK_EDGE_OFFSET_SCALE
	return Vector2.ZERO

func _door_texture_for_tile(grid: Array, tile: Vector2i) -> Texture2D:
	if grid.is_empty():
		return _prop_textures.get("door", null)
	var width: int = (grid[0] as Array).size()
	var height: int = grid.size()
	if tile.y == 0 or tile.y == height - 1:
		return _prop_textures.get("door_row", _prop_textures.get("door", null))
	if tile.x == 0 or tile.x == width - 1:
		return _prop_textures.get("door_col", _prop_textures.get("door", null))
	return _prop_textures.get("door", null)

func _door_opening_texture_for_tile(grid: Array, tile: Vector2i) -> Texture2D:
	var animation: Dictionary = _door_opening_animation_for_tile(tile)
	if animation.is_empty():
		return null
	var frames: Array[Texture2D] = _door_opening_frames_for_tile(grid, tile)
	if frames.is_empty():
		return null
	return frames[_door_opening_frame_index(animation, frames.size())]

func _door_opening_animation_for_tile(tile: Vector2i) -> Dictionary:
	var animation: Dictionary = presentation.get("door_opening", {})
	if animation.is_empty():
		return {}
	if animation.get("tile", Vector2i(-999, -999)) != tile:
		return {}
	return animation

func _door_opening_frames_for_tile(grid: Array, tile: Vector2i) -> Array[Texture2D]:
	if _door_uses_flipped_orientation(grid, tile):
		return _door_opening_flipped_frames
	return _door_opening_frames

func _door_uses_flipped_orientation(grid: Array, tile: Vector2i) -> bool:
	if grid.is_empty():
		return false
	var width: int = (grid[0] as Array).size()
	return tile.x == 0 or tile.x == width - 1

func _door_opening_frame_index(animation: Dictionary, frame_count: int) -> int:
	if frame_count <= 1:
		return 0
	if animation.has("frame"):
		return clampi(int(animation.get("frame", 0)), 0, frame_count - 1)
	var progress: float = clampf(float(animation.get("progress", 0.0)), 0.0, 1.0)
	return clampi(int(roundf(progress * float(frame_count - 1))), 0, frame_count - 1)

func _door_opening_draw_rect(texture: Texture2D, static_texture: Texture2D, static_draw_rect: Rect2, flipped_orientation: bool = false) -> Rect2:
	if texture == null or static_texture == null:
		return static_draw_rect
	var reference_size: Vector2 = _door_opening_reference_frame_size()
	if reference_size.y <= 0.0:
		return static_draw_rect
	var static_used_rect: Rect2 = _texture_used_draw_rect(static_texture, static_draw_rect)
	var scale: float = static_used_rect.size.y / reference_size.y
	var draw_size: Vector2 = texture.get_size() * scale
	var draw_y: float = static_used_rect.end.y - draw_size.y
	var draw_x: float = static_used_rect.position.x if flipped_orientation else static_used_rect.end.x - draw_size.x
	return Rect2(Vector2(draw_x, draw_y), draw_size)

func _door_opening_reference_frame_size() -> Vector2:
	if _door_opening_frames.is_empty():
		return Vector2.ZERO
	var reference: Texture2D = _door_opening_frames[0]
	if reference == null:
		return Vector2.ZERO
	var reference_used_rect: Rect2i = _texture_used_rect(reference)
	return Vector2(reference_used_rect.size) if reference_used_rect.size.x > 0 and reference_used_rect.size.y > 0 else reference.get_size()

func _texture_used_draw_rect(texture: Texture2D, draw_rect: Rect2) -> Rect2:
	if texture == null:
		return draw_rect
	var used_rect: Rect2i = _texture_used_rect(texture)
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return draw_rect
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return draw_rect
	var scale := Vector2(draw_rect.size.x / texture_size.x, draw_rect.size.y / texture_size.y)
	return Rect2(
		draw_rect.position + Vector2(float(used_rect.position.x) * scale.x, float(used_rect.position.y) * scale.y),
		Vector2(float(used_rect.size.x) * scale.x, float(used_rect.size.y) * scale.y)
	)

func _texture_used_rect(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2i()
	return image.get_used_rect()

func _draw_door_icon(icon_texture: Texture2D, icon_id: String, door_texture: Texture2D, door_draw_rect: Rect2) -> void:
	if icon_texture == null:
		return
	var door_used_rect: Rect2 = _texture_used_draw_rect(door_texture, door_draw_rect)
	var icon_size: float = clampf(_tile_width() * DOOR_ICON_SIZE_SCALE, DOOR_ICON_MIN_SIZE, DOOR_ICON_MAX_SIZE)
	var accent: Color = ElementData.door_tint(icon_id) if ElementData.is_elemental(icon_id) else Color("d3b78e")
	var center := Vector2(
		door_used_rect.get_center().x,
		door_used_rect.position.y - icon_size * 0.5 - _tile_height() * DOOR_ICON_FLOAT_GAP_SCALE
	)
	var radius: float = icon_size * 0.56
	draw_circle(center, radius, Color(0.07, 0.05, 0.04, 0.86))
	draw_arc(center, radius, 0.0, TAU, 28, Color(accent.r, accent.g, accent.b, 0.88), 2.0, true)
	var icon_rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(icon_texture, icon_rect, false)

func _is_outer_boundary_tile(grid: Array, tile: Vector2i) -> bool:
	if grid.is_empty():
		return false
	var width: int = (grid[0] as Array).size()
	var height: int = grid.size()
	return tile.x == 0 or tile.y == 0 or tile.x == width - 1 or tile.y == height - 1

func _boundary_prop_segments(tile_id: String, grid: Array, tile: Vector2i) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if not _is_outer_boundary_tile(grid, tile):
		return segments
	var width: int = (grid[0] as Array).size()
	var height: int = grid.size()
	if tile.y == 0 or tile.y == height - 1:
		var row_half: String = "full"
		if tile.x == 0:
			row_half = "right"
		elif tile.x == width - 1:
			row_half = "left"
		var row_segment: Dictionary = _boundary_prop_segment(tile_id, tile, grid, "row", row_half)
		if not row_segment.is_empty():
			segments.append(row_segment)
	if tile.x == 0 or tile.x == width - 1:
		var col_half: String = "full"
		if tile.y == 0:
			col_half = "left"
		elif tile.y == height - 1:
			col_half = "right"
		var col_segment: Dictionary = _boundary_prop_segment(tile_id, tile, grid, "col", col_half)
		if not col_segment.is_empty():
			segments.append(col_segment)
	return segments

func _boundary_prop_segment(tile_id: String, tile: Vector2i, grid: Array, orientation: String, half: String) -> Dictionary:
	var texture: Texture2D = _prop_textures.get("%s_%s" % [tile_id, orientation], _prop_textures.get(tile_id, null))
	if texture == null:
		return {}
	var frame_rect: Rect2 = _door_rect_for_tile(tile, grid) if tile_id == "door" else _prop_rect_for_tile(tile)
	var full_rect: Rect2 = _prop_draw_rect(texture, frame_rect)
	return {
		"orientation": orientation,
		"half": half,
		"texture": texture,
		"draw_rect": _boundary_segment_draw_rect(full_rect, half),
		"source_rect": _boundary_segment_source_rect(texture, half)
	}

func _boundary_segment_draw_rect(full_rect: Rect2, half: String) -> Rect2:
	if half == "left":
		return Rect2(full_rect.position, Vector2(full_rect.size.x * 0.5, full_rect.size.y))
	if half == "right":
		return Rect2(Vector2(full_rect.position.x + full_rect.size.x * 0.5, full_rect.position.y), Vector2(full_rect.size.x * 0.5, full_rect.size.y))
	return full_rect

func _boundary_segment_source_rect(texture: Texture2D, half: String) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if half == "left":
		return Rect2(Vector2.ZERO, Vector2(texture_size.x * 0.5, texture_size.y))
	if half == "right":
		return Rect2(Vector2(texture_size.x * 0.5, 0.0), Vector2(texture_size.x * 0.5, texture_size.y))
	return Rect2(Vector2.ZERO, texture_size)

func _display_tile_id(tile_id: String, tile: Vector2i) -> String:
	if tile_id == "door" and not _door_is_visible(tile):
		return "wall"
	return tile_id

func _should_render_tile(display_tile_id: String, tile: Vector2i, grid: Array) -> bool:
	if not OUTER_WALL_RENDERING_ENABLED and display_tile_id == "wall" and _is_outer_boundary_tile(grid, tile):
		return false
	return true

func _door_is_visible(tile: Vector2i) -> bool:
	if exit_tiles.has(tile):
		return true
	var active_doors: Dictionary = presentation.get("active_door_tiles", {})
	if bool(active_doors.get(tile, false)):
		return true
	var locked_doors: Dictionary = presentation.get("locked_door_tiles", {})
	return bool(locked_doors.get(tile, false))

func _loot_rect_for_tile(tile: Vector2i) -> Rect2:
	return Rect2(_tile_center(tile) - Vector2(26.0, 58.0), Vector2(52.0, 68.0))

func _draw_exit_marker_for_tile(tile: Vector2i) -> void:
	if not exit_tiles.has(tile):
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var label: String = str(exit_tiles.get(tile, ""))
	var icon_id: String = str(exit_icon_ids.get(tile, ""))
	var accent: Color = ElementData.door_tint(icon_id) if ElementData.is_elemental(icon_id) else Color("d3b78e")
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, -_tile_height() * 0.58)
	var marker_rect := Rect2(center - Vector2(26.0, 16.0), Vector2(52.0, 32.0))
	draw_rect(marker_rect, Color(0.11, 0.08, 0.06, 0.92), true)
	draw_rect(marker_rect, accent, false, 2.0)
	draw_string(font, marker_rect.position + Vector2(0.0, 13.0), label, HORIZONTAL_ALIGNMENT_CENTER, marker_rect.size.x, 11, Color("fff0d1"))
	var icon_texture: Texture2D = _door_icon_texture(icon_id)
	if icon_texture != null:
		draw_texture_rect(icon_texture, Rect2(marker_rect.position + Vector2(4.0, 4.0), Vector2(14.0, 14.0)), false)

func _visible_units() -> Array[Dictionary]:
	var units_to_draw: Array[Dictionary] = []
	var player: Dictionary = combat_state.get("player", {})
	var player_restrictions: Dictionary = combat_state.get("player_turn_restrictions", {})
	if not player.is_empty() and int(player.get("hp", 0)) > 0:
		var player_statuses: Dictionary = _player_display_statuses(player, player_restrictions)
		units_to_draw.append({
			"key": "player",
			"role": "player",
			"type": "player",
			"pos": player.get("pos", Vector2i.ZERO),
			"hp": int(player.get("hp", 0)),
			"max_hp": int(player.get("max_hp", 1)),
			"block": int(player.get("block", 0)),
			"stoneskin": int(player.get("stoneskin", 0)),
			"burn": int(player_statuses.get("burn", 0)),
			"freeze": int(player_statuses.get("freeze", 0)),
			"shock": int(player_statuses.get("shock", 0)),
			"stun": int(player_statuses.get("stun", 0)),
			"poison": player.get("poison", {}).duplicate(true)
		})
	for enemy: Dictionary in combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0:
			continue
		units_to_draw.append({
			"key": "enemy_%d" % int(enemy.get("id", -1)),
			"role": "enemy",
			"type": str(enemy.get("type", "")),
			"intent": enemy.get("intent", {}),
			"pos": enemy.get("pos", Vector2i.ZERO),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", 1)),
			"block": int(enemy.get("block", 0)),
			"stoneskin": int(enemy.get("stoneskin", 0)),
			"burn": int(enemy.get("burn", 0)),
			"freeze": int(enemy.get("freeze", 0)),
			"shock": int(enemy.get("shock", 0)),
			"stun": int(enemy.get("stun", 0)),
			"poison": enemy.get("poison", {}).duplicate(true)
		})
	for npc_index: int in range((combat_state.get("npcs", []) as Array).size()):
		var npc: Dictionary = (combat_state.get("npcs", []) as Array)[npc_index]
		var npc_id: String = str(npc.get("id", ""))
		if npc_id.is_empty():
			continue
		var npc_def: Dictionary = GameData.npc_def(npc_id)
		units_to_draw.append({
			"key": "npc_%s_%d" % [npc_id, npc_index],
			"role": "npc",
			"type": npc_id,
			"name": str(npc.get("name", npc_def.get("name", npc_id))),
			"pos": npc.get("pos", Vector2i.ZERO),
			"accent": Color(str(npc.get("accent", npc_def.get("accent", "#d2c2a7"))))
		})
	units_to_draw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_pos: Vector2i = _effective_unit_tile(a)
		var b_pos: Vector2i = _effective_unit_tile(b)
		if a_pos == b_pos:
			return _tile_draws_before(a.get("pos", Vector2i.ZERO), b.get("pos", Vector2i.ZERO))
		return _tile_draws_before(a_pos, b_pos)
	)
	return units_to_draw

func _draw_unit_bodies_for_tile(tile: Vector2i, units_to_draw: Array[Dictionary]) -> void:
	for unit: Dictionary in units_to_draw:
		if _effective_unit_tile(unit) != tile:
			continue
		_draw_unit_body(unit)

func _draw_unit_body(unit: Dictionary) -> void:
	var center: Vector2 = _unit_center(unit)
	_draw_shadow(center + Vector2(0.0, _tile_height() * 0.58))
	var texture: Texture2D = _texture_for_unit(unit)
	if texture != null:
		draw_texture_rect(texture, _unit_draw_rect(unit), false)

func _draw_unit_huds(units_to_draw: Array[Dictionary]) -> void:
	var font: Font = get_theme_default_font()
	var reserved_rects: Array[Rect2] = _fixed_hud_collision_rects(units_to_draw, font)
	for unit: Dictionary in units_to_draw:
		var center: Vector2 = _unit_center(unit)
		if str(unit.get("role", "")) == "npc":
			_draw_npc_nameplate(unit, center)
			continue
		var health_rect: Rect2 = _unit_health_bar_rect(unit, center)
		if str(unit.get("role", "")) == "enemy":
			var enemy_layout: Dictionary = _enemy_hud_layout(unit, center, reserved_rects, font)
			health_rect = enemy_layout.get("health_rect", health_rect)
			_draw_enemy_hud_tether(unit, center, enemy_layout)
			_draw_health_bar(unit, health_rect)
			_draw_unit_statuses(unit, health_rect)
			_draw_enemy_intent_layout(enemy_layout, font)
			for rect_var: Variant in enemy_layout.get("occupied_rects", []):
				if typeof(rect_var) == TYPE_RECT2:
					reserved_rects.append(rect_var)
			continue
		_draw_health_bar(unit, health_rect)
		_draw_unit_statuses(unit, health_rect)

func _draw_npc_nameplate(unit: Dictionary, center: Vector2) -> void:
	var font: Font = get_theme_default_font()
	var plate_rect: Rect2 = _npc_nameplate_rect(unit, center, font)
	if plate_rect.size.x <= 0.0 or plate_rect.size.y <= 0.0:
		return
	var accent: Color = unit.get("accent", Color("d2c2a7"))
	var name: String = str(unit.get("name", ""))
	draw_rect(plate_rect, Color(0.08, 0.06, 0.05, 0.9), true)
	draw_rect(plate_rect, accent, false, 1.0)
	draw_string(font, plate_rect.position + Vector2(0.0, 11.0), name, HORIZONTAL_ALIGNMENT_CENTER, plate_rect.size.x, 8, Color("fff4dc"))
	_register_tooltip(plate_rect, name)

func _npc_nameplate_rect(unit: Dictionary, center: Vector2, font: Font = null) -> Rect2:
	if font == null:
		return Rect2()
	var name: String = str(unit.get("name", ""))
	if name.is_empty():
		return Rect2()
	var text_width: float = maxf(72.0, font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8).x + 16.0)
	return Rect2(
		Vector2(center.x - text_width * 0.5, _unit_art_top_y(unit, center) - 22.0),
		Vector2(text_width, 16.0)
	)

func _draw_health_bar(unit: Dictionary, rect: Rect2) -> void:
	var font: Font = get_theme_default_font()
	SegmentedHealthBar.draw_bar(
		self,
		rect,
		float(unit.get("hp", 0)),
		float(maxi(1, int(unit.get("max_hp", 1)))),
		maxi(1, int(ceili(float(maxi(1, int(unit.get("max_hp", 1)))) / 10.0))),
		Color("2d1f18"),
		PLAYER_BAR_FILL if str(unit.get("role", "")) == "player" else ENEMY_BAR_FILL,
		Color("f5efdf"),
		Color("eed3a6"),
		Color(0.0, 0.0, 0.0, 0.35),
		1.0,
		1.0
	)
	if font != null:
		var text_baseline: Vector2 = rect.position + Vector2(0.0, rect.size.y - 1.0)
		for offset: Vector2 in [
			Vector2(-1.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, -1.0),
			Vector2(0.0, 1.0)
		]:
			draw_string(
				font,
				text_baseline + offset,
				"%d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))],
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				9,
				Color("140f0b")
			)
		draw_string(
			font,
			text_baseline,
			"%d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			9,
			Color("fff4dc")
		)
	var block_amount: int = int(unit.get("block", 0))
	var defense_badge_x: float = rect.position.x + rect.size.x + 4.0
	if block_amount > 0:
		var block_rect := Rect2(Vector2(defense_badge_x, rect.position.y), Vector2(36.0, 16.0))
		_draw_icon_value_badge(block_rect, "block", block_amount, Color(0.07, 0.12, 0.16, 0.92), Color("90d9ff"), Color("d9f5ff"), font)
		defense_badge_x += block_rect.size.x + 4.0
	var stoneskin_amount: int = int(unit.get("stoneskin", 0))
	if stoneskin_amount > 0:
		var skin_rect := Rect2(Vector2(defense_badge_x, rect.position.y), Vector2(40.0, 16.0))
		_draw_icon_value_badge(skin_rect, "stoneskin", stoneskin_amount, Color(0.10, 0.14, 0.08, 0.92), ElementData.accent(ElementData.EARTH), Color("eff8d7"), font)

func _draw_icon_value_badge(rect: Rect2, icon_key: String, amount: int, fill: Color, border: Color, text_color: Color, font: Font) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 1.0)
	var icon_size: float = maxf(10.0, rect.size.y - 4.0)
	var icon_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2(icon_size, icon_size))
	_draw_keyword_icon(icon_key, icon_rect, ActionIcons.tooltip(icon_key))
	if font != null:
		var text_left: float = icon_size + 4.0
		draw_string(
			font,
			rect.position + Vector2(text_left, rect.size.y - 4.0),
			str(amount),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x - text_left,
			9,
			text_color
		)
	_register_tooltip(rect, ActionIcons.tooltip(icon_key))

func _unit_frame_rect(center: Vector2) -> Rect2:
	var unit_size: Vector2 = _unit_size()
	return Rect2(center - Vector2(unit_size.x * 0.5, unit_size.y * 0.84), unit_size)

func _unit_art_top_y(unit: Dictionary, center: Vector2) -> float:
	return _unit_draw_rect_for_center(unit, center).position.y

func _unit_health_bar_rect(unit: Dictionary, center: Vector2) -> Rect2:
	var bar_size: Vector2 = PLAYER_HEALTH_BAR_SIZE if str(unit.get("role", "")) == "player" else ENEMY_HEALTH_BAR_SIZE
	var bottom_y: float = _unit_art_top_y(unit, center) - UNIT_ART_HUD_CLEARANCE
	return Rect2(
		Vector2(center.x - bar_size.x * 0.5, bottom_y - bar_size.y),
		bar_size
	)

func _draw_unit_statuses(unit: Dictionary, health_rect: Rect2) -> void:
	var badges: Array[Dictionary] = _unit_status_badges(unit)
	if badges.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var spacing: float = 22.0
	var start_x: float = health_rect.position.x - 12.0 - (float(badges.size() - 1) * spacing)
	var center_y: float = health_rect.position.y + health_rect.size.y - 2.0
	for index: int in range(badges.size()):
		_draw_status_badge(font, Vector2(start_x + float(index) * spacing, center_y), badges[index])

func _draw_enemy_intent(unit: Dictionary, center: Vector2, health_rect: Rect2) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var layout: Dictionary = _enemy_hud_layout(unit, center, [], font)
	layout["health_rect"] = health_rect
	var intent_rect: Rect2 = layout.get("intent_rect", Rect2())
	if intent_rect.size.x <= 0.0 or intent_rect.size.y <= 0.0:
		return
	var default_health_rect: Rect2 = _unit_health_bar_rect(unit, center)
	var applied_offset: Vector2 = health_rect.position - default_health_rect.position
	if applied_offset != Vector2.ZERO:
		intent_rect.position += applied_offset
		layout["intent_rect"] = intent_rect
		layout["offset"] = applied_offset
	_draw_enemy_intent_layout(layout, font)

func _draw_enemy_intent_layout(layout: Dictionary, font: Font) -> void:
	if font == null:
		return
	var label_rect: Rect2 = layout.get("intent_rect", Rect2())
	if label_rect.size.x <= 0.0 or label_rect.size.y <= 0.0:
		return
	var rows: Array = layout.get("rows", [])
	var intent_name: String = str(layout.get("intent_name", ""))
	var border: Color = layout.get("border", Color("d8b96f"))
	draw_rect(label_rect, Color(0.08, 0.06, 0.05, 0.88), true)
	draw_rect(label_rect, border, false, 2.0)
	var rows_origin_y: float = label_rect.position.y + 8.0
	if not intent_name.is_empty():
		var title_rect := Rect2(label_rect.position + Vector2(INTENT_POPUP_PADDING_X, 6.0), Vector2(label_rect.size.x - INTENT_POPUP_PADDING_X * 2.0, 16.0))
		_draw_enemy_intent_title(title_rect, intent_name, border, font)
		rows_origin_y += 20.0
	for row_index: int in range(rows.size()):
		_draw_token_row(
			rows[row_index] as Array,
			Vector2(label_rect.position.x + INTENT_POPUP_PADDING_X, rows_origin_y + float(row_index) * 20.0),
			INTENT_POPUP_ICON_SIZE,
			INTENT_POPUP_ROW_FONT_SIZE,
			Color("f7ecd4"),
			font
		)

func _enemy_intent_rect_for_line_count(center: Vector2, health_rect: Rect2, line_count: int, popup_width: float = INTENT_POPUP_WIDTH) -> Rect2:
	if line_count <= 0:
		return Rect2()
	var label_height: float = 14.0 + float(line_count) * 20.0
	return Rect2(
		Vector2(center.x - popup_width * 0.5, health_rect.position.y - HUD_STACK_GAP - label_height),
		Vector2(popup_width, label_height)
	)

func _draw_enemy_intent_title(rect: Rect2, title: String, border: Color, font: Font) -> void:
	if title.is_empty() or font == null:
		return
	var baseline: Vector2 = rect.position + Vector2(0.0, 11.0)
	draw_string(font, baseline + Vector2(0.0, 1.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 9, Color("140f0b"))
	draw_string(font, baseline, title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 9, Color("fff4dc"))
	var divider_y: float = rect.position.y + rect.size.y + 1.0
	draw_line(
		Vector2(rect.position.x + 2.0, divider_y),
		Vector2(rect.position.x + rect.size.x - 2.0, divider_y),
		border.darkened(0.18),
		1.0,
		true
	)

func _draw_token_row(tokens: Array, origin: Vector2, icon_size: float, font_size: int, text_color: Color, font: Font) -> void:
	var cursor_x: float = origin.x
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			var pattern_size: Vector2 = _aoe_token_size(token, icon_size)
			var pattern_rect := Rect2(Vector2(cursor_x, origin.y + (icon_size - pattern_size.y) * 0.5), pattern_size)
			_draw_aoe_token_pattern(token, pattern_rect, icon_size)
			_register_tooltip(pattern_rect, ActionIcons.token_tooltip(token))
			cursor_x += pattern_size.x + 5.0
			continue
		var icon_key: String = str(token.get("icon", ""))
		var tooltip: String = ActionIcons.token_tooltip(token)
		var icon_rect := Rect2(Vector2(cursor_x, origin.y), Vector2(icon_size, icon_size))
		_draw_keyword_icon(icon_key, icon_rect, tooltip)
		cursor_x += icon_size + 3.0
		var value_text: String = ActionIcons.token_value_text(token)
		if not value_text.is_empty() and font != null:
			var value_width: float = maxf(font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x, 8.0)
			var value_rect := Rect2(Vector2(cursor_x, origin.y), Vector2(value_width, icon_size))
			draw_string(
				font,
				Vector2(cursor_x, origin.y + icon_size - 2.0),
				value_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				value_width,
				font_size,
				_token_value_color(token, text_color)
			)
			_register_tooltip(value_rect, tooltip)
			cursor_x += value_width + 6.0
		else:
			cursor_x += 5.0

func _enemy_intent_popup_width(intent: Dictionary, rows: Array, font: Font) -> float:
	var popup_width: float = INTENT_POPUP_WIDTH
	var intent_name: String = _intent_display_name(intent)
	if not intent_name.is_empty() and font != null:
		var title_width: float = font.get_string_size(intent_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, INTENT_POPUP_TITLE_FONT_SIZE).x
		popup_width = maxf(popup_width, ceilf(title_width) + INTENT_POPUP_PADDING_X * 2.0 + 4.0)
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		popup_width = maxf(popup_width, _token_row_width(row_var as Array, INTENT_POPUP_ICON_SIZE, INTENT_POPUP_ROW_FONT_SIZE, font) + INTENT_POPUP_PADDING_X * 2.0)
	return popup_width

func _token_row_width(tokens: Array, icon_size: float, font_size: int, font: Font) -> float:
	var width: float = 0.0
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		if str((token_var as Dictionary).get("kind", "")) == "aoe_pattern":
			width += _aoe_token_size(token_var as Dictionary, icon_size).x + 5.0
			continue
		width += icon_size + 3.0
		var value_text: String = ActionIcons.token_value_text(token_var as Dictionary)
		if not value_text.is_empty() and font != null:
			width += maxf(font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x, 8.0) + 6.0
		else:
			width += 5.0
	return width

func _aoe_token_size(token: Dictionary, icon_size: float) -> Vector2:
	var offsets: Array[Vector2i] = _aoe_token_offsets(token)
	if bool(token.get("show_origin", false)) and not offsets.has(Vector2i.ZERO):
		offsets.append(Vector2i.ZERO)
	var bounds: Rect2 = _aoe_token_bounds(offsets, icon_size)
	return Vector2(maxf(icon_size * 1.8, bounds.size.x + 6.0), maxf(icon_size, bounds.size.y + 4.0))

func _draw_aoe_token_pattern(token: Dictionary, rect: Rect2, icon_size: float) -> void:
	var offsets: Array[Vector2i] = _aoe_token_offsets(token)
	var show_origin: bool = bool(token.get("show_origin", false))
	var hit_lookup: Dictionary = {}
	for offset: Vector2i in offsets:
		hit_lookup[offset] = true
	if show_origin and not hit_lookup.has(Vector2i.ZERO):
		offsets.append(Vector2i.ZERO)
	var bounds: Rect2 = _aoe_token_bounds(offsets, icon_size)
	var shift: Vector2 = rect.get_center() - bounds.get_center()
	for offset: Vector2i in offsets:
		var is_origin: bool = show_origin and offset == Vector2i.ZERO and not hit_lookup.has(offset)
		var fill: Color = Color("e9dcc6") if is_origin else Color("d95f4a")
		var border: Color = Color("5a493b") if is_origin else Color("7b2f25")
		_draw_aoe_token_tile(_aoe_token_center(offset, icon_size) + shift, icon_size, fill, border)

func _aoe_token_offsets(token: Dictionary) -> Array[Vector2i]:
	var raw_pattern: Variant = token.get("pattern", [])
	var offsets: Array[Vector2i] = []
	if typeof(raw_pattern) == TYPE_ARRAY:
		for offset_var: Variant in raw_pattern:
			match typeof(offset_var):
				TYPE_VECTOR2I:
					offsets.append(offset_var)
				TYPE_ARRAY:
					var pair: Array = offset_var
					if pair.size() >= 2:
						offsets.append(Vector2i(int(pair[0]), int(pair[1])))
				TYPE_DICTIONARY:
					var offset_dict: Dictionary = offset_var
					offsets.append(Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0))))
	if offsets.is_empty():
		offsets.append(Vector2i.ZERO)
	return offsets

func _aoe_token_bounds(offsets: Array[Vector2i], icon_size: float) -> Rect2:
	var first: bool = true
	var rect := Rect2()
	var tile_width: float = icon_size * 0.70
	var tile_height: float = icon_size * 0.46
	for offset: Vector2i in offsets:
		var center: Vector2 = _aoe_token_center(offset, icon_size)
		var tile_rect := Rect2(center - Vector2(tile_width * 0.5, tile_height * 0.5), Vector2(tile_width, tile_height))
		if first:
			rect = tile_rect
			first = false
		else:
			rect = rect.merge(tile_rect)
	return rect

func _aoe_token_center(offset: Vector2i, icon_size: float) -> Vector2:
	var tile_width: float = icon_size * 0.70
	var tile_height: float = icon_size * 0.46
	return Vector2(float(offset.x - offset.y) * tile_width * 0.5, float(offset.x + offset.y) * tile_height * 0.5)

func _draw_aoe_token_tile(center: Vector2, icon_size: float, fill: Color, border: Color) -> void:
	var tile_width: float = icon_size * 0.70
	var tile_height: float = icon_size * 0.46
	var points := PackedVector2Array([
		center + Vector2(0.0, -tile_height * 0.5),
		center + Vector2(tile_width * 0.5, 0.0),
		center + Vector2(0.0, tile_height * 0.5),
		center + Vector2(-tile_width * 0.5, 0.0),
		center + Vector2(0.0, -tile_height * 0.5)
	])
	draw_colored_polygon(points, fill)
	draw_polyline(points, border, 1.0, true)

func _fixed_hud_collision_rects(units_to_draw: Array[Dictionary], font: Font) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for unit: Dictionary in units_to_draw:
		var center: Vector2 = _unit_center(unit)
		match str(unit.get("role", "")):
			"enemy":
				continue
			"npc":
				var plate_rect: Rect2 = _npc_nameplate_rect(unit, center, font)
				if plate_rect.size.x > 0.0 and plate_rect.size.y > 0.0:
					rects.append(plate_rect)
			_:
				rects.append_array(_health_bar_collision_rects(unit, _unit_health_bar_rect(unit, center)))
	return rects

func _enemy_hud_layout(unit: Dictionary, center: Vector2, occupied_rects: Array, font: Font = null) -> Dictionary:
	var health_rect: Rect2 = _unit_health_bar_rect(unit, center)
	var intent: Dictionary = unit.get("intent", {})
	var rows: Array = []
	var intent_name: String = ""
	var intent_rect := Rect2()
	var border: Color = Color("d8b96f")
	if not intent.is_empty():
		rows = _intent_rows(intent)
		intent_name = _intent_display_name(intent)
		var line_count: int = rows.size() + (1 if not intent_name.is_empty() else 0)
		if font != null and line_count > 0:
			var popup_width: float = _enemy_intent_popup_width(intent, rows, font)
			intent_rect = _enemy_intent_rect_for_line_count(center, health_rect, line_count, popup_width)
			border = _intent_color(intent)
	var base_rects: Array[Rect2] = _enemy_hud_collision_rects(unit, health_rect, intent_rect)
	var offset: Vector2 = _best_enemy_hud_offset(base_rects, occupied_rects)
	health_rect.position += offset
	intent_rect.position += offset
	return {
		"health_rect": health_rect,
		"intent_rect": intent_rect,
		"rows": rows,
		"intent_name": intent_name,
		"border": border,
		"offset": offset,
		"occupied_rects": _enemy_hud_collision_rects(unit, health_rect, intent_rect)
	}

func _enemy_hud_collision_rects(unit: Dictionary, health_rect: Rect2, intent_rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = _health_bar_collision_rects(unit, health_rect)
	if intent_rect.size.x > 0.0 and intent_rect.size.y > 0.0:
		rects.append(intent_rect)
	return rects

func _health_bar_collision_rects(unit: Dictionary, health_rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if health_rect.size.x > 0.0 and health_rect.size.y > 0.0:
		rects.append(health_rect)
	rects.append_array(_unit_status_badge_rects(unit, health_rect))
	rects.append_array(_health_bar_defense_badge_rects(unit, health_rect))
	return rects

func _unit_status_badge_rects(unit: Dictionary, health_rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var badges: Array[Dictionary] = _unit_status_badges(unit)
	if badges.is_empty():
		return rects
	var spacing: float = 22.0
	var start_x: float = health_rect.position.x - 12.0 - (float(badges.size() - 1) * spacing)
	var center_y: float = health_rect.position.y + health_rect.size.y - 2.0
	for index: int in range(badges.size()):
		var center := Vector2(start_x + float(index) * spacing, center_y)
		var badge_rect := Rect2(center - Vector2(10.0, 10.0), Vector2(20.0, 20.0))
		if int((badges[index] as Dictionary).get("count", 0)) > 0:
			badge_rect = badge_rect.merge(Rect2(center + Vector2(5.0, 3.0), Vector2(12.0, 12.0)))
		rects.append(badge_rect)
	return rects

func _health_bar_defense_badge_rects(unit: Dictionary, health_rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var defense_badge_x: float = health_rect.position.x + health_rect.size.x + 4.0
	if int(unit.get("block", 0)) > 0:
		var block_rect := Rect2(Vector2(defense_badge_x, health_rect.position.y), Vector2(36.0, 16.0))
		rects.append(block_rect)
		defense_badge_x += block_rect.size.x + 4.0
	if int(unit.get("stoneskin", 0)) > 0:
		rects.append(Rect2(Vector2(defense_badge_x, health_rect.position.y), Vector2(40.0, 16.0)))
	return rects

func _best_enemy_hud_offset(base_rects: Array, occupied_rects: Array) -> Vector2:
	if base_rects.is_empty():
		return Vector2.ZERO
	var viewport_bounds := Rect2(
		Vector2(ENEMY_HUD_VIEWPORT_MARGIN, ENEMY_HUD_VIEWPORT_MARGIN),
		Vector2(
			maxf(1.0, size.x - ENEMY_HUD_VIEWPORT_MARGIN * 2.0),
			maxf(1.0, size.y - ENEMY_HUD_VIEWPORT_MARGIN * 2.0)
		)
	)
	var hud_bounds: Rect2 = _rects_bounds(base_rects)
	var candidate_x_steps: Array = ENEMY_HUD_OFFSET_X_STEPS.duplicate()
	var wide_step: float = ceilf(hud_bounds.size.x + 8.0)
	if wide_step > 72.0:
		if not candidate_x_steps.has(-wide_step):
			candidate_x_steps.append(-wide_step)
		if not candidate_x_steps.has(wide_step):
			candidate_x_steps.append(wide_step)
	var candidate_y_steps: Array = ENEMY_HUD_OFFSET_Y_STEPS.duplicate()
	var tall_step: float = -ceilf(hud_bounds.size.y + 12.0)
	if absf(tall_step) > 72.0 and not candidate_y_steps.has(tall_step):
		candidate_y_steps.append(tall_step)
	var top_escape_step: float = ceilf(viewport_bounds.position.y - hud_bounds.position.y)
	if top_escape_step > 0.0 and not candidate_y_steps.has(top_escape_step):
		candidate_y_steps.append(top_escape_step)
	var bottom_escape_step: float = -ceilf(hud_bounds.end.y - viewport_bounds.end.y)
	if bottom_escape_step < 0.0 and not candidate_y_steps.has(bottom_escape_step):
		candidate_y_steps.append(bottom_escape_step)
	var best_offset := Vector2.ZERO
	var best_score: float = INF
	for y_step_var: Variant in candidate_y_steps:
		for x_step_var: Variant in candidate_x_steps:
			var offset := Vector2(float(x_step_var), float(y_step_var))
			var candidate_rects: Array[Rect2] = _offset_rects(base_rects, offset)
			var score: float = _enemy_hud_layout_score(candidate_rects, occupied_rects, viewport_bounds, offset)
			if score < best_score:
				best_score = score
				best_offset = offset
	return best_offset

func _offset_rects(rects: Array[Rect2], offset: Vector2) -> Array[Rect2]:
	var shifted: Array[Rect2] = []
	for rect: Rect2 in rects:
		shifted.append(Rect2(rect.position + offset, rect.size))
	return shifted

func _enemy_hud_layout_score(candidate_rects: Array, occupied_rects: Array, viewport_bounds: Rect2, offset: Vector2) -> float:
	var overlap_area: float = 0.0
	for candidate_var: Variant in candidate_rects:
		if typeof(candidate_var) != TYPE_RECT2:
			continue
		var candidate: Rect2 = candidate_var
		for occupied_var: Variant in occupied_rects:
			if typeof(occupied_var) != TYPE_RECT2:
				continue
			overlap_area += _rect_overlap_area(candidate, occupied_var)
	var overflow_area: float = 0.0
	for candidate_var: Variant in candidate_rects:
		if typeof(candidate_var) != TYPE_RECT2:
			continue
		overflow_area += _rect_outside_area(candidate_var, viewport_bounds)
	return overlap_area * 100000.0 + overflow_area * 5000.0 + absf(offset.x) * 2.4 + absf(offset.y) * 1.6

func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left: float = maxf(a.position.x, b.position.x)
	var top: float = maxf(a.position.y, b.position.y)
	var right: float = minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var bottom: float = minf(a.position.y + a.size.y, b.position.y + b.size.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)

func _rect_outside_area(rect: Rect2, bounds: Rect2) -> float:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 0.0
	var inside_left: float = maxf(rect.position.x, bounds.position.x)
	var inside_top: float = maxf(rect.position.y, bounds.position.y)
	var inside_right: float = minf(rect.position.x + rect.size.x, bounds.position.x + bounds.size.x)
	var inside_bottom: float = minf(rect.position.y + rect.size.y, bounds.position.y + bounds.size.y)
	var inside_area: float = 0.0
	if inside_right > inside_left and inside_bottom > inside_top:
		inside_area = (inside_right - inside_left) * (inside_bottom - inside_top)
	return rect.size.x * rect.size.y - inside_area

func _rects_bounds(rects: Array) -> Rect2:
	var bounds := Rect2()
	var found_rect: bool = false
	for rect_var: Variant in rects:
		if typeof(rect_var) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_var
		if not found_rect:
			bounds = rect
			found_rect = true
			continue
		bounds = bounds.merge(rect)
	return bounds

func _draw_enemy_hud_tether(unit: Dictionary, center: Vector2, layout: Dictionary) -> void:
	var offset: Vector2 = layout.get("offset", Vector2.ZERO)
	if offset.length_squared() < 4.0:
		return
	var health_rect: Rect2 = layout.get("health_rect", Rect2())
	if health_rect.size.x <= 0.0 or health_rect.size.y <= 0.0:
		return
	var border: Color = layout.get("border", Color("d8b96f"))
	var anchor: Vector2 = Vector2(center.x, _unit_art_top_y(unit, center) - UNIT_ART_HUD_CLEARANCE * 0.4)
	var target: Vector2 = Vector2(health_rect.position.x + health_rect.size.x * 0.5, health_rect.position.y + health_rect.size.y)
	draw_line(anchor, target, Color(0.0, 0.0, 0.0, 0.24), 3.0, true)
	draw_line(anchor, target, Color(border.r, border.g, border.b, 0.58), 1.0, true)

func _draw_keyword_icon(icon_key: String, rect: Rect2, tooltip: String = "", tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = _keyword_icon_textures.get(icon_key, null)
	if texture != null:
		draw_texture_rect(texture, rect, false, tint)
	else:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.22), true)
	if not tooltip.is_empty():
		_register_tooltip(rect, tooltip)

func _register_tooltip(rect: Rect2, tooltip: String) -> void:
	if tooltip.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_tooltip_regions.append({
		"rect": rect,
		"tooltip": tooltip
	})

func _token_value_color(token: Dictionary, default_color: Color) -> Color:
	match str(token.get("tone", "neutral")):
		"bonus":
			return Color("78c46a")
		"penalty":
			return Color("d46c62")
		_:
			return default_color

func _draw_status_text() -> void:
	if status_label.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(22.0, 30.0), status_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("f4ebd7"))
	if not status_detail.is_empty():
		draw_string(font, Vector2(22.0, 54.0), status_detail, HORIZONTAL_ALIGNMENT_LEFT, size.x - 44.0, 14, Color("d8ccb6"))

func _draw_target_reticle(center: Vector2, color: Color, radius: float = 10.0) -> void:
	draw_circle(center, radius * 0.28, Color(color.r, color.g, color.b, color.a * 0.30))
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.2)
	draw_line(center + Vector2(-radius - 3.0, 0.0), center + Vector2(-radius * 0.35, 0.0), color, 2.0)
	draw_line(center + Vector2(radius + 3.0, 0.0), center + Vector2(radius * 0.35, 0.0), color, 2.0)
	draw_line(center + Vector2(0.0, -radius - 3.0), center + Vector2(0.0, -radius * 0.35), color, 2.0)
	draw_line(center + Vector2(0.0, radius + 3.0), center + Vector2(0.0, radius * 0.35), color, 2.0)

func _draw_projectile_diamond(center: Vector2, direction: Vector2, color: Color, size: float = 5.0) -> void:
	var dir: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		center + dir * size,
		center + perp * size * 0.6,
		center - dir * size,
		center - perp * size * 0.6
	]), color)

func _draw_bezier_glow(from_point: Vector2, control: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	_draw_partial_bezier_glow(from_point, control, to_point, color, width, 1.0)

func _draw_partial_bezier_glow(from_point: Vector2, control: Vector2, to_point: Vector2, color: Color, width: float, progress: float) -> void:
	var points: Array[Vector2] = _sample_quadratic_points(from_point, control, to_point, 10)
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if points.size() < 2 or clamped_progress <= 0.0:
		return
	var segment_count: int = mini(points.size() - 1, maxi(1, int(ceil(float(points.size() - 1) * clamped_progress))))
	for idx: int in range(segment_count):
		var segment_alpha: float = color.a * (0.40 + 0.60 * float(idx + 1) / float(segment_count))
		draw_line(points[idx], points[idx + 1], Color(0.0, 0.0, 0.0, segment_alpha * 0.18), width + 2.0, true)
		draw_line(points[idx], points[idx + 1], Color(color.r, color.g, color.b, segment_alpha), width, true)

func _quadratic_bezier(from_point: Vector2, control: Vector2, to_point: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * from_point + 2.0 * u * t * control + t * t * to_point

func _sample_quadratic_points(from_point: Vector2, control: Vector2, to_point: Vector2, segments: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var safe_segments: int = maxi(1, segments)
	for idx: int in range(safe_segments + 1):
		var t: float = float(idx) / float(safe_segments)
		out.append(_quadratic_bezier(from_point, control, to_point, t))
	return out

func _arc_control_point(from_point: Vector2, to_point: Vector2) -> Vector2:
	var midpoint: Vector2 = (from_point + to_point) * 0.5
	var height: float = 34.0 + absf(to_point.x - from_point.x) * 0.18
	return midpoint + Vector2(0.0, -height)

func _draw_effect_overlay() -> void:
	var effect: Dictionary = presentation.get("effect", {})
	if effect.is_empty():
		return
	var kind: String = str(effect.get("kind", ""))
	var progress: float = clampf(float(presentation.get("effect_progress", 1.0)), 0.0, 1.0)
	var from_tile: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	var center_tile: Vector2i = effect.get("center", to_tile)
	var from_point: Vector2 = _tile_center(from_tile) if from_tile.x >= 0 else Vector2.ZERO
	var to_point: Vector2 = _tile_center(to_tile) if to_tile.x >= 0 else Vector2.ZERO
	var center_point: Vector2 = _tile_center(center_tile) if center_tile.x >= 0 else Vector2.ZERO
	match kind:
		"move":
			return
		"blink":
			if from_tile.x < 0 or to_tile.x < 0:
				return
			var blink_point: Vector2 = from_point.lerp(to_point, progress)
			draw_line(from_point + Vector2(0.0, -10.0), blink_point + Vector2(0.0, -10.0), Color("bdb5ff"), 3.0, true)
			draw_arc(from_point, _tile_width() * 0.16, 0.0, TAU, 16, Color("c6bdff"), 2.0)
			draw_arc(blink_point, _tile_width() * 0.16, 0.0, TAU, 16, Color("c6bdff"), 2.0)
		"ranged":
			if from_tile.x < 0 or to_tile.x < 0:
				return
			var start: Vector2 = from_point + Vector2(0.0, -24.0)
			var end: Vector2 = to_point + Vector2(0.0, -24.0)
			var control: Vector2 = _arc_control_point(start, end)
			var warmup_progress: float = clampf(progress / 0.34, 0.0, 1.0)
			var pulse_radius: float = lerpf(9.0, 17.0, warmup_progress)
			draw_circle(end, pulse_radius, Color(1.0, 0.60, 0.34, 0.08 + 0.05 * warmup_progress))
			_draw_target_reticle(end, Color(1.0, 0.86, 0.66, 0.62 + 0.28 * warmup_progress), pulse_radius)
			_draw_bezier_glow(start, control, end, Color(1.0, 0.74, 0.37, 0.16 + 0.10 * warmup_progress), 1.6)
			var travel_progress: float = clampf((progress - 0.18) / 0.48, 0.0, 1.0)
			if travel_progress > 0.0:
				_draw_partial_bezier_glow(start, control, end, Color(1.0, 0.74, 0.37, 0.94), 3.0, travel_progress)
				var projectile_point: Vector2 = _quadratic_bezier(start, control, end, travel_progress)
				_draw_projectile_diamond(projectile_point, control - start, Color(1.0, 0.92, 0.70, 0.98), 5.2)
				draw_circle(start, 5.0, Color(1.0, 0.88, 0.68, 0.16))
			if progress >= 0.98:
				draw_circle(to_point, 12.0, Color(0.94, 0.47, 0.30, 0.20))
		"melee":
			if to_tile.x < 0:
				return
			var slash_center: Vector2 = from_point.lerp(to_point, 0.20 + progress * 0.62)
			var melee_size: float = _tile_width() * (0.12 + progress * 0.14)
			draw_line(slash_center + Vector2(-melee_size, -melee_size), slash_center + Vector2(melee_size, melee_size), Color("f2c996"), 5.0, true)
			draw_line(slash_center + Vector2(melee_size, -melee_size), slash_center + Vector2(-melee_size, melee_size), Color("f2c996"), 5.0, true)
		"aoe":
			var effect_tiles: Array[Vector2i] = _vector2i_array(effect.get("tiles", []))
			if effect_tiles.is_empty() and center_tile.x >= 0:
				effect_tiles = [center_tile]
			var warm_alpha: float = 0.18 + progress * 0.18
			for tile: Vector2i in effect_tiles:
				var tile_point: Vector2 = _tile_center(tile)
				draw_arc(tile_point, _tile_width() * (0.18 + progress * 0.10), 0.0, TAU, 18, Color(0.96, 0.50, 0.30, 0.52 + progress * 0.28), 3.0)
				draw_circle(tile_point, _tile_width() * 0.13, Color(1.0, 0.35, 0.18, warm_alpha))
		"block":
			var block_tile: Vector2i = effect.get("tile", Vector2i(-1, -1))
			if block_tile.x < 0:
				return
			draw_arc(_tile_center(block_tile) + Vector2(0.0, -22.0), _tile_width() * 0.22, 0.0, TAU, 22, Color("6dd0ff"), 4.0)
		"heal":
			var heal_tile: Vector2i = effect.get("tile", Vector2i(-1, -1))
			if heal_tile.x < 0:
				return
			var heal_center: Vector2 = _tile_center(heal_tile) + Vector2(0.0, -28.0)
			draw_line(heal_center + Vector2(-10.0, 0.0), heal_center + Vector2(10.0, 0.0), Color("9ee27e"), 4.0, true)
			draw_line(heal_center + Vector2(0.0, -10.0), heal_center + Vector2(0.0, 10.0), Color("9ee27e"), 4.0, true)

func _draw_floating_texts() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	for entry_var: Variant in presentation.get("floating_texts", []):
		var entry: Dictionary = entry_var
		var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var rise: float = float(entry.get("rise", 0.0))
		var text_pos: Vector2 = _tile_center(tile) + Vector2(-18.0, -84.0 + float(entry.get("offset", 0.0)) - rise)
		var color: Color = entry.get("color", Color("f8f0da"))
		color.a *= clampf(float(entry.get("alpha", 1.0)), 0.0, 1.0)
		draw_string(font, text_pos, str(entry.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, 48.0, 16, color)

func _draw_path_preview() -> void:
	var path_tiles: Array[Vector2i] = _vector2i_array(presentation.get("path_tiles", []))
	if path_tiles.is_empty():
		return
	var color: Color = presentation.get("path_color", MOVE_PATH_COLOR)
	var point_offset := Vector2(0.0, -8.0)
	if path_tiles.size() == 1:
		draw_circle(_tile_center(path_tiles[0]) + point_offset, 6.0, Color(color.r, color.g, color.b, 0.82))
		return
	for index: int in range(path_tiles.size() - 1):
		var from_point: Vector2 = _tile_center(path_tiles[index]) + point_offset
		var to_point: Vector2 = _tile_center(path_tiles[index + 1]) + point_offset
		draw_line(from_point, to_point, Color(0.0, 0.0, 0.0, 0.18), 6.0, true)
		draw_line(from_point, to_point, color, 3.0, true)
	for tile: Vector2i in path_tiles:
		draw_circle(_tile_center(tile) + point_offset, 4.5, Color(0.08, 0.07, 0.05, 0.9))
		draw_circle(_tile_center(tile) + point_offset, 3.0, color)

func _draw_unit_focus(unit: Dictionary, center: Vector2) -> void:
	var focus_keys: Array = presentation.get("focus_actor_keys", [])
	if not focus_keys.has(str(unit.get("key", ""))):
		return
	var points := PackedVector2Array()
	var color: Color = presentation.get("focus_actor_color", PLAYER_FOCUS_COLOR)
	var focus_center: Vector2 = center + Vector2(0.0, -10.0)
	for step: int in range(18):
		var angle: float = TAU * float(step) / 18.0
		points.append(focus_center + Vector2(cos(angle) * _tile_width() * 0.24, sin(angle) * _tile_height() * 0.32))
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.14))
	draw_polyline(points, color, 2.0, true)

func _effective_unit_tile(unit: Dictionary) -> Vector2i:
	var actor_key: String = str(unit.get("key", ""))
	if not actor_key.is_empty():
		var overrides: Dictionary = presentation.get("unit_draw_tiles", {})
		if overrides.has(actor_key):
			return overrides[actor_key]
	return unit.get("pos", Vector2i.ZERO)

func _nearest_tile_for_world_position(world_position: Vector2) -> Vector2i:
	var grid: Array = combat_state.get("grid", [])
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_distance_sq: float = INF
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile: Vector2i = Vector2i(x, y)
			var distance_sq: float = _tile_center(tile).distance_squared_to(world_position)
			if distance_sq >= best_distance_sq:
				continue
			best_distance_sq = distance_sq
			best_tile = tile
	return best_tile if best_tile.x >= 0 else Vector2i.ZERO

func _tile_color(tile_id: String) -> Color:
	match tile_id:
		"ember":
			return Color("874d36")
		"wall":
			return Color("4a3930")
		"pillar":
			return Color("5d4f47")
		_:
			return Color("75695f")

func _floor_texture_key(tile_id: String) -> String:
	match tile_id:
		"ember":
			return "ember"
		"door":
			return "ash"
		"wall":
			return "ash"
		"pillar":
			return "ash"
		_:
			return "ash"

func _floor_texture_for_tile(tile_id: String, tile: Vector2i) -> Texture2D:
	var texture_key: String = _floor_texture_key(tile_id)
	var variants: Array = _floor_texture_variants.get(texture_key, [])
	if not variants.is_empty():
		var variant_index: int = int(_floor_variant_by_tile.get(tile, 0))
		if variant_index >= 0 and variant_index < variants.size():
			return variants[variant_index]
		return variants[0]
	return _tile_textures.get(texture_key, null)

func _build_floor_variant_lookup(grid: Array) -> Dictionary:
	var lookup: Dictionary = {}
	var ash_variants: Array = _floor_texture_variants.get("ash", [])
	var variant_count: int = ash_variants.size()
	if variant_count <= 1:
		return lookup
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			if _floor_texture_key(str(row[x])) != "ash":
				continue
			var tile := Vector2i(x, y)
			var variant_index: int = _hashed_floor_variant_index(tile, room_coord, variant_count)
			var left_tile := Vector2i(x - 1, y)
			var up_tile := Vector2i(x, y - 1)
			if lookup.has(left_tile) and int(lookup.get(left_tile, -1)) == variant_index:
				variant_index = (variant_index + 1 + posmod(room_coord.x + y, maxi(1, variant_count - 1))) % variant_count
			if lookup.has(up_tile) and int(lookup.get(up_tile, -1)) == variant_index:
				variant_index = (variant_index + 2 + posmod(room_coord.y + x, maxi(1, variant_count - 1))) % variant_count
				if variant_count > 2 and lookup.has(left_tile) and int(lookup.get(left_tile, -1)) == variant_index:
					variant_index = (variant_index + 1) % variant_count
			lookup[tile] = variant_index
	return lookup

func _hashed_floor_variant_index(tile: Vector2i, room_coord: Vector2i, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	var mixed: int = tile.x * 92821
	mixed += tile.y * 68917
	mixed += room_coord.x * 1237
	mixed += room_coord.y * 1999
	mixed += tile.x * tile.y * 17
	mixed += (tile.x - tile.y) * 53
	mixed += (room_coord.x + room_coord.y) * 31
	return posmod(mixed, variant_count)

func _build_moss_tile_lookup(moss: Dictionary) -> Dictionary:
	var lookup: Dictionary = {
		"floor": {},
		"wall": {},
		"pillar": {}
	}
	for surface: String in ["floor", "wall", "pillar"]:
		var surface_lookup: Dictionary = {}
		for tile_var: Variant in moss.get(surface, []):
			if typeof(tile_var) == TYPE_VECTOR2I:
				surface_lookup[tile_var] = true
		lookup[surface] = surface_lookup
	return lookup

func _tile_has_moss(surface: String, tile: Vector2i) -> bool:
	var surface_lookup: Dictionary = _moss_tiles_by_surface.get(surface, {})
	return surface_lookup.has(tile)

func _moss_texture_for_surface(surface: String, tile: Vector2i, flip_override: bool = false) -> Texture2D:
	var variants: Array = _moss_texture_variants.get(surface, [])
	if variants.is_empty():
		return null
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	var variant_index: int = _hashed_moss_variant_index(tile, room_coord, surface, variants.size())
	var texture: Texture2D = variants[variant_index]
	var should_flip: bool = _should_flip_moss_h(tile, room_coord, surface)
	if flip_override:
		should_flip = not should_flip
	return AssetLoader.flip_texture_h(texture) if should_flip else texture

func _hashed_moss_variant_index(tile: Vector2i, room_coord: Vector2i, surface: String, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	return posmod(_hashed_moss_value(tile, room_coord, surface, 0), variant_count)

func _should_flip_moss_h(tile: Vector2i, room_coord: Vector2i, surface: String) -> bool:
	return posmod(_hashed_moss_value(tile, room_coord, surface, 211), 2) == 0

func _hashed_moss_value(tile: Vector2i, room_coord: Vector2i, surface: String, salt: int) -> int:
	var surface_salt: int = 97
	match surface:
		"wall":
			surface_salt = 173
		"pillar":
			surface_salt = 251
	var mixed: int = tile.x * 92821
	mixed += tile.y * 68917
	mixed += room_coord.x * 1237
	mixed += room_coord.y * 1999
	mixed += tile.x * tile.y * 29
	mixed += (tile.x - tile.y) * 61
	mixed += (room_coord.x + room_coord.y) * 37
	mixed += surface_salt + salt
	return mixed

func _wall_orientation_for_tile(grid: Array, tile: Vector2i) -> String:
	if not _is_outer_boundary_tile(grid, tile):
		return ""
	if tile.y == 0 or tile.y == grid.size() - 1:
		return "row"
	if tile.x == 0 or tile.x == (grid[0] as Array).size() - 1:
		return "col"
	return ""

func _wall_moss_rect(draw_rect: Rect2) -> Rect2:
	var width: float = draw_rect.size.x
	var height: float = draw_rect.size.y * 0.54
	return Rect2(
		Vector2(draw_rect.get_center().x - width * 0.5, draw_rect.position.y + draw_rect.size.y * 0.02),
		Vector2(width, height)
	)

func _pillar_moss_rect(draw_rect: Rect2) -> Rect2:
	var width: float = draw_rect.size.x * 0.96
	var height: float = draw_rect.size.y * 0.52
	return Rect2(
		Vector2(
			draw_rect.get_center().x - width * 0.5 + draw_rect.size.x * PILLAR_MOSS_OFFSET_X_SCALE,
			draw_rect.position.y + draw_rect.size.y * PILLAR_MOSS_OFFSET_Y_SCALE
		),
		Vector2(width, height)
	)

func _door_icon_texture(icon_id: String) -> Texture2D:
	if icon_id.is_empty():
		return null
	if not _door_icon_textures.has(icon_id):
		_door_icon_textures[icon_id] = RoomIcons.icon_texture(icon_id)
	return _door_icon_textures.get(icon_id, null)

func _load_assets() -> void:
	var ash_floor_variants: Array[Texture2D] = _load_floor_variants(ASH_FLOOR_VARIANT_PATHS)
	var moss_floor_variants: Array[Texture2D] = _load_floor_variants(MOSS_FLOOR_OVERLAY_PATHS)
	var moss_wall_variants: Array[Texture2D] = _load_floor_variants(MOSS_WALL_OVERLAY_PATHS)
	var moss_pillar_variants: Array[Texture2D] = _load_floor_variants(MOSS_PILLAR_OVERLAY_PATHS)
	_tile_textures = {
		"ash": ash_floor_variants[0] if not ash_floor_variants.is_empty() else AssetLoader.load_texture("res://assets/art/tiles/ash.png"),
		"ember": AssetLoader.load_texture("res://assets/art/tiles/ember.png")
	}
	_floor_texture_variants = {
		"ash": ash_floor_variants
	}
	_moss_texture_variants = {
		"floor": moss_floor_variants,
		"wall": moss_wall_variants,
		"pillar": moss_pillar_variants
	}
	var pillar_texture: Texture2D = AssetLoader.trim_texture_to_used_rect(AssetLoader.load_texture("res://assets/placeholders/tiles/pillar.png"))
	var wall_row_texture: Texture2D = AssetLoader.trim_texture_to_used_rect(AssetLoader.load_texture("res://assets/placeholders/tiles/wall.png"))
	var door_texture: Texture2D = AssetLoader.load_texture("res://assets/placeholders/tiles/door.png")
	_prop_textures = {
		"pillar": pillar_texture,
		"wall": wall_row_texture,
		"wall_row": wall_row_texture,
		"wall_col": AssetLoader.flip_texture_h(wall_row_texture),
		"door": door_texture,
		"door_row": door_texture,
		"door_col": AssetLoader.flip_texture_h(door_texture)
	}
	_scene_prop_textures = {
		"campfire_bonfire": AssetLoader.load_texture(CAMPFIRE_BONFIRE_PATH)
	}
	_door_opening_frames = _load_door_opening_frames()
	_door_opening_flipped_frames = []
	for frame_texture: Texture2D in _door_opening_frames:
		_door_opening_flipped_frames.append(AssetLoader.flip_texture_h(frame_texture))
	_loot_textures = {
		"healing_vial": AssetLoader.load_texture("res://assets/art/tiles/healing_vial.png"),
		"ember_cache": AssetLoader.load_texture("res://assets/art/tiles/ember_cache.png")
	}
	_element_textures.clear()
	for element_id: String in ElementData.all_elements():
		_element_textures[element_id] = AssetLoader.load_texture(ElementData.icon_path(element_id))
	_trap_textures.clear()
	for element_id: String in ElementData.all_elements():
		_trap_textures[element_id] = AssetLoader.load_texture("res://assets/art/traps/trap_%s.png" % element_id)
	_door_icon_textures.clear()
	for icon_id: String in RoomIcons.all_icon_ids():
		_door_icon_textures[icon_id] = RoomIcons.icon_texture(icon_id)
	_keyword_icon_textures.clear()
	for icon_key_var: Variant in ActionIcons.all_icon_keys():
		var icon_key: String = str(icon_key_var)
		_keyword_icon_textures[icon_key] = ActionIcons.icon_texture(icon_key)
	_unit_textures.clear()
	_idle_frames_by_type.clear()
	_unit_textures["player"] = _load_unit_texture_with_idle("player", "res://assets/placeholders/units/player_reaver.png")
	for enemy_type: String in GameData.enemies().keys():
		var art_path: String = str(GameData.enemy_def(enemy_type).get("art_path", ""))
		_unit_textures[enemy_type] = _load_unit_texture_with_idle(enemy_type, art_path)
	for npc_id: String in GameData.npcs().keys():
		var art_path: String = str(GameData.npc_def(npc_id).get("art_path", ""))
		_unit_textures[npc_id] = _load_unit_texture_with_idle(npc_id, art_path)

func _load_floor_variants(paths: PackedStringArray) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path: String in paths:
		var texture: Texture2D = AssetLoader.load_texture(path)
		if texture == null:
			continue
		textures.append(texture)
	return textures

func _load_door_opening_frames() -> Array[Texture2D]:
	var sheet: Texture2D = AssetLoader.load_texture(DOOR_OPENING_SHEET_PATH)
	if sheet == null:
		return []
	var sheet_image: Image = sheet.get_image()
	if sheet_image == null or sheet_image.is_empty():
		return []
	var canvas_size: Vector2i = _door_opening_frame_canvas_size()
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return []
	var frames: Array[Texture2D] = []
	for region: Rect2i in DOOR_OPENING_FRAME_REGIONS:
		var frame_image := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
		frame_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var frame_position := Vector2i(canvas_size.x - region.size.x, canvas_size.y - region.size.y)
		frame_image.blit_rect(sheet_image, region, frame_position)
		frames.append(ImageTexture.create_from_image(frame_image))
	return frames

func _door_opening_frame_canvas_size() -> Vector2i:
	var canvas_size := Vector2i.ZERO
	for region: Rect2i in DOOR_OPENING_FRAME_REGIONS:
		canvas_size.x = maxi(canvas_size.x, region.size.x)
		canvas_size.y = maxi(canvas_size.y, region.size.y)
	return canvas_size

func _texture_for_unit(unit: Dictionary) -> Texture2D:
	var idle_frames: Array[Texture2D] = _unit_idle_frames(unit)
	if _unit_idle_animation_active(unit) and not idle_frames.is_empty():
		return idle_frames[_idle_frame_index(unit)]
	return _unit_textures.get(str(unit.get("type", "")), null)

func _load_unit_texture_with_idle(unit_type: String, art_path: String) -> Texture2D:
	var texture: Texture2D = AssetLoader.load_texture(art_path)
	var idle_frames: Array[Texture2D] = _load_idle_frames_for_art_path(unit_type, art_path)
	if not idle_frames.is_empty():
		_idle_frames_by_type[unit_type] = idle_frames
		if texture == null:
			return idle_frames[0]
	return texture

func _load_idle_frames_for_art_path(unit_type: String, art_path: String) -> Array[Texture2D]:
	var idle_frames: Array[Texture2D] = []
	if art_path.is_empty():
		return idle_frames
	var idle_sheet: Texture2D = AssetLoader.load_texture_by_stem("%s_idle" % art_path.get_basename(), AssetLoader.PNG_FIRST_TEXTURE_EXTENSIONS)
	if idle_sheet == null:
		return idle_frames
	var idle_layout: Dictionary = _unit_idle_sheet_layout(unit_type)
	var frame_size := Vector2i(
		int(idle_sheet.get_width() / int(idle_layout.get("columns", IDLE_SHEET_COLUMNS))),
		int(idle_sheet.get_height() / int(idle_layout.get("rows", IDLE_SHEET_ROWS)))
	)
	return AssetLoader.build_sprite_sheet_frames(idle_sheet, frame_size, _idle_frame_indices(idle_layout))

func _unit_idle_sheet_layout(unit_type: String) -> Dictionary:
	var definition: Dictionary = {}
	if unit_type != "player" and not unit_type.is_empty():
		definition = GameData.npc_def(unit_type)
		if definition.is_empty():
			definition = GameData.enemy_def(unit_type)
	return {
		"columns": maxi(1, int(definition.get("idle_sheet_columns", IDLE_SHEET_COLUMNS))),
		"rows": maxi(1, int(definition.get("idle_sheet_rows", IDLE_SHEET_ROWS))),
		"order": str(definition.get("idle_sheet_order", IDLE_SHEET_ORDER_ROW_MAJOR))
	}

func _idle_frame_indices(layout: Dictionary) -> Array:
	var columns: int = maxi(1, int(layout.get("columns", IDLE_SHEET_COLUMNS)))
	var rows: int = maxi(1, int(layout.get("rows", IDLE_SHEET_ROWS)))
	var order: String = str(layout.get("order", IDLE_SHEET_ORDER_ROW_MAJOR))
	var frame_indices: Array = []
	if order == IDLE_SHEET_ORDER_COLUMN_MAJOR:
		for column: int in range(columns):
			for row: int in range(rows):
				frame_indices.append(row * columns + column)
		return frame_indices
	for row: int in range(rows):
		for column: int in range(columns):
			frame_indices.append(row * columns + column)
	return frame_indices

func _unit_idle_frames(unit: Dictionary) -> Array[Texture2D]:
	var unit_type: String = str(unit.get("type", ""))
	if not _idle_frames_by_type.has(unit_type):
		return []
	return _idle_frames_by_type[unit_type]

func _idle_frame_index(unit: Dictionary) -> int:
	var idle_frames: Array[Texture2D] = _unit_idle_frames(unit)
	if idle_frames.is_empty():
		return 0
	return int(floor(_idle_elapsed / _unit_idle_frame_seconds(unit))) % idle_frames.size()

func _unit_idle_frame_seconds(unit: Dictionary) -> float:
	var unit_type: String = str(unit.get("type", ""))
	if unit_type == "player" or unit_type.is_empty():
		return IDLE_FRAME_SECONDS
	var definition: Dictionary = GameData.npc_def(unit_type)
	if definition.is_empty():
		definition = GameData.enemy_def(unit_type)
	return maxf(0.01, float(definition.get("idle_frame_seconds", IDLE_FRAME_SECONDS)))

func _active_idle_frame_seconds() -> float:
	var active_seconds: float = IDLE_FRAME_SECONDS
	var found_active_unit: bool = false
	for unit: Dictionary in _visible_units():
		if str(unit.get("role", "")) != "npc" and int(unit.get("hp", 0)) <= 0:
			continue
		if not _unit_idle_animation_active(unit):
			continue
		var unit_seconds: float = _unit_idle_frame_seconds(unit)
		if not found_active_unit or unit_seconds < active_seconds:
			active_seconds = unit_seconds
			found_active_unit = true
	return active_seconds

func _unit_idle_animation_active(unit: Dictionary) -> bool:
	if not visible or combat_state.is_empty() or _unit_idle_frames(unit).is_empty():
		return false
	var actor_key: String = str(unit.get("key", ""))
	if actor_key.is_empty():
		return false
	if (presentation.get("unit_world_positions", {}) as Dictionary).has(actor_key):
		return false
	var effect: Dictionary = presentation.get("effect", {})
	if effect.is_empty():
		return true
	var focus_actor_keys: Array = presentation.get("focus_actor_keys", [])
	return not focus_actor_keys.has(actor_key)

func _unit_draw_rect(unit: Dictionary) -> Rect2:
	return _unit_draw_rect_for_center(unit, _unit_center(unit))

func _unit_draw_rect_for_center(unit: Dictionary, center: Vector2) -> Rect2:
	var frame_rect: Rect2 = _unit_frame_rect(center)
	var texture: Texture2D = _texture_for_unit(unit)
	if texture == null:
		return frame_rect
	var draw_rect: Rect2 = _scaled_unit_rect(_fitted_unit_rect(texture, frame_rect), _unit_art_scale(unit))
	draw_rect.position += _unit_art_offset(unit)
	return draw_rect

func _unit_center(unit: Dictionary) -> Vector2:
	var unit_key: String = str(unit.get("key", ""))
	var overrides: Dictionary = presentation.get("unit_world_positions", {})
	if overrides.has(unit_key):
		return overrides[unit_key]
	return _tile_center(unit.get("pos", Vector2i.ZERO))

func _fitted_unit_rect(texture: Texture2D, frame_rect: Rect2) -> Rect2:
	return _fitted_draw_rect(texture, frame_rect)

func _fitted_prop_rect(texture: Texture2D, frame_rect: Rect2) -> Rect2:
	return _fitted_draw_rect(texture, frame_rect)

func _prop_draw_rect(texture: Texture2D, frame_rect: Rect2) -> Rect2:
	return _fitted_prop_rect(texture, frame_rect)

func _fitted_draw_rect(texture: Texture2D, frame_rect: Rect2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return frame_rect
	var scale_factor: float = minf(frame_rect.size.x / texture_size.x, frame_rect.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale_factor
	var draw_position := Vector2(
		frame_rect.position.x + (frame_rect.size.x - draw_size.x) * 0.5,
		frame_rect.position.y + frame_rect.size.y - draw_size.y
	)
	return Rect2(draw_position, draw_size)

func _scaled_unit_rect(rect: Rect2, scale: float) -> Rect2:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or is_equal_approx(scale, 1.0):
		return rect
	var scaled_size: Vector2 = rect.size * maxf(scale, 0.1)
	var scaled_position := Vector2(
		rect.position.x + (rect.size.x - scaled_size.x) * 0.5,
		rect.position.y + rect.size.y - scaled_size.y
	)
	return Rect2(scaled_position, scaled_size)

func _unit_art_scale(unit: Dictionary) -> float:
	var unit_type: String = str(unit.get("type", ""))
	if unit_type == "player" or unit_type.is_empty():
		return 1.0
	var npc_def: Dictionary = GameData.npc_def(unit_type)
	if not npc_def.is_empty():
		return float(npc_def.get("art_scale", 1.0))
	return float(GameData.enemy_def(unit_type).get("art_scale", 1.0))

func _unit_art_offset(unit: Dictionary) -> Vector2:
	var unit_type: String = str(unit.get("type", ""))
	if unit_type == "player" or unit_type.is_empty():
		return Vector2.ZERO
	var definition: Dictionary = GameData.npc_def(unit_type)
	if definition.is_empty():
		definition = GameData.enemy_def(unit_type)
	return Vector2(
		float(definition.get("art_offset_x", 0.0)),
		float(definition.get("art_offset_y", 0.0))
	)

func _tiles_in_draw_order(grid: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile := Vector2i(x, y)
			var tile_id: String = str((grid[y] as Array)[x])
			var display_tile_id: String = _display_tile_id(tile_id, tile)
			if _should_render_tile(display_tile_id, tile, grid):
				tiles.append(tile)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _tile_draws_before(a, b)
	)
	return tiles

func _rendered_tiles_in_draw_order() -> Array[Vector2i]:
	_ensure_board_layout_cache()
	return _board_layout_cache_tiles

func _tile_draws_before(a: Vector2i, b: Vector2i) -> bool:
	var a_score: int = a.x + a.y
	var b_score: int = b.x + b.y
	if a_score == b_score:
		return a.x < b.x
	return a_score < b_score

func _tile_center(tile: Vector2i) -> Vector2:
	var origin: Vector2 = _board_origin()
	var tile_width: float = _tile_width()
	var half_w: float = tile_width * 0.5
	var half_h: float = tile_width * 0.25
	return Vector2(
		origin.x + float(tile.x - tile.y) * half_w,
		origin.y + float(tile.x + tile.y) * half_h
	)

func _tile_step_offset(dir: Vector2i) -> Vector2:
	var tile_width: float = _tile_width()
	return Vector2(
		float(dir.x - dir.y) * tile_width * 0.5,
		float(dir.x + dir.y) * tile_width * 0.25
	)

func world_position_for_tile(tile: Vector2i) -> Vector2:
	return _tile_center(tile)

func _tile_polygon(tile: Vector2i) -> PackedVector2Array:
	var center: Vector2 = _tile_center(tile)
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	return PackedVector2Array([
		center + Vector2(0.0, -tile_height * 0.5),
		center + Vector2(tile_width * 0.5, 0.0),
		center + Vector2(0.0, tile_height * 0.5),
		center + Vector2(-tile_width * 0.5, 0.0),
		center + Vector2(0.0, -tile_height * 0.5)
	])

func _board_origin() -> Vector2:
	_ensure_board_layout_cache()
	return _board_layout_cache_origin

func _board_origin_for_extents(extents: Dictionary, tile_width: float) -> Vector2:
	var half_height: float = tile_width * 0.25
	var half_width: float = tile_width * 0.5
	var min_diag: float = float(extents.get("min_diag", -4.0))
	var max_diag: float = float(extents.get("max_diag", 4.0))
	var min_sum: float = float(extents.get("min_sum", 0.0))
	var content_width: float = _board_layout_width_units(extents) * tile_width
	var content_height: float = _board_layout_height_units(extents) * tile_width
	var available_width: float = maxf(1.0, size.x - BOARD_SIDE_MARGIN * 2.0)
	var available_height: float = maxf(1.0, size.y - BOARD_VERTICAL_MARGIN * 2.0)
	var content_left: float = BOARD_SIDE_MARGIN + maxf(0.0, (available_width - content_width) * 0.5)
	var content_top: float = BOARD_VERTICAL_MARGIN + maxf(0.0, (available_height - content_height) * BOARD_VERTICAL_BIAS)
	var target_center_x: float = content_left + content_width * 0.5
	var origin_x: float = target_center_x - ((min_diag + max_diag) * 0.5 * half_width)
	var origin_y: float = content_top + tile_width * BOARD_TOP_CLEARANCE_SCALE - min_sum * half_height
	return Vector2(origin_x, origin_y)

func _tile_at_point(point: Vector2) -> Vector2i:
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	for index: int in range(tiles.size() - 1, -1, -1):
		var tile: Vector2i = tiles[index]
		if Geometry2D.is_point_in_polygon(point, _tile_polygon(tile)):
			return tile
	return Vector2i(-1, -1)

func _draw_shadow(center: Vector2) -> void:
	var points := PackedVector2Array()
	var tile_width: float = _tile_width()
	var tile_height: float = tile_width * 0.5
	for step: int in range(18):
		var angle: float = TAU * float(step) / 18.0
		points.append(center + Vector2(cos(angle) * tile_width * 0.20, sin(angle) * tile_height * 0.17))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.18))

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _tile_width() -> float:
	_ensure_board_layout_cache()
	return _board_layout_cache_tile_width

func _tile_width_for_extents(extents: Dictionary) -> float:
	var width_units: float = _board_layout_width_units(extents)
	var height_units: float = _board_layout_height_units(extents)
	var available_width: float = maxf(1.0, size.x - BOARD_SIDE_MARGIN * 2.0)
	var available_height: float = maxf(1.0, size.y - BOARD_VERTICAL_MARGIN * 2.0)
	var width_based: float = available_width / maxf(1.0, width_units)
	var height_based: float = available_height / maxf(1.0, height_units)
	return clampf(minf(width_based, height_based), 90.0, BOARD_MAX_TILE_WIDTH)

func _board_layout_width_units(extents: Dictionary) -> float:
	var diag_span: float = maxf(0.0, float(extents.get("max_diag", 4.0)) - float(extents.get("min_diag", -4.0)))
	return diag_span * 0.5 + 1.0

func _board_layout_height_units(extents: Dictionary) -> float:
	var sum_span: float = maxf(0.0, float(extents.get("max_sum", 14.0)) - float(extents.get("min_sum", 0.0)))
	return sum_span * 0.25 + BOARD_TOP_CLEARANCE_SCALE + BOARD_BOTTOM_CLEARANCE_SCALE

func _board_layout_extents() -> Dictionary:
	_ensure_board_layout_cache()
	return _board_layout_cache_extents

func _board_layout_extents_for_tiles(tiles: Array[Vector2i]) -> Dictionary:
	if tiles.is_empty():
		return {
			"min_diag": -4.0,
			"max_diag": 4.0,
			"min_sum": 0.0,
			"max_sum": 14.0
		}
	var min_diag: int = tiles[0].x - tiles[0].y
	var max_diag: int = min_diag
	var min_sum: int = tiles[0].x + tiles[0].y
	var max_sum: int = min_sum
	for tile: Vector2i in tiles:
		var diag: int = tile.x - tile.y
		var sum: int = tile.x + tile.y
		min_diag = mini(min_diag, diag)
		max_diag = maxi(max_diag, diag)
		min_sum = mini(min_sum, sum)
		max_sum = maxi(max_sum, sum)
	return {
		"min_diag": min_diag,
		"max_diag": max_diag,
		"min_sum": min_sum,
		"max_sum": max_sum
	}

func _invalidate_board_layout_cache() -> void:
	_board_layout_cache_valid = false

func _ensure_board_layout_cache() -> void:
	if _board_layout_cache_valid and _board_layout_cache_size == size:
		return
	var grid: Array = combat_state.get("grid", [])
	var tiles: Array[Vector2i] = _tiles_in_draw_order(grid)
	var extents: Dictionary = _board_layout_extents_for_tiles(tiles)
	var tile_width: float = _tile_width_for_extents(extents)
	_board_layout_cache_size = size
	_board_layout_cache_tiles = tiles
	_board_layout_cache_extents = extents
	_board_layout_cache_tile_width = tile_width
	_board_layout_cache_origin = _board_origin_for_extents(extents, tile_width)
	_board_layout_cache_valid = true

func _tile_height() -> float:
	return _tile_width() * 0.5

func _unit_size() -> Vector2:
	var tile_width: float = _tile_width()
	return Vector2(tile_width * 1.03, tile_width * 1.32)

func _prop_size() -> Vector2:
	var tile_width: float = _tile_width()
	return Vector2(tile_width * 0.92, tile_width * 1.14)

func _intent_rows(intent: Dictionary) -> Array:
	var rows: Array = []
	for action_var: Variant in intent.get("actions", []):
		var action: Dictionary = action_var
		var row: Array = ActionIcons.tokens_for_action(action)
		if not row.is_empty():
			rows.append(row)
	return rows

func _intent_display_name(intent: Dictionary) -> String:
	return str(intent.get("name", "")).strip_edges()

func _enemy_intent_line_count(intent: Dictionary) -> int:
	var line_count: int = _intent_rows(intent).size()
	if not _intent_display_name(intent).is_empty():
		line_count += 1
	return line_count

func _intent_lines(intent: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = []
	for row_var: Variant in _intent_rows(intent):
		if typeof(row_var) == TYPE_ARRAY:
			parts.append(ActionIcons.plain_text_for_tokens(row_var as Array))
	return parts

func _intent_color(intent: Dictionary) -> Color:
	var element_id: String = str(intent.get("element", ElementData.NONE))
	if ElementData.is_elemental(element_id):
		return ElementData.accent(element_id)
	for action_var: Variant in intent.get("actions", []):
		var action_type: String = str((action_var as Dictionary).get("type", ""))
		if action_type in ["melee", "ranged", "aoe"]:
			return Color("d56a55")
		if action_type == "stoneskin":
			return ElementData.accent(ElementData.EARTH)
		if action_type == "block":
			return Color("7eb9d5")
		if action_type == "heal_self":
			return Color("90c86d")
	return Color("d8b96f")

func _unit_status_badges(unit: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	if int(unit.get("burn", 0)) > 0:
		badges.append({
			"icon": "burn",
			"count": int(unit.get("burn", 0)),
			"fill": STATUS_BURN,
			"border": STATUS_BURN.lightened(0.24)
		})
	if int(unit.get("freeze", 0)) > 0:
		badges.append({
			"icon": "freeze",
			"count": 0,
			"fill": STATUS_FREEZE,
			"border": STATUS_FREEZE.lightened(0.20)
		})
	if int(unit.get("shock", 0)) > 0:
		badges.append({
			"icon": "shock",
			"count": 0,
			"fill": STATUS_SHOCK,
			"border": STATUS_SHOCK.lightened(0.18)
		})
	if int(unit.get("stun", 0)) > 0:
		badges.append({
			"icon": "stun",
			"count": 0,
			"fill": STATUS_STUN,
			"border": STATUS_STUN.lightened(0.18)
		})
	var poison: Dictionary = unit.get("poison", {})
	if int(poison.get("damage", 0)) > 0 and int(poison.get("delay", 0)) > 0:
		badges.append({
			"icon": "poison",
			"count": int(poison.get("delay", 0)),
			"fill": STATUS_POISON,
			"border": STATUS_POISON.lightened(0.22)
		})
	return badges

func _player_display_statuses(player: Dictionary, restrictions: Dictionary) -> Dictionary:
	return {
		"burn": int(player.get("burn", 0)),
		"freeze": maxi(int(player.get("freeze", 0)), 1 if bool(restrictions.get("frozen", false)) else 0),
		"shock": maxi(int(player.get("shock", 0)), 1 if bool(restrictions.get("shocked", false)) else 0),
		"stun": maxi(int(player.get("stun", 0)), 1 if bool(restrictions.get("stunned", false)) else 0)
	}

func _draw_status_badge(font: Font, center: Vector2, badge: Dictionary) -> void:
	var radius: float = 10.0
	draw_circle(center, radius, badge.get("fill", Color("888888")))
	draw_arc(center, radius, 0.0, TAU, 18, badge.get("border", Color.WHITE), 1.6)
	var icon_key: String = str(badge.get("icon", ""))
	var badge_rect := Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	_draw_keyword_icon(icon_key, Rect2(center - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), ActionIcons.tooltip(icon_key), Color("1f1812"))
	_register_tooltip(badge_rect, ActionIcons.tooltip(icon_key))
	var count: int = int(badge.get("count", 0))
	if count <= 0:
		return
	var chip_rect := Rect2(center + Vector2(5.0, 3.0), Vector2(12.0, 12.0))
	draw_rect(chip_rect, Color(0.09, 0.07, 0.05, 0.96), true)
	draw_rect(chip_rect, badge.get("border", Color.WHITE), false, 1.0)
	draw_string(
		font,
		chip_rect.position + Vector2(0.0, 9.0),
		str(count),
		HORIZONTAL_ALIGNMENT_CENTER,
		chip_rect.size.x,
		9,
		Color("fff4dc")
	)

func _update_cursor_shape() -> void:
	var is_hot: bool = exit_tiles.has(_hover_tile) or move_tiles.has(_hover_tile) or attack_tiles.has(_hover_tile)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_hot else Control.CURSOR_ARROW

func _draw_trap_marker(trap: Dictionary) -> void:
	var tile: Vector2i = trap.get("pos", Vector2i(-1, -1))
	if tile.x < 0:
		return
	var element_id: String = str(trap.get("element", ElementData.NONE))
	var trap_texture: Texture2D = _trap_textures.get(element_id, null)
	if trap_texture != null:
		var trap_rect: Rect2 = _trap_draw_rect(tile)
		draw_texture_rect(trap_texture, trap_rect, false)
		_register_tooltip(trap_rect.grow(4.0), _trap_tooltip_text(trap))
		return
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, -18.0)
	var accent: Color = ElementData.accent(element_id)
	draw_circle(center, 13.0, Color(accent.r, accent.g, accent.b, 0.78))
	draw_arc(center, 13.0, 0.0, TAU, 22, Color("1a130f"), 2.0)
	draw_line(center + Vector2(-8.0, -8.0), center + Vector2(8.0, 8.0), Color("1a130f"), 2.0, true)
	draw_line(center + Vector2(8.0, -8.0), center + Vector2(-8.0, 8.0), Color("1a130f"), 2.0, true)
	var icon_texture: Texture2D = _element_textures.get(element_id, null)
	var icon_rect := Rect2(center - Vector2(8.0, 18.0), Vector2(16.0, 16.0))
	if icon_texture != null:
		draw_texture_rect(icon_texture, icon_rect, false)
	var tooltip_rect := Rect2(center - Vector2(14.0, 20.0), Vector2(28.0, 34.0))
	_register_tooltip(tooltip_rect, _trap_tooltip_text(trap))

func _trap_draw_rect(tile: Vector2i) -> Rect2:
	var tile_width: float = _tile_width()
	var draw_size := Vector2(tile_width * TRAP_DRAW_WIDTH_SCALE, _tile_height() * TRAP_DRAW_HEIGHT_SCALE)
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * TRAP_DRAW_Y_OFFSET_SCALE)
	return Rect2(center - draw_size * 0.5, draw_size)

func _trap_tooltip_text(trap: Dictionary) -> String:
	var lines: PackedStringArray = ["%s Trap" % ElementData.name(str(trap.get("element", ElementData.NONE)))]
	lines.append("%d damage" % int(trap.get("damage", 0)))
	if int(trap.get("burn", 0)) > 0:
		lines.append("Burn %d" % int(trap.get("burn", 0)))
	if int(trap.get("freeze", 0)) > 0:
		lines.append("Freeze")
	if int(trap.get("shock", 0)) > 0:
		lines.append("Shock")
	if int(trap.get("stun", 0)) > 0:
		lines.append("Stun")
	if int(trap.get("poison", 0)) > 0:
		lines.append("Poison %d" % int(trap.get("poison", 0)))
	return "\n".join(lines)
