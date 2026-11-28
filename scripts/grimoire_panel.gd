extends ColorRect

## The shared book UI. RunScene provides live card previews and owns discovery
## persistence. The title supplies a read-only snapshot of the profile.
signal opening
signal closed

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const GameData = preload("res://scripts/game_data.gd")
const CreaturePage = preload("res://scripts/grimoire_creature_page.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const GrimoireSearch = preload("res://scripts/grimoire_search.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const ItemPreviewBuilders = preload("res://scripts/item_preview_builders.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const GRIMOIRE_DIALOG_SIZE: Vector2 = Vector2(1120.0, 640.0)
const GRIMOIRE_MIN_DIALOG_SIZE: Vector2 = Vector2(820.0, 520.0)
# Match the section map's right-stick pan response, on the vertical axis.
const DETAIL_STICK_SPEED: float = 1150.0
const DETAIL_STICK_DEADZONE: float = 0.22
const DETAIL_ICON_SIZE: float = 86.0
const GRIMOIRE_LEFT_PAGE_WIDTH: float = 300.0
const GRIMOIRE_DETAIL_PAGE_WIDTH: float = 620.0
const GRIMOIRE_ENTRY_BUTTON_HEIGHT: float = 44.0
const GRIMOIRE_CARD_PREVIEW_SIZE: Vector2 = Vector2(240.0, 337.92)
const GRIMOIRE_EQUIPMENT_CARD_SIZE := Vector2(maxf(176.0, CardWidget.MIN_READABLE_CARD_SIZE.x), maxf(246.4, CardWidget.MIN_READABLE_CARD_SIZE.y))

# The existing parchment palette and scrim, shared by both entry points.
const BINDING_RGBA := Vector4(0.25, 0.14, 0.07, 0.72)
const DETAIL_RULE_RGBA := Vector4(0.45, 0.27, 0.13, 0.46)
const SCRIM_RGBA := Vector4(0.025, 0.018, 0.014, 0.72)
const SEARCH_TEXT := 0x3b2818ff
const SEARCH_CARET := 0x70431fff
const ACTION_TEXT := 0xf7dfadff
const TITLE_TEXT := 0xf3ddb0ff
const TITLE_OUTLINE := 0x2b1a10ff
const SUBTITLE_TEXT := 0xc9ad7cff
const DETAIL_KICKER := 0xa97546ff
const DETAIL_TITLE := 0x3a2416ff
const DETAIL_BODY := 0x4a3320ff
const COVER_EDGE := 0x7c4a24ff
const PAGE_RIGHT := 0xd8c08fff
const PAGE_LEFT := 0xccb07cff
const ICON_EDGE := 0x8b5b2eff
const SEARCH_FOCUS_FILL := 0xead7aaff
const SEARCH_FILL := 0xe2ca98ff
const SEARCH_FOCUS_EDGE := 0x9a632fff
const ROW_SELECTED_TEXT := 0x2f1d10ff
const ROW_TEXT := 0x3d2818ff
const ROW_HEADING_SELECTED_TEXT := 0xfff1cfff
const ROW_NESTED_TEXT := 0x4c3522ff
const ROW_HOVER_TEXT := 0x26170dff
const SECTION_SELECTED_FILL := 0x5d351dff
const SECTION_ACTIVE_EDGE := 0xd1a35eff
const GROUP_SELECTED_FILL := 0x8a5628ff
const GROUP_ACTIVE_EDGE := 0xd6a057ff
const ENTRY_SELECTED_FILL := 0xd7b16dff
const GRANTED_CARDS_TEXT := 0x6a3e1fff
const SEARCH_PLACEHOLDER_RGBA := Vector4(0.30, 0.21, 0.13, 0.72)
const SEARCH_SELECTION_RGBA := Vector4(0.54, 0.32, 0.14, 0.34)
const SEARCH_STATUS_RGBA := Vector4(0.28, 0.18, 0.10, 0.82)
const DETAIL_TITLE_OUTLINE_RGBA := Vector4(1.0, 0.88, 0.64, 0.20)
const COVER_FILL_RGBA := Vector4(0.12, 0.065, 0.035, 0.98)
const PAGE_EDGE_RGBA := Vector4(0.54, 0.33, 0.16, 0.74)
const ICON_FILL_RGBA := Vector4(0.25, 0.14, 0.075, 0.88)
const SEARCH_EDGE_RGBA := Vector4(0.42, 0.26, 0.12, 0.62)
const SEARCH_SHADOW_RGBA := Vector4(0.24, 0.13, 0.06, 0.22)
const BREADCRUMB_RGBA := Vector4(0.28, 0.18, 0.10, 0.76)
const SECTION_FILL_RGBA := Vector4(0.72, 0.55, 0.32, 0.22)
const SECTION_EDGE_RGBA := Vector4(0.39, 0.24, 0.12, 0.42)
const GROUP_FILL_RGBA := Vector4(0.72, 0.53, 0.29, 0.22)
const GROUP_EDGE_RGBA := Vector4(0.48, 0.29, 0.13, 0.52)
const ENTRY_FILL_RGBA := Vector4(0.98, 0.88, 0.66, 0.18)
const ENTRY_EDGE_RGBA := Vector4(0.53, 0.34, 0.16, 0.34)
const GRANTED_CARDS_OUTLINE_RGBA := Vector4(1.0, 0.88, 0.64, 0.18)
const BOOK_INK := 0xf4ddb0ff

var _grimoire_dialog: PanelContainer
var _grimoire_search_input: LineEdit
var _grimoire_search_clear_button: Button
var _grimoire_search_status: Label
var _grimoire_section_list: VBoxContainer
var _grimoire_entry_scroll: ScrollContainer
var _grimoire_entry_list: VBoxContainer
var _grimoire_detail_panel: PanelContainer
var _grimoire_detail_icon: TextureRect
var _grimoire_detail_kicker: Label
var _grimoire_detail_title: Label
var _grimoire_detail_stack: VBoxContainer
var _grimoire_detail_scroll: ScrollContainer
var _grimoire_creature_stack: VBoxContainer
var _grimoire_detail_stick: float = 0.0
var _grimoire_detail_entry: String = ""
var _grimoire_detail_body: RichTextLabel
var _grimoire_detail_content: VBoxContainer
var _grimoire_selected_section: String = ""
var _grimoire_selected_group: String = ""
var _grimoire_selected_entry: String = ""
var _grimoire_nav_scroll_revision: int = 0
var _grimoire_search_query: String = ""
var _grimoire_search_index: Array[Dictionary]
var _grimoire_search_index_unlocked: Array[String]
var _grimoire_cached_result_query: String = ""
var _grimoire_cached_results_valid: bool = false
var _grimoire_cached_results: Array[Dictionary]
var _grimoire_search_results: Array[Dictionary]
var _grimoire_search_result_buttons: Array[Button]
var _grimoire_search_retained_rows: Dictionary = {}
var _grimoire_row_preparation_revision: int = 0
var _grimoire_row_preparation_running_revision: int = -1
var _grimoire_nav_buttons: Array[Button]
var _grimoire_search_restore_selection: Dictionary = {}
var _grimoire_search_restore_scroll: int = 0
var _grimoire_restore_focus: Control
var _grimoire_restore_navigation_focus: bool = true

# The rows and texture preparation helpers also operate on this control.
var _grimoire_scrim: ColorRect:
	get: return self
var _ui_skin := UiSkin.new()
var _run_state: Dictionary = {}
var _profile: Dictionary = {}
var catalog_source: Callable
var card_preview: Callable
var detail_icon: Callable
var performance_phase: Callable
var _runtime_performance_instrumentation_enabled: bool:
	get: return performance_phase.is_valid() and bool(performance_phase.get_object().get("_runtime_performance_instrumentation_enabled"))
static var _book_icon: Texture2D

func set_catalog(state: Dictionary) -> void:
	_run_state = {
		GrimoireLibrary.UNLOCKED_KEY: state.get(GrimoireLibrary.UNLOCKED_KEY, []),
		GrimoireLibrary.UNREAD_KEY: state.get(GrimoireLibrary.UNREAD_KEY, []),
	}

func prepare_title_catalog(profile: Dictionary) -> void:
	_profile = profile
	# These are the discovery inputs present when RunEngine creates a run.
	# Resolve them through the same library without creating a run or a map.
	set_catalog(GrimoireLibrary.ensure_run_state({
		"progression": profile,
		"deck_cards": GameData.starting_deck(),
		"attuned_magic_cards": GameData.starting_magic_cards(),
		"collected_equipment": GameData.starter_equipment_ids(),
		"equipped_equipment": GameData.starting_equipped_equipment(),
		"rooms": {"0,0": {"npcs": [{"id": "emaciated_man"}]}},
	}))

func open_from_title(profile: Dictionary, opener: Control) -> void:
	if _run_state.is_empty() or _profile != profile:
		prepare_title_catalog(profile)
	open(opener)

func open(opener: Control) -> void:
	_grimoire_restore_focus = opener
	_grimoire_restore_navigation_focus = true
	_reset_grimoire_search()
	# The title already supplied its snapshot. RunScene's catalog is kept
	# current when loading a run and when new discoveries arrive.
	_select_first_unread_grimoire_entry()
	_rebuild_grimoire_overlay(true)
	if not visible: opening.emit()
	show()
	move_to_front()
	_focus_grimoire_after_open.call_deferred()

func close() -> void:
	var was_visible: bool = visible
	hide()
	_grimoire_detail_stick = 0.0
	_grimoire_detail_entry = ""
	_reset_grimoire_search()
	preload("res://scripts/grimoire_search_rows.gd").release_closed(self)
	if not was_visible: return
	closed.emit()
	var target: Control = _grimoire_restore_focus
	if _grimoire_restore_navigation_focus and is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
	_grimoire_restore_focus = null

func track_navigation_intent(event: InputEvent) -> void:
	# In a run a pointer dismissal leaves no navigation highlight on the HUD.
	if not event.is_pressed(): return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_grimoire_restore_navigation_focus = false
	elif event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton:
		_grimoire_restore_navigation_focus = true

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_grimoire_detail_stick = event.axis_value

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_grimoire_detail_scroll) or not _grimoire_detail_scroll.visible:
		return
	if absf(_grimoire_detail_stick) <= DETAIL_STICK_DEADZONE:
		return
	var strength: float = (absf(_grimoire_detail_stick) - DETAIL_STICK_DEADZONE) / (1.0 - DETAIL_STICK_DEADZONE)
	var bar: VScrollBar = _grimoire_detail_scroll.get_v_scroll_bar()
	if bar.visible:
		bar.value += signf(_grimoire_detail_stick) * strength * DETAIL_STICK_SPEED * delta

func layout() -> void:
	_layout_grimoire_dialog()

func refresh_input_wording() -> void:
	if _grimoire_detail_body == null or not _grimoire_detail_body.visible: return
	var entry: Dictionary = GrimoireLibrary.entry_def(_grimoire_selected_entry)
	if not entry.is_empty() and str(entry.get("card_id", "")).is_empty():
		InlineIconText.apply_to(_grimoire_detail_body, _grimoire_body_text(entry), InlineIconText.DEFAULT_ICON_SCALE, true)

func _focus_grimoire_after_open() -> void:
	if visible: _grimoire_search_input.grab_focus()

func _controller_is_active() -> bool:
	if not is_inside_tree(): return false
	var router: Node = get_node_or_null("/root/InputRouter")
	return router != null and bool(router.call("using_controller"))

func _build_card_preview_widget(card_id: String, card_size: Vector2, interactive: bool) -> Control:
	if card_preview.is_valid(): return card_preview.call(card_id, card_size, interactive)
	var builder := ItemPreviewBuilders.new()
	builder.definition_resolver = _profile_card_definition
	return builder.card_preview(card_id, card_size, interactive)

func _profile_card_definition(card_id: String) -> Dictionary:
	return GameData.card_def_for_progression(card_id, _profile)

func _record_runtime_performance_phase(phase: String, started: int) -> int:
	return performance_phase.call(phase, started) if performance_phase.is_valid() else 0

static func _rgba(channels: Vector4) -> Color:
	return Color(channels.x, channels.y, channels.z, channels.w)

static func book_icon() -> Texture2D:
	if _book_icon == null:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		_draw_header_book_icon(image, Color.hex(BOOK_INK))
		_book_icon = ImageTexture.create_from_image(image)
	return _book_icon

func build() -> void:
	name = "GrimoireScrim"
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = _rgba(SCRIM_RGBA)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 255
	z_as_relative = false
	set_meta("cursor_feedback_context_provider", _grimoire_scrim_cursor_feedback_context)
	gui_input.connect(_on_grimoire_scrim_gui_input)
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_grimoire_dialog = PanelContainer.new()
	_grimoire_dialog.name = "GrimoireDialog"
	_grimoire_dialog.custom_minimum_size = GRIMOIRE_DIALOG_SIZE
	_grimoire_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_grimoire_dialog.add_theme_stylebox_override("panel", _grimoire_cover_style())
	center.add_child(_grimoire_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_LARGE))
	_grimoire_dialog.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)

	var title := Label.new()
	title.text = "Grimoire"
	UiTypography.apply_label_role(title, UiTypography.ROLE_TITLE)
	title.add_theme_color_override("font_color", Color.hex(TITLE_TEXT))
	title.add_theme_color_override("font_outline_color", Color.hex(TITLE_OUTLINE))
	title.add_theme_constant_override("outline_size", 2)
	title_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Collected field notes"
	UiTypography.apply_label_role(subtitle, UiTypography.ROLE_BODY)
	subtitle.add_theme_color_override("font_color", Color.hex(SUBTITLE_TEXT))
	title_stack.add_child(subtitle)

	var close_button := UiTooltipButton.new()
	close_button.text = "Close"
	close_button.tooltip_text = "Close Grimoire"
	_ui_skin.apply_button_stylebox_overrides(close_button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(close_button, Color.hex(ACTION_TEXT))
	UiTypography.apply_button_role(close_button, UiTypography.ROLE_BODY)
	close_button.custom_minimum_size = Vector2(104.0, 36.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var book_row := HBoxContainer.new()
	book_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_row.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	root.add_child(book_row)

	var left_page := PanelContainer.new()
	left_page.name = "GrimoireLeftPage"
	left_page.custom_minimum_size = Vector2(GRIMOIRE_LEFT_PAGE_WIDTH, 0.0)
	left_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_theme_stylebox_override("panel", _grimoire_page_style(false))
	book_row.add_child(left_page)
	_ui_skin.apply_surface_finish(left_page, "paper_left")

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	left_margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING_COMPACT))
	left_margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	left_margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_LARGE))
	left_page.add_child(left_margin)

	var left_stack := VBoxContainer.new()
	left_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_stack.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	left_margin.add_child(left_stack)

	var search_row := HBoxContainer.new()
	search_row.name = "GrimoireSearchRow"
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	left_stack.add_child(search_row)

	_grimoire_search_input = LineEdit.new()
	_grimoire_search_input.name = "GrimoireSearchInput"
	_grimoire_search_input.placeholder_text = "Search discovered entries"
	_grimoire_search_input.tooltip_text = "Search every discovered Grimoire entry by name, rule, category, or familiar term. Close spellings are accepted."
	_grimoire_search_input.max_length = 64
	_grimoire_search_input.clear_button_enabled = false
	_grimoire_search_input.custom_minimum_size = Vector2(0.0, 42.0)
	_grimoire_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_search_input.focus_mode = Control.FOCUS_ALL
	_grimoire_search_input.add_theme_font_override("font", UiTypography.text_font())
	_grimoire_search_input.add_theme_font_size_override("font_size", UiTypography.scaled_size(_grimoire_search_input, UiTypography.SIZE_BODY))
	_grimoire_search_input.add_theme_color_override("font_color", Color.hex(SEARCH_TEXT))
	_grimoire_search_input.add_theme_color_override("font_placeholder_color", _rgba(SEARCH_PLACEHOLDER_RGBA))
	_grimoire_search_input.add_theme_color_override("caret_color", Color.hex(SEARCH_CARET))
	_grimoire_search_input.add_theme_color_override("selection_color", _rgba(SEARCH_SELECTION_RGBA))
	_grimoire_search_input.add_theme_stylebox_override("normal", _grimoire_search_field_style(false))
	_grimoire_search_input.add_theme_stylebox_override("focus", _grimoire_search_field_style(true))
	_grimoire_search_input.text_changed.connect(_on_grimoire_search_text_changed)
	_grimoire_search_input.text_submitted.connect(_on_grimoire_search_submitted)
	_grimoire_search_input.gui_input.connect(_on_grimoire_search_gui_input)
	search_row.add_child(_grimoire_search_input)
	preload("res://scripts/controller_focus_tooltip.gd").attach(_grimoire_search_input)
	preload("res://scripts/grimoire_search_keyboard.gd").attach(_grimoire_search_input)
	_grimoire_search_input.focus_neighbor_top = _grimoire_search_input.get_path_to(close_button)
	close_button.focus_neighbor_bottom = close_button.get_path_to(_grimoire_search_input)
	search_row.set_meta("controller_repeat_region", &"grimoire_search")

	_grimoire_search_clear_button = UiTooltipButton.new()
	_grimoire_search_clear_button.name = "GrimoireSearchClear"
	_grimoire_search_clear_button.text = "Clear"
	_grimoire_search_clear_button.tooltip_text = "Clear search and return to section browsing"
	_grimoire_search_clear_button.visible = false
	_grimoire_search_clear_button.focus_mode = Control.FOCUS_ALL
	_ui_skin.apply_button_stylebox_overrides(_grimoire_search_clear_button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(_grimoire_search_clear_button, Color.hex(ACTION_TEXT))
	UiTypography.apply_button_role(_grimoire_search_clear_button, UiTypography.ROLE_CAPTION)
	_grimoire_search_clear_button.custom_minimum_size = Vector2(66.0, 42.0)
	_grimoire_search_clear_button.pressed.connect(_clear_grimoire_search)
	search_row.add_child(_grimoire_search_clear_button)

	_grimoire_search_status = Label.new()
	_grimoire_search_status.name = "GrimoireSearchStatus"
	_grimoire_search_status.text = "Discovered entries"
	_grimoire_search_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grimoire_search_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_grimoire_search_status, UiTypography.ROLE_CAPTION)
	_grimoire_search_status.add_theme_color_override("font_color", _rgba(SEARCH_STATUS_RGBA))
	left_stack.add_child(_grimoire_search_status)

	_grimoire_entry_scroll = ScrollContainer.new()
	_grimoire_entry_scroll.set_meta("controller_repeat_region", &"grimoire_list")
	_grimoire_entry_scroll.name = "GrimoireNavScroll"
	_grimoire_entry_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_entry_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grimoire_entry_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_grimoire_entry_scroll.follow_focus = true
	_grimoire_entry_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	left_stack.add_child(_grimoire_entry_scroll)

	_grimoire_section_list = VBoxContainer.new()
	_grimoire_section_list.name = "GrimoireNavList"
	_grimoire_section_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_section_list.add_theme_constant_override("separation", UiTypography.SPACE_TIGHT)
	_grimoire_entry_scroll.add_child(_grimoire_section_list)
	_grimoire_entry_list = _grimoire_section_list

	var binding := ColorRect.new()
	binding.custom_minimum_size = Vector2(3.0, 0.0)
	binding.color = _rgba(BINDING_RGBA)
	binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_row.add_child(binding)

	_grimoire_detail_panel = PanelContainer.new()
	_grimoire_detail_panel.name = "GrimoireDetailPage"
	_grimoire_detail_panel.custom_minimum_size = Vector2(GRIMOIRE_DETAIL_PAGE_WIDTH, 0.0)
	_grimoire_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_panel.add_theme_stylebox_override("panel", _grimoire_page_style(true))
	book_row.add_child(_grimoire_detail_panel)
	_ui_skin.apply_surface_finish(_grimoire_detail_panel, "paper_right")

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	detail_margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	detail_margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	detail_margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_LARGE))
	_grimoire_detail_panel.add_child(detail_margin)

	_grimoire_detail_stack = VBoxContainer.new()
	_grimoire_detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_stack.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	detail_margin.add_child(_grimoire_detail_stack)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	_grimoire_detail_stack.add_child(detail_header)

	_grimoire_detail_icon = TextureRect.new()
	detail_header.add_child(_grimoire_icon_socket(DETAIL_ICON_SIZE, _grimoire_detail_icon))

	var detail_title_stack := VBoxContainer.new()
	detail_title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title_stack.add_theme_constant_override("separation", 1)
	detail_header.add_child(detail_title_stack)

	_grimoire_detail_kicker = Label.new()
	UiTypography.apply_label_role(_grimoire_detail_kicker, UiTypography.ROLE_CAPTION)
	_grimoire_detail_kicker.add_theme_color_override("font_color", Color.hex(DETAIL_KICKER))
	detail_title_stack.add_child(_grimoire_detail_kicker)

	_grimoire_detail_title = Label.new()
	_grimoire_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_grimoire_detail_title, UiTypography.ROLE_TITLE)
	_grimoire_detail_title.add_theme_color_override("font_color", Color.hex(DETAIL_TITLE))
	_grimoire_detail_title.add_theme_color_override("font_outline_color", _rgba(DETAIL_TITLE_OUTLINE_RGBA))
	_grimoire_detail_title.add_theme_constant_override("outline_size", 1)
	detail_title_stack.add_child(_grimoire_detail_title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = _rgba(DETAIL_RULE_RGBA)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grimoire_detail_stack.add_child(rule)

	_grimoire_detail_body = RichTextLabel.new()
	_grimoire_detail_body.bbcode_enabled = false
	_grimoire_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grimoire_detail_body.fit_content = true
	_grimoire_detail_body.scroll_active = true
	_grimoire_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTypography.apply_rich_text_role(_grimoire_detail_body, UiTypography.ROLE_BODY)
	_grimoire_detail_body.add_theme_color_override("default_color", Color.hex(DETAIL_BODY))
	_grimoire_detail_stack.add_child(_grimoire_detail_body)

	_grimoire_detail_content = VBoxContainer.new()
	_grimoire_detail_content.name = "GrimoireDetailContent"
	_grimoire_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_content.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	_grimoire_detail_stack.add_child(_grimoire_detail_content)
	_grimoire_detail_scroll = ScrollContainer.new()
	_grimoire_detail_scroll.set_meta("controller_repeat_region", &"grimoire_detail")
	_grimoire_detail_scroll.name = "GrimoireDetailScroll"
	_grimoire_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grimoire_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grimoire_detail_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_grimoire_detail_scroll.hide()
	_grimoire_detail_stack.add_child(_grimoire_detail_scroll)
	_grimoire_creature_stack = VBoxContainer.new()
	_grimoire_creature_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grimoire_creature_stack.add_theme_constant_override("separation", 0)
	_grimoire_detail_scroll.add_child(_grimoire_creature_stack)
	_ui_skin.apply_outer_panel_frame(_grimoire_dialog, UiSkin.SURFACE_PARCHMENT)

func _grimoire_cover_style() -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style(_rgba(COVER_FILL_RGBA), Color.hex(COVER_EDGE), 18.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_size = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	return style

func _grimoire_page_style(right_page: bool) -> StyleBoxFlat:
	var base: Color = Color.hex(PAGE_RIGHT) if right_page else Color.hex(PAGE_LEFT)
	var style := _ui_skin.make_plain_card_style(base, _rgba(PAGE_EDGE_RGBA), 14.0)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	return style

func _grimoire_icon_socket(edge: float, icon: TextureRect) -> PanelContainer:
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(edge, edge)
	icon_frame.add_theme_stylebox_override("panel", _grimoire_icon_frame_style(edge / DETAIL_ICON_SIZE))

	var icon_margin := MarginContainer.new()
	icon_margin.add_theme_constant_override("margin_left", roundi(3.0 * edge / DETAIL_ICON_SIZE))
	icon_margin.add_theme_constant_override("margin_top", roundi(3.0 * edge / DETAIL_ICON_SIZE))
	icon_margin.add_theme_constant_override("margin_right", roundi(3.0 * edge / DETAIL_ICON_SIZE))
	icon_margin.add_theme_constant_override("margin_bottom", roundi(3.0 * edge / DETAIL_ICON_SIZE))
	icon_frame.add_child(icon_margin)

	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(icon)
	return icon_frame

func _grimoire_icon_frame_style(scale_factor: float) -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style(_rgba(ICON_FILL_RGBA), Color.hex(ICON_EDGE), 8.0 * scale_factor)
	style.corner_radius_top_left = roundi(7.0 * scale_factor)
	style.corner_radius_top_right = roundi(7.0 * scale_factor)
	style.corner_radius_bottom_right = roundi(7.0 * scale_factor)
	style.corner_radius_bottom_left = roundi(7.0 * scale_factor)
	style.shadow_size = roundi(4.0 * scale_factor)
	style.set_border_width_all(roundi(3.0 * scale_factor))
	return style

func _grimoire_search_field_style(focused: bool) -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style()
	style.bg_color = Color.hex(SEARCH_FOCUS_FILL) if focused else Color.hex(SEARCH_FILL)
	style.border_color = Color.hex(SEARCH_FOCUS_EDGE) if focused else _rgba(SEARCH_EDGE_RGBA)
	style.border_width_left = 2 if focused else 1
	style.border_width_top = 2 if focused else 1
	style.border_width_right = 2 if focused else 1
	style.border_width_bottom = 2 if focused else 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = UiTypography.SPACE_MEDIUM
	style.content_margin_top = UiTypography.SPACE_SMALL
	style.content_margin_right = UiTypography.SPACE_MEDIUM
	style.content_margin_bottom = UiTypography.SPACE_SMALL
	style.shadow_color = _rgba(SEARCH_SHADOW_RGBA) if focused else Color.TRANSPARENT
	style.shadow_size = 4 if focused else 0
	return style

func _rebuild_grimoire_overlay(scroll_to_selection: bool = false) -> void:
	if _grimoire_section_list == null:
		return
	# Opening or switching section warms that section's card faces after its first frame.
	preload("res://scripts/grimoire_texture_preparation.gd").prepare_for.call_deferred(self)
	var grimoire_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	_layout_grimoire_dialog()
	var preserved_scroll_vertical: int = 0
	if _grimoire_entry_scroll != null:
		preserved_scroll_vertical = _grimoire_entry_scroll.scroll_vertical
	_grimoire_nav_scroll_revision += 1
	var scroll_revision: int = _grimoire_nav_scroll_revision
	if catalog_source.is_valid():
		set_catalog(catalog_source.call())
	var unlocked: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNLOCKED_KEY, []))
	var unread: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNREAD_KEY, []))
	var sections: Array = GrimoireLibrary.sections()
	_grimoire_search_result_buttons.clear()
	_grimoire_nav_buttons.clear()
	grimoire_started = _record_runtime_performance_phase("grimoire_catalog_prepare", grimoire_started)
	if _grimoire_search_active():
		_rebuild_grimoire_search_results(unlocked, unread, sections, preserved_scroll_vertical, scroll_revision)
		return
	var entries_by_section: Dictionary = _grimoire_entries_by_section(unlocked)
	_grimoire_search_results.clear()
	_update_grimoire_search_chrome(unlocked.size())
	if _grimoire_selected_section.is_empty() or _grimoire_entries_for_section_map(entries_by_section, _grimoire_selected_section).is_empty():
		_grimoire_selected_section = _first_unlocked_grimoire_section_from(sections, entries_by_section)
	_grimoire_sync_selected_entry(_grimoire_entries_for_section_map(entries_by_section, _grimoire_selected_section))
	_clear_grimoire_browse_controls()
	var selected_index: int = 0
	for section_var: Variant in sections:
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = section_var as Dictionary
		var section_id: String = str(section.get("id", ""))
		var section_entries: Array[Dictionary] = _grimoire_entries_for_section_map(entries_by_section, section_id)
		if section_entries.is_empty():
			continue
		var section_selected: bool = section_id == _grimoire_selected_section
		var section_button := _grimoire_nav_button(
			"%s · %d" % [str(section.get("title", section_id)), section_entries.size()],
			0,
			section_selected,
			_grimoire_section_has_unread(section_id, unread),
			str(section.get("summary", "")),
			"section"
		)
		section_button.set_meta("grimoire_nav_kind", "section")
		section_button.set_meta("grimoire_nav_id", section_id)
		section_button.pressed.connect(_on_grimoire_section_pressed.bind(section_id))
		_add_grimoire_nav_button(section_button, 0)
		if section_selected and _grimoire_selected_entry.is_empty():
			selected_index = _grimoire_nav_buttons.size() - 1
		if not section_selected:
			continue
		var groups: Array[String] = _grimoire_group_ids_for_entries(section_entries)
		if groups.is_empty():
			for entry: Dictionary in section_entries:
				var entry_index: int = _add_grimoire_entry_tab(entry, unread, 1)
				if str(entry.get("id", "")) == _grimoire_selected_entry:
					selected_index = entry_index
			continue
		for group_id: String in groups:
			var group_entries: Array[Dictionary] = _grimoire_entries_for_group(section_entries, group_id)
			var group_selected: bool = group_id == _grimoire_selected_group
			var group_button := _grimoire_nav_button(
				"%s · %d" % [_grimoire_group_title(group_entries, group_id), group_entries.size()],
				1,
				group_selected,
				_grimoire_group_has_unread(group_entries, unread),
				"",
				"group"
			)
			group_button.set_meta("grimoire_nav_kind", "group")
			group_button.set_meta("grimoire_nav_id", "%s:%s" % [section_id, group_id])
			group_button.pressed.connect(_on_grimoire_group_pressed.bind(section_id, group_id))
			_add_grimoire_nav_button(group_button, 1)
			if not group_selected:
				continue
			for entry: Dictionary in group_entries:
				var entry_index: int = _add_grimoire_entry_tab(entry, unread, 2)
				if str(entry.get("id", "")) == _grimoire_selected_entry:
					selected_index = entry_index
	_refresh_grimoire_nav_minimum_size()
	if scroll_to_selection:
		call_deferred("_scroll_grimoire_entry_list_to_index", selected_index, 0, scroll_revision)
	else:
		call_deferred("_restore_grimoire_entry_list_scroll", preserved_scroll_vertical, 0, scroll_revision)
	grimoire_started = _record_runtime_performance_phase("grimoire_browse_build", grimoire_started)
	_refresh_grimoire_detail()
	_record_runtime_performance_phase("grimoire_detail_build", grimoire_started)

func _rebuild_grimoire_search_results(unlocked: Array[String], unread: Array[String], sections: Array, preserved_scroll_vertical: int, scroll_revision: int) -> void:
	var grimoire_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	if _grimoire_search_index.is_empty() or unlocked != _grimoire_search_index_unlocked:
		var unlocked_entries: Array = []
		var unlocked_lookup: Dictionary = {}
		for entry_id: String in unlocked: unlocked_lookup[entry_id] = true
		for entry_var: Variant in GrimoireLibrary.entries():
			if typeof(entry_var) == TYPE_DICTIONARY and unlocked_lookup.has(str((entry_var as Dictionary).get("id", ""))):
				unlocked_entries.append(entry_var)
		_grimoire_search_index = GrimoireSearch.build_index(unlocked_entries, sections)
		_grimoire_search_index_unlocked.assign(unlocked)
		_grimoire_cached_results_valid = false
	grimoire_started = _record_runtime_performance_phase("grimoire_search_catalog", grimoire_started)
	if not _grimoire_cached_results_valid or _grimoire_cached_result_query != _grimoire_search_query:
		_grimoire_cached_results = GrimoireSearch.search_index(_grimoire_search_index, _grimoire_search_query)
		_grimoire_cached_result_query = _grimoire_search_query
		_grimoire_cached_results_valid = true
	# Browsing clears its visible array; preserve a separate owned outer array
	# so selection/unread changes can reuse the same immutable ranking.
	_grimoire_search_results.assign(_grimoire_cached_results)
	grimoire_started = _record_runtime_performance_phase("grimoire_search_score", grimoire_started)
	var selected_still_matches: bool = false
	for result: Dictionary in _grimoire_search_results:
		var result_entry: Dictionary = result.get("entry", {}) as Dictionary
		if str(result_entry.get("id", "")) == _grimoire_selected_entry:
			selected_still_matches = true
			break
	if not selected_still_matches:
		_grimoire_selected_entry = "" if _grimoire_search_results.is_empty() else str((_grimoire_search_results[0].get("entry", {}) as Dictionary).get("id", ""))
	_reconcile_grimoire_search_rows(unread)
	_update_grimoire_search_chrome(unlocked.size())
	_refresh_grimoire_nav_minimum_size()
	if _grimoire_search_results.is_empty():
		call_deferred("_restore_grimoire_entry_list_scroll", 0, 0, scroll_revision)
	else:
		var selected_index: int = 0
		for index: int in range(_grimoire_search_results.size()):
			var result_entry: Dictionary = _grimoire_search_results[index].get("entry", {}) as Dictionary
			if str(result_entry.get("id", "")) == _grimoire_selected_entry:
				selected_index = index
				break
		if preserved_scroll_vertical > 0:
			call_deferred("_restore_grimoire_entry_list_scroll", preserved_scroll_vertical, 0, scroll_revision)
		else:
			call_deferred("_scroll_grimoire_entry_list_to_index", selected_index, 0, scroll_revision)
	grimoire_started = _record_runtime_performance_phase("grimoire_result_controls", grimoire_started)
	_refresh_grimoire_detail()
	_record_runtime_performance_phase("grimoire_detail_build", grimoire_started)

func _grimoire_known_row_ids() -> Array[String]:
	return GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNLOCKED_KEY, []))

func _grimoire_row_preparation_key() -> Dictionary:
	return {"ids": _grimoire_known_row_ids(), "common": [get_viewport_rect().size, UiTypography.ui_scale(self)]}

func _prepare_known_grimoire_rows() -> void:
	await preload("res://scripts/grimoire_search_rows.gd").prepare_current_for(self, _grimoire_row_preparation_revision, preload("res://scripts/encounter_asset_preparation.gd").present_frame.bind(get_tree()), func() -> bool: return true)

func _grimoire_search_row_input(result: Dictionary, unread: Array[String], common: Array) -> Array:
	var entry: Dictionary = result.get("entry", {}) as Dictionary
	var id: String = str(entry.get("id", ""))
	return [str(entry.get("title", id)), unread.has(id), id == _grimoire_selected_entry, _grimoire_search_result_context(result), _grimoire_search_result_tooltip(result), common]

func _park_grimoire_search_row(wrapper: Control) -> void:
	var button: Button = wrapper.get_child(0) as Button
	if button.has_focus(): button.release_focus()
	button.focus_mode = Control.FOCUS_NONE
	wrapper.hide()
	wrapper.process_mode = Node.PROCESS_MODE_DISABLED

func _clear_grimoire_browse_controls() -> void:
	for child: Node in _grimoire_section_list.get_children():
		var id: String = str(child.get_meta("grimoire_prepared_search_row", ""))
		if _grimoire_search_retained_rows.get(id, {}).get("node") == child:
			_park_grimoire_search_row(child as Control)
		else:
			_prepare_node_for_immediate_free(child)
			_grimoire_section_list.remove_child(child)
			child.queue_free()

	preload("res://scripts/grimoire_search_rows.gd").trim_hidden(self)

func _prune_grimoire_search_rows(ids: Array[String]) -> void:
	for id: String in _grimoire_search_retained_rows.keys():
		var node: Variant = _grimoire_search_retained_rows[id].get("node")
		if ids.has(id) and _node_is_alive(node): continue
		_grimoire_search_retained_rows.erase(id)
		if _node_is_alive(node):
			_prepare_node_for_immediate_free(node)
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.queue_free()

func _prepare_grimoire_search_row(document: Dictionary) -> void:
	var entry: Dictionary = document["entry"]
	var id: String = str(entry["id"])
	var common: Array = [get_viewport_rect().size, UiTypography.ui_scale(self)]
	var cached: Variant = _grimoire_search_retained_rows.get(id, {}).get("node")
	if _node_is_alive(cached):
		# Published rows may already be in use. Preparation never replaces a
		# visible row or changes any live selection, focus, or search results.
		if cached.visible or _grimoire_search_retained_rows[id]["input"][5] == common: return
		_grimoire_search_retained_rows.erase(id)
		_prepare_node_for_immediate_free(cached)
		cached.get_parent().remove_child(cached)
		cached.queue_free()
	var unread: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNREAD_KEY, []))
	var result: Dictionary = {"entry": entry, "breadcrumb": document.get("breadcrumb", ""), "match_kind": "title"}
	var button: Button = _new_grimoire_search_result(result, unread)
	var wrapper := MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("margin_left", 0)
	wrapper.add_theme_constant_override("margin_right", 0)
	wrapper.add_child(button)
	wrapper.set_meta("grimoire_prepared_search_row", id)
	_park_grimoire_search_row(wrapper)
	# Its final parent/theme/layout context is ready before publication. No
	# continuation owns or discards this row after a rendered boundary.
	_grimoire_section_list.add_child(wrapper)
	_grimoire_search_retained_rows[id] = {"node": wrapper, "input": _grimoire_search_row_input(result, unread, common).duplicate(true)}

func _reconcile_grimoire_search_rows(unread: Array[String]) -> void:
	# Only discovered entries have prepared controls. Keep hidden rows after the
	# ordered visible rows under their final parent, avoiding native theme setup
	# when a broad query first exposes hundreds of results.
	_prune_grimoire_search_rows(_grimoire_known_row_ids())
	var next: Dictionary = _grimoire_search_retained_rows.duplicate()
	var ordered: Array[Control]
	var common: Array = [get_viewport_rect().size, UiTypography.ui_scale(self)]
	for result: Dictionary in _grimoire_search_results:
		var id: String = str((result.get("entry", {}) as Dictionary).get("id", ""))
		var input: Array = _grimoire_search_row_input(result, unread, common)
		var previous: Dictionary = _grimoire_search_retained_rows.get(id, {})
		var cached: Variant = previous.get("node")
		var wrapper: Control
		if _node_is_alive(cached) and cached.get_parent() == _grimoire_section_list and (previous.get("input", []) as Array).size() == input.size() and previous["input"][5] == common:
			var button: Button = cached.get_child(0) as Button
			# A visible row with active pointer state takes the original fallback.
			# Hidden prepared rows have no gesture and normalize selection at use.
			if not cached.visible or button.get_draw_mode() not in [BaseButton.DRAW_HOVER, BaseButton.DRAW_HOVER_PRESSED, BaseButton.DRAW_PRESSED]:
				wrapper = cached
				if button.has_focus(): button.release_focus()
				_update_grimoire_search_result(button, previous["input"], input)
				button.focus_mode = Control.FOCUS_ALL
				wrapper.process_mode = Node.PROCESS_MODE_INHERIT
				wrapper.show()
				preload("res://scripts/grimoire_search_rows.gd").append_navigation_button(self, button)
				_grimoire_search_result_buttons.append(button)
		if wrapper == null:
			var button: Button = _new_grimoire_search_result(result, unread)
			_add_grimoire_nav_button(button, 0)
			_grimoire_search_result_buttons.append(button)
			wrapper = button.get_parent() as Control
			wrapper.set_meta("grimoire_prepared_search_row", id)
		next[id] = {"node": wrapper, "input": input.duplicate(true)}
		ordered.append(wrapper)
	for child: Node in _grimoire_section_list.get_children():
		if ordered.has(child): continue
		var id: String = str(child.get_meta("grimoire_prepared_search_row", ""))
		if next.get(id, {}).get("node") == child:
			_park_grimoire_search_row(child as Control)
		else:
			_prepare_node_for_immediate_free(child)
			_grimoire_section_list.remove_child(child)
			child.queue_free()
	for index: int in ordered.size(): _grimoire_section_list.move_child(ordered[index], index)
	_grimoire_search_retained_rows = next
	preload("res://scripts/grimoire_search_rows.gd").trim_hidden(self)


func _update_grimoire_search_result(button: Button, previous: Array, input: Array) -> void:
	var content: VBoxContainer = button.get_child(0) as VBoxContainer
	var title: Label = content.get_child(0) as Label
	var breadcrumb: Label = content.get_child(1) as Label
	var selected: bool = bool(input[2])
	# Native accessibility activation may toggle before emitting pressed. Match
	# a freshly constructed result even when presentation inputs did not change.
	button.set_pressed_no_signal(selected)
	if previous[0] != input[0] or previous[1] != input[1]:
		title.text = "%s%s" % ["* " if bool(input[1]) else "", str(input[0])]
	if previous[3] != input[3]: breadcrumb.text = str(input[3])
	if previous[4] != input[4]: button.tooltip_text = str(input[4])
	if previous[2] != input[2]:
		button.add_theme_stylebox_override("normal", _grimoire_tab_style(1, selected, false, false, "search"))
		button.add_theme_stylebox_override("hover", _grimoire_tab_style(1, selected, true, false, "search"))
		button.add_theme_stylebox_override("focus", _grimoire_tab_style(1, selected, true, false, "search"))
		var color: Color = Color.hex(ROW_SELECTED_TEXT) if selected else Color.hex(ROW_TEXT)
		for role: String in ["font_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(role, color)
		title.add_theme_color_override("font_color", color)

func _new_grimoire_search_result(result: Dictionary, unread: Array[String]) -> Button:
	var entry: Dictionary = result.get("entry", {}) as Dictionary
	var entry_id: String = str(entry.get("id", ""))
	var selected: bool = entry_id == _grimoire_selected_entry
	var button := _grimoire_nav_button(
		"",
		1,
		selected,
		false,
		_grimoire_search_result_tooltip(result),
		"search",
		entry_id
	)
	button.custom_minimum_size.y = 60.0
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("grimoire_nav_kind", "entry")
	button.set_meta("grimoire_nav_id", entry_id)
	button.pressed.connect(_on_grimoire_entry_pressed.bind(entry_id))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = UiTypography.SPACE_MEDIUM
	content.offset_top = UiTypography.SPACE_TIGHT
	content.offset_right = -UiTypography.SPACE_SMALL
	content.offset_bottom = -UiTypography.SPACE_TIGHT
	content.add_theme_constant_override("separation", 0)
	button.add_child(content)
	var title := Label.new()
	title.text = "%s%s" % ["* " if unread.has(entry_id) else "", str(entry.get("title", entry_id))]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(title, UiTypography.ROLE_BODY)
	title.add_theme_color_override("font_color", Color.hex(ROW_SELECTED_TEXT) if selected else Color.hex(ROW_TEXT))
	content.add_child(title)
	var breadcrumb := Label.new()
	breadcrumb.text = _grimoire_search_result_context(result)
	breadcrumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breadcrumb.clip_text = true
	breadcrumb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	breadcrumb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiTypography.apply_label_role(breadcrumb, UiTypography.ROLE_CAPTION)
	breadcrumb.add_theme_color_override("font_color", _rgba(BREADCRUMB_RGBA))
	content.add_child(breadcrumb)
	return button

func _grimoire_search_result_context(result: Dictionary) -> String:
	var breadcrumb: String = str(result.get("breadcrumb", ""))
	var match_label: String = {
		"alias": "common term",
		"topic": "category",
		"rules": "rules text",
		"close": "close spelling"
	}.get(str(result.get("match_kind", "title")), "")
	if breadcrumb.is_empty():
		return match_label
	return breadcrumb if match_label.is_empty() else "%s · %s" % [breadcrumb, match_label]

func _grimoire_search_result_tooltip(result: Dictionary) -> String:
	var entry: Dictionary = result.get("entry", {}) as Dictionary
	var context: String = _grimoire_search_result_context(result)
	return str(entry.get("title", "")) if context.is_empty() else "%s\n%s" % [str(entry.get("title", "")), context.capitalize()]

func _update_grimoire_search_chrome(unlocked_count: int) -> void:
	var active: bool = _grimoire_search_active()
	if _grimoire_search_clear_button != null:
		_grimoire_search_clear_button.visible = active
	if _grimoire_search_status == null:
		return
	if not active:
		_grimoire_search_status.text = "%d discovered %s" % [unlocked_count, "entry" if unlocked_count == 1 else "entries"]
	elif _grimoire_search_results.is_empty():
		_grimoire_search_status.text = "No matches in discovered entries"
	else:
		var close_count: int = 0
		for result: Dictionary in _grimoire_search_results:
			if str(result.get("match_kind", "")) == "close":
				close_count += 1
		if close_count == _grimoire_search_results.size():
			_grimoire_search_status.text = "%d close %s" % [close_count, "match" if close_count == 1 else "matches"]
		else:
			_grimoire_search_status.text = "%d %s across all sections" % [_grimoire_search_results.size(), "match" if _grimoire_search_results.size() == 1 else "matches"]

func _grimoire_search_active() -> bool:
	return not GrimoireSearch.normalize(_grimoire_search_query).is_empty()

func _on_grimoire_search_text_changed(next_query: String) -> void:
	var was_active: bool = _grimoire_search_active()
	var will_be_active: bool = not GrimoireSearch.normalize(next_query).is_empty()
	var browse_scroll_to_restore: int = -1
	if not was_active and will_be_active:
		_grimoire_search_restore_selection = {
			"section": _grimoire_selected_section,
			"group": _grimoire_selected_group,
			"entry": _grimoire_selected_entry
		}
		_grimoire_search_restore_scroll = _grimoire_entry_scroll.scroll_vertical if _grimoire_entry_scroll != null else 0
	elif was_active and not will_be_active:
		browse_scroll_to_restore = _grimoire_search_restore_scroll
		_restore_grimoire_browse_selection()
	_grimoire_search_query = next_query
	_rebuild_grimoire_overlay(false)
	if browse_scroll_to_restore >= 0:
		call_deferred("_restore_grimoire_entry_list_scroll", browse_scroll_to_restore, 0, _grimoire_nav_scroll_revision)
		_grimoire_search_restore_scroll = 0

func _on_grimoire_search_submitted(_query: String) -> void:
	if _grimoire_search_results.is_empty():
		return
	var first_entry: Dictionary = _grimoire_search_results[0].get("entry", {}) as Dictionary
	_on_grimoire_entry_pressed(str(first_entry.get("id", "")))
	call_deferred("_focus_selected_grimoire_search_result")

func _on_grimoire_search_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") and not _grimoire_nav_buttons.is_empty():
		_grimoire_nav_buttons[0].grab_focus()
		_grimoire_search_input.accept_event()

func _focus_selected_grimoire_search_result() -> void:
	for index: int in range(_grimoire_search_results.size()):
		var entry: Dictionary = _grimoire_search_results[index].get("entry", {}) as Dictionary
		if str(entry.get("id", "")) == _grimoire_selected_entry and index < _grimoire_search_result_buttons.size():
			_grimoire_search_result_buttons[index].grab_focus()
			return

func _clear_grimoire_search() -> void:
	if _grimoire_search_input == null:
		return
	_grimoire_search_input.text = ""
	# Programmatic LineEdit text changes do not emit text_changed.
	_on_grimoire_search_text_changed("")
	_grimoire_search_input.grab_focus()

func _restore_grimoire_browse_selection() -> void:
	if _grimoire_search_restore_selection.is_empty():
		return
	_grimoire_selected_section = str(_grimoire_search_restore_selection.get("section", _grimoire_selected_section))
	_grimoire_selected_group = str(_grimoire_search_restore_selection.get("group", _grimoire_selected_group))
	_grimoire_selected_entry = str(_grimoire_search_restore_selection.get("entry", _grimoire_selected_entry))
	_grimoire_search_restore_selection.clear()

func _reset_grimoire_search() -> void:
	if _grimoire_search_active():
		_restore_grimoire_browse_selection()
	_grimoire_search_query = ""
	_grimoire_search_results.clear()
	_grimoire_search_result_buttons.clear()
	_grimoire_search_restore_selection.clear()
	_grimoire_search_restore_scroll = 0
	if _grimoire_search_input != null:
		_grimoire_search_input.set_block_signals(true)
		_grimoire_search_input.text = ""
		_grimoire_search_input.set_block_signals(false)
	if _grimoire_search_clear_button != null:
		_grimoire_search_clear_button.visible = false

func _grimoire_entries_by_section(unlocked: Array[String]) -> Dictionary:
	var unlocked_lookup: Dictionary = {}
	for entry_id: String in unlocked:
		unlocked_lookup[entry_id] = true
	var result: Dictionary = {}
	for entry_var: Variant in GrimoireLibrary.entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if entry_id.is_empty() or not bool(unlocked_lookup.get(entry_id, false)):
			continue
		var section_id: String = str(entry.get("section", ""))
		if section_id.is_empty():
			continue
		if not result.has(section_id):
			result[section_id] = []
		var section_entries: Array = result.get(section_id, [])
		section_entries.append(entry)
		result[section_id] = section_entries
	return result

func _grimoire_entries_for_section_map(entries_by_section: Dictionary, section_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry_var: Variant in entries_by_section.get(section_id, []):
		if typeof(entry_var) == TYPE_DICTIONARY:
			result.append(entry_var as Dictionary)
	return result

func _first_unlocked_grimoire_section_from(sections: Array, entries_by_section: Dictionary) -> String:
	for section_var: Variant in sections:
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section_id: String = str((section_var as Dictionary).get("id", ""))
		if not _grimoire_entries_for_section_map(entries_by_section, section_id).is_empty():
			return section_id
	return ""

func _select_first_unread_grimoire_entry() -> void:
	var unread: Array[String] = GrimoireLibrary.normalize_entry_ids(_run_state.get(GrimoireLibrary.UNREAD_KEY, []))
	if unread.is_empty():
		return
	var entry: Dictionary = GrimoireLibrary.entry_def(unread[0])
	if entry.is_empty():
		return
	_grimoire_selected_section = str(entry.get("section", ""))
	_grimoire_selected_group = _grimoire_entry_group_id(entry)
	_grimoire_selected_entry = unread[0]

func _grimoire_section_has_unread(section_id: String, unread: Array[String]) -> bool:
	for entry_id: String in unread:
		var entry: Dictionary = GrimoireLibrary.entry_def(entry_id)
		if str(entry.get("section", "")) == section_id:
			return true
	return false

func _layout_grimoire_dialog() -> void:
	if _grimoire_dialog == null:
		return
	var dialog_size: Vector2 = UiTypography.modal_size(_grimoire_dialog, GRIMOIRE_DIALOG_SIZE, GRIMOIRE_MIN_DIALOG_SIZE)
	_grimoire_dialog.custom_minimum_size = dialog_size
	_grimoire_dialog.size = dialog_size

func _grimoire_sync_selected_entry(entries_for_section: Array[Dictionary]) -> void:
	if entries_for_section.is_empty():
		_grimoire_selected_entry = ""
		_grimoire_selected_group = ""
		return
	var groups: Array[String] = _grimoire_group_ids_for_entries(entries_for_section)
	var selected_in_section: bool = false
	for entry: Dictionary in entries_for_section:
		if str(entry.get("id", "")) == _grimoire_selected_entry:
			selected_in_section = true
			break
	if not selected_in_section:
		_grimoire_selected_entry = ""
	if groups.is_empty():
		_grimoire_selected_group = ""
		if _grimoire_selected_entry.is_empty():
			_grimoire_selected_entry = str(entries_for_section[0].get("id", ""))
		return
	if _grimoire_selected_group.is_empty() or not groups.has(_grimoire_selected_group):
		_grimoire_selected_group = _grimoire_entry_group_id(GrimoireLibrary.entry_def(_grimoire_selected_entry))
	if _grimoire_selected_group.is_empty() or not groups.has(_grimoire_selected_group):
		_grimoire_selected_group = groups[0]
	var group_entries: Array[Dictionary] = _grimoire_entries_for_group(entries_for_section, _grimoire_selected_group)
	var selected_in_group: bool = false
	for entry: Dictionary in group_entries:
		if str(entry.get("id", "")) == _grimoire_selected_entry:
			selected_in_group = true
			break
	if not selected_in_group and not group_entries.is_empty():
		_grimoire_selected_entry = str(group_entries[0].get("id", ""))

func _add_grimoire_entry_tab(entry: Dictionary, unread: Array[String], depth: int) -> int:
	var entry_id: String = str(entry.get("id", ""))
	var button := _grimoire_nav_button(
		str(entry.get("title", entry_id)),
		depth,
		entry_id == _grimoire_selected_entry,
		unread.has(entry_id),
		str(entry.get("title", entry_id)),
		"entry",
		entry_id
	)
	button.set_meta("grimoire_nav_kind", "entry")
	button.set_meta("grimoire_nav_id", entry_id)
	button.pressed.connect(_on_grimoire_entry_pressed.bind(entry_id))
	_add_grimoire_nav_button(button, depth)
	return _grimoire_nav_buttons.size() - 1

func _add_grimoire_nav_button(button: Button, depth: int) -> void:
	var wrapper := MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("margin_left", depth * UiTypography.SPACE_LARGE)
	wrapper.add_theme_constant_override("margin_right", 0)
	wrapper.add_child(button)
	_grimoire_section_list.add_child(wrapper)
	_grimoire_section_list.move_child(wrapper, _grimoire_nav_buttons.size())
	preload("res://scripts/grimoire_search_rows.gd").append_navigation_button(self, button)

func _grimoire_nav_button(label: String, depth: int, selected: bool, unread: bool, tooltip: String, kind: String, entry_id: String = "") -> Button:
	var button := UiTooltipButton.new()
	if entry_id.begins_with("keyword:"):
		button.tooltip_source = {"kind": "grimoire", "id": entry_id}
	var marker: String = "* " if unread else ""
	button.text = "%s%s" % [marker, label]
	button.toggle_mode = true
	button.button_pressed = selected
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = tooltip if not tooltip.is_empty() else label
	button.custom_minimum_size = Vector2(0.0, 44.0 if depth == 0 else 38.0 if kind == "group" else GRIMOIRE_ENTRY_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _grimoire_tab_style(depth, selected, false, false, kind))
	button.add_theme_stylebox_override("hover", _grimoire_tab_style(depth, selected, true, false, kind))
	button.add_theme_stylebox_override("pressed", _grimoire_tab_style(depth, true, false, true, kind))
	button.add_theme_stylebox_override("focus", _grimoire_tab_style(depth, selected, true, false, kind))
	button.add_theme_stylebox_override("disabled", _grimoire_tab_style(depth, false, false, false, kind))
	var text_color: Color = Color.hex(ROW_HEADING_SELECTED_TEXT) if selected and depth == 0 else Color.hex(ROW_TEXT)
	if selected and kind == "group":
		text_color = Color.hex(ROW_HEADING_SELECTED_TEXT)
	elif selected and depth > 0:
		text_color = Color.hex(ROW_SELECTED_TEXT)
	elif depth == 2:
		text_color = Color.hex(ROW_NESTED_TEXT)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.hex(ROW_HOVER_TEXT))
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	UiTypography.apply_button_role(button, UiTypography.ROLE_BODY if depth <= 1 else UiTypography.ROLE_CAPTION)
	return button

func _grimoire_tab_style(depth: int, selected: bool, hover: bool, pressed: bool, kind: String) -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style()
	style.shadow_size = 0
	if depth == 0:
		style.bg_color = Color.hex(SECTION_SELECTED_FILL) if selected else _rgba(SECTION_FILL_RGBA)
		style.border_color = Color.hex(SECTION_ACTIVE_EDGE) if selected or hover else _rgba(SECTION_EDGE_RGBA)
	elif kind == "group":
		style.bg_color = Color.hex(GROUP_SELECTED_FILL) if selected else _rgba(GROUP_FILL_RGBA)
		style.border_color = Color.hex(GROUP_ACTIVE_EDGE) if selected or hover else _rgba(GROUP_EDGE_RGBA)
	else:
		style.bg_color = Color.hex(ENTRY_SELECTED_FILL) if selected else _rgba(ENTRY_FILL_RGBA)
		style.border_color = Color.hex(GROUP_SELECTED_FILL) if selected or hover else _rgba(ENTRY_EDGE_RGBA)
	style.border_width_left = 3 if selected and depth > 0 else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	if hover and not selected:
		style.bg_color = style.bg_color.lightened(0.16)
	elif hover and selected:
		style.border_color = style.border_color.lightened(0.24)
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	if pressed:
		style.bg_color = style.bg_color.darkened(0.10)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = UiTypography.SPACE_MEDIUM
	style.content_margin_top = UiTypography.SPACE_TIGHT
	style.content_margin_right = UiTypography.SPACE_SMALL
	style.content_margin_bottom = UiTypography.SPACE_TIGHT
	return style

func _refresh_grimoire_nav_minimum_size() -> void:
	# Replacing rows can leave the list with the same minimum size, so it
	# emits no change to refresh ScrollContainer's cached child extent.
	# Recalculate with the final rows before restoring scroll or handling input.
	_grimoire_entry_scroll.update_minimum_size()

func _restore_grimoire_entry_list_scroll(scroll_position: int, attempt: int = 0, revision: int = 0) -> void:
	if revision != _grimoire_nav_scroll_revision:
		return
	if _grimoire_entry_scroll == null:
		return
	var scroll_bar: VScrollBar = _grimoire_entry_scroll.get_v_scroll_bar()
	var layout_not_ready: bool = _grimoire_entry_scroll.size.y <= 0.0 \
			or (_grimoire_entry_list != null and _grimoire_entry_list.size.y <= 0.0) \
			or (scroll_position > 0 and scroll_bar != null and scroll_bar.max_value <= scroll_bar.page)
	if layout_not_ready and attempt < 4:
		call_deferred("_restore_grimoire_entry_list_scroll", scroll_position, attempt + 1, revision)
		return
	_grimoire_entry_scroll.scroll_vertical = maxi(0, scroll_position)

func _scroll_grimoire_entry_list_to_index(index: int, attempt: int = 0, revision: int = 0) -> void:
	if revision != _grimoire_nav_scroll_revision:
		return
	if _grimoire_entry_scroll == null:
		return
	if _grimoire_entry_list == null or _grimoire_entry_list.get_child_count() <= 0:
		return
	var safe_index: int = clampi(index, 0, _grimoire_entry_list.get_child_count() - 1)
	var child: Control = _grimoire_entry_list.get_child(safe_index) as Control
	if child == null:
		return
	if (child.size.y <= 0.0 or _grimoire_entry_scroll.size.y <= 0.0) and attempt < 4:
		call_deferred("_scroll_grimoire_entry_list_to_index", safe_index, attempt + 1, revision)
		return
	var target: int = maxi(0, int(child.position.y - _grimoire_entry_scroll.size.y * 0.45 + child.size.y * 0.5))
	_grimoire_entry_scroll.scroll_vertical = target
	_grimoire_entry_scroll.ensure_control_visible(child)

func _grimoire_group_ids_for_entries(entries: Array[Dictionary]) -> Array[String]:
	var found: Array[String]
	for entry: Dictionary in entries:
		var group_id: String = _grimoire_entry_group_id(entry)
		if group_id.is_empty() or found.has(group_id):
			continue
		found.append(group_id)
	if found.size() <= 1:
		return found
	var ordered: Array[String]
	for preferred: String in ["none", "fire", "ice", "lightning", "air", "earth", "weapon", "offhand", "armor", "boots", "trinket"]:
		if found.has(preferred):
			ordered.append(preferred)
	for group_id: String in found:
		if not ordered.has(group_id):
			ordered.append(group_id)
	return ordered

func _grimoire_entry_group_id(entry: Dictionary) -> String:
	return str(entry.get("group", ""))

func _grimoire_entries_for_group(entries: Array[Dictionary], group_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		if _grimoire_entry_group_id(entry) == group_id:
			result.append(entry)
	return result

func _grimoire_group_title(entries: Array[Dictionary], group_id: String) -> String:
	for entry: Dictionary in entries:
		var title: String = str(entry.get("group_title", ""))
		if not title.is_empty():
			return title
	return group_id.capitalize()

func _grimoire_group_has_unread(entries: Array[Dictionary], unread: Array[String]) -> bool:
	for entry: Dictionary in entries:
		if unread.has(str(entry.get("id", ""))):
			return true
	return false

func _refresh_grimoire_detail() -> void:
	if _grimoire_detail_title == null or _grimoire_detail_body == null:
		return
	if _grimoire_detail_content != null:
		_clear_children_now(_grimoire_detail_content)
	var entry: Dictionary = GrimoireLibrary.entry_def(_grimoire_selected_entry)
	var enemy_id: String = str(entry.get("enemy_id", ""))
	var page_changed: bool = _grimoire_detail_entry != _grimoire_selected_entry
	_grimoire_detail_entry = _grimoire_selected_entry
	_set_creature_detail(not enemy_id.is_empty())
	if page_changed and _grimoire_detail_scroll.visible:
		_grimoire_detail_scroll.scroll_vertical = 0
	if entry.is_empty():
		_grimoire_detail_kicker.text = "SEARCH" if _grimoire_search_active() else ""
		_grimoire_detail_title.text = "No known match" if _grimoire_search_active() else "No entries"
		_grimoire_detail_body.text = "Try a name, common term, rule, character, or creature." if _grimoire_search_active() else ""
		_grimoire_detail_body.visible = true
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grimoire_detail_icon.texture = book_icon()
		return
	var section: Dictionary = GrimoireLibrary.section_def(str(entry.get("section", "")))
	_grimoire_detail_kicker.text = str(section.get("title", ""))
	_grimoire_detail_title.text = str(entry.get("title", _grimoire_selected_entry))
	_grimoire_detail_icon.texture = detail_icon.call(entry) if detail_icon.is_valid() else entry_icon(entry, ActionIcons.icon_texture)
	var body_text: String = _grimoire_body_text(entry)
	var card_id: String = str(entry.get("card_id", ""))
	var equipment_id: String = str(entry.get("equipment_id", ""))
	if not card_id.is_empty():
		_grimoire_detail_body.text = ""
		_grimoire_detail_body.visible = false
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_populate_grimoire_card_detail(card_id)
	elif not equipment_id.is_empty():
		InlineIconText.apply_to(_grimoire_detail_body, body_text, InlineIconText.DEFAULT_ICON_SCALE, true)
		_grimoire_detail_body.visible = not body_text.is_empty()
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_populate_grimoire_equipment_detail(equipment_id)
	elif not enemy_id.is_empty():
		InlineIconText.apply_to(_grimoire_detail_body, body_text, InlineIconText.DEFAULT_ICON_SCALE, true)
		_grimoire_detail_body.visible = not body_text.is_empty()
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		CreaturePage.populate(self, _grimoire_detail_content, enemy_id)
	else:
		InlineIconText.apply_to(_grimoire_detail_body, body_text, InlineIconText.DEFAULT_ICON_SCALE, true)
		_grimoire_detail_body.visible = true
		_grimoire_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _set_creature_detail(enabled: bool) -> void:
	if _grimoire_detail_scroll.visible == enabled:
		return
	var parent: VBoxContainer = _grimoire_creature_stack if enabled else _grimoire_detail_stack
	_grimoire_detail_body.reparent(parent, false)
	_grimoire_detail_content.reparent(parent, false)
	_grimoire_detail_scroll.visible = enabled
	_grimoire_detail_body.scroll_active = not enabled

func _populate_grimoire_card_detail(card_id: String) -> void:
	if _grimoire_detail_content == null:
		return
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_build_card_preview_widget(card_id, GRIMOIRE_CARD_PREVIEW_SIZE, true))
	_grimoire_detail_content.add_child(center)

func _populate_grimoire_equipment_detail(equipment_id: String) -> void:
	if _grimoire_detail_content == null:
		return
	var card_ids: Array = GameData.equipment_cards(equipment_id)
	if card_ids.is_empty():
		return
	_grimoire_detail_content.add_child(_grimoire_section_heading("Granted Cards"))
	var row := ItemPreviewBuilders.granted_card_row()
	_grimoire_detail_content.add_child(row)
	for card_id_var: Variant in card_ids:
		row.add_child(_build_card_preview_widget(str(card_id_var), GRIMOIRE_EQUIPMENT_CARD_SIZE, true))

func _grimoire_section_heading(title: String) -> Label:
	var label := Label.new()
	label.text = title
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
	label.add_theme_color_override("font_color", Color.hex(GRANTED_CARDS_TEXT))
	label.add_theme_color_override("font_outline_color", _rgba(GRANTED_CARDS_OUTLINE_RGBA))
	label.add_theme_constant_override("outline_size", 1)
	return label

func _grimoire_body_text(entry: Dictionary) -> String:
	return preload("res://scripts/input_wording.gd").grimoire_body(entry, _controller_is_active())

static func entry_icon(entry: Dictionary, action_icon: Callable) -> Texture2D:
	var card_id: String = str(entry.get("card_id", ""))
	if not card_id.is_empty():
		var card: Dictionary = GameData.card_def(card_id)
		var card_art_path: String = str(card.get("art_path", ""))
		var card_texture: Texture2D = AssetLoader.load_texture(card_art_path)
		if card_texture != null:
			return card_texture
	var equipment_id: String = str(entry.get("equipment_id", ""))
	if not equipment_id.is_empty():
		var equipment: Dictionary = GameData.equipment_def(equipment_id)
		var equipment_texture: Texture2D = AssetLoader.load_texture(str(equipment.get("icon_path", "")))
		if equipment_texture != null:
			return equipment_texture
	var npc_id: String = str(entry.get("npc_id", ""))
	if not npc_id.is_empty():
		var npc: Dictionary = GameData.npc_def(npc_id)
		var npc_texture: Texture2D = AssetLoader.load_texture(str(npc.get("art_path", "")))
		if npc_texture != null:
			return npc_texture
	var enemy_id: String = str(entry.get("enemy_id", ""))
	if not enemy_id.is_empty():
		var enemy: Dictionary = GameData.enemy_def(enemy_id)
		var enemy_art_path: String = str(enemy.get("art_path", ""))
		var enemy_texture: Texture2D = AssetLoader.load_texture(enemy_art_path)
		if enemy_texture != null:
			return enemy_texture
	var icon_key: String = str(entry.get("icon", ""))
	if not icon_key.is_empty():
		var texture: Texture2D = action_icon.call(icon_key)
		if texture != null:
			return texture
	return book_icon()

func _on_grimoire_section_pressed(section_id: String) -> void:
	var restore_nav_focus: bool = _grimoire_nav_has_focus()
	_grimoire_selected_section = section_id
	_grimoire_selected_group = ""
	_grimoire_selected_entry = ""
	_rebuild_grimoire_overlay()
	if restore_nav_focus:
		call_deferred("_focus_grimoire_nav_item", "section", section_id)

func _on_grimoire_group_pressed(section_id: String, group_id: String) -> void:
	var restore_nav_focus: bool = _grimoire_nav_has_focus()
	_grimoire_selected_section = section_id
	_grimoire_selected_group = group_id
	_grimoire_selected_entry = ""
	_rebuild_grimoire_overlay()
	if restore_nav_focus:
		call_deferred("_focus_grimoire_nav_item", "group", "%s:%s" % [section_id, group_id])

func _on_grimoire_entry_pressed(entry_id: String) -> void:
	var restore_nav_focus: bool = _grimoire_nav_has_focus()
	var entry: Dictionary = GrimoireLibrary.entry_def(entry_id)
	if not entry.is_empty():
		_grimoire_selected_section = str(entry.get("section", _grimoire_selected_section))
	_grimoire_selected_entry = entry_id
	_grimoire_selected_group = _grimoire_entry_group_id(entry)
	_rebuild_grimoire_overlay()
	if restore_nav_focus:
		call_deferred("_focus_grimoire_nav_item", "entry", entry_id)

func _grimoire_nav_has_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if not focus_owner is Button:
		return false
	return _grimoire_nav_buttons.has(focus_owner as Button)

func _focus_grimoire_nav_item(kind: String, item_id: String) -> void:
	for button: Button in _grimoire_nav_buttons:
		if str(button.get_meta("grimoire_nav_kind", "")) == kind \
				and str(button.get_meta("grimoire_nav_id", "")) == item_id:
			button.grab_focus()
			return

func _on_grimoire_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event: InputEventMouseButton = event
		if _grimoire_dialog != null and _grimoire_dialog.get_global_rect().has_point(mouse_event.global_position):
			return
		close()
		accept_event()

func _grimoire_scrim_cursor_feedback_context(local_position: Vector2) -> String:
	if not visible:
		return "inert"
	var global_position: Vector2 = get_global_transform_with_canvas() * local_position
	if _grimoire_dialog != null and _grimoire_dialog.get_global_rect().has_point(global_position):
		return "inert"
	return "action"

func _clear_children_now(node: Node) -> void:
	for child: Node in node.get_children():
		_prepare_node_for_immediate_free(child)
		node.remove_child(child)
		if _node_is_alive(child):
			child.queue_free()

func _node_is_alive(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not (node as Node).is_queued_for_deletion()

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

static func _draw_header_book_icon(image: Image, ink: Color) -> void:
	draw_icon_line(image, Vector2i(11, 15), Vector2i(23, 11), ink, 3)
	draw_icon_line(image, Vector2i(23, 11), Vector2i(23, 36), ink, 3)
	draw_icon_line(image, Vector2i(23, 36), Vector2i(11, 32), ink, 3)
	draw_icon_line(image, Vector2i(11, 32), Vector2i(11, 15), ink, 3)
	draw_icon_line(image, Vector2i(25, 11), Vector2i(37, 15), ink, 3)
	draw_icon_line(image, Vector2i(37, 15), Vector2i(37, 32), ink, 3)
	draw_icon_line(image, Vector2i(37, 32), Vector2i(25, 36), ink, 3)
	draw_icon_line(image, Vector2i(25, 36), Vector2i(25, 11), ink, 3)
	draw_icon_line(image, Vector2i(15, 19), Vector2i(20, 17), ink.darkened(0.18), 2)
	draw_icon_line(image, Vector2i(15, 24), Vector2i(20, 23), ink.darkened(0.18), 2)
	draw_icon_line(image, Vector2i(28, 17), Vector2i(33, 19), ink.darkened(0.18), 2)
	draw_icon_line(image, Vector2i(28, 23), Vector2i(33, 24), ink.darkened(0.18), 2)

static func draw_icon_line(image: Image, from_point: Vector2i, to_point: Vector2i, color: Color, width: int = 1) -> void:
	var delta: Vector2i = to_point - from_point
	var steps: int = maxi(abs(delta.x), abs(delta.y))
	if steps <= 0:
		_draw_image_point(image, from_point, color, width)
		return
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		var point := Vector2i(
				roundi(lerpf(float(from_point.x), float(to_point.x), t)),
				roundi(lerpf(float(from_point.y), float(to_point.y), t))
		)
		_draw_image_point(image, point, color, width)

static func _draw_image_point(image: Image, point: Vector2i, color: Color, width: int = 1) -> void:
	var radius: int = maxi(0, int(floor(float(width) * 0.5)))
	for y: int in range(point.y - radius, point.y + radius + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x: int in range(point.x - radius, point.x + radius + 1):
			if x < 0 or x >= image.get_width():
				continue
			if Vector2(float(x), float(y)).distance_to(Vector2(float(point.x), float(point.y))) <= float(radius) + 0.65:
				image.set_pixel(x, y, color)
