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
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const DeathEngulfOverlay = preload("res://scripts/death_engulf_overlay.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

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
const DIALOGUE_CHARACTERS_PER_SECOND: float = 34.0
const PLAYER_PREVIEW_FOCUS: Color = Color("f1d18b")
const PLAYER_ATTACK_FOCUS: Color = Color("f08c53")
const ILLUSION_PREVIEW_FOCUS: Color = Color("9beeff")
const INVALID_TARGET_TILE: Vector2i = Vector2i(-1, -1)
const SHORTCUT_ATTACK_TYPES := ["melee", "ranged", "push", "pull"]
const HAND_CARD_OVERLAP: float = -28.0
const HAND_CARD_GAP: float = 14.0
const PILE_CARD_SIZE: Vector2 = Vector2(220.0, 314.0)
const PILE_CARD_SCALE: float = 0.80
const PILE_STACK_OFFSET: Vector2 = Vector2(8.0, 10.0)
const PILE_STACK_LAYERS: int = 3
const UPGRADE_CARD_SIZE: Vector2 = Vector2(186.0, 266.0)
const CARD_BACK_TEXTURE_PATH: String = "res://assets/art/ui/card_back.png"
const CARD_FRAME_TEXTURE_PATH: String = "res://assets/art/ui/card_frame.png"
const CARD_PLAY_ICON_PATH: String = "res://assets/art/icons/card_play.png"
const EMBER_ICON_PATH: String = "res://assets/art/icons/ember.png"
const MAX_EMBER_REWARD_MOTES: int = 20
const CAMPFIRE_ACTION_OVERLAY_SIZE: Vector2 = Vector2(468.0, 88.0)
const RELIC_CHOICE_OVERLAY_SIZE: Vector2 = Vector2(760.0, 136.0)
const RELIC_CHOICE_CARD_SIZE: Vector2 = Vector2(172.0, 118.0)
const MENU_DIALOG_BUTTON_MIN_WIDTH: float = 234.0
const UPGRADE_LIST_BUTTON_MIN_WIDTH: float = 216.0
const MUSIC_FADE_SECONDS: float = 2.5
const MUSIC_SILENCE_DB: float = -60.0
@onready var room_title: Label = $Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomTitle
@onready var room_subtitle: Label = $Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomSubtitle
@onready var relic_bar: HFlowContainer = $Backdrop/Margin/MainVBox/TopBar/TitleBox/RelicBar
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
var _victory_bank_processed: bool = false
var _defeat_loss_processed: bool = false
var _victory_bank_amount: int = 0
var _exit_destinations_by_tile: Dictionary = {}
var _animation_lock: bool = false
var _board_presentation: Dictionary = {}
var _menu_scrim: ColorRect
var _menu_dialog: PanelContainer
var _pile_scrim: ColorRect
var _pile_dialog: PanelContainer
var _pile_dialog_title: Label
var _pile_dialog_cards: HFlowContainer
var _pile_dialog_empty: Label
var _pile_content_hosts: Dictionary = {}
var _pile_visual_hosts: Dictionary = {}
var _pile_badges: Dictionary = {}
var _active_pile_kind: String = ""
var _play_meter: PanelContainer
var _play_meter_count: Label
var _play_meter_icon: TextureRect
var _ember_count_override: int = -1
var _context_choice_overlay: PanelContainer
var _context_choice_bar: HBoxContainer
var _relic_choice_overlay: Control
var _relic_choice_bar: HBoxContainer
var _selected_card_label_override: String = ""
var _drag_overlay: Control
var _drag_zone_panels: Dictionary = {}
var _drag_zone_labels: Dictionary = {}
var _drag_card_index: int = -1
var _drag_card_options: Dictionary = {}
var _drag_hover_zone: String = ""
var _card_fx_layer: Control
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
var _dialogue_active: bool = false
var _dialogue_script: Dictionary = {}
var _dialogue_line_index: int = -1
var _dialogue_char_progress: float = 0.0
var _dialogue_text_complete: bool = false
var _last_auto_dialogue_key: String = ""

func _ready() -> void:
	set_process(true)
	_apply_style()
	_layout_mini_map_overlay()
	_build_overlay_ui()
	_build_context_choice_overlay()
	_setup_pile_widgets()
	_setup_play_meter()
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
	if event.is_action_pressed("ui_cancel"):
		await _on_cancel_requested()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run_progress()
		get_tree().quit()
	elif what == NOTIFICATION_RESIZED:
		_layout_mini_map_overlay()
		_layout_context_choice_overlay()
		_layout_relic_choice_overlay()

func _apply_style() -> void:
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
	relic_bar.visible = false
	relic_bar.add_theme_constant_override("h_separation", 8)
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

func _build_overlay_ui() -> void:
	_build_card_fx_layer()
	_build_dialogue_overlay()
	_build_menu_overlay()
	_build_pile_overlay()
	_build_card_upgrade_overlay()
	_build_drag_overlay()
	_build_death_overlay()

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
	stage_root.add_child(_relic_choice_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_choice_overlay.add_child(center)

	_relic_choice_bar = HBoxContainer.new()
	_relic_choice_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_choice_bar.add_theme_constant_override("separation", 18)
	center.add_child(_relic_choice_bar)
	_layout_relic_choice_overlay()

func _layout_relic_choice_overlay() -> void:
	if _relic_choice_overlay == null:
		return
	var stage_root: Control = board_view.get_parent()
	var stage_size: Vector2 = stage_root.size if stage_root != null else get_viewport_rect().size
	var width: float = clampf(stage_size.x * 0.74, 440.0, RELIC_CHOICE_OVERLAY_SIZE.x)
	var height: float = RELIC_CHOICE_OVERLAY_SIZE.y
	_relic_choice_overlay.anchor_left = 0.5
	_relic_choice_overlay.anchor_top = 1.0
	_relic_choice_overlay.anchor_right = 0.5
	_relic_choice_overlay.anchor_bottom = 1.0
	_relic_choice_overlay.offset_left = -width * 0.5
	_relic_choice_overlay.offset_right = width * 0.5
	_relic_choice_overlay.offset_top = -height - 20.0
	_relic_choice_overlay.offset_bottom = -20.0

func _build_card_fx_layer() -> void:
	_card_fx_layer = Control.new()
	_card_fx_layer.name = "CardFxLayer"
	_card_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_card_fx_layer.anchor_right = 1.0
	_card_fx_layer.anchor_bottom = 1.0
	add_child(_card_fx_layer)

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
	_dialogue_dialog.custom_minimum_size = Vector2(0.0, 214.0)
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
	_dialogue_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_text_label.custom_minimum_size = Vector2(0.0, 104.0)
	_dialogue_text_label.fit_content = false
	_dialogue_text_label.scroll_active = false
	UiTypography.set_rich_text_size(_dialogue_text_label, UiTypography.SIZE_SECTION)
	_dialogue_text_label.add_theme_color_override("default_color", Color("f5ebd8"))
	_dialogue_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_text_label)

	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0.0, 44.0)
	footer.add_theme_constant_override("separation", 12)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer)

	_dialogue_hint_label = Label.new()
	_dialogue_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(_dialogue_hint_label, UiTypography.SIZE_BODY)
	_dialogue_hint_label.add_theme_color_override("font_color", Color("cab697"))
	_dialogue_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_dialogue_hint_label)

	_dialogue_choice_bar = HBoxContainer.new()
	_dialogue_choice_bar.custom_minimum_size = Vector2(0.0, 44.0)
	_dialogue_choice_bar.alignment = BoxContainer.ALIGNMENT_END
	_dialogue_choice_bar.add_theme_constant_override("separation", 10)
	_dialogue_choice_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_dialogue_choice_bar)

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
	_pile_dialog.custom_minimum_size = Vector2(1220.0, 620.0)
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
	close_button.text = "X"
	_ui_skin.apply_button_stylebox_overrides(close_button)
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
	_ui_skin.apply_button_native_size(close_button, 36.0)
	close_button.pressed.connect(_close_pile_view)
	top_row.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_pile_dialog_cards = HFlowContainer.new()
	_pile_dialog_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_dialog_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_dialog_cards.add_theme_constant_override("h_separation", 12)
	_pile_dialog_cards.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_pile_dialog_cards)

	_pile_dialog_empty = Label.new()
	_pile_dialog_empty.text = "Nothing here."
	UiTypography.set_label_size(_pile_dialog_empty, UiTypography.SIZE_BODY)
	_pile_dialog_empty.add_theme_color_override("font_color", Color("d2c2a7"))
	_pile_dialog_empty.visible = false
	vbox.add_child(_pile_dialog_empty)

func _build_card_upgrade_overlay() -> void:
	_upgrade_scrim = ColorRect.new()
	_upgrade_scrim.name = "CardUpgradeScrim"
	_upgrade_scrim.visible = false
	_upgrade_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
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

	_drag_zone_panels["attack"] = _build_drag_zone("2 Attack", UiTypography.SIZE_SMALL, Vector2(273.0, 96.0), Color("cf7657"), Color("2f1d18"))
	bottom_row.add_child(_drag_zone_panels["attack"])
	_drag_zone_labels["attack"] = _drag_zone_panels["attack"].get_meta("label")

	_drag_zone_panels["move"] = _build_drag_zone("2 Move", UiTypography.SIZE_SMALL, Vector2(273.0, 96.0), Color("5b8ea2"), Color("18262f"))
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

func _update_dialogue_footer() -> void:
	_clear_dialogue_choices()
	if _dialogue_hint_label == null:
		return
	_dialogue_hint_label.text = ""
	if not _dialogue_active or not _dialogue_text_complete:
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
		UiTypography.set_button_size(button, UiTypography.SIZE_BODY)
		_ui_skin.apply_button_native_size(button, 44.0)
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
		_drag_card_proxy.queue_free()
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
			label_override = "2 Attack"
		"move":
			preview = options.get("move", {})
			label_override = "2 Move"
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

func _update_drag_proxy_position(mouse_position: Vector2) -> void:
	if _drag_card_proxy == null:
		return
	_drag_card_proxy.position = mouse_position - _drag_card_grab_offset

func _spawn_card_proxy(card_id: String, rect: Rect2) -> Control:
	var widget = CardWidgetScene.instantiate()
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.top_level = true
	widget.custom_minimum_size = rect.size
	widget.size = rect.size
	widget.position = rect.position
	widget.configure(card_id, false, false, true, false, false, true, _card_def(card_id, _combat_state))
	var display: Dictionary = _card_widget_display(card_id, _combat_state)
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	return widget

func _animate_card_proxy_to_rect(proxy: Control, target_rect: Rect2, duration: float) -> void:
	if proxy == null:
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "position", target_rect.position, duration)
	tween.parallel().tween_property(proxy, "size", target_rect.size, duration)
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
	var widget = CardWidgetScene.instantiate()
	widget.custom_minimum_size = card_size
	widget.position = Vector2.ZERO
	widget.size = card_size
	widget.configure(top_card_id, false, false, true, false, false, true, _card_def(top_card_id, _combat_state))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	host.add_child(widget)
	widget.position = Vector2.ZERO
	widget.size = card_size
	_set_mouse_filter_recursive(widget, Control.MOUSE_FILTER_IGNORE)

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
	_victory_bank_processed = false
	_defeat_loss_processed = false
	_victory_bank_amount = 0
	_death_sequence_started = false
	if _death_overlay != null:
		_death_overlay.reset()
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
	if str(_run_state.get("mode", "room")) == "victory" and not _victory_bank_processed:
		_process_victory_banking()
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
	mini_map.set_run_state(_run_state)
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
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(52.0, 52.0)
		frame.set_meta("relic_id", relic_id)
		frame.tooltip_text = "%s\n%s" % [
			str(relic.get("name", relic_id)),
			str(relic.get("description", ""))
		]
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		frame.add_theme_stylebox_override("panel", _pile_card_style(
			Color("261b14"),
			Color(str(relic.get("accent", "#8a6d49"))),
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
	var cards_left: int = _combat_engine.cards_remaining_this_turn(_combat_state)
	_play_meter_count.text = str(cards_left)
	var meter_tint: Color = Color.WHITE if cards_left > 0 else Color(1.0, 1.0, 1.0, 0.42)
	_play_meter.modulate = meter_tint

func _displayed_ember_count() -> int:
	if _ember_count_override >= 0:
		return _ember_count_override
	var total: int = int(_run_state.get("unbanked_embers", 0))
	if str(_run_state.get("mode", "room")) == "combat" and not _combat_state.is_empty():
		total += int(_combat_state.get("room_embers", 0))
	return total

func _set_stats_label_text(ember_count: int) -> void:
	stats_label.text = "EMBERS %d" % ember_count

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
	if _context_choice_overlay != null and mode != "campfire":
		_context_choice_overlay.visible = false
	menu_button.visible = mode != "defeat"
	if mode != "combat":
		_cancel_drag_play()
		_close_pile_view()
	if mode != "room":
		_close_card_upgrade_overlay()

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
	_clear_context_choice_overlay()
	_clear_relic_choice_overlay()
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "combat" and _selected_card_index >= 0:
		if _current_action_can_skip():
			_add_choice_button("Skip", _on_skip_action_pressed)
		_add_choice_button("Cancel", _on_cancel_requested)
	elif mode == "combat" and not _animation_lock and _drag_card_index < 0:
		_add_choice_button("Pass", _on_pass_turn_pressed)
	match mode:
		"campfire":
			_add_context_choice_button("Sit", _on_campfire_sit_pressed, "Rest and bank embers")
			_add_context_choice_button("Leave", _on_campfire_leave_pressed, "Continue onward")
		"treasure":
			for relic_id_var: Variant in _run_state.get("pending_relics", []):
				var relic_id: String = str(relic_id_var)
				var relic: Dictionary = GameData.relic_def(relic_id)
				_add_relic_choice(relic_id, relic)
		"victory":
			_add_choice_button("Menu", _on_back_to_menu_pressed)
			_add_choice_button("Again", _on_restart_pressed)
	choice_bar.visible = choice_bar.get_child_count() > 0
	if _context_choice_overlay != null:
		_context_choice_overlay.visible = _context_choice_bar != null and _context_choice_bar.get_child_count() > 0
	if _relic_choice_overlay != null:
		_relic_choice_overlay.visible = _relic_choice_bar != null and _relic_choice_bar.get_child_count() > 0

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
	choice_bar.add_child(button)

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
		_clear_children(_context_choice_bar)
	if _context_choice_overlay != null:
		_context_choice_overlay.visible = false

func _clear_relic_choice_overlay() -> void:
	if _relic_choice_bar != null:
		_clear_children(_relic_choice_bar)
	if _relic_choice_overlay != null:
		_relic_choice_overlay.visible = false

func _add_relic_choice(relic_id: String, relic: Dictionary) -> void:
	if _relic_choice_bar == null:
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size = RELIC_CHOICE_CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = str(relic.get("description", ""))
	panel.add_theme_stylebox_override("panel", _relic_choice_style(Color(str(relic.get("accent", "#8a6d49"))), false))
	panel.gui_input.connect(_on_relic_choice_gui_input.bind(relic_id))
	panel.mouse_entered.connect(_set_relic_choice_hovered.bind(panel, relic, true))
	panel.mouse_exited.connect(_set_relic_choice_hovered.bind(panel, relic, false))
	_relic_choice_bar.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58.0, 58.0)
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
	label.custom_minimum_size = Vector2(RELIC_CHOICE_CARD_SIZE.x - 24.0, 34.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
	label.add_theme_color_override("font_color", Color("fff1d5"))
	label.add_theme_color_override("font_outline_color", Color("26180f"))
	label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(label)

func _set_relic_choice_hovered(panel: PanelContainer, relic: Dictionary, hovered: bool) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _relic_choice_style(Color(str(relic.get("accent", "#8a6d49"))), hovered))

func _relic_choice_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.045, 0.92).lightened(0.08) if hovered else Color(0.09, 0.06, 0.045, 0.86)
	style.border_color = accent.lightened(0.20) if hovered else Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 10 if hovered else 6
	return style

func _on_relic_choice_gui_input(event: InputEvent, relic_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		await _on_relic_pressed(relic_id)

func _refresh_hand_panel() -> void:
	_clear_children(hand_box)
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
	var slot := Control.new()
	slot.custom_minimum_size = card_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(widget)
	widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return slot

func _reward_heal_choice_slot(heal_amount: int, slot_size: Vector2) -> Control:
	var slot := CenterContainer.new()
	slot.custom_minimum_size = slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.text = "+%d HP" % heal_amount
	button.tooltip_text = "Recover instead"
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION)
	var button_height: float = minf(UiSkin.BUTTON_HEIGHT_ACTION, maxf(UiSkin.BUTTON_HEIGHT_STANDARD, slot_size.x / UiSkin.BUTTON_TEXTURE_ASPECT))
	_ui_skin.apply_button_native_size(button, button_height)
	button.pressed.connect(_on_skip_reward_pressed)
	slot.add_child(button)
	return slot

func _refresh_stage_view() -> void:
	_exit_destinations_by_tile = _exit_tile_lookup()
	var display_state: Dictionary = _board_display_state()
	var move_tiles: Array[Vector2i] = []
	var attack_tiles: Array[Vector2i] = []
	var presentation: Dictionary = _board_presentation.duplicate(true)
	var preview: Dictionary = {}
	if str(_run_state.get("mode", "room")) == "combat" and not _animation_lock:
		preview = _active_card_preview()
		if not preview.is_empty() and not bool(preview.get("complete", false)):
			var action: Dictionary = preview.get("action", {})
			var target_tiles: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
			if str(action.get("type", "")) in ["move", "blink"]:
				move_tiles = target_tiles
				var shortcuts: Dictionary = _preview_shortcuts_for_current_action(preview)
				attack_tiles = _vector2i_array(shortcuts.get("tiles", []))
			else:
				attack_tiles = target_tiles
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
	if not _animation_lock and str(_run_state.get("mode", "room")) == "room" and _hovered_board_tile.x >= 0 and _exit_destinations_by_tile.has(_hovered_board_tile):
		presentation["focus_tiles"] = [_hovered_board_tile]
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
		"log": []
	}

func _active_card_preview() -> Dictionary:
	if _drag_card_index >= 0:
		return {}
	if _selected_card_index >= 0:
		if _pending_action_index < _pending_actions.size():
			return {
				"card_id": _card_id_for_hand_index(_selected_card_index),
				"state": _preview_combat_state.duplicate(true),
				"actions": _pending_actions.duplicate(true),
				"action_index": _pending_action_index,
				"target_tiles": _vector2i_array(_pending_target_tiles),
				"complete": false,
				"playable": true,
				"action": _pending_actions[_pending_action_index],
				"skip_allowed": _pending_action_can_skip
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
			return [{"type": "melee", "damage": 2, "range": 1}]
		"move":
			return [{"type": "move", "range": 2}]
		_:
			return []

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
				var base_damage: int = int(action.get("damage", 0))
				var final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
				summary_rows.append(ActionIcons.tokens_for_action(action, {"final_damage": final_damage}))
				for modifier: Dictionary in _combat_engine.damage_modifiers_for_player_action(preview_state, action):
					modifier_lines.append(_damage_modifier_line(modifier))
				_consume_preview_damage_modifiers(preview_state, action)
			"push", "pull":
				summary_rows.append(ActionIcons.tokens_for_action(action, {"final_damage": _combat_engine.final_damage_for_player_action(preview_state, action)}))
				for modifier: Dictionary in _combat_engine.damage_modifiers_for_player_action(preview_state, action):
					modifier_lines.append(_damage_modifier_line(modifier))
				_consume_preview_damage_modifiers(preview_state, action)
			_:
				var row: Array = ActionIcons.tokens_for_action(action)
				if not row.is_empty():
					summary_rows.append(row)
	var summary_text: String = ActionIcons.plain_text_for_rows(summary_rows)
	if summary_text.is_empty():
		summary_text = str(card.get("description", ""))
	return {
		"summary_bbcode": summary_text,
		"summary_rows": summary_rows,
		"modifier_lines": modifier_lines
	}

func _damage_modifier_line(modifier: Dictionary) -> String:
	var amount: int = int(modifier.get("amount", 0))
	var amount_label: String = "%+d" % amount
	var source: String = str(modifier.get("source", "Modifier"))
	var detail: String = str(modifier.get("detail", ""))
	if detail.is_empty():
		return "%s %s" % [source, amount_label]
	return "%s %s  %s" % [source, amount_label, detail]

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
			var valid_targets: Array[Vector2i] = []
			for target_tile: Vector2i in _combat_engine.valid_targets_for_player_action(working_state, action):
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
			result["focus_color"] = Color(0.40, 0.86, 0.94, 0.22)
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
	if _hovered_board_tile.x < 0:
		return []
	var shortcut_plan: Dictionary = _hovered_shortcut_plan_for_preview(preview)
	if not shortcut_plan.is_empty():
		var path_tiles: Array[Vector2i] = _vector2i_array(shortcut_plan.get("path_tiles", []))
		return path_tiles if not path_tiles.is_empty() else _vector2i_array([_hovered_board_tile])
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type in ["move", "blink"]:
		return _path_tiles_for_preview(preview)
	if action_type == "aoe":
		return _aoe_tiles_for_action(preview.get("state", {}), action, _hovered_board_tile)
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
			return {
				"kind": "ranged" if action_type in ["push", "pull"] else action_type,
				"from": from_tile,
				"to": target_tile,
				"preview": true,
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
	_append_skipped_target_placeholders(0, _pending_action_index)
	_refresh_ui()

func _on_card_hover_started(index: int) -> void:
	if _animation_lock or _selected_card_index >= 0 or _drag_card_index >= 0 or str(_run_state.get("mode", "room")) != "combat":
		return
	_hovered_card_index = index
	_refresh_stage_view()

func _on_card_hover_ended(index: int) -> void:
	if _selected_card_index >= 0 or _drag_card_index >= 0:
		return
	if _hovered_card_index == index:
		_hovered_card_index = -1
		_refresh_stage_view()

func _on_board_tile_hovered(tile: Vector2i) -> void:
	if _dialogue_active or _drag_card_index >= 0:
		return
	_hovered_board_tile = tile
	if str(_run_state.get("mode", "room")) in ["combat", "room"]:
		_refresh_stage_view()

func _on_board_tile_clicked(tile: Vector2i) -> void:
	if _dialogue_active or _animation_lock or _drag_card_index >= 0:
		return
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "room" and _exit_destinations_by_tile.has(tile):
		await _on_map_view_room_selected(_exit_destinations_by_tile[tile], tile)
		return
	if mode != "combat" or _selected_card_index < 0:
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
	_refresh_ui()
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
	_animation_lock = false
	_animating_hand_card_index = -1
	_reset_card_resolution()
	_hovered_card_index = -1
	_refresh_ui()
	if str(_run_state.get("mode", "room")) == "combat" and _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		await _resolve_enemy_round()

func _card_destination_pile(card_id: String) -> String:
	return "burn" if bool(_card_def(card_id, _combat_state).get("burn", false)) else "discard"

func _animate_card_play_fx(card_id: String, source_rect: Rect2, size_hint: Vector2) -> void:
	return

func _animate_card_to_pile_fx(card_id: String, pile_kind: String, size_hint: Vector2) -> void:
	return

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
		var proxy: Control = _spawn_card_proxy(card_id, source_rect)
		_card_fx_layer.add_child(proxy)
		await _animate_card_proxy_to_rect(proxy, _hand_receive_rect(target_index, target_total, size_hint * 0.94), DRAW_FRAME_SECONDS)
		proxy.queue_free()
		await get_tree().create_timer(0.05).timeout

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
	var displayed_embers: int = int(_run_state.get("unbanked_embers", 0)) + int(before_state.get("room_embers", 0))
	var displayed_card_plays: int = _combat_engine.cards_remaining_this_turn(before_state)
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
	_play_meter_count.text = str(displayed_card_plays)
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
		var animated_texts: Array[Dictionary] = []
		for text_var: Variant in base_texts:
			var text_entry: Dictionary = (text_var as Dictionary).duplicate(true)
			text_entry["rise"] = lerpf(0.0, 14.0, t)
			text_entry["alpha"] = 1.0 if t < 0.72 else clampf(1.0 - ((t - 0.72) / 0.28), 0.0, 1.0)
			animated_texts.append(text_entry)
		presentation["floating_texts"] = animated_texts
		_render_board_state(display_state, presentation)
		await get_tree().create_timer(frame_seconds).timeout

func _animate_player_card_resolution(animated_state: Dictionary, card_id: String, actions: Array, selected_targets: Array[Vector2i]) -> void:
	var target_index: int = 0
	for action_var: Variant in actions:
		var action: Dictionary = action_var
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

func _animate_player_action_step(before_state: Dictionary, after_state: Dictionary, card_id: String, action: Dictionary, target_tile: Vector2i) -> void:
	var action_type: String = str(action.get("type", ""))
	if _combat_engine.player_action_needs_target(action) and target_tile.x < 0:
		return
	var player_before: Dictionary = before_state.get("player", {})
	var player_after: Dictionary = after_state.get("player", {})
	var player_before_tile: Vector2i = player_before.get("pos", Vector2i.ZERO)
	var player_after_tile: Vector2i = player_after.get("pos", player_before_tile)
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
				"tiles": focus_tiles
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
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_ATTACK_FOCUS,
				"focus_tiles": focus_tiles,
				"focus_color": Color(0.95, 0.62, 0.37, 0.22),
				"effect": effect,
				"effect_progress": 1.0,
				"impact_actor_keys": _damaged_enemy_keys(before_state, after_state),
				"floating_texts": _player_damage_floating_texts(before_state, after_state)
				})
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
			var card_plays_gained: int = maxi(0, _combat_engine.cards_remaining_this_turn(after_state) - _combat_engine.cards_remaining_this_turn(before_state))
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
			await _animate_card_play_reward(_combat_engine.cards_remaining_this_turn(after_state))
			await get_tree().create_timer(0.10).timeout
	await _animate_death_rewards(before_state, after_state)

func _resolve_enemy_round() -> void:
	_animation_lock = true
	_refresh_ui()
	var previous_run_state: Dictionary = _run_state.duplicate(true)
	var previous_combat_state: Dictionary = _combat_state.duplicate(true)
	var previous_tracker: Dictionary = _analytics_snapshot_combat_tracker()
	var phase_result: Dictionary = _combat_engine.resolve_enemy_phase_with_steps(_combat_state)
	var animated_state: Dictionary = _combat_state.duplicate(true)
	_clear_enemy_blocks(animated_state)
	await _animate_enemy_phase_steps(animated_state, phase_result.get("steps", []))
	_board_presentation.clear()
	_set_action_banner("")
	_combat_state = (phase_result.get("state", {}) as Dictionary).duplicate(true)
	_analytics_log_enemy_status_ticks(phase_result)
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	if outcome == "":
		var before_draw_state: Dictionary = _combat_state.duplicate(true)
		_combat_state = _combat_engine.prepare_next_player_turn(_combat_state)
		_analytics_reconcile_combat_tracker(before_draw_state, _combat_state)
		_analytics_log_card_draws(before_draw_state, _combat_state, previous_tracker, _analytics_snapshot_combat_tracker(), "turn_draw")
		_analytics_log_playable_cards()
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
			"intent":
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
				await _animate_floating_text_presentation(animated_state, {
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.95, 0.62, 0.37, 0.18),
					"effect": step,
					"effect_progress": 1.0,
					"impact_actor_keys": impact_actor_keys,
					"floating_texts": _floating_texts_for_step(step)
				})

func _animate_move_step(animated_state: Dictionary, step: Dictionary) -> void:
	var from_tile: Vector2i = step.get("from", Vector2i.ZERO)
	var to_tile: Vector2i = step.get("to", Vector2i.ZERO)
	var actor_key: String = str(step.get("actor_key", ""))
	var from_point: Vector2 = board_view.world_position_for_tile(from_tile)
	var to_point: Vector2 = board_view.world_position_for_tile(to_tile)
	_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	for frame: int in range(1, MOVE_STEP_FRAMES + 1):
		var t: float = float(frame) / float(MOVE_STEP_FRAMES)
		_render_board_state(animated_state, {
			"focus_actor_keys": [actor_key],
			"focus_actor_color": PLAYER_ATTACK_FOCUS,
			"focus_tiles": [to_tile],
			"focus_color": Color(0.95, 0.62, 0.37, 0.18),
			"unit_world_positions": {actor_key: from_point.lerp(to_point, t)},
			"unit_draw_tiles": {actor_key: to_tile}
		})
		await get_tree().create_timer(MOVE_FRAME_SECONDS).timeout
	_apply_animation_step(animated_state, step)
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
			if not target_losses.is_empty():
				return _floating_texts_for_target_losses(target_losses, str(step.get("status_text", "")), step.get("to", Vector2i.ZERO))
			var floats: Array[Dictionary] = []
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

func _set_action_banner(text: String) -> void:
	action_banner.visible = not text.is_empty()
	action_banner.text = text

func _board_status_label(preview: Dictionary) -> String:
	var mode: String = str(_run_state.get("mode", "room"))
	if _animation_lock:
		return ""
	if mode == "combat":
		var restrictions: Dictionary = (_combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
		if bool(restrictions.get("frozen", false)):
			return "Frozen"
		if bool(restrictions.get("stunned", false)):
			return "Stunned"
		if bool(restrictions.get("shocked", false)) and _selected_card_index < 0 and _hovered_card_index < 0:
			return "Shocked"
		if _drag_card_index >= 0:
			return "Play Card"
		if _selected_card_index >= 0:
			if not _selected_card_label_override.is_empty():
				return _selected_card_label_override
			return str(_card_def(_card_id_for_hand_index(_selected_card_index), _combat_state).get("name", "Card"))
		if _hovered_card_index >= 0 and bool(preview.get("playable", false)):
			return str(_card_def(str(preview.get("card_id", "")), _combat_state).get("name", "Card"))
		if not _has_any_playable_combat_card():
			return "Pass"
		if not _has_playable_combat_card():
			return "Drag Card"
		return "Pick Card"
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
		var restrictions: Dictionary = (_combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
		if bool(restrictions.get("frozen", false)):
			return "Pass to continue"
		if bool(restrictions.get("stunned", false)):
			return "Pass to continue"
		if bool(restrictions.get("shocked", false)) and _selected_card_index < 0 and _hovered_card_index < 0:
			return "Only move/blink, or pass"
		if _drag_card_index >= 0:
			if _drag_hover_zone == "play":
				return "Play"
			if _drag_hover_zone == "attack":
				return "2 attack"
			if _drag_hover_zone == "move":
				return "2 move"
			return "Drop in a lane"
		if _selected_card_index >= 0 and _pending_action_index < _pending_actions.size():
			return _action_prompt(_pending_actions[_pending_action_index])
		if _hovered_card_index >= 0 and not preview.is_empty() and not bool(preview.get("complete", true)):
			return _action_prompt(preview.get("action", {}))
		if _combat_engine.cards_remaining_this_turn(_combat_state) > 0 and not _has_playable_combat_card() and _has_any_playable_combat_card():
			return "2 atk / 2 move"
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
				"offset": -10.0
			})
		if block_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d B" % block_loss,
				"color": Color("90d9ff"),
				"offset": 10.0
			})
		if stoneskin_loss > 0:
			floats.append({
				"tile": enemy.get("pos", Vector2i.ZERO),
				"text": "-%d S" % stoneskin_loss,
				"color": ElementData.accent(ElementData.EARTH),
				"offset": 22.0
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
	_sync_progression_from_run()
	var bankable: int = _run_engine.bankable_embers(_run_state)
	if bankable > 0:
		_progression = ProgressionStore.add_embers(_progression, bankable)
	_progression = ProgressionStore.mark_rested_at_fire(_progression)
	ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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
	ProgressionStore.save_data(_progression)
	var mode: String = str(_run_state.get("mode", ""))
	if mode in ["victory", "defeat"] or _run_state.is_empty():
		ProgressionStore.clear_saved_run()
		return
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
	_active_pile_kind = pile_kind
	_pile_dialog_title.text = "%s Pile" % _pile_display_name(pile_kind)
	_clear_children(_pile_dialog_cards)
	for card_id_var: Variant in cards:
		var widget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = PILE_CARD_SIZE
		widget.configure(str(card_id_var), false, false, true, false, false, true, _card_def(str(card_id_var)))
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pile_dialog_cards.add_child(widget)
	_pile_dialog_empty.visible = cards.is_empty()
	_pile_scrim.visible = true

func _close_pile_view() -> void:
	if _pile_scrim != null:
		_pile_scrim.visible = false
	_active_pile_kind = ""

func _open_card_upgrade_overlay() -> void:
	if _upgrade_scrim == null:
		return
	_cancel_drag_play()
	_close_pile_view()
	_close_menu_overlay()
	_refresh_card_upgrade_overlay()
	_upgrade_scrim.visible = true

func _close_card_upgrade_overlay() -> void:
	if _upgrade_scrim != null:
		_upgrade_scrim.visible = false

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
	var current_widget = CardWidgetScene.instantiate()
	current_widget.custom_minimum_size = UPGRADE_CARD_SIZE
	current_widget.configure(_upgrade_selected_card_id, false, false, true, false, false, true, current_card)
	current_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_preview_box.add_child(current_widget)
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
	var preview_widget = CardWidgetScene.instantiate()
	preview_widget.custom_minimum_size = UPGRADE_CARD_SIZE
	preview_widget.configure(_upgrade_selected_card_id, false, false, true, false, false, true, preview_card)
	preview_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview_widget)

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
	var max_width: float = 236.0 if reward_mode else 232.0
	var min_width: float = 188.0 if reward_mode else 184.0
	var width: float = clampf(target_width, min_width, max_width)
	return Vector2(width, width * 1.42)

func _card_id_for_hand_index(index: int) -> String:
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return ""
	return str(hand[index])

func _card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	if not state.is_empty() and (state.has("card_upgrades") or state.has("card_mods")):
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
	_preview_combat_state.clear()
	_hovered_board_tile = Vector2i(-1, -1)

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()

func _clear_children_now(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

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
	return {
		"run_id": str(run_analytics.get("run_id", "")),
		"combat_id": str(combat_analytics.get("combat_id", "")),
		"turn": int(combat_state.get("turn", 0)),
		"room_depth": int(combat_state.get("room_depth", room_meta.get("depth", 0))),
		"room_element": str(combat_state.get("room_element", room_meta.get("element", ""))),
		"player_hp": int(player.get("hp", run_state.get("player_hp", -1))),
		"player_max_hp": int(player.get("max_hp", run_state.get("player_max_hp", -1))),
		"deck_size": int((run_state.get("deck_cards", []) as Array).size()),
		"card_id": card_id,
		"card_instance_id": card_instance_id
	}

func _analytics_log_run_started() -> void:
	_analytics_store.write_event("run_started", _analytics_context_from_states(_run_state, _combat_state), {
		"seed": int(_run_state.get("seed", 0)),
		"run_index": int(_run_state.get("run_index", 0)),
		"player_start_hp": int(_run_state.get("player_hp", 0)),
		"player_max_hp": int(_run_state.get("player_max_hp", 0)),
		"starting_deck": (_run_state.get("deck_cards", []) as Array).duplicate(true)
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
		"unbanked_embers": int(_run_state.get("unbanked_embers", 0)),
		"mode": str(_run_state.get("mode", "room"))
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
		"deck_cards": (_run_state.get("deck_cards", []) as Array).duplicate(true),
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
	var enemy_freeze_applied: int = 0
	var enemy_shock_applied: int = 0
	var enemy_stun_applied: int = 0
	var enemy_poison_applied: int = 0
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
		enemy_freeze_applied += maxi(0, int(after_enemy.get("freeze", 0)) - int(before_enemy.get("freeze", 0)))
		enemy_shock_applied += maxi(0, int(after_enemy.get("shock", 0)) - int(before_enemy.get("shock", 0)))
		enemy_stun_applied += maxi(0, int(after_enemy.get("stun", 0)) - int(before_enemy.get("stun", 0)))
		enemy_poison_applied += maxi(0, int((after_enemy.get("poison", {}) as Dictionary).get("damage", 0)) - int((before_enemy.get("poison", {}) as Dictionary).get("damage", 0)))
	var player_burn_applied: int = maxi(0, int(after_player.get("burn", 0)) - int(before_player.get("burn", 0)))
	var player_freeze_applied: int = maxi(0, int(after_player.get("freeze", 0)) - int(before_player.get("freeze", 0)))
	var player_shock_applied: int = maxi(0, int(after_player.get("shock", 0)) - int(before_player.get("shock", 0)))
	var player_stun_applied: int = maxi(0, int(after_player.get("stun", 0)) - int(before_player.get("stun", 0)))
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
	var play_mode: String = "printed"
	if JSON.stringify(actions) != JSON.stringify(printed_actions):
		play_mode = "attack" if JSON.stringify(actions) == JSON.stringify(_fallback_actions("attack")) else "move" if JSON.stringify(actions) == JSON.stringify(_fallback_actions("move")) else "custom"
	return {
		"play_mode": play_mode,
		"printed_health_cost": int(printed_card.get("health_cost", 0)),
		"enemy_hp_damage": enemy_hp_damage,
		"enemy_block_removed": enemy_block_removed,
		"enemy_stoneskin_removed": enemy_stoneskin_removed,
		"kills_secured": kills_secured,
		"player_hp_delta": int(after_player.get("hp", 0)) - int(before_player.get("hp", 0)),
		"player_heal_gained": maxi(0, int(after_player.get("hp", 0)) - int(before_player.get("hp", 0))),
		"player_block_gained": maxi(0, int(after_player.get("block", 0)) - int(before_player.get("block", 0))),
		"player_stoneskin_gained": maxi(0, int(after_player.get("stoneskin", 0)) - int(before_player.get("stoneskin", 0))),
		"move_distance": absi(after_pos.x - before_pos.x) + absi(after_pos.y - before_pos.y),
		"cards_drawn": _draw_entries_between_states(before_state, resolved_state).size(),
		"card_plays_gained": maxi(0, _combat_engine.cards_remaining_this_turn(resolved_state) - _combat_engine.cards_remaining_this_turn(before_state)),
		"illusions_created": illusions_created,
		"illusion_health_created": illusion_health_created,
		"enemy_status_applied": {
			"burn": enemy_burn_applied,
			"freeze": enemy_freeze_applied,
			"shock": enemy_shock_applied,
			"stun": enemy_stun_applied,
			"poison": enemy_poison_applied
		},
		"player_status_applied": {
			"burn": player_burn_applied,
			"freeze": player_freeze_applied,
			"shock": player_shock_applied,
			"stun": player_stun_applied,
			"poison": player_poison_applied
		},
		"selected_targets": _vector2i_array(selected_targets),
		"actions": actions.duplicate(true)
	}

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
	_progression = run_progression

func _layout_mini_map_overlay() -> void:
	if mini_map_overlay == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var overlay_width: float = clampf(viewport_size.x * 0.105, 132.0, 168.0)
	var overlay_height: float = clampf(viewport_size.y * 0.145, 132.0, 164.0)
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

func _process_victory_banking() -> void:
	if _is_debug_boss_run():
		_victory_bank_amount = _run_engine.bankable_embers(_run_state)
		_victory_bank_processed = true
		return
	var amount: int = _run_engine.bankable_embers(_run_state)
	_victory_bank_amount = amount
	if amount > 0:
		_progression = ProgressionStore.add_embers(_progression, amount)
		ProgressionStore.save_data(_progression)
		_run_state = _run_engine.consume_banked_embers(_run_state)
	_run_state["progression"] = _progression.duplicate(true)
	_victory_bank_processed = true

func _process_defeat_loss() -> void:
	if _is_debug_boss_run():
		_defeat_loss_processed = true
		return
	var lost_amount: int = _run_engine.bankable_embers(_run_state)
	_progression = ProgressionStore.record_lost_embers(
		_progression,
		lost_amount,
		_run_state.get("current_room", Vector2i.ZERO),
		int(_run_state.get("run_index", 0))
	)
	ProgressionStore.save_data(_progression)
	_run_state = _run_engine.consume_banked_embers(_run_state)
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
