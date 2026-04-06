extends Control
class_name CombatBoardView

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")

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
const MOVE_MARKER_COLOR: Color = Color("95ebff")
const ATTACK_MARKER_COLOR: Color = Color("ffad7d")
const PLAYER_FOCUS_COLOR: Color = Color("f1d18b")
const ENEMY_FOCUS_COLOR: Color = Color("f08c53")
const PLAYER_BAR_FILL: Color = Color("8ec26c")
const ENEMY_BAR_FILL: Color = Color("d06752")
const STATUS_BURN: Color = Color("f28a42")
const STATUS_FREEZE: Color = Color("7dd4ff")
const STATUS_SHOCK: Color = Color("f3d762")
const STATUS_POISON: Color = Color("86bf63")

var combat_state: Dictionary = {}
var move_tiles: Array[Vector2i] = []
var attack_tiles: Array[Vector2i] = []
var selected_tile: Vector2i = Vector2i(-1, -1)
var status_label: String = ""
var status_detail: String = ""
var exit_tiles: Dictionary = {}
var exit_elements: Dictionary = {}
var presentation: Dictionary = {}
var _hover_tile: Vector2i = Vector2i(-1, -1)
var _tile_textures: Dictionary = {}
var _prop_textures: Dictionary = {}
var _loot_textures: Dictionary = {}
var _unit_textures: Dictionary = {}
var _element_textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(960.0, 680.0)
	_load_assets()

func set_combat_state(next_state: Dictionary, next_move_tiles: Array = [], next_attack_tiles: Array = [], next_selected_tile: Vector2i = Vector2i(-1, -1), next_status_label: String = "", next_status_detail: String = "", next_exit_tiles: Dictionary = {}, next_exit_elements: Dictionary = {}, next_presentation: Dictionary = {}) -> void:
	combat_state = next_state.duplicate(true)
	move_tiles = _vector2i_array(next_move_tiles)
	attack_tiles = _vector2i_array(next_attack_tiles)
	selected_tile = next_selected_tile
	status_label = next_status_label
	status_detail = next_status_detail
	exit_tiles = next_exit_tiles.duplicate(true)
	exit_elements = next_exit_elements.duplicate(true)
	presentation = next_presentation.duplicate(true)
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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("18120f"), true)
	if combat_state.is_empty():
		_draw_empty_state()
		return
	var grid: Array = combat_state.get("grid", [])
	var tiles: Array[Vector2i] = _tiles_in_draw_order(grid)
	for tile: Vector2i in tiles:
		_draw_floor_tile(grid, tile)
	for tile: Vector2i in tiles:
		_draw_tile_overlays(tile)
	_draw_path_preview()
	for tile: Vector2i in tiles:
		_draw_tile_props(grid, tile)
	_draw_exit_markers()
	_draw_units()
	_draw_target_markers()
	_draw_effect_overlay()
	_draw_status_text()
	_draw_floating_texts()

func _draw_empty_state() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(34, 52), "No active combat.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("f0e5cf"))

func _draw_floor_tile(grid: Array, tile: Vector2i) -> void:
	var tile_id: String = str((grid[tile.y] as Array)[tile.x])
	var polygon: PackedVector2Array = _tile_polygon(tile)
	var base_color: Color = _tile_color(tile_id)
	draw_colored_polygon(polygon, base_color)
	var texture: Texture2D = _tile_textures.get(_floor_texture_key(tile_id), null)
	if texture != null:
		var tile_width: float = _tile_width()
		var tile_height: float = _tile_height()
		var rect := Rect2(_tile_center(tile) - Vector2(tile_width * 0.5, tile_height * 0.5), Vector2(tile_width, tile_height))
		draw_texture_rect(texture, rect, false)
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

func _draw_tile_props(grid: Array, tile: Vector2i) -> void:
	var tile_id: String = str((grid[tile.y] as Array)[tile.x])
	if tile_id == "wall" or tile_id == "pillar":
		var texture: Texture2D = _prop_textures.get(tile_id, null)
		if texture != null:
			var center: Vector2 = _tile_center(tile)
			var prop_size: Vector2 = _prop_size()
			var rect := Rect2(center - Vector2(prop_size.x * 0.5, prop_size.y * 0.84), prop_size)
			draw_texture_rect(texture, rect, false)
	elif tile_id == "door":
		var door_texture: Texture2D = _prop_textures.get("door", null)
		if door_texture != null:
			var door_center: Vector2 = _tile_center(tile)
			var tile_width: float = _tile_width()
			var tile_height: float = _tile_height()
			var door_rect := Rect2(door_center - Vector2(tile_width * 0.45, tile_height * 0.6), Vector2(tile_width * 0.9, tile_height * 0.8))
			var element_id: String = str(exit_elements.get(tile, ElementData.NONE))
			draw_texture_rect(door_texture, door_rect, false, ElementData.door_tint(element_id))
			var icon_texture: Texture2D = _element_textures.get(element_id, null)
			if icon_texture != null:
				var icon_rect := Rect2(door_center + Vector2(-12.0, -tile_height * 0.7), Vector2(24.0, 24.0))
				draw_texture_rect(icon_texture, icon_rect, false)
	for loot: Dictionary in combat_state.get("loot", []):
		if bool(loot.get("claimed", false)):
			continue
		if loot.get("pos", Vector2i(-1, -1)) != tile:
			continue
		var loot_texture: Texture2D = _loot_textures.get(str(loot.get("kind", "")), null)
		if loot_texture == null:
			continue
		var loot_rect := Rect2(_tile_center(tile) - Vector2(26.0, 58.0), Vector2(52.0, 68.0))
		draw_texture_rect(loot_texture, loot_rect, false)

func _draw_exit_markers() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	for tile_var: Variant in exit_tiles.keys():
		var tile: Vector2i = tile_var
		var label: String = str(exit_tiles.get(tile_var, ""))
		var element_id: String = str(exit_elements.get(tile_var, ElementData.NONE))
		var accent: Color = ElementData.door_tint(element_id)
		var center: Vector2 = _tile_center(tile) + Vector2(0.0, -_tile_height() * 0.58)
		var marker_rect := Rect2(center - Vector2(26.0, 16.0), Vector2(52.0, 32.0))
		draw_rect(marker_rect, Color(0.11, 0.08, 0.06, 0.92), true)
		draw_rect(marker_rect, accent, false, 2.0)
		draw_string(font, marker_rect.position + Vector2(0.0, 13.0), label, HORIZONTAL_ALIGNMENT_CENTER, marker_rect.size.x, 11, Color("fff0d1"))
		if ElementData.is_elemental(element_id):
			draw_string(font, marker_rect.position + Vector2(0.0, 25.0), ElementData.short_label(element_id), HORIZONTAL_ALIGNMENT_CENTER, marker_rect.size.x, 7, accent)

func _draw_units() -> void:
	var units_to_draw: Array[Dictionary] = []
	var player: Dictionary = combat_state.get("player", {})
	var player_restrictions: Dictionary = combat_state.get("player_turn_restrictions", {})
	if not player.is_empty() and int(player.get("hp", 0)) > 0:
		var player_statuses: Dictionary = _player_display_statuses(player, player_restrictions)
		units_to_draw.append({
			"key": "player",
			"type": "player",
			"pos": player.get("pos", Vector2i.ZERO),
			"hp": int(player.get("hp", 0)),
			"max_hp": int(player.get("max_hp", 1)),
			"block": int(player.get("block", 0)),
			"stoneskin": int(player.get("stoneskin", 0)),
			"burn": int(player_statuses.get("burn", 0)),
			"freeze": int(player_statuses.get("freeze", 0)),
			"shock": int(player_statuses.get("shock", 0)),
			"poison": player.get("poison", {}).duplicate(true)
		})
	for enemy: Dictionary in combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0:
			continue
		units_to_draw.append({
			"key": "enemy_%d" % int(enemy.get("id", -1)),
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
			"poison": enemy.get("poison", {}).duplicate(true)
		})
	units_to_draw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_pos: Vector2i = a.get("pos", Vector2i.ZERO)
		var b_pos: Vector2i = b.get("pos", Vector2i.ZERO)
		return (a_pos.x + a_pos.y) < (b_pos.x + b_pos.y)
	)
	for unit: Dictionary in units_to_draw:
		var center: Vector2 = _unit_center(unit)
		_draw_shadow(center + Vector2(0.0, _tile_height() * 0.58))
		_draw_unit_focus(unit, center)
		var texture: Texture2D = _texture_for_unit(unit)
		if texture != null:
			var unit_size: Vector2 = _unit_size()
			var frame_rect := Rect2(center - Vector2(unit_size.x * 0.5, unit_size.y * 0.84), unit_size)
			draw_texture_rect(texture, _fitted_unit_rect(texture, frame_rect), false)
		_draw_health_bar(unit, center)
		_draw_unit_statuses(unit, center)
		if str(unit.get("type", "")) != "player":
			_draw_enemy_intent(unit, center)

func _draw_health_bar(unit: Dictionary, center: Vector2) -> void:
	var rect := Rect2(center + Vector2(-34.0, -58.0), Vector2(68.0, 10.0))
	var font: Font = get_theme_default_font()
	SegmentedHealthBar.draw_bar(
		self,
		rect,
		float(unit.get("hp", 0)),
		float(maxi(1, int(unit.get("max_hp", 1)))),
		maxi(1, int(ceili(float(maxi(1, int(unit.get("max_hp", 1)))) / 10.0))),
		Color("2d1f18"),
		PLAYER_BAR_FILL if str(unit.get("type", "")) == "player" else ENEMY_BAR_FILL,
		Color("f5efdf"),
		Color("eed3a6"),
		Color(0.0, 0.0, 0.0, 0.35),
		1.0,
		1.0
	)
	if font != null:
		for offset: Vector2 in [
			Vector2(-1.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, -1.0),
			Vector2(0.0, 1.0)
		]:
			draw_string(
				font,
				rect.position + Vector2(0.0, 8.5) + offset,
				"%d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))],
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				8,
				Color("140f0b")
			)
		draw_string(
			font,
			rect.position + Vector2(0.0, 8.5),
			"%d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			8,
			Color("fff4dc")
		)
	var block_amount: int = int(unit.get("block", 0))
	if block_amount > 0 and font != null:
		var block_rect := Rect2(rect.position + Vector2(72.0, -2.0), Vector2(22.0, 14.0))
		draw_rect(block_rect, Color(0.07, 0.12, 0.16, 0.92), true)
		draw_rect(block_rect, Color("90d9ff"), false, 1.0)
		draw_string(
			font,
			block_rect.position + Vector2(0.0, 10.0),
			"+%d" % block_amount,
			HORIZONTAL_ALIGNMENT_CENTER,
			block_rect.size.x,
			8,
			Color("d9f5ff")
		)
	var stoneskin_amount: int = int(unit.get("stoneskin", 0))
	if stoneskin_amount > 0 and font != null:
		var skin_rect := Rect2(rect.position + Vector2(97.0, -2.0), Vector2(26.0, 14.0))
		draw_rect(skin_rect, Color(0.10, 0.14, 0.08, 0.92), true)
		draw_rect(skin_rect, ElementData.accent(ElementData.EARTH), false, 1.0)
		draw_string(
			font,
			skin_rect.position + Vector2(0.0, 10.0),
			"S%d" % stoneskin_amount,
			HORIZONTAL_ALIGNMENT_CENTER,
			skin_rect.size.x,
			8,
			Color("eff8d7")
		)

func _draw_unit_statuses(unit: Dictionary, center: Vector2) -> void:
	var badges: Array[Dictionary] = _unit_status_badges(unit)
	if badges.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var spacing: float = 18.0
	var start_x: float = center.x - (float(badges.size() - 1) * spacing) * 0.5
	for index: int in range(badges.size()):
		_draw_status_badge(font, Vector2(start_x + float(index) * spacing, center.y - 74.0), badges[index])

func _draw_enemy_intent(unit: Dictionary, center: Vector2) -> void:
	var intent: Dictionary = unit.get("intent", {})
	if intent.is_empty():
		return
	var lines: PackedStringArray = _intent_lines(intent)
	if lines.is_empty():
		return
	var border: Color = _intent_color(intent)
	var label_height: float = 14.0 + float(lines.size()) * 12.0
	var label_rect := Rect2(center + Vector2(-58.0, -126.0 - label_height * 0.25), Vector2(116.0, label_height))
	draw_rect(label_rect, Color(0.08, 0.06, 0.05, 0.88), true)
	draw_rect(label_rect, border, false, 2.0)
	var font: Font = get_theme_default_font()
	if font == null:
		return
	for line_index: int in range(lines.size()):
		draw_string(
			font,
			label_rect.position + Vector2(8.0, 14.0 + float(line_index) * 12.0),
			lines[line_index],
			HORIZONTAL_ALIGNMENT_LEFT,
			100.0,
			11,
			Color("f7ecd4")
		)

func _draw_status_text() -> void:
	if status_label.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(22.0, 28.0), status_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("f4ebd7"))
	if not status_detail.is_empty():
		draw_string(font, Vector2(22.0, 48.0), status_detail, HORIZONTAL_ALIGNMENT_LEFT, size.x - 44.0, 12, Color("d8ccb6"))

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
			if from_tile.x < 0 or to_tile.x < 0:
				return
			var trail_point: Vector2 = from_point.lerp(to_point, progress)
			draw_line(from_point, trail_point, Color("f1d18b"), 4.0, true)
			draw_circle(trail_point, 9.0, Color(0.95, 0.82, 0.49, 0.28))
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
			var projectile_point: Vector2 = start.lerp(end, progress)
			draw_line(start, projectile_point, Color("f4b56f"), 5.0, true)
			draw_circle(projectile_point, 6.0, Color("ffd29c"))
			if progress >= 0.98:
				draw_circle(to_point, 12.0, Color(0.94, 0.47, 0.30, 0.20))
		"melee":
			if to_tile.x < 0:
				return
			var slash_center: Vector2 = from_point.lerp(to_point, 0.20 + progress * 0.62)
			var melee_size: float = _tile_width() * (0.12 + progress * 0.14)
			draw_line(slash_center + Vector2(-melee_size, -melee_size), slash_center + Vector2(melee_size, melee_size), Color("f2c996"), 5.0, true)
			draw_line(slash_center + Vector2(melee_size, -melee_size), slash_center + Vector2(-melee_size, melee_size), Color("f2c996"), 5.0, true)
		"blast":
			if center_tile.x < 0:
				return
			var radius: int = int(effect.get("radius", 1))
			var draw_radius: float = _tile_width() * (0.10 + progress * (0.36 + float(radius) * 0.42))
			draw_arc(center_point, draw_radius, 0.0, TAU, 28, Color("f08c53"), 4.0)
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
	if path_tiles.size() < 2:
		return
	for index: int in range(path_tiles.size() - 1):
		var from_point: Vector2 = _tile_center(path_tiles[index]) + Vector2(0.0, -12.0)
		var to_point: Vector2 = _tile_center(path_tiles[index + 1]) + Vector2(0.0, -12.0)
		draw_line(from_point, to_point, MOVE_PATH_COLOR, 4.0, true)
	for tile: Vector2i in path_tiles:
		draw_circle(_tile_center(tile) + Vector2(0.0, -12.0), 4.0, MOVE_MARKER_COLOR)

func _draw_target_markers() -> void:
	for tile: Vector2i in move_tiles:
		_draw_move_target_marker(tile, tile == _hover_tile)
	for tile: Vector2i in attack_tiles:
		_draw_attack_target_marker(tile, tile == _hover_tile)

func _draw_move_target_marker(tile: Vector2i, hovered: bool) -> void:
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, -10.0)
	var radius: float = 10.0 if hovered else 8.0
	var color: Color = MOVE_MARKER_COLOR.lightened(0.18) if hovered else MOVE_MARKER_COLOR
	draw_arc(center, radius, 0.0, TAU, 24, color, 3.0)
	draw_circle(center, 2.8, color)

func _draw_attack_target_marker(tile: Vector2i, hovered: bool) -> void:
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, -16.0)
	var radius: float = 12.0 if hovered else 10.0
	var color: Color = ATTACK_MARKER_COLOR.lightened(0.16) if hovered else ATTACK_MARKER_COLOR
	draw_arc(center, radius, 0.0, TAU, 24, color, 3.0)
	draw_line(center + Vector2(-radius * 0.7, 0.0), center + Vector2(radius * 0.7, 0.0), color, 2.0, true)
	draw_line(center + Vector2(0.0, -radius * 0.7), center + Vector2(0.0, radius * 0.7), color, 2.0, true)

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

func _tile_color(tile_id: String) -> Color:
	match tile_id:
		"moss":
			return Color("667a5d")
		"ember":
			return Color("874d36")
		"wall":
			return Color("4a3930")
		"pillar":
			return Color("5d4f47")
		"door":
			return Color("8c6b42")
		_:
			return Color("75695f")

func _floor_texture_key(tile_id: String) -> String:
	match tile_id:
		"moss":
			return "moss"
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

func _load_assets() -> void:
	_tile_textures = {
		"ash": AssetLoader.load_texture("res://assets/placeholders/tiles/ash.svg"),
		"moss": AssetLoader.load_texture("res://assets/placeholders/tiles/moss.svg"),
		"ember": AssetLoader.load_texture("res://assets/placeholders/tiles/ember.svg")
	}
	_prop_textures = {
		"pillar": AssetLoader.load_texture("res://assets/placeholders/tiles/pillar.svg"),
		"wall": AssetLoader.load_texture("res://assets/placeholders/tiles/pillar.svg"),
		"door": AssetLoader.load_texture("res://assets/placeholders/tiles/door.svg")
	}
	_loot_textures = {
		"healing_vial": AssetLoader.load_texture("res://assets/placeholders/tiles/healing_vial.svg"),
		"ember_cache": AssetLoader.load_texture("res://assets/placeholders/tiles/ember_cache.svg")
	}
	_element_textures.clear()
	for element_id: String in ElementData.all_elements():
		_element_textures[element_id] = AssetLoader.load_texture(ElementData.icon_path(element_id))
	_unit_textures["player"] = AssetLoader.load_texture("res://assets/placeholders/units/player_reaver.png")
	for enemy_type: String in GameData.enemies().keys():
		var art_path: String = str(GameData.enemy_def(enemy_type).get("art_path", ""))
		_unit_textures[enemy_type] = AssetLoader.load_texture(art_path)

func _texture_for_unit(unit: Dictionary) -> Texture2D:
	return _unit_textures.get(str(unit.get("type", "")), null)

func _unit_center(unit: Dictionary) -> Vector2:
	var unit_key: String = str(unit.get("key", ""))
	var overrides: Dictionary = presentation.get("unit_world_positions", {})
	if overrides.has(unit_key):
		return overrides[unit_key]
	return _tile_center(unit.get("pos", Vector2i.ZERO))

func _fitted_unit_rect(texture: Texture2D, frame_rect: Rect2) -> Rect2:
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

func _tiles_in_draw_order(grid: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			tiles.append(Vector2i(x, y))
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_score: int = a.x + a.y
		var b_score: int = b.x + b.y
		if a_score == b_score:
			return a.x < b.x
		return a_score < b_score
	)
	return tiles

func _tile_center(tile: Vector2i) -> Vector2:
	var origin: Vector2 = _board_origin()
	var half_w: float = _tile_width() * 0.5
	var half_h: float = _tile_height() * 0.5
	return Vector2(
		origin.x + float(tile.x - tile.y) * half_w,
		origin.y + float(tile.x + tile.y) * half_h
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
	var grid: Array = combat_state.get("grid", [])
	var board_w: int = 8
	var board_h: int = 8
	if not grid.is_empty():
		board_h = grid.size()
		board_w = (grid[0] as Array).size()
	var tile_width: float = _tile_width()
	var half_height: float = _tile_height() * 0.5
	var board_span_y: float = float(maxi(0, board_w + board_h - 2)) * half_height
	var top_pad: float = _unit_size().y * 0.62
	var bottom_pad: float = tile_width * 0.18
	var origin_y: float = maxf(top_pad, (size.y - (board_span_y + top_pad + bottom_pad)) * 0.5 + top_pad)
	return Vector2(size.x * 0.5, origin_y)

func _tile_at_point(point: Vector2) -> Vector2i:
	var grid: Array = combat_state.get("grid", [])
	var tiles: Array[Vector2i] = _tiles_in_draw_order(grid)
	for index: int in range(tiles.size() - 1, -1, -1):
		var tile: Vector2i = tiles[index]
		if Geometry2D.is_point_in_polygon(point, _tile_polygon(tile)):
			return tile
	return Vector2i(-1, -1)

func _draw_shadow(center: Vector2) -> void:
	var points := PackedVector2Array()
	for step: int in range(18):
		var angle: float = TAU * float(step) / 18.0
		points.append(center + Vector2(cos(angle) * _tile_width() * 0.20, sin(angle) * _tile_height() * 0.17))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.18))

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _tile_width() -> float:
	var grid: Array = combat_state.get("grid", [])
	var board_w: int = 8
	var board_h: int = 8
	if not grid.is_empty():
		board_h = grid.size()
		board_w = (grid[0] as Array).size()
	var span: float = float(maxi(2, board_w + board_h))
	var width_based: float = (size.x - 120.0) * 2.0 / span
	var height_based: float = (size.y - 124.0) * 4.0 / span
	return clampf(minf(width_based, height_based), 86.0, 138.0)

func _tile_height() -> float:
	return _tile_width() * 0.5

func _unit_size() -> Vector2:
	var tile_width: float = _tile_width()
	return Vector2(tile_width * 1.03, tile_width * 1.32)

func _prop_size() -> Vector2:
	var tile_width: float = _tile_width()
	return Vector2(tile_width * 0.92, tile_width * 1.14)

func _intent_lines(intent: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = []
	for action_var: Variant in intent.get("actions", []):
		var action: Dictionary = action_var
		match str(action.get("type", "")):
			"move_toward":
				parts.append("MOVE %d" % int(action.get("range", 0)))
			"move_away":
				parts.append("BACK %d" % int(action.get("range", 0)))
			"melee":
				parts.append(_intent_action_text("HIT %d" % int(action.get("damage", 0)), action))
			"ranged":
				parts.append(_intent_action_text("SHOT %d" % int(action.get("damage", 0)), action))
			"blast":
				parts.append(_intent_action_text("BLAST %d" % int(action.get("damage", 0)), action))
			"push":
				parts.append(_intent_action_text("PUSH %d" % int(action.get("amount", 0)), action))
			"pull":
				parts.append(_intent_action_text("PULL %d" % int(action.get("amount", 0)), action))
			"block":
				parts.append("BLOCK %d" % int(action.get("amount", 0)))
			"stoneskin":
				parts.append("SKIN %d" % int(action.get("amount", 0)))
			"heal_self":
				parts.append("HEAL %d" % int(action.get("amount", 0)))
	return parts

func _intent_action_text(base_text: String, action: Dictionary) -> String:
	var text: String = base_text
	var range_label: String = _intent_range_label(action)
	if not range_label.is_empty():
		text += " %s" % range_label
	var tags: PackedStringArray = []
	if int(action.get("burn", 0)) > 0:
		tags.append("BRN")
	if int(action.get("freeze", 0)) > 0:
		tags.append("FRZ")
	if int(action.get("shock", 0)) > 0:
		tags.append("SHK")
	if int(action.get("poison", 0)) > 0:
		tags.append("PSN")
	if int(action.get("push", 0)) > 0:
		tags.append("PUSH")
	if int(action.get("pull", 0)) > 0:
		tags.append("PULL")
	if tags.is_empty():
		return text
	return "%s %s" % [text, "/".join(tags)]

func _intent_range_label(action: Dictionary) -> String:
	var action_type: String = str(action.get("type", ""))
	var action_range: int = int(action.get("range", 0))
	match action_type:
		"ranged":
			return "R%d" % maxi(1, action_range)
		"blast":
			return "R%d" % action_range if action_range > 0 else ""
		"melee", "push", "pull":
			return "R%d" % action_range if action_range > 1 else ""
		_:
			return ""

func _intent_color(intent: Dictionary) -> Color:
	var element_id: String = str(intent.get("element", ElementData.NONE))
	if ElementData.is_elemental(element_id):
		return ElementData.accent(element_id)
	for action_var: Variant in intent.get("actions", []):
		var action_type: String = str((action_var as Dictionary).get("type", ""))
		if action_type in ["melee", "ranged", "blast"]:
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
			"glyph": "B",
			"count": int(unit.get("burn", 0)),
			"fill": STATUS_BURN,
			"border": STATUS_BURN.lightened(0.24)
		})
	if int(unit.get("freeze", 0)) > 0:
		badges.append({
			"glyph": "F",
			"count": 0,
			"fill": STATUS_FREEZE,
			"border": STATUS_FREEZE.lightened(0.20)
		})
	if int(unit.get("shock", 0)) > 0:
		badges.append({
			"glyph": "Z",
			"count": 0,
			"fill": STATUS_SHOCK,
			"border": STATUS_SHOCK.lightened(0.18)
		})
	var poison: Dictionary = unit.get("poison", {})
	if int(poison.get("damage", 0)) > 0 and int(poison.get("delay", 0)) > 0:
		badges.append({
			"glyph": "P",
			"count": int(poison.get("delay", 0)),
			"fill": STATUS_POISON,
			"border": STATUS_POISON.lightened(0.22)
		})
	return badges

func _player_display_statuses(player: Dictionary, restrictions: Dictionary) -> Dictionary:
	return {
		"burn": int(player.get("burn", 0)),
		"freeze": maxi(int(player.get("freeze", 0)), 1 if bool(restrictions.get("frozen", false)) else 0),
		"shock": maxi(int(player.get("shock", 0)), 1 if bool(restrictions.get("shocked", false)) else 0)
	}

func _draw_status_badge(font: Font, center: Vector2, badge: Dictionary) -> void:
	var radius: float = 8.0
	draw_circle(center, radius, badge.get("fill", Color("888888")))
	draw_arc(center, radius, 0.0, TAU, 18, badge.get("border", Color.WHITE), 1.6)
	draw_string(
		font,
		Vector2(center.x - radius, center.y + 3.5),
		str(badge.get("glyph", "")),
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		8,
		Color("1f1812")
	)
	var count: int = int(badge.get("count", 0))
	if count <= 0:
		return
	var chip_rect := Rect2(center + Vector2(4.0, 2.0), Vector2(10.0, 10.0))
	draw_rect(chip_rect, Color(0.09, 0.07, 0.05, 0.96), true)
	draw_rect(chip_rect, badge.get("border", Color.WHITE), false, 1.0)
	draw_string(
		font,
		chip_rect.position + Vector2(0.0, 8.0),
		str(count),
		HORIZONTAL_ALIGNMENT_CENTER,
		chip_rect.size.x,
		8,
		Color("fff4dc")
	)

func _update_cursor_shape() -> void:
	var is_hot: bool = exit_tiles.has(_hover_tile) or move_tiles.has(_hover_tile) or attack_tiles.has(_hover_tile)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_hot else Control.CURSOR_ARROW
