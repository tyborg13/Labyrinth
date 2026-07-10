extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const BACKGROUND_ART_PATH: String = "res://assets/art/ui/main_menu_umbra_dragon.png"
const HEADER_FONT = preload("res://fonts/LabyrinthCrumble-Header.tres")
const REGULAR_FONT = preload("res://fonts/LabyrinthCrumble-Regular.tres")

const TITLE_LINE_TEXTS := ["Escape", "the", "Umbra"]
const TITLE_LINE_ROW_INDICES := [0, 1, 1]
const TITLE_LINE_SCALE_FACTORS := [1.0, 0.58, 1.0]
const TITLE_ROW_OFFSET_FACTORS := [0.0, 0.72]
const TITLE_WORD_GAP_FACTOR: float = 0.10
const FALLBACK_PROFILE_TEXT: String = "Profile Reaver"
const TITLE_BASE_SIZE: int = 114
const TITLE_MIN_SIZE: int = 42
const TITLE_SMALL_LINE_MIN_SIZE: int = 28
const TITLE_LINE_SPACING: int = -8
const TITLE_TO_MENU_EXTRA_GAP: float = 14.0
const MENU_FONT_SIZE: int = 34
const MENU_BUTTON_HEIGHT: float = 78.0
const MENU_BUTTON_HEIGHT_COMPACT: float = 64.0
const MENU_BUTTON_MIN_WIDTH: float = 380.0
const MENU_BUTTON_MAX_WIDTH: float = 470.0
const MENU_SEPARATION: int = 14
const CONTEXT_PANEL_MIN_WIDTH: float = 300.0
const CONTEXT_PANEL_MAX_WIDTH: float = 360.0
const CONTEXT_PANEL_GAP: float = 24.0
const RESUME_PANEL_HEIGHT: float = 124.0
const REPLACEMENT_PANEL_HEIGHT: float = 248.0
const EDGE_ACCENT := Color("d69b47")
const DANGER_ACCENT := Color("b94c3f")
const SAVED_RUN_MODE_LABELS := {
	"room": "EXPLORING",
	"pre_battle": "AT THE THRESHOLD",
	"combat": "IN COMBAT",
	"reward": "CHOOSING A REWARD",
	"campfire": "AT CAMPFIRE",
	"treasure": "AT TREASURE"
}
const TITLE_FACE_TOP_COLOR := Color("fff7cf")
const TITLE_FACE_HIGH_COLOR := Color("ffe08e")
const TITLE_FACE_MID_COLOR := Color("dd853e")
const TITLE_FACE_LOW_COLOR := Color("85311f")
const TITLE_FACE_BOTTOM_COLOR := Color("2d0b24")
const TITLE_FACE_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 top_color : source_color;
uniform vec4 high_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 low_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float gradient_height = 1.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float y = clamp(local_y / max(gradient_height, 1.0), 0.0, 1.0);
	vec4 ramp = mix(top_color, high_color, smoothstep(0.00, 0.32, y));
	ramp = mix(ramp, mid_color, smoothstep(0.22, 0.62, y));
	ramp = mix(ramp, low_color, smoothstep(0.50, 0.86, y));
	ramp = mix(ramp, bottom_color, smoothstep(0.76, 1.00, y));
	COLOR = vec4(ramp.rgb, glyph.a * COLOR.a);
}
"""

@onready var background_art: TextureRect = $MenuArt
@onready var global_scrim: ColorRect = $GlobalScrim
@onready var left_scrim: ColorRect = $LeftScrim
@onready var title_shadow_label: Label = $TitleShadow
@onready var title_rim_label: Label = $TitleRim
@onready var title_label: Label = $Title
@onready var title_face_blend: Control = $TitleFaceBlend
@onready var menu_column: VBoxContainer = $MenuColumn
@onready var continue_button: Button = $MenuColumn/ContinueButton
@onready var start_button: Button = $MenuColumn/StartButton
@onready var settings_button: Button = $MenuColumn/SettingsButton
@onready var quit_button: Button = $MenuColumn/QuitButton
@onready var boss_button: Button = $MenuColumn/BossButton
@onready var resume_panel: PanelContainer = $ResumePanel
@onready var resume_location_label: Label = $ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation
@onready var resume_stats_label: Label = $ResumePanel/ResumeMargin/ResumeVBox/ResumeStats
@onready var profile_block: VBoxContainer = $ProfileBlock
@onready var embers_label: Label = $ProfileBlock/Embers
@onready var footer_label: Label = $ProfileBlock/Footer
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var replacement_panel: PanelContainer = $ReplacementPanel
@onready var replacement_location_label: Label = $ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementLocation
@onready var replacement_stats_label: Label = $ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementStats
@onready var replacement_cancel_button: Button = $ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementActions/ReplacementCancelButton
@onready var replacement_confirm_button: Button = $ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementActions/ReplacementConfirmButton

var _progression: Dictionary = {}
var _saved_run_preview: Dictionary = {}
var _replacement_confirmation_open: bool = false
var _using_keyboard_navigation: bool = false
var _music_player: AudioStreamPlayer
var _ui_skin: UiSkin = UiSkin.new()
var settings_back_button: Button
var _title_shadow_lines: Array[Label]
var _title_rim_lines: Array[Label]
var _title_base_lines: Array[Label]
var _title_face_lines: Array[Label]
var _title_face_materials: Array[ShaderMaterial]

func _ready() -> void:
	ParallelRuntime.apply_from_environment()
	SettingsStore.apply_settings(SettingsStore.load_settings(), get_window())
	_initialize_title_arrays()
	_connect_steam_service()
	settings_back_button = settings_panel.call("back_button") as Button
	if settings_panel.has_signal("back_requested"):
		settings_panel.connect("back_requested", Callable(self, "_on_settings_back_button_pressed"))
	resized.connect(_update_layout)
	_apply_style()
	_reload_progression()
	_update_layout()
	_play_menu_music()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_using_keyboard_navigation = false
		call_deferred("_clear_menu_keyboard_focus")
	elif event is InputEventMouseButton:
		_using_keyboard_navigation = false
		var mouse_button := event as InputEventMouseButton
		# Releasing focus on mouse-down can cancel Button's press/release click path.
		if not mouse_button.pressed:
			call_deferred("_clear_menu_keyboard_focus")

func _unhandled_input(event: InputEvent) -> void:
	if not _is_keyboard_navigation_event(event):
		return
	_using_keyboard_navigation = true
	if _menu_or_settings_has_focus():
		return
	_focus_default_keyboard_target()
	get_viewport().set_input_as_handled()

func _apply_style() -> void:
	background_art.texture = AssetLoader.load_texture(BACKGROUND_ART_PATH)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	global_scrim.color = Color(0.0, 0.0, 0.0, 0.16)
	left_scrim.visible = false

	_configure_title_container(title_shadow_label)
	_configure_title_container(title_rim_label)
	_configure_title_container(title_label)
	_configure_title_container(title_face_blend)
	_ensure_title_line_labels()
	_apply_title_layer_style(_title_shadow_lines, Color("5b2d74"), Color("0b040f"), 18, Color(1.0, 0.78, 1.0, 0.78))
	_apply_title_layer_style(_title_rim_lines, Color("c0522f"), Color("170508"), 13, Color(1.0, 0.78, 0.56, 0.88))
	_apply_title_layer_style(_title_base_lines, Color("ffd98d"), Color("210725"), 12, Color.WHITE)
	_apply_title_layer_style(_title_face_lines, Color.WHITE, Color.TRANSPARENT, 0, Color.WHITE)

	menu_column.add_theme_constant_override("separation", MENU_SEPARATION)
	for button: Button in [continue_button, start_button, settings_button, quit_button, boss_button]:
		_apply_menu_button_style(button)
	_apply_confirmation_button_style(replacement_cancel_button, false)
	_apply_confirmation_button_style(replacement_confirm_button, true)
	boss_button.visible = false

	resume_panel.add_theme_stylebox_override("panel", _make_context_panel_style(EDGE_ACCENT, 0.90))
	_apply_label_style($ResumePanel/ResumeMargin/ResumeVBox/ResumeEyebrow, REGULAR_FONT, 14, Color("c9a86c"), Color("100908"), 2)
	_apply_label_style(resume_location_label, HEADER_FONT, 23, Color("fff0c4"), Color("100908"), 4)
	_apply_label_style(resume_stats_label, REGULAR_FONT, 17, Color("e7d7ba"), Color("100908"), 2)

	_apply_label_style(embers_label, HEADER_FONT, 22, Color("f6d99f"), Color("100908"), 3)
	_apply_label_style(footer_label, REGULAR_FONT, 15, Color("dbc59b"), Color("100908"), 2)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	replacement_panel.add_theme_stylebox_override("panel", _make_context_panel_style(DANGER_ACCENT, 0.94))
	_apply_label_style($ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementTitle, HEADER_FONT, 27, Color("fff1cf"), Color("090708"), 5)
	_apply_label_style($ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementWarning, REGULAR_FONT, 15, Color("d9b8a4"), Color("090708"), 2)
	_apply_label_style(replacement_location_label, HEADER_FONT, 20, Color("ffe2b0"), Color("090708"), 4)
	_apply_label_style(replacement_stats_label, REGULAR_FONT, 16, Color("e7d7ba"), Color("090708"), 2)

func _configure_title_container(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control is Label:
		(control as Label).text = ""

func _initialize_title_arrays() -> void:
	_title_shadow_lines = _make_empty_title_label_array()
	_title_rim_lines = _make_empty_title_label_array()
	_title_base_lines = _make_empty_title_label_array()
	_title_face_lines = _make_empty_title_label_array()
	_title_face_materials = _make_title_face_material_array()

func _make_empty_title_label_array() -> Array[Label]:
	var labels: Array[Label]
	return labels

func _ensure_title_line_labels() -> void:
	if not _title_shadow_lines.is_empty():
		return
	_title_shadow_lines = _make_title_line_labels(title_shadow_label, "TitleShadowLine")
	_title_rim_lines = _make_title_line_labels(title_rim_label, "TitleRimLine")
	_title_base_lines = _make_title_line_labels(title_label, "TitleBaseLine")
	_title_face_lines = _make_title_line_labels(title_face_blend, "TitleFaceLine")
	_title_face_materials = _make_title_face_material_array()
	for index: int in range(_title_face_lines.size()):
		var material := _make_title_face_material()
		_title_face_materials.append(material)
		_title_face_lines[index].material = material

func _make_title_line_labels(parent: Node, prefix: String) -> Array[Label]:
	for child: Node in parent.get_children():
		child.queue_free()
	var labels: Array[Label]
	for index: int in range(TITLE_LINE_TEXTS.size()):
		var label := Label.new()
		label.name = "%s%d" % [prefix, index + 1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(label)
		labels.append(label)
	return labels

func _make_title_face_material_array() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial]
	return materials

func _apply_title_layer_style(labels: Array[Label], color: Color, outline_color: Color, outline_size: int, modulate_color: Color) -> void:
	for index: int in range(labels.size()):
		_apply_title_style(labels[index], str(TITLE_LINE_TEXTS[index]), color, outline_color, outline_size)
		labels[index].modulate = modulate_color

func _apply_title_style(label: Label, text: String, color: Color, outline_color: Color, outline_size: int) -> void:
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override("font", HEADER_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)

func _make_title_face_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = TITLE_FACE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top_color", TITLE_FACE_TOP_COLOR)
	material.set_shader_parameter("high_color", TITLE_FACE_HIGH_COLOR)
	material.set_shader_parameter("mid_color", TITLE_FACE_MID_COLOR)
	material.set_shader_parameter("low_color", TITLE_FACE_LOW_COLOR)
	material.set_shader_parameter("bottom_color", TITLE_FACE_BOTTOM_COLOR)
	return material

func _apply_label_style(label: Label, font: Font, size: int, color: Color, outline_color: Color, outline_size: int) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)

func _apply_menu_button_style(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", HEADER_FONT)
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_LARGE)
	_ui_skin.apply_button_text_overrides(button, Color("f3e5c5"), Color("080606"), Color("8d806b"), 5)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _apply_confirmation_button_style(button: Button, destructive: bool) -> void:
	_apply_menu_button_style(button)
	button.add_theme_font_size_override("font_size", 20)
	if not destructive:
		return
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_DESTRUCTIVE)
	_ui_skin.apply_button_text_overrides(button, Color("ffe2d6"), Color("120507"), Color("8d6d68"), 4)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER

func _apply_continue_button_state(primary: bool) -> void:
	_apply_menu_button_style(continue_button)
	if not primary:
		return
	_ui_skin.apply_button_stylebox_overrides(continue_button, UiSkin.VARIANT_SELECTED)
	_ui_skin.apply_button_text_overrides(continue_button, Color("fff2cf"), Color("080606"), Color("8d806b"), 5)
	continue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.023, 0.025, 0.033, 0.88)
	style.border_color = Color("d69b47")
	style.border_width_left = 4
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 14
	style.content_margin_left = 18
	style.content_margin_top = 18
	style.content_margin_right = 18
	style.content_margin_bottom = 18
	return style

func _make_context_panel_style(accent: Color, opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.020, 0.028, opacity)
	style.border_color = accent
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 12
	style.content_margin_left = 18
	style.content_margin_top = 15
	style.content_margin_right = 18
	style.content_margin_bottom = 15
	return style

func _reload_progression() -> void:
	_progression = ProgressionStore.load_data()
	_refresh_saved_run_preview()
	embers_label.text = _profile_text()
	footer_label.text = "LV %d  |  EMBERS %d  |  BOUND %d" % [
		int(_progression.get("level", 1)),
		int(_progression.get("embers", 0)),
		_bound_magick_count()
	]

func _refresh_saved_run_preview() -> void:
	_saved_run_preview = _build_saved_run_preview(ProgressionStore.load_saved_run())
	var has_valid_save: bool = not _saved_run_preview.is_empty()
	if not has_valid_save:
		_replacement_confirmation_open = false
	continue_button.text = "Continue Run" if has_valid_save else "Continue"
	_set_menu_actions_locked(_replacement_confirmation_open)
	_apply_continue_button_state(has_valid_save)
	_apply_preview_text(_saved_run_preview)
	_sync_context_panels()

func _build_saved_run_preview(run_state: Dictionary) -> Dictionary:
	if run_state.is_empty():
		return {}
	var mode_value: Variant = run_state.get("mode", null)
	var coord_value: Variant = run_state.get("current_room", null)
	var hp_value: Variant = run_state.get("player_hp", null)
	var max_hp_value: Variant = run_state.get("player_max_hp", null)
	var ember_value: Variant = run_state.get("held_embers", run_state.get("unbanked_embers", null))
	if typeof(mode_value) not in [TYPE_STRING, TYPE_STRING_NAME] or not SAVED_RUN_MODE_LABELS.has(str(mode_value)):
		return {}
	if typeof(coord_value) != TYPE_VECTOR2I:
		return {}
	if not _is_numeric_value(hp_value) or not _is_numeric_value(max_hp_value) or not _is_numeric_value(ember_value):
		return {}
	var player_hp: int = int(hp_value)
	var player_max_hp: int = int(max_hp_value)
	var held_embers: int = int(ember_value)
	if player_max_hp <= 0 or player_hp < 0 or player_hp > player_max_hp or held_embers < 0:
		return {}
	var coord: Vector2i = coord_value
	if not _has_resumable_saved_run_structure(run_state, str(mode_value), coord, player_hp, player_max_hp):
		return {}
	var depth: int = _saved_room_depth(run_state, coord)
	return {
		"location": "DEPTH %d  ·  %s" % [depth, str(SAVED_RUN_MODE_LABELS[str(mode_value)])],
		"stats": "HP %d / %d  ·  HELD %d EMBERS" % [player_hp, player_max_hp, held_embers]
	}

func _is_numeric_value(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]

func _has_resumable_saved_run_structure(run_state: Dictionary, mode: String, coord: Vector2i, player_hp: int, player_max_hp: int) -> bool:
	if not _is_numeric_value(run_state.get("seed", null)):
		return false
	if typeof(run_state.get("current_room_layout", null)) != TYPE_DICTIONARY or (run_state.get("current_room_layout", {}) as Dictionary).is_empty():
		return false
	var rooms_value: Variant = run_state.get("rooms", null)
	if typeof(rooms_value) != TYPE_DICTIONARY:
		return false
	var room_value: Variant = (rooms_value as Dictionary).get("%d,%d" % [coord.x, coord.y], null)
	if typeof(room_value) != TYPE_DICTIONARY:
		return false
	var room: Dictionary = room_value
	if not _is_numeric_value(room.get("depth", null)) or str(room.get("type", "")).is_empty():
		return false
	var room_coord_value: Variant = room.get("coord", null)
	if typeof(room_coord_value) != TYPE_VECTOR2I or room_coord_value != coord:
		return false
	var deck_value: Variant = run_state.get("deck_cards", null)
	if typeof(deck_value) != TYPE_ARRAY or (deck_value as Array).is_empty():
		return false
	match mode:
		"combat":
			return _has_resumable_combat_structure(run_state, player_hp, player_max_hp)
		"pre_battle":
			return bool(run_state.get("pre_battle_pending", false)) and typeof(run_state.get("pre_battle_travel_dir", null)) == TYPE_VECTOR2I
		"reward":
			var reward_value: Variant = run_state.get("pending_reward", null)
			return typeof(reward_value) == TYPE_DICTIONARY and typeof((reward_value as Dictionary).get("cards", null)) == TYPE_ARRAY and not ((reward_value as Dictionary).get("cards", []) as Array).is_empty()
		"treasure":
			var relics_value: Variant = run_state.get("pending_relics", null)
			return typeof(relics_value) == TYPE_ARRAY and not (relics_value as Array).is_empty()
		"room", "campfire":
			return true
	return false

func _has_resumable_combat_structure(run_state: Dictionary, player_hp: int, player_max_hp: int) -> bool:
	var combat_value: Variant = run_state.get("combat_state", null)
	if typeof(combat_value) != TYPE_DICTIONARY or (combat_value as Dictionary).is_empty():
		return false
	var combat_state: Dictionary = combat_value
	var combat_player_value: Variant = combat_state.get("player", null)
	if typeof(combat_player_value) != TYPE_DICTIONARY:
		return false
	var combat_player: Dictionary = combat_player_value
	if not _is_numeric_value(combat_player.get("hp", null)) or not _is_numeric_value(combat_player.get("max_hp", null)):
		return false
	if int(combat_player.get("hp", -1)) != player_hp or int(combat_player.get("max_hp", -1)) != player_max_hp:
		return false
	var combat_deck_value: Variant = combat_state.get("deck", null)
	var enemies_value: Variant = combat_state.get("enemies", null)
	return (
		typeof(combat_deck_value) == TYPE_DICTIONARY
		and not (combat_deck_value as Dictionary).is_empty()
		and typeof(enemies_value) == TYPE_ARRAY
		and not (enemies_value as Array).is_empty()
	)

func _saved_room_depth(run_state: Dictionary, coord: Vector2i) -> int:
	var fallback: int = maxi(absi(coord.x), absi(coord.y))
	var rooms_value: Variant = run_state.get("rooms", {})
	if typeof(rooms_value) != TYPE_DICTIONARY:
		return fallback
	var room_value: Variant = (rooms_value as Dictionary).get("%d,%d" % [coord.x, coord.y], {})
	if typeof(room_value) != TYPE_DICTIONARY:
		return fallback
	var depth_value: Variant = (room_value as Dictionary).get("depth", fallback)
	return maxi(0, int(depth_value)) if _is_numeric_value(depth_value) else fallback

func _apply_preview_text(preview: Dictionary) -> void:
	var location: String = str(preview.get("location", ""))
	var stats: String = str(preview.get("stats", ""))
	resume_location_label.text = location
	resume_stats_label.text = stats
	replacement_location_label.text = location
	replacement_stats_label.text = stats

func _sync_context_panels() -> void:
	var has_valid_save: bool = not _saved_run_preview.is_empty()
	replacement_panel.visible = _replacement_confirmation_open and has_valid_save
	resume_panel.visible = has_valid_save and not _replacement_confirmation_open and not settings_panel.visible

func _set_menu_actions_locked(locked: bool) -> void:
	continue_button.disabled = locked or _saved_run_preview.is_empty()
	start_button.disabled = locked
	settings_button.disabled = locked
	quit_button.disabled = locked
	boss_button.disabled = locked

func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var margin_x: float = clampf(viewport_size.x * 0.04, 30.0, 72.0)
	var title_y: float = clampf(viewport_size.y * 0.052, 26.0, 62.0)
	var menu_width: float = clampf(viewport_size.x * 0.22, MENU_BUTTON_MIN_WIDTH, MENU_BUTTON_MAX_WIDTH)
	var button_height: float = MENU_BUTTON_HEIGHT_COMPACT if viewport_size.y < 700.0 else MENU_BUTTON_HEIGHT
	var title_max_width: float = minf(viewport_size.x - margin_x * 2.0, clampf(viewport_size.x * 0.38, 340.0, 700.0))
	var title_max_height: float = clampf(viewport_size.y * 0.30, 136.0, 312.0)
	var title_font_size: int = _fitted_title_font_size(title_max_width, title_max_height)
	var title_height: float = maxf(_title_text_height(title_font_size), 54.0)
	var title_size := Vector2(title_max_width, title_height + 34.0)

	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_shadow_label.add_theme_font_size_override("font_size", title_font_size)
	title_rim_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.position = Vector2(margin_x, title_y)
	title_shadow_label.position = title_label.position + Vector2(18.0, 15.0)
	title_rim_label.position = title_label.position + Vector2(7.0, 6.0)
	title_label.size = title_size
	title_shadow_label.size = title_size
	title_rim_label.size = title_size
	title_face_blend.position = title_label.position
	title_face_blend.size = title_size
	_layout_title_lines(title_font_size)

	var menu_y: float = title_y + title_size.y + clampf(viewport_size.y * 0.028, 20.0, 42.0) + TITLE_TO_MENU_EXTRA_GAP
	menu_column.position = Vector2(margin_x, menu_y)
	menu_column.size = Vector2(menu_width, _menu_column_height(button_height))
	for button: Button in [continue_button, start_button, settings_button, quit_button, boss_button]:
		button.custom_minimum_size = Vector2(menu_width, button_height)

	var context_width: float = clampf(viewport_size.x * 0.18, CONTEXT_PANEL_MIN_WIDTH, CONTEXT_PANEL_MAX_WIDTH)
	var context_x: float = margin_x + menu_width + CONTEXT_PANEL_GAP
	var context_y: float = menu_y
	if context_x + context_width + margin_x > viewport_size.x:
		context_x = margin_x
		context_y = menu_y + _menu_column_height(button_height) + 20.0
		context_width = menu_width
	resume_panel.position = Vector2(context_x, context_y)
	resume_panel.size = Vector2(context_width, RESUME_PANEL_HEIGHT)
	replacement_panel.position = Vector2(context_x, context_y)
	replacement_panel.size = Vector2(maxf(context_width, 340.0), REPLACEMENT_PANEL_HEIGHT)

	var profile_width: float = minf(menu_width + 72.0, viewport_size.x - margin_x * 2.0)
	var profile_height: float = 86.0
	var profile_y: float = viewport_size.y - profile_height - clampf(viewport_size.y * 0.055, 34.0, 64.0)
	profile_block.visible = profile_y > menu_y + _menu_column_height(button_height) + 16.0
	profile_block.position = Vector2(margin_x, profile_y)
	profile_block.size = Vector2(profile_width, profile_height)

	left_scrim.position = Vector2.ZERO
	left_scrim.size = Vector2.ZERO

	var panel_width: float = minf(900.0, maxf(720.0, viewport_size.x - margin_x * 2.0))
	var panel_height: float = minf(800.0, viewport_size.y - 48.0)
	var panel_x: float = margin_x + menu_width + 38.0
	var panel_y: float = maxf(24.0, (viewport_size.y - panel_height) * 0.5)
	if panel_x + panel_width + margin_x > viewport_size.x:
		panel_width = minf(900.0, viewport_size.x - margin_x * 2.0)
		panel_x = (viewport_size.x - panel_width) * 0.5
	settings_panel.position = Vector2(panel_x, panel_y)
	settings_panel.size = Vector2(panel_width, panel_height)

func _layout_title_lines(title_font_size: int) -> void:
	_ensure_title_line_labels()
	var row_ys: Array = _title_row_y_positions(title_font_size)
	var row_next_x: Array = []
	for row_index: int in range(_title_row_count()):
		row_next_x.append(_title_row_offset_x(title_font_size, row_index))
	for index: int in range(TITLE_LINE_TEXTS.size()):
		var row_index: int = _title_line_row_index(index)
		var line_font_size: int = _title_line_font_size(title_font_size, index)
		var line_text := str(TITLE_LINE_TEXTS[index])
		var line_width: float = HEADER_FONT.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, line_font_size).x
		var line_height: float = HEADER_FONT.get_height(line_font_size)
		var line_size := Vector2(line_width + 80.0, line_height + 38.0)
		var line_position := Vector2(float(row_next_x[row_index]), float(row_ys[row_index]))
		_layout_title_line(_title_shadow_lines, index, line_position, line_size, line_font_size)
		_layout_title_line(_title_rim_lines, index, line_position, line_size, line_font_size)
		_layout_title_line(_title_base_lines, index, line_position, line_size, line_font_size)
		_layout_title_line(_title_face_lines, index, line_position, line_size, line_font_size)
		if index < _title_face_materials.size():
			_title_face_materials[index].set_shader_parameter("gradient_height", line_size.y)
		row_next_x[row_index] = line_position.x + line_width + _title_word_gap(title_font_size)

func _layout_title_line(labels: Array[Label], index: int, position: Vector2, size: Vector2, font_size: int) -> void:
	if index >= labels.size():
		return
	var label: Label = labels[index]
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)

func _menu_column_height(button_height: float) -> float:
	var visible_buttons: int = 4
	return float(visible_buttons) * button_height + float(visible_buttons - 1) * float(MENU_SEPARATION)

func _fitted_title_font_size(max_width: float, max_height: float) -> int:
	var font_size: int = TITLE_BASE_SIZE
	while font_size > TITLE_MIN_SIZE:
		var text_width: float = _title_max_line_width(font_size)
		var text_height: float = _title_text_height(font_size)
		if text_width <= max_width and text_height <= max_height:
			return font_size
		font_size -= 2
	return TITLE_MIN_SIZE

func _title_max_line_width(font_size: int) -> float:
	var width: float = 0.0
	var row_next_x: Array = []
	for row_index: int in range(_title_row_count()):
		row_next_x.append(_title_row_offset_x(font_size, row_index))
	for index: int in range(TITLE_LINE_TEXTS.size()):
		var row_index: int = _title_line_row_index(index)
		var line_font_size: int = _title_line_font_size(font_size, index)
		var line := str(TITLE_LINE_TEXTS[index])
		var line_width: float = HEADER_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, line_font_size).x
		var line_x: float = float(row_next_x[row_index])
		width = maxf(width, line_x + line_width)
		row_next_x[row_index] = line_x + line_width + _title_word_gap(font_size)
	return width

func _title_text_height(font_size: int) -> float:
	var row_heights: Array = _title_row_heights(font_size)
	var height: float = 0.0
	for row_index: int in range(row_heights.size()):
		height += float(row_heights[row_index])
		if row_index < row_heights.size() - 1:
			height += float(TITLE_LINE_SPACING)
	return height

func _title_row_heights(font_size: int) -> Array:
	var row_heights: Array = []
	for row_index: int in range(_title_row_count()):
		row_heights.append(0.0)
	for index: int in range(TITLE_LINE_TEXTS.size()):
		var row_index: int = _title_line_row_index(index)
		var line_height: float = HEADER_FONT.get_height(_title_line_font_size(font_size, index))
		row_heights[row_index] = maxf(float(row_heights[row_index]), line_height)
	return row_heights

func _title_row_y_positions(font_size: int) -> Array:
	var row_heights: Array = _title_row_heights(font_size)
	var positions: Array = []
	var y: float = 0.0
	for row_index: int in range(row_heights.size()):
		positions.append(y)
		y += float(row_heights[row_index]) + float(TITLE_LINE_SPACING)
	return positions

func _title_line_font_size(base_font_size: int, index: int) -> int:
	var scale: float = float(TITLE_LINE_SCALE_FACTORS[index])
	var min_size: int = TITLE_SMALL_LINE_MIN_SIZE if index == 1 else TITLE_MIN_SIZE
	return maxi(min_size, int(round(float(base_font_size) * scale)))

func _title_line_row_index(index: int) -> int:
	return int(TITLE_LINE_ROW_INDICES[index])

func _title_row_count() -> int:
	return TITLE_ROW_OFFSET_FACTORS.size()

func _title_row_offset_x(base_font_size: int, row_index: int) -> float:
	return roundf(float(base_font_size) * float(TITLE_ROW_OFFSET_FACTORS[row_index]))

func _title_word_gap(base_font_size: int) -> float:
	return roundf(float(base_font_size) * TITLE_WORD_GAP_FACTOR)

func _bound_magick_count() -> int:
	var total: int = (_progression.get("card_upgrades", {}) as Dictionary).size()
	for mods_var: Variant in (_progression.get("card_mods", {}) as Dictionary).values():
		if typeof(mods_var) == TYPE_ARRAY:
			total += (mods_var as Array).size()
	return total

func _connect_steam_service() -> void:
	var steam_service: Node = _steam_service()
	if steam_service == null:
		return
	if steam_service.has_signal("profile_changed") and not steam_service.is_connected("profile_changed", Callable(self, "_on_steam_profile_changed")):
		steam_service.connect("profile_changed", Callable(self, "_on_steam_profile_changed"))
	if steam_service.has_signal("steam_status_changed") and not steam_service.is_connected("steam_status_changed", Callable(self, "_on_steam_status_changed")):
		steam_service.connect("steam_status_changed", Callable(self, "_on_steam_status_changed"))

func _profile_text() -> String:
	var steam_service: Node = _steam_service()
	if steam_service != null and steam_service.has_method("profile_label_text"):
		var label_text: String = str(steam_service.call("profile_label_text")).strip_edges()
		if not label_text.is_empty():
			return label_text
	return FALLBACK_PROFILE_TEXT

func _steam_service() -> Node:
	return get_node_or_null("/root/SteamService")

func _on_steam_profile_changed(_profile_name: String) -> void:
	embers_label.text = _profile_text()

func _on_steam_status_changed(_active: bool) -> void:
	embers_label.text = _profile_text()

func _play_menu_music() -> void:
	var entry: Dictionary = MusicLibrary.entry(MusicLibrary.RELIC_ROOM_TRACK_ID)
	var path: String = str(entry.get("path", ""))
	var stream: AudioStream = AssetLoader.load_audio_stream(path)
	if stream == null:
		return
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		_music_player.bus = SettingsStore.MUSIC_BUS
		add_child(_music_player)
		_music_player.finished.connect(_on_music_finished)
	_music_player.stream = stream
	_music_player.volume_db = float(entry.get("volume_db", -13.0))
	_music_player.play()

func _on_music_finished() -> void:
	if _music_player == null or _music_player.stream == null:
		return
	_music_player.play()

func _is_keyboard_navigation_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB]:
		return true
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(action):
			return true
	return false

func _menu_or_settings_has_focus() -> bool:
	for button_var: Variant in _focusable_menu_buttons():
		var button := button_var as Button
		if button != null and button.has_focus():
			return true
	return false

func _clear_menu_keyboard_focus() -> void:
	for button_var: Variant in _focusable_menu_buttons():
		var button := button_var as Button
		if button != null and button.has_focus():
			button.release_focus()

func _focus_default_keyboard_target() -> void:
	if settings_panel.visible:
		settings_back_button.grab_focus()
		return
	var target: Button = continue_button if not continue_button.disabled else start_button
	target.grab_focus()

func _focusable_menu_buttons() -> Array:
	return [continue_button, start_button, settings_button, quit_button, boss_button, settings_back_button]

func _on_start_button_pressed() -> void:
	_refresh_saved_run_preview()
	if not _saved_run_preview.is_empty():
		_replacement_confirmation_open = true
		_set_menu_actions_locked(true)
		_sync_context_panels()
		return
	_begin_new_game()

func _on_replacement_cancel_button_pressed() -> void:
	_replacement_confirmation_open = false
	_set_menu_actions_locked(false)
	_sync_context_panels()

func _on_replacement_confirm_button_pressed() -> void:
	_begin_new_game()

func _begin_new_game() -> void:
	var scene_tree: SceneTree = get_tree() if is_inside_tree() else null
	if scene_tree != null and scene_tree.root.has_meta("labyrinth_resume_saved_run"):
		scene_tree.root.remove_meta("labyrinth_resume_saved_run")
	if ProgressionStore.has_saved_run():
		_progression = ProgressionStore.set_embers(ProgressionStore.load_data(), 0)
		ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	_saved_run_preview = {}
	if scene_tree != null:
		scene_tree.change_scene_to_file("res://scenes/run_scene.tscn")

func _on_continue_button_pressed() -> void:
	_refresh_saved_run_preview()
	if continue_button.disabled:
		return
	get_tree().root.set_meta("labyrinth_resume_saved_run", true)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _on_settings_button_pressed() -> void:
	if settings_panel.has_method("open"):
		settings_panel.call("open")
	else:
		settings_panel.visible = true
	_sync_context_panels()
	if _using_keyboard_navigation:
		settings_back_button.grab_focus()
	else:
		_clear_menu_keyboard_focus()

func _on_settings_back_button_pressed() -> void:
	settings_panel.visible = false
	_sync_context_panels()
	if _using_keyboard_navigation:
		settings_button.grab_focus()
	else:
		_clear_menu_keyboard_focus()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_boss_button_pressed() -> void:
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	get_tree().root.set_meta("labyrinth_debug_boss_run", true)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
