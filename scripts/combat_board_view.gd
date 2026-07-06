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
signal tile_dragged(start_tile: Vector2i, current_tile: Vector2i)
signal tile_drag_released(start_tile: Vector2i, current_tile: Vector2i)
signal cancel_requested

const GRID_OUTLINE: Color = Color("1f1713")
const MOVE_HIGHLIGHT: Color = Color(0.28, 0.75, 0.86, 0.20)
const ATTACK_HIGHLIGHT: Color = Color(0.96, 0.40, 0.25, 0.20)
const ABILITY_HIGHLIGHT: Color = Color(0.30, 0.78, 0.35, 0.22)
const HOVER_HIGHLIGHT: Color = Color(1.0, 0.96, 0.82, 0.22)
const SELECT_HIGHLIGHT: Color = Color(0.97, 0.81, 0.43, 0.36)
const EXIT_HIGHLIGHT: Color = Color(0.95, 0.78, 0.31, 0.34)
const FOCUS_HIGHLIGHT: Color = Color(0.99, 0.92, 0.57, 0.24)
const MOVE_PATH_COLOR: Color = Color("80e4f2")
const MOVE_PATH_SHADOW: Color = Color(0.02, 0.03, 0.03, 0.35)
const MOVE_RISK_CHIP_FONT_SIZE: int = 10
const MOVE_RISK_CHIP_HEIGHT: float = 18.0
const MOVE_RISK_CHIP_GAP: float = 3.0
const IMPACT_FLASH_COLOR: Color = Color(1.0, 0.22, 0.15, 0.72)
const PLAYER_FOCUS_COLOR: Color = Color("f1d18b")
const ENEMY_FOCUS_COLOR: Color = Color("f08c53")
const PLAYER_BAR_FILL: Color = Color("8ec26c")
const ILLUSION_BAR_FILL: Color = Color("7bd8ee")
const ENEMY_BAR_FILL: Color = Color("d06752")
const TERRAIN_BAR_FILL: Color = Color("d9b84f")
const STATUS_BURN: Color = Color("f28a42")
const STATUS_BLEED: Color = Color("b84646")
const STATUS_EXPOSE: Color = Color("d9b36a")
const STATUS_FREEZE: Color = Color("7dd4ff")
const STATUS_SHOCK: Color = Color("f3d762")
const STATUS_IMMOBILIZE: Color = Color("b8c48f")
const STATUS_POISON: Color = Color("86bf63")
const PLAYER_HEALTH_BAR_SIZE: Vector2 = Vector2(78.0, 12.0)
const ENEMY_HEALTH_BAR_SIZE: Vector2 = Vector2(84.0, 14.0)
const BOSS_HEALTH_BAR_SIZE: Vector2 = Vector2(760.0, 30.0)
const BOSS_HEALTH_BAR_Y: float = -24.0
const BOSS_INTENT_ICON_SIZE: float = 20.0
const BOSS_INTENT_FONT_SIZE: int = 13
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
const FOREGROUND_OBSTRUCTION_COVERAGE_THRESHOLD: float = 0.25
const LOOT_DRAW_WIDTH: float = 58.0
const EQUIPMENT_LOOT_MIN_DRAW_WIDTH: float = 64.0
const EQUIPMENT_LOOT_MAX_DRAW_WIDTH: float = 90.0
const EQUIPMENT_LOOT_TILE_WIDTH_SCALE: float = 0.56
const EQUIPMENT_LOOT_FLOAT_BASELINE_SCALE: float = -0.02
const IDLE_FRAME_SECONDS: float = 0.10
const IDLE_SHEET_COLUMNS: int = 4
const IDLE_SHEET_ROWS: int = 2
const DEATH_FRAME_SECONDS: float = 0.065
const DEATH_SHEET_COLUMNS: int = 4
const DEATH_SHEET_ROWS: int = 4
const IDLE_SHEET_ORDER_ROW_MAJOR: String = "row_major"
const IDLE_SHEET_ORDER_COLUMN_MAJOR: String = "column_major"
const OUTER_WALL_RENDERING_ENABLED: bool = false
const BOARD_SIDE_MARGIN: float = 36.0
const BOARD_VERTICAL_MARGIN: float = 8.0
const BOARD_TOP_CLEARANCE_SCALE: float = 0.82
const BOARD_BOTTOM_CLEARANCE_SCALE: float = 0.34
const BOARD_VERTICAL_BIAS: float = 0.28
const BOARD_MAX_TILE_WIDTH: float = 184.0
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
const CAMPFIRE_BONFIRE_IDLE_PATH: String = "res://assets/art/tiles/campfire_bonfire_idle.png"
const CAMPFIRE_BONFIRE_IDLE_COLUMNS: int = 4
const CAMPFIRE_BONFIRE_IDLE_ROWS: int = 4
const CAMPFIRE_BONFIRE_IDLE_FRAME_SECONDS: float = 0.10
const CAMPFIRE_BONFIRE_WIDTH_SCALE: float = 1.2925
const CAMPFIRE_BONFIRE_BASELINE_SCALE: float = 0.48
const CAMPFIRE_FIRELIGHT_BLOOM_ALPHA: float = 0.42
const CAMPFIRE_FIRELIGHT_CORE_ALPHA: float = 0.34
const CAMPFIRE_EMBER_MOTE_COUNT: int = 46
const CAMPFIRE_EMBER_MOTE_ALPHA: float = 1.30
const CAMPFIRE_EMBER_PLUME_HEIGHT_SCALE: float = 1.78
const RELIC_CHEST_PATH: String = "res://assets/art/tiles/relic_chest.png"
const RELIC_CHEST_WIDTH_SCALE: float = 0.68
const RELIC_CHEST_BASELINE_SCALE: float = 0.44
const BLACKSMITH_FORGE_PATH: String = "res://assets/art/tiles/blacksmith_forge.png"
const ARCANIST_TABLE_PATH: String = "res://assets/art/tiles/arcanist_table.png"
const SCAVENGER_STALL_PATH: String = "res://assets/art/tiles/scavenger_stall.png"
const COLUMN_TORCH_LEFT_PATH: String = "res://assets/art/tiles/column_torch_left.png"
const COLUMN_TORCH_RIGHT_PATH: String = "res://assets/art/tiles/column_torch_right.png"
const COLUMN_TORCH_LEFT_IDLE_PATH: String = "res://assets/art/tiles/column_torch_left_idle.png"
const COLUMN_TORCH_RIGHT_IDLE_PATH: String = "res://assets/art/tiles/column_torch_right_idle.png"
const COLUMN_TORCH_IDLE_COLUMNS: int = 4
const COLUMN_TORCH_IDLE_ROWS: int = 4
const COLUMN_TORCH_IDLE_FRAME_SECONDS: float = 0.1166667
const COLUMN_TORCH_EMBER_MOTE_COUNT: int = 4
const COLUMN_TORCH_EMBER_MOTE_ALPHA: float = 0.90
const COLUMN_TORCH_EMBER_PLUME_HEIGHT_SCALE: float = 0.52
const COLUMN_TORCH_EMBER_MIN_WIDTH_SCALE: float = 0.020
const COLUMN_TORCH_EMBER_MAX_WIDTH_SCALE: float = 0.040
const CONTINUOUS_PRESENTATION_REDRAW_SECONDS: float = 1.0 / 30.0
const AMBIENT_PARTICLE_DENSITY: float = 0.76
const AMBIENT_PARTICLE_OPACITY: float = 0.68
const AMBIENT_PARTICLE_SPEED_SCALE: float = 1.0
const COLUMN_TORCH_WIDTH_SCALE: float = 0.30
const COLUMN_TORCH_FACE_OFFSET_X_SCALE: float = 0.26
const COLUMN_TORCH_TOP_Y_SCALE: float = 0.27
const AMBIENT_PARTICLE_ATLAS_PATH: String = "res://assets/art/effects/ambient_particles.png"
const AMBIENT_PARTICLE_GLOW_ATLAS_PATH: String = "res://assets/art/effects/ambient_particles_glow.png"
const AMBIENT_FIRE_SOFT_ATLAS_PATH: String = "res://assets/art/effects/ambient_fire_soft_particles.png"
const AMBIENT_AIR_WISP_FRAMES_PATH: String = "res://assets/art/effects/ambient_air_wisp_frames.png"
const AMBIENT_AIR_WISP_SOFT_ATLAS_PATH: String = "res://assets/art/effects/ambient_air_wisp_soft_particles.png"
const AMBIENT_AIR_WISP_GLOW_FRAMES_PATH: String = "res://assets/art/effects/ambient_air_wisp_glow_frames.png"
const AMBIENT_PARTICLE_ATLAS_COLUMNS: int = 4
const AMBIENT_PARTICLE_ATLAS_ROWS: int = 5
const AMBIENT_FIRE_SOFT_ATLAS_COLUMNS: int = 4
const AMBIENT_AIR_WISP_SOFT_ATLAS_COLUMNS: int = 4
const AMBIENT_AIR_WISP_FRAME_COLUMNS: int = 32
const AMBIENT_AIR_WISP_FULL_FRAME_INDEX: int = 16
const AMBIENT_AIR_WISP_VARIANTS: int = 4
const MELEE_SLASH_SHEET_PATH: String = "res://assets/art/effects/melee_slash_sheet.png"
const MELEE_SLASH_SHEET_COLUMNS: int = 6
const MELEE_SLASH_SHEET_ROWS: int = 1
const ELEMENTAL_PROJECTILE_ATLAS_PATH: String = "res://assets/art/effects/elemental_projectiles.png"
const ELEMENTAL_PROJECTILE_ATLAS_ROWS: int = 6
const PROJECTILE_DRAW_TILE_SCALE: float = 0.34
const PROJECTILE_DRAW_MIN_SIZE: float = 30.0
const PROJECTILE_DRAW_MAX_SIZE: float = 48.0
const PROJECTILE_SPRITE_PATH_ANCHOR_X: float = 0.78
const PROJECTILE_PREVIEW_LOOP_SECONDS: float = 2.4
const LETHAL_SKULL_EFFECT_PATH: String = "res://assets/art/effects/lethal_skull.png"
const BLINK_RIFT_PREVIEW_TEXTURE_PATH: String = "res://assets/art/effects/blink_rift_preview.png"
const DEFENSE_HEAL_CASTS_PATH: String = "res://assets/art/effects/defense_heal_casts.png"
const DEFENSE_HEAL_CASTS_COLUMNS: int = 4
const DEFENSE_HEAL_CASTS_ROWS: int = 3
const DEFENSE_HEAL_CASTS_FRAMES_PER_KIND: int = 4
const TRAP_DRAW_WIDTH_SCALE: float = 1.0
const TRAP_DRAW_HEIGHT_SCALE: float = 1.0
const TRAP_DRAW_Y_OFFSET_SCALE: float = 0.0
const TRAP_BLAST_DRAW_WIDTH_SCALE: float = 0.76
const TRAP_BLAST_DRAW_HEIGHT_SCALE: float = 1.18
const TRAP_BLAST_BASELINE_SCALE: float = 0.32
const IMPACT_DECAL_FADE_PROGRESS: float = 0.72
const IMPACT_DECAL_MAX_ALPHA: float = 0.72
const DROPPED_EMBERS_PATH: String = "res://assets/art/tiles/dropped_embers.png"
const TERRAIN_BOX_DRAW_WIDTH_SCALE: float = 0.64
const TERRAIN_CRATE_DRAW_WIDTH_SCALE: float = 0.60
const TERRAIN_DRAW_BASELINE_SCALE: float = 0.42
const TERRAIN_HEALTH_BAR_SIZE: Vector2 = Vector2(56.0, 8.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.22)
const SHADOW_LIGHT_VECTOR: Vector2 = Vector2(1.0, 0.55)
const SHADOW_POINT_COUNT: int = 24
const UNIT_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.24)
const UNIT_SHADOW_SOFT_COLOR: Color = Color(0.0, 0.0, 0.0, 0.10)
const UNIT_SHADOW_ALPHA_THRESHOLD: float = 0.08
const UNIT_SHADOW_SIMPLIFY_EPSILON: float = 3.0
const UNIT_SHADOW_RETRY_SIMPLIFY_EPSILON: float = 0.75
const UNIT_SHADOW_MIN_ALPHA_POLYGON_AREA: float = 8.0
const UNIT_SHADOW_SHAPE_SCALE: float = 1.72
const UNIT_SHADOW_WIDTH_SCALE: float = 0.82
const UNIT_SHADOW_WIDTH_SLOPE_Y: float = 0.0
const UNIT_SHADOW_HEIGHT_CAST_X: float = -0.02
const UNIT_SHADOW_HEIGHT_CAST_Y: float = 0.20
const UNIT_SHADOW_FOOT_OFFSET_Y_RATIO: float = 0.0
const UNIT_SHADOW_SOFT_SCALE: float = 1.12

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
var _left_drag_start_tile: Vector2i = Vector2i(-1, -1)
var _left_drag_moved: bool = false
var _tile_textures: Dictionary = {}
var _floor_texture_variants: Dictionary = {}
var _floor_variant_by_tile: Dictionary = {}
var _moss_texture_variants: Dictionary = {}
var _moss_tiles_by_surface: Dictionary = {}
var _prop_textures: Dictionary = {}
var _scene_prop_textures: Dictionary = {}
var _scene_prop_idle_frames: Dictionary = {}
var _pillar_torch_idle_frames: Dictionary = {}
var _effect_textures: Dictionary = {}
var _effect_frames: Dictionary = {}
var _projectile_atlas: Texture2D = null
var _projectile_textures: Dictionary = {}
var _ambient_particle_atlas: Texture2D = null
var _ambient_particle_glow_atlas: Texture2D = null
var _ambient_fire_soft_atlas: Texture2D = null
var _ambient_air_wisp_atlas: Texture2D = null
var _ambient_air_wisp_soft_atlas: Texture2D = null
var _ambient_air_wisp_glow_atlas: Texture2D = null
var _ambient_particle_textures: Dictionary = {}
var _ambient_particle_glow_textures: Dictionary = {}
var _ambient_fire_soft_textures: Dictionary = {}
var _ambient_air_wisp_textures: Dictionary = {}
var _ambient_air_wisp_soft_textures: Dictionary = {}
var _ambient_air_wisp_glow_textures: Dictionary = {}
var _loot_textures: Dictionary = {}
var _terrain_textures: Dictionary = {}
var _unit_textures: Dictionary = {}
var _element_textures: Dictionary = {}
var _trap_textures: Dictionary = {}
var _trap_blast_textures: Dictionary = {}
var _door_icon_textures: Dictionary = {}
var _keyword_icon_textures: Dictionary = {}
var _unit_shadow_polygon_cache: Dictionary = {}
var _unit_shadow_bottom_ratio_cache: Dictionary = {}
var _door_opening_frames: Array[Texture2D] = []
var _door_opening_flipped_frames: Array[Texture2D] = []
var _tooltip_regions: Array[Dictionary] = []
var _idle_frames_by_type: Dictionary = {}
var _death_frames_by_type: Dictionary = {}
var _idle_animating: bool = false
var _idle_elapsed: float = 0.0
var _idle_frame_key: String = ""
var _board_layout_cache_valid: bool = false
var _board_layout_cache_size: Vector2 = Vector2(-1.0, -1.0)
var _board_layout_cache_tiles: Array[Vector2i] = []
var _board_layout_cache_extents: Dictionary = {}
var _board_layout_cache_tile_width: float = 90.0
var _board_layout_cache_origin: Vector2 = Vector2.ZERO
var _board_layout_signature: String = ""
var _floor_variant_signature: String = ""
var _moss_signature: String = ""
var _continuous_presentation_elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	custom_minimum_size = Vector2(960.0, 680.0)
	set_process(true)
	_load_assets()

func _process(delta: float) -> void:
	if _presentation_needs_continuous_redraw():
		_continuous_presentation_elapsed += delta
		if _continuous_presentation_elapsed >= CONTINUOUS_PRESENTATION_REDRAW_SECONDS:
			_continuous_presentation_elapsed = 0.0
			queue_redraw()
	else:
		_continuous_presentation_elapsed = 0.0
	var animating: bool = _any_idle_animation_active()
	if animating != _idle_animating:
		_idle_animating = animating
		_idle_elapsed = 0.0
		_idle_frame_key = ""
		queue_redraw()
	if not animating:
		return
	_idle_elapsed = wrapf(_idle_elapsed + delta, 0.0, 3600.0)
	var next_frame_key: String = _active_idle_frame_key()
	if next_frame_key != _idle_frame_key:
		_idle_frame_key = next_frame_key
		queue_redraw()

func _presentation_needs_continuous_redraw() -> bool:
	if not visible:
		return false
	if _ambient_particles_active():
		return true
	if _campfire_atmosphere_active():
		return true
	if _pillar_torch_ember_motes_active():
		return true
	if _equipment_pickup_beacon_active():
		return true
	if bool(presentation.get("pulse_attack_tiles", false)) and not attack_tiles.is_empty():
		return true
	if bool(presentation.get("pulse_exit_tiles", false)) and not exit_tiles.is_empty():
		return true
	if presentation.is_empty():
		return false
	if not (presentation.get("damage_preview", {}) as Dictionary).is_empty():
		return true
	if not (presentation.get("impact_actor_keys", []) as Array).is_empty():
		return true
	if not (presentation.get("impact_decals", []) as Array).is_empty():
		return true
	if not (presentation.get("death_animation_units", []) as Array).is_empty():
		return true
	if not (presentation.get("preview_units", []) as Array).is_empty():
		return true
	var effect: Dictionary = presentation.get("effect", {})
	return bool(effect.get("preview", false))

func _equipment_pickup_beacon_active() -> bool:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		if str(loot.get("kind", "")) == "equipment":
			return true
	return false

func _any_idle_animation_active() -> bool:
	if not visible or combat_state.is_empty():
		return false
	if not _idle_frames_by_type.is_empty():
		for unit: Dictionary in _visible_units():
			if str(unit.get("role", "")) != "npc" and int(unit.get("hp", 0)) <= 0:
				continue
			if _unit_idle_animation_active(unit):
				return true
	if not _scene_prop_idle_frames.is_empty():
		for prop_var: Variant in presentation.get("scene_props", []):
			if typeof(prop_var) == TYPE_DICTIONARY and _scene_prop_idle_animation_active(prop_var as Dictionary):
				return true
	if _pillar_torch_idle_animation_active():
		return true
	return false

func set_combat_state(next_state: Dictionary, next_move_tiles: Array = [], next_attack_tiles: Array = [], next_selected_tile: Vector2i = Vector2i(-1, -1), next_status_label: String = "", next_status_detail: String = "", next_exit_tiles: Dictionary = {}, next_exit_icon_ids: Dictionary = {}, next_presentation: Dictionary = {}) -> void:
	var next_room_grid_signature: String = _room_grid_signature(next_state)
	var next_layout_signature: String = _layout_signature_for_state(next_state, next_exit_tiles, next_presentation, next_room_grid_signature)
	var next_floor_signature: String = next_room_grid_signature
	var next_moss_signature: String = _moss_signature_for_state(next_state)
	combat_state = next_state.duplicate(true)
	move_tiles = _vector2i_array(next_move_tiles)
	attack_tiles = _vector2i_array(next_attack_tiles)
	selected_tile = next_selected_tile
	status_label = next_status_label
	status_detail = next_status_detail
	exit_tiles = next_exit_tiles.duplicate(true)
	exit_icon_ids = next_exit_icon_ids.duplicate(true)
	presentation = next_presentation.duplicate(true)
	if next_layout_signature != _board_layout_signature:
		_board_layout_signature = next_layout_signature
		_invalidate_board_layout_cache()
	if next_floor_signature != _floor_variant_signature:
		_floor_variant_signature = next_floor_signature
		_floor_variant_by_tile = _build_floor_variant_lookup(combat_state.get("grid", []))
	if next_moss_signature != _moss_signature:
		_moss_signature = next_moss_signature
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
		if _left_drag_start_tile.x >= 0 and next_hover.x >= 0 and (int(event.button_mask) & MOUSE_BUTTON_MASK_LEFT) != 0:
			if next_hover != _left_drag_start_tile:
				_left_drag_moved = true
			if _left_drag_moved:
				tile_dragged.emit(_left_drag_start_tile, next_hover)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked: Vector2i = _tile_at_point(event.position)
		if event.pressed:
			_left_drag_start_tile = clicked
			_left_drag_moved = false
		elif _left_drag_start_tile.x >= 0:
			if clicked.x >= 0 and _left_drag_moved:
				tile_drag_released.emit(_left_drag_start_tile, clicked)
			elif clicked.x >= 0:
				tile_clicked.emit(clicked)
			_left_drag_start_tile = Vector2i(-1, -1)
			_left_drag_moved = false
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
	_draw_campfire_room_firelight(tiles)
	_draw_ambient_particles(tiles)
	for tile: Vector2i in tiles:
		_draw_tile_overlays(tile)
	_draw_path_preview()
	_draw_impact_decals()
	var units_to_draw: Array[Dictionary] = _visible_units()
	_draw_scene_objects(grid, tiles, units_to_draw)
	_draw_pillar_torch_ember_motes(tiles, units_to_draw)
	_draw_campfire_ember_motes()
	_draw_unit_huds(units_to_draw)
	_draw_effect_overlay()
	_draw_movement_risk_chips()
	_draw_status_text()
	_draw_floating_texts()

func _draw_empty_state() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(34, 52), "No active combat.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("f0e5cf"))

func _campfire_atmosphere_active() -> bool:
	return not _campfire_scene_props().is_empty()

func _campfire_scene_props() -> Array:
	var props: Array = []
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		if str(prop.get("kind", "")) == "campfire_bonfire":
			props.append(prop)
	return props

func _draw_campfire_room_firelight(tiles: Array[Vector2i]) -> void:
	var props: Array = _campfire_scene_props()
	if props.is_empty() or tiles.is_empty():
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	for prop_var: Variant in props:
		var prop: Dictionary = prop_var
		var source_tile: Vector2i = prop.get("tile", Vector2i(4, 4))
		var source_seed: int = _campfire_atmosphere_seed(source_tile)
		var floor_point: Vector2 = _campfire_floor_light_point(prop)
		var flame_point: Vector2 = _campfire_flame_point(prop)
		_draw_campfire_soft_floor_bloom(floor_point, flame_point, source_seed, time_seconds)

func _draw_campfire_soft_floor_bloom(floor_point: Vector2, flame_point: Vector2, source_seed: int, time_seconds: float) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", 0)
	var flicker: float = 0.88 + 0.12 * sin(time_seconds * 6.9 + _ambient_hash01(source_seed + 5) * TAU)
	var slow_breath: float = 0.5 + 0.5 * sin(time_seconds * 1.55 + _ambient_hash01(source_seed + 7) * TAU)
	var drift := Vector2(
		sin(time_seconds * 0.74 + _ambient_hash01(source_seed + 11) * TAU) * tile_width * 0.045,
		sin(time_seconds * 0.58 + _ambient_hash01(source_seed + 13) * TAU) * tile_height * 0.08
	)
	_draw_campfire_soft_ellipse(
		floor_point + drift + Vector2(0.0, tile_height * 0.12),
		tile_width * (1.78 + slow_breath * 0.08),
		Vector2(1.78, 0.78),
		-0.04,
		Color(1.0, 0.40, 0.12, CAMPFIRE_FIRELIGHT_BLOOM_ALPHA * 0.62 * flicker),
		24
	)
	_draw_campfire_soft_ellipse(
		floor_point - drift * 0.50 + Vector2(-tile_width * 0.15, tile_height * 0.03),
		tile_width * 1.28,
		Vector2(1.58, 0.72),
		0.16,
		Color(1.0, 0.61, 0.23, CAMPFIRE_FIRELIGHT_BLOOM_ALPHA * 0.38 * flicker),
		18
	)
	_draw_campfire_soft_ellipse(
		floor_point + drift * 0.62 + Vector2(tile_width * 0.12, -tile_height * 0.08),
		tile_width * 0.74,
		Vector2(1.32, 0.66),
		-0.20,
		Color(1.0, 0.80, 0.38, CAMPFIRE_FIRELIGHT_CORE_ALPHA * 0.36 * flicker),
		14
	)
	if glow_texture != null:
		_draw_ambient_particle_sprite(
			glow_texture,
			flame_point + Vector2(0.0, tile_height * 0.24),
			Vector2(tile_width * 1.92, tile_height * 2.02),
			0.0,
			CAMPFIRE_FIRELIGHT_CORE_ALPHA * 0.22 * flicker,
			Color(1.0, 0.50, 0.14, 1.0)
		)
		return
	draw_circle(floor_point, tile_width * 1.65, Color(1.0, 0.48, 0.18, CAMPFIRE_FIRELIGHT_BLOOM_ALPHA * 0.22 * flicker))
	draw_circle(flame_point, tile_width * 0.74, Color(1.0, 0.78, 0.34, CAMPFIRE_FIRELIGHT_CORE_ALPHA * 0.20 * flicker))

func _draw_campfire_soft_ellipse(center: Vector2, radius: float, ellipse_scale: Vector2, rotation: float, color: Color, layer_count: int) -> void:
	if layer_count <= 0 or color.a <= 0.0:
		return
	for layer_index: int in range(layer_count, 0, -1):
		var t: float = float(layer_index) / float(layer_count)
		var inner_weight: float = pow(1.0 - t, 0.84)
		var layer_alpha: float = color.a * (0.022 + inner_weight * 0.056)
		var layer_radius: float = radius * (0.10 + t * 0.90)
		draw_set_transform(center, rotation, ellipse_scale)
		draw_circle(Vector2.ZERO, layer_radius, Color(color.r, color.g, color.b, layer_alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_campfire_ember_motes() -> void:
	var props: Array = _campfire_scene_props()
	if props.is_empty():
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	for prop_var: Variant in props:
		var prop: Dictionary = prop_var
		var source_tile: Vector2i = prop.get("tile", Vector2i(4, 4))
		var source_seed: int = _campfire_atmosphere_seed(source_tile)
		var source_point: Vector2 = _campfire_flame_point(prop) + Vector2(0.0, _tile_height() * 0.08)
		for index: int in range(CAMPFIRE_EMBER_MOTE_COUNT):
			var seed: int = source_seed + index * 1759
			var speed: float = lerpf(0.18, 0.34, _ambient_hash01(seed + 13))
			var cycle: float = wrapf(_ambient_hash01(seed + 17) + time_seconds * speed, 0.0, 1.0)
			var center_bias: float = _campfire_ember_center_bias(seed)
			var edge_lifetime: float = lerpf(0.54, 1.0, pow(center_bias, 0.72))
			if cycle > edge_lifetime:
				continue
			var lifetime_cycle: float = cycle / edge_lifetime
			var alpha: float = pow(clampf(sin(lifetime_cycle * PI), 0.0, 1.0), 0.72) * CAMPFIRE_EMBER_MOTE_ALPHA
			alpha *= lerpf(0.62, 1.0, center_bias)
			if alpha <= 0.04:
				continue
			var point: Vector2 = _campfire_ember_mote_point(source_point, seed, cycle, time_seconds)
			var previous_cycle: float = maxf(0.0, cycle - _ambient_motion_blur_cycle_delta("fire"))
			var previous_point: Vector2 = _campfire_ember_mote_point(source_point, seed, previous_cycle, time_seconds - 0.12)
			var velocity: Vector2 = point - previous_point
			var draw_width: float = _tile_width() * lerpf(0.060, 0.122, _ambient_hash01(seed + 37))
			var variant_index: int = posmod(index + int(_ambient_hash01(seed + 39) * float(AMBIENT_PARTICLE_ATLAS_COLUMNS)), AMBIENT_PARTICLE_ATLAS_COLUMNS)
			var texture: Texture2D = _ambient_particle_texture("fire", variant_index)
			var soft_texture: Texture2D = _ambient_fire_soft_texture(variant_index)
			var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", variant_index)
			if texture == null and soft_texture == null:
				draw_circle(point, draw_width * 0.45, Color(1.0, 0.66, 0.28, minf(alpha * 0.46, 0.74)))
				continue
			if texture == null:
				texture = soft_texture
			var mote_alpha: float = alpha * lerpf(0.28, 0.58, _ambient_hash01(seed + 41))
			var texture_size: Vector2 = texture.get_size()
			var draw_size := Vector2(draw_width, draw_width)
			if texture_size.x > 0.0:
				draw_size.y = draw_width * texture_size.y / texture_size.x
			var rotation: float = lerpf(-0.34, 0.34, _ambient_hash01(seed + 43)) + sin(time_seconds * 0.72 + _ambient_hash01(seed + 47) * TAU) * 0.11
			_draw_ambient_fire_particle(texture, soft_texture, glow_texture, point, velocity, draw_size, rotation, mote_alpha, seed, time_seconds)
			draw_circle(point, maxf(1.6, draw_width * 0.14), Color(1.0, 0.84, 0.38, minf(mote_alpha * 0.66, 0.72)))

func _campfire_ember_mote_point(source_point: Vector2, seed: int, cycle: float, time_seconds: float) -> Vector2:
	var tile_width: float = _tile_width()
	var base_lateral: float = _campfire_ember_base_lateral(seed)
	var center_bias: float = 1.0 - absf(base_lateral)
	var plume_width: float = lerpf(0.52, 0.10, pow(cycle, 0.62)) * tile_width
	var lateral: float = base_lateral * plume_width
	var sway: float = sin(time_seconds * lerpf(1.1, 2.5, _ambient_hash01(seed + 29)) + _ambient_hash01(seed + 31) * TAU) * tile_width * lerpf(0.020, 0.105, cycle)
	var height_scale: float = lerpf(0.50, 1.08, pow(center_bias, 0.70))
	var rise: float = pow(cycle, 0.72) * tile_width * CAMPFIRE_EMBER_PLUME_HEIGHT_SCALE * height_scale
	var chimney_pull: float = sin(cycle * TAU + _ambient_hash01(seed + 33) * TAU) * tile_width * 0.035
	return source_point + Vector2(lateral + sway + chimney_pull, _tile_height() * 0.18 - rise)

func _campfire_ember_base_lateral(seed: int) -> float:
	return lerpf(-1.0, 1.0, _ambient_hash01(seed + 23))

func _campfire_ember_center_bias(seed: int) -> float:
	return 1.0 - absf(_campfire_ember_base_lateral(seed))

func _campfire_prop_draw_rect(prop: Dictionary) -> Rect2:
	var texture: Texture2D = _texture_for_scene_prop(prop)
	if texture != null:
		return _scene_prop_rect(texture, prop)
	var tile: Vector2i = prop.get("tile", Vector2i(4, 4))
	return Rect2(_tile_center(tile), Vector2.ZERO)

func _campfire_flame_point(prop: Dictionary) -> Vector2:
	var draw_rect: Rect2 = _campfire_prop_draw_rect(prop)
	if draw_rect.size == Vector2.ZERO:
		return draw_rect.position + Vector2(0.0, -_tile_height() * 0.18)
	return Vector2(draw_rect.get_center().x, draw_rect.position.y + draw_rect.size.y * 0.45)

func _campfire_floor_light_point(prop: Dictionary) -> Vector2:
	var draw_rect: Rect2 = _campfire_prop_draw_rect(prop)
	if draw_rect.size == Vector2.ZERO:
		return draw_rect.position
	return Vector2(draw_rect.get_center().x, draw_rect.position.y + draw_rect.size.y * 0.62)

func _campfire_atmosphere_seed(source_tile: Vector2i) -> int:
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	return room_coord.x * 81283 + room_coord.y * 52639 + source_tile.x * 947 + source_tile.y * 1223 + 71

func _ambient_particles_active() -> bool:
	if combat_state.is_empty():
		return false
	return ElementData.is_elemental(_ambient_element_id())

func _ambient_element_id() -> String:
	return str(combat_state.get("room_element", ElementData.NONE))

func _draw_ambient_particles(tiles: Array[Vector2i]) -> void:
	var element_id: String = _ambient_element_id()
	if tiles.is_empty() or not ElementData.is_elemental(element_id):
		return
	var particle_count: int = _ambient_particle_count(element_id, tiles.size())
	if particle_count <= 0:
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var room_seed: int = _ambient_room_seed(element_id)
	for index: int in range(particle_count):
		var particle_seed: int = room_seed + index * 7919
		var tile_index: int = posmod(_ambient_hash(particle_seed + 17), tiles.size())
		var base_point: Vector2 = _tile_center(tiles[tile_index])
		_draw_ambient_particle(element_id, base_point, particle_seed, time_seconds)

func _ambient_particle_count(element_id: String, tile_count: int) -> int:
	var base_count: int = 0
	match element_id:
		"fire":
			base_count = 84
		"ice":
			base_count = 172
		"lightning":
			base_count = 56
		"air":
			base_count = 43
		"earth":
			base_count = 88
	var board_scale: float = clampf(float(tile_count) / 72.0, 0.72, 1.14)
	return maxi(0, int(roundf(float(base_count) * board_scale * AMBIENT_PARTICLE_DENSITY)))

func _ambient_room_seed(element_id: String) -> int:
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	return room_coord.x * 92821 + room_coord.y * 68917 + _ambient_element_seed(element_id) * 3571

func _ambient_element_seed(element_id: String) -> int:
	match element_id:
		"fire":
			return 11
		"ice":
			return 23
		"lightning":
			return 37
		"air":
			return 43
		"earth":
			return 59
		_:
			return 3

func _ambient_hash(seed: int) -> int:
	var value: int = posmod(seed, 2147483647)
	value = posmod(value * 1103515245 + 12345, 2147483647)
	value = posmod(value * 1103515245 + 12345, 2147483647)
	return value

func _ambient_hash01(seed: int) -> float:
	return float(posmod(_ambient_hash(seed), 10000)) / 10000.0

func _ambient_cycle(seed: int, time_seconds: float, speed: float) -> float:
	return wrapf(_ambient_hash01(seed) + time_seconds * speed * AMBIENT_PARTICLE_SPEED_SCALE, 0.0, 1.0)

func _ambient_particle_alpha(cycle: float) -> float:
	return clampf(sin(cycle * PI), 0.0, 1.0)

func _draw_ambient_particle(element_id: String, base_point: Vector2, seed: int, time_seconds: float) -> void:
	var variant_index: int = int(_ambient_hash01(seed + 41) * float(AMBIENT_PARTICLE_ATLAS_COLUMNS))
	var texture: Texture2D = _ambient_particle_texture(element_id, variant_index)
	if texture == null:
		return
	var glow_texture: Texture2D = _ambient_particle_glow_texture(element_id, variant_index)
	var air_soft_texture: Texture2D = null
	var cycle: float = _ambient_cycle(seed + 101, time_seconds, _ambient_particle_speed(element_id, seed))
	if element_id == "air":
		var wisp_variant_index: int = _ambient_air_wisp_variant_index(seed)
		var wisp_texture: Texture2D = _ambient_air_wisp_texture(wisp_variant_index, AMBIENT_AIR_WISP_FULL_FRAME_INDEX)
		if wisp_texture != null:
			texture = wisp_texture
		air_soft_texture = _ambient_air_wisp_soft_texture(wisp_variant_index)
		var wisp_glow_texture: Texture2D = _ambient_air_wisp_glow_texture(wisp_variant_index, AMBIENT_AIR_WISP_FULL_FRAME_INDEX)
		if wisp_glow_texture != null:
			glow_texture = wisp_glow_texture
	var alpha: float = _ambient_alpha_for_element(element_id, cycle)
	if alpha <= 0.04:
		return
	var tile_width: float = _tile_width()
	var point: Vector2 = base_point + _ambient_particle_offset(element_id, seed, cycle, time_seconds, tile_width)
	var previous_cycle: float = wrapf(cycle - _ambient_motion_blur_cycle_delta(element_id), 0.0, 1.0)
	var previous_point: Vector2 = base_point + _ambient_particle_offset(element_id, seed, previous_cycle, time_seconds - 0.12, tile_width)
	var velocity: Vector2 = point - previous_point
	var draw_width: float = _ambient_particle_draw_width(element_id, seed)
	var texture_size: Vector2 = texture.get_size()
	var draw_size := Vector2(draw_width, draw_width)
	if texture_size.x > 0.0:
		draw_size.y = draw_width * texture_size.y / texture_size.x
	var rotation: float = _ambient_particle_rotation(element_id, seed, time_seconds)
	if element_id == "fire":
		_draw_ambient_fire_particle(
			texture,
			_ambient_fire_soft_texture(variant_index),
			glow_texture,
			point,
			velocity,
			draw_size,
			rotation,
			alpha,
			seed,
			time_seconds
		)
		return
	if element_id == "air":
		_draw_ambient_air_wisp_particle(texture, air_soft_texture, glow_texture, point, velocity, draw_size, rotation, alpha)
		return
	if glow_texture != null:
		_draw_ambient_particle_trail(glow_texture, point, velocity, draw_size, alpha, element_id)
		_draw_ambient_particle_sprite(glow_texture, point, draw_size * _ambient_glow_scale(element_id), rotation, alpha * _ambient_glow_alpha(element_id))
	_draw_ambient_particle_sprite(texture, point, draw_size, rotation, alpha)

func _ambient_particle_texture(element_id: String, variant_index: int) -> Texture2D:
	if _ambient_particle_atlas == null:
		return null
	return _ambient_particle_texture_from_atlas(_ambient_particle_atlas, _ambient_particle_textures, element_id, variant_index)

func _ambient_particle_glow_texture(element_id: String, variant_index: int) -> Texture2D:
	if _ambient_particle_glow_atlas == null:
		return null
	return _ambient_particle_texture_from_atlas(_ambient_particle_glow_atlas, _ambient_particle_glow_textures, element_id, variant_index)

func _ambient_fire_soft_texture(variant_index: int) -> Texture2D:
	if _ambient_fire_soft_atlas == null:
		return null
	var col: int = posmod(variant_index, AMBIENT_FIRE_SOFT_ATLAS_COLUMNS)
	var cache_key: String = str(col)
	if _ambient_fire_soft_textures.has(cache_key):
		return _ambient_fire_soft_textures.get(cache_key, null)
	var atlas_size: Vector2 = _ambient_fire_soft_atlas.get_size()
	var cell_size := Vector2(atlas_size.x / float(AMBIENT_FIRE_SOFT_ATLAS_COLUMNS), atlas_size.y)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _ambient_fire_soft_atlas
	atlas_texture.region = Rect2(Vector2(cell_size.x * float(col), 0.0), cell_size)
	_ambient_fire_soft_textures[cache_key] = atlas_texture
	return atlas_texture

func _ambient_air_wisp_texture(variant_index: int, frame_index: int) -> Texture2D:
	if _ambient_air_wisp_atlas == null:
		return null
	return _ambient_air_wisp_texture_from_atlas(_ambient_air_wisp_atlas, _ambient_air_wisp_textures, variant_index, frame_index)

func _ambient_air_wisp_soft_texture(variant_index: int) -> Texture2D:
	if _ambient_air_wisp_soft_atlas == null:
		return null
	var col: int = posmod(variant_index, AMBIENT_AIR_WISP_SOFT_ATLAS_COLUMNS)
	var cache_key: String = str(col)
	if _ambient_air_wisp_soft_textures.has(cache_key):
		return _ambient_air_wisp_soft_textures.get(cache_key, null)
	var atlas_size: Vector2 = _ambient_air_wisp_soft_atlas.get_size()
	var cell_size := Vector2(atlas_size.x / float(AMBIENT_AIR_WISP_SOFT_ATLAS_COLUMNS), atlas_size.y)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _ambient_air_wisp_soft_atlas
	atlas_texture.region = Rect2(Vector2(cell_size.x * float(col), 0.0), cell_size)
	_ambient_air_wisp_soft_textures[cache_key] = atlas_texture
	return atlas_texture

func _ambient_air_wisp_glow_texture(variant_index: int, frame_index: int) -> Texture2D:
	if _ambient_air_wisp_glow_atlas == null:
		return null
	return _ambient_air_wisp_texture_from_atlas(_ambient_air_wisp_glow_atlas, _ambient_air_wisp_glow_textures, variant_index, frame_index)

func _ambient_particle_texture_from_atlas(atlas: Texture2D, cache: Dictionary, element_id: String, variant_index: int) -> Texture2D:
	var row: int = _ambient_particle_row(element_id)
	if row < 0:
		return null
	var col: int = posmod(variant_index, AMBIENT_PARTICLE_ATLAS_COLUMNS)
	var cache_key: String = "%d:%d" % [row, col]
	if cache.has(cache_key):
		return cache.get(cache_key, null)
	var atlas_size: Vector2 = atlas.get_size()
	var cell_size := Vector2(
		atlas_size.x / float(AMBIENT_PARTICLE_ATLAS_COLUMNS),
		atlas_size.y / float(AMBIENT_PARTICLE_ATLAS_ROWS)
	)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = atlas
	atlas_texture.region = Rect2(Vector2(cell_size.x * float(col), cell_size.y * float(row)), cell_size)
	cache[cache_key] = atlas_texture
	return atlas_texture

func _ambient_air_wisp_texture_from_atlas(atlas: Texture2D, cache: Dictionary, variant_index: int, frame_index: int) -> Texture2D:
	var row: int = posmod(variant_index, AMBIENT_AIR_WISP_VARIANTS)
	var col: int = clampi(frame_index, 0, AMBIENT_AIR_WISP_FRAME_COLUMNS - 1)
	var cache_key: String = "%d:%d" % [row, col]
	if cache.has(cache_key):
		return cache.get(cache_key, null)
	var atlas_size: Vector2 = atlas.get_size()
	var cell_size := Vector2(
		atlas_size.x / float(AMBIENT_AIR_WISP_FRAME_COLUMNS),
		atlas_size.y / float(AMBIENT_AIR_WISP_VARIANTS)
	)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = atlas
	atlas_texture.region = Rect2(Vector2(cell_size.x * float(col), cell_size.y * float(row)), cell_size)
	cache[cache_key] = atlas_texture
	return atlas_texture

func _ambient_particle_row(element_id: String) -> int:
	match element_id:
		"fire":
			return 0
		"ice":
			return 1
		"lightning":
			return 2
		"air":
			return 3
		"earth":
			return 4
		_:
			return -1

func _ambient_particle_speed(element_id: String, seed: int) -> float:
	match element_id:
		"fire":
			return lerpf(0.105, 0.170, _ambient_hash01(seed + 2))
		"ice":
			return lerpf(0.085, 0.140, _ambient_hash01(seed + 2))
		"lightning":
			return lerpf(0.70, 1.15, _ambient_hash01(seed + 2))
		"air":
			return lerpf(0.12, 0.20, _ambient_hash01(seed + 2))
		"earth":
			return lerpf(0.060, 0.105, _ambient_hash01(seed + 2))
		_:
			return 0.10

func _ambient_alpha_for_element(element_id: String, cycle: float) -> float:
	if element_id == "lightning":
		var pulse: float = 1.0 - clampf(absf(cycle - 0.16) / 0.24, 0.0, 1.0)
		return clampf(pulse * AMBIENT_PARTICLE_OPACITY, 0.0, 1.0)
	if element_id == "air":
		return clampf(_ambient_particle_alpha(cycle) * AMBIENT_PARTICLE_OPACITY, 0.0, 1.0)
	var floor_alpha: float = 0.12 if element_id in ["fire", "ice"] else 0.08
	return clampf(lerpf(floor_alpha, 1.0, _ambient_particle_alpha(cycle)) * AMBIENT_PARTICLE_OPACITY, 0.0, 1.0)

func _ambient_particle_offset(element_id: String, seed: int, cycle: float, time_seconds: float, tile_width: float) -> Vector2:
	var lateral: float = lerpf(-0.54, 0.54, _ambient_hash01(seed + 3)) * tile_width
	var y_jitter: float = lerpf(-0.18, 0.22, _ambient_hash01(seed + 4)) * tile_width
	match element_id:
		"fire":
			return Vector2(
				lateral + sin(time_seconds * lerpf(1.2, 2.5, _ambient_hash01(seed + 5)) + _ambient_hash01(seed + 6) * TAU) * tile_width * 0.07,
				_tile_height() * 0.30 - cycle * tile_width * 0.90
			)
		"ice":
			return Vector2(
				lateral + sin(time_seconds * lerpf(0.8, 1.6, _ambient_hash01(seed + 5)) + _ambient_hash01(seed + 6) * TAU) * tile_width * 0.12 - cycle * tile_width * 0.16,
				-tile_width * 0.66 + cycle * tile_width * 1.02
			)
		"lightning":
			return Vector2(lateral, y_jitter - tile_width * 0.10)
		"air":
			var wind_direction: float = _ambient_air_wind_direction()
			return Vector2(
				lateral + (cycle - 0.5) * tile_width * 1.55 * wind_direction,
				y_jitter + sin((cycle + _ambient_hash01(seed + 5)) * TAU) * tile_width * 0.10
			)
		"earth":
			return Vector2(
				lateral + sin(time_seconds * 0.7 + _ambient_hash01(seed + 5) * TAU) * tile_width * 0.06,
				y_jitter - cycle * tile_width * 0.24
			)
		_:
			return Vector2(lateral, y_jitter)

func _ambient_particle_draw_width(element_id: String, seed: int) -> float:
	var tile_width: float = _tile_width()
	var min_scale: float = 0.0
	var max_scale: float = 0.0
	match element_id:
		"fire":
			min_scale = 0.0425
			max_scale = 0.08
		"ice":
			min_scale = 0.08
			max_scale = 0.15
		"lightning":
			min_scale = 0.135
			max_scale = 0.2625
		"air":
			min_scale = 0.20
			max_scale = 0.39
		"earth":
			min_scale = 0.15
			max_scale = 0.30
		_:
			min_scale = 0.16
			max_scale = 0.28
	return tile_width * lerpf(min_scale, max_scale, _ambient_hash01(seed + 9))

func _ambient_particle_rotation(element_id: String, seed: int, time_seconds: float) -> float:
	var base_angle: float = lerpf(-0.32, 0.32, _ambient_hash01(seed + 10))
	match element_id:
		"air":
			return _ambient_air_wisp_rotation(seed, time_seconds)
		"earth":
			return base_angle + sin(time_seconds * 0.45 + _ambient_hash01(seed + 11) * TAU) * 0.12
		"lightning":
			return lerpf(-0.46, 0.46, _ambient_hash01(seed + 10))
		_:
			return base_angle

func _ambient_air_wind_direction() -> float:
	return 1.0 if _ambient_hash01(_ambient_room_seed("air") + 73) >= 0.5 else -1.0

func _ambient_air_wisp_variant_index(seed: int) -> int:
	return 1 if _ambient_hash01(seed + 41) < 0.72 else 3

func _ambient_air_wisp_rotation(seed: int, time_seconds: float) -> float:
	var wind_direction: float = _ambient_air_wind_direction()
	var variant_index: int = _ambient_air_wisp_variant_index(seed)
	var base_angle: float = 0.0 if wind_direction > 0.0 else PI
	if variant_index == 3:
		base_angle = PI * 0.5 if wind_direction > 0.0 else -PI * 0.5
	var wobble: float = lerpf(-0.08, 0.08, _ambient_hash01(seed + 10))
	return base_angle + wobble + sin(time_seconds * 0.38 + _ambient_hash01(seed + 11) * TAU) * 0.045

func _draw_ambient_fire_particle(texture: Texture2D, soft_texture: Texture2D, glow_texture: Texture2D, point: Vector2, velocity: Vector2, draw_size: Vector2, rotation: float, alpha: float, seed: int, time_seconds: float) -> void:
	var flicker: float = 0.88 + sin(time_seconds * lerpf(7.0, 10.5, _ambient_hash01(seed + 14)) + _ambient_hash01(seed + 15) * TAU) * 0.12
	var ember_offset := Vector2(
		sin(time_seconds * lerpf(1.6, 2.8, _ambient_hash01(seed + 16)) + _ambient_hash01(seed + 17) * TAU) * draw_size.x * 0.10,
		sin(time_seconds * lerpf(2.2, 3.8, _ambient_hash01(seed + 18)) + _ambient_hash01(seed + 19) * TAU) * draw_size.y * 0.05
	)
	if glow_texture != null:
		_draw_ambient_particle_trail(glow_texture, point, velocity, draw_size, alpha * 0.90, "fire")
		_draw_ambient_particle_sprite(
			glow_texture,
			point + ember_offset * 0.45,
			draw_size * Vector2(2.35, 2.05),
			rotation + sin(time_seconds * 0.9 + _ambient_hash01(seed + 20) * TAU) * 0.16,
			alpha * 0.24 * flicker,
			Color(1.0, 0.60, 0.22, 1.0)
		)
	if soft_texture != null:
		_draw_ambient_particle_sprite(
			soft_texture,
			point + ember_offset,
			draw_size * Vector2(1.30, 1.18),
			rotation + sin(time_seconds * 1.3 + _ambient_hash01(seed + 21) * TAU) * 0.22,
			alpha * 0.82 * flicker,
			Color(1.0, 0.78, 0.42, 1.0)
		)
		_draw_ambient_particle_sprite(
			soft_texture,
			point - ember_offset * 0.35,
			draw_size * Vector2(0.72, 0.68),
			rotation - sin(time_seconds * 1.7 + _ambient_hash01(seed + 22) * TAU) * 0.18,
			alpha * 0.46,
			Color(1.0, 0.94, 0.66, 1.0)
		)
	_draw_ambient_particle_sprite(
		texture,
		point + ember_offset * 0.18,
		draw_size * Vector2(0.58, 0.56),
		rotation,
		alpha * 0.16,
		Color(1.0, 0.72, 0.38, 1.0)
	)

func _draw_ambient_air_wisp_particle(texture: Texture2D, soft_texture: Texture2D, glow_texture: Texture2D, point: Vector2, velocity: Vector2, draw_size: Vector2, rotation: float, alpha: float) -> void:
	if glow_texture != null:
		_draw_ambient_particle_trail(glow_texture, point, velocity, draw_size, alpha * 0.82, "air")
		_draw_ambient_particle_sprite(
			glow_texture,
			point,
			draw_size * _ambient_glow_scale("air"),
			rotation,
			alpha * 0.14,
			Color(0.70, 0.90, 1.0, 1.0)
		)
	if soft_texture != null:
		_draw_ambient_particle_sprite(
			soft_texture,
			point,
			draw_size,
			rotation,
			alpha * 0.82,
			Color(0.90, 0.98, 1.0, 1.0)
		)
		_draw_ambient_particle_sprite(
			soft_texture,
			point,
			draw_size * Vector2(0.82, 0.82),
			rotation,
			alpha * 0.30,
			Color(1.0, 1.0, 1.0, 1.0)
		)
		_draw_ambient_particle_sprite(
			texture,
			point,
			draw_size,
			rotation,
			alpha * 0.26,
			Color(0.94, 1.0, 1.0, 1.0)
		)
	else:
		_draw_ambient_particle_sprite(texture, point, draw_size, rotation, alpha)

func _ambient_motion_blur_cycle_delta(element_id: String) -> float:
	match element_id:
		"fire":
			return 0.055
		"ice":
			return 0.045
		"lightning":
			return 0.085
		"air":
			return 0.070
		"earth":
			return 0.038
		_:
			return 0.050

func _ambient_glow_scale(element_id: String) -> Vector2:
	match element_id:
		"fire":
			return Vector2(1.85, 1.72)
		"lightning":
			return Vector2(2.10, 1.82)
		"air":
			return Vector2(1.95, 1.65)
		_:
			return Vector2(1.72, 1.58)

func _ambient_glow_alpha(element_id: String) -> float:
	match element_id:
		"lightning":
			return 0.24
		"fire":
			return 0.22
		"ice":
			return 0.13
		"air":
			return 0.17
		"earth":
			return 0.14
		_:
			return 0.16

func _draw_ambient_particle_trail(texture: Texture2D, point: Vector2, velocity: Vector2, draw_size: Vector2, alpha: float, element_id: String) -> void:
	if velocity.length_squared() < 4.0:
		return
	var trail_strength: float = _ambient_trail_alpha(element_id) * alpha
	if trail_strength <= 0.01:
		return
	var length_scale: float = clampf(1.0 + velocity.length() / maxf(1.0, _tile_width()) * _ambient_trail_length_scale(element_id), 1.20, 3.80)
	var trail_size := Vector2(draw_size.x * length_scale, draw_size.y * _ambient_trail_height_scale(element_id))
	var trail_center: Vector2 = point - velocity.normalized() * trail_size.x * 0.16
	_draw_ambient_particle_sprite(texture, trail_center, trail_size, velocity.angle(), trail_strength)

func _ambient_trail_alpha(element_id: String) -> float:
	match element_id:
		"lightning":
			return 0.20
		"fire":
			return 0.16
		"ice":
			return 0.08
		"air":
			return 0.15
		"earth":
			return 0.08
		_:
			return 0.11

func _ambient_trail_length_scale(element_id: String) -> float:
	match element_id:
		"lightning":
			return 8.0
		"fire":
			return 5.8
		"ice":
			return 4.2
		"air":
			return 6.5
		"earth":
			return 3.0
		_:
			return 4.0

func _ambient_trail_height_scale(element_id: String) -> float:
	return 0.50 if element_id in ["fire", "lightning", "air"] else 0.62

func _draw_ambient_particle_sprite(texture: Texture2D, point: Vector2, draw_size: Vector2, rotation: float, alpha: float, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	draw_set_transform(point, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, Color(modulate.r, modulate.g, modulate.b, modulate.a * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
		if bool(presentation.get("pulse_exit_tiles", false)):
			_draw_exit_tile_pulse(tile)
	for focus_tile_var: Variant in presentation.get("focus_tiles", []):
		if focus_tile_var == tile:
			draw_colored_polygon(polygon, presentation.get("focus_color", FOCUS_HIGHLIGHT))
	if move_tiles.has(tile):
		draw_colored_polygon(polygon, MOVE_HIGHLIGHT)
		_draw_tile_ring(tile, Color(0.60, 0.91, 0.94, 0.58), 2.0, 0.86)
	var ability_tiles: Array[Vector2i] = _ability_tiles()
	if ability_tiles.has(tile):
		draw_colored_polygon(polygon, ABILITY_HIGHLIGHT)
		_draw_tile_ring(tile, Color(0.55, 0.92, 0.48, 0.62), 2.0, 0.86)
	if attack_tiles.has(tile):
		draw_colored_polygon(polygon, ATTACK_HIGHLIGHT)
		if bool(presentation.get("pulse_attack_tiles", false)):
			_draw_attack_target_pulse(tile)
	if tile == selected_tile:
		draw_colored_polygon(polygon, SELECT_HIGHLIGHT)
	if tile == _hover_tile:
		draw_colored_polygon(polygon, HOVER_HIGHLIGHT)

func _draw_attack_target_pulse(tile: Vector2i) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * TAU * 1.45)
	var alpha: float = lerpf(0.30, 0.78, pulse)
	var width: float = lerpf(1.6, 3.2, pulse)
	var scale: float = lerpf(0.82, 0.96, pulse)
	_draw_tile_ring(tile, Color(1.0, 0.78, 0.44, alpha), width, scale)

func _draw_exit_tile_pulse(tile: Vector2i) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * TAU * 1.15)
	var alpha: float = lerpf(0.26, 0.70, pulse)
	var width: float = lerpf(1.4, 3.0, pulse)
	var scale: float = lerpf(0.84, 0.98, pulse)
	_draw_tile_ring(tile, Color(1.0, 0.83, 0.38, alpha), width, scale)

func _draw_tile_ring(tile: Vector2i, color: Color, width: float, scale: float = 0.92) -> void:
	var center: Vector2 = _tile_center(tile)
	var tile_width: float = _tile_width() * scale
	var tile_height: float = _tile_height() * scale
	var points := PackedVector2Array([
		center + Vector2(0.0, -tile_height * 0.5),
		center + Vector2(tile_width * 0.5, 0.0),
		center + Vector2(0.0, tile_height * 0.5),
		center + Vector2(-tile_width * 0.5, 0.0),
		center + Vector2(0.0, -tile_height * 0.5)
	])
	draw_polyline(points, Color(0.0, 0.0, 0.0, color.a * 0.28), width + 2.0, true)
	draw_polyline(points, color, width, true)

func _draw_scene_objects(grid: Array, tiles: Array[Vector2i], units_to_draw: Array[Dictionary]) -> void:
	var obstruction_entries: Array[Dictionary] = _foreground_obstruction_entries(units_to_draw)
	for tile: Vector2i in tiles:
		_draw_scene_props_for_tile(tile, obstruction_entries)
		_draw_tile_props(grid, tile, obstruction_entries)
		_draw_unit_bodies_for_tile(tile, units_to_draw)

func _draw_scene_props_for_tile(tile: Vector2i, obstruction_entries: Array = []) -> void:
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		if prop.get("tile", Vector2i(-1, -1)) != tile:
			continue
		var texture: Texture2D = _texture_for_scene_prop(prop)
		if texture == null:
			continue
		var draw_rect: Rect2 = _scene_prop_rect(texture, prop)
		var tint: Color = _foreground_blocker_tint("scene_prop", tile, draw_rect, obstruction_entries)
		if str(prop.get("kind", "")) == "campfire_bonfire":
			_draw_campfire_prop_glow(tile, draw_rect)
		_draw_rect_ground_shadow(tile, draw_rect, 0.58, 0.28, 0.16)
		draw_texture_rect(texture, draw_rect, false, tint)

func _draw_campfire_prop_glow(tile: Vector2i, draw_rect: Rect2) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var seed: int = _campfire_atmosphere_seed(tile)
	var flicker: float = 0.80 + 0.20 * sin(time_seconds * 7.9 + _ambient_hash01(seed + 61) * TAU)
	var flame_point: Vector2 = Vector2(draw_rect.get_center().x, draw_rect.position.y + draw_rect.size.y * 0.45)
	var soft_texture: Texture2D = _ambient_fire_soft_texture(1)
	var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", 1)
	if glow_texture != null:
		_draw_ambient_particle_sprite(
			glow_texture,
			flame_point + Vector2(0.0, _tile_height() * 0.10),
			Vector2(_tile_width() * 1.60, _tile_height() * 2.10),
			0.0,
			0.18 * flicker,
			Color(1.0, 0.43, 0.14, 1.0)
		)
	if soft_texture != null:
		_draw_ambient_particle_sprite(
			soft_texture,
			flame_point + Vector2(0.0, -_tile_height() * 0.05),
			Vector2(_tile_width() * 1.10, _tile_height() * 1.64),
			sin(time_seconds * 1.1 + _ambient_hash01(seed + 67) * TAU) * 0.08,
			0.44 * flicker,
			Color(1.0, 0.72, 0.28, 1.0)
		)
		_draw_ambient_particle_sprite(
			soft_texture,
			flame_point + Vector2(0.0, -_tile_height() * 0.22),
			Vector2(_tile_width() * 0.56, _tile_height() * 0.94),
			-sin(time_seconds * 1.4 + _ambient_hash01(seed + 71) * TAU) * 0.10,
			0.34 * flicker,
			Color(1.0, 0.93, 0.58, 1.0)
		)
		return
	draw_circle(flame_point, _tile_width() * 0.68, Color(1.0, 0.45, 0.16, 0.15 * flicker))

func _scene_prop_rect(texture: Texture2D, prop: Dictionary) -> Rect2:
	var tile: Vector2i = prop.get("tile", Vector2i(4, 4))
	var center: Vector2 = _tile_center(tile)
	center.x += _tile_width() * float(prop.get("x_offset_scale", 0.0))
	var default_width_scale: float = RELIC_CHEST_WIDTH_SCALE if str(prop.get("kind", "")) == "relic_chest" else CAMPFIRE_BONFIRE_WIDTH_SCALE
	var width_scale: float = float(prop.get("width_scale", default_width_scale))
	var draw_width: float = _tile_width() * width_scale
	var texture_size: Vector2 = texture.get_size()
	var draw_height: float = draw_width
	if texture_size.x > 0.0:
		draw_height = draw_width * texture_size.y / texture_size.x
	var default_baseline_scale: float = RELIC_CHEST_BASELINE_SCALE if str(prop.get("kind", "")) == "relic_chest" else CAMPFIRE_BONFIRE_BASELINE_SCALE
	var baseline_scale: float = float(prop.get("baseline_scale", default_baseline_scale))
	var bottom_y: float = center.y + _tile_height() * baseline_scale
	return Rect2(Vector2(center.x - draw_width * 0.5, bottom_y - draw_height), Vector2(draw_width, draw_height))

func _foreground_obstruction_entries(units_to_draw: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for unit: Dictionary in units_to_draw:
		entries.append({
			"tile": _effective_unit_tile(unit),
			"rect": _unit_draw_rect(unit)
		})
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		var texture: Texture2D = _texture_for_scene_prop(prop)
		if texture == null:
			continue
		var tile: Vector2i = prop.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		entries.append({
			"tile": tile,
			"rect": _scene_prop_rect(texture, prop)
		})
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if int(terrain.get("hp", 0)) <= 0:
			continue
		var terrain_texture: Texture2D = _terrain_textures.get(str(terrain.get("kind", "")), null)
		if terrain_texture == null:
			continue
		var terrain_tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		if terrain_tile.x < 0:
			continue
		entries.append({
			"tile": terrain_tile,
			"rect": _terrain_rect_for_tile(terrain_tile, terrain_texture, str(terrain.get("kind", "")))
		})
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		var loot_texture: Texture2D = _loot_texture(loot)
		if loot_texture == null:
			continue
		var loot_tile: Vector2i = loot.get("pos", Vector2i(-1, -1))
		if loot_tile.x < 0:
			continue
		entries.append({
			"tile": loot_tile,
			"rect": _loot_rect_for_tile(loot_tile, loot_texture, loot)
		})
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		var trap_tile: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if trap_tile.x < 0:
			continue
		entries.append({
			"tile": trap_tile,
			"rect": _trap_draw_rect(trap_tile)
		})
	return entries

func _draw_prop_moss_overlay(tile_id: String, grid: Array, tile: Vector2i, obstruction_entries: Array) -> void:
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
		draw_texture_rect(texture, moss_rect, false, _foreground_blocker_tint(tile_id, tile, moss_rect, obstruction_entries))
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
	draw_texture_rect(texture, moss_rect, false, _foreground_blocker_tint(tile_id, tile, moss_rect, obstruction_entries))

func _draw_tile_props(grid: Array, tile: Vector2i, obstruction_entries: Array = []) -> void:
	var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
	if tile_id == "wall" and not _is_outer_boundary_tile(grid, tile):
		tile_id = "pillar"
	if tile_id == "pillar":
		var texture: Texture2D = _prop_textures.get("pillar", null)
		if texture != null:
			var frame_rect: Rect2 = _prop_rect_for_tile(tile)
			var draw_rect: Rect2 = _prop_draw_rect(texture, frame_rect)
			_draw_rect_ground_shadow(tile, draw_rect, 0.72, 0.28, 0.24)
			draw_texture_rect(texture, draw_rect, false, _foreground_blocker_tint(tile_id, tile, draw_rect, obstruction_entries))
	elif tile_id == "wall":
		var segments: Array[Dictionary] = _boundary_prop_segments(tile_id, grid, tile)
		for segment: Dictionary in segments:
			var texture: Texture2D = segment.get("texture", null)
			if texture == null:
				continue
			var draw_rect: Rect2 = segment.get("draw_rect", Rect2())
			var source_rect: Rect2 = segment.get("source_rect", Rect2(Vector2.ZERO, texture.get_size()))
			var tint: Color = _foreground_blocker_tint(tile_id, tile, draw_rect, obstruction_entries)
			_draw_wall_segment_shadow(tile, str(segment.get("orientation", "")), draw_rect)
			if source_rect.position == Vector2.ZERO and source_rect.size == texture.get_size():
				draw_texture_rect(texture, draw_rect, false, tint)
			else:
				draw_texture_rect_region(texture, draw_rect, source_rect, tint)
	elif tile_id == "door":
		var door_texture: Texture2D = _door_texture_for_tile(grid, tile)
		if door_texture != null:
			var draw_rect: Rect2 = _prop_draw_rect(door_texture, _door_rect_for_tile(tile, grid))
			var opening_texture: Texture2D = _door_opening_texture_for_tile(grid, tile)
			var tint: Color = _foreground_blocker_tint(tile_id, tile, draw_rect, obstruction_entries)
			_draw_rect_ground_shadow(tile, draw_rect, 0.62, 0.24, 0.18)
			if opening_texture != null:
				draw_texture_rect(opening_texture, _door_opening_draw_rect(opening_texture, door_texture, draw_rect, _door_uses_flipped_orientation(grid, tile)), false, tint)
			else:
				draw_texture_rect(door_texture, draw_rect, false, tint)
				var icon_id: String = str(exit_icon_ids.get(tile, ""))
				var icon_texture: Texture2D = _door_icon_texture(icon_id)
				if icon_texture != null:
					_draw_door_icon(icon_texture, icon_id, door_texture, draw_rect, tint)
	_draw_prop_moss_overlay(tile_id, grid, tile, obstruction_entries)
	if tile_id == "pillar":
		var pillar_texture: Texture2D = _prop_textures.get("pillar", null)
		if pillar_texture != null:
			var pillar_rect: Rect2 = _prop_draw_rect(pillar_texture, _prop_rect_for_tile(tile))
			_draw_pillar_torch_fixtures(tile_id, tile, pillar_rect, obstruction_entries)
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if int(terrain.get("hp", 0)) <= 0:
			continue
		if terrain.get("pos", Vector2i(-1, -1)) != tile:
			continue
		_draw_terrain_object(terrain, obstruction_entries)
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		if loot.get("pos", Vector2i(-1, -1)) != tile:
			continue
		var loot_texture: Texture2D = _loot_texture(loot)
		if loot_texture == null:
			continue
		var loot_rect: Rect2 = _loot_rect_for_tile(tile, loot_texture, loot)
		if _is_equipment_loot(loot):
			_draw_equipment_pickup(tile, loot_rect, loot_texture, loot)
			_register_tooltip(loot_rect.grow(8.0), _loot_tooltip_text(loot))
		else:
			_draw_rect_ground_shadow(tile, loot_rect, 0.62, 0.18, 0.08)
			draw_texture_rect(loot_texture, loot_rect, false)
			_register_tooltip(loot_rect.grow(4.0), _loot_tooltip_text(loot))
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if trap.get("pos", Vector2i(-1, -1)) != tile:
			continue
		_draw_trap_marker(trap)

func _draw_pillar_torch_fixtures(tile_id: String, tile: Vector2i, pillar_rect: Rect2, obstruction_entries: Array) -> void:
	var tint: Color = _foreground_blocker_tint(tile_id, tile, pillar_rect, obstruction_entries)
	var left_texture: Texture2D = _pillar_torch_texture("left")
	var right_texture: Texture2D = _pillar_torch_texture("right")
	if left_texture != null:
		draw_texture_rect(left_texture, _pillar_torch_rect(pillar_rect, left_texture, -1.0), false, tint)
	if right_texture != null:
		draw_texture_rect(right_texture, _pillar_torch_rect(pillar_rect, right_texture, 1.0), false, tint)

func _pillar_torch_texture(side_key: String) -> Texture2D:
	var idle_frames: Array[Texture2D] = _pillar_torch_idle_frames_for_side(side_key)
	if _pillar_torch_idle_animation_active() and not idle_frames.is_empty():
		return idle_frames[_pillar_torch_idle_frame_index(side_key)]
	return _prop_textures.get("column_torch_%s" % side_key, null)

func _pillar_torch_idle_frames_for_side(side_key: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_var: Variant in _pillar_torch_idle_frames.get(side_key, []):
		if frame_var is Texture2D:
			frames.append(frame_var)
	return frames

func _pillar_torch_idle_frame_index(side_key: String) -> int:
	var idle_frames: Array[Texture2D] = _pillar_torch_idle_frames_for_side(side_key)
	if idle_frames.is_empty():
		return 0
	var side_offset: int = 3 if side_key == "right" else 0
	return (int(floor(_idle_elapsed / COLUMN_TORCH_IDLE_FRAME_SECONDS)) + side_offset) % idle_frames.size()

func _pillar_torch_rect(pillar_rect: Rect2, texture: Texture2D, side_sign: float) -> Rect2:
	var draw_width: float = pillar_rect.size.x * COLUMN_TORCH_WIDTH_SCALE
	var draw_height: float = draw_width
	if texture != null and texture.get_size().x > 0.0:
		draw_height = draw_width * texture.get_size().y / texture.get_size().x
	var anchor_x: float = pillar_rect.get_center().x + pillar_rect.size.x * COLUMN_TORCH_FACE_OFFSET_X_SCALE * side_sign
	var top_y: float = pillar_rect.position.y + pillar_rect.size.y * COLUMN_TORCH_TOP_Y_SCALE
	if side_sign < 0.0:
		return Rect2(Vector2(anchor_x - draw_width * 0.84, top_y), Vector2(draw_width, draw_height))
	return Rect2(Vector2(anchor_x - draw_width * 0.16, top_y), Vector2(draw_width, draw_height))

func _draw_pillar_torch_ember_motes(tiles: Array[Vector2i], units_to_draw: Array[Dictionary]) -> void:
	if tiles.is_empty() or not _pillar_torch_ember_motes_active():
		return
	var grid: Array = combat_state.get("grid", [])
	var pillar_texture: Texture2D = _prop_textures.get("pillar", null)
	if pillar_texture == null:
		return
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var obstruction_entries: Array[Dictionary] = _foreground_obstruction_entries(units_to_draw)
	for tile: Vector2i in tiles:
		if not _tile_renders_as_pillar(grid, tile):
			continue
		var pillar_rect: Rect2 = _prop_draw_rect(pillar_texture, _prop_rect_for_tile(tile))
		var tint: Color = _foreground_blocker_tint("pillar", tile, pillar_rect, obstruction_entries)
		var tint_alpha: float = clampf(tint.a, 0.0, 1.0)
		_draw_pillar_torch_ember_motes_for_side(tile, pillar_rect, "left", -1.0, tint_alpha, time_seconds)
		_draw_pillar_torch_ember_motes_for_side(tile, pillar_rect, "right", 1.0, tint_alpha, time_seconds)

func _pillar_torch_ember_motes_active() -> bool:
	if not visible or combat_state.is_empty():
		return false
	var has_torch_texture: bool = _prop_textures.get("column_torch_left", null) != null or _prop_textures.get("column_torch_right", null) != null
	if not has_torch_texture and _pillar_torch_idle_frames_for_side("left").is_empty() and _pillar_torch_idle_frames_for_side("right").is_empty():
		return false
	return _grid_has_tile("pillar")

func _draw_pillar_torch_ember_motes_for_side(tile: Vector2i, pillar_rect: Rect2, side_key: String, side_sign: float, tint_alpha: float, time_seconds: float) -> void:
	if tint_alpha <= 0.0:
		return
	var torch_texture: Texture2D = _pillar_torch_texture(side_key)
	if torch_texture == null:
		return
	var torch_rect: Rect2 = _pillar_torch_rect(pillar_rect, torch_texture, side_sign)
	var source_point: Vector2 = _pillar_torch_flame_point(torch_rect, side_sign)
	for index: int in range(COLUMN_TORCH_EMBER_MOTE_COUNT):
		var seed: int = _pillar_torch_ember_seed(tile, side_key, index)
		var speed: float = lerpf(0.34, 0.56, _ambient_hash01(seed + 13))
		var cycle: float = wrapf(_ambient_hash01(seed + 17) + time_seconds * speed, 0.0, 1.0)
		var alpha: float = pow(clampf(sin(cycle * PI), 0.0, 1.0), 0.86) * COLUMN_TORCH_EMBER_MOTE_ALPHA * tint_alpha
		alpha *= lerpf(0.56, 1.0, _ambient_hash01(seed + 19))
		if alpha <= 0.045:
			continue
		var point: Vector2 = _pillar_torch_ember_mote_point(source_point, seed, cycle, time_seconds, side_sign)
		var previous_cycle: float = maxf(0.0, cycle - _ambient_motion_blur_cycle_delta("fire") * 0.62)
		var previous_point: Vector2 = _pillar_torch_ember_mote_point(source_point, seed, previous_cycle, time_seconds - 0.09, side_sign)
		var velocity: Vector2 = point - previous_point
		var draw_width: float = _tile_width() * lerpf(COLUMN_TORCH_EMBER_MIN_WIDTH_SCALE, COLUMN_TORCH_EMBER_MAX_WIDTH_SCALE, _ambient_hash01(seed + 37))
		var variant_index: int = posmod(index + int(_ambient_hash01(seed + 39) * float(AMBIENT_PARTICLE_ATLAS_COLUMNS)), AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = _ambient_particle_texture("fire", variant_index)
		var soft_texture: Texture2D = _ambient_fire_soft_texture(variant_index)
		var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", variant_index)
		if texture == null and soft_texture == null:
			draw_circle(point, maxf(0.7, draw_width * 0.28), Color(1.0, 0.70, 0.30, minf(alpha * 0.62, 0.48)))
			continue
		if texture == null:
			texture = soft_texture
		var texture_size: Vector2 = texture.get_size()
		var draw_size := Vector2(draw_width, draw_width)
		if texture_size.x > 0.0:
			draw_size.y = draw_width * texture_size.y / texture_size.x
		var rotation: float = lerpf(-0.22, 0.22, _ambient_hash01(seed + 43)) + sin(time_seconds * 0.86 + _ambient_hash01(seed + 47) * TAU) * 0.07
		var mote_alpha: float = alpha * lerpf(0.48, 0.74, _ambient_hash01(seed + 41))
		_draw_ambient_fire_particle(texture, soft_texture, glow_texture, point, velocity, draw_size, rotation, mote_alpha, seed, time_seconds)
		draw_circle(point, maxf(0.65, draw_width * 0.16), Color(1.0, 0.86, 0.42, minf(mote_alpha * 0.52, 0.46)))

func _pillar_torch_flame_point(torch_rect: Rect2, side_sign: float) -> Vector2:
	var flame_x_scale: float = 0.34 if side_sign < 0.0 else 0.66
	return torch_rect.position + Vector2(torch_rect.size.x * flame_x_scale, torch_rect.size.y * 0.23)

func _pillar_torch_ember_seed(tile: Vector2i, side_key: String, index: int) -> int:
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	var side_seed: int = 211 if side_key == "right" else 103
	return room_coord.x * 83431 + room_coord.y * 64217 + tile.x * 2459 + tile.y * 3613 + side_seed + index * 1297 + 509

func _pillar_torch_ember_mote_point(source_point: Vector2, seed: int, cycle: float, time_seconds: float, side_sign: float) -> Vector2:
	var tile_width: float = _tile_width()
	var base_lateral: float = lerpf(-0.18, 0.18, _ambient_hash01(seed + 23)) * tile_width * lerpf(1.0, 0.64, cycle)
	var sway: float = sin(time_seconds * lerpf(1.2, 2.6, _ambient_hash01(seed + 29)) + _ambient_hash01(seed + 31) * TAU) * tile_width * lerpf(0.006, 0.038, cycle)
	var side_drift: float = side_sign * tile_width * lerpf(0.006, 0.030, _ambient_hash01(seed + 33)) * pow(cycle, 1.10)
	var rise: float = pow(cycle, 0.76) * tile_width * COLUMN_TORCH_EMBER_PLUME_HEIGHT_SCALE * lerpf(0.82, 1.18, _ambient_hash01(seed + 35))
	return source_point + Vector2(base_lateral + sway + side_drift, _tile_height() * 0.018 - rise)

func _tile_renders_as_pillar(grid: Array, tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= grid.size():
		return false
	var row_var: Variant = grid[tile.y]
	if typeof(row_var) != TYPE_ARRAY:
		return false
	var row: Array = row_var
	if tile.x < 0 or tile.x >= row.size():
		return false
	var tile_id: String = _display_tile_id(str(row[tile.x]), tile)
	if tile_id == "wall" and not _is_outer_boundary_tile(grid, tile):
		tile_id = "pillar"
	return tile_id == "pillar"

func _foreground_blocker_tint(tile_id: String, tile: Vector2i, prop_rect: Rect2, obstruction_entries: Array) -> Color:
	if not _is_tall_obstructive_tile(tile_id):
		return Color.WHITE
	for entry_var: Variant in obstruction_entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var entry_tile: Vector2i = entry.get("tile", entry.get("pos", Vector2i(-1, -1)))
		if entry_tile.x < 0 or entry_tile.y < 0:
			continue
		if not _tile_draws_before(entry_tile, tile):
			continue
		var entry_rect: Rect2 = entry.get("rect", Rect2())
		if entry_rect == Rect2() and not entry.has("rect"):
			entry_rect = _unit_draw_rect(entry)
		if _foreground_overlap_coverage(prop_rect, entry_rect) >= FOREGROUND_OBSTRUCTION_COVERAGE_THRESHOLD:
			return FOREGROUND_OBSTRUCTION_TINT
	return Color.WHITE

func _foreground_overlap_coverage(foreground_rect: Rect2, covered_rect: Rect2) -> float:
	if foreground_rect.size.x <= 0.0 or foreground_rect.size.y <= 0.0:
		return 0.0
	if covered_rect.size.x <= 0.0 or covered_rect.size.y <= 0.0:
		return 0.0
	if not foreground_rect.intersects(covered_rect, true):
		return 0.0
	var left: float = maxf(foreground_rect.position.x, covered_rect.position.x)
	var top: float = maxf(foreground_rect.position.y, covered_rect.position.y)
	var right: float = minf(foreground_rect.position.x + foreground_rect.size.x, covered_rect.position.x + covered_rect.size.x)
	var bottom: float = minf(foreground_rect.position.y + foreground_rect.size.y, covered_rect.position.y + covered_rect.size.y)
	var intersection_size: Vector2 = Vector2(maxf(0.0, right - left), maxf(0.0, bottom - top))
	var covered_area: float = covered_rect.size.x * covered_rect.size.y
	if covered_area <= 0.0:
		return 0.0
	return (intersection_size.x * intersection_size.y) / covered_area

func _is_tall_obstructive_tile(tile_id: String) -> bool:
	return tile_id in ["pillar", "wall", "door", "scene_prop", "terrain"]

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

func _draw_door_icon(icon_texture: Texture2D, icon_id: String, door_texture: Texture2D, door_draw_rect: Rect2, tint: Color = Color.WHITE) -> void:
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
	draw_circle(center, radius, Color(0.07, 0.05, 0.04, 0.86 * tint.a))
	draw_arc(center, radius, 0.0, TAU, 28, Color(accent.r, accent.g, accent.b, 0.88 * tint.a), 2.0, true)
	var icon_rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(icon_texture, icon_rect, false, tint)

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

func _tile_in_grid(grid: Array, tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= grid.size():
		return false
	var row: Array = grid[tile.y]
	return tile.x >= 0 and tile.x < row.size()

func _tile_drawn_as_floor(grid: Array, tile: Vector2i) -> bool:
	if not _tile_in_grid(grid, tile):
		return false
	var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
	return tile_id != "wall" and tile_id != "pillar" and tile_id != "door"

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

func _is_equipment_loot(loot: Dictionary) -> bool:
	return str(loot.get("kind", "")) == "equipment"

func _draw_equipment_pickup(tile: Vector2i, loot_rect: Rect2, loot_texture: Texture2D, loot: Dictionary) -> void:
	var accent: Color = _equipment_loot_accent(loot)
	var glow_color: Color = _equipment_pickup_glow_color(accent)
	var pulse: float = _equipment_pickup_pulse(tile, loot)
	_draw_equipment_pickup_beacon(tile, accent, glow_color, pulse)
	_draw_rect_ground_shadow(tile, loot_rect, 0.54, 0.15, 0.10)
	_draw_equipment_pickup_outline(loot_texture, loot_rect, glow_color, pulse)
	draw_texture_rect(loot_texture, loot_rect, false)

func _draw_equipment_pickup_beacon(tile: Vector2i, accent: Color, glow_color: Color, pulse: float) -> void:
	var center: Vector2 = _tile_center(tile)
	var ground_center: Vector2 = center + Vector2(0.0, _tile_height() * 0.20)
	_draw_iso_ground_glow(
		ground_center,
		_tile_width() * (0.82 + pulse * 0.06),
		_tile_height() * (0.34 + pulse * 0.04),
		glow_color,
		0.22 + pulse * 0.09
	)
	_draw_iso_ground_glow(
		ground_center + Vector2(0.0, -_tile_height() * 0.03),
		_tile_width() * 0.48,
		_tile_height() * 0.18,
		accent.lightened(0.36),
		0.12 + pulse * 0.06
	)
	_draw_tile_ring(tile, Color(glow_color.r, glow_color.g, glow_color.b, 0.36 + pulse * 0.18), 2.3 + pulse * 0.9, 0.72 + pulse * 0.04)

func _draw_equipment_pickup_outline(texture: Texture2D, loot_rect: Rect2, glow_color: Color, pulse: float) -> void:
	var offset_px: float = maxf(2.4, _tile_width() * 0.022)
	var outline_rect: Rect2 = loot_rect.grow(maxf(1.6, _tile_width() * 0.008))
	var outline_tint := Color(glow_color.r, glow_color.g, glow_color.b, 0.34 + pulse * 0.12)
	draw_texture_rect(texture, Rect2(outline_rect.position + Vector2(-offset_px, 0.0), outline_rect.size), false, outline_tint)
	draw_texture_rect(texture, Rect2(outline_rect.position + Vector2(offset_px, 0.0), outline_rect.size), false, outline_tint)
	draw_texture_rect(texture, Rect2(outline_rect.position + Vector2(0.0, -offset_px), outline_rect.size), false, outline_tint)
	draw_texture_rect(texture, Rect2(outline_rect.position + Vector2(0.0, offset_px), outline_rect.size), false, outline_tint)
	draw_texture_rect(texture, Rect2(outline_rect.position + Vector2(-offset_px * 0.72, -offset_px * 0.72), outline_rect.size), false, Color(glow_color.r, glow_color.g, glow_color.b, outline_tint.a * 0.60))
	draw_texture_rect(texture, Rect2(outline_rect.position + Vector2(offset_px * 0.72, -offset_px * 0.72), outline_rect.size), false, Color(glow_color.r, glow_color.g, glow_color.b, outline_tint.a * 0.60))
	draw_texture_rect(texture, loot_rect.grow(maxf(1.0, _tile_width() * 0.006)), false, Color(1.0, 0.92, 0.62, 0.14 + pulse * 0.06))

func _draw_iso_ground_glow(center: Vector2, width: float, height: float, color: Color, alpha: float) -> void:
	if width <= 0.0 or height <= 0.0 or alpha <= 0.0:
		return
	for layer: int in range(3, 0, -1):
		var layer_ratio: float = float(layer) / 3.0
		var layer_width: float = width * (1.0 + layer_ratio * 0.28)
		var layer_height: float = height * (1.0 + layer_ratio * 0.22)
		var layer_alpha: float = alpha * (0.24 + (1.0 - layer_ratio) * 0.34)
		var points := PackedVector2Array()
		for step: int in range(SHADOW_POINT_COUNT):
			var angle: float = TAU * float(step) / float(SHADOW_POINT_COUNT)
			var unit_y: float = sin(angle)
			points.append(center + Vector2(cos(angle) * layer_width * 0.5 + unit_y * layer_width * 0.08, unit_y * layer_height * 0.5))
		draw_colored_polygon(points, Color(color.r, color.g, color.b, layer_alpha))

func _equipment_pickup_pulse(tile: Vector2i, loot: Dictionary) -> float:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	return 0.5 + 0.5 * sin(time_seconds * 2.65 + _equipment_loot_phase(tile, loot))

func _equipment_loot_phase(tile: Vector2i, loot: Dictionary) -> float:
	var equipment_id: String = str(loot.get("equipment_id", ""))
	var seed: int = abs(tile.x * 92821 + tile.y * 68917 + equipment_id.length() * 131)
	return (float(seed % 1000) / 1000.0) * TAU

func _equipment_loot_accent(loot: Dictionary) -> Color:
	return Color(GameData.equipment_accent(str(loot.get("equipment_id", ""))))

func _equipment_pickup_glow_color(accent: Color) -> Color:
	return Color("f1d18b").lerp(accent.lightened(0.24), 0.34)

func _loot_draw_width(loot: Dictionary) -> float:
	if _is_equipment_loot(loot):
		return clampf(_tile_width() * EQUIPMENT_LOOT_TILE_WIDTH_SCALE, EQUIPMENT_LOOT_MIN_DRAW_WIDTH, EQUIPMENT_LOOT_MAX_DRAW_WIDTH)
	return LOOT_DRAW_WIDTH

func _loot_rect_for_tile(tile: Vector2i, texture: Texture2D = null, loot: Dictionary = {}) -> Rect2:
	var draw_width: float = _loot_draw_width(loot)
	var draw_height: float = draw_width
	if texture != null and texture.get_size().x > 0.0:
		draw_height = draw_width * texture.get_size().y / texture.get_size().x
	var center: Vector2 = _tile_center(tile)
	var baseline_scale: float = EQUIPMENT_LOOT_FLOAT_BASELINE_SCALE if _is_equipment_loot(loot) else 0.30
	var bottom_y: float = center.y + _tile_height() * baseline_scale
	return Rect2(Vector2(center.x - draw_width * 0.5, bottom_y - draw_height), Vector2(draw_width, draw_height))

func _loot_tooltip_text(loot: Dictionary) -> String:
	match str(loot.get("kind", "")):
		"healing_vial":
			return "Healing potion: Heal %d" % int(loot.get("amount", 0))
		"rusty_shield":
			return "Rusty shield: Gain %d block" % int(loot.get("amount", 0))
		"dropped_embers":
			return "Dropped embers: Reclaim %d" % int(loot.get("amount", 0))
		"equipment":
			var equipment_id: String = str(loot.get("equipment_id", ""))
			var item: Dictionary = GameData.equipment_def(equipment_id)
			var item_name: String = str(item.get("name", equipment_id))
			var slot: String = str(item.get("slot", ""))
			return "%s: %s" % [item_name, slot.capitalize()]
	return ""

func _loot_texture(loot: Dictionary) -> Texture2D:
	if str(loot.get("kind", "")) == "equipment":
		var item: Dictionary = GameData.equipment_def(str(loot.get("equipment_id", "")))
		return AssetLoader.load_texture(str(item.get("icon_path", "")))
	return _loot_textures.get(str(loot.get("kind", "")), null)

func _draw_terrain_object(terrain: Dictionary, obstruction_entries: Array = []) -> void:
	var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
	if tile.x < 0:
		return
	var terrain_kind: String = str(terrain.get("kind", ""))
	var texture: Texture2D = _terrain_textures.get(terrain_kind, null)
	if texture == null:
		return
	var terrain_rect: Rect2 = _terrain_rect_for_tile(tile, texture, terrain_kind)
	var tint: Color = _foreground_blocker_tint("terrain", tile, terrain_rect, obstruction_entries)
	_draw_rect_ground_shadow(tile, terrain_rect, 0.70, 0.24, 0.16)
	draw_texture_rect(texture, terrain_rect, false, tint)
	_draw_terrain_health_bar(terrain, terrain_rect)
	_register_tooltip(terrain_rect.grow(4.0), _terrain_tooltip_text(terrain))

func _terrain_rect_for_tile(tile: Vector2i, texture: Texture2D, terrain_kind: String = "") -> Rect2:
	var draw_width: float = _tile_width() * _terrain_draw_width_scale(terrain_kind)
	var draw_height: float = draw_width
	if texture != null and texture.get_size().x > 0.0:
		draw_height = draw_width * texture.get_size().y / texture.get_size().x
	var center: Vector2 = _tile_center(tile)
	var bottom_y: float = center.y + _tile_height() * TERRAIN_DRAW_BASELINE_SCALE
	return Rect2(Vector2(center.x - draw_width * 0.5, bottom_y - draw_height), Vector2(draw_width, draw_height))

func _terrain_draw_width_scale(terrain_kind: String) -> float:
	if terrain_kind == "wooden_crate":
		return TERRAIN_CRATE_DRAW_WIDTH_SCALE
	return TERRAIN_BOX_DRAW_WIDTH_SCALE

func _draw_terrain_health_bar(terrain: Dictionary, terrain_rect: Rect2) -> void:
	if not _should_show_terrain_health_bar(terrain):
		return
	var bar_size: Vector2 = TERRAIN_HEALTH_BAR_SIZE
	var bar_rect := Rect2(
		Vector2(terrain_rect.get_center().x - bar_size.x * 0.5, terrain_rect.position.y - 10.0),
		bar_size
	)
	var preview: Dictionary = _terrain_damage_preview(terrain)
	SegmentedHealthBar.draw_bar(
		self,
		bar_rect,
		float(terrain.get("hp", 0)),
		float(maxi(1, int(terrain.get("max_hp", 1)))),
		_health_bar_segment_count(int(terrain.get("max_hp", 1))),
		Color("2d1f18"),
		TERRAIN_BAR_FILL,
		Color("fff0bf"),
		Color("eed3a6"),
		Color(0.0, 0.0, 0.0, 0.35),
		1.0,
		1.0
	)
	if not preview.is_empty():
		_draw_health_damage_preview(terrain, bar_rect, preview)

func _should_show_terrain_health_bar(terrain: Dictionary) -> bool:
	if int(terrain.get("hp", 0)) <= 0:
		return false
	if int(terrain.get("hp", 0)) < maxi(1, int(terrain.get("max_hp", 1))):
		return true
	if not _terrain_damage_preview(terrain).is_empty():
		return true
	return attack_tiles.has(terrain.get("pos", Vector2i(-1, -1)))

func _terrain_damage_preview(terrain: Dictionary) -> Dictionary:
	var terrain_key: String = _terrain_key(terrain)
	if terrain_key.is_empty():
		return {}
	return _damage_preview_map().get(terrain_key, {}) as Dictionary

func _terrain_key(terrain: Dictionary) -> String:
	var terrain_id: String = str(terrain.get("id", ""))
	if terrain_id.is_empty():
		return ""
	return "terrain_%s" % terrain_id

func _terrain_tooltip_text(terrain: Dictionary) -> String:
	var label: String = "Wooden box" if str(terrain.get("kind", "")) == "wooden_box" else "Wooden crate"
	return "%s\n%d/%d HP" % [
		label,
		int(terrain.get("hp", 0)),
		int(terrain.get("max_hp", 1))
	]

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
			"immobilize": bool(player_statuses.get("immobilize", false)),
			"poison": player.get("poison", {}).duplicate(true)
		})
	for illusion_var: Variant in combat_state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var
		if int(illusion.get("hp", 0)) <= 0:
			continue
		units_to_draw.append({
			"key": "illusion_%d" % int(illusion.get("id", -1)),
			"role": "illusion",
			"type": "player",
			"name": "Illusion",
			"pos": illusion.get("pos", Vector2i.ZERO),
			"hp": int(illusion.get("hp", 0)),
			"max_hp": int(illusion.get("max_hp", illusion.get("hp", 1))),
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"freeze": 0,
			"shock": 0,
			"immobilize": false,
			"poison": {}
		})
	for preview_var: Variant in presentation.get("preview_units", []):
		if typeof(preview_var) != TYPE_DICTIONARY:
			continue
		var preview_unit: Dictionary = preview_var
		if str(preview_unit.get("role", "")) != "illusion_preview":
			continue
		var preview_tile: Vector2i = preview_unit.get("pos", Vector2i(-1, -1))
		if preview_tile.x < 0:
			continue
		var preview_hp: int = maxi(1, int(preview_unit.get("hp", preview_unit.get("max_hp", 1))))
		units_to_draw.append({
			"key": str(preview_unit.get("key", "illusion_preview")),
			"role": "illusion_preview",
			"type": "player",
			"name": str(preview_unit.get("name", "Illusion preview")),
			"pos": preview_tile,
			"hp": preview_hp,
			"max_hp": maxi(1, int(preview_unit.get("max_hp", preview_hp))),
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"freeze": 0,
			"shock": 0,
			"immobilize": false,
			"poison": {},
			"preview": true
		})
	for enemy: Dictionary in combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0:
			continue
		units_to_draw.append({
			"key": "enemy_%d" % int(enemy.get("id", -1)),
			"role": "enemy",
			"id": int(enemy.get("id", -1)),
			"type": str(enemy.get("type", "")),
			"name": str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
			"boss_bar": bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)),
			"footprint": enemy.get("footprint", Vector2i.ONE),
			"intent": enemy.get("intent", {}),
			"pos": enemy.get("pos", Vector2i.ZERO),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", 1)),
			"block": int(enemy.get("block", 0)),
			"stoneskin": int(enemy.get("stoneskin", 0)),
			"burn": int(enemy.get("burn", 0)),
			"freeze": int(enemy.get("freeze", 0)),
			"shock": int(enemy.get("shock", 0)),
			"immobilize": bool(enemy.get("immobilize", false)),
			"poison": enemy.get("poison", {}).duplicate(true)
		})
	units_to_draw.append_array(_death_animation_units_from_presentation())
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

func _death_animation_units_from_presentation() -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	for unit_var: Variant in presentation.get("death_animation_units", []):
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = (unit_var as Dictionary).duplicate(true)
		var unit_type: String = str(unit.get("type", ""))
		var unit_key: String = str(unit.get("key", ""))
		if unit_type.is_empty() or unit_key.is_empty():
			continue
		var definition: Dictionary = GameData.enemy_def(unit_type)
		if definition.is_empty():
			continue
		unit["key"] = unit_key
		unit["role"] = "enemy"
		unit["death_animation"] = true
		unit["boss_bar"] = false
		unit["name"] = str(unit.get("name", definition.get("name", "Enemy")))
		unit["id"] = int(unit.get("id", -1))
		var pos_value: Variant = unit.get("pos", Vector2i.ZERO)
		unit["pos"] = pos_value if typeof(pos_value) == TYPE_VECTOR2I else Vector2i.ZERO
		unit["hp"] = maxi(1, int(unit.get("hp", 1)))
		unit["max_hp"] = maxi(1, int(unit.get("max_hp", unit.get("hp", 1))))
		unit["block"] = 0
		unit["stoneskin"] = 0
		unit["burn"] = 0
		unit["freeze"] = 0
		unit["shock"] = 0
		unit["immobilize"] = false
		unit["poison"] = {}
		if not unit.has("footprint"):
			var footprint_value: Variant = definition.get("footprint", [])
			if typeof(footprint_value) == TYPE_ARRAY and (footprint_value as Array).size() >= 2:
				unit["footprint"] = Vector2i(int((footprint_value as Array)[0]), int((footprint_value as Array)[1]))
			else:
				unit["footprint"] = Vector2i.ONE
		units.append(unit)
	return units

func _draw_unit_bodies_for_tile(tile: Vector2i, units_to_draw: Array[Dictionary]) -> void:
	for unit: Dictionary in units_to_draw:
		if _effective_unit_tile(unit) != tile:
			continue
		_draw_unit_body(unit)

func _draw_unit_body(unit: Dictionary) -> void:
	_draw_unit_shadow(unit)
	var texture: Texture2D = _texture_for_unit(unit)
	if texture != null:
		var death_animation: bool = bool(unit.get("death_animation", false))
		var draw_rect: Rect2 = _unit_draw_rect(unit)
		var impact: float = _unit_impact_strength(unit)
		var impact_offset := Vector2.ZERO
		if impact > 0.0:
			impact_offset = Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0 * impact, 0.0)
		var shifted_rect := Rect2(draw_rect.position + impact_offset, draw_rect.size)
		if death_animation:
			shifted_rect = _death_animation_draw_rect(shifted_rect, float(unit.get("death_progress", 0.0)))
		var body_tint: Color = Color.WHITE
		var role: String = str(unit.get("role", ""))
		if role == "illusion_preview":
			var pulse: float = 0.5 + sin(Time.get_ticks_msec() * 0.008) * 0.5
			var preview_echo_rect := Rect2(shifted_rect.position + Vector2(0.0, -7.0), shifted_rect.size)
			draw_texture_rect(texture, preview_echo_rect, false, Color(0.38, 0.90, 1.0, 0.08 + 0.04 * pulse))
			body_tint = Color(0.76, 0.98, 1.0, 0.30 + 0.06 * pulse)
		elif role == "illusion":
			var echo_rect := Rect2(shifted_rect.position + Vector2(0.0, -5.0), shifted_rect.size)
			draw_texture_rect(texture, echo_rect, false, Color(0.38, 0.90, 1.0, 0.18))
			body_tint = Color(0.70, 0.95, 1.0, 0.58)
		elif death_animation:
			body_tint = _death_animation_tint(unit)
		draw_texture_rect(texture, shifted_rect, false, body_tint)
		if impact > 0.0:
			var flash: Color = IMPACT_FLASH_COLOR
			flash.a *= impact
			draw_texture_rect(texture, shifted_rect, false, flash)
		if _unit_is_preview_lethal(unit):
			_draw_lethal_preview_icon(shifted_rect)

func _draw_unit_huds(units_to_draw: Array[Dictionary]) -> void:
	var font: Font = get_theme_default_font()
	var reserved_rects: Array[Rect2] = _fixed_hud_collision_rects(units_to_draw, font)
	for unit: Dictionary in units_to_draw:
		if bool(unit.get("death_animation", false)):
			continue
		var center: Vector2 = _unit_center(unit)
		if str(unit.get("role", "")) == "npc":
			_draw_npc_nameplate(unit, center)
			continue
		if str(unit.get("role", "")) == "illusion_preview":
			continue
		if bool(unit.get("boss_bar", false)):
			var boss_layout: Dictionary = _boss_intent_layout(unit, center, reserved_rects, font)
			_draw_enemy_intent_layout(boss_layout, font)
			for rect_var: Variant in boss_layout.get("occupied_rects", []):
				if typeof(rect_var) == TYPE_RECT2:
					reserved_rects.append(rect_var)
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
	_draw_boss_health_bar(units_to_draw)

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
	var preview: Dictionary = _unit_damage_preview(unit)
	var display_hp: int = int(preview.get("hp", unit.get("hp", 0)))
	var role: String = str(unit.get("role", ""))
	var fill_color: Color = ILLUSION_BAR_FILL if role == "illusion" else PLAYER_BAR_FILL if role == "player" else ENEMY_BAR_FILL
	SegmentedHealthBar.draw_bar(
		self,
		rect,
		float(unit.get("hp", 0)),
		float(maxi(1, int(unit.get("max_hp", 1)))),
		_health_bar_segment_count(int(unit.get("max_hp", 1))),
		Color("2d1f18"),
		fill_color,
		Color("f5efdf"),
		Color("eed3a6"),
		Color(0.0, 0.0, 0.0, 0.35),
		1.0,
		1.0
	)
	if not preview.is_empty():
		_draw_health_damage_preview(unit, rect, preview)
	if font != null:
		var text_baseline: Vector2 = rect.position + Vector2(0.0, rect.size.y - 1.0)
		var hp_text: String = "%d/%d" % [display_hp, int(unit.get("max_hp", 1))]
		var text_color: Color = Color("fff4dc") if preview.is_empty() else Color("ffe1ae")
		for offset: Vector2 in [
			Vector2(-1.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, -1.0),
			Vector2(0.0, 1.0)
		]:
			draw_string(
				font,
				text_baseline + offset,
				hp_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				9,
				Color("140f0b")
			)
		draw_string(
			font,
			text_baseline,
			hp_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			9,
			text_color
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

func _draw_boss_health_bar(units_to_draw: Array[Dictionary]) -> void:
	var boss_unit: Dictionary = {}
	for unit: Dictionary in units_to_draw:
		if bool(unit.get("boss_bar", false)) and int(unit.get("hp", 0)) > 0:
			boss_unit = unit
			break
	if boss_unit.is_empty():
		return
	var font: Font = get_theme_default_font()
	var bar_rect: Rect2 = _boss_health_bar_rect()
	var name: String = str(boss_unit.get("name", "Boss"))
	if font != null:
		var name_rect := Rect2(Vector2(bar_rect.position.x, bar_rect.position.y - 30.0), Vector2(bar_rect.size.x, 24.0))
		var name_baseline: Vector2 = name_rect.position + Vector2(0.0, 21.0)
		for outline_offset: Vector2 in [Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
			draw_string(font, name_baseline + outline_offset, name, HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x, 21, Color("050403"))
		draw_string(font, name_baseline, name, HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x, 21, Color("ffe66d"))
	SegmentedHealthBar.draw_bar(
		self,
		bar_rect,
		float(boss_unit.get("hp", 0)),
		float(maxi(1, int(boss_unit.get("max_hp", 1)))),
		_health_bar_segment_count(int(boss_unit.get("max_hp", 1))),
		Color("1a1110"),
		Color("b83d3a"),
		Color("f5efdf"),
		Color("f5d96c"),
		Color(0.0, 0.0, 0.0, 0.45),
		1.0,
		2.0
	)
	draw_rect(bar_rect.grow(3.0), Color("0d0908"), false, 2.0)
	_draw_health_damage_preview(boss_unit, bar_rect, _unit_damage_preview(boss_unit))
	if font != null:
		var hp_text: String = "%d/%d" % [int(boss_unit.get("hp", 0)), int(boss_unit.get("max_hp", 1))]
		draw_string(font, bar_rect.position + Vector2(0.0, bar_rect.size.y - 7.0), hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, 14, Color("fff4dc"))

func _health_bar_segment_count(max_hp_value: int) -> int:
	return SegmentedHealthBar.segment_count_for_max_hp(float(maxi(1, max_hp_value)))

func _boss_health_bar_rect() -> Rect2:
	var bar_width: float = minf(BOSS_HEALTH_BAR_SIZE.x, maxf(300.0, size.x - 96.0))
	return Rect2(Vector2((size.x - bar_width) * 0.5, BOSS_HEALTH_BAR_Y), Vector2(bar_width, BOSS_HEALTH_BAR_SIZE.y))

func _draw_health_damage_preview(unit: Dictionary, rect: Rect2, preview: Dictionary) -> void:
	var current_hp: float = float(unit.get("hp", 0))
	var next_hp: float = float(preview.get("hp", current_hp))
	var max_hp: float = maxf(1.0, float(unit.get("max_hp", 1)))
	var current_ratio: float = clampf(current_hp / max_hp, 0.0, 1.0)
	var next_ratio: float = clampf(next_hp / max_hp, 0.0, 1.0)
	if current_ratio > next_ratio:
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.010)
		var damage_rect := Rect2(
			Vector2(rect.position.x + rect.size.x * next_ratio, rect.position.y),
			Vector2(rect.size.x * (current_ratio - next_ratio), rect.size.y)
		)
		var damage_color: Color = Color(1.0, 0.72, 0.34, 0.52 + pulse * 0.22)
		if bool(preview.get("lethal", false)):
			damage_color = Color(0.72, 0.18, 0.14, 0.62 + pulse * 0.26)
		draw_rect(damage_rect, damage_color, true)
		draw_rect(damage_rect, Color(1.0, 0.93, 0.62, 0.45), false, 1.0)
func _unit_damage_preview(unit: Dictionary) -> Dictionary:
	var actor_key: String = str(unit.get("key", ""))
	if actor_key.is_empty():
		return {}
	return _damage_preview_map().get(actor_key, {}) as Dictionary

func _damage_preview_map() -> Dictionary:
	var effect: Dictionary = presentation.get("effect", {})
	var preview_map: Dictionary = (presentation.get("damage_preview", {}) as Dictionary).duplicate(true)
	var effect_preview_map: Dictionary = effect.get("damage_preview", {}) as Dictionary
	for key: Variant in effect_preview_map.keys():
		preview_map[key] = effect_preview_map[key]
	return preview_map

func _unit_is_preview_lethal(unit: Dictionary) -> bool:
	return bool(_unit_damage_preview(unit).get("lethal", false))

func _draw_lethal_preview_icon(unit_rect: Rect2) -> void:
	var texture: Texture2D = _effect_textures.get("lethal_skull", null)
	if texture == null or unit_rect.size.x <= 0.0 or unit_rect.size.y <= 0.0:
		return
	var icon_size: float = clampf(minf(unit_rect.size.x, unit_rect.size.y) * 0.42, 30.0, 58.0)
	var icon_center := Vector2(
		unit_rect.get_center().x,
		unit_rect.position.y + unit_rect.size.y * 0.42
	)
	var icon_rect := Rect2(icon_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(texture, icon_rect, false, Color(1.0, 1.0, 1.0, 0.94))

func _unit_impact_strength(unit: Dictionary) -> float:
	var actor_key: String = str(unit.get("key", ""))
	if actor_key.is_empty():
		return 0.0
	var impact_keys: Array = presentation.get("impact_actor_keys", [])
	if not impact_keys.has(actor_key):
		return 0.0
	var progress: float = clampf(float(presentation.get("impact_progress", 0.0)), 0.0, 1.0)
	var strength: float = maxf(0.0, float(presentation.get("impact_strength", 1.0)))
	return clampf(1.0 - progress, 0.0, 1.0) * strength

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
	var role: String = str(unit.get("role", ""))
	var bar_size: Vector2 = PLAYER_HEALTH_BAR_SIZE if role == "player" or role == "illusion" else ENEMY_HEALTH_BAR_SIZE
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
		if str(token.get("kind", "")) == "text":
			var text_value: String = ActionIcons.token_value_text(token)
			if text_value.is_empty() or font == null:
				continue
			var text_width: float = maxf(font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x, 8.0)
			var text_rect := Rect2(Vector2(cursor_x, origin.y), Vector2(text_width, icon_size))
			draw_string(
				font,
				Vector2(cursor_x, origin.y + icon_size - 2.0),
				text_value,
				HORIZONTAL_ALIGNMENT_LEFT,
				text_width,
				font_size,
				_token_value_color(token, text_color)
			)
			_register_tooltip(text_rect, ActionIcons.token_tooltip(token))
			cursor_x += text_width + 6.0
			continue
		var icon_key: String = str(token.get("icon", ""))
		var tooltip: String = ActionIcons.token_tooltip(token)
		var icon_rect := Rect2(Vector2(cursor_x, origin.y), Vector2(icon_size, icon_size))
		_draw_keyword_icon(icon_key, icon_rect, tooltip)
		if ActionIcons.token_is_modified(token) and font != null:
			_draw_token_modifier_marker(icon_rect, tooltip, font)
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

func _draw_token_modifier_marker(icon_rect: Rect2, tooltip: String, font: Font) -> void:
	var marker_rect := Rect2(icon_rect.position + Vector2(icon_rect.size.x - 7.0, -3.0), Vector2(10.0, 10.0))
	draw_string(font, marker_rect.position + Vector2(0.0, 8.0), "+", HORIZONTAL_ALIGNMENT_CENTER, marker_rect.size.x, 10, Color("78c46a"))
	_register_tooltip(marker_rect.grow(2.0), tooltip)

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
		if str((token_var as Dictionary).get("kind", "")) == "text":
			var text_value: String = ActionIcons.token_value_text(token_var as Dictionary)
			if not text_value.is_empty() and font != null:
				width += maxf(font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x, 8.0) + 6.0
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
				if bool(unit.get("boss_bar", false)):
					rects.append(_boss_health_bar_rect().grow(6.0))
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
		rows = _enemy_intent_rows_for_display(unit, intent)
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

func _boss_intent_layout(unit: Dictionary, center: Vector2, occupied_rects: Array, font: Font = null) -> Dictionary:
	var intent: Dictionary = unit.get("intent", {})
	var rows: Array = []
	var intent_name: String = ""
	var intent_rect := Rect2()
	var expanded_rect := Rect2()
	var border: Color = Color("d8b96f")
	if not intent.is_empty():
		rows = _enemy_intent_rows_for_display(unit, intent)
		intent_name = _intent_display_name(intent)
		var expanded_rows: Array = _intent_rows_for_unit(unit, intent)
		var expanded_line_count: int = expanded_rows.size() + (1 if not intent_name.is_empty() else 0)
		var visible_line_count: int = rows.size() + (1 if not intent_name.is_empty() else 0)
		if font != null and expanded_line_count > 0 and visible_line_count > 0:
			var popup_width: float = _enemy_intent_popup_width(intent, expanded_rows, font)
			var anchor_rect := Rect2(
				Vector2(center.x - 1.0, _unit_art_top_y(unit, center) - UNIT_ART_HUD_CLEARANCE),
				Vector2(2.0, 1.0)
			)
			expanded_rect = _enemy_intent_rect_for_line_count(center, anchor_rect, expanded_line_count, popup_width)
			intent_rect = _enemy_intent_rect_for_line_count(center, anchor_rect, visible_line_count, popup_width)
			intent_rect.position = expanded_rect.end - intent_rect.size
			border = _intent_color(intent)
	var rects: Array[Rect2] = []
	if expanded_rect.size.x > 0.0 and expanded_rect.size.y > 0.0:
		rects.append(expanded_rect)
	var offset: Vector2 = _best_enemy_hud_offset(rects, occupied_rects)
	intent_rect.position += offset
	expanded_rect.position += offset
	var occupied: Array[Rect2] = []
	if expanded_rect.size.x > 0.0 and expanded_rect.size.y > 0.0:
		occupied.append(expanded_rect)
	return {
		"health_rect": Rect2(),
		"intent_rect": intent_rect,
		"rows": rows,
		"intent_name": intent_name,
		"border": border,
		"offset": offset,
		"occupied_rects": occupied
	}

func _enemy_intent_rows_for_display(unit: Dictionary, intent: Dictionary) -> Array:
	if _enemy_intent_expanded(unit):
		return _intent_rows_for_unit(unit, intent)
	return []

func _enemy_intent_expanded(unit: Dictionary) -> bool:
	if _all_enemy_intents_expanded():
		return true
	var expanded_keys: Array = presentation.get("expanded_enemy_actor_keys", [])
	var actor_key: String = str(unit.get("key", ""))
	if actor_key.is_empty() and str(unit.get("role", "enemy")) == "enemy":
		actor_key = "enemy_%d" % int(unit.get("id", -1))
	if not actor_key.is_empty() and expanded_keys.has(actor_key):
		return true
	return _unit_footprint_tiles(unit).has(_hover_tile)

func _all_enemy_intents_expanded() -> bool:
	return bool(presentation.get("show_all_enemy_intents", presentation.get("expand_enemy_intents", false)))

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

func _unit_footprint_tiles(unit: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = unit.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

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

func _draw_impact_decals() -> void:
	var decals: Array = presentation.get("impact_decals", [])
	if decals.is_empty():
		return
	var progress: float = clampf(float(presentation.get("impact_progress", 0.0)), 0.0, 1.0)
	for decal_var: Variant in decals:
		if typeof(decal_var) != TYPE_DICTIONARY:
			continue
		var decal: Dictionary = decal_var
		var tile: Vector2i = decal.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var element_id: String = str(decal.get("element", ElementData.NONE))
		var kind: String = str(decal.get("kind", ""))
		var seed: int = int(decal.get("seed", _impact_decal_seed(tile, element_id, kind)))
		_draw_impact_decal(tile, element_id, kind, seed, progress)

func _draw_impact_decal(tile: Vector2i, element_id: String, kind: String, seed: int, progress: float) -> void:
	var fade: float = clampf(1.0 - progress / IMPACT_DECAL_FADE_PROGRESS, 0.0, 1.0)
	if fade <= 0.0:
		return
	var pop: float = clampf(progress / 0.16, 0.0, 1.0)
	var alpha: float = fade * lerpf(0.78, 1.0, pop) * IMPACT_DECAL_MAX_ALPHA
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * 0.07)
	var scale: float = 1.12 if kind in ["aoe", "lightning_strikes"] else 0.96
	match element_id:
		ElementData.FIRE:
			_draw_fire_impact_decal(center, seed, scale, alpha)
		ElementData.ICE:
			_draw_ice_impact_decal(center, seed, scale, alpha)
		ElementData.LIGHTNING:
			_draw_lightning_impact_decal(center, seed, scale, alpha)
		ElementData.AIR:
			_draw_air_impact_decal(center, seed, scale, alpha)
		ElementData.EARTH:
			_draw_earth_impact_decal(center, seed, scale, alpha)
		_:
			_draw_neutral_impact_decal(center, seed, scale, alpha)

func _draw_fire_impact_decal(center: Vector2, seed: int, scale: float, alpha: float) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.46 * scale, tile_height * 0.56 * scale, tile_width * 0.08, Color(0.07, 0.035, 0.020, 0.46 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.54 * scale, tile_height * 0.64 * scale, tile_width * 0.10, Color(0.98, 0.34, 0.13, 0.30 * alpha), 1.8)
	_draw_impact_radial_marks(center, seed, 6, Color(1.0, 0.48, 0.18, 0.66 * alpha), tile_width * 0.08 * scale, tile_width * 0.25 * scale, 0.48, 2.0)
	for idx: int in range(3):
		var ember_point: Vector2 = center + _impact_offset(seed + idx * 17, tile_width * 0.18 * scale, tile_height * 0.22 * scale)
		draw_circle(ember_point, tile_width * (0.014 + 0.006 * _ambient_hash01(seed + idx + 40)), Color(1.0, 0.62, 0.22, 0.72 * alpha))

func _draw_ice_impact_decal(center: Vector2, seed: int, scale: float, alpha: float) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.50 * scale, tile_height * 0.58 * scale, -tile_width * 0.04, Color(0.52, 0.86, 1.0, 0.18 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.56 * scale, tile_height * 0.64 * scale, -tile_width * 0.05, Color(0.78, 0.96, 1.0, 0.42 * alpha), 1.6)
	_draw_impact_crack_marks(center, seed, 7, Color(0.82, 0.98, 1.0, 0.72 * alpha), tile_width * 0.07 * scale, tile_width * 0.27 * scale, 0.42, 1.7)
	for idx: int in range(4):
		var shard_center: Vector2 = center + _impact_offset(seed + idx * 23, tile_width * 0.21 * scale, tile_height * 0.22 * scale)
		draw_line(shard_center + Vector2(-2.0, 1.0), shard_center + Vector2(3.0, -5.0), Color(0.92, 1.0, 1.0, 0.72 * alpha), 1.3, true)

func _draw_lightning_impact_decal(center: Vector2, seed: int, scale: float, alpha: float) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.44 * scale, tile_height * 0.52 * scale, tile_width * 0.03, Color(0.08, 0.07, 0.16, 0.36 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.58 * scale, tile_height * 0.68 * scale, tile_width * 0.06, Color(0.96, 0.86, 0.26, 0.52 * alpha), 1.7)
	_draw_impact_crack_marks(center, seed, 5, Color(0.52, 0.82, 1.0, 0.66 * alpha), tile_width * 0.06 * scale, tile_width * 0.28 * scale, 0.44, 1.8)
	_draw_impact_radial_marks(center, seed + 53, 4, Color(1.0, 0.94, 0.42, 0.82 * alpha), tile_width * 0.05 * scale, tile_width * 0.22 * scale, 0.40, 2.1)

func _draw_air_impact_decal(center: Vector2, seed: int, scale: float, alpha: float) -> void:
	var tile_width: float = _tile_width()
	_draw_impact_ellipse(center, tile_width * 0.52 * scale, _tile_height() * 0.58 * scale, -tile_width * 0.05, Color(0.46, 0.88, 0.72, 0.12 * alpha))
	for idx: int in range(3):
		var radius: float = tile_width * (0.12 + float(idx) * 0.055) * scale
		var start_angle: float = _ambient_hash01(seed + idx * 31) * TAU
		draw_arc(center, radius, start_angle, start_angle + PI * 0.86, 18, Color(0.72, 1.0, 0.86, (0.48 - float(idx) * 0.09) * alpha), 1.6, true)
	_draw_impact_radial_marks(center, seed + 71, 5, Color(0.82, 0.70, 0.48, 0.32 * alpha), tile_width * 0.12 * scale, tile_width * 0.30 * scale, 0.40, 1.5)

func _draw_earth_impact_decal(center: Vector2, seed: int, scale: float, alpha: float) -> void:
	var tile_width: float = _tile_width()
	_draw_impact_ellipse(center, tile_width * 0.46 * scale, _tile_height() * 0.54 * scale, tile_width * 0.05, Color(0.10, 0.07, 0.035, 0.38 * alpha))
	_draw_impact_crack_marks(center, seed, 8, Color(0.74, 0.62, 0.36, 0.66 * alpha), tile_width * 0.05 * scale, tile_width * 0.30 * scale, 0.46, 2.0)
	for idx: int in range(5):
		var chip_point: Vector2 = center + _impact_offset(seed + idx * 19, tile_width * 0.24 * scale, _tile_height() * 0.26 * scale)
		draw_circle(chip_point, tile_width * 0.013, Color(0.58, 0.44, 0.24, 0.54 * alpha))

func _draw_neutral_impact_decal(center: Vector2, seed: int, scale: float, alpha: float) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.44 * scale, tile_height * 0.52 * scale, tile_width * 0.04, Color(0.09, 0.07, 0.05, 0.34 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.54 * scale, tile_height * 0.62 * scale, tile_width * 0.05, Color(0.72, 0.56, 0.35, 0.34 * alpha), 1.5)
	_draw_impact_radial_marks(center, seed, 7, Color(0.78, 0.62, 0.42, 0.46 * alpha), tile_width * 0.07 * scale, tile_width * 0.25 * scale, 0.44, 1.7)

func _draw_impact_ellipse(center: Vector2, width: float, height: float, skew: float, color: Color) -> void:
	draw_colored_polygon(_impact_ellipse_points(center, width, height, skew), color)

func _draw_impact_ellipse_outline(center: Vector2, width: float, height: float, skew: float, color: Color, line_width: float) -> void:
	draw_polyline(_impact_ellipse_points(center, width, height, skew), color, line_width, true)

func _impact_ellipse_points(center: Vector2, width: float, height: float, skew: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments: int = 28
	for idx: int in range(segments + 1):
		var angle: float = TAU * float(idx) / float(segments)
		var unit_y: float = sin(angle)
		points.append(center + Vector2(cos(angle) * width * 0.5 + unit_y * skew, unit_y * height * 0.5))
	return points

func _draw_impact_radial_marks(center: Vector2, seed: int, count: int, color: Color, inner_radius: float, outer_radius: float, y_scale: float, line_width: float) -> void:
	for idx: int in range(count):
		var angle: float = _ambient_hash01(seed + idx * 13) * TAU
		var direction := Vector2(cos(angle), sin(angle) * y_scale)
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		draw_line(center + direction * inner_radius, center + direction * outer_radius, color, line_width, true)

func _draw_impact_crack_marks(center: Vector2, seed: int, count: int, color: Color, inner_radius: float, outer_radius: float, y_scale: float, line_width: float) -> void:
	for idx: int in range(count):
		var angle: float = _ambient_hash01(seed + idx * 29) * TAU
		var direction := Vector2(cos(angle), sin(angle) * y_scale)
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var start: Vector2 = center + direction * inner_radius
		var finish: Vector2 = center + direction * outer_radius
		var perpendicular := Vector2(-direction.y, direction.x)
		var kink: Vector2 = start.lerp(finish, 0.54) + perpendicular * lerpf(-5.0, 5.0, _ambient_hash01(seed + idx * 29 + 7))
		draw_line(start, kink, color, line_width, true)
		draw_line(kink, finish, color, maxf(1.0, line_width - 0.35), true)

func _impact_offset(seed: int, radius_x: float, radius_y: float) -> Vector2:
	var angle: float = _ambient_hash01(seed) * TAU
	return Vector2(cos(angle) * radius_x, sin(angle) * radius_y)

func _impact_decal_seed(tile: Vector2i, element_id: String, kind: String) -> int:
	return tile.x * 92821 + tile.y * 68917 + _impact_element_seed(element_id) * 3571 + kind.length() * 197

func _impact_element_seed(element_id: String) -> int:
	match element_id:
		ElementData.FIRE:
			return 11
		ElementData.ICE:
			return 23
		ElementData.LIGHTNING:
			return 37
		ElementData.AIR:
			return 41
		ElementData.EARTH:
			return 53
		_:
			return 7

func _draw_effect_overlay() -> void:
	var effect: Dictionary = presentation.get("effect", {})
	var progress: float = clampf(float(presentation.get("effect_progress", 1.0)), 0.0, 1.0)
	var trap_effects: Array = presentation.get("trap_effects", [])
	if not trap_effects.is_empty():
		_draw_trap_blast_effects(trap_effects, progress)
	if effect.is_empty():
		return
	var kind: String = str(effect.get("kind", ""))
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
			_draw_blink_rift_effect(from_tile, to_tile, progress, bool(effect.get("preview", false)))
		"ranged":
			if from_tile.x < 0 or to_tile.x < 0:
				return
			_draw_ranged_projectile_effect(effect, progress, from_point, to_point)
			for force_tile: Vector2i in _vector2i_array(effect.get("force_tiles", [])):
				_draw_tile_ring(force_tile, Color(0.72, 0.95, 1.0, 0.64), 2.2, 0.74)
		"melee":
			if to_tile.x < 0:
				return
			_draw_melee_slash_effect(from_point, to_point, progress)
		"aoe":
			_draw_aoe_effect(effect, progress, from_point, center_point)
		"lightning_strikes":
			var strike_tiles: Array[Vector2i] = _vector2i_array(effect.get("tiles", []))
			var bolt_alpha: float = 0.24 + progress * 0.34
			for tile: Vector2i in strike_tiles:
				var tile_point: Vector2 = _tile_center(tile)
				var top_point: Vector2 = tile_point + Vector2(-10.0 + sin(float(tile.x + tile.y)) * 8.0, -_tile_height() * 1.45)
				draw_line(top_point, tile_point, Color(1.0, 0.94, 0.42, bolt_alpha), 3.0, true)
				draw_line(top_point + Vector2(7.0, 22.0), tile_point + Vector2(-5.0, -6.0), Color(0.58, 0.78, 1.0, bolt_alpha * 0.76), 2.0, true)
				draw_arc(tile_point, _tile_width() * (0.18 + progress * 0.08), 0.0, TAU, 18, Color(1.0, 0.86, 0.28, 0.48 + progress * 0.24), 3.0)
				draw_circle(tile_point, _tile_width() * 0.10, Color(1.0, 0.95, 0.50, 0.16 + progress * 0.18))
		"block":
			var block_tile: Vector2i = effect.get("tile", Vector2i(-1, -1))
			if block_tile.x < 0:
				return
			_draw_block_cast_effect(block_tile, progress)
		"heal":
			var heal_tile: Vector2i = effect.get("tile", Vector2i(-1, -1))
			if heal_tile.x < 0:
				return
			_draw_heal_cast_effect(heal_tile, progress)
		"stoneskin":
			var stoneskin_tile: Vector2i = effect.get("tile", Vector2i(-1, -1))
			if stoneskin_tile.x < 0:
				return
			_draw_stoneskin_cast_effect(stoneskin_tile, progress)

func _draw_block_cast_effect(tile: Vector2i, progress: float) -> void:
	_draw_cast_icon_effect("block", tile, progress, -0.30, 0.50)

func _draw_heal_cast_effect(tile: Vector2i, progress: float) -> void:
	var normalized_progress: float = clampf(progress, 0.0, 1.0)
	var tile_width: float = _tile_width()
	var base: Vector2 = _tile_center(tile) + Vector2(0.0, -tile_width * 0.08)
	var plus_offsets := [
		Vector2(-0.18, 0.02),
		Vector2(0.14, -0.02),
		Vector2(-0.03, 0.08),
		Vector2(0.24, 0.05),
		Vector2(-0.26, 0.09)
	]
	for index: int in range(plus_offsets.size()):
		var local_progress: float = clampf(normalized_progress * 1.30 - float(index) * 0.12, 0.0, 1.0)
		if local_progress <= 0.0 or local_progress >= 1.0:
			continue
		var texture: Texture2D = _defense_heal_cast_frame(DEFENSE_HEAL_CASTS_FRAMES_PER_KIND + (index % DEFENSE_HEAL_CASTS_FRAMES_PER_KIND))
		if texture == null:
			continue
		var fade: float = clampf(sin(local_progress * PI) * 1.08, 0.0, 1.0)
		var rise: float = tile_width * lerpf(0.03, 0.34, local_progress)
		var drift: Vector2 = plus_offsets[index]
		var point: Vector2 = base + Vector2(tile_width * drift.x, tile_width * drift.y - rise)
		var size: float = tile_width * (0.20 + 0.025 * sin(float(index) * 1.7))
		_draw_ambient_particle_sprite(texture, point, Vector2.ONE * size, 0.0, fade)

func _draw_stoneskin_cast_effect(tile: Vector2i, progress: float) -> void:
	_draw_cast_icon_effect("stoneskin", tile, progress, -0.26, 0.56)

func _draw_cast_icon_effect(effect_id: String, tile: Vector2i, progress: float, y_offset_scale: float, size_scale: float) -> void:
	var frame_index: int = _cast_effect_frame_index(effect_id, progress)
	var texture: Texture2D = _defense_heal_cast_frame(frame_index)
	if texture == null:
		return
	var normalized_progress: float = clampf(progress, 0.0, 1.0)
	var fade_in: float = clampf(normalized_progress / 0.18, 0.0, 1.0)
	var fade_out: float = clampf((1.0 - normalized_progress) / 0.24, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	var pop: float = 1.0 - pow(1.0 - fade_in, 2.0)
	var settle: float = 1.0 + 0.06 * sin(normalized_progress * PI)
	var tile_width: float = _tile_width()
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, tile_width * y_offset_scale)
	var draw_size: Vector2 = Vector2.ONE * tile_width * size_scale * lerpf(0.72, 1.0, pop) * settle
	_draw_ambient_particle_sprite(texture, center, draw_size, 0.0, alpha)

func _cast_effect_frame_index(effect_id: String, progress: float) -> int:
	var row: int = 0
	match effect_id:
		"heal":
			row = 1
		"stoneskin":
			row = 2
		_:
			row = 0
	var local_progress: float = clampf(progress, 0.0, 0.999)
	var column: int = clampi(int(floor(local_progress * float(DEFENSE_HEAL_CASTS_FRAMES_PER_KIND))), 0, DEFENSE_HEAL_CASTS_FRAMES_PER_KIND - 1)
	return row * DEFENSE_HEAL_CASTS_FRAMES_PER_KIND + column

func _defense_heal_cast_frame(frame_index: int) -> Texture2D:
	var frames: Array = _effect_frames.get("defense_heal_casts", [])
	if frame_index < 0 or frame_index >= frames.size():
		return null
	return frames[frame_index] as Texture2D

func _draw_ranged_projectile_effect(effect: Dictionary, progress: float, from_point: Vector2, to_point: Vector2) -> void:
	var element_id: String = _projectile_element_id(_effect_element(effect))
	var accent: Color = _projectile_accent(element_id)
	var secondary: Color = _projectile_secondary(element_id)
	var preview: bool = bool(effect.get("preview", false))
	var preview_phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
	var preview_pulse: float = 0.5 + 0.5 * sin(preview_phase * TAU)
	var start: Vector2 = from_point + Vector2(0.0, -24.0)
	var end: Vector2 = to_point + Vector2(0.0, -24.0)
	var control: Vector2 = _arc_control_point(start, end)
	var warmup_progress: float = 1.0 if preview else clampf(progress / 0.34, 0.0, 1.0)
	var arc_alpha: float = 0.11 + 0.08 * warmup_progress + (0.05 * preview_pulse if preview else 0.0)
	_draw_bezier_glow(start, control, end, Color(accent.r, accent.g, accent.b, arc_alpha), 1.5)
	var travel_progress: float = lerpf(0.05, 0.96, preview_phase) if preview else clampf((progress - 0.18) / 0.48, 0.0, 1.0)
	var loop_fade: float = 1.0
	if preview:
		loop_fade = clampf(minf(preview_phase / 0.16, (1.0 - preview_phase) / 0.16), 0.0, 1.0)
	if travel_progress > 0.0:
		_draw_elemental_projectile_trail(start, control, end, travel_progress, element_id, accent, secondary, 0.72 * loop_fade if preview else 1.0)
		var projectile_point: Vector2 = _quadratic_bezier(start, control, end, travel_progress)
		var behind_point: Vector2 = _quadratic_bezier(start, control, end, maxf(0.0, travel_progress - 0.04))
		var ahead_point: Vector2 = _quadratic_bezier(start, control, end, minf(1.0, travel_progress + 0.04))
		_draw_projectile_sprite(projectile_point, ahead_point - behind_point, element_id, travel_progress, 0.84 * loop_fade if preview else 1.0)

func _draw_elemental_projectile_trail(
	start: Vector2,
	control: Vector2,
	end: Vector2,
	travel_progress: float,
	element_id: String,
	accent: Color,
	secondary: Color,
	alpha_multiplier: float = 1.0
) -> void:
	var points: Array[Vector2] = _sample_quadratic_points(start, control, end, 16)
	if points.size() < 2:
		return
	var last_index: int = clampi(int(floor(float(points.size() - 1) * travel_progress)), 1, points.size() - 1)
	var first_index: int = maxi(0, last_index - _projectile_trail_segment_count(element_id))
	var segment_total: int = maxi(1, last_index - first_index)
	for index: int in range(first_index, last_index):
		var local_t: float = float(index - first_index + 1) / float(segment_total)
		var alpha: float = (0.16 + 0.62 * local_t) * clampf(travel_progress * 1.25, 0.0, 1.0) * alpha_multiplier
		var width: float = lerpf(1.4, _projectile_trail_width(element_id), local_t)
		draw_line(points[index], points[index + 1], Color(0.0, 0.0, 0.0, alpha * 0.18), width + 4.5, true)
		draw_line(points[index], points[index + 1], Color(secondary.r, secondary.g, secondary.b, alpha * 0.62), width + 1.8, true)
		draw_line(points[index], points[index + 1], Color(accent.r, accent.g, accent.b, alpha), width, true)

func _draw_projectile_sprite(center: Vector2, direction: Vector2, element_id: String, travel_progress: float, alpha_multiplier: float = 1.0) -> void:
	var dir: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var texture: Texture2D = _projectile_texture(element_id)
	var draw_size: float = clampf(_tile_width() * PROJECTILE_DRAW_TILE_SCALE, PROJECTILE_DRAW_MIN_SIZE, PROJECTILE_DRAW_MAX_SIZE)
	var alpha: float = clampf((0.68 + sin(travel_progress * PI) * 0.30) * alpha_multiplier, 0.0, 1.0)
	if texture == null:
		var fallback_color: Color = _projectile_secondary(element_id)
		fallback_color.a = alpha
		_draw_projectile_diamond(center, dir, fallback_color, draw_size * 0.18)
		return
	var shadow_rect: Rect2 = _projectile_sprite_rect(draw_size, element_id, 1.28)
	var glow_rect: Rect2 = _projectile_sprite_rect(draw_size, element_id, 1.14)
	var sprite_rect: Rect2 = _projectile_sprite_rect(draw_size, element_id, 1.0)
	draw_set_transform(center + Vector2(2.5, 4.0), dir.angle(), Vector2.ONE)
	draw_texture_rect(texture, shadow_rect, false, Color(0.0, 0.0, 0.0, 0.28 * alpha))
	draw_set_transform(center, dir.angle(), Vector2.ONE)
	var glow_color: Color = _projectile_secondary(element_id)
	draw_texture_rect(texture, glow_rect, false, Color(glow_color.r, glow_color.g, glow_color.b, 0.26 * alpha))
	draw_texture_rect(texture, sprite_rect, false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _projectile_sprite_rect(draw_size: float, element_id: String, scale: float = 1.0) -> Rect2:
	var sprite_size := Vector2(draw_size, draw_size) * scale
	var anchor: Vector2 = _projectile_sprite_anchor(element_id)
	return Rect2(
		Vector2(-sprite_size.x * anchor.x, -sprite_size.y * anchor.y),
		sprite_size
	)

func _projectile_sprite_anchor(element_id: String) -> Vector2:
	match _projectile_element_id(element_id):
		ElementData.LIGHTNING:
			return Vector2(PROJECTILE_SPRITE_PATH_ANCHOR_X, 0.38)
		ElementData.AIR:
			return Vector2(PROJECTILE_SPRITE_PATH_ANCHOR_X, 0.34)
		ElementData.EARTH:
			return Vector2(PROJECTILE_SPRITE_PATH_ANCHOR_X, 0.46)
		_:
			return Vector2(PROJECTILE_SPRITE_PATH_ANCHOR_X, 0.50)

func _projectile_texture(element_id: String) -> Texture2D:
	if _projectile_atlas == null:
		return null
	var row: int = _projectile_atlas_row(element_id)
	var cache_key: String = str(row)
	if _projectile_textures.has(cache_key):
		return _projectile_textures.get(cache_key, null)
	var atlas_size: Vector2 = _projectile_atlas.get_size()
	var cell_size := Vector2(atlas_size.x, atlas_size.y / float(ELEMENTAL_PROJECTILE_ATLAS_ROWS))
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = _projectile_atlas
	atlas_texture.region = Rect2(Vector2(0.0, cell_size.y * float(row)), cell_size)
	_projectile_textures[cache_key] = atlas_texture
	return atlas_texture

func _projectile_atlas_row(element_id: String) -> int:
	match _projectile_element_id(element_id):
		ElementData.FIRE:
			return 1
		ElementData.ICE:
			return 2
		ElementData.LIGHTNING:
			return 3
		ElementData.AIR:
			return 4
		ElementData.EARTH:
			return 5
		_:
			return 0

func _projectile_element_id(element_id: String) -> String:
	return element_id if ElementData.is_elemental(element_id) else ElementData.NONE

func _projectile_accent(element_id: String) -> Color:
	match _projectile_element_id(element_id):
		ElementData.FIRE:
			return Color("d66a38")
		ElementData.ICE:
			return Color("79bddd")
		ElementData.LIGHTNING:
			return Color("d8bd48")
		ElementData.AIR:
			return Color("78b99f")
		ElementData.EARTH:
			return Color("8a9a5a")
		_:
			return Color("b99c72")

func _projectile_secondary(element_id: String) -> Color:
	match _projectile_element_id(element_id):
		ElementData.FIRE:
			return Color("f0a65b")
		ElementData.ICE:
			return Color("c8ebf4")
		ElementData.LIGHTNING:
			return Color("8da4d6")
		ElementData.AIR:
			return Color("c4e6d4")
		ElementData.EARTH:
			return Color("c0ad72")
		_:
			return Color("dcc59c")

func _projectile_trail_segment_count(element_id: String) -> int:
	match _projectile_element_id(element_id):
		ElementData.AIR:
			return 7
		ElementData.LIGHTNING:
			return 4
		ElementData.EARTH:
			return 3
		_:
			return 5

func _projectile_trail_width(element_id: String) -> float:
	match _projectile_element_id(element_id):
		ElementData.FIRE:
			return 4.1
		ElementData.ICE:
			return 3.2
		ElementData.LIGHTNING:
			return 2.6
		ElementData.AIR:
			return 2.8
		ElementData.EARTH:
			return 4.4
		_:
			return 3.0

func _draw_blink_rift_effect(from_tile: Vector2i, to_tile: Vector2i, progress: float, preview: bool = false) -> void:
	var from_point: Vector2 = _tile_center(from_tile)
	var to_point: Vector2 = _tile_center(to_tile)
	var path: Vector2 = to_point - from_point
	var path_length: float = path.length()
	var direction: Vector2 = path / path_length if path_length > 0.001 else Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var eased_progress: float = _blink_rift_ease(clamped_progress)
	var distance_tiles: float = maxf(1.0, path_length / maxf(1.0, tile_width * 0.56))
	var preview_scale: float = 0.78 if preview else 1.0
	var rift_alpha_scale: float = 0.96 if preview else 1.0
	var band_width: float = clampf(tile_width * (0.15 + distance_tiles * 0.012), 8.0, 19.0) * preview_scale
	var path_lift := Vector2(0.0, -tile_height * 0.28)
	var from_lifted: Vector2 = from_point + path_lift
	var to_lifted: Vector2 = to_point + path_lift
	var current_point: Vector2 = from_point.lerp(to_point, eased_progress)
	var wash_reveal: float = 1.0 if preview else clampf(eased_progress + 0.22, 0.0, 1.0)

	if preview:
		_draw_blink_preview_integrated_rift(from_lifted, to_lifted, direction, normal, band_width, rift_alpha_scale, clamped_progress * TAU)
		return

	_draw_blink_smoke_wash(from_lifted, to_lifted, direction, normal, wash_reveal, band_width, rift_alpha_scale, clamped_progress * TAU, false)
	draw_line(from_lifted, to_lifted, Color(0.018, 0.012, 0.034, 0.15 * rift_alpha_scale), band_width * 1.75, true)
	_draw_blink_smoke_band(from_lifted, to_lifted, normal, wash_reveal, band_width * 0.70, Color(0.08, 0.055, 0.13, 0.13 * rift_alpha_scale), clamped_progress * TAU)
	_draw_blink_smoke_band(from_lifted, to_lifted, normal, eased_progress, band_width, Color(0.18, 0.12, 0.27, 0.45 * rift_alpha_scale), clamped_progress * TAU * 1.35)
	_draw_blink_smoke_band(from_lifted, to_lifted, normal, clampf(eased_progress + 0.12, 0.0, 1.0), band_width * 0.42, Color(0.55, 0.49, 0.78, 0.30 * rift_alpha_scale), clamped_progress * TAU * 1.75)
	_draw_blink_rift_edge_strokes(from_lifted, to_lifted, direction, normal, wash_reveal, band_width, rift_alpha_scale, clamped_progress * TAU, false)
	_draw_blink_rift_motes(from_lifted, to_lifted, direction, normal, wash_reveal, band_width, rift_alpha_scale, clamped_progress * TAU, false)

	var source_alpha: float = lerpf(0.68, 0.20, eased_progress) * preview_scale
	var destination_alpha: float = lerpf(0.18, 0.74, eased_progress) * preview_scale
	_draw_tile_ring(from_tile, Color(0.20, 0.13, 0.28, source_alpha), 2.4 * preview_scale, lerpf(0.82, 1.02, eased_progress))
	_draw_tile_ring(to_tile, Color(0.52, 0.46, 0.74, destination_alpha), 2.5 * preview_scale, lerpf(0.78, 0.98, eased_progress))
	_draw_blink_rift_mouth(from_point, source_alpha, clamped_progress, 0.08, preview)
	_draw_blink_rift_mouth(to_point, destination_alpha, clamped_progress, 0.58, preview)

	var settle_fade: float = 1.0 - clampf((clamped_progress - 0.86) / 0.14, 0.0, 1.0)
	for puff_index: int in range(4):
		var trail_t: float = clampf(eased_progress - float(puff_index) * 0.17, 0.0, 1.0)
		if trail_t <= 0.0 and clamped_progress < 0.16:
			continue
		var puff_alpha: float = (0.20 - float(puff_index) * 0.035) * (0.55 + 0.45 * clamped_progress) * preview_scale * settle_fade
		if puff_alpha <= 0.01:
			continue
		var wave_offset: Vector2 = normal * sin(trail_t * TAU * 1.7 + float(puff_index) * 0.9) * tile_width * 0.065
		var puff_center: Vector2 = from_point.lerp(to_point, trail_t) + path_lift * 0.84 + wave_offset
		var puff_radius: float = clampf(tile_width * (0.10 + float(puff_index) * 0.025), 6.0, 15.0)
		draw_circle(puff_center, puff_radius, Color(0.025, 0.018, 0.045, puff_alpha))
		draw_circle(puff_center + normal * tile_width * 0.03, puff_radius * 0.55, Color(0.18, 0.12, 0.26, puff_alpha * 0.48))

	var ghost_fade: float = 1.0 - clampf((clamped_progress - 0.80) / 0.20, 0.0, 1.0)
	_draw_blink_afterimage_ghost(from_point, maxf(0.0, 0.20 * (1.0 - eased_progress)) * ghost_fade, 0.96)
	for ghost_index: int in range(4):
		var ghost_t: float = clampf(eased_progress - float(ghost_index) * 0.13, 0.0, 1.0)
		if ghost_t <= 0.02:
			continue
		var ghost_center: Vector2 = from_point.lerp(to_point, ghost_t)
		ghost_center += normal * sin(ghost_t * TAU * 1.25 + float(ghost_index) * 0.65) * tile_width * 0.035
		var ghost_alpha: float = (0.28 - float(ghost_index) * 0.045) * (0.38 + 0.62 * clamped_progress) * ghost_fade
		_draw_blink_afterimage_ghost(ghost_center, ghost_alpha, 0.98 - float(ghost_index) * 0.045)
	_draw_blink_afterimage_ghost(current_point, (0.14 + 0.18 * clamped_progress) * ghost_fade, 1.04)

func _blink_rift_ease(progress: float) -> float:
	var t: float = clampf(progress, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _draw_blink_preview_integrated_rift(from_point: Vector2, to_point: Vector2, direction: Vector2, normal: Vector2, width: float, alpha_scale: float, phase: float) -> void:
	var texture: Texture2D = _effect_textures.get("blink_rift_preview", null)
	if texture != null:
		_draw_blink_preview_rift_texture(texture, from_point, to_point, width, alpha_scale)
		return
	_draw_blink_preview_rift_ribbon(from_point, to_point, direction, normal, 1.0, width, alpha_scale, phase)
	_draw_blink_preview_endpoint_smudge(from_point, direction, normal, width * 1.08, Color(0.010, 0.008, 0.026, 0.17 * alpha_scale), phase + 0.40)
	_draw_blink_preview_endpoint_smudge(from_point + direction * width * 0.42 - normal * width * 0.12, direction, normal, width * 0.72, Color(0.105, 0.070, 0.150, 0.11 * alpha_scale), phase + 1.60)
	_draw_blink_preview_endpoint_smudge(to_point, direction * -1.0, normal, width * 1.22, Color(0.030, 0.020, 0.060, 0.21 * alpha_scale), phase + 2.10)
	_draw_blink_preview_endpoint_smudge(to_point - direction * width * 0.36 + normal * width * 0.10, direction * -1.0, normal, width * 0.78, Color(0.36, 0.29, 0.52, 0.085 * alpha_scale), phase + 3.20)

func _draw_blink_preview_rift_texture(texture: Texture2D, from_point: Vector2, to_point: Vector2, width: float, alpha_scale: float) -> void:
	var path: Vector2 = to_point - from_point
	var path_length: float = path.length()
	if path_length <= 0.001:
		return
	var draw_size := Vector2(
		path_length + width * 8.4,
		clampf(width * 8.6, 74.0, 136.0)
	)
	var center: Vector2 = from_point.lerp(to_point, 0.5)
	draw_set_transform(center, path.angle(), Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, 0.88 * alpha_scale))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_blink_preview_endpoint_smudge(center: Vector2, direction: Vector2, normal: Vector2, width: float, color: Color, phase: float) -> void:
	var points := PackedVector2Array()
	var point_count: int = 17
	for point_index: int in range(point_count):
		var angle: float = TAU * float(point_index) / float(point_count)
		var forward: float = cos(angle)
		var sideways: float = sin(angle)
		var contour: float = 0.88 + 0.13 * sin(angle * 3.0 + phase)
		contour += 0.07 * sin(angle * 7.0 + phase * 0.63)
		var taper: float = 1.0 + maxf(forward, 0.0) * 0.34
		var point: Vector2 = center
		point += direction * forward * width * 0.78 * contour * taper
		point += normal * sideways * width * 0.50 * contour
		point += direction * sin(angle * 5.0 + phase * 0.41) * width * 0.055
		points.append(point)
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func _draw_blink_smoke_wash(from_point: Vector2, to_point: Vector2, direction: Vector2, normal: Vector2, reveal: float, width: float, alpha_scale: float, phase: float, preview: bool) -> void:
	var clamped_reveal: float = clampf(reveal, 0.0, 1.0)
	if clamped_reveal <= 0.0 or width <= 0.0:
		return
	if preview:
		_draw_blink_preview_rift_ribbon(from_point, to_point, direction, normal, clamped_reveal, width, alpha_scale, phase)
		return
	var path_length: float = from_point.distance_to(to_point)
	var lobe_count: int = mini(18, maxi(6, int(ceil(path_length / maxf(width * 0.85, 1.0)))))
	var base_alpha: float = 0.088
	for lobe_index: int in range(lobe_count):
		var t: float = (float(lobe_index) + 0.5) / float(lobe_count)
		if t > clamped_reveal:
			continue
		var reveal_fade: float = clampf((clamped_reveal - t) * float(lobe_count), 0.0, 1.0)
		var center_fade: float = 0.38 + 0.62 * sin(t * PI)
		var drift: float = sin(t * TAU * 2.15 + phase * 0.58) * width * 0.78
		drift += sin(t * TAU * 5.0 + phase * 0.21) * width * 0.22
		var pull: float = cos(t * TAU * 1.4 + phase * 0.35) * width * 0.24
		var center: Vector2 = from_point.lerp(to_point, t) + normal * drift + direction * pull
		center += Vector2(0.0, sin(t * PI) * width * 0.13)
		var rough: float = 0.84 + 0.16 * sin(t * TAU * 6.0 + phase)
		var radius: float = width * ((1.48 if preview else 1.18) + 0.44 * sin(t * TAU * 2.8 + phase * 0.42)) * rough
		var alpha: float = base_alpha * alpha_scale * center_fade * reveal_fade
		draw_circle(center + normal * width * 0.18, radius * 1.36, Color(0.010, 0.008, 0.025, alpha * 0.46))
		draw_circle(center, radius, Color(0.055, 0.035, 0.085, alpha))
		draw_circle(center + direction * width * 0.24 - normal * width * 0.10, radius * 0.56, Color(0.20, 0.145, 0.29, alpha * 0.52))

func _draw_blink_preview_rift_ribbon(from_point: Vector2, to_point: Vector2, direction: Vector2, normal: Vector2, reveal: float, width: float, alpha_scale: float, phase: float) -> void:
	var clamped_reveal: float = clampf(reveal, 0.0, 1.0)
	if clamped_reveal <= 0.0:
		return
	var path_length: float = from_point.distance_to(to_point)
	var segment_count: int = mini(18, maxi(7, int(ceil(path_length / maxf(width * 0.88, 1.0)))))
	_draw_blink_preview_ribbon_layer(from_point, to_point, direction, normal, clamped_reveal, width * 2.75, segment_count, Color(0.006, 0.005, 0.018, 0.135 * alpha_scale), phase + 0.20, Vector2(0.0, width * 0.18))
	_draw_blink_preview_ribbon_layer(from_point, to_point, direction, normal, clamped_reveal, width * 2.05, segment_count, Color(0.035, 0.023, 0.070, 0.175 * alpha_scale), phase + 1.00, normal * width * 0.05)
	_draw_blink_preview_ribbon_layer(from_point, to_point, direction, normal, clamped_reveal, width * 1.22, segment_count, Color(0.120, 0.080, 0.180, 0.135 * alpha_scale), phase + 2.20, -normal * width * 0.06)
	_draw_blink_preview_ribbon_layer(from_point, to_point, direction, normal, clamped_reveal, width * 0.54, segment_count, Color(0.46, 0.38, 0.64, 0.055 * alpha_scale), phase + 3.50, direction * width * 0.06)

func _draw_blink_preview_ribbon_layer(from_point: Vector2, to_point: Vector2, direction: Vector2, normal: Vector2, reveal: float, width: float, segment_count: int, color: Color, phase: float, offset: Vector2) -> void:
	var left_points: Array[Vector2] = []
	var right_points: Array[Vector2] = []
	var safe_segments: int = maxi(2, segment_count)
	for point_index: int in range(safe_segments + 1):
		var t: float = reveal * float(point_index) / float(safe_segments)
		var center_fade: float = pow(sin(t * PI), 0.62)
		var wave: float = sin(t * TAU * 1.70 + phase) * width * 0.10
		wave += sin(t * TAU * 3.85 + phase * 0.43) * width * 0.045
		var center: Vector2 = from_point.lerp(to_point, t) + offset + normal * wave
		center += Vector2(0.0, sin(t * PI) * width * 0.030)
		var edge_noise: float = 0.74 + 0.18 * sin(t * TAU * 5.10 + phase * 0.80)
		edge_noise += 0.08 * sin(t * TAU * 9.30 + phase * 1.70)
		var half_width: float = width * (0.18 + 0.44 * center_fade) * edge_noise
		var ragged_shift: Vector2 = direction * sin(t * TAU * 6.50 + phase * 0.37) * width * 0.035
		left_points.append(center + normal * half_width + ragged_shift)
		right_points.push_front(center - normal * half_width - ragged_shift * 0.72)
	var polygon := PackedVector2Array()
	for point: Vector2 in left_points:
		polygon.append(point)
	for point: Vector2 in right_points:
		polygon.append(point)
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, color)

func _draw_blink_smoke_band(from_point: Vector2, to_point: Vector2, normal: Vector2, progress: float, width: float, color: Color, phase: float) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if clamped_progress <= 0.0 or width <= 0.0:
		return
	var segment_count: int = 16
	var visible_segments: int = maxi(2, int(ceil(float(segment_count) * clamped_progress)))
	var previous_point := Vector2.ZERO
	for point_index: int in range(visible_segments + 1):
		var t: float = clamped_progress * float(point_index) / float(visible_segments)
		var wave: float = sin(t * TAU * 1.7 + phase) * width * 0.42
		wave += sin(t * TAU * 3.4 + phase * 0.55) * width * 0.18
		var sag: float = sin(t * PI) * width * 0.12
		var point: Vector2 = from_point.lerp(to_point, t) + normal * wave + Vector2(0.0, sag)
		if point_index > 0:
			var segment_t: float = float(point_index) / float(visible_segments)
			var center_fade: float = 0.34 + 0.66 * sin(t * PI)
			var rough: float = 0.78 + 0.22 * sin(t * TAU * 5.6 + phase * 0.37)
			var alpha: float = color.a * (0.38 + 0.62 * segment_t) * center_fade * rough
			var segment_width: float = width * (0.55 + 0.35 * center_fade + 0.10 * rough)
			draw_line(previous_point, point, Color(color.r, color.g, color.b, alpha), segment_width, true)
		previous_point = point

func _draw_blink_rift_edge_strokes(from_point: Vector2, to_point: Vector2, direction: Vector2, normal: Vector2, reveal: float, width: float, alpha_scale: float, phase: float, preview: bool) -> void:
	var clamped_reveal: float = clampf(reveal, 0.0, 1.0)
	if clamped_reveal <= 0.0 or width <= 0.0:
		return
	var path_length: float = from_point.distance_to(to_point)
	var stroke_count: int = mini(22, maxi(8, int(ceil(path_length / maxf(width * 0.58, 1.0)))))
	var base_alpha: float = 0.31 if preview else 0.22
	for stroke_index: int in range(stroke_count):
		var t: float = (float(stroke_index) + 0.36) / float(stroke_count)
		if t > clamped_reveal:
			continue
		var side: float = -1.0 if stroke_index % 2 == 0 else 1.0
		var edge_offset: float = width * (0.70 + 0.34 * sin(t * TAU * 3.1 + phase)) * side
		var center: Vector2 = from_point.lerp(to_point, t) + normal * edge_offset
		center += direction * sin(t * TAU * 4.4 + phase * 0.33) * width * 0.20
		var tangent_length: float = width * (0.34 + 0.18 * sin(t * TAU * 5.3 + phase * 0.44))
		var curl: Vector2 = normal * side * width * 0.20 * sin(t * TAU * 2.2 + phase)
		var stroke_alpha: float = base_alpha * alpha_scale * (0.48 + 0.52 * sin(t * PI))
		var start_point: Vector2 = center - direction * tangent_length + curl
		var end_point: Vector2 = center + direction * tangent_length - curl * 0.36
		draw_line(start_point, end_point, Color(0.020, 0.014, 0.040, stroke_alpha * 0.88), 1.45 if preview else 1.9, true)
		draw_line(start_point.lerp(end_point, 0.34), end_point, Color(0.48, 0.42, 0.66, stroke_alpha * 0.38), 0.75 if preview else 1.05, true)

func _draw_blink_rift_motes(from_point: Vector2, to_point: Vector2, direction: Vector2, normal: Vector2, reveal: float, width: float, alpha_scale: float, phase: float, preview: bool) -> void:
	var clamped_reveal: float = clampf(reveal, 0.0, 1.0)
	if clamped_reveal <= 0.0 or width <= 0.0:
		return
	var path_length: float = from_point.distance_to(to_point)
	var mote_count: int = mini(28, maxi(9, int(ceil(path_length / maxf(width * 0.42, 1.0)))))
	var base_alpha: float = 0.22 if preview else 0.18
	for mote_index: int in range(mote_count):
		var t: float = (float(mote_index) + 0.24) / float(mote_count)
		if t > clamped_reveal:
			continue
		var offset: float = sin(t * TAU * 7.0 + phase * 0.49) * width * 1.28
		var lift: float = cos(t * TAU * 4.0 + phase * 0.31) * width * 0.26
		var center: Vector2 = from_point.lerp(to_point, t) + normal * offset + direction * lift
		var center_fade: float = 0.28 + 0.72 * sin(t * PI)
		var alpha: float = base_alpha * alpha_scale * center_fade * (0.56 + 0.44 * sin(t * TAU * 5.5 + phase))
		var radius: float = 0.75 + 1.15 * (0.5 + 0.5 * sin(t * TAU * 6.3 + phase * 0.62))
		if preview:
			var mote_direction: Vector2 = direction * radius * 1.55 + normal * sin(t * TAU * 3.4 + phase) * radius * 0.70
			draw_line(center - mote_direction * 0.35, center + mote_direction, Color(0.58, 0.52, 0.76, alpha * 0.74), 0.85, true)
			draw_line(center + Vector2(0.0, 0.8), center + mote_direction * 0.72 + Vector2(0.0, 0.8), Color(0.025, 0.018, 0.045, alpha * 0.18), 1.2, true)
		else:
			draw_circle(center, radius, Color(0.58, 0.52, 0.76, alpha))
			draw_circle(center + Vector2(0.0, 0.8), radius * 1.7, Color(0.025, 0.018, 0.045, alpha * 0.22))

func _draw_blink_rift_mouth(center: Vector2, alpha: float, progress: float, phase: float, preview: bool = false) -> void:
	if alpha <= 0.0:
		return
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	var mouth_center: Vector2 = center + Vector2(0.0, -tile_height * 0.20)
	var pulse: float = 0.5 + 0.5 * sin((progress + phase) * TAU)
	var mouth_scale: float = 0.88 if preview else 1.0
	draw_circle(mouth_center + Vector2(0.0, tile_height * 0.04), tile_width * (0.18 + 0.03 * pulse) * mouth_scale, Color(0.010, 0.008, 0.024, alpha * 0.16))
	draw_circle(mouth_center, tile_width * (0.10 + 0.04 * pulse) * mouth_scale, Color(0.015, 0.010, 0.030, alpha * 0.46))
	draw_circle(mouth_center + Vector2(tile_width * 0.018, -tile_height * 0.018), tile_width * (0.058 + 0.018 * pulse) * mouth_scale, Color(0.20, 0.14, 0.30, alpha * 0.28))
	for ring_index: int in range(4):
		var radius: float = tile_width * (0.12 + float(ring_index) * 0.044 + pulse * 0.016) * mouth_scale
		var start_angle: float = phase * TAU + progress * TAU * (0.62 + float(ring_index) * 0.16) + float(ring_index) * 0.74
		var end_angle: float = start_angle + PI * (0.74 + float(ring_index) * 0.13)
		var ring_alpha: float = alpha * (0.56 - float(ring_index) * 0.09)
		draw_arc(mouth_center, radius, start_angle, end_angle, 14, Color(0.18, 0.12, 0.28, ring_alpha), 1.25 if preview else 1.6)
		draw_arc(mouth_center, radius + 1.8, end_angle - PI * 0.22, end_angle, 7, Color(0.58, 0.52, 0.78, ring_alpha * 0.34), 0.9 if preview else 1.2)

func _draw_blink_afterimage_ghost(center: Vector2, alpha: float, scale: float) -> void:
	if alpha <= 0.0:
		return
	var unit: Dictionary = _blink_player_unit_snapshot()
	var texture: Texture2D = _texture_for_unit(unit)
	if texture == null:
		draw_circle(center + Vector2(0.0, -_tile_height() * 0.18), _tile_width() * 0.12, Color(0.36, 0.30, 0.52, alpha))
		return
	var base_rect: Rect2 = _unit_draw_rect_for_center(unit, center)
	var ghost_rect: Rect2 = _scaled_unit_rect(base_rect, scale)
	ghost_rect.position += Vector2(0.0, -_tile_height() * 0.06)
	_draw_iso_ground_shadow(center + Vector2(0.0, _tile_height() * 0.14), _tile_width() * 0.36 * scale, _tile_height() * 0.18, _tile_width() * 0.04, alpha * 0.34)
	draw_texture_rect(texture, Rect2(ghost_rect.position + Vector2(-2.0, -2.0), ghost_rect.size), false, Color(0.018, 0.012, 0.035, alpha * 0.72))
	draw_texture_rect(texture, ghost_rect, false, Color(0.48, 0.40, 0.68, alpha))
	draw_texture_rect(texture, Rect2(ghost_rect.position + Vector2(2.0, 1.0), ghost_rect.size), false, Color(0.08, 0.04, 0.12, alpha * 0.30))

func _blink_player_unit_snapshot() -> Dictionary:
	var player: Dictionary = combat_state.get("player", {})
	return {
		"key": "player",
		"role": "player",
		"type": "player",
		"name": "Player",
		"pos": player.get("pos", Vector2i.ZERO),
		"hp": int(player.get("hp", 1)),
		"max_hp": int(player.get("max_hp", maxi(1, int(player.get("hp", 1))))),
		"block": int(player.get("block", 0)),
		"stoneskin": int(player.get("stoneskin", 0)),
		"burn": int(player.get("burn", 0)),
		"freeze": int(player.get("freeze", 0)),
		"shock": int(player.get("shock", 0)),
		"immobilize": bool(player.get("immobilize", false)),
		"poison": player.get("poison", {}).duplicate(true)
	}

func _draw_aoe_effect(effect: Dictionary, progress: float, from_point: Vector2, center_point: Vector2) -> void:
	var tiles: Array[Vector2i] = _vector2i_array(effect.get("tiles", []))
	if tiles.is_empty():
		return
	var preview: bool = bool(effect.get("preview", false))
	var accent: Color = _aoe_effect_accent(effect)
	var secondary: Color = _aoe_effect_secondary(effect)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * TAU * (1.55 if preview else 1.05))
	var reveal: float = 1.0 if preview else clampf(progress / 0.42, 0.0, 1.0)
	var base_alpha: float = (0.76 + pulse * 0.18) if preview else (0.42 + reveal * 0.42)
	for tile: Vector2i in tiles:
		var ring_scale: float = 0.74 + 0.06 * pulse if preview else 0.76 + 0.08 * reveal
		_draw_tile_ring(tile, Color(accent.r, accent.g, accent.b, base_alpha), 3.0 + 1.0 * reveal, ring_scale)
		draw_circle(_tile_center(tile), _tile_width() * 0.065, Color(secondary.r, secondary.g, secondary.b, 0.22 + 0.14 * pulse))
	if center_point != Vector2.ZERO:
		var reticle_radius: float = _tile_width() * (0.16 + 0.025 * pulse)
		_draw_target_reticle(center_point + Vector2(0.0, -_tile_height() * 0.42), Color(accent.r, accent.g, accent.b, 0.84 + 0.14 * pulse), reticle_radius)
	var line_tiles: Array[Vector2i] = _ordered_aoe_line_tiles_for_effect(effect)
	if line_tiles.size() >= 2:
		_draw_aoe_line_effect(line_tiles, accent, secondary, base_alpha, preview)
	if preview and from_point != Vector2.ZERO and center_point != Vector2.ZERO:
		var start: Vector2 = from_point + Vector2(0.0, -_tile_height() * 0.72)
		var end: Vector2 = center_point + Vector2(0.0, -_tile_height() * 0.50)
		var control: Vector2 = _arc_control_point(start, end)
		_draw_bezier_glow(start, control, end, Color(secondary.r, secondary.g, secondary.b, 0.18 + 0.08 * pulse), 1.4)

func _draw_aoe_line_effect(line_tiles: Array[Vector2i], accent: Color, secondary: Color, alpha: float, preview: bool) -> void:
	var points := PackedVector2Array()
	for tile: Vector2i in line_tiles:
		points.append(_tile_center(tile) + Vector2(0.0, -_tile_height() * 0.62))
	if points.size() < 2:
		return
	var core_width: float = 4.0 if preview else 4.6
	draw_polyline(points, Color(0.0, 0.0, 0.0, alpha * 0.26), core_width + 9.0, true)
	draw_polyline(points, Color(secondary.r, secondary.g, secondary.b, alpha * 0.44), core_width + 4.8, true)
	draw_polyline(points, Color(accent.r, accent.g, accent.b, alpha), core_width, true)
	for index: int in range(points.size() - 1):
		_draw_aoe_bolt_segment(points[index], points[index + 1], accent, secondary, alpha)
	for point: Vector2 in points:
		draw_circle(point, 6.0, Color(1.0, 0.96, 0.72, alpha * 0.62))

func _draw_aoe_bolt_segment(start: Vector2, finish: Vector2, accent: Color, secondary: Color, alpha: float) -> void:
	var delta: Vector2 = finish - start
	if delta.length_squared() <= 1.0:
		return
	var perpendicular: Vector2 = Vector2(-delta.y, delta.x).normalized()
	var mid: Vector2 = start.lerp(finish, 0.5) + perpendicular * 7.0
	draw_line(start, mid, Color(0.0, 0.0, 0.0, alpha * 0.24), 7.0, true)
	draw_line(mid, finish, Color(0.0, 0.0, 0.0, alpha * 0.24), 7.0, true)
	draw_line(start, mid, Color(secondary.r, secondary.g, secondary.b, alpha * 0.78), 3.4, true)
	draw_line(mid, finish, Color(secondary.r, secondary.g, secondary.b, alpha * 0.78), 3.4, true)
	draw_line(start, mid, Color(accent.r, accent.g, accent.b, alpha), 1.6, true)
	draw_line(mid, finish, Color(accent.r, accent.g, accent.b, alpha), 1.6, true)

func _ordered_aoe_line_tiles_for_effect(effect: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = _vector2i_array(effect.get("tiles", []))
	if tiles.size() < 2:
		return _vector2i_array([])
	var same_x: bool = true
	var same_y: bool = true
	var first_tile: Vector2i = tiles[0]
	for tile: Vector2i in tiles:
		if tile.x != first_tile.x:
			same_x = false
		if tile.y != first_tile.y:
			same_y = false
	if not same_x and not same_y:
		return _vector2i_array([])
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if same_x else a.x < b.x
	)
	return tiles

func _aoe_effect_accent(effect: Dictionary) -> Color:
	var element_id: String = _effect_element(effect)
	if ElementData.is_elemental(element_id):
		if element_id == ElementData.LIGHTNING:
			return Color(1.0, 0.91, 0.34, 1.0)
		return ElementData.accent(element_id).lightened(0.22)
	return Color(1.0, 0.76, 0.42, 1.0)

func _aoe_effect_secondary(effect: Dictionary) -> Color:
	match _effect_element(effect):
		ElementData.FIRE:
			return Color(1.0, 0.38, 0.18, 1.0)
		ElementData.ICE:
			return Color(0.62, 0.90, 1.0, 1.0)
		ElementData.LIGHTNING:
			return Color(0.58, 0.78, 1.0, 1.0)
		ElementData.AIR:
			return Color(0.70, 1.0, 0.90, 1.0)
		ElementData.EARTH:
			return Color(0.80, 0.94, 0.48, 1.0)
		_:
			return Color(1.0, 0.92, 0.64, 1.0)

func _effect_element(effect: Dictionary) -> String:
	return str(effect.get("element", effect.get("_card_element", ElementData.NONE)))

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
		var text_pos: Vector2 = _tile_center(tile) + Vector2(float(entry.get("x_offset", -18.0)), -84.0 + float(entry.get("offset", 0.0)) - rise)
		var color: Color = entry.get("color", Color("f8f0da"))
		color.a *= clampf(float(entry.get("alpha", 1.0)), 0.0, 1.0)
		var label_width: float = float(entry.get("width", 48.0))
		var font_size: int = int(entry.get("font_size", 16))
		var text: String = str(entry.get("text", ""))
		var outline_size: int = int(entry.get("outline_size", 2))
		if outline_size > 0:
			var outline_color: Color = entry.get("outline_color", Color("200806"))
			outline_color.a *= color.a
			for outline_offset: Vector2 in [
				Vector2(-outline_size, 0.0),
				Vector2(outline_size, 0.0),
				Vector2(0.0, -outline_size),
				Vector2(0.0, outline_size),
				Vector2(-outline_size, -outline_size),
				Vector2(outline_size, -outline_size),
				Vector2(-outline_size, outline_size),
				Vector2(outline_size, outline_size)
			]:
				draw_string(font, text_pos + outline_offset, text, HORIZONTAL_ALIGNMENT_LEFT, label_width, font_size, outline_color)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, label_width, font_size, color)

func _draw_melee_slash_effect(from_point: Vector2, to_point: Vector2, progress: float) -> void:
	if progress >= 0.82:
		return
	var frames: Array = _effect_frames.get("melee_slash", [])
	if frames.is_empty():
		return
	var slash_progress: float = clampf(progress / 0.82, 0.0, 1.0)
	var frame_index: int = clampi(int(floor(slash_progress * float(frames.size()))), 0, frames.size() - 1)
	var texture: Texture2D = frames[frame_index]
	if texture == null:
		return
	var from_anchor: Vector2 = from_point + Vector2(0.0, -_tile_width() * 0.52)
	var to_anchor: Vector2 = to_point + Vector2(0.0, -_tile_width() * 0.38)
	var direction: Vector2 = to_anchor - from_anchor
	var slash_center: Vector2 = from_anchor.lerp(to_anchor, 0.50)
	var draw_size := Vector2.ONE * _tile_width() * 1.24
	var alpha: float = clampf(sin(slash_progress * PI) * 1.18, 0.0, 1.0)
	if frame_index == 0:
		alpha = maxf(alpha, 0.58)
	elif frame_index >= frames.size() - 1:
		alpha = minf(alpha, 0.22)
	var horizontal_sign: float = -1.0 if direction.x < -1.0 else 1.0
	var rotation: float = deg_to_rad(-10.0 * horizontal_sign)
	draw_set_transform(slash_center, rotation, Vector2(horizontal_sign, 1.0))
	var draw_rect := Rect2(-draw_size * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_path_preview() -> void:
	if _blink_preview_effect_active():
		return
	var path_tiles: Array[Vector2i] = _vector2i_array(presentation.get("path_tiles", []))
	if path_tiles.is_empty():
		return
	var color: Color = presentation.get("path_color", MOVE_PATH_COLOR)
	var point_offset := Vector2(0.0, -10.0)
	if path_tiles.size() == 1:
		var single_center: Vector2 = _tile_center(path_tiles[0]) + point_offset
		draw_circle(single_center, 9.0, Color(color.r, color.g, color.b, 0.18))
		draw_arc(single_center, 12.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.74), 2.2, true)
		return
	for index: int in range(path_tiles.size() - 1):
		var from_point: Vector2 = _tile_center(path_tiles[index]) + point_offset
		var to_point: Vector2 = _tile_center(path_tiles[index + 1]) + point_offset
		draw_line(from_point, to_point, MOVE_PATH_SHADOW, 9.0, true)
		draw_line(from_point, to_point, Color(color.r, color.g, color.b, 0.30), 6.0, true)
		draw_line(from_point, to_point, color, 2.4, true)
		_draw_path_arrowhead(from_point, to_point, color)
	for tile: Vector2i in path_tiles:
		var center: Vector2 = _tile_center(tile) + point_offset
		draw_circle(center, 5.8, Color(0.05, 0.05, 0.04, 0.78))
		draw_circle(center, 3.3, color)

func _blink_preview_effect_active() -> bool:
	var effect: Dictionary = presentation.get("effect", {})
	return str(effect.get("kind", "")) == "blink" and bool(effect.get("preview", false))

func _draw_path_arrowhead(from_point: Vector2, to_point: Vector2, color: Color) -> void:
	var dir: Vector2 = (to_point - from_point).normalized()
	if dir.length_squared() <= 0.0:
		return
	var perp := Vector2(-dir.y, dir.x)
	var center: Vector2 = from_point.lerp(to_point, 0.62)
	var arrow_size: float = 8.0
	var points := PackedVector2Array([
		center + dir * arrow_size,
		center - dir * arrow_size * 0.55 + perp * arrow_size * 0.48,
		center - dir * arrow_size * 0.55 - perp * arrow_size * 0.48
	])
	draw_colored_polygon(points, Color(0.02, 0.03, 0.03, 0.45))
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.86))

func _draw_movement_risk_chips() -> void:
	var chips: Array = presentation.get("movement_risk_chips", [])
	if chips.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var slots_by_tile: Dictionary = {}
	for chip_var: Variant in chips:
		if typeof(chip_var) != TYPE_DICTIONARY:
			continue
		var chip: Dictionary = chip_var
		var tile: Vector2i = chip.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var label: String = str(chip.get("label", "")).strip_edges()
		if label.is_empty():
			continue
		var slot: int = int(slots_by_tile.get(tile, 0))
		slots_by_tile[tile] = slot + 1
		var center: Vector2 = _tile_center(tile) + Vector2(0.0, -_tile_height() * 0.92 - float(slot) * (MOVE_RISK_CHIP_HEIGHT + MOVE_RISK_CHIP_GAP))
		_draw_movement_risk_chip(font, center, label, str(chip.get("kind", "")))

func _draw_movement_risk_chip(font: Font, center: Vector2, label: String, kind: String) -> void:
	var colors: Dictionary = _movement_risk_chip_colors(kind)
	var text_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MOVE_RISK_CHIP_FONT_SIZE).x
	var chip_width: float = clampf(text_width + 14.0, 38.0, 104.0)
	var rect := Rect2(center - Vector2(chip_width * 0.5, MOVE_RISK_CHIP_HEIGHT * 0.5), Vector2(chip_width, MOVE_RISK_CHIP_HEIGHT))
	draw_rect(rect.grow(1.5), Color(0.0, 0.0, 0.0, 0.34), true)
	draw_rect(rect, colors.get("fill", Color("241914")), true)
	draw_rect(rect, colors.get("border", Color("d8b96f")), false, 1.4)
	draw_string(
		font,
		rect.position + Vector2(0.0, 12.5),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		MOVE_RISK_CHIP_FONT_SIZE,
		colors.get("text", Color("fff4dc"))
	)

func _movement_risk_chip_colors(kind: String) -> Dictionary:
	match kind:
		"danger":
			return {"fill": Color(0.27, 0.08, 0.055, 0.94), "border": Color("ef8b62"), "text": Color("ffe5cf")}
		"status":
			return {"fill": Color(0.18, 0.15, 0.07, 0.94), "border": Color("f3d762"), "text": Color("fff0b7")}
		"pickup":
			return {"fill": Color(0.08, 0.20, 0.13, 0.94), "border": Color("83d088"), "text": Color("ddffd7")}
	return {"fill": Color(0.12, 0.10, 0.08, 0.94), "border": Color("d8b96f"), "text": Color("fff4dc")}

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
	return draw_tile_for_unit_origin(unit, unit.get("pos", Vector2i.ZERO))

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

func _layout_signature_for_state(next_state: Dictionary, next_exit_tiles: Dictionary, next_presentation: Dictionary, room_grid_signature: String) -> String:
	if next_state.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append(room_grid_signature)
	parts.append("exit:%s" % _vector2i_dict_key_signature(next_exit_tiles))
	parts.append("active:%s" % _truthy_vector2i_dict_key_signature(next_presentation.get("active_door_tiles", {}) as Dictionary))
	parts.append("locked:%s" % _truthy_vector2i_dict_key_signature(next_presentation.get("locked_door_tiles", {}) as Dictionary))
	return "|".join(parts)

func _moss_signature_for_state(next_state: Dictionary) -> String:
	if next_state.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append(_coord_signature(next_state.get("room_coord", Vector2i.ZERO)))
	var moss: Dictionary = next_state.get("moss", {})
	for surface: String in ["floor", "wall", "pillar"]:
		parts.append("%s:%s" % [surface, _vector2i_array_signature(moss.get(surface, []))])
	return "|".join(parts)

func _room_grid_signature(next_state: Dictionary) -> String:
	if next_state.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append(_coord_signature(next_state.get("room_coord", Vector2i.ZERO)))
	var grid: Array = next_state.get("grid", [])
	for row_var: Variant in grid:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var cells: Array[String] = []
		for cell_var: Variant in (row_var as Array):
			cells.append(str(cell_var))
		parts.append(",".join(cells))
	return "|".join(parts)

func _vector2i_dict_key_signature(values: Dictionary) -> String:
	var keys: Array[String] = []
	for key_var: Variant in values.keys():
		if typeof(key_var) == TYPE_VECTOR2I:
			keys.append(_coord_signature(key_var))
	keys.sort()
	return ",".join(keys)

func _truthy_vector2i_dict_key_signature(values: Dictionary) -> String:
	var keys: Array[String] = []
	for key_var: Variant in values.keys():
		if typeof(key_var) != TYPE_VECTOR2I:
			continue
		if bool(values.get(key_var, false)):
			keys.append(_coord_signature(key_var))
	keys.sort()
	return ",".join(keys)

func _vector2i_array_signature(values: Array) -> String:
	var keys: Array[String] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			keys.append(_coord_signature(value))
	keys.sort()
	return ",".join(keys)

func _coord_signature(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

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
		"door_col": AssetLoader.flip_texture_h(door_texture),
		"column_torch_left": AssetLoader.load_texture(COLUMN_TORCH_LEFT_PATH),
		"column_torch_right": AssetLoader.load_texture(COLUMN_TORCH_RIGHT_PATH)
	}
	_scene_prop_textures = {
		"campfire_bonfire": AssetLoader.load_texture(CAMPFIRE_BONFIRE_PATH),
		"relic_chest": AssetLoader.load_texture(RELIC_CHEST_PATH),
		"blacksmith_forge": AssetLoader.load_texture(BLACKSMITH_FORGE_PATH),
		"arcanist_table": AssetLoader.load_texture(ARCANIST_TABLE_PATH),
		"scavenger_stall": AssetLoader.load_texture(SCAVENGER_STALL_PATH)
	}
	_scene_prop_idle_frames = {
		"campfire_bonfire": _load_sprite_sheet_frames(
			CAMPFIRE_BONFIRE_IDLE_PATH,
			CAMPFIRE_BONFIRE_IDLE_COLUMNS,
			CAMPFIRE_BONFIRE_IDLE_ROWS
		)
	}
	_pillar_torch_idle_frames = {
		"left": _load_sprite_sheet_frames(
			COLUMN_TORCH_LEFT_IDLE_PATH,
			COLUMN_TORCH_IDLE_COLUMNS,
			COLUMN_TORCH_IDLE_ROWS
		),
		"right": _load_sprite_sheet_frames(
			COLUMN_TORCH_RIGHT_IDLE_PATH,
			COLUMN_TORCH_IDLE_COLUMNS,
			COLUMN_TORCH_IDLE_ROWS
		)
	}
	_effect_textures = {
		"lethal_skull": AssetLoader.load_texture(LETHAL_SKULL_EFFECT_PATH),
		"blink_rift_preview": AssetLoader.load_texture(BLINK_RIFT_PREVIEW_TEXTURE_PATH)
	}
	_effect_frames = {
		"melee_slash": _load_sprite_sheet_frames(
			MELEE_SLASH_SHEET_PATH,
			MELEE_SLASH_SHEET_COLUMNS,
			MELEE_SLASH_SHEET_ROWS
		),
		"defense_heal_casts": _load_sprite_sheet_frames(
			DEFENSE_HEAL_CASTS_PATH,
			DEFENSE_HEAL_CASTS_COLUMNS,
			DEFENSE_HEAL_CASTS_ROWS
		)
	}
	_projectile_atlas = AssetLoader.load_texture(ELEMENTAL_PROJECTILE_ATLAS_PATH)
	_projectile_textures.clear()
	_ambient_particle_atlas = AssetLoader.load_texture(AMBIENT_PARTICLE_ATLAS_PATH)
	_ambient_particle_glow_atlas = AssetLoader.load_texture(AMBIENT_PARTICLE_GLOW_ATLAS_PATH)
	_ambient_fire_soft_atlas = AssetLoader.load_texture(AMBIENT_FIRE_SOFT_ATLAS_PATH)
	_ambient_air_wisp_atlas = AssetLoader.load_texture(AMBIENT_AIR_WISP_FRAMES_PATH)
	_ambient_air_wisp_soft_atlas = AssetLoader.load_texture(AMBIENT_AIR_WISP_SOFT_ATLAS_PATH)
	_ambient_air_wisp_glow_atlas = AssetLoader.load_texture(AMBIENT_AIR_WISP_GLOW_FRAMES_PATH)
	_ambient_particle_textures.clear()
	_ambient_particle_glow_textures.clear()
	_ambient_fire_soft_textures.clear()
	_ambient_air_wisp_textures.clear()
	_ambient_air_wisp_soft_textures.clear()
	_ambient_air_wisp_glow_textures.clear()
	_door_opening_frames = _load_door_opening_frames()
	_door_opening_flipped_frames = []
	for frame_texture: Texture2D in _door_opening_frames:
		_door_opening_flipped_frames.append(AssetLoader.flip_texture_h(frame_texture))
	_loot_textures = {
		"healing_vial": AssetLoader.load_texture("res://assets/art/tiles/healing_vial.png"),
		"rusty_shield": AssetLoader.load_texture("res://assets/art/tiles/rusty_shield.png"),
		"dropped_embers": AssetLoader.load_texture(DROPPED_EMBERS_PATH)
	}
	_terrain_textures = {
		"wooden_box": AssetLoader.load_texture("res://assets/art/tiles/wooden_box.png"),
		"wooden_crate": AssetLoader.load_texture("res://assets/art/tiles/wooden_crate.png")
	}
	_element_textures.clear()
	for element_id: String in ElementData.all_elements():
		_element_textures[element_id] = AssetLoader.load_texture(ElementData.icon_path(element_id))
	_trap_textures.clear()
	for element_id: String in ElementData.all_elements():
		_trap_textures[element_id] = AssetLoader.load_texture("res://assets/art/traps/trap_%s.png" % element_id)
	_trap_blast_textures.clear()
	for element_id: String in ElementData.all_elements():
		_trap_blast_textures[element_id] = AssetLoader.load_texture("res://assets/art/effects/trap_blast_%s.png" % element_id)
	_door_icon_textures.clear()
	for icon_id: String in RoomIcons.all_icon_ids():
		_door_icon_textures[icon_id] = RoomIcons.icon_texture(icon_id)
	_keyword_icon_textures.clear()
	for icon_key_var: Variant in ActionIcons.all_icon_keys():
		var icon_key: String = str(icon_key_var)
		_keyword_icon_textures[icon_key] = ActionIcons.icon_texture(icon_key)
	_unit_textures.clear()
	_idle_frames_by_type.clear()
	_death_frames_by_type.clear()
	_unit_shadow_polygon_cache.clear()
	_unit_shadow_bottom_ratio_cache.clear()
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

func _load_sprite_sheet_frames(path: String, columns: int, rows: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var sheet: Texture2D = AssetLoader.load_texture(path)
	if sheet == null:
		return frames
	var frame_size := Vector2i(
		int(sheet.get_width() / maxi(1, columns)),
		int(sheet.get_height() / maxi(1, rows))
	)
	return AssetLoader.build_sprite_sheet_frames(sheet, frame_size, _idle_frame_indices({
		"columns": columns,
		"rows": rows,
		"order": IDLE_SHEET_ORDER_ROW_MAJOR,
		"ping_pong": false
	}))

func _texture_for_scene_prop(prop: Dictionary) -> Texture2D:
	var idle_frames: Array[Texture2D] = _scene_prop_idle_frames_for_kind(str(prop.get("kind", "")))
	if _scene_prop_idle_animation_active(prop) and not idle_frames.is_empty():
		return idle_frames[_scene_prop_idle_frame_index(prop)]
	return _scene_prop_textures.get(str(prop.get("kind", "")), null)

func _scene_prop_idle_frames_for_kind(kind: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_var: Variant in _scene_prop_idle_frames.get(kind, []):
		if frame_var is Texture2D:
			frames.append(frame_var)
	return frames

func _door_opening_frame_canvas_size() -> Vector2i:
	var canvas_size := Vector2i.ZERO
	for region: Rect2i in DOOR_OPENING_FRAME_REGIONS:
		canvas_size.x = maxi(canvas_size.x, region.size.x)
		canvas_size.y = maxi(canvas_size.y, region.size.y)
	return canvas_size

func _texture_for_unit(unit: Dictionary) -> Texture2D:
	var death_frames: Array[Texture2D] = _unit_death_frames(unit)
	if _unit_death_animation_active(unit) and not death_frames.is_empty():
		return death_frames[_death_frame_index(unit)]
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
	var death_frames: Array[Texture2D] = _load_death_frames_for_art_path(unit_type, art_path)
	if not death_frames.is_empty():
		_death_frames_by_type[unit_type] = death_frames
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

func _load_death_frames_for_art_path(unit_type: String, art_path: String) -> Array[Texture2D]:
	var death_frames: Array[Texture2D] = []
	if art_path.is_empty():
		return death_frames
	var death_sheet: Texture2D = AssetLoader.load_texture_by_stem("%s_death" % art_path.get_basename(), AssetLoader.PNG_FIRST_TEXTURE_EXTENSIONS)
	if death_sheet == null:
		return death_frames
	var death_layout: Dictionary = _unit_death_sheet_layout(unit_type)
	var frame_size := Vector2i(
		int(death_sheet.get_width() / int(death_layout.get("columns", DEATH_SHEET_COLUMNS))),
		int(death_sheet.get_height() / int(death_layout.get("rows", DEATH_SHEET_ROWS)))
	)
	return AssetLoader.build_sprite_sheet_frames(death_sheet, frame_size, _idle_frame_indices(death_layout))

func _unit_idle_sheet_layout(unit_type: String) -> Dictionary:
	var definition: Dictionary = {}
	if unit_type != "player" and not unit_type.is_empty():
		definition = GameData.npc_def(unit_type)
		if definition.is_empty():
			definition = GameData.enemy_def(unit_type)
	return {
		"columns": maxi(1, int(definition.get("idle_sheet_columns", IDLE_SHEET_COLUMNS))),
		"rows": maxi(1, int(definition.get("idle_sheet_rows", IDLE_SHEET_ROWS))),
		"order": str(definition.get("idle_sheet_order", IDLE_SHEET_ORDER_ROW_MAJOR)),
		"ping_pong": bool(definition.get("idle_sheet_ping_pong", false))
	}

func _unit_death_sheet_layout(unit_type: String) -> Dictionary:
	var definition: Dictionary = {}
	if unit_type != "player" and not unit_type.is_empty():
		definition = GameData.npc_def(unit_type)
		if definition.is_empty():
			definition = GameData.enemy_def(unit_type)
	return {
		"columns": maxi(1, int(definition.get("death_sheet_columns", DEATH_SHEET_COLUMNS))),
		"rows": maxi(1, int(definition.get("death_sheet_rows", DEATH_SHEET_ROWS))),
		"order": str(definition.get("death_sheet_order", IDLE_SHEET_ORDER_ROW_MAJOR)),
		"ping_pong": bool(definition.get("death_sheet_ping_pong", false))
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
	else:
		for row: int in range(rows):
			for column: int in range(columns):
				frame_indices.append(row * columns + column)
	if bool(layout.get("ping_pong", false)):
		if frame_indices.size() > 1:
			frame_indices.pop_back()
		var reverse_indices: Array = frame_indices.duplicate()
		reverse_indices.reverse()
		if not reverse_indices.is_empty():
			reverse_indices.pop_front()
		if not reverse_indices.is_empty():
			reverse_indices.pop_back()
		frame_indices.append_array(reverse_indices)
	return frame_indices

func _unit_idle_frames(unit: Dictionary) -> Array[Texture2D]:
	var unit_type: String = str(unit.get("type", ""))
	if not _idle_frames_by_type.has(unit_type):
		return []
	return _idle_frames_by_type[unit_type]

func _unit_death_frames(unit: Dictionary) -> Array[Texture2D]:
	var unit_type: String = str(unit.get("type", ""))
	if not _death_frames_by_type.has(unit_type):
		return []
	return _death_frames_by_type[unit_type]

func _unit_death_frame_count(unit: Dictionary) -> int:
	return _unit_death_frames(unit).size()

func _death_frame_index(unit: Dictionary) -> int:
	var death_frames: Array[Texture2D] = _unit_death_frames(unit)
	if death_frames.is_empty():
		return 0
	return clampi(int(unit.get("death_frame", 0)), 0, death_frames.size() - 1)

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

func _unit_death_frame_seconds(unit: Dictionary) -> float:
	var unit_type: String = str(unit.get("type", ""))
	if unit_type == "player" or unit_type.is_empty():
		return DEATH_FRAME_SECONDS
	var definition: Dictionary = GameData.npc_def(unit_type)
	if definition.is_empty():
		definition = GameData.enemy_def(unit_type)
	return maxf(0.01, float(definition.get("death_frame_seconds", DEATH_FRAME_SECONDS)))

func _scene_prop_idle_frame_index(prop: Dictionary) -> int:
	var idle_frames: Array[Texture2D] = _scene_prop_idle_frames_for_kind(str(prop.get("kind", "")))
	if idle_frames.is_empty():
		return 0
	return int(floor(_idle_elapsed / _scene_prop_idle_frame_seconds(prop))) % idle_frames.size()

func _scene_prop_idle_frame_seconds(prop: Dictionary) -> float:
	return maxf(0.01, float(prop.get("idle_frame_seconds", CAMPFIRE_BONFIRE_IDLE_FRAME_SECONDS)))

func _active_idle_frame_key() -> String:
	var parts: Array[String] = []
	for unit: Dictionary in _visible_units():
		if str(unit.get("role", "")) != "npc" and int(unit.get("hp", 0)) <= 0:
			continue
		if not _unit_idle_animation_active(unit):
			continue
		var actor_key: String = str(unit.get("key", unit.get("id", "")))
		parts.append("u:%s:%d" % [actor_key, _idle_frame_index(unit)])
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		if not _scene_prop_idle_animation_active(prop):
			continue
		parts.append("p:%s:%s:%d" % [str(prop.get("kind", "")), str(prop.get("tile", Vector2i.ZERO)), _scene_prop_idle_frame_index(prop)])
	if _pillar_torch_idle_animation_active():
		parts.append("tl:%d" % _pillar_torch_idle_frame_index("left"))
		parts.append("tr:%d" % _pillar_torch_idle_frame_index("right"))
	return "|".join(parts)

func _unit_idle_animation_active(unit: Dictionary) -> bool:
	if not visible or combat_state.is_empty() or _unit_idle_frames(unit).is_empty():
		return false
	if bool(unit.get("death_animation", false)):
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

func _unit_death_animation_active(unit: Dictionary) -> bool:
	if not visible or combat_state.is_empty() or not bool(unit.get("death_animation", false)):
		return false
	return not _unit_death_frames(unit).is_empty()

func _scene_prop_idle_animation_active(prop: Dictionary) -> bool:
	if not visible or combat_state.is_empty():
		return false
	return not _scene_prop_idle_frames_for_kind(str(prop.get("kind", ""))).is_empty()

func _pillar_torch_idle_animation_active() -> bool:
	if not visible or combat_state.is_empty():
		return false
	if _pillar_torch_idle_frames_for_side("left").is_empty() and _pillar_torch_idle_frames_for_side("right").is_empty():
		return false
	return _grid_has_tile("pillar")

func _grid_has_tile(tile_id: String) -> bool:
	var grid: Array = combat_state.get("grid", [])
	for row_var: Variant in grid:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var row: Array = row_var
		for cell_var: Variant in row:
			if str(cell_var) == tile_id:
				return true
	return false

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
	return world_position_for_unit_origin(unit, unit.get("pos", Vector2i.ZERO))

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

func _death_animation_draw_rect(rect: Rect2, progress: float) -> Rect2:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return rect
	var t: float = clampf(progress, 0.0, 1.0)
	var vertical_scale: float = lerpf(1.0, 0.62, smoothstep(0.34, 1.0, t))
	var horizontal_scale: float = 1.0 + sin(t * PI) * 0.10
	var draw_size := Vector2(rect.size.x * horizontal_scale, rect.size.y * vertical_scale)
	var bottom_center := Vector2(rect.get_center().x, rect.end.y)
	return Rect2(Vector2(bottom_center.x - draw_size.x * 0.5, bottom_center.y - draw_size.y), draw_size)

func _death_animation_tint(unit: Dictionary) -> Color:
	var t: float = clampf(float(unit.get("death_progress", 0.0)), 0.0, 1.0)
	var alpha: float = 1.0 - smoothstep(0.72, 1.0, t)
	return Color(0.78, 0.76, 0.92, clampf(alpha, 0.0, 1.0))

func _unit_shadow_alpha_scale(unit: Dictionary) -> float:
	if not bool(unit.get("death_animation", false)):
		return 1.0
	var t: float = clampf(float(unit.get("death_progress", 0.0)), 0.0, 1.0)
	return 1.0 - smoothstep(0.45, 1.0, t)

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

func world_position_for_unit_origin(unit: Dictionary, origin: Vector2i) -> Vector2:
	var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
	if footprint != Vector2i.ONE:
		var total := Vector2.ZERO
		var count: int = 0
		for y: int in range(maxi(1, footprint.y)):
			for x: int in range(maxi(1, footprint.x)):
				total += _tile_center(origin + Vector2i(x, y))
				count += 1
		if count > 0:
			return total / float(count)
	return _tile_center(origin)

func draw_tile_for_unit_origin(unit: Dictionary, origin: Vector2i) -> Vector2i:
	var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
	return origin + Vector2i(maxi(1, footprint.x) - 1, maxi(1, footprint.y) - 1)

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

func _draw_unit_shadow(unit: Dictionary) -> void:
	if str(unit.get("role", "")) in ["illusion", "illusion_preview"]:
		return
	var shadow_alpha_scale: float = _unit_shadow_alpha_scale(unit)
	if shadow_alpha_scale <= 0.02:
		return
	var texture: Texture2D = _texture_for_unit(unit)
	if texture == null:
		_draw_unit_shadow_fallback(unit)
		return
	var draw_rect: Rect2 = _unit_draw_rect(unit)
	var shadow_polygons: Array[PackedVector2Array] = _unit_shadow_polygons_for_texture(texture)
	if shadow_polygons.is_empty():
		_draw_unit_shadow_fallback(unit)
		return
	var bounds: Rect2 = _unit_shadow_bounds_for_texture(texture)
	var shadow_size: Vector2 = _unit_shadow_draw_size(texture, draw_rect.size, bounds)
	var foot_point: Vector2 = _unit_shadow_foot_point(texture, draw_rect, bounds, str(unit.get("type", "")))
	var shadow_origin: Vector2 = foot_point + Vector2(0.0, _tile_height() * UNIT_SHADOW_FOOT_OFFSET_Y_RATIO)
	var drew_shadow: bool = false
	var shadow_color: Color = UNIT_SHADOW_COLOR
	var soft_color: Color = UNIT_SHADOW_SOFT_COLOR
	shadow_color.a *= shadow_alpha_scale
	soft_color.a *= shadow_alpha_scale
	for local_polygon: PackedVector2Array in shadow_polygons:
		var shadow_polygon: PackedVector2Array = _project_unit_shadow_polygon(local_polygon, shadow_size, shadow_origin)
		if not _polygon_can_draw(shadow_polygon):
			continue
		var soft_polygon: PackedVector2Array = _scaled_polygon(shadow_polygon, UNIT_SHADOW_SOFT_SCALE)
		if _polygon_can_draw(soft_polygon):
			draw_colored_polygon(soft_polygon, soft_color)
		draw_colored_polygon(shadow_polygon, shadow_color)
		drew_shadow = true
	if not drew_shadow:
		_draw_unit_shadow_fallback(unit)

func _draw_unit_shadow_fallback(unit: Dictionary) -> void:
	var shadow_alpha_scale: float = _unit_shadow_alpha_scale(unit)
	if shadow_alpha_scale <= 0.02:
		return
	var draw_rect: Rect2 = _unit_draw_rect(unit)
	var center := Vector2(draw_rect.get_center().x, draw_rect.position.y + draw_rect.size.y - _tile_height() * 0.03)
	var width: float = clampf(draw_rect.size.x * 0.54, _tile_width() * 0.26, _tile_width() * 0.68)
	var height: float = clampf(_tile_height() * 0.34, _tile_height() * 0.20, _tile_height() * 0.44)
	_draw_iso_ground_shadow(center, width, height, width * 0.10, 0.20 * shadow_alpha_scale)

func _unit_shadow_polygons_for_texture(texture: Texture2D) -> Array[PackedVector2Array]:
	return _unit_shadow_data_for_texture(texture).get("polygons", []) as Array[PackedVector2Array]

func _unit_shadow_bounds_for_texture(texture: Texture2D) -> Rect2:
	return _unit_shadow_data_for_texture(texture).get("bounds", Rect2()) as Rect2

func _unit_shadow_data_for_texture(texture: Texture2D) -> Dictionary:
	var local_polygons: Array[PackedVector2Array] = []
	if texture == null:
		return {"polygons": local_polygons, "bounds": Rect2()}
	var cache_key: int = texture.get_instance_id()
	if _unit_shadow_polygon_cache.has(cache_key):
		return _unit_shadow_polygon_cache.get(cache_key, {})
	var data: Dictionary = _unit_shadow_data_for_texture_with_simplify(texture, UNIT_SHADOW_SIMPLIFY_EPSILON)
	var shadow_polygons: Array = data.get("polygons", [])
	var bounds: Rect2 = data.get("bounds", Rect2())
	if shadow_polygons.is_empty() and bounds.size.x > 0.0 and bounds.size.y > 0.0 and UNIT_SHADOW_RETRY_SIMPLIFY_EPSILON < UNIT_SHADOW_SIMPLIFY_EPSILON:
		var retry_data: Dictionary = _unit_shadow_data_for_texture_with_simplify(texture, UNIT_SHADOW_RETRY_SIMPLIFY_EPSILON)
		var retry_polygons: Array = retry_data.get("polygons", [])
		if not retry_polygons.is_empty():
			data = retry_data
	_unit_shadow_polygon_cache[cache_key] = data
	return data

func _unit_shadow_data_for_texture_with_simplify(texture: Texture2D, simplify_epsilon: float) -> Dictionary:
	var local_polygons: Array[PackedVector2Array] = []
	var opaque_polygons: Array[PackedVector2Array] = AssetLoader.build_alpha_polygons(
		texture,
		UNIT_SHADOW_ALPHA_THRESHOLD,
		simplify_epsilon,
		UNIT_SHADOW_MIN_ALPHA_POLYGON_AREA
	)
	var bounds: Rect2 = _polygon_bounds(opaque_polygons)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {"polygons": local_polygons, "bounds": Rect2()}
	var bounds_center_x: float = bounds.position.x + bounds.size.x * 0.5
	var bounds_bottom_y: float = bounds.position.y + bounds.size.y
	for polygon: PackedVector2Array in opaque_polygons:
		var local_polygon := PackedVector2Array()
		for point: Vector2 in polygon:
			local_polygon.append(Vector2(
				(point.x - bounds_center_x) / bounds.size.x,
				(point.y - bounds_bottom_y) / bounds.size.y
		))
		if _polygon_can_draw(local_polygon):
			local_polygons.append(local_polygon)
	var data: Dictionary = {"polygons": local_polygons, "bounds": bounds}
	return data

func _unit_shadow_draw_size(texture: Texture2D, draw_size: Vector2, bounds: Rect2) -> Vector2:
	if texture == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return draw_size
	return Vector2(
		draw_size.x * bounds.size.x / maxf(1.0, float(texture.get_width())),
		draw_size.y * bounds.size.y / maxf(1.0, float(texture.get_height()))
	)

func _unit_shadow_foot_point(texture: Texture2D, draw_rect: Rect2, bounds: Rect2, unit_type: String = "") -> Vector2:
	if texture == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2(draw_rect.get_center().x, draw_rect.end.y)
	var texture_size := Vector2(maxf(1.0, float(texture.get_width())), maxf(1.0, float(texture.get_height())))
	var bottom_ratio: float = _unit_shadow_stable_bottom_ratio(unit_type, texture, bounds)
	return Vector2(
		draw_rect.position.x + (bounds.position.x + bounds.size.x * 0.5) / texture_size.x * draw_rect.size.x,
		draw_rect.position.y + bottom_ratio * draw_rect.size.y
	)

func _unit_shadow_stable_bottom_ratio(unit_type: String, fallback_texture: Texture2D, fallback_bounds: Rect2) -> float:
	if unit_type.is_empty():
		return _unit_shadow_bottom_ratio(fallback_texture, fallback_bounds)
	if _unit_shadow_bottom_ratio_cache.has(unit_type):
		return float(_unit_shadow_bottom_ratio_cache.get(unit_type, _unit_shadow_bottom_ratio(fallback_texture, fallback_bounds)))
	var ratios: Array[float] = []
	for frame_texture: Texture2D in _unit_idle_frames({"type": unit_type}):
		var frame_bounds: Rect2 = _unit_shadow_bounds_for_texture(frame_texture)
		if frame_bounds.size.y > 0.0:
			ratios.append(_unit_shadow_bottom_ratio(frame_texture, frame_bounds))
	if ratios.is_empty() and _unit_textures.has(unit_type):
		var base_texture: Texture2D = _unit_textures.get(unit_type, null)
		var base_bounds: Rect2 = _unit_shadow_bounds_for_texture(base_texture)
		if base_bounds.size.y > 0.0:
			ratios.append(_unit_shadow_bottom_ratio(base_texture, base_bounds))
	if ratios.is_empty():
		ratios.append(_unit_shadow_bottom_ratio(fallback_texture, fallback_bounds))
	ratios.sort()
	var ratio: float = ratios[int(floor(float(ratios.size() - 1) * 0.5))]
	_unit_shadow_bottom_ratio_cache[unit_type] = ratio
	return ratio

func _unit_shadow_bottom_ratio(texture: Texture2D, bounds: Rect2) -> float:
	if texture == null:
		return 1.0
	return clampf((bounds.position.y + bounds.size.y) / maxf(1.0, float(texture.get_height())), 0.0, 1.0)

func _polygon_bounds(polygons: Array[PackedVector2Array]) -> Rect2:
	var found_point: bool = false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for polygon: PackedVector2Array in polygons:
		for point: Vector2 in polygon:
			if not found_point:
				min_point = point
				max_point = point
				found_point = true
				continue
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)
	if not found_point:
		return Rect2()
	return Rect2(min_point, max_point - min_point)

func _project_unit_shadow_polygon(local_polygon: PackedVector2Array, sprite_size: Vector2, shadow_origin: Vector2) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for point: Vector2 in local_polygon:
		var horizontal_px: float = point.x * sprite_size.x * UNIT_SHADOW_SHAPE_SCALE
		var height_px: float = -point.y * sprite_size.y * UNIT_SHADOW_SHAPE_SCALE
		projected.append(shadow_origin + Vector2(
			horizontal_px * UNIT_SHADOW_WIDTH_SCALE + height_px * UNIT_SHADOW_HEIGHT_CAST_X,
			horizontal_px * UNIT_SHADOW_WIDTH_SLOPE_Y + height_px * UNIT_SHADOW_HEIGHT_CAST_Y
		))
	return projected

func _polygon_can_draw(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	return Geometry2D.triangulate_polygon(points).size() >= 3

func _scaled_polygon(points: PackedVector2Array, scale_factor: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point: Vector2 in points:
		center += point
	if points.size() > 0:
		center /= float(points.size())
	center += offset
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(center + (point - center) * scale_factor)
	return scaled

func _draw_rect_ground_shadow(tile: Vector2i, draw_rect: Rect2, width_scale: float, height_scale: float, cast_scale: float) -> void:
	if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return
	var base_center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * 0.34)
	var width: float = maxf(_tile_width() * 0.24, draw_rect.size.x * width_scale)
	var height: float = maxf(_tile_height() * 0.13, _tile_height() * height_scale)
	var cast_offset: Vector2 = SHADOW_LIGHT_VECTOR * _tile_width() * cast_scale
	_draw_iso_ground_shadow(base_center + cast_offset, width * 0.96, height * 0.86, width * 0.28, float(SHADOW_COLOR.a) * 0.38)
	_draw_iso_ground_shadow(base_center, width * 0.48, height * 0.54, width * 0.08, float(SHADOW_COLOR.a) * 0.56)

func _draw_wall_segment_shadow(tile: Vector2i, orientation: String, draw_rect: Rect2) -> void:
	var base_center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * 0.32)
	var width: float = maxf(_tile_width() * 0.38, draw_rect.size.x * 0.82)
	var height: float = _tile_height() * 0.16
	var skew: float = width * (0.16 if orientation == "row" else -0.16)
	var cast_offset: Vector2 = SHADOW_LIGHT_VECTOR * _tile_width() * 0.12
	_draw_iso_ground_shadow(base_center + cast_offset, width, height, skew, float(SHADOW_COLOR.a) * 0.32)
	_draw_iso_ground_shadow(base_center, width * 0.56, height * 0.58, skew * 0.45, float(SHADOW_COLOR.a) * 0.46)

func _draw_iso_ground_shadow(center: Vector2, width: float, height: float, skew: float, alpha: float) -> void:
	if width <= 0.0 or height <= 0.0 or alpha <= 0.0:
		return
	var points := PackedVector2Array()
	for step: int in range(SHADOW_POINT_COUNT):
		var angle: float = TAU * float(step) / float(SHADOW_POINT_COUNT)
		var unit_y: float = sin(angle)
		points.append(center + Vector2(cos(angle) * width * 0.5 + unit_y * skew, unit_y * height * 0.5))
	draw_colored_polygon(points, Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, alpha))

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _ability_tiles() -> Array[Vector2i]:
	return _vector2i_array(presentation.get("ability_tiles", []))

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
	return _intent_rows_for_unit({}, intent)

func _intent_rows_for_unit(unit: Dictionary, intent: Dictionary) -> Array:
	var rows: Array = []
	for action_var: Variant in intent.get("actions", []):
		var action: Dictionary = action_var
		var row: Array = ActionIcons.tokens_for_action(action)
		var support_token: Dictionary = _support_target_token_for_action(unit, action)
		if not support_token.is_empty():
			row.append(support_token)
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
		if action_type == "block" or action_type == "guard_ally":
			return Color("7eb9d5")
		if action_type == "heal_self" or action_type == "heal_ally":
			return Color("90c86d")
	return Color("d8b96f")

func _support_target_token_for_action(unit: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["heal_ally", "guard_ally"]:
		return {}
	var source_enemy: Dictionary = _support_source_enemy(unit)
	if source_enemy.is_empty():
		return {}
	var target_enemy: Dictionary = _support_target_enemy(source_enemy, action)
	var value_text: String = "None"
	var tooltip_text: String = "No valid support target."
	if not target_enemy.is_empty():
		var source_id: int = int(source_enemy.get("id", -1))
		var target_id: int = int(target_enemy.get("id", -1))
		value_text = "-> Self" if target_id == source_id else "-> %s" % _short_enemy_name(target_enemy)
		tooltip_text = "Support target: %s." % str(target_enemy.get("name", "Enemy"))
	return ActionIcons.text_token(value_text, "neutral", tooltip_text)

func _support_source_enemy(unit: Dictionary) -> Dictionary:
	var source_id: int = int(unit.get("id", -1))
	if source_id < 0:
		var key: String = str(unit.get("key", ""))
		if key.begins_with("enemy_"):
			var id_text: String = key.substr(6)
			if id_text.is_valid_int():
				source_id = int(id_text)
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = _support_enemy_unit(enemy_var as Dictionary)
		if int(enemy.get("id", -1)) == source_id:
			return enemy
	return {}

func _support_target_enemy(source_enemy: Dictionary, action: Dictionary) -> Dictionary:
	var allow_self: bool = bool(action.get("allow_self", true))
	var max_range: int = int(action.get("range", 99)) if action.has("range") else 99
	var best_enemy: Dictionary = {}
	var player: Dictionary = combat_state.get("player", {}) as Dictionary
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = _support_enemy_unit(enemy_var as Dictionary)
		if int(candidate.get("hp", 0)) <= 0:
			continue
		if int(candidate.get("id", -1)) == int(source_enemy.get("id", -1)) and not allow_self:
			continue
		if not _support_action_can_affect(candidate, action):
			continue
		if _support_unit_distance_between(source_enemy, candidate) > max_range:
			continue
		if best_enemy.is_empty() or _support_candidate_precedes(str(action.get("type", "")), source_enemy, candidate, best_enemy, player):
			best_enemy = candidate
	return best_enemy

func _support_enemy_unit(enemy: Dictionary) -> Dictionary:
	var unit: Dictionary = enemy.duplicate(true)
	unit["id"] = int(unit.get("id", -1))
	unit["name"] = str(GameData.enemy_def(str(unit.get("type", ""))).get("name", "Enemy"))
	unit["hp"] = int(unit.get("hp", 0))
	unit["max_hp"] = maxi(1, int(unit.get("max_hp", 1)))
	unit["block"] = int(unit.get("block", 0))
	unit["stoneskin"] = int(unit.get("stoneskin", 0))
	if not unit.has("footprint"):
		var footprint_value: Variant = GameData.enemy_def(str(unit.get("type", ""))).get("footprint", [])
		if typeof(footprint_value) == TYPE_ARRAY and (footprint_value as Array).size() >= 2:
			unit["footprint"] = Vector2i(int((footprint_value as Array)[0]), int((footprint_value as Array)[1]))
	var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
	unit["footprint"] = Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	return unit

func _support_action_can_affect(candidate: Dictionary, action: Dictionary) -> bool:
	if int(action.get("amount", 0)) <= 0:
		return false
	match str(action.get("type", "")):
		"heal_ally":
			return int(candidate.get("hp", 0)) < int(candidate.get("max_hp", 1))
		"guard_ally":
			return true
		_:
			return false

func _support_candidate_precedes(action_type: String, source_enemy: Dictionary, candidate: Dictionary, incumbent: Dictionary, player: Dictionary) -> bool:
	match action_type:
		"heal_ally":
			var candidate_missing: int = maxi(0, int(candidate.get("max_hp", 1)) - int(candidate.get("hp", 0)))
			var incumbent_missing: int = maxi(0, int(incumbent.get("max_hp", 1)) - int(incumbent.get("hp", 0)))
			if candidate_missing != incumbent_missing:
				return candidate_missing > incumbent_missing
			var candidate_support_distance: int = _support_unit_distance_between(source_enemy, candidate)
			var incumbent_support_distance: int = _support_unit_distance_between(source_enemy, incumbent)
			if candidate_support_distance != incumbent_support_distance:
				return candidate_support_distance < incumbent_support_distance
			if int(candidate.get("hp", 0)) != int(incumbent.get("hp", 0)):
				return int(candidate.get("hp", 0)) < int(incumbent.get("hp", 0))
		"guard_ally":
			var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
			var candidate_threat_distance: int = _support_unit_distance_to_tile(candidate, player_pos)
			var incumbent_threat_distance: int = _support_unit_distance_to_tile(incumbent, player_pos)
			if candidate_threat_distance != incumbent_threat_distance:
				return candidate_threat_distance < incumbent_threat_distance
			var candidate_defense: int = int(candidate.get("block", 0)) + int(candidate.get("stoneskin", 0))
			var incumbent_defense: int = int(incumbent.get("block", 0)) + int(incumbent.get("stoneskin", 0))
			if candidate_defense != incumbent_defense:
				return candidate_defense < incumbent_defense
			var candidate_ratio: int = int(candidate.get("hp", 0)) * int(incumbent.get("max_hp", 1))
			var incumbent_ratio: int = int(incumbent.get("hp", 0)) * int(candidate.get("max_hp", 1))
			if candidate_ratio != incumbent_ratio:
				return candidate_ratio < incumbent_ratio
			var candidate_guard_distance: int = _support_unit_distance_between(source_enemy, candidate)
			var incumbent_guard_distance: int = _support_unit_distance_between(source_enemy, incumbent)
			if candidate_guard_distance != incumbent_guard_distance:
				return candidate_guard_distance < incumbent_guard_distance
	return int(candidate.get("id", 0)) < int(incumbent.get("id", 0))

func _support_unit_distance_between(first_unit: Dictionary, second_unit: Dictionary) -> int:
	var best_distance: int = 9999
	for first_tile: Vector2i in _unit_footprint_tiles(first_unit):
		for second_tile: Vector2i in _unit_footprint_tiles(second_unit):
			best_distance = mini(best_distance, absi(first_tile.x - second_tile.x) + absi(first_tile.y - second_tile.y))
	return best_distance

func _support_unit_distance_to_tile(unit: Dictionary, tile: Vector2i) -> int:
	var best_distance: int = 9999
	for unit_tile: Vector2i in _unit_footprint_tiles(unit):
		best_distance = mini(best_distance, absi(unit_tile.x - tile.x) + absi(unit_tile.y - tile.y))
	return best_distance

func _short_enemy_name(enemy: Dictionary) -> String:
	var display_name: String = str(enemy.get("name", "Enemy"))
	for prefix: String in ["Tunnel ", "Ash ", "Bone ", "Lightning ", "Grave "]:
		if display_name.begins_with(prefix):
			return display_name.substr(prefix.length())
	return display_name

func _unit_status_badges(unit: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	if int(unit.get("burn", 0)) > 0:
		badges.append({
			"icon": "burn",
			"count": int(unit.get("burn", 0)),
			"fill": STATUS_BURN,
			"border": STATUS_BURN.lightened(0.24)
		})
	if int(unit.get("bleed", 0)) > 0:
		badges.append({
			"icon": "bleed",
			"count": int(unit.get("bleed", 0)),
			"fill": STATUS_BLEED,
			"border": STATUS_BLEED.lightened(0.22)
		})
	if int(unit.get("expose", 0)) > 0:
		badges.append({
			"icon": "expose",
			"count": int(unit.get("expose", 0)),
			"fill": STATUS_EXPOSE,
			"border": STATUS_EXPOSE.lightened(0.18)
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
	if bool(unit.get("immobilize", false)):
		badges.append({
			"icon": "immobilize",
			"count": 0,
			"fill": STATUS_IMMOBILIZE,
			"border": STATUS_IMMOBILIZE.lightened(0.20)
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
		"bleed": int(player.get("bleed", 0)),
		"expose": int(player.get("expose", 0)),
		"freeze": maxi(int(player.get("freeze", 0)), 1 if bool(restrictions.get("frozen", false)) else 0),
		"shock": maxi(int(player.get("shock", 0)), 1 if bool(restrictions.get("shocked", false)) else 0),
		"immobilize": bool(player.get("immobilize", false)) or bool(restrictions.get("immobilized", false))
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
	var is_hot: bool = exit_tiles.has(_hover_tile) or move_tiles.has(_hover_tile) or attack_tiles.has(_hover_tile) or _ability_tiles().has(_hover_tile)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_hot else Control.CURSOR_ARROW

func _draw_trap_blast_effects(trap_effects: Array, progress: float) -> void:
	for trap_var: Variant in trap_effects:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		var element_id: String = str(trap.get("element", ElementData.NONE))
		var texture: Texture2D = _trap_blast_textures.get(element_id, null)
		if texture == null:
			continue
		for tile: Vector2i in _trap_blast_tiles(trap):
			_draw_trap_blast_tile(tile, texture, progress)

func _trap_blast_tiles(trap: Dictionary) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),
		Vector2i(-1, -1)
	]
	var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
	var tiles: Array[Vector2i] = []
	var grid: Array = combat_state.get("grid", [])
	for offset: Vector2i in offsets:
		var tile: Vector2i = trap_pos + offset
		if not _tile_in_grid(grid, tile):
			continue
		if not _tile_drawn_as_floor(grid, tile):
			continue
		tiles.append(tile)
	return tiles

func _draw_trap_blast_tile(tile: Vector2i, texture: Texture2D, progress: float) -> void:
	var t: float = clampf(progress, 0.0, 1.0)
	var pulse: float = sin(t * PI)
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0:
		return
	var draw_width: float = _tile_width() * TRAP_BLAST_DRAW_WIDTH_SCALE * (0.88 + 0.12 * pulse)
	var draw_height: float = _tile_height() * TRAP_BLAST_DRAW_HEIGHT_SCALE * (0.88 + 0.12 * pulse)
	var center: Vector2 = _tile_center(tile)
	var bottom_y: float = center.y + _tile_height() * TRAP_BLAST_BASELINE_SCALE
	var rect := Rect2(
		Vector2(center.x - draw_width * 0.5, bottom_y - draw_height),
		Vector2(draw_width, draw_height)
	)
	var alpha: float = 0.18 + 0.82 * pulse
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))

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

func _trap_draw_rect(tile: Vector2i) -> Rect2:
	var tile_width: float = _tile_width()
	var draw_size := Vector2(tile_width * TRAP_DRAW_WIDTH_SCALE, _tile_height() * TRAP_DRAW_HEIGHT_SCALE)
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * TRAP_DRAW_Y_OFFSET_SCALE)
	return Rect2(center - draw_size * 0.5, draw_size)

func _trap_tooltip_text(trap: Dictionary) -> String:
	var lines: PackedStringArray = ["%s Trap" % ElementData.name(str(trap.get("element", ElementData.NONE)))]
	lines.append("%d damage to adjacent tiles" % int(trap.get("damage", 0)))
	if int(trap.get("burn", 0)) > 0:
		lines.append("Burn %d" % int(trap.get("burn", 0)))
	if int(trap.get("freeze", 0)) > 0:
		lines.append("Freeze")
	if int(trap.get("shock", 0)) > 0:
		lines.append("Shock")
	if bool(trap.get("immobilize", false)):
		lines.append("Immobilize")
	if int(trap.get("poison", 0)) > 0:
		lines.append("Poison %d" % int(trap.get("poison", 0)))
	return "\n".join(lines)
