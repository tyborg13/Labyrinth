extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const DialogueEngineScript = preload("res://scripts/dialogue_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const STEP_DELAY_SECONDS: float = 0.26
const MOVE_STEP_FRAMES: int = 10
const MOVE_FRAME_SECONDS: float = 0.045
const ATTACK_FRAMES: int = 6
const ATTACK_FRAME_SECONDS: float = 0.04
const DRAW_FRAME_SECONDS: float = 0.23
const CARD_PLAY_SECONDS: float = 0.14
const CARD_PILE_SECONDS: float = 0.18
const CARD_SNAPBACK_SECONDS: float = 0.14
const FLOAT_TEXT_FRAMES: int = 7
const FLOAT_TEXT_FRAME_SECONDS: float = 0.05
const DIALOGUE_CHARACTERS_PER_SECOND: float = 34.0
const PLAYER_PREVIEW_FOCUS: Color = Color("f1d18b")
const PLAYER_ATTACK_FOCUS: Color = Color("f08c53")

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
@onready var choice_bar: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/ChoiceBar
@onready var hand_row: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow
@onready var piles_bar: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar
@onready var draw_pile: PanelContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/DrawPile
@onready var discard_pile: PanelContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/DiscardPile
@onready var burn_pile: PanelContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/BurnPile
@onready var draw_count: Label = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/DrawPile/DrawMargin/DrawVBox/DrawCount
@onready var discard_count: Label = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/DiscardPile/DiscardMargin/DiscardVBox/DiscardCount
@onready var burn_count: Label = $Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/BurnPile/BurnMargin/BurnVBox/BurnCount
@onready var hand_scroll: ScrollContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll
@onready var hand_box: HBoxContainer = $Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox

var _ui_skin: UiSkin = UiSkin.new()
var _dialogue_engine = DialogueEngineScript.new()
var _run_engine = RunEngineScript.new()
var _combat_engine = CombatEngineScript.new()
var _progression: Dictionary = {}
var _run_state: Dictionary = {}
var _combat_state: Dictionary = {}
var _preview_combat_state: Dictionary = {}
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
var _pile_badges: Dictionary = {}
var _pile_previews: Dictionary = {}
var _pile_captions: Dictionary = {}
var _pile_fronts: Dictionary = {}
var _active_pile_kind: String = ""
var _selected_card_label_override: String = ""
var _drag_overlay: Control
var _drag_zone_panels: Dictionary = {}
var _drag_zone_labels: Dictionary = {}
var _drag_card_index: int = -1
var _drag_card_options: Dictionary = {}
var _drag_hover_zone: String = ""
var _card_fx_layer: Control
var _drag_card_proxy: Control
var _drag_card_source_rect: Rect2 = Rect2()
var _drag_card_grab_offset: Vector2 = Vector2.ZERO
var _animating_hand_card_index: int = -1
var _dialogue_overlay: Control
var _dialogue_dialog: PanelContainer
var _dialogue_name_label: Label
var _dialogue_text_label: Label
var _dialogue_hint_label: Label
var _dialogue_choice_bar: HBoxContainer
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
	_setup_pile_widgets()
	_boot_run()

func _process(delta: float) -> void:
	if not _dialogue_active or _dialogue_text_complete or _dialogue_text_label == null:
		return
	var line: Dictionary = _current_dialogue_line()
	var text: String = str(line.get("text", ""))
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
	UiTypography.set_label_size(room_title, UiTypography.SIZE_SECTION_LARGE)
	UiTypography.set_label_size(room_subtitle, UiTypography.SIZE_SMALL)
	UiTypography.set_label_size(stats_label, UiTypography.SIZE_SMALL)
	UiTypography.set_label_size(action_banner, UiTypography.SIZE_SMALL)
	room_title.add_theme_color_override("font_color", Color("f0e6d2"))
	room_title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	room_title.add_theme_constant_override("outline_size", 2)
	room_subtitle.add_theme_color_override("font_color", Color("cdbca2"))
	stats_label.add_theme_color_override("font_color", Color("f0c978"))
	stats_label.add_theme_color_override("font_outline_color", Color("2c1f16"))
	stats_label.add_theme_constant_override("outline_size", 1)
	relic_bar.visible = false
	relic_bar.add_theme_constant_override("h_separation", 6)
	relic_bar.add_theme_constant_override("v_separation", 6)
	action_banner.add_theme_color_override("font_color", Color("fbf0d7"))
	action_banner.add_theme_color_override("font_outline_color", Color("2d1f18"))
	action_banner.add_theme_constant_override("outline_size", 2)
	_ui_skin.apply_button_stylebox_overrides(menu_button)
	_ui_skin.apply_button_text_overrides(menu_button)
	menu_button.disabled = false
	menu_button.modulate = Color.WHITE
	UiTypography.set_button_size(menu_button, UiTypography.SIZE_SMALL)
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
	piles_bar.custom_minimum_size = Vector2(286.0, 0.0)
	hand_row.custom_minimum_size = Vector2(0.0, 224.0)
	for pile_label: Label in [
		$Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/DrawPile/DrawMargin/DrawVBox/DrawTitle,
		$Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/DiscardPile/DiscardMargin/DiscardVBox/DiscardTitle,
		$Backdrop/Margin/MainVBox/BottomStack/HandRow/PilesBar/BurnPile/BurnMargin/BurnVBox/BurnTitle,
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
	_build_drag_overlay()

func _build_card_fx_layer() -> void:
	_card_fx_layer = Control.new()
	_card_fx_layer.name = "CardFxLayer"
	_card_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_card_fx_layer.anchor_right = 1.0
	_card_fx_layer.anchor_bottom = 1.0
	add_child(_card_fx_layer)

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
		button.custom_minimum_size = Vector2(0.0, 40.0)
		_ui_skin.apply_button_stylebox_overrides(button)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
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
	_dialogue_dialog.custom_minimum_size = Vector2(0.0, 156.0)
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
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_dialogue_name_label = Label.new()
	UiTypography.set_label_size(_dialogue_name_label, UiTypography.SIZE_SMALL)
	_dialogue_name_label.add_theme_color_override("font_color", Color("f0c978"))
	_dialogue_name_label.add_theme_color_override("font_outline_color", Color("2d1f18"))
	_dialogue_name_label.add_theme_constant_override("outline_size", 1)
	_dialogue_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_name_label)

	_dialogue_text_label = Label.new()
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text_label.visible_characters = 0
	_dialogue_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text_label.custom_minimum_size = Vector2(0.0, 78.0)
	UiTypography.set_label_size(_dialogue_text_label, UiTypography.SIZE_BODY)
	_dialogue_text_label.add_theme_color_override("font_color", Color("f5ebd8"))
	_dialogue_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialogue_text_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer)

	_dialogue_hint_label = Label.new()
	_dialogue_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.set_label_size(_dialogue_hint_label, UiTypography.SIZE_SMALL)
	_dialogue_hint_label.add_theme_color_override("font_color", Color("cab697"))
	_dialogue_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_dialogue_hint_label)

	_dialogue_choice_bar = HBoxContainer.new()
	_dialogue_choice_bar.alignment = BoxContainer.ALIGNMENT_END
	_dialogue_choice_bar.add_theme_constant_override("separation", 10)
	_dialogue_choice_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_dialogue_choice_bar)

func _build_pile_overlay() -> void:
	_pile_scrim = ColorRect.new()
	_pile_scrim.name = "PileScrim"
	_pile_scrim.visible = false
	_pile_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_pile_dialog.custom_minimum_size = Vector2(1080.0, 540.0)
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
	close_button.custom_minimum_size = Vector2(44.0, 36.0)
	_ui_skin.apply_button_stylebox_overrides(close_button)
	_ui_skin.apply_button_text_overrides(close_button)
	UiTypography.set_button_size(close_button, UiTypography.SIZE_SMALL)
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
	_dialogue_text_label.text = str(line.get("text", ""))
	_dialogue_text_label.visible_characters = 0
	_update_dialogue_footer()
	if _dialogue_text_label.text.is_empty():
		_complete_current_dialogue_line()

func _complete_current_dialogue_line() -> void:
	if not _dialogue_active:
		return
	_dialogue_text_complete = true
	_dialogue_char_progress = float(_dialogue_text_label.text.length())
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
	var next_index: int = int(option.get("next", -1))
	if next_index >= 0:
		_show_dialogue_line(next_index)
		return
	_close_dialogue()

func _close_dialogue() -> void:
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

func _current_dialogue_line() -> Dictionary:
	if not _dialogue_active or _dialogue_line_index < 0:
		return {}
	var lines: Array = _dialogue_script.get("lines", [])
	if _dialogue_line_index >= lines.size():
		return {}
	return lines[_dialogue_line_index]

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
		button.custom_minimum_size = Vector2(120.0, 36.0)
		_ui_skin.apply_button_stylebox_overrides(button)
		_ui_skin.apply_button_text_overrides(button)
		UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
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
	widget.configure(card_id, false, false, true, false, false, true)
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
	if index < 0 or index >= hand_box.get_child_count():
		return Rect2()
	var control: Control = hand_box.get_child(index)
	return Rect2(control.global_position, control.size)

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
	var spacing: float = size_hint.x * 0.48
	var center_offset: float = (float(index) - float(maxi(0, total - 1)) * 0.5) * spacing
	var center: Vector2 = hand_rect.get_center() + Vector2(center_offset, hand_rect.size.y * 0.08)
	return _rect_from_center(center, size_hint)

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
	var pile_specs: Array[Dictionary] = [
		{"kind": "draw", "panel": draw_pile, "title": "Draw", "accent": Color("8a6b49"), "fill": Color("33261d")},
		{"kind": "discard", "panel": discard_pile, "title": "Discard", "accent": Color("7f8ea4"), "fill": Color("ede2cd")},
		{"kind": "burn", "panel": burn_pile, "title": "Burn", "accent": Color("ad5848"), "fill": Color("ecd1c9")}
	]
	for spec_var: Variant in pile_specs:
		var spec: Dictionary = spec_var
		_build_pile_widget(spec)

func _build_pile_widget(spec: Dictionary) -> void:
	var kind: String = str(spec.get("kind", ""))
	var panel: PanelContainer = spec.get("panel", null)
	if panel == null:
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_NONE
	panel.custom_minimum_size = Vector2(94.0, 124.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = true
	for child: Node in panel.get_children():
		child.visible = false
		if child is Control:
			var child_control: Control = child
			child_control.custom_minimum_size = Vector2.ZERO
			child_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			child_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var visual := Control.new()
	visual.name = "PileVisual_%s" % kind
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.anchors_preset = Control.PRESET_FULL_RECT
	visual.anchor_right = 1.0
	visual.anchor_bottom = 1.0
	panel.add_child(visual)

	for stack_index: int in range(2):
		var underlay := Panel.new()
		underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underlay.position = Vector2(14.0 + float(stack_index) * 4.0, 12.0 - float(stack_index) * 2.0)
		underlay.size = Vector2(62.0, 88.0)
		var underlay_style := _pile_card_style(Color(0.16, 0.12, 0.09, 0.95), Color(0.44, 0.33, 0.24, 0.84))
		underlay_style.shadow_size = 0
		underlay.add_theme_stylebox_override("panel", underlay_style)
		visual.add_child(underlay)

	var front := Panel.new()
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.position = Vector2(10.0, 6.0)
	front.size = Vector2(74.0, 106.0)
	front.clip_contents = true
	front.add_theme_stylebox_override("panel", _pile_card_style(spec.get("fill", Color("e8dcc0")), spec.get("accent", Color("8a6d49"))))
	visual.add_child(front)
	_pile_fronts[kind] = front

	var art_frame := Panel.new()
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.position = Vector2(8.0, 8.0)
	art_frame.size = Vector2(58.0, 64.0)
	art_frame.clip_contents = true
	art_frame.add_theme_stylebox_override("panel", _pile_card_style(Color("3b312a"), Color(0.0, 0.0, 0.0, 0.0), 6.0))
	front.add_child(art_frame)

	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.anchors_preset = Control.PRESET_FULL_RECT
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	preview.offset_left = 4.0
	preview.offset_top = 4.0
	preview.offset_right = -4.0
	preview.offset_bottom = -4.0
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_frame.add_child(preview)
	_pile_previews[kind] = preview

	var caption := Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(7.0, 78.0)
	caption.size = Vector2(60.0, 18.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text = str(spec.get("title", "")).to_upper()
	UiTypography.set_label_size(caption, UiTypography.SIZE_CAPTION)
	caption.add_theme_color_override("font_color", Color("f8edd8"))
	caption.add_theme_color_override("font_outline_color", Color("241912"))
	caption.add_theme_constant_override("outline_size", 1)
	front.add_child(caption)
	_pile_captions[kind] = caption

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(46.0, 5.0)
	badge.size = Vector2(20.0, 18.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(badge, UiTypography.SIZE_CAPTION)
	badge.add_theme_color_override("font_color", Color("fff4dc"))
	badge.add_theme_color_override("font_outline_color", Color("2f2018"))
	badge.add_theme_constant_override("outline_size", 1)
	var badge_style := _pile_card_style(Color(0.16, 0.12, 0.09, 0.94), spec.get("accent", Color("8a6d49")), 4.0)
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge.add_theme_stylebox_override("normal", badge_style)
	front.add_child(badge)
	_pile_badges[kind] = badge

	panel.gui_input.connect(_on_pile_gui_input.bind(kind))

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
	var should_resume: bool = bool(get_tree().root.get_meta("labyrinth_resume_saved_run", false))
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	if should_resume and ProgressionStore.has_saved_run():
		var saved_run: Dictionary = ProgressionStore.load_saved_run()
		if not saved_run.is_empty():
			_load_run_state(saved_run)
			return
	_start_run()

func _load_run_state(next_run_state: Dictionary) -> void:
	_close_dialogue()
	_last_auto_dialogue_key = ""
	_run_state = next_run_state.duplicate(true)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_reset_card_resolution()
	_victory_bank_processed = false
	_defeat_loss_processed = false
	_victory_bank_amount = 0
	_board_presentation.clear()
	action_banner.visible = false
	_refresh_ui()

func _start_run() -> void:
	_progression = ProgressionStore.prepare_for_new_run(ProgressionStore.load_data())
	ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	_load_run_state(_run_engine.create_new_run(_new_seed(), _progression))

func _refresh_ui() -> void:
	if _dialogue_active and str(_run_state.get("mode", "room")) != "room":
		_close_dialogue()
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
	var room_element: String = str(display_room.get("element", ElementData.NONE))
	var title_color: Color = ElementData.accent(room_element) if ElementData.is_elemental(room_element) else Color("f0e6d2")
	room_title.add_theme_color_override("font_color", title_color)
	room_subtitle.add_theme_color_override("font_color", title_color.lightened(0.28) if ElementData.is_elemental(room_element) else Color("cdbca2"))
	room_title.text = _room_title_text(display_room)
	room_subtitle.text = _room_subtitle_text(display_room)
	stats_label.text = "HP %d/%d  EMBERS %d" % [
		int(_run_state.get("player_hp", 0)),
		int(_run_state.get("player_max_hp", 1)),
		int(_run_state.get("unbanked_embers", 0))
	]
	_refresh_relic_bar()
	mini_map.set_run_state(_run_state)
	_refresh_pile_counts()
	_refresh_pile_visuals()
	_refresh_choice_bar()
	_refresh_stage_view()
	_refresh_hand_panel()
	_refresh_visibility()
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
		frame.custom_minimum_size = Vector2(28.0, 28.0)
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
		margin.add_theme_constant_override("margin_left", 3)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_right", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
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
	for kind: String in ["draw", "discard", "burn"]:
		if not _pile_badges.has(kind):
			continue
		var cards: Array = piles.get(kind, []).duplicate()
		var badge: Label = _pile_badges[kind]
		badge.text = str(cards.size())
		badge.visible = true
		var preview: TextureRect = _pile_previews.get(kind, null)
		if preview == null:
			continue
		var front: Control = _pile_fronts.get(kind, null)
		var caption: Label = _pile_captions.get(kind, null)
		if kind == "draw":
			preview.texture = null
			preview.modulate = Color(1.0, 1.0, 1.0, 0.0)
			if caption != null:
				caption.text = "DECK"
			if front != null:
				front.add_theme_stylebox_override("panel", _pile_card_style(Color("3a2b21"), Color("8a6b49")))
			continue
		var top_card_id: String = str(cards[cards.size() - 1]) if not cards.is_empty() else ""
		if top_card_id.is_empty():
			preview.texture = null
			preview.modulate = Color(1.0, 1.0, 1.0, 0.0)
			if caption != null:
				caption.text = "DECK" if kind == "draw" else "DISC" if kind == "discard" else "BURN"
			continue
		var card: Dictionary = GameData.card_def(top_card_id)
		preview.texture = AssetLoader.load_texture(str(card.get("art_path", "")))
		preview.modulate = Color.WHITE
		if caption != null:
			caption.text = "DISC" if kind == "discard" else "BURN"
		if front != null:
			front.add_theme_stylebox_override("panel", _pile_card_style(
				Color("ecdcc4") if kind == "discard" else Color("e0c7bd"),
				Color(str(card.get("accent", "#8a6d49")))
			))

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
	bottom_stack.visible = choice_bar.visible or hand_row.visible
	if mode != "combat":
		_cancel_drag_play()
		_close_pile_view()

func _refresh_choice_bar() -> void:
	_clear_children(choice_bar)
	var mode: String = str(_run_state.get("mode", "room"))
	if mode == "combat" and _selected_card_index >= 0:
		if _current_action_can_skip():
			_add_choice_button("Skip", _on_skip_action_pressed)
		_add_choice_button("Cancel", _on_cancel_requested)
	elif mode == "combat" and not _animation_lock and _drag_card_index < 0:
		_add_choice_button("Pass", _on_pass_turn_pressed)
	match mode:
		"reward":
			_add_choice_button("Skip +%d HP" % int((_run_state.get("pending_reward", {}) as Dictionary).get("heal_amount", 0)), _on_skip_reward_pressed)
		"campfire":
			_add_choice_button("Sit", _on_campfire_sit_pressed)
			_add_choice_button("Leave", _on_campfire_leave_pressed)
		"treasure":
			for relic_id_var: Variant in _run_state.get("pending_relics", []):
				var relic_id: String = str(relic_id_var)
				var relic: Dictionary = GameData.relic_def(relic_id)
				_add_choice_button(str(relic.get("name", relic_id)), _on_relic_pressed.bind(relic_id), str(relic.get("description", "")))
		"victory":
			_add_choice_button("Menu", _on_back_to_menu_pressed)
			_add_choice_button("Again", _on_restart_pressed)
		"defeat":
			_add_choice_button("Menu", _on_back_to_menu_pressed)
			_add_choice_button("Again", _on_restart_pressed)
	choice_bar.visible = choice_bar.get_child_count() > 0

func _add_choice_button(text: String, callback: Callable, tooltip: String = "") -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0.0, 36.0)
	_ui_skin.apply_button_stylebox_overrides(button)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
	button.pressed.connect(callback)
	choice_bar.add_child(button)

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
				bool(options.get("printed_playable", false))
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
			hand_box.add_child(widget)
	elif mode == "reward":
		var reward_cards: Array = (_run_state.get("pending_reward", {}) as Dictionary).get("cards", [])
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if reward_cards.size() <= 4 else ScrollContainer.SCROLL_MODE_AUTO
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var reward_card_size: Vector2 = _hand_card_size(reward_cards.size(), true)
		for card_id_var: Variant in reward_cards:
			var widget = CardWidgetScene.instantiate()
			widget.custom_minimum_size = reward_card_size
			widget.configure(str(card_id_var), false, false, true, false)
			widget.activated.connect(_on_reward_card_pressed.bind(str(card_id_var)))
			hand_box.add_child(widget)

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
			var target_tiles: Array[Vector2i] = preview.get("target_tiles", [])
			if str(action.get("type", "")) in ["move", "blink"]:
				move_tiles = target_tiles
			else:
				attack_tiles = target_tiles
			var preview_presentation: Dictionary = _preview_presentation(preview)
			for key: Variant in preview_presentation.keys():
				presentation[key] = preview_presentation[key]
		elif _hovered_board_tile.x >= 0:
			var threat_preview: Dictionary = _hovered_enemy_threat(display_state)
			move_tiles = (threat_preview.get("move", []) as Array).duplicate()
			attack_tiles = (threat_preview.get("attack", []) as Array).duplicate()
			if threat_preview.has("enemy_key"):
				presentation["focus_actor_keys"] = [str(threat_preview.get("enemy_key", ""))]
				presentation["focus_actor_color"] = Color("f2ddb2")
	if not _animation_lock and str(_run_state.get("mode", "room")) == "room" and _hovered_board_tile.x >= 0 and _exit_destinations_by_tile.has(_hovered_board_tile):
		presentation["focus_tiles"] = [_hovered_board_tile]
	board_view.set_combat_state(
		display_state,
		move_tiles,
		attack_tiles,
		(display_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		_board_status_label(preview),
		_board_status_detail(preview),
		_exit_labels_for_board() if str(_run_state.get("mode", "room")) == "room" else {},
		_exit_elements_for_board() if str(_run_state.get("mode", "room")) == "room" else {},
		presentation
	)

func _hovered_enemy_threat(display_state: Dictionary) -> Dictionary:
	for enemy_index: int in range((display_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (display_state.get("enemies", []) as Array)[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if enemy.get("pos", Vector2i(-1, -1)) != _hovered_board_tile:
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
		"grid": layout.get("grid", []).duplicate(true),
		"player": {
			"pos": layout.get("player_start", RoomGeneratorScript.entry_tile_for_direction(Vector2i.ZERO)),
			"hp": int(_run_state.get("player_hp", 1)),
			"max_hp": int(_run_state.get("player_max_hp", 1)),
			"block": 0
		},
		"npcs": layout.get("npcs", []).duplicate(true),
		"enemies": [],
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
				"target_tiles": _pending_target_tiles.duplicate(),
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
	return _card_preview_from_state(card_id, _combat_state, GameData.card_def(card_id).get("actions", []), 0)

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
	var card: Dictionary = GameData.card_def(card_id)
	var summary_rows: Array = []
	var modifier_lines: PackedStringArray = []
	var preview_state: Dictionary = state.duplicate(true)
	for action_var: Variant in card.get("actions", []):
		var action: Dictionary = action_var
		var action_type: String = str(action.get("type", ""))
		match action_type:
			"melee", "ranged", "blast":
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
	if action_type not in ["melee", "ranged", "blast", "push", "pull"]:
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
				"target_tiles": valid_targets,
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
		"target_tiles": [],
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
	result["focus_actor_color"] = PLAYER_PREVIEW_FOCUS if action_type in ["move", "blink"] else PLAYER_ATTACK_FOCUS
	var focus_tiles: Array[Vector2i] = _focus_tiles_for_preview(preview)
	if not focus_tiles.is_empty():
		result["focus_tiles"] = focus_tiles
		result["focus_color"] = Color(0.42, 0.84, 0.93, 0.24) if action_type in ["move", "blink"] else Color(0.95, 0.62, 0.37, 0.22)
	var path_tiles: Array[Vector2i] = _path_tiles_for_preview(preview)
	if not path_tiles.is_empty():
		result["path_tiles"] = path_tiles
	var effect: Dictionary = _preview_effect_for_action(preview)
	if not effect.is_empty():
		result["effect"] = effect
	return result

func _focus_tiles_for_preview(preview: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if _hovered_board_tile.x < 0:
		return []
	var valid_targets: Array[Vector2i] = preview.get("target_tiles", [])
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type in ["move", "blink"]:
		return _path_tiles_for_preview(preview)
	if action_type == "blast":
		return _tiles_in_radius(_hovered_board_tile, int(action.get("radius", 1)), (preview.get("state", {}) as Dictionary).get("grid", []))
	return [_hovered_board_tile]

func _path_tiles_for_preview(preview: Dictionary) -> Array[Vector2i]:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if _hovered_board_tile.x < 0:
		return []
	var valid_targets: Array[Vector2i] = preview.get("target_tiles", [])
	if not valid_targets.has(_hovered_board_tile):
		return []
	if action_type == "move":
		var preview_state: Dictionary = preview.get("state", {})
		var grid: Array = preview_state.get("grid", [])
		var start: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		return PathUtils.find_path(grid, start, _hovered_board_tile, _enemy_occupied_tiles(preview_state))
	if action_type == "blink":
		return [_hovered_board_tile]
	return []

func _preview_effect_for_action(preview: Dictionary) -> Dictionary:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if _hovered_board_tile.x < 0:
		return {}
	var valid_targets: Array[Vector2i] = preview.get("target_tiles", [])
	if not valid_targets.has(_hovered_board_tile):
		return {}
	var preview_state: Dictionary = preview.get("state", {})
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	match action_type:
		"move":
			return {"kind": "move", "from": player_tile, "to": _hovered_board_tile}
		"blink":
			return {"kind": "blink", "from": player_tile, "to": _hovered_board_tile}
		"melee", "ranged":
			return {"kind": action_type, "from": player_tile, "to": _hovered_board_tile}
		"blast":
			return {"kind": "blast", "from": player_tile, "to": _hovered_board_tile, "center": _hovered_board_tile, "radius": int(action.get("radius", 1))}
		_:
			return {}

func _tiles_in_radius(center: Vector2i, radius: int, grid: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y_offset: int in range(-radius, radius + 1):
		for x_offset: int in range(-radius, radius + 1):
			var tile: Vector2i = center + Vector2i(x_offset, y_offset)
			if PathUtils.manhattan(center, tile) > radius:
				continue
			if tile.y < 0 or tile.y >= grid.size():
				continue
			if tile.x < 0 or tile.x >= (grid[tile.y] as Array).size():
				continue
			tiles.append(tile)
	return tiles

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
		_refresh_ui()
		await _play_player_card(
			index,
			(preview.get("state", {}) as Dictionary).duplicate(true),
			(preview.get("actions", []) as Array).duplicate(true),
			[]
		)
		return
	_selected_card_index = index
	_preview_combat_state = (preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_actions = (preview.get("actions", []) as Array).duplicate(true)
	_pending_action_index = int(preview.get("action_index", 0))
	_pending_action_can_skip = bool(preview.get("skip_allowed", false))
	_pending_target_tiles = (preview.get("target_tiles", []) as Array).duplicate()
	_pending_selected_targets.clear()
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
		_on_map_view_room_selected(_exit_destinations_by_tile[tile])
		return
	if mode != "combat" or _selected_card_index < 0:
		return
	if not _pending_target_tiles.has(tile):
		return
	var action: Dictionary = _pending_actions[_pending_action_index]
	_pending_selected_targets.append(tile)
	_preview_combat_state = _combat_engine.apply_player_action(_preview_combat_state, action, tile)
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	if bool(next_preview.get("complete", false)):
		await _play_player_card(
			_selected_card_index,
			(next_preview.get("state", {}) as Dictionary).duplicate(true),
			_pending_actions.duplicate(true),
			_pending_selected_targets.duplicate()
		)
		return
	_preview_combat_state = (next_preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_action_index = int(next_preview.get("action_index", 0))
	_pending_action_can_skip = bool(next_preview.get("skip_allowed", false))
	_pending_target_tiles = (next_preview.get("target_tiles", []) as Array).duplicate()
	_refresh_ui()

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
	var card_id: String = _card_id_for_hand_index(_selected_card_index)
	var next_preview: Dictionary = _card_preview_from_state(card_id, _preview_combat_state, _pending_actions, _pending_action_index + 1)
	if bool(next_preview.get("complete", false)):
		await _play_player_card(
			_selected_card_index,
			(next_preview.get("state", {}) as Dictionary).duplicate(true),
			_pending_actions.duplicate(true),
			_pending_selected_targets.duplicate()
		)
		return
	_preview_combat_state = (next_preview.get("state", {}) as Dictionary).duplicate(true)
	_pending_action_index = int(next_preview.get("action_index", 0))
	_pending_action_can_skip = bool(next_preview.get("skip_allowed", false))
	_pending_target_tiles = (next_preview.get("target_tiles", []) as Array).duplicate()
	_refresh_ui()

func _play_player_card(hand_index: int, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	var card_id: String = _card_id_for_hand_index(hand_index)
	var source_rect: Rect2 = _hand_card_global_rect(hand_index)
	var card_size: Vector2 = source_rect.size if source_rect.size.length() > 0.0 else _hand_card_size(5, false)
	var pile_kind: String = _card_destination_pile(card_id)
	_animating_hand_card_index = hand_index
	_animation_lock = true
	_refresh_ui()
	await _animate_player_card_resolution(_combat_state.duplicate(true), card_id, actions, selected_targets)
	_board_presentation.clear()
	_set_action_banner("")
	_combat_state = _combat_engine.finish_player_card(resolved_state, hand_index)
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	if outcome == "":
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
		_sync_combat_state_from_run()
	_animation_lock = false
	_animating_hand_card_index = -1
	_reset_card_resolution()
	_hovered_card_index = -1
	_refresh_ui()
	if str(_run_state.get("mode", "room")) == "combat" and _combat_engine.cards_remaining_this_turn(_combat_state) <= 0:
		await _resolve_enemy_round()

func _card_destination_pile(card_id: String) -> String:
	return "burn" if bool(GameData.card_def(card_id).get("burn", false)) else "discard"

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
		var target_tile: Vector2i = Vector2i(-1, -1)
		if _combat_engine.player_action_needs_target(action):
			if target_index >= selected_targets.size():
				break
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
				presentation["path_tiles"] = move_path
				presentation["focus_tiles"] = move_path
				presentation["focus_color"] = Color(0.42, 0.84, 0.93, 0.24)
				presentation["effect"] = {"kind": "move", "from": player_before_tile, "to": player_after_tile}
				presentation["effect_progress"] = t
				presentation["unit_world_positions"] = {"player": from_point.lerp(to_point, t)}
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
		"melee", "ranged", "blast", "push", "pull":
			var focus_tiles: Array[Vector2i] = [target_tile]
			if action_type == "blast":
				focus_tiles = _tiles_in_radius(target_tile, int(action.get("radius", 1)), before_state.get("grid", []))
			var effect := {
				"kind": "ranged" if action_type in ["push", "pull"] else action_type,
				"from": player_before_tile,
				"to": target_tile,
				"center": target_tile,
				"radius": int(action.get("radius", 1))
			}
			_set_action_banner(_player_action_label(card_id, action, before_state))
			var from_point: Vector2 = board_view.world_position_for_tile(player_before_tile)
			var to_point: Vector2 = board_view.world_position_for_tile(target_tile)
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
				_render_board_state(before_state, presentation)
				await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
			await _animate_floating_text_presentation(after_state, {
				"focus_actor_keys": ["player"],
				"focus_actor_color": PLAYER_ATTACK_FOCUS,
				"focus_tiles": focus_tiles,
				"focus_color": Color(0.95, 0.62, 0.37, 0.22),
				"effect": effect,
				"effect_progress": 1.0,
				"floating_texts": _player_damage_floating_texts(before_state, after_state)
				})
		"block":
			var block_gain: int = int(player_after.get("block", 0)) - int(player_before.get("block", 0))
			_set_action_banner(_player_action_label(card_id, action, before_state))
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

func _resolve_enemy_round() -> void:
	_animation_lock = true
	_refresh_ui()
	var phase_result: Dictionary = _combat_engine.resolve_enemy_phase_with_steps(_combat_state)
	var animated_state: Dictionary = _combat_state.duplicate(true)
	_clear_enemy_blocks(animated_state)
	await _animate_enemy_phase_steps(animated_state, phase_result.get("steps", []))
	_board_presentation.clear()
	_set_action_banner("")
	_combat_state = (phase_result.get("state", {}) as Dictionary).duplicate(true)
	var outcome: String = _combat_engine.combat_outcome(_combat_state)
	if outcome == "":
		var before_draw_state: Dictionary = _combat_state.duplicate(true)
		_combat_state = _combat_engine.prepare_next_player_turn(_combat_state)
		await _animate_draw_cards_fx(_draw_entries_between_states(before_draw_state, _combat_state))
		outcome = _combat_engine.combat_outcome(_combat_state)
	if outcome == "":
		_run_state = _run_engine.set_combat_state(_run_state, _combat_state)
	else:
		_run_state = _run_engine.finish_combat(_run_state, _combat_state)
		_sync_combat_state_from_run()
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
				await _animate_floating_text_presentation(animated_state, {
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": [step.get("tile", Vector2i(-1, -1))],
					"focus_color": Color(0.95, 0.62, 0.37, 0.18),
					"effect": step,
					"floating_texts": _floating_texts_for_step(step)
				})
			"melee", "ranged", "blast", "push", "pull":
				var focus_tiles: Array[Vector2i] = [step.get("to", Vector2i(-1, -1))]
				if str(step.get("kind", "")) == "blast":
					focus_tiles = _tiles_in_radius(step.get("center", Vector2i(-1, -1)), int(step.get("radius", 1)), animated_state.get("grid", []))
				_set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
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
					_render_board_state(animated_state, presentation)
					await get_tree().create_timer(ATTACK_FRAME_SECONDS).timeout
				_apply_animation_step(animated_state, step)
				await _animate_floating_text_presentation(animated_state, {
					"focus_actor_keys": [step_actor_key],
					"focus_actor_color": PLAYER_ATTACK_FOCUS,
					"focus_tiles": focus_tiles,
					"focus_color": Color(0.95, 0.62, 0.37, 0.18),
					"effect": step,
					"effect_progress": 1.0,
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
			"effect": step,
			"effect_progress": t
		})
		await get_tree().create_timer(MOVE_FRAME_SECONDS).timeout
	_apply_animation_step(animated_state, step)
	_render_board_state(animated_state, {})
	await get_tree().create_timer(0.06).timeout

func _render_board_state(display_state: Dictionary, presentation: Dictionary) -> void:
	board_view.set_combat_state(
		display_state,
		[],
		[],
		(display_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		"",
		"",
		{},
		{},
		presentation
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
		"melee", "ranged", "blast", "push", "pull":
			_apply_player_losses(animated_state, int(step.get("hp_loss", 0)), int(step.get("block_loss", 0)), int(step.get("stoneskin_loss", 0)))
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
		"melee", "ranged", "blast", "push", "pull":
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

func _set_player_pos(state: Dictionary, pos: Vector2i) -> void:
	var player: Dictionary = state.get("player", {})
	player["pos"] = pos
	state["player"] = player

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
		if bool(restrictions.get("shocked", false)) and _selected_card_index < 0 and _hovered_card_index < 0:
			return "Shocked"
		if _drag_card_index >= 0:
			return "Play Card"
		if _selected_card_index >= 0:
			if not _selected_card_label_override.is_empty():
				return _selected_card_label_override
			return str(GameData.card_def(_card_id_for_hand_index(_selected_card_index)).get("name", "Card"))
		if _hovered_card_index >= 0 and bool(preview.get("playable", false)):
			return str(GameData.card_def(str(preview.get("card_id", ""))).get("name", "Card"))
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
		var cards_left: int = _combat_engine.cards_remaining_this_turn(_combat_state)
		if cards_left > 0:
			if not _has_playable_combat_card() and _has_any_playable_combat_card():
				return "2 atk / 2 move"
			return "%d play%s left" % [cards_left, "" if cards_left == 1 else "s"]
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
		"move", "blink":
			return "Choose tile"
		"melee", "ranged", "blast", "push", "pull":
			return "Choose target"
		_:
			return "Resolve"

func _player_action_label(card_id: String, _action: Dictionary, _state: Dictionary = _combat_state) -> String:
	return str(GameData.card_def(card_id).get("name", card_id))

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

func _on_map_view_room_selected(coord: Vector2i) -> void:
	if str(_run_state.get("mode", "room")) != "room":
		return
	_run_state = _run_engine.move_to_room(_run_state, coord)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_reset_card_resolution()
	_refresh_ui()

func _on_reward_card_pressed(card_id: String) -> void:
	_run_state = _run_engine.claim_card_reward(_run_state, card_id)
	_sync_combat_state_from_run()
	_refresh_ui()

func _on_skip_reward_pressed() -> void:
	_run_state = _run_engine.skip_reward_for_heal(_run_state)
	_sync_progression_from_run()
	_sync_combat_state_from_run()
	_refresh_ui()

func _on_campfire_sit_pressed() -> void:
	_sync_progression_from_run()
	var bankable: int = _run_engine.bankable_embers(_run_state)
	if bankable > 0:
		_progression = ProgressionStore.add_embers(_progression, bankable)
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

func _on_back_to_menu_pressed() -> void:
	ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_restart_pressed() -> void:
	ProgressionStore.clear_saved_run()
	_start_run()

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
	_menu_scrim.visible = true

func _close_menu_overlay() -> void:
	if _menu_scrim != null:
		_menu_scrim.visible = false

func _committed_run_state() -> Dictionary:
	var state: Dictionary = _run_state.duplicate(true)
	if str(state.get("mode", "")) == "combat":
		state = _run_engine.set_combat_state(state, _combat_state)
	return state

func _save_run_progress() -> void:
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
	var cards: Array = _cards_for_pile(pile_kind)
	_active_pile_kind = pile_kind
	_pile_dialog_title.text = "%s Pile" % pile_kind.capitalize()
	_clear_children(_pile_dialog_cards)
	for card_id_var: Variant in cards:
		var widget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = Vector2(156.0, 224.0)
		widget.configure(str(card_id_var), false, false, true, false, false, true)
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pile_dialog_cards.add_child(widget)
	_pile_dialog_empty.visible = cards.is_empty()
	_pile_scrim.visible = true

func _close_pile_view() -> void:
	if _pile_scrim != null:
		_pile_scrim.visible = false
	_active_pile_kind = ""

func _cards_for_pile(pile_kind: String) -> Array:
	var piles: Dictionary = _deck_piles()
	var cards: Array = piles.get(pile_kind, []).duplicate()
	if pile_kind == "draw":
		cards.sort_custom(func(a: Variant, b: Variant) -> bool:
			var a_name: String = str(GameData.card_def(str(a)).get("name", str(a)))
			var b_name: String = str(GameData.card_def(str(b)).get("name", str(b)))
			if a_name == b_name:
				return str(a) < str(b)
			return a_name < b_name
		)
		return cards
	cards.reverse()
	return cards

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
	var gaps: float = float(maxi(0, card_count - 1)) * 12.0
	var target_width: float = (available_width - gaps) / float(maxi(1, card_count))
	var max_width: float = 168.0 if reward_mode else 160.0
	var min_width: float = 140.0 if reward_mode else 132.0
	var width: float = clampf(target_width, min_width, max_width)
	return Vector2(width, width * (1.44 if reward_mode else 1.38))

func _card_id_for_hand_index(index: int) -> String:
	var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
	if index < 0 or index >= hand.size():
		return ""
	return str(hand[index])

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

func _exit_labels_for_board() -> Dictionary:
	var labels: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var dir: Vector2i = option.get("dir", Vector2i.ZERO)
		var marker: String = "N" if dir == Vector2i(0, -1) else "E" if dir == Vector2i(1, 0) else "S" if dir == Vector2i(0, 1) else "W"
		labels[option.get("door_tile", Vector2i(-1, -1))] = marker
	return labels

func _exit_elements_for_board() -> Dictionary:
	var elements: Dictionary = {}
	for option: Dictionary in _run_engine.exit_options(_run_state):
		var room: Dictionary = option.get("room", {})
		elements[option.get("door_tile", Vector2i(-1, -1))] = str(room.get("element", ElementData.NONE))
	return elements

func _process_victory_banking() -> void:
	var amount: int = _run_engine.bankable_embers(_run_state)
	_victory_bank_amount = amount
	if amount > 0:
		_progression = ProgressionStore.add_embers(_progression, amount)
		ProgressionStore.save_data(_progression)
		_run_state = _run_engine.consume_banked_embers(_run_state)
	_run_state["progression"] = _progression.duplicate(true)
	_victory_bank_processed = true

func _process_defeat_loss() -> void:
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
		occupied[enemy.get("pos", Vector2i.ZERO)] = true
	return occupied

func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))
