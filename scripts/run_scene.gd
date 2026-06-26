extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const AttackSfxLibrary = preload("res://scripts/attack_sfx_library.gd")
const DialogueEngineScript = preload("res://scripts/dialogue_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const LabyrinthMapViewScript = preload("res://scripts/labyrinth_map_view.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const DeathEngulfOverlay = preload("res://scripts/death_engulf_overlay.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

class TooltipPanelContainer:
	extends PanelContainer
	const UiTooltipPanelScript = preload("res://scripts/ui_tooltip_panel.gd")

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.strip_edges().is_empty():
			return null
		return UiTooltipPanelScript.make_text(for_text)

class EquipmentTooltipPanelContainer:
	extends TooltipPanelContainer

	var equipment_id: String = ""
	var host: Node = null

	func _make_custom_tooltip(for_text: String) -> Object:
		if host == null or equipment_id.is_empty():
			return super._make_custom_tooltip(for_text)
		return host.call("_build_equipment_tooltip_panel", equipment_id)

class EquipmentInventoryTile:
	extends EquipmentTooltipPanelContainer

	var _left_pressed: bool = false

	func _gui_input(event: InputEvent) -> void:
		if host == null or equipment_id.is_empty():
			return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			if mouse_event.button_index != MOUSE_BUTTON_LEFT:
				return
			if mouse_event.pressed:
				if mouse_event.double_click:
					_left_pressed = false
					host.call("_equip_equipment_from_overlay", equipment_id)
					accept_event()
					return
				if bool(host.call("_equipment_overlay_can_change")):
					_left_pressed = true
					host.call("_begin_equipment_overlay_drag", equipment_id, host.call("_equipment_icon_rect_for_control", self), self, get_viewport().get_mouse_position())
					accept_event()
					return
			elif _left_pressed:
				_left_pressed = false
				host.call("_release_equipment_overlay_drag", get_viewport().get_mouse_position())
				accept_event()
				return
		elif event is InputEventMouseMotion and _left_pressed:
			host.call("_update_equipment_overlay_drag", get_viewport().get_mouse_position())
			accept_event()

class EquipmentSlotDrop:
	extends EquipmentTooltipPanelContainer

	var slot_id: String = ""

class EquipmentCardBadge:
	extends TooltipPanelContainer

	var card_id: String = ""
	var host: Node = null

	func _make_custom_tooltip(for_text: String) -> Object:
		if host == null or card_id.is_empty():
			return super._make_custom_tooltip(for_text)
		return host.call("_build_card_tooltip_panel", card_id)

class MagicCardTile:
	extends EquipmentCardBadge

	var source_kind: String = ""
	var magic_index: int = -1
	var _left_pressed: bool = false

	func _gui_input(event: InputEvent) -> void:
		if host == null or card_id.is_empty():
			return
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			var mouse_position: Vector2 = mouse_event.global_position
			if mouse_position == Vector2.ZERO:
				mouse_position = get_viewport().get_mouse_position()
			if mouse_event.button_index != MOUSE_BUTTON_LEFT:
				return
			if mouse_event.pressed:
				if bool(host.call("_magic_overlay_can_change")):
					_left_pressed = true
					host.call("_begin_magic_overlay_drag", source_kind, magic_index, card_id, get_global_rect(), self, mouse_position)
					accept_event()
					return
			elif _left_pressed or bool(host.call("_magic_overlay_drag_active")):
				_left_pressed = false
				host.call("_release_magic_overlay_drag", mouse_position)
				accept_event()
				return
		elif event is InputEventMouseMotion:
			var motion_event: InputEventMouseMotion = event
			var motion_position: Vector2 = motion_event.global_position
			if motion_position == Vector2.ZERO:
				motion_position = get_viewport().get_mouse_position()
			if _left_pressed or bool(host.call("_magic_overlay_drag_active")):
				host.call("_update_magic_overlay_drag", motion_position)
				accept_event()

class CardArtBadgeWash:
	extends Control

	var accent: Color = Color("f0c978")
	var wash_alpha: float = 0.36

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.06), true)
		draw_rect(rect, Color(0.025, 0.018, 0.014, wash_alpha), true)
		var vertical_steps: int = max(12, int(rect.size.y))
		for index: int in range(vertical_steps):
			var t: float = float(index) / float(max(1, vertical_steps - 1))
			var eased_bottom: float = _badge_smoothstep(0.22, 1.0, t)
			var eased_top: float = 1.0 - _badge_smoothstep(0.0, 0.34, t)
			var alpha: float = 0.16 * eased_bottom + 0.05 * eased_top
			var y0: float = rect.size.y * float(index) / float(vertical_steps)
			var y1: float = rect.size.y * float(index + 1) / float(vertical_steps)
			draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), Color(0.0, 0.0, 0.0, alpha), true)
		var side_width: float = minf(34.0, rect.size.x * 0.18)
		var side_steps: int = max(8, int(side_width))
		for index: int in range(side_steps):
			var edge_t: float = float(index) / float(max(1, side_steps - 1))
			var alpha: float = 0.12 * pow(1.0 - edge_t, 1.7)
			var x0: float = side_width * float(index) / float(side_steps)
			var x1: float = side_width * float(index + 1) / float(side_steps)
			var strip_width: float = x1 - x0 + 1.0
			draw_rect(Rect2(x0, 0.0, strip_width, rect.size.y), Color(0.0, 0.0, 0.0, alpha), true)
			draw_rect(Rect2(rect.size.x - x1, 0.0, strip_width, rect.size.y), Color(0.0, 0.0, 0.0, alpha), true)

	func _badge_smoothstep(edge0: float, edge1: float, value: float) -> float:
		var t: float = clampf((value - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

class CardArtBadgeBacking:
	extends Control

	var accent: Color = Color("f0c978")
	var base_color: Color = Color("51463f")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var ground: Color = base_color.darkened(0.24).lerp(accent.darkened(0.34), 0.10)
		var glow: Color = base_color.lightened(0.08).lerp(accent, 0.14)
		var bottom: Color = base_color.darkened(0.42).lerp(accent.darkened(0.42), 0.08)
		var steps: int = max(12, int(rect.size.y))
		for index: int in range(steps):
			var t: float = float(index) / float(max(1, steps - 1))
			var eased: float = _badge_smoothstep(0.0, 1.0, t)
			var color: Color = ground.lerp(bottom, eased)
			var glow_alpha: float = 0.12 * (1.0 - minf(absf(t - 0.42) / 0.58, 1.0))
			var y0: float = rect.size.y * float(index) / float(steps)
			var y1: float = rect.size.y * float(index + 1) / float(steps)
			draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), Color(color.r, color.g, color.b, 1.0), true)
			draw_rect(Rect2(0.0, y0, rect.size.x, y1 - y0 + 1.0), Color(glow.r, glow.g, glow.b, glow_alpha), true)

	func _badge_smoothstep(edge0: float, edge1: float, value: float) -> float:
		var t: float = clampf((value - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

class FatigueEdgeOverlay:
	extends Control

	const WEB_LINE_COLOR: Color = Color(0.96, 0.06, 0.04, 0.70)
	const WEB_GLOW_COLOR: Color = Color(0.58, 0.0, 0.0, 0.30)
	const EDGE_WASH_COLOR: Color = Color(0.52, 0.0, 0.0, 0.14)

	var progress: float = -1.0:
		set(value):
			progress = value
			visible = progress >= 0.0
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		if progress < 0.0 or size.x <= 0.0 or size.y <= 0.0:
			return
		var t: float = clampf(progress, 0.0, 1.0)
		var pulse: float = sin(t * PI)
		if pulse <= 0.001:
			return
		var wash_color: Color = EDGE_WASH_COLOR
		wash_color.a *= pulse
		var edge_thickness: float = lerpf(18.0, 46.0, pulse)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, edge_thickness)), wash_color, true)
		draw_rect(Rect2(Vector2(0.0, size.y - edge_thickness), Vector2(size.x, edge_thickness)), wash_color, true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(edge_thickness, size.y)), wash_color, true)
		draw_rect(Rect2(Vector2(size.x - edge_thickness, 0.0), Vector2(edge_thickness, size.y)), wash_color, true)

		var line_color: Color = WEB_LINE_COLOR
		line_color.a *= pulse
		var glow_color: Color = WEB_GLOW_COLOR
		glow_color.a *= pulse
		var reach: float = minf(size.x, size.y) * lerpf(0.10, 0.27, pulse)
		_draw_corner_web(Vector2.ZERO, Vector2(1.0, 1.0), reach, line_color, glow_color)
		_draw_corner_web(Vector2(size.x, 0.0), Vector2(-1.0, 1.0), reach, line_color, glow_color)
		_draw_corner_web(Vector2(0.0, size.y), Vector2(1.0, -1.0), reach, line_color, glow_color)
		_draw_corner_web(size, Vector2(-1.0, -1.0), reach, line_color, glow_color)
		_draw_edge_strand(Vector2(size.x * 0.20, 0.0), Vector2(0.12, 1.0), reach * 0.62, line_color, glow_color)
		_draw_edge_strand(Vector2(size.x * 0.78, size.y), Vector2(-0.18, -1.0), reach * 0.58, line_color, glow_color)
		_draw_edge_strand(Vector2(0.0, size.y * 0.36), Vector2(1.0, -0.12), reach * 0.66, line_color, glow_color)
		_draw_edge_strand(Vector2(size.x, size.y * 0.62), Vector2(-1.0, 0.16), reach * 0.60, line_color, glow_color)

	func _draw_corner_web(origin: Vector2, direction: Vector2, reach: float, line_color: Color, glow_color: Color) -> void:
		var endpoints: Array = [
			origin + Vector2(direction.x * reach, 0.0),
			origin + Vector2(direction.x * reach * 0.78, direction.y * reach * 0.28),
			origin + Vector2(direction.x * reach * 0.50, direction.y * reach * 0.64),
			origin + Vector2(0.0, direction.y * reach)
		]
		for endpoint_var: Variant in endpoints:
			var endpoint: Vector2 = endpoint_var
			draw_line(origin, endpoint, glow_color, 4.0, true)
			draw_line(origin, endpoint, line_color, 1.3, true)
		for ring_var: Variant in [0.34, 0.58, 0.82]:
			var ring: float = float(ring_var)
			var points := PackedVector2Array()
			for endpoint_var: Variant in endpoints:
				var endpoint: Vector2 = endpoint_var
				points.append(origin.lerp(endpoint, ring))
			draw_polyline(points, glow_color, 3.0, true)
			draw_polyline(points, line_color, 1.1, true)

	func _draw_edge_strand(start: Vector2, direction: Vector2, length: float, line_color: Color, glow_color: Color) -> void:
		var points := PackedVector2Array()
		points.append(start)
		points.append(start + Vector2(direction.x * length * 0.34, direction.y * length * 0.34) + Vector2(direction.y, -direction.x) * 7.0)
		points.append(start + Vector2(direction.x * length * 0.68, direction.y * length * 0.68) - Vector2(direction.y, -direction.x) * 5.0)
		points.append(start + direction * length)
		draw_polyline(points, glow_color, 4.0, true)
		draw_polyline(points, line_color, 1.2, true)

const STEP_DELAY_SECONDS: float = 0.26
const MOVE_STEP_FRAMES: int = 8
const MOVE_FRAME_SECONDS: float = 0.045
const ATTACK_FRAMES: int = 6
const ATTACK_FRAME_SECONDS: float = 0.04
const DRAW_FRAME_SECONDS: float = 0.23
const CARD_PLAY_SECONDS: float = 0.14
const CARD_PILE_SECONDS: float = 0.18
const CARD_SNAPBACK_SECONDS: float = 0.14
const DOOR_OPENING_FRAMES: int = 8
const DOOR_OPENING_FRAME_SECONDS: float = 0.075
const DOOR_OPENING_SETTLE_SECONDS: float = 0.04
const FLOAT_TEXT_FRAMES: int = 7
const FLOAT_TEXT_FRAME_SECONDS: float = 0.05
const FATIGUE_EFFECT_FRAMES: int = 9
const FATIGUE_EFFECT_FRAME_SECONDS: float = 0.045
const FATIGUE_EDGE_LINGER_FRAMES: int = 3
const FATIGUE_EDGE_HOLD_PROGRESS: float = 0.82
const DIALOGUE_CHARACTERS_PER_SECOND: float = 34.0
const PLAYER_PREVIEW_FOCUS: Color = Color("f1d18b")
const PLAYER_ATTACK_FOCUS: Color = Color("f08c53")
const ILLUSION_PREVIEW_FOCUS: Color = Color("9beeff")
const INVALID_TARGET_TILE: Vector2i = Vector2i(-1, -1)
const SHORTCUT_ATTACK_TYPES := ["melee", "ranged", "push", "pull"]
const FALLBACK_ATTACK_BASE_DAMAGE: int = 2
const FALLBACK_MOVE_RANGE: int = 2
const CARD_WIDGET_BASE_SIZE: Vector2 = Vector2(250.0, 352.0)
const CARD_ASPECT_RATIO: float = 352.0 / 250.0
const ORIENTATION_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const HAND_CARD_OVERLAP: float = -28.0
const HAND_CARD_GAP: float = 14.0
const PILE_CARD_SIZE: Vector2 = Vector2(220.0, 220.0 * CARD_ASPECT_RATIO)
const PILE_DIALOG_CARD_SIZE: Vector2 = Vector2(196.0, 196.0 * CARD_ASPECT_RATIO)
const PILE_DIALOG_FULL_SIZE: Vector2 = Vector2(1220.0, 620.0)
const PILE_DIALOG_ROW_SIZE: Vector2 = Vector2(1220.0, 438.0)
const PILE_DIALOG_EMPTY_SIZE: Vector2 = Vector2(520.0, 238.0)
const PILE_DIALOG_MIN_CARD_WIDTH: float = 620.0
const PILE_CARD_SCALE: float = 0.80
const PILE_STACK_OFFSET: Vector2 = Vector2(8.0, 10.0)
const PILE_STACK_LAYERS: int = 3
const UPGRADE_CARD_SIZE: Vector2 = Vector2(186.0, 186.0 * CARD_ASPECT_RATIO)
const CARD_BACK_TEXTURE_PATH: String = "res://assets/art/ui/card_back.png"
const CARD_FRAME_TEXTURE_PATH: String = "res://assets/art/ui/card_frame.png"
const CARD_PLAY_ICON_PATH: String = "res://assets/art/icons/card_play.png"
const PLAYER_UNIT_TEXTURE_PATH: String = "res://assets/placeholders/units/player_reaver.png"
const EMBER_ICON_PATH: String = "res://assets/art/icons/ember.png"
const HEALTH_ICON_PATH: String = "res://assets/art/icons/health.png"
const RELIC_BADGE_SIZE: Vector2 = Vector2(52.0, 52.0)
const RELIC_BAR_HORIZONTAL_GAP: float = 8.0
const RELIC_BAR_MIN_VISIBLE_RELICS: int = 8
const HEADER_RELIC_WRAP_MARGIN: float = 24.0
const ELEMENTAL_INTENSITY_HEADER_GAP: float = 3.0
const INTENSITY_BADGE_SIZE: Vector2 = Vector2(87.0, 87.0)
const INTENSITY_ICON_INSET: float = 8.0
const MAX_EMBER_REWARD_MOTES: int = 20
const CAMPFIRE_ACTION_OVERLAY_SIZE: Vector2 = Vector2(468.0, 88.0)
const CAMPFIRE_LINGER_HEAL_AMOUNT: int = 100
const CAMPFIRE_CHOICE_LINGER_ICON_PATH: String = "res://assets/art/ui/campfire_choice_linger.png"
const CAMPFIRE_CHOICE_EMBRACE_ICON_PATH: String = "res://assets/art/ui/campfire_choice_embrace.png"
const CAMPFIRE_CHOICE_STRENGTH_ICON_PATH: String = "res://assets/art/ui/campfire_choice_strength.png"
const CAMPFIRE_CHOICE_LINGER_TEXT: String = "Linger for a moment"
const CAMPFIRE_CHOICE_EMBRACE_TEXT: String = "Embrace the fire's warmth"
const CAMPFIRE_CHOICE_STRENGTH_TEXT: String = "Draw strength from the flame"
const CAMPFIRE_CHOICE_LINGER_DESCRIPTION: String = "Heal 100 and continue onward"
const CAMPFIRE_CHOICE_EMBRACE_DESCRIPTION: String = "Carry held embers into the next run"
const CAMPFIRE_CHOICE_STRENGTH_DESCRIPTION: String = "Spend embers to become permanently stronger"
const PROGRESSION_STEPPER_BUTTON_NORMAL_PATH: String = "res://assets/art/ui/progression_stepper_normal.png"
const PROGRESSION_STEPPER_BUTTON_HOVER_PATH: String = "res://assets/art/ui/progression_stepper_hover.png"
const PROGRESSION_STEPPER_BUTTON_PRESSED_PATH: String = "res://assets/art/ui/progression_stepper_pressed.png"
const PROGRESSION_STEPPER_BUTTON_DISABLED_PATH: String = "res://assets/art/ui/progression_stepper_disabled.png"
const PROGRESSION_COMMAND_BUTTON_NORMAL_PATH: String = "res://assets/art/ui/progression_command_normal.png"
const PROGRESSION_COMMAND_BUTTON_HOVER_PATH: String = "res://assets/art/ui/progression_command_hover.png"
const PROGRESSION_COMMAND_BUTTON_PRESSED_PATH: String = "res://assets/art/ui/progression_command_pressed.png"
const PROGRESSION_COMMAND_BUTTON_DISABLED_PATH: String = "res://assets/art/ui/progression_command_disabled.png"
const RELIC_CHOICE_OVERLAY_SIZE: Vector2 = Vector2(1040.0, 248.0)
const RELIC_CHOICE_CARD_SIZE: Vector2 = Vector2(264.0, 220.0)
const REWARD_CHOICE_TITLE_TEXT: String = "GROW YOUR POWER"
const RELIC_CHOICE_TITLE_TEXT: String = "CLAIM YOUR TREASURE"
const RELIC_CHOICE_TITLE_FONT_SIZE: int = 76
const RELIC_CHOICE_TITLE_HEIGHT: float = 156.0
const RELIC_CHOICE_TITLE_TOP_RATIO: float = 0.0
const RELIC_CHOICE_BOTTOM_MARGIN: float = 68.0
const TERMINAL_OVERLAY_SIZE: Vector2 = Vector2(560.0, 292.0)
const DIALOGUE_DIALOG_WIDTH: float = 1060.0
const DIALOGUE_DIALOG_HINT_MIN_HEIGHT: float = 154.0
const DIALOGUE_DIALOG_OPTION_MIN_HEIGHT: float = 206.0
const DIALOGUE_TEXT_HINT_MIN_HEIGHT: float = 46.0
const DIALOGUE_TEXT_OPTION_MIN_HEIGHT: float = 78.0
const DIALOGUE_HINT_FOOTER_HEIGHT: float = 34.0
const DIALOGUE_OPTION_BUTTON_HEIGHT: float = 58.0
const DIALOGUE_OPTION_BUTTON_MIN_WIDTH: float = 292.0
const MENU_DIALOG_BUTTON_MIN_WIDTH: float = 234.0
const UPGRADE_LIST_BUTTON_MIN_WIDTH: float = 216.0
const CHARACTER_DIALOG_SIZE: Vector2 = Vector2(1160.0, 790.0)
const CHARACTER_BODY_HEIGHT: float = 600.0
const EQUIPMENT_TILE_SIZE: Vector2 = Vector2(178.0, 92.0)
const EQUIPMENT_SLOT_SIZE: Vector2 = Vector2(300.0, 72.0)
const EQUIPMENT_ICON_SIZE: Vector2 = Vector2(42.0, 42.0)
const EQUIPMENT_DRAG_GHOST_SIZE: Vector2 = Vector2(78.0, 78.0)
const EQUIPMENT_DRAG_CURSOR_OFFSET: Vector2 = Vector2(18.0, 20.0)
const EQUIPMENT_SWAP_SNAP_SECONDS: float = 0.22
const EQUIPMENT_SWAP_RETURN_SECONDS: float = 0.24
const EQUIPMENT_DECK_BADGE_SIZE: Vector2 = Vector2(164.0, 34.0)
const MAGIC_ATTUNED_TILE_SIZE: Vector2 = Vector2(292.0, 46.0)
const MAGIC_INVENTORY_TILE_SIZE: Vector2 = Vector2(164.0, 38.0)
const MAGIC_DRAG_CURSOR_OFFSET: Vector2 = Vector2(14.0, 18.0)
const EQUIPMENT_TOOLTIP_CARD_SIZE: Vector2 = Vector2(150.0, 150.0 * CARD_ASPECT_RATIO)
const CARD_TOOLTIP_SIZE: Vector2 = Vector2(180.0, 180.0 * CARD_ASPECT_RATIO)
const TURN_ORDER_PANEL_MIN_SIZE: Vector2 = Vector2(840.0, 104.0)
const TURN_ORDER_PANEL_MIN_WIDTH: float = 520.0
const TURN_ORDER_LABEL_WIDTH: float = 118.0
const TURN_ORDER_PORTRAIT_SIZE: Vector2 = Vector2(84.0, 84.0)
const TURN_ORDER_ACTIVE_SIZE: Vector2 = Vector2(84.0, 84.0)
const TURN_ORDER_SLOT_GAP: float = 9.0
const TURN_ORDER_MAX_SLOTS: int = 10
const TURN_ORDER_REMOVE_SECONDS: float = 0.18
const TURN_ORDER_REFLOW_SECONDS: float = 0.24
const TURN_ORDER_INSERT_SECONDS: float = 0.20
const TURN_ORDER_STYLE_SECONDS: float = 0.18
const TURN_ORDER_FLOAT_OFFSET: float = 24.0
const TURN_ORDER_PORTRAITS := {
	"player": "res://assets/art/portraits/player_reaver.png",
	"crawler": "res://assets/art/portraits/tunnel_crawler.png",
	"acolyte": "res://assets/art/portraits/ash_acolyte.png",
	"harrier": "res://assets/art/portraits/bone_harrier.png",
	"warden": "res://assets/art/portraits/ash_warden.png",
	"zekarion": "res://assets/art/portraits/zekarion.png",
	"lightning_wisp": "res://assets/art/portraits/lightning_wisp.png"
}
const MUSIC_FADE_SECONDS: float = 2.5
const MUSIC_SILENCE_DB: float = -60.0
@onready var top_bar: HBoxContainer = $Backdrop/Margin/MainVBox/TopBar
@onready var title_box: VBoxContainer = $Backdrop/Margin/MainVBox/TopBar/TitleBox
@onready var room_title: Label = $Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomTitle
@onready var room_subtitle: Label = $Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomSubtitle
@onready var relic_bar: HFlowContainer = $Backdrop/Margin/MainVBox/TopBar/TitleBox/RelicBar
@onready var header_spacer: Control = $Backdrop/Margin/MainVBox/TopBar/Spacer
@onready var stats_label: Label = $Backdrop/Margin/MainVBox/TopBar/StatsLabel
@onready var menu_button: Button = $Backdrop/Margin/MainVBox/TopBar/MenuButton
@onready var board_view = $Backdrop/Margin/MainVBox/StageRoot/CombatBoard
@onready var action_banner: Label = $Backdrop/Margin/MainVBox/StageRoot/ActionBanner
@onready var mini_map_overlay: PanelContainer = $Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay
@onready var mini_map = $Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay/MiniMapMargin/MiniMap
@onready var log_overlay: PanelContainer = $Backdrop/Margin/MainVBox/StageRoot/LogOverlay
@onready var log_label: RichTextLabel = $Backdrop/Margin/MainVBox/StageRoot/LogOverlay/LogMargin/Log
@onready var bottom_stack: VBoxContainer = $Backdrop/Margin/MainVBox/BottomStack
@onready var left_action_stack: VBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack
@onready var choice_bar: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar
@onready var hand_row: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow
@onready var piles_bar: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar
@onready var draw_pile: PanelContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile
@onready var discard_pile: PanelContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile
@onready var burn_pile: PanelContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile
@onready var draw_count: Label = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile/DrawMargin/DrawVBox/DrawCount
@onready var discard_count: Label = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile/DiscardMargin/DiscardVBox/DiscardCount
@onready var burn_count: Label = $Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile/BurnMargin/BurnVBox/BurnCount
@onready var hand_scroll: ScrollContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll
@onready var hand_box: HandFanContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox

var _ui_skin: UiSkin = UiSkin.new()
var _dialogue_engine = DialogueEngineScript.new()
var _run_engine = RunEngineScript.new()
var _combat_engine = CombatEngineScript.new()
var _progression: Dictionary = {}
var _run_state: Dictionary = {}
var _combat_state: Dictionary = {}
var _preview_combat_state: Dictionary = {}
var _analytics_store: AnalyticsStore = AnalyticsStore.new()
var _analytics_combat_tracker: Dictionary = {}
var _selected_card_index: int = -1
var _hovered_card_index: int = -1
var _hovered_board_tile: Vector2i = Vector2i(-1, -1)
var _pending_actions: Array = []
var _pending_action_index: int = 0
var _pending_action_can_skip: bool = false
var _pending_target_tiles: Array[Vector2i] = []
var _pending_selected_targets: Array[Vector2i] = []
var _pending_orientation_target_tile: Vector2i = INVALID_TARGET_TILE
var _aoe_aim_orientation: Vector2i = Vector2i(1, 0)
var _victory_carry_processed: bool = false
var _defeat_loss_processed: bool = false
var _victory_carry_amount: int = 0
var _exit_destinations_by_tile: Dictionary = {}
var _animation_lock: bool = false
var _board_presentation: Dictionary = {}
var _menu_scrim: ColorRect
var _menu_dialog: PanelContainer
var _pile_scrim: ColorRect
var _pile_dialog: PanelContainer
var _pile_dialog_title: Label
var _pile_dialog_scroll: ScrollContainer
var _pile_dialog_cards: HFlowContainer
var _pile_dialog_empty: Label
var _pile_content_hosts: Dictionary = {}
var _pile_visual_hosts: Dictionary = {}
var _pile_badges: Dictionary = {}
var _active_pile_kind: String = ""
var _play_meter: PanelContainer
var _play_meter_count: Label
var _play_meter_icon: TextureRect
var _intensity_bar: Control
var _turn_order_panel: PanelContainer
var _turn_order_bar: Control
var _turn_order_animating: bool = false
var _turn_order_hovered_enemy_key: String = ""
var _turn_order_panel_locked_width: float = -1.0
var _intensity_badges: Dictionary = {}
var _intensity_labels: Dictionary = {}
var _ember_count_override: int = -1
var _card_play_count_override: int = -1
var _choice_button_overlay: HBoxContainer
var _context_choice_overlay: PanelContainer
var _context_choice_bar: HBoxContainer
var _relic_choice_overlay: Control
var _relic_choice_title: Label
var _relic_choice_host: CenterContainer
var _relic_choice_bar: HBoxContainer
var _terminal_overlay: Control
var _terminal_panel: PanelContainer
var _terminal_title_label: Label
var _terminal_status_label: Label
var _terminal_reward_label: Label
var _large_map_scrim: ColorRect
var _large_map_dialog: PanelContainer
var _large_map_view: Control
var _selected_card_label_override: String = ""
var _drag_overlay: Control
var _drag_zone_panels: Dictionary = {}
var _drag_zone_labels: Dictionary = {}
var _drag_card_index: int = -1
var _drag_card_options: Dictionary = {}
var _drag_hover_zone: String = ""
var _card_fx_layer: Control
var _equipment_fx_layer: Control
var _fatigue_edge_overlay: FatigueEdgeOverlay
var _death_overlay: DeathEngulfOverlay
var _death_sequence_started: bool = false
var _drag_card_proxy: Control
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _active_music_id: String = ""
var _drag_card_source_rect: Rect2 = Rect2()
var _drag_card_grab_offset: Vector2 = Vector2.ZERO
var _animating_hand_card_index: int = -1
var _dialogue_overlay: Control
var _dialogue_dialog: PanelContainer
var _dialogue_name_label: Label
var _dialogue_text_label: RichTextLabel
var _dialogue_footer: HBoxContainer
var _dialogue_hint_label: Label
var _dialogue_choice_bar: HBoxContainer
var _upgrade_scrim: ColorRect
var _upgrade_dialog: PanelContainer
var _upgrade_embers_label: Label
var _upgrade_card_list: VBoxContainer
var _upgrade_element_list: VBoxContainer
var _upgrade_option_list: VBoxContainer
var _upgrade_preview_box: HBoxContainer
var _upgrade_selected_card_id: String = ""
var _upgrade_selected_element_key: String = ""
var _progression_overlay_mode: String = ""
var _progression_pending_stats: Dictionary = {}
var _equipment_slot_panels: Dictionary = {}
var _equipment_inventory_tiles: Dictionary = {}
var _equipment_drag_id: String = ""
var _equipment_drag_source_rect: Rect2 = Rect2()
var _equipment_drag_source_control: Control
var _equipment_held_proxy: Control
var _equipment_swap_animation_active: bool = false
var _magic_attuned_tiles: Dictionary = {}
var _magic_inventory_tiles: Dictionary = {}
var _magic_drag_source_kind: String = ""
var _magic_drag_index: int = -1
var _magic_drag_card_id: String = ""
var _magic_drag_source_rect: Rect2 = Rect2()
var _magic_drag_source_control: Control
var _magic_held_proxy: Control
var _magic_drag_release_in_progress: bool = false
var _magic_drag_last_mouse_position: Vector2 = Vector2(-1.0, -1.0)
var _magic_attuned_drop_panel: Control
var _magic_inventory_drop_panel: Control
var _dialogue_active: bool = false
var _dialogue_script: Dictionary = {}
var _dialogue_line_index: int = -1
var _dialogue_char_progress: float = 0.0
var _dialogue_text_complete: bool = false
var _last_auto_dialogue_key: String = ""

func _ready() -> void:
	ParallelRuntime.apply_from_environment()
	set_process(true)
	_apply_style()
	_layout_mini_map_overlay()
	_build_overlay_ui()
	_build_context_choice_overlay()
	_setup_pile_widgets()
	_setup_play_meter()
	_setup_elemental_intensity_bar()
	_connect_header_layout_signals()
	_connect_choice_overlay_layout_signals()
	_connect_board_aim_signals()
	_boot_run()

func _process(delta: float) -> void:
	if not _dialogue_active or _dialogue_text_complete or _dialogue_text_label == null:
		return
	var line: Dictionary = _current_dialogue_line()
	var text: String = _dialogue_visible_text()
	if text.is_empty():
		_complete_current_dialogue_line()
		return
	_dialogue_char_progress = minf(_dialogue_char_progress + delta * DIALOGUE_CHARACTERS_PER_SECOND, float(text.length()))
	_dialogue_text_label.visible_characters = int(floor(_dialogue_char_progress))
	if _dialogue_char_progress >= float(text.length()):
		_complete_current_dialogue_line()

func _input(event: InputEvent) -> void:
	if _dialogue_active:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if _upgrade_scrim != null and _upgrade_scrim.visible:
		if not _equipment_drag_id.is_empty():
			if event is InputEventMouseMotion:
				_update_equipment_overlay_drag(_current_mouse_position())
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				get_viewport().set_input_as_handled()
				await _release_equipment_overlay_drag(_current_mouse_position())
				return
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				await _cancel_equipment_overlay_drag(true)
				return
		if not _magic_drag_card_id.is_empty():
			if event is InputEventMouseMotion:
				_update_magic_overlay_drag(_mouse_event_position(event))
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				get_viewport().set_input_as_handled()
				await _release_magic_overlay_drag(_mouse_event_position(event))
				return
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				await _cancel_magic_overlay_drag(true)
				return
		if event.is_action_pressed("ui_cancel"):
			_close_card_upgrade_overlay()
			get_viewport().set_input_as_handled()
		return
	if _drag_card_index >= 0:
		if event is InputEventMouseMotion:
			_update_drag_overlay_hover(_drag_zone_at(_current_mouse_position()))
			_update_drag_proxy_position(_current_mouse_position())
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			await _commit_drag_drop(_drag_zone_at(_current_mouse_position()))
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			await _animate_drag_cancel_to_source()
			get_viewport().set_input_as_handled()
			return
	if _selected_card_index >= 0 and _current_action_is_aimed_aoe():
		if event.is_action_pressed("ui_left"):
			_rotate_aoe_aim(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_rotate_aoe_aim(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		await _on_cancel_requested()

func _connect_board_aim_signals() -> void:
	if board_view == null:
		return
	if board_view.has_signal("tile_dragged") and not board_view.tile_dragged.is_connected(_on_board_tile_dragged):
		board_view.tile_dragged.connect(_on_board_tile_dragged)
	if board_view.has_signal("tile_drag_released") and not board_view.tile_drag_released.is_connected(_on_board_tile_drag_released):
		board_view.tile_drag_released.connect(_on_board_tile_drag_released)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run_progress()
		get_tree().quit()
	elif what == NOTIFICATION_RESIZED:
		_layout_mini_map_overlay()
		_layout_context_choice_overlay()
		_layout_relic_choice_overlay()
		_layout_terminal_overlay()
		_layout_choice_button_overlay()
		_layout_header_hud()
		_layout_elemental_intensity_bar()

func _apply_style() -> void:
	_apply_tooltip_wrapper_style()
	$Backdrop.color = Color("18120f")
	var mini_map_style := StyleBoxFlat.new()
	mini_map_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	mini_map_style.corner_radius_top_left = 10
	mini_map_style.corner_radius_top_right = 10
	mini_map_style.corner_radius_bottom_right = 10
	mini_map_style.corner_radius_bottom_left = 10
	mini_map_style.border_color = Color(0.91, 0.82, 0.67, 0.24)
	mini_map_style.border_width_left = 1
	mini_map_style.border_width_top = 1
	mini_map_style.border_width_right = 1
	mini_map_style.border_width_bottom = 1
	mini_map_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	mini_map_style.shadow_size = 0
	mini_map_overlay.add_theme_stylebox_override("panel", mini_map_style)
	mini_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	mini_map_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mini_map_overlay.tooltip_text = "Map"
	if not mini_map_overlay.gui_input.is_connected(_on_mini_map_overlay_gui_input):
		mini_map_overlay.gui_input.connect(_on_mini_map_overlay_gui_input)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.09, 0.06, 0.05, 0.74)
	log_style.corner_radius_top_left = 8
	log_style.corner_radius_top_right = 8
	log_style.corner_radius_bottom_right = 8
	log_style.corner_radius_bottom_left = 8
	log_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	log_style.shadow_size = 8
	log_overlay.add_theme_stylebox_override("panel", log_style)
	for pile_panel: PanelContainer in [draw_pile, discard_pile, burn_pile]:
		pile_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		pile_panel.clip_contents = true
	UiTypography.set_label_size(room_title, UiTypography.SIZE_TITLE)
	UiTypography.set_label_size(room_subtitle, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(stats_label, UiTypography.SIZE_SECTION)
	UiTypography.set_label_size(action_banner, UiTypography.SIZE_SMALL)
	room_title.add_theme_color_override("font_color", Color("f0e6d2"))
	room_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	room_title.add_theme_constant_override("outline_size", 2)
	room_subtitle.add_theme_color_override("font_color", Color("cdbca2"))
	stats_label.add_theme_color_override("font_color", Color("f0c978"))
	stats_label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	stats_label.add_theme_constant_override("outline_size", 2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_stretch_ratio = 2.0
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_spacer.size_flags_stretch_ratio = 1.0
	_setup_turn_order_bar()
	relic_bar.visible = false
	relic_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_bar.add_theme_constant_override("h_separation", int(RELIC_BAR_HORIZONTAL_GAP))
	relic_bar.add_theme_constant_override("v_separation", 8)
	action_banner.add_theme_color_override("font_color", Color("fbf0d7"))
	action_banner.add_theme_color_override("font_outline_color", Color("2d1f18"))
	action_banner.add_theme_constant_override("outline_size", 2)
	choice_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	_ui_skin.apply_button_stylebox_overrides(menu_button)
	_ui_skin.apply_button_text_overrides(menu_button)
	menu_button.disabled = false
	menu_button.modulate = Color.WHITE
	UiTypography.set_button_size(menu_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(menu_button, UiSkin.BUTTON_HEIGHT_SMALL)
	UiTypography.set_rich_text_size(log_label, UiTypography.SIZE_SMALL)
	log_label.add_theme_color_override("default_color", Color("f2e7d4"))
	log_label.fit_content = true
	log_label.scroll_following = false
	log_label.scroll_active = false
	mini_map.interactive = false
	mini_map.show_legend = false
	mini_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_map.custom_minimum_size = Vector2.ZERO
	board_view.visible = true
	board_view.custom_minimum_size = Vector2.ZERO
	hand_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hand_scroll.clip_contents = false
	piles_bar.custom_minimum_size = Vector2.ZERO
	piles_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	piles_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	piles_bar.add_theme_constant_override("separation", 18)
	hand_row.custom_minimum_size = Vector2(0.0, 352.0)
	for pile_label: Label in [
		$Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DrawPile/DrawMargin/DrawVBox/DrawTitle,
		$Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/DiscardPile/DiscardMargin/DiscardVBox/DiscardTitle,
		$Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar/BurnPile/BurnMargin/BurnVBox/BurnTitle,
		draw_count,
		discard_count,
		burn_count
	]:
		UiTypography.set_label_size(pile_label, UiTypography.SIZE_SMALL)
		pile_label.add_theme_color_override("font_color", Color("f0e4c8"))
		pile_label.add_theme_color_override("font_outline_color", Color("261b14"))
		pile_label.add_theme_constant_override("outline_size", 1)

func _apply_tooltip_wrapper_style() -> void:
	var scene_theme: Theme = theme if theme != null else Theme.new()
	scene_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	theme = scene_theme

func _build_overlay_ui() -> void:
	_build_card_fx_layer()
	_build_equipment_fx_layer()
	_build_fatigue_edge_overlay()
	_build_choice_button_overlay()
	_build_dialogue_overlay()
	_build_menu_overlay()
	_build_pile_overlay()
	_build_card_upgrade_overlay()
	_build_large_map_overlay()
	_build_drag_overlay()
	_build_death_overlay()

func _build_choice_button_overlay() -> void:
	_choice_button_overlay = HBoxContainer.new()
	_choice_button_overlay.name = "ChoiceButtonOverlay"
	_choice_button_overlay.visible = false
	_choice_button_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_choice_button_overlay.clip_contents = false
	_choice_button_overlay.z_index = 120
	_choice_button_overlay.z_as_relative = false
	_choice_button_overlay.add_theme_constant_override("separation", int(choice_bar.get_theme_constant("separation")))
	add_child(_choice_button_overlay)

func _combat_choice_placeholder_size() -> Vector2:
	return _ui_skin.button_native_size(UiSkin.BUTTON_HEIGHT_ACTION)

func _layout_choice_button_overlay() -> void:
	if _choice_button_overlay == null or not _choice_button_overlay.visible:
		return
	if not choice_bar.is_inside_tree() or not choice_bar.visible:
		return
	var overlay_size: Vector2 = _choice_button_overlay.get_combined_minimum_size()
	_choice_button_overlay.global_position = _choice_button_overlay_anchor_position(overlay_size)
	_choice_button_overlay.size = overlay_size

func _connect_choice_overlay_layout_signals() -> void:
	for control_var: Variant in [choice_bar, piles_bar, left_action_stack, bottom_stack, hand_row]:
		var control: Control = control_var as Control
		if control == null:
			continue
		if not control.resized.is_connected(_queue_choice_button_overlay_layout):
			control.resized.connect(_queue_choice_button_overlay_layout)

func _queue_choice_button_overlay_layout() -> void:
	call_deferred("_layout_choice_button_overlay")

func _choice_button_overlay_anchor_position(overlay_size: Vector2) -> Vector2:
	var choice_rect: Rect2 = choice_bar.get_global_rect()
	if _choice_bar_anchor_is_ready(choice_rect):
		return choice_rect.position
	if piles_bar != null and piles_bar.is_inside_tree():
		var piles_rect: Rect2 = piles_bar.get_global_rect()
		if piles_rect.size.y > 0.0 and piles_rect.position.y > 0.0:
			var separation: float = float(left_action_stack.get_theme_constant("separation")) if left_action_stack != null else 0.0
			return Vector2(piles_rect.position.x, piles_rect.position.y - overlay_size.y - separation)
	return choice_rect.position

func _choice_bar_anchor_is_ready(choice_rect: Rect2) -> bool:
	if choice_rect.size.x <= 0.0 or choice_rect.size.y <= 0.0:
		return false
	if bottom_stack != null and bottom_stack.is_inside_tree():
		var bottom_rect: Rect2 = bottom_stack.get_global_rect()
		if bottom_rect.position.y > 0.0 and choice_rect.position.y < bottom_rect.position.y - 1.0:
			return false
	return choice_rect.position.y > 0.0

func _build_large_map_overlay() -> void:
	_large_map_scrim = ColorRect.new()
	_large_map_scrim.name = "LargeMapScrim"
	_large_map_scrim.visible = false
	_large_map_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_large_map_scrim.z_index = 940
	_large_map_scrim.z_as_relative = false
	_large_map_scrim.color = Color(0.015, 0.012, 0.010, 1.0)
	_large_map_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_large_map_scrim.anchor_right = 1.0
	_large_map_scrim.anchor_bottom = 1.0
	add_child(_large_map_scrim)

	var frame_margin := MarginContainer.new()
	frame_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.anchor_right = 1.0
	frame_margin.anchor_bottom = 1.0
	frame_margin.add_theme_constant_override("margin_left", 34)
	frame_margin.add_theme_constant_override("margin_top", 30)
	frame_margin.add_theme_constant_override("margin_right", 34)
	frame_margin.add_theme_constant_override("margin_bottom", 30)
	frame_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_large_map_scrim.add_child(frame_margin)

	_large_map_dialog = PanelContainer.new()
	_large_map_dialog.name = "LargeMapDialog"
	_large_map_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_large_map_dialog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_large_map_dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.09, 0.065, 0.048, 0.96), Color(0.92, 0.80, 0.60, 0.86), 16.0)
	dialog_style.corner_radius_top_left = 10
	dialog_style.corner_radius_top_right = 10
	dialog_style.corner_radius_bottom_right = 10
	dialog_style.corner_radius_bottom_left = 10
	dialog_style.shadow_size = 18
	_large_map_dialog.add_theme_stylebox_override("panel", dialog_style)
	frame_margin.add_child(_large_map_dialog)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 18)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 18)
	content_margin.add_theme_constant_override("margin_bottom", 18)
	_large_map_dialog.add_child(content_margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Map"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(title)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	close_button.add_theme_stylebox_override("normal", _large_map_close_button_style(Color(0.18, 0.13, 0.09, 0.84), Color(0.88, 0.76, 0.56, 0.72)))
	close_button.add_theme_stylebox_override("hover", _large_map_close_button_style(Color(0.28, 0.20, 0.13, 0.90), Color(0.98, 0.86, 0.64, 0.88)))
	close_button.add_theme_stylebox_override("pressed", _large_map_close_button_style(Color(0.12, 0.09, 0.07, 0.92), Color(0.72, 0.58, 0.40, 0.90)))
	close_button.add_theme_stylebox_override("focus", _large_map_close_button_style(Color(0.28, 0.20, 0.13, 0.90), Color(0.98, 0.86, 0.64, 0.88)))
	close_button.custom_minimum_size = Vector2(40.0, 40.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_large_map)
	top_row.add_child(close_button)

	_large_map_view = LabyrinthMapViewScript.new()
	_large_map_view.name = "LargeMap"
	_large_map_view.set("interactive", true)
	_large_map_view.set("show_legend", true)
	_large_map_view.set("draw_background", false)
	_large_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_large_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_large_map_view.custom_minimum_size = Vector2(720.0, 460.0)
	_large_map_view.connect("room_selected", _on_large_map_room_selected)
	vbox.add_child(_large_map_view)

func _large_map_close_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	return style

func _build_context_choice_overlay() -> void:
	var stage_root: Control = board_view.get_parent()
	if stage_root == null:
		return
	_context_choice_overlay = PanelContainer.new()
	_context_choice_overlay.name = "ContextChoiceOverlay"
	_context_choice_overlay.visible = false
	_context_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.10, 0.065, 0.045, 0.88)
	overlay_style.border_color = Color(0.88, 0.63, 0.32, 0.72)
	overlay_style.border_width_left = 2
	overlay_style.border_width_top = 2
	overlay_style.border_width_right = 2
	overlay_style.border_width_bottom = 2
	overlay_style.corner_radius_top_left = 8
	overlay_style.corner_radius_top_right = 8
	overlay_style.corner_radius_bottom_right = 8
	overlay_style.corner_radius_bottom_left = 8
	overlay_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	overlay_style.shadow_size = 12
	overlay_style.content_margin_left = 12
	overlay_style.content_margin_top = 10
	overlay_style.content_margin_right = 12
	overlay_style.content_margin_bottom = 10
	_context_choice_overlay.add_theme_stylebox_override("panel", overlay_style)
	stage_root.add_child(_context_choice_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_context_choice_overlay.add_child(margin)

	_context_choice_bar = HBoxContainer.new()
	_context_choice_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_context_choice_bar.add_theme_constant_override("separation", 16)
	margin.add_child(_context_choice_bar)
	_layout_context_choice_overlay()
	_build_relic_choice_overlay(stage_root)
	_build_terminal_overlay(stage_root)

func _layout_context_choice_overlay() -> void:
	if _context_choice_overlay == null:
		return
	var stage_root: Control = board_view.get_parent()
	var stage_size: Vector2 = stage_root.size if stage_root != null else get_viewport_rect().size
	var width: float = clampf(stage_size.x * 0.52, 360.0, CAMPFIRE_ACTION_OVERLAY_SIZE.x)
	var height: float = CAMPFIRE_ACTION_OVERLAY_SIZE.y
	_context_choice_overlay.anchor_left = 0.5
	_context_choice_overlay.anchor_top = 1.0
	_context_choice_overlay.anchor_right = 0.5
	_context_choice_overlay.anchor_bottom = 1.0
	_context_choice_overlay.offset_left = -width * 0.5
	_context_choice_overlay.offset_right = width * 0.5
	_context_choice_overlay.offset_top = -height - 24.0
	_context_choice_overlay.offset_bottom = -24.0
	_layout_relic_choice_overlay()

func _build_relic_choice_overlay(stage_root: Control) -> void:
	_relic_choice_overlay = Control.new()
	_relic_choice_overlay.name = "RelicChoiceOverlay"
	_relic_choice_overlay.visible = false
	_relic_choice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_overlay.z_index = 70
	stage_root.add_child(_relic_choice_overlay)

	_relic_choice_title = Label.new()
	_relic_choice_title.name = "TreasureTitle"
	_relic_choice_title.visible = false
	_relic_choice_title.text = ""
	_relic_choice_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_choice_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_relic_choice_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	UiTypography.set_label_size(_relic_choice_title, RELIC_CHOICE_TITLE_FONT_SIZE)
	_relic_choice_title.add_theme_color_override("font_color", Color("ffe4a5"))
	_relic_choice_title.add_theme_color_override("font_outline_color", Color("26160e"))
	_relic_choice_title.add_theme_constant_override("outline_size", 8)
	_relic_choice_overlay.add_child(_relic_choice_title)

	_relic_choice_host = CenterContainer.new()
	_relic_choice_host.name = "RelicChoiceHost"
	_relic_choice_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_overlay.add_child(_relic_choice_host)

	_relic_choice_bar = HBoxContainer.new()
	_relic_choice_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_choice_bar.add_theme_constant_override("separation", 28)
	_relic_choice_host.add_child(_relic_choice_bar)
	_layout_relic_choice_overlay()

func _layout_relic_choice_overlay() -> void:
	if _relic_choice_overlay == null:
		return
	var stage_root: Control = board_view.get_parent()
	var stage_size: Vector2 = stage_root.size if stage_root != null else get_viewport_rect().size
	_relic_choice_overlay.anchor_left = 0.0
	_relic_choice_overlay.anchor_top = 0.0
	_relic_choice_overlay.anchor_right = 1.0
	_relic_choice_overlay.anchor_bottom = 1.0
	_relic_choice_overlay.offset_left = 0.0
	_relic_choice_overlay.offset_top = 0.0
	_relic_choice_overlay.offset_right = 0.0
	_relic_choice_overlay.offset_bottom = 0.0
	if _relic_choice_title != null:
		var title_height: float = clampf(stage_size.y * 0.20, 116.0, RELIC_CHOICE_TITLE_HEIGHT)
		var title_top: float = maxf(10.0, stage_size.y * RELIC_CHOICE_TITLE_TOP_RATIO)
		_relic_choice_title.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_relic_choice_title.position = Vector2(0.0, title_top)
		_relic_choice_title.size = Vector2(stage_size.x, title_height)
	if _relic_choice_host != null:
		var max_width: float = minf(RELIC_CHOICE_OVERLAY_SIZE.x, maxf(360.0, stage_size.x - 24.0))
		var min_width: float = minf(640.0, max_width)
		var width: float = clampf(stage_size.x * 0.90, min_width, max_width)
		var height: float = RELIC_CHOICE_OVERLAY_SIZE.y
		var left: float = (stage_size.x - width) * 0.5
		var top: float = stage_size.y - height - RELIC_CHOICE_BOTTOM_MARGIN
		_relic_choice_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_relic_choice_host.position = Vector2(left, top)
		_relic_choice_host.size = Vector2(width, height)

func _build_terminal_overlay(stage_root: Control) -> void:
	_terminal_overlay = Control.new()
	_terminal_overlay.name = "TerminalOverlay"
	_terminal_overlay.visible = false
	_terminal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terminal_overlay.z_index = 88
	stage_root.add_child(_terminal_overlay)

	_terminal_panel = PanelContainer.new()
	_terminal_panel.name = "TerminalPanel"
	_terminal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_terminal_panel.add_theme_stylebox_override("panel", _terminal_panel_style())
	_terminal_overlay.add_child(_terminal_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terminal_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_terminal_title_label = Label.new()
	_terminal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_terminal_title_label, UiTypography.SIZE_HERO)
	_terminal_title_label.add_theme_color_override("font_color", Color("ffe4a5"))
	_terminal_title_label.add_theme_color_override("font_outline_color", Color("24150d"))
	_terminal_title_label.add_theme_constant_override("outline_size", 5)
	vbox.add_child(_terminal_title_label)

	_terminal_status_label = Label.new()
	_terminal_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_terminal_status_label, UiTypography.SIZE_SECTION)
	_terminal_status_label.add_theme_color_override("font_color", Color("f7ecd3"))
	_terminal_status_label.add_theme_color_override("font_outline_color", Color("21150e"))
	_terminal_status_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_terminal_status_label)

	_terminal_reward_label = Label.new()
	_terminal_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_terminal_reward_label, UiTypography.SIZE_BODY_LARGE)
	_terminal_reward_label.add_theme_color_override("font_color", Color("f0c56f"))
	_terminal_reward_label.add_theme_color_override("font_outline_color", Color("2a1a0e"))
	_terminal_reward_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_terminal_reward_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	vbox.add_child(spacer)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 18)
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(button_row)

	button_row.add_child(_terminal_button("Again", _on_restart_pressed))
	button_row.add_child(_terminal_button("Menu", _on_back_to_menu_pressed))
	_layout_terminal_overlay()

func _terminal_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_LARGE, 210.0)
	button.pressed.connect(callback)
	return button

func _terminal_panel_style() -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style(Color(0.10, 0.065, 0.045, 0.96), Color("c08a4a"), 20.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 18
	return style

func _layout_terminal_overlay() -> void:
	if _terminal_overlay == null:
		return
	var stage_root: Control = board_view.get_parent()
	var stage_size: Vector2 = stage_root.size if stage_root != null else get_viewport_rect().size
	_terminal_overlay.anchor_left = 0.0
	_terminal_overlay.anchor_top = 0.0
	_terminal_overlay.anchor_right = 1.0
	_terminal_overlay.anchor_bottom = 1.0
	_terminal_overlay.offset_left = 0.0
	_terminal_overlay.offset_top = 0.0
	_terminal_overlay.offset_right = 0.0
	_terminal_overlay.offset_bottom = 0.0
	if _terminal_panel == null:
		return
	var width: float = clampf(stage_size.x * 0.46, 420.0, TERMINAL_OVERLAY_SIZE.x)
	var height: float = TERMINAL_OVERLAY_SIZE.y
	var left: float = (stage_size.x - width) * 0.5
	var top: float = (stage_size.y - height) * 0.5
	_terminal_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_terminal_panel.position = Vector2(left, top)
	_terminal_panel.size = Vector2(width, height)

func _build_card_fx_layer() -> void:
	_card_fx_layer = Control.new()
	_card_fx_layer.name = "CardFxLayer"
	_card_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_card_fx_layer.anchor_right = 1.0
	_card_fx_layer.anchor_bottom = 1.0
	add_child(_card_fx_layer)

func _build_equipment_fx_layer() -> void:
	_equipment_fx_layer = Control.new()
	_equipment_fx_layer.name = "EquipmentFxLayer"
	_equipment_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_equipment_fx_layer.anchor_right = 1.0
	_equipment_fx_layer.anchor_bottom = 1.0
	_equipment_fx_layer.z_index = 1300
	_equipment_fx_layer.z_as_relative = false
	add_child(_equipment_fx_layer)

func _build_fatigue_edge_overlay() -> void:
	_fatigue_edge_overlay = FatigueEdgeOverlay.new()
	_fatigue_edge_overlay.name = "FatigueEdgeOverlay"
	_fatigue_edge_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fatigue_edge_overlay.anchor_right = 1.0
	_fatigue_edge_overlay.anchor_bottom = 1.0
	_fatigue_edge_overlay.z_index = 210
	_fatigue_edge_overlay.z_as_relative = false
	add_child(_fatigue_edge_overlay)

func _build_death_overlay() -> void:
	_death_overlay = DeathEngulfOverlay.new()
	_death_overlay.name = "DeathEngulfOverlay"
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.anchor_right = 1.0
	_death_overlay.anchor_bottom = 1.0
	_death_overlay.continue_pressed.connect(_on_death_continue_pressed)
	add_child(_death_overlay)

func _build_menu_overlay() -> void:
	_menu_scrim = ColorRect.new()
	_menu_scrim.name = "MenuScrim"
	_menu_scrim.visible = false
	_menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_scrim.color = Color(0.02, 0.02, 0.02, 0.56)
	_menu_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_menu_scrim.anchor_right = 1.0
	_menu_scrim.anchor_bottom = 1.0
	add_child(_menu_scrim)

	_menu_dialog = PanelContainer.new()
	_menu_dialog.name = "MenuDialog"
	_menu_dialog.custom_minimum_size = Vector2(360.0, 0.0)
	_menu_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.11, 0.08, 0.06, 0.96), Color("9d7a50"), 18.0)
	dialog_style.corner_radius_top_left = 14
	dialog_style.corner_radius_top_right = 14
	dialog_style.corner_radius_bottom_right = 14
	dialog_style.corner_radius_bottom_left = 14
	dialog_style.shadow_size = 12
	_menu_dialog.add_theme_stylebox_override("panel", dialog_style)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_menu_scrim.add_child(center)
	center.add_child(_menu_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_menu_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Camp"
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose your next step."
	UiTypography.set_label_size(subtitle, UiTypography.SIZE_SMALL)
	subtitle.add_theme_color_override("font_color", Color("cdbca2"))
	vbox.add_child(subtitle)

	for entry: Dictionary in [
		{"text": "Character", "callback": Callable(self, "_on_character_stats_pressed")},
		{"text": "Exit to Desktop", "callback": Callable(self, "_on_exit_to_desktop_pressed")},
		{"text": "Save and Quit", "callback": Callable(self, "_on_save_and_quit_pressed")},
		{"text": "Succumb to the Darkness", "callback": Callable(self, "_on_abandon_run_pressed")},
		{"text": "Close", "callback": Callable(self, "_close_menu_overlay")}
	]:
		var button := Button.new()
		button.text = str(entry.get("text", ""))
		_ui_skin.apply_button_stylebox_overrides(button)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
		_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_STANDARD, MENU_DIALOG_BUTTON_MIN_WIDTH)
		button.pressed.connect(entry.get("callback", Callable()))
		vbox.add_child(button)

func _build_dialogue_overlay() -> void:
	_dialogue_overlay = Control.new()
	_dialogue_overlay.name = "DialogueOverlay"
	_dialogue_overlay.visible = false
	_dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_dialogue_overlay.anchor_right = 1.0
	_dialogue_overlay.anchor_bottom = 1.0
	_dialogue_overlay.gui_input.connect(_on_dialogue_overlay_gui_input)
	add_child(_dialogue_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.01, 0.01, 0.18)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.anchors_preset = Control.PRESET_FULL_RECT
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	_dialogue_overlay.add_child(scrim)

	var anchor := MarginContainer.new()
	anchor.anchors_preset = Control.PRESET_FULL_RECT
	anchor.anchor_right = 1.0
	anchor.anchor_bottom = 1.0
	anchor.add_theme_constant_override("margin_left", 18)
	anchor.add_theme_constant_override("margin_top", 18)
	anchor.add_theme_constant_override("margin_right", 18)
	anchor.add_theme_constant_override("margin_bottom", 18)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_overlay.add_child(anchor)

	var bottom := VBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(bottom)

	_dialogue_dialog = PanelContainer.new()
	_dialogue_dialog.custom_minimum_size = Vector2(DIALOGUE_DIALOG_WIDTH, DIALOGUE_DIALOG_HINT_MIN_HEIGHT)
	_dialogue_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dialogue_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dialogue_style := _ui_skin.make_plain_card_style(Color(0.10, 0.07, 0.05, 0.96), Color("b8aa90"), 18.0)
	dialogue_style.corner_radius_top_left = 14
	dialogue_style.corner_radius_top_right = 14
	dialogue_style.corner_radius_bottom_right = 14
	dialogue_style.corner_radius_bottom_left = 14
	dialogue_style.shadow_size = 10
	_dialogue_dialog.add_theme_stylebox_override("panel", dialogue_style)
	bottom.add_child(_dialogue_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_dialogue_name_label = Label.new()
	UiTypography.set_label_size(_dialogue_name_label, UiTypography.SIZE_BODY)
	_dialogue_name_label.add_theme_color_override("font_color", Color("f0c978"))
	_dialogue_name_label.add_theme_color_override("font_outline_color", Color("2d1f18"))
	_dialogue_name_label.add_theme_constant_override("outline_size", 1)
	_dialogue_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_name_label)

	_dialogue_text_label = RichTextLabel.new()
	_dialogue_text_label.bbcode_enabled = true
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text_label.visible_characters = 0
	_dialogue_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text_label.size_flags_vertical = Control.SIZE_FILL
	_dialogue_text_label.custom_minimum_size = Vector2(0.0, DIALOGUE_TEXT_HINT_MIN_HEIGHT)
	_dialogue_text_label.fit_content = true
	_dialogue_text_label.scroll_active = false
	UiTypography.set_rich_text_size(_dialogue_text_label, UiTypography.SIZE_SECTION)
	_dialogue_text_label.add_theme_color_override("default_color", Color("f5ebd8"))
	_dialogue_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_text_label)

	_dialogue_footer = HBoxContainer.new()
	_dialogue_footer.custom_minimum_size = Vector2(0.0, DIALOGUE_HINT_FOOTER_HEIGHT)
	_dialogue_footer.add_theme_constant_override("separation", 12)
	_dialogue_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_footer)

	_dialogue_hint_label = Label.new()
	_dialogue_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_dialogue_hint_label, UiTypography.SIZE_BODY)
	_dialogue_hint_label.add_theme_color_override("font_color", Color("cab697"))
	_dialogue_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_footer.add_child(_dialogue_hint_label)

	_dialogue_choice_bar = HBoxContainer.new()
	_dialogue_choice_bar.custom_minimum_size = Vector2.ZERO
	_dialogue_choice_bar.alignment = BoxContainer.ALIGNMENT_END
	_dialogue_choice_bar.add_theme_constant_override("separation", 10)
	_dialogue_choice_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_choice_bar.visible = false
	_dialogue_footer.add_child(_dialogue_choice_bar)

func _build_pile_overlay() -> void:
	_pile_scrim = ColorRect.new()
	_pile_scrim.name = "PileScrim"
	_pile_scrim.visible = false
	_pile_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pile_scrim.z_index = 1000
	_pile_scrim.z_as_relative = false
	_pile_scrim.color = Color(0.02, 0.02, 0.02, 0.58)
	_pile_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_pile_scrim.anchor_right = 1.0
	_pile_scrim.anchor_bottom = 1.0
	add_child(_pile_scrim)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_pile_scrim.add_child(center)

	_pile_dialog = PanelContainer.new()
	_pile_dialog.custom_minimum_size = PILE_DIALOG_FULL_SIZE
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.11, 0.08, 0.06, 0.98), Color("9d7a50"), 16.0)
	dialog_style.corner_radius_top_left = 14
	dialog_style.corner_radius_top_right = 14
	dialog_style.corner_radius_bottom_right = 14
	dialog_style.corner_radius_bottom_left = 14
	dialog_style.shadow_size = 12
	_pile_dialog.add_theme_stylebox_override("panel", dialog_style)
	center.add_child(_pile_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_pile_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	_pile_dialog_title = Label.new()
	_pile_dialog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(_pile_dialog_title, UiTypography.SIZE_SECTION)
	_pile_dialog_title.add_theme_color_override("font_color", Color("f0e6d2"))
	_pile_dialog_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	_pile_dialog_title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(_pile_dialog_title)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	close_button.add_theme_stylebox_override("normal", _large_map_close_button_style(Color(0.18, 0.13, 0.09, 0.84), Color(0.88, 0.76, 0.56, 0.72)))
	close_button.add_theme_stylebox_override("hover", _large_map_close_button_style(Color(0.28, 0.20, 0.13, 0.90), Color(0.98, 0.86, 0.64, 0.88)))
	close_button.add_theme_stylebox_override("pressed", _large_map_close_button_style(Color(0.12, 0.09, 0.07, 0.92), Color(0.72, 0.58, 0.40, 0.90)))
	close_button.add_theme_stylebox_override("focus", _large_map_close_button_style(Color(0.28, 0.20, 0.13, 0.90), Color(0.98, 0.86, 0.64, 0.88)))
	close_button.custom_minimum_size = Vector2(40.0, 40.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_pile_view)
	top_row.add_child(close_button)

	_pile_dialog_scroll = ScrollContainer.new()
	_pile_dialog_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_pile_dialog_scroll)

	_pile_dialog_cards = HFlowContainer.new()
	_pile_dialog_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	_pile_dialog_cards.add_theme_constant_override("h_separation", 12)
	_pile_dialog_cards.add_theme_constant_override("v_separation", 12)
	_pile_dialog_scroll.add_child(_pile_dialog_cards)

	_pile_dialog_empty = Label.new()
	_pile_dialog_empty.text = "No cards in this pile."
	_pile_dialog_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pile_dialog_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pile_dialog_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_empty.custom_minimum_size = Vector2(0.0, 96.0)
	UiTypography.set_label_size(_pile_dialog_empty, UiTypography.SIZE_BODY)
	_pile_dialog_empty.add_theme_color_override("font_color", Color("d2c2a7"))
	_pile_dialog_empty.add_theme_color_override("font_outline_color", Color("2c1f16"))
	_pile_dialog_empty.add_theme_constant_override("outline_size", 1)
	_pile_dialog_empty.visible = false
	vbox.add_child(_pile_dialog_empty)

func _build_card_upgrade_overlay() -> void:
	_upgrade_scrim = ColorRect.new()
	_upgrade_scrim.name = "CardUpgradeScrim"
	_upgrade_scrim.visible = false
	_upgrade_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_scrim.z_index = 1200
	_upgrade_scrim.z_as_relative = false
	_upgrade_scrim.color = Color(0.02, 0.02, 0.02, 0.64)
	_upgrade_scrim.anchors_preset = Control.PRESET_FULL_RECT
	_upgrade_scrim.anchor_right = 1.0
	_upgrade_scrim.anchor_bottom = 1.0
	add_child(_upgrade_scrim)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_upgrade_scrim.add_child(center)

	_upgrade_dialog = PanelContainer.new()
	_upgrade_dialog.custom_minimum_size = Vector2(1120.0, 620.0)
	var dialog_style := _ui_skin.make_plain_card_style(Color(0.10, 0.07, 0.05, 0.98), Color("c28a53"), 16.0)
	dialog_style.corner_radius_top_left = 14
	dialog_style.corner_radius_top_right = 14
	dialog_style.corner_radius_bottom_right = 14
	dialog_style.corner_radius_bottom_left = 14
	dialog_style.shadow_size = 12
	_upgrade_dialog.add_theme_stylebox_override("panel", dialog_style)
	center.add_child(_upgrade_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_upgrade_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Bound Magicks"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(title)

	_upgrade_embers_label = Label.new()
	UiTypography.set_label_size(_upgrade_embers_label, UiTypography.SIZE_SMALL)
	_upgrade_embers_label.add_theme_color_override("font_color", Color("f0c978"))
	_upgrade_embers_label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	_upgrade_embers_label.add_theme_constant_override("outline_size", 1)
	top_row.add_child(_upgrade_embers_label)

	var close_button := Button.new()
	close_button.text = "X"
	_ui_skin.apply_button_stylebox_overrides(close_button)
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(close_button, 36.0)
	close_button.pressed.connect(_close_card_upgrade_overlay)
	top_row.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	vbox.add_child(body)

	_upgrade_card_list = _build_upgrade_column(body, "Cards", 220.0)
	_upgrade_element_list = _build_upgrade_column(body, "Parts", 220.0)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)

	var preview_title := Label.new()
	preview_title.text = "Preview"
	UiTypography.set_label_size(preview_title, UiTypography.SIZE_SMALL)
	preview_title.add_theme_color_override("font_color", Color("f0e6d2"))
	preview_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	preview_title.add_theme_constant_override("outline_size", 1)
	right_column.add_child(preview_title)

	_upgrade_preview_box = HBoxContainer.new()
	_upgrade_preview_box.custom_minimum_size = Vector2(0.0, 286.0)
	_upgrade_preview_box.add_theme_constant_override("separation", 12)
	right_column.add_child(_upgrade_preview_box)

	var option_title := Label.new()
	option_title.text = "Options"
	UiTypography.set_label_size(option_title, UiTypography.SIZE_SMALL)
	option_title.add_theme_color_override("font_color", Color("f0e6d2"))
	option_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	option_title.add_theme_constant_override("outline_size", 1)
	right_column.add_child(option_title)

	var option_scroll := ScrollContainer.new()
	option_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(option_scroll)

	_upgrade_option_list = VBoxContainer.new()
	_upgrade_option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_option_list.add_theme_constant_override("separation", 10)
	option_scroll.add_child(_upgrade_option_list)

func _build_upgrade_column(parent: Node, title_text: String, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)

	var title := Label.new()
	title.text = title_text
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 1)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list

func _build_drag_overlay() -> void:
	_drag_overlay = Control.new()
	_drag_overlay.name = "DragOverlay"
	_drag_overlay.visible = false
	_drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_drag_overlay.anchor_right = 1.0
	_drag_overlay.anchor_bottom = 1.0
	add_child(_drag_overlay)

	var tint := ColorRect.new()
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0.02, 0.02, 0.02, 0.22)
	tint.anchors_preset = Control.PRESET_FULL_RECT
	tint.anchor_right = 1.0
	tint.anchor_bottom = 1.0
	_drag_overlay.add_child(tint)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_drag_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.custom_minimum_size = Vector2(560.0, 240.0)
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	_drag_zone_panels.clear()
	_drag_zone_labels.clear()
	_drag_zone_panels["play"] = _build_drag_zone("Play", UiTypography.SIZE_SECTION, Vector2(560.0, 118.0), Color("c5a26a"), Color("2f241c"))
	vbox.add_child(_drag_zone_panels["play"])
	_drag_zone_labels["play"] = _drag_zone_panels["play"].get_meta("label")

	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_theme_constant_override("separation", 14)
	vbox.add_child(bottom_row)

	_drag_zone_panels["attack"] = _build_drag_zone(_fallback_label("attack"), UiTypography.SIZE_SMALL, Vector2(273.0, 96.0), Color("cf7657"), Color("2f1d18"))
	bottom_row.add_child(_drag_zone_panels["attack"])
	_drag_zone_labels["attack"] = _drag_zone_panels["attack"].get_meta("label")

	_drag_zone_panels["move"] = _build_drag_zone(_fallback_label("move"), UiTypography.SIZE_SMALL, Vector2(273.0, 96.0), Color("5b8ea2"), Color("18262f"))
	bottom_row.add_child(_drag_zone_panels["move"])
	_drag_zone_labels["move"] = _drag_zone_panels["move"].get_meta("label")

func _build_drag_zone(text: String, font_size: int, minimum_size: Vector2, accent: Color, fill: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = minimum_size
	panel.set_meta("accent", accent)
	panel.set_meta("fill", fill)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", Color("f4ead5"))
	label.add_theme_color_override("font_outline_color", Color("241912"))
	label.add_theme_constant_override("outline_size", 2)
	center.add_child(label)
	panel.set_meta("label", label)
	panel.add_theme_stylebox_override("panel", _drag_zone_style(fill, accent, false, true))
	return panel

func _on_dialogue_overlay_gui_input(event: InputEvent) -> void:
	if not _dialogue_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _has_current_dialogue_options() and _dialogue_choice_bar != null and _dialogue_choice_bar.get_global_rect().has_point(get_global_mouse_position()):
			return
		accept_event()
		_advance_dialogue()

func _start_dialogue(dialogue: Dictionary) -> void:
	if dialogue.is_empty():
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_menu_overlay()
	_close_card_upgrade_overlay()
	_dialogue_script = dialogue.duplicate(true)
	_dialogue_active = true
	_dialogue_overlay.visible = true
	_show_dialogue_line(0)

func _show_dialogue_line(index: int) -> void:
	var lines: Array = _dialogue_script.get("lines", [])
	if index < 0 or index >= lines.size():
		_close_dialogue()
		return
	_dialogue_line_index = index
	_dialogue_char_progress = 0.0
	_dialogue_text_complete = false
	var line: Dictionary = lines[index]
	var speaker: String = str(line.get("speaker", _dialogue_script.get("speaker", "")))
	var accent_text: String = str(line.get("accent", _dialogue_script.get("accent", "#b8aa90")))
	_apply_dialogue_accent(accent_text)
	_dialogue_name_label.text = speaker
	_dialogue_text_label.text = _dialogue_line_markup(line)
	_sync_dialogue_layout()
	var visible_text_length: int = _dialogue_visible_text().length()
	if visible_text_length > 0:
		_dialogue_char_progress = 1.0
		_dialogue_text_label.visible_characters = 1
	else:
		_dialogue_text_label.visible_characters = 0
	_update_dialogue_footer()
	if _dialogue_visible_text().is_empty():
		_complete_current_dialogue_line()

func _complete_current_dialogue_line() -> void:
	if not _dialogue_active:
		return
	_dialogue_text_complete = true
	_dialogue_char_progress = float(_dialogue_visible_text().length())
	_dialogue_text_label.visible_characters = -1
	_update_dialogue_footer()

func _advance_dialogue() -> void:
	if not _dialogue_active:
		return
	if not _dialogue_text_complete:
		_complete_current_dialogue_line()
		return
	if _has_current_dialogue_options():
		return
	var lines: Array = _dialogue_script.get("lines", [])
	var next_index: int = _dialogue_line_index + 1
	if next_index >= lines.size():
		_close_dialogue()
		return
	_show_dialogue_line(next_index)

func _on_dialogue_option_pressed(option: Dictionary) -> void:
	if not _dialogue_active or not _dialogue_text_complete:
		return
	var action: String = str(option.get("action", ""))
	if action == "open_card_upgrades":
		_close_dialogue()
		_open_card_upgrade_overlay()
		return
	if action == "close":
		_close_dialogue()
		return
	var next_index: int = int(option.get("next", -1))
	if next_index >= 0:
		_show_dialogue_line(next_index)
		return
	_close_dialogue()

func _close_dialogue() -> void:
	_maybe_mark_fire_rest_dialogue_seen()
	_dialogue_active = false
	_dialogue_script.clear()
	_dialogue_line_index = -1
	_dialogue_char_progress = 0.0
	_dialogue_text_complete = false
	_clear_dialogue_choices()
	if _dialogue_hint_label != null:
		_dialogue_hint_label.text = ""
	if _dialogue_overlay != null:
		_dialogue_overlay.visible = false

func _maybe_mark_fire_rest_dialogue_seen() -> void:
	if _dialogue_script.is_empty() or not bool(_dialogue_script.get("marks_fire_rest_seen", false)):
		return
	_progression = ProgressionStore.mark_fire_rest_dialogue_seen(_progression)
	ProgressionStore.save_data(_progression)
	if not _run_state.is_empty():
		_run_state["progression"] = _progression.duplicate(true)

func _current_dialogue_line() -> Dictionary:
	if not _dialogue_active or _dialogue_line_index < 0:
		return {}
	var lines: Array = _dialogue_script.get("lines", [])
	if _dialogue_line_index >= lines.size():
		return {}
	return lines[_dialogue_line_index]

func _dialogue_line_markup(line: Dictionary) -> String:
	return str(line.get("bbcode", line.get("text", "")))

func _dialogue_visible_text() -> String:
	if _dialogue_text_label == null:
		return ""
	return _dialogue_text_label.get_parsed_text()

func _has_current_dialogue_options() -> bool:
	return (_current_dialogue_line().get("options", []) as Array).size() > 0 and _dialogue_text_complete

func _sync_dialogue_layout() -> void:
	if _dialogue_dialog == null or _dialogue_text_label == null or _dialogue_footer == null:
		return
	var options: Array = _current_dialogue_line().get("options", [])
	var has_options: bool = not options.is_empty()
	var dialog_height: float = DIALOGUE_DIALOG_OPTION_MIN_HEIGHT if has_options else DIALOGUE_DIALOG_HINT_MIN_HEIGHT
	var text_height: float = DIALOGUE_TEXT_OPTION_MIN_HEIGHT if has_options else DIALOGUE_TEXT_HINT_MIN_HEIGHT
	var footer_height: float = DIALOGUE_OPTION_BUTTON_HEIGHT if has_options else DIALOGUE_HINT_FOOTER_HEIGHT
	_dialogue_dialog.custom_minimum_size = Vector2(DIALOGUE_DIALOG_WIDTH, dialog_height)
	_dialogue_text_label.custom_minimum_size = Vector2(0.0, text_height)
	_dialogue_footer.custom_minimum_size = Vector2(0.0, footer_height)
	if _dialogue_choice_bar != null:
		_dialogue_choice_bar.custom_minimum_size = Vector2(0.0, DIALOGUE_OPTION_BUTTON_HEIGHT if has_options else 0.0)
		_dialogue_choice_bar.visible = has_options

func _update_dialogue_footer() -> void:
	_clear_dialogue_choices()
	if _dialogue_hint_label == null:
		return
	_dialogue_hint_label.text = ""
	if not _dialogue_active:
		return
	if not _dialogue_text_complete:
		_dialogue_hint_label.text = "Click to reveal"
		return
	var options: Array = _current_dialogue_line().get("options", [])
	if options.is_empty():
		_dialogue_hint_label.text = _dialogue_hint_text()
		return
	for option_var: Variant in options:
		if typeof(option_var) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = (option_var as Dictionary).duplicate(true)
		var button := Button.new()
		button.text = str(option.get("label", "Continue"))
		_ui_skin.apply_button_stylebox_overrides(button)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.set_button_size(button, UiTypography.SIZE_BODY_LARGE)
		_ui_skin.apply_button_native_size(button, DIALOGUE_OPTION_BUTTON_HEIGHT, DIALOGUE_OPTION_BUTTON_MIN_WIDTH)
		button.pressed.connect(_on_dialogue_option_pressed.bind(option))
		_dialogue_choice_bar.add_child(button)

func _dialogue_hint_text() -> String:
	var lines: Array = _dialogue_script.get("lines", [])
	if _dialogue_line_index >= 0 and _dialogue_line_index < lines.size() - 1:
		return "Click to continue"
	return "Click to leave"

func _clear_dialogue_choices() -> void:
	if _dialogue_choice_bar == null:
		return
	_clear_children(_dialogue_choice_bar)

func _apply_dialogue_accent(accent_text: String) -> void:
	var accent: Color = Color(accent_text)
	if _dialogue_name_label != null:
		_dialogue_name_label.add_theme_color_override("font_color", accent.lightened(0.08))
	if _dialogue_dialog == null:
		return
	var dialogue_style := _ui_skin.make_plain_card_style(Color(0.10, 0.07, 0.05, 0.96), accent, 18.0)
	dialogue_style.corner_radius_top_left = 14
	dialogue_style.corner_radius_top_right = 14
	dialogue_style.corner_radius_bottom_right = 14
	dialogue_style.corner_radius_bottom_left = 14
	dialogue_style.shadow_size = 10
	_dialogue_dialog.add_theme_stylebox_override("panel", dialogue_style)

func _show_drag_overlay() -> void:
	if _drag_overlay == null:
		return
	_close_pile_view()
	_drag_overlay.visible = true

func _cancel_drag_play() -> void:
	if _drag_overlay != null:
		_drag_overlay.visible = false
	if _drag_card_proxy != null:
		_queue_free_node_now(_drag_card_proxy)
		_drag_card_proxy = null
	_drag_card_index = -1
	_drag_card_options.clear()
	_drag_hover_zone = ""
	_drag_card_source_rect = Rect2()
	_drag_card_grab_offset = Vector2.ZERO
	_update_drag_overlay_hover("")
	_refresh_hand_panel()

func _animate_drag_cancel_to_source() -> void:
	if _drag_card_proxy != null and _drag_card_source_rect.size.length() > 0.0:
		await _animate_card_proxy_to_rect(_drag_card_proxy, _drag_card_source_rect, CARD_SNAPBACK_SECONDS)
	_cancel_drag_play()

func _commit_drag_drop(zone: String) -> void:
	if _drag_card_index < 0:
		return
	var hand_index: int = _drag_card_index
	var options: Dictionary = _drag_card_options.duplicate(true)
	var preview: Dictionary = {}
	var label_override: String = ""
	match zone:
		"play":
			preview = options.get("play", {})
		"attack":
			preview = options.get("attack", {})
			label_override = _fallback_label("attack")
		"move":
			preview = options.get("move", {})
			label_override = _fallback_label("move")
		_:
			await _animate_drag_cancel_to_source()
			return
	if _drag_card_proxy != null:
		var zone_rect: Rect2 = _drag_zone_panels.get(zone, null).get_global_rect()
		await _animate_card_proxy_to_rect(_drag_card_proxy, _rect_from_center(zone_rect.get_center(), _drag_card_source_rect.size), 0.10)
	_cancel_drag_play()
	await _begin_card_preview(hand_index, preview, label_override)

func _drag_zone_at(mouse_position: Vector2) -> String:
	for zone: String in ["play", "attack", "move"]:
		var panel: PanelContainer = _drag_zone_panels.get(zone, null)
		if panel == null or not panel.visible:
			continue
		if panel.get_global_rect().has_point(mouse_position):
			return zone
	return ""

func _current_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()

func _mouse_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		return mouse_button.position
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event
		return mouse_motion.position
	return _current_mouse_position()

func _update_drag_proxy_position(mouse_position: Vector2) -> void:
	if _drag_card_proxy == null:
		return
	_drag_card_proxy.position = mouse_position - _drag_card_grab_offset

func _spawn_card_proxy(card_id: String, rect: Rect2) -> Control:
	var proxy := Control.new()
	proxy.name = "CardProxy"
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.top_level = true
	proxy.position = rect.position
	proxy.custom_minimum_size = CARD_WIDGET_BASE_SIZE
	proxy.size = CARD_WIDGET_BASE_SIZE
	proxy.scale = Vector2.ONE * _card_widget_scale_for_size(_normalized_card_size(rect.size))
	proxy.set_meta("scaled_card_proxy", true)
	var widget = CardWidgetScene.instantiate()
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prepare_native_card_widget(widget)
	proxy.add_child(widget)
	widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	widget.configure(card_id, false, false, true, false, false, true, _card_def(card_id, _combat_state))
	var display: Dictionary = _card_widget_display(card_id, _combat_state)
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	return proxy

func _animate_card_proxy_to_rect(proxy: Control, target_rect: Rect2, duration: float) -> void:
	if proxy == null:
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "position", target_rect.position, duration)
	if bool(proxy.get_meta("scaled_card_proxy", false)):
		tween.parallel().tween_property(proxy, "scale", Vector2.ONE * _card_widget_scale_for_size(_normalized_card_size(target_rect.size)), duration)
	else:
		tween.parallel().tween_property(proxy, "size", _normalized_card_size(target_rect.size), duration)
	await tween.finished

func _hand_card_global_rect(index: int) -> Rect2:
	var control: Control = _hand_card_control(index)
	if control == null:
		return Rect2()
	return Rect2(control.global_position, control.size)

func _hand_card_control(index: int) -> Control:
	if index < 0 or index >= hand_box.get_child_count():
		return null
	var slot: Control = hand_box.get_child(index) as Control
	if slot == null:
		return null
	if slot.get_child_count() > 0 and slot.get_child(0) is Control:
		return slot.get_child(0) as Control
	return slot

func _pile_global_rect(kind: String) -> Rect2:
	var source: Control = null
	match kind:
		"draw":
			source = draw_pile
		"discard":
			source = discard_pile
		"burn":
			source = burn_pile
	if source == null:
		return Rect2()
	return Rect2(source.global_position, source.size)

func _rect_from_center(center: Vector2, rect_size: Vector2) -> Rect2:
	return Rect2(center - rect_size * 0.5, rect_size)

func _hand_receive_rect(index: int, total: int, size_hint: Vector2) -> Rect2:
	var hand_rect := Rect2(hand_scroll.global_position, hand_scroll.size)
	var content_size: Vector2 = HandFanContainer.content_size_for_layout(total, size_hint, HAND_CARD_OVERLAP, true)
	var local_rect: Rect2 = HandFanContainer.card_rect_for_layout(index, total, size_hint, HAND_CARD_OVERLAP, true)
	var origin: Vector2 = hand_rect.get_center() - content_size * 0.5
	return Rect2(origin + local_rect.position, local_rect.size)

func _stage_card_rect(size_hint: Vector2) -> Rect2:
	var board_rect := Rect2(board_view.global_position, board_view.size)
	var center: Vector2 = board_rect.get_center() + Vector2(0.0, board_rect.size.y * 0.16)
	return _rect_from_center(center, size_hint)

func _update_drag_overlay_hover(zone: String) -> void:
	_drag_hover_zone = zone
	for zone_name: String in ["play", "attack", "move"]:
		var panel: PanelContainer = _drag_zone_panels.get(zone_name, null)
		var label: Label = _drag_zone_labels.get(zone_name, null)
		if panel == null or label == null:
			continue
		var accent: Color = panel.get_meta("accent", Color("9d7a50"))
		var fill: Color = panel.get_meta("fill", Color("241912"))
		var valid: bool = _drag_option_valid(zone_name)
		panel.add_theme_stylebox_override("panel", _drag_zone_style(fill, accent, zone == zone_name and valid, valid))
		label.modulate = Color.WHITE if valid else Color(1.0, 1.0, 1.0, 0.42)

func _drag_zone_style(fill: Color, accent: Color, hovered: bool, valid: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill.lightened(0.12) if hovered else fill
	style.border_color = accent.lightened(0.24) if hovered else accent if valid else Color("625244")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 10 if hovered else 6
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	if not valid:
		style.bg_color = fill.darkened(0.12)
		style.shadow_size = 0
	return style

func _drag_option_valid(zone: String) -> bool:
	match zone:
		"play":
			return bool(_drag_card_options.get("printed_playable", false))
		"attack":
			return bool(_drag_card_options.get("attack_playable", false))
		"move":
			return bool(_drag_card_options.get("move_playable", false))
		_:
			return false

func _setup_pile_widgets() -> void:
	burn_pile.visible = false
	burn_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burn_pile.custom_minimum_size = Vector2.ZERO
	var pile_specs: Array[Dictionary] = [
		{"kind": "draw", "panel": draw_pile, "title": "Draw", "accent": Color("8a6b49"), "fill": Color("33261d")},
		{"kind": "discard", "panel": discard_pile, "title": "Discard", "accent": Color("7f8ea4"), "fill": Color("ede2cd")}
	]
	for spec_var: Variant in pile_specs:
		var spec: Dictionary = spec_var
		_build_pile_widget(spec)

func _setup_play_meter() -> void:
	_play_meter = PanelContainer.new()
	_play_meter.name = "CardPlayMeter"
	_play_meter.custom_minimum_size = Vector2(152.0, 108.0)
	_play_meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_play_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_meter.tooltip_text = "Card plays remaining"
	var meter_style := _pile_card_style(Color(0.10, 0.07, 0.05, 0.94), Color("c28a53"), 6.0)
	meter_style.corner_radius_top_left = 8
	meter_style.corner_radius_top_right = 8
	meter_style.corner_radius_bottom_right = 8
	meter_style.corner_radius_bottom_left = 8
	meter_style.shadow_size = 5
	_play_meter.add_theme_stylebox_override("panel", meter_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 11)
	_play_meter.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_play_meter_icon = TextureRect.new()
	_play_meter_icon.custom_minimum_size = Vector2(68.0, 68.0)
	_play_meter_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_play_meter_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_play_meter_icon.texture = AssetLoader.load_texture(CARD_PLAY_ICON_PATH)
	_play_meter_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_play_meter_icon)

	_play_meter_count = Label.new()
	_play_meter_count.custom_minimum_size = Vector2(40.0, 68.0)
	_play_meter_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_meter_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_play_meter_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_play_meter_count, UiTypography.SIZE_SECTION_LARGE)
	_play_meter_count.add_theme_color_override("font_color", Color("fff4dc"))
	_play_meter_count.add_theme_color_override("font_outline_color", Color("2b1b12"))
	_play_meter_count.add_theme_constant_override("outline_size", 2)
	hbox.add_child(_play_meter_count)

	var insert_index: int = hand_row.get_child_count()
	for index: int in range(hand_row.get_child_count()):
		if hand_row.get_child(index) == hand_scroll:
			insert_index = index
			break
	hand_row.add_child(_play_meter)
	hand_row.move_child(_play_meter, insert_index)
	_refresh_card_play_meter()

func _setup_elemental_intensity_bar() -> void:
	_intensity_bar = Control.new()
	_intensity_bar.name = "ElementalIntensityBar"
	_intensity_bar.visible = false
	_intensity_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_intensity_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_intensity_bar.custom_minimum_size = _intensity_bar_size()
	_intensity_bar.size = _intensity_bar_size()
	_intensity_bar.z_index = 30
	add_child(_intensity_bar)
	for element_id: String in ElementData.all_elements():
		var badge := TooltipPanelContainer.new()
		badge.custom_minimum_size = INTENSITY_BADGE_SIZE
		badge.size = INTENSITY_BADGE_SIZE
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.mouse_default_cursor_shape = Control.CURSOR_HELP
		badge.tooltip_text = _intensity_tooltip(element_id)
		badge.add_theme_stylebox_override("panel", _intensity_badge_style(element_id, false))
		_intensity_bar.add_child(badge)
		_intensity_badges[element_id] = badge

		var content := Control.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.anchor_right = 1.0
		content.anchor_bottom = 1.0
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(content)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = INTENSITY_ICON_INSET
		icon.offset_top = INTENSITY_ICON_INSET
		icon.offset_right = -INTENSITY_ICON_INSET
		icon.offset_bottom = -INTENSITY_ICON_INSET
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = AssetLoader.load_texture(ElementData.intensity_icon_path(element_id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.anchor_right = 1.0
		count.anchor_bottom = 1.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.text = "0"
		UiTypography.set_label_size(count, UiTypography.SIZE_SECTION)
		count.add_theme_color_override("font_color", Color("fff7df"))
		count.add_theme_color_override("font_outline_color", Color("24160f"))
		count.add_theme_constant_override("outline_size", 4)
		content.add_child(count)
		_intensity_labels[element_id] = count
	_layout_intensity_badges()
	_refresh_elemental_intensity_bar()

func _connect_header_layout_signals() -> void:
	for control_var: Variant in [title_box, room_title, room_subtitle, relic_bar]:
		var control: Control = control_var as Control
		if control == null:
			continue
		if not control.resized.is_connected(_queue_elemental_intensity_layout):
			control.resized.connect(_queue_elemental_intensity_layout)

func _queue_elemental_intensity_layout() -> void:
	call_deferred("_layout_header_hud")
	call_deferred("_layout_elemental_intensity_bar")

func _intensity_bar_size() -> Vector2:
	return Vector2(INTENSITY_BADGE_SIZE.x * 3.0 + 9.0 * 2.0, INTENSITY_BADGE_SIZE.y * 2.0 + 7.0)

func _intensity_badge_position(index: int) -> Vector2:
	var row: int = 0 if index < 3 else 1
	var column: int = index if row == 0 else index - 3
	var row_count: int = 3 if row == 0 else 2
	var row_width: float = INTENSITY_BADGE_SIZE.x * float(row_count) + 9.0 * float(maxi(0, row_count - 1))
	var x_offset: float = (_intensity_bar_size().x - row_width) * 0.5
	return Vector2(
		x_offset + float(column) * (INTENSITY_BADGE_SIZE.x + 9.0),
		float(row) * (INTENSITY_BADGE_SIZE.y + 7.0)
	)

func _layout_intensity_badges() -> void:
	if _intensity_bar == null:
		return
	for index: int in range(_intensity_bar.get_child_count()):
		var child: Control = _intensity_bar.get_child(index) as Control
		if child == null:
			continue
		child.position = _intensity_badge_position(index)
		child.size = INTENSITY_BADGE_SIZE

func _layout_header_hud() -> void:
	if title_box == null:
		return
	var min_width: float = maxf(room_title.get_combined_minimum_size().x, room_subtitle.get_combined_minimum_size().x)
	var intensity_active: bool = str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty()
	if intensity_active:
		min_width = maxf(min_width, _intensity_bar_size().x)
	if relic_bar != null and relic_bar.visible and relic_bar.get_child_count() > 0:
		min_width = maxf(min_width, _desired_relic_bar_width())
	var available_width: float = _header_title_available_width()
	if available_width > 0.0:
		min_width = minf(min_width, available_width)
	title_box.custom_minimum_size = Vector2(min_width, title_box.custom_minimum_size.y)
	if relic_bar != null:
		relic_bar.custom_minimum_size = Vector2(min_width, relic_bar.custom_minimum_size.y)

func _desired_relic_bar_width() -> float:
	if relic_bar == null or relic_bar.get_child_count() <= 0:
		return 0.0
	var relic_count: int = mini(relic_bar.get_child_count(), RELIC_BAR_MIN_VISIBLE_RELICS)
	return RELIC_BADGE_SIZE.x * float(relic_count) + RELIC_BAR_HORIZONTAL_GAP * float(maxi(0, relic_count - 1))

func _header_title_available_width() -> float:
	if top_bar == null or title_box == null:
		return 0.0
	var width: float = top_bar.size.x
	if width <= 0.0:
		return 0.0
	var fixed_width: float = 0.0
	var visible_children: int = 0
	for child: Node in top_bar.get_children():
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		if not child_control.visible:
			continue
		visible_children += 1
		if child_control == title_box or child_control == header_spacer:
			continue
		fixed_width += child_control.get_combined_minimum_size().x
	var separation: float = float(top_bar.get_theme_constant("separation"))
	var total_gap: float = separation * float(maxi(0, visible_children - 1))
	return maxf(0.0, width - fixed_width - total_gap - HEADER_RELIC_WRAP_MARGIN)

func _layout_elemental_intensity_bar() -> void:
	if _intensity_bar == null or room_title == null or room_subtitle == null:
		return
	_layout_header_hud()
	_intensity_bar.size = _intensity_bar_size()
	_layout_intensity_badges()
	var title_rect: Rect2 = room_title.get_global_rect()
	var y: float = room_subtitle.get_global_rect().end.y + ELEMENTAL_INTENSITY_HEADER_GAP
	if relic_bar != null and relic_bar.visible and relic_bar.get_child_count() > 0:
		y = _relic_bar_visible_bottom_y() + ELEMENTAL_INTENSITY_HEADER_GAP
	_intensity_bar.global_position = Vector2(title_rect.position.x, y)

func _relic_bar_visible_bottom_y() -> float:
	if relic_bar == null:
		return 0.0
	var bottom: float = relic_bar.get_global_rect().end.y
	for child: Node in relic_bar.get_children():
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		if not child_control.visible:
			continue
		bottom = maxf(bottom, child_control.get_global_rect().end.y)
	return bottom

func _build_pile_widget(spec: Dictionary) -> void:
	var kind: String = str(spec.get("kind", ""))
	var panel: PanelContainer = spec.get("panel", null)
	if panel == null:
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_NONE
	panel.custom_minimum_size = _pile_widget_size(PILE_CARD_SIZE * PILE_CARD_SCALE)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.clip_contents = false
	panel.tooltip_text = "%s pile" % str(spec.get("title", kind)).capitalize()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for child: Node in panel.get_children():
		child.visible = false
		if child is Control:
			var child_control: Control = child
			child_control.custom_minimum_size = Vector2.ZERO
			child_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			child_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var content := Control.new()
	content.name = "PileContent_%s" % kind
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.clip_contents = false
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.add_child(content)
	_pile_content_hosts[kind] = content

	var visual := Control.new()
	visual.name = "PileVisual_%s" % kind
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.clip_contents = false
	visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.add_child(visual)
	_pile_visual_hosts[kind] = visual

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 50
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(badge, UiTypography.SIZE_BODY)
	badge.add_theme_color_override("font_color", Color("fff4dc"))
	badge.add_theme_color_override("font_outline_color", Color("2f2018"))
	badge.add_theme_constant_override("outline_size", 2)
	var badge_style := _pile_card_style(Color(0.16, 0.12, 0.09, 0.94), spec.get("accent", Color("8a6d49")), 4.0)
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge.add_theme_stylebox_override("normal", badge_style)
	content.add_child(badge)
	_pile_badges[kind] = badge

	panel.gui_input.connect(_on_pile_gui_input.bind(kind))

func _pile_panel_for_kind(kind: String) -> PanelContainer:
	match kind:
		"draw":
			return draw_pile
		"discard":
			return discard_pile
		"burn":
			return burn_pile
	return null

func _pile_display_card_size() -> Vector2:
	var hand_count: int = 1
	if not _combat_state.is_empty():
		var deck: Dictionary = _combat_state.get("deck", {})
		hand_count = maxi(1, (deck.get("hand", []) as Array).size())
	return _hand_card_size(hand_count, false) * PILE_CARD_SCALE

func _pile_widget_size(card_size: Vector2) -> Vector2:
	return card_size + _pile_stack_offset() * float(PILE_STACK_LAYERS - 1)

func _pile_stack_offset() -> Vector2:
	return PILE_STACK_OFFSET * PILE_CARD_SCALE

func _layout_pile_widget(kind: String, card_size: Vector2) -> void:
	var panel: PanelContainer = _pile_panel_for_kind(kind)
	var content: Control = _pile_content_hosts.get(kind, null)
	var host: Control = _pile_visual_hosts.get(kind, null)
	if panel == null or content == null or host == null:
		return
	var widget_size: Vector2 = _pile_widget_size(card_size)
	panel.custom_minimum_size = widget_size
	content.custom_minimum_size = widget_size
	content.position = Vector2.ZERO
	content.size = widget_size
	host.custom_minimum_size = widget_size
	host.position = Vector2.ZERO
	host.size = widget_size
	var badge: Label = _pile_badges.get(kind, null)
	if badge != null:
		badge.position = Vector2(card_size.x - 46.0, 7.0)
		badge.size = Vector2(38.0, 30.0)

func _populate_draw_pile(host: Control, cards: Array, card_size: Vector2) -> void:
	_clear_children_now(host)
	var visible_layers: int = clampi(cards.size(), 1, PILE_STACK_LAYERS)
	for stack_index: int in range(visible_layers - 1, -1, -1):
		var alpha: float = 0.34 if cards.is_empty() else clampf(1.0 - float(stack_index) * 0.12, 0.72, 1.0)
		_add_card_back_layer(host, card_size, stack_index, alpha)

func _populate_discard_pile(host: Control, cards: Array, card_size: Vector2) -> void:
	_clear_children_now(host)
	if cards.is_empty():
		var empty_frame := TextureRect.new()
		empty_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_frame.position = Vector2.ZERO
		empty_frame.size = card_size
		empty_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty_frame.stretch_mode = TextureRect.STRETCH_SCALE
		empty_frame.texture = AssetLoader.load_texture(CARD_FRAME_TEXTURE_PATH)
		empty_frame.modulate = Color(1.0, 1.0, 1.0, 0.16)
		host.add_child(empty_frame)
		return
	var visible_layers: int = clampi(cards.size(), 1, PILE_STACK_LAYERS)
	for stack_index: int in range(visible_layers - 1, 0, -1):
		_add_card_back_layer(host, card_size, stack_index, 0.58)
	var top_card_id: String = str(cards[cards.size() - 1])
	var display: Dictionary = _card_widget_display(top_card_id, _combat_state)
	var widget := CardWidgetScene.instantiate() as CardWidget
	widget.configure(top_card_id, false, false, true, false, false, true, _card_def(top_card_id, _combat_state))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	var slot: Control = _scaled_card_slot(widget, card_size)
	host.add_child(slot)
	slot.position = Vector2.ZERO
	slot.size = _normalized_card_size(card_size)
	_set_mouse_filter_recursive(slot, Control.MOUSE_FILTER_IGNORE)

func _add_card_back_layer(host: Control, card_size: Vector2, stack_index: int, alpha: float) -> void:
	var card_back := TextureRect.new()
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_back.position = _pile_stack_offset() * float(stack_index)
	card_back.size = card_size
	card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_back.stretch_mode = TextureRect.STRETCH_SCALE
	card_back.texture = AssetLoader.load_texture(CARD_BACK_TEXTURE_PATH)
	card_back.modulate = Color(1.0, 1.0, 1.0, alpha)
	host.add_child(card_back)

func _pile_card_style(fill: Color, border: Color, margin: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style

func _boot_run() -> void:
	_progression = ProgressionStore.load_data()
	var debug_boss: bool = bool(get_tree().root.get_meta("labyrinth_debug_boss_run", false))
	if get_tree().root.has_meta("labyrinth_debug_boss_run"):
		get_tree().root.remove_meta("labyrinth_debug_boss_run")
	if debug_boss:
		_start_debug_boss_run()
		return
	var should_resume: bool = bool(get_tree().root.get_meta("labyrinth_resume_saved_run", false))
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	if should_resume and ProgressionStore.has_saved_run():
		var saved_run: Dictionary = ProgressionStore.load_saved_run()
		if not saved_run.is_empty():
			_load_run_state(saved_run)
			_analytics_log_run_resumed()
			return
	_start_run()

func _load_run_state(next_run_state: Dictionary) -> void:
	_close_dialogue()
	_last_auto_dialogue_key = ""
	_run_state = _ensure_run_analytics_metadata(_run_engine.repair_loaded_run_state(next_run_state))
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_sync_analytics_combat_tracker()
	_reset_card_resolution()
	_victory_carry_processed = false
	_defeat_loss_processed = false
	_victory_carry_amount = 0
	_death_sequence_started = false
	if _death_overlay != null:
		_death_overlay.reset()
	_set_fatigue_edge_progress(-1.0)
	_board_presentation.clear()
	action_banner.visible = false
	_refresh_ui()

func _start_run() -> void:
	_progression = ProgressionStore.prepare_for_new_run(ProgressionStore.load_data())
	ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	var new_run_state: Dictionary = _ensure_run_analytics_metadata(_run_engine.create_new_run(_new_seed(), _progression))
	_load_run_state(new_run_state)
	_analytics_log_run_started()

func _start_debug_boss_run() -> void:
	_progression = ProgressionStore.default_data()
	var run_state: Dictionary = _run_engine.create_debug_boss_run(_progression)
	_load_run_state(_ensure_run_analytics_metadata(run_state))
	_analytics_log_run_started()

func _refresh_ui() -> void:
	if _dialogue_active and str(_run_state.get("mode", "room")) != "room":
		_close_dialogue()
	_sync_analytics_combat_tracker()
	if str(_run_state.get("mode", "room")) == "victory" and not _victory_carry_processed:
		_process_victory_carry()
	if str(_run_state.get("mode", "room")) == "defeat" and not _defeat_loss_processed:
		_process_defeat_loss()
	_sync_progression_from_run()
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	var display_room: Dictionary = current_room.duplicate(true)
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		display_room["name"] = str(_combat_state.get("room_name", display_room.get("name", "Chamber")))
		display_room["type"] = str(_combat_state.get("room_type", display_room.get("type", "combat")))
		display_room["element"] = str(_combat_state.get("room_element", display_room.get("element", ElementData.NONE)))
	_update_music_for_context(display_room)
	var room_element: String = str(display_room.get("element", ElementData.NONE))
	var title_color: Color = ElementData.accent(room_element) if ElementData.is_elemental(room_element) else Color("f0e6d2")
	room_title.add_theme_color_override("font_color", title_color)
	room_subtitle.add_theme_color_override("font_color", title_color.lightened(0.28) if ElementData.is_elemental(room_element) else Color("cdbca2"))
	room_title.text = _room_title_text(display_room)
	room_subtitle.text = _room_subtitle_text(display_room)
	_set_stats_label_text(_displayed_ember_count())
	_refresh_relic_bar()
	_refresh_turn_order_bar()
	_layout_header_hud()
	_refresh_elemental_intensity_bar()
	call_deferred("_layout_header_hud")
	call_deferred("_layout_elemental_intensity_bar")
	mini_map.set_run_state(_run_state)
	if _large_map_view != null:
		_large_map_view.call("set_run_state", _run_state)
	_refresh_pile_counts()
	_refresh_card_play_meter()
	_refresh_pile_visuals()
	_refresh_choice_bar()
	_refresh_stage_view()
	_refresh_hand_panel()
	_refresh_visibility()
	_refresh_death_overlay()
	log_label.text = _log_text()
	log_overlay.visible = not log_label.text.is_empty()
	_maybe_auto_trigger_room_dialogue()

func _refresh_pile_counts() -> void:
	var mode: String = str(_run_state.get("mode", "room"))
	if mode != "combat" or _combat_state.is_empty():
		draw_count.text = "-"
		discard_count.text = "-"
		burn_count.text = "-"
		return
	var deck: Dictionary = _combat_state.get("deck", {})
	draw_count.text = str((deck.get("draw", []) as Array).size())
	discard_count.text = str((deck.get("discard", []) as Array).size())
	burn_count.text = str((deck.get("burned", []) as Array).size())

func _refresh_relic_bar() -> void:
	if relic_bar == null:
		return
	_clear_children(relic_bar)
	var relic_ids: Array = (_run_state.get("relics", []) as Array).duplicate()
	relic_bar.visible = not relic_ids.is_empty()
	for relic_id_var: Variant in relic_ids:
		var relic_id: String = str(relic_id_var)
		var relic: Dictionary = GameData.relic_def(relic_id)
		if relic.is_empty():
			continue
		var frame := TooltipPanelContainer.new()
		frame.custom_minimum_size = RELIC_BADGE_SIZE
		frame.set_meta("relic_id", relic_id)
		frame.tooltip_text = "%s\n%s" % [
				str(relic.get("name", relic_id)),
				str(relic.get("description", ""))
		]
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		frame.add_theme_stylebox_override("panel", _pile_card_style(
				Color("261b14"),
				Color(GameData.relic_accent(relic_id)),
				4.0
		))
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.anchor_right = 1.0
		margin.anchor_bottom = 1.0
		margin.add_theme_constant_override("margin_left", 5)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_right", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		frame.add_child(margin)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = AssetLoader.load_texture(str(relic.get("icon_path", "")))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(icon)
		if icon.texture == null:
			var fallback := Label.new()
			fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
			fallback.anchor_right = 1.0
			fallback.anchor_bottom = 1.0
			fallback.text = str(relic.get("name", "?")).substr(0, 1).to_upper()
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UiTypography.set_label_size(fallback, UiTypography.SIZE_CAPTION)
			fallback.add_theme_color_override("font_color", Color("f0e6d2"))
			fallback.add_theme_color_override("font_outline_color", Color("2c1f16"))
			fallback.add_theme_constant_override("outline_size", 1)
			margin.add_child(fallback)
		relic_bar.add_child(frame)
	_layout_header_hud()
	call_deferred("_layout_header_hud")
	call_deferred("_layout_elemental_intensity_bar")

func _setup_turn_order_bar() -> void:
	if _turn_order_panel != null:
		return
	_turn_order_panel = PanelContainer.new()
	_turn_order_panel.name = "TurnOrderPanel"
	_turn_order_panel.visible = false
	_turn_order_panel.custom_minimum_size = TURN_ORDER_PANEL_MIN_SIZE
	_turn_order_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_turn_order_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_turn_order_panel.add_theme_stylebox_override("panel", _turn_order_panel_style())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_turn_order_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var label := Label.new()
	label.text = "TURN\nCLOCK"
	label.custom_minimum_size = Vector2(TURN_ORDER_LABEL_WIDTH, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_SECTION)
	label.add_theme_color_override("font_color", Color("f5dfb3"))
	label.add_theme_color_override("font_outline_color", Color("21150f"))
	label.add_theme_constant_override("outline_size", 2)
	row.add_child(label)
	_turn_order_bar = Control.new()
	_turn_order_bar.name = "TurnOrderBar"
	_turn_order_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_order_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_turn_order_bar.custom_minimum_size = TURN_ORDER_PORTRAIT_SIZE
	row.add_child(_turn_order_bar)
	top_bar.add_child(_turn_order_panel)
	top_bar.move_child(_turn_order_panel, header_spacer.get_index())

func _refresh_turn_order_bar() -> void:
	if _turn_order_bar == null:
		return
	if _turn_order_animating:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	if mode != "combat" or _combat_state.is_empty():
		_clear_children(_turn_order_bar)
		_turn_order_panel_locked_width = -1.0
		if _turn_order_panel != null:
			_turn_order_panel.visible = false
		return
	var entries: Array[Dictionary] = _combat_engine.current_turn_order(_turn_order_display_state(), TURN_ORDER_MAX_SLOTS)
	_set_turn_order_bar_entries(entries)

func _turn_order_display_state() -> Dictionary:
	var state: Dictionary = _combat_state.duplicate(true)
	var preview: Dictionary = _turn_order_card_time_preview()
	if not preview.is_empty():
		state["turn_order_preview_time_delta"] = int(preview.get("time", 0))
		state["turn_order_preview_card_name"] = str(preview.get("name", ""))
	return state

func _turn_order_card_time_preview() -> Dictionary:
	if _animation_lock or _combat_state.is_empty() or not _combat_engine.is_player_turn(_combat_state):
		return {}
	var index: int = _selected_card_index if _selected_card_index >= 0 else _hovered_card_index
	if index < 0:
		return {}
	if not bool(_card_play_options_for_index(index).get("any_playable", false)):
		return {}
	var card_id: String = _card_id_for_hand_index(index)
	if card_id.is_empty():
		return {}
	var card: Dictionary = _card_def(card_id, _combat_state)
	return {
		"time": _combat_engine.card_time_cost_from_def(card),
		"name": str(card.get("name", card_id))
	}

func _set_turn_order_bar_entries(entries: Array[Dictionary]) -> void:
	if _turn_order_bar == null:
		return
	_clear_children(_turn_order_bar)
	var entries_width: float = _turn_order_entries_width(entries.size())
	_turn_order_bar.custom_minimum_size = Vector2(entries_width, TURN_ORDER_PORTRAIT_SIZE.y)
	_turn_order_bar.size = _turn_order_bar.custom_minimum_size
	if _turn_order_panel != null:
		var panel_width: float = _turn_order_panel_locked_width if _turn_order_panel_locked_width > 0.0 else _turn_order_panel_width_for_count(entries.size())
		_turn_order_panel.custom_minimum_size = Vector2(panel_width, TURN_ORDER_PANEL_MIN_SIZE.y)
		_turn_order_panel.visible = not entries.is_empty()
	for index: int in range(entries.size()):
		var slot: Control = _build_turn_order_slot(entries[index], index)
		slot.position = _turn_order_slot_position(index)
		_turn_order_bar.add_child(slot)

func _turn_order_entries_width(count: int) -> float:
	if count <= 0:
		return 0.0
	return float(count) * TURN_ORDER_PORTRAIT_SIZE.x + float(count - 1) * TURN_ORDER_SLOT_GAP

func _turn_order_panel_width_for_count(count: int) -> float:
	return maxf(TURN_ORDER_PANEL_MIN_WIDTH, 28.0 + TURN_ORDER_LABEL_WIDTH + 12.0 + _turn_order_entries_width(count))

func _turn_order_slot_position(index: int) -> Vector2:
	return Vector2(float(index) * (TURN_ORDER_PORTRAIT_SIZE.x + TURN_ORDER_SLOT_GAP), 0.0)

func _build_turn_order_slot(entry: Dictionary, index: int) -> Control:
	var active: bool = bool(entry.get("active", false))
	var slot_size: Vector2 = TURN_ORDER_ACTIVE_SIZE if active else TURN_ORDER_PORTRAIT_SIZE
	var frame := Control.new()
	frame.custom_minimum_size = slot_size
	frame.size = slot_size
	frame.clip_contents = false
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if str(entry.get("kind", "")) == "enemy" else Control.CURSOR_ARROW
	frame.tooltip_text = _turn_order_tooltip(entry, index)
	frame.set_meta("turn_order_key", _turn_order_entry_key(entry))
	frame.set_meta("turn_order_size", slot_size)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _turn_order_slot_style(entry, active))
	frame.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	var inset: int = 5 if active else 6
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	panel.add_child(margin)
	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = AssetLoader.load_texture(_turn_order_portrait_path(entry))
	portrait.modulate = Color(1.0, 1.0, 1.0, 0.74) if bool(entry.get("projected", false)) and not active else Color.WHITE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(portrait)
	var badge_text: String = _turn_order_clock_badge_text(entry)
	frame.set_meta("turn_order_badge_text", badge_text)
	frame.add_child(_turn_order_number_badge(badge_text, entry, active))
	if str(entry.get("kind", "")) == "enemy":
		var tile: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var actor_key: String = str(entry.get("actor_key", ""))
		frame.mouse_entered.connect(_on_turn_order_enemy_hovered.bind(tile, actor_key))
		frame.mouse_exited.connect(_on_turn_order_enemy_unhovered.bind(tile, actor_key))
	return frame

func _turn_order_clock_badge_text(entry: Dictionary) -> String:
	return str(_turn_order_relative_time(entry))

func _turn_order_number_badge(text: String, entry: Dictionary, active: bool) -> Control:
	var badge := PanelContainer.new()
	badge.position = Vector2(3.0, 3.0)
	var badge_size := Vector2(maxf(24.0, 12.0 + float(text.length()) * 8.0), 22.0)
	badge.custom_minimum_size = badge_size
	badge.size = badge_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _turn_order_number_badge_style(entry, active))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL if text.length() >= 3 else UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("fff4d2"))
	label.add_theme_color_override("font_outline_color", Color("120b07"))
	label.add_theme_constant_override("outline_size", 1)
	badge.add_child(label)
	return badge

func _turn_order_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.025, 0.86)
	style.border_color = Color(0.63, 0.43, 0.25, 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 7.0)
	return style

func _turn_order_slot_style(entry: Dictionary, active: bool) -> StyleBoxFlat:
	var team: String = str(entry.get("team", "enemy"))
	var accent: Color = Color("5ca7e0") if team == "player" else Color("d36a55")
	if team == "enemy":
		var enemy_type: String = str(entry.get("type", ""))
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		if not enemy_def.is_empty():
			accent = Color(str(enemy_def.get("accent", "#d36a55")))
	var style := StyleBoxFlat.new()
	var projected: bool = bool(entry.get("projected", false)) and not active
	style.bg_color = Color(0.075, 0.050, 0.036, 0.94 if not projected else 0.78)
	style.border_color = accent.lightened(0.30 if active else 0.06)
	style.border_color.a = 0.95 if active else 0.74 if not projected else 0.52
	var border_width: int = 5 if active else 3 if not projected else 2
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34 if active else 0.26)
	style.shadow_size = 14 if active else 9
	style.shadow_offset = Vector2(0.0, 4.0)
	return style

func _turn_order_number_badge_style(entry: Dictionary, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var team: String = str(entry.get("team", "enemy"))
	var accent: Color = Color("5ca7e0") if team == "player" else Color("d36a55")
	style.bg_color = Color(0.05, 0.03, 0.02, 0.88)
	style.border_color = accent.lightened(0.18 if active else 0.02)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style

func _turn_order_tooltip(entry: Dictionary, _index: int) -> String:
	var clock: int = int(entry.get("time", 0))
	var eta: int = _turn_order_relative_time(entry)
	var name: String = str(entry.get("name", "Actor"))
	var lines: Array[String] = []
	if eta <= 0:
		lines.append("Now: %s" % name)
	else:
		lines.append("+%d: %s" % [eta, name])
	if bool(entry.get("active", false)):
		lines.append("Acting now")
	else:
		lines.append("Acts in %d" % eta)
	if clock > 0:
		lines.append("Clock %d" % clock)
	if bool(entry.get("projected", false)):
		lines.append("Projected next turn")
	var base: int = int(entry.get("base_initiative", 0))
	if str(entry.get("kind", "")) == "enemy":
		var intent_time: int = int(entry.get("intent_time_cost", 0))
		if intent_time > 0:
			lines.append("Base %d + intent %d" % [base, intent_time])
		elif base > 0:
			lines.append("Base %d" % base)
	else:
		var spent: int = int(entry.get("turn_time_spent", 0))
		var preview_time: int = int(entry.get("projected_time_cost", 0))
		if preview_time > 0:
			lines.append("Base %d + played %d + preview %d" % [base, spent, preview_time])
			var card_name: String = str(entry.get("projected_card_name", ""))
			if not card_name.is_empty():
				lines.append(card_name)
		elif spent > 0:
			lines.append("Base %d + played %d" % [base, spent])
		elif base > 0:
			lines.append("Base %d" % base)
	return "\n".join(lines)

func _turn_order_relative_time(entry: Dictionary) -> int:
	if entry.has("eta"):
		return maxi(0, int(entry.get("eta", 0)))
	return maxi(0, int(entry.get("time", 0)) - int(_combat_state.get("initiative_clock", 0)))

func _turn_order_portrait_path(entry: Dictionary) -> String:
	var key: String = "player" if str(entry.get("kind", "")) == "player" else str(entry.get("type", ""))
	return str(TURN_ORDER_PORTRAITS.get(key, TURN_ORDER_PORTRAITS.get("player", "")))

func _on_turn_order_enemy_hovered(tile: Vector2i, actor_key: String) -> void:
	if tile.x < 0:
		return
	_turn_order_hovered_enemy_key = actor_key
	_hovered_board_tile = tile
	_refresh_stage_view()

func _on_turn_order_enemy_unhovered(tile: Vector2i, actor_key: String) -> void:
	if _turn_order_hovered_enemy_key == actor_key:
		_turn_order_hovered_enemy_key = ""
	if _hovered_board_tile == tile:
		_hovered_board_tile = Vector2i(-1, -1)
		_refresh_stage_view()

func _turn_order_entries_from_state(state: Dictionary) -> Array[Dictionary]:
	return _combat_engine.current_turn_order(state, TURN_ORDER_MAX_SLOTS)

func _turn_order_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_var: Variant in value:
		if typeof(entry_var) == TYPE_DICTIONARY:
			result.append((entry_var as Dictionary).duplicate(true))
	return result

func _turn_order_entry_key(entry: Dictionary) -> String:
	return "%s:%s:%d:%d" % [
		str(entry.get("kind", "")),
		str(entry.get("actor_key", "")),
		int(entry.get("time", 0)),
		int(entry.get("seq", 0))
	]

func _turn_order_signature(entries: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in entries:
		parts.append("%s:%s" % [_turn_order_entry_key(entry), str(bool(entry.get("active", false)))])
	return "|".join(parts)

func _turn_order_actor_key(entry: Dictionary) -> String:
	return "%s:%s" % [str(entry.get("kind", "")), str(entry.get("actor_key", ""))]

func _turn_order_animation_role(entry: Dictionary) -> String:
	if bool(entry.get("active", false)):
		return "active"
	if bool(entry.get("projected", false)):
		return "projected"
	return "scheduled"

func _turn_order_animation_base_key(entry: Dictionary) -> String:
	return "%s:%s" % [_turn_order_actor_key(entry), _turn_order_animation_role(entry)]

func _turn_order_active_removal_indices(before_order: Array[Dictionary]) -> Array:
	for index: int in range(before_order.size()):
		if bool(before_order[index].get("active", false)):
			return [index]
	return []

func _turn_order_index_set(indices: Array) -> Dictionary:
	var result: Dictionary = {}
	for index_var: Variant in indices:
		result[int(index_var)] = true
	return result

func _turn_order_is_activation_style_update(before_order: Array[Dictionary], after_order: Array[Dictionary]) -> bool:
	if before_order.is_empty() or after_order.is_empty():
		return false
	if bool(before_order[0].get("active", false)) or not bool(after_order[0].get("active", false)):
		return false
	return _turn_order_actor_key(before_order[0]) == _turn_order_actor_key(after_order[0])

func _turn_order_instance_keys(entries: Array[Dictionary], excluded_indices: Array = []) -> Array[String]:
	var counts: Dictionary = {}
	var keys: Array[String] = []
	var excluded: Dictionary = _turn_order_index_set(excluded_indices)
	for index: int in range(entries.size()):
		if bool(excluded.get(index, false)):
			keys.append("")
			continue
		var key: String = _turn_order_animation_base_key(entries[index])
		var occurrence: int = int(counts.get(key, 0))
		counts[key] = occurrence + 1
		keys.append("%s#%d" % [key, occurrence])
	return keys

func _turn_order_child_positions(entries: Array[Dictionary], excluded_indices: Array = []) -> Dictionary:
	var positions: Dictionary = {}
	if _turn_order_bar == null:
		return positions
	var keys: Array[String] = _turn_order_instance_keys(entries, excluded_indices)
	var count: int = mini(keys.size(), _turn_order_bar.get_child_count())
	for index: int in range(count):
		if keys[index].is_empty():
			continue
		var child: Control = _turn_order_bar.get_child(index) as Control
		if child != null:
			positions[keys[index]] = child.position
	return positions

func _animate_turn_order_transition_between_states(before_state: Dictionary, after_state: Dictionary) -> void:
	await _animate_turn_order_transition(_turn_order_entries_from_state(before_state), _turn_order_entries_from_state(after_state))

func _animate_turn_order_transition(before_order: Array[Dictionary], after_order: Array[Dictionary]) -> void:
	if _turn_order_bar == null:
		return
	if _turn_order_signature(before_order) == _turn_order_signature(after_order):
		return
	if before_order.is_empty():
		_set_turn_order_bar_entries(after_order)
		return
	if _turn_order_is_activation_style_update(before_order, after_order):
		_set_turn_order_bar_entries(after_order)
		await get_tree().create_timer(TURN_ORDER_STYLE_SECONDS).timeout
		return
	_turn_order_animating = true
	var working_order: Array[Dictionary] = _turn_order_array(before_order)
	_turn_order_panel_locked_width = maxf(_turn_order_panel_width_for_count(working_order.size()), _turn_order_panel_width_for_count(after_order.size()))
	_set_turn_order_bar_entries(working_order)
	await get_tree().process_frame
	var removed_indices: Array = _turn_order_active_removal_indices(working_order)
	if not removed_indices.is_empty():
		var remove_tween: Tween = null
		for index_var: Variant in removed_indices:
			var removed_index: int = int(index_var)
			if removed_index < 0 or removed_index >= _turn_order_bar.get_child_count():
				continue
			var removed_child: Control = _turn_order_bar.get_child(removed_index) as Control
			if removed_child == null:
				continue
			if remove_tween == null:
				remove_tween = create_tween().set_parallel(true)
			var removed_target_position: Vector2 = removed_child.position + Vector2(0.0, -TURN_ORDER_FLOAT_OFFSET)
			remove_tween.tween_property(removed_child, "position", removed_target_position, TURN_ORDER_REMOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			remove_tween.tween_property(removed_child, "modulate:a", 0.0, TURN_ORDER_REMOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if remove_tween != null:
			await remove_tween.finished
	var previous_positions: Dictionary = _turn_order_child_positions(working_order, removed_indices)
	var after_keys: Array[String] = _turn_order_instance_keys(after_order)
	_set_turn_order_bar_entries(after_order)
	await get_tree().process_frame
	var reflow_tween: Tween = null
	var inserted_slots: Array[Dictionary] = []
	var child_count: int = mini(after_order.size(), _turn_order_bar.get_child_count())
	for index: int in range(child_count):
		var child: Control = _turn_order_bar.get_child(index) as Control
		if child == null:
			continue
		var final_position: Vector2 = child.position
		var instance_key: String = after_keys[index]
		if previous_positions.has(instance_key):
			var previous_position: Vector2 = previous_positions[instance_key]
			var offset: Vector2 = previous_position - final_position
			if offset.length() > 0.5:
				child.position = final_position + offset
				if reflow_tween == null:
					reflow_tween = create_tween().set_parallel(true)
				reflow_tween.tween_property(child, "position", final_position, TURN_ORDER_REFLOW_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		else:
			child.modulate.a = 0.0
			child.position = final_position + Vector2(0.0, -TURN_ORDER_FLOAT_OFFSET)
			inserted_slots.append({
				"child": child,
				"position": final_position
			})
	if reflow_tween != null:
		await reflow_tween.finished
	else:
		await get_tree().create_timer(TURN_ORDER_STYLE_SECONDS).timeout
	if not inserted_slots.is_empty():
		var insert_tween: Tween = create_tween().set_parallel(true)
		for slot_var: Variant in inserted_slots:
			var slot: Dictionary = slot_var
			var inserted_child: Control = slot.get("child", null) as Control
			if inserted_child == null:
				continue
			var target_position: Vector2 = slot.get("position", inserted_child.position)
			insert_tween.tween_property(inserted_child, "position", target_position, TURN_ORDER_INSERT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			insert_tween.tween_property(inserted_child, "modulate:a", 1.0, TURN_ORDER_INSERT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await insert_tween.finished
	_turn_order_panel_locked_width = -1.0
	_set_turn_order_bar_entries(after_order)
	_turn_order_animating = false

func _refresh_pile_visuals() -> void:
	var piles: Dictionary = _deck_piles()
	var card_size: Vector2 = _pile_display_card_size()
	for kind: String in ["draw", "discard"]:
		var host: Control = _pile_visual_hosts.get(kind, null)
		if host == null:
			continue
		var cards: Array = (piles.get(kind, []) as Array).duplicate()
		_layout_pile_widget(kind, card_size)
		var badge: Label = _pile_badges.get(kind, null)
		if badge != null:
			badge.text = str(cards.size()) if kind == "draw" else ""
			badge.visible = kind == "draw"
		if kind == "draw":
			_populate_draw_pile(host, cards, card_size)
			continue
		_populate_discard_pile(host, cards, card_size)

func _refresh_card_play_meter() -> void:
	if _play_meter == null or _play_meter_count == null:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	var active: bool = mode == "combat" and not _combat_state.is_empty()
	_play_meter.visible = active
	if not active:
		_play_meter_count.text = ""
		return
	var cards_left: int = _displayed_card_play_count()
	_play_meter_count.text = str(cards_left)
	var meter_tint: Color = Color.WHITE if cards_left > 0 else Color(1.0, 1.0, 1.0, 0.42)
	_play_meter.modulate = meter_tint

func _displayed_card_play_count() -> int:
	if _card_play_count_override >= 0:
		return _card_play_count_override
	return _combat_engine.cards_remaining_this_turn(_combat_state)

func _card_play_count_for_resolution_state(state: Dictionary) -> int:
	var cards_left: int = _combat_engine.cards_remaining_this_turn(state)
	if _card_play_count_override >= 0:
		cards_left -= 1
	return maxi(0, cards_left)

func _set_card_play_count_override(cards_left: int) -> void:
	_card_play_count_override = maxi(0, cards_left)
	_refresh_card_play_meter()

func _begin_card_play_meter_spend_preview() -> void:
	_set_card_play_count_override(maxi(0, _combat_engine.cards_remaining_this_turn(_combat_state) - 1))

func _refresh_elemental_intensity_bar(display_state: Dictionary = {}) -> void:
	if _intensity_bar == null:
		return
	var state: Dictionary = display_state if not display_state.is_empty() else _combat_state
	var active: bool = str(_run_state.get("mode", "room")) == "combat" and not state.is_empty()
	_intensity_bar.visible = active
	if not active:
		return
	_layout_elemental_intensity_bar()
	var intensities: Dictionary = _combat_engine.elemental_intensities(state)
	for element_id: String in ElementData.all_elements():
		var value: int = int(intensities.get(element_id, 0))
		var label: Label = _intensity_labels.get(element_id, null)
		if label != null:
			label.text = str(value)
		var badge: PanelContainer = _intensity_badges.get(element_id, null)
		if badge != null:
			badge.modulate = Color.WHITE if value > 0 else Color(1.0, 1.0, 1.0, 0.44)
			badge.add_theme_stylebox_override("panel", _intensity_badge_style(element_id, value > 0))

func _intensity_tooltip(element_id: String) -> String:
	return "%s Intensity\nRoom-wide %s power. Some %s card effects need this value." % [
		ElementData.name(element_id),
		ElementData.name(element_id),
		ElementData.name(element_id)
	]

func _intensity_badge_style(element_id: String, active: bool) -> StyleBoxFlat:
	var accent: Color = ElementData.accent(element_id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.045, 0.86 if active else 0.58)
	style.border_color = accent.lightened(0.18) if active else Color(accent.r, accent.g, accent.b, 0.42)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32 if active else 0.12)
	style.shadow_size = 8 if active else 3
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _displayed_ember_count() -> int:
	if _ember_count_override >= 0:
		return _ember_count_override
	var total: int = _run_engine.held_embers(_run_state)
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		total += int(_combat_state.get("room_embers", 0))
	return total

func _set_stats_label_text(ember_count: int) -> void:
	var level: int = int((_run_state.get("progression", _progression) as Dictionary).get("level", _progression.get("level", 1)))
	stats_label.text = "LV %d  EMBERS %d" % [level, ember_count]

func _deck_piles() -> Dictionary:
	if _combat_state.is_empty():
		return {"draw": [], "discard": [], "burn": []}
	var deck: Dictionary = _combat_state.get("deck", {})
	return {
		"draw": (deck.get("draw", []) as Array).duplicate(),
		"discard": (deck.get("discard", []) as Array).duplicate(),
		"burn": (deck.get("burned", []) as Array).duplicate()
	}

func _refresh_visibility() -> void:
	var mode: String = str(_run_state.get("mode", "room"))
	hand_row.visible = mode in ["combat", "reward"]
	piles_bar.visible = mode == "combat"
	hand_scroll.visible = mode in ["combat", "reward"]
	left_action_stack.visible = choice_bar.visible or piles_bar.visible
	bottom_stack.visible = choice_bar.visible or hand_row.visible
	if mode != "combat" and _choice_button_overlay != null:
		_choice_button_overlay.visible = false
	if _context_choice_overlay != null and mode != "campfire":
		_context_choice_overlay.visible = false
	menu_button.visible = mode != "defeat"
	if mode != "combat":
		_cancel_drag_play()
		_close_pile_view()
	if not (mode in ["combat", "reward"]) and _card_fx_layer != null and _card_fx_layer.get_child_count() > 0:
		_clear_children_now(_card_fx_layer)
	if mode != "room":
		_close_card_upgrade_overlay()
	if mode == "defeat":
		_close_large_map()
	_layout_choice_button_overlay()

func _refresh_death_overlay() -> void:
	if _death_overlay == null:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	if mode != "defeat":
		_death_sequence_started = false
		if _death_overlay.visible:
			_death_overlay.reset()
		return
	if _death_sequence_started:
		return
	_death_sequence_started = true
	_close_menu_overlay()
	_close_pile_view()
	_close_card_upgrade_overlay()
	_cancel_drag_play()
	_death_overlay.play(board_view)

func _refresh_choice_bar() -> void:
	_clear_children(choice_bar)
	if _choice_button_overlay != null:
		_clear_children(_choice_button_overlay)
		_choice_button_overlay.visible = false
	_clear_context_choice_overlay()
	_clear_relic_choice_overlay()
	_clear_terminal_overlay()
	var mode: String = str(_run_state.get("mode", "room"))
	choice_bar.custom_minimum_size = Vector2.ZERO
	if mode == "combat" and _selected_card_index >= 0:
		if _current_action_can_skip():
			_add_choice_button("Skip", _on_skip_action_pressed)
		_add_choice_button("Cancel", _on_cancel_requested)
	elif mode == "combat" and not _animation_lock and _drag_card_index < 0 and _combat_engine.is_player_turn(_combat_state):
		_add_choice_button("Pass", _on_pass_turn_pressed)
	match mode:
		"campfire":
			_add_campfire_choice(
				"linger",
				CAMPFIRE_CHOICE_LINGER_TEXT,
				CAMPFIRE_CHOICE_LINGER_DESCRIPTION,
				CAMPFIRE_CHOICE_LINGER_ICON_PATH,
				Color("efb35f")
			)
			_add_campfire_choice(
				"embrace",
				CAMPFIRE_CHOICE_EMBRACE_TEXT,
				CAMPFIRE_CHOICE_EMBRACE_DESCRIPTION,
				CAMPFIRE_CHOICE_EMBRACE_ICON_PATH,
				Color("d85d42")
			)
			_add_campfire_choice(
				"strength",
				CAMPFIRE_CHOICE_STRENGTH_TEXT,
				_campfire_strength_description(),
				CAMPFIRE_CHOICE_STRENGTH_ICON_PATH,
				Color("d79a4d"),
				_can_level_at_campfire()
			)
		"reward":
			if _reward_choices_available():
				_set_relic_choice_title(REWARD_CHOICE_TITLE_TEXT)
		"treasure":
			var pending_relics: Array = (_run_state.get("pending_relics", []) as Array).duplicate()
			if not pending_relics.is_empty():
				_set_relic_choice_title(RELIC_CHOICE_TITLE_TEXT)
			for relic_id_var: Variant in pending_relics:
				var relic_id: String = str(relic_id_var)
				var relic: Dictionary = GameData.relic_def(relic_id)
				_add_relic_choice(relic_id, relic)
		"victory":
			_show_victory_overlay()
	var has_overlay_choices: bool = _choice_button_overlay != null and _choice_button_overlay.get_child_count() > 0
	if has_overlay_choices:
		choice_bar.custom_minimum_size = _combat_choice_placeholder_size()
	choice_bar.visible = choice_bar.get_child_count() > 0 or has_overlay_choices
	if _choice_button_overlay != null:
		_choice_button_overlay.visible = has_overlay_choices
		_layout_choice_button_overlay()
		call_deferred("_layout_choice_button_overlay")
	if _context_choice_overlay != null:
		_context_choice_overlay.visible = _context_choice_bar != null and _context_choice_bar.get_child_count() > 0
	if _relic_choice_overlay != null:
		var has_relic_choices: bool = _relic_choice_bar != null and _relic_choice_bar.get_child_count() > 0
		var has_selection_title: bool = _relic_choice_title != null and _relic_choice_title.visible
		if _relic_choice_host != null:
			_relic_choice_host.visible = has_relic_choices
		_relic_choice_overlay.visible = has_relic_choices or has_selection_title
		if _relic_choice_overlay.visible:
			_layout_relic_choice_overlay()
			call_deferred("_layout_relic_choice_overlay")

func _add_choice_button(text: String, callback: Callable, tooltip: String = "") -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	var large_action_button: bool = _large_action_choice_text(text)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION if large_action_button else UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_ACTION if large_action_button else UiSkin.BUTTON_HEIGHT_STANDARD)
	button.pressed.connect(callback)
	if _choice_buttons_use_overlay():
		_choice_button_overlay.add_child(button)
	else:
		choice_bar.add_child(button)

func _choice_buttons_use_overlay() -> bool:
	return str(_run_state.get("mode", "room")) == "combat" and _choice_button_overlay != null

func _large_action_choice_text(text: String) -> bool:
	return text == "Pass" or text == "Skip" or text == "Cancel"

func _add_context_choice_button(text: String, callback: Callable, tooltip: String = "") -> void:
	if _context_choice_bar == null:
		return
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_LARGE)
	button.pressed.connect(callback)
	_context_choice_bar.add_child(button)

func _clear_context_choice_overlay() -> void:
	if _context_choice_bar != null:
		_clear_children_now(_context_choice_bar)
	if _context_choice_overlay != null:
		_context_choice_overlay.visible = false

func _clear_relic_choice_overlay() -> void:
	if _relic_choice_bar != null:
		_clear_children_now(_relic_choice_bar)
	if _relic_choice_host != null:
		_relic_choice_host.visible = false
	if _relic_choice_title != null:
		_relic_choice_title.visible = false
		_relic_choice_title.text = ""
	if _relic_choice_overlay != null:
		_relic_choice_overlay.visible = false

func _clear_terminal_overlay() -> void:
	if _terminal_overlay != null:
		_terminal_overlay.visible = false

func _show_victory_overlay() -> void:
	if _terminal_overlay == null:
		return
	var carried_embers: int = _victory_carry_amount
	if carried_embers <= 0:
		carried_embers = _run_engine.held_embers(_run_state)
	if _terminal_title_label != null:
		_terminal_title_label.text = "VICTORY"
	if _terminal_status_label != null:
		_terminal_status_label.text = "Run complete"
	if _terminal_reward_label != null:
		_terminal_reward_label.text = "Embers carried %d" % carried_embers
	_terminal_overlay.visible = true
	_layout_terminal_overlay()
	call_deferred("_layout_terminal_overlay")

func _reward_choices_available() -> bool:
	var reward_state: Dictionary = _run_state.get("pending_reward", {}) as Dictionary
	return (reward_state.get("cards", []) as Array).size() > 0 or int(reward_state.get("heal_amount", 0)) > 0

func _set_relic_choice_title(text: String) -> void:
	if _relic_choice_title == null:
		return
	_relic_choice_title.text = text
	_relic_choice_title.visible = not text.is_empty()

func _add_relic_choice(relic_id: String, relic: Dictionary) -> void:
	if _relic_choice_bar == null:
		return
	var panel := TooltipPanelContainer.new()
	panel.custom_minimum_size = RELIC_CHOICE_CARD_SIZE
	panel.clip_contents = false
	panel.z_index = 30
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _relic_choice_style(Color(GameData.relic_accent(relic_id)), false))
	panel.gui_input.connect(_on_relic_choice_gui_input.bind(relic_id))
	panel.mouse_entered.connect(_set_relic_choice_hovered.bind(panel, relic, true))
	panel.mouse_exited.connect(_set_relic_choice_hovered.bind(panel, relic, false))
	_relic_choice_bar.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76.0, 76.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(str(relic.get("icon_path", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var label := Label.new()
	label.text = str(relic.get("name", relic_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 32.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("fff1d5"))
	label.add_theme_color_override("font_outline_color", Color("26180f"))
	label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(label)

	var description := Label.new()
	description.text = str(relic.get("description", ""))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 76.0)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(description, UiTypography.SIZE_SMALL)
	description.add_theme_color_override("font_color", Color("dec9a7"))
	description.add_theme_color_override("font_outline_color", Color("21150e"))
	description.add_theme_constant_override("outline_size", 1)
	vbox.add_child(description)

func _add_campfire_choice(choice_id: String, title: String, detail: String, icon_path: String, accent: Color, enabled: bool = true) -> void:
	if _relic_choice_bar == null:
		return
	var panel := TooltipPanelContainer.new()
	panel.custom_minimum_size = RELIC_CHOICE_CARD_SIZE
	panel.clip_contents = false
	panel.z_index = 30
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	panel.set_meta("choice_enabled", enabled)
	panel.add_theme_stylebox_override("panel", _relic_choice_style(accent if enabled else Color("5c5046"), false))
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.58, 0.55, 0.50, 0.82)
	panel.gui_input.connect(_on_campfire_choice_gui_input.bind(choice_id))
	panel.mouse_entered.connect(_set_campfire_choice_hovered.bind(panel, accent, true))
	panel.mouse_exited.connect(_set_campfire_choice_hovered.bind(panel, accent, false))
	_relic_choice_bar.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76.0, 76.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(icon_path)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 32.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_BODY)
	label.add_theme_color_override("font_color", Color("fff1d5") if enabled else Color("b8aa94"))
	label.add_theme_color_override("font_outline_color", Color("26180f"))
	label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(label)

	var description := Label.new()
	description.text = detail
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 36.0, 76.0)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(description, UiTypography.SIZE_SMALL)
	description.add_theme_color_override("font_color", Color("dec9a7") if enabled else Color("948572"))
	description.add_theme_color_override("font_outline_color", Color("21150e"))
	description.add_theme_constant_override("outline_size", 1)
	vbox.add_child(description)

func _can_level_at_campfire() -> bool:
	_sync_progression_from_run()
	return ProgressionStore.can_level_up(_progression)

func _campfire_strength_description() -> String:
	_sync_progression_from_run()
	if ProgressionStore.is_max_level(_progression):
		return "Maximum level"
	var cost: int = ProgressionStore.next_level_cost(_progression)
	if cost <= 0:
		return CAMPFIRE_CHOICE_STRENGTH_DESCRIPTION
	if ProgressionStore.can_level_up(_progression):
		return "%s (%d embers)" % [CAMPFIRE_CHOICE_STRENGTH_DESCRIPTION, cost]
	return "Need %d embers" % cost

func _set_relic_choice_hovered(panel: PanelContainer, relic: Dictionary, hovered: bool) -> void:
	if panel == null:
		return
	var accent: String = str(relic.get("accent", GameData.relic_rarity_accent(str(relic.get("rarity", "common")))))
	panel.z_index = 40 if hovered else 30
	panel.add_theme_stylebox_override("panel", _relic_choice_style(Color(accent), hovered))

func _set_campfire_choice_hovered(panel: PanelContainer, accent: Color, hovered: bool) -> void:
	if panel == null:
		return
	if not bool(panel.get_meta("choice_enabled", true)):
		return
	panel.z_index = 40 if hovered else 30
	panel.add_theme_stylebox_override("panel", _relic_choice_style(accent, hovered))

func _relic_choice_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.045, 0.92).lightened(0.08) if hovered else Color(0.09, 0.06, 0.045, 0.86)
	style.border_color = accent.lightened(0.20) if hovered else Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48 if hovered else 0.38)
	style.shadow_size = 22 if hovered else 16
	style.shadow_offset = Vector2(0.0, 9.0 if hovered else 7.0)
	style.expand_margin_left = 8.0
	style.expand_margin_top = 8.0
	style.expand_margin_right = 8.0
	style.expand_margin_bottom = 14.0
	return style

func _on_relic_choice_gui_input(event: InputEvent, relic_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		await _on_relic_pressed(relic_id)

func _on_campfire_choice_gui_input(event: InputEvent, choice_id: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if choice_id == "strength" and not _can_level_at_campfire():
		return
	match choice_id:
		"linger":
			_on_campfire_linger_pressed()
		"embrace":
			_on_campfire_embrace_pressed()
		"strength":
			_open_level_up_overlay()

func _refresh_hand_panel() -> void:
	_clear_idle_card_fx_layer()
	_clear_children_now(hand_box)
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "combat":
		var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if hand.size() <= 6 else ScrollContainer.SCROLL_MODE_AUTO
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var card_size: Vector2 = _hand_card_size(hand.size(), false)
		for index: int in range(hand.size()):
			var options: Dictionary = _card_play_options_for_index(index)
			var display: Dictionary = _card_widget_display_for_index(index)
			var widget = CardWidgetScene.instantiate()
			widget.custom_minimum_size = card_size
			widget.configure(
				str(hand[index]),
				index == _selected_card_index,
				(_selected_card_index >= 0 and _selected_card_index != index) or _animation_lock,
				bool(options.get("any_playable", false)) and not _animation_lock,
				_hovered_card_index == index and _selected_card_index < 0
				and _drag_card_index < 0,
				not _animation_lock,
				bool(options.get("printed_playable", false)),
				_card_def(str(hand[index]), _combat_state)
			)
			widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
			if index == _drag_card_index:
				widget.modulate = Color(1.0, 1.0, 1.0, 0.20)
			elif index == _animating_hand_card_index:
				widget.visible = false
			if not _animation_lock:
				widget.activated.connect(_on_card_pressed.bind(index))
				widget.drag_started.connect(_on_card_drag_started.bind(index))
				widget.mouse_entered.connect(_on_card_hover_started.bind(index))
				widget.mouse_exited.connect(_on_card_hover_ended.bind(index))
			hand_box.add_child(_hand_card_slot(widget, card_size))
		hand_box.configure_layout(HAND_CARD_OVERLAP, true)
	elif mode == "reward":
		var reward_state: Dictionary = _run_state.get("pending_reward", {}) as Dictionary
		var reward_cards: Array = reward_state.get("cards", [])
		var heal_amount: int = int(reward_state.get("heal_amount", 0))
		var reward_choice_count: int = reward_cards.size() + (1 if heal_amount > 0 else 0)
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if reward_choice_count <= 4 else ScrollContainer.SCROLL_MODE_AUTO
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var reward_card_size: Vector2 = _hand_card_size(reward_choice_count, true)
		for card_id_var: Variant in reward_cards:
			var widget = CardWidgetScene.instantiate()
			widget.custom_minimum_size = reward_card_size
			widget.configure(str(card_id_var), false, false, true, false, true, true, _card_def(str(card_id_var)))
			widget.activated.connect(_on_reward_card_pressed.bind(str(card_id_var)))
			hand_box.add_child(_hand_card_slot(widget, reward_card_size))
		if heal_amount > 0:
			hand_box.add_child(_reward_heal_choice_slot(heal_amount, reward_card_size))
		hand_box.configure_layout(HAND_CARD_GAP, false)
	else:
		hand_box.configure_layout(HAND_CARD_GAP, false)

func _hand_card_slot(widget: Control, card_size: Vector2) -> Control:
	return _scaled_card_slot(widget, card_size)

func _scaled_card_slot(widget: Control, card_size: Vector2) -> Control:
	card_size = _normalized_card_size(card_size)
	var slot := Control.new()
	slot.custom_minimum_size = card_size
	slot.size = card_size
	slot.clip_contents = false
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scaler := Control.new()
	scaler.name = "CardScaleFrame"
	scaler.custom_minimum_size = CARD_WIDGET_BASE_SIZE
	scaler.size = CARD_WIDGET_BASE_SIZE
	scaler.scale = Vector2.ONE * _card_widget_scale_for_size(card_size)
	scaler.position = (card_size - CARD_WIDGET_BASE_SIZE * scaler.scale.x) * 0.5
	scaler.clip_contents = false
	scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(scaler)
	_prepare_native_card_widget(widget)
	scaler.add_child(widget)
	widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return slot

func _prepare_native_card_widget(widget: Control) -> void:
	if widget == null:
		return
	widget.custom_minimum_size = CARD_WIDGET_BASE_SIZE
	widget.size = CARD_WIDGET_BASE_SIZE
	widget.position = Vector2.ZERO
	widget.scale = Vector2.ONE

func _card_widget_scale_for_size(card_size: Vector2) -> float:
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return 1.0
	return minf(card_size.x / CARD_WIDGET_BASE_SIZE.x, card_size.y / CARD_WIDGET_BASE_SIZE.y)

func _reward_heal_choice_slot(heal_amount: int, slot_size: Vector2) -> Control:
	var slot := Control.new()
	slot.name = "RewardHealChoiceSlot"
	slot.custom_minimum_size = slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.name = "RewardHealChoice"
	panel.custom_minimum_size = slot_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "Recover instead"
	panel.set_meta("reward_heal_amount", heal_amount)
	panel.add_theme_stylebox_override("panel", _reward_heal_choice_style(false))
	panel.gui_input.connect(_on_reward_heal_choice_gui_input)
	panel.mouse_entered.connect(_set_reward_heal_choice_hovered.bind(panel, true))
	panel.mouse_exited.connect(_set_reward_heal_choice_hovered.bind(panel, false))
	slot.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 9)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var art_panel := PanelContainer.new()
	art_panel.name = "RewardHealArt"
	art_panel.custom_minimum_size = Vector2(0.0, clampf(slot_size.y * 0.38, 104.0, 132.0))
	art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_panel.add_theme_stylebox_override("panel", _reward_heal_art_style())
	vbox.add_child(art_panel)

	var art_center := CenterContainer.new()
	art_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_panel.add_child(art_center)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(86.0, 86.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(HEALTH_ICON_PATH)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_center.add_child(icon)

	var title := Label.new()
	title.text = "Recover"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(title, UiTypography.SIZE_BODY)
	title.add_theme_color_override("font_color", Color("fff1d5"))
	title.add_theme_color_override("font_outline_color", Color("26180f"))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	var amount := Label.new()
	amount.text = "+%d HP" % heal_amount
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(amount, UiTypography.SIZE_SECTION)
	amount.add_theme_color_override("font_color", Color("b9ef86"))
	amount.add_theme_color_override("font_outline_color", Color("1f170f"))
	amount.add_theme_constant_override("outline_size", 2)
	vbox.add_child(amount)

	var detail := Label.new()
	detail.text = "Skip card"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(detail, UiTypography.SIZE_CAPTION)
	detail.add_theme_color_override("font_color", Color("dec9a7"))
	detail.add_theme_color_override("font_outline_color", Color("21150e"))
	detail.add_theme_constant_override("outline_size", 1)
	vbox.add_child(detail)
	return slot

func _clear_idle_card_fx_layer() -> void:
	if _animation_lock or _card_fx_layer == null or _card_fx_layer.get_child_count() <= 0:
		return
	_clear_children_now(_card_fx_layer)

func _on_reward_heal_choice_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_skip_reward_pressed()

func _set_reward_heal_choice_hovered(panel: PanelContainer, hovered: bool) -> void:
	if panel == null:
		return
	panel.z_index = 40 if hovered else 30
	panel.add_theme_stylebox_override("panel", _reward_heal_choice_style(hovered))

func _reward_heal_choice_style(hovered: bool) -> StyleBoxFlat:
	var accent := Color("a9d16e")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.085, 0.055, 0.96).lightened(0.06) if hovered else Color(0.13, 0.085, 0.055, 0.92)
	style.border_color = accent.lightened(0.16) if hovered else Color("8e9f63")
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48 if hovered else 0.38)
	style.shadow_size = 22 if hovered else 16
	style.shadow_offset = Vector2(0.0, 9.0 if hovered else 7.0)
	return style

func _reward_heal_art_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.040, 0.030, 0.88)
	style.border_color = Color("74664a")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _refresh_stage_view() -> void:
	_exit_destinations_by_tile = _exit_tile_lookup()
	var display_state: Dictionary = _board_display_state()
	var move_tiles: Array[Vector2i] = []
	var attack_tiles: Array[Vector2i] = []
	var ability_tiles: Array[Vector2i] = []
	var presentation: Dictionary = _board_presentation.duplicate(true)
	var preview: Dictionary = {}
	if str(_run_state.get("mode", "room")) == "combat" and not _animation_lock:
		preview = _active_card_preview()
		if not preview.is_empty() and not bool(preview.get("complete", false)):
			var action: Dictionary = preview.get("action", {})
			var action_type: String = str(action.get("type", ""))
			var target_tiles: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
			if action_type in ["move", "blink"]:
				move_tiles = target_tiles
				var shortcuts: Dictionary = _preview_shortcuts_for_current_action(preview)
				attack_tiles = _vector2i_array(shortcuts.get("tiles", []))
				if not attack_tiles.is_empty():
					presentation["pulse_attack_tiles"] = true
			elif action_type in ["melee", "ranged", "aoe", "push", "pull"]:
				if bool(preview.get("orientation_pending", false)):
					attack_tiles = _vector2i_array([preview.get("orientation_target", INVALID_TARGET_TILE)])
					presentation["ability_tiles"] = _direction_choice_tiles(preview.get("orientation_target", INVALID_TARGET_TILE))
				else:
					attack_tiles = target_tiles
					if action_type != "aoe":
						presentation["pulse_attack_tiles"] = true
			else:
				ability_tiles = target_tiles
				presentation["ability_tiles"] = ability_tiles
			var preview_presentation: Dictionary = _preview_presentation(preview)
			for key: Variant in preview_presentation.keys():
				presentation[key] = preview_presentation[key]
		elif _hovered_board_tile.x >= 0:
			var threat_preview: Dictionary = _hovered_enemy_threat(display_state)
			move_tiles = _vector2i_array(threat_preview.get("move", []))
			attack_tiles = _vector2i_array(threat_preview.get("attack", []))
			if threat_preview.has("enemy_key"):
				presentation["focus_actor_keys"] = [str(threat_preview.get("enemy_key", ""))]
				presentation["focus_actor_color"] = Color("f2ddb2")
		if not _turn_order_hovered_enemy_key.is_empty():
			presentation["expanded_enemy_actor_keys"] = [_turn_order_hovered_enemy_key]
			presentation["focus_actor_keys"] = [_turn_order_hovered_enemy_key]
			presentation["focus_actor_color"] = Color("f2ddb2")
	if not _animation_lock and str(_run_state.get("mode", "room")) == "room" and _hovered_board_tile.x >= 0 and _exit_destinations_by_tile.has(_hovered_board_tile):
		presentation["focus_tiles"] = [_hovered_board_tile]
	if not _animation_lock and str(_run_state.get("mode", "room")) == "room" and not _exit_destinations_by_tile.is_empty():
		presentation["pulse_exit_tiles"] = true
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	if str(current_room.get("type", "")) == "campfire":
		presentation["scene_props"] = [
			{
				"kind": "campfire_bonfire",
				"tile": Vector2i(4, 4),
				"idle_frame_seconds": 0.10
			}
		]
	elif str(current_room.get("type", "")) == "treasure":
		presentation["scene_props"] = [
			{
				"kind": "relic_chest",
				"tile": Vector2i(4, 4),
				"width_scale": 0.68,
				"baseline_scale": 0.44
			}
		]
	presentation["active_door_tiles"] = _active_door_tiles_for_board()
	presentation["locked_door_tiles"] = _locked_door_tiles_for_board()
	presentation["equipped_equipment"] = _equipped_equipment_for_board()
	board_view.set_combat_state(
		display_state,
		move_tiles,
		attack_tiles,
		(display_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		_board_status_label(preview),
		_board_status_detail(preview),
		_exit_labels_for_board() if str(_run_state.get("mode", "room")) == "room" else {},
		_exit_icon_ids_for_board() if str(_run_state.get("mode", "room")) == "room" else {},
		presentation
	)

func _hovered_enemy_threat(display_state: Dictionary) -> Dictionary:
	for enemy_index: int in range((display_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (display_state.get("enemies", []) as Array)[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if not _enemy_footprint_tiles(enemy).has(_hovered_board_tile):
			continue
		var threat: Dictionary = _combat_engine.enemy_threat_tiles(display_state, enemy_index)
		threat["enemy_key"] = _enemy_key(enemy)
		return threat
	return {}

func _board_display_state() -> Dictionary:
	if str(_run_state.get("mode", "room")) == "combat":
		if not _preview_combat_state.is_empty():
			return _preview_combat_state.duplicate(true)
		if not _combat_state.is_empty():
			return _combat_state.duplicate(true)
	var layout: Dictionary = (_run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	return {
		"room_name": layout.get("name", "Room"),
		"room_coord": layout.get("coord", _run_state.get("current_room", Vector2i.ZERO)),
		"room_type": layout.get("type", "room"),
		"room_element": layout.get("element", ElementData.NONE),
		"grid": layout.get("grid", []).duplicate(true),
		"moss": layout.get("moss", {}).duplicate(true),
		"player": {
			"pos": layout.get("player_start", RoomGeneratorScript.entry_tile_for_direction(Vector2i.ZERO)),
			"hp": int(_run_state.get("player_hp", 1)),
			"max_hp": int(_run_state.get("player_max_hp", 1)),
			"block": 0
		},
		"npcs": layout.get("npcs", []).duplicate(true),
		"enemies": [],
		"traps": layout.get("traps", []).duplicate(true),
		"loot": layout.get("loot", []).duplicate(true),
		"terrain": layout.get("terrain", []).duplicate(true),
		"log": []
	}

func _active_card_preview() -> Dictionary:
	if _drag_card_index >= 0:
		return {}
	if _selected_card_index >= 0:
		if _pending_action_index < _pending_actions.size():
			var action: Dictionary = _pending_actions[_pending_action_index]
			var target_tiles: Array[Vector2i] = _vector2i_array(_pending_target_tiles)
			var orientation_pending: bool = _orientation_pending()
			if orientation_pending:
				action = _pending_oriented_action()
				target_tiles = _vector2i_array([_pending_orientation_target_tile])
			elif str(action.get("type", "")) == "aoe":
				action = _action_with_aoe_aim_orientation(action)
				target_tiles = _combat_engine.valid_targets_for_player_action(_preview_combat_state, action)
			return {
				"card_id": _card_id_for_hand_index(_selected_card_index),
				"state": _preview_combat_state.duplicate(true),
				"actions": _pending_actions.duplicate(true),
				"action_index": _pending_action_index,
				"target_tiles": target_tiles,
				"complete": false,
				"playable": true,
				"action": action,
				"skip_allowed": _pending_action_can_skip and not orientation_pending,
				"orientation_pending": orientation_pending,
				"orientation_target": _pending_orientation_target_tile
			}
		return {}
	if _hovered_card_index >= 0:
		return _card_preview_for_index(_hovered_card_index)
	return {}

func _card_preview_for_index(index: int) -> Dictionary:
	if _combat_state.is_empty():
		return {}
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return {"playable": false}
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return {}
	var card_id: String = str(hand[index])
	return _card_preview_from_state(card_id, _combat_state, _card_def(card_id, _combat_state).get("actions", []), 0)

func _fallback_preview_for_index(index: int, play_kind: String) -> Dictionary:
	if _combat_state.is_empty():
		return {}
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return {"playable": false}
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return {}
	return _card_preview_from_state(str(hand[index]), _combat_state, _fallback_actions(play_kind), 0)

func _card_play_options_for_index(index: int) -> Dictionary:
	var printed: Dictionary = _card_preview_for_index(index)
	var attack: Dictionary = _fallback_preview_for_index(index, "attack")
	var move: Dictionary = _fallback_preview_for_index(index, "move")
	var printed_playable: bool = bool(printed.get("playable", false))
	var attack_playable: bool = bool(attack.get("playable", false))
	var move_playable: bool = bool(move.get("playable", false))
	return {
		"play": printed,
		"attack": attack,
		"move": move,
		"printed_playable": printed_playable,
		"attack_playable": attack_playable,
		"move_playable": move_playable,
		"any_playable": printed_playable or attack_playable or move_playable
	}

func _fallback_actions(play_kind: String) -> Array:
	match play_kind:
		"attack":
			return [{"type": "melee", "damage": _fallback_attack_damage(), "range": 1}]
		"move":
			return [{"type": "move", "range": FALLBACK_MOVE_RANGE}]
		_:
			return []

func _fallback_attack_damage() -> int:
	return GameData.fixed_point_amount(FALLBACK_ATTACK_BASE_DAMAGE)

func _fallback_label(play_kind: String) -> String:
	match play_kind:
		"attack":
			return "%d Attack" % _fallback_attack_damage()
		"move":
			return "%d Move" % FALLBACK_MOVE_RANGE
		_:
			return ""

func _card_widget_display_for_index(index: int) -> Dictionary:
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return {}
	return _card_widget_display(str(hand[index]), _combat_state)

func _card_widget_display(card_id: String, state: Dictionary) -> Dictionary:
	var card: Dictionary = _card_def(card_id, state)
	var summary_rows: Array = ActionIcons.cost_rows_for_card(card)
	var modifier_lines: PackedStringArray = []
	var preview_state: Dictionary = state.duplicate(true)
	for action_var: Variant in card.get("actions", []):
		var action: Dictionary = action_var
		var action_type: String = str(action.get("type", ""))
		match action_type:
			"melee", "ranged", "aoe":
				var attack_final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
				var attack_damage_modifiers: Array[Dictionary] = _combat_engine.damage_modifiers_for_player_action(preview_state, action)
				var attack_visible_modifiers: Array[Dictionary] = _non_intensity_damage_modifiers(attack_damage_modifiers)
				var attack_row: Array = ActionIcons.tokens_for_action(action, {
					"final_damage": attack_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(attack_final_damage, attack_visible_modifiers),
					"damage_modifiers": attack_visible_modifiers
				})
				summary_rows.append(_annotate_intensity_condition_row(attack_row, _combat_engine.action_intensity_requirement_met(preview_state, action)))
				_consume_preview_damage_modifiers(preview_state, action)
			"push", "pull":
				var shove_final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
				var shove_damage_modifiers: Array[Dictionary] = _combat_engine.damage_modifiers_for_player_action(preview_state, action)
				var shove_visible_modifiers: Array[Dictionary] = _non_intensity_damage_modifiers(shove_damage_modifiers)
				var shove_row: Array = ActionIcons.tokens_for_action(action, {
					"final_damage": shove_final_damage,
					"tone_base_damage": _damage_tone_base_excluding_modifiers(shove_final_damage, shove_visible_modifiers),
					"damage_modifiers": shove_visible_modifiers
				})
				summary_rows.append(_annotate_intensity_condition_row(shove_row, _combat_engine.action_intensity_requirement_met(preview_state, action)))
				_consume_preview_damage_modifiers(preview_state, action)
			_:
				var row: Array = ActionIcons.tokens_for_action(action)
				if not row.is_empty():
					summary_rows.append(_annotate_intensity_condition_row(row, _combat_engine.action_intensity_requirement_met(preview_state, action)))
		if action_type == "intensity" and _combat_engine.player_action_can_resolve(preview_state, action):
			preview_state = _combat_engine.apply_player_action(preview_state, action)
		var bonus_row: Array = ActionIcons.tokens_for_intensity_bonus(action)
		if not bonus_row.is_empty():
			summary_rows.append(_annotate_intensity_condition_row(bonus_row, _combat_engine.action_intensity_bonus_requirement_met(preview_state, action)))
	var summary_text: String = ActionIcons.plain_text_for_rows(summary_rows)
	if summary_text.is_empty():
		summary_text = str(card.get("description", ""))
	return {
		"summary_bbcode": summary_text,
		"summary_rows": summary_rows,
		"modifier_lines": modifier_lines
	}

func _annotate_intensity_condition_row(row: Array, active: bool) -> Array:
	var annotated: Array = []
	for token_var: Variant in row:
		if typeof(token_var) != TYPE_DICTIONARY:
			annotated.append(token_var)
			continue
		var token: Dictionary = (token_var as Dictionary).duplicate(true)
		if str(token.get("kind", "")) == "intensity_requirement":
			token["condition_active"] = active
		annotated.append(token)
	return annotated

func _non_intensity_damage_modifiers(modifiers: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for modifier: Dictionary in modifiers:
		if str(modifier.get("kind", "")) == "elemental_intensity":
			continue
		filtered.append(modifier)
	return filtered

func _damage_tone_base_excluding_modifiers(final_damage: int, visible_modifiers: Array[Dictionary]) -> int:
	var tone_base: int = final_damage
	for modifier: Dictionary in visible_modifiers:
		tone_base -= int(modifier.get("amount", 0))
	return tone_base

func _consume_preview_damage_modifiers(state: Dictionary, action: Dictionary) -> void:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "aoe", "push", "pull"]:
		return
	if int(action.get("damage", 0)) <= 0:
		return
	if _combat_engine.attack_bonus_for_current_turn(state) == 0:
		return
	var turn_flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	turn_flags["first_attack_bonus_used"] = true
	state["turn_flags"] = turn_flags

func _has_playable_combat_card() -> bool:
	if _combat_state.is_empty():
		return false
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return false
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		if bool(_card_preview_for_index(index).get("playable", false)):
			return true
	return false

func _has_any_playable_combat_card() -> bool:
	if _combat_state.is_empty():
		return false
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return false
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		if bool(_card_play_options_for_index(index).get("any_playable", false)):
			return true
	return false

func _card_preview_from_state(card_id: String, combat_state: Dictionary, actions: Array, action_index: int, has_effect: bool = false) -> Dictionary:
	var working_state: Dictionary = combat_state.duplicate(true)
	var cursor: int = action_index
	var effect_seen: bool = has_effect or action_index > 0
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			cursor += 1
			continue
		if str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) <= 0:
			if _combat_engine.valid_targets_for_player_action(working_state, action).is_empty():
				cursor += 1
				continue
			working_state = _combat_engine.apply_player_action(working_state, action)
			effect_seen = true
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var skip_allowed: bool = _target_action_can_skip(action, actions)
			var skip_playable: bool = false
			if skip_allowed:
				skip_playable = bool(_card_preview_from_state(card_id, working_state, actions, cursor + 1, effect_seen).get("playable", false))
			var candidate_targets: Array[Vector2i] = _combat_engine.valid_targets_for_player_action(working_state, action)
			if _remaining_actions_are_targetless(actions, cursor + 1):
				if candidate_targets.is_empty() and skip_playable:
					cursor += 1
					continue
				return {
					"card_id": card_id,
					"state": working_state,
					"actions": actions.duplicate(true),
					"action_index": cursor,
					"target_tiles": _vector2i_array(candidate_targets),
					"complete": false,
					"playable": not candidate_targets.is_empty(),
					"action": action,
					"skip_allowed": skip_playable
				}
			var valid_targets: Array[Vector2i] = []
			for target_tile: Vector2i in candidate_targets:
				var next_state: Dictionary = _combat_engine.apply_player_action(working_state, action, target_tile)
				var continuation: Dictionary = _card_preview_from_state(card_id, next_state, actions, cursor + 1, true)
				if bool(continuation.get("playable", false)):
					valid_targets.append(target_tile)
			if valid_targets.is_empty() and skip_playable:
				cursor += 1
				continue
			return {
				"card_id": card_id,
				"state": working_state,
				"actions": actions.duplicate(true),
				"action_index": cursor,
				"target_tiles": _vector2i_array(valid_targets),
				"complete": false,
				"playable": not valid_targets.is_empty(),
				"action": action,
				"skip_allowed": skip_playable
			}
		working_state = _combat_engine.apply_player_action(working_state, action)
		effect_seen = true
		cursor += 1
	return {
		"card_id": card_id,
		"state": working_state,
		"actions": actions.duplicate(true),
		"action_index": cursor,
		"target_tiles": _vector2i_array([]),
		"complete": true,
		"playable": effect_seen,
		"action": {},
		"skip_allowed": false
	}

func _remaining_actions_are_targetless(actions: Array, start_index: int) -> bool:
	for index: int in range(maxi(0, start_index), actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		if _combat_engine.player_action_needs_target(actions[index] as Dictionary):
			return false
	return true

func _target_action_can_skip(action: Dictionary, actions: Array) -> bool:
	if bool(action.get("required", false)):
		return false
	if bool(action.get("optional", false)):
		return true
	return actions.size() > 1

func _preview_presentation(preview: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"focus_actor_keys": ["player"]
	}
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	result["focus_actor_color"] = PLAYER_PREVIEW_FOCUS if action_type in ["move", "blink", "illusion"] else PLAYER_ATTACK_FOCUS
	var focus_tiles: Array[Vector2i] = _focus_tiles_for_preview(preview)
	if not focus_tiles.is_empty():
		result["focus_tiles"] = focus_tiles
		if action_type == "illusion":
			result["focus_color"] = Color(0.42, 0.88, 0.42, 0.22)
		else:
			result["focus_color"] = Color(0.42, 0.84, 0.93, 0.24) if action_type in ["move", "blink"] else Color(0.95, 0.62, 0.37, 0.22)
	var path_tiles: Array[Vector2i] = _path_tiles_for_preview(preview)
	if not path_tiles.is_empty():
		result["path_tiles"] = path_tiles
	var effect: Dictionary = _preview_effect_for_action(preview)
	if not effect.is_empty():
		result["effect"] = effect
	var preview_units: Array = _preview_units_for_action(preview)
	if not preview_units.is_empty():
		result["preview_units"] = preview_units
	return result

func _preview_units_for_action(preview: Dictionary) -> Array:
	var action: Dictionary = preview.get("action", {})
	if str(action.get("type", "")) != "illusion":
		return []
	if _selected_card_index < 0 or _hovered_board_tile.x < 0:
		return []
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	var health: int = maxi(1, int(action.get("health", action.get("amount", 1))))
	return [{
		"key": "illusion_preview",
		"role": "illusion_preview",
		"type": "player",
		"name": "Illusion preview",
		"pos": _hovered_board_tile,
		"hp": health,
		"max_hp": health,
		"accent": ILLUSION_PREVIEW_FOCUS
	}]

func _focus_tiles_for_preview(preview: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if bool(preview.get("orientation_pending", false)):
		var orientation_target: Vector2i = preview.get("orientation_target", INVALID_TARGET_TILE)
		if action_type == "aoe":
			return _aoe_tiles_for_action(preview.get("state", {}), action, orientation_target)
		if action_type in ["push", "pull"] or int(action.get("push", 0)) > 0 or int(action.get("pull", 0)) > 0:
			var force_tiles: Array[Vector2i] = _combat_engine.forced_movement_tiles_for_player_action(preview.get("state", {}), action, orientation_target)
			force_tiles.push_front(orientation_target)
			return force_tiles
		return _vector2i_array([orientation_target])
	if _hovered_board_tile.x < 0:
		return []
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		var path_tiles: Array[Vector2i] = _vector2i_array(shortcut_plan.get("path_tiles", []))
		return path_tiles if not path_tiles.is_empty() else _vector2i_array([_hovered_board_tile])
	if action_type == "aoe" and _aoe_hover_can_show_pattern(preview.get("state", {}), action, _hovered_board_tile):
		return _aoe_tiles_for_action(preview.get("state", {}), action, _hovered_board_tile)
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type in ["move", "blink"]:
		return _path_tiles_for_preview(preview)
	return _vector2i_array([_hovered_board_tile])

func _path_tiles_for_preview(preview: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if _hovered_board_tile.x < 0:
		return []
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		return _vector2i_array(shortcut_plan.get("path_tiles", []))
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type == "move":
		var preview_state: Dictionary = preview.get("state", {})
		return _combat_engine.path_for_player_action(preview_state, action, _hovered_board_tile)
	if action_type == "blink":
		return _vector2i_array([_hovered_board_tile])
	return []

func _preview_effect_for_action(preview: Dictionary) -> Dictionary:
	var action: Dictionary = preview.get("action", {})
	if bool(preview.get("orientation_pending", false)):
		var orientation_target: Vector2i = preview.get("orientation_target", INVALID_TARGET_TILE)
		var orientation_state: Dictionary = preview.get("state", {})
		var orientation_player_tile: Vector2i = (orientation_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		return _preview_effect_for_target(orientation_state, orientation_player_tile, orientation_target, action)
	if _hovered_board_tile.x < 0:
		return {}
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	var preview_state: Dictionary = preview.get("state", {})
	if not shortcut_plan.is_empty():
		return _preview_effect_for_target(
			(shortcut_plan.get("state", preview_state) as Dictionary),
			shortcut_plan.get("move_tile", INVALID_TARGET_TILE),
			_hovered_board_tile,
			shortcut_plan.get("action", {})
		)
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return {}
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	return _preview_effect_for_target(preview_state, player_tile, _hovered_board_tile, action)

func _preview_effect_for_target(state: Dictionary, from_tile: Vector2i, target_tile: Vector2i, action: Dictionary) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move":
			return {"kind": "move", "from": from_tile, "to": target_tile, "preview": true}
		"blink":
			return {"kind": "blink", "from": from_tile, "to": target_tile, "preview": true}
		"melee", "ranged", "push", "pull":
			var force_tiles: Array[Vector2i] = _combat_engine.forced_movement_tiles_for_player_action(state, action, target_tile)
			return {
				"kind": "ranged" if action_type in ["push", "pull"] else action_type,
				"from": from_tile,
				"to": target_tile,
				"preview": true,
				"element": str(action.get("element", action.get("_card_element", ElementData.NONE))),
				"force_tiles": force_tiles,
				"damage_preview": _preview_damage_for_action(state, action, target_tile)
			}
		"aoe":
			return {
				"kind": "aoe",
				"from": from_tile,
				"to": target_tile,
				"center": target_tile,
				"tiles": _aoe_tiles_for_action(state, action, target_tile),
				"preview": true,
				"element": str(action.get("element", action.get("_card_element", ElementData.NONE))),
				"damage_preview": _preview_damage_for_action(state, action, target_tile)
			}
		_:
			return {}

func _preview_damage_for_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "aoe", "push", "pull"]:
		return {}
	if action_type != "aoe" and target_tile.x < 0:
		return {}
	var before_state: Dictionary = state.duplicate(true)
	var after_state: Dictionary = _combat_engine.apply_player_action(before_state, action, target_tile)
	var after_by_id: Dictionary = {}
	for after_var: Variant in after_state.get("enemies", []):
		var after_enemy: Dictionary = after_var
		after_by_id[int(after_enemy.get("id", -1))] = after_enemy
	var preview: Dictionary = {}
	for before_var: Variant in state.get("enemies", []):
		var before_enemy: Dictionary = before_var
		var enemy_id: int = int(before_enemy.get("id", -1))
		if not after_by_id.has(enemy_id):
			continue
		var after_enemy: Dictionary = after_by_id[enemy_id]
		var hp_loss: int = maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		var block_loss: int = maxi(0, int(before_enemy.get("block", 0)) - int(after_enemy.get("block", 0)))
		var stoneskin_loss: int = maxi(0, int(before_enemy.get("stoneskin", 0)) - int(after_enemy.get("stoneskin", 0)))
		if hp_loss <= 0 and block_loss <= 0 and stoneskin_loss <= 0:
			continue
		preview[_enemy_key(before_enemy)] = {
			"hp": int(after_enemy.get("hp", 0)),
			"hp_loss": hp_loss,
			"block": int(after_enemy.get("block", 0)),
			"block_loss": block_loss,
			"stoneskin": int(after_enemy.get("stoneskin", 0)),
			"stoneskin_loss": stoneskin_loss,
			"lethal": int(after_enemy.get("hp", 0)) <= 0
		}
	var after_terrain_by_id: Dictionary = {}
	for after_terrain_var: Variant in after_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var
		after_terrain_by_id[str(after_terrain.get("id", ""))] = after_terrain
	for before_terrain_var: Variant in state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var
		var terrain_id: String = str(before_terrain.get("id", ""))
		if terrain_id.is_empty() or not after_terrain_by_id.has(terrain_id):
			continue
		var after_terrain: Dictionary = after_terrain_by_id[terrain_id]
		var hp_loss: int = maxi(0, int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0)))
		if hp_loss <= 0:
			continue
		preview[_terrain_key(before_terrain)] = {
			"hp": int(after_terrain.get("hp", 0)),
			"hp_loss": hp_loss,
			"lethal": int(after_terrain.get("hp", 0)) <= 0
		}
	return preview

func _hovered_shortcut_plan_for_preview(preview: Dictionary) -> Dictionary:
	if _hovered_board_tile.x < 0:
		return {}
	var shortcuts: Dictionary = _preview_shortcuts_for_current_action(preview)
	var plans: Dictionary = shortcuts.get("plans", {})
	return plans.get(_hovered_board_tile, {}) as Dictionary

func _preview_shortcuts_for_current_action(preview: Dictionary) -> Dictionary:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"]:
		return {}
	var actions: Array = preview.get("actions", [])
	var action_index: int = int(preview.get("action_index", -1))
	var card_id: String = str(preview.get("card_id", ""))
	if action_index < 0 or action_index >= actions.size() or card_id.is_empty():
		return {}
	var preview_state: Dictionary = (preview.get("state", {}) as Dictionary).duplicate(true)
	if preview_state.is_empty():
		return {}
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var plans: Dictionary = {}
	for move_target: Vector2i in _vector2i_array(preview.get("target_tiles", [])):
		var after_move_state: Dictionary = _combat_engine.apply_player_action(preview_state, action, move_target)
		var path_tiles: Array[Vector2i] = _vector2i_array([move_target]) if action_type == "blink" else _combat_engine.path_for_player_action(preview_state, action, move_target)
		var move_distance: int = PathUtils.manhattan(player_tile, move_target) if action_type == "blink" else maxi(0, path_tiles.size() - 1)
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, after_move_state, move_target, move_target, move_distance, path_tiles)
	if bool(preview.get("skip_allowed", false)):
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, preview_state, INVALID_TARGET_TILE, player_tile, 0, [])
	var tiles: Array[Vector2i] = []
	for tile_var: Variant in plans.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			tiles.append(tile_var)
	return {
		"plans": plans,
		"tiles": tiles
	}

func _collect_shortcut_attack_plans(plans: Dictionary, card_id: String, actions: Array, action_index: int, base_state: Dictionary, move_target: Vector2i, move_tile: Vector2i, move_distance: int, path_tiles: Array[Vector2i]) -> void:
	var followup: Dictionary = _next_shortcut_attack_step(base_state, actions, action_index + 1)
	if followup.is_empty():
		return
	var followup_state: Dictionary = followup.get("state", {})
	var followup_action: Dictionary = followup.get("action", {})
	var followup_index: int = int(followup.get("action_index", -1))
	for enemy_tile: Vector2i in _combat_engine.valid_targets_for_player_action(followup_state, followup_action):
		var after_attack_state: Dictionary = _combat_engine.apply_player_action(followup_state, followup_action, enemy_tile)
		var continuation: Dictionary = _card_preview_from_state(card_id, after_attack_state, actions, followup_index + 1, true)
		if not bool(continuation.get("playable", false)):
			continue
		var existing: Dictionary = plans.get(enemy_tile, {})
		if not existing.is_empty():
			var existing_distance: int = int(existing.get("move_distance", 99999))
			var existing_path_length: int = _vector2i_array(existing.get("path_tiles", [])).size()
			if move_distance > existing_distance:
				continue
			if move_distance == existing_distance and path_tiles.size() >= existing_path_length:
				continue
		plans[enemy_tile] = {
			"state": followup_state.duplicate(true),
			"move_target": move_target,
			"move_tile": move_tile,
			"move_distance": move_distance,
			"path_tiles": path_tiles.duplicate(),
			"action_index": followup_index,
			"action": followup_action.duplicate(true)
		}

func _next_shortcut_attack_step(state: Dictionary, actions: Array, action_index: int) -> Dictionary:
	var working_state: Dictionary = state.duplicate(true)
	var cursor: int = action_index
	while cursor < actions.size():
		var action: Dictionary = actions[cursor]
		if not _combat_engine.player_action_can_resolve(working_state, action):
			cursor += 1
			continue
		if _combat_engine.player_action_needs_target(action):
			var action_type: String = str(action.get("type", ""))
			if action_type not in SHORTCUT_ATTACK_TYPES:
				return {}
			return {
				"state": working_state,
				"action_index": cursor,
				"action": action
			}
		working_state = _combat_engine.apply_player_action(working_state, action)
		cursor += 1
	return {}

func _aoe_tiles_for_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = INVALID_TARGET_TILE) -> Array[Vector2i]:
	if str(action.get("type", "")) != "aoe":
		return []
	return _combat_engine.aoe_tiles_for_player_action(state, action, target_tile)

func _aoe_hover_can_show_pattern(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> bool:
	if str(action.get("type", "")) != "aoe":
		return false
	if target_tile.x < 0:
		return false
	var grid: Array = state.get("grid", [])
	if int(action.get("range", 0)) <= 0:
		return true
	var player_tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	return (
		PathUtils.is_passable(grid, target_tile)
		and PathUtils.manhattan(player_tile, target_tile) <= int(action.get("range", 0))
		and PathUtils.has_line_of_sight(grid, player_tile, target_tile)
	)

func _orientation_pending() -> bool:
	return _selected_card_index >= 0 and _pending_orientation_target_tile.x >= 0 and _pending_action_index < _pending_actions.size()

func _current_action_is_aimed_aoe() -> bool:
	if _selected_card_index < 0 or _pending_action_index < 0 or _pending_action_index >= _pending_actions.size():
		return false
	return str((_pending_actions[_pending_action_index] as Dictionary).get("type", "")) == "aoe"

func _action_with_aoe_aim_orientation(action: Dictionary) -> Dictionary:
	if str(action.get("type", "")) != "aoe":
		return action
	var oriented: Dictionary = action.duplicate(true)
	if _combat_engine.player_action_needs_orientation(action):
		oriented["orientation"] = _aoe_aim_orientation
	else:
		oriented.erase("orientation")
	return oriented

func _reset_aoe_aim_orientation_for_action(action: Dictionary) -> void:
	var direction: Vector2i = _cardinal_direction(action.get("orientation", Vector2i(1, 0)))
	_aoe_aim_orientation = direction if direction != Vector2i.ZERO else Vector2i(1, 0)

func _refresh_pending_aoe_target_tiles() -> void:
	if not _current_action_is_aimed_aoe():
		return
	var action: Dictionary = _action_with_aoe_aim_orientation(_pending_actions[_pending_action_index])
	_pending_target_tiles = _combat_engine.valid_targets_for_player_action(_preview_combat_state, action)

func _set_aoe_aim_orientation(direction: Vector2i) -> void:
	var snapped: Vector2i = _cardinal_direction(direction)
	if snapped == Vector2i.ZERO or snapped == _aoe_aim_orientation:
		return
	_aoe_aim_orientation = snapped
	if _current_action_is_aimed_aoe():
		_refresh_pending_aoe_target_tiles()
		_refresh_stage_view()

func _rotate_aoe_aim(step: int) -> void:
	var current_index: int = ORIENTATION_DIRECTIONS.find(_aoe_aim_orientation)
	if current_index < 0:
		current_index = ORIENTATION_DIRECTIONS.find(Vector2i(1, 0))
	if current_index < 0:
		current_index = 0
	_set_aoe_aim_orientation(ORIENTATION_DIRECTIONS[posmod(current_index + step, ORIENTATION_DIRECTIONS.size())])

func _direction_from_tiles(start_tile: Vector2i, current_tile: Vector2i) -> Vector2i:
	if start_tile.x < 0 or current_tile.x < 0 or start_tile == current_tile:
		return Vector2i.ZERO
	var delta: Vector2i = current_tile - start_tile
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(1 if delta.x >= 0 else -1, 0)
	return Vector2i(0, 1 if delta.y >= 0 else -1)

func _cardinal_direction(direction: Variant) -> Vector2i:
	var raw: Vector2i = Vector2i.ZERO
	match typeof(direction):
		TYPE_VECTOR2I:
			raw = direction
		TYPE_VECTOR2:
			var vector_direction: Vector2 = direction
			raw = Vector2i(int(roundf(vector_direction.x)), int(roundf(vector_direction.y)))
		TYPE_ARRAY:
			var pair: Array = direction
			if pair.size() >= 2:
				raw = Vector2i(int(pair[0]), int(pair[1]))
		TYPE_DICTIONARY:
			var direction_dict: Dictionary = direction
			raw = Vector2i(int(direction_dict.get("x", 0)), int(direction_dict.get("y", 0)))
	if raw == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(raw.x) >= absi(raw.y):
		return Vector2i(1 if raw.x >= 0 else -1, 0)
	return Vector2i(0, 1 if raw.y >= 0 else -1)

func _force_direction_for_action(action: Dictionary, target_tile: Vector2i, hover_tile: Vector2i) -> Vector2i:
	var allowed: Array[Vector2i] = _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile)
	if allowed.is_empty():
		return Vector2i.ZERO
	var candidate: Vector2i = Vector2i.ZERO
	if hover_tile.x >= 0 and hover_tile != target_tile:
		candidate = _direction_from_tiles(target_tile, hover_tile)
	var player_tile: Vector2i = (_preview_combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	if candidate == Vector2i.ZERO and player_tile != target_tile:
		var fallback_delta: Vector2i = target_tile - player_tile
		var action_type: String = str(action.get("type", ""))
		if action_type == "pull" or (int(action.get("pull", 0)) > 0 and int(action.get("push", 0)) <= 0):
			fallback_delta = player_tile - target_tile
		candidate = _cardinal_direction(fallback_delta)
	if allowed.has(candidate):
		return candidate
	return allowed[0]

func _force_direction_for_confirmation(action: Dictionary, target_tile: Vector2i, click_tile: Vector2i) -> Vector2i:
	var allowed: Array[Vector2i] = _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile)
	if allowed.is_empty():
		return Vector2i.ZERO
	if click_tile == target_tile:
		return _force_direction_for_action(action, target_tile, _hovered_board_tile)
	var candidate: Vector2i = _direction_from_tiles(target_tile, click_tile)
	return candidate if allowed.has(candidate) else Vector2i.ZERO

func _action_with_pending_orientation(action: Dictionary, direction: Vector2i) -> Dictionary:
	var oriented: Dictionary = action.duplicate(true)
	var action_type: String = str(oriented.get("type", ""))
	if _combat_engine.player_action_needs_orientation(action) and (
		action_type in ["push", "pull"]
		or int(oriented.get("push", 0)) > 0
		or int(oriented.get("pull", 0)) > 0
	):
		oriented["force_direction"] = direction
	return oriented

func _target_needs_force_orientation(action: Dictionary, target_tile: Vector2i) -> bool:
	if str(action.get("type", "")) == "aoe":
		return false
	if not _combat_engine.player_action_needs_orientation(action):
		return false
	return not _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile).is_empty()

func _pending_oriented_action() -> Dictionary:
	if not _orientation_pending():
		return {}
	var action: Dictionary = _pending_actions[_pending_action_index]
	return _action_with_pending_orientation(action, _force_direction_for_action(action, _pending_orientation_target_tile, _hovered_board_tile))

func _direction_choice_tiles(target_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid: Array = _preview_combat_state.get("grid", [])
	var action: Dictionary = _pending_actions[_pending_action_index] if _pending_action_index >= 0 and _pending_action_index < _pending_actions.size() else {}
	for direction: Vector2i in _combat_engine.force_directions_for_player_action(_preview_combat_state, action, target_tile):
		var tile: Vector2i = target_tile + direction
		if grid.is_empty() or PathUtils.is_in_bounds(grid, tile):
			result.append(tile)
	return result

func _confirm_pending_orientation(click_tile: Vector2i) -> void:
	var action: Dictionary = _pending_actions[_pending_action_index]
	var direction: Vector2i = _force_direction_for_confirmation(action, _pending_orientation_target_tile, click_tile)
	if direction == Vector2i.ZERO:
		_refresh_stage_view()
		return
	var oriented_action: Dictionary = _action_with_pending_orientation(action, direction)
	if not _combat_engine.valid_targets_for_player_action(_preview_combat_state, oriented_action).has(_pending_orientation_target_tile):
		_refresh_stage_view()
		return
	var previous_action_index: int = _pending_action_index
	_pending_actions[_pending_action_index] = oriented_action
	_pending_selected_targets.append(_pending_orientation_target_tile)
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, oriented_action, _pending_orientation_target_tile)
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _on_card_pressed(index: int) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "combat":
		return
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return
	if _drag_card_index >= 0:
		return
	if _selected_card_index == index:
		_cancel_card_selection()
		return
	var preview: Dictionary = _card_preview_for_index(index)
	await _begin_card_preview(index, preview)

func _on_card_drag_started(index: int) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "combat":
		return
	if _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		return
	if _selected_card_index >= 0:
		_cancel_card_selection()
	var options: Dictionary = _card_play_options_for_index(index)
	if not bool(options.get("any_playable", false)):
		return
	var source_rect: Rect2 = _hand_card_global_rect(index)
	_drag_card_index = index
	_drag_card_options = options.duplicate(true)
	_drag_hover_zone = ""
	_drag_card_source_rect = source_rect
	_drag_card_grab_offset = _current_mouse_position() - source_rect.position
	if _drag_card_proxy != null:
		_drag_card_proxy.queue_free()
	_drag_card_proxy = _spawn_card_proxy(_card_id_for_hand_index(index), source_rect)
	_drag_overlay.add_child(_drag_card_proxy)
	_update_drag_proxy_position(_current_mouse_position())
	_show_drag_overlay()
	_update_drag_overlay_hover(_drag_zone_at(_current_mouse_position()))
	var source_widget: Control = hand_box.get_child(index) as Control
	if source_widget != null:
		source_widget.visible = false

func _begin_card_preview(index: int, preview: Dictionary, label_override: String = "") -> void:
	if not bool(preview.get("playable", false)):
		return
	_hovered_card_index = -1
	_selected_card_label_override = label_override
	if bool(preview.get("complete", false)):
		_selected_card_index = index
		_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
		_pending_actions = (preview.get("actions", []) as Array).duplicate(true)
		_pending_action_index = int(preview.get("action_index", 0))
		_pending_action_can_skip = false
		_pending_target_tiles.clear()
		_pending_selected_targets.clear()
		_pending_orientation_target_tile = INVALID_TARGET_TILE
		_aoe_aim_orientation = Vector2i(1, 0)
		_append_skipped_target_placeholders(0, _pending_action_index)
		_refresh_ui()
		await _play_player_card(
			index,
			(preview.get("state", {}) as Dictionary).duplicate(true),
			(preview.get("actions", []) as Array).duplicate(true),
			_vector2i_array(_pending_selected_targets)
		)
		return
	_selected_card_index = index
	_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_actions = (preview.get("actions", []) as Array).duplicate(true)
	_pending_action_index = int(preview.get("action_index", 0))
	_pending_action_can_skip = bool(preview.get("skip_allowed", false))
	_pending_target_tiles = _vector2i_array(preview.get("target_tiles", []))
	_pending_selected_targets.clear()
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	if _pending_action_index < _pending_actions.size():
		_reset_aoe_aim_orientation_for_action(_pending_actions[_pending_action_index])
		_refresh_pending_aoe_target_tiles()
	_append_skipped_target_placeholders(0, _pending_action_index)
	_refresh_ui()

func _on_card_hover_started(index: int) -> void:
	if _animation_lock or _selected_card_index >= 0 or _drag_card_index >= 0 or str(_run_state.get("mode", "room")) != "combat":
		return
	_hovered_card_index = index
	_refresh_stage_view()
	_refresh_turn_order_bar()

func _on_card_hover_ended(index: int) -> void:
	if _selected_card_index >= 0 or _drag_card_index >= 0:
		return
	if _hovered_card_index == index:
		_hovered_card_index = -1
		_refresh_stage_view()
		_refresh_turn_order_bar()

func _on_board_tile_hovered(tile: Vector2i) -> void:
	if _dialogue_active or _drag_card_index >= 0:
		return
	_hovered_board_tile = tile
	if str(_run_state.get("mode", "room")) in ["combat", "room"]:
		_refresh_stage_view()

func _on_board_tile_dragged(start_tile: Vector2i, current_tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	if str(_run_state.get("mode", "room")) != "combat" or not _current_action_is_aimed_aoe():
		return
	var direction: Vector2i = _direction_from_tiles(start_tile, current_tile)
	if direction != Vector2i.ZERO:
		_set_aoe_aim_orientation(direction)
	_hovered_board_tile = current_tile
	_refresh_stage_view()

func _on_board_tile_drag_released(start_tile: Vector2i, current_tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	if str(_run_state.get("mode", "room")) != "combat" or not _current_action_is_aimed_aoe():
		return
	var direction: Vector2i = _direction_from_tiles(start_tile, current_tile)
	if direction != Vector2i.ZERO:
		_set_aoe_aim_orientation(direction)
	_hovered_board_tile = current_tile
	await _on_board_tile_clicked(current_tile)

func _on_board_tile_clicked(tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "room" and _exit_destinations_by_tile.has(tile):
		await _on_map_view_room_selected(_exit_destinations_by_tile[tile], tile)
		return
	if mode != "combat" or _selected_card_index < 0:
		return
	if _orientation_pending():
		await _confirm_pending_orientation(tile)
		return
	var preview: Dictionary = _active_card_preview()
	var shortcut_plan: Dictionary = {}
	if not preview.is_empty():
		shortcut_plan = (_preview_shortcuts_for_current_action(preview).get("plans", {}) as Dictionary).get(tile, {}) as Dictionary
	if not _pending_target_tiles.has(tile) and shortcut_plan.is_empty():
		return
	if not shortcut_plan.is_empty():
		await _on_pending_shortcut_clicked(tile, shortcut_plan)
		return
	var action: Dictionary = _pending_actions[_pending_action_index]
	var previous_action_index: int = _pending_action_index
	if str(action.get("type", "")) == "aoe":
		action = _action_with_aoe_aim_orientation(action)
		if not _combat_engine.valid_targets_for_player_action(_preview_combat_state, action).has(tile):
			return
		_pending_actions[_pending_action_index] = action
	elif _target_needs_force_orientation(action, tile):
		_pending_orientation_target_tile = tile
		_hovered_board_tile = tile
		_refresh_stage_view()
		return
	_pending_selected_targets.append(tile)
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, action, tile)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _on_cancel_requested() -> void:
	if _dialogue_active:
		_advance_dialogue()
		return
	if _animation_lock:
		return
	if _drag_card_index >= 0:
		await _animate_drag_cancel_to_source()
		return
	if _large_map_scrim != null and _large_map_scrim.visible:
		_close_large_map()
		return
	if _pile_scrim != null and _pile_scrim.visible:
		_close_pile_view()
		return
	if _menu_scrim != null and _menu_scrim.visible:
		_close_menu_overlay()
		return
	if _selected_card_index >= 0:
		_cancel_card_selection()
		return
	_open_menu_overlay()

func _on_mini_map_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _dialogue_active or _animation_lock:
			return
		_open_large_map()
		get_viewport().set_input_as_handled()

func _open_large_map() -> void:
	if _large_map_scrim == null:
		return
	_close_menu_overlay()
	_close_pile_view()
	_close_card_upgrade_overlay()
	if _large_map_view != null:
		_large_map_view.call("set_run_state", _run_state)
	_large_map_scrim.visible = true
	_large_map_scrim.move_to_front()

func _close_large_map() -> void:
	if _large_map_scrim == null:
		return
	_large_map_scrim.visible = false

func _on_large_map_room_selected(coord: Vector2i) -> void:
	_close_large_map()
	await _on_map_view_room_selected(coord)

func _cancel_card_selection() -> void:
	if _selected_card_index < 0:
		return
	_reset_card_resolution()
	_refresh_ui()

func _current_action_can_skip() -> bool:
	return _selected_card_index >= 0 and _pending_action_index < _pending_actions.size() and _pending_action_can_skip

func _on_skip_action_pressed() -> void:
	if _animation_lock or not _current_action_can_skip():
		return
	var previous_action_index: int = _pending_action_index
	_pending_selected_targets.append(INVALID_TARGET_TILE)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _on_pending_shortcut_clicked(target_tile: Vector2i, shortcut_plan: Dictionary) -> void:
	var move_target: Vector2i = shortcut_plan.get("move_target", INVALID_TARGET_TILE)
	var previous_action_index: int = _pending_action_index
	_pending_selected_targets.append(move_target)
	if move_target.x >= 0:
		var move_action: Dictionary = _pending_actions[_pending_action_index]
		_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, move_action, move_target)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var attack_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(previous_action_index + 1, int(attack_preview.get("action_index", 0)))
	if bool(attack_preview.get("complete", false)):
		await _apply_pending_preview_result(attack_preview)
		return
	_load_pending_preview_state(attack_preview)
	if not _pending_target_tiles.has(target_tile):
		_refresh_ui()
		return
	var attack_action_index: int = _pending_action_index
	if _target_needs_force_orientation(_pending_actions[_pending_action_index], target_tile):
		_pending_orientation_target_tile = target_tile
		_hovered_board_tile = target_tile
		_refresh_stage_view()
		return
	_pending_selected_targets.append(target_tile)
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, _pending_actions[_pending_action_index], target_tile)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	_append_skipped_target_placeholders(attack_action_index + 1, int(next_preview.get("action_index", 0)))
	await _apply_pending_preview_result(next_preview)

func _load_pending_preview_state(preview: Dictionary) -> void:
	_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_action_index = int(preview.get("action_index", 0))
	_pending_action_can_skip = bool(preview.get("skip_allowed", false))
	_pending_target_tiles = _vector2i_array(preview.get("target_tiles", []))
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	if _pending_action_index < _pending_actions.size():
		_reset_aoe_aim_orientation_for_action(_pending_actions[_pending_action_index])
		_refresh_pending_aoe_target_tiles()

func _apply_pending_preview_result(next_preview: Dictionary) -> void:
	if bool(next_preview.get("complete", false)):
		await _play_player_card(
			_selected_card_index,
			(next_preview.get("state", {}) as Dictionary).duplicate(true),
			_pending_actions.duplicate(true),
			_vector2i_array(_pending_selected_targets)
		)
		return
	_load_pending_preview_state(next_preview)
	_refresh_ui()

func _append_skipped_target_placeholders(start_action_index: int, end_action_index: int) -> void:
	var safe_start: int = maxi(0, start_action_index)
	var safe_end: int = mini(end_action_index, _pending_actions.size())
	for index: int in range(safe_start, safe_end):
		if _combat_engine.player_action_needs_target(_pending_actions[index]):
			_pending_selected_targets.append(INVALID_TARGET_TILE)

func _play_player_card(hand_index: int, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	var card_id: String = _card_id_for_hand_index(hand_index)
	var source_rect: Rect2 = _hand_card_global_rect(hand_index)
	var card_size: Vector2 = source_rect.size if source_rect.size.length() > 0.0 else _hand_card_size(5, false)
	var pile_kind: String = _card_destination_pile(card_id)
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var previous_combat_state: Dictionary = _combat_state.duplicate(true)
	var previous_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var played_instance_id: String = _analytics_hand_instance_id(hand_index)
	_animating_hand_card_index = hand_index
	_animation_lock = true
	_begin_card_play_meter_spend_preview()
	_refresh_ui()
	await _animate_card_play_fx(card_id, source_rect, card_size)
	await _animate_player_card_resolution(_combat_state.duplicate(true), card_id, actions, selected_targets)
	_board_presentation.clear()
	_set_action_banner("")
	_combat_state = _combat_engine.finish_player_card(resolved_state, hand_index)
	_analytics_reconcile_combat_tracker(previous_combat_state, _combat_state)
	_analytics_log_card_draws(previous_combat_state, _combat_state, previous_tracker, _analytics_snapshot_combat_tracker(), "card_effect")
	_analytics_log_card_played(card_id, played_instance_id, previous_combat_state, resolved_state, actions, selected_targets)
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	var transition_combat_state: Dictionary = _combat_state.duplicate(true)
	if outcome == "":
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
	_sync_combat_state_from_run()
	_analytics_log_playable_cards()
	_analytics_log_combat_transition(previous_run_state, "card_play", transition_combat_state)
	if outcome == "":
		await _animate_card_to_pile_fx(card_id, pile_kind, card_size)
	_animation_lock = false
	_animating_hand_card_index = -1
	_card_play_count_override = -1
	_reset_card_resolution()
	_hovered_card_index = -1
	_refresh_ui()
	if str(_run_state.get("mode", "room")) == "combat" and _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		await _resolve_enemy_round()

func _card_destination_pile(card_id: String) -> String:
	return "burn" if bool(_card_def(card_id, _combat_state).get("burn", false)) else "discard"

func _animate_card_play_fx(card_id: String, source_rect: Rect2, size_hint: Vector2) -> void:
	if _card_fx_layer == null or card_id.is_empty() or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var proxy: Control = _spawn_card_proxy(card_id, source_rect)
	proxy.z_index = 1500
	proxy.modulate = Color(1.0, 1.0, 1.0, 0.96)
	_card_fx_layer.add_child(proxy)
	var target_rect: Rect2 = _stage_card_rect(size_hint * 0.88)
	await _animate_card_proxy_to_rect(proxy, target_rect, CARD_PLAY_SECONDS)
	if not _node_is_alive(proxy):
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.07)
	await tween.finished
	_queue_free_node_now(proxy)

func _animate_card_to_pile_fx(card_id: String, pile_kind: String, size_hint: Vector2) -> void:
	if _card_fx_layer == null or card_id.is_empty():
		return
	var pile_rect: Rect2 = _pile_global_rect(pile_kind)
	if pile_rect.size.x <= 0.0 or pile_rect.size.y <= 0.0:
		return
	var start_rect: Rect2 = _stage_card_rect(size_hint * 0.58)
	var target_size: Vector2 = Vector2(
		minf(96.0, size_hint.x * 0.42),
		minf(136.0, size_hint.y * 0.42)
	)
	target_size = _normalized_card_size(target_size)
	var target_rect: Rect2 = _rect_from_center(pile_rect.get_center(), target_size)
	var proxy: Control = _spawn_card_proxy(card_id, start_rect)
	proxy.z_index = 1490
	proxy.modulate = Color(1.0, 1.0, 1.0, 0.76)
	_card_fx_layer.add_child(proxy)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(proxy, "position", target_rect.position, CARD_PILE_SECONDS)
	if bool(proxy.get_meta("scaled_card_proxy", false)):
		tween.parallel().tween_property(proxy, "scale", Vector2.ONE * _card_widget_scale_for_size(target_rect.size), CARD_PILE_SECONDS)
	else:
		tween.parallel().tween_property(proxy, "size", target_rect.size, CARD_PILE_SECONDS)
	tween.parallel().tween_property(proxy, "modulate", Color(1.0, 1.0, 1.0, 0.18), CARD_PILE_SECONDS)
	await tween.finished
	_queue_free_node_now(proxy)

func _animate_draw_cards_fx(draw_entries: Array) -> void:
	if _card_fx_layer == null or draw_entries.is_empty():
		return
	var final_total: int = draw_entries.size()
	for entry_var: Variant in draw_entries:
		if entry_var is Dictionary:
			final_total = maxi(final_total, int((entry_var as Dictionary).get("total", final_total)))
	var size_hint: Vector2 = _hand_card_size(maxi(5, final_total), false)
	var source_rect: Rect2 = _rect_from_center(_pile_global_rect("draw").get_center(), size_hint * 0.86)
	for draw_index: int in range(draw_entries.size()):
		if not _card_fx_can_continue_combat():
			return
		var entry: Variant = draw_entries[draw_index]
		var card_id: String = ""
		var target_index: int = draw_index
		var target_total: int = final_total
		if entry is Dictionary:
			var draw_entry: Dictionary = entry
			card_id = str(draw_entry.get("card_id", ""))
			target_index = int(draw_entry.get("index", draw_index))
			target_total = int(draw_entry.get("total", final_total))
		else:
			card_id = str(entry)
		if card_id.is_empty() or not _card_fx_can_continue_combat():
			return
		var proxy: Control = _spawn_card_proxy(card_id, source_rect)
		_card_fx_layer.add_child(proxy)
		await _animate_card_proxy_to_rect(proxy, _hand_receive_rect(target_index, target_total, size_hint * 0.94), DRAW_FRAME_SECONDS)
		if not _card_fx_can_continue_combat():
			_queue_free_node_now(proxy)
			return
		_queue_free_node_now(proxy)
		await get_tree().create_timer(0.05).timeout

func _card_fx_can_continue_combat() -> bool:
	return _node_is_alive(_card_fx_layer) and str(_run_state.get("mode", "room")) == "combat"

func _draw_entries_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_counts: Dictionary = {}
	for card_id_var: Variant in (before_state.get("deck", {}) as Dictionary).get("hand", []):
		var card_id: String = str(card_id_var)
		before_counts[card_id] = int(before_counts.get(card_id, 0)) + 1
	var after_hand: Array = (after_state.get("deck", {}) as Dictionary).get("hand", [])
	var drawn: Array[Dictionary] = []
	for index: int in range(after_hand.size()):
		var card_id: String = str(after_hand[index])
		var remaining: int = int(before_counts.get(card_id, 0))
		if remaining > 0:
			before_counts[card_id] = remaining - 1
			continue
		drawn.append({
			"card_id": card_id,
			"index": index,
			"total": after_hand.size()
		})
	return drawn

func _death_rewards_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_count: int = (before_state.get("death_rewards", []) as Array).size()
	var after_rewards: Array = after_state.get("death_rewards", [])
	var result: Array[Dictionary] = []
	for index: int in range(before_count, after_rewards.size()):
		if after_rewards[index] is Dictionary:
			result.append((after_rewards[index] as Dictionary).duplicate(true))
	return result

func _animate_death_rewards(before_state: Dictionary, after_state: Dictionary) -> void:
	var rewards: Array[Dictionary] = _death_rewards_between_states(before_state, after_state)
	if rewards.is_empty():
		return
	var displayed_embers: int = _run_engine.held_embers(_run_state) + int(before_state.get("room_embers", 0))
	var displayed_card_plays: int = _card_play_count_for_resolution_state(before_state)
	_ember_count_override = displayed_embers
	_set_stats_label_text(displayed_embers)
	for reward: Dictionary in rewards:
		if int(reward.get("card_plays", 0)) > 0:
			displayed_card_plays += int(reward.get("card_plays", 0))
			await _animate_card_play_reward(displayed_card_plays)
		var ember_amount: int = int(reward.get("embers", 0))
		if ember_amount > 0:
			var next_displayed_embers: int = displayed_embers + ember_amount
			await _animate_ember_reward(reward.get("tile", Vector2i.ZERO), ember_amount, displayed_embers, next_displayed_embers)
			displayed_embers = next_displayed_embers
	_ember_count_override = -1

func _animate_card_play_reward(displayed_card_plays: int) -> void:
	if _play_meter == null or _play_meter_count == null:
		return
	var safe_displayed_card_plays: int = maxi(0, displayed_card_plays)
	_card_play_count_override = safe_displayed_card_plays
	_play_meter_count.text = str(safe_displayed_card_plays)
	_play_meter.pivot_offset = _play_meter.size * 0.5
	_play_meter_count.add_theme_color_override("font_color", Color("ffe27a"))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_play_meter, "scale", Vector2(1.14, 1.14), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_play_meter, "modulate", Color(1.0, 0.84, 0.46, 1.0), 0.11)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(_play_meter, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(_play_meter, "modulate", Color.WHITE, 0.18)
	await settle.finished
	_play_meter_count.add_theme_color_override("font_color", Color("fff4dc"))

func _animate_intensity_gain(element_id: String, displayed_value: int) -> void:
	if not ElementData.is_elemental(element_id):
		return
	var badge: PanelContainer = _intensity_badges.get(element_id, null)
	var label: Label = _intensity_labels.get(element_id, null)
	if badge == null or label == null:
		return
	_refresh_elemental_intensity_bar(_combat_state)
	label.text = str(displayed_value)
	badge.pivot_offset = badge.size * 0.5
	label.add_theme_color_override("font_color", Color("fff4dc"))
	var accent: Color = ElementData.accent(element_id).lightened(0.18)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(badge, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "modulate", Color(accent.r, accent.g, accent.b, 1.0), 0.11)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(badge, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(badge, "modulate", Color.WHITE, 0.20)
	await settle.finished
	label.add_theme_color_override("font_color", Color("fff7df"))

func _animate_ember_reward(source_tile: Vector2i, amount: int, from_count: int, to_count: int) -> void:
	if _card_fx_layer == null:
		return
	var icon_texture: Texture2D = AssetLoader.load_texture(EMBER_ICON_PATH)
	var start: Vector2 = _board_global_position_for_tile(source_tile)
	var target: Vector2 = _ember_counter_target_global_position()
	var mote_count: int = clampi(amount, 1, MAX_EMBER_REWARD_MOTES)
	for mote_index: int in range(mote_count):
		await _animate_ember_mote(icon_texture, start, target, mote_index, mote_count)
		var count_progress: float = float(mote_index + 1) / float(mote_count)
		_ember_count_override = int(round(lerpf(float(from_count), float(to_count), count_progress)))
		_set_stats_label_text(_ember_count_override)
	await _pulse_ember_counter()

func _animate_ember_mote(icon_texture: Texture2D, start: Vector2, target: Vector2, mote_index: int, mote_count: int) -> void:
	_play_sfx(AttackSfxLibrary.entry_for_ember_collect())
	var icon := Sprite2D.new()
	var mote_size: float = 40.0 + float(mote_index % 4) * 3.0
	var texture_size: Vector2 = icon_texture.get_size() if icon_texture != null else Vector2.ONE
	icon.texture = icon_texture
	icon.centered = true
	var source_size: float = maxf(1.0, maxf(texture_size.x, texture_size.y))
	icon.scale = Vector2.ONE * (mote_size / source_size)
	var spread_angle: float = -0.95 + 1.9 * (float(mote_index % 7) / 6.0)
	var spread_radius: float = 8.0 + float((mote_index * 5) % 13)
	var local_start: Vector2 = start - _card_fx_layer.global_position + Vector2(cos(spread_angle), sin(spread_angle)) * spread_radius
	var local_target: Vector2 = target - _card_fx_layer.global_position + Vector2(float((mote_index % 5) - 2) * 3.0, float((mote_index % 3) - 1) * 2.0)
	icon.position = local_start
	_card_fx_layer.add_child(icon)
	var frames: int = 5
	var arc_height: float = 36.0 + float((mote_index * 11) % 22)
	for frame: int in range(frames + 1):
		var t: float = float(frame) / float(frames)
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var arc: Vector2 = Vector2(0.0, -arc_height * sin(t * PI))
		var center: Vector2 = local_start.lerp(local_target, eased) + arc
		icon.position = center
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0 - maxf(0.0, t - 0.86) / 0.14)
		await get_tree().create_timer(0.010).timeout
	icon.queue_free()
	if mote_index < mote_count - 1:
		await get_tree().create_timer(0.006).timeout

func _pulse_ember_counter() -> void:
	stats_label.pivot_offset = stats_label.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(stats_label, "scale", Vector2(1.06, 1.06), 0.08)
	tween.tween_property(stats_label, "modulate", Color(1.0, 0.86, 0.50, 1.0), 0.08)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(stats_label, "scale", Vector2.ONE, 0.16)
	settle.tween_property(stats_label, "modulate", Color.WHITE, 0.16)
	await settle.finished

func _board_global_position_for_tile(tile: Vector2i) -> Vector2:
	return board_view.global_position + board_view.world_position_for_tile(tile)

func _ember_counter_target_global_position() -> Vector2:
	return stats_label.global_position + stats_label.size * 0.5

func _animate_floating_text_presentation(display_state: Dictionary, base_presentation: Dictionary, frames: int = FLOAT_TEXT_FRAMES, frame_seconds: float = FLOAT_TEXT_FRAME_SECONDS) -> void:
	var base_texts: Array = (base_presentation.get("floating_texts", []) as Array).duplicate(true)
	if base_texts.is_empty():
		_render_board_state(display_state, base_presentation)
		await get_tree().create_timer(frame_seconds * float(maxi(1, frames))).timeout
		return
	var frame_count: int = maxi(1, frames)
	for frame: int in range(frame_count):
		var t: float = 1.0 if frame_count == 1 else float(frame) / float(frame_count - 1)
		var presentation: Dictionary = base_presentation.duplicate(true)
		presentation["impact_progress"] = t
		if not (presentation.get("trap_effects", []) as Array).is_empty() and not presentation.has("effect_progress"):
			presentation["effect_progress"] = t
		var animated_texts: Array[Dictionary] = []
		for text_var: Variant in base_texts:
			var text_entry: Dictionary = (text_var as Dictionary).duplicate(true)
			text_entry["rise"] = lerpf(0.0, 14.0, t)
			text_entry["alpha"] = 1.0 if t < 0.72 else clampf(1.0 - ((t - 0.72) / 0.28), 0.0, 1.0)
			animated_texts.append(text_entry)
		presentation["floating_texts"] = animated_texts
		_render_board_state(display_state, presentation)
		await get_tree().create_timer(frame_seconds).timeout

func _fatigue_damage_events_between_states(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_deck: Dictionary = before_state.get("deck", {})
	var after_deck: Dictionary = after_state.get("deck", {})
	var before_cycles: int = int(before_deck.get("cycles", 0))
	var after_cycles: int = int(after_deck.get("cycles", 0))
	var events: Array[Dictionary] = []
	if after_cycles <= before_cycles:
		return events
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var player_tile: Vector2i = after_player.get("pos", before_player.get("pos", Vector2i.ZERO))
	var fatigue_base: int = int(after_deck.get("fatigue_base", before_deck.get("fatigue_base", CombatEngineScript.FATIGUE_BASE_DAMAGE)))
	for cycle: int in range(before_cycles + 1, after_cycles + 1):
		events.append({
			"cycle": cycle,
			"amount": fatigue_base + cycle - 1,
			"tile": player_tile
		})
	return events

func _fatigue_floating_texts_for_events(display_state: Dictionary, fatigue_events: Array[Dictionary]) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	if fatigue_events.is_empty():
		return floats
	var player_tile: Vector2i = (display_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var total_damage: int = 0
	for event_var: Variant in fatigue_events:
		var event: Dictionary = event_var
		total_damage += maxi(0, int(event.get("amount", 0)))
		player_tile = event.get("tile", player_tile)
	if total_damage > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d" % total_damage,
			"color": Color("f39779"),
			"offset": -36.0,
			"x_offset": -34.0,
			"width": 84.0,
			"font_size": 20,
			"outline_size": 2,
			"outline_color": Color("270806")
		})
	floats.append({
		"tile": player_tile,
		"text": "fatigue sets in",
		"color": Color("ff695f"),
		"offset": -4.0,
		"x_offset": 20.0,
		"width": 152.0,
		"font_size": 16,
		"outline_size": 2,
		"outline_color": Color("270806")
	})
	return floats

func _fatigue_damage_presentation_for_progress(display_state: Dictionary, fatigue_events: Array[Dictionary], progress: float) -> Dictionary:
	var base_texts: Array[Dictionary] = _fatigue_floating_texts_for_events(display_state, fatigue_events)
	var animated_texts: Array[Dictionary] = []
	var t: float = clampf(progress, 0.0, 1.0)
	for text_var: Variant in base_texts:
		var text_entry: Dictionary = (text_var as Dictionary).duplicate(true)
		text_entry["rise"] = lerpf(0.0, 18.0, t)
		text_entry["alpha"] = 1.0 if t < 0.66 else clampf(1.0 - ((t - 0.66) / 0.34), 0.0, 1.0)
		animated_texts.append(text_entry)
	return {
		"impact_actor_keys": ["player"],
		"impact_progress": t,
		"impact_strength": 1.35,
		"floating_texts": animated_texts
	}

func _animate_fatigue_damage(display_state: Dictionary, fatigue_events: Array[Dictionary]) -> void:
	if fatigue_events.is_empty():
		return
	var frame_count: int = maxi(1, FATIGUE_EFFECT_FRAMES)
	for frame: int in range(frame_count):
		var t: float = 1.0 if frame_count == 1 else float(frame) / float(frame_count - 1)
		_set_fatigue_edge_progress(minf(t, FATIGUE_EDGE_HOLD_PROGRESS))
		_render_board_state(display_state, _fatigue_damage_presentation_for_progress(display_state, fatigue_events, t))
		await get_tree().create_timer(FATIGUE_EFFECT_FRAME_SECONDS).timeout
	for linger_frame: int in range(FATIGUE_EDGE_LINGER_FRAMES):
		var linger_t: float = float(linger_frame + 1) / float(FATIGUE_EDGE_LINGER_FRAMES)
		_set_fatigue_edge_progress(lerpf(FATIGUE_EDGE_HOLD_PROGRESS, 1.0, linger_t))
		await get_tree().create_timer(FATIGUE_EFFECT_FRAME_SECONDS).timeout
	_set_fatigue_edge_progress(-1.0)
	_render_board_state(display_state, {})

func _set_fatigue_edge_progress(progress: float) -> void:
	if _fatigue_edge_overlay == null:
		return
	_fatigue_edge_overlay.progress = progress

func _animate_player_card_resolution(animated_state: Dictionary, card_id: String, actions: Array, selected_targets: Array[Vector2i]) -> void:
	var target_index: int = 0
	for action_var: Variant in actions:
		var action: Dictionary = action_var
		if not _combat_engine.player_action_can_resolve(animated_state, action):
			continue
		var target_tile: Vector2i = INVALID_TARGET_TILE
		if _combat_engine.player_action_needs_target(action):
			if target_index < selected_targets.size():
				target_tile = selected_targets[target_index]
			target_index += 1
		var before_state: Dictionary = animated_state.duplicate(true)
		var after_state: Dictionary = _combat_engine.apply_player_action(animated_state, action, target_tile)
		await _animate_player_action_step(before_state, after_state, card_id, action, target_tile)
		animated_state = after_state
	_render_board_state(animated_state, {})
	await get_tree().create_timer(0.04).timeout

func _attack_impact_presentation(base_presentation: Dictionary) -> Dictionary:
	var impact_presentation: Dictionary = base_presentation.duplicate(true)
	impact_presentation.erase("effect")
	impact_presentation.erase("effect_progress")
	return impact_presentation

func _animate_player_trap_result(after_state: Dictionary, before_state: Dictionary, trap_effects: Array[Dictionary], base_presentation: Dictionary) -> void:
	if trap_effects.is_empty():
		return
	var presentation: Dictionary = base_presentation.duplicate(true)
	presentation["trap_effects"] = trap_effects
	presentation["floating_texts"] = _player_action_floating_texts(before_state, after_state)
	presentation["impact_actor_keys"] = _player_action_impact_actor_keys(before_state, after_state)
	await _animate_floating_text_presentation(after_state, presentation)

func _animate_player_action_step(before_state: Dictionary, after_state: Dictionary, card_id: String, action: Dictionary, target_tile: Vector2i) -> void:
	var action_type: String = str(action.get("type", ""))
	if _combat_engine.player_action_needs_target(action) and target_tile.x < 0:
		return
	var player_before: Dictionary = before_state.get("player", {})
	var player_after: Dictionary = after_state.get("player", {})
	var player_before_tile: Vector2i = player_before.get("pos", Vector2i.ZERO)
	var player_after_tile: Vector2i = player_after.get("pos", player_before_tile)
	var triggered_traps: Array[Dictionary] = _triggered_traps_between(before_state, after_state)
	var base_presentation: Dictionary = {
		"focus_actor_keys": ["player"],
		"focus_actor_color": PLAYER_PREVIEW_FOCUS if action_type in ["move", "blink"] else PLAYER_ATTACK_FOCUS
	}
	match action_type:
		"move":
			var move_path: Array[Vector2i] = PathUtils.find_path(before_state.get("grid", []), player_before_tile, player_after_tile, _enemy_occupied_tiles(before_state))
			var from_point: Vector2 = board_view.world_position_for_tile(player_before_tile)
			var to_point: Vector2 = board_view.world_position_for_tile(player_after_tile)
			_set_action_banner(_player_action_label(card_id, action, before_state))
			for frame: int in range(1, MOVE_STEP_FRAMES + 1):
				var t: float = float(frame) / float(MOVE_STEP_FRAMES)
				var presentation: Dictionary = base_presentation.duplicate(true)
				presentation["focus_tiles"] = move_path
				presentation["focus_color"] = Color(0.42, 0.84, 0.93, 0.24)
				presentation["unit_world_positions"] = {"player": from_point.lerp(to_point, t)}
				presentation["unit_draw_tiles"] = {"player": player_after_tile}
				_render_board_state(before_state, presentation)
				await get_tree().create_timer(MOVE_FRAME_SECONDS).timeout
			_render_board_state(after_state, base_presentation)
			await get_tree().create_timer(0.06).timeout
			await _animate_player_trap_result(after_state, before_state, triggered_traps, base_presentation)
		"blink":
			_set_action_banner(_player_action_label(card_id, action, before_state))
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				_render_board_state(before_state, {
					"focus_actor_keys": ["player"],
					"focus_actor_color": PLAYER_PREVIEW_FOCUS,
					"focus_tiles": [player_after_tile],
					"focus_color": Color(0.53, 0.48, 0.92, 0.24),
					"effect": {"kind": "blink", "from": player_before_tile, "to": player_after_tile},
					"effect_progress": t
				})
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			_render_board_state(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"focus_tiles": [player_after_tile],
				"focus_color": Color(0.53, 0.48, 0.92, 0.24),
				"effect": {"kind": "blink", "from": player_before_tile, "to": player_after_tile},
				"effect_progress": 1.0
			})
			await get_tree().create_timer(0.14).timeout
			await _animate_player_trap_result(after_state, before_state, triggered_traps, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"focus_tiles": [player_after_tile],
				"focus_color": Color(0.53, 0.48, 0.92, 0.24)
			})
		"illusion":
			var focus_tiles: Array[Vector2i] = _vector2i_array([target_tile])
			_set_action_banner(_player_action_label(card_id, action, before_state))
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				_render_board_state(before_state, {
					"focus_actor_keys": ["player"],
					"focus_actor_color": PLAYER_PREVIEW_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.40, 0.86, 0.94, 0.18 + 0.12 * t)
				})
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"focus_tiles": focus_tiles,
				"focus_color": Color(0.40, 0.86, 0.94, 0.26),
				"floating_texts": [{
					"tile": target_tile,
					"text": "+%d illusion" % int(action.get("health", action.get("amount", 0))),
					"color": Color("9beeff"),
					"offset": -6.0
				}]
			})
		"melee", "ranged", "aoe", "push", "pull":
			var effect_target_tile: Vector2i = target_tile
			if action_type == "aoe" and int(action.get("range", 0)) <= 0:
				effect_target_tile = player_before_tile
			var focus_tiles: Array[Vector2i] = _vector2i_array([effect_target_tile])
			if action_type == "aoe":
				focus_tiles = _aoe_tiles_for_action(before_state, action, effect_target_tile)
			var effect := {
				"kind": "ranged" if action_type in ["push", "pull"] else action_type,
				"from": player_before_tile,
				"to": effect_target_tile,
				"center": effect_target_tile,
				"tiles": focus_tiles,
				"element": str(action.get("element", action.get("_card_element", ElementData.NONE))),
				"force_tiles": _combat_engine.forced_movement_tiles_for_player_action(before_state, action, target_tile)
			}
			_set_action_banner(_player_action_label(card_id, action, before_state))
			_play_sfx(AttackSfxLibrary.entry_for_player_action(_card_def(card_id, before_state), action))
			var from_point: Vector2 = board_view.world_position_for_tile(player_before_tile)
			var to_point: Vector2 = board_view.world_position_for_tile(effect_target_tile)
			for frame: int in range(1, ATTACK_FRAMES + 1):
				var t: float = float(frame) / float(ATTACK_FRAMES)
				var presentation := {
					"focus_actor_keys": ["player"],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.95, 0.62, 0.37, 0.22),
					"effect": effect,
					"effect_progress": t
				}
				if action_type == "melee":
					presentation["unit_world_positions"] = {
						"player": from_point.lerp(to_point, 0.10 + sin(t * PI) * 0.24)
					}
					presentation["unit_draw_tiles"] = {"player": effect_target_tile}
				_render_board_state(before_state, presentation)
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			await _animate_floating_text_presentation(after_state, _attack_impact_presentation({
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_ATTACK_FOCUS,
				"focus_tiles": focus_tiles,
				"focus_color": Color(0.95, 0.62, 0.37, 0.22),
				"effect": effect,
				"effect_progress": 1.0,
				"impact_actor_keys": _player_action_impact_actor_keys(before_state, after_state),
				"trap_effects": triggered_traps,
				"floating_texts": _player_action_floating_texts(before_state, after_state)
			}))
		"block":
			var block_gain: int = int(player_after.get("block", 0)) - int(player_before.get("block", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			_play_sfx(AttackSfxLibrary.entry_for_block_action(_card_def(card_id, before_state), action))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"effect": {"kind": "block", "tile": player_after_tile},
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d" % block_gain,
					"color": Color("90d9ff"),
					"offset": -6.0
				}]
			})
		"stoneskin":
			var skin_gain: int = int(player_after.get("stoneskin", 0)) - int(player_before.get("stoneskin", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d S" % skin_gain,
					"color": ElementData.accent(ElementData.EARTH),
					"offset": -6.0
				}]
			})
		"heal":
			var heal_amount: int = int(player_after.get("hp", 0)) - int(player_before.get("hp", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"effect": {"kind": "heal", "tile": player_after_tile},
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d" % heal_amount,
					"color": Color("9ee27e"),
					"offset": -6.0
				}]
			})
		"draw":
			var draw_amount: int = int(((after_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size()) - int(((before_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size())
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d draw" % maxi(1, draw_amount),
					"color": Color("f1d18b"),
					"offset": -6.0
				}]
			})
			await _animate_draw_cards_fx(_draw_entries_between_states(before_state, after_state))
			await get_tree().create_timer(0.12).timeout
		"card_play":
			var card_plays_gained: int = maxi(0, _card_play_count_for_resolution_state(after_state) - _card_play_count_for_resolution_state(before_state))
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d play" % maxi(1, card_plays_gained),
					"color": Color("ffe27a"),
					"offset": -6.0
				}]
			})
			await _animate_card_play_reward(_card_play_count_for_resolution_state(after_state))
			await get_tree().create_timer(0.10).timeout
		"intensity":
			var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
			var before_value: int = _combat_engine.elemental_intensity(before_state, element_id)
			var after_value: int = _combat_engine.elemental_intensity(after_state, element_id)
			var gained: int = maxi(0, after_value - before_value)
			_set_action_banner(_player_action_label(card_id, action, before_state))
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_PREVIEW_FOCUS,
				"floating_texts": [{
					"tile": player_after_tile,
					"text": "+%d %s" % [gained, ElementData.name(element_id)],
					"color": ElementData.accent(element_id),
					"offset": -6.0
				}]
			})
			await _animate_intensity_gain(element_id, after_value)
			await get_tree().create_timer(0.08).timeout
	await _animate_death_rewards(before_state, after_state)

func _resolve_enemy_round() -> void:
	_animation_lock = true
	_refresh_ui()
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var previous_combat_state: Dictionary = _combat_state.duplicate(true)
	var previous_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var scheduled_state: Dictionary = _combat_engine.finish_player_activation(_combat_state)
	await _animate_turn_order_transition_between_states(_combat_state, scheduled_state)
	_combat_state = scheduled_state.duplicate(true)
	var phase_result: Dictionary = _combat_engine.advance_to_next_player_turn_with_steps(scheduled_state)
	var animated_state: Dictionary = scheduled_state.duplicate(true)
	await _animate_enemy_phase_steps(animated_state, phase_result.get("steps", []))
	_board_presentation.clear()
	_set_action_banner("")
	_combat_state = (phase_result.get("state", {}) as Dictionary).duplicate(true)
	_analytics_log_enemy_status_ticks(phase_result)
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	var before_draw_state: Dictionary = (phase_result.get("player_turn_before_state", {}) as Dictionary).duplicate(true)
	if outcome == "" and not before_draw_state.is_empty():
		var fatigue_events: Array[Dictionary] = _fatigue_damage_events_between_states(before_draw_state, _combat_state)
		_analytics_reconcile_combat_tracker(before_draw_state, _combat_state)
		_analytics_log_card_draws(before_draw_state, _combat_state, previous_tracker, _analytics_snapshot_combat_tracker(), "turn_draw")
		_analytics_log_playable_cards()
		if not fatigue_events.is_empty():
			await _animate_fatigue_damage(_combat_state, fatigue_events)
		await _animate_draw_cards_fx(_draw_entries_between_states(before_draw_state, _combat_state))
		outcome = _combat_engine.combat_outcome(_combat_state)
	var transition_combat_state: Dictionary = _combat_state.duplicate(true)
	if outcome == "":
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
	_sync_combat_state_from_run()
	_analytics_log_combat_transition(previous_run_state, "enemy_round", transition_combat_state)
	_animation_lock = false
	_refresh_ui()

func _animate_enemy_phase_steps(animated_state: Dictionary, steps: Array) -> void:
	if steps.is_empty():
		return
	for step_var: Variant in steps:
		var step: Dictionary = step_var
		var step_actor_key: String = str(step.get("actor_key", ""))
		var step_actor_tile: Vector2i = step.get("tile", step.get("from", Vector2i(-1, -1)))
		match str(step.get("kind", "")):
			"turn_order":
				await _animate_turn_order_transition(_turn_order_array(step.get("before_order", [])), _turn_order_array(step.get("after_order", [])))
			"intent":
				_clear_enemy_block_by_key(animated_state, step_actor_key)
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("intent_name", ""))])
				_render_board_state(animated_state, {
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": [step_actor_tile],
					"focus_color": Color(0.95, 0.62, 0.37, 0.18)
				})
				await get_tree().create_timer(0.20).timeout
			"move":
				await _animate_move_step(animated_state, step)
			"block", "heal", "stoneskin", "status", "status_damage":
				_apply_animation_step(animated_state, step)
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
				if str(step.get("kind", "")) == "block":
					_play_sfx(AttackSfxLibrary.entry_for_enemy_step(step))
				await _animate_floating_text_presentation(animated_state, {
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": [step.get("tile", Vector2i(-1, -1))],
					"focus_color": Color(0.95, 0.62, 0.37, 0.18),
					"effect": step,
					"floating_texts": _floating_texts_for_step(step)
				})
			"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
				var focus_tiles: Array[Vector2i] = _vector2i_array([step.get("to", Vector2i(-1, -1))])
				if str(step.get("kind", "")) in ["aoe", "lightning_strikes"]:
					focus_tiles = _vector2i_array(step.get("tiles", []))
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
				_play_sfx(AttackSfxLibrary.entry_for_enemy_step(step))
				var from_point: Vector2 = board_view.world_position_for_tile(step.get("from", Vector2i.ZERO))
				var to_point: Vector2 = board_view.world_position_for_tile(step.get("to", Vector2i.ZERO))
				for frame: int in range(1, ATTACK_FRAMES + 1):
					var t: float = float(frame) / float(ATTACK_FRAMES)
					var presentation := {
						"focus_actor_keys": [step_actor_key],
						"focus_actor_color": PLAYER_ATTACK_FOCUS,
						"focus_tiles": focus_tiles,
						"focus_color": Color(0.95, 0.62, 0.37, 0.18),
						"effect": step,
						"effect_progress": t
					}
					if str(step.get("kind", "")) == "melee":
						presentation["unit_world_positions"] = {
							step_actor_key: from_point.lerp(to_point, 0.08 + sin(t * PI) * 0.22)
						}
						presentation["unit_draw_tiles"] = {
							step_actor_key: step.get("to", Vector2i.ZERO)
						}
					_render_board_state(animated_state, presentation)
					await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
				_apply_animation_step(animated_state, step)
				var impact_actor_keys: Array = step.get("impact_actor_keys", [])
				if impact_actor_keys.is_empty() and (int(step.get("hp_loss", 0)) > 0 or int(step.get("block_loss", 0)) > 0 or int(step.get("stoneskin_loss", 0)) > 0):
					impact_actor_keys = ["player"]
				await _animate_floating_text_presentation(animated_state, _attack_impact_presentation({
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.95, 0.62, 0.37, 0.18),
					"effect": step,
					"effect_progress": 1.0,
					"trap_effects": step.get("triggered_traps", []),
					"impact_actor_keys": impact_actor_keys,
					"floating_texts": _floating_texts_for_step(step)
				}))

func _animate_move_step(animated_state: Dictionary, step: Dictionary) -> void:
	var from_tile: Vector2i = step.get("from", Vector2i.ZERO)
	var to_tile: Vector2i = step.get("to", Vector2i.ZERO)
	var actor_key: String = str(step.get("actor_key", ""))
	var actor_unit: Dictionary = _animation_actor_unit(animated_state, actor_key)
	var from_point: Vector2 = board_view.world_position_for_unit_origin(actor_unit, from_tile)
	var to_point: Vector2 = board_view.world_position_for_unit_origin(actor_unit, to_tile)
	var draw_tile: Vector2i = board_view.draw_tile_for_unit_origin(actor_unit, to_tile)
	_apply_animation_step(animated_state, step)
	_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	for frame: int in range(1, MOVE_STEP_FRAMES + 1):
		var t: float = float(frame) / float(MOVE_STEP_FRAMES)
		_render_board_state(animated_state, {
			"focus_actor_keys": [actor_key],
			"focus_actor_color": PLAYER_ATTACK_FOCUS,
			"focus_tiles": [to_tile],
			"focus_color": Color(0.95, 0.62, 0.37, 0.18),
			"unit_world_positions": {actor_key: from_point.lerp(to_point, t)},
			"unit_draw_tiles": {actor_key: draw_tile}
		})
		await get_tree().create_timer(MOVE_FRAME_SECONDS).timeout
	_render_board_state(animated_state, {})
	await get_tree().create_timer(0.06).timeout

func _play_sfx(entry: Dictionary) -> void:
	var path: String = str(entry.get("path", ""))
	if path.is_empty():
		return
	var resource: Resource = load(path)
	if not (resource is AudioStream):
		return
	var player := AudioStreamPlayer.new()
	player.stream = resource as AudioStream
	player.volume_db = float(entry.get("volume_db", 0.0))
	add_child(player)
	player.play()
	var duration: float = float(entry.get("duration", 0.0))
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(_stop_attack_sfx_player.bind(player))
	else:
		player.finished.connect(player.queue_free)

func _stop_attack_sfx_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.queue_free()

func _update_music_for_context(room: Dictionary) -> void:
	_play_music(MusicLibrary.entry_for_context(str(_run_state.get("mode", "room")), room, _combat_state))

func _play_music(entry: Dictionary) -> void:
	var track_id: String = str(entry.get("id", ""))
	if track_id == _active_music_id:
		return
	_ensure_music_player()
	if track_id.is_empty():
		_fade_out_music()
		return
	var path: String = str(entry.get("path", ""))
	var resource: Resource = load(path)
	if not (resource is AudioStream):
		_fade_out_music()
		return
	_music_player.stream = resource as AudioStream
	_active_music_id = track_id
	_stop_music_tween()
	_music_player.volume_db = MUSIC_SILENCE_DB
	_music_player.play()
	_fade_music_to(float(entry.get("volume_db", -12.0)))

func _ensure_music_player() -> void:
	if _music_player != null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	if _music_player == null or _active_music_id.is_empty() or _music_player.stream == null:
		return
	_music_player.play()

func _fade_music_to(volume_db: float) -> void:
	if _music_player == null:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", volume_db, MUSIC_FADE_SECONDS)

func _fade_out_music() -> void:
	if _music_player == null or _music_player.stream == null:
		_active_music_id = ""
		return
	_active_music_id = ""
	_stop_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_SILENCE_DB, MUSIC_FADE_SECONDS)
	_music_tween.finished.connect(_finish_music_fade_out)

func _finish_music_fade_out() -> void:
	if _music_player == null or not _active_music_id.is_empty():
		return
	_music_player.stop()
	_music_player.stream = null

func _stop_music_tween() -> void:
	if _music_tween == null:
		return
	if _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

func _render_board_state(display_state: Dictionary, presentation: Dictionary) -> void:
	var rendered_presentation: Dictionary = presentation.duplicate(true)
	rendered_presentation["active_door_tiles"] = _active_door_tiles_for_board()
	rendered_presentation["locked_door_tiles"] = _locked_door_tiles_for_board()
	rendered_presentation["equipped_equipment"] = _equipped_equipment_for_board()
	board_view.set_combat_state(
		display_state,
		[],
		[],
		(display_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		"",
		"",
		{},
		{},
		rendered_presentation
	)

func _equipped_equipment_for_board() -> Dictionary:
	return (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)

func _apply_animation_step(animated_state: Dictionary, step: Dictionary) -> void:
	match str(step.get("kind", "")):
		"move":
			_set_enemy_pos_by_key(animated_state, str(step.get("actor_key", "")), step.get("to", Vector2i.ZERO))
		"block":
			_add_enemy_block_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"stoneskin":
			_add_enemy_stoneskin_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"heal":
			_add_enemy_heal_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"status_damage":
			_apply_enemy_damage_by_key(animated_state, str(step.get("actor_key", "")), int(step.get("amount", 0)))
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var target_losses: Array = step.get("target_losses", [])
			if target_losses.is_empty():
				_apply_player_losses(animated_state, int(step.get("hp_loss", 0)), int(step.get("block_loss", 0)), int(step.get("stoneskin_loss", 0)))
			else:
				_apply_actor_losses(animated_state, target_losses)
			if step.has("player_to"):
				_set_player_pos(animated_state, step.get("player_to", Vector2i.ZERO))
			_apply_terrain_losses(animated_state, step.get("terrain_losses", []))
			_remove_triggered_traps(animated_state, step.get("triggered_traps", []))

func _floating_texts_for_step(step: Dictionary) -> Array[Dictionary]:
	match str(step.get("kind", "")):
		"block":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "+%d" % int(step.get("amount", 0)),
				"color": Color("90d9ff"),
				"offset": -6.0
			}]
		"stoneskin":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "+%d S" % int(step.get("amount", 0)),
				"color": ElementData.accent(ElementData.EARTH),
				"offset": -6.0
			}]
		"heal":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "+%d" % int(step.get("amount", 0)),
				"color": Color("9ee27e"),
				"offset": -6.0
			}]
		"status":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": str(step.get("text", step.get("label", ""))),
				"color": Color("f1d18b"),
				"offset": -6.0
			}]
		"status_damage":
			return [{
				"tile": step.get("tile", Vector2i.ZERO),
				"text": "-%d" % int(step.get("amount", 0)),
				"color": Color("f39779"),
				"offset": -6.0
			}]
		"melee", "ranged", "aoe", "push", "pull", "lightning_strikes":
			var target_losses: Array = step.get("target_losses", [])
			var terrain_losses: Array = step.get("terrain_losses", [])
			var floats: Array[Dictionary] = []
			if not target_losses.is_empty():
				floats.append_array(_floating_texts_for_target_losses(target_losses, str(step.get("status_text", "")), step.get("to", Vector2i.ZERO)))
			else:
				if int(step.get("hp_loss", 0)) > 0:
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": "-%d" % int(step.get("hp_loss", 0)),
						"color": Color("f39779"),
						"offset": -10.0
					})
				if int(step.get("block_loss", 0)) > 0:
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": "-%d B" % int(step.get("block_loss", 0)),
						"color": Color("90d9ff"),
						"offset": 10.0
					})
				if int(step.get("stoneskin_loss", 0)) > 0:
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": "-%d S" % int(step.get("stoneskin_loss", 0)),
						"color": ElementData.accent(ElementData.EARTH),
						"offset": 22.0
					})
				if not str(step.get("status_text", "")).is_empty():
					floats.append({
						"tile": step.get("to", Vector2i.ZERO),
						"text": str(step.get("status_text", "")),
						"color": Color("f1d18b"),
						"offset": -24.0
					})
			floats.append_array(_floating_texts_for_terrain_losses(terrain_losses))
			return floats
		_:
			return []

func _floating_texts_for_target_losses(target_losses: Array, status_text: String = "", status_tile: Vector2i = Vector2i.ZERO) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	for loss_var: Variant in target_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var tile: Vector2i = loss.get("tile", Vector2i.ZERO)
		if int(loss.get("hp_loss", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "-%d" % int(loss.get("hp_loss", 0)),
				"color": Color("f39779"),
				"offset": -10.0
			})
		if int(loss.get("block_loss", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "-%d B" % int(loss.get("block_loss", 0)),
				"color": Color("90d9ff"),
				"offset": 10.0
			})
		if int(loss.get("stoneskin_loss", 0)) > 0:
			floats.append({
				"tile": tile,
				"text": "-%d S" % int(loss.get("stoneskin_loss", 0)),
				"color": ElementData.accent(ElementData.EARTH),
				"offset": 22.0
			})
		if str(loss.get("kind", "")) == "player":
			status_tile = tile
	if not status_text.is_empty():
		floats.append({
			"tile": status_tile,
			"text": status_text,
			"color": Color("f1d18b"),
			"offset": -24.0
		})
	return floats

func _floating_texts_for_terrain_losses(terrain_losses: Array) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	for loss_var: Variant in terrain_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var hp_loss: int = int(loss.get("hp_loss", loss.get("amount", 0)))
		if hp_loss <= 0:
			continue
		floats.append({
			"tile": loss.get("tile", Vector2i.ZERO),
			"text": "-%d" % hp_loss,
			"color": Color("f0c85c"),
			"offset": -4.0
		})
	return floats

func _terrain_target_losses_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_by_id: Dictionary = {}
	for after_terrain_var: Variant in after_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var
		after_by_id[str(after_terrain.get("id", ""))] = after_terrain
	var losses: Array[Dictionary] = []
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var
		if int(before_terrain.get("hp", 0)) <= 0:
			continue
		var terrain_id: String = str(before_terrain.get("id", ""))
		var after_terrain: Dictionary = after_by_id.get(terrain_id, before_terrain)
		var hp_loss: int = int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0))
		if hp_loss <= 0:
			continue
		losses.append({
			"key": "terrain_%s" % terrain_id,
			"kind": str(before_terrain.get("kind", "terrain")),
			"id": terrain_id,
			"tile": before_terrain.get("pos", Vector2i.ZERO),
			"hp_loss": hp_loss,
			"amount": hp_loss
		})
	return losses

func _triggered_traps_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var after_ids: Dictionary = {}
	for after_trap_var: Variant in after_state.get("traps", []):
		if typeof(after_trap_var) != TYPE_DICTIONARY:
			continue
		var after_trap: Dictionary = after_trap_var
		after_ids[str(after_trap.get("id", ""))] = true
	var triggered: Array[Dictionary] = []
	for before_trap_var: Variant in before_state.get("traps", []):
		if typeof(before_trap_var) != TYPE_DICTIONARY:
			continue
		var before_trap: Dictionary = (before_trap_var as Dictionary).duplicate(true)
		var trap_id: String = str(before_trap.get("id", ""))
		if trap_id.is_empty() or after_ids.has(trap_id):
			continue
		triggered.append(before_trap)
	return triggered

func _set_enemy_pos_by_key(state: Dictionary, actor_key: String, pos: Vector2i) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["pos"] = pos
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _add_enemy_block_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["block"] = int(enemy.get("block", 0)) + amount
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _clear_enemy_block_by_key(state: Dictionary, actor_key: String) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["block"] = 0
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _add_enemy_heal_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["hp"] = mini(int(enemy.get("max_hp", 1)), int(enemy.get("hp", 0)) + amount)
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _add_enemy_stoneskin_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["stoneskin"] = int(enemy.get("stoneskin", 0)) + amount
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _apply_enemy_damage_by_key(state: Dictionary, actor_key: String, amount: int) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		if _enemy_key(enemy) != actor_key:
			continue
		enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - amount)
		(state.get("enemies", []) as Array)[enemy_index] = enemy
		return

func _apply_player_losses(state: Dictionary, hp_loss: int, block_loss: int, stoneskin_loss: int = 0) -> void:
	var player: Dictionary = state.get("player", {})
	player["block"] = maxi(0, int(player.get("block", 0)) - block_loss)
	player["stoneskin"] = maxi(0, int(player.get("stoneskin", 0)) - stoneskin_loss)
	player["hp"] = maxi(0, int(player.get("hp", 0)) - hp_loss)
	state["player"] = player

func _apply_actor_losses(state: Dictionary, target_losses: Array) -> void:
	for loss_var: Variant in target_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		match str(loss.get("kind", "")):
			"player":
				_apply_player_losses(state, int(loss.get("hp_loss", 0)), int(loss.get("block_loss", 0)), int(loss.get("stoneskin_loss", 0)))
			"illusion":
				_apply_illusion_loss_by_key(state, str(loss.get("key", "")), int(loss.get("hp_loss", 0)))

func _apply_terrain_losses(state: Dictionary, terrain_losses: Array) -> void:
	if terrain_losses.is_empty():
		return
	var terrain_entries: Array = (state.get("terrain", []) as Array).duplicate(true)
	for loss_var: Variant in terrain_losses:
		if typeof(loss_var) != TYPE_DICTIONARY:
			continue
		var loss: Dictionary = loss_var
		var terrain_id: String = str(loss.get("id", ""))
		if terrain_id.is_empty():
			continue
		for terrain_index: int in range(terrain_entries.size()):
			var terrain: Dictionary = terrain_entries[terrain_index]
			if str(terrain.get("id", "")) != terrain_id:
				continue
			terrain["hp"] = maxi(0, int(terrain.get("hp", 0)) - int(loss.get("hp_loss", loss.get("amount", 0))))
			terrain_entries[terrain_index] = terrain
			break
	state["terrain"] = terrain_entries

func _remove_triggered_traps(state: Dictionary, triggered_traps: Array) -> void:
	if triggered_traps.is_empty():
		return
	var triggered_ids: Dictionary = {}
	for trap_var: Variant in triggered_traps:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap_id: String = str((trap_var as Dictionary).get("id", ""))
		if not trap_id.is_empty():
			triggered_ids[trap_id] = true
	if triggered_ids.is_empty():
		return
	var remaining: Array = []
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var trap: Dictionary = trap_var
		if triggered_ids.has(str(trap.get("id", ""))):
			continue
		remaining.append(trap)
	state["traps"] = remaining

func _apply_illusion_loss_by_key(state: Dictionary, actor_key: String, hp_loss: int) -> void:
	if actor_key.is_empty() or hp_loss <= 0:
		return
	for illusion_index: int in range((state.get("illusions", []) as Array).size()):
		var illusion: Dictionary = (state.get("illusions", []) as Array)[illusion_index]
		var key: String = "illusion_%d" % int(illusion.get("id", -1))
		if key != actor_key:
			continue
		illusion["hp"] = maxi(0, int(illusion.get("hp", 0)) - hp_loss)
		(state.get("illusions", []) as Array)[illusion_index] = illusion
		return

func _set_player_pos(state: Dictionary, pos: Vector2i) -> void:
	var player: Dictionary = state.get("player", {})
	player["pos"] = pos
	state["player"] = player

func _damaged_enemy_keys(before_state: Dictionary, after_state: Dictionary) -> Array[String]:
	var before_by_id: Dictionary = {}
	for enemy_var: Variant in before_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		before_by_id[int(enemy.get("id", -1))] = enemy
	var keys: Array[String] = []
	for enemy_var: Variant in after_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		var enemy_id: int = int(enemy.get("id", -1))
		if not before_by_id.has(enemy_id):
			continue
		var before_enemy: Dictionary = before_by_id[enemy_id]
		var hp_loss: int = int(before_enemy.get("hp", 0)) - int(enemy.get("hp", 0))
		var block_loss: int = int(before_enemy.get("block", 0)) - int(enemy.get("block", 0))
		var stoneskin_loss: int = int(before_enemy.get("stoneskin", 0)) - int(enemy.get("stoneskin", 0))
		if hp_loss > 0 or block_loss > 0 or stoneskin_loss > 0:
			keys.append(_enemy_key(enemy))
	return keys

func _clear_enemy_blocks(state: Dictionary) -> void:
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (state.get("enemies", []) as Array)[enemy_index]
		enemy["block"] = 0
		(state.get("enemies", []) as Array)[enemy_index] = enemy

func _animation_actor_unit(state: Dictionary, actor_key: String) -> Dictionary:
	if actor_key == "player":
		return (state.get("player", {}) as Dictionary).duplicate(true)
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if _enemy_key(enemy) == actor_key:
			return enemy.duplicate(true)
	for illusion_var: Variant in state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var as Dictionary
		var illusion_key: String = "illusion_%d" % int(illusion.get("id", -1))
		if illusion_key == actor_key:
			return illusion.duplicate(true)
	return {"footprint": Vector2i.ONE}

func _set_action_banner(text: String) -> void:
	action_banner.visible = not text.is_empty()
	action_banner.text = text

func _board_status_label(preview: Dictionary) -> String:
	var mode: String = str(_run_state.get("mode", "room"))
	if _animation_lock:
		return ""
	if mode == "combat":
		return ""
	if mode == "room":
		return "Choose door"
	if mode == "reward":
		return "Choose reward"
	if mode == "campfire":
		return "Campfire"
	if mode == "treasure":
		return "Relic"
	if mode == "victory":
		return "Victory"
	if mode == "defeat":
		return "Defeat"
	return ""

func _board_status_detail(preview: Dictionary) -> String:
	var mode: String = str(_run_state.get("mode", "room"))
	if _animation_lock:
		return ""
	if mode == "combat":
		return ""
	if mode == "room":
		return _room_hover_hint()
	return ""

func _room_hover_hint() -> String:
	if _hovered_board_tile.x < 0 or not _exit_destinations_by_tile.has(_hovered_board_tile):
		return ""
	var destination: Vector2i = _exit_destinations_by_tile[_hovered_board_tile]
	var room: Dictionary = _run_engine.room_metadata(_run_state, destination)
	var room_element: String = str(room.get("element", ElementData.NONE))
	var prefix: String = "%s " % ElementData.name(room_element) if ElementData.is_elemental(room_element) else ""
	return "%s%s %d" % [prefix, str(room.get("type", "combat")).capitalize(), int(room.get("depth", 1))]

func _action_prompt(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"move", "blink", "illusion":
			return "Choose tile"
		"aoe":
			return "Choose area" if int(action.get("range", 0)) > 0 else "Resolve"
		"melee", "ranged", "push", "pull":
			return "Choose target"
		_:
			return "Resolve"

func _player_action_label(card_id: String, _action: Dictionary, _state: Dictionary = _combat_state) -> String:
	return str(_card_def(card_id, _state).get("name", card_id))

func _player_action_floating_texts(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var floats: Array[Dictionary] = _player_damage_floating_texts(before_state, after_state)
	floats.append_array(_player_loss_floating_texts(before_state, after_state))
	floats.append_array(_floating_texts_for_terrain_losses(_terrain_target_losses_between(before_state, after_state)))
	return floats

func _player_action_impact_actor_keys(before_state: Dictionary, after_state: Dictionary) -> Array[String]:
	var keys: Array[String] = _damaged_enemy_keys(before_state, after_state)
	if _player_took_loss(before_state, after_state):
		keys.append("player")
	return keys

func _player_took_loss(before_state: Dictionary, after_state: Dictionary) -> bool:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	if int(before_player.get("hp", 0)) > int(after_player.get("hp", 0)):
		return true
	if int(before_player.get("block", 0)) > int(after_player.get("block", 0)):
		return true
	return int(before_player.get("stoneskin", 0)) > int(after_player.get("stoneskin", 0))

func _player_loss_floating_texts(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var player_tile: Vector2i = after_player.get("pos", before_player.get("pos", Vector2i.ZERO))
	var hp_loss: int = int(before_player.get("hp", 0)) - int(after_player.get("hp", 0))
	var block_loss: int = int(before_player.get("block", 0)) - int(after_player.get("block", 0))
	var stoneskin_loss: int = int(before_player.get("stoneskin", 0)) - int(after_player.get("stoneskin", 0))
	var floats: Array[Dictionary] = []
	if hp_loss > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d" % hp_loss,
			"color": Color("f39779"),
			"offset": -10.0
		})
	if block_loss > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d B" % block_loss,
			"color": Color("90d9ff"),
			"offset": 10.0
		})
	if stoneskin_loss > 0:
		floats.append({
			"tile": player_tile,
			"text": "-%d S" % stoneskin_loss,
			"color": ElementData.accent(ElementData.EARTH),
			"offset": 22.0
		})
	return floats

func _player_damage_floating_texts(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var before_by_id: Dictionary = {}
	for enemy_var: Variant in before_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		before_by_id[int(enemy.get("id", -1))] = enemy
	var floats: Array[Dictionary] = []
	for enemy_var: Variant in after_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		var enemy_id: int = int(enemy.get("id", -1))
		if not before_by_id.has(enemy_id):
			continue
		var before_enemy: Dictionary = before_by_id[enemy_id]
		var hp_loss: int = int(before_enemy.get("hp", 0)) - int(enemy.get("hp", 0))
		var block_loss: int = int(before_enemy.get("block", 0)) - int(enemy.get("block", 0))
		var stoneskin_loss: int = int(before_enemy.get("stoneskin", 0)) - int(enemy.get("stoneskin", 0))
		if hp_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d" % hp_loss,
				"color": Color("f39779"),
				"offset": -60.0,
				"x_offset": -24.0,
				"width": 72.0
			})
		if block_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d B" % block_loss,
				"color": Color("90d9ff"),
				"offset": -40.0,
				"x_offset": -24.0,
				"width": 72.0
			})
		if stoneskin_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d S" % stoneskin_loss,
				"color": ElementData.accent(ElementData.EARTH),
				"offset": -20.0,
				"x_offset": -24.0,
				"width": 72.0
			})
	return floats

func _log_text() -> String:
	var notice: String = str(_run_state.get("notice", ""))
	if not _combat_state.is_empty():
		var lines: Array = (_combat_state.get("log", []) as Array).duplicate()
		if not notice.is_empty():
			lines.append(notice)
		while lines.size() > 2:
			lines.remove_at(0)
		return "\n".join(lines)
	if not notice.is_empty():
		return notice
	return ""

func _on_map_view_room_selected(coord: Vector2i, door_tile: Vector2i = INVALID_TARGET_TILE) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "room":
		return
	if not _run_engine.available_moves(_run_state).has(coord):
		return
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var selected_door_tile: Vector2i = door_tile if door_tile.x >= 0 else _door_tile_for_destination(coord)
	_animation_lock = true
	_reset_card_resolution()
	_hovered_board_tile = selected_door_tile
	_refresh_ui()
	if selected_door_tile.x >= 0:
		await _play_door_opening_animation(selected_door_tile)
	_run_state = _run_engine.move_to_room(_run_state, coord)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_analytics_log_combat_transition(previous_run_state, "room_move", _combat_state)
	_board_presentation.clear()
	_animation_lock = false
	_reset_card_resolution()
	_hovered_board_tile = Vector2i(-1, -1)
	_refresh_ui()

func _play_door_opening_animation(door_tile: Vector2i) -> void:
	var frame_count: int = maxi(1, DOOR_OPENING_FRAMES)
	for frame: int in range(frame_count):
		var progress: float = 1.0 if frame_count <= 1 else float(frame) / float(frame_count - 1)
		_board_presentation = {
			"door_opening": {
				"tile": door_tile,
				"frame": frame,
				"progress": progress
			}
		}
		_refresh_stage_view()
		await get_tree().create_timer(DOOR_OPENING_FRAME_SECONDS).timeout
	await get_tree().create_timer(DOOR_OPENING_SETTLE_SECONDS).timeout

func _on_reward_card_pressed(card_id: String) -> void:
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	var player_hp_before: int = int(_run_state.get("player_hp", 0))
	_run_state = _run_engine.claim_card_reward(_run_state, card_id)
	_sync_combat_state_from_run()
	_analytics_log_reward_choice("card", reward_state, card_id, player_hp_before, int(_run_state.get("player_hp", player_hp_before)))
	_refresh_ui()

func _on_skip_reward_pressed() -> void:
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	var player_hp_before: int = int(_run_state.get("player_hp", 0))
	_run_state = _run_engine.skip_reward_for_heal(_run_state)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_analytics_log_reward_choice("heal_skip", reward_state, "", player_hp_before, int(_run_state.get("player_hp", player_hp_before)))
	_refresh_ui()

func _on_campfire_sit_pressed() -> void:
	_on_campfire_embrace_pressed()

func _on_campfire_embrace_pressed() -> void:
	_sync_progression_from_run()
	var held: int = _run_engine.held_embers(_run_state)
	_progression = ProgressionStore.set_embers(_progression, held)
	_progression = ProgressionStore.mark_rested_at_fire(_progression)
	ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_campfire_linger_pressed() -> void:
	_run_state = _run_engine.leave_campfire(_run_state, CAMPFIRE_LINGER_HEAL_AMOUNT)
	_refresh_ui()

func _on_campfire_leave_pressed() -> void:
	_run_state = _run_engine.leave_campfire(_run_state)
	_refresh_ui()

func _on_relic_pressed(relic_id: String) -> void:
	_run_state = _run_engine.claim_relic(_run_state, relic_id)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_refresh_ui()
	await _animate_relic_acquired(relic_id)

func _animate_relic_acquired(relic_id: String) -> void:
	await get_tree().process_frame
	var frame: Control = _relic_frame_for_id(relic_id)
	if frame == null:
		return
	frame.pivot_offset = frame.size * 0.5
	frame.scale = Vector2(0.86, 0.86)
	frame.modulate = Color(1.0, 0.92, 0.62, 1.0)
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(frame, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(frame, "scale", Vector2.ONE, 0.10)
	settle.tween_property(frame, "modulate", Color.WHITE, 0.10)
	await settle.finished

func _relic_frame_for_id(relic_id: String) -> Control:
	if relic_bar == null:
		return null
	for child: Node in relic_bar.get_children():
		if child is Control and str(child.get_meta("relic_id", "")) == relic_id:
			return child as Control
	return null

func _on_back_to_menu_pressed() -> void:
	if not _is_debug_boss_run():
		ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_restart_pressed() -> void:
	if _is_debug_boss_run():
		_start_debug_boss_run()
		return
	ProgressionStore.clear_saved_run()
	_start_run()

func _on_death_continue_pressed() -> void:
	if str(_run_state.get("mode", "room")) != "defeat":
		return
	_on_restart_pressed()

func _on_menu_button_pressed() -> void:
	if _dialogue_active or _animation_lock:
		return
	_open_menu_overlay()

func _on_pass_turn_pressed() -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "combat":
		return
	if not _combat_engine.is_player_turn(_combat_state):
		return
	if _selected_card_index >= 0:
		_cancel_card_selection()
	await _resolve_enemy_round()

func _open_menu_overlay() -> void:
	if _menu_scrim == null:
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_card_upgrade_overlay()
	_menu_scrim.visible = true

func _close_menu_overlay() -> void:
	if _menu_scrim != null:
		_menu_scrim.visible = false

func _committed_run_state() -> Dictionary:
	var state: Dictionary = _run_state.duplicate(true)
	if str(state.get("mode", "")) == "combat":
		state = _run_engine.set_combat_state(state, _combat_state)
	return state

func _is_debug_boss_run() -> bool:
	return bool(_run_state.get("debug_boss_run", false))

func _save_run_progress() -> void:
	if _is_debug_boss_run():
		return
	var mode: String = str(_run_state.get("mode", ""))
	if mode in ["victory", "defeat"] or _run_state.is_empty():
		ProgressionStore.save_data(_progression)
		ProgressionStore.clear_saved_run()
		return
	var saved_progression: Dictionary = _progression.duplicate(true)
	var run_progression: Dictionary = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
	if not run_progression.is_empty():
		saved_progression["embers"] = int(run_progression.get("embers", 0))
	ProgressionStore.save_data(saved_progression)
	ProgressionStore.save_run_state(_committed_run_state())

func _on_save_and_quit_pressed() -> void:
	_close_menu_overlay()
	_save_run_progress()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_exit_to_desktop_pressed() -> void:
	_close_menu_overlay()
	_save_run_progress()
	get_tree().quit()

func _on_abandon_run_pressed() -> void:
	_close_menu_overlay()
	_reset_card_resolution()
	_analytics_log_run_ended("abandoned")
	if not _is_debug_boss_run():
		_sync_progression_from_run()
		_progression = ProgressionStore.record_lost_embers(
			_progression,
			_run_engine.held_embers(_run_state),
			_run_state.get("current_room", Vector2i.ZERO),
			int(_run_state.get("run_index", 0))
		)
		ProgressionStore.save_data(_progression)
		ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_pile_gui_input(event: InputEvent, pile_kind: String) -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "combat" or _selected_card_index >= 0 or _drag_card_index >= 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_pile_view(pile_kind)

func _open_pile_view(pile_kind: String) -> void:
	if _pile_scrim == null:
		return
	_cancel_drag_play()
	_close_card_upgrade_overlay()
	var cards: Array = _cards_for_pile(pile_kind)
	var pile_empty: bool = cards.is_empty()
	_pile_dialog.custom_minimum_size = _pile_dialog_size_for_count(cards.size())
	_active_pile_kind = pile_kind
	_pile_dialog_title.text = "%s Pile" % _pile_display_name(pile_kind)
	_clear_children_now(_pile_dialog_cards)
	for card_id_var: Variant in cards:
		var widget := CardWidgetScene.instantiate() as CardWidget
		widget.configure(str(card_id_var), false, false, true, false, false, true, _card_def(str(card_id_var)))
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pile_dialog_cards.add_child(_scaled_card_slot(widget, PILE_DIALOG_CARD_SIZE))
	if _pile_dialog_scroll != null:
		_pile_dialog_scroll.visible = not pile_empty
	_pile_dialog_empty.text = "No cards in this pile." if pile_empty else ""
	_pile_dialog_empty.visible = pile_empty
	_pile_scrim.visible = true

func _pile_dialog_size_for_count(card_count: int) -> Vector2:
	if card_count <= 0:
		return PILE_DIALOG_EMPTY_SIZE
	var visible_cards: int = mini(card_count, 5)
	var content_width: float = PILE_DIALOG_CARD_SIZE.x * float(visible_cards) + 12.0 * float(maxi(visible_cards - 1, 0)) + 88.0
	var target_size: Vector2 = PILE_DIALOG_ROW_SIZE if card_count <= 5 else PILE_DIALOG_FULL_SIZE
	return Vector2(clampf(content_width, PILE_DIALOG_MIN_CARD_WIDTH, target_size.x), target_size.y)

func _close_pile_view() -> void:
	if _pile_scrim != null:
		_pile_scrim.visible = false
	_active_pile_kind = ""

func _open_card_upgrade_overlay() -> void:
	_open_character_overlay("stats")

func _on_character_stats_pressed() -> void:
	_open_character_overlay("equipment")

func _open_character_stats_overlay() -> void:
	_open_character_overlay("stats")

func _open_character_overlay(mode: String = "equipment") -> void:
	if _upgrade_scrim == null:
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_menu_overlay()
	_progression_overlay_mode = mode if mode in ["equipment", "magic", "stats"] else "equipment"
	_progression_pending_stats.clear()
	_rebuild_progression_overlay()
	_upgrade_scrim.visible = true

func _open_level_up_overlay() -> void:
	if _upgrade_scrim == null or not _can_level_at_campfire():
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_menu_overlay()
	_progression_overlay_mode = "level_up"
	_progression_pending_stats.clear()
	_rebuild_progression_overlay()
	_upgrade_scrim.visible = true

func _close_card_upgrade_overlay() -> void:
	if _upgrade_scrim != null:
		_upgrade_scrim.visible = false
	_progression_overlay_mode = ""
	_progression_pending_stats.clear()
	_clear_equipment_drag_state(true)
	_clear_magic_drag_state(true)

func _rebuild_progression_overlay() -> void:
	if _upgrade_dialog == null:
		return
	_sync_progression_from_run()
	_clear_children_now(_upgrade_dialog)
	var dialog_size: Vector2 = Vector2(1040.0, 560.0) if _progression_overlay_mode == "level_up" else CHARACTER_DIALOG_SIZE
	_upgrade_dialog.custom_minimum_size = dialog_size
	_upgrade_dialog.size = dialog_size
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_upgrade_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Draw Strength" if _progression_overlay_mode == "level_up" else "Character"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 2)
	top_row.add_child(title)

	var summary := Label.new()
	summary.text = _progression_overlay_summary_text()
	UiTypography.set_label_size(summary, UiTypography.SIZE_SMALL)
	summary.add_theme_color_override("font_color", Color("f0c978"))
	summary.add_theme_color_override("font_outline_color", Color("2c1f16"))
	summary.add_theme_constant_override("outline_size", 1)
	top_row.add_child(summary)

	var close_button := Button.new()
	close_button.text = "X"
	_apply_progression_stepper_button_style(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	close_button.custom_minimum_size = Vector2(48.0, 48.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_card_upgrade_overlay)
	top_row.add_child(close_button)

	if _progression_overlay_mode != "level_up":
		vbox.add_child(_build_character_overlay_tabs())

	if _progression_overlay_mode == "equipment":
		vbox.add_child(_build_equipment_overlay_body())
	elif _progression_overlay_mode == "magic":
		vbox.add_child(_build_magic_overlay_body())
	else:
		var body := HBoxContainer.new()
		body.custom_minimum_size = Vector2(0.0, CHARACTER_BODY_HEIGHT)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 16)
		vbox.add_child(body)

		body.add_child(_build_progression_status_panel())
		body.add_child(_build_progression_stat_list())

	if _progression_overlay_mode == "level_up":
		var confirm_row := HBoxContainer.new()
		confirm_row.alignment = BoxContainer.ALIGNMENT_END
		confirm_row.add_theme_constant_override("separation", 10)
		vbox.add_child(confirm_row)

		var cancel_button := Button.new()
		cancel_button.text = "Cancel"
		_apply_progression_command_button_style(cancel_button)
		UiTypography.set_button_size(cancel_button, UiTypography.SIZE_SMALL)
		cancel_button.custom_minimum_size = Vector2(176.0, 52.0)
		cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cancel_button.pressed.connect(_close_card_upgrade_overlay)
		confirm_row.add_child(cancel_button)

		var confirm_button := Button.new()
		var pending_stat_ids: Array[String] = _progression_pending_stat_ids()
		var can_confirm: bool = ProgressionStore.can_purchase_level_with_stats(_progression, pending_stat_ids)
		confirm_button.text = "Confirm"
		confirm_button.disabled = not can_confirm
		_apply_progression_command_button_style(confirm_button)
		UiTypography.set_button_size(confirm_button, UiTypography.SIZE_SMALL)
		confirm_button.custom_minimum_size = Vector2(188.0, 52.0)
		confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if can_confirm:
			confirm_button.pressed.connect(_confirm_level_up)
		confirm_row.add_child(confirm_button)

func _progression_overlay_summary_text() -> String:
	var level: int = int(_progression.get("level", 1))
	var embers: int = int(_progression.get("embers", 0))
	if _progression_overlay_mode == "level_up":
		return "LV %d -> %d   COST %d   EMBERS %d" % [level, mini(level + 1, GameData.max_progression_level()), ProgressionStore.next_level_cost(_progression), embers]
	if _progression_overlay_mode == "equipment":
		var deck_size: int = int((_run_state.get("deck_cards", []) as Array).size())
		var inventory_size: int = int((_run_state.get("equipment_inventory", []) as Array).size())
		return "LV %d   DECK %d   GEAR %d" % [level, deck_size, inventory_size]
	if _progression_overlay_mode == "magic":
		var deck_size: int = int((_run_state.get("deck_cards", []) as Array).size())
		var attuned_size: int = int((_run_state.get("attuned_magic_cards", []) as Array).size())
		var learned_size: int = int((_run_state.get("magic_inventory", []) as Array).size())
		return "LV %d   DECK %d   MAGIC %d/%d   LEARNED %d" % [level, deck_size, mini(attuned_size, GameData.magic_loadout_limit()), GameData.magic_loadout_limit(), learned_size]
	return "LV %d   EMBERS %d" % [level, embers]

func _build_character_overlay_tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for entry: Dictionary in [
		{"mode": "equipment", "text": "Gear"},
		{"mode": "magic", "text": "Magic"},
		{"mode": "stats", "text": "Stats"}
	]:
		var button := Button.new()
		var mode: String = str(entry.get("mode", ""))
		button.text = str(entry.get("text", ""))
		button.toggle_mode = true
		button.button_pressed = _progression_overlay_mode == mode
		button.custom_minimum_size = Vector2(132.0, 42.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_apply_character_tab_style(button, button.button_pressed)
		if _progression_overlay_mode != mode:
			button.pressed.connect(_switch_character_overlay_mode.bind(mode))
		row.add_child(button)
	return row

func _switch_character_overlay_mode(mode: String) -> void:
	if not (mode in ["equipment", "magic", "stats"]):
		return
	_progression_overlay_mode = mode
	_progression_pending_stats.clear()
	_rebuild_progression_overlay()

func _apply_character_tab_style(button: Button, active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.13, 0.08, 0.95) if active else Color(0.10, 0.07, 0.05, 0.90)
	normal.border_color = Color("d7a85d") if active else Color("6d5a46")
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_right = 6
	normal.corner_radius_bottom_left = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("focus", hover)
	_apply_progression_button_text(button, UiTypography.SIZE_SMALL)

func _build_equipment_overlay_body() -> Control:
	_equipment_slot_panels.clear()
	_equipment_inventory_tiles.clear()
	_magic_attuned_tiles.clear()
	_magic_inventory_tiles.clear()
	_magic_attuned_drop_panel = null
	_magic_inventory_drop_panel = null
	var body := HBoxContainer.new()
	body.custom_minimum_size = Vector2(0.0, CHARACTER_BODY_HEIGHT)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	body.add_child(_build_equipment_character_column())
	body.add_child(_build_equipment_inventory_column())
	body.add_child(_build_current_deck_column())
	return body

func _build_magic_overlay_body() -> Control:
	_equipment_slot_panels.clear()
	_equipment_inventory_tiles.clear()
	_magic_attuned_tiles.clear()
	_magic_inventory_tiles.clear()
	_magic_attuned_drop_panel = null
	_magic_inventory_drop_panel = null
	var body := HBoxContainer.new()
	body.custom_minimum_size = Vector2(0.0, CHARACTER_BODY_HEIGHT)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	body.add_child(_build_magic_attuned_column())
	body.add_child(_build_magic_inventory_column())
	body.add_child(_build_current_deck_column())
	return body

func _build_equipment_character_column() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(326.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Loadout"
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)
	vbox.add_child(_build_equipment_portrait_panel())

	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 8)
	vbox.add_child(slots)
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		slots.add_child(_build_equipment_slot_panel(slot, str(equipped.get(slot, ""))))
	return panel

func _build_equipment_portrait_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 144.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(_equipped_equipment_accent(), true))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var art := TextureRect.new()
	art.name = "EquipmentCharacterArt"
	art.texture = AssetLoader.load_texture(PLAYER_UNIT_TEXTURE_PATH)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(150.0, 124.0)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = _equipment_player_art_tint()
	row.add_child(art)

	var icons := HFlowContainer.new()
	icons.custom_minimum_size = Vector2(92.0, 0.0)
	icons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icons.alignment = FlowContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("h_separation", 6)
	icons.add_theme_constant_override("v_separation", 6)
	row.add_child(icons)
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		var equipment_id: String = str(equipped.get(slot, ""))
		if equipment_id.is_empty():
			continue
		icons.add_child(_build_equipment_icon_chip(equipment_id, Vector2(38.0, 38.0)))
	return panel

func _build_equipment_slot_panel(slot: String, equipment_id: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent: Color = Color(GameData.equipment_accent(equipment_id)) if not equipment_id.is_empty() else Color("6d5a46")
	var panel := EquipmentSlotDrop.new()
	panel.slot_id = slot
	panel.host = self
	panel.equipment_id = equipment_id
	panel.custom_minimum_size = EQUIPMENT_SLOT_SIZE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = "equipment:%s" % equipment_id if not equipment_id.is_empty() else _equipment_slot_label(slot)
	var drag_target_slot: String = GameData.equipment_slot(_equipment_drag_id)
	var is_drag_target: bool = not _equipment_drag_id.is_empty() and drag_target_slot == slot
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(accent, is_drag_target))
	if not _equipment_drag_id.is_empty() and drag_target_slot != slot:
		panel.modulate = Color(0.68, 0.68, 0.68, 1.0)
	_equipment_slot_panels[slot] = panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	if not equipment_id.is_empty():
		row.add_child(_build_equipment_icon_chip(equipment_id, EQUIPMENT_ICON_SIZE))
	else:
		var empty_icon := Control.new()
		empty_icon.custom_minimum_size = EQUIPMENT_ICON_SIZE
		row.add_child(empty_icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var slot_label := Label.new()
	slot_label.text = _equipment_slot_label(slot)
	slot_label.clip_text = true
	UiTypography.set_label_size(slot_label, UiTypography.SIZE_SMALL)
	slot_label.add_theme_color_override("font_color", Color("dcc9a9"))
	slot_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	slot_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(slot_label)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "Empty")) if not item.is_empty() else "Empty"
	name_label.clip_text = true
	UiTypography.set_label_size(name_label, UiTypography.SIZE_BODY_LARGE)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)
	if not _equipment_overlay_can_change():
		panel.modulate = Color(0.78, 0.78, 0.78, 1.0)
	return panel

func _build_equipment_inventory_column() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(374.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var count := Label.new()
	count.text = str((_run_state.get("equipment_inventory", []) as Array).size())
	UiTypography.set_label_size(count, UiTypography.SIZE_SMALL)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.alignment = FlowContainer.ALIGNMENT_BEGIN
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var inventory_ids: Array = _equipment_inventory_ids()
	if inventory_ids.is_empty():
		var empty := Label.new()
		empty.text = "No spare gear"
		empty.custom_minimum_size = Vector2(0.0, 80.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTypography.set_label_size(empty, UiTypography.SIZE_SMALL)
		empty.add_theme_color_override("font_color", Color("cdbca2"))
		grid.add_child(empty)
	else:
		for equipment_id_var: Variant in inventory_ids:
			grid.add_child(_build_equipment_inventory_tile(str(equipment_id_var)))
	return panel

func _build_magic_attuned_column() -> Control:
	var panel := PanelContainer.new()
	_magic_attuned_drop_panel = panel
	panel.custom_minimum_size = Vector2(326.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Attuned Magic"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var attuned: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	var count := Label.new()
	count.text = "%d/%d" % [mini(attuned.size(), GameData.magic_loadout_limit()), GameData.magic_loadout_limit()]
	UiTypography.set_label_size(count, UiTypography.SIZE_SMALL)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)

	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 8)
	vbox.add_child(slots)
	for index: int in range(GameData.magic_loadout_limit()):
		var card_id: String = str(attuned[index]) if index < attuned.size() else ""
		slots.add_child(_build_magic_card_tile(card_id, "attuned", index, MAGIC_ATTUNED_TILE_SIZE))
	if not _magic_overlay_can_change():
		var locked := Label.new()
		locked.text = "Locked in combat"
		UiTypography.set_label_size(locked, UiTypography.SIZE_CAPTION)
		locked.add_theme_color_override("font_color", Color("d8a06a"))
		vbox.add_child(locked)
	return panel

func _build_magic_inventory_column() -> Control:
	var panel := PanelContainer.new()
	_magic_inventory_drop_panel = panel
	panel.custom_minimum_size = Vector2(374.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Learned Magic"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	title_row.add_child(title)
	var reserve: Array = (_run_state.get("magic_inventory", []) as Array).duplicate()
	var count := Label.new()
	count.text = str(reserve.size())
	UiTypography.set_label_size(count, UiTypography.SIZE_SMALL)
	count.add_theme_color_override("font_color", Color("f0c978"))
	title_row.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.alignment = FlowContainer.ALIGNMENT_BEGIN
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	if reserve.is_empty():
		var empty := Label.new()
		empty.text = "No learned magic"
		empty.custom_minimum_size = Vector2(0.0, 80.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTypography.set_label_size(empty, UiTypography.SIZE_SMALL)
		empty.add_theme_color_override("font_color", Color("cdbca2"))
		grid.add_child(empty)
	else:
		for index: int in range(reserve.size()):
			var card_id: String = str(reserve[index])
			grid.add_child(_build_magic_card_tile(card_id, "inventory", index, MAGIC_INVENTORY_TILE_SIZE))
	return panel

func _build_current_deck_column() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(344.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(Color("8f6f46")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Deck"
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f5ead4"))
	title.add_theme_color_override("font_outline_color", Color("241912"))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var attuned_magic: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	list.add_child(_build_attuned_magic_deck_group(attuned_magic))
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		var equipment_id: String = str(equipped.get(slot, ""))
		if equipment_id.is_empty():
			continue
		list.add_child(_build_equipment_deck_group(equipment_id, _equipment_slot_label(slot)))
	return panel

func _build_equipment_inventory_tile(equipment_id: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent := Color(GameData.equipment_accent(equipment_id))
	var tile := EquipmentInventoryTile.new()
	tile.equipment_id = equipment_id
	tile.host = self
	tile.custom_minimum_size = EQUIPMENT_TILE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.tooltip_text = "equipment:%s" % equipment_id
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _equipment_overlay_can_change() else Control.CURSOR_ARROW
	tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, false))
	if _equipment_drag_id == equipment_id:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_equipment_inventory_tiles[equipment_id] = tile
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	tile.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	row.add_child(_build_equipment_icon_chip(equipment_id, EQUIPMENT_ICON_SIZE, false))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = str(item.get("name", equipment_id))
	name_label.clip_text = true
	UiTypography.set_label_size(name_label, UiTypography.SIZE_CAPTION)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = "%s | %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))]
	meta_label.clip_text = true
	UiTypography.set_label_size(meta_label, UiTypography.SIZE_CAPTION)
	meta_label.add_theme_color_override("font_color", Color("cdbca2"))
	text_box.add_child(meta_label)
	var card_label := Label.new()
	card_label.text = _equipment_card_summary(equipment_id)
	card_label.clip_text = true
	UiTypography.set_label_size(card_label, UiTypography.SIZE_CAPTION)
	card_label.add_theme_color_override("font_color", Color("d7c6aa"))
	text_box.add_child(card_label)
	_make_equipment_tile_content_passive(margin)
	if not _equipment_overlay_can_change():
		tile.modulate = Color(0.72, 0.72, 0.72, 1.0)
	return tile

func _build_equipment_deck_group(equipment_id: String, heading: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = "%s - %s" % [heading, str(item.get("name", equipment_id))]
	label.clip_text = true
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("f0c978"))
	label.add_theme_color_override("font_outline_color", Color("1d1510"))
	label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(label)
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vbox.add_child(row)
	var accent := Color(GameData.equipment_accent(equipment_id))
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		row.add_child(_build_equipment_card_badge(str(card_id_var), accent))
	return vbox

func _build_attuned_magic_deck_group(attuned_card_ids: Array) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Attuned Magic %d/%d" % [mini(attuned_card_ids.size(), GameData.magic_loadout_limit()), GameData.magic_loadout_limit()]
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("f0c978"))
	label.add_theme_color_override("font_outline_color", Color("1d1510"))
	label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(label)
	var attuned_row := HFlowContainer.new()
	attuned_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attuned_row.add_theme_constant_override("h_separation", 6)
	attuned_row.add_theme_constant_override("v_separation", 6)
	vbox.add_child(attuned_row)
	for index: int in range(GameData.magic_loadout_limit()):
		var card_id: String = str(attuned_card_ids[index]) if index < attuned_card_ids.size() else ""
		if card_id.is_empty():
			continue
		attuned_row.add_child(_build_equipment_card_badge(card_id, ElementData.accent(GameData.card_element(card_id))))
	return vbox

func _build_magic_card_tile(card_id: String, source_kind: String, index: int, tile_size: Vector2 = EQUIPMENT_DECK_BADGE_SIZE) -> Control:
	if card_id.is_empty():
		var empty := PanelContainer.new()
		empty.custom_minimum_size = tile_size
		empty.add_theme_stylebox_override("panel", _equipment_panel_style(Color("4f453b"), false))
		return empty
	var card: Dictionary = GameData.card_def(card_id)
	var accent: Color = ElementData.accent(GameData.card_element(card_id))
	var tile := MagicCardTile.new()
	tile.card_id = card_id
	tile.host = self
	tile.source_kind = source_kind
	tile.magic_index = index
	tile.custom_minimum_size = tile_size
	if tile_size.x > EQUIPMENT_DECK_BADGE_SIZE.x:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _magic_overlay_can_change() else Control.CURSOR_ARROW
	tile.tooltip_text = "card:%s" % card_id
	tile.clip_contents = true
	var is_drag_source: bool = _magic_drag_source_kind == source_kind and _magic_drag_index == index
	tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, is_drag_source))
	if is_drag_source:
		tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
	if source_kind == "attuned":
		_magic_attuned_tiles[index] = tile
	elif source_kind == "inventory":
		_magic_inventory_tiles[index] = tile
	tile.add_child(_build_card_art_badge_content(card, accent, str(card.get("name", card_id))))
	return tile

func _build_equipment_card_badge(card_id: String, accent: Color) -> Control:
	var card: Dictionary = GameData.card_def(card_id)
	var badge := EquipmentCardBadge.new()
	badge.card_id = card_id
	badge.host = self
	badge.custom_minimum_size = EQUIPMENT_DECK_BADGE_SIZE
	badge.tooltip_text = "card:%s" % card_id
	badge.clip_contents = true
	badge.add_theme_stylebox_override("panel", _equipment_panel_style(accent, false))
	badge.add_child(_build_card_art_badge_content(card, accent, str(card.get("name", card_id))))
	return badge

func _build_card_art_badge_content(card: Dictionary, accent: Color, label_text: String) -> Control:
	var margin := MarginContainer.new()
	margin.name = "CardArtBadgeContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 3)

	var stack := Control.new()
	stack.name = "CardArtBadgeStack"
	stack.clip_contents = true
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)

	var element_id: String = GameData.card_element_from_def(card)
	var art_texture: Texture2D = AssetLoader.load_texture(str(card.get("art_path", "")))
	var backing := CardArtBadgeBacking.new()
	backing.name = "CardBadgeBacking"
	backing.base_color = ElementData.card_art_background(element_id)
	backing.accent = accent
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(backing)

	var underpaint := TextureRect.new()
	underpaint.name = "CardBadgeArtFill"
	underpaint.texture = art_texture
	underpaint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	underpaint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	underpaint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	underpaint.modulate = Color(1.0, 1.0, 1.0, 0.22)
	underpaint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underpaint.set_anchors_preset(Control.PRESET_FULL_RECT)
	underpaint.offset_left = -48.0
	underpaint.offset_top = -14.0
	underpaint.offset_right = 48.0
	underpaint.offset_bottom = 14.0
	stack.add_child(underpaint)

	var art := TextureRect.new()
	art.name = "CardBadgeArt"
	art.texture = art_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = Color.WHITE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(art)

	var wash := CardArtBadgeWash.new()
	wash.name = "CardBadgeWash"
	wash.accent = accent
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(wash)

	var label := Label.new()
	label.name = "CardBadgeName"
	label.text = label_text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_CAPTION)
	label.add_theme_color_override("font_color", Color("fff6d8"))
	label.add_theme_color_override("font_outline_color", Color("100a07"))
	label.add_theme_constant_override("outline_size", 2)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 6.0
	label.offset_right = -6.0
	stack.add_child(label)
	return margin

func _build_equipment_icon_chip(equipment_id: String, chip_size: Vector2, owns_tooltip: bool = true) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var chip: PanelContainer
	if owns_tooltip:
		var tooltip_chip := EquipmentTooltipPanelContainer.new()
		tooltip_chip.equipment_id = equipment_id
		tooltip_chip.host = self
		tooltip_chip.tooltip_text = "equipment:%s" % equipment_id
		chip = tooltip_chip
	else:
		chip = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.name = "EquipmentIconChip"
	chip.custom_minimum_size = chip_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _equipment_icon_style(Color(GameData.equipment_accent(equipment_id))))
	var icon := TextureRect.new()
	icon.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chip.add_child(icon)
	return chip

func _build_equipment_icon_proxy_panel(equipment_id: String, icon_size: Vector2) -> PanelContainer:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = icon_size
	panel.size = icon_size
	panel.add_theme_stylebox_override("panel", _equipment_drag_ghost_style(Color(GameData.equipment_accent(equipment_id))))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var texture := TextureRect.new()
	texture.name = "EquipmentGhostTexture"
	texture.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(texture)
	return panel

func _make_equipment_tile_content_passive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_make_equipment_tile_content_passive(child)

func _begin_equipment_overlay_drag(equipment_id: String, source_rect: Rect2, source_control: Control = null, mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if equipment_id.is_empty():
		return
	if not _equipment_drag_id.is_empty():
		_clear_equipment_drag_state(true)
	_equipment_drag_id = equipment_id
	_equipment_drag_source_rect = source_rect
	_equipment_drag_source_control = source_control
	if _node_is_alive(_equipment_drag_source_control):
		_equipment_drag_source_control.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_spawn_equipment_held_proxy(equipment_id, mouse_position)
	_apply_equipment_drag_highlights()

func _end_equipment_overlay_drag() -> void:
	if _equipment_swap_animation_active:
		return
	_clear_equipment_drag_state(true)

func _spawn_equipment_held_proxy(equipment_id: String, mouse_position: Vector2) -> void:
	if _equipment_fx_layer == null:
		return
	if _node_is_alive(_equipment_held_proxy):
		_queue_free_node_now(_equipment_held_proxy)
	_equipment_held_proxy = _build_equipment_icon_proxy_panel(equipment_id, EQUIPMENT_DRAG_GHOST_SIZE)
	_equipment_held_proxy.name = "EquipmentHeldProxy"
	_equipment_held_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_held_proxy.size = EQUIPMENT_DRAG_GHOST_SIZE
	_equipment_held_proxy.pivot_offset = EQUIPMENT_DRAG_GHOST_SIZE * 0.5
	_equipment_held_proxy.modulate = Color(1.0, 1.0, 1.0, 0.82)
	_equipment_held_proxy.z_index = 20
	_equipment_fx_layer.add_child(_equipment_held_proxy)
	_update_equipment_overlay_drag(mouse_position)

func _update_equipment_overlay_drag(mouse_position: Vector2) -> void:
	if _equipment_drag_id.is_empty() or not _node_is_alive(_equipment_held_proxy):
		return
	var local_mouse: Vector2 = mouse_position
	if local_mouse.x < 0.0 or local_mouse.y < 0.0:
		local_mouse = _current_mouse_position()
	_equipment_held_proxy.position = local_mouse + EQUIPMENT_DRAG_CURSOR_OFFSET - EQUIPMENT_DRAG_GHOST_SIZE * 0.5 - _equipment_fx_layer.global_position

func _release_equipment_overlay_drag(mouse_position: Vector2) -> void:
	if _equipment_drag_id.is_empty():
		return
	_update_equipment_overlay_drag(mouse_position)
	var equipment_id: String = _equipment_drag_id
	var slot: String = _equipment_slot_at(mouse_position)
	if not slot.is_empty() and GameData.equipment_slot(equipment_id) == slot:
		var held_rect: Rect2 = _equipment_held_proxy_global_rect()
		if held_rect.size.x > 0.0 and held_rect.size.y > 0.0:
			_equipment_drag_source_rect = held_rect
		if _node_is_alive(_equipment_held_proxy):
			_queue_free_node_now(_equipment_held_proxy)
			_equipment_held_proxy = null
		await _equip_equipment_from_overlay(equipment_id, slot, _equipment_slot_icon_rect(slot))
		return
	await _cancel_equipment_overlay_drag(true)

func _cancel_equipment_overlay_drag(animate: bool = true) -> void:
	if _equipment_drag_id.is_empty():
		return
	var proxy: Control = _equipment_held_proxy
	if animate and _node_is_alive(proxy) and _equipment_drag_source_rect.size.x > 0.0 and _equipment_drag_source_rect.size.y > 0.0:
		var tween: Tween = create_tween().set_parallel(true)
		_animate_equipment_proxy_to_rect(tween, proxy, _equipment_drag_source_rect, 0.14)
		tween.tween_property(proxy, "modulate:a", 0.46, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
	_clear_equipment_drag_state(true)

func _clear_equipment_drag_state(restore_source: bool) -> void:
	if restore_source and _node_is_alive(_equipment_drag_source_control):
		_equipment_drag_source_control.modulate = Color.WHITE
	if _node_is_alive(_equipment_held_proxy):
		_queue_free_node_now(_equipment_held_proxy)
	_equipment_held_proxy = null
	_equipment_drag_id = ""
	_equipment_drag_source_rect = Rect2()
	_equipment_drag_source_control = null
	_apply_equipment_drag_highlights()

func _apply_equipment_drag_highlights() -> void:
	var target_slot: String = GameData.equipment_slot(_equipment_drag_id)
	for slot_var: Variant in _equipment_slot_panels.keys():
		var slot: String = str(slot_var)
		var panel_var: Variant = _equipment_slot_panels.get(slot, null)
		if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is PanelContainer):
			continue
		var panel: PanelContainer = panel_var as PanelContainer
		var equipment_id: String = str(panel.get("equipment_id"))
		var accent: Color = Color(GameData.equipment_accent(equipment_id)) if not equipment_id.is_empty() else Color("6d5a46")
		var is_drag_target: bool = not _equipment_drag_id.is_empty() and target_slot == slot
		panel.add_theme_stylebox_override("panel", _equipment_panel_style(accent, is_drag_target))
		panel.modulate = Color.WHITE
		if not _equipment_drag_id.is_empty() and not is_drag_target:
			panel.modulate = Color(0.68, 0.68, 0.68, 1.0)

func _equipment_slot_at(mouse_position: Vector2) -> String:
	for slot_var: Variant in _equipment_slot_panels.keys():
		var slot: String = str(slot_var)
		var panel_var: Variant = _equipment_slot_panels.get(slot, null)
		if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is Control):
			continue
		var panel: Control = panel_var as Control
		if panel.get_global_rect().has_point(mouse_position):
			return slot
	return ""

func _equipment_held_proxy_global_rect() -> Rect2:
	if not _node_is_alive(_equipment_held_proxy):
		return Rect2()
	return _equipment_held_proxy.get_global_rect()

func _equipment_icon_rect_for_control(control: Control) -> Rect2:
	if control == null or not control.is_inside_tree():
		return Rect2()
	var icon_node: Node = control.find_child("EquipmentIconChip", true, false)
	if icon_node is Control:
		var icon_control: Control = icon_node as Control
		var icon_rect: Rect2 = icon_control.get_global_rect()
		if icon_rect.size.x > 0.0 and icon_rect.size.y > 0.0:
			return icon_rect
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	return _rect_from_center(rect.get_center(), EQUIPMENT_ICON_SIZE)

func _equipment_inventory_icon_rect(equipment_id: String) -> Rect2:
	var tile_var: Variant = _equipment_inventory_tiles.get(equipment_id, null)
	if typeof(tile_var) != TYPE_OBJECT or not is_instance_valid(tile_var) or not (tile_var is Control):
		return Rect2()
	var tile: Control = tile_var as Control
	return _equipment_icon_rect_for_control(tile)

func _equipment_slot_icon_rect(slot: String) -> Rect2:
	var panel_var: Variant = _equipment_slot_panels.get(slot, null)
	if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is Control):
		return Rect2()
	var panel: Control = panel_var as Control
	return _equipment_icon_rect_for_control(panel)

func _equipment_fx_local_rect(global_rect: Rect2) -> Rect2:
	if _equipment_fx_layer == null:
		return global_rect
	return Rect2(global_rect.position - _equipment_fx_layer.global_position, global_rect.size)

func _spawn_equipment_icon_proxy(equipment_id: String, global_rect: Rect2, alpha: float = 0.94) -> Control:
	if _equipment_fx_layer == null or equipment_id.is_empty() or global_rect.size.x <= 0.0 or global_rect.size.y <= 0.0:
		return null
	var local_rect: Rect2 = _equipment_fx_local_rect(global_rect)
	var proxy: PanelContainer = _build_equipment_icon_proxy_panel(equipment_id, local_rect.size)
	proxy.name = "EquipmentSwapProxy"
	proxy.position = local_rect.position
	proxy.size = local_rect.size
	proxy.pivot_offset = local_rect.size * 0.5
	proxy.modulate = Color(1.0, 1.0, 1.0, alpha)
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.z_index = 10
	_equipment_fx_layer.add_child(proxy)
	return proxy

func _animate_equipment_proxy_to_rect(tween: Tween, proxy: Control, global_target_rect: Rect2, duration: float, delay: float = 0.0) -> void:
	if proxy == null or global_target_rect.size.x <= 0.0 or global_target_rect.size.y <= 0.0:
		return
	var target_rect: Rect2 = _equipment_fx_local_rect(global_target_rect)
	tween.tween_property(proxy, "position", target_rect.position, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "size", target_rect.size, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "modulate:a", 1.0, duration * 0.72).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_equipment_swap_fx(equipment_id: String, previous_equipment_id: String, slot: String, source_rect: Rect2, previous_slot_rect: Rect2) -> void:
	if _equipment_fx_layer == null:
		_equipment_swap_animation_active = false
		_clear_equipment_drag_state(false)
		return
	var target_slot_rect: Rect2 = _equipment_slot_icon_rect(slot)
	if target_slot_rect.size.x <= 0.0 or target_slot_rect.size.y <= 0.0:
		target_slot_rect = previous_slot_rect
	var new_start_rect: Rect2 = source_rect
	if new_start_rect.size.x <= 0.0 or new_start_rect.size.y <= 0.0:
		new_start_rect = target_slot_rect
	var new_proxy: Control = _spawn_equipment_icon_proxy(equipment_id, new_start_rect, 0.86)
	if new_proxy != null:
		new_proxy.scale = Vector2(1.10, 1.10)
	var old_proxy: Control = null
	var old_target_rect: Rect2 = Rect2()
	if not previous_equipment_id.is_empty():
		old_target_rect = _equipment_inventory_icon_rect(previous_equipment_id)
		if old_target_rect.size.x > 0.0 and old_target_rect.size.y > 0.0:
			old_proxy = _spawn_equipment_icon_proxy(previous_equipment_id, previous_slot_rect, 0.76)
		if old_proxy != null:
			old_proxy.scale = Vector2(0.96, 0.96)
	if new_proxy == null and old_proxy == null:
		_equipment_swap_animation_active = false
		_clear_equipment_drag_state(false)
		return
	_equipment_swap_animation_active = true
	var tween: Tween = create_tween().set_parallel(true)
	_animate_equipment_proxy_to_rect(tween, new_proxy, target_slot_rect, EQUIPMENT_SWAP_SNAP_SECONDS)
	_animate_equipment_proxy_to_rect(tween, old_proxy, old_target_rect, EQUIPMENT_SWAP_RETURN_SECONDS, 0.04)
	await tween.finished
	_queue_free_node_now(new_proxy)
	_queue_free_node_now(old_proxy)
	_equipment_swap_animation_active = false
	_clear_equipment_drag_state(false)
	_pulse_equipment_slot(slot)

func _pulse_equipment_slot(slot: String) -> void:
	var panel_var: Variant = _equipment_slot_panels.get(slot, null)
	if typeof(panel_var) != TYPE_OBJECT or not is_instance_valid(panel_var) or not (panel_var is Control):
		return
	var panel: Control = panel_var as Control
	panel.pivot_offset = panel.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.035, 1.035), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _begin_magic_overlay_drag(source_kind: String, index: int, card_id: String, source_rect: Rect2, source_control: Control = null, mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if card_id.is_empty() or not _magic_overlay_can_change():
		return
	if not (source_kind in ["attuned", "inventory"]):
		return
	if not _magic_drag_card_id.is_empty():
		_clear_magic_drag_state(true)
	_magic_drag_source_kind = source_kind
	_magic_drag_index = index
	_magic_drag_card_id = card_id
	_magic_drag_source_rect = source_rect
	_magic_drag_source_control = source_control
	_magic_drag_last_mouse_position = mouse_position
	if _node_is_alive(_magic_drag_source_control):
		_magic_drag_source_control.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_spawn_magic_held_proxy(card_id, mouse_position)
	_apply_magic_drag_highlights()

func _spawn_magic_held_proxy(card_id: String, mouse_position: Vector2) -> void:
	if _equipment_fx_layer == null:
		return
	if _node_is_alive(_magic_held_proxy):
		_queue_free_node_now(_magic_held_proxy)
	var proxy_size: Vector2 = _magic_drag_source_rect.size if _magic_drag_source_rect.size.x > 0.0 and _magic_drag_source_rect.size.y > 0.0 else EQUIPMENT_DECK_BADGE_SIZE
	_magic_held_proxy = _build_magic_card_proxy_panel(card_id, proxy_size)
	_magic_held_proxy.name = "MagicHeldProxy"
	_magic_held_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_magic_held_proxy.size = proxy_size
	_magic_held_proxy.pivot_offset = proxy_size * 0.5
	_magic_held_proxy.modulate = Color(1.0, 1.0, 1.0, 0.84)
	_magic_held_proxy.z_index = 22
	_equipment_fx_layer.add_child(_magic_held_proxy)
	_update_magic_overlay_drag(mouse_position)

func _build_magic_card_proxy_panel(card_id: String, proxy_size: Vector2) -> PanelContainer:
	var card: Dictionary = GameData.card_def(card_id)
	var accent: Color = ElementData.accent(GameData.card_element(card_id))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = proxy_size
	panel.size = proxy_size
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _equipment_drag_ghost_style(accent))
	panel.add_child(_build_card_art_badge_content(card, accent, str(card.get("name", card_id))))
	return panel

func _update_magic_overlay_drag(mouse_position: Vector2) -> void:
	if _magic_drag_card_id.is_empty() or not _node_is_alive(_magic_held_proxy):
		return
	var local_mouse: Vector2 = mouse_position
	if local_mouse.x < 0.0 or local_mouse.y < 0.0:
		local_mouse = _current_mouse_position()
	_magic_drag_last_mouse_position = local_mouse
	_magic_held_proxy.position = local_mouse + MAGIC_DRAG_CURSOR_OFFSET - _magic_held_proxy.size * 0.5 - _equipment_fx_layer.global_position

func _release_magic_overlay_drag(mouse_position: Vector2) -> void:
	if _magic_drag_card_id.is_empty() or _magic_drag_release_in_progress:
		return
	_magic_drag_release_in_progress = true
	_update_magic_overlay_drag(mouse_position)
	var target: Dictionary = _magic_drop_target_for_release(mouse_position)
	if not target.is_empty() and _magic_drag_can_swap_with(target):
		var inventory_index: int = int(target.get("index", -1)) if str(target.get("source_kind", "")) == "inventory" else _magic_drag_index
		var attuned_index: int = int(target.get("index", -1)) if str(target.get("source_kind", "")) == "attuned" else _magic_drag_index
		var target_rect: Rect2 = _magic_tile_rect(str(target.get("source_kind", "")), int(target.get("index", -1)))
		if _node_is_alive(_magic_held_proxy) and target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			await _animate_magic_proxy_to_rect(_magic_held_proxy, target_rect, 0.10)
		await _swap_magic_from_overlay(inventory_index, attuned_index)
		return
	await _cancel_magic_overlay_drag(true)

func _cancel_magic_overlay_drag(animate: bool = true) -> void:
	if _magic_drag_card_id.is_empty():
		return
	var proxy: Control = _magic_held_proxy
	if animate and _node_is_alive(proxy) and _magic_drag_source_rect.size.x > 0.0 and _magic_drag_source_rect.size.y > 0.0:
		await _animate_magic_proxy_to_rect(proxy, _magic_drag_source_rect, 0.12)
	_clear_magic_drag_state(true)

func _clear_magic_drag_state(restore_source: bool) -> void:
	_magic_drag_release_in_progress = false
	if restore_source and _node_is_alive(_magic_drag_source_control):
		_magic_drag_source_control.modulate = Color.WHITE
	if _node_is_alive(_magic_held_proxy):
		_queue_free_node_now(_magic_held_proxy)
	_magic_held_proxy = null
	_magic_drag_source_kind = ""
	_magic_drag_index = -1
	_magic_drag_card_id = ""
	_magic_drag_source_rect = Rect2()
	_magic_drag_source_control = null
	_magic_drag_last_mouse_position = Vector2(-1.0, -1.0)
	_apply_magic_drag_highlights()

func _animate_magic_proxy_to_rect(proxy: Control, global_target_rect: Rect2, duration: float) -> void:
	if proxy == null or global_target_rect.size.x <= 0.0 or global_target_rect.size.y <= 0.0:
		return
	var tween: Tween = create_tween().set_parallel(true)
	_animate_equipment_proxy_to_rect(tween, proxy, global_target_rect, duration)
	await tween.finished

func _magic_drag_can_swap_with(target: Dictionary) -> bool:
	var target_kind: String = str(target.get("source_kind", ""))
	var target_index: int = int(target.get("index", -1))
	if _magic_drag_source_kind.is_empty() or target_kind.is_empty() or target_index < 0:
		return false
	if _magic_drag_source_kind == target_kind:
		return false
	return (_magic_drag_source_kind == "inventory" and target_kind == "attuned") or (_magic_drag_source_kind == "attuned" and target_kind == "inventory")

func _magic_tile_at(mouse_position: Vector2) -> Dictionary:
	for index_var: Variant in _magic_attuned_tiles.keys():
		var index: int = int(index_var)
		var tile: Control = _magic_tile_control("attuned", index)
		if tile != null and tile.get_global_rect().has_point(mouse_position):
			return {"source_kind": "attuned", "index": index}
	for index_var: Variant in _magic_inventory_tiles.keys():
		var index: int = int(index_var)
		var tile: Control = _magic_tile_control("inventory", index)
		if tile != null and tile.get_global_rect().has_point(mouse_position):
			return {"source_kind": "inventory", "index": index}
	return {}

func _magic_drop_target_for_release(mouse_position: Vector2) -> Dictionary:
	var target: Dictionary = _magic_tile_at(mouse_position)
	if not target.is_empty():
		return target
	if _magic_drag_last_mouse_position.x >= 0.0 and _magic_drag_last_mouse_position.y >= 0.0:
		target = _magic_tile_at(_magic_drag_last_mouse_position)
		if not target.is_empty():
			return target
	if not _node_is_alive(_magic_held_proxy):
		return {}
	var proxy_rect: Rect2 = _magic_held_proxy.get_global_rect()
	var best_target: Dictionary = {}
	var best_overlap: float = 0.0
	for source_kind: String in ["attuned", "inventory"]:
		var tiles: Dictionary = _magic_attuned_tiles if source_kind == "attuned" else _magic_inventory_tiles
		for index_var: Variant in tiles.keys():
			var index: int = int(index_var)
			var candidate: Dictionary = {"source_kind": source_kind, "index": index}
			if not _magic_drag_can_swap_with(candidate):
				continue
			var tile: Control = _magic_tile_control(source_kind, index)
			if tile == null:
				continue
			var overlap: float = _rect_overlap_area(proxy_rect, tile.get_global_rect())
			if overlap > best_overlap:
				best_overlap = overlap
				best_target = candidate
	if not best_target.is_empty():
		return best_target
	return _magic_panel_fallback_target(mouse_position, proxy_rect)

func _magic_panel_fallback_target(mouse_position: Vector2, proxy_rect: Rect2) -> Dictionary:
	var target_kind: String = "attuned" if _magic_drag_source_kind == "inventory" else "inventory"
	var panel: Control = _magic_attuned_drop_panel if target_kind == "attuned" else _magic_inventory_drop_panel
	if panel == null or not is_instance_valid(panel):
		return {}
	var panel_rect: Rect2 = panel.get_global_rect()
	var overlaps_panel: bool = panel_rect.has_point(mouse_position) or _rect_overlap_area(proxy_rect, panel_rect) > 0.0
	if not overlaps_panel:
		return {}
	return _nearest_magic_tile_target(target_kind, proxy_rect.get_center())

func _nearest_magic_tile_target(source_kind: String, point: Vector2) -> Dictionary:
	var tiles: Dictionary = _magic_attuned_tiles if source_kind == "attuned" else _magic_inventory_tiles
	var best_target: Dictionary = {}
	var best_distance: float = 1.0e20
	for index_var: Variant in tiles.keys():
		var index: int = int(index_var)
		var candidate: Dictionary = {"source_kind": source_kind, "index": index}
		if not _magic_drag_can_swap_with(candidate):
			continue
		var tile: Control = _magic_tile_control(source_kind, index)
		if tile == null:
			continue
		var distance: float = point.distance_squared_to(tile.get_global_rect().get_center())
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left: float = maxf(a.position.x, b.position.x)
	var top: float = maxf(a.position.y, b.position.y)
	var right: float = minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var bottom: float = minf(a.position.y + a.size.y, b.position.y + b.size.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)

func _magic_tile_rect(source_kind: String, index: int) -> Rect2:
	var tile: Control = _magic_tile_control(source_kind, index)
	return tile.get_global_rect() if tile != null else Rect2()

func _magic_tile_control(source_kind: String, index: int) -> Control:
	var tile_var: Variant = null
	if source_kind == "attuned":
		tile_var = _magic_attuned_tiles.get(index, null)
	else:
		tile_var = _magic_inventory_tiles.get(index, null)
	if typeof(tile_var) != TYPE_OBJECT or not is_instance_valid(tile_var) or not (tile_var is Control):
		return null
	return tile_var as Control

func _apply_magic_drag_highlights() -> void:
	for source_kind: String in ["attuned", "inventory"]:
		var tiles: Dictionary = _magic_attuned_tiles if source_kind == "attuned" else _magic_inventory_tiles
		for index_var: Variant in tiles.keys():
			var index: int = int(index_var)
			var tile: Control = _magic_tile_control(source_kind, index)
			if tile == null:
				continue
			var card_id: String = str(tile.get("card_id"))
			var accent: Color = ElementData.accent(GameData.card_element(card_id))
			var can_receive: bool = not _magic_drag_card_id.is_empty() and _magic_drag_source_kind != source_kind
			tile.add_theme_stylebox_override("panel", _equipment_panel_style(accent, can_receive))
			if _magic_drag_source_kind == source_kind and _magic_drag_index == index:
				tile.modulate = Color(1.0, 1.0, 1.0, 0.34)
			else:
				tile.modulate = Color.WHITE if can_receive or _magic_drag_card_id.is_empty() else Color(0.72, 0.72, 0.72, 1.0)

func _swap_magic_from_overlay(inventory_index: int, attuned_index: int) -> void:
	if not _magic_overlay_can_change():
		_clear_magic_drag_state(true)
		return
	var reserve: Array = (_run_state.get("magic_inventory", []) as Array).duplicate()
	if inventory_index < 0 or inventory_index >= reserve.size():
		_clear_magic_drag_state(true)
		return
	var incoming_card_id: String = str(reserve[inventory_index])
	_run_state = _run_engine.swap_magic_card(_run_state, inventory_index, attuned_index)
	var attuned: Array = _run_state.get("attuned_magic_cards", []) as Array
	if attuned_index < 0 or attuned_index >= attuned.size() or str(attuned[attuned_index]) != incoming_card_id:
		_clear_magic_drag_state(true)
		return
	ProgressionStore.save_run_state(_committed_run_state())
	_analytics_log_magic_attuned(inventory_index, attuned_index, incoming_card_id)
	_clear_magic_drag_state(false)
	_refresh_ui()
	_progression_overlay_mode = "magic"
	_rebuild_progression_overlay()
	await get_tree().process_frame
	_pulse_magic_tile("attuned", attuned_index)

func _pulse_magic_tile(source_kind: String, index: int) -> void:
	var tile: Control = _magic_tile_control(source_kind, index)
	if tile == null:
		return
	tile.pivot_offset = tile.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(tile, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _build_card_tooltip_panel(card_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_TOOLTIP_SIZE + Vector2(18.0, 18.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(ElementData.accent(GameData.card_element(card_id)), true))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	margin.add_child(_build_card_preview_widget(card_id, CARD_TOOLTIP_SIZE))
	return panel

func _build_equipment_tooltip_panel(equipment_id: String) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent := Color(GameData.equipment_accent(equipment_id))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _equipment_panel_style(accent, true))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	vbox.add_child(header)
	var icon := TextureRect.new()
	icon.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	var name_label := Label.new()
	name_label.text = str(item.get("name", equipment_id))
	UiTypography.set_label_size(name_label, UiTypography.SIZE_SMALL)
	name_label.add_theme_color_override("font_color", Color("fff0ce"))
	name_label.add_theme_color_override("font_outline_color", Color("1d1510"))
	name_label.add_theme_constant_override("outline_size", 1)
	title_box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = "%s | %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))]
	UiTypography.set_label_size(meta_label, UiTypography.SIZE_CAPTION)
	meta_label.add_theme_color_override("font_color", Color("d7c6aa"))
	title_box.add_child(meta_label)

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	vbox.add_child(card_row)
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		card_row.add_child(_build_card_preview_widget(str(card_id_var), EQUIPMENT_TOOLTIP_CARD_SIZE))
	if not _equipment_overlay_can_change():
		var locked_label := Label.new()
		locked_label.text = "Locked in combat"
		UiTypography.set_label_size(locked_label, UiTypography.SIZE_CAPTION)
		locked_label.add_theme_color_override("font_color", Color("d8a06a"))
		vbox.add_child(locked_label)
	return panel

func _build_card_preview_widget(card_id: String, card_size: Vector2) -> Control:
	card_size = _normalized_card_size(card_size)
	var widget := CardWidgetScene.instantiate() as CardWidget
	widget.disabled = true
	widget.focus_mode = Control.FOCUS_NONE
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.configure(card_id, false, false, true, false, false, true, _card_def(card_id))
	return _scaled_card_slot(widget, card_size)

func _equipment_inventory_ids() -> Array:
	var inventory: Array = (_run_state.get("equipment_inventory", []) as Array).duplicate()
	var sorted_ids: Array = []
	for slot: String in GameData.equipment_slots():
		var slot_ids: Array = []
		for equipment_id_var: Variant in inventory:
			var equipment_id: String = str(equipment_id_var)
			if GameData.equipment_slot(equipment_id) == slot:
				slot_ids.append(equipment_id)
		slot_ids.sort()
		sorted_ids.append_array(slot_ids)
	return sorted_ids

func _equipment_overlay_can_change() -> bool:
	return _run_engine.can_change_equipment(_run_state)

func _magic_overlay_can_change() -> bool:
	return _progression_overlay_mode == "magic" and _run_engine.can_change_magic(_run_state)

func _magic_overlay_drag_active() -> bool:
	return not _magic_drag_card_id.is_empty()

func _can_drop_equipment_data(slot: String, data: Variant) -> bool:
	if not _equipment_overlay_can_change() or typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data as Dictionary
	if str(payload.get("kind", "")) != "equipment":
		return false
	var equipment_id: String = str(payload.get("equipment_id", ""))
	return GameData.equipment_slot(equipment_id) == slot

func _equip_equipment_from_overlay(equipment_id: String, drop_slot: String = "", drop_rect: Rect2 = Rect2()) -> void:
	if equipment_id.is_empty() or not _equipment_overlay_can_change():
		return
	var slot: String = GameData.equipment_slot(equipment_id)
	if slot.is_empty():
		return
	if not drop_slot.is_empty() and drop_slot != slot:
		return
	var before_equipped: Dictionary = (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
	var before_id: String = str(before_equipped.get(slot, ""))
	var source_rect: Rect2 = _equipment_drag_source_rect
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = _equipment_inventory_icon_rect(equipment_id)
	var previous_slot_rect: Rect2 = _equipment_slot_icon_rect(slot)
	if previous_slot_rect.size.x <= 0.0 or previous_slot_rect.size.y <= 0.0:
		previous_slot_rect = drop_rect
	_run_state = _run_engine.equip_equipment(_run_state, equipment_id)
	var after_equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	if str(after_equipped.get(slot, "")) == before_id:
		_clear_equipment_drag_state(true)
		return
	_equipment_swap_animation_active = true
	ProgressionStore.save_run_state(_committed_run_state())
	_analytics_log_equipment_equipped(slot, before_id, equipment_id)
	_refresh_ui()
	_progression_overlay_mode = "equipment"
	_rebuild_progression_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate_equipment_swap_fx(equipment_id, before_id, slot, source_rect, previous_slot_rect)

func _equipment_tooltip(equipment_id: String) -> String:
	if equipment_id.is_empty():
		return ""
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var lines: Array = [
		str(item.get("name", equipment_id)),
		"%s | %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))]
	]
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		var card: Dictionary = GameData.card_def(str(card_id_var))
		lines.append(str(card.get("name", card_id_var)))
	if not _equipment_overlay_can_change():
		lines.append("Locked in combat")
	return "\n".join(lines)

func _equipment_card_summary(equipment_id: String) -> String:
	if equipment_id.is_empty():
		return ""
	var names: Array = []
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		names.append(str(GameData.card_def(str(card_id_var)).get("name", card_id_var)))
	if names.size() <= 1:
		return str(names[0]) if not names.is_empty() else ""
	return "%s, +%d" % [str(names[0]), names.size() - 1]

func _equipment_slot_label(slot: String) -> String:
	match slot:
		"weapon":
			return "Weapon"
		"offhand":
			return "Offhand"
		"armor":
			return "Armor"
		"boots":
			return "Boots"
		"trinket":
			return "Trinket"
	return slot.capitalize()

func _equipment_rarity_label(rarity: String) -> String:
	if rarity == "legendary":
		return "Legend"
	return rarity.capitalize()

func _equipped_equipment_accent() -> Color:
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	var best_id: String = ""
	var best_rank: int = -1
	for equipment_id_var: Variant in equipped.values():
		var equipment_id: String = str(equipment_id_var)
		var rank: int = _equipment_rarity_rank(GameData.equipment_rarity(equipment_id))
		if rank > best_rank:
			best_rank = rank
			best_id = equipment_id
	if best_id.is_empty():
		return Color("8f6f46")
	return Color(GameData.equipment_accent(best_id))

func _equipment_player_art_tint() -> Color:
	var accent: Color = _equipped_equipment_accent().lightened(0.18)
	return Color(1.0, 0.96, 0.88, 1.0).lerp(accent, 0.16)

func _equipment_rarity_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 3
		"epic":
			return 2
		"rare":
			return 1
	return 0

func _equipment_panel_style(accent: Color, active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.060, 0.045, 0.96).lightened(0.06 if active else 0.0)
	style.border_color = accent.lightened(0.22 if active else 0.04)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _equipment_icon_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.036, 0.032, 0.92)
	style.border_color = accent.lightened(0.18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _equipment_drag_ghost_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.044, 0.038, 0.72)
	style.border_color = accent.lightened(0.34)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 12
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _build_progression_status_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(282.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _ui_skin.make_plain_card_style(Color(0.13, 0.09, 0.065, 0.96), Color("8f6f46"), 12.0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	vbox.add_child(_build_progression_character_panel())
	for row_text: String in _progression_status_rows():
		var label := Label.new()
		label.text = row_text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
		label.add_theme_color_override("font_color", Color("e8dcc5"))
		label.add_theme_color_override("font_outline_color", Color("241912"))
		label.add_theme_constant_override("outline_size", 1)
		vbox.add_child(label)
	return panel

func _build_progression_character_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 252.0 if _progression_overlay_mode == "stats" else 210.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.042, 0.034, 0.86)
	style.border_color = Color("5f4a35")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var art := TextureRect.new()
	art.name = "ProgressionCharacterArt"
	art.texture = AssetLoader.load_texture(PLAYER_UNIT_TEXTURE_PATH)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0.0, 176.0 if _progression_overlay_mode == "stats" else 136.0)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(1.0, 0.96, 0.88, 1.0)
	stack.add_child(art)

	var name_label := Label.new()
	name_label.text = "The Reaver"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(name_label, UiTypography.SIZE_SMALL)
	name_label.add_theme_color_override("font_color", Color("f5ead4"))
	name_label.add_theme_color_override("font_outline_color", Color("241912"))
	name_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(name_label)
	return panel

func _progression_status_rows() -> Array[String]:
	var rows: Array[String] = []
	rows.append("Level %d" % int(_progression.get("level", 1)))
	rows.append("Held embers %d" % int(_progression.get("embers", 0)))
	if _progression_overlay_mode == "level_up":
		rows.append("Cost %d" % ProgressionStore.next_level_cost(_progression))
		rows.append("Choose %d different stats." % GameData.progression_stat_points_per_level())
		rows.append("Assigned %d/%d" % [_progression_pending_point_count(), GameData.progression_stat_points_per_level()])
	else:
		rows.append("Max health %d" % int(_run_state.get("player_max_hp", RunEngineScript.BASE_MAX_HP)))
		rows.append("Unspent points %d" % int(_progression.get("unspent_stat_points", 0)))
	return rows

func _build_progression_stat_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var stats: Dictionary = GameData.normalized_progression_stats(_progression.get("stats", {}))
	for stat_id: String in GameData.progression_stat_ids():
		list.add_child(_build_progression_stat_row(stat_id, int(stats.get(stat_id, 0))))
	return scroll

func _build_progression_stat_row(stat_id: String, value: int) -> Control:
	var stat_def: Dictionary = GameData.progression_stat_def(stat_id)
	var pending: int = _progression_pending_stat_delta(stat_id)
	var displayed_value: int = value + pending
	var selected: bool = pending > 0
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _progression_stat_row_style(Color(str(stat_def.get("accent", "#c28a53"))), selected))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48.0, 48.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetLoader.load_texture(str(stat_def.get("icon_path", "")))
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = str(stat_def.get("name", stat_id))
	UiTypography.set_label_size(name_label, UiTypography.SIZE_SMALL)
	name_label.add_theme_color_override("font_color", Color("f5ead4"))
	name_label.add_theme_color_override("font_outline_color", Color("241912"))
	name_label.add_theme_constant_override("outline_size", 1)
	text_box.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = str(stat_def.get("short", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.set_label_size(desc_label, UiTypography.SIZE_CAPTION)
	desc_label.add_theme_color_override("font_color", Color("cdbca2"))
	text_box.add_child(desc_label)
	if _progression_overlay_mode == "level_up":
		var minus_button := Button.new()
		minus_button.text = "-"
		minus_button.disabled = not _can_decrement_level_up_stat(stat_id)
		_apply_progression_stepper_button_style(minus_button)
		UiTypography.set_button_size(minus_button, UiTypography.SIZE_BODY)
		minus_button.custom_minimum_size = Vector2(46.0, 46.0)
		minus_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		minus_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not minus_button.disabled:
			minus_button.pressed.connect(_change_level_up_stat.bind(stat_id, -1))
		row.add_child(minus_button)

		row.add_child(_build_progression_stat_value_badge(displayed_value, GameData.progression_stat_cap(), selected))

		var plus_button := Button.new()
		plus_button.text = "+"
		plus_button.disabled = not _can_increment_level_up_stat(stat_id, value)
		_apply_progression_stepper_button_style(plus_button)
		UiTypography.set_button_size(plus_button, UiTypography.SIZE_BODY)
		plus_button.custom_minimum_size = Vector2(46.0, 46.0)
		plus_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plus_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not plus_button.disabled:
			plus_button.pressed.connect(_change_level_up_stat.bind(stat_id, 1))
		row.add_child(plus_button)
	else:
		row.add_child(_build_progression_stat_value_badge(displayed_value, GameData.progression_stat_cap(), false))
	return panel

func _build_progression_stat_value_badge(value: int, cap: int, selected: bool) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(74.0, 46.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.040, 0.94).lightened(0.10 if selected else 0.0)
	style.border_color = Color("d7a85d") if selected else Color("6d5a46")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%d/%d" % [value, cap]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
	label.add_theme_color_override("font_color", Color("fff0ce") if selected else Color("e8dcc5"))
	label.add_theme_color_override("font_outline_color", Color("1d1510"))
	label.add_theme_constant_override("outline_size", 1)
	badge.add_child(label)
	return badge

func _apply_progression_stepper_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _progression_texture_button_style(PROGRESSION_STEPPER_BUTTON_NORMAL_PATH, 18.0, 5.0, 5.0))
	button.add_theme_stylebox_override("hover", _progression_texture_button_style(PROGRESSION_STEPPER_BUTTON_HOVER_PATH, 18.0, 5.0, 5.0))
	button.add_theme_stylebox_override("pressed", _progression_texture_button_style(PROGRESSION_STEPPER_BUTTON_PRESSED_PATH, 18.0, 6.0, 4.0))
	button.add_theme_stylebox_override("focus", _progression_texture_button_style(PROGRESSION_STEPPER_BUTTON_HOVER_PATH, 18.0, 5.0, 5.0))
	button.add_theme_stylebox_override("disabled", _progression_texture_button_style(PROGRESSION_STEPPER_BUTTON_DISABLED_PATH, 18.0, 5.0, 5.0))
	_apply_progression_button_text(button, UiTypography.SIZE_BODY)

func _apply_progression_command_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _progression_texture_button_style(PROGRESSION_COMMAND_BUTTON_NORMAL_PATH, 26.0, 16.0, 7.0))
	button.add_theme_stylebox_override("hover", _progression_texture_button_style(PROGRESSION_COMMAND_BUTTON_HOVER_PATH, 26.0, 16.0, 7.0))
	button.add_theme_stylebox_override("pressed", _progression_texture_button_style(PROGRESSION_COMMAND_BUTTON_PRESSED_PATH, 26.0, 16.0, 8.0))
	button.add_theme_stylebox_override("focus", _progression_texture_button_style(PROGRESSION_COMMAND_BUTTON_HOVER_PATH, 26.0, 16.0, 7.0))
	button.add_theme_stylebox_override("disabled", _progression_texture_button_style(PROGRESSION_COMMAND_BUTTON_DISABLED_PATH, 26.0, 16.0, 7.0))
	_apply_progression_button_text(button, UiTypography.SIZE_SMALL)

func _progression_texture_button_style(path: String, texture_margin: float, content_margin_h: float, content_margin_v: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = AssetLoader.load_texture(path)
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_right = content_margin_h
	style.content_margin_bottom = content_margin_v
	return style

func _apply_progression_button_text(button: Button, font_size: int) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_color_override("font_color", Color("ffe8b6"))
	button.add_theme_color_override("font_hover_color", Color("fff4d2"))
	button.add_theme_color_override("font_focus_color", Color("fff4d2"))
	button.add_theme_color_override("font_pressed_color", Color("f5c179"))
	button.add_theme_color_override("font_disabled_color", Color("928a7d"))
	button.add_theme_color_override("font_outline_color", Color("1c120c"))
	button.add_theme_constant_override("outline_size", 2)
	UiTypography.set_button_size(button, font_size)

func _progression_stat_row_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.05, 0.92).lightened(0.06 if selected else 0.0)
	style.border_color = accent.lightened(0.30) if selected else Color(accent.r, accent.g, accent.b, 0.58)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _progression_pending_stat_delta(stat_id: String) -> int:
	return int(_progression_pending_stats.get(stat_id, 0))

func _progression_pending_point_count() -> int:
	var total: int = 0
	for amount_var: Variant in _progression_pending_stats.values():
		total += int(amount_var)
	return total

func _progression_pending_stat_ids() -> Array[String]:
	var result: Array[String] = []
	for stat_id: String in GameData.progression_stat_ids():
		if int(_progression_pending_stats.get(stat_id, 0)) > 0:
			result.append(stat_id)
	return result

func _can_increment_level_up_stat(stat_id: String, current_value: int) -> bool:
	if _progression_overlay_mode != "level_up":
		return false
	if _progression_pending_stat_delta(stat_id) > 0:
		return false
	if _progression_pending_point_count() >= GameData.progression_stat_points_per_level():
		return false
	return current_value < GameData.progression_stat_cap()

func _can_decrement_level_up_stat(stat_id: String) -> bool:
	return _progression_overlay_mode == "level_up" and _progression_pending_stat_delta(stat_id) > 0

func _change_level_up_stat(stat_id: String, delta: int) -> void:
	if _progression_overlay_mode != "level_up":
		return
	var stats: Dictionary = GameData.normalized_progression_stats(_progression.get("stats", {}))
	var current_value: int = int(stats.get(stat_id, 0))
	var current_pending: int = _progression_pending_stat_delta(stat_id)
	if delta > 0:
		if not _can_increment_level_up_stat(stat_id, current_value):
			return
		_progression_pending_stats[stat_id] = 1
	elif delta < 0:
		if current_pending <= 0:
			return
		_progression_pending_stats.erase(stat_id)
	_rebuild_progression_overlay()

func _confirm_level_up() -> void:
	var pending_stat_ids: Array[String] = _progression_pending_stat_ids()
	if not ProgressionStore.can_purchase_level_with_stats(_progression, pending_stat_ids):
		return
	var before_progression: Dictionary = _progression.duplicate(true)
	_progression = ProgressionStore.purchase_level_with_stats(_progression, pending_stat_ids)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.apply_progression_update(_run_state, _progression)
	_run_state = _run_engine.leave_campfire(_run_state, 0)
	ProgressionStore.save_run_state(_run_state)
	_analytics_log_level_up(before_progression, _progression)
	_close_card_upgrade_overlay()
	_refresh_ui()

func _refresh_card_upgrade_overlay() -> void:
	if _upgrade_card_list == null:
		return
	_sync_progression_from_run()
	_upgrade_embers_label.text = "EMBERS %d" % int(_progression.get("embers", 0))
	var card_ids: Array = GameData.upgradeable_card_ids()
	if _upgrade_selected_card_id.is_empty() or not card_ids.has(_upgrade_selected_card_id):
		_upgrade_selected_card_id = str(card_ids[0]) if not card_ids.is_empty() else ""
	_upgrade_refresh_card_list(card_ids)
	_upgrade_refresh_element_list()
	_upgrade_refresh_options()

func _upgrade_refresh_card_list(card_ids: Array) -> void:
	_clear_children(_upgrade_card_list)
	for card_id_var: Variant in card_ids:
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var label: String = str(card.get("name", card_id))
		var button := _upgrade_list_button(label, card_id == _upgrade_selected_card_id)
		button.pressed.connect(_on_upgrade_card_selected.bind(card_id))
		_upgrade_card_list.add_child(button)

func _upgrade_refresh_element_list() -> void:
	_clear_children(_upgrade_element_list)
	var elements: Array = GameData.upgradeable_elements_for_card(_upgrade_selected_card_id, _progression)
	if elements.is_empty():
		_upgrade_selected_element_key = ""
		return
	var has_selected: bool = false
	for element_var: Variant in elements:
		var element: Dictionary = element_var
		if str(element.get("key", "")) == _upgrade_selected_element_key:
			has_selected = true
			break
	if not has_selected:
		_upgrade_selected_element_key = str((elements[0] as Dictionary).get("key", ""))
	for element_var: Variant in elements:
		var element: Dictionary = element_var
		var selected: bool = str(element.get("key", "")) == _upgrade_selected_element_key
		var button := _upgrade_list_button(str(element.get("label", "Part")), selected)
		button.pressed.connect(_on_upgrade_element_selected.bind(element))
		_upgrade_element_list.add_child(button)

func _upgrade_refresh_options() -> void:
	_clear_children(_upgrade_option_list)
	_clear_children(_upgrade_preview_box)
	if _upgrade_selected_card_id.is_empty():
		return
	var current_card: Dictionary = GameData.card_def_for_progression(_upgrade_selected_card_id, _progression)
	var current_widget := CardWidgetScene.instantiate() as CardWidget
	current_widget.configure(_upgrade_selected_card_id, false, false, true, false, false, true, current_card)
	current_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_preview_box.add_child(_scaled_card_slot(current_widget, UPGRADE_CARD_SIZE))
	var element: Dictionary = _selected_upgrade_element()
	if element.is_empty():
		return
	var options: Array = GameData.upgrade_options_for_element(_upgrade_selected_card_id, element, _progression)
	for option_var: Variant in options:
		var option: Dictionary = option_var
		_upgrade_option_list.add_child(_build_upgrade_option_row(option))

func _selected_upgrade_element() -> Dictionary:
	for element_var: Variant in GameData.upgradeable_elements_for_card(_upgrade_selected_card_id, _progression):
		var element: Dictionary = element_var
		if str(element.get("key", "")) == _upgrade_selected_element_key:
			return element
	return {}

func _build_upgrade_option_row(option: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var preview_card: Dictionary = GameData.preview_card_with_mod(_upgrade_selected_card_id, option, _progression)
	var preview_widget := CardWidgetScene.instantiate() as CardWidget
	preview_widget.configure(_upgrade_selected_card_id, false, false, true, false, false, true, preview_card)
	preview_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_scaled_card_slot(preview_widget, UPGRADE_CARD_SIZE))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	var title := Label.new()
	title.text = str(option.get("label", "Upgrade"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.set_label_size(title, UiTypography.SIZE_SMALL)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 1)
	info.add_child(title)

	var cost_label := Label.new()
	cost_label.text = "Cost %d embers" % int(option.get("cost", 0))
	UiTypography.set_label_size(cost_label, UiTypography.SIZE_CAPTION)
	cost_label.add_theme_color_override("font_color", Color("cdbca2"))
	info.add_child(cost_label)

	var button := Button.new()
	if ProgressionStore.can_purchase_card_mod(_progression, _upgrade_selected_card_id, option):
		button.text = "Confirm"
	else:
		button.text = "Need %d" % int(option.get("cost", 0))
		button.disabled = true
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(button, 42.0)
	if not button.disabled:
		button.pressed.connect(_on_card_mod_upgrade_pressed.bind(option))
	row.add_child(button)
	return row

func _upgrade_list_button(text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = text
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_CAPTION)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_STANDARD, UPGRADE_LIST_BUTTON_MIN_WIDTH)
	if selected:
		button.modulate = Color("ffd99a")
	return button

func _on_upgrade_card_selected(card_id: String) -> void:
	_upgrade_selected_card_id = card_id
	_upgrade_selected_element_key = ""
	_refresh_card_upgrade_overlay()

func _on_upgrade_element_selected(element: Dictionary) -> void:
	_upgrade_selected_element_key = str(element.get("key", ""))
	_refresh_card_upgrade_overlay()

func _on_card_mod_upgrade_pressed(mod: Dictionary) -> void:
	_progression = ProgressionStore.purchase_card_mod(_progression, _upgrade_selected_card_id, mod)
	ProgressionStore.save_data(_progression)
	_run_state["progression"] = _progression.duplicate(true)
	if not _combat_state.is_empty():
		_combat_state["card_upgrades"] = (_progression.get("card_upgrades", {}) as Dictionary).duplicate(true)
		_combat_state["card_mods"] = (_progression.get("card_mods", {}) as Dictionary).duplicate(true)
		_run_state["combat_state"] = _combat_state.duplicate(true)
	_refresh_card_upgrade_overlay()
	_refresh_ui()

func _cards_for_pile(pile_kind: String) -> Array:
	var piles: Dictionary = _deck_piles()
	var cards: Array = piles.get(pile_kind, []).duplicate()
	if pile_kind == "draw":
		cards.sort_custom(func(a: Variant, b: Variant) -> bool:
			var a_name: String = str(_card_def(str(a)).get("name", str(a)))
			var b_name: String = str(_card_def(str(b)).get("name", str(b)))
			if a_name == b_name:
				return str(a) < str(b)
			return a_name < b_name
		)
		return cards
	cards.reverse()
	return cards

func _pile_display_name(pile_kind: String) -> String:
	return "Exhaust" if pile_kind == "burn" else pile_kind.capitalize()

func _room_title_text(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "start":
		return "Central Waypoint"
	if room_type == "campfire":
		return "Campfire"
	if room_type == "treasure":
		return "Relic Cache"
	if room_type == "boss":
		return "Outer Sanctum"
	return str(room.get("name", "Chamber"))

func _room_subtitle_text(room: Dictionary) -> String:
	var element_text: String = ElementData.short_label(str(room.get("element", ElementData.NONE)))
	var depth_text: String = "Depth %d" % int(room.get("depth", 0))
	if not element_text.is_empty():
		depth_text = "%s  %s" % [element_text, depth_text]
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		return "%s  TURN %d  %d/%d" % [
			depth_text,
			int(_combat_state.get("turn", 1)),
			int(_combat_state.get("cards_played_this_turn", 0)),
			int(_combat_state.get("cards_per_turn", 2))
		]
	return depth_text

func _maybe_auto_trigger_room_dialogue() -> void:
	if _dialogue_active or str(_run_state.get("mode", "room")) != "room":
		return
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, _run_state.get("current_room", Vector2i.ZERO))
	var trigger_key: String = _dialogue_trigger_key(current_room)
	if trigger_key == _last_auto_dialogue_key:
		return
	var dialogue: Dictionary = _dialogue_engine.build_room_dialogue(current_room, _run_state, _progression)
	if dialogue.is_empty():
		return
	_last_auto_dialogue_key = trigger_key
	_start_dialogue(dialogue)

func _dialogue_trigger_key(room: Dictionary) -> String:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	return "%d,%d|%d" % [coord.x, coord.y, int(_run_state.get("turns_spent", 0))]

func _new_seed() -> int:
	return int(Time.get_unix_time_from_system()) & 0x7fffffff

func _hand_card_size(card_count: int, reward_mode: bool) -> Vector2:
	var available_width: float = maxf(620.0, hand_scroll.size.x if hand_scroll.size.x > 0.0 else get_viewport_rect().size.x - 280.0)
	var card_gap: float = HAND_CARD_GAP if reward_mode else HAND_CARD_OVERLAP
	var gaps: float = float(maxi(0, card_count - 1)) * card_gap
	var target_width: float = (available_width - gaps) / float(maxi(1, card_count))
	var max_width: float = 224.0 if reward_mode else 204.0
	var min_width: float = 188.0 if reward_mode else 184.0
	var width: float = clampf(target_width, min_width, max_width)
	return _card_size_from_width(width)

func _card_size_from_width(width: float) -> Vector2:
	return Vector2(width, width * CARD_ASPECT_RATIO)

func _normalized_card_size(card_size: Vector2) -> Vector2:
	if card_size.x <= 0.0 and card_size.y <= 0.0:
		return _card_size_from_width(200.0)
	if card_size.x <= 0.0:
		return Vector2(card_size.y / CARD_ASPECT_RATIO, card_size.y)
	if card_size.y <= 0.0:
		return _card_size_from_width(card_size.x)
	var aspect_height: float = card_size.x * CARD_ASPECT_RATIO
	if aspect_height <= card_size.y:
		return Vector2(card_size.x, aspect_height)
	return Vector2(card_size.y / CARD_ASPECT_RATIO, card_size.y)

func _card_id_for_hand_index(index: int) -> String:
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return ""
	return str(hand[index])

func _card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	if not state.is_empty() and (state.has("card_upgrades") or state.has("card_mods") or state.has("stats") or state.has("relics")):
		return GameData.card_def_for_progression(card_id, state)
	if not _progression.is_empty():
		return GameData.card_def_for_progression(card_id, _progression)
	return GameData.card_def(card_id)

func _reset_card_resolution() -> void:
	_selected_card_index = -1
	_selected_card_label_override = ""
	_hovered_card_index = -1
	_pending_actions.clear()
	_pending_action_index = 0
	_pending_action_can_skip = false
	_pending_target_tiles.clear()
	_pending_selected_targets.clear()
	_pending_orientation_target_tile = INVALID_TARGET_TILE
	_aoe_aim_orientation = Vector2i(1, 0)
	_preview_combat_state.clear()
	_hovered_board_tile = Vector2i(-1, -1)

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()

func _clear_children_now(node: Node) -> void:
	for child: Node in node.get_children():
		_prepare_node_for_immediate_free(child)
		node.remove_child(child)
		if _node_is_alive(child):
			child.queue_free()

func _node_is_alive(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not (node as Node).is_queued_for_deletion()

func _queue_free_node_now(node) -> void:
	if not _node_is_alive(node):
		return
	_prepare_node_for_immediate_free(node)
	(node as Node).queue_free()

func _prepare_node_for_immediate_free(node) -> void:
	if not _node_is_alive(node):
		return
	if node is CanvasItem:
		var item: CanvasItem = node as CanvasItem
		item.visible = false
		item.top_level = false
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_prepare_node_for_immediate_free(child)

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		var control: Control = node as Control
		control.mouse_filter = filter
	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _ensure_run_analytics_metadata(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if next_state.is_empty():
		return next_state
	var analytics: Dictionary = (next_state.get("analytics", {}) as Dictionary).duplicate(true)
	if str(analytics.get("run_id", "")).is_empty():
		analytics["run_id"] = _analytics_random_id("run")
	if not analytics.has("combat_counter"):
		analytics["combat_counter"] = 0
	next_state["analytics"] = analytics
	return next_state

func _analytics_random_id(prefix: String) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return "%s_%d_%08x" % [prefix, Time.get_ticks_usec(), rng.randi()]

func _analytics_context_from_states(run_state: Dictionary, combat_state: Dictionary = {}, card_id: String = "", card_instance_id: String = "") -> Dictionary:
	var room_meta: Dictionary = {}
	if not run_state.is_empty():
		room_meta = _run_engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary) if not combat_state.is_empty() else {}
	var combat_analytics: Dictionary = (combat_state.get("analytics", {}) as Dictionary).duplicate(true)
	var run_analytics: Dictionary = (run_state.get("analytics", {}) as Dictionary).duplicate(true)
	var progression: Dictionary = (run_state.get("progression", _progression) as Dictionary).duplicate(true)
	var context: Dictionary = {
		"run_id": str(run_analytics.get("run_id", "")),
		"combat_id": str(combat_analytics.get("combat_id", "")),
		"turn": int(combat_state.get("turn", 0)),
		"initiative_clock": int(combat_state.get("initiative_clock", 0)),
		"current_actor_kind": str((combat_state.get("current_actor", {}) as Dictionary).get("kind", "")),
		"current_actor_key": str((combat_state.get("current_actor", {}) as Dictionary).get("actor_key", "")),
		"room_depth": int(combat_state.get("room_depth", room_meta.get("depth", 0))),
		"room_element": str(combat_state.get("room_element", room_meta.get("element", ""))),
		"player_hp": int(player.get("hp", run_state.get("player_hp", -1))),
		"player_max_hp": int(player.get("max_hp", run_state.get("player_max_hp", -1))),
		"progression_level": int(progression.get("level", 1)),
		"progression_stats": GameData.normalized_progression_stats(progression.get("stats", {})),
		"deck_size": int((run_state.get("deck_cards", []) as Array).size()),
		"card_id": card_id,
		"card_instance_id": card_instance_id
	}
	if not combat_state.is_empty():
		context["elemental_intensity"] = _combat_engine.elemental_intensities(combat_state)
	return context

func _combat_recovery_marker_amount(combat_state: Dictionary) -> int:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)):
			continue
		if str(loot.get("kind", "")) == "dropped_embers":
			return maxi(0, int(loot.get("amount", 0)))
	return 0

func _analytics_equipment_loot_ids(combat_state: Dictionary) -> Array:
	var ids: Array = []
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if bool(loot.get("claimed", false)) or str(loot.get("kind", "")) != "equipment":
			continue
		var equipment_id: String = str(loot.get("equipment_id", ""))
		if not equipment_id.is_empty():
			ids.append(equipment_id)
	return ids

func _analytics_log_run_started() -> void:
	var recovery_marker: Dictionary = ProgressionStore.recovery_marker(_progression)
	_analytics_store.write_event("run_started", _analytics_context_from_states(_run_state, _combat_state), {
		"seed": int(_run_state.get("seed", 0)),
		"run_index": int(_run_state.get("run_index", 0)),
		"player_start_hp": int(_run_state.get("player_hp", 0)),
		"player_max_hp": int(_run_state.get("player_max_hp", 0)),
		"starting_deck": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"collected_equipment": (_run_state.get("collected_equipment", []) as Array).duplicate(true),
		"recovery_marker_active": not recovery_marker.is_empty(),
		"recovery_marker_amount": int(recovery_marker.get("amount", 0)),
		"recovery_marker_coord": ProgressionStore.recovery_coord(_progression) if not recovery_marker.is_empty() else Vector2i(-999, -999)
	})

func _analytics_log_run_resumed() -> void:
	_analytics_store.write_event("run_resumed", _analytics_context_from_states(_run_state, _combat_state), {
		"mode": str(_run_state.get("mode", "room")),
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"current_room": _run_state.get("current_room", Vector2i.ZERO)
	})
	if str(_run_state.get("mode", "")) == "combat" and not _combat_state.is_empty():
		_analytics_store.write_event("combat_resumed", _analytics_context_from_states(_run_state, _combat_state), {
			"room_name": str(_combat_state.get("room_name", "")),
			"hand": _analytics_zone_cards(_combat_state, "hand")
		})
		_analytics_log_playable_cards()

func _analytics_log_run_ended(outcome: String) -> void:
	if outcome.is_empty() or _run_state.is_empty():
		return
	_analytics_store.write_event("run_ended", _analytics_context_from_states(_run_state, _combat_state), {
		"outcome": outcome,
		"turns_spent": int(_run_state.get("turns_spent", 0)),
		"held_embers": _run_engine.held_embers(_run_state),
		"mode": str(_run_state.get("mode", "room"))
	})

func _analytics_log_level_up(before_progression: Dictionary, after_progression: Dictionary) -> void:
	var chosen_stat_ids: Array[String] = _progression_pending_stat_ids()
	var stat_values: Dictionary = {}
	for stat_id: String in chosen_stat_ids:
		stat_values[stat_id] = GameData.stat_value(after_progression, stat_id)
	_analytics_store.write_event("progression_level_up", _analytics_context_from_states(_run_state, _combat_state), {
		"level_before": int(before_progression.get("level", 1)),
		"level_after": int(after_progression.get("level", 1)),
		"stat_id": str(chosen_stat_ids[0]) if not chosen_stat_ids.is_empty() else "",
		"stat_ids": chosen_stat_ids,
		"stat_values": stat_values,
		"cost": ProgressionStore.next_level_cost(before_progression),
		"held_embers_after": int(after_progression.get("embers", 0)),
		"room": _run_state.get("current_room", Vector2i.ZERO)
	})

func _analytics_log_reward_choice(choice_kind: String, reward_state: Dictionary, selected_card_id: String, player_hp_before: int, player_hp_after: int) -> void:
	_analytics_store.write_event("reward_choice", _analytics_context_from_states(_run_state, _combat_state, selected_card_id), {
		"choice_kind": choice_kind,
		"selected_card_id": selected_card_id,
		"offered_cards": (reward_state.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward_state.get("heal_amount", 0)),
		"ember_amount": int(reward_state.get("ember_amount", 0)),
		"player_hp_before": player_hp_before,
		"player_hp_after": player_hp_after
	})

func _analytics_log_equipment_equipped(slot: String, previous_equipment_id: String, equipment_id: String) -> void:
	_analytics_store.write_event("equipment_equipped", _analytics_context_from_states(_run_state, _combat_state), {
		"slot": slot,
		"previous_equipment_id": previous_equipment_id,
		"equipment_id": equipment_id,
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true)
	})

func _analytics_log_magic_attuned(inventory_index: int, attuned_index: int, card_id: String) -> void:
	_analytics_store.write_event("magic_attuned", _analytics_context_from_states(_run_state, _combat_state, card_id), {
		"inventory_index": inventory_index,
		"attuned_index": attuned_index,
		"card_id": card_id,
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true)
	})

func _analytics_log_combat_transition(previous_run_state: Dictionary, reason: String, transition_combat_state: Dictionary = {}) -> void:
	var previous_mode: String = str(previous_run_state.get("mode", "room"))
	var next_mode: String = str(_run_state.get("mode", "room"))
	if previous_mode != "combat" and next_mode == "combat" and not transition_combat_state.is_empty():
		_run_state = _ensure_run_analytics_metadata(_run_state)
		var analytics: Dictionary = (_run_state.get("analytics", {}) as Dictionary).duplicate(true)
		analytics["combat_counter"] = int(analytics.get("combat_counter", 0)) + 1
		_run_state["analytics"] = analytics
		_combat_state = transition_combat_state.duplicate(true)
		var combat_analytics: Dictionary = (_combat_state.get("analytics", {}) as Dictionary).duplicate(true)
		combat_analytics["combat_id"] = "%s_c%03d" % [str(analytics.get("run_id", "")), int(analytics.get("combat_counter", 0))]
		_combat_state["analytics"] = combat_analytics
		_run_state["combat_state"] = _combat_state.duplicate(true)
		_analytics_initialize_combat_tracker(_combat_state)
		_analytics_log_combat_started(reason)
		return
	if previous_mode == "combat" and next_mode != "combat" and not transition_combat_state.is_empty():
		_analytics_log_combat_ended(transition_combat_state, reason)
		if next_mode == "reward":
			_analytics_log_reward_offered(transition_combat_state, reason)
		elif next_mode in ["victory", "defeat"]:
			_analytics_log_run_ended(next_mode)
		_reset_analytics_combat_tracker()

func _analytics_log_combat_started(reason: String) -> void:
	_analytics_store.write_event("combat_started", _analytics_context_from_states(_run_state, _combat_state), {
		"reason": reason,
		"room_name": str(_combat_state.get("room_name", "")),
		"room_type": str(_combat_state.get("room_type", "")),
		"room_coord": _combat_state.get("room_coord", Vector2i.ZERO),
		"recovery_marker_present": _combat_recovery_marker_amount(_combat_state) > 0,
		"recovery_marker_amount": _combat_recovery_marker_amount(_combat_state),
		"elemental_intensity": _combat_engine.elemental_intensities(_combat_state),
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true),
		"reward_cards": (_run_state.get("reward_cards", []) as Array).duplicate(true),
		"attuned_magic_cards": (_run_state.get("attuned_magic_cards", []) as Array).duplicate(true),
		"magic_inventory": (_run_state.get("magic_inventory", []) as Array).duplicate(true),
		"equipped_equipment": (_run_state.get("equipped_equipment", {}) as Dictionary).duplicate(true),
		"equipment_inventory": (_run_state.get("equipment_inventory", []) as Array).duplicate(true),
		"equipment_drops": _analytics_equipment_loot_ids(_combat_state),
		"opening_hand": _analytics_zone_cards(_combat_state, "hand")
	})
	_analytics_log_card_draws({}, _combat_state, {}, _analytics_snapshot_combat_tracker(), "opening_hand")
	_analytics_log_playable_cards()

func _analytics_log_combat_ended(combat_state: Dictionary, reason: String) -> void:
	_analytics_store.write_event("combat_ended", _analytics_context_from_states(_run_state, combat_state), {
		"reason": reason,
		"outcome": _combat_engine.combat_outcome(combat_state),
		"turn": int(combat_state.get("turn", 0)),
		"room_embers": int(combat_state.get("room_embers", 0)),
		"recovered_embers": int(combat_state.get("recovered_embers_total", 0)),
		"collected_equipment": (combat_state.get("collected_equipment", []) as Array).duplicate(true),
		"remaining_player_hp": int((combat_state.get("player", {}) as Dictionary).get("hp", 0))
	})

func _analytics_log_reward_offered(combat_state: Dictionary, reason: String) -> void:
	var reward_state: Dictionary = (_run_state.get("pending_reward", {}) as Dictionary).duplicate(true)
	_analytics_store.write_event("reward_offered", _analytics_context_from_states(_run_state, combat_state), {
		"reason": reason,
		"offered_cards": (reward_state.get("cards", []) as Array).duplicate(true),
		"heal_amount": int(reward_state.get("heal_amount", 0)),
		"ember_amount": int(reward_state.get("ember_amount", 0))
	})

func _sync_analytics_combat_tracker() -> void:
	if str(_run_state.get("mode", "")) != "combat" or _combat_state.is_empty():
		if not _analytics_combat_tracker.is_empty():
			_reset_analytics_combat_tracker()
		return
	var combat_analytics: Dictionary = (_combat_state.get("analytics", {}) as Dictionary).duplicate(true)
	if str(combat_analytics.get("combat_id", "")).is_empty():
		_run_state = _ensure_run_analytics_metadata(_run_state)
		var analytics: Dictionary = (_run_state.get("analytics", {}) as Dictionary).duplicate(true)
		analytics["combat_counter"] = maxi(1, int(analytics.get("combat_counter", 0)))
		_run_state["analytics"] = analytics
		combat_analytics["combat_id"] = "%s_c%03d" % [str(analytics.get("run_id", "")), int(analytics.get("combat_counter", 0))]
		_combat_state["analytics"] = combat_analytics
		_run_state["combat_state"] = _combat_state.duplicate(true)
	if _analytics_combat_tracker.is_empty() or str(_analytics_combat_tracker.get("combat_id", "")) != str(combat_analytics.get("combat_id", "")):
		_analytics_initialize_combat_tracker(_combat_state)

func _reset_analytics_combat_tracker() -> void:
	_analytics_combat_tracker = {}

func _analytics_initialize_combat_tracker(combat_state: Dictionary) -> void:
	var tracker: Dictionary = {
		"combat_id": str((combat_state.get("analytics", {}) as Dictionary).get("combat_id", "")),
		"next_instance_seq": 1,
		"playable_logged": {},
		"zones": {}
	}
	var zones: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var zone_cards: Array[String] = _analytics_zone_cards(combat_state, zone)
		var zone_ids: Array[String] = []
		for _card_id: String in zone_cards:
			zone_ids.append(_analytics_next_card_instance_id(tracker))
		zones[zone] = zone_ids
	tracker["zones"] = zones
	_analytics_combat_tracker = tracker

func _analytics_snapshot_combat_tracker() -> Dictionary:
	return _analytics_combat_tracker.duplicate(true)

func _analytics_zone_cards(state: Dictionary, zone: String) -> Array[String]:
	var cards: Array[String] = []
	var zone_values: Array = ((state.get("deck", {}) as Dictionary).get(zone, []) as Array)
	for card_id_var: Variant in zone_values:
		cards.append(str(card_id_var))
	return cards

func _analytics_zone_ids(tracker: Dictionary, zone: String) -> Array:
	if tracker.is_empty():
		return []
	return ((tracker.get("zones", {}) as Dictionary).get(zone, []) as Array).duplicate(true)

func _analytics_reconcile_combat_tracker(before_state: Dictionary, after_state: Dictionary) -> void:
	if _analytics_combat_tracker.is_empty():
		_analytics_initialize_combat_tracker(after_state)
		return
	var cross_pool: Dictionary = {}
	var same_zone_ids: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var before_cards: Array[String] = _analytics_zone_cards(before_state, zone)
		var before_ids: Array = _analytics_zone_ids(_analytics_combat_tracker, zone)
		var after_cards: Array[String] = _analytics_zone_cards(after_state, zone)
		var same_zone_pool: Dictionary = {}
		for index: int in range(mini(before_cards.size(), before_ids.size())):
			var card_id: String = before_cards[index]
			var instance_id: String = str(before_ids[index])
			if not same_zone_pool.has(card_id):
				same_zone_pool[card_id] = []
			(same_zone_pool[card_id] as Array).append(instance_id)
		var assigned_ids: Array[String] = []
		for card_id: String in after_cards:
			var instance_id: String = _analytics_take_from_pool(same_zone_pool, card_id)
			assigned_ids.append(instance_id)
		same_zone_ids[zone] = assigned_ids
		for pool_card_id_var: Variant in same_zone_pool.keys():
			var pool_card_id: String = str(pool_card_id_var)
			for leftover_id_var: Variant in same_zone_pool[pool_card_id]:
				_analytics_enqueue_instance_id(cross_pool, pool_card_id, str(leftover_id_var))
	_update_analytics_zone_ids_from_pool(after_state, same_zone_ids, cross_pool)

func _update_analytics_zone_ids_from_pool(after_state: Dictionary, zone_ids: Dictionary, cross_pool: Dictionary) -> void:
	var next_zones: Dictionary = {}
	for zone: String in ["draw", "hand", "discard", "burned"]:
		var after_cards: Array[String] = _analytics_zone_cards(after_state, zone)
		var resolved_ids: Array = (zone_ids.get(zone, []) as Array).duplicate(true)
		for index: int in range(resolved_ids.size()):
			if not str(resolved_ids[index]).is_empty():
				continue
			var card_id: String = after_cards[index]
			var instance_id: String = _analytics_take_from_pool(cross_pool, card_id)
			if instance_id.is_empty():
				instance_id = _analytics_next_card_instance_id(_analytics_combat_tracker)
			resolved_ids[index] = instance_id
		next_zones[zone] = resolved_ids
	_analytics_combat_tracker["zones"] = next_zones

func _analytics_enqueue_instance_id(pool: Dictionary, card_id: String, instance_id: String) -> void:
	if not pool.has(card_id):
		pool[card_id] = []
	(pool[card_id] as Array).append(instance_id)

func _analytics_take_from_pool(pool: Dictionary, card_id: String) -> String:
	if not pool.has(card_id) or (pool[card_id] as Array).is_empty():
		return ""
	var queue: Array = pool[card_id]
	var instance_id: String = str(queue[0])
	queue.remove_at(0)
	pool[card_id] = queue
	return instance_id

func _analytics_next_card_instance_id(tracker: Dictionary) -> String:
	var next_seq: int = int(tracker.get("next_instance_seq", 1))
	tracker["next_instance_seq"] = next_seq + 1
	return "%s_i%03d" % [str(tracker.get("combat_id", "combat")), next_seq]

func _analytics_hand_instance_id(hand_index: int) -> String:
	var hand_ids: Array = _analytics_zone_ids(_analytics_combat_tracker, "hand")
	if hand_index < 0 or hand_index >= hand_ids.size():
		return ""
	return str(hand_ids[hand_index])

func _analytics_log_card_draws(before_state: Dictionary, after_state: Dictionary, before_tracker: Dictionary, after_tracker: Dictionary, reason: String) -> void:
	var before_hand_ids: Dictionary = {}
	for instance_id_var: Variant in _analytics_zone_ids(before_tracker, "hand"):
		before_hand_ids[str(instance_id_var)] = true
	var after_hand_ids: Array = _analytics_zone_ids(after_tracker, "hand")
	var after_hand_cards: Array[String] = _analytics_zone_cards(after_state, "hand")
	for index: int in range(mini(after_hand_ids.size(), after_hand_cards.size())):
		var instance_id: String = str(after_hand_ids[index])
		if before_hand_ids.has(instance_id):
			continue
		var card_id: String = after_hand_cards[index]
		_analytics_store.write_event("card_drawn", _analytics_context_from_states(_run_state, after_state, card_id, instance_id), {
			"reason": reason,
			"hand_index": index,
			"hand_size": after_hand_cards.size(),
			"draw_pile_size": _analytics_zone_cards(after_state, "draw").size()
		})

func _analytics_log_playable_cards() -> void:
	if _combat_state.is_empty() or _analytics_combat_tracker.is_empty():
		return
	var playable_logged: Dictionary = (_analytics_combat_tracker.get("playable_logged", {}) as Dictionary).duplicate(true)
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	var hand_ids: Array = _analytics_zone_ids(_analytics_combat_tracker, "hand")
	for index: int in range(mini(hand.size(), hand_ids.size())):
		var instance_id: String = str(hand_ids[index])
		if bool(playable_logged.get(instance_id, false)):
			continue
		var options: Dictionary = _card_play_options_for_index(index)
		if not bool(options.get("any_playable", false)):
			continue
		var card_id: String = str(hand[index])
		playable_logged[instance_id] = true
		_analytics_store.write_event("card_became_playable", _analytics_context_from_states(_run_state, _combat_state, card_id, instance_id), {
			"hand_index": index,
			"printed_playable": bool(options.get("printed_playable", false)),
			"attack_playable": bool(options.get("attack_playable", false)),
			"move_playable": bool(options.get("move_playable", false))
		})
	_analytics_combat_tracker["playable_logged"] = playable_logged

func _analytics_log_card_played(card_id: String, card_instance_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	if card_id.is_empty():
		return
	_analytics_store.write_event("card_played", _analytics_context_from_states(_run_state, before_state, card_id, card_instance_id), _analytics_card_play_payload(card_id, before_state, resolved_state, actions, selected_targets))

func _analytics_card_play_payload(card_id: String, before_state: Dictionary, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> Dictionary:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = resolved_state.get("player", {})
	var before_pos: Vector2i = before_player.get("pos", Vector2i.ZERO)
	var after_pos: Vector2i = after_player.get("pos", Vector2i.ZERO)
	var enemy_hp_damage: int = 0
	var enemy_block_removed: int = 0
	var enemy_stoneskin_removed: int = 0
	var kills_secured: int = 0
	var enemy_burn_applied: int = 0
	var enemy_bleed_applied: int = 0
	var enemy_expose_applied: int = 0
	var enemy_freeze_applied: int = 0
	var enemy_shock_applied: int = 0
	var enemy_immobilize_applied: int = 0
	var enemy_poison_applied: int = 0
	var terrain_hp_damage: int = 0
	var terrain_destroyed: int = 0
	var before_enemies: Array = before_state.get("enemies", [])
	var after_enemies: Array = resolved_state.get("enemies", [])
	for index: int in range(mini(before_enemies.size(), after_enemies.size())):
		var before_enemy: Dictionary = before_enemies[index]
		var after_enemy: Dictionary = after_enemies[index]
		enemy_hp_damage += maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		enemy_block_removed += maxi(0, int(before_enemy.get("block", 0)) - int(after_enemy.get("block", 0)))
		enemy_stoneskin_removed += maxi(0, int(before_enemy.get("stoneskin", 0)) - int(after_enemy.get("stoneskin", 0)))
		if int(before_enemy.get("hp", 0)) > 0 and int(after_enemy.get("hp", 0)) <= 0:
			kills_secured += 1
		enemy_burn_applied += maxi(0, int(after_enemy.get("burn", 0)) - int(before_enemy.get("burn", 0)))
		enemy_bleed_applied += maxi(0, int(after_enemy.get("bleed", 0)) - int(before_enemy.get("bleed", 0)))
		enemy_expose_applied += maxi(0, int(after_enemy.get("expose", 0)) - int(before_enemy.get("expose", 0)))
		enemy_freeze_applied += maxi(0, int(after_enemy.get("freeze", 0)) - int(before_enemy.get("freeze", 0)))
		enemy_shock_applied += maxi(0, int(after_enemy.get("shock", 0)) - int(before_enemy.get("shock", 0)))
		if bool(after_enemy.get("immobilize", false)) and not bool(before_enemy.get("immobilize", false)):
			enemy_immobilize_applied += 1
		enemy_poison_applied += maxi(0, int((after_enemy.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_enemy.get("poison", {}) as Dictionary).get("damage", 0)))
	var after_terrain_by_id: Dictionary = {}
	for after_terrain_var: Variant in resolved_state.get("terrain", []):
		if typeof(after_terrain_var) != TYPE_DICTIONARY:
			continue
		var after_terrain: Dictionary = after_terrain_var
		after_terrain_by_id[str(after_terrain.get("id", ""))] = after_terrain
	for before_terrain_var: Variant in before_state.get("terrain", []):
		if typeof(before_terrain_var) != TYPE_DICTIONARY:
			continue
		var before_terrain: Dictionary = before_terrain_var
		if int(before_terrain.get("hp", 0)) <= 0:
			continue
		var terrain_id: String = str(before_terrain.get("id", ""))
		if not after_terrain_by_id.has(terrain_id):
			continue
		var after_terrain: Dictionary = after_terrain_by_id[terrain_id]
		var terrain_loss: int = maxi(0, int(before_terrain.get("hp", 0)) - int(after_terrain.get("hp", 0)))
		terrain_hp_damage += terrain_loss
		if terrain_loss > 0 and int(after_terrain.get("hp", 0)) <= 0:
			terrain_destroyed += 1
	var player_burn_applied: int = maxi(0, int(after_player.get("burn", 0)) - int(before_player.get("burn", 0)))
	var player_bleed_applied: int = maxi(0, int(after_player.get("bleed", 0)) - int(before_player.get("bleed", 0)))
	var player_expose_applied: int = maxi(0, int(after_player.get("expose", 0)) - int(before_player.get("expose", 0)))
	var player_freeze_applied: int = maxi(0, int(after_player.get("freeze", 0)) - int(before_player.get("freeze", 0)))
	var player_shock_applied: int = maxi(0, int(after_player.get("shock", 0)) - int(before_player.get("shock", 0)))
	var player_immobilize_applied: int = 1 if bool(after_player.get("immobilize", false)) and not bool(before_player.get("immobilize", false)) else 0
	var player_poison_applied: int = maxi(0, int((after_player.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_player.get("poison", {}) as Dictionary).get("damage", 0)))
	var before_illusion_ids: Dictionary = {}
	for before_illusion_var: Variant in before_state.get("illusions", []):
		if typeof(before_illusion_var) != TYPE_DICTIONARY:
			continue
		var before_illusion: Dictionary = before_illusion_var
		before_illusion_ids[int(before_illusion.get("id", -1))] = true
	var illusions_created: int = 0
	var illusion_health_created: int = 0
	for after_illusion_var: Variant in resolved_state.get("illusions", []):
		if typeof(after_illusion_var) != TYPE_DICTIONARY:
			continue
		var after_illusion: Dictionary = after_illusion_var
		if before_illusion_ids.has(int(after_illusion.get("id", -1))):
			continue
		if int(after_illusion.get("hp", 0)) <= 0:
			continue
		illusions_created += 1
		illusion_health_created += maxi(0, int(after_illusion.get("max_hp", after_illusion.get("hp", 0))))
	var printed_card: Dictionary = _card_def(card_id, before_state)
	var printed_actions: Array = (printed_card.get("actions", []) as Array).duplicate(true)
	var intensity_before: Dictionary = _combat_engine.elemental_intensities(before_state)
	var intensity_after: Dictionary = _combat_engine.elemental_intensities(resolved_state)
	var intensity_gained: Dictionary = _elemental_intensity_counter_delta(before_state, resolved_state, "elemental_intensity_gained_total")
	if intensity_gained.is_empty():
		intensity_gained = _elemental_intensity_delta(intensity_before, intensity_after)
	var intensity_spent: Dictionary = _elemental_intensity_counter_delta(before_state, resolved_state, "elemental_intensity_spent_total")
	var capacity_delta: int = _card_play_capacity_value(resolved_state) - _card_play_capacity_value(before_state)
	var play_mode: String = "printed"
	var comparable_actions: Array = _analytics_actions_without_runtime_orientation(actions)
	if JSON.stringify(comparable_actions) != JSON.stringify(printed_actions):
		play_mode = "attack" if JSON.stringify(comparable_actions) == JSON.stringify(_fallback_actions("attack")) else "move" if JSON.stringify(comparable_actions) == JSON.stringify(_fallback_actions("move")) else "custom"
	return {
		"play_mode": play_mode,
		"printed_health_cost": int(printed_card.get("health_cost", 0)),
		"enemy_hp_damage": enemy_hp_damage,
		"enemy_block_removed": enemy_block_removed,
		"enemy_stoneskin_removed": enemy_stoneskin_removed,
		"enemy_defense_bypassed": _analytics_enemy_defense_bypassed(before_state, resolved_state, actions),
		"terrain_hp_damage": terrain_hp_damage,
		"terrain_destroyed": terrain_destroyed,
		"traps_triggered": _triggered_traps_between(before_state, resolved_state).size(),
		"pickups_collected": _analytics_picked_loot_count(before_state, resolved_state),
		"embers_recovered": maxi(0, int(resolved_state.get("recovered_embers_total", 0)) - int(before_state.get("recovered_embers_total", 0))),
		"kills_secured": kills_secured,
		"player_hp_delta": int(after_player.get("hp", 0)) - int(before_player.get("hp", 0)),
		"player_heal_gained": maxi(0, int(after_player.get("hp", 0)) - int(before_player.get("hp", 0))),
		"player_block_gained": maxi(0, int(after_player.get("block", 0)) - int(before_player.get("block", 0))),
		"player_stoneskin_gained": maxi(0, int(after_player.get("stoneskin", 0)) - int(before_player.get("stoneskin", 0))),
		"move_distance": absi(after_pos.x - before_pos.x) + absi(after_pos.y - before_pos.y),
		"cards_drawn": _draw_entries_between_states(before_state, resolved_state).size(),
		"card_plays_gained": maxi(0, capacity_delta),
		"card_plays_remaining_before": _combat_engine.cards_remaining_this_turn(before_state),
		"card_plays_remaining_after": _combat_engine.cards_remaining_this_turn(resolved_state),
		"net_card_plays_remaining_delta": _combat_engine.cards_remaining_this_turn(resolved_state) - _combat_engine.cards_remaining_this_turn(before_state),
		"card_plays_spent": maxi(0, int(resolved_state.get("cards_played_this_turn", 0)) - int(before_state.get("cards_played_this_turn", 0))),
		"death_bonus_card_plays_gained": maxi(0, int(resolved_state.get("death_bonus_card_plays_this_turn", 0)) - int(before_state.get("death_bonus_card_plays_this_turn", 0))),
		"card_action_plays_gained": maxi(0, int(resolved_state.get("card_play_bonus_this_turn", 0)) - int(before_state.get("card_play_bonus_this_turn", 0))),
		"card_time": _combat_engine.card_time_cost_from_def(printed_card),
		"turn_time_spent_before": int(before_state.get("player_turn_time_spent", 0)),
		"turn_time_spent_after": int(before_state.get("player_turn_time_spent", 0)) + _combat_engine.card_time_cost_from_def(printed_card),
		"player_base_initiative": _combat_engine.player_base_initiative(before_state),
		"elemental_intensity_before": intensity_before,
		"elemental_intensity_after": intensity_after,
		"elemental_intensity_gained": intensity_gained,
		"elemental_intensity_spent": intensity_spent,
		"pierce_actions": _analytics_pierce_action_count(actions),
		"sunder_actions": _analytics_attack_keyword_action_count(actions, "sunder"),
		"illusions_created": illusions_created,
		"illusion_health_created": illusion_health_created,
		"enemy_status_applied": {
			"burn": enemy_burn_applied,
			"bleed": enemy_bleed_applied,
			"expose": enemy_expose_applied,
			"freeze": enemy_freeze_applied,
			"shock": enemy_shock_applied,
			"immobilize": enemy_immobilize_applied,
			"poison": enemy_poison_applied
		},
		"player_status_applied": {
			"burn": player_burn_applied,
			"bleed": player_bleed_applied,
			"expose": player_expose_applied,
			"freeze": player_freeze_applied,
			"shock": player_shock_applied,
			"immobilize": player_immobilize_applied,
			"poison": player_poison_applied
		},
		"selected_targets": _vector2i_array(selected_targets),
		"actions": actions.duplicate(true)
	}

func _analytics_actions_without_runtime_orientation(actions: Array) -> Array:
	var result: Array = []
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			result.append(action_var)
			continue
		var action: Dictionary = (action_var as Dictionary).duplicate(true)
		action.erase("orientation")
		action.erase("force_direction")
		result.append(action)
	return result

func _elemental_intensity_delta(before_intensity: Dictionary, after_intensity: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		var gained: int = int(after_intensity.get(element_id, 0)) - int(before_intensity.get(element_id, 0))
		if gained > 0:
			result[element_id] = gained
	return result

func _elemental_intensity_counter_delta(before_state: Dictionary, after_state: Dictionary, counter_key: String) -> Dictionary:
	var result: Dictionary = {}
	var before_counter: Dictionary = _combat_engine.elemental_intensity_counter(before_state, counter_key)
	var after_counter: Dictionary = _combat_engine.elemental_intensity_counter(after_state, counter_key)
	for element_id: String in ElementData.all_elements():
		var delta: int = int(after_counter.get(element_id, 0)) - int(before_counter.get(element_id, 0))
		if delta > 0:
			result[element_id] = delta
	return result

func _card_play_capacity_value(state: Dictionary) -> int:
	return (
		int(state.get("cards_per_turn", 2))
		+ int(state.get("death_bonus_card_plays_this_turn", 0))
		+ int(state.get("card_play_bonus_this_turn", 0))
	)

func _analytics_pierce_action_count(actions: Array) -> int:
	return _analytics_attack_keyword_action_count(actions, "pierce")

func _analytics_attack_keyword_action_count(actions: Array, keyword: String) -> int:
	var count: int = 0
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if keyword == "pierce" and not bool(action.get(keyword, false)):
			continue
		if keyword != "pierce" and int(action.get(keyword, 0)) <= 0:
			continue
		if str(action.get("type", "")) in ["melee", "ranged", "aoe", "push", "pull"]:
			count += 1
	return count

func _analytics_picked_loot_count(before_state: Dictionary, after_state: Dictionary) -> int:
	var after_claimed: Dictionary = {}
	for after_loot_var: Variant in after_state.get("loot", []):
		if typeof(after_loot_var) != TYPE_DICTIONARY:
			continue
		var after_loot: Dictionary = after_loot_var
		if bool(after_loot.get("claimed", false)):
			after_claimed[_analytics_loot_key(after_loot)] = true
	var picked_count: int = 0
	for before_loot_var: Variant in before_state.get("loot", []):
		if typeof(before_loot_var) != TYPE_DICTIONARY:
			continue
		var before_loot: Dictionary = before_loot_var
		if bool(before_loot.get("claimed", false)):
			continue
		if after_claimed.has(_analytics_loot_key(before_loot)):
			picked_count += 1
	return picked_count

func _analytics_loot_key(loot: Dictionary) -> String:
	var loot_id: String = str(loot.get("id", ""))
	if not loot_id.is_empty():
		return loot_id
	var pos: Vector2i = loot.get("pos", Vector2i.ZERO)
	return "%s:%d:%d" % [str(loot.get("kind", "")), pos.x, pos.y]

func _analytics_enemy_defense_bypassed(before_state: Dictionary, resolved_state: Dictionary, actions: Array) -> int:
	if _analytics_pierce_action_count(actions) <= 0:
		return 0
	var total: int = 0
	var before_enemies: Array = before_state.get("enemies", [])
	var after_enemies: Array = resolved_state.get("enemies", [])
	for index: int in range(mini(before_enemies.size(), after_enemies.size())):
		if typeof(before_enemies[index]) != TYPE_DICTIONARY or typeof(after_enemies[index]) != TYPE_DICTIONARY:
			continue
		var before_enemy: Dictionary = before_enemies[index]
		var after_enemy: Dictionary = after_enemies[index]
		var hp_loss: int = maxi(0, int(before_enemy.get("hp", 0)) - int(after_enemy.get("hp", 0)))
		if hp_loss <= 0:
			continue
		var before_defense: int = maxi(0, int(before_enemy.get("block", 0))) + maxi(0, int(before_enemy.get("stoneskin", 0)))
		total += mini(hp_loss, before_defense)
	return total

func _analytics_log_enemy_status_ticks(phase_result: Dictionary) -> void:
	for step_var: Variant in phase_result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		var kind: String = str(step.get("kind", ""))
		if kind not in ["status_damage", "status"]:
			continue
		_analytics_store.write_event("enemy_status_tick", _analytics_context_from_states(_run_state, _combat_state), {
			"kind": kind,
			"actor_key": str(step.get("actor_key", "")),
			"actor_name": str(step.get("actor_name", "")),
			"label": str(step.get("label", "")),
			"amount": int(step.get("amount", 0)),
			"text": str(step.get("text", "")),
			"tile": step.get("tile", Vector2i(-1, -1))
		})

func _sync_combat_state_from_run() -> void:
	_combat_state = (_run_state.get("combat_state", {}) as Dictionary).duplicate(true)

func _sync_progression_from_run() -> void:
	var run_progression: Dictionary = (_run_state.get("progression", {}) as Dictionary).duplicate(true)
	if run_progression.is_empty():
		return
	_progression = ProgressionStore.set_embers(run_progression, _run_engine.held_embers(_run_state))

func _layout_mini_map_overlay() -> void:
	if mini_map_overlay == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var overlay_width: float = clampf(viewport_size.x * 0.15, 184.0, 244.0)
	var overlay_height: float = clampf(viewport_size.y * 0.20, 168.0, 224.0)
	mini_map_overlay.offset_left = -overlay_width - 8.0
	mini_map_overlay.offset_top = 8.0
	mini_map_overlay.offset_right = -8.0
	mini_map_overlay.offset_bottom = 8.0 + overlay_height

func _exit_tile_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	if str(_run_state.get("mode", "room")) != "room":
		return lookup
	for option: Dictionary in _run_engine.exit_options(_run_state):
		lookup[option.get("door_tile", Vector2i(-1, -1))] = option.get("coord", Vector2i.ZERO)
	return lookup

func _door_tile_for_destination(coord: Vector2i) -> Vector2i:
	for option: Dictionary in _run_engine.exit_options(_run_state):
		if option.get("coord", Vector2i.ZERO) == coord:
			return option.get("door_tile", INVALID_TARGET_TILE)
	return INVALID_TARGET_TILE

func _exit_labels_for_board() -> Dictionary:
	var labels: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var dir: Vector2i = option.get("dir", Vector2i.ZERO)
		var marker: String = "N" if dir == Vector2i(0, -1) else "E" if dir == Vector2i(1, 0) else "S" if dir == Vector2i(0, 1) else "W"
		labels[option.get("door_tile", Vector2i(-1, -1))] = marker
	return labels

func _exit_icon_ids_for_board() -> Dictionary:
	var icon_ids: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var room: Dictionary = option.get("room", {})
		icon_ids[option.get("door_tile", Vector2i(-1, -1))] = RoomIcons.icon_id_for_room(room)
	return icon_ids

func _active_door_tiles_for_board() -> Dictionary:
	var active: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var door_tile: Vector2i = option.get("door_tile", INVALID_TARGET_TILE)
		if door_tile.x < 0:
			continue
		active[door_tile] = true
	return active

func _locked_door_tiles_for_board() -> Dictionary:
	var locked: Dictionary = {}
	var current_coord: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = _run_engine.room_metadata(_run_state, current_coord)
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var destination: Vector2i = connection.get("coord", Vector2i(999, 999))
		var destination_room: Dictionary = _run_engine.room_metadata(_run_state, destination)
		if not bool(destination_room.get("visited", false)) or not bool(destination_room.get("sealed", false)):
			continue
		var door_tile: Vector2i = RoomGeneratorScript.door_tile_for_direction(connection.get("door_dir", Vector2i.ZERO))
		if door_tile.x < 0:
			continue
		locked[door_tile] = true
	return locked

func _process_victory_carry() -> void:
	if _is_debug_boss_run():
		_victory_carry_amount = _run_engine.held_embers(_run_state)
		_victory_carry_processed = true
		return
	var amount: int = _run_engine.held_embers(_run_state)
	_victory_carry_amount = amount
	_progression = ProgressionStore.set_embers(_progression, amount)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.clear_held_embers(_run_state)
	_run_state["progression"] = _progression.duplicate(true)
	_victory_carry_processed = true

func _process_defeat_loss() -> void:
	if _is_debug_boss_run():
		_defeat_loss_processed = true
		return
	var lost_amount: int = _run_engine.held_embers(_run_state)
	_progression = ProgressionStore.record_lost_embers(
		_progression,
		lost_amount,
		_run_state.get("current_room", Vector2i.ZERO),
		int(_run_state.get("run_index", 0))
	)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.clear_held_embers(_run_state)
	_run_state["progression"] = _progression.duplicate(true)
	_defeat_loss_processed = true

func _enemy_occupied_tiles(state: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	for enemy_var: Variant in state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if int(enemy.get("hp", 0)) <= 0:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			occupied[tile] = true
	for illusion_var: Variant in state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var
		if int(illusion.get("hp", 0)) <= 0:
			continue
		occupied[illusion.get("pos", Vector2i.ZERO)] = true
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		if int(terrain.get("hp", 0)) <= 0:
			continue
		occupied[terrain.get("pos", Vector2i.ZERO)] = true
	return occupied

func _enemy_footprint_tiles(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))

func _terrain_key(terrain: Dictionary) -> String:
	var terrain_id: String = str(terrain.get("id", ""))
	if terrain_id.is_empty():
		return ""
	return "terrain_%s" % terrain_id
