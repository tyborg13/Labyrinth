extends Control
class_name CombatBoardView

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ElementalIntensityRules = preload("res://scripts/elemental_intensity_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")

signal tile_clicked(tile: Vector2i)
signal tile_hovered(tile: Vector2i)
signal tile_dragged(start_tile: Vector2i, current_tile: Vector2i)
signal tile_drag_released(start_tile: Vector2i, current_tile: Vector2i)
signal cancel_requested
signal navigation_changed

const GRID_OUTLINE: Color = Color("1f1713")
const MOVE_HIGHLIGHT: Color = Color(0.28, 0.75, 0.86, 0.20)
const ATTACK_HIGHLIGHT: Color = Color(0.96, 0.40, 0.25, 0.20)
const ABILITY_HIGHLIGHT: Color = Color(0.30, 0.78, 0.35, 0.22)
const HOVER_HIGHLIGHT: Color = Color(1.0, 0.96, 0.82, 0.22)
const SELECT_HIGHLIGHT: Color = Color(0.97, 0.81, 0.43, 0.36)
const EXIT_HIGHLIGHT: Color = Color(0.95, 0.78, 0.31, 0.34)
const FOCUS_HIGHLIGHT: Color = Color(0.99, 0.92, 0.57, 0.24)
const MOVE_PATH_COLOR: Color = Color("80e4f2")
const MOVE_PATH_SHAFT_TILE_HEIGHT_RATIO: float = 0.333
const MOVE_PATH_HEAD_WIDTH_TILE_RATIO: float = 0.405
const MOVE_PATH_HEAD_TIP_REACH_TILE_RATIO: float = 0.138
const MOVE_PATH_HEAD_TAIL_REACH_TILE_RATIO: float = 0.285
const MOVE_PATH_SHADOW_OFFSET_TILE_RATIO: float = 0.038
const MOVE_PATH_OUTLINE_WIDTH_RATIO: float = 1.12
const MOVE_PATH_GLOW_WIDTH_RATIO: float = 1.24
const MOVE_PATH_GRADIENT_DARKEN: float = 0.34
const MOVE_PATH_GRADIENT_LIGHTEN: float = 0.30
const MOVE_PATH_GRADIENT_LAYER_COUNT: int = 16
const MOVE_PATH_BODY_ALPHA: float = 0.86
const MOVE_PATH_GRADIENT_BASE_ALPHA: float = 0.70
const MOVE_PATH_GRADIENT_LAYER_ALPHA: float = 0.055
const MOVE_PATH_GRADIENT_DISC_SEGMENTS: int = 24
const MOVE_PATH_LIGHT_DIRECTION: Vector2 = Vector2(-0.42, -0.91)
const MOVE_RISK_CHIP_FONT_SIZE: int = 10
const MOVE_RISK_CHIP_HEIGHT: float = 18.0
const MOVE_RISK_CHIP_GAP: float = 3.0
const IMPACT_FLASH_COLOR: Color = Color(1.0, 0.22, 0.15, 0.72)
const PLAYER_FOCUS_COLOR: Color = Color("f1d18b")
const ENEMY_FOCUS_COLOR: Color = Color("f08c53")
const FLOATING_TEXT_RIGHT_OFFSET: float = 18.0
const PLAYER_BAR_FILL: Color = Color("4f9f8c")
const ILLUSION_BAR_FILL: Color = Color("7bd8ee")
const ENEMY_BAR_FILL: Color = Color("8f3038")
const HEALTH_BAR_STYLE_PLAIN: StringName = &"plain"
const HEALTH_BAR_STYLE_LIGHT: StringName = &"light"
const HEALTH_BAR_STYLE_UMBRA: StringName = &"umbra"
const PLAYER_HEALTH_FRAME_PATH: String = "res://assets/art/ui/health_bars/player_lantern_frame_v1.png"
const ENEMY_HEALTH_FRAME_PATH: String = "res://assets/art/ui/health_bars/enemy_umbra_frame_v1.png"
const PLAYER_HEALTH_CONTENT_INSETS: Vector4 = Vector4(0.124, 0.326, 0.087, 0.275)
const ENEMY_HEALTH_CONTENT_INSETS: Vector4 = Vector4(0.161, 0.286, 0.152, 0.301)
const TERRAIN_BAR_FILL: Color = Color("d9b84f")
const STATUS_BURN: Color = Color("f28a42")
const STATUS_BLEED: Color = Color("b84646")
const STATUS_EXPOSE: Color = Color("d9b36a")
const STATUS_FREEZE: Color = Color("7dd4ff")
const STATUS_SHOCK: Color = Color("f3d762")
const STATUS_IMMOBILIZE: Color = Color("b8c48f")
const STATUS_POISON: Color = Color("86bf63")
const PLAYER_HEALTH_BAR_SIZE: Vector2 = Vector2(128.0, 28.0)
const ENEMY_HEALTH_BAR_SIZE: Vector2 = Vector2(124.0, 30.0)
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
const ENEMY_HUD_ACTOR_CLEARANCE: float = 4.0
const ENEMY_HUD_SIDE_GAP: float = 4.0
const ENEMY_HUD_REPOSITION_OVERLAP_AREA: float = 1.0
const ENEMY_HUD_SIDE_SWITCH_SCORE_MARGIN: float = 120000.0
const ENEMY_HUD_SIDE_STICKY_OVERLAP_AREA: float = 1.0
const ENEMY_HUD_OFFSET_X_STEPS := [0.0, -24.0, 24.0, -48.0, 48.0, -72.0, 72.0]
const ENEMY_HUD_OFFSET_Y_STEPS := [0.0, -18.0, 18.0, -36.0, 36.0, -54.0, 54.0, -72.0, 72.0]
const FOREGROUND_OBSTRUCTION_TINT: Color = Color(1.0, 1.0, 1.0, 0.54)
const FOREGROUND_OBSTRUCTION_COVERAGE_THRESHOLD: float = 0.25
const LOOT_DRAW_TILE_WIDTH_SCALE: float = 0.34
const EQUIPMENT_LOOT_TILE_WIDTH_SCALE: float = 0.56
const EQUIPMENT_LOOT_FLOAT_BASELINE_SCALE: float = -0.02
const IDLE_FRAME_SECONDS: float = 0.10
const IDLE_SHEET_COLUMNS: int = 4
const IDLE_SHEET_ROWS: int = 2
const DEATH_FRAME_SECONDS: float = 0.065
const DEATH_SHEET_COLUMNS: int = 4
const DEATH_SHEET_ROWS: int = 4
const TERRAIN_DESTRUCTION_FRAME_SECONDS: float = 0.065
const TERRAIN_DESTRUCTION_SHEET_LAYOUTS := {
	"wooden_box": {
		"path": "res://assets/art/tiles/wooden_box_destroy.png",
		"columns": 4,
		"rows": 4,
		"order": "row_major",
		"ping_pong": false,
		"frame_seconds": 0.065
	},
	"wooden_crate": {
		"path": "res://assets/art/tiles/wooden_crate_destroy.png",
		"columns": 4,
		"rows": 4,
		"order": "row_major",
		"ping_pong": false,
		"frame_seconds": 0.065
	}
}
const IDLE_SHEET_ORDER_ROW_MAJOR: String = "row_major"
const IDLE_SHEET_ORDER_COLUMN_MAJOR: String = "column_major"
const OUTER_WALL_RENDERING_ENABLED: bool = false
const TILE_DEPTH_HEIGHT_RATIO: float = 0.30
const TILE_DEPTH_LEFT_FACE: Color = Color("241914")
const TILE_DEPTH_RIGHT_FACE: Color = Color("33231b")
const TILE_DEPTH_EDGE: Color = Color("130e0c")
const BOARD_SIDE_MARGIN: float = 36.0
const BOARD_VERTICAL_MARGIN: float = 8.0
const BOARD_TOP_CLEARANCE_SCALE: float = 0.82
const BOARD_BOTTOM_CLEARANCE_SCALE: float = 0.34
const BOARD_COMBAT_VERTICAL_BIAS: float = 1.20
const BOARD_ROOM_VERTICAL_BIAS: float = 0.50
const BOARD_MAX_TILE_WIDTH: float = 184.0
const BOARD_MIN_NAVIGATION_ZOOM: float = 0.80
const BOARD_MAX_NAVIGATION_ZOOM: float = 1.40
const BOARD_ZOOM_STEP: float = 1.10
const BOARD_DEFAULT_NAVIGATION_ZOOM: float = 1.26
const BOARD_COMBAT_COMPACT_DEFAULT_NAVIGATION_ZOOM: float = 1.04
const BOARD_COMBAT_EXPANDED_DEFAULT_NAVIGATION_ZOOM: float = 1.24
const BOARD_REACH_EXIT_DEFAULT_NAVIGATION_ZOOM_SCALE: float = 0.97
const BOARD_ROOM_COMPACT_DEFAULT_NAVIGATION_ZOOM: float = 1.22
const BOARD_ROOM_EXPANDED_DEFAULT_NAVIGATION_ZOOM: float = 1.36
const BOARD_COMPACT_VIEWPORT_HEIGHT: float = 1080.0
const BOARD_EXPANDED_VIEWPORT_HEIGHT: float = 1227.0
const BOARD_PAN_DRAG_THRESHOLD: float = 8.0
const BOARD_PAN_OVERSCROLL_FRACTION: float = 0.08
const BOARD_PAN_OVERSCROLL_MAX: float = 72.0
const BOARD_TRACKPAD_PAN_SCALE: float = 18.0
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
const STONE_FLOOR_VARIANT_PATHS: PackedStringArray = [
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
const RENDER_LAYER_AMBIENT: String = "ambient"
const RENDER_LAYER_OVERLAYS: String = "overlays"
const RENDER_LAYER_GROUND: String = "ground"
const RENDER_LAYER_PATH: String = "path"
const RENDER_LAYER_WORLD: String = "world"
const RENDER_LAYER_SCENE_TILE: String = "scene_tile"
const RENDER_LAYER_FOREGROUND: String = "foreground"
const RENDER_LAYER_HUD: String = "hud"
const RENDER_LAYER_EFFECTS: String = "effects"
const ELEMENTAL_FOREGROUND_PARTICLE_COUNT: int = 15
const HUD_LAYOUT_CACHE_LIMIT: int = 32
const UMBRA_RETURN_STAGGER_SECONDS: float = 0.52
const UMBRA_RETURN_FADE_SECONDS: float = 0.46
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
const FIREBALL_TRAVEL_SHEET_PATH: String = "res://assets/art/effects/fireball_travel_sheet.png"
const FIREBALL_TRAVEL_SHEET_COLUMNS: int = 8
const FIREBALL_TRAVEL_SHEET_ROWS: int = 1
const FIREBALL_WAKE_SHEET_PATH: String = "res://assets/art/effects/fireball_wake_sheet.png"
const FIREBALL_WAKE_SHEET_COLUMNS: int = 4
const FIREBALL_WAKE_SHEET_ROWS: int = 2
const FIREBALL_IMPACT_SHEET_PATH: String = "res://assets/art/effects/fireball_impact_sheet.png"
const FIREBALL_IMPACT_SHEET_COLUMNS: int = 4
const FIREBALL_IMPACT_SHEET_ROWS: int = 2
const FIREBALL_TRAVEL_CYCLES: float = 1.35
const FIREBALL_WAKE_CYCLES: float = 1.72
const FIREBALL_AFTERIMAGE_COUNT: int = 3
const FIREBALL_AFTERIMAGE_SPACING: float = 0.048
const FIREBALL_TRAVEL_EMBER_COUNT: int = 13
const FIREBALL_IMPACT_EMBER_COUNT: int = 27
const FIREBALL_TRAVEL_DRAW_TILE_SCALE: float = 1.08
const FIREBALL_IMPACT_DRAW_TILE_SCALE: float = 1.74
const FIREBALL_TRAVEL_MIN_SIZE: float = 82.0
const FIREBALL_TRAVEL_MAX_SIZE: float = 118.0
const FIREBALL_IMPACT_MIN_SIZE: float = 124.0
const FIREBALL_IMPACT_MAX_SIZE: float = 198.0
const FIREBALL_FRAME_CORE_ANCHOR: Vector2 = Vector2(0.81, 0.50)
const FIREBALL_WAKE_CORE_ANCHOR: Vector2 = Vector2(0.86, 0.50)
const EARTH_SPIKE_TRAVEL_SHEET_PATH: String = "res://assets/art/effects/earth_spike_travel_sheet_v2.png"
const EARTH_SPIKE_IMPACT_SHEET_PATH: String = "res://assets/art/effects/earth_spike_impact_sheet_v2.png"
const EARTH_GROUND_LAYER_SHEET_PATH: String = "res://assets/art/effects/earth_ground_layer_sheet.png"
const AIR_GUST_TRAVEL_SHEET_PATH: String = "res://assets/art/effects/air_gust_travel_sheet.png"
const AIR_GUST_IMPACT_SHEET_PATH: String = "res://assets/art/effects/air_gust_impact_sheet.png"
const AIR_ENVELOPE_LAYER_SHEET_PATH: String = "res://assets/art/effects/air_envelope_layer_sheet.png"
const LIGHTNING_BOLT_TRAVEL_SHEET_PATH: String = "res://assets/art/effects/lightning_bolt_travel_sheet.png"
const LIGHTNING_BOLT_IMPACT_SHEET_PATH: String = "res://assets/art/effects/lightning_bolt_impact_sheet.png"
const LIGHTNING_ENVELOPE_LAYER_SHEET_PATH: String = "res://assets/art/effects/lightning_envelope_layer_sheet.png"
const ICE_SHARD_TRAVEL_SHEET_PATH: String = "res://assets/art/effects/ice_shard_travel_sheet_v2.png"
const ICE_ICICLE_IMPACT_SHEET_PATH: String = "res://assets/art/effects/ice_icicle_impact_sheet_v2.png"
const ICE_GROUND_LAYER_SHEET_PATH: String = "res://assets/art/effects/ice_ground_layer_sheet.png"
const ELEMENTAL_FIRE_PERFORMANCE_SHEET_PATH: String = "res://assets/art/effects/elemental_fire_performance_sheet_v3.png"
const ELEMENTAL_EARTH_PERFORMANCE_SHEET_PATH: String = "res://assets/art/effects/elemental_earth_performance_sheet_v3.png"
const ELEMENTAL_AIR_PERFORMANCE_SHEET_PATH: String = "res://assets/art/effects/elemental_air_performance_sheet_v3.png"
const ELEMENTAL_LIGHTNING_PERFORMANCE_SHEET_PATH: String = "res://assets/art/effects/elemental_lightning_performance_sheet_v4.png"
const ELEMENTAL_ICE_PERFORMANCE_SHEET_PATH: String = "res://assets/art/effects/elemental_ice_performance_sheet_v3.png"
const ELEMENTAL_FIRE_PERFORMANCE_BLOOM_SHEET_PATH: String = "res://assets/art/effects/elemental_fire_performance_bloom_sheet_v4.png"
const ELEMENTAL_EARTH_PERFORMANCE_BLOOM_SHEET_PATH: String = "res://assets/art/effects/elemental_earth_performance_bloom_sheet_v4.png"
const ELEMENTAL_AIR_PERFORMANCE_BLOOM_SHEET_PATH: String = "res://assets/art/effects/elemental_air_performance_bloom_sheet_v4.png"
const ELEMENTAL_LIGHTNING_PERFORMANCE_BLOOM_SHEET_PATH: String = "res://assets/art/effects/elemental_lightning_performance_bloom_sheet_v4.png"
const ELEMENTAL_ICE_PERFORMANCE_BLOOM_SHEET_PATH: String = "res://assets/art/effects/elemental_ice_performance_bloom_sheet_v4.png"
const ELEMENTAL_ATTACK_SHEET_COLUMNS: int = 4
const ELEMENTAL_ATTACK_SHEET_ROWS: int = 2
const ELEMENTAL_PERFORMANCE_MIN_SIZE: float = 218.0
const ELEMENTAL_PERFORMANCE_MAX_SIZE: float = 342.0
const ELEMENTAL_COMPACT_DETONATION_SCALE: float = 0.50
const TRAP_ELEMENTAL_DETONATION_SCALE: float = 1.15
const ELEMENTAL_BACKGROUND_VOLUME_COUNT: int = 14
const EARTH_PATH_SPIKE_COUNT: int = 6
const EARTH_PATH_SPIKE_SIZE_SCALE: float = 0.68
const EARTH_IMPACT_SIZE_SCALE: float = 2.08
const AIR_GUST_TRAVEL_SIZE_SCALE: float = 1.18
const AIR_GUST_IMPACT_SIZE_SCALE: float = 2.62
const LIGHTNING_TRAVEL_SIZE_SCALE: float = 1.22
const LIGHTNING_IMPACT_SIZE_SCALE: float = 2.76
const ICE_TRAVEL_SIZE_SCALE: float = 1.16
const ICE_IMPACT_SIZE_SCALE: float = 2.04
const ELEMENTAL_TRAVEL_AFTERIMAGE_COUNT: int = 3
const ELEMENTAL_TRAVEL_MOTE_COUNT: int = 12
const ELEMENTAL_IMPACT_MOTE_COUNT: int = 18
const PROJECTILE_DRAW_TILE_SCALE: float = 0.34
const PROJECTILE_DRAW_MIN_SIZE: float = 30.0
const PROJECTILE_DRAW_MAX_SIZE: float = 48.0
const PROJECTILE_SPRITE_PATH_ANCHOR_X: float = 0.78
const PROJECTILE_PREVIEW_LOOP_SECONDS: float = 2.4
const LETHAL_DEATH_MARK_EFFECT_PATH: String = "res://assets/art/effects/lethal_death_mark.png"
const LETHAL_DEATH_MARK_PULSE_SECONDS: float = 1.4
const LETHAL_DEATH_MARK_MIN_SCALE: float = 0.92
const LETHAL_DEATH_MARK_MAX_SCALE: float = 1.08
const LETHAL_DEATH_MARK_MIN_ALPHA: float = 0.80
const LETHAL_DEATH_MARK_MAX_ALPHA: float = 0.98
const BLINK_RIFT_PREVIEW_TEXTURE_PATH: String = "res://assets/art/effects/blink_rift_preview.png"
const DEFENSE_HEAL_CASTS_PATH: String = "res://assets/art/effects/defense_heal_casts.png"
const DEFENSE_HEAL_CASTS_COLUMNS: int = 4
const DEFENSE_HEAL_CASTS_ROWS: int = 3
const DEFENSE_HEAL_CASTS_FRAMES_PER_KIND: int = 4
const TRAP_DRAW_WIDTH_SCALE: float = 1.0
# Trap sources are 122x80 while the isometric tile rectangle is 2:1. Preserve
# the source aspect instead of vertically compressing the pressure plates.
const TRAP_DRAW_HEIGHT_SCALE: float = 160.0 / 122.0
const TRAP_DRAW_Y_OFFSET_SCALE: float = 0.0
const TRAP_ANIMATION_SHEET_COLUMNS: int = 4
const TRAP_ANIMATION_SHEET_ROWS: int = 4
const TRAP_IDLE_FRAME_SECONDS: float = 0.12
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
var _navigation_zoom: float = BOARD_DEFAULT_NAVIGATION_ZOOM
var _navigation_pan: Vector2 = Vector2.ZERO
var _navigation_uses_default_zoom: bool = true
var _navigation_content_signature: String = ""
var _navigation_pointer_button: int = MOUSE_BUTTON_NONE
var _navigation_pointer_start: Vector2 = Vector2.ZERO
var _navigation_pan_start: Vector2 = Vector2.ZERO
var _navigation_pan_active: bool = false
var _last_pointer_position: Vector2 = Vector2.ZERO
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
var _ambient_hash_cache: Dictionary = {}
var _ambient_hash01_cache: Dictionary = {}
var _ambient_hash_cache_room_key: String = ""
var _ambient_particle_batch_enabled: bool = true
var _ambient_batch_active: bool = false
var _ambient_batch_vertices: PackedVector3Array = PackedVector3Array()
var _ambient_batch_uvs: PackedVector2Array = PackedVector2Array()
var _ambient_batch_colors: PackedColorArray = PackedColorArray()
var _ambient_batch_indices: PackedInt32Array = PackedInt32Array()
var _ambient_combined_atlas: Texture2D = null
var _ambient_combined_atlas_regions: Dictionary = {}
var _ambient_combined_atlas_element_id: String = ""
var _ambient_batch_mesh: ArrayMesh = null
var _loot_textures: Dictionary = {}
var _terrain_textures: Dictionary = {}
var _terrain_destruction_frames_by_kind: Dictionary = {}
var _unit_textures: Dictionary = {}
var _unit_assets_loaded: Dictionary = {}
var _element_textures: Dictionary = {}
var _trap_textures: Dictionary = {}
var _trap_idle_frames: Dictionary = {}
var _trap_activation_frames: Dictionary = {}
var _door_icon_textures: Dictionary = {}
var _keyword_icon_textures: Dictionary = {}
var _health_bar_frame_textures: Dictionary = {}
var _unit_shadow_polygon_cache: Dictionary = {}
var _unit_shadow_bottom_ratio_cache: Dictionary = {}
var _unit_shadow_draw_geometry_cache: Dictionary = {}
var _unit_shadow_draw_mesh_cache: Dictionary = {}
var _door_opening_frames: Array[Texture2D] = []
var _door_opening_flipped_frames: Array[Texture2D] = []
var _tooltip_regions: Array[Dictionary] = []
var equipment_tooltip_builder: Callable
var _idle_frames_by_type: Dictionary = {}
var _death_frames_by_type: Dictionary = {}
var _idle_animating: bool = false
var _idle_elapsed: float = 0.0
var _idle_frame_key: String = ""
var _board_layout_cache_valid: bool = false
var _board_layout_content_cache_valid: bool = false
var _board_layout_cache_size: Vector2 = Vector2(-1.0, -1.0)
var _board_layout_cache_tiles: Array[Vector2i] = []
var _board_layout_cache_extents: Dictionary = {}
var _board_layout_cache_tile_width: float = 90.0
var _board_layout_cache_origin: Vector2 = Vector2.ZERO
var _board_layout_cache_visual_top_offset: float = 0.0
var _board_layout_cache_tile_centers: Dictionary = {}
var _board_layout_cache_tile_polygons: Dictionary = {}
var _board_layout_signature: String = ""
var _board_visual_framing_signature: String = ""
var _floor_variant_signature: String = ""
var _moss_signature: String = ""
var _continuous_presentation_elapsed: float = 0.0
var _last_processed_render_frame: int = -1
var _explicit_effects_redraw_process_frame: int = -1
var _explicit_impact_redraw_process_frame: int = -1
var _submission_cache_valid: bool = false
var _damage_preview_cache: Dictionary = {}
var _visible_units_cache: Array[Dictionary] = []
var _scene_props_by_tile: Dictionary = {}
var _terrain_by_tile: Dictionary = {}
var _loot_by_tile: Dictionary = {}
var _traps_by_tile: Dictionary = {}
var _campfire_scene_props_cache: Array = []
var _grid_tile_ids_cache: Dictionary = {}
var _ability_tiles_cache: Array[Vector2i] = []
var _move_tiles_lookup_cache: Dictionary = {}
var _attack_tiles_lookup_cache: Dictionary = {}
var _focus_tiles_lookup_cache: Dictionary = {}
var _objective_exit_tiles_lookup_cache: Dictionary = {}
var _projected_attack_tiles_lookup_cache: Dictionary = {}
var _ability_tiles_lookup_cache: Dictionary = {}
var _ambient_element_id_cache: String = ElementData.NONE
var _equipment_pickup_beacon_cache: bool = false
var _preview_unit_pulse_cache: bool = false
var _hud_health_rects_cache: Dictionary = {}
var _hud_health_rects_source_snapshot: Dictionary = {}
var _hud_layout_entries_cache: Array = []
var _hud_layout_cache_by_signature: Dictionary = {}
var _hud_layout_cache_order: Array = []
var _enemy_hud_side_by_actor: Dictionary = {}
var _foreground_obstruction_candidates_cache: Array = []
var _foreground_obstruction_candidates_source_snapshot: Dictionary = {}
var _texture_used_rect_cache: Dictionary = {}
var _unit_shadow_prewarm_urgent_queue: Array[Texture2D] = []
var _unit_shadow_prewarm_background_queue: Array[Texture2D] = []
var _unit_shadow_prewarm_queued_ids: Dictionary = {}
var _unit_shadow_prewarm_thread: Thread = null
var _unit_shadow_prewarm_active_texture: Texture2D = null
var _submission_cache_source_snapshot: Dictionary = {}
var _submission_cache_initialized: bool = false
var _submission_cache_combat_changed: bool = false
var _is_dynamic_render_layer: bool = false
var _render_layer_kind: String = ""
var _render_layer_tile: Vector2i = Vector2i(-1, -1)
var _ambient_render_layer: Control = null
var _overlay_render_layer: Control = null
var _ground_render_layer: Control = null
var _path_render_layer: Control = null
var _dynamic_render_layer: Control = null
var _scene_render_layers_by_tile: Dictionary = {}
var _scene_render_layers: Array = []
var _foreground_render_layer: Control = null
var _hud_render_layer: Control = null
var _effects_render_layer: Control = null
var _foreground_obstruction_entries_cache: Array[Dictionary]
var _static_draw_count: int = 0
var _dynamic_draw_count: int = 0
var _static_draw_total_usec: int = 0
var _static_draw_max_usec: int = 0
var _dynamic_draw_total_usec: int = 0
var _dynamic_draw_max_usec: int = 0
var _render_section_total_usec: Dictionary = {}
var _render_section_max_usec: Dictionary = {}
var _unit_shadow_sync_miss_metrics: Dictionary = {}
var _submission_performance_instrumentation_enabled: bool = false
var _submission_performance_total_usec: Dictionary = {}
var _submission_performance_counts: Dictionary = {}
var _umbra_return_start_by_tile: Dictionary = {}
var _board_layout_content_rebuild_count: int = 0

func _ready() -> void:
	if _is_dynamic_render_layer:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_process(false)
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The board's input rect remains stage-sized, but its art may flow beneath the
	# surrounding HUD. The scene keeps fixed HUD controls above this canvas.
	clip_contents = false
	custom_minimum_size = Vector2(960.0, 680.0)
	set_process(true)
	resized.connect(_on_board_resized)
	_load_assets(false)
	_create_dynamic_render_layer()

func _exit_tree() -> void:
	if _unit_shadow_prewarm_thread != null and _unit_shadow_prewarm_thread.is_started():
		_unit_shadow_prewarm_thread.wait_to_finish()
	_unit_shadow_prewarm_thread = null
	_unit_shadow_prewarm_active_texture = null

func _on_board_resized() -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer) or combat_state.is_empty():
		return
	_invalidate_board_layout_cache(false)
	_foreground_obstruction_entries_cache = _foreground_obstruction_entries(_visible_units())
	_rebuild_hud_health_rects_cache()
	_sync_dynamic_render_state(false)
	for layer: Control in _retained_render_layers():
		layer.call("_invalidate_board_layout_cache", false)
	queue_redraw()
	_queue_dynamic_redraw()

func _create_dynamic_render_layer() -> void:
	if _dynamic_render_layer != null and is_instance_valid(_dynamic_render_layer):
		return
	_ambient_render_layer = _create_retained_render_layer("AmbientRenderLayer", RENDER_LAYER_AMBIENT)
	_overlay_render_layer = _create_retained_render_layer("OverlayRenderLayer", RENDER_LAYER_OVERLAYS)
	_ground_render_layer = _create_retained_render_layer("GroundRenderLayer", RENDER_LAYER_GROUND)
	_path_render_layer = _create_retained_render_layer("PathRenderLayer", RENDER_LAYER_PATH)
	_dynamic_render_layer = _create_retained_render_layer("DynamicRenderLayer", RENDER_LAYER_WORLD)
	_foreground_render_layer = _create_retained_render_layer("ForegroundRenderLayer", RENDER_LAYER_FOREGROUND)
	_effects_render_layer = _create_retained_render_layer("EffectsRenderLayer", RENDER_LAYER_EFFECTS)
	_hud_render_layer = _create_retained_render_layer("HudRenderLayer", RENDER_LAYER_HUD)
	_sync_dynamic_render_assets()
	_sync_dynamic_render_state(true)
	_queue_dynamic_redraw()

func _create_retained_render_layer(layer_name: String, layer_kind: String) -> Control:
	var layer: Control = get_script().new() as Control
	layer.name = layer_name
	layer.set("_is_dynamic_render_layer", true)
	layer.set("_render_layer_kind", layer_kind)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.focus_mode = Control.FOCUS_NONE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	return layer

func _retained_render_layers() -> Array:
	var layers: Array = []
	for layer: Control in [_ambient_render_layer, _overlay_render_layer, _ground_render_layer, _path_render_layer, _dynamic_render_layer]:
		if layer != null and is_instance_valid(layer):
			layers.append(layer)
	for layer_var: Variant in _scene_render_layers:
		var layer: Control = layer_var as Control
		if layer != null and is_instance_valid(layer):
			layers.append(layer)
	for layer: Control in [_foreground_render_layer, _effects_render_layer, _hud_render_layer]:
		if layer != null and is_instance_valid(layer):
			layers.append(layer)
	return layers

func _sync_scene_render_layers() -> void:
	var desired_tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var desired_lookup: Dictionary = {}
	for tile: Vector2i in desired_tiles:
		desired_lookup[tile] = true
	for tile_var: Variant in _scene_render_layers_by_tile.keys():
		if desired_lookup.has(tile_var):
			continue
		var stale_layer: Control = _scene_render_layers_by_tile.get(tile_var, null) as Control
		_scene_render_layers_by_tile.erase(tile_var)
		if stale_layer != null and is_instance_valid(stale_layer):
			remove_child(stale_layer)
			stale_layer.queue_free()
	_scene_render_layers.clear()
	for tile: Vector2i in desired_tiles:
		var layer: Control = _scene_render_layers_by_tile.get(tile, null) as Control
		if layer == null or not is_instance_valid(layer):
			layer = _create_retained_render_layer("SceneTile_%d_%d" % [tile.x, tile.y], RENDER_LAYER_SCENE_TILE)
			layer.set("_render_layer_tile", tile)
			_scene_render_layers_by_tile[tile] = layer
		_scene_render_layers.append(layer)
	var insertion_index: int = _dynamic_render_layer.get_index() + 1
	for layer_var: Variant in _scene_render_layers:
		move_child(layer_var as Control, insertion_index)
		insertion_index += 1

func _sync_dynamic_render_assets() -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		return
	for layer: Control in _retained_render_layers():
		for field: String in [
			"_tile_textures", "_floor_texture_variants", "_moss_texture_variants",
			"_prop_textures", "_scene_prop_textures", "_scene_prop_idle_frames",
			"_pillar_torch_idle_frames", "_effect_textures", "_effect_frames",
			"_projectile_atlas", "_projectile_textures", "_ambient_particle_atlas",
			"_ambient_particle_glow_atlas", "_ambient_fire_soft_atlas", "_ambient_air_wisp_atlas",
			"_ambient_air_wisp_soft_atlas", "_ambient_air_wisp_glow_atlas",
			"_ambient_particle_textures", "_ambient_particle_glow_textures",
			"_ambient_fire_soft_textures", "_ambient_air_wisp_textures",
			"_ambient_air_wisp_soft_textures", "_ambient_air_wisp_glow_textures",
			"_loot_textures", "_terrain_textures", "_terrain_destruction_frames_by_kind",
			"_unit_textures", "_unit_assets_loaded",
			"_element_textures", "_trap_textures", "_trap_idle_frames", "_trap_activation_frames",
			"_door_icon_textures", "_keyword_icon_textures", "_health_bar_frame_textures", "_unit_shadow_polygon_cache",
			"_unit_shadow_bottom_ratio_cache", "_unit_shadow_draw_geometry_cache", "_unit_shadow_draw_mesh_cache", "_door_opening_frames", "_door_opening_flipped_frames",
			"_idle_frames_by_type", "_death_frames_by_type", "_texture_used_rect_cache", "_unit_shadow_sync_miss_metrics"
		]:
			layer.set(field, get(field))

func _sync_dynamic_render_state(layout_changed: bool = false, visual_framing_changed: bool = false, changed_fields: Array = []) -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		return
	# Adaptive top clearance is retained across visual snapshots to prevent
	# whole-board chatter. Materialize that history on the parent before layers
	# are invalidated so a same-frame Blink/spawn transition cannot make each
	# retained layer recompute from a different intermediate snapshot.
	if (layout_changed or visual_framing_changed) and not combat_state.is_empty():
		_ensure_board_layout_cache()
	var fields: Array = changed_fields
	if fields.is_empty():
		fields = [
			"combat_state", "move_tiles", "attack_tiles", "selected_tile", "status_label",
			"status_detail", "exit_tiles", "exit_icon_ids", "presentation", "_hover_tile",
			"_navigation_zoom", "_navigation_pan", "_navigation_uses_default_zoom", "_navigation_content_signature",
			"_floor_variant_by_tile", "_moss_tiles_by_surface", "_board_layout_signature", "_board_visual_framing_signature",
			"_board_layout_cache_visual_top_offset",
			"_floor_variant_signature", "_moss_signature", "_damage_preview_cache",
			"_visible_units_cache", "_scene_props_by_tile", "_terrain_by_tile", "_loot_by_tile",
			"_traps_by_tile", "_campfire_scene_props_cache", "_grid_tile_ids_cache",
			"_ability_tiles_cache", "_move_tiles_lookup_cache", "_attack_tiles_lookup_cache",
			"_focus_tiles_lookup_cache", "_objective_exit_tiles_lookup_cache",
			"_projected_attack_tiles_lookup_cache", "_ability_tiles_lookup_cache",
			"_ambient_element_id_cache", "_equipment_pickup_beacon_cache",
			"_preview_unit_pulse_cache", "_submission_cache_valid", "_idle_elapsed",
			"_umbra_return_start_by_tile", "_foreground_obstruction_entries_cache", "_hud_health_rects_cache",
			"_hud_layout_entries_cache"
		]
	for layer: Control in _retained_render_layers():
		if layout_changed:
			layer.call("_invalidate_board_layout_cache")
		elif visual_framing_changed:
			layer.call("_invalidate_board_layout_cache", false, true)
		for field_var: Variant in fields:
			var field: String = str(field_var)
			layer.set(field, get(field))

func _queue_dynamic_redraw() -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		queue_redraw()
		return
	for layer: Control in _retained_render_layers():
		layer.set("_idle_elapsed", _idle_elapsed)
		layer.set("_hover_tile", _hover_tile)
		layer.queue_redraw()

func _queue_render_layer_redraw(layer: Control) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	layer.set("_idle_elapsed", _idle_elapsed)
	layer.set("_hover_tile", _hover_tile)
	layer.queue_redraw()

func render_instrumentation_snapshot() -> Dictionary:
	var dynamic_count: int = _dynamic_draw_count
	var dynamic_total_usec: int = _dynamic_draw_total_usec
	var dynamic_max_usec: int = _dynamic_draw_max_usec
	var section_total_usec: Dictionary = _render_section_total_usec.duplicate()
	var section_max_usec: Dictionary = _render_section_max_usec.duplicate()
	var layer_draw_counts: Dictionary = {}
	var layer_draw_total_usec: Dictionary = {}
	var scene_tile_draw_counts: Dictionary = {}
	if not _retained_render_layers().is_empty():
		dynamic_count = 0
		dynamic_total_usec = 0
		dynamic_max_usec = 0
		for layer: Control in _retained_render_layers():
			var layer_kind: String = str(layer.get("_render_layer_kind"))
			var layer_count: int = int(layer.get("_dynamic_draw_count"))
			var layer_total: int = int(layer.get("_dynamic_draw_total_usec"))
			dynamic_count += layer_count
			dynamic_total_usec += layer_total
			dynamic_max_usec = maxi(dynamic_max_usec, int(layer.get("_dynamic_draw_max_usec")))
			layer_draw_counts[layer_kind] = int(layer_draw_counts.get(layer_kind, 0)) + layer_count
			layer_draw_total_usec[layer_kind] = int(layer_draw_total_usec.get(layer_kind, 0)) + layer_total
			if layer_kind == RENDER_LAYER_SCENE_TILE:
				var layer_tile: Vector2i = layer.get("_render_layer_tile") as Vector2i
				scene_tile_draw_counts["%d,%d" % [layer_tile.x, layer_tile.y]] = layer_count
			_merge_render_section_metrics(section_total_usec, layer.get("_render_section_total_usec") as Dictionary, false)
			_merge_render_section_metrics(section_max_usec, layer.get("_render_section_max_usec") as Dictionary, true)
	return {
		"static_draw_count": _static_draw_count,
		"dynamic_draw_count": dynamic_count,
		"static_draw_total_usec": _static_draw_total_usec,
		"static_draw_max_usec": _static_draw_max_usec,
		"dynamic_draw_total_usec": dynamic_total_usec,
		"dynamic_draw_max_usec": dynamic_max_usec,
		"render_section_total_usec": section_total_usec,
		"render_section_max_usec": section_max_usec,
		"layer_draw_counts": layer_draw_counts,
		"layer_draw_total_usec": layer_draw_total_usec,
		"scene_tile_draw_counts": scene_tile_draw_counts,
		"split_layers_active": _dynamic_render_layer != null and is_instance_valid(_dynamic_render_layer),
		"presentation_redraw_dedup_active": true,
		"presentation_redraw_dedup_mode": "pre_process_render_frame",
		"retained_layer_count": _retained_render_layers().size(),
		"hud_layout_cache_entries": _hud_layout_cache_by_signature.size(),
		"loaded_unit_asset_type_count": _unit_assets_loaded.size(),
		"layout_content_rebuild_count": _board_layout_content_rebuild_count,
		"unit_shadow_sync_misses": _unit_shadow_sync_miss_metrics.duplicate(true),
	}

func _merge_render_section_metrics(target: Dictionary, source: Dictionary, keep_maximum: bool) -> void:
	for key_var: Variant in source:
		var key: String = str(key_var)
		var value: int = int(source.get(key_var, 0))
		if keep_maximum:
			target[key] = maxi(int(target.get(key, 0)), value)
		else:
			target[key] = int(target.get(key, 0)) + value

func reset_render_instrumentation() -> void:
	_static_draw_count = 0
	_static_draw_total_usec = 0
	_static_draw_max_usec = 0
	_dynamic_draw_count = 0
	_dynamic_draw_total_usec = 0
	_dynamic_draw_max_usec = 0
	_render_section_total_usec.clear()
	_render_section_max_usec.clear()
	_unit_shadow_sync_miss_metrics.clear()
	for layer: Control in _retained_render_layers():
		layer.call("reset_render_instrumentation")

func _process(delta: float) -> void:
	_process_next_unit_shadow_prewarm()
	var process_frame: int = Engine.get_process_frames()
	_last_processed_render_frame = process_frame
	var explicit_effects_redraw_this_frame: bool = _explicit_effects_redraw_process_frame == process_frame
	var explicit_impact_redraw_this_frame: bool = _explicit_impact_redraw_process_frame == process_frame
	if _presentation_needs_continuous_redraw():
		_continuous_presentation_elapsed += delta
		if _continuous_presentation_elapsed >= CONTINUOUS_PRESENTATION_REDRAW_SECONDS:
			_continuous_presentation_elapsed = 0.0
			_queue_continuous_render_redraws(explicit_effects_redraw_this_frame, explicit_impact_redraw_this_frame)
	else:
		_continuous_presentation_elapsed = 0.0
	var animating: bool = _any_idle_animation_active()
	if animating != _idle_animating:
		_idle_animating = animating
		_idle_elapsed = 0.0
		_idle_frame_key = ""
		_queue_active_idle_redraws()
	if not animating:
		return
	_idle_elapsed = wrapf(_idle_elapsed + delta, 0.0, 3600.0)
	var next_frame_key: String = _active_idle_frame_key()
	if next_frame_key != _idle_frame_key:
		_idle_frame_key = next_frame_key
		_queue_active_idle_redraws()

func _queue_continuous_render_redraws(skip_effects: bool = false, skip_impact: bool = false) -> void:
	if _ambient_particles_active() or _campfire_atmosphere_active():
		_queue_render_layer_redraw(_ambient_render_layer)
	if (
		(bool(presentation.get("pulse_attack_tiles", false)) and not attack_tiles.is_empty())
		or (bool(presentation.get("pulse_exit_tiles", false)) and not exit_tiles.is_empty())
	):
		_queue_render_layer_redraw(_overlay_render_layer)
	if not skip_impact and (
		str(presentation.get("umbra_stage", "clear")) != "clear"
		or _impact_animation_active()
	):
		_queue_render_layer_redraw(_dynamic_render_layer)
	if (
		_campfire_atmosphere_active()
		or _pillar_torch_ember_motes_active()
		or str(presentation.get("umbra_stage", "clear")) != "clear"
		or (bool(presentation.get("pulse_attack_tiles", false)) and not attack_tiles.is_empty())
	):
		_queue_render_layer_redraw(_foreground_render_layer)
	_queue_continuously_animated_scene_redraws(skip_impact)
	var damage_preview: Dictionary = _damage_preview_map()
	if not damage_preview.is_empty():
		# Damage-preview fill and lethal markers use the existing continuous
		# presentation cadence. Retaining unrelated layers must not freeze those
		# pulses, including destructible-terrain health bars drawn per tile.
		if _unit_damage_preview_active():
			_queue_render_layer_redraw(_hud_render_layer)
		for terrain_var: Variant in combat_state.get("terrain", []):
			if typeof(terrain_var) != TYPE_DICTIONARY:
				continue
			var terrain: Dictionary = terrain_var as Dictionary
			if not _terrain_damage_preview(terrain).is_empty():
				_queue_scene_render_layer_for_tile(terrain.get("pos", Vector2i(-1, -1)))
		if not skip_effects:
			_queue_render_layer_redraw(_effects_render_layer)
	elif not skip_effects and _preview_effect_needs_continuous_redraw(presentation.get("effect", {})):
		_queue_render_layer_redraw(_effects_render_layer)
		_queue_elemental_scene_depth_redraws(
			_elemental_scene_depth_tiles_for_presentation(presentation),
			_elemental_scene_depth_tiles_for_presentation(presentation)
		)

func _queue_continuously_animated_scene_redraws(skip_impact: bool = false) -> void:
	if _campfire_atmosphere_active():
		for prop_var: Variant in _campfire_scene_props_cache:
			if typeof(prop_var) == TYPE_DICTIONARY:
				_queue_scene_render_layer_for_tile((prop_var as Dictionary).get("tile", Vector2i(-1, -1)))
	if _pillar_torch_ember_motes_active():
		for prop_var: Variant in presentation.get("scene_props", []):
			if typeof(prop_var) == TYPE_DICTIONARY and str((prop_var as Dictionary).get("kind", "")) == "pillar_torch":
				_queue_scene_render_layer_for_tile((prop_var as Dictionary).get("tile", Vector2i(-1, -1)))
	if _equipment_pickup_beacon_active():
		for loot_var: Variant in combat_state.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var
			if not bool(loot.get("claimed", false)) and str(loot.get("kind", "")) == "equipment":
				_queue_scene_render_layer_for_tile(loot.get("pos", Vector2i(-1, -1)))
	if _impact_animation_active() and not skip_impact:
		_queue_impact_scene_redraws()
	if _preview_unit_pulse_active():
		for unit: Dictionary in _visible_units():
			if str(unit.get("role", "")) == "illusion_preview":
				_queue_scene_render_layer_for_tile(_scene_render_tile_for_unit(unit))

func _queue_impact_scene_redraws() -> void:
	var impact_keys: Array = presentation.get("impact_actor_keys", [])
	for unit: Dictionary in _visible_units():
		if impact_keys.has(str(unit.get("key", ""))):
			_queue_scene_render_layer_for_tile(_scene_render_tile_for_unit(unit))

func _queue_active_idle_redraws() -> void:
	for unit: Dictionary in _visible_units():
		if _unit_idle_animation_active(unit):
			_queue_scene_render_layer_for_tile(_scene_render_tile_for_unit(unit))
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) == TYPE_DICTIONARY and _scene_prop_idle_animation_active(prop_var as Dictionary):
			_queue_scene_render_layer_for_tile((prop_var as Dictionary).get("tile", Vector2i(-1, -1)))
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY and _trap_idle_animation_active(trap_var as Dictionary):
			# Traps retain their authored below-path ordering without invalidating
			# target highlights, paths, decals, or Umbra on every idle frame.
			_queue_render_layer_redraw(_ground_render_layer)
			break
	if _pillar_torch_idle_animation_active():
		var grid: Array = combat_state.get("grid", [])
		for tile: Vector2i in _rendered_tiles_in_draw_order():
			if _tile_renders_as_pillar(grid, tile):
				_queue_scene_render_layer_for_tile(tile)

func _queue_scene_render_layer_for_tile(tile: Vector2i) -> void:
	var layer: Control = _scene_render_layers_by_tile.get(tile, null) as Control
	_queue_render_layer_redraw(layer)

func _scene_render_tile_for_unit(unit: Dictionary) -> Vector2i:
	# Retained scene layers draw large actors on the far tile of their footprint.
	# Falling back to the origin only works for 1x1 actors and freezes dragon
	# animation until an unrelated event happens to invalidate the scene layer.
	return _effective_unit_tile(unit)

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
	if str(presentation.get("umbra_stage", "clear")) != "clear":
		return true
	if bool(presentation.get("pulse_attack_tiles", false)) and not attack_tiles.is_empty():
		return true
	if bool(presentation.get("pulse_exit_tiles", false)) and not exit_tiles.is_empty():
		return true
	if presentation.is_empty():
		return false
	if not _damage_preview_map().is_empty():
		return true
	if _impact_animation_active():
		return true
	if _preview_unit_pulse_active():
		return true
	var effect: Dictionary = presentation.get("effect", {})
	return _preview_effect_needs_continuous_redraw(effect)

func _impact_animation_active() -> bool:
	var impact_keys: Array = presentation.get("impact_actor_keys", [])
	if impact_keys.is_empty():
		return false
	if float(presentation.get("impact_strength", 1.0)) <= 0.0:
		return false
	if bool(presentation.get("reduced_motion", false)):
		return false
	return float(presentation.get("impact_progress", 0.0)) < 1.0

func _preview_unit_pulse_active() -> bool:
	if _submission_cache_valid:
		return _preview_unit_pulse_cache
	for unit_var: Variant in presentation.get("preview_units", []):
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "illusion_preview":
			return true
	return false

func _preview_effect_needs_continuous_redraw(effect: Dictionary) -> bool:
	if not bool(effect.get("preview", false)):
		return false
	# The authored Blink preview is a static integrated-rift texture. Redrawing its
	# retained effects layer at 30 Hz did no visual work, but it kept a busy combat
	# canvas active for the entire time the player considered a destination. Keep
	# animation only for the procedural fallback used when that texture is absent.
	var kind: String = str(effect.get("kind", ""))
	if kind == "blink":
		return _effect_textures.get("blink_rift_preview", null) == null
	# Only the AOE preview still derives motion from wall-clock time. Authored
	# elemental ranged previews are static curves, while Blink returned above
	# only when its authored static texture is unavailable.
	return kind == "aoe"

func _equipment_pickup_beacon_active() -> bool:
	if _submission_cache_valid:
		return _equipment_pickup_beacon_cache
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
	if not _trap_idle_frames.is_empty():
		for trap_var: Variant in combat_state.get("traps", []):
			if typeof(trap_var) == TYPE_DICTIONARY and _trap_idle_animation_active(trap_var as Dictionary):
				return true
	if _pillar_torch_idle_animation_active():
		return true
	return false

func set_combat_state(next_state: Dictionary, next_move_tiles: Array = [], next_attack_tiles: Array = [], next_selected_tile: Vector2i = Vector2i(-1, -1), next_status_label: String = "", next_status_detail: String = "", next_exit_tiles: Dictionary = {}, next_exit_icon_ids: Dictionary = {}, next_presentation: Dictionary = {}) -> void:
	var submission_phase_started: int = Time.get_ticks_usec() if _submission_performance_instrumentation_enabled else 0
	# The owning RunScene submits immutable copy-on-write snapshots. Pointer-only
	# presentation changes therefore retain the exact combat dictionary reference;
	# compare only the board-consumed snapshot when a non-conforming caller mutates
	# that dictionary in place. This keeps the safety net exact without walking
	# unrelated late-run state on the normal immutable-snapshot path.
	var state_reference_changed: bool = not is_same(next_state, combat_state)
	var state_changed: bool = state_reference_changed and next_state != combat_state
	if not state_reference_changed and _submission_cache_initialized:
		state_changed = (
			_combat_submission_cache_source(next_state)
			!= (_submission_cache_source_snapshot.get("combat", {}) as Dictionary)
		)
	var move_tiles_changed: bool = next_move_tiles != move_tiles
	var attack_tiles_changed: bool = next_attack_tiles != attack_tiles
	var selected_tile_changed: bool = next_selected_tile != selected_tile
	var status_changed: bool = next_status_label != status_label or next_status_detail != status_detail
	var exit_tiles_changed: bool = next_exit_tiles != exit_tiles
	var exit_icon_ids_changed: bool = next_exit_icon_ids != exit_icon_ids
	var previous_exit_tiles: Dictionary = exit_tiles
	var interaction_changed: bool = (
		move_tiles_changed
		or attack_tiles_changed
		or selected_tile_changed
		or status_changed
		or exit_tiles_changed
		or exit_icon_ids_changed
	)
	# Layout/framing semantics must remain valid before _ready() creates retained
	# layers (unit tests and callers can submit state while the view is detached).
	# Live views already pay this exact diff cost for selective redraw routing.
	var presentation_changes: Dictionary = _changed_presentation_keys(presentation, next_presentation)
	var previous_damage_preview: Dictionary = {}
	var moving_actor_keys: Dictionary = {}
	var previous_unit_render_tiles: Dictionary = {}
	var previous_unit_obstruction_entries: Dictionary = {}
	var previous_elemental_scene_tiles: Array[Vector2i] = _elemental_scene_depth_tiles_for_presentation(presentation)
	var previous_units_by_key: Dictionary = {}
	var track_visible_unit_changes: bool = false
	if _dynamic_render_layer != null and is_instance_valid(_dynamic_render_layer):
		previous_damage_preview = _damage_preview_map().duplicate(true)
		moving_actor_keys = _changed_unit_presentation_actor_keys(presentation, next_presentation)
		track_visible_unit_changes = (
			not moving_actor_keys.is_empty()
			or presentation_changes.has("preview_units")
			or presentation_changes.has("death_animation_units")
			or presentation_changes.has("visible_enemy_ids")
		)
		if track_visible_unit_changes:
			previous_units_by_key = _units_by_key(_visible_units())
			previous_unit_render_tiles = _unit_render_tiles_by_key(_visible_units())
			previous_unit_obstruction_entries = _unit_obstruction_entries_by_key(_visible_units())
	submission_phase_started = _record_submission_performance_phase("diff", submission_phase_started)
	var layout_inputs_changed: bool = state_changed or exit_tiles_changed or _board_layout_signature.is_empty()
	for layout_key: String in ["active_door_tiles", "locked_door_tiles", "board_backdrop_visible", "board_framing_mode", "board_safe_global_rect"]:
		if presentation_changes.has(layout_key):
			layout_inputs_changed = true
			break
	var framing_inputs_changed: bool = state_changed or _board_visual_framing_signature.is_empty()
	for framing_key: String in ["death_animation_units", "visible_enemy_ids", "scene_props"]:
		if presentation_changes.has(framing_key):
			framing_inputs_changed = true
			break
	var next_room_grid_signature: String = _room_grid_signature(next_state) if state_changed or layout_inputs_changed or _navigation_content_signature.is_empty() else _floor_variant_signature
	var next_navigation_content_signature: String = _navigation_content_signature
	if state_changed or _navigation_content_signature.is_empty():
		next_navigation_content_signature = "%s|%s" % [
			next_room_grid_signature,
			str(next_state.get("room_coord", Vector2i(-1, -1)))
		]
	var next_layout_signature: String = (
		_layout_signature_for_state(next_state, next_exit_tiles, next_presentation, next_room_grid_signature)
		if layout_inputs_changed
		else _board_layout_signature
	)
	var next_visual_framing_signature: String = (
		_visual_framing_signature_for_state(next_state, next_presentation)
		if framing_inputs_changed
		else _board_visual_framing_signature
	)
	var next_floor_signature: String = next_room_grid_signature if state_changed or _floor_variant_signature.is_empty() else _floor_variant_signature
	var next_moss_signature: String = _moss_signature_for_state(next_state) if state_changed or _moss_signature.is_empty() else _moss_signature
	var layout_changed: bool = next_layout_signature != _board_layout_signature
	var visual_framing_signature_changed: bool = next_visual_framing_signature != _board_visual_framing_signature
	var visual_framing_changed: bool = false
	var previous_layout_origin: Vector2 = _board_layout_cache_origin
	var previous_layout_tile_width: float = _board_layout_cache_tile_width
	var previous_visual_top_offset: float = _board_layout_cache_visual_top_offset
	var floor_changed: bool = next_floor_signature != _floor_variant_signature
	var moss_changed: bool = next_moss_signature != _moss_signature
	submission_phase_started = _record_submission_performance_phase("signatures", submission_phase_started)
	_update_umbra_return_transition(combat_state, presentation, next_state, next_presentation, layout_changed)
	_submission_cache_valid = false
	# Combat and presentation dictionaries are copy-on-write snapshots owned by
	# the caller. CombatBoardView only reads them and stores derived render data,
	# avoiding a full recursive clone on every animation/hover submission.
	combat_state = next_state
	move_tiles = _vector2i_array(next_move_tiles)
	attack_tiles = _vector2i_array(next_attack_tiles)
	selected_tile = next_selected_tile
	status_label = next_status_label
	status_detail = next_status_detail
	exit_tiles = next_exit_tiles
	exit_icon_ids = next_exit_icon_ids
	presentation = next_presentation
	var next_elemental_scene_tiles: Array[Vector2i] = _elemental_scene_depth_tiles_for_presentation(presentation)
	if move_tiles_changed:
		_move_tiles_lookup_cache = _vector2i_lookup(move_tiles)
	if attack_tiles_changed:
		_attack_tiles_lookup_cache = _vector2i_lookup(attack_tiles)
	var overlay_presentation_cache_changed: bool = not _submission_cache_initialized
	for overlay_key: String in ["focus_tiles", "objective_exit_target_tiles", "projected_attack_tiles"]:
		if presentation_changes.has(overlay_key):
			overlay_presentation_cache_changed = true
			break
	if overlay_presentation_cache_changed:
		_focus_tiles_lookup_cache = _vector2i_lookup(presentation.get("focus_tiles", []))
		_objective_exit_tiles_lookup_cache = _vector2i_lookup(presentation.get("objective_exit_target_tiles", []))
		_projected_attack_tiles_lookup_cache = _vector2i_lookup(presentation.get("projected_attack_tiles", []))
	if not _navigation_content_signature.is_empty() and next_navigation_content_signature != _navigation_content_signature:
		_navigation_pan = Vector2.ZERO
		_enemy_hud_side_by_actor.clear()
		_clear_hud_layout_signature_cache()
	_navigation_content_signature = next_navigation_content_signature
	if state_changed or presentation_changes.has("death_animation_units") or not _submission_cache_initialized:
		_ensure_unit_assets_for_submission(combat_state, presentation)
	submission_phase_started = _record_submission_performance_phase("assign_and_assets", submission_phase_started)
	if layout_changed:
		_board_layout_signature = next_layout_signature
		_invalidate_board_layout_cache()
	elif visual_framing_signature_changed:
		# Geometry-bearing combat content can change without changing the room
		# grid. Preserve any top clearance already earned in this room so deaths,
		# spawns, and adjacent moves cannot make the whole board chatter vertically.
		_invalidate_board_layout_cache(false, true)
		_ensure_board_layout_cache()
		visual_framing_changed = (
			not _board_layout_cache_origin.is_equal_approx(previous_layout_origin)
			or not is_equal_approx(_board_layout_cache_tile_width, previous_layout_tile_width)
			or not is_equal_approx(_board_layout_cache_visual_top_offset, previous_visual_top_offset)
		)
	_board_visual_framing_signature = next_visual_framing_signature
	if floor_changed:
		_floor_variant_signature = next_floor_signature
		_floor_variant_by_tile = _build_floor_variant_lookup(combat_state.get("grid", []))
	if moss_changed:
		_moss_signature = next_moss_signature
		_moss_tiles_by_surface = _build_moss_tile_lookup(combat_state.get("moss", {}))
	var submission_sources_changed: bool = state_changed or not _submission_cache_initialized
	for cache_key: String in [
		"scene_props", "preview_units", "death_animation_units", "unit_draw_tiles",
		"unit_world_positions", "visible_enemy_ids", "umbra_visible_tiles",
		"umbra_light_sources", "umbra_stage", "damage_preview", "effect", "ability_tiles"
	]:
		if presentation_changes.has(cache_key):
			submission_sources_changed = true
			break
	if submission_sources_changed:
		_rebuild_submission_caches()
	else:
		_submission_cache_valid = true
		_submission_cache_combat_changed = false
	submission_phase_started = _record_submission_performance_phase("derived_caches", submission_phase_started)
	if track_visible_unit_changes:
		var current_units_by_key: Dictionary = _units_by_key(_visible_units())
		for actor_key_var: Variant in previous_units_by_key:
			if not current_units_by_key.has(actor_key_var) or previous_units_by_key.get(actor_key_var) != current_units_by_key.get(actor_key_var):
				moving_actor_keys[str(actor_key_var)] = true
		for actor_key_var: Variant in current_units_by_key:
			if not previous_units_by_key.has(actor_key_var) or current_units_by_key.get(actor_key_var) != previous_units_by_key.get(actor_key_var):
				moving_actor_keys[str(actor_key_var)] = true
	var hud_layout_inputs_changed: bool = state_changed or layout_changed or visual_framing_changed or _hud_layout_entries_cache.is_empty()
	for hud_key: String in [
		"expanded_enemy_actor_keys", "expand_enemy_intents", "show_all_enemy_intents",
		"unit_draw_tiles", "unit_world_positions", "preview_units", "death_animation_units",
		"visible_enemy_ids"
	]:
		if presentation_changes.has(hud_key):
			hud_layout_inputs_changed = true
			break
	if hud_layout_inputs_changed:
		_rebuild_hud_health_rects_cache()
	submission_phase_started = _record_submission_performance_phase("hud_layout", submission_phase_started)
	if _dynamic_render_layer != null and is_instance_valid(_dynamic_render_layer) and (layout_changed or _scene_render_layers.is_empty()):
		_sync_scene_render_layers()
		_sync_dynamic_render_assets()
	var retained_sync_fields: Array = []
	if not layout_changed and not visual_framing_changed:
		if state_changed:
			retained_sync_fields.append_array([
				"combat_state", "_terrain_by_tile", "_loot_by_tile", "_traps_by_tile",
				"_grid_tile_ids_cache", "_ambient_element_id_cache", "_equipment_pickup_beacon_cache",
				"_visible_units_cache", "_preview_unit_pulse_cache", "_foreground_obstruction_entries_cache",
				"_hud_health_rects_cache", "_hud_layout_entries_cache", "_submission_cache_valid",
				"_umbra_return_start_by_tile"
			])
		if move_tiles_changed:
			retained_sync_fields.append_array(["move_tiles", "_move_tiles_lookup_cache"])
		if attack_tiles_changed:
			retained_sync_fields.append_array(["attack_tiles", "_attack_tiles_lookup_cache"])
		if selected_tile_changed:
			retained_sync_fields.append("selected_tile")
		if status_changed:
			retained_sync_fields.append_array(["status_label", "status_detail"])
		if exit_tiles_changed:
			retained_sync_fields.append("exit_tiles")
		if exit_icon_ids_changed:
			retained_sync_fields.append("exit_icon_ids")
		if not presentation_changes.is_empty():
			retained_sync_fields.append("presentation")
			retained_sync_fields.append_array(["_hud_health_rects_cache", "_hud_layout_entries_cache"])
		if presentation_changes.has("damage_preview") or presentation_changes.has("effect"):
			retained_sync_fields.append("_damage_preview_cache")
		if presentation_changes.has("ability_tiles"):
			retained_sync_fields.append_array(["_ability_tiles_cache", "_ability_tiles_lookup_cache"])
		if overlay_presentation_cache_changed:
			retained_sync_fields.append_array([
				"_focus_tiles_lookup_cache", "_objective_exit_tiles_lookup_cache",
				"_projected_attack_tiles_lookup_cache"
			])
		for unit_key: String in ["preview_units", "death_animation_units", "unit_draw_tiles", "unit_world_positions", "visible_enemy_ids", "umbra_visible_tiles", "umbra_light_sources", "umbra_stage"]:
			if not presentation_changes.has(unit_key):
				continue
			retained_sync_fields.append_array([
				"_visible_units_cache", "_preview_unit_pulse_cache", "_foreground_obstruction_entries_cache",
				"_submission_cache_valid"
			])
			break
		if presentation_changes.has("scene_props"):
			retained_sync_fields.append_array([
				"_scene_props_by_tile", "_campfire_scene_props_cache", "_foreground_obstruction_entries_cache",
				"_submission_cache_valid"
			])
		if floor_changed:
			retained_sync_fields.append_array(["_floor_variant_by_tile", "_floor_variant_signature"])
		if moss_changed:
			retained_sync_fields.append_array(["_moss_tiles_by_surface", "_moss_signature"])
		var unique_sync_fields: Array = []
		for field_var: Variant in retained_sync_fields:
			if not unique_sync_fields.has(field_var):
				unique_sync_fields.append(field_var)
		retained_sync_fields = unique_sync_fields
	if layout_changed or visual_framing_changed or not retained_sync_fields.is_empty():
		_sync_dynamic_render_state(layout_changed, visual_framing_changed, retained_sync_fields)
	submission_phase_started = _record_submission_performance_phase("retained_sync", submission_phase_started)
	_update_cursor_shape()
	if layout_changed or visual_framing_changed or floor_changed or moss_changed or _dynamic_render_layer == null:
		queue_redraw()
	if state_changed or _submission_cache_combat_changed or layout_changed or visual_framing_changed or floor_changed or moss_changed:
		_explicit_effects_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_explicit_impact_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_queue_dynamic_redraw()
	else:
		if interaction_changed:
			_queue_interaction_change_redraws(
				move_tiles_changed,
				attack_tiles_changed,
				selected_tile_changed,
				status_changed,
				exit_tiles_changed,
				exit_icon_ids_changed,
				previous_exit_tiles
			)
		_queue_presentation_change_redraws(
			presentation_changes,
			previous_damage_preview != _damage_preview_cache,
			moving_actor_keys,
			previous_unit_render_tiles,
			previous_unit_obstruction_entries,
			previous_elemental_scene_tiles,
			next_elemental_scene_tiles
		)
	_record_submission_performance_phase("redraw_routing", submission_phase_started)

func set_submission_performance_instrumentation_enabled(enabled: bool) -> void:
	_submission_performance_instrumentation_enabled = enabled
	_submission_performance_total_usec.clear()
	_submission_performance_counts.clear()

func submission_performance_instrumentation_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for phase_var: Variant in _submission_performance_total_usec:
		var phase: String = str(phase_var)
		var count: int = int(_submission_performance_counts.get(phase, 0))
		result[phase] = {
			"count": count,
			"total_usec": int(_submission_performance_total_usec.get(phase, 0)),
			"usec_per_call": float(_submission_performance_total_usec.get(phase, 0)) / float(count) if count > 0 else 0.0,
		}
	return result

func _record_submission_performance_phase(phase: String, started_usec: int) -> int:
	if not _submission_performance_instrumentation_enabled:
		return 0
	var now_usec: int = Time.get_ticks_usec()
	_submission_performance_total_usec[phase] = int(_submission_performance_total_usec.get(phase, 0)) + now_usec - started_usec
	_submission_performance_counts[phase] = int(_submission_performance_counts.get(phase, 0)) + 1
	return now_usec

func _queue_interaction_change_redraws(
	move_changed: bool,
	attack_changed: bool,
	selection_changed: bool,
	status_text_changed: bool,
	exits_changed: bool,
	exit_icons_changed: bool,
	previous_exits: Dictionary
) -> void:
	if move_changed or attack_changed or selection_changed or exits_changed:
		_queue_render_layer_redraw(_overlay_render_layer)
	if attack_changed:
		_queue_render_layer_redraw(_foreground_render_layer)
	if status_text_changed:
		_explicit_effects_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_queue_render_layer_redraw(_effects_render_layer)
	if exit_icons_changed:
		for tile_var: Variant in previous_exits:
			if typeof(tile_var) == TYPE_VECTOR2I:
				_queue_scene_render_layer_for_tile(tile_var)
		for tile_var: Variant in exit_tiles:
			if typeof(tile_var) == TYPE_VECTOR2I:
				_queue_scene_render_layer_for_tile(tile_var)

func _changed_presentation_keys(previous: Dictionary, next: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for key_var: Variant in previous:
		if not next.has(key_var) or previous.get(key_var) != next.get(key_var):
			changed[str(key_var)] = true
	for key_var: Variant in next:
		if not previous.has(key_var) or previous.get(key_var) != next.get(key_var):
			changed[str(key_var)] = true
	return changed

func _coalescible_explicit_redraw_frame() -> int:
	var render_frame: int = Engine.get_process_frames()
	# Engine advances this counter after rendering. If this board already processed
	# the current value, a timer/deferred submission will render later in this frame
	# and must not suppress the following frame's continuous redraw.
	return render_frame if _last_processed_render_frame != render_frame else -1

func _changed_unit_presentation_actor_keys(previous: Dictionary, next: Dictionary) -> Dictionary:
	var changed: Dictionary = {}
	for field: String in ["unit_world_positions", "unit_draw_tiles"]:
		var previous_values: Dictionary = previous.get(field, {}) as Dictionary
		var next_values: Dictionary = next.get(field, {}) as Dictionary
		for key_var: Variant in previous_values:
			if not next_values.has(key_var) or previous_values.get(key_var) != next_values.get(key_var):
				changed[str(key_var)] = true
		for key_var: Variant in next_values:
			if not previous_values.has(key_var) or previous_values.get(key_var) != next_values.get(key_var):
				changed[str(key_var)] = true
	return changed

func _unit_render_tiles_by_key(units_to_draw: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in units_to_draw:
		var actor_key: String = str(unit.get("key", ""))
		if not actor_key.is_empty():
			result[actor_key] = _effective_unit_tile(unit)
	return result

func _units_by_key(units_to_draw: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in units_to_draw:
		var actor_key: String = str(unit.get("key", ""))
		if not actor_key.is_empty():
			result[actor_key] = unit
	return result

func _unit_obstruction_entries_by_key(units_to_draw: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in units_to_draw:
		var actor_key: String = str(unit.get("key", ""))
		if actor_key.is_empty():
			continue
		result[actor_key] = {"tile": _effective_unit_tile(unit), "rect": _unit_draw_rect(unit)}
	return result

func _queue_presentation_change_redraws(
	changed_keys: Dictionary,
	damage_preview_changed: bool = false,
	moving_actor_keys: Dictionary = {},
	previous_unit_render_tiles: Dictionary = {},
	previous_unit_obstruction_entries: Dictionary = {},
	previous_elemental_scene_tiles: Array = [],
	next_elemental_scene_tiles: Array = []
) -> void:
	if changed_keys.is_empty() and not damage_preview_changed:
		return
	var ambient_changed: bool = false
	var overlay_changed: bool = false
	var path_changed: bool = false
	var world_changed: bool = false
	var impact_changed: bool = false
	var unit_movement_changed: bool = false
	var foreground_changed: bool = false
	var hud_changed: bool = false
	var effects_changed: bool = false
	for key_var: Variant in changed_keys:
		match str(key_var):
			"ambient_time_seconds":
				ambient_changed = true
			"ability_tiles", "focus_color", "focus_tiles", "objective_exit_target_tiles", "objective_leader_tile", "projected_attack_tiles", "projected_destination", "pulse_attack_tiles", "pulse_exit_tiles":
				overlay_changed = true
			"path_color", "path_tiles":
				path_changed = true
			"effect", "effect_progress":
				effects_changed = true
				world_changed = true
			"floating_texts", "lethal_preview_time_seconds", "movement_risk_chips", "status_safe_global_rect":
				effects_changed = true
			"trap_effects":
				effects_changed = true
				world_changed = true
			"damage_preview":
				effects_changed = true
			"expand_enemy_intents", "expanded_enemy_actor_keys", "show_all_enemy_intents":
				hud_changed = true
			"impact_actor_keys", "impact_decals", "impact_progress", "impact_strength":
				world_changed = true
				impact_changed = true
			"death_animation_units", "preview_units", "unit_world_positions", "unit_draw_tiles", "visible_enemy_ids":
				unit_movement_changed = true
				foreground_changed = true
				hud_changed = true
			_:
				# Unclassified presentation state remains conservative. The retained
				# layers optimize known animation-only submissions without risking a
				# stale frame when a new presentation field is introduced.
				_queue_dynamic_redraw()
				return
	if ambient_changed:
		_queue_render_layer_redraw(_ambient_render_layer)
	if overlay_changed:
		_queue_render_layer_redraw(_overlay_render_layer)
	if path_changed:
		_queue_render_layer_redraw(_path_render_layer)
	if world_changed:
		_explicit_impact_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_queue_render_layer_redraw(_dynamic_render_layer)
	if impact_changed:
		_queue_impact_scene_redraws()
	if unit_movement_changed:
		_queue_moving_actor_redraws(moving_actor_keys, previous_unit_render_tiles, previous_unit_obstruction_entries)
	if foreground_changed:
		_queue_render_layer_redraw(_foreground_render_layer)
	if damage_preview_changed:
		hud_changed = true
		for terrain_var: Variant in combat_state.get("terrain", []):
			if typeof(terrain_var) == TYPE_DICTIONARY:
				_queue_scene_render_layer_for_tile((terrain_var as Dictionary).get("pos", Vector2i(-1, -1)))
	if hud_changed:
		_queue_render_layer_redraw(_hud_render_layer)
	if effects_changed:
		_explicit_effects_redraw_process_frame = _coalescible_explicit_redraw_frame()
		_queue_render_layer_redraw(_effects_render_layer)
		_queue_elemental_scene_depth_redraws(previous_elemental_scene_tiles, next_elemental_scene_tiles)

func _queue_elemental_scene_depth_redraws(previous_tiles: Array, next_tiles: Array) -> void:
	var queued_tiles: Dictionary = {}
	for tile_var: Variant in previous_tiles + next_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I or queued_tiles.has(tile_var):
			continue
		queued_tiles[tile_var] = true
		_queue_scene_render_layer_for_tile(tile_var as Vector2i)

func _queue_moving_actor_redraws(
	moving_actor_keys: Dictionary,
	previous_unit_render_tiles: Dictionary,
	previous_unit_obstruction_entries: Dictionary
) -> void:
	var current_render_tiles: Dictionary = _unit_render_tiles_by_key(_visible_units())
	var current_obstruction_entries: Dictionary = _unit_obstruction_entries_by_key(_visible_units())
	var previous_moving_entries: Array = []
	var current_moving_entries: Array = []
	for actor_key_var: Variant in moving_actor_keys:
		var actor_key: String = str(actor_key_var)
		if previous_unit_render_tiles.has(actor_key):
			_queue_scene_render_layer_for_tile(previous_unit_render_tiles.get(actor_key, Vector2i(-1, -1)))
		if current_render_tiles.has(actor_key):
			_queue_scene_render_layer_for_tile(current_render_tiles.get(actor_key, Vector2i(-1, -1)))
		if previous_unit_obstruction_entries.has(actor_key):
			previous_moving_entries.append(previous_unit_obstruction_entries.get(actor_key))
		if current_obstruction_entries.has(actor_key):
			current_moving_entries.append(current_obstruction_entries.get(actor_key))
	for candidate_var: Variant in _foreground_obstruction_candidates():
		var candidate: Dictionary = candidate_var as Dictionary
		if (
			_moving_entries_obstruct_candidate(previous_moving_entries, candidate)
			!= _moving_entries_obstruct_candidate(current_moving_entries, candidate)
		):
			_queue_scene_render_layer_for_tile(candidate.get("tile", Vector2i(-1, -1)))

func _foreground_obstruction_candidates() -> Array:
	var source: Dictionary = {
		"size": size,
		"navigation_zoom": _navigation_zoom,
		"navigation_pan": _navigation_pan,
		"grid": combat_state.get("grid", []),
		"scene_props": presentation.get("scene_props", []),
		"terrain": combat_state.get("terrain", []),
		"umbra_visible_tiles": presentation.get("umbra_visible_tiles", [])
	}
	if source == _foreground_obstruction_candidates_source_snapshot:
		return _foreground_obstruction_candidates_cache
	var candidates: Array = []
	var grid: Array = combat_state.get("grid", [])
	for tile: Vector2i in _rendered_tiles_in_draw_order():
		for prop_var: Variant in _entries_for_tile(_scene_props_by_tile, presentation.get("scene_props", []), "tile", tile):
			if typeof(prop_var) != TYPE_DICTIONARY:
				continue
			var prop: Dictionary = prop_var as Dictionary
			var prop_texture: Texture2D = _texture_for_scene_prop(prop)
			if prop_texture != null:
				candidates.append({"tile": tile, "rect": _scene_prop_rect(prop_texture, prop)})
		var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
		if tile_id == "wall" and not _is_outer_boundary_tile(grid, tile):
			tile_id = "pillar"
		match tile_id:
			"pillar":
				var pillar_texture: Texture2D = _prop_textures.get("pillar", null)
				if pillar_texture != null:
					candidates.append({"tile": tile, "rect": _prop_draw_rect(pillar_texture, _prop_rect_for_tile(tile))})
			"wall":
				for segment: Dictionary in _boundary_prop_segments(tile_id, grid, tile):
					candidates.append({"tile": tile, "rect": segment.get("draw_rect", Rect2())})
			"door":
				var door_texture: Texture2D = _door_texture_for_tile(grid, tile)
				if door_texture != null:
					candidates.append({"tile": tile, "rect": _prop_draw_rect(door_texture, _door_rect_for_tile(tile, grid))})
		for terrain_var: Variant in _entries_for_tile(_terrain_by_tile, combat_state.get("terrain", []), "pos", tile):
			if typeof(terrain_var) != TYPE_DICTIONARY:
				continue
			var terrain: Dictionary = terrain_var as Dictionary
			if not _board_tile_is_visible_to_player(terrain.get("pos", Vector2i(-1, -1))):
				continue
			if int(terrain.get("hp", 0)) <= 0:
				continue
			var terrain_texture: Texture2D = _terrain_textures.get(str(terrain.get("kind", "")), null)
			if terrain_texture != null:
				candidates.append({
					"tile": tile,
					"rect": _terrain_rect_for_tile(tile, terrain_texture, str(terrain.get("kind", "")))
				})
	_foreground_obstruction_candidates_source_snapshot = source.duplicate(true)
	_foreground_obstruction_candidates_cache = candidates
	return _foreground_obstruction_candidates_cache

func _moving_entries_obstruct_candidate(moving_entries: Array, candidate: Dictionary) -> bool:
	var candidate_tile: Vector2i = candidate.get("tile", Vector2i(-1, -1))
	var candidate_rect: Rect2 = candidate.get("rect", Rect2())
	for entry_var: Variant in moving_entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		if not _tile_draws_before(entry_tile, candidate_tile):
			continue
		if _foreground_overlap_coverage(candidate_rect, entry.get("rect", Rect2())) >= FOREGROUND_OBSTRUCTION_COVERAGE_THRESHOLD:
			return true
	return false

func _update_umbra_return_transition(previous_state: Dictionary, previous_presentation: Dictionary, next_state: Dictionary, next_presentation: Dictionary, layout_changed: bool) -> void:
	if layout_changed or str(next_presentation.get("umbra_stage", "clear")) == "clear":
		_umbra_return_start_by_tile.clear()
		return
	var next_visible_lookup: Dictionary = {}
	for tile_var: Variant in next_presentation.get("umbra_visible_tiles", []):
		if typeof(tile_var) == TYPE_VECTOR2I:
			next_visible_lookup[tile_var] = true
			_umbra_return_start_by_tile.erase(tile_var)
	if previous_state.is_empty() or int(next_state.get("turn", 0)) <= int(previous_state.get("turn", 0)):
		return
	var previous_visible_tiles: Array[Vector2i] = _vector2i_array(previous_presentation.get("umbra_visible_tiles", []))
	var lost_tiles: Array[Vector2i] = _vector2i_array([])
	for tile: Vector2i in previous_visible_tiles:
		if not next_visible_lookup.has(tile):
			lost_tiles.append(tile)
	if lost_tiles.is_empty():
		return
	var centers: Array[Vector2i] = _vector2i_array([])
	var next_source_ids: Dictionary = {}
	for source_var: Variant in next_presentation.get("umbra_light_sources", []):
		if typeof(source_var) == TYPE_DICTIONARY:
			next_source_ids[int((source_var as Dictionary).get("id", -1))] = true
	for source_var: Variant in previous_presentation.get("umbra_light_sources", []):
		if typeof(source_var) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = source_var as Dictionary
		if next_source_ids.has(int(source.get("id", -1))):
			continue
		var source_pos: Vector2i = source.get("pos", Vector2i(-1, -1))
		if source_pos.x >= 0:
			centers.append(source_pos)
	var previous_vision_duration: int = int(previous_presentation.get("umbra_vision_bonus_activations", 0))
	var next_vision_duration: int = int(next_presentation.get("umbra_vision_bonus_activations", 0))
	if previous_vision_duration != 0 and next_vision_duration == 0:
		var player: Dictionary = next_state.get("player", {})
		centers.append(player.get("pos", Vector2i.ZERO))
	if centers.is_empty():
		return
	var maximum_distance: int = 0
	var distance_by_tile: Dictionary = {}
	for tile: Vector2i in lost_tiles:
		var closest_distance: int = 9999
		for center: Vector2i in centers:
			closest_distance = mini(closest_distance, absi(tile.x - center.x) + absi(tile.y - center.y))
		distance_by_tile[tile] = closest_distance
		maximum_distance = maxi(maximum_distance, closest_distance)
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	for tile: Vector2i in lost_tiles:
		var normalized_distance: float = float(int(distance_by_tile.get(tile, 0))) / float(maxi(1, maximum_distance))
		var delay: float = (1.0 - normalized_distance) * UMBRA_RETURN_STAGGER_SECONDS
		_umbra_return_start_by_tile[tile] = now_seconds + delay

func _combat_submission_cache_source(source_state: Dictionary) -> Dictionary:
	return {
		"player": source_state.get("player", {}),
		"player_turn_restrictions": source_state.get("player_turn_restrictions", {}),
		"illusions": source_state.get("illusions", []),
		"enemies": source_state.get("enemies", []),
		"npcs": source_state.get("npcs", []),
		"terrain": source_state.get("terrain", []),
		"loot": source_state.get("loot", []),
		"traps": source_state.get("traps", []),
		"elemental_intensity": source_state.get("elemental_intensity", {}),
		"grid": source_state.get("grid", []),
		"room_element": source_state.get("room_element", ElementData.NONE)
	}

func _rebuild_submission_caches() -> bool:
	var effect: Dictionary = presentation.get("effect", {})
	# Compare inputs by the derived cache they affect. Preview effects and damage
	# change on nearly every target hover; rebuilding spatial indexes, visible
	# units, and obstruction geometry for those changes made target feedback scale
	# with every actor and prop on the board.
	var combat_source: Dictionary = _combat_submission_cache_source(combat_state)
	var scene_source: Dictionary = {
		"scene_props": presentation.get("scene_props", []),
	}
	var unit_source: Dictionary = {
		"preview_units": presentation.get("preview_units", []),
		"death_animation_units": presentation.get("death_animation_units", []),
		"unit_draw_tiles": presentation.get("unit_draw_tiles", {}),
		"unit_world_positions": presentation.get("unit_world_positions", {}),
		"visible_enemy_ids": presentation.get("visible_enemy_ids", []),
		"umbra_visible_tiles": presentation.get("umbra_visible_tiles", []),
		"umbra_light_sources": presentation.get("umbra_light_sources", []),
		"umbra_stage": presentation.get("umbra_stage", "clear"),
	}
	var damage_source: Dictionary = {
		"damage_preview": presentation.get("damage_preview", {}),
		"effect_damage_preview": effect.get("damage_preview", {}),
	}
	var ability_source: Dictionary = {
		"ability_tiles": presentation.get("ability_tiles", []),
	}
	var combat_changed: bool = (
		not _submission_cache_initialized
		or combat_source != (_submission_cache_source_snapshot.get("combat", {}) as Dictionary)
	)
	var scene_changed: bool = (
		not _submission_cache_initialized
		or scene_source != (_submission_cache_source_snapshot.get("scene", {}) as Dictionary)
	)
	var units_changed: bool = (
		not _submission_cache_initialized
		or unit_source != (_submission_cache_source_snapshot.get("units", {}) as Dictionary)
	)
	var damage_changed: bool = (
		not _submission_cache_initialized
		or damage_source != (_submission_cache_source_snapshot.get("damage", {}) as Dictionary)
	)
	var ability_changed: bool = (
		not _submission_cache_initialized
		or ability_source != (_submission_cache_source_snapshot.get("ability", {}) as Dictionary)
	)
	_submission_cache_combat_changed = combat_changed
	if not combat_changed and not scene_changed and not units_changed and not damage_changed and not ability_changed:
		_submission_cache_valid = true
		_submission_cache_combat_changed = false
		return false
	# Snapshot only the category that changed. In particular, a new per-target
	# damage preview no longer deep-copies the entire combat state.
	if combat_changed:
		_submission_cache_source_snapshot["combat"] = combat_source.duplicate(true)
	if scene_changed:
		_submission_cache_source_snapshot["scene"] = scene_source.duplicate(true)
	if units_changed:
		_submission_cache_source_snapshot["units"] = unit_source.duplicate(true)
	if damage_changed:
		_submission_cache_source_snapshot["damage"] = damage_source.duplicate(true)
	if ability_changed:
		_submission_cache_source_snapshot["ability"] = ability_source.duplicate(true)
	_submission_cache_initialized = true
	if damage_changed:
		_damage_preview_cache = _build_damage_preview_map(presentation)
	if scene_changed:
		_scene_props_by_tile = _index_dictionary_entries_by_tile(presentation.get("scene_props", []), "tile")
		_campfire_scene_props_cache = []
		for prop_var: Variant in presentation.get("scene_props", []):
			if typeof(prop_var) != TYPE_DICTIONARY:
				continue
			var prop: Dictionary = prop_var
			if str(prop.get("kind", "")) == "campfire_bonfire":
				_campfire_scene_props_cache.append(prop)
	if combat_changed:
		_terrain_by_tile = _index_dictionary_entries_by_tile(combat_state.get("terrain", []), "pos")
		_loot_by_tile = _index_dictionary_entries_by_tile(combat_state.get("loot", []), "pos")
		_traps_by_tile = _index_dictionary_entries_by_tile(combat_state.get("traps", []), "pos")
		_grid_tile_ids_cache = {}
		for row_var: Variant in combat_state.get("grid", []):
			if typeof(row_var) != TYPE_ARRAY:
				continue
			for cell_var: Variant in row_var as Array:
				_grid_tile_ids_cache[str(cell_var)] = true
		_ambient_element_id_cache = str(combat_state.get("room_element", ElementData.NONE))
		_equipment_pickup_beacon_cache = false
		for loot_var: Variant in combat_state.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var
			if not bool(loot.get("claimed", false)) and str(loot.get("kind", "")) == "equipment":
				_equipment_pickup_beacon_cache = true
				break
	if ability_changed:
		_ability_tiles_cache = _vector2i_array(presentation.get("ability_tiles", []))
		_ability_tiles_lookup_cache = _vector2i_lookup(_ability_tiles_cache)
	if combat_changed or units_changed:
		_visible_units_cache = _build_visible_units()
		_preview_unit_pulse_cache = false
		for unit: Dictionary in _visible_units_cache:
			if str(unit.get("role", "")) == "illusion_preview":
				_preview_unit_pulse_cache = true
				break
	# Scene props participate in foreground obstruction even though they do not
	# affect the visible-unit list. Keep that derived cache aligned when a room
	# prop changes without paying to rebuild it for damage-only hovers.
	if combat_changed or units_changed or scene_changed:
		if is_inside_tree():
			_foreground_obstruction_entries_cache = _foreground_obstruction_entries(_visible_units_cache)
		else:
			_foreground_obstruction_entries_cache.clear()
	_submission_cache_valid = true
	return true

func _index_dictionary_entries_by_tile(entries: Array, tile_key: String) -> Dictionary:
	var index: Dictionary = {}
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var tile_value: Variant = entry.get(tile_key, Vector2i(-1, -1))
		if typeof(tile_value) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_value
		var tile_entries: Array = index.get(tile, [])
		tile_entries.append(entry)
		index[tile] = tile_entries
	return index

func _entries_for_tile(index: Dictionary, entries: Array, tile_key: String, tile: Vector2i) -> Array:
	if _submission_cache_valid:
		return index.get(tile, []) as Array
	var matching: Array = []
	for entry_var: Variant in entries:
		if typeof(entry_var) == TYPE_DICTIONARY and (entry_var as Dictionary).get(tile_key, Vector2i(-1, -1)) == tile:
			matching.append(entry_var)
	return matching

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_last_pointer_position = event.position
		set_navigation_zoom(_navigation_zoom * event.factor, event.position)
		accept_event()
		return
	if event is InputEventPanGesture:
		_last_pointer_position = event.position
		set_navigation_pan(_navigation_pan - event.delta * BOARD_TRACKPAD_PAN_SCALE, false)
		_update_hover_at(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion:
		_last_pointer_position = event.position
		if _navigation_pointer_button != MOUSE_BUTTON_NONE and _mouse_button_is_held(event, _navigation_pointer_button):
			var drag_delta: Vector2 = event.position - _navigation_pointer_start
			if not _navigation_pan_active and drag_delta.length() >= BOARD_PAN_DRAG_THRESHOLD:
				_navigation_pan_active = true
				_clear_hover_for_navigation()
			if _navigation_pan_active:
				set_navigation_pan(_navigation_pan_start + drag_delta, false)
				_update_cursor_shape()
				accept_event()
				return
		var next_hover: Vector2i = _update_hover_at(event.position)
		if _navigation_pointer_button == MOUSE_BUTTON_NONE and _tile_drag_aiming_active() and _left_drag_start_tile.x >= 0 and next_hover.x >= 0 and (int(event.button_mask) & MOUSE_BUTTON_MASK_LEFT) != 0:
			if next_hover != _left_drag_start_tile:
				_left_drag_moved = true
			if _left_drag_moved:
				tile_dragged.emit(_left_drag_start_tile, next_hover)
		return
	if not event is InputEventMouseButton:
		return
	_last_pointer_position = event.position
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var zoom_direction: float = 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
		var wheel_factor: float = maxf(0.25, event.factor)
		set_navigation_zoom(_navigation_zoom * pow(BOARD_ZOOM_STEP, zoom_direction * wheel_factor), event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed and event.double_click:
			reset_navigation()
			accept_event()
			return
		if event.pressed:
			_begin_navigation_pan(MOUSE_BUTTON_MIDDLE, event.position, true)
		elif _navigation_pointer_button == MOUSE_BUTTON_MIDDLE:
			_end_navigation_pan(event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var clicked: Vector2i = _tile_at_point(event.position)
		if event.pressed:
			_left_drag_start_tile = clicked
			_left_drag_moved = false
			if not _tile_drag_aiming_active() or Input.is_key_pressed(KEY_SPACE):
				_begin_navigation_pan(MOUSE_BUTTON_LEFT, event.position, false)
			return
		var completed_navigation_pan: bool = false
		if _navigation_pointer_button == MOUSE_BUTTON_LEFT:
			completed_navigation_pan = _navigation_pan_active
			_end_navigation_pan(event.position)
		if not completed_navigation_pan and _left_drag_start_tile.x >= 0:
			if clicked.x >= 0 and _left_drag_moved:
				tile_drag_released.emit(_left_drag_start_tile, clicked)
			elif clicked.x >= 0:
				tile_clicked.emit(clicked)
		_left_drag_start_tile = Vector2i(-1, -1)
		_left_drag_moved = false
		if completed_navigation_pan:
			accept_event()
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_requested.emit()

func set_navigation_zoom(next_zoom: float, focus_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var clamped_zoom: float = clampf(next_zoom, BOARD_MIN_NAVIGATION_ZOOM, BOARD_MAX_NAVIGATION_ZOOM)
	if is_equal_approx(clamped_zoom, _navigation_zoom):
		return
	if focus_position.x < 0.0 or focus_position.y < 0.0:
		focus_position = size * 0.5
	_ensure_board_layout_cache()
	var previous_zoom: float = _navigation_zoom
	var zoom_anchor: Vector2 = _navigation_zoom_anchor()
	var zoom_ratio: float = clamped_zoom / maxf(0.001, previous_zoom)
	var anchored_pan: Vector2 = focus_position - zoom_anchor - (focus_position - zoom_anchor - _navigation_pan) * zoom_ratio
	_navigation_zoom = clamped_zoom
	var next_tile_width: float = _tile_width_for_extents(_board_layout_cache_extents) * _navigation_zoom
	_navigation_pan = _clamped_navigation_pan_for_layout(anchored_pan, _board_layout_cache_extents, next_tile_width)
	_navigation_uses_default_zoom = false
	_navigation_transform_changed(true)

func set_navigation_pan(next_pan: Vector2, update_hover: bool = true) -> void:
	_ensure_board_layout_cache()
	var clamped_pan: Vector2 = _clamped_navigation_pan_for_layout(next_pan, _board_layout_cache_extents, _board_layout_cache_tile_width)
	if clamped_pan.is_equal_approx(_navigation_pan):
		return
	_navigation_pan = clamped_pan
	_navigation_transform_changed(update_hover)

func reset_navigation() -> void:
	var default_zoom: float = _default_navigation_zoom_for_viewport()
	var changed: bool = not is_equal_approx(_navigation_zoom, default_zoom) or not _navigation_pan.is_zero_approx() or not _navigation_uses_default_zoom
	_navigation_zoom = default_zoom
	_navigation_pan = Vector2.ZERO
	_navigation_uses_default_zoom = true
	if changed:
		_navigation_transform_changed(true)

func _default_navigation_zoom_for_viewport() -> float:
	# Layout helpers are also exercised on detached board instances by tests and
	# tooling. Avoid asking CanvasItem for a viewport rect until the node is in a
	# tree; preserve the historical neutral zoom when no authored size exists.
	if not is_inside_tree() and size.y <= 0.0:
		return BOARD_DEFAULT_NAVIGATION_ZOOM
	var viewport_height: float = get_viewport_rect().size.y if is_inside_tree() else size.y
	var expansion: float = clampf(
		(viewport_height - BOARD_COMPACT_VIEWPORT_HEIGHT) / (BOARD_EXPANDED_VIEWPORT_HEIGHT - BOARD_COMPACT_VIEWPORT_HEIGHT),
		0.0,
		1.0
	)
	var default_zoom: float
	if str(presentation.get("board_framing_mode", "room")) == "combat":
		default_zoom = lerpf(BOARD_COMBAT_COMPACT_DEFAULT_NAVIGATION_ZOOM, BOARD_COMBAT_EXPANDED_DEFAULT_NAVIGATION_ZOOM, expansion)
	else:
		default_zoom = lerpf(BOARD_ROOM_COMPACT_DEFAULT_NAVIGATION_ZOOM, BOARD_ROOM_EXPANDED_DEFAULT_NAVIGATION_ZOOM, expansion)
	return clampf(default_zoom * _navigation_zoom_scale_for_presentation(presentation), BOARD_MIN_NAVIGATION_ZOOM, BOARD_MAX_NAVIGATION_ZOOM)

func _navigation_zoom_scale_for_presentation(source: Dictionary) -> float:
	if not (source.get("objective_exit_target_tiles", []) as Array).is_empty():
		return BOARD_REACH_EXIT_DEFAULT_NAVIGATION_ZOOM_SCALE
	return 1.0

func navigation_snapshot() -> Dictionary:
	_ensure_board_layout_cache()
	var limits: Rect2 = _navigation_pan_limits(_board_layout_cache_extents, _board_layout_cache_tile_width)
	return {
		"zoom": _navigation_zoom,
		"pan": _navigation_pan,
		"min_zoom": BOARD_MIN_NAVIGATION_ZOOM,
		"max_zoom": BOARD_MAX_NAVIGATION_ZOOM,
		"pan_limits": limits,
		"content_rect": _navigation_content_rect(_board_layout_cache_extents, _board_layout_cache_tile_width, _navigation_pan)
	}

func _begin_navigation_pan(button: int, pointer_position: Vector2, begin_immediately: bool) -> void:
	_navigation_pointer_button = button
	_navigation_pointer_start = pointer_position
	_navigation_pan_start = _navigation_pan
	_navigation_pan_active = begin_immediately
	if begin_immediately:
		_clear_hover_for_navigation()
	_update_cursor_shape()

func _end_navigation_pan(pointer_position: Vector2) -> void:
	_navigation_pointer_button = MOUSE_BUTTON_NONE
	_navigation_pan_active = false
	_update_hover_at(pointer_position)
	_update_cursor_shape()

func _mouse_button_is_held(event: InputEventMouseMotion, button: int) -> bool:
	if button == MOUSE_BUTTON_LEFT:
		return (int(event.button_mask) & MOUSE_BUTTON_MASK_LEFT) != 0
	if button == MOUSE_BUTTON_MIDDLE:
		return (int(event.button_mask) & MOUSE_BUTTON_MASK_MIDDLE) != 0
	return false

func _tile_drag_aiming_active() -> bool:
	return bool(presentation.get("tile_drag_aiming", false))

func _update_hover_at(pointer_position: Vector2) -> Vector2i:
	var next_hover: Vector2i = _tile_at_point(pointer_position)
	if next_hover == _hover_tile:
		return next_hover
	_hover_tile = next_hover
	tile_hovered.emit(_hover_tile)
	_update_cursor_shape()
	_queue_hover_redraws()
	return next_hover

func _clear_hover_for_navigation() -> void:
	if _hover_tile.x < 0:
		return
	_hover_tile = Vector2i(-1, -1)
	tile_hovered.emit(_hover_tile)
	_queue_hover_redraws()

func _queue_hover_redraws() -> void:
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		queue_redraw()
		return
	# Hover only changes tile overlays and enemy intent/HUD layout. Ambient,
	# occupied-tile art, foreground atmosphere, and effects retain their draw
	# commands while pointer motion remains fully event-driven.
	_rebuild_hud_health_rects_cache()
	if _hud_render_layer != null and is_instance_valid(_hud_render_layer):
		_hud_render_layer.set("_hud_layout_entries_cache", _hud_layout_entries_cache)
		_hud_render_layer.set("_hud_health_rects_cache", _hud_health_rects_cache)
	if _effects_render_layer != null and is_instance_valid(_effects_render_layer):
		_effects_render_layer.set("_hud_health_rects_cache", _hud_health_rects_cache)
	_queue_render_layer_redraw(_overlay_render_layer)
	_queue_render_layer_redraw(_hud_render_layer)

func _navigation_transform_changed(update_hover: bool) -> void:
	_invalidate_board_layout_cache(false)
	_foreground_obstruction_entries_cache = _foreground_obstruction_entries(_visible_units())
	_rebuild_hud_health_rects_cache()
	_sync_dynamic_render_state(false)
	for layer: Control in _retained_render_layers():
		layer.call("_invalidate_board_layout_cache", false)
	queue_redraw()
	_queue_dynamic_redraw()
	if update_hover:
		_update_hover_at(_last_pointer_position)
	_update_cursor_shape()
	navigation_changed.emit()

func _get_tooltip(at_position: Vector2) -> String:
	var tooltip_sources: Array = _retained_render_layers()
	tooltip_sources.reverse()
	tooltip_sources.append(self)
	for source_var: Variant in tooltip_sources:
		var source: Control = source_var as Control
		var regions: Array = source.get("_tooltip_regions") as Array
		for index: int in range(regions.size() - 1, -1, -1):
			var region: Dictionary = regions[index]
			var rect: Rect2 = region.get("rect", Rect2())
			if rect.has_point(at_position):
				return str(region.get("tooltip", ""))
	return ""

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges().is_empty():
		return null
	if for_text.begins_with("equipment:"):
		var equipment_id: String = for_text.trim_prefix("equipment:")
		if not equipment_id.is_empty() and equipment_tooltip_builder.is_valid():
			return equipment_tooltip_builder.call(equipment_id)
		return UiTooltipPanel.make_text(_equipment_loot_fallback_tooltip(equipment_id))
	return UiTooltipPanel.make_text(for_text)

func _draw() -> void:
	if _is_dynamic_render_layer:
		match _render_layer_kind:
			RENDER_LAYER_AMBIENT:
				_draw_ambient_render_layer()
			RENDER_LAYER_OVERLAYS:
				_draw_overlay_render_layer()
			RENDER_LAYER_GROUND:
				_draw_ground_render_layer()
			RENDER_LAYER_PATH:
				_draw_path_render_layer()
			RENDER_LAYER_WORLD:
				_draw_world_render_layer()
			RENDER_LAYER_SCENE_TILE:
				_draw_scene_tile_render_layer()
			RENDER_LAYER_FOREGROUND:
				_draw_foreground_render_layer()
			RENDER_LAYER_HUD:
				_draw_hud_render_layer()
			RENDER_LAYER_EFFECTS:
				_draw_effects_render_layer()
			_:
				_draw_dynamic_board()
		return
	_draw_static_board()
	if _dynamic_render_layer == null or not is_instance_valid(_dynamic_render_layer):
		_draw_dynamic_board()

func _draw_static_board() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_static_draw_count += 1
	if not bool(presentation.get("board_backdrop_visible", false)):
		draw_rect(Rect2(Vector2.ZERO, size), Color("18120f"), true)
	if combat_state.is_empty():
		_draw_empty_state()
		_record_static_draw_time(started_usec)
		return
	var grid: Array = combat_state.get("grid", [])
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	for tile: Vector2i in tiles:
		_draw_floor_tile(grid, tile)
	_record_static_draw_time(started_usec)

func _draw_dynamic_board() -> void:
	_draw_ambient_render_layer()
	_draw_overlay_render_layer()
	_draw_ground_render_layer()
	_draw_path_render_layer()
	_draw_world_render_layer()
	if not combat_state.is_empty():
		var grid: Array = combat_state.get("grid", [])
		var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
		var units_to_draw: Array[Dictionary] = _visible_units()
		_draw_scene_objects(grid, tiles, units_to_draw)
		_draw_large_enemy_attack_highlights(units_to_draw)
		_draw_umbra_light_source_markers(float(Time.get_ticks_msec()) / 1000.0)
		_draw_pillar_torch_ember_motes(tiles, units_to_draw)
		_draw_campfire_ember_motes()
	_draw_effects_render_layer()
	_draw_hud_render_layer()

func _draw_ambient_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var section_started_usec: int = Time.get_ticks_usec()
	_draw_campfire_room_firelight(tiles)
	_record_render_section_time("campfire_light", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_ambient_particles(tiles)
	_record_render_section_time("ambient_particles", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_world_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var section_started_usec: int = Time.get_ticks_usec()
	_draw_impact_decals()
	_record_render_section_time("impact_decals", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_umbra_overlay(tiles)
	_record_render_section_time("umbra", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_elemental_spell_floor_overlay()
	_draw_elemental_trap_floor_overlay()
	_record_render_section_time("elemental_floor_overlays", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_overlay_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var section_started_usec: int = Time.get_ticks_usec()
	for tile: Vector2i in tiles:
		_draw_tile_overlays(tile)
	_record_render_section_time("tile_overlays", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_ground_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var section_started_usec: int = Time.get_ticks_usec()
	_draw_ground_items_below_path(tiles)
	_record_render_section_time("ground_items", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_path_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var section_started_usec: int = Time.get_ticks_usec()
	_draw_path_preview()
	_record_render_section_time("path_preview", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_scene_tile_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty() or _render_layer_tile.x < 0:
		_record_dynamic_draw_time(started_usec)
		return
	var section_started_usec: int = Time.get_ticks_usec()
	var grid: Array = combat_state.get("grid", [])
	var units_to_draw: Array[Dictionary] = _visible_units()
	var obstruction_entries: Array = _foreground_obstruction_entries_cache
	_draw_elemental_scene_depth_pass(_render_layer_tile, false)
	_draw_scene_props_for_tile(_render_layer_tile, obstruction_entries)
	_draw_tile_props(grid, _render_layer_tile, obstruction_entries)
	_draw_unit_bodies_for_tile(_render_layer_tile, units_to_draw)
	_draw_elemental_scene_depth_pass(_render_layer_tile, true)
	_record_render_section_time("scene_tiles", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_foreground_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var section_started_usec: int = Time.get_ticks_usec()
	var tiles: Array[Vector2i] = _rendered_tiles_in_draw_order()
	var units_to_draw: Array[Dictionary] = _visible_units()
	_draw_large_enemy_attack_highlights(units_to_draw)
	_record_render_section_time("foreground_attack_highlights", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_umbra_light_source_markers(float(Time.get_ticks_msec()) / 1000.0)
	_record_render_section_time("foreground_umbra_markers", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_pillar_torch_ember_motes(tiles, units_to_draw)
	_record_render_section_time("foreground_torch_motes", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_campfire_ember_motes()
	_record_render_section_time("foreground_campfire_motes", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_hud_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var section_started_usec: int = Time.get_ticks_usec()
	var units_to_draw: Array[Dictionary] = _visible_units()
	_draw_unit_huds(units_to_draw)
	_record_render_section_time("unit_huds", section_started_usec)
	# Damage-preview text and the lost-HP band must composite after the health
	# bar itself. Drawing them on the lower effects layer lets the retained HUD
	# layer paint over the projected HP text during ranged targeting.
	section_started_usec = Time.get_ticks_usec()
	_draw_unit_damage_preview_overlays(units_to_draw)
	_record_render_section_time("damage_preview_overlays", section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _draw_effects_render_layer() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_dynamic_draw_count += 1
	_tooltip_regions.clear()
	if combat_state.is_empty():
		_record_dynamic_draw_time(started_usec)
		return
	var total_section_started_usec: int = Time.get_ticks_usec()
	var section_started_usec: int = total_section_started_usec
	var units_to_draw: Array[Dictionary] = _visible_units()
	_draw_effect_overlay()
	_record_render_section_time("effect_overlay", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_lethal_preview_icons(units_to_draw)
	_record_render_section_time("lethal_preview_icons", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_movement_risk_chips()
	_record_render_section_time("movement_risk_chips", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_status_text()
	_record_render_section_time("status_text", section_started_usec)
	section_started_usec = Time.get_ticks_usec()
	_draw_floating_texts()
	_record_render_section_time("floating_texts", section_started_usec)
	_record_render_section_time("effects_and_feedback", total_section_started_usec)
	_record_dynamic_draw_time(started_usec)

func _record_static_draw_time(started_usec: int) -> void:
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_static_draw_total_usec += elapsed_usec
	_static_draw_max_usec = maxi(_static_draw_max_usec, elapsed_usec)

func _record_dynamic_draw_time(started_usec: int) -> void:
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_dynamic_draw_total_usec += elapsed_usec
	_dynamic_draw_max_usec = maxi(_dynamic_draw_max_usec, elapsed_usec)

func _record_render_section_time(section: String, started_usec: int) -> void:
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_render_section_total_usec[section] = int(_render_section_total_usec.get(section, 0)) + elapsed_usec
	_render_section_max_usec[section] = maxi(int(_render_section_max_usec.get(section, 0)), elapsed_usec)

func _draw_umbra_overlay(tiles: Array[Vector2i]) -> void:
	var stage_id: String = str(presentation.get("umbra_stage", "clear"))
	if stage_id == "clear" or tiles.is_empty():
		return
	var visible_lookup: Dictionary = {}
	for tile_var: Variant in presentation.get("umbra_visible_tiles", []):
		if typeof(tile_var) == TYPE_VECTOR2I:
			visible_lookup[tile_var] = true
	var stage_alpha: float = _umbra_stage_fill_alpha(stage_id)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var hidden_tiles: Array[Vector2i] = _vector2i_array([])
	var hidden_lookup: Dictionary = {}
	var return_progress_by_tile: Dictionary = {}
	for tile: Vector2i in tiles:
		if visible_lookup.has(tile):
			continue
		var return_progress: float = _umbra_return_progress(tile, time_seconds)
		hidden_tiles.append(tile)
		hidden_lookup[tile] = true
		return_progress_by_tile[tile] = return_progress
		draw_colored_polygon(_tile_polygon(tile), Color(0.012, 0.008, 0.026, stage_alpha * return_progress))
	for tile: Vector2i in hidden_tiles:
		var return_progress: float = float(return_progress_by_tile.get(tile, 1.0))
		if return_progress <= 0.0:
			continue
		_draw_umbra_tile_billows(tile, time_seconds, stage_alpha, return_progress)
	_draw_umbra_boundary_billows(hidden_tiles, visible_lookup, hidden_lookup, return_progress_by_tile, time_seconds, stage_alpha)
	_draw_umbra_light_sources(time_seconds)

func _umbra_stage_fill_alpha(stage_id: String) -> float:
	return {
		"fringe": 0.54,
		"advancing": 0.58,
		"pressing": 0.62,
		"deep": 0.66,
		"heart": 0.70,
		"eclipse": 0.74
	}.get(stage_id, 0.60)

func _draw_umbra_tile_billows(tile: Vector2i, time_seconds: float, stage_alpha: float, return_progress: float) -> void:
	var seed: int = tile.x * 92821 + tile.y * 68917 + 1709
	var flow_phase: float = time_seconds * 0.58 + float(tile.x) * 0.73 + float(tile.y) * 0.51
	var counter_phase: float = time_seconds * 0.44 - float(tile.x) * 0.39 + float(tile.y) * 0.67
	var swell: float = 0.5 + 0.5 * sin(flow_phase + _ambient_hash01(seed + 7) * 0.8)
	var center: Vector2 = _tile_center(tile)
	var flow := Vector2(
		sin(flow_phase) * _tile_width() * 0.15,
		cos(counter_phase) * _tile_height() * 0.24
	)
	_draw_umbra_soft_lobe(
		center + flow,
		_tile_width() * (0.48 + swell * 0.07),
		Vector2(1.14 + _ambient_hash01(seed + 11) * 0.14, 0.76 + _ambient_hash01(seed + 13) * 0.14),
		lerpf(-0.22, 0.22, _ambient_hash01(seed + 17)),
		Color(0.018, 0.006, 0.042, (0.78 + stage_alpha * 0.16) * return_progress),
		10
	)
	var counter_flow := Vector2(-flow.x * 0.78, -flow.y * 0.46) + Vector2(0.0, -_tile_height() * 0.08)
	_draw_umbra_soft_lobe(
		center + counter_flow,
		_tile_width() * (0.34 + (1.0 - swell) * 0.07),
		Vector2(1.04 + _ambient_hash01(seed + 19) * 0.14, 0.80 + _ambient_hash01(seed + 23) * 0.12),
		lerpf(-0.30, 0.30, _ambient_hash01(seed + 29)),
		Color(0.165, 0.048, 0.235, (0.46 + stage_alpha * 0.14) * return_progress),
		9
	)

func _umbra_return_progress(tile: Vector2i, time_seconds: float) -> float:
	if not _umbra_return_start_by_tile.has(tile):
		return 1.0
	var elapsed: float = time_seconds - float(_umbra_return_start_by_tile[tile])
	if elapsed <= 0.0:
		return 0.0
	if elapsed >= UMBRA_RETURN_FADE_SECONDS:
		_umbra_return_start_by_tile.erase(tile)
		return 1.0
	var linear_progress: float = elapsed / UMBRA_RETURN_FADE_SECONDS
	return smoothstep(0.0, 1.0, linear_progress)

func _draw_umbra_boundary_billows(hidden_tiles: Array[Vector2i], visible_lookup: Dictionary, hidden_lookup: Dictionary, return_progress_by_tile: Dictionary, time_seconds: float, stage_alpha: float) -> void:
	var neighbor_offsets: Array[Vector2i] = _vector2i_array([
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	])
	for tile: Vector2i in hidden_tiles:
		var return_progress: float = float(return_progress_by_tile.get(tile, 1.0))
		if return_progress <= 0.0:
			continue
		var hidden_center: Vector2 = _tile_center(tile)
		for neighbor_offset: Vector2i in neighbor_offsets:
			var neighbor: Vector2i = tile + neighbor_offset
			if hidden_lookup.has(neighbor) or not visible_lookup.has(neighbor):
				continue
			var visible_center: Vector2 = _tile_center(neighbor)
			var edge_center: Vector2 = hidden_center.lerp(visible_center, 0.48)
			var seed: int = tile.x * 81173 + tile.y * 46349 + neighbor_offset.x * 719 + neighbor_offset.y * 1237
			var phase: float = _ambient_hash01(seed + 5) * TAU
			var roll: float = sin(time_seconds * (0.44 + _ambient_hash01(seed + 7) * 0.16) + phase)
			var tangent: Vector2 = (visible_center - hidden_center).orthogonal().normalized()
			var inward: Vector2 = (hidden_center - visible_center).normalized()
			var boundary_center: Vector2 = edge_center + tangent * roll * _tile_width() * 0.08 + inward * _tile_width() * (0.025 + 0.02 * cos(time_seconds * 0.27 + phase))
			var boundary_angle: float = (visible_center - hidden_center).angle() + PI * 0.5
			for puff_index: int in range(2):
				var puff_side: float = -1.0 if puff_index == 0 else 1.0
				var puff_center: Vector2 = boundary_center + tangent * puff_side * _tile_width() * (0.08 + 0.025 * roll)
				var puff_swell: float = 0.5 + 0.5 * sin(time_seconds * 0.58 + phase + float(puff_index) * 1.7)
				_draw_umbra_soft_lobe(
					puff_center,
					_tile_width() * (0.28 + puff_swell * 0.07),
					Vector2(1.14 + puff_swell * 0.12, 0.74 + (1.0 - puff_swell) * 0.12),
					boundary_angle + roll * 0.10,
					Color(0.145, 0.044, 0.215, (0.56 + stage_alpha * 0.14) * return_progress),
					9
				)
			var edge_points: PackedVector2Array = _umbra_boundary_edge(tile, neighbor_offset)
			if edge_points.size() == 2:
				draw_line(edge_points[0], edge_points[1], Color(0.008, 0.005, 0.020, 0.86 * return_progress), 3.4, true)
				draw_line(edge_points[0], edge_points[1], Color(0.20, 0.105, 0.285, (0.30 + stage_alpha * 0.10) * return_progress), 1.1, true)

func _umbra_boundary_edge(tile: Vector2i, neighbor_offset: Vector2i) -> PackedVector2Array:
	var polygon: PackedVector2Array = _tile_polygon(tile)
	var edge := PackedVector2Array()
	if polygon.size() < 4:
		return edge
	match neighbor_offset:
		Vector2i.UP:
			edge.append(polygon[0])
			edge.append(polygon[1])
		Vector2i.RIGHT:
			edge.append(polygon[1])
			edge.append(polygon[2])
		Vector2i.DOWN:
			edge.append(polygon[2])
			edge.append(polygon[3])
		Vector2i.LEFT:
			edge.append(polygon[3])
			edge.append(polygon[0])
	return edge

func _draw_umbra_soft_lobe(center: Vector2, radius: float, ellipse_scale: Vector2, rotation: float, color: Color, layer_count: int) -> void:
	if layer_count <= 0 or color.a <= 0.0:
		return
	draw_set_transform(center, rotation, ellipse_scale)
	for layer_index: int in range(layer_count, 0, -1):
		var t: float = float(layer_index) / float(layer_count)
		var inner_weight: float = pow(1.0 - t, 0.76)
		var layer_alpha: float = color.a * (0.028 + inner_weight * 0.082)
		var layer_radius: float = radius * (0.12 + t * 0.88)
		draw_circle(Vector2.ZERO, layer_radius, Color(color.r, color.g, color.b, layer_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _draw_umbra_light_sources(time_seconds: float) -> void:
	for source_var: Variant in presentation.get("umbra_light_sources", []):
		if typeof(source_var) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = source_var as Dictionary
		var tile: Vector2i = source.get("pos", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		_draw_umbra_light_source_reach(source, time_seconds)

func _umbra_light_source_tiles(source: Dictionary) -> Array[Vector2i]:
	var source_tile: Vector2i = source.get("pos", Vector2i(-1, -1))
	var radius_tiles: int = maxi(1, int(source.get("radius", 1)))
	var result: Array[Vector2i] = []
	if source_tile.x < 0:
		return result
	for tile: Vector2i in _rendered_tiles_in_draw_order():
		if _umbra_light_source_distance(source_tile, tile) <= radius_tiles:
			result.append(tile)
	return result

func _umbra_light_source_distance(source_tile: Vector2i, tile: Vector2i) -> int:
	return absi(tile.x - source_tile.x) + absi(tile.y - source_tile.y)

func _draw_umbra_light_source_reach(source: Dictionary, time_seconds: float) -> void:
	var source_tile: Vector2i = source.get("pos", Vector2i(-1, -1))
	var radius_tiles: int = maxi(1, int(source.get("radius", 1)))
	var source_seed: float = _umbra_light_source_seed(source)
	var pulse: float = 0.96 + 0.04 * sin(time_seconds * 1.42 + source_seed * 0.73)
	var footprint_tiles: Array[Vector2i] = _umbra_light_source_tiles(source)
	for tile: Vector2i in footprint_tiles:
		var distance: int = _umbra_light_source_distance(source_tile, tile)
		var reach_weight: float = 1.0 - float(distance) / (float(radius_tiles) + 0.90)
		var tile_center: Vector2 = _tile_center(tile)
		var tile_seed: float = float(tile.x * 17 + tile.y * 31)
		var tile_drift := Vector2(
			sin(time_seconds * 0.47 + tile_seed) * _tile_width() * 0.010,
			cos(time_seconds * 0.39 + tile_seed) * _tile_height() * 0.018
		)
		_draw_campfire_soft_ellipse(
			tile_center + tile_drift,
			_tile_width() * (0.64 + reach_weight * 0.10),
			Vector2(1.02, 0.48),
			0.0,
			Color(1.0, 0.48, 0.10, (0.14 + reach_weight * 0.18) * pulse),
			22
		)
		_draw_campfire_soft_ellipse(
			tile_center - tile_drift * 0.52,
			_tile_width() * (0.42 + reach_weight * 0.08),
			Vector2(1.04, 0.46),
			0.0,
			Color(1.0, 0.79, 0.30, (0.08 + reach_weight * 0.13) * pulse),
			18
		)
	_draw_campfire_soft_ellipse(
		_tile_center(source_tile) + Vector2(0.0, _tile_height() * 0.10),
		_tile_width() * (0.78 + float(radius_tiles) * 0.18),
		Vector2(1.32, 0.62),
		-0.04,
		Color(1.0, 0.67, 0.20, 0.28 * pulse),
		26
	)

func _draw_umbra_light_source_markers(time_seconds: float) -> void:
	var font: Font = get_theme_default_font()
	for source_var: Variant in presentation.get("umbra_light_sources", []):
		if typeof(source_var) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = source_var as Dictionary
		var tile: Vector2i = source.get("pos", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var radius_tiles: int = maxi(1, int(source.get("radius", 1)))
		var remaining: int = int(source.get("remaining_activations", 0))
		var source_seed: float = _umbra_light_source_seed(source)
		if bool(source.get("tethered", false)):
			var tethered_rect: Rect2 = _draw_umbra_tethered_light_marker(tile, source_seed, time_seconds)
			_register_tooltip(tethered_rect, _tethered_light_tooltip(source))
			continue
		var breath: float = _umbra_light_orb_breath(source_seed, time_seconds)
		var glow_brightness: float = 0.94 + 0.10 * (0.5 + 0.5 * sin(time_seconds * 2.15 + source_seed * 0.37))
		var orb_center: Vector2 = _umbra_light_orb_center(tile, source_seed, time_seconds)
		var orb_radius: float = clampf(_tile_width() * 0.115, 11.0, 20.0) * breath
		_draw_umbra_light_orb(orb_center, orb_radius, glow_brightness, source_seed, time_seconds)
		var count_text: String = "∞" if remaining < 0 else str(maxi(0, remaining))
		var chip_rect: Rect2 = _draw_umbra_light_orb_counter(orb_center, orb_radius, count_text, font, glow_brightness)
		var duration_text: String = "Lasts for this combat." if remaining < 0 else "%d player turn%s remaining." % [remaining, "" if remaining == 1 else "s"]
		var tooltip: String = "Light Source\nReveals Umbra within %d tile%s.\n%s" % [radius_tiles, "" if radius_tiles == 1 else "s", duration_text]
		var marker_rect := Rect2(orb_center - Vector2(orb_radius * 1.65, orb_radius * 1.65), Vector2(orb_radius * 3.3, orb_radius * 3.3)).merge(chip_rect)
		_register_tooltip(marker_rect, tooltip)

func _tethered_light_tooltip(source: Dictionary) -> String:
	var radius: int = maxi(1, int(source.get("radius", 1)))
	var lines := PackedStringArray(["Tethered Light — Radius %d" % radius])
	for contributor_var: Variant in source.get("radius_contributors", []):
		if typeof(contributor_var) != TYPE_DICTIONARY:
			continue
		var contributor: Dictionary = contributor_var
		lines.append("%s: +%d" % [str(contributor.get("name", "Source")), int(contributor.get("radius", 0))])
	lines.append("Moves with this illusion and ends when it is removed.")
	return "\n".join(lines)

func _umbra_light_source_seed(source: Dictionary) -> float:
	return float(absi(str(source.get("id", "0")).hash()) % 10007)

func _draw_umbra_tethered_light_marker(tile: Vector2i, source_seed: float, time_seconds: float) -> Rect2:
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, -_tile_height() * 0.22)
	var breath: float = _umbra_light_orb_breath(source_seed, time_seconds)
	var halo_radius: float = clampf(_tile_width() * 0.27, 20.0, 38.0) * breath
	_draw_campfire_soft_ellipse(
		center,
		halo_radius * 1.85,
		Vector2(1.18, 0.48),
		-0.05,
		Color(1.0, 0.68, 0.18, 0.34),
		24
	)
	_draw_campfire_soft_ellipse(
		center + Vector2(0.0, -halo_radius * 0.08),
		halo_radius,
		Vector2(1.10, 0.38),
		0.04,
		Color(1.0, 0.90, 0.48, 0.42),
		18
	)
	for mote_index: int in range(3):
		var phase: float = time_seconds * (0.72 + float(mote_index) * 0.11) + source_seed * 0.013 + float(mote_index) * TAU / 3.0
		var mote_center: Vector2 = center + Vector2(cos(phase) * halo_radius * 0.84, sin(phase) * halo_radius * 0.28)
		draw_circle(mote_center, 1.8 + float(mote_index) * 0.35, Color(1.0, 0.90, 0.52, 0.78))
	return Rect2(center - Vector2(halo_radius * 1.9, halo_radius), Vector2(halo_radius * 3.8, halo_radius * 2.0))

func _umbra_light_orb_breath(source_seed: float, time_seconds: float) -> float:
	return 1.0 + 0.055 * sin(time_seconds * 2.15 + source_seed * 0.37)

func _umbra_light_orb_center(tile: Vector2i, source_seed: float, time_seconds: float) -> Vector2:
	var bob: float = sin(time_seconds * 1.45 + source_seed * 0.91) * _tile_height() * 0.045
	var sway: float = sin(time_seconds * 0.83 + source_seed * 1.17) * _tile_width() * 0.010
	return _tile_center(tile) + Vector2(sway, -_tile_height() * 0.18 + bob)

func _draw_umbra_light_orb(orb_center: Vector2, orb_radius: float, glow_brightness: float, source_seed: float, time_seconds: float) -> void:
	_draw_campfire_soft_ellipse(
		orb_center + Vector2(0.0, orb_radius * 0.76),
		orb_radius * 1.32,
		Vector2(1.42, 0.31),
		0.0,
		Color(0.14, 0.055, 0.015, 0.34),
		14
	)
	_draw_campfire_soft_ellipse(
		orb_center,
		orb_radius * 4.45 * glow_brightness,
		Vector2(1.08, 0.86),
		0.0,
		Color(1.0, 0.56, 0.11, 0.66),
		28
	)
	_draw_campfire_soft_ellipse(
		orb_center - Vector2(orb_radius * 0.05, orb_radius * 0.08),
		orb_radius * 2.45 * glow_brightness,
		Vector2(1.02, 0.94),
		0.0,
		Color(1.0, 0.81, 0.30, 0.72),
		22
	)
	_draw_campfire_soft_ellipse(
		orb_center - Vector2(orb_radius * 0.10, orb_radius * 0.12),
		orb_radius * 1.42,
		Vector2(1.0, 0.96),
		0.0,
		Color(1.0, 0.96, 0.64, 0.82),
		18
	)
	var core_drift := Vector2(
		sin(time_seconds * 1.18 + source_seed) * orb_radius * 0.075,
		cos(time_seconds * 0.96 + source_seed * 1.31) * orb_radius * 0.060
	)
	var gradient_layers: int = 30
	for layer_index: int in range(gradient_layers, 0, -1):
		var outer_t: float = float(layer_index) / float(gradient_layers)
		var core_weight: float = 1.0 - outer_t
		var light_offset := Vector2(-orb_radius * 0.14, -orb_radius * 0.18) * core_weight
		var layer_center: Vector2 = orb_center + core_drift * (0.42 + core_weight * 0.58) + light_offset
		var layer_radius: float = orb_radius * (0.16 + outer_t * 0.92)
		var layer_color: Color = Color("ff9d16").lerp(Color("fff8c9"), pow(core_weight, 0.66))
		layer_color.a = lerpf(0.012, 0.20, pow(core_weight, 0.74))
		draw_circle(layer_center, layer_radius, layer_color)
	_draw_campfire_soft_ellipse(
		orb_center + core_drift - Vector2(orb_radius * 0.25, orb_radius * 0.28),
		orb_radius * 0.55,
		Vector2(1.0, 0.74),
		-0.42,
		Color(1.0, 1.0, 0.90, 0.78),
		12
	)
	_draw_campfire_soft_ellipse(
		orb_center - core_drift * 0.70 + Vector2(orb_radius * 0.23, orb_radius * 0.20),
		orb_radius * 0.42,
		Vector2(1.0, 0.82),
		0.30,
		Color(1.0, 0.55, 0.08, 0.42),
		10
	)
	_draw_umbra_light_orb_motes(orb_center, orb_radius, source_seed, time_seconds)

func _draw_umbra_light_orb_motes(orb_center: Vector2, orb_radius: float, source_seed: float, time_seconds: float) -> void:
	for mote_index: int in range(3):
		var phase: float = time_seconds * (0.72 + float(mote_index) * 0.09) + source_seed + float(mote_index) * 2.09
		var orbit_radius: float = orb_radius * (1.34 + float(mote_index) * 0.16)
		var mote_point := orb_center + Vector2(cos(phase) * orbit_radius, sin(phase) * orbit_radius * 0.62)
		var mote_alpha: float = 0.28 + 0.24 * (0.5 + 0.5 * sin(phase * 1.7))
		_draw_campfire_soft_ellipse(
			mote_point,
			orb_radius * (0.20 + float(mote_index) * 0.025),
			Vector2.ONE,
			0.0,
			Color(1.0, 0.92, 0.56, mote_alpha),
			8
		)

func _draw_umbra_light_orb_counter(orb_center: Vector2, orb_radius: float, count_text: String, font: Font, pulse: float) -> Rect2:
	var chip_radius: float = clampf(orb_radius * 0.56, 7.5, 10.5)
	var chip_center: Vector2 = orb_center + Vector2(orb_radius * 0.82, orb_radius * 0.68)
	_draw_campfire_soft_ellipse(
		chip_center,
		chip_radius * 1.85 * pulse,
		Vector2.ONE,
		0.0,
		Color(1.0, 0.67, 0.18, 0.28),
		10
	)
	var chip_rect := Rect2(chip_center - Vector2.ONE * chip_radius, Vector2.ONE * chip_radius * 2.0)
	if font != null:
		draw_string(font, Vector2(chip_rect.position.x + 1.2, chip_center.y + 5.2), count_text, HORIZONTAL_ALIGNMENT_CENTER, chip_rect.size.x, 11, Color(0.05, 0.025, 0.01, 0.92))
		draw_string(font, Vector2(chip_rect.position.x, chip_center.y + 4.0), count_text, HORIZONTAL_ALIGNMENT_CENTER, chip_rect.size.x, 11, Color("fff9db"))
	return chip_rect

func _draw_empty_state() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(34, 52), "No active combat.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("f0e5cf"))

func _campfire_atmosphere_active() -> bool:
	return not _campfire_scene_props().is_empty()

func _campfire_scene_props() -> Array:
	if _submission_cache_valid:
		return _campfire_scene_props_cache
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
	if _submission_cache_valid:
		return _ambient_element_id_cache
	return str(combat_state.get("room_element", ElementData.NONE))

func _ambient_intensity(element_id: String = "") -> int:
	var resolved_element: String = element_id if not element_id.is_empty() else _ambient_element_id()
	var intensities: Dictionary = combat_state.get("elemental_intensity", {}) as Dictionary
	return maxi(0, int(intensities.get(resolved_element, 0)))

func _draw_ambient_particles(tiles: Array[Vector2i]) -> void:
	var element_id: String = _ambient_element_id()
	if tiles.is_empty() or not ElementData.is_elemental(element_id):
		return
	var particle_count: int = _ambient_particle_count(element_id, tiles.size())
	if particle_count <= 0:
		return
	_prepare_ambient_hash_cache(element_id)
	_begin_ambient_particle_batch(element_id)
	var time_seconds: float = float(presentation.get("ambient_time_seconds", float(Time.get_ticks_msec()) / 1000.0))
	var room_seed: int = _ambient_room_seed(element_id)
	for index: int in range(particle_count):
		var particle_seed: int = room_seed + index * 7919
		var tile_index: int = posmod(_ambient_hash(particle_seed + 17), tiles.size())
		var base_point: Vector2 = _tile_center(tiles[tile_index])
		_draw_ambient_particle(element_id, base_point, particle_seed, time_seconds)
	_flush_ambient_particle_batch()

func _ambient_particle_count(element_id: String, tile_count: int, intensity_override: int = -1) -> int:
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
	var intensity: int = _ambient_intensity(element_id) if intensity_override < 0 else maxi(0, intensity_override)
	return maxi(0, int(roundf(float(base_count) * board_scale * AMBIENT_PARTICLE_DENSITY * ElementalIntensityRules.ambient_density_scale(intensity))))

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
	if _ambient_hash_cache.has(seed):
		return int(_ambient_hash_cache.get(seed, 0))
	var value: int = posmod(seed, 2147483647)
	value = posmod(value * 1103515245 + 12345, 2147483647)
	value = posmod(value * 1103515245 + 12345, 2147483647)
	_ambient_hash_cache[seed] = value
	return value

func _ambient_hash01(seed: int) -> float:
	if _ambient_hash01_cache.has(seed):
		return float(_ambient_hash01_cache.get(seed, 0.0))
	var value: float = float(posmod(_ambient_hash(seed), 10000)) / 10000.0
	_ambient_hash01_cache[seed] = value
	return value

func _prepare_ambient_hash_cache(element_id: String) -> void:
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	var room_key: String = "%d,%d|%s" % [room_coord.x, room_coord.y, element_id]
	if room_key == _ambient_hash_cache_room_key:
		return
	_ambient_hash_cache_room_key = room_key
	_ambient_hash_cache.clear()
	_ambient_hash01_cache.clear()

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
	var cycle: float = _ambient_cycle(seed + 101, time_seconds, _ambient_particle_speed(element_id, seed) * ElementalIntensityRules.ambient_speed_scale(_ambient_intensity(element_id)))
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
	var intensity_opacity: float = ElementalIntensityRules.ambient_opacity_scale(_ambient_intensity(element_id))
	if element_id == "lightning":
		var pulse: float = 1.0 - clampf(absf(cycle - 0.16) / 0.24, 0.0, 1.0)
		return clampf(pulse * AMBIENT_PARTICLE_OPACITY * intensity_opacity, 0.0, 1.0)
	if element_id == "air":
		return clampf(_ambient_particle_alpha(cycle) * AMBIENT_PARTICLE_OPACITY * intensity_opacity, 0.0, 1.0)
	var floor_alpha: float = 0.12 if element_id in ["fire", "ice"] else 0.08
	return clampf(lerpf(floor_alpha, 1.0, _ambient_particle_alpha(cycle)) * AMBIENT_PARTICLE_OPACITY * intensity_opacity, 0.0, 1.0)

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
	if _ambient_batch_active:
		_queue_ambient_particle_sprite(texture, point, draw_size, rotation, alpha, modulate)
		return
	draw_set_transform(point, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, Color(modulate.r, modulate.g, modulate.b, modulate.a * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _begin_ambient_particle_batch(element_id: String) -> void:
	if not _ambient_particle_batch_enabled:
		_ambient_batch_active = false
		return
	_ensure_ambient_combined_atlas(element_id)
	_ambient_batch_active = _ambient_combined_atlas != null
	_ambient_batch_vertices = PackedVector3Array()
	_ambient_batch_uvs = PackedVector2Array()
	_ambient_batch_colors = PackedColorArray()
	_ambient_batch_indices = PackedInt32Array()

func _queue_ambient_particle_sprite(texture: Texture2D, point: Vector2, draw_size: Vector2, rotation: float, alpha: float, modulate: Color) -> void:
	if texture == null or alpha <= 0.0 or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var uv_rect: Rect2 = _ambient_combined_uv_rect(texture)
	if uv_rect.size.x <= 0.0 or uv_rect.size.y <= 0.0:
		return
	var axis_x := Vector2(cos(rotation), sin(rotation)) * draw_size.x
	var axis_y := Vector2(-sin(rotation), cos(rotation)) * draw_size.y
	var first_vertex: int = _ambient_batch_vertices.size()
	for vertex: Vector2 in [
		point - axis_x * 0.5 - axis_y * 0.5,
		point + axis_x * 0.5 - axis_y * 0.5,
		point + axis_x * 0.5 + axis_y * 0.5,
		point - axis_x * 0.5 + axis_y * 0.5
	]:
		_ambient_batch_vertices.append(Vector3(vertex.x, vertex.y, 0.0))
	_ambient_batch_uvs.append(uv_rect.position)
	_ambient_batch_uvs.append(Vector2(uv_rect.end.x, uv_rect.position.y))
	_ambient_batch_uvs.append(uv_rect.end)
	_ambient_batch_uvs.append(Vector2(uv_rect.position.x, uv_rect.end.y))
	var color := Color(modulate.r, modulate.g, modulate.b, modulate.a * alpha)
	for _index: int in range(4):
		_ambient_batch_colors.append(color)
	for offset: int in [0, 1, 2, 0, 2, 3]:
		_ambient_batch_indices.append(first_vertex + offset)

func _flush_ambient_particle_batch() -> void:
	_ambient_batch_active = false
	if _ambient_batch_vertices.is_empty() or _ambient_combined_atlas == null:
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _ambient_batch_vertices
	arrays[Mesh.ARRAY_TEX_UV] = _ambient_batch_uvs
	arrays[Mesh.ARRAY_COLOR] = _ambient_batch_colors
	arrays[Mesh.ARRAY_INDEX] = _ambient_batch_indices
	_ambient_batch_mesh = ArrayMesh.new()
	_ambient_batch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh(_ambient_batch_mesh, _ambient_combined_atlas)

func _ensure_ambient_combined_atlas(element_id: String) -> void:
	if _ambient_combined_atlas != null and element_id == _ambient_combined_atlas_element_id:
		return
	_ambient_combined_atlas = null
	_ambient_combined_atlas_regions.clear()
	_ambient_combined_atlas_element_id = element_id
	var sources: Array[Texture2D]
	for variant_index: int in range(AMBIENT_PARTICLE_ATLAS_COLUMNS):
		_append_unique_ambient_atlas_source(sources, _ambient_particle_texture(element_id, variant_index))
		_append_unique_ambient_atlas_source(sources, _ambient_particle_glow_texture(element_id, variant_index))
		if element_id == "fire":
			_append_unique_ambient_atlas_source(sources, _ambient_fire_soft_texture(variant_index))
	if element_id == "air":
		for variant_index: int in range(AMBIENT_AIR_WISP_VARIANTS):
			_append_unique_ambient_atlas_source(sources, _ambient_air_wisp_texture(variant_index, AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
			_append_unique_ambient_atlas_source(sources, _ambient_air_wisp_soft_texture(variant_index))
			_append_unique_ambient_atlas_source(sources, _ambient_air_wisp_glow_texture(variant_index, AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
	if sources.is_empty():
		return
	const ATLAS_GAP: int = 2
	var atlas_width: int = ATLAS_GAP
	var atlas_height: int = 1
	for source: Texture2D in sources:
		atlas_width += source.get_width() + ATLAS_GAP
		atlas_height = maxi(atlas_height, source.get_height() + ATLAS_GAP * 2)
	var image := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var cursor_x: int = ATLAS_GAP
	for source: Texture2D in sources:
		var source_image: Image = source.get_image()
		if source_image == null or source_image.is_empty():
			_ambient_combined_atlas_regions.clear()
			return
		if source_image.get_format() != Image.FORMAT_RGBA8:
			source_image.convert(Image.FORMAT_RGBA8)
		image.blit_rect(source_image, Rect2i(Vector2i.ZERO, source_image.get_size()), Vector2i(cursor_x, ATLAS_GAP))
		_ambient_combined_atlas_regions[source.get_instance_id()] = Rect2i(cursor_x, ATLAS_GAP, source.get_width(), source.get_height())
		cursor_x += source.get_width() + ATLAS_GAP
	_ambient_combined_atlas = ImageTexture.create_from_image(image)

func _append_unique_ambient_atlas_source(sources: Array[Texture2D], source: Texture2D) -> void:
	if source != null and not sources.has(source):
		sources.append(source)

func _ambient_combined_uv_rect(texture: Texture2D) -> Rect2:
	var packed_region: Rect2 = _ambient_combined_atlas_regions.get(texture.get_instance_id(), Rect2()) as Rect2
	if packed_region.size.x <= 0.0 or _ambient_combined_atlas == null:
		return Rect2()
	var atlas_size: Vector2 = _ambient_combined_atlas.get_size()
	return Rect2(packed_region.position / atlas_size, packed_region.size / atlas_size)

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
	_draw_floor_tile_depth(tile)
	draw_colored_polygon(polygon, base_color)
	var texture: Texture2D = _floor_texture_for_tile(tile_id, tile)
	if texture != null:
		var tile_width: float = _tile_width()
		var tile_height: float = _tile_height()
		var rect := Rect2(_tile_center(tile) - Vector2(tile_width * 0.5, tile_height * 0.5), Vector2(tile_width, tile_height))
		draw_texture_rect(texture, rect, false)
	_draw_floor_moss_overlay(tile)
	draw_polyline(polygon, GRID_OUTLINE, 2.0, true)

func _draw_floor_tile_depth(tile: Vector2i) -> void:
	var faces: Array[PackedVector2Array] = _tile_depth_faces(tile)
	for face_index: int in range(faces.size()):
		var face: PackedVector2Array = faces[face_index]
		var face_color: Color = TILE_DEPTH_RIGHT_FACE if face_index == 0 else TILE_DEPTH_LEFT_FACE
		draw_colored_polygon(face, face_color)
		if face.size() >= 4:
			draw_polyline(
				PackedVector2Array([face[0], face[1], face[2], face[3], face[0]]),
				TILE_DEPTH_EDGE,
				1.5,
				true
			)

func _tile_depth_faces(tile: Vector2i) -> Array[PackedVector2Array]:
	var faces: Array[PackedVector2Array] = []
	var polygon: PackedVector2Array = _tile_polygon(tile)
	if polygon.size() < 4:
		return faces
	var depth_offset := Vector2(0.0, _tile_height() * TILE_DEPTH_HEIGHT_RATIO)
	faces.append(PackedVector2Array([
		polygon[1],
		polygon[2],
		polygon[2] + depth_offset,
		polygon[1] + depth_offset
	]))
	faces.append(PackedVector2Array([
		polygon[2],
		polygon[3],
		polygon[3] + depth_offset,
		polygon[2] + depth_offset
	]))
	return faces

func _draw_tile_overlays(tile: Vector2i) -> void:
	var polygon: PackedVector2Array = _tile_polygon(tile)
	if tile == presentation.get("objective_leader_tile", Vector2i(-1, -1)):
		_draw_objective_leader_beacon(tile)
	if _objective_exit_tiles_lookup_cache.has(tile):
		_draw_objective_exit_target(tile)
	if exit_tiles.has(tile):
		draw_colored_polygon(polygon, EXIT_HIGHLIGHT)
		if bool(presentation.get("pulse_exit_tiles", false)):
			_draw_exit_tile_pulse(tile)
	if _focus_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, presentation.get("focus_color", FOCUS_HIGHLIGHT))
	if _move_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, MOVE_HIGHLIGHT)
		_draw_tile_ring(tile, Color(0.60, 0.91, 0.94, 0.58), 2.0, 0.86)
	if _ability_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, ABILITY_HIGHLIGHT)
		_draw_tile_ring(tile, Color(0.55, 0.92, 0.48, 0.62), 2.0, 0.86)
	if _attack_tiles_lookup_cache.has(tile):
		_draw_attack_tile_highlight(tile)
	if _projected_attack_tiles_lookup_cache.has(tile):
		draw_colored_polygon(polygon, Color(0.98, 0.30, 0.20, 0.18))
		_draw_tile_ring(tile, Color(1.0, 0.42, 0.25, 0.94), 3.6, 0.78)
	if tile == presentation.get("projected_destination", Vector2i(-999, -999)):
		_draw_tile_ring(tile, Color(0.95, 0.78, 0.43, 0.98), 4.0, 0.92)
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

func _draw_attack_tile_highlight(tile: Vector2i) -> void:
	draw_colored_polygon(_tile_polygon(tile), ATTACK_HIGHLIGHT)
	if bool(presentation.get("pulse_attack_tiles", false)):
		_draw_attack_target_pulse(tile)

func _large_enemy_attack_highlight_tiles(units_to_draw: Array[Dictionary]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for unit: Dictionary in units_to_draw:
		if str(unit.get("role", "")) != "enemy":
			continue
		var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
		if maxi(1, footprint.x) * maxi(1, footprint.y) <= 1:
			continue
		var footprint_tiles: Array[Vector2i] = _unit_footprint_tiles(unit)
		var targetable: bool = false
		for tile: Vector2i in footprint_tiles:
			if attack_tiles.has(tile):
				targetable = true
				break
		if not targetable:
			continue
		for tile: Vector2i in footprint_tiles:
			if not result.has(tile):
				result.append(tile)
	return result

func _draw_large_enemy_attack_highlights(units_to_draw: Array[Dictionary]) -> void:
	for tile: Vector2i in _large_enemy_attack_highlight_tiles(units_to_draw):
		_draw_attack_tile_highlight(tile)

func _draw_exit_tile_pulse(tile: Vector2i) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * TAU * 1.15)
	var alpha: float = lerpf(0.26, 0.70, pulse)
	var width: float = lerpf(1.4, 3.0, pulse)
	var scale: float = lerpf(0.84, 0.98, pulse)
	_draw_tile_ring(tile, Color(1.0, 0.83, 0.38, alpha), width, scale)

func _draw_objective_exit_target(tile: Vector2i) -> void:
	var polygon: PackedVector2Array = _tile_polygon(tile)
	draw_colored_polygon(polygon, Color(0.15, 0.70, 0.72, 0.30))
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time_seconds * TAU * 1.05)
	_draw_tile_ring(tile, Color(0.52, 0.95, 0.91, lerpf(0.66, 0.96, pulse)), lerpf(2.5, 4.0, pulse), 0.90)
	var texture: Texture2D = AssetLoader.load_texture(CombatObjectiveRules.icon_path(CombatObjectiveRules.REACH_EXIT))
	if texture == null:
		return
	var icon_size: float = clampf(_tile_width() * 0.30, 34.0, 50.0)
	var center: Vector2 = _tile_center(tile) - Vector2(0.0, _tile_height() * 0.03)
	var icon_rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(texture, icon_rect, false, Color(0.88, 1.0, 0.96, 0.92))
	_register_tooltip(icon_rect, "Objective threshold · Reach this tile to clear the encounter.")

func _draw_objective_leader_beacon(tile: Vector2i) -> void:
	draw_colored_polygon(_tile_polygon(tile), Color(0.62, 0.30, 0.08, 0.22))
	_draw_tile_ring(tile, Color(0.98, 0.73, 0.28, 0.92), 3.2, 0.93)
	var texture: Texture2D = AssetLoader.load_texture(CombatObjectiveRules.icon_path(CombatObjectiveRules.KILL_LEADER))
	if texture == null:
		return
	var icon_size: float = clampf(_tile_width() * 0.21, 28.0, 40.0)
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * 0.18)
	var icon_rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(texture, icon_rect, false, Color(1.0, 0.90, 0.70, 0.88))
	_register_tooltip(icon_rect, "Marked leader · Defeat this enemy to clear the encounter.")

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

func _board_tile_is_visible_to_player(tile: Vector2i) -> bool:
	var visible_tiles: Variant = presentation.get("umbra_visible_tiles", null)
	if typeof(visible_tiles) != TYPE_ARRAY:
		return true
	return (visible_tiles as Array).has(tile)

func _draw_ground_items_below_path(tiles: Array[Vector2i]) -> void:
	# Traps and ordinary loot lie on the floor, so the raised route ribbon crosses
	# over them. Floating equipment remains in _draw_tile_props with units and is
	# intentionally painted after the route.
	for tile: Vector2i in tiles:
		if not _board_tile_is_visible_to_player(tile):
			continue
		for loot_var: Variant in _entries_for_tile(_loot_by_tile, combat_state.get("loot", []), "pos", tile):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var
			if bool(loot.get("claimed", false)) or not _loot_renders_below_path(loot):
				continue
			var loot_texture: Texture2D = _loot_texture(loot)
			if loot_texture == null:
				continue
			var loot_rect: Rect2 = _loot_rect_for_tile(tile, loot_texture, loot)
			_draw_rect_ground_shadow(tile, loot_rect, 0.62, 0.18, 0.08)
			draw_texture_rect(loot_texture, loot_rect, false)
			_register_tooltip(loot_rect.grow(4.0), _loot_tooltip_text(loot))
		for trap_var: Variant in _entries_for_tile(_traps_by_tile, combat_state.get("traps", []), "pos", tile):
			if typeof(trap_var) == TYPE_DICTIONARY:
				_draw_trap_marker(trap_var as Dictionary)

func _draw_scene_props_for_tile(tile: Vector2i, obstruction_entries: Array = []) -> void:
	for prop_var: Variant in _entries_for_tile(_scene_props_by_tile, presentation.get("scene_props", []), "tile", tile):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
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
		if not _board_tile_is_visible_to_player(terrain.get("pos", Vector2i(-1, -1))):
			continue
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
		if not _board_tile_is_visible_to_player(loot.get("pos", Vector2i(-1, -1))):
			continue
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
		if not _board_tile_is_visible_to_player(trap_tile):
			continue
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
	for terrain_var: Variant in _entries_for_tile(_terrain_by_tile, combat_state.get("terrain", []), "pos", tile):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if not _board_tile_is_visible_to_player(terrain.get("pos", Vector2i(-1, -1))):
			continue
		if int(terrain.get("hp", 0)) <= 0:
			continue
		_draw_terrain_object(terrain, obstruction_entries)
	for destruction_var: Variant in presentation.get("terrain_destruction_units", []):
		if typeof(destruction_var) != TYPE_DICTIONARY:
			continue
		var destroyed_terrain: Dictionary = destruction_var
		if destroyed_terrain.get("pos", Vector2i(-1, -1)) != tile:
			continue
		if not _board_tile_is_visible_to_player(tile):
			continue
		_draw_terrain_destruction(destroyed_terrain, obstruction_entries)
	for loot_var: Variant in _entries_for_tile(_loot_by_tile, combat_state.get("loot", []), "pos", tile):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if not _board_tile_is_visible_to_player(loot.get("pos", Vector2i(-1, -1))):
			continue
		if bool(loot.get("claimed", false)):
			continue
		var loot_texture: Texture2D = _loot_texture(loot)
		if loot_texture == null:
			continue
		var loot_rect: Rect2 = _loot_rect_for_tile(tile, loot_texture, loot)
		if _loot_renders_below_path(loot):
			continue
		_draw_equipment_pickup(tile, loot_rect, loot_texture, loot)
		_register_tooltip(loot_rect.grow(8.0), _loot_tooltip_text(loot))

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
	var cache_key: int = texture.get_instance_id()
	if _texture_used_rect_cache.has(cache_key):
		return _texture_used_rect_cache.get(cache_key, Rect2i())
	var used_rect: Rect2i = AssetLoader.texture_used_rect(texture)
	_texture_used_rect_cache[cache_key] = used_rect
	return used_rect

func _draw_door_icon(icon_texture: Texture2D, icon_id: String, door_texture: Texture2D, door_draw_rect: Rect2, tint: Color = Color.WHITE) -> void:
	if icon_texture == null:
		return
	var visual_rect: Rect2 = _door_icon_visual_rect(door_texture, door_draw_rect)
	var center: Vector2 = visual_rect.get_center()
	var radius: float = visual_rect.size.x * 0.5
	var icon_size: float = _door_icon_size()
	var accent: Color = ElementData.door_tint(icon_id) if ElementData.is_elemental(icon_id) else Color("d3b78e")
	draw_circle(center, radius, Color(0.07, 0.05, 0.04, 0.86 * tint.a))
	draw_arc(center, radius, 0.0, TAU, 28, Color(accent.r, accent.g, accent.b, 0.88 * tint.a), 2.0, true)
	var icon_rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(icon_texture, icon_rect, false, tint)

func _door_icon_size() -> float:
	return clampf(_tile_width() * DOOR_ICON_SIZE_SCALE, DOOR_ICON_MIN_SIZE, DOOR_ICON_MAX_SIZE)

func _door_icon_visual_rect(door_texture: Texture2D, door_draw_rect: Rect2) -> Rect2:
	var door_used_rect: Rect2 = _texture_used_draw_rect(door_texture, door_draw_rect)
	var icon_size: float = _door_icon_size()
	var center := Vector2(
		door_used_rect.get_center().x,
		door_used_rect.position.y - icon_size * 0.5 - _tile_height() * DOOR_ICON_FLOAT_GAP_SCALE
	)
	var radius: float = icon_size * 0.56
	return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)

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

func _loot_renders_below_path(loot: Dictionary) -> bool:
	return not _is_equipment_loot(loot)

func _draw_equipment_pickup(tile: Vector2i, loot_rect: Rect2, loot_texture: Texture2D, loot: Dictionary) -> void:
	var accent: Color = _equipment_loot_accent(loot)
	var glow_color: Color = _equipment_pickup_glow_color(accent)
	var pulse: float = _equipment_pickup_pulse(tile, loot)
	var bobbed_rect: Rect2 = Rect2(loot_rect.position + _equipment_pickup_bob_offset(pulse), loot_rect.size)
	var disintegration_progress: float = _missed_equipment_disintegration_progress(loot)
	if disintegration_progress >= 0.0:
		_draw_missed_equipment_disintegration(tile, bobbed_rect, loot_texture, loot, disintegration_progress)
		return
	_draw_equipment_pickup_beacon(tile, accent, glow_color, pulse)
	_draw_rect_ground_shadow(tile, loot_rect, 0.54, 0.15, 0.10)
	_draw_equipment_pickup_outline(loot_texture, bobbed_rect, glow_color, pulse)
	draw_texture_rect(loot_texture, bobbed_rect, false)

func _missed_equipment_disintegration_progress(loot: Dictionary) -> float:
	var equipment_id: String = str(loot.get("equipment_id", ""))
	if equipment_id.is_empty() or not (presentation.get("missed_equipment_ids", []) as Array).has(equipment_id):
		return -1.0
	return clampf(float(presentation.get("missed_equipment_progress", 0.0)), 0.0, 1.0)

func _draw_missed_equipment_disintegration(tile: Vector2i, loot_rect: Rect2, loot_texture: Texture2D, loot: Dictionary, progress: float) -> void:
	var corruption: float = smoothstep(0.0, 0.58, progress)
	var fade: float = 1.0 - smoothstep(0.28, 1.0, progress)
	var jitter: float = sin(progress * 31.0 + _equipment_loot_phase(tile, loot)) * _tile_width() * 0.018 * corruption
	var corrupted_rect: Rect2 = Rect2(loot_rect.position + Vector2(jitter, -progress * _tile_height() * 0.05), loot_rect.size)
	_draw_tile_diamond_fill(tile, Color(0.18, 0.10, 0.17, 0.18 * (1.0 - progress)), 0.64 - progress * 0.12)
	_draw_rect_ground_shadow(tile, loot_rect, 0.48 * fade, 0.14, 0.08)
	if fade > 0.01:
		var tint: Color = Color(1.0, 1.0, 1.0, fade).lerp(Color(0.24, 0.16, 0.22, fade), corruption)
		_draw_disintegrating_equipment_texture(loot_texture, corrupted_rect, tint, progress)
	_draw_missed_equipment_cinders(tile, loot_rect, loot, progress)

func _draw_disintegrating_equipment_texture(texture: Texture2D, draw_rect: Rect2, tint: Color, progress: float) -> void:
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var slice_count: int = 7
	for index: int in range(slice_count):
		var source_y: float = source_size.y * float(index) / float(slice_count)
		var next_source_y: float = source_size.y * float(index + 1) / float(slice_count)
		var dest_y: float = draw_rect.position.y + draw_rect.size.y * float(index) / float(slice_count)
		var next_dest_y: float = draw_rect.position.y + draw_rect.size.y * float(index + 1) / float(slice_count)
		var slice_progress: float = clampf((progress - float(index) * 0.035) / 0.78, 0.0, 1.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var drift := Vector2(side * draw_rect.size.x * 0.12 * slice_progress, -draw_rect.size.y * 0.16 * slice_progress * slice_progress)
		var slice_tint: Color = tint
		slice_tint.a *= 1.0 - smoothstep(0.52, 1.0, slice_progress)
		draw_texture_rect_region(
			texture,
			Rect2(Vector2(draw_rect.position.x, dest_y) + drift, Vector2(draw_rect.size.x, next_dest_y - dest_y + 1.0)),
			Rect2(Vector2(0.0, source_y), Vector2(source_size.x, next_source_y - source_y)),
			slice_tint
		)

func _draw_missed_equipment_cinders(tile: Vector2i, loot_rect: Rect2, loot: Dictionary, progress: float) -> void:
	var center: Vector2 = loot_rect.get_center()
	var phase: float = _equipment_loot_phase(tile, loot)
	for index: int in range(24):
		var start: float = float(index % 9) / 12.0
		var particle_progress: float = clampf((progress - start * 0.42) / 0.72, 0.0, 1.0)
		if particle_progress <= 0.0:
			continue
		var angle: float = phase + float(index) * 2.399
		var spread: float = loot_rect.size.x * (0.10 + float((index * 7) % 13) / 13.0 * 0.44)
		var drift := Vector2(cos(angle) * spread * particle_progress, -loot_rect.size.y * (0.12 + 0.80 * particle_progress))
		drift.x += sin(particle_progress * 8.0 + angle) * loot_rect.size.x * 0.08
		var particle_size: float = maxf(3.0, loot_rect.size.x * (0.035 + float(index % 4) * 0.010)) * (1.0 - particle_progress * 0.38)
		var alpha: float = sin(particle_progress * PI) * (0.72 + float(index % 3) * 0.12)
		var cinder_color: Color = Color("c05b38").lerp(Color("4a3a43"), particle_progress)
		cinder_color.a = alpha
		draw_rect(Rect2(center + drift - Vector2.ONE * particle_size * 0.5, Vector2.ONE * particle_size), cinder_color)

func _draw_equipment_pickup_beacon(tile: Vector2i, accent: Color, glow_color: Color, pulse: float) -> void:
	var accent_glow: Color = accent.lightened(0.36)
	_draw_tile_diamond_fill(tile, Color(glow_color.r, glow_color.g, glow_color.b, 0.10 + pulse * 0.06), 0.70 + pulse * 0.05)
	_draw_tile_ring(tile, Color(glow_color.r, glow_color.g, glow_color.b, 0.46 + pulse * 0.22), 3.0 + pulse * 1.1, 0.76 + pulse * 0.05)
	_draw_tile_ring(tile, Color(accent_glow.r, accent_glow.g, accent_glow.b, 0.56 + pulse * 0.18), 1.6 + pulse * 0.5, 0.58 + pulse * 0.03)

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

func _draw_tile_diamond_fill(tile: Vector2i, color: Color, scale: float) -> void:
	var center: Vector2 = _tile_center(tile)
	var tile_width: float = _tile_width() * scale
	var tile_height: float = _tile_height() * scale
	var points := PackedVector2Array([
		center + Vector2(0.0, -tile_height * 0.5),
		center + Vector2(tile_width * 0.5, 0.0),
		center + Vector2(0.0, tile_height * 0.5),
		center + Vector2(-tile_width * 0.5, 0.0)
	])
	draw_colored_polygon(points, color)

func _equipment_pickup_pulse(tile: Vector2i, loot: Dictionary) -> float:
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	return 0.5 + 0.5 * sin(time_seconds * 2.65 + _equipment_loot_phase(tile, loot))

func _equipment_pickup_bob_offset(pulse: float) -> Vector2:
	return Vector2(0.0, -_tile_height() * (0.035 + pulse * 0.060))

func _equipment_loot_phase(tile: Vector2i, loot: Dictionary) -> float:
	var equipment_id: String = str(loot.get("equipment_id", ""))
	var seed: int = abs(tile.x * 92821 + tile.y * 68917 + equipment_id.length() * 131)
	return (float(seed % 1000) / 1000.0) * TAU

func _equipment_loot_accent(loot: Dictionary) -> Color:
	return Color(GameData.equipment_accent(str(loot.get("equipment_id", ""))))

func _equipment_pickup_glow_color(accent: Color) -> Color:
	return Color("f1d18b").lerp(accent.lightened(0.24), 0.34)

func _loot_draw_width(loot: Dictionary) -> float:
	# Board objects share the zoomed tile-space basis used by actor frames. Fixed
	# pixel widths (and equipment's old min/max clamp) made pickups appear to
	# shrink relative to actors, or stop growing altogether, when navigating in.
	var width_scale: float = EQUIPMENT_LOOT_TILE_WIDTH_SCALE if _is_equipment_loot(loot) else LOOT_DRAW_TILE_WIDTH_SCALE
	return _tile_width() * width_scale

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
			return "equipment:%s" % equipment_id
	return ""

func _equipment_loot_fallback_tooltip(equipment_id: String) -> String:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var item_name: String = str(item.get("name", equipment_id))
	var slot: String = str(item.get("slot", ""))
	return "%s\n%s" % [item_name, slot.capitalize()]

func _loot_texture(loot: Dictionary) -> Texture2D:
	if str(loot.get("kind", "")) == "equipment":
		var item: Dictionary = GameData.equipment_def(str(loot.get("equipment_id", "")))
		return AssetLoader.load_texture(str(item.get("icon_path", "")))
	return _loot_textures.get(str(loot.get("kind", "")), null)

func _draw_terrain_object(terrain: Dictionary, obstruction_entries: Array = []) -> void:
	var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
	if tile.x < 0 or not _board_tile_is_visible_to_player(tile):
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

func _draw_terrain_destruction(terrain: Dictionary, obstruction_entries: Array = []) -> void:
	var texture: Texture2D = _terrain_destruction_texture(terrain)
	if texture == null:
		return
	var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
	if tile.x < 0 or not _board_tile_is_visible_to_player(tile):
		return
	var terrain_kind: String = str(terrain.get("kind", ""))
	var terrain_rect: Rect2 = _terrain_rect_for_tile(tile, texture, terrain_kind)
	var tint: Color = _foreground_blocker_tint("terrain", tile, terrain_rect, obstruction_entries)
	var progress: float = clampf(float(terrain.get("destruction_progress", 0.0)), 0.0, 1.0)
	tint.a *= 1.0 - smoothstep(0.84, 1.0, progress)
	if progress < 0.84:
		_draw_rect_ground_shadow(tile, terrain_rect, 0.70, 0.24, 0.16)
	draw_texture_rect(texture, terrain_rect, false, tint)

func _terrain_rect_for_tile(tile: Vector2i, texture: Texture2D, terrain_kind: String = "") -> Rect2:
	var draw_width: float = _tile_width() * _terrain_draw_width_scale(terrain_kind)
	var draw_height: float = draw_width
	if texture != null and texture.get_size().x > 0.0:
		draw_height = draw_width * texture.get_size().y / texture.get_size().x
	var center: Vector2 = _tile_center(tile)
	var bottom_y: float = center.y + _tile_height() * TERRAIN_DRAW_BASELINE_SCALE
	return Rect2(Vector2(center.x - draw_width * 0.5, bottom_y - draw_height), Vector2(draw_width, draw_height))

func _terrain_draw_width_scale(terrain_kind: String) -> float:
	if terrain_kind == "dragon_spire":
		return 0.72
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
	if not _board_tile_is_visible_to_player(terrain.get("pos", Vector2i(-1, -1))):
		return {}
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
	var terrain_kind: String = str(terrain.get("kind", ""))
	var label: String = "Worldspine" if terrain_kind == "dragon_spire" else "Wooden box" if terrain_kind == "wooden_box" else "Wooden crate"
	return "%s\n%d/%d HP" % [
		label,
		int(terrain.get("hp", 0)),
		int(terrain.get("max_hp", 1))
	]

func _visible_units() -> Array[Dictionary]:
	if _submission_cache_valid:
		return _visible_units_cache
	return _build_visible_units()

func _build_visible_units() -> Array[Dictionary]:
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
			"bleed": int(player_statuses.get("bleed", 0)),
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
			"bleed": 0,
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
			"bleed": 0,
			"freeze": 0,
			"shock": 0,
			"immobilize": false,
			"poison": {},
			"preview": true
		})
	var visible_enemy_ids: Array = presentation.get("visible_enemy_ids", []) as Array
	var filter_enemies_for_umbra: bool = presentation.has("visible_enemy_ids")
	for enemy: Dictionary in combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if filter_enemies_for_umbra and not visible_enemy_ids.has(int(enemy.get("id", -1))):
			continue
		units_to_draw.append({
			"key": "enemy_%d" % int(enemy.get("id", -1)),
			"role": "enemy",
			"id": int(enemy.get("id", -1)),
			"type": str(enemy.get("type", "")),
			"name": str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Enemy")),
			"boss_bar": bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)),
			"is_leader": bool(enemy.get("is_leader", false)),
			"footprint": enemy.get("footprint", Vector2i.ONE),
			"intent": enemy.get("intent", {}),
			"pos": enemy.get("pos", Vector2i.ZERO),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", 1)),
			"block": int(enemy.get("block", 0)),
			"stoneskin": int(enemy.get("stoneskin", 0)),
			"frost_armor": int(enemy.get("frost_armor", 0)),
			"burn": int(enemy.get("burn", 0)),
			"bleed": int(enemy.get("bleed", 0)),
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
		var impact_shake: float = _unit_impact_shake_strength(unit)
		var impact_offset := Vector2.ZERO
		if impact_shake > 0.0:
			impact_offset = Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0 * impact_shake, 0.0)
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

func _draw_unit_huds(units_to_draw: Array[Dictionary]) -> void:
	if not _hud_layout_entries_cache.is_empty():
		_draw_unit_huds_from_layout_cache(units_to_draw)
		return
	var font: Font = get_theme_default_font()
	var reserved_rects: Array[Rect2] = _enemy_hud_reserved_rects(units_to_draw, font)
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
			_draw_leader_marker(unit, health_rect, enemy_layout.get("intent_rect", Rect2()) as Rect2)
			_draw_enemy_intent_layout(enemy_layout, font)
			for rect_var: Variant in enemy_layout.get("occupied_rects", []):
				if typeof(rect_var) == TYPE_RECT2:
					reserved_rects.append(rect_var)
			continue
		_draw_health_bar(unit, health_rect)
		_draw_unit_statuses(unit, health_rect)

func _draw_unit_huds_from_layout_cache(units_to_draw: Array[Dictionary]) -> void:
	var font: Font = get_theme_default_font()
	var units_by_key: Dictionary = {}
	for unit: Dictionary in units_to_draw:
		units_by_key[str(unit.get("key", ""))] = unit
	for entry_var: Variant in _hud_layout_entries_cache:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var unit: Dictionary = units_by_key.get(str(entry.get("actor_key", "")), {}) as Dictionary
		if unit.is_empty():
			continue
		var center: Vector2 = entry.get("center", _unit_center(unit))
		match str(entry.get("kind", "")):
			"npc":
				_draw_npc_nameplate(unit, center)
			"boss":
				_draw_enemy_intent_layout(entry.get("layout", {}) as Dictionary, font)
			"enemy":
				var layout: Dictionary = entry.get("layout", {}) as Dictionary
				var health_rect: Rect2 = entry.get("health_rect", Rect2()) as Rect2
				_draw_enemy_hud_tether(unit, center, layout)
				_draw_health_bar(unit, health_rect)
				_draw_unit_statuses(unit, health_rect)
				_draw_leader_marker(unit, health_rect, layout.get("intent_rect", Rect2()) as Rect2)
				_draw_enemy_intent_layout(layout, font)
			_:
				var health_rect: Rect2 = entry.get("health_rect", Rect2()) as Rect2
				_draw_health_bar(unit, health_rect)
				_draw_unit_statuses(unit, health_rect)

func _rebuild_hud_health_rects_cache() -> bool:
	var performance_phase_started: int = Time.get_ticks_usec() if _submission_performance_instrumentation_enabled else 0
	if not is_inside_tree() or combat_state.is_empty():
		_hud_health_rects_cache.clear()
		_hud_health_rects_source_snapshot.clear()
		_hud_layout_entries_cache.clear()
		return false
	var hud_units: Array[Dictionary] = _hud_layout_units()
	performance_phase_started = _record_submission_performance_phase("hud_units", performance_phase_started)
	var source: Dictionary = {
		"visible_units": hud_units,
		# HUD geometry changes only when pointer hover expands a different enemy's
		# intent. Every empty tile is layout-equivalent, and every tile in a large
		# enemy footprint is equivalent too. Keying by the raw tile forced the dense
		# collision solver to build a distinct layout for every Blink destination.
		"hover_actor_key": _hud_hover_actor_key(hud_units),
		"size": size,
		"navigation_zoom": _navigation_zoom,
		"navigation_pan": _navigation_pan,
		"expanded_enemy_actor_keys": presentation.get("expanded_enemy_actor_keys", []),
		"expand_enemy_intents": presentation.get("expand_enemy_intents", false),
		"show_all_enemy_intents": presentation.get("show_all_enemy_intents", false),
		"unit_draw_tiles": presentation.get("unit_draw_tiles", {}),
		"unit_world_positions": presentation.get("unit_world_positions", {})
	}
	performance_phase_started = _record_submission_performance_phase("hud_source", performance_phase_started)
	if source == _hud_health_rects_source_snapshot:
		return false
	_hud_health_rects_source_snapshot = source.duplicate(true)
	var signature: int = hash(source)
	performance_phase_started = _record_submission_performance_phase("hud_signature", performance_phase_started)
	var cached: Dictionary = _hud_layout_cache_by_signature.get(signature, {}) as Dictionary
	if not cached.is_empty() and cached.get("source", {}) == source:
		_hud_layout_entries_cache = cached.get("entries", []) as Array
		_hud_health_rects_cache = cached.get("health_rects", {}) as Dictionary
		return true
	var built: Dictionary = _build_hud_layout_data(hud_units)
	performance_phase_started = _record_submission_performance_phase("hud_build", performance_phase_started)
	_hud_layout_entries_cache = built.get("entries", []) as Array
	_hud_health_rects_cache = built.get("health_rects", {}) as Dictionary
	_hud_layout_cache_by_signature[signature] = {
		"source": source.duplicate(true),
		"entries": _hud_layout_entries_cache,
		"health_rects": _hud_health_rects_cache
	}
	_hud_layout_cache_order.erase(signature)
	_hud_layout_cache_order.append(signature)
	while _hud_layout_cache_order.size() > HUD_LAYOUT_CACHE_LIMIT:
		var stale_signature: Variant = _hud_layout_cache_order.pop_front()
		_hud_layout_cache_by_signature.erase(stale_signature)
	return true

func _hud_hover_actor_key(hud_units: Array[Dictionary]) -> String:
	if _hover_tile.x < 0:
		return ""
	for unit: Dictionary in hud_units:
		if str(unit.get("role", "")) != "enemy":
			continue
		var origin: Vector2i = unit.get("pos", Vector2i.ZERO)
		var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
		if (
			_hover_tile.x >= origin.x
			and _hover_tile.y >= origin.y
			and _hover_tile.x < origin.x + maxi(1, footprint.x)
			and _hover_tile.y < origin.y + maxi(1, footprint.y)
		):
			return _enemy_hud_actor_key(unit)
	return ""

func _hud_layout_units() -> Array[Dictionary]:
	# Illusion targeting ghosts intentionally have no health bar or intent HUD.
	# Excluding them from the HUD cache key prevents their tile-by-tile movement
	# from rerunning the dense enemy collision/layout solver on every hover.
	var result: Array[Dictionary] = []
	for unit: Dictionary in _visible_units():
		if str(unit.get("role", "")) != "illusion_preview":
			result.append(unit)
	return result

func _clear_hud_layout_signature_cache() -> void:
	_hud_layout_cache_by_signature.clear()
	_hud_layout_cache_order.clear()

func _build_hud_layout_data(units_to_draw: Array[Dictionary]) -> Dictionary:
	var performance_phase_started: int = Time.get_ticks_usec() if _submission_performance_instrumentation_enabled else 0
	var health_rects: Dictionary = {}
	var entries: Array = []
	var font: Font = get_theme_default_font()
	var reserved_rects: Array[Rect2] = _enemy_hud_reserved_rects(units_to_draw, font)
	performance_phase_started = _record_submission_performance_phase("hud_build_reserved", performance_phase_started)
	for unit: Dictionary in units_to_draw:
		if bool(unit.get("death_animation", false)):
			continue
		var role: String = str(unit.get("role", ""))
		if role == "illusion_preview":
			continue
		var center: Vector2 = _unit_center(unit)
		var actor_key: String = str(unit.get("key", ""))
		if role == "npc":
			entries.append({"actor_key": actor_key, "kind": "npc", "center": center})
			continue
		if bool(unit.get("boss_bar", false)):
			var boss_layout: Dictionary = _boss_intent_layout(unit, center, reserved_rects, font)
			entries.append({"actor_key": actor_key, "kind": "boss", "center": center, "layout": boss_layout})
			for rect_var: Variant in boss_layout.get("occupied_rects", []):
				if typeof(rect_var) == TYPE_RECT2:
					reserved_rects.append(rect_var)
			continue
		var health_rect: Rect2 = _unit_health_bar_rect(unit, center)
		if role == "enemy":
			var enemy_layout: Dictionary = _enemy_hud_layout(unit, center, reserved_rects, font)
			health_rect = enemy_layout.get("health_rect", health_rect)
			entries.append({"actor_key": actor_key, "kind": "enemy", "center": center, "health_rect": health_rect, "layout": enemy_layout})
			for rect_var: Variant in enemy_layout.get("occupied_rects", []):
				if typeof(rect_var) == TYPE_RECT2:
					reserved_rects.append(rect_var)
		else:
			entries.append({"actor_key": actor_key, "kind": "unit", "center": center, "health_rect": health_rect})
		if not actor_key.is_empty():
			health_rects[actor_key] = health_rect
	_record_submission_performance_phase("hud_build_units", performance_phase_started)
	return {"entries": entries, "health_rects": health_rects}

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
	var display_hp: int = _health_bar_fill_hp(unit, preview)
	var role: String = str(unit.get("role", ""))
	var fill_color: Color = ILLUSION_BAR_FILL if role == "illusion" else PLAYER_BAR_FILL if role == "player" else ENEMY_BAR_FILL
	var visual_style: StringName = _health_bar_visual_style(unit)
	var content_rect: Rect2 = _health_bar_content_rect(unit, rect)
	SegmentedHealthBar.draw_bar(
		self,
		content_rect,
		float(display_hp),
		float(maxi(1, int(unit.get("max_hp", 1)))),
		_health_bar_segment_count(int(unit.get("max_hp", 1))),
		Color("160f17") if visual_style == HEALTH_BAR_STYLE_UMBRA else Color("191512"),
		fill_color,
		Color("cf6469") if visual_style == HEALTH_BAR_STYLE_UMBRA else Color("9de2ce") if visual_style == HEALTH_BAR_STYLE_LIGHT else Color("f5efdf"),
		Color("5b405f") if visual_style == HEALTH_BAR_STYLE_UMBRA else Color("8f7345") if visual_style == HEALTH_BAR_STYLE_LIGHT else Color("eed3a6"),
		Color(0.0, 0.0, 0.0, 0.45),
		1.0,
		1.0
	)
	var frame_texture: Texture2D = _health_bar_frame_textures.get(visual_style, null) as Texture2D
	if frame_texture != null:
		draw_texture_rect(frame_texture, rect, false)
	var defer_preview_overlay: bool = _health_bar_defers_damage_preview(preview)
	if _damage_preview_shows_lost_hp(preview) and not defer_preview_overlay:
		_draw_health_damage_preview(unit, content_rect, preview)
	if font != null and not defer_preview_overlay:
		_draw_health_bar_text(unit, content_rect, preview, font)
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

func _health_bar_defers_damage_preview(preview: Dictionary) -> bool:
	# Unit health bars are only drawn during the HUD phase. Always defer a
	# nonlethal preview so the one final HUD composite works identically for the
	# retained HUD child and the monolithic fallback renderer.
	return _damage_preview_shows_lost_hp(preview)

func _draw_leader_marker(unit: Dictionary, health_rect: Rect2, intent_rect: Rect2 = Rect2()) -> void:
	if not bool(unit.get("is_leader", false)):
		return
	var marker_rect: Rect2 = _leader_marker_rect(unit, health_rect, intent_rect)
	draw_rect(marker_rect, Color(0.12, 0.055, 0.045, 0.96), true)
	draw_rect(marker_rect, Color("e4b65f"), false, 2.0)
	var texture: Texture2D = AssetLoader.load_texture(CombatObjectiveRules.icon_path(CombatObjectiveRules.KILL_LEADER))
	if texture != null:
		var icon_rect := Rect2(marker_rect.position + Vector2(3.0, 2.0), Vector2(20.0, 20.0))
		draw_texture_rect(texture, icon_rect, false)
	var font: Font = get_theme_default_font()
	if font != null:
		draw_string(font, marker_rect.position + Vector2(24.0, 17.0), "LEADER", HORIZONTAL_ALIGNMENT_CENTER, 61.0, 11, Color("ffe2a3"))
	_register_tooltip(marker_rect, "Leader · Defeating this marked enemy clears the encounter immediately.")

func _draw_unit_damage_preview_overlays(units_to_draw: Array[Dictionary]) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	for unit: Dictionary in units_to_draw:
		var preview: Dictionary = _unit_damage_preview(unit)
		if not _damage_preview_shows_lost_hp(preview):
			continue
		var actor_key: String = str(unit.get("key", ""))
		var health_rect: Rect2 = _hud_health_rects_cache.get(actor_key, Rect2()) as Rect2
		if health_rect.size.x <= 0.0 or health_rect.size.y <= 0.0:
			continue
		var content_rect: Rect2 = _health_bar_content_rect(unit, health_rect)
		_draw_health_damage_preview(unit, content_rect, preview)
		_draw_health_bar_text(unit, content_rect, preview, font)

func _draw_health_bar_text(unit: Dictionary, rect: Rect2, preview: Dictionary, font: Font) -> void:
	var display_hp: int = _health_bar_fill_hp(unit, preview)
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
			10,
			Color("140f0b")
		)
	draw_string(
		font,
		text_baseline,
		hp_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		10,
		text_color
	)

func _health_bar_segment_count(max_hp_value: int) -> int:
	return SegmentedHealthBar.segment_count_for_max_hp(float(maxi(1, max_hp_value)))

func _health_bar_visual_style(unit: Dictionary) -> StringName:
	match str(unit.get("role", "")):
		"player":
			return HEALTH_BAR_STYLE_LIGHT
		"enemy":
			return HEALTH_BAR_STYLE_UMBRA
		_:
			return HEALTH_BAR_STYLE_PLAIN

func _health_bar_content_rect(unit: Dictionary, rect: Rect2) -> Rect2:
	var insets: Vector4
	match _health_bar_visual_style(unit):
		HEALTH_BAR_STYLE_LIGHT:
			insets = PLAYER_HEALTH_CONTENT_INSETS
		HEALTH_BAR_STYLE_UMBRA:
			insets = ENEMY_HEALTH_CONTENT_INSETS
		_:
			return rect
	return Rect2(
		rect.position + Vector2(rect.size.x * insets.x, rect.size.y * insets.y),
		Vector2(
			rect.size.x * (1.0 - insets.x - insets.z),
			rect.size.y * (1.0 - insets.y - insets.w)
		)
	)

func _health_bar_fill_hp(unit: Dictionary, preview: Dictionary) -> int:
	return int(preview.get("hp", unit.get("hp", 0)))

func _damage_preview_shows_lost_hp(preview: Dictionary) -> bool:
	return not preview.is_empty() and not bool(preview.get("lethal", false))

func _draw_health_damage_preview(unit: Dictionary, rect: Rect2, preview: Dictionary) -> void:
	var current_hp: float = float(unit.get("hp", 0))
	var next_hp: float = float(preview.get("hp", current_hp))
	var max_hp: float = maxf(1.0, float(unit.get("max_hp", 1)))
	var current_ratio: float = clampf(current_hp / max_hp, 0.0, 1.0)
	var next_ratio: float = clampf(next_hp / max_hp, 0.0, 1.0)
	if current_ratio > next_ratio:
		var time_seconds: float = float(presentation.get("damage_preview_time_seconds", float(Time.get_ticks_msec()) / 1000.0))
		var pulse: float = 0.55 + 0.45 * sin(time_seconds * 10.0)
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
	if _submission_cache_valid:
		return _damage_preview_cache
	return _build_damage_preview_map(presentation)

func _unit_damage_preview_active() -> bool:
	for unit: Dictionary in _visible_units():
		if not _unit_damage_preview(unit).is_empty():
			return true
	return false

func _build_damage_preview_map(source_presentation: Dictionary) -> Dictionary:
	var effect: Dictionary = source_presentation.get("effect", {})
	var preview_map: Dictionary = (source_presentation.get("damage_preview", {}) as Dictionary).duplicate(true)
	var effect_preview_map: Dictionary = effect.get("damage_preview", {}) as Dictionary
	for key: Variant in effect_preview_map.keys():
		preview_map[key] = effect_preview_map[key]
	return preview_map

func _unit_is_preview_lethal(unit: Dictionary) -> bool:
	return bool(_unit_damage_preview(unit).get("lethal", false))

func _draw_lethal_preview_icons(units_to_draw: Array[Dictionary]) -> void:
	for unit: Dictionary in units_to_draw:
		if bool(unit.get("death_animation", false)) or not _unit_is_preview_lethal(unit):
			continue
		_draw_lethal_preview_icon(_unit_draw_rect(unit))

func _draw_lethal_preview_icon(unit_rect: Rect2) -> void:
	var texture: Texture2D = _effect_textures.get("lethal_death_mark", null)
	if texture == null or unit_rect.size.x <= 0.0 or unit_rect.size.y <= 0.0:
		return
	var pulse: float = _lethal_death_mark_pulse(_lethal_death_mark_time_seconds())
	var draw_scale: float = lerpf(
		LETHAL_DEATH_MARK_MIN_SCALE,
		LETHAL_DEATH_MARK_MAX_SCALE,
		pulse
	)
	var icon_size: float = clampf(
		minf(unit_rect.size.x, unit_rect.size.y) * 0.58,
		42.0,
		76.0
	) * draw_scale
	var icon_center := Vector2(
		unit_rect.get_center().x,
		unit_rect.position.y + unit_rect.size.y * 0.43
	)
	var icon_rect := Rect2(icon_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	var alpha: float = lerpf(
		LETHAL_DEATH_MARK_MIN_ALPHA,
		LETHAL_DEATH_MARK_MAX_ALPHA,
		pulse
	)
	draw_texture_rect(texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))

func _lethal_death_mark_time_seconds() -> float:
	if presentation.has("lethal_preview_time_seconds"):
		return float(presentation.get("lethal_preview_time_seconds", 0.0))
	return float(Time.get_ticks_msec()) / 1000.0

func _lethal_death_mark_pulse(time_seconds: float) -> float:
	if bool(presentation.get("reduced_motion", false)):
		return 0.5
	var phase: float = time_seconds * TAU / LETHAL_DEATH_MARK_PULSE_SECONDS
	return 0.5 + sin(phase) * 0.5

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

func _unit_impact_shake_strength(unit: Dictionary) -> float:
	if bool(presentation.get("reduced_motion", false)):
		return 0.0
	return _unit_impact_strength(unit)

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
		layout["offset"] = (layout.get("offset", Vector2.ZERO) as Vector2) + applied_offset
		layout["tether"] = _enemy_intent_tether_geometry(unit, center, intent_rect)
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
		var condition_tint: Color = Color.WHITE
		if token.has("condition_active") and not bool(token.get("condition_active", false)):
			condition_tint = Color(0.42, 0.39, 0.36, 0.64)
		_draw_keyword_icon(icon_key, icon_rect, tooltip, condition_tint)
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
				continue
			"npc":
				var plate_rect: Rect2 = _npc_nameplate_rect(unit, center, font)
				if plate_rect.size.x > 0.0 and plate_rect.size.y > 0.0:
					rects.append(plate_rect)
			_:
				rects.append_array(_health_bar_collision_rects(unit, _unit_health_bar_rect(unit, center)))
	return rects

func _enemy_hud_reserved_rects(units_to_draw: Array[Dictionary], font: Font) -> Array[Rect2]:
	var rects: Array[Rect2] = _fixed_hud_collision_rects(units_to_draw, font)
	for unit: Dictionary in units_to_draw:
		if bool(unit.get("death_animation", false)) or str(unit.get("role", "")) == "illusion_preview":
			continue
		var art_rect: Rect2 = _enemy_hud_actor_clear_rect(unit, _unit_center(unit))
		if art_rect.size.x > 0.0 and art_rect.size.y > 0.0:
			rects.append(art_rect)
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
	var actor_clear_rect: Rect2 = _enemy_hud_actor_clear_rect(unit, center)
	var placement_obstacles: Array = _enemy_hud_placement_obstacles(occupied_rects, actor_clear_rect)
	var actor_key: String = _enemy_hud_actor_key(unit)
	var offset: Vector2 = _placed_enemy_hud_offset(base_rects, placement_obstacles, actor_clear_rect, actor_key)
	health_rect.position += offset
	intent_rect.position += offset
	var tether: Dictionary = {}
	if absf(offset.x) >= 2.0:
		tether = _enemy_intent_tether_geometry(unit, center, intent_rect)
	return {
		"health_rect": health_rect,
		"intent_rect": intent_rect,
		"rows": rows,
		"intent_name": intent_name,
		"border": border,
		"offset": offset,
		"health_offset": offset,
		"intent_offset": offset,
		"side": str(_enemy_hud_side_by_actor.get(actor_key, "")),
		"tether": tether,
		"occupied_rects": _enemy_hud_collision_rects(unit, health_rect, intent_rect)
	}

func _enemy_hud_placement_obstacles(occupied_rects: Array, actor_clear_rect: Rect2) -> Array:
	var placement_obstacles: Array = occupied_rects.duplicate()
	for occupied_var: Variant in placement_obstacles:
		if typeof(occupied_var) != TYPE_RECT2:
			continue
		var occupied_rect: Rect2 = occupied_var as Rect2
		if occupied_rect.position.is_equal_approx(actor_clear_rect.position) and occupied_rect.size.is_equal_approx(actor_clear_rect.size):
			return placement_obstacles
	placement_obstacles.append(actor_clear_rect)
	return placement_obstacles

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
	var actor_clear_rect: Rect2 = _enemy_hud_actor_clear_rect(unit, center)
	var placement_obstacles: Array = occupied_rects.duplicate()
	placement_obstacles.append(actor_clear_rect)
	var actor_key: String = _enemy_hud_actor_key(unit)
	var offset: Vector2 = _placed_enemy_hud_offset(rects, placement_obstacles, actor_clear_rect, actor_key)
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
		"side": str(_enemy_hud_side_by_actor.get(actor_key, "")),
		"occupied_rects": occupied
	}

func _enemy_hud_actor_key(unit: Dictionary) -> String:
	var actor_key: String = str(unit.get("key", ""))
	if actor_key.is_empty() and str(unit.get("role", "enemy")) == "enemy":
		actor_key = "enemy_%d" % int(unit.get("id", -1))
	return actor_key

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
	var leader_rect: Rect2 = _leader_marker_rect(unit, health_rect, intent_rect)
	if leader_rect.size.x > 0.0 and leader_rect.size.y > 0.0:
		rects.append(leader_rect)
	return rects

func _leader_marker_rect(unit: Dictionary, health_rect: Rect2, intent_rect: Rect2 = Rect2()) -> Rect2:
	if not bool(unit.get("is_leader", false)) or health_rect.size.x <= 0.0:
		return Rect2()
	var marker_size := Vector2(88.0, 24.0)
	var top: float = minf(health_rect.position.y, intent_rect.position.y) if intent_rect.size.y > 0.0 else health_rect.position.y
	return Rect2(
		Vector2(health_rect.get_center().x - marker_size.x * 0.5, top - marker_size.y - 5.0),
		marker_size
	)

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
		var badge: Dictionary = badges[index] as Dictionary
		if int(badge.get("count", 0)) > 0 or not str(badge.get("count_text", "")).is_empty():
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
	var viewport_bounds: Rect2 = _enemy_hud_viewport_bounds()
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
			var score: float = _enemy_hud_layout_score_for_offset(base_rects, occupied_rects, viewport_bounds, offset, best_score)
			if score < best_score:
				best_score = score
				best_offset = offset
	return best_offset

func _enemy_hud_viewport_bounds() -> Rect2:
	return Rect2(
		Vector2(ENEMY_HUD_VIEWPORT_MARGIN, ENEMY_HUD_VIEWPORT_MARGIN),
		Vector2(
			maxf(1.0, size.x - ENEMY_HUD_VIEWPORT_MARGIN * 2.0),
			maxf(1.0, size.y - ENEMY_HUD_VIEWPORT_MARGIN * 2.0)
		)
	)

func _enemy_hud_actor_clear_rect(unit: Dictionary, center: Vector2) -> Rect2:
	# HUD placement must not depend on whichever idle-animation frame happens to
	# be current. Besides making nameplates subtly wander, that forced the first
	# hover over an actor to synchronously read back and scan an arbitrary atlas
	# frame that background shadow preparation had not reached yet. The authored
	# base texture is stable for the unit type and is prepared as an urgent asset.
	var texture: Texture2D = _unit_hud_anchor_texture(unit)
	var draw_rect: Rect2 = _unit_draw_rect_for_texture(unit, center, texture)
	if texture != null:
		var visible_rect: Rect2 = _texture_used_draw_rect(texture, draw_rect)
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			draw_rect = visible_rect
	return draw_rect.grow(ENEMY_HUD_ACTOR_CLEARANCE)

func _unit_hud_anchor_texture(unit: Dictionary) -> Texture2D:
	var unit_type: String = str(unit.get("type", ""))
	var base_texture: Texture2D = _unit_textures.get(unit_type, null) as Texture2D
	return base_texture if base_texture != null else _texture_for_unit(unit)

func _placed_enemy_hud_offset(base_rects: Array, occupied_rects: Array, actor_clear_rect: Rect2, actor_key: String = "") -> Vector2:
	if base_rects.is_empty():
		return Vector2.ZERO
	var viewport_bounds: Rect2 = _enemy_hud_viewport_bounds()
	var hud_bounds: Rect2 = _rects_bounds(base_rects)
	var base_areas: Dictionary = _enemy_hud_collision_areas(base_rects, occupied_rects, viewport_bounds)
	if _enemy_hud_collision_areas_are_clear(base_areas):
		return Vector2.ZERO
	if hud_bounds.position.y < viewport_bounds.position.y:
		var centered_offset := Vector2(0.0, ceilf(viewport_bounds.position.y - hud_bounds.position.y))
		var centered_areas: Dictionary = _enemy_hud_collision_areas_for_offset(base_rects, occupied_rects, viewport_bounds, centered_offset)
		if _enemy_hud_collision_areas_are_clear(centered_areas):
			return centered_offset
		var actor_areas: Dictionary = _enemy_hud_collision_areas_for_offset(base_rects, [actor_clear_rect], viewport_bounds, centered_offset)
		if float(actor_areas.get("overlap_area", 0.0)) > ENEMY_HUD_REPOSITION_OVERLAP_AREA:
			return _best_enemy_hud_side_offset(base_rects, occupied_rects, actor_clear_rect, viewport_bounds, actor_key)
	return _best_enemy_hud_offset(base_rects, occupied_rects)

func _best_enemy_hud_side_offset(base_rects: Array, occupied_rects: Array, actor_clear_rect: Rect2, viewport_bounds: Rect2, actor_key: String = "") -> Vector2:
	var hud_bounds: Rect2 = _rects_bounds(base_rects)
	var max_y: float = maxf(viewport_bounds.position.y, viewport_bounds.end.y - hud_bounds.size.y)
	var clamped_y: float = clampf(hud_bounds.position.y, viewport_bounds.position.y, max_y)
	var y_offsets: Array[float] = [
		clamped_y - hud_bounds.position.y,
		clampf(actor_clear_rect.position.y, viewport_bounds.position.y, max_y) - hud_bounds.position.y,
		clampf(actor_clear_rect.get_center().y - hud_bounds.size.y * 0.5, viewport_bounds.position.y, max_y) - hud_bounds.position.y
	]
	var best_by_side: Dictionary = {}
	for y_offset: float in y_offsets:
		for side: String in ["left", "right"]:
			var x_offset: float = _enemy_hud_minimum_side_x_offset(base_rects, y_offset, actor_clear_rect, side)
			var offset := Vector2(x_offset, y_offset)
			var previous: Dictionary = best_by_side.get(side, {}) as Dictionary
			var previous_score: float = float(previous.get("score", INF))
			var score: float = _enemy_hud_layout_score_for_offset(base_rects, occupied_rects, viewport_bounds, offset, previous_score)
			if not previous.is_empty() and score >= previous_score:
				continue
			var collision_areas: Dictionary = _enemy_hud_collision_areas_for_offset(base_rects, occupied_rects, viewport_bounds, offset)
			if previous.is_empty() or score < float(previous.get("score", INF)):
				best_by_side[side] = {
					"offset": offset,
					"score": score,
					"side": side,
					"overlap_area": float(collision_areas.get("overlap_area", 0.0)),
					"overflow_area": float(collision_areas.get("overflow_area", 0.0))
				}
	var chosen: Dictionary = {}
	for side_var: Variant in best_by_side:
		var candidate: Dictionary = best_by_side.get(side_var, {}) as Dictionary
		if chosen.is_empty() or float(candidate.get("score", INF)) < float(chosen.get("score", INF)):
			chosen = candidate
	var preferred_side: String = str(_enemy_hud_side_by_actor.get(actor_key, ""))
	var preferred: Dictionary = best_by_side.get(preferred_side, {}) as Dictionary
	if not preferred.is_empty() and not chosen.is_empty():
		var preferred_score: float = float(preferred.get("score", INF))
		var chosen_score: float = float(chosen.get("score", INF))
		# A remembered side is sticky through small score changes caused by board
		# motion. It only changes when the other side is materially safer, avoiding
		# left/right chatter around a nearly tied collision boundary.
		if (
			float(preferred.get("overflow_area", INF)) <= 0.01
			and float(preferred.get("overlap_area", INF)) <= ENEMY_HUD_SIDE_STICKY_OVERLAP_AREA
			and preferred_score <= chosen_score + ENEMY_HUD_SIDE_SWITCH_SCORE_MARGIN
		):
			chosen = preferred
	if chosen.is_empty():
		return Vector2.ZERO
	_remember_enemy_hud_side(actor_key, str(chosen.get("side", "")))
	return chosen.get("offset", Vector2.ZERO) as Vector2

func _enemy_hud_minimum_side_x_offset(base_rects: Array, y_offset: float, actor_clear_rect: Rect2, side: String) -> float:
	var x_offset: float = 0.0
	for rect_var: Variant in base_rects:
		if typeof(rect_var) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_var as Rect2
		var shifted_top: float = rect.position.y + y_offset
		var shifted_bottom: float = rect.end.y + y_offset
		if shifted_bottom <= actor_clear_rect.position.y or shifted_top >= actor_clear_rect.end.y:
			continue
		if side == "left":
			x_offset = minf(x_offset, actor_clear_rect.position.x - ENEMY_HUD_SIDE_GAP - rect.end.x)
		else:
			x_offset = maxf(x_offset, actor_clear_rect.end.x + ENEMY_HUD_SIDE_GAP - rect.position.x)
	return x_offset

func _remember_enemy_hud_side(actor_key: String, side: String) -> void:
	if actor_key.is_empty() or side.is_empty() or str(_enemy_hud_side_by_actor.get(actor_key, "")) == side:
		return
	_enemy_hud_side_by_actor[actor_key] = side
	# Cached pan signatures can otherwise restore an older opposite-side layout
	# after the preference changes. Keep the current rendered entry, but discard
	# reusable signatures so future geometry always honors the new side.
	_clear_hud_layout_signature_cache()

func _offset_rects(rects: Array[Rect2], offset: Vector2) -> Array[Rect2]:
	var shifted: Array[Rect2] = []
	for rect: Rect2 in rects:
		shifted.append(Rect2(rect.position + offset, rect.size))
	return shifted

func _enemy_hud_layout_score(candidate_rects: Array, occupied_rects: Array, viewport_bounds: Rect2, offset: Vector2) -> float:
	var collision_areas: Dictionary = _enemy_hud_collision_areas(candidate_rects, occupied_rects, viewport_bounds)
	return _enemy_hud_layout_score_from_areas(collision_areas, offset)

func _enemy_hud_layout_score_for_offset(base_rects: Array, occupied_rects: Array, viewport_bounds: Rect2, offset: Vector2, score_ceiling: float = INF) -> float:
	var overlap_area: float = 0.0
	var overflow_area: float = 0.0
	var offset_score: float = absf(offset.x) * 2.4 + absf(offset.y) * 1.6
	if offset_score >= score_ceiling:
		return offset_score
	for base_var: Variant in base_rects:
		var base_rect: Rect2 = base_var
		var candidate := Rect2(base_rect.position + offset, base_rect.size)
		for occupied_var: Variant in occupied_rects:
			var occupied_rect: Rect2 = occupied_var
			overlap_area += _rect_overlap_area(candidate, occupied_rect)
			var partial_score: float = maxf(0.0, overlap_area - ENEMY_HUD_REPOSITION_OVERLAP_AREA) * 100000.0 + offset_score
			if partial_score >= score_ceiling:
				return partial_score
		overflow_area += _rect_outside_area(candidate, viewport_bounds)
		var partial_score: float = (
			maxf(0.0, overlap_area - ENEMY_HUD_REPOSITION_OVERLAP_AREA) * 100000.0
			+ overflow_area * 5000.0
			+ offset_score
		)
		if partial_score >= score_ceiling:
			return partial_score
	var meaningful_overlap: float = maxf(0.0, overlap_area - ENEMY_HUD_REPOSITION_OVERLAP_AREA)
	return meaningful_overlap * 100000.0 + overflow_area * 5000.0 + offset_score

func _enemy_hud_layout_score_from_areas(collision_areas: Dictionary, offset: Vector2) -> float:
	var overlap_area: float = float(collision_areas.get("overlap_area", 0.0))
	var overflow_area: float = float(collision_areas.get("overflow_area", 0.0))
	var meaningful_overlap: float = maxf(0.0, overlap_area - ENEMY_HUD_REPOSITION_OVERLAP_AREA)
	return meaningful_overlap * 100000.0 + overflow_area * 5000.0 + absf(offset.x) * 2.4 + absf(offset.y) * 1.6

func _enemy_hud_collision_areas_are_clear(collision_areas: Dictionary) -> bool:
	return (
		float(collision_areas.get("overflow_area", INF)) <= 0.01
		and float(collision_areas.get("overlap_area", INF)) <= ENEMY_HUD_REPOSITION_OVERLAP_AREA
	)

func _enemy_hud_collision_areas(candidate_rects: Array, occupied_rects: Array, viewport_bounds: Rect2) -> Dictionary:
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
	return {"overlap_area": overlap_area, "overflow_area": overflow_area}

func _enemy_hud_collision_areas_for_offset(base_rects: Array, occupied_rects: Array, viewport_bounds: Rect2, offset: Vector2) -> Dictionary:
	# HUD placement evaluates dozens of offsets for every visible enemy. Applying
	# an offset arithmetically avoids allocating a shifted Rect2 array for every
	# candidate while preserving the exact collision score and tie ordering.
	var overlap_area: float = 0.0
	var overflow_area: float = 0.0
	for base_var: Variant in base_rects:
		if typeof(base_var) != TYPE_RECT2:
			continue
		var base_rect: Rect2 = base_var as Rect2
		var candidate := Rect2(base_rect.position + offset, base_rect.size)
		for occupied_var: Variant in occupied_rects:
			if typeof(occupied_var) == TYPE_RECT2:
				overlap_area += _rect_overlap_area(candidate, occupied_var as Rect2)
		overflow_area += _rect_outside_area(candidate, viewport_bounds)
	return {"overlap_area": overlap_area, "overflow_area": overflow_area}

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

func _draw_enemy_hud_tether(_unit: Dictionary, _center: Vector2, layout: Dictionary) -> void:
	var tether: Dictionary = layout.get("tether", {})
	if tether.is_empty():
		return
	var border: Color = layout.get("border", Color("d8b96f"))
	var anchor: Vector2 = tether.get("from", Vector2.ZERO)
	var target: Vector2 = tether.get("to", Vector2.ZERO)
	draw_line(anchor, target, Color(0.0, 0.0, 0.0, 0.24), 3.0, true)
	draw_line(anchor, target, Color(border.r, border.g, border.b, 0.58), 1.0, true)

func _enemy_intent_tether_geometry(unit: Dictionary, center: Vector2, intent_rect: Rect2) -> Dictionary:
	if intent_rect.size.x <= 0.0 or intent_rect.size.y <= 0.0:
		return {}
	var art_rect: Rect2 = _unit_draw_rect_for_center(unit, center)
	if art_rect.size.x <= 0.0 or art_rect.size.y <= 0.0:
		return {}
	return {
		"from": _rect_edge_point_toward(art_rect, intent_rect.get_center()),
		"to": _rect_edge_point_toward(intent_rect, art_rect.get_center())
	}

func _rect_edge_point_toward(rect: Rect2, target: Vector2) -> Vector2:
	var center: Vector2 = rect.get_center()
	var direction: Vector2 = target - center
	if direction.length_squared() <= 0.0001:
		return center
	var half_size: Vector2 = rect.size * 0.5
	var x_scale: float = half_size.x / absf(direction.x) if absf(direction.x) > 0.0001 else INF
	var y_scale: float = half_size.y / absf(direction.y) if absf(direction.y) > 0.0001 else INF
	return center + direction * minf(x_scale, y_scale)

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
	if token.has("condition_active") and not bool(token.get("condition_active", false)):
		return default_color.darkened(0.42)
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
	var role: String = str(presentation.get("status_typography_role", UiTypography.ROLE_SECTION))
	var font: Font = UiTypography.font_for_role(role)
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return
	var label_font_size: int = UiTypography.scaled_size(self, UiTypography.role_size(role))
	var layout: Dictionary = _status_text_layout(font, label_font_size)
	var label_rect: Rect2 = layout.get("label", Rect2()) as Rect2
	draw_string(font, label_rect.position + Vector2(0.0, label_rect.size.y), status_label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, label_font_size, Color("f4ebd7"))
	if not status_detail.is_empty():
		var detail_font: Font = UiTypography.text_font()
		if detail_font == null:
			detail_font = font
		var detail_font_size: int = UiTypography.scaled_size(self, UiTypography.SIZE_BODY)
		var detail_rect: Rect2 = layout.get("detail", Rect2()) as Rect2
		draw_string(detail_font, detail_rect.position + Vector2(0.0, detail_rect.size.y), status_detail, HORIZONTAL_ALIGNMENT_CENTER, detail_rect.size.x, detail_font_size, Color("d8ccb6"))

func _status_text_layout(font: Font, label_font_size: int) -> Dictionary:
	var safe_rect: Rect2 = Rect2(Vector2(280.0, 18.0), Vector2(maxf(1.0, size.x - 560.0), 82.0))
	var safe_global_rect: Rect2 = presentation.get("status_safe_global_rect", Rect2()) as Rect2
	if safe_global_rect.size.x > 0.0 and safe_global_rect.size.y > 0.0:
		# The board camera's transform can settle after RunScene builds its
		# presentation. Convert the screen-safe band at draw time so its label stays
		# centered between the actual header groups rather than drifting with a stale
		# board-local transform.
		var inverse_transform: Transform2D = get_global_transform().affine_inverse()
		var local_top_left: Vector2 = inverse_transform * safe_global_rect.position
		var local_bottom_right: Vector2 = inverse_transform * safe_global_rect.end
		safe_rect = Rect2(local_top_left, local_bottom_right - local_top_left)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		safe_rect = Rect2(Vector2(0.0, 18.0), Vector2(maxf(1.0, size.x), 82.0))
	var label_size: Vector2 = font.get_string_size(status_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_font_size)
	var label_rect := Rect2(
		Vector2(safe_rect.get_center().x - label_size.x * 0.5, safe_rect.position.y + 6.0),
		label_size
	)
	var detail_rect := Rect2()
	if not status_detail.is_empty():
		var detail_font: Font = UiTypography.text_font()
		if detail_font == null:
			detail_font = font
		var detail_font_size: int = UiTypography.scaled_size(self, UiTypography.SIZE_BODY)
		var detail_size: Vector2 = detail_font.get_string_size(status_detail, HORIZONTAL_ALIGNMENT_LEFT, -1.0, detail_font_size)
		detail_rect = Rect2(
			Vector2(safe_rect.get_center().x - detail_size.x * 0.5, label_rect.end.y + 5.0),
			detail_size
		)
	return {"label": label_rect, "detail": detail_rect}

func status_text_local_bounds() -> Rect2:
	# Keep UI probes coupled to the exact board-owned status paint region.
	if status_label.is_empty():
		return Rect2()
	var role: String = str(presentation.get("status_typography_role", UiTypography.ROLE_SECTION))
	var font: Font = UiTypography.font_for_role(role)
	if font == null:
		font = get_theme_default_font()
	if font == null:
		return Rect2()
	var layout: Dictionary = _status_text_layout(font, UiTypography.scaled_size(self, UiTypography.role_size(role)))
	var label_bounds: Rect2 = layout.get("label", Rect2()) as Rect2
	if status_detail.is_empty():
		return label_bounds
	var detail_bounds: Rect2 = layout.get("detail", Rect2()) as Rect2
	return label_bounds.merge(detail_bounds)

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

func _effect_uses_elemental_scene_depth(effect: Dictionary) -> bool:
	return (
		str(effect.get("kind", "")) == "ranged"
		and AttackFxLibrary.uses_authored_elemental_ranged(effect)
		and not bool(effect.get("preview", false))
	)

func _elemental_scene_depth_tiles_for_presentation(source_presentation: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = _vector2i_array([])
	for trap_var: Variant in source_presentation.get("trap_effects", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		_elemental_append_unique_depth_tile(tiles, (trap_var as Dictionary).get("pos", Vector2i(-1, -1)))
	var effect: Dictionary = source_presentation.get("effect", {}) as Dictionary
	if not _effect_uses_elemental_scene_depth(effect):
		return tiles
	var from_tile: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	if from_tile.x < 0 or to_tile.x < 0:
		return tiles
	var style: String = AttackFxLibrary.style_for_effect(effect)
	if style == AttackFxLibrary.STYLE_EARTH_SPIKES:
		_elemental_append_unique_depth_tile(tiles, from_tile)
		for spike_index: int in range(EARTH_PATH_SPIKE_COUNT):
			var path_progress: float = lerpf(0.10, 0.96, float(spike_index) / float(EARTH_PATH_SPIKE_COUNT - 1))
			_elemental_append_unique_depth_tile(tiles, _elemental_lerp_depth_tile(from_tile, to_tile, path_progress))
		_elemental_append_unique_depth_tile(tiles, to_tile)
		return tiles
	if bool(effect.get("preview", false)):
		for sample_index: int in range(13):
			var sample_progress: float = float(sample_index) / 12.0
			_elemental_append_unique_depth_tile(tiles, _elemental_lerp_depth_tile(from_tile, to_tile, sample_progress))
		return tiles
	var progress: float = clampf(float(source_presentation.get("effect_progress", 1.0)), 0.0, 1.0)
	_elemental_append_unique_depth_tile(tiles, _elemental_scene_depth_tile_for_effect(effect, progress))
	return tiles

func _elemental_append_unique_depth_tile(tiles: Array[Vector2i], tile: Vector2i) -> void:
	if tile.x >= 0 and not tiles.has(tile):
		tiles.append(tile)

func _elemental_scene_depth_tile_for_effect(effect: Dictionary, progress: float) -> Vector2i:
	var from_tile: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	if from_tile.x < 0 or to_tile.x < 0:
		return Vector2i(-1, -1)
	var travel_progress: float = 0.0
	if bool(effect.get("preview", false)):
		var phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
		travel_progress = lerpf(0.05, 0.95, phase)
	else:
		var style: String = AttackFxLibrary.style_for_effect(effect)
		travel_progress = AttackFxLibrary.travel_progress_for_style(style, progress)
	return _elemental_lerp_depth_tile(from_tile, to_tile, travel_progress)

func _elemental_lerp_depth_tile(from_tile: Vector2i, to_tile: Vector2i, progress: float) -> Vector2i:
	var point: Vector2 = Vector2(from_tile).lerp(Vector2(to_tile), clampf(progress, 0.0, 1.0))
	return Vector2i(roundi(point.x), roundi(point.y))

func _draw_elemental_scene_depth_pass(tile: Vector2i, foreground_pass: bool) -> void:
	var progress: float = clampf(float(presentation.get("effect_progress", 1.0)), 0.0, 1.0)
	for trap_var: Variant in presentation.get("trap_effects", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var as Dictionary
		if trap.get("pos", Vector2i(-1, -1)) == tile:
			_draw_trap_elemental_depth_effect(trap, _trap_elemental_effect_progress(trap, progress), foreground_pass)
	var effect: Dictionary = presentation.get("effect", {}) as Dictionary
	if not _effect_uses_elemental_scene_depth(effect):
		return
	var style: String = AttackFxLibrary.style_for_effect(effect)
	var depth_tiles: Array[Vector2i] = _elemental_scene_depth_tiles_for_presentation(presentation)
	if not depth_tiles.has(tile):
		return
	var current_depth_tile: Vector2i = _elemental_scene_depth_tile_for_effect(effect, progress)
	var from_tile: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	var from_point: Vector2 = _tile_center(from_tile)
	var to_point: Vector2 = _tile_center(to_tile)
	if foreground_pass:
		if tile == current_depth_tile:
			_draw_elemental_foreground_depth_effect(effect, style, progress, to_point)
		return
	if style != AttackFxLibrary.STYLE_EARTH_SPIKES and tile != current_depth_tile:
		return
	_draw_ranged_projectile_effect(effect, progress, from_point, to_point)

func _draw_trap_elemental_depth_effect(trap: Dictionary, progress: float, foreground_pass: bool) -> void:
	var element_id: String = str(trap.get("element", ElementData.NONE))
	var style: String = _elemental_style_for_element(element_id)
	if style == AttackFxLibrary.STYLE_DEFAULT:
		return
	var reduced_motion: bool = bool(presentation.get("reduced_motion", false))
	var impact_progress: float = 0.52 if reduced_motion else clampf(progress, 0.0, 1.0)
	var core_fade: float = 1.0 if reduced_motion else _elemental_impact_core_fade(style, impact_progress)
	var volume_fade: float = 1.0 if reduced_motion else _elemental_impact_volume_fade(style, impact_progress)
	if core_fade <= 0.0 and volume_fade <= 0.0:
		return
	var tile_center: Vector2 = _tile_center(trap.get("pos", Vector2i(-1, -1)))
	var ground_point: Vector2 = _elemental_ground_point(tile_center)
	var scale_ratio: float = _trap_elemental_scale_ratio(style)
	_draw_scaled_elemental_begin(ground_point, scale_ratio)
	if foreground_pass:
		var draw_size: float = _elemental_performance_size(style, impact_progress)
		_draw_elemental_foreground_performance(style, ground_point, impact_progress, core_fade, reduced_motion)
		_draw_elemental_foreground_volume(element_id, ground_point, impact_progress, draw_size, volume_fade, reduced_motion)
	else:
		match style:
			AttackFxLibrary.STYLE_EARTH_SPIKES:
				_draw_earth_impact(ground_point, impact_progress, 1.0, reduced_motion)
			AttackFxLibrary.STYLE_AIR_GUST:
				_draw_air_gust_impact(_elemental_air_point(tile_center, 0.56), ground_point, impact_progress, 1.0, reduced_motion)
			AttackFxLibrary.STYLE_LIGHTNING_BOLT:
				_draw_lightning_impact(_elemental_air_point(tile_center, 0.58), ground_point, impact_progress, 1.0, reduced_motion)
			AttackFxLibrary.STYLE_ICE_SHARDS:
				_draw_ice_icicle_impact(ground_point, impact_progress, 1.0, reduced_motion)
			_:
				_draw_fireball_impact_frame(ground_point, ground_point, impact_progress, 1.0, reduced_motion)
	_draw_scaled_elemental_end()

func _draw_elemental_foreground_depth_effect(effect: Dictionary, style: String, progress: float, target_point: Vector2) -> void:
	if bool(effect.get("preview", false)):
		return
	var reduced_motion: bool = bool(presentation.get("reduced_motion", false))
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	if not reduced_motion and progress < travel_end:
		return
	var impact_progress: float = 0.52 if reduced_motion else AttackFxLibrary.impact_progress_for_style(style, progress)
	var core_fade: float = 1.0 if reduced_motion else _elemental_impact_core_fade(style, impact_progress)
	var volume_fade: float = 1.0 if reduced_motion else _elemental_impact_volume_fade(style, impact_progress)
	if core_fade <= 0.0 and volume_fade <= 0.0:
		return
	var element_id: String = _elemental_style_id(style)
	var ground_point: Vector2 = _elemental_ground_point(target_point)
	var draw_size: float = _elemental_performance_size(style, impact_progress)
	_draw_elemental_foreground_performance(style, ground_point, impact_progress, core_fade, reduced_motion)
	_draw_elemental_foreground_volume(element_id, ground_point, impact_progress, draw_size, volume_fade, reduced_motion)

func _draw_elemental_foreground_performance(style: String, ground_point: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> void:
	var core_frames: Array[Texture2D] = _elemental_impact_core_frames(style)
	if core_frames.is_empty() or alpha <= 0.0:
		return
	var profile: Dictionary = _elemental_integration_profile(style)
	var sample_progress: float = 0.52 if reduced_motion else impact_progress
	var frame_blend: Vector3 = _elemental_performance_frame_blend(style, sample_progress, core_frames.size(), reduced_motion)
	var draw_size: float = _elemental_performance_size(style, sample_progress)
	var energy: float = 0.76 if reduced_motion else 0.54 + sin(clampf(impact_progress, 0.0, 1.0) * PI) * 0.46
	var modulate: Color = _elemental_performance_modulate(style)
	var bloom_frames: Array[Texture2D] = _elemental_performance_bloom_frames(style)
	if not bloom_frames.is_empty():
		var bloom_blend: Vector3 = _remap_frame_blend(frame_blend, bloom_frames.size())
		var bloom_alpha: float = float(profile.get("front_bloom_alpha", 0.64)) * energy
		_draw_elemental_blended_performance_frames(
			bloom_frames,
			bloom_blend,
			ground_point + Vector2(0.0, -draw_size * 0.018),
			draw_size * 1.25,
			alpha * bloom_alpha * 0.52,
			profile.get("bloom_color", Color.WHITE),
			style
		)
		_draw_elemental_blended_performance_frames(
			bloom_frames,
			bloom_blend,
			ground_point + Vector2(0.0, draw_size * 0.012),
			draw_size * 1.08,
			alpha * bloom_alpha * 0.44,
			profile.get("bloom_color", Color.WHITE),
			style
		)
	_draw_elemental_blended_impact_core_frames(
		core_frames,
		frame_blend,
		ground_point,
		draw_size * (0.985 + energy * 0.018),
		alpha * float(profile.get("front_core_alpha", 0.34)),
		modulate,
		style
	)

func _draw_elemental_foreground_volume(element_id: String, ground_point: Vector2, impact_progress: float, draw_size: float, alpha: float, reduced_motion: bool) -> void:
	var style: String = _elemental_style_for_id(element_id)
	var profile: Dictionary = _elemental_integration_profile(style)
	var soft_texture: Texture2D = _ambient_fire_soft_texture(2) if element_id in ["fire", "earth"] else _ambient_air_wisp_soft_texture(2)
	if soft_texture != null:
		var veil_energy: float = 0.82 if reduced_motion else 0.56 + sin(clampf(impact_progress, 0.0, 1.0) * PI) * 0.44
		for veil_index: int in range(3):
			var veil_depth: float = float(veil_index) / 2.0
			_draw_ambient_particle_sprite(
				soft_texture,
				ground_point + Vector2(draw_size * lerpf(-0.055, 0.065, veil_depth), -draw_size * lerpf(0.16, 0.34, veil_depth)),
				Vector2(draw_size * lerpf(1.02, 0.72, veil_depth), draw_size * lerpf(0.54, 0.70, veil_depth)),
				lerpf(-0.12, 0.14, veil_depth),
				alpha * veil_energy * float(profile.get("front_veil_alpha", 0.38)) * lerpf(0.54, 0.30, veil_depth),
				_elemental_scene_color(element_id)
			)
	for particle_index: int in range(ELEMENTAL_FOREGROUND_PARTICLE_COUNT):
		var delay: float = float(particle_index) * 0.014
		var age: float = 0.46 if reduced_motion else clampf((impact_progress - 0.06 - delay) / 0.82, 0.0, 1.0)
		if age <= 0.0 or age >= 1.0:
			continue
		var seed: int = 36017 + particle_index * 977 + _impact_element_seed(element_id) * 43
		var angle: float = lerpf(0.10 * PI, 0.90 * PI, float(particle_index) / float(ELEMENTAL_FOREGROUND_PARTICLE_COUNT - 1))
		angle += lerpf(-0.08, 0.08, _ambient_hash01(seed))
		var radial: float = draw_size * lerpf(0.10, 0.48, age) * lerpf(0.72, 1.18, _ambient_hash01(seed + 3))
		var lift: float = draw_size * lerpf(0.06, 0.28, _ambient_hash01(seed + 5)) * sin(age * PI)
		var point: Vector2 = ground_point + Vector2(cos(angle) * radial, sin(angle) * radial * 0.32 - lift + draw_size * 0.08 * age * age)
		var texture: Texture2D = null
		var particle_soft_texture: Texture2D = null
		var glow_texture: Texture2D = null
		if element_id == "air":
			texture = _ambient_air_wisp_texture(posmod(particle_index, AMBIENT_AIR_WISP_VARIANTS), clampi(int(age * 18.0), 0, AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
			particle_soft_texture = _ambient_air_wisp_soft_texture(posmod(particle_index, AMBIENT_AIR_WISP_VARIANTS))
			glow_texture = _ambient_air_wisp_glow_texture(posmod(particle_index, AMBIENT_AIR_WISP_VARIANTS), clampi(int(age * 18.0), 0, AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
		else:
			texture = _ambient_particle_texture(element_id, posmod(particle_index * 3 + 2, AMBIENT_PARTICLE_ATLAS_COLUMNS))
			glow_texture = _ambient_particle_glow_texture(element_id, posmod(particle_index * 3 + 2, AMBIENT_PARTICLE_ATLAS_COLUMNS))
			particle_soft_texture = _ambient_fire_soft_texture(posmod(particle_index, AMBIENT_FIRE_SOFT_ATLAS_COLUMNS)) if element_id in ["fire", "earth"] else glow_texture
		if texture == null and particle_soft_texture == null and glow_texture == null:
			continue
		var size_scale: float = lerpf(0.085, 0.040, age) * lerpf(0.78, 1.20, _ambient_hash01(seed + 7))
		var particle_size := Vector2.ONE * draw_size * size_scale
		if element_id == "air":
			particle_size = Vector2(draw_size * size_scale * 2.2, draw_size * size_scale * 0.78)
		var particle_alpha: float = alpha * pow(1.0 - age, 0.82) * lerpf(0.58, 0.88, _ambient_hash01(seed + 11))
		var particle_velocity := Vector2(cos(angle) * draw_size * 0.24, -draw_size * lerpf(0.18, 0.34, _ambient_hash01(seed + 13)))
		if glow_texture != null:
			_draw_ambient_particle_trail(glow_texture, point, particle_velocity, particle_size * Vector2(1.20, 0.90), particle_alpha * 0.92, element_id)
			_draw_ambient_particle_sprite(glow_texture, point, particle_size * _ambient_glow_scale(element_id), angle - PI * 0.5, particle_alpha * _ambient_glow_alpha(element_id), _elemental_scene_color(element_id))
		if particle_soft_texture != null:
			_draw_ambient_particle_sprite(particle_soft_texture, point, particle_size * Vector2(1.34, 1.22), angle - PI * 0.5, particle_alpha * 0.76, _elemental_scene_color(element_id))
		if texture != null:
			_draw_ambient_particle_sprite(texture, point, particle_size, angle - PI * 0.5, particle_alpha * 0.54, _elemental_scene_color(element_id))

func _draw_elemental_spell_floor_overlay() -> void:
	var effect: Dictionary = presentation.get("effect", {})
	if effect.is_empty() or bool(effect.get("preview", false)):
		return
	var style: String = AttackFxLibrary.style_for_effect(effect)
	if style == AttackFxLibrary.STYLE_DEFAULT:
		return
	var target_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	if target_tile.x < 0:
		return
	var progress: float = clampf(float(presentation.get("effect_progress", 1.0)), 0.0, 1.0)
	_draw_elemental_spell_scene(
		style,
		progress,
		_elemental_ground_point(_tile_center(target_tile)),
		bool(presentation.get("reduced_motion", false))
	)

func _draw_elemental_trap_floor_overlay() -> void:
	var trap_effects: Array = presentation.get("trap_effects", [])
	if trap_effects.is_empty():
		return
	var progress: float = clampf(float(presentation.get("effect_progress", 1.0)), 0.0, 1.0)
	var reduced_motion: bool = bool(presentation.get("reduced_motion", false))
	for trap_var: Variant in trap_effects:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var as Dictionary
		var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if not _board_tile_is_visible_to_player(trap_pos):
			continue
		var element_id: String = str(trap.get("element", ElementData.NONE))
		var style: String = _elemental_style_for_element(element_id)
		if style == AttackFxLibrary.STYLE_DEFAULT:
			continue
		var trap_progress: float = _trap_elemental_effect_progress(trap, progress)
		var ground_point: Vector2 = _elemental_ground_point(_tile_center(trap_pos))
		var style_progress: float = lerpf(AttackFxLibrary.travel_end_progress(style), 1.0, trap_progress)
		var scale_ratio: float = _trap_elemental_scale_ratio(style)
		_draw_scaled_elemental_begin(ground_point, scale_ratio)
		_draw_elemental_spell_scene(style, style_progress, ground_point, reduced_motion)
		_draw_scaled_elemental_end()
		_draw_trap_elemental_footprint(trap, element_id, trap_progress, reduced_motion)
		var activation_texture: Texture2D = _trap_activation_texture(trap, trap_progress)
		if activation_texture != null:
			draw_texture_rect(activation_texture, _trap_visual_draw_rect(trap), false, _trap_visual_modulate(trap))

func _trap_elemental_effect_progress(trap: Dictionary, fallback_progress: float) -> float:
	return clampf(float(trap.get("effect_progress", fallback_progress)), 0.0, 1.0)

func _draw_trap_elemental_footprint(trap: Dictionary, element_id: String, progress: float, reduced_motion: bool) -> void:
	var frame_progress: float = 0.52 if reduced_motion else clampf(progress, 0.0, 1.0)
	var envelope: float = 0.44 if reduced_motion else sin(frame_progress * PI)
	if envelope <= 0.0:
		return
	var frame_index: int = AttackFxLibrary.one_shot_frame_index(frame_progress, 8)
	var texture: Texture2D = _elemental_floor_light_texture(element_id, frame_index)
	if texture == null:
		return
	var tint: Color = _elemental_scene_color(element_id)
	for tile: Vector2i in _trap_blast_tiles(trap):
		if not _board_tile_is_visible_to_player(tile):
			continue
		var tile_ground: Vector2 = _elemental_ground_point(_tile_center(tile))
		var is_center: bool = tile == trap.get("pos", Vector2i(-1, -1))
		var width: float = _tile_width() * (1.42 if is_center else 1.08)
		_draw_elemental_floor_light_sprite(
			element_id,
			texture,
			tile_ground,
			Vector2(width, width * 0.38),
			envelope * (0.22 if is_center else 0.13),
			tint,
			frame_index
		)

func _draw_effect_overlay() -> void:
	var effect: Dictionary = presentation.get("effect", {})
	var progress: float = clampf(float(presentation.get("effect_progress", 1.0)), 0.0, 1.0)
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
			if not _effect_uses_elemental_scene_depth(effect) or not _is_dynamic_render_layer:
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
	if bool(effect.get("preview", false)):
		_draw_ranged_target_preview_curve(effect, from_point, to_point)
		return
	var style: String = AttackFxLibrary.style_for_effect(effect)
	match style:
		AttackFxLibrary.STYLE_FIREBALL:
			_draw_fireball_attack_effect(effect, progress, from_point, to_point)
			return
		AttackFxLibrary.STYLE_EARTH_SPIKES:
			_draw_earth_spike_attack_effect(effect, progress, from_point, to_point)
			return
		AttackFxLibrary.STYLE_AIR_GUST:
			_draw_air_gust_attack_effect(effect, progress, from_point, to_point)
			return
		AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			_draw_lightning_attack_effect(effect, progress, from_point, to_point)
			return
		AttackFxLibrary.STYLE_ICE_SHARDS:
			_draw_ice_shard_attack_effect(effect, progress, from_point, to_point)
			return
	var element_id: String = _projectile_element_id(_effect_element(effect))
	var accent: Color = _projectile_accent(element_id)
	var secondary: Color = _projectile_secondary(element_id)
	var start: Vector2 = from_point + Vector2(0.0, -24.0)
	var end: Vector2 = to_point + Vector2(0.0, -24.0)
	var control: Vector2 = _arc_control_point(start, end)
	var warmup_progress: float = clampf(progress / 0.34, 0.0, 1.0)
	var arc_alpha: float = 0.11 + 0.08 * warmup_progress
	_draw_bezier_glow(start, control, end, Color(accent.r, accent.g, accent.b, arc_alpha), 1.5)
	var travel_progress: float = clampf((progress - 0.18) / 0.48, 0.0, 1.0)
	if travel_progress > 0.0:
		_draw_elemental_projectile_trail(start, control, end, travel_progress, element_id, accent, secondary)
		var projectile_point: Vector2 = _quadratic_bezier(start, control, end, travel_progress)
		var behind_point: Vector2 = _quadratic_bezier(start, control, end, maxf(0.0, travel_progress - 0.04))
		var ahead_point: Vector2 = _quadratic_bezier(start, control, end, minf(1.0, travel_progress + 0.04))
		_draw_projectile_sprite(projectile_point, ahead_point - behind_point, element_id, travel_progress)

func _ranged_target_preview_curve_points(from_point: Vector2, to_point: Vector2) -> Array[Vector2]:
	var start: Vector2 = from_point + Vector2(0.0, -_tile_height() * 0.64)
	var end: Vector2 = to_point + Vector2(0.0, -_tile_height() * 0.64)
	return _sample_quadratic_points(start, _arc_control_point(start, end), end, 16)

func _draw_ranged_target_preview_curve(effect: Dictionary, from_point: Vector2, to_point: Vector2) -> void:
	var element_id: String = _projectile_element_id(_effect_element(effect))
	var accent: Color = _projectile_accent(element_id)
	var secondary: Color = _projectile_secondary(element_id)
	var points: Array[Vector2] = _ranged_target_preview_curve_points(from_point, to_point)
	if points.size() < 2:
		return
	var packed_points := PackedVector2Array(points)
	draw_polyline(packed_points, Color(0.0, 0.0, 0.0, 0.28), 7.0, true)
	draw_polyline(packed_points, Color(secondary.r, secondary.g, secondary.b, 0.26), 4.2, true)
	draw_polyline(packed_points, Color(accent.r, accent.g, accent.b, 0.82), 1.8, true)

func _elemental_ground_point(tile_center: Vector2) -> Vector2:
	# _tile_center is the center of the rendered 2:1 diamond: the exact floor
	# plane players target. Sprite-local anchors map authored eruption origins to
	# this invariant point; the world anchor must never drift toward an actor's
	# screen-space feet or the diamond's lower vertex.
	return tile_center

func _elemental_air_point(tile_center: Vector2, lift_ratio: float) -> Vector2:
	return tile_center - Vector2(0.0, _tile_height() * lift_ratio)

func _elemental_style_id(style: String) -> String:
	match style:
		AttackFxLibrary.STYLE_EARTH_SPIKES:
			return "earth"
		AttackFxLibrary.STYLE_AIR_GUST:
			return "air"
		AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			return "lightning"
		AttackFxLibrary.STYLE_ICE_SHARDS:
			return "ice"
		_:
			return "fire"

func _elemental_style_for_element(element_id: String) -> String:
	return AttackFxLibrary.style_for_effect({
		"kind": "ranged",
		"action_type": "ranged",
		"element": element_id,
	})

func _trap_elemental_scale_ratio(style: String) -> float:
	return TRAP_ELEMENTAL_DETONATION_SCALE / maxf(0.001, _elemental_detonation_scale(style))

func _draw_scaled_elemental_begin(ground_point: Vector2, scale_ratio: float) -> void:
	var clamped_ratio: float = maxf(0.001, scale_ratio)
	draw_set_transform(ground_point * (1.0 - clamped_ratio), 0.0, Vector2.ONE * clamped_ratio)

func _draw_scaled_elemental_end() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _elemental_scene_color(element_id: String) -> Color:
	match element_id:
		"earth":
			return Color(0.72, 0.49, 0.23, 1.0)
		"air":
			return Color(0.58, 0.86, 1.0, 1.0)
		"lightning":
			return Color(0.68, 0.72, 1.0, 1.0)
		"ice":
			return Color(0.42, 0.76, 1.0, 1.0)
		_:
			return Color(1.0, 0.32, 0.07, 1.0)

func _draw_elemental_spell_scene(style: String, progress: float, target_ground: Vector2, reduced_motion: bool) -> void:
	var element_id: String = _elemental_style_id(style)
	var tint: Color = _elemental_scene_color(element_id)
	var stage_in: float = smoothstep(0.0, 0.10, progress)
	var stage_out: float = 1.0 - smoothstep(0.78, 1.0, progress)
	var envelope: float = minf(stage_in, stage_out)
	if reduced_motion:
		envelope = 0.42
	var impact_progress: float = AttackFxLibrary.impact_progress_for_style(style, progress)
	var impact_energy: float = sin(clampf(impact_progress, 0.0, 1.0) * PI)
	var detonation_scale: float = _elemental_detonation_scale(style)
	var light_frame_index: int = AttackFxLibrary.one_shot_frame_index(impact_progress, 8)
	var light_texture: Texture2D = _elemental_floor_light_texture(element_id, light_frame_index)
	if light_texture != null:
		var light_size: float = clampf(_tile_width() * (2.15 + impact_energy * 1.20), 208.0, 390.0) * detonation_scale
		_draw_elemental_floor_light_sprite(
			element_id,
			light_texture,
			target_ground,
			Vector2(light_size, light_size * 0.42),
			(0.10 + impact_energy * 0.25) * envelope,
			tint,
			light_frame_index
		)
	var flash: float = 0.34 if reduced_motion else AttackFxLibrary.contact_flash_strength(style, progress)
	if flash <= 0.0:
		return
	if light_texture != null:
		var flash_size: float = clampf(_tile_width() * (2.35 + flash * 1.35), 228.0, 420.0) * detonation_scale
		_draw_elemental_floor_light_sprite(
			element_id,
			light_texture,
			target_ground,
			Vector2(flash_size, flash_size * 0.46),
			0.56 * flash,
			Color(1.0, 0.98, 0.90, 1.0),
			light_frame_index
		)

func _draw_elemental_release(style: String, start: Vector2, ground_start: Vector2, end: Vector2, release_progress: float, alpha: float = 1.0) -> void:
	var element_id: String = _elemental_style_id(style)
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT
	var frame_key: String = "fireball_travel"
	match style:
		AttackFxLibrary.STYLE_EARTH_SPIKES:
			frame_key = "elemental_earth_performance"
		AttackFxLibrary.STYLE_AIR_GUST:
			frame_key = "air_gust_travel"
		AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			frame_key = "lightning_bolt_travel"
		AttackFxLibrary.STYLE_ICE_SHARDS:
			frame_key = "ice_shard_travel"
	var frames: Array[Texture2D] = _authored_elemental_frames(frame_key)
	if frames.is_empty():
		return
	var texture: Texture2D = frames[0]
	var pulse: float = sin(clampf(release_progress, 0.0, 1.0) * PI * 0.72)
	var release_alpha: float = alpha * clampf(0.34 + pulse * 0.90, 0.0, 1.0)
	var draw_size: float = clampf(_tile_width() * lerpf(0.46, 0.92, release_progress), 46.0, 104.0)
	if style == AttackFxLibrary.STYLE_EARTH_SPIKES:
		_draw_elemental_performance_frame(texture, ground_start, draw_size * 1.18, release_alpha, Color.WHITE, style, 0)
	else:
		var stretch := Vector2(draw_size * lerpf(0.62, 1.28, release_progress), draw_size * lerpf(1.08, 0.72, release_progress))
		_draw_authored_oriented_frame(texture, start, direction, stretch, release_alpha, Color.WHITE, Vector2(0.80, 0.50))
	_draw_elemental_release_intake(element_id, start, release_progress, draw_size, release_alpha)

func _draw_elemental_release_intake(element_id: String, center: Vector2, release_progress: float, draw_size: float, alpha: float) -> void:
	for mote_index: int in range(9):
		var texture: Texture2D = _ambient_particle_texture(element_id, posmod(mote_index * 3, AMBIENT_PARTICLE_ATLAS_COLUMNS))
		if texture == null:
			texture = _elemental_ground_texture(element_id, posmod(mote_index, AMBIENT_PARTICLE_ATLAS_COLUMNS))
		if texture == null:
			continue
		var angle: float = float(mote_index) * 2.399963 + 0.31
		var direction := Vector2(cos(angle), sin(angle))
		var radius: float = draw_size * lerpf(1.05, 0.18, pow(release_progress, 0.72)) * lerpf(0.72, 1.22, _ambient_hash01(16001 + mote_index * 211))
		var point: Vector2 = center + direction * radius
		var mote_size: float = draw_size * lerpf(0.075, 0.035, release_progress)
		_draw_ambient_particle_sprite(texture, point, Vector2.ONE * mote_size, -angle, alpha * (0.42 + release_progress * 0.34))

func _elemental_performance_frames(style: String) -> Array[Texture2D]:
	return _authored_elemental_frames("elemental_%s_performance" % _elemental_style_id(style))

func _elemental_impact_core_frames(style: String) -> Array[Texture2D]:
	match style:
		AttackFxLibrary.STYLE_EARTH_SPIKES:
			return _authored_elemental_frames("earth_spike_impact")
		AttackFxLibrary.STYLE_ICE_SHARDS:
			return _authored_elemental_frames("ice_icicle_impact")
		_:
			return _elemental_performance_frames(style)

func _elemental_performance_bloom_frames(style: String) -> Array[Texture2D]:
	return _authored_elemental_frames("elemental_%s_performance_bloom" % _elemental_style_id(style))

func _elemental_integration_profile(style: String) -> Dictionary:
	match style:
		AttackFxLibrary.STYLE_EARTH_SPIKES:
			return {
				"ground_anchor": Vector2(0.50, 0.80),
				"bloom_alpha": 0.42,
				"floor_alpha": 0.62,
				"volume_alpha": 0.54,
				"rear_core_alpha": 0.22,
				"front_core_alpha": 0.36,
				"front_bloom_alpha": 0.78,
				"front_veil_alpha": 0.50,
				"bloom_color": Color(1.0, 0.86, 0.62, 1.0),
				"volume_color": Color(0.78, 0.62, 0.42, 1.0),
			}
		AttackFxLibrary.STYLE_AIR_GUST:
			return {
				"ground_anchor": Vector2(0.50, 0.80),
				"bloom_alpha": 0.58,
				"floor_alpha": 0.54,
				"volume_alpha": 0.58,
				"rear_core_alpha": 0.16,
				"front_core_alpha": 0.25,
				"front_bloom_alpha": 0.84,
				"front_veil_alpha": 0.62,
				"bloom_color": Color(0.72, 0.93, 1.0, 1.0),
				"volume_color": Color(0.76, 0.91, 1.0, 1.0),
			}
		AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			return {
				"ground_anchor": Vector2(0.50, 0.78),
				"bloom_alpha": 0.94,
				"floor_alpha": 0.92,
				"volume_alpha": 0.48,
				"rear_core_alpha": 0.46,
				"front_core_alpha": 0.62,
				"front_bloom_alpha": 0.90,
				"front_veil_alpha": 0.54,
				"bloom_color": Color(0.76, 0.80, 1.0, 1.0),
				"volume_color": Color(0.66, 0.72, 1.0, 1.0),
			}
		AttackFxLibrary.STYLE_ICE_SHARDS:
			return {
				"ground_anchor": Vector2(0.50, 0.82),
				"bloom_alpha": 0.72,
				"floor_alpha": 0.76,
				"volume_alpha": 0.52,
				"rear_core_alpha": 0.20,
				"front_core_alpha": 0.34,
				"front_bloom_alpha": 0.88,
				"front_veil_alpha": 0.54,
				"bloom_color": Color(0.56, 0.84, 1.0, 1.0),
				"volume_color": Color(0.66, 0.86, 1.0, 1.0),
			}
		_:
			return {
				"ground_anchor": Vector2(0.50, 0.78),
				"bloom_alpha": 0.88,
				"floor_alpha": 0.88,
				"volume_alpha": 0.64,
				"rear_core_alpha": 0.18,
				"front_core_alpha": 0.30,
				"front_bloom_alpha": 0.96,
				"front_veil_alpha": 0.62,
				"bloom_color": Color(1.0, 0.62, 0.22, 1.0),
				"volume_color": Color(1.0, 0.42, 0.12, 1.0),
			}

func _elemental_performance_ground_anchor(style: String, frame_index: int = -1) -> Vector2:
	if frame_index >= 0:
		var frame_anchors: Array = []
		match style:
			AttackFxLibrary.STYLE_EARTH_SPIKES:
				frame_anchors = [0.68, 0.70, 0.72, 0.73, 0.80, 0.82, 0.82, 0.79]
			AttackFxLibrary.STYLE_AIR_GUST:
				frame_anchors = [0.77, 0.77, 0.78, 0.79, 0.80, 0.80, 0.80, 0.79]
			AttackFxLibrary.STYLE_LIGHTNING_BOLT:
				frame_anchors = [0.79, 0.79, 0.79, 0.79, 0.80, 0.80, 0.80, 0.79]
			AttackFxLibrary.STYLE_ICE_SHARDS:
				frame_anchors = [0.78, 0.79, 0.80, 0.81, 0.82, 0.82, 0.82, 0.81]
			_:
				frame_anchors = [0.75, 0.75, 0.76, 0.78, 0.80, 0.80, 0.79, 0.78]
		if frame_index < frame_anchors.size():
			return Vector2(0.50, frame_anchors[frame_index])
	var profile: Dictionary = _elemental_integration_profile(style)
	return profile.get("ground_anchor", Vector2(0.50, 0.78))

func _elemental_performance_modulate(style: String) -> Color:
	match style:
		AttackFxLibrary.STYLE_AIR_GUST:
			return Color(0.54, 0.92, 1.0, 1.0)
		AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			return Color(0.96, 0.98, 1.0, 1.0)
		_:
			return Color.WHITE

func _elemental_performance_size_scale(style: String) -> float:
	match style:
		AttackFxLibrary.STYLE_EARTH_SPIKES:
			return EARTH_IMPACT_SIZE_SCALE
		AttackFxLibrary.STYLE_AIR_GUST:
			return AIR_GUST_IMPACT_SIZE_SCALE
		AttackFxLibrary.STYLE_LIGHTNING_BOLT:
			return LIGHTNING_IMPACT_SIZE_SCALE
		AttackFxLibrary.STYLE_ICE_SHARDS:
			return ICE_IMPACT_SIZE_SCALE
		_:
			return 2.55

func _elemental_detonation_scale(style: String) -> float:
	return 1.0 if style == AttackFxLibrary.STYLE_LIGHTNING_BOLT else ELEMENTAL_COMPACT_DETONATION_SCALE

func _elemental_performance_size(style: String, impact_progress: float) -> float:
	var detonation_scale: float = _elemental_detonation_scale(style)
	var scale: float = _elemental_performance_size_scale(style) * detonation_scale
	var bloom: float = sin(clampf(impact_progress, 0.0, 1.0) * PI)
	var bloom_scale: float = 0.08 if style in [AttackFxLibrary.STYLE_EARTH_SPIKES, AttackFxLibrary.STYLE_ICE_SHARDS] else 0.16
	return clampf(
		_tile_width() * scale * (0.90 + bloom * bloom_scale),
		ELEMENTAL_PERFORMANCE_MIN_SIZE * detonation_scale,
		ELEMENTAL_PERFORMANCE_MAX_SIZE * detonation_scale
	)

func _elemental_impact_core_fade(style: String, impact_progress: float) -> float:
	if style == AttackFxLibrary.STYLE_FIREBALL:
		return 1.0 - smoothstep(0.64, 0.88, impact_progress)
	return 1.0 - smoothstep(0.86, 1.0, impact_progress)

func _elemental_impact_volume_fade(style: String, impact_progress: float) -> float:
	if style == AttackFxLibrary.STYLE_FIREBALL:
		return 1.0 - smoothstep(0.76, 1.0, impact_progress)
	return _elemental_impact_core_fade(style, impact_progress)

func _elemental_reduced_motion_frame_index(style: String, frame_count: int) -> int:
	var preferred_frame: int = 3 if style == AttackFxLibrary.STYLE_FIREBALL else 4
	return clampi(preferred_frame, 0, maxi(0, frame_count - 1))

func _elemental_performance_frame_blend(style: String, impact_progress: float, frame_count: int, reduced_motion: bool) -> Vector3:
	if frame_count <= 0:
		return Vector3.ZERO
	if reduced_motion:
		var reduced_frame_index: int = _elemental_reduced_motion_frame_index(style, frame_count)
		return Vector3(float(reduced_frame_index), float(reduced_frame_index), 0.0)
	if style != AttackFxLibrary.STYLE_FIREBALL:
		return AttackFxLibrary.one_shot_frame_blend(impact_progress, frame_count)
	# The tallest source cells touch their atlas ceiling. Skip those cells and let
	# scale, bloom, trails, and particles carry Fire's peak without exposing a
	# rectangular texture boundary.
	var safe_fire_sequence: Array = [0, 1, 2, 3, 3, 3, 7, 7]
	var scaled_progress: float = clampf(impact_progress, 0.0, 1.0) * float(safe_fire_sequence.size())
	var sequence_index: int = clampi(int(floor(scaled_progress)), 0, safe_fire_sequence.size() - 1)
	var next_sequence_index: int = mini(sequence_index + 1, safe_fire_sequence.size() - 1)
	var current_frame: int = clampi(int(safe_fire_sequence[sequence_index]), 0, frame_count - 1)
	var next_frame: int = clampi(int(safe_fire_sequence[next_sequence_index]), 0, frame_count - 1)
	var blend: float = 0.0 if current_frame == next_frame else smoothstep(0.0, 1.0, scaled_progress - floor(scaled_progress))
	return Vector3(float(current_frame), float(next_frame), blend)

func _draw_elemental_performance(style: String, ground_point: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> float:
	var core_frames: Array[Texture2D] = _elemental_impact_core_frames(style)
	if core_frames.is_empty() or alpha <= 0.0:
		return 0.0
	var bloom_frames: Array[Texture2D] = _elemental_performance_bloom_frames(style)
	var profile: Dictionary = _elemental_integration_profile(style)
	var element_id: String = _elemental_style_id(style)
	var sample_progress: float = 0.52 if reduced_motion else impact_progress
	var frame_blend: Vector3 = _elemental_performance_frame_blend(style, sample_progress, core_frames.size(), reduced_motion)
	var draw_size: float = _elemental_performance_size(style, sample_progress)
	var core_fade: float = 1.0 if reduced_motion else _elemental_impact_core_fade(style, impact_progress)
	var volume_fade: float = 1.0 if reduced_motion else _elemental_impact_volume_fade(style, impact_progress)
	var modulate: Color = _elemental_performance_modulate(style)
	var energy: float = 0.72 if reduced_motion else 0.48 + sin(clampf(impact_progress, 0.0, 1.0) * PI) * 0.52
	var core_alpha: float = alpha * core_fade
	var volume_alpha: float = alpha * volume_fade
	_draw_elemental_ground_contact(
		element_id,
		ground_point,
		impact_progress,
		draw_size,
		volume_alpha * float(profile.get("floor_alpha", 0.70))
	)
	_draw_elemental_background_volume(style, ground_point, impact_progress, draw_size, volume_alpha, reduced_motion)
	if not bloom_frames.is_empty():
		var bloom_blend: Vector3 = _remap_frame_blend(frame_blend, bloom_frames.size())
		var bloom_color: Color = profile.get("bloom_color", Color.WHITE)
		var bloom_alpha: float = float(profile.get("bloom_alpha", 0.65))
		var bloom_layer_count: int = 2 if reduced_motion else 3
		for bloom_layer: int in range(bloom_layer_count):
			var layer_scale: float = 1.34 - float(bloom_layer) * 0.14
			var layer_alpha: float = (0.16 + float(bloom_layer) * 0.10) * bloom_alpha * energy
			_draw_elemental_blended_performance_frames(
				bloom_frames,
				bloom_blend,
				ground_point,
				draw_size * layer_scale,
				core_alpha * layer_alpha,
				bloom_color,
				style
			)
	if not reduced_motion and int(frame_blend.x) > 0 and not bloom_frames.is_empty():
		var echo_frame_index: int = mini(int(frame_blend.x) - 1, bloom_frames.size() - 1)
		_draw_elemental_performance_frame(
			bloom_frames[echo_frame_index],
			ground_point + Vector2(0.0, draw_size * 0.025),
			draw_size * 1.16,
			core_alpha * 0.24,
			profile.get("bloom_color", Color.WHITE),
			style,
			echo_frame_index
		)
	_draw_elemental_blended_impact_core_frames(
		core_frames,
		frame_blend,
		ground_point,
		draw_size * (0.99 + energy * 0.012),
		core_alpha * float(profile.get("rear_core_alpha", 0.20)),
		modulate,
		style
	)
	return draw_size * maxf(core_fade, volume_fade)

func _remap_frame_blend(frame_blend: Vector3, frame_count: int) -> Vector3:
	if frame_count <= 0:
		return Vector3.ZERO
	return Vector3(
		float(clampi(int(frame_blend.x), 0, frame_count - 1)),
		float(clampi(int(frame_blend.y), 0, frame_count - 1)),
		clampf(frame_blend.z, 0.0, 1.0)
	)

func _offset_frame_blend(frame_blend: Vector3, frame_offset: int, frame_count: int) -> Vector3:
	if frame_count <= 0:
		return Vector3.ZERO
	return Vector3(
		float(posmod(int(frame_blend.x) + frame_offset, frame_count)),
		float(posmod(int(frame_blend.y) + frame_offset, frame_count)),
		clampf(frame_blend.z, 0.0, 1.0)
	)

func _draw_elemental_blended_performance_frames(frames: Array[Texture2D], frame_blend: Vector3, ground_point: Vector2, draw_size: float, alpha: float, modulate: Color, style: String) -> void:
	if frames.is_empty() or alpha <= 0.0:
		return
	var current_index: int = clampi(int(frame_blend.x), 0, frames.size() - 1)
	var next_index: int = clampi(int(frame_blend.y), 0, frames.size() - 1)
	var next_weight: float = clampf(frame_blend.z, 0.0, 1.0) if current_index != next_index else 0.0
	var current_weight: float = 1.0 - next_weight
	_draw_elemental_performance_frame(frames[current_index], ground_point, draw_size, alpha * current_weight, modulate, style, current_index)
	if next_weight > 0.0:
		_draw_elemental_performance_frame(frames[next_index], ground_point, draw_size, alpha * next_weight, modulate, style, next_index)

func _draw_elemental_blended_impact_core_frames(frames: Array[Texture2D], frame_blend: Vector3, ground_point: Vector2, draw_size: float, alpha: float, modulate: Color, style: String) -> void:
	if style not in [AttackFxLibrary.STYLE_EARTH_SPIKES, AttackFxLibrary.STYLE_ICE_SHARDS]:
		_draw_elemental_blended_performance_frames(frames, frame_blend, ground_point, draw_size, alpha, modulate, style)
		return
	if frames.is_empty() or alpha <= 0.0:
		return
	var current_index: int = clampi(int(frame_blend.x), 0, frames.size() - 1)
	var next_index: int = clampi(int(frame_blend.y), 0, frames.size() - 1)
	var next_weight: float = clampf(frame_blend.z, 0.0, 1.0) if current_index != next_index else 0.0
	_draw_authored_bottom_frame(frames[current_index], ground_point, draw_size, alpha * (1.0 - next_weight), modulate)
	if next_weight > 0.0:
		_draw_authored_bottom_frame(frames[next_index], ground_point, draw_size, alpha * next_weight, modulate)

func _draw_elemental_background_volume(style: String, ground_point: Vector2, impact_progress: float, draw_size: float, alpha: float, reduced_motion: bool) -> void:
	var profile: Dictionary = _elemental_integration_profile(style)
	var element_id: String = _elemental_style_id(style)
	var volume_color: Color = profile.get("volume_color", Color.WHITE)
	var volume_alpha: float = float(profile.get("volume_alpha", 0.50))
	var particle_count: int = 5 if reduced_motion else ELEMENTAL_BACKGROUND_VOLUME_COUNT
	for particle_index: int in range(particle_count):
		var variant: int = posmod(particle_index * 3 + 1, AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = null
		if element_id == "fire" or element_id == "earth":
			texture = _ambient_fire_soft_texture(variant)
		else:
			texture = _ambient_air_wisp_soft_texture(variant)
		if texture == null:
			texture = _elemental_ground_texture(element_id, variant)
		if texture == null:
			continue
		var seed: int = 27103 + particle_index * 1297 + element_id.length() * 79
		var particle_age: float = 0.44 if reduced_motion else clampf((impact_progress - float(particle_index) * 0.018) / 0.82, 0.0, 1.0)
		if particle_age <= 0.0 or particle_age >= 1.0:
			continue
		var side: float = lerpf(-1.0, 1.0, _ambient_hash01(seed))
		var depth: float = lerpf(0.66, 1.24, _ambient_hash01(seed + 3))
		var lift: float = draw_size * lerpf(0.04, 0.48, pow(particle_age, 0.72)) * depth
		var spread: float = draw_size * (0.10 + particle_age * 0.28) * side
		var point: Vector2 = ground_point + Vector2(spread, -lift)
		var particle_size := Vector2(
			draw_size * lerpf(0.24, 0.58, particle_age) * depth,
			draw_size * lerpf(0.16, 0.40, particle_age) * depth
		)
		var particle_fade: float = sin(particle_age * PI) * alpha * volume_alpha * lerpf(0.54, 0.90, _ambient_hash01(seed + 7))
		var plume_velocity := Vector2(side * draw_size * 0.16, -draw_size * lerpf(0.20, 0.38, particle_age))
		_draw_ambient_particle_trail(texture, point, plume_velocity, particle_size, particle_fade * 0.72, element_id)
		_draw_ambient_particle_sprite(
			texture,
			point,
			particle_size * Vector2(1.18, 1.12),
			lerpf(-0.48, 0.48, _ambient_hash01(seed + 11)) + particle_age * side * 0.34,
			particle_fade * 0.82,
			volume_color
		)

func _draw_elemental_performance_frame(texture: Texture2D, ground_point: Vector2, draw_size: float, alpha: float, modulate: Color = Color.WHITE, style: String = AttackFxLibrary.STYLE_FIREBALL, frame_index: int = -1) -> void:
	if texture == null or draw_size <= 0.0 or alpha <= 0.0:
		return
	var ground_anchor: Vector2 = _elemental_performance_ground_anchor(style, frame_index)
	var rect := Rect2(
		ground_point - Vector2(draw_size * ground_anchor.x, draw_size * ground_anchor.y),
		Vector2.ONE * draw_size
	)
	draw_texture_rect(texture, rect, false, Color(modulate.r, modulate.g, modulate.b, modulate.a * clampf(alpha, 0.0, 1.0)))

func _draw_earth_spike_attack_effect(effect: Dictionary, progress: float, from_point: Vector2, to_point: Vector2) -> void:
	var style: String = AttackFxLibrary.STYLE_EARTH_SPIKES
	var from_tile: Vector2i = effect.get("from", Vector2i(-1, -1))
	var to_tile: Vector2i = effect.get("to", Vector2i(-1, -1))
	var start: Vector2 = _elemental_ground_point(from_point)
	var end: Vector2 = _elemental_ground_point(to_point)
	if bool(presentation.get("reduced_motion", false)):
		if _render_layer_kind != RENDER_LAYER_SCENE_TILE or _render_layer_tile == to_tile:
			_draw_earth_impact(end, 0.52, 1.0, true)
		return
	if bool(effect.get("preview", false)):
		var phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
		_draw_earth_spike_path(start, end, phase, 0.62, from_tile, to_tile)
		return
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	var travel_progress: float = AttackFxLibrary.travel_progress_for_style(style, progress)
	if progress <= anticipation_end and (_render_layer_kind != RENDER_LAYER_SCENE_TILE or _render_layer_tile == from_tile):
		_draw_elemental_release(style, start, start, end, AttackFxLibrary.release_progress_for_style(style, progress))
	if progress >= anticipation_end and progress <= travel_end:
		_draw_earth_spike_path(start, end, travel_progress, 1.0, from_tile, to_tile)
	if progress >= travel_end and (_render_layer_kind != RENDER_LAYER_SCENE_TILE or _render_layer_tile == to_tile):
		_draw_earth_impact(end, AttackFxLibrary.impact_progress_for_style(style, progress), 1.0, false)

func _draw_earth_spike_path(start: Vector2, end: Vector2, travel_progress: float, alpha: float, from_tile: Vector2i = Vector2i(-1, -1), to_tile: Vector2i = Vector2i(-1, -1)) -> void:
	var frames: Array[Texture2D] = _elemental_performance_frames(AttackFxLibrary.STYLE_EARTH_SPIKES)
	var bloom_frames: Array[Texture2D] = _elemental_performance_bloom_frames(AttackFxLibrary.STYLE_EARTH_SPIKES)
	var ground_frames: Array[Texture2D] = _authored_elemental_frames("earth_ground_layer")
	if frames.is_empty():
		return
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var draw_size: float = clampf(_tile_width() * 1.02, 82.0, 118.0)
	for spike_index: int in range(EARTH_PATH_SPIKE_COUNT):
		var path_progress: float = lerpf(0.10, 0.96, float(spike_index) / float(EARTH_PATH_SPIKE_COUNT - 1))
		if (
			_render_layer_kind == RENDER_LAYER_SCENE_TILE
			and from_tile.x >= 0
			and _render_layer_tile != _elemental_lerp_depth_tile(from_tile, to_tile, path_progress)
		):
			continue
		var local_age: float = (travel_progress - path_progress) / 0.72
		if local_age < 0.0 or local_age >= 1.0:
			continue
		var spike_frame_count: int = mini(3, frames.size())
		var frame_blend: Vector3 = AttackFxLibrary.one_shot_frame_blend(clampf(local_age / 0.82, 0.0, 1.0), spike_frame_count)
		var side_offset: float = sin(float(spike_index) * 2.17) * draw_size * 0.08
		var point: Vector2 = start.lerp(end, path_progress) + normal * side_offset
		var scale_jitter: float = 0.86 + 0.14 * _ambient_hash01(3101 + spike_index * 337)
		var spike_fade: float = 1.0 - smoothstep(0.78, 1.0, local_age)
		if not ground_frames.is_empty():
			var ground_blend: Vector3 = AttackFxLibrary.one_shot_frame_blend(local_age, ground_frames.size())
			_draw_authored_ground_frame_blend(
				ground_frames,
				ground_blend,
				point,
				Vector2.ONE * draw_size * scale_jitter * 1.36,
				alpha * spike_fade * 0.58,
				Color(0.78, 0.68, 0.56, 1.0)
			)
		var dust_texture: Texture2D = _ambient_fire_soft_texture(posmod(spike_index, AMBIENT_FIRE_SOFT_ATLAS_COLUMNS))
		if dust_texture != null:
			_draw_ambient_particle_sprite(
				dust_texture,
				point + Vector2(0.0, -draw_size * lerpf(0.10, 0.26, local_age)),
				Vector2(draw_size * 1.12, draw_size * lerpf(0.42, 0.68, local_age)),
				side_offset * 0.003,
				alpha * spike_fade * 0.38,
				Color(0.72, 0.56, 0.38, 1.0)
			)
		if not bloom_frames.is_empty():
			_draw_elemental_blended_performance_frames(
				bloom_frames,
				_remap_frame_blend(frame_blend, bloom_frames.size()),
				point,
				draw_size * scale_jitter * 1.16,
				alpha * spike_fade * 0.36,
				Color(1.0, 0.84, 0.60, 1.0),
				AttackFxLibrary.STYLE_EARTH_SPIKES
			)
		_draw_elemental_blended_performance_frames(
			frames,
			frame_blend,
			point,
			draw_size * scale_jitter,
			alpha * spike_fade * 0.52,
			Color.WHITE,
			AttackFxLibrary.STYLE_EARTH_SPIKES
		)
		_draw_earth_spike_debris(point, local_age, draw_size, spike_index, alpha)

func _draw_earth_spike_debris(point: Vector2, local_age: float, draw_size: float, spike_index: int, alpha: float) -> void:
	if local_age < 0.18:
		return
	var debris_age: float = clampf((local_age - 0.18) / 0.82, 0.0, 1.0)
	for debris_index: int in range(3):
		var seed: int = 5501 + spike_index * 479 + debris_index * 149
		var texture: Texture2D = _ambient_particle_texture("earth", debris_index)
		if texture == null:
			continue
		var side: float = -1.0 if debris_index % 2 == 0 else 1.0
		var offset := Vector2(
			side * draw_size * (0.12 + 0.18 * debris_age),
			-draw_size * (0.14 + 0.22 * sin(debris_age * PI)) + draw_size * 0.18 * debris_age
		)
		offset.x *= lerpf(0.72, 1.20, _ambient_hash01(seed))
		var mote_size: float = draw_size * lerpf(0.105, 0.055, debris_age) * lerpf(0.72, 1.16, _ambient_hash01(seed + 3))
		_draw_ambient_particle_sprite(texture, point + offset, Vector2.ONE * mote_size, debris_age * 2.3 * side, alpha * pow(1.0 - debris_age, 0.72))

func _draw_earth_impact(point: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> void:
	var draw_size: float = _draw_elemental_performance(AttackFxLibrary.STYLE_EARTH_SPIKES, point, impact_progress, alpha, reduced_motion)
	if draw_size <= 0.0:
		return
	var fade: float = 1.0 if reduced_motion else 1.0 - smoothstep(0.86, 1.0, impact_progress)
	if not reduced_motion:
		_draw_elemental_impact_motes("earth", point, impact_progress, draw_size, alpha * fade, false)

func _draw_air_gust_attack_effect(effect: Dictionary, progress: float, from_point: Vector2, to_point: Vector2) -> void:
	var style: String = AttackFxLibrary.STYLE_AIR_GUST
	var start: Vector2 = _elemental_air_point(from_point, 0.62)
	var end: Vector2 = _elemental_air_point(to_point, 0.56)
	var ground_start: Vector2 = _elemental_ground_point(from_point)
	var ground_end: Vector2 = _elemental_ground_point(to_point)
	if bool(presentation.get("reduced_motion", false)):
		_draw_air_gust_impact(end, ground_end, 0.52, 1.0, true)
		return
	if bool(effect.get("preview", false)):
		var phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
		var preview_alpha: float = clampf(minf(phase / 0.14, (1.0 - phase) / 0.14), 0.0, 1.0) * 0.64
		_draw_air_gust_travel(start, end, ground_start, ground_end, lerpf(0.05, 0.95, phase), preview_alpha)
		return
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	if progress <= anticipation_end:
		_draw_elemental_release(style, start, ground_start, end, AttackFxLibrary.release_progress_for_style(style, progress))
	if progress >= anticipation_end and progress <= travel_end:
		_draw_air_gust_travel(start, end, ground_start, ground_end, AttackFxLibrary.travel_progress_for_style(style, progress), 1.0)
	if progress >= travel_end:
		_draw_air_gust_impact(end, ground_end, AttackFxLibrary.impact_progress_for_style(style, progress), 1.0, false)

func _draw_air_gust_travel(start: Vector2, end: Vector2, ground_start: Vector2, ground_end: Vector2, travel_progress: float, alpha: float) -> void:
	var frames: Array[Texture2D] = _authored_elemental_frames("air_gust_travel")
	var envelope_frames: Array[Texture2D] = _authored_elemental_frames("air_envelope_layer")
	if frames.is_empty() or alpha <= 0.0:
		return
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var draw_size: float = clampf(_tile_width() * AIR_GUST_TRAVEL_SIZE_SCALE, 96.0, 138.0)
	_draw_elemental_ground_trace("air", ground_start, ground_end, travel_progress, draw_size, alpha)
	for sweep_index: int in range(3):
		var sweep_progress: float = clampf(travel_progress * 1.34 - float(sweep_index) * 0.16, 0.0, 1.0)
		if sweep_progress <= 0.0:
			continue
		var frame_blend: Vector3 = _offset_frame_blend(
			AttackFxLibrary.looping_frame_blend(sweep_progress + float(sweep_index) * 0.17, frames.size(), 1.8),
			sweep_index * 2,
			frames.size()
		)
		var sweep_point: Vector2 = start.lerp(end, sweep_progress) + normal * sin(float(sweep_index) * 2.1 + sweep_progress * PI) * draw_size * (0.15 + float(sweep_index) * 0.04)
		var sweep_direction: Vector2 = direction.rotated(lerpf(-0.075, 0.075, float(sweep_index) / 2.0))
		var sweep_alpha: float = alpha * (0.72 - float(sweep_index) * 0.13) * (1.0 - smoothstep(0.78, 1.0, sweep_progress))
		var sweep_size := Vector2(draw_size * (2.30 + float(sweep_index) * 0.30), draw_size * (0.62 + float(sweep_index) * 0.08))
		_draw_authored_oriented_frame_blend(frames, frame_blend, sweep_point, sweep_direction, sweep_size, sweep_alpha * 0.74, Color(0.72, 0.93, 1.0, 1.0), Vector2(0.76, 0.50))
		if not envelope_frames.is_empty():
			var envelope_blend: Vector3 = _offset_frame_blend(_remap_frame_blend(frame_blend, envelope_frames.size()), sweep_index * 3, envelope_frames.size())
			_draw_authored_oriented_frame_blend(envelope_frames, envelope_blend, sweep_point - direction * draw_size * 0.18, sweep_direction.rotated(0.045 if sweep_index % 2 == 0 else -0.045), sweep_size * Vector2(1.12, 1.18), sweep_alpha * 0.58, Color(0.88, 0.98, 1.0, 1.0), Vector2(0.74, 0.50))
	_draw_air_wake_motes(start, end, travel_progress, direction, draw_size, alpha)

func _draw_air_wake_motes(start: Vector2, end: Vector2, travel_progress: float, direction: Vector2, draw_size: float, alpha: float) -> void:
	var normal := Vector2(-direction.y, direction.x)
	for mote_index: int in range(ELEMENTAL_TRAVEL_MOTE_COUNT):
		var spawn_progress: float = lerpf(0.02, 0.90, float(mote_index) / float(ELEMENTAL_TRAVEL_MOTE_COUNT - 1))
		if travel_progress < spawn_progress:
			continue
		var age: float = (travel_progress - spawn_progress) / 0.34
		if age >= 1.0:
			continue
		var seed: int = 7103 + mote_index * 631
		var variant: int = posmod(mote_index * 3, AMBIENT_AIR_WISP_VARIANTS)
		var texture: Texture2D = _ambient_air_wisp_texture(variant, clampi(int(age * 18.0), 0, AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
		if texture == null:
			texture = _ambient_air_wisp_soft_texture(variant)
		if texture == null:
			continue
		var side: float = -1.0 if mote_index % 2 == 0 else 1.0
		var base_point: Vector2 = start.lerp(end, spawn_progress)
		var point: Vector2 = base_point - direction * draw_size * age * 0.34 + normal * side * draw_size * (0.10 + age * 0.22) * lerpf(0.72, 1.28, _ambient_hash01(seed))
		var size := Vector2(draw_size * lerpf(0.26, 0.48, age), draw_size * lerpf(0.12, 0.22, age))
		_draw_ambient_particle_sprite(texture, point, size, direction.angle() + side * age * 0.32, alpha * pow(1.0 - age, 1.15) * 0.58, Color(0.78, 0.92, 1.0, 1.0))

func _draw_air_gust_impact(center: Vector2, ground_center: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> void:
	var draw_size: float = _draw_elemental_performance(AttackFxLibrary.STYLE_AIR_GUST, ground_center, impact_progress, alpha, reduced_motion)
	if draw_size <= 0.0:
		return
	var fade: float = 1.0 if reduced_motion else 1.0 - smoothstep(0.86, 1.0, impact_progress)
	if not reduced_motion:
		_draw_elemental_impact_motes("air", center, impact_progress, draw_size, alpha * fade, true)

func _draw_lightning_attack_effect(effect: Dictionary, progress: float, from_point: Vector2, to_point: Vector2) -> void:
	var style: String = AttackFxLibrary.STYLE_LIGHTNING_BOLT
	var start: Vector2 = _elemental_air_point(from_point, 0.66)
	var end: Vector2 = _elemental_air_point(to_point, 0.58)
	var ground_start: Vector2 = _elemental_ground_point(from_point)
	var ground_end: Vector2 = _elemental_ground_point(to_point)
	if bool(presentation.get("reduced_motion", false)):
		_draw_lightning_impact(end, ground_end, 0.52, 1.0, true)
		return
	if bool(effect.get("preview", false)):
		var phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / 1.35, 0.0, 1.0)
		var preview_alpha: float = clampf(minf(phase / 0.10, (1.0 - phase) / 0.10), 0.0, 1.0) * 0.66
		_draw_lightning_travel(start, end, ground_start, ground_end, lerpf(0.06, 0.96, phase), preview_alpha)
		return
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	if progress <= anticipation_end:
		_draw_elemental_release(style, start, ground_start, end, AttackFxLibrary.release_progress_for_style(style, progress))
	if progress >= anticipation_end and progress <= travel_end:
		_draw_lightning_travel(start, end, ground_start, ground_end, AttackFxLibrary.travel_progress_for_style(style, progress), 1.0)
	if progress >= travel_end:
		_draw_lightning_impact(end, ground_end, AttackFxLibrary.impact_progress_for_style(style, progress), 1.0, false)

func _draw_lightning_travel(start: Vector2, end: Vector2, ground_start: Vector2, ground_end: Vector2, travel_progress: float, alpha: float) -> void:
	var frames: Array[Texture2D] = _authored_elemental_frames("lightning_bolt_travel")
	var envelope_frames: Array[Texture2D] = _authored_elemental_frames("lightning_envelope_layer")
	if frames.is_empty() or alpha <= 0.0:
		return
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var frame_blend: Vector3 = AttackFxLibrary.looping_frame_blend(travel_progress, frames.size(), 2.85)
	var draw_size: float = clampf(_tile_width() * LIGHTNING_TRAVEL_SIZE_SCALE, 94.0, 138.0)
	_draw_elemental_ground_trace("lightning", ground_start, ground_end, travel_progress, draw_size, alpha)
	var lane_length: float = start.distance_to(end)
	var lane_center: Vector2 = start.lerp(end, 0.50)
	var search_alpha: float = (1.0 - smoothstep(0.34, 0.60, travel_progress)) * alpha
	if not envelope_frames.is_empty() and search_alpha > 0.0:
		for branch_index: int in range(2):
			var branch_blend: Vector3 = _offset_frame_blend(_remap_frame_blend(frame_blend, envelope_frames.size()), branch_index * 3, envelope_frames.size())
			var branch_offset: float = (-1.0 if branch_index == 0 else 1.0) * draw_size * 0.12
			_draw_authored_oriented_frame_blend(
				envelope_frames,
				branch_blend,
				lane_center + normal * branch_offset,
				direction.rotated((-0.035 if branch_index == 0 else 0.035)),
				Vector2(lane_length * lerpf(0.72, 1.02, travel_progress), draw_size * 0.72),
				search_alpha * (0.30 + float(branch_index) * 0.12),
				Color(0.64, 0.72, 1.0, 1.0)
			)
	var strike_alpha: float = smoothstep(0.22, 0.42, travel_progress) * (1.0 - smoothstep(0.97, 1.0, travel_progress)) * alpha
	if strike_alpha > 0.0:
		var jitter_direction: Vector2 = direction.rotated(sin(travel_progress * TAU * 7.0) * 0.018)
		_draw_authored_oriented_frame_blend(
			frames,
			frame_blend,
			lane_center,
			jitter_direction,
			Vector2(lane_length + draw_size * 0.72, draw_size * (0.82 + strike_alpha * 0.34)),
			strike_alpha * 0.96,
			Color.WHITE,
			Vector2(0.50, 0.50)
		)
	_draw_elemental_travel_motes("lightning", start, end, travel_progress, direction, draw_size, alpha * 0.62)

func _draw_lightning_impact(center: Vector2, ground_center: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> void:
	var draw_size: float = _draw_elemental_performance(AttackFxLibrary.STYLE_LIGHTNING_BOLT, ground_center, impact_progress, alpha, reduced_motion)
	if draw_size <= 0.0:
		return
	var fade: float = 1.0 if reduced_motion else 1.0 - smoothstep(0.82, 1.0, impact_progress)
	var burst_frames: Array[Texture2D] = _authored_elemental_frames("lightning_bolt_impact")
	if not burst_frames.is_empty():
		var burst_progress: float = 0.52 if reduced_motion else clampf(0.14 + impact_progress * 0.90, 0.0, 1.0)
		var burst_frame_index: int = AttackFxLibrary.one_shot_frame_index(burst_progress, burst_frames.size())
		var burst_blend: Vector3 = Vector3(float(burst_frame_index), float(burst_frame_index), 0.0) if reduced_motion else AttackFxLibrary.one_shot_frame_blend(burst_progress, burst_frames.size())
		var burst_energy: float = sin(burst_progress * PI)
		_draw_authored_oriented_frame_blend(
			burst_frames,
			burst_blend,
			ground_center,
			Vector2.RIGHT,
			Vector2.ONE * draw_size * (0.60 + burst_energy * 0.24),
			alpha * fade * (0.68 + burst_energy * 0.26),
			Color(0.78, 0.86, 1.0, 1.0),
			Vector2(0.50, 0.50)
		)
	if not reduced_motion:
		_draw_elemental_impact_motes("lightning", ground_center, impact_progress, draw_size, alpha * fade, false)

func _draw_ice_shard_attack_effect(effect: Dictionary, progress: float, from_point: Vector2, to_point: Vector2) -> void:
	var style: String = AttackFxLibrary.STYLE_ICE_SHARDS
	var start: Vector2 = _elemental_air_point(from_point, 0.60)
	var end: Vector2 = _elemental_air_point(to_point, 0.40)
	var ground_start: Vector2 = _elemental_ground_point(from_point)
	var ground_end: Vector2 = _elemental_ground_point(to_point)
	if bool(presentation.get("reduced_motion", false)):
		_draw_ice_icicle_impact(ground_end, 0.52, 1.0, true)
		return
	if bool(effect.get("preview", false)):
		var phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
		var preview_alpha: float = clampf(minf(phase / 0.14, (1.0 - phase) / 0.14), 0.0, 1.0) * 0.66
		_draw_ice_shard_travel(start, end, ground_start, ground_end, lerpf(0.05, 0.95, phase), preview_alpha)
		return
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	if progress <= anticipation_end:
		_draw_elemental_release(style, start, ground_start, end, AttackFxLibrary.release_progress_for_style(style, progress))
	if progress >= anticipation_end and progress <= travel_end:
		_draw_ice_shard_travel(start, end, ground_start, ground_end, AttackFxLibrary.travel_progress_for_style(style, progress), 1.0)
	if progress >= travel_end:
		_draw_ice_icicle_impact(ground_end, AttackFxLibrary.impact_progress_for_style(style, progress), 1.0, false)

func _draw_ice_shard_travel(start: Vector2, end: Vector2, ground_start: Vector2, ground_end: Vector2, travel_progress: float, alpha: float) -> void:
	var frames: Array[Texture2D] = _authored_elemental_frames("ice_shard_travel")
	if frames.is_empty() or alpha <= 0.0:
		return
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var draw_size: float = clampf(_tile_width() * ICE_TRAVEL_SIZE_SCALE, 90.0, 132.0)
	_draw_elemental_ground_trace("ice", ground_start, ground_end, travel_progress, draw_size, alpha)
	for shard_wave: int in range(3):
		var shard_progress: float = clampf(travel_progress * 1.42 - float(shard_wave) * 0.17, 0.0, 1.0)
		if shard_progress <= 0.0:
			continue
		var frame_blend: Vector3 = _offset_frame_blend(
			AttackFxLibrary.looping_frame_blend(shard_progress + float(shard_wave) * 0.21, frames.size(), 1.7),
			shard_wave * 2,
			frames.size()
		)
		var frame_index: int = int(frame_blend.x)
		var point: Vector2 = start.lerp(end, shard_progress) + normal * (-1.0 + float(shard_wave)) * draw_size * (0.15 + 0.05 * shard_progress)
		var wave_direction: Vector2 = direction.rotated((-0.052 + float(shard_wave) * 0.052) * (1.0 - shard_progress * 0.45))
		var wave_alpha: float = alpha * (0.92 - float(shard_wave) * 0.16) * (1.0 - smoothstep(0.84, 1.0, shard_progress))
		var wave_size := Vector2(draw_size * (1.20 + float(shard_wave) * 0.16), draw_size * (0.70 + float(shard_wave) * 0.06))
		var glow_texture: Texture2D = _ambient_particle_glow_texture("ice", frame_index)
		if glow_texture != null:
			_draw_ambient_particle_sprite(glow_texture, point - direction * draw_size * 0.18, wave_size * Vector2(1.30, 1.12), wave_direction.angle(), wave_alpha * 0.22, Color(0.58, 0.86, 1.0, 1.0))
		_draw_authored_oriented_frame_blend(frames, frame_blend, point, wave_direction, wave_size, wave_alpha * 0.76, Color.WHITE, Vector2(0.84, 0.50))
	_draw_elemental_travel_motes("ice", start, end, travel_progress, direction, draw_size, alpha)
	if travel_progress > 0.48:
		var ground_frames: Array[Texture2D] = _authored_elemental_frames("ice_ground_layer")
		if not ground_frames.is_empty():
			var frost_age: float = clampf((travel_progress - 0.48) / 0.52, 0.0, 1.0)
			var frost_blend: Vector3 = AttackFxLibrary.one_shot_frame_blend(frost_age * 0.18, ground_frames.size())
			_draw_authored_ground_frame_blend(
				ground_frames,
				frost_blend,
				ground_end,
				Vector2(clampf(_tile_width() * 1.34, 122.0, 164.0), clampf(_tile_height() * 0.62, 34.0, 56.0)),
				alpha * frost_age * 0.40,
				Color.WHITE
			)

func _draw_ice_icicle_impact(point: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> void:
	var draw_size: float = _draw_elemental_performance(AttackFxLibrary.STYLE_ICE_SHARDS, point, impact_progress, alpha, reduced_motion)
	if draw_size <= 0.0:
		return
	var fade: float = 1.0 if reduced_motion else 1.0 - smoothstep(0.88, 1.0, impact_progress)
	if not reduced_motion:
		_draw_elemental_impact_motes("ice", point, impact_progress, draw_size, alpha * fade, false)

func _draw_elemental_travel_motes(element_id: String, start: Vector2, end: Vector2, travel_progress: float, direction: Vector2, draw_size: float, alpha: float) -> void:
	var normal := Vector2(-direction.y, direction.x)
	for mote_index: int in range(ELEMENTAL_TRAVEL_MOTE_COUNT):
		var spawn_progress: float = lerpf(0.02, 0.90, float(mote_index) / float(ELEMENTAL_TRAVEL_MOTE_COUNT - 1))
		if travel_progress < spawn_progress:
			continue
		var age: float = (travel_progress - spawn_progress) / 0.32
		if age >= 1.0:
			continue
		var seed: int = 9109 + mote_index * 733 + (17 if element_id == "ice" else 0)
		var variant: int = posmod(mote_index * 3 + 1, AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = _ambient_particle_texture(element_id, variant)
		var glow_texture: Texture2D = _ambient_particle_glow_texture(element_id, variant)
		if texture == null and glow_texture == null:
			continue
		var side: float = -1.0 if mote_index % 2 == 0 else 1.0
		var base_point: Vector2 = start.lerp(end, spawn_progress)
		var side_drift: float = side * draw_size * (0.08 + 0.18 * age) * lerpf(0.70, 1.24, _ambient_hash01(seed))
		var point: Vector2 = base_point - direction * draw_size * age * 0.24 + normal * side_drift + Vector2(0.0, draw_size * (0.10 if element_id == "ice" else -0.06) * age)
		var fade: float = pow(1.0 - age, 1.08) * alpha
		var mote_size: float = draw_size * lerpf(0.095, 0.045, age) * lerpf(0.72, 1.20, _ambient_hash01(seed + 3))
		if glow_texture != null:
			_draw_ambient_particle_sprite(glow_texture, point - direction * mote_size * 0.4, Vector2(mote_size * 2.4, mote_size * 1.12), direction.angle(), fade * 0.28)
		if texture != null:
			_draw_ambient_particle_sprite(texture, point, Vector2.ONE * mote_size, direction.angle() + side * age * 0.72, fade * 0.86)

func _draw_elemental_impact_motes(element_id: String, center: Vector2, impact_progress: float, draw_size: float, alpha: float, use_air_wisps: bool) -> void:
	if impact_progress < 0.08 or alpha <= 0.0:
		return
	var age: float = clampf((impact_progress - 0.08) / 0.92, 0.0, 1.0)
	for mote_index: int in range(ELEMENTAL_IMPACT_MOTE_COUNT):
		var seed: int = 11299 + mote_index * 887
		var angle: float = float(mote_index) * 2.399963 + lerpf(-0.20, 0.20, _ambient_hash01(seed))
		var direction := Vector2(cos(angle), sin(angle))
		var radial_distance: float = draw_size * lerpf(0.28, 0.68, _ambient_hash01(seed + 3)) * pow(age, 0.66)
		var depth_scale: float = lerpf(0.72, 1.24, (sin(angle) + 1.0) * 0.5)
		var point: Vector2
		if use_air_wisps:
			point = center + direction * radial_distance
		else:
			var lift_scale: float = 0.28 if element_id == "lightning" else 0.44
			var ballistic_lift: float = draw_size * lift_scale * lerpf(0.68, 1.18, _ambient_hash01(seed + 5)) * sin(age * PI)
			var floor_direction := Vector2(direction.x, direction.y * 0.42)
			point = center + floor_direction * radial_distance + Vector2(0.0, -ballistic_lift + draw_size * 0.10 * age * age)
		var fade: float = pow(1.0 - age, 0.88) * alpha * lerpf(0.72, 1.0, _ambient_hash01(seed + 7))
		if use_air_wisps:
			var air_texture: Texture2D = _ambient_air_wisp_texture(posmod(mote_index, AMBIENT_AIR_WISP_VARIANTS), clampi(int(age * 18.0), 0, AMBIENT_AIR_WISP_FULL_FRAME_INDEX))
			if air_texture != null:
				_draw_ambient_particle_sprite(air_texture, point, Vector2(draw_size * lerpf(0.22, 0.42, age), draw_size * 0.14) * depth_scale, angle, fade * 0.52, Color(0.78, 0.92, 1.0, 1.0))
			continue
		var variant: int = posmod(mote_index * 5 + 2, AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = _ambient_particle_texture(element_id, variant)
		var glow_texture: Texture2D = _ambient_particle_glow_texture(element_id, variant)
		var mote_size: float = draw_size * lerpf(0.070, 0.030, age) * lerpf(0.74, 1.18, _ambient_hash01(seed + 11)) * depth_scale
		if glow_texture != null:
			_draw_ambient_particle_sprite(glow_texture, point, Vector2(mote_size * 2.2, mote_size * 1.12), angle, fade * 0.24)
		if texture != null:
			_draw_ambient_particle_sprite(texture, point, Vector2.ONE * mote_size, angle + age * 1.6, fade * 0.82)

func _draw_elemental_ground_trace(element_id: String, start: Vector2, end: Vector2, travel_progress: float, draw_size: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	for echo_index: int in range(3, -1, -1):
		var echo_progress: float = maxf(0.0, travel_progress - float(echo_index) * 0.055)
		var point: Vector2 = start.lerp(end, echo_progress)
		var frame_index: int = AttackFxLibrary.looping_frame_index(echo_progress + float(echo_index) * 0.13, AMBIENT_PARTICLE_ATLAS_COLUMNS, 2.3)
		var texture: Texture2D = _elemental_ground_texture(element_id, frame_index)
		if texture == null:
			continue
		var age: float = float(echo_index) / 3.0
		var strength: float = lerpf(0.26, 0.055, age)
		var footprint := Vector2(
			draw_size * lerpf(0.82, 1.12, age),
			maxf(10.0, _tile_height() * lerpf(0.18, 0.12, age))
		)
		_draw_ambient_particle_sprite(texture, point, footprint, 0.0, alpha * strength, _elemental_ground_modulate(element_id))

func _draw_elemental_ground_contact(element_id: String, center: Vector2, impact_progress: float, draw_size: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var bloom: float = sin(clampf(impact_progress, 0.0, 1.0) * PI)
	var frame_blend: Vector3 = AttackFxLibrary.one_shot_frame_blend(impact_progress, 8)
	for layer_index: int in range(3):
		var layer_scale: float = 1.0 + float(layer_index) * 0.18
		var footprint_width: float = draw_size * (0.86 + bloom * _elemental_ground_contact_expansion(element_id)) * layer_scale
		var footprint := Vector2(footprint_width, maxf(18.0, footprint_width * 0.36))
		var next_weight: float = clampf(frame_blend.z, 0.0, 1.0) if int(frame_blend.x) != int(frame_blend.y) else 0.0
		var current_weight: float = 1.0 - next_weight
		for blend_index: int in range(2):
			var frame_index: int = int(frame_blend.x) if blend_index == 0 else int(frame_blend.y)
			var frame_weight: float = current_weight if blend_index == 0 else next_weight
			if frame_weight <= 0.0:
				continue
			var texture: Texture2D = _elemental_floor_light_texture(element_id, frame_index)
			if texture == null:
				continue
			_draw_elemental_floor_light_sprite(
				element_id,
				texture,
				center,
				footprint,
				alpha * (0.34 - float(layer_index) * 0.095) * frame_weight,
				_elemental_ground_modulate(element_id),
				frame_index
			)

func _elemental_ground_contact_expansion(element_id: String) -> float:
	match element_id:
		"ice":
			return 0.10
		"earth":
			return 0.18
		_:
			return 0.46

func _elemental_ground_texture(element_id: String, frame_index: int) -> Texture2D:
	match element_id:
		"fire":
			return _ambient_fire_soft_texture(frame_index)
		"air":
			return _ambient_air_wisp_soft_texture(frame_index)
	var glow_texture: Texture2D = _ambient_particle_glow_texture(element_id, frame_index)
	if glow_texture != null:
		return glow_texture
	return _ambient_particle_texture(element_id, frame_index)

func _elemental_floor_light_texture(element_id: String, frame_index: int) -> Texture2D:
	var ground_layer_key: String = ""
	if element_id == "earth":
		ground_layer_key = "earth_ground_layer"
	elif element_id == "ice":
		ground_layer_key = "ice_ground_layer"
	if not ground_layer_key.is_empty():
		var ground_frames: Array[Texture2D] = _authored_elemental_frames(ground_layer_key)
		if not ground_frames.is_empty():
			return ground_frames[posmod(frame_index, ground_frames.size())]
	var bloom_frames: Array[Texture2D] = _authored_elemental_frames("elemental_%s_performance_bloom" % element_id)
	if not bloom_frames.is_empty():
		return bloom_frames[posmod(frame_index, bloom_frames.size())]
	return _elemental_ground_texture(element_id, frame_index)

func _elemental_style_for_id(element_id: String) -> String:
	match element_id:
		"earth":
			return AttackFxLibrary.STYLE_EARTH_SPIKES
		"air":
			return AttackFxLibrary.STYLE_AIR_GUST
		"lightning":
			return AttackFxLibrary.STYLE_LIGHTNING_BOLT
		"ice":
			return AttackFxLibrary.STYLE_ICE_SHARDS
		_:
			return AttackFxLibrary.STYLE_FIREBALL

func _draw_elemental_floor_light_sprite(element_id: String, texture: Texture2D, floor_point: Vector2, draw_size: Vector2, alpha: float, modulate: Color, frame_index: int) -> void:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0 or alpha <= 0.0:
		return
	var style: String = _elemental_style_for_id(element_id)
	var source_anchor: Vector2 = Vector2(0.50, 0.50) if element_id in ["earth", "ice"] else _elemental_performance_ground_anchor(style, frame_index)
	var rect := Rect2(
		floor_point - Vector2(draw_size.x * source_anchor.x, draw_size.y * source_anchor.y),
		draw_size
	)
	draw_texture_rect(texture, rect, false, Color(modulate.r, modulate.g, modulate.b, modulate.a * clampf(alpha, 0.0, 1.0)))

func _elemental_ground_modulate(element_id: String) -> Color:
	match element_id:
		"fire":
			return Color(1.0, 0.42, 0.08, 1.0)
		"air":
			return Color(0.66, 0.88, 1.0, 1.0)
		"lightning":
			return Color(0.64, 0.70, 1.0, 1.0)
		"ice":
			return Color(0.52, 0.82, 1.0, 1.0)
		_:
			return Color.WHITE

func _draw_authored_oriented_frame(texture: Texture2D, center: Vector2, direction: Vector2, draw_size: Vector2, alpha: float, modulate: Color = Color.WHITE, anchor: Vector2 = Vector2(0.5, 0.5)) -> void:
	if texture == null or alpha <= 0.0 or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var facing: Vector2 = direction.normalized()
	if facing.length_squared() <= 0.01:
		facing = Vector2.RIGHT
	var rect := Rect2(Vector2(-draw_size.x * anchor.x, -draw_size.y * anchor.y), draw_size)
	draw_set_transform(center, facing.angle(), Vector2.ONE)
	draw_texture_rect(texture, rect, false, Color(modulate.r, modulate.g, modulate.b, modulate.a * clampf(alpha, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_authored_oriented_frame_blend(frames: Array[Texture2D], frame_blend: Vector3, center: Vector2, direction: Vector2, draw_size: Vector2, alpha: float, modulate: Color = Color.WHITE, anchor: Vector2 = Vector2(0.5, 0.5)) -> void:
	if frames.is_empty() or alpha <= 0.0:
		return
	var current_index: int = clampi(int(frame_blend.x), 0, frames.size() - 1)
	var next_index: int = clampi(int(frame_blend.y), 0, frames.size() - 1)
	var next_weight: float = clampf(frame_blend.z, 0.0, 1.0) if current_index != next_index else 0.0
	_draw_authored_oriented_frame(frames[current_index], center, direction, draw_size, alpha * (1.0 - next_weight), modulate, anchor)
	if next_weight > 0.0:
		_draw_authored_oriented_frame(frames[next_index], center, direction, draw_size, alpha * next_weight, modulate, anchor)

func _draw_authored_ground_frame(texture: Texture2D, center: Vector2, draw_size: Vector2, alpha: float, modulate: Color = Color.WHITE) -> void:
	if texture == null or alpha <= 0.0 or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	draw_texture_rect(texture, rect, false, Color(modulate.r, modulate.g, modulate.b, modulate.a * clampf(alpha, 0.0, 1.0)))

func _draw_authored_ground_frame_blend(frames: Array[Texture2D], frame_blend: Vector3, center: Vector2, draw_size: Vector2, alpha: float, modulate: Color = Color.WHITE) -> void:
	if frames.is_empty() or alpha <= 0.0:
		return
	var current_index: int = clampi(int(frame_blend.x), 0, frames.size() - 1)
	var next_index: int = clampi(int(frame_blend.y), 0, frames.size() - 1)
	var next_weight: float = clampf(frame_blend.z, 0.0, 1.0) if current_index != next_index else 0.0
	_draw_authored_ground_frame(frames[current_index], center, draw_size, alpha * (1.0 - next_weight), modulate)
	if next_weight > 0.0:
		_draw_authored_ground_frame(frames[next_index], center, draw_size, alpha * next_weight, modulate)

func _draw_authored_bottom_frame(texture: Texture2D, ground_point: Vector2, draw_size: float, alpha: float, modulate: Color = Color.WHITE) -> void:
	if texture == null or alpha <= 0.0 or draw_size <= 0.0:
		return
	var rect := Rect2(ground_point + Vector2(-draw_size * 0.5, -draw_size * 0.957), Vector2.ONE * draw_size)
	draw_texture_rect(texture, rect, false, Color(modulate.r, modulate.g, modulate.b, modulate.a * clampf(alpha, 0.0, 1.0)))

func _authored_elemental_frames(frame_key: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_var: Variant in _effect_frames.get(frame_key, []):
		if frame_var is Texture2D:
			frames.append(frame_var)
	return frames

func _draw_fireball_attack_effect(effect: Dictionary, progress: float, from_point: Vector2, to_point: Vector2) -> void:
	var style: String = AttackFxLibrary.STYLE_FIREBALL
	var start: Vector2 = _elemental_air_point(from_point, 0.72)
	var end: Vector2 = _elemental_air_point(to_point, 0.66)
	var ground_start: Vector2 = _elemental_ground_point(from_point)
	var ground_end: Vector2 = _elemental_ground_point(to_point)
	if bool(presentation.get("reduced_motion", false)):
		_draw_fireball_impact_frame(end, ground_end, 0.52, 1.0, true)
		return
	if bool(effect.get("preview", false)):
		var preview_phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
		var preview_travel: float = lerpf(0.06, 0.94, preview_phase)
		var preview_alpha: float = clampf(minf(preview_phase / 0.14, (1.0 - preview_phase) / 0.14), 0.0, 1.0) * 0.66
		_draw_fireball_travel_composite(start, end, ground_start, ground_end, preview_travel, preview_alpha, true)
		return
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_progress: float = AttackFxLibrary.fireball_travel_progress(progress)
	if progress <= anticipation_end:
		_draw_elemental_release(style, start, ground_start, end, AttackFxLibrary.release_progress_for_style(style, progress))
	if progress >= anticipation_end and progress <= AttackFxLibrary.FIREBALL_TRAVEL_END_PROGRESS:
		_draw_fireball_travel_composite(start, end, ground_start, ground_end, travel_progress, 1.0, false)
	var impact_progress: float = AttackFxLibrary.fireball_impact_progress(progress)
	if progress >= AttackFxLibrary.FIREBALL_TRAVEL_END_PROGRESS:
		_draw_fireball_impact_frame(end, ground_end, impact_progress, 1.0, false)

func _draw_fireball_travel_composite(start: Vector2, end: Vector2, ground_start: Vector2, ground_end: Vector2, travel_progress: float, alpha: float, preview: bool) -> void:
	var frames: Array[Texture2D] = _fireball_frames("fireball_travel")
	if frames.is_empty() or alpha <= 0.0:
		return
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var draw_size: float = clampf(_tile_width() * FIREBALL_TRAVEL_DRAW_TILE_SCALE, FIREBALL_TRAVEL_MIN_SIZE, FIREBALL_TRAVEL_MAX_SIZE)
	var frame_blend: Vector3 = AttackFxLibrary.looping_frame_blend(travel_progress, frames.size(), FIREBALL_TRAVEL_CYCLES)
	var frame_index: int = int(frame_blend.x)
	var glow_texture: Texture2D = _ambient_fire_soft_texture(frame_index)
	var point: Vector2 = _fireball_travel_point(start, end, travel_progress)
	var turbulence_phase: float = travel_progress * TAU * 2.35
	_draw_elemental_ground_trace("fire", ground_start, ground_end, travel_progress, draw_size, alpha * (0.56 if preview else 0.78))
	if glow_texture != null:
		_draw_ambient_particle_sprite(
			glow_texture,
			point - direction * draw_size * 0.24,
			Vector2(draw_size * 1.92, draw_size * 0.92),
			direction.angle(),
			alpha * (0.18 if preview else 0.34),
			Color(1.0, 0.42, 0.10, 1.0)
		)
	_draw_fireball_wake(point, direction, normal, draw_size, travel_progress, alpha, preview)
	for afterimage_index: int in range(FIREBALL_AFTERIMAGE_COUNT, 0, -1):
		var afterimage_progress: float = maxf(0.0, travel_progress - FIREBALL_AFTERIMAGE_SPACING * float(afterimage_index))
		if is_equal_approx(afterimage_progress, travel_progress):
			continue
		var afterimage_point: Vector2 = _fireball_travel_point(start, end, afterimage_progress)
		var afterimage_blend: Vector3 = _offset_frame_blend(
			AttackFxLibrary.looping_frame_blend(afterimage_progress, frames.size(), FIREBALL_TRAVEL_CYCLES),
			-afterimage_index,
			frames.size()
		)
		var afterimage_alpha: float = alpha * (0.025 + float(FIREBALL_AFTERIMAGE_COUNT - afterimage_index) * 0.030)
		var afterimage_scale: float = 0.68 + float(FIREBALL_AFTERIMAGE_COUNT - afterimage_index) * 0.06
		_draw_authored_oriented_frame_blend(
			frames,
			afterimage_blend,
			afterimage_point,
			direction,
			Vector2(draw_size * afterimage_scale * 1.38, draw_size * afterimage_scale * 0.72),
			afterimage_alpha,
			Color.WHITE,
			FIREBALL_FRAME_CORE_ANCHOR
		)
	_draw_fireball_travel_embers(start, end, travel_progress, direction, normal, draw_size, alpha * (0.62 if preview else 1.0))
	var core_scale: float = 0.92 + 0.085 * sin(turbulence_phase + float(frame_index) * 0.71)
	var core_direction: Vector2 = direction.rotated(sin(turbulence_phase * 0.77) * 0.026)
	var velocity_stretch: float = 1.35 + sin(travel_progress * PI) * 0.78
	_draw_authored_oriented_frame_blend(
		frames,
		frame_blend,
		point,
		core_direction,
		Vector2(draw_size * core_scale * velocity_stretch, draw_size * core_scale * lerpf(0.82, 0.58, sin(travel_progress * PI))),
		alpha * 0.78,
		Color.WHITE,
		FIREBALL_FRAME_CORE_ANCHOR
	)

func _draw_fireball_wake(point: Vector2, direction: Vector2, normal: Vector2, draw_size: float, travel_progress: float, alpha: float, preview: bool) -> void:
	var wake_frames: Array[Texture2D] = _fireball_frames("fireball_wake")
	if wake_frames.is_empty():
		return
	var frame_blend: Vector3 = AttackFxLibrary.looping_frame_blend(travel_progress, wake_frames.size(), FIREBALL_WAKE_CYCLES)
	var secondary_frame_blend: Vector3 = _offset_frame_blend(frame_blend, 3, wake_frames.size())
	var frame_index: int = int(frame_blend.x)
	var phase: float = travel_progress * TAU * 2.10
	var pulse: float = 0.96 + sin(phase + float(frame_index) * 0.61) * 0.065
	var wake_size := Vector2(draw_size * 1.78 * pulse, draw_size * (0.88 + cos(phase * 1.17) * 0.055))
	var turbulence_offset: Vector2 = normal * sin(phase * 1.31) * draw_size * 0.036
	_draw_authored_oriented_frame_blend(
		wake_frames,
		secondary_frame_blend,
		point - direction * draw_size * 0.16 - turbulence_offset * 0.72,
		direction.rotated(-sin(phase) * 0.045),
		wake_size * Vector2(1.10, 1.14),
		alpha * (0.11 if preview else 0.22),
		Color(0.74, 0.28, 0.14, 1.0),
		FIREBALL_WAKE_CORE_ANCHOR
	)
	_draw_authored_oriented_frame_blend(
		wake_frames,
		frame_blend,
		point - direction * draw_size * 0.06 + turbulence_offset,
		direction.rotated(sin(phase * 0.83) * 0.030),
		wake_size,
		alpha * (0.47 if preview else 0.76),
		Color(1.0, 0.86, 0.72, 1.0),
		FIREBALL_WAKE_CORE_ANCHOR
	)

func _draw_fireball_wake_sprite(texture: Texture2D, core_point: Vector2, direction: Vector2, draw_size: Vector2, alpha: float, modulate: Color) -> void:
	if texture == null or draw_size.x <= 0.0 or draw_size.y <= 0.0 or alpha <= 0.0:
		return
	var rect := Rect2(
		Vector2(-draw_size.x * FIREBALL_WAKE_CORE_ANCHOR.x, -draw_size.y * FIREBALL_WAKE_CORE_ANCHOR.y),
		draw_size
	)
	draw_set_transform(core_point, direction.angle(), Vector2.ONE)
	draw_texture_rect(texture, rect, false, Color(modulate.r, modulate.g, modulate.b, modulate.a * clampf(alpha, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fireball_travel_embers(start: Vector2, end: Vector2, travel_progress: float, direction: Vector2, normal: Vector2, draw_size: float, alpha: float) -> void:
	for ember_index: int in range(FIREBALL_TRAVEL_EMBER_COUNT):
		var spawn_progress: float = 0.025 + float(ember_index) / float(FIREBALL_TRAVEL_EMBER_COUNT - 1) * 0.88
		if travel_progress < spawn_progress:
			continue
		var age: float = (travel_progress - spawn_progress) / 0.30
		if age >= 1.0:
			continue
		var seed: int = 1901 + ember_index * 811
		var variant_index: int = posmod(ember_index * 3 + 1, AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = _ambient_particle_texture("fire", variant_index)
		var soft_texture: Texture2D = _ambient_fire_soft_texture(variant_index)
		var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", variant_index)
		if texture == null and soft_texture == null:
			continue
		var base_point: Vector2 = _fireball_travel_point(start, end, spawn_progress)
		var side_sign: float = -1.0 if ember_index % 2 == 0 else 1.0
		var side_drift: float = side_sign * draw_size * (0.055 + 0.12 * age) * (0.55 + _ambient_hash01(seed + 3) * 0.45)
		var flutter: float = sin(age * TAU * (0.72 + _ambient_hash01(seed + 5) * 0.42) + _ambient_hash01(seed + 7) * TAU) * draw_size * 0.055
		var point: Vector2 = base_point + normal * (side_drift + flutter) - direction * draw_size * 0.24 * age + Vector2(0.0, -draw_size * 0.14 * age)
		var fade: float = pow(1.0 - age, 1.35) * alpha
		var mote_size: float = draw_size * lerpf(0.105, 0.055, age) * lerpf(0.78, 1.22, _ambient_hash01(seed + 11))
		if glow_texture != null:
			_draw_ambient_particle_sprite(glow_texture, point - direction * mote_size * 0.35, Vector2(mote_size * 2.35, mote_size * 1.20), direction.angle(), fade * 0.22, Color(1.0, 0.44, 0.10, 1.0))
		if soft_texture != null:
			_draw_ambient_particle_sprite(soft_texture, point, Vector2.ONE * mote_size * 1.28, direction.angle() + side_sign * 0.18, fade * 0.72, Color(1.0, 0.76, 0.32, 1.0))
		if texture != null:
			_draw_ambient_particle_sprite(texture, point, Vector2.ONE * mote_size, direction.angle(), fade * 0.78)

func _fireball_travel_point(start: Vector2, end: Vector2, travel_progress: float) -> Vector2:
	return start.lerp(end, clampf(travel_progress, 0.0, 1.0))

func _draw_fireball_travel_sprite(texture: Texture2D, core_point: Vector2, direction: Vector2, draw_size: float, alpha: float) -> void:
	if texture == null or draw_size <= 0.0 or alpha <= 0.0:
		return
	var rect := Rect2(
		Vector2(-draw_size * FIREBALL_FRAME_CORE_ANCHOR.x, -draw_size * FIREBALL_FRAME_CORE_ANCHOR.y),
		Vector2.ONE * draw_size
	)
	draw_set_transform(core_point, direction.angle(), Vector2.ONE)
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fireball_impact_frame(center: Vector2, ground_center: Vector2, impact_progress: float, alpha: float, reduced_motion: bool) -> void:
	var frames: Array[Texture2D] = _fireball_frames("fireball_impact")
	if alpha <= 0.0:
		return
	var draw_size: float = _draw_elemental_performance(AttackFxLibrary.STYLE_FIREBALL, ground_center, impact_progress, alpha, reduced_motion)
	if draw_size <= 0.0:
		return
	if not frames.is_empty() and not reduced_motion:
		var contact_alpha: float = 1.0 - smoothstep(0.0, 0.34, impact_progress)
		var contact_size: float = clampf(_tile_width() * 1.92, 158.0, 232.0) * _elemental_detonation_scale(AttackFxLibrary.STYLE_FIREBALL)
		var contact_blend: Vector3 = AttackFxLibrary.one_shot_frame_blend(impact_progress, frames.size())
		_draw_elemental_blended_performance_frames(
			frames,
			contact_blend,
			ground_center,
			contact_size,
			alpha * contact_alpha * 0.44,
			Color.WHITE,
			AttackFxLibrary.STYLE_FIREBALL
		)
	if not reduced_motion:
		_draw_fireball_impact_embers(ground_center, impact_progress, draw_size, alpha)

func _draw_fireball_impact_embers(center: Vector2, impact_progress: float, draw_size: float, alpha: float) -> void:
	if impact_progress < 0.06 or alpha <= 0.0:
		return
	for ember_index: int in range(FIREBALL_IMPACT_EMBER_COUNT):
		var seed: int = 4201 + ember_index * 977
		var wave_index: int = ember_index / 9
		var spawn_progress: float = 0.06 + float(wave_index) * 0.24 + float(ember_index % 9) * 0.012
		if impact_progress <= spawn_progress:
			continue
		var age: float = clampf((impact_progress - spawn_progress) / maxf(0.12, 1.0 - spawn_progress), 0.0, 1.0)
		if age >= 1.0:
			continue
		var angle: float = float(ember_index) * 2.399963 + lerpf(-0.18, 0.18, _ambient_hash01(seed + 3))
		var radial_speed: float = lerpf(0.38, 0.78, _ambient_hash01(seed + 5))
		var radial_distance: float = draw_size * radial_speed * pow(age, 0.68)
		var depth_scale: float = lerpf(0.74, 1.22, (sin(angle) + 1.0) * 0.5)
		var floor_direction := Vector2(cos(angle), sin(angle) * 0.42)
		var ballistic_lift: float = draw_size * lerpf(0.30, 0.60, _ambient_hash01(seed + 13)) * sin(age * PI)
		var point: Vector2 = center + floor_direction * radial_distance + Vector2(0.0, -ballistic_lift + draw_size * 0.12 * age * age)
		var variant_index: int = posmod(ember_index * 5 + 2, AMBIENT_PARTICLE_ATLAS_COLUMNS)
		var texture: Texture2D = _ambient_particle_texture("fire", variant_index)
		var soft_texture: Texture2D = _ambient_fire_soft_texture(variant_index)
		var glow_texture: Texture2D = _ambient_particle_glow_texture("fire", variant_index)
		var stagger: float = lerpf(0.72, 1.0, _ambient_hash01(seed + 7))
		var fade: float = pow(1.0 - age, 0.68) * alpha * stagger
		var mote_size: float = draw_size * lerpf(0.075, 0.035, age) * lerpf(0.78, 1.18, _ambient_hash01(seed + 11)) * depth_scale
		if glow_texture != null:
			var ember_velocity := Vector2(floor_direction.x * draw_size * radial_speed * 0.42, -draw_size * lerpf(0.24, 0.44, _ambient_hash01(seed + 17)))
			_draw_ambient_particle_trail(glow_texture, point, ember_velocity, Vector2(mote_size * 1.42, mote_size), fade * 0.58, "fire")
			_draw_ambient_particle_sprite(glow_texture, point, Vector2(mote_size * 2.20, mote_size * 1.12), angle, fade * 0.20, Color(1.0, 0.43, 0.08, 1.0))
		if soft_texture != null:
			_draw_ambient_particle_sprite(soft_texture, point, Vector2.ONE * mote_size * 1.18, angle, fade * 0.65, Color(1.0, 0.72, 0.26, 1.0))
			var smoke_point: Vector2 = point + Vector2(0.0, -draw_size * 0.06 * age)
			_draw_ambient_particle_sprite(soft_texture, smoke_point, Vector2(mote_size * lerpf(1.8, 3.2, age), mote_size * lerpf(1.2, 2.4, age)), -angle * 0.18, fade * 0.16, Color(0.42, 0.30, 0.25, 1.0))
		if texture != null:
			_draw_ambient_particle_sprite(texture, point, Vector2.ONE * mote_size, angle, fade * 0.75)

func _fireball_frames(frame_key: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_var: Variant in _effect_frames.get(frame_key, []):
		if frame_var is Texture2D:
			frames.append(frame_var)
	return frames

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
	var default_font: Font = get_theme_default_font()
	if default_font == null:
		return
	for entry_var: Variant in presentation.get("floating_texts", []):
		var entry: Dictionary = entry_var
		var is_damage: bool = FloatingCombatText.is_damage_entry(entry)
		var is_popup: bool = FloatingCombatText.is_popup_entry(entry)
		var font: Font = UiTypography.body_font() if is_damage else default_font
		if font == null:
			font = default_font
		var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var label_width: float = _floating_text_rendered_width(entry, font)
		var font_scale: float = clampf(float(entry.get("font_scale", 1.0)), 0.1, 2.0)
		var motion_offset: Vector2 = entry.get("motion_offset", Vector2.ZERO)
		var text_pos: Vector2
		if is_popup and bool(entry.get("automatic_anchor", false)):
			motion_offset.x = absf(motion_offset.x)
			text_pos = _floating_text_local_origin(tile, label_width * font_scale)
		else:
			var tile_center: Vector2 = _tile_center(tile)
			text_pos = tile_center + Vector2(
				float(entry.get("x_offset", -18.0)),
				float(entry.get("anchor_y", -84.0))
			)
		text_pos += motion_offset + Vector2(0.0, float(entry.get("offset", 0.0)))
		var color: Color = entry.get("color", Color("f8f0da"))
		color.a *= clampf(float(entry.get("alpha", 1.0)), 0.0, 1.0)
		var font_size: int = int(entry.get("font_size", 16))
		var text: String = str(entry.get("text", ""))
		var alignment: HorizontalAlignment = entry.get("alignment", HORIZONTAL_ALIGNMENT_LEFT)
		draw_set_transform(text_pos, 0.0, Vector2(font_scale, font_scale))
		var local_text_pos := Vector2.ZERO
		var icon_key: String = str(entry.get("icon", ""))
		if not icon_key.is_empty():
			var icon_size: float = float(entry.get("icon_size", 18.0))
			var icon_rect := Rect2(Vector2(0.0, -icon_size + 2.0), Vector2(icon_size, icon_size))
			var icon_fill: Color = entry.get("icon_fill", Color(0.12, 0.06, 0.05, 0.90))
			icon_fill.a *= color.a
			var icon_border: Color = entry.get("icon_border", color)
			icon_border.a *= color.a
			var icon_tint: Color = entry.get("icon_tint", Color.WHITE)
			icon_tint.a *= color.a
			draw_circle(icon_rect.get_center(), icon_size * 0.56, icon_fill)
			draw_arc(icon_rect.get_center(), icon_size * 0.56, 0.0, TAU, 20, icon_border, 1.3)
			_draw_keyword_icon(icon_key, icon_rect.grow(-2.0), "", icon_tint)
			local_text_pos.x += icon_size + 4.0
			label_width = maxf(0.0, label_width - icon_size - 4.0)
		var outline_size: int = int(entry.get("outline_size", 2))
		var shadow_offset: Vector2 = entry.get("shadow_offset", Vector2.ZERO)
		if not shadow_offset.is_zero_approx():
			var shadow_color: Color = entry.get("shadow_color", Color(0.03, 0.01, 0.01, 0.70))
			shadow_color.a *= color.a
			draw_string(font, local_text_pos + shadow_offset, text, alignment, label_width, font_size, shadow_color)
		if outline_size > 0:
			var outline_color: Color = entry.get("outline_color", Color("200806"))
			outline_color.a *= color.a
			for outline_y: int in range(-outline_size, outline_size + 1):
				for outline_x: int in range(-outline_size, outline_size + 1):
					if outline_x == 0 and outline_y == 0:
						continue
					if Vector2(outline_x, outline_y).length() > float(outline_size) + 0.35:
						continue
					draw_string(font, local_text_pos + Vector2(outline_x, outline_y), text, alignment, label_width, font_size, outline_color)
		draw_string(font, local_text_pos, text, alignment, label_width, font_size, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _floating_text_rendered_width(entry: Dictionary, font: Font = null) -> float:
	var resolved_font: Font = font
	if resolved_font == null:
		resolved_font = UiTypography.body_font() if FloatingCombatText.is_damage_entry(entry) else get_theme_default_font()
	if resolved_font == null:
		return float(entry.get("width", 48.0))
	var text: String = str(entry.get("text", ""))
	var font_size: int = int(entry.get("font_size", 16))
	var outline_size: int = int(entry.get("outline_size", 2))
	var shadow_offset: Vector2 = entry.get("shadow_offset", Vector2.ZERO)
	var text_width: float = resolved_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	# draw_string's width bounds the glyph layout. Reserve its outline and shadow
	# as well, so short status words such as Draw and Play cannot lose their final
	# glyph at the impact scale.
	var required_width: float = ceilf(text_width) + float(outline_size * 2) + absf(shadow_offset.x)
	var icon_key: String = str(entry.get("icon", ""))
	if not icon_key.is_empty():
		required_width += float(entry.get("icon_size", 18.0)) + 4.0
	return maxf(float(entry.get("width", 48.0)), required_width)

func _floating_text_glyph_width(entry: Dictionary, font: Font = null) -> float:
	var resolved_font: Font = font
	if resolved_font == null:
		resolved_font = UiTypography.body_font() if FloatingCombatText.is_damage_entry(entry) else get_theme_default_font()
	if resolved_font == null:
		return 0.0
	return resolved_font.get_string_size(str(entry.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(entry.get("font_size", 16))).x

func _floating_text_local_origin(tile: Vector2i, rendered_width: float) -> Vector2:
	var target_rect: Rect2 = _floating_text_target_rect(tile)
	var x: float = target_rect.get_center().x + FLOATING_TEXT_RIGHT_OFFSET - rendered_width * 0.5
	var y: float = lerpf(target_rect.position.y, target_rect.end.y, 0.42)
	x = clampf(x, 12.0, maxf(12.0, size.x - rendered_width - 12.0))
	y = clampf(y, 36.0, maxf(36.0, size.y - 28.0))
	return Vector2(x, y)

func _floating_text_target_rect(tile: Vector2i) -> Rect2:
	for unit: Dictionary in _visible_units():
		if _unit_footprint_tiles(unit).has(tile):
			return _unit_draw_rect(unit)
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if terrain.get("pos", Vector2i(-1, -1)) != tile:
			continue
		var terrain_kind: String = str(terrain.get("kind", ""))
		var texture: Texture2D = _terrain_textures.get(terrain_kind, null)
		return _terrain_rect_for_tile(tile, texture, terrain_kind)
	var center: Vector2 = _tile_center(tile)
	var width: float = _tile_width() * 0.72
	var height: float = _tile_height() * 0.92
	return Rect2(center - Vector2(width * 0.5, height * 0.72), Vector2(width, height))

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
	var tile_width: float = _tile_width()
	var point_offset := Vector2(0.0, -tile_width * 0.075)
	if path_tiles.size() == 1:
		_draw_single_path_marker(_tile_center(path_tiles[0]) + point_offset, color, tile_width)
		return
	var points := PackedVector2Array()
	for tile: Vector2i in path_tiles:
		points.append(_tile_center(tile) + point_offset)
	var shaft_width: float = _tile_height() * MOVE_PATH_SHAFT_TILE_HEIGHT_RATIO
	var arrow_geometry: Dictionary = _path_arrow_geometry(
		points[points.size() - 2],
		points[points.size() - 1],
		tile_width,
		shaft_width
	)
	if arrow_geometry.is_empty():
		return
	var arrow_points: PackedVector2Array = arrow_geometry.get("polygon", PackedVector2Array())
	var shaft_points: PackedVector2Array = points.duplicate()
	var final_direction: Vector2 = arrow_geometry.get("direction", Vector2.ZERO)
	shaft_points[shaft_points.size() - 1] = (
		arrow_geometry.get("tail_center", points[points.size() - 1])
		+ final_direction * shaft_width * 0.18
	)
	var unified_arrow: PackedVector2Array = _unified_path_arrow_polygon(shaft_points, arrow_points, shaft_width)
	if unified_arrow.is_empty():
		return
	var shadow_offset := Vector2(0.0, tile_width * MOVE_PATH_SHADOW_OFFSET_TILE_RATIO)
	var outline_color: Color = _path_outline_color(color)

	# Every layer starts from the same merged shaft-and-head silhouette. There is
	# no internal head boundary left for the renderer to shade, outline, or
	# double-composite, so the head inherits the ribbon's exact depth treatment.
	_draw_expanded_path_polygon(
		unified_arrow,
		shaft_width * 0.15,
		shadow_offset * 1.55,
		Color(0.0, 0.0, 0.0, 0.13)
	)
	_draw_expanded_path_polygon(
		unified_arrow,
		shaft_width * 0.07,
		shadow_offset,
		Color(0.005, 0.018, 0.025, 0.48)
	)
	_draw_expanded_path_polygon(
		unified_arrow,
		shaft_width * (MOVE_PATH_GLOW_WIDTH_RATIO - 1.0) * 0.5,
		Vector2.ZERO,
		Color(color.r, color.g, color.b, 0.09)
	)
	_draw_expanded_path_polygon(
		unified_arrow,
		shaft_width * (MOVE_PATH_OUTLINE_WIDTH_RATIO - 1.0) * 0.5,
		Vector2.ZERO,
		outline_color
	)
	_draw_gradient_path_polygon(unified_arrow, shaft_width, color)

func _blink_preview_effect_active() -> bool:
	var effect: Dictionary = presentation.get("effect", {})
	return str(effect.get("kind", "")) == "blink" and bool(effect.get("preview", false))

func _draw_single_path_marker(center: Vector2, color: Color, tile_width: float) -> void:
	var marker_width: float = _tile_height() * MOVE_PATH_SHAFT_TILE_HEIGHT_RATIO
	var marker_radius: float = marker_width * 0.5
	var shadow_offset := Vector2(0.0, tile_width * MOVE_PATH_SHADOW_OFFSET_TILE_RATIO)
	draw_circle(center + shadow_offset * 1.55, marker_radius * 1.30, Color(0.0, 0.0, 0.0, 0.13), true, -1.0, true)
	draw_circle(center + shadow_offset, marker_radius * 1.14, Color(0.005, 0.018, 0.025, 0.48), true, -1.0, true)
	draw_circle(center, marker_radius * MOVE_PATH_GLOW_WIDTH_RATIO, Color(color.r, color.g, color.b, 0.09), true, -1.0, true)
	draw_circle(center, marker_radius * MOVE_PATH_OUTLINE_WIDTH_RATIO, _path_outline_color(color), true, -1.0, true)
	_draw_gradient_disc(center, marker_radius, color)

func _path_outline_color(color: Color) -> Color:
	var outline_color: Color = color.darkened(0.87)
	outline_color.a = 0.92
	return outline_color

func _path_arrow_geometry(from_point: Vector2, to_point: Vector2, tile_width: float, _shaft_width: float) -> Dictionary:
	var dir: Vector2 = (to_point - from_point).normalized()
	if dir.length_squared() <= 0.0:
		return {}
	var board_cross_direction: Vector2 = _path_board_cross_direction(dir)
	var half_width: float = tile_width * MOVE_PATH_HEAD_WIDTH_TILE_RATIO * 0.5
	var tip: Vector2 = to_point + dir * tile_width * MOVE_PATH_HEAD_TIP_REACH_TILE_RATIO
	var tail_center: Vector2 = to_point - dir * tile_width * MOVE_PATH_HEAD_TAIL_REACH_TILE_RATIO
	var plus_shoulder: Vector2 = tail_center + board_cross_direction * half_width
	var minus_shoulder: Vector2 = tail_center - board_cross_direction * half_width
	# Build the triangle in isometric board space instead of rotating the screen
	# direction by 90 degrees. Its rear edge now follows the board's other grid
	# axis, while the base/tip straddle the destination's near edge so the route
	# visibly lands on that tile instead of pointing through it.
	var polygon := PackedVector2Array([tip, plus_shoulder, minus_shoulder])
	return {
		"polygon": polygon,
		"tail_center": tail_center,
		"direction": dir,
		"board_cross_direction": board_cross_direction,
		"tip": tip,
		"plus_shoulder": plus_shoulder,
		"minus_shoulder": minus_shoulder
	}

func _path_board_cross_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0:
		return Vector2.ZERO
	# Isometric cardinal steps are (±0.5, ±0.25) in tile-width units. Flipping
	# only x maps either movement axis to the other family of board grid lines.
	return Vector2(-direction.x, direction.y).normalized()

func _unified_path_arrow_polygon(
	shaft_points: PackedVector2Array,
	head_points: PackedVector2Array,
	shaft_width: float
) -> PackedVector2Array:
	if shaft_points.size() < 2 or head_points.size() < 3 or shaft_width <= 0.0:
		return PackedVector2Array()
	var shaft_polygons: Array[PackedVector2Array] = Geometry2D.offset_polyline(
		shaft_points,
		shaft_width * 0.5,
		Geometry2D.JOIN_ROUND,
		Geometry2D.END_ROUND
	)
	if shaft_polygons.is_empty():
		return PackedVector2Array()
	var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(shaft_polygons[0], head_points)
	return _largest_path_polygon(merged)

func _largest_path_polygon(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	var largest := PackedVector2Array()
	var largest_area: float = 0.0
	for polygon: PackedVector2Array in polygons:
		var area: float = absf(_path_polygon_signed_area(polygon))
		if area > largest_area:
			largest_area = area
			largest = polygon
	return largest

func _path_polygon_signed_area(polygon: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5

func _draw_expanded_path_polygon(
	polygon: PackedVector2Array,
	expansion: float,
	offset: Vector2,
	color: Color
) -> void:
	var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(
		polygon,
		expansion,
		Geometry2D.JOIN_ROUND
	)
	_draw_path_polygons(expanded, offset, color)

func _draw_gradient_path_polygon(polygon: PackedVector2Array, width: float, color: Color) -> void:
	if polygon.size() < 3 or width <= 0.0:
		return
	var edge_color: Color = color.darkened(MOVE_PATH_GRADIENT_DARKEN)
	var light_color: Color = color.lightened(MOVE_PATH_GRADIENT_LIGHTEN)
	edge_color.a = color.a * MOVE_PATH_GRADIENT_BASE_ALPHA
	var light_direction: Vector2 = MOVE_PATH_LIGHT_DIRECTION.normalized()
	draw_colored_polygon(polygon, edge_color)
	for layer: int in range(1, MOVE_PATH_GRADIENT_LAYER_COUNT + 1):
		var progress: float = float(layer) / float(MOVE_PATH_GRADIENT_LAYER_COUNT)
		var eased: float = smoothstep(0.0, 1.0, progress)
		var layer_offset: Vector2 = light_direction * width * 0.46 * progress
		var layer_color: Color = edge_color.lerp(light_color, eased)
		layer_color.a = color.a * MOVE_PATH_GRADIENT_LAYER_ALPHA
		var shifted: PackedVector2Array = _shifted_path_polygon(polygon, layer_offset)
		var lit_polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(polygon, shifted)
		_draw_path_polygons(lit_polygons, Vector2.ZERO, layer_color)

func _shifted_path_polygon(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point: Vector2 in polygon:
		shifted.append(point + offset)
	return shifted

func _draw_path_polygons(polygons: Array[PackedVector2Array], offset: Vector2, color: Color) -> void:
	for polygon: PackedVector2Array in polygons:
		if polygon.size() < 3:
			continue
		var shifted := PackedVector2Array()
		for point: Vector2 in polygon:
			shifted.append(point + offset)
		draw_colored_polygon(shifted, color)

func _draw_gradient_disc(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var center_color: Color = _path_gradient_color(Vector2.ZERO, radius, color)
	for index: int in range(MOVE_PATH_GRADIENT_DISC_SEGMENTS):
		var angle_a: float = TAU * float(index) / float(MOVE_PATH_GRADIENT_DISC_SEGMENTS)
		var angle_b: float = TAU * float(index + 1) / float(MOVE_PATH_GRADIENT_DISC_SEGMENTS)
		var offset_a := Vector2(cos(angle_a), sin(angle_a)) * radius
		var offset_b := Vector2(cos(angle_b), sin(angle_b)) * radius
		draw_primitive(
			PackedVector2Array([center, center + offset_a, center + offset_b]),
			PackedColorArray([
				center_color,
				_path_gradient_color(offset_a, radius, color),
				_path_gradient_color(offset_b, radius, color)
			]),
			PackedVector2Array()
		)

func _path_gradient_color(offset: Vector2, radius: float, color: Color) -> Color:
	var light_direction: Vector2 = MOVE_PATH_LIGHT_DIRECTION.normalized()
	var light_amount: float = clampf(0.5 + offset.dot(light_direction) / maxf(radius * 2.0, 0.001), 0.0, 1.0)
	light_amount = smoothstep(0.0, 1.0, light_amount)
	var gradient_color: Color = color.darkened(MOVE_PATH_GRADIENT_DARKEN).lerp(color.lightened(MOVE_PATH_GRADIENT_LIGHTEN), light_amount)
	gradient_color.a = color.a * MOVE_PATH_BODY_ALPHA
	return gradient_color

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
			return "stone"
		"wall":
			return "stone"
		"pillar":
			return "stone"
		_:
			return "stone"

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
	var stone_variants: Array = _floor_texture_variants.get("stone", [])
	var variant_count: int = stone_variants.size()
	if variant_count <= 1:
		return lookup
	var room_coord: Vector2i = combat_state.get("room_coord", Vector2i.ZERO)
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			if _floor_texture_key(str(row[x])) != "stone":
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
	parts.append("backdrop:%s" % bool(next_presentation.get("board_backdrop_visible", false)))
	parts.append("framing:%s" % str(next_presentation.get("board_framing_mode", "room")))
	parts.append("zoom:%s" % _navigation_zoom_scale_for_presentation(next_presentation))
	parts.append("safe:%s" % str(next_presentation.get("board_safe_global_rect", Rect2())))
	return "|".join(parts)

func _visual_framing_signature_for_state(next_state: Dictionary, next_presentation: Dictionary) -> String:
	if next_state.is_empty():
		return ""
	var parts: Array[String] = []
	var player: Dictionary = next_state.get("player", {})
	parts.append("player:%s" % (str(player.get("pos", Vector2i.ZERO)) if not player.is_empty() and int(player.get("hp", 0)) > 0 else "hidden"))
	parts.append("illusions:%s" % _visual_framing_unit_entries_signature(next_state.get("illusions", []), true))
	parts.append("enemies:%s" % _visual_framing_unit_entries_signature(next_state.get("enemies", []), true))
	parts.append("npcs:%s" % _visual_framing_unit_entries_signature(next_state.get("npcs", []), false, "id"))
	# Ephemeral targeting ghosts always occupy legal in-grid unit origins and use
	# the same art bounds already reserved for committed actors. Including them in
	# framing made every illusion-target hover recalculate the entire board's
	# visual bounds even though the resulting origin and scale did not move.
	parts.append("deaths:%s" % _visual_framing_unit_entries_signature(next_presentation.get("death_animation_units", []), false))
	var visible_enemy_ids: Array[String] = []
	if next_presentation.has("visible_enemy_ids"):
		for enemy_id_var: Variant in next_presentation.get("visible_enemy_ids", []):
			visible_enemy_ids.append(str(enemy_id_var))
		visible_enemy_ids.sort()
		parts.append("visible:%s" % ",".join(visible_enemy_ids))
	else:
		parts.append("visible:all")
	var scene_prop_entries: Array[String] = []
	for prop_var: Variant in next_presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var as Dictionary
		scene_prop_entries.append("%s@%s:x%s:w%s:b%s" % [
			str(prop.get("kind", "")),
			str(prop.get("tile", Vector2i(-1, -1))),
			str(prop.get("x_offset_scale", 0.0)),
			str(prop.get("width_scale", "default")),
			str(prop.get("baseline_scale", "default"))
		])
	scene_prop_entries.sort()
	parts.append("props:%s" % ";".join(scene_prop_entries))
	var visible_tiles: Variant = next_presentation.get("umbra_visible_tiles", null)
	parts.append("terrain:%s" % _visual_framing_board_entries_signature(next_state.get("terrain", []), "pos", ["kind"], true, "hp", visible_tiles))
	parts.append("loot:%s" % _visual_framing_board_entries_signature(next_state.get("loot", []), "pos", ["kind", "equipment_id"], true, "claimed", visible_tiles))
	parts.append("traps:%s" % _visual_framing_board_entries_signature(next_state.get("traps", []), "pos", [], false, "", visible_tiles))
	# unit_world_positions contains per-frame interpolation coordinates. Stable
	# state positions drive framing so an animation cannot move the entire board
	# every frame; its committed destination triggers one cache refresh instead.
	return "|".join(parts)

func _visual_framing_unit_entries_signature(entries: Array, living_only: bool, type_key: String = "type", required_role: String = "") -> String:
	var signatures: Array[String] = []
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		if living_only and int(entry.get("hp", 0)) <= 0:
			continue
		if not required_role.is_empty() and str(entry.get("role", "")) != required_role:
			continue
		var footprint: Variant = entry.get("footprint", Vector2i.ONE)
		signatures.append("%s:%s@%s:%s" % [
			str(entry.get("id", entry.get("key", ""))),
			str(entry.get(type_key, "player")),
			str(entry.get("pos", Vector2i(-1, -1))),
			str(footprint)
		])
	signatures.sort()
	return ";".join(signatures)

func _visual_framing_board_entries_signature(entries: Array, position_key: String, fields: Array, exclude_flag: bool = false, flag_key: String = "", visible_tiles: Variant = null) -> String:
	var signatures: Array[String] = []
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		if typeof(visible_tiles) == TYPE_ARRAY and not (visible_tiles as Array).has(entry.get(position_key, Vector2i(-1, -1))):
			continue
		if exclude_flag:
			if flag_key == "hp" and int(entry.get(flag_key, 0)) <= 0:
				continue
			if flag_key != "hp" and bool(entry.get(flag_key, false)):
				continue
		var field_values: Array[String] = []
		for field_var: Variant in fields:
			field_values.append(str(entry.get(str(field_var), "")))
		signatures.append("%s@%s" % [":".join(field_values), str(entry.get(position_key, Vector2i(-1, -1)))])
	signatures.sort()
	return ";".join(signatures)

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

func _load_assets(load_full_unit_roster: bool = true) -> void:
	# Status prompts can use display, UI, or text roles depending on room/combat
	# mode. Resolve all three while the board is being prepared so the first
	# player-visible prompt never pays font-resource decode during an action frame.
	UiTypography.display_font()
	UiTypography.ui_font()
	UiTypography.text_font()
	_health_bar_frame_textures = {
		HEALTH_BAR_STYLE_LIGHT: AssetLoader.load_texture(PLAYER_HEALTH_FRAME_PATH),
		HEALTH_BAR_STYLE_UMBRA: AssetLoader.load_texture(ENEMY_HEALTH_FRAME_PATH),
	}
	var stone_floor_variants: Array[Texture2D] = _load_floor_variants(STONE_FLOOR_VARIANT_PATHS)
	var moss_floor_variants: Array[Texture2D] = _load_floor_variants(MOSS_FLOOR_OVERLAY_PATHS)
	var moss_wall_variants: Array[Texture2D] = _load_floor_variants(MOSS_WALL_OVERLAY_PATHS)
	var moss_pillar_variants: Array[Texture2D] = _load_floor_variants(MOSS_PILLAR_OVERLAY_PATHS)
	_tile_textures = {
		"stone": stone_floor_variants[0] if not stone_floor_variants.is_empty() else AssetLoader.load_texture("res://assets/art/tiles/stone.png"),
		"ember": AssetLoader.load_texture("res://assets/art/tiles/ember.png")
	}
	_floor_texture_variants = {
		"stone": stone_floor_variants
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
		"lethal_death_mark": AssetLoader.load_texture(LETHAL_DEATH_MARK_EFFECT_PATH),
		"blink_rift_preview": AssetLoader.load_texture(BLINK_RIFT_PREVIEW_TEXTURE_PATH)
	}
	_effect_frames = {
		"melee_slash": _load_sprite_sheet_frames(
			MELEE_SLASH_SHEET_PATH,
			MELEE_SLASH_SHEET_COLUMNS,
			MELEE_SLASH_SHEET_ROWS
		),
		"fireball_travel": _load_sprite_sheet_frames(
			FIREBALL_TRAVEL_SHEET_PATH,
			FIREBALL_TRAVEL_SHEET_COLUMNS,
			FIREBALL_TRAVEL_SHEET_ROWS
		),
		"fireball_wake": _load_sprite_sheet_frames(
			FIREBALL_WAKE_SHEET_PATH,
			FIREBALL_WAKE_SHEET_COLUMNS,
			FIREBALL_WAKE_SHEET_ROWS
		),
		"fireball_impact": _load_sprite_sheet_frames(
			FIREBALL_IMPACT_SHEET_PATH,
			FIREBALL_IMPACT_SHEET_COLUMNS,
			FIREBALL_IMPACT_SHEET_ROWS
		),
		"earth_spike_travel": _load_sprite_sheet_frames(
			EARTH_SPIKE_TRAVEL_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"earth_spike_impact": _load_sprite_sheet_frames(
			EARTH_SPIKE_IMPACT_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"earth_ground_layer": _load_sprite_sheet_frames(
			EARTH_GROUND_LAYER_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"air_gust_travel": _load_sprite_sheet_frames(
			AIR_GUST_TRAVEL_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"air_gust_impact": _load_sprite_sheet_frames(
			AIR_GUST_IMPACT_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"air_envelope_layer": _load_sprite_sheet_frames(
			AIR_ENVELOPE_LAYER_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"lightning_bolt_travel": _load_sprite_sheet_frames(
			LIGHTNING_BOLT_TRAVEL_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"lightning_bolt_impact": _load_sprite_sheet_frames(
			LIGHTNING_BOLT_IMPACT_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"lightning_envelope_layer": _load_sprite_sheet_frames(
			LIGHTNING_ENVELOPE_LAYER_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"ice_shard_travel": _load_sprite_sheet_frames(
			ICE_SHARD_TRAVEL_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"ice_icicle_impact": _load_sprite_sheet_frames(
			ICE_ICICLE_IMPACT_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"ice_ground_layer": _load_sprite_sheet_frames(
			ICE_GROUND_LAYER_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_fire_performance": _load_sprite_sheet_frames(
			ELEMENTAL_FIRE_PERFORMANCE_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_earth_performance": _load_sprite_sheet_frames(
			ELEMENTAL_EARTH_PERFORMANCE_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_air_performance": _load_sprite_sheet_frames(
			ELEMENTAL_AIR_PERFORMANCE_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_lightning_performance": _load_sprite_sheet_frames(
			ELEMENTAL_LIGHTNING_PERFORMANCE_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_ice_performance": _load_sprite_sheet_frames(
			ELEMENTAL_ICE_PERFORMANCE_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_fire_performance_bloom": _load_sprite_sheet_frames(
			ELEMENTAL_FIRE_PERFORMANCE_BLOOM_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_earth_performance_bloom": _load_sprite_sheet_frames(
			ELEMENTAL_EARTH_PERFORMANCE_BLOOM_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_air_performance_bloom": _load_sprite_sheet_frames(
			ELEMENTAL_AIR_PERFORMANCE_BLOOM_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_lightning_performance_bloom": _load_sprite_sheet_frames(
			ELEMENTAL_LIGHTNING_PERFORMANCE_BLOOM_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
		),
		"elemental_ice_performance_bloom": _load_sprite_sheet_frames(
			ELEMENTAL_ICE_PERFORMANCE_BLOOM_SHEET_PATH,
			ELEMENTAL_ATTACK_SHEET_COLUMNS,
			ELEMENTAL_ATTACK_SHEET_ROWS
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
		"wooden_crate": AssetLoader.load_texture("res://assets/art/tiles/wooden_crate.png"),
		"dragon_spire": AssetLoader.load_texture("res://assets/art/tiles/dragon_spire.png")
	}
	_terrain_destruction_frames_by_kind.clear()
	for terrain_kind: String in TERRAIN_DESTRUCTION_SHEET_LAYOUTS.keys():
		var destruction_frames: Array[Texture2D] = _load_terrain_destruction_frames(terrain_kind)
		if not destruction_frames.is_empty():
			_terrain_destruction_frames_by_kind[terrain_kind] = destruction_frames
	_element_textures.clear()
	for element_id: String in ElementData.all_elements():
		_element_textures[element_id] = AssetLoader.load_texture(ElementData.icon_path(element_id))
	_trap_textures.clear()
	_trap_idle_frames.clear()
	_trap_activation_frames.clear()
	for element_id: String in ElementData.all_elements():
		_trap_textures[element_id] = AssetLoader.load_texture("res://assets/art/traps/trap_%s.png" % element_id)
		_trap_idle_frames[element_id] = _load_sprite_sheet_frames(
			"res://assets/art/traps/trap_%s_idle.png" % element_id,
			TRAP_ANIMATION_SHEET_COLUMNS,
			TRAP_ANIMATION_SHEET_ROWS
		)
		_trap_activation_frames[element_id] = _load_sprite_sheet_frames(
			"res://assets/art/traps/trap_%s_activation.png" % element_id,
			TRAP_ANIMATION_SHEET_COLUMNS,
			TRAP_ANIMATION_SHEET_ROWS
		)
	_door_icon_textures.clear()
	for icon_id: String in RoomIcons.all_icon_ids():
		_door_icon_textures[icon_id] = RoomIcons.icon_texture(icon_id)
	_keyword_icon_textures.clear()
	for icon_key_var: Variant in ActionIcons.all_icon_keys():
		var icon_key: String = str(icon_key_var)
		_keyword_icon_textures[icon_key] = ActionIcons.icon_texture(icon_key)
	_unit_textures.clear()
	_unit_assets_loaded.clear()
	_idle_frames_by_type.clear()
	_death_frames_by_type.clear()
	_unit_shadow_polygon_cache.clear()
	_unit_shadow_bottom_ratio_cache.clear()
	_unit_shadow_draw_geometry_cache.clear()
	_unit_shadow_draw_mesh_cache.clear()
	_ensure_unit_assets_for_type("player")
	if load_full_unit_roster:
		for enemy_type: String in GameData.enemies().keys():
			_ensure_unit_assets_for_type(enemy_type)
		for npc_id: String in GameData.npcs().keys():
			_ensure_unit_assets_for_type(npc_id)

func _ensure_unit_assets_for_submission(state: Dictionary, source_presentation: Dictionary) -> void:
	if not (state.get("player", {}) as Dictionary).is_empty():
		_ensure_unit_assets_for_type("player")
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			_ensure_unit_assets_for_type(str((enemy_var as Dictionary).get("type", "")))
	for npc_var: Variant in state.get("npcs", []):
		if typeof(npc_var) != TYPE_DICTIONARY:
			continue
		var npc: Dictionary = npc_var
		_ensure_unit_assets_for_type(str(npc.get("id", npc.get("type", ""))))
	for death_var: Variant in source_presentation.get("death_animation_units", []):
		if typeof(death_var) == TYPE_DICTIONARY:
			_ensure_unit_assets_for_type(str((death_var as Dictionary).get("type", "")))

func prepare_unit_assets_for_state(state: Dictionary) -> void:
	# Pre-battle owns an exact preview of the upcoming composition. Loading its
	# textures here lets expensive immutable alpha/shadow metadata build a frame at
	# a time while the player inspects the encounter instead of blocking Start.
	_ensure_unit_assets_for_submission(state, {})

func _ensure_unit_assets_for_type(unit_type: String) -> void:
	if unit_type.is_empty() or _unit_assets_loaded.has(unit_type):
		return
	_unit_assets_loaded[unit_type] = true
	var art_path: String = ""
	if unit_type == "player":
		art_path = "res://assets/placeholders/units/player_reaver.png"
	else:
		var definition: Dictionary = GameData.npc_def(unit_type)
		if definition.is_empty():
			definition = GameData.enemy_def(unit_type)
		art_path = str(definition.get("art_path", ""))
	_unit_textures[unit_type] = _load_unit_texture_with_idle(unit_type, art_path)
	_queue_unit_shadow_source_data(unit_type)

func _queue_unit_shadow_source_data(unit_type: String) -> void:
	var urgent_textures: Array[Texture2D] = []
	var background_textures: Array[Texture2D] = []
	var base_texture: Texture2D = _unit_textures.get(unit_type, null) as Texture2D
	if base_texture != null:
		urgent_textures.append(base_texture)
	var idle_index: int = 0
	for frame_var: Variant in _idle_frames_by_type.get(unit_type, []):
		if frame_var is Texture2D:
			var idle_texture: Texture2D = frame_var as Texture2D
			if idle_index == 0:
				urgent_textures.append(idle_texture)
			else:
				background_textures.append(idle_texture)
			idle_index += 1
	for frame_var: Variant in _death_frames_by_type.get(unit_type, []):
		if frame_var is Texture2D:
			background_textures.append(frame_var as Texture2D)
	for texture: Texture2D in urgent_textures:
		_queue_unit_shadow_texture(texture, true)
	for texture: Texture2D in background_textures:
		_queue_unit_shadow_texture(texture, false)

func _queue_unit_shadow_texture(texture: Texture2D, urgent: bool) -> void:
	if texture == null:
		return
	var texture_id: int = texture.get_instance_id()
	if _unit_shadow_polygon_cache.has(texture_id) or _unit_shadow_prewarm_queued_ids.has(texture_id):
		return
	_unit_shadow_prewarm_queued_ids[texture_id] = true
	if urgent:
		_unit_shadow_prewarm_urgent_queue.append(texture)
	else:
		_unit_shadow_prewarm_background_queue.append(texture)

func _process_next_unit_shadow_prewarm() -> void:
	if _unit_shadow_prewarm_thread != null:
		if _unit_shadow_prewarm_thread.is_alive():
			return
		var result: Dictionary = _unit_shadow_prewarm_thread.wait_to_finish() as Dictionary
		if _unit_shadow_prewarm_active_texture != null:
			var texture_id: int = _unit_shadow_prewarm_active_texture.get_instance_id()
			if not _unit_shadow_polygon_cache.has(texture_id):
				_unit_shadow_polygon_cache[texture_id] = result.get("shadow_data", {})
			var used_rect: Rect2i = result.get("used_rect", Rect2i())
			_texture_used_rect_cache[texture_id] = used_rect
			AssetLoader.cache_texture_used_rect(_unit_shadow_prewarm_active_texture, used_rect)
		_unit_shadow_prewarm_thread = null
		_unit_shadow_prewarm_active_texture = null
	var texture: Texture2D = null
	if not _unit_shadow_prewarm_urgent_queue.is_empty():
		texture = _unit_shadow_prewarm_urgent_queue.pop_front()
	elif not _unit_shadow_prewarm_background_queue.is_empty():
		texture = _unit_shadow_prewarm_background_queue.pop_front()
	if texture == null:
		return
	_unit_shadow_prewarm_queued_ids.erase(texture.get_instance_id())
	if _unit_shadow_polygon_cache.has(texture.get_instance_id()):
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_unit_shadow_polygon_cache[texture.get_instance_id()] = {"polygons": [], "bounds": Rect2()}
		_texture_used_rect_cache[texture.get_instance_id()] = Rect2i()
		return
	_unit_shadow_prewarm_active_texture = texture
	_unit_shadow_prewarm_thread = Thread.new()
	var start_error: Error = _unit_shadow_prewarm_thread.start(_compute_unit_shadow_data_for_image.bind(image))
	if start_error != OK:
		_unit_shadow_prewarm_thread = null
		_unit_shadow_prewarm_active_texture = null
		_unit_shadow_data_for_texture(texture)
		_texture_used_rect(texture)

func _compute_unit_shadow_data_for_image(image: Image) -> Dictionary:
	var data: Dictionary = _unit_shadow_data_for_image_with_simplify(image, UNIT_SHADOW_SIMPLIFY_EPSILON)
	var shadow_polygons: Array = data.get("polygons", [])
	var bounds: Rect2 = data.get("bounds", Rect2())
	if shadow_polygons.is_empty() and bounds.size.x > 0.0 and bounds.size.y > 0.0 and UNIT_SHADOW_RETRY_SIMPLIFY_EPSILON < UNIT_SHADOW_SIMPLIFY_EPSILON:
		var retry_data: Dictionary = _unit_shadow_data_for_image_with_simplify(image, UNIT_SHADOW_RETRY_SIMPLIFY_EPSILON)
		if not (retry_data.get("polygons", []) as Array).is_empty():
			data = retry_data
	return {"shadow_data": data, "used_rect": image.get_used_rect()}

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

func _load_terrain_destruction_frames(terrain_kind: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var layout: Dictionary = TERRAIN_DESTRUCTION_SHEET_LAYOUTS.get(terrain_kind, {})
	if layout.is_empty():
		return frames
	var sheet: Texture2D = AssetLoader.load_texture(str(layout.get("path", "")))
	if sheet == null:
		return frames
	var columns: int = maxi(1, int(layout.get("columns", 1)))
	var rows: int = maxi(1, int(layout.get("rows", 1)))
	var frame_size := Vector2i(int(sheet.get_width() / columns), int(sheet.get_height() / rows))
	return AssetLoader.build_sprite_sheet_frames(sheet, frame_size, _idle_frame_indices(layout))

func _terrain_destruction_frames_for_kind(terrain_kind: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_var: Variant in _terrain_destruction_frames_by_kind.get(terrain_kind, []):
		if frame_var is Texture2D:
			frames.append(frame_var)
	return frames

func _terrain_destruction_frame_count(terrain: Dictionary) -> int:
	return _terrain_destruction_frames_for_kind(str(terrain.get("kind", ""))).size()

func _terrain_destruction_frame_seconds(terrain: Dictionary) -> float:
	var layout: Dictionary = TERRAIN_DESTRUCTION_SHEET_LAYOUTS.get(str(terrain.get("kind", "")), {})
	return maxf(0.01, float(layout.get("frame_seconds", TERRAIN_DESTRUCTION_FRAME_SECONDS)))

func _terrain_destruction_texture(terrain: Dictionary) -> Texture2D:
	var frames: Array[Texture2D] = _terrain_destruction_frames_for_kind(str(terrain.get("kind", "")))
	if frames.is_empty():
		return null
	return frames[clampi(int(terrain.get("destruction_frame", 0)), 0, frames.size() - 1)]

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
	var unit_type: String = str(unit.get("type", ""))
	var death_frames: Array[Texture2D] = _unit_death_frames(unit)
	if _unit_death_animation_active(unit) and not death_frames.is_empty():
		return death_frames[_death_frame_index(unit)]
	var idle_frames: Array[Texture2D] = _unit_idle_frames(unit)
	if _unit_idle_animation_active(unit) and not idle_frames.is_empty():
		return idle_frames[_idle_frame_index(unit)]
	return _unit_textures.get(unit_type, null)

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

func _trap_idle_frames_for_element(element_id: String) -> Array[Texture2D]:
	if not _trap_idle_frames.has(element_id):
		var empty_frames: Array[Texture2D] = []
		return empty_frames
	var frames: Array[Texture2D] = _trap_idle_frames[element_id] as Array[Texture2D]
	return frames

func _trap_activation_frames_for_element(element_id: String) -> Array[Texture2D]:
	if not _trap_activation_frames.has(element_id):
		var empty_frames: Array[Texture2D] = []
		return empty_frames
	var frames: Array[Texture2D] = _trap_activation_frames[element_id] as Array[Texture2D]
	return frames

func _trap_idle_frame_index(trap: Dictionary) -> int:
	var frames: Array[Texture2D] = _trap_idle_frames_for_element(str(trap.get("element", ElementData.NONE)))
	if frames.is_empty():
		return 0
	return int(floor(_idle_elapsed / TRAP_IDLE_FRAME_SECONDS)) % frames.size()

func _trap_idle_texture(trap: Dictionary) -> Texture2D:
	var element_id: String = str(trap.get("element", ElementData.NONE))
	if bool(presentation.get("reduced_motion", false)):
		return _trap_textures.get(element_id, null)
	var frames: Array[Texture2D] = _trap_idle_frames_for_element(element_id)
	if frames.is_empty():
		return _trap_textures.get(element_id, null)
	return frames[_trap_idle_frame_index(trap)]

func _trap_activation_frame_index(progress: float, frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	if bool(presentation.get("reduced_motion", false)):
		return mini(7, frame_count - 1)
	return clampi(int(floor(clampf(progress, 0.0, 1.0) * float(frame_count))), 0, frame_count - 1)

func _trap_activation_texture(trap: Dictionary, progress: float) -> Texture2D:
	var frames: Array[Texture2D] = _trap_activation_frames_for_element(str(trap.get("element", ElementData.NONE)))
	if frames.is_empty():
		return null
	return frames[_trap_activation_frame_index(progress, frames.size())]

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
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if not _trap_idle_animation_active(trap):
			continue
		parts.append("t:%s:%s:%d" % [str(trap.get("element", "")), str(trap.get("pos", Vector2i.ZERO)), _trap_idle_frame_index(trap)])
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

func _trap_idle_animation_active(trap: Dictionary) -> bool:
	if not visible or combat_state.is_empty() or bool(presentation.get("reduced_motion", false)):
		return false
	return not _trap_idle_frames_for_element(str(trap.get("element", ElementData.NONE))).is_empty()

func _pillar_torch_idle_animation_active() -> bool:
	if not visible or combat_state.is_empty():
		return false
	if _pillar_torch_idle_frames_for_side("left").is_empty() and _pillar_torch_idle_frames_for_side("right").is_empty():
		return false
	return _grid_has_tile("pillar")

func _grid_has_tile(tile_id: String) -> bool:
	if _submission_cache_valid:
		return _grid_tile_ids_cache.has(tile_id)
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
	var texture: Texture2D = _texture_for_unit(unit)
	return _unit_draw_rect_for_texture(unit, center, texture)

func _unit_draw_rect_for_texture(unit: Dictionary, center: Vector2, texture: Texture2D) -> Rect2:
	var frame_rect: Rect2 = _unit_frame_rect(center)
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

func rendered_visual_bounds() -> Rect2:
	# This is deliberately based on the exact draw rectangles used by the static
	# board and DynamicRenderLayer, rather than only tile diamonds. Consumers use
	# it for framing/collision proof so tall pillars, doors, actors, pickups, and
	# room props cannot be silently clipped while the tile polygon still fits.
	_ensure_board_layout_cache()
	var rects: Array[Rect2] = []
	var grid: Array = combat_state.get("grid", [])
	for tile: Vector2i in _board_layout_cache_tiles:
		var polygon: PackedVector2Array = _tile_polygon(tile)
		if not polygon.is_empty():
			var tile_bounds := Rect2(polygon[0], Vector2.ZERO)
			for point: Vector2 in polygon:
				tile_bounds = tile_bounds.expand(point)
			rects.append(tile_bounds)
		if tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= (grid[tile.y] as Array).size():
			continue
		var tile_id: String = _display_tile_id(str((grid[tile.y] as Array)[tile.x]), tile)
		if tile_id == "wall" and not _is_outer_boundary_tile(grid, tile):
			tile_id = "pillar"
		if tile_id == "pillar":
			var pillar: Texture2D = _prop_textures.get("pillar", null)
			if pillar != null:
				var pillar_rect: Rect2 = _prop_draw_rect(pillar, _prop_rect_for_tile(tile))
				rects.append(pillar_rect)
				var left_torch: Texture2D = _pillar_torch_texture("left")
				var right_torch: Texture2D = _pillar_torch_texture("right")
				if left_torch != null:
					rects.append(_pillar_torch_rect(pillar_rect, left_torch, -1.0))
				if right_torch != null:
					rects.append(_pillar_torch_rect(pillar_rect, right_torch, 1.0))
		elif tile_id == "wall":
			for segment: Dictionary in _boundary_prop_segments(tile_id, grid, tile):
				rects.append(segment.get("draw_rect", Rect2()) as Rect2)
		elif tile_id == "door":
			var door: Texture2D = _door_texture_for_tile(grid, tile)
			if door != null:
				var door_rect: Rect2 = _prop_draw_rect(door, _door_rect_for_tile(tile, grid))
				var opening: Texture2D = _door_opening_texture_for_tile(grid, tile)
				rects.append(_door_opening_draw_rect(opening, door, door_rect, _door_uses_flipped_orientation(grid, tile)) if opening != null else door_rect)
				if opening == null and not str(exit_icon_ids.get(tile, "")).is_empty():
					rects.append(_door_icon_visual_rect(door, door_rect))
	for unit: Dictionary in _visible_units():
		rects.append(_unit_draw_rect(unit))
	for prop_var: Variant in presentation.get("scene_props", []):
		if typeof(prop_var) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_var
		var prop_texture: Texture2D = _texture_for_scene_prop(prop)
		if prop_texture != null:
			rects.append(_scene_prop_rect(prop_texture, prop))
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if not _board_tile_is_visible_to_player(terrain.get("pos", Vector2i(-1, -1))):
			continue
		if int(terrain.get("hp", 0)) <= 0:
			continue
		var terrain_texture: Texture2D = _terrain_textures.get(str(terrain.get("kind", "")), null)
		if terrain_texture != null:
			rects.append(_terrain_rect_for_tile(terrain.get("pos", Vector2i(-1, -1)), terrain_texture, str(terrain.get("kind", ""))))
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if not _board_tile_is_visible_to_player(loot.get("pos", Vector2i(-1, -1))):
			continue
		if bool(loot.get("claimed", false)):
			continue
		var loot_texture: Texture2D = _loot_texture(loot)
		if loot_texture != null:
			rects.append(_loot_rect_for_tile(loot.get("pos", Vector2i(-1, -1)), loot_texture, loot))
	for trap_var: Variant in combat_state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if _board_tile_is_visible_to_player(trap.get("pos", Vector2i(-1, -1))):
			rects.append(_trap_draw_rect(trap.get("pos", Vector2i(-1, -1))))
	var bounds := Rect2()
	var has_bounds: bool = false
	for rect: Rect2 in rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		bounds = rect if not has_bounds else bounds.merge(rect)
		has_bounds = true
	return bounds

func _tile_draws_before(a: Vector2i, b: Vector2i) -> bool:
	var a_score: int = a.x + a.y
	var b_score: int = b.x + b.y
	if a_score == b_score:
		return a.x < b.x
	return a_score < b_score

func _tile_center(tile: Vector2i) -> Vector2:
	_ensure_board_layout_cache()
	if _board_layout_cache_tile_centers.has(tile):
		return _board_layout_cache_tile_centers.get(tile, Vector2.ZERO)
	var origin: Vector2 = _board_layout_cache_origin
	var tile_width: float = _board_layout_cache_tile_width
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
	_ensure_board_layout_cache()
	if _board_layout_cache_tile_polygons.has(tile):
		return _board_layout_cache_tile_polygons.get(tile, PackedVector2Array())
	var center: Vector2 = _tile_center(tile)
	var tile_width: float = _board_layout_cache_tile_width
	var tile_height: float = tile_width * 0.5
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

func _board_origin_for_extents(extents: Dictionary, tile_width: float, tiles: Array[Vector2i]) -> Vector2:
	var half_height: float = tile_width * 0.25
	var half_width: float = tile_width * 0.5
	var min_diag: float = float(extents.get("min_diag", -4.0))
	var max_diag: float = float(extents.get("max_diag", 4.0))
	var min_sum: float = float(extents.get("min_sum", 0.0))
	var content_width: float = _board_layout_width_units(extents) * tile_width
	var content_height: float = _board_layout_height_units(extents) * tile_width
	var available_rect: Rect2 = _board_layout_available_rect()
	var content_left: float = available_rect.position.x + (available_rect.size.x - content_width) * 0.5
	var content_top: float = available_rect.position.y + (available_rect.size.y - content_height) * _board_vertical_bias()
	var target_center_x: float = content_left + content_width * 0.5
	var origin_x: float = target_center_x - ((min_diag + max_diag) * 0.5 * half_width)
	var origin_y: float = content_top + tile_width * BOARD_TOP_CLEARANCE_SCALE - min_sum * half_height
	# Bias the default composition upward for the lower hand clearance, but never
	# let that presentation offset crop the topmost rendered tile. This is a base
	# framing correction, not a clamp on _navigation_pan, so player pan and zoom
	# preferences retain their existing behavior.
	origin_y += _default_vertical_framing_offset(extents, tile_width, content_top, tiles)
	return Vector2(origin_x, origin_y) + _navigation_pan

func _default_vertical_framing_offset(extents: Dictionary, tile_width: float, content_top: float, tiles: Array[Vector2i]) -> float:
	var half_height: float = tile_width * 0.25
	var min_sum: float = float(extents.get("min_sum", 0.0))
	var origin_y: float = content_top + tile_width * BOARD_TOP_CLEARANCE_SCALE - min_sum * half_height
	var visual_top: float = INF
	for tile: Vector2i in tiles:
		var tile_center_y: float = origin_y + float(tile.x + tile.y) * half_height
		visual_top = minf(visual_top, tile_center_y - half_height)
	if not is_finite(visual_top):
		visual_top = origin_y - half_height
	return maxf(0.0, _board_local_safe_top() - visual_top)

func _board_local_safe_top() -> float:
	# The board is nested below the stage chrome, so the screenshot-safe top edge
	# lives in global canvas space rather than at local y=BOARD_VERTICAL_MARGIN.
	if str(presentation.get("board_framing_mode", "room")) != "combat" and (presentation.get("board_safe_global_rect", Rect2()) as Rect2).size.y > 0.0:
		return _board_layout_available_rect().position.y
	return BOARD_VERTICAL_MARGIN - get_global_transform().origin.y

func _default_visual_top_framing_offset() -> float:
	var visual_bounds: Rect2 = rendered_visual_bounds()
	if visual_bounds.size.x <= 0.0 or visual_bounds.size.y <= 0.0:
		return 0.0
	# rendered_visual_bounds includes the current player pan. Remove it before
	# deriving the default composition so this safety correction does not cancel
	# an intentional upward pan.
	var default_visual_top: float = visual_bounds.position.y - _navigation_pan.y
	return maxf(0.0, _board_local_safe_top() - default_visual_top)

func _navigation_zoom_anchor() -> Vector2:
	var available_rect: Rect2 = _board_layout_available_rect()
	var extents: Dictionary = _board_layout_cache_extents
	var tile_width: float = _tile_width_for_extents(extents) * _navigation_zoom
	var content_height: float = _board_layout_height_units(extents) * tile_width
	var content_top: float = available_rect.position.y + (available_rect.size.y - content_height) * _board_vertical_bias()
	var framing_offset: float = _default_vertical_framing_offset(extents, tile_width, content_top, _board_layout_cache_tiles)
	return Vector2(
		available_rect.get_center().x,
		available_rect.position.y + available_rect.size.y * _board_vertical_bias() + framing_offset + _board_layout_cache_visual_top_offset
	)

func _navigation_content_rect(extents: Dictionary, tile_width: float, pan: Vector2 = Vector2.ZERO) -> Rect2:
	var content_size := Vector2(
		_board_layout_width_units(extents) * tile_width,
		_board_layout_height_units(extents) * tile_width
	)
	var available_rect: Rect2 = _board_layout_available_rect()
	var content_position := Vector2(
		available_rect.position.x + (available_rect.size.x - content_size.x) * 0.5,
		available_rect.position.y + (available_rect.size.y - content_size.y) * _board_vertical_bias()
	)
	content_position.y += _default_vertical_framing_offset(extents, tile_width, content_position.y, _board_layout_cache_tiles)
	if _board_layout_cache_valid and is_equal_approx(tile_width, _board_layout_cache_tile_width) and extents == _board_layout_cache_extents:
		content_position.y += _board_layout_cache_visual_top_offset
	return Rect2(content_position + pan, content_size)

func _board_vertical_bias() -> float:
	return BOARD_COMBAT_VERTICAL_BIAS if str(presentation.get("board_framing_mode", "room")) == "combat" else BOARD_ROOM_VERTICAL_BIAS

func _navigation_pan_limits(extents: Dictionary, tile_width: float) -> Rect2:
	var content_rect: Rect2 = _navigation_content_rect(extents, tile_width)
	var available_rect: Rect2 = _board_layout_available_rect()
	var overscroll := Vector2(
		minf(BOARD_PAN_OVERSCROLL_MAX, available_rect.size.x * BOARD_PAN_OVERSCROLL_FRACTION),
		minf(BOARD_PAN_OVERSCROLL_MAX, available_rect.size.y * BOARD_PAN_OVERSCROLL_FRACTION)
	)
	var minimum := Vector2(
		minf(0.0, available_rect.end.x - content_rect.end.x) - overscroll.x,
		minf(0.0, available_rect.end.y - content_rect.end.y) - overscroll.y
	)
	var maximum := Vector2(
		maxf(0.0, available_rect.position.x - content_rect.position.x) + overscroll.x,
		maxf(0.0, available_rect.position.y - content_rect.position.y) + overscroll.y
	)
	return Rect2(minimum, maximum - minimum)

func _clamped_navigation_pan_for_layout(candidate: Vector2, extents: Dictionary, tile_width: float) -> Vector2:
	var limits: Rect2 = _navigation_pan_limits(extents, tile_width)
	return Vector2(
		clampf(candidate.x, limits.position.x, limits.end.x),
		clampf(candidate.y, limits.position.y, limits.end.y)
	)

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
	var unit_type: String = str(unit.get("type", ""))
	var shadow_geometry: Array = _unit_shadow_draw_geometry(texture, draw_rect, unit_type)
	if shadow_geometry.is_empty():
		_draw_unit_shadow_fallback(unit)
		return
	var shadow_mesh: ArrayMesh = _unit_shadow_draw_mesh(texture, draw_rect, unit_type, shadow_geometry)
	if shadow_mesh == null:
		_draw_unit_shadow_fallback(unit)
		return
	draw_mesh(shadow_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, shadow_alpha_scale))

func _unit_shadow_draw_mesh(texture: Texture2D, draw_rect: Rect2, unit_type: String, shadow_geometry: Array) -> ArrayMesh:
	var cache_key: String = _unit_shadow_draw_cache_key(texture, draw_rect, unit_type)
	if _unit_shadow_draw_mesh_cache.has(cache_key):
		return _unit_shadow_draw_mesh_cache.get(cache_key, null) as ArrayMesh
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for geometry_var: Variant in shadow_geometry:
		var geometry: Dictionary = geometry_var as Dictionary
		_append_colored_polygon_to_mesh_arrays(
			geometry.get("soft", PackedVector2Array()) as PackedVector2Array,
			UNIT_SHADOW_SOFT_COLOR,
			vertices,
			colors,
			indices
		)
		_append_colored_polygon_to_mesh_arrays(
			geometry.get("hard", PackedVector2Array()) as PackedVector2Array,
			UNIT_SHADOW_COLOR,
			vertices,
			colors,
			indices
		)
	if vertices.is_empty() or indices.is_empty():
		_unit_shadow_draw_mesh_cache[cache_key] = null
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var shadow_mesh := ArrayMesh.new()
	shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_unit_shadow_draw_mesh_cache[cache_key] = shadow_mesh
	return shadow_mesh

func _append_colored_polygon_to_mesh_arrays(
	polygon: PackedVector2Array,
	color: Color,
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if not _polygon_can_draw(polygon):
		return
	var triangulated: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if triangulated.is_empty():
		return
	var first_vertex: int = vertices.size()
	for point: Vector2 in polygon:
		vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(color)
	for index: int in triangulated:
		indices.append(first_vertex + index)

func _unit_shadow_draw_cache_key(texture: Texture2D, draw_rect: Rect2, unit_type: String) -> String:
	return "%d|%.3f,%.3f,%.3f,%.3f|%s" % [
		texture.get_instance_id(),
		draw_rect.position.x,
		draw_rect.position.y,
		draw_rect.size.x,
		draw_rect.size.y,
		unit_type
	]

func _unit_shadow_draw_geometry(texture: Texture2D, draw_rect: Rect2, unit_type: String) -> Array:
	var cache_key: String = _unit_shadow_draw_cache_key(texture, draw_rect, unit_type)
	if _unit_shadow_draw_geometry_cache.has(cache_key):
		return _unit_shadow_draw_geometry_cache.get(cache_key, []) as Array
	var geometry: Array = []
	var shadow_data_was_missing: bool = not _unit_shadow_polygon_cache.has(texture.get_instance_id())
	var shadow_data_started_usec: int = Time.get_ticks_usec() if shadow_data_was_missing else 0
	var shadow_polygons: Array[PackedVector2Array] = _unit_shadow_polygons_for_texture(texture)
	var bounds: Rect2 = _unit_shadow_bounds_for_texture(texture)
	if shadow_data_was_missing:
		var elapsed_usec: int = Time.get_ticks_usec() - shadow_data_started_usec
		_unit_shadow_sync_miss_metrics["count"] = int(_unit_shadow_sync_miss_metrics.get("count", 0)) + 1
		_unit_shadow_sync_miss_metrics["total_usec"] = int(_unit_shadow_sync_miss_metrics.get("total_usec", 0)) + elapsed_usec
		_unit_shadow_sync_miss_metrics["max_usec"] = maxi(int(_unit_shadow_sync_miss_metrics.get("max_usec", 0)), elapsed_usec)
		var by_type: Dictionary = _unit_shadow_sync_miss_metrics.get("by_type", {}) as Dictionary
		var type_metrics: Dictionary = by_type.get(unit_type, {}) as Dictionary
		type_metrics["count"] = int(type_metrics.get("count", 0)) + 1
		type_metrics["total_usec"] = int(type_metrics.get("total_usec", 0)) + elapsed_usec
		type_metrics["max_usec"] = maxi(int(type_metrics.get("max_usec", 0)), elapsed_usec)
		by_type[unit_type] = type_metrics
		_unit_shadow_sync_miss_metrics["by_type"] = by_type
	if shadow_polygons.is_empty() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_unit_shadow_draw_geometry_cache[cache_key] = geometry
		return geometry
	var shadow_size: Vector2 = _unit_shadow_draw_size(texture, draw_rect.size, bounds)
	var foot_point: Vector2 = _unit_shadow_foot_point(texture, draw_rect, bounds, unit_type)
	var shadow_origin: Vector2 = foot_point + Vector2(0.0, _tile_height() * UNIT_SHADOW_FOOT_OFFSET_Y_RATIO)
	for local_polygon: PackedVector2Array in shadow_polygons:
		var shadow_polygon: PackedVector2Array = _project_unit_shadow_polygon(local_polygon, shadow_size, shadow_origin)
		if not _polygon_can_draw(shadow_polygon):
			continue
		var soft_polygon: PackedVector2Array = _scaled_polygon(shadow_polygon, UNIT_SHADOW_SOFT_SCALE)
		geometry.append({"hard": shadow_polygon, "soft": soft_polygon if _polygon_can_draw(soft_polygon) else PackedVector2Array()})
	_unit_shadow_draw_geometry_cache[cache_key] = geometry
	return geometry

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
	var opaque_polygons: Array[PackedVector2Array] = AssetLoader.build_alpha_polygons(
		texture,
		UNIT_SHADOW_ALPHA_THRESHOLD,
		simplify_epsilon,
		UNIT_SHADOW_MIN_ALPHA_POLYGON_AREA
	)
	return _unit_shadow_data_from_opaque_polygons(opaque_polygons)

func _unit_shadow_data_for_image_with_simplify(image: Image, simplify_epsilon: float) -> Dictionary:
	var opaque_polygons: Array[PackedVector2Array] = AssetLoader.build_alpha_polygons_from_image(
		image,
		UNIT_SHADOW_ALPHA_THRESHOLD,
		simplify_epsilon,
		UNIT_SHADOW_MIN_ALPHA_POLYGON_AREA
	)
	return _unit_shadow_data_from_opaque_polygons(opaque_polygons)

func _unit_shadow_data_from_opaque_polygons(opaque_polygons: Array[PackedVector2Array]) -> Dictionary:
	var local_polygons: Array[PackedVector2Array] = []
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

func _vector2i_lookup(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result[value] = true
	return result

func _ability_tiles() -> Array[Vector2i]:
	if _submission_cache_valid:
		return _ability_tiles_cache
	return _vector2i_array(presentation.get("ability_tiles", []))

func _tile_width() -> float:
	_ensure_board_layout_cache()
	return _board_layout_cache_tile_width

func _tile_width_for_extents(extents: Dictionary) -> float:
	var width_units: float = _board_layout_width_units(extents)
	var height_units: float = _board_layout_height_units(extents)
	var available_rect: Rect2 = _board_layout_available_rect()
	var available_width: float = available_rect.size.x
	var available_height: float = available_rect.size.y
	var width_based: float = available_width / maxf(1.0, width_units)
	var height_based: float = available_height / maxf(1.0, height_units)
	return clampf(minf(width_based, height_based), 90.0, BOARD_MAX_TILE_WIDTH)

func _board_layout_available_rect() -> Rect2:
	var base_rect := Rect2(
		Vector2(BOARD_SIDE_MARGIN, BOARD_VERTICAL_MARGIN),
		Vector2(
			maxf(1.0, size.x - BOARD_SIDE_MARGIN * 2.0),
			maxf(1.0, size.y - BOARD_VERTICAL_MARGIN * 2.0)
		)
	)
	if str(presentation.get("board_framing_mode", "room")) == "combat":
		return base_rect
	var safe_global_rect: Rect2 = presentation.get("board_safe_global_rect", Rect2()) as Rect2
	if safe_global_rect.size.x <= 0.0 or safe_global_rect.size.y <= 0.0:
		return base_rect
	var inverse_transform: Transform2D = get_global_transform().affine_inverse()
	var local_top_left: Vector2 = inverse_transform * safe_global_rect.position
	var local_bottom_right: Vector2 = inverse_transform * safe_global_rect.end
	var safe_local_rect := Rect2(local_top_left, local_bottom_right - local_top_left)
	var clipped: Rect2 = base_rect.intersection(safe_local_rect)
	if clipped.size.x <= 1.0 or clipped.size.y <= 1.0:
		return base_rect
	return clipped

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

func _invalidate_board_layout_cache(content_changed: bool = true, preserve_visual_top_offset: bool = false) -> void:
	var retained_visual_top_offset: float = _board_layout_cache_visual_top_offset if preserve_visual_top_offset else 0.0
	_board_layout_cache_valid = false
	_board_layout_cache_visual_top_offset = retained_visual_top_offset
	_board_layout_cache_tile_centers.clear()
	_board_layout_cache_tile_polygons.clear()
	_unit_shadow_draw_geometry_cache.clear()
	_unit_shadow_draw_mesh_cache.clear()
	if content_changed:
		_board_layout_content_cache_valid = false
		_board_layout_cache_tiles.clear()
		_board_layout_cache_extents.clear()

func _ensure_board_layout_cache() -> void:
	if _board_layout_cache_valid and _board_layout_cache_size == size:
		return
	if _navigation_uses_default_zoom:
		_navigation_zoom = _default_navigation_zoom_for_viewport()
	var tiles: Array[Vector2i] = _board_layout_cache_tiles
	var extents: Dictionary = _board_layout_cache_extents
	if not _board_layout_content_cache_valid:
		var grid: Array = combat_state.get("grid", [])
		tiles = _tiles_in_draw_order(grid)
		extents = _board_layout_extents_for_tiles(tiles)
		_board_layout_content_rebuild_count += 1
		_board_layout_cache_tiles = tiles
		_board_layout_cache_extents = extents
		_board_layout_content_cache_valid = true
	var tile_width: float = _tile_width_for_extents(extents) * _navigation_zoom
	_navigation_pan = _clamped_navigation_pan_for_layout(_navigation_pan, extents, tile_width)
	var retained_visual_top_offset: float = _board_layout_cache_visual_top_offset
	_board_layout_cache_size = size
	_board_layout_cache_tile_width = tile_width
	_board_layout_cache_origin = _board_origin_for_extents(extents, tile_width, tiles)
	_board_layout_cache_visual_top_offset = 0.0
	_board_layout_cache_tile_centers = {}
	_board_layout_cache_tile_polygons = {}
	var tile_height: float = tile_width * 0.5
	var half_w: float = tile_width * 0.5
	var half_h: float = tile_width * 0.25
	for tile: Vector2i in tiles:
		var center := Vector2(
			_board_layout_cache_origin.x + float(tile.x - tile.y) * half_w,
			_board_layout_cache_origin.y + float(tile.x + tile.y) * half_h
		)
		_board_layout_cache_tile_centers[tile] = center
		_board_layout_cache_tile_polygons[tile] = PackedVector2Array([
			center + Vector2(0.0, -tile_height * 0.5),
			center + Vector2(tile_width * 0.5, 0.0),
			center + Vector2(0.0, tile_height * 0.5),
			center + Vector2(-tile_width * 0.5, 0.0),
			center + Vector2(0.0, -tile_height * 0.5)
		])
	_board_layout_cache_valid = true
	var visual_top_offset: float = maxf(retained_visual_top_offset, _default_visual_top_framing_offset())
	if visual_top_offset > 0.01:
		_board_layout_cache_visual_top_offset = visual_top_offset
		_board_layout_cache_origin.y += visual_top_offset
		for tile: Vector2i in tiles:
			_board_layout_cache_tile_centers[tile] = (_board_layout_cache_tile_centers.get(tile, Vector2.ZERO) as Vector2) + Vector2(0.0, visual_top_offset)
			var shifted_polygon := PackedVector2Array()
			var polygon: PackedVector2Array = _board_layout_cache_tile_polygons.get(tile, PackedVector2Array()) as PackedVector2Array
			for point: Vector2 in polygon:
				shifted_polygon.append(point + Vector2(0.0, visual_top_offset))
			_board_layout_cache_tile_polygons[tile] = shifted_polygon

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
		var row: Array = _annotate_intensity_intent_row(ActionIcons.tokens_for_action(action))
		var support_token: Dictionary = _support_target_token_for_action(unit, action)
		if not support_token.is_empty():
			row.append(support_token)
		if not row.is_empty():
			rows.append(row)
		var bonus_row: Array = ActionIcons.tokens_for_intensity_bonus(action)
		if not bonus_row.is_empty():
			rows.append(_annotate_intensity_intent_row(bonus_row))
	return rows

func _annotate_intensity_intent_row(row: Array) -> Array:
	var annotated: Array = []
	for token_var: Variant in row:
		if typeof(token_var) != TYPE_DICTIONARY:
			annotated.append(token_var)
			continue
		var token: Dictionary = (token_var as Dictionary).duplicate(true)
		var kind: String = str(token.get("kind", ""))
		if kind in ["intensity_requirement", "intensity_spend"]:
			var element_id: String = str(token.get("element", ElementData.NONE))
			var needed: int = int(token.get("threshold", token.get("amount", 0)))
			token["condition_active"] = _ambient_intensity(element_id) >= needed
		annotated.append(token)
	return annotated

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
	for prefix: String in ["Tunnel ", "Dust ", "Stone ", "Bone ", "Lightning ", "Grave "]:
		if display_name.begins_with(prefix):
			return display_name.substr(prefix.length())
	return display_name

func _unit_status_badges(unit: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	var truesight_activations: int = int(presentation.get("umbra_truesight_activations", 0))
	var conditional_truesight: bool = bool(presentation.get("umbra_truesight_conditional", false))
	if str(unit.get("role", "")) == "player" and (truesight_activations != 0 or conditional_truesight):
		var duration_text: String = "Active while standing in Light." if conditional_truesight else "Lasts for this combat." if truesight_activations < 0 else "%d player turn%s remaining." % [truesight_activations, "" if truesight_activations == 1 else "s"]
		badges.append({
			"icon": "truesight",
			"count_text": "" if conditional_truesight else "∞" if truesight_activations < 0 else str(truesight_activations),
			"fill": Color("3c285f"),
			"border": Color("8eefff"),
			"icon_tint": Color.WHITE,
			"tooltip": "True Sight\nEnemies remain visible through Umbra and reveal their intents.\n%s" % duration_text
		})
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
			"border": STATUS_BLEED.lightened(0.22),
			"icon_tint": Color("ffe9df")
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
	if int(unit.get("frost_armor", 0)) > 0:
		badges.append({
			"icon": "freeze",
			"count": int(unit.get("frost_armor", 0)),
			"fill": Color("274864"),
			"border": Color("b9f3ff"),
			"tooltip": "Crystal Armor\nEach damaging hit breaks one layer instead of dealing damage."
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
	var icon_tint: Color = badge.get("icon_tint", Color("1f1812"))
	var tooltip: String = str(badge.get("tooltip", ActionIcons.tooltip(icon_key)))
	_draw_keyword_icon(icon_key, Rect2(center - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), tooltip, icon_tint)
	var count: int = int(badge.get("count", 0))
	var count_text: String = str(badge.get("count_text", ""))
	if count_text.is_empty() and count > 0:
		count_text = str(count)
	if count_text.is_empty():
		_register_tooltip(badge_rect, tooltip)
		return
	var chip_rect := Rect2(center + Vector2(5.0, 3.0), Vector2(12.0, 12.0))
	badge_rect = badge_rect.merge(chip_rect)
	draw_rect(chip_rect, Color(0.09, 0.07, 0.05, 0.96), true)
	draw_rect(chip_rect, badge.get("border", Color.WHITE), false, 1.0)
	draw_string(
		font,
		chip_rect.position + Vector2(0.0, 9.0),
		count_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		chip_rect.size.x,
		9,
		Color("fff4dc")
	)
	_register_tooltip(badge_rect, tooltip)

func _update_cursor_shape() -> void:
	if _navigation_pan_active:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		return
	var is_hot: bool = exit_tiles.has(_hover_tile) or move_tiles.has(_hover_tile) or attack_tiles.has(_hover_tile) or _ability_tiles().has(_hover_tile)
	if is_hot:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif _tile_drag_aiming_active():
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		mouse_default_cursor_shape = Control.CURSOR_MOVE

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

func _draw_trap_marker(trap: Dictionary) -> void:
	var tile: Vector2i = trap.get("pos", Vector2i(-1, -1))
	if tile.x < 0 or not _board_tile_is_visible_to_player(tile):
		return
	var trap_texture: Texture2D = _trap_idle_texture(trap)
	if trap_texture != null:
		var trap_rect: Rect2 = _trap_visual_draw_rect(trap)
		draw_texture_rect(trap_texture, trap_rect, false, _trap_visual_modulate(trap))
		_register_tooltip(trap_rect.grow(4.0), _trap_tooltip_text(trap))

func _trap_visual_draw_rect(trap: Dictionary) -> Rect2:
	var tile: Vector2i = trap.get("pos", Vector2i(-1, -1))
	if tile.x < 0:
		return Rect2()
	var trap_rect: Rect2 = _trap_draw_rect(tile)
	var intensity: int = _ambient_intensity(str(trap.get("element", ElementData.NONE)))
	var scale_bonus: float = clampf(float(intensity - 1) * 0.035, -0.04, 0.18)
	var scaled_size: Vector2 = trap_rect.size * (1.0 + scale_bonus)
	return Rect2(trap_rect.get_center() - scaled_size * 0.5, scaled_size)

func _trap_visual_modulate(_trap: Dictionary) -> Color:
	return Color.WHITE

func _trap_draw_rect(tile: Vector2i) -> Rect2:
	var tile_width: float = _tile_width()
	var draw_size := Vector2(tile_width * TRAP_DRAW_WIDTH_SCALE, _tile_height() * TRAP_DRAW_HEIGHT_SCALE)
	var center: Vector2 = _tile_center(tile) + Vector2(0.0, _tile_height() * TRAP_DRAW_Y_OFFSET_SCALE)
	return Rect2(center - draw_size * 0.5, draw_size)

func _trap_tooltip_text(trap: Dictionary) -> String:
	var element_id: String = str(trap.get("element", ElementData.NONE))
	var intensity: int = _ambient_intensity(element_id)
	var base_damage: int = int(trap.get("base_damage", trap.get("damage", 0)))
	var resolved_damage: int = ElementalIntensityRules.scaled_trap_damage(base_damage, intensity)
	return "%s Trap\n%d damage" % [ElementData.name(element_id), resolved_damage]
