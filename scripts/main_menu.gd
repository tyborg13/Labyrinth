extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const NewDescentPanel = preload("res://scripts/new_descent_panel.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunPersistence = preload("res://scripts/run_persistence.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const ControllerPromptBarScript = preload("res://scripts/controller_prompt_bar.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const MenuRunTransition = preload("res://scripts/menu_run_transition.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"
const CombatAtmosphere = preload("res://scripts/combat_atmosphere.gd")
const ChroniclePanel = preload("res://scripts/chronicle_panel.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoEndPanel = preload("res://scripts/demo_end_panel.gd")
const DemoLayout = preload("res://scripts/main_menu_demo_layout.gd")
const UiQuietLink = preload("res://scripts/ui_quiet_link.gd")
const TITLE_MOTE_COUNT: int = 42

const BACKGROUND_ART_PATH: String = preload("res://scripts/menu_title_assets.gd").BACKGROUND_ART_PATH
const DISPLAY_FONT = preload("res://fonts/LabyrinthCrumble-Display.tres")
const UI_FONT = preload("res://fonts/LabyrinthCrumble-UI.tres")
const TEXT_FONT = preload("res://fonts/LabyrinthCrumble-Text.tres")

const TITLE_LINE_TEXTS := ["ESCAPE", "THE", "UMBRA"]
const TITLE_LINE_ROW_INDICES := [0, 1, 1]
const TITLE_LINE_SCALE_FACTORS := [1.0, 0.52, 1.0]
const TITLE_ROW_OFFSET_FACTORS := [0.0, 0.72]
const TITLE_WORD_GAP_FACTOR: float = 0.10
const FALLBACK_PROFILE_TEXT: String = "Profile Reaver"
const TITLE_BASE_SIZE: int = 114
const TITLE_MIN_SIZE: int = 42
const TITLE_SMALL_LINE_MIN_SIZE: int = 28
const TITLE_LINE_SPACING: int = -8
const TITLE_LINE_VERTICAL_PADDING: float = 38.0
const TITLE_TO_MENU_EXTRA_GAP: float = 14.0
const MENU_FONT_SIZE: int = 34
const MENU_BUTTON_HEIGHT: float = 78.0
const MENU_BUTTON_HEIGHT_COMPACT: float = 64.0
const MENU_BUTTON_MIN_WIDTH: float = 380.0
const MENU_BUTTON_MAX_WIDTH: float = 470.0
const MENU_SEPARATION: int = 14
const UMBRA_SELECTION_META: String = "umbra_selected"
const CONTEXT_PANEL_MIN_WIDTH: float = 300.0
const CONTEXT_PANEL_MAX_WIDTH: float = 360.0
const CONTEXT_PANEL_GAP: float = 24.0
const SETTINGS_TITLE_CLEARANCE: float = 40.0
const RESUME_PANEL_HEIGHT: float = 124.0
const REPLACEMENT_PANEL_HEIGHT: float = 248.0
const EDGE_ACCENT := Color("d69b47")
const DANGER_ACCENT := Color("b94c3f")
const SAVED_RUN_MODE_LABELS := {
	"room": "EXPLORING",
	"pre_battle": "AT THE THRESHOLD",
	"combat": "IN COMBAT",
	"reward": "CHOOSING A REWARD",
	"campfire": "AT EMBER HEARTH",
	"treasure": "AT TREASURE",
	"graftwright": "AT GRAFTWRIGHT",
	"event": "EVENT",
	"escape": "REACH EXIT",
	"victory": "CHOOSING AN HEIRLOOM",
	"defeat": "CHOOSING AN HEIRLOOM"
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
uniform float gradient_offset = 0.0;
uniform float gradient_height = 1.0;
uniform float texture_strength = 0.12;

varying float local_y;
varying vec2 local_position;

float stone_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float stone_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float top = mix(stone_hash(cell), stone_hash(cell + vec2(1.0, 0.0)), blend.x);
	float bottom = mix(stone_hash(cell + vec2(0.0, 1.0)), stone_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(top, bottom, blend.y);
}

vec4 title_color_ramp(float position) {
	if (position <= 0.26) {
		return mix(top_color, high_color, clamp(position / 0.26, 0.0, 1.0));
	}
	if (position <= 0.56) {
		return mix(high_color, mid_color, clamp((position - 0.26) / 0.30, 0.0, 1.0));
	}
	if (position <= 0.80) {
		return mix(mid_color, low_color, clamp((position - 0.56) / 0.24, 0.0, 1.0));
	}
	return mix(low_color, bottom_color, clamp((position - 0.80) / 0.20, 0.0, 1.0));
}

void vertex() {
	local_y = VERTEX.y;
	local_position = VERTEX;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float y = clamp((gradient_offset + local_y) / max(gradient_height, 1.0), 0.0, 1.0);
	vec4 ramp = title_color_ramp(y);
	float fine_grain = stone_noise(local_position / 5.0);
	float broad_grain = stone_noise(local_position / 19.0 + vec2(19.0, 7.0));
	float fleck_noise = stone_noise(local_position / 3.6 + vec2(5.0, 13.0));
	float dark_fleck = smoothstep(0.82, 0.97, fleck_noise);
	float pale_fleck = smoothstep(0.86, 0.98, stone_noise(local_position / 5.0 + vec2(31.0, 11.0)));
	float stone_value = (broad_grain - 0.5) * 0.82 + (fine_grain - 0.5) * 0.30;
	stone_value -= dark_fleck * 0.20;
	stone_value += pale_fleck * 0.10;
	ramp.rgb = clamp(ramp.rgb * (1.0 + stone_value * texture_strength), vec3(0.0), vec3(1.0));
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

var chronicle_button: Button
var _chronicle: Control
var _progression: Dictionary = {}
var _new_descent_panel: Control
var _saved_run_preview: Dictionary = {}
var _saved_run_unavailable: bool = false
var _saved_seed: Variant
var _replacement_confirmation_open: bool = false
var _using_keyboard_navigation: bool = false
var _music_player: AudioStreamPlayer
var _title_motes: CPUParticles2D
var _ui_skin: UiSkin = UiSkin.new()
var settings_back_button: Button
var _title_shadow_lines: Array[Label]
var _title_rim_lines: Array[Label]
var _title_base_lines: Array[Label]
var _title_face_lines: Array[Label]
var _title_face_materials: Array[ShaderMaterial]
var _controller_prompt_bar
var _loading_run: bool = false
var _loading_error: AcceptDialog
var _umbra_primary_button: Button
var _umbra_normal_style: StyleBoxFlat
var _umbra_selected_style: StyleBoxFlat
var _demo_links: Array[Button]
var _settings_input_blocker: Control
var _settings_menu_input: Dictionary = {}
var _settings_menu_selection: Button
var _boot_preparing: bool
var _boot_step: int

func _ready() -> void:
	if _boot_preparing: return
	_apply_menu_settings()
	_build_menu()
	_connect_steam_service()
	_style_menu()
	_reload_progression(true)
	_update_layout()
	_activate_menu()

func stage_for_boot() -> void:
	_boot_preparing = true
	# The panel can build its hidden controls at attachment. Apply live
	# preferences when the menu takes over, as on the direct scene path.
	get_node("SettingsPanel").defer_initial_refresh()
	hide()

func prepare_next_boot_step() -> bool:
	var started := Time.get_ticks_usec()
	match _boot_step:
		0: _build_menu()
		1: _style_menu()
		2: _update_layout(true)
		_: return false
	_boot_step += 1
	AssetLoader.count_preparation_work(started)
	return true

func reveal_from_boot(settings: Dictionary) -> void:
	# An unusually slow load or reduced motion can exhaust the cover. The same
	# setup still completes before drawing, without waiting on prewarm jobs.
	while prepare_next_boot_step():
		pass
	_boot_preparing = false
	_refresh_boot_settings(settings)
	background_art.texture = AssetLoader.load_texture(BACKGROUND_ART_PATH)
	show()
	_install_title_motes()
	_connect_steam_service()
	_reload_progression(true)
	_update_layout()
	resized.connect(_update_layout)
	_activate_menu()

func prepare_boot_audio(present: Callable, active: Callable) -> void:
	var entry: Dictionary = MusicLibrary.entry(MusicLibrary.OLD_CASTLE_MENU_TRACK_ID)
	var paths := PackedStringArray([str(entry["path"])])
	AssetLoader.prepare_audio_for(get_tree().root, paths, present, active)

func _apply_menu_settings() -> void:
	var _trace := _boot_trace("settings")
	ParallelRuntime.apply_from_environment()
	SettingsStore.apply_settings(SettingsStore.load_settings(), get_window())

func _refresh_boot_settings(settings: Dictionary) -> void:
	var _trace := _boot_trace("settings")
	settings_panel.apply_saved_settings(settings)

func _build_menu() -> void:
	var _trace := _boot_trace("hidden_panels")
	chronicle_button = Button.new()
	chronicle_button.name = "ChronicleButton"
	chronicle_button.text = "Chronicle"
	menu_column.add_child(chronicle_button)
	menu_column.move_child(chronicle_button, settings_button.get_index())
	chronicle_button.pressed.connect(_on_chronicle_button_pressed)
	_chronicle = ChroniclePanel.new()
	_chronicle.name = "ChroniclePanel"
	add_child(_chronicle)
	_chronicle.closed.connect(_on_chronicle_closed)
	_build_demo_links()
	_chronicle.visibility_changed.connect(_on_chronicle_visibility_changed)
	_initialize_title_arrays()
	settings_back_button = settings_panel.call("back_button") as Button
	_settings_input_blocker = Control.new()
	_settings_input_blocker.name = "SettingsModalInputBlocker"
	_settings_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_input_blocker.visible = false
	add_child(_settings_input_blocker)
	_settings_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_settings_input_blocker, settings_panel.get_index())
	settings_panel.visibility_changed.connect(_sync_settings_modality)
	get_viewport().gui_focus_changed.connect(_keep_settings_focus)
	if settings_panel.has_signal("back_requested"):
		settings_panel.connect("back_requested", Callable(self, "_on_settings_back_button_pressed"))

func _style_menu() -> void:
	var _trace := _boot_trace("theme_and_controls")
	if not _boot_preparing: resized.connect(_update_layout)
	_apply_style()
	_build_controller_prompt_bar()

func _activate_menu() -> void:
	var _trace := _boot_trace("activation")
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null and router.call("using_controller"):
		_using_keyboard_navigation = true
		_umbra_primary_button.grab_focus()
	_play_menu_music()
	SceneLoads.watch_menu(self)

	preload("res://scripts/controller_gui_navigation.gd").install(self)

func _boot_trace(label: String) -> RefCounted:
	if not _hitch_trace_enabled: return null
	return get_node("/root/PerformanceTelemetry").hitch_phase("startup:menu:" + label)

func _input(event: InputEvent) -> void:
	if _boot_preparing: return
	if is_instance_valid(_new_descent_panel):
		if _new_descent_panel.handle_input(event): get_viewport().set_input_as_handled()
		return
	if _loading_run or (_chronicle != null and _chronicle.visible):
		return
	if InputRouterScript.is_controller_event(event):
		_using_keyboard_navigation = true
		# B must still reach _unhandled_input's Back handler after pointer input
		# left nothing focused (Settings would otherwise need two presses).
		var back: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputRouterScript.ACTION_CANCEL)
		if not back and not _menu_or_settings_has_focus():
			_focus_default_keyboard_target()
			get_viewport().set_input_as_handled()
		_refresh_controller_prompts()
	elif _is_keyboard_navigation_event(event):
		# Native Control focus navigation can consume arrow keys before
		# _unhandled_input, so claim keyboard ownership in the early input pass.
		_using_keyboard_navigation = true
		if not _menu_or_settings_has_focus():
			_focus_default_keyboard_target()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		# Empty-space pointer motion must not steal keyboard/controller focus.
		# Pointer ownership begins only when the cursor enters an enabled action.
		pass
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if settings_panel.visible and not settings_panel.contains_pointer_position(mouse_button.position):
			return
		_using_keyboard_navigation = false
		# Releasing focus on mouse-down can cancel Button's press/release click path.
		if not mouse_button.pressed:
			call_deferred("_clear_menu_keyboard_focus")

func _unhandled_input(event: InputEvent) -> void:
	if _boot_preparing: return
	if is_instance_valid(_new_descent_panel): return
	if _loading_run or (_chronicle != null and _chronicle.visible):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputRouterScript.ACTION_CANCEL):
		if _replacement_confirmation_open:
			_on_replacement_cancel_button_pressed()
			get_viewport().set_input_as_handled()
			return
		if settings_panel.visible:
			_on_settings_back_button_pressed()
			get_viewport().set_input_as_handled()
			return
	if not _is_keyboard_navigation_event(event):
		return
	_using_keyboard_navigation = true
	if _menu_or_settings_has_focus():
		return
	_focus_default_keyboard_target()
	get_viewport().set_input_as_handled()

func _build_controller_prompt_bar() -> void:
	if _controller_prompt_bar != null:
		return
	_controller_prompt_bar = ControllerPromptBarScript.new()
	_controller_prompt_bar.name = "ControllerPromptBar"
	_controller_prompt_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_controller_prompt_bar.anchor_left = 1.0
	_controller_prompt_bar.anchor_top = 1.0
	_controller_prompt_bar.anchor_right = 1.0
	_controller_prompt_bar.anchor_bottom = 1.0
	_controller_prompt_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_controller_prompt_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_controller_prompt_bar.offset_left = -24.0
	_controller_prompt_bar.offset_top = -20.0
	_controller_prompt_bar.offset_right = -24.0
	_controller_prompt_bar.offset_bottom = -20.0
	add_child(_controller_prompt_bar)
	_refresh_controller_prompts()

func _refresh_controller_prompts() -> void:
	if _controller_prompt_bar == null:
		return
	var prompts: Array = [
		{"action": InputRouterScript.ACTION_ACCEPT, "label": "Select"},
	]
	if is_instance_valid(_new_descent_panel):
		var depth_action: StringName = _new_descent_panel.depth_prompt_action()
		if not depth_action.is_empty():
			prompts.append({"action": depth_action, "label": "Umbra Depth"})
		prompts.append({"action": InputRouterScript.ACTION_CANCEL, "label": "Back"})
	else:
		prompts.append({"action": &"controller_dpad", "label": "Navigate"})
		if settings_panel.visible or _replacement_confirmation_open:
			prompts.append({"action": InputRouterScript.ACTION_CANCEL, "label": "Back"})
	_controller_prompt_bar.set_prompts(prompts)

func _apply_style() -> void:
	if not _boot_preparing: background_art.texture = AssetLoader.load_texture(BACKGROUND_ART_PATH)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	global_scrim.color = Color(0.0, 0.0, 0.0, 0.16)
	left_scrim.visible = false
	if not _boot_preparing: _install_title_motes()

	_configure_title_container(title_shadow_label)
	_configure_title_container(title_rim_label)
	_configure_title_container(title_label)
	_configure_title_container(title_face_blend)
	_ensure_title_line_labels()
	_apply_title_layer_style(_title_shadow_lines, Color("5b2d74"), Color("0b040f"), 9, Color(1.0, 0.78, 1.0, 0.78))
	_apply_title_layer_style(_title_rim_lines, Color("c0522f"), Color("170508"), 6, Color(1.0, 0.78, 0.56, 0.88))
	_apply_title_layer_style(_title_base_lines, Color("ffd98d"), Color("210725"), 5, Color.WHITE)
	_apply_title_layer_style(_title_face_lines, Color.WHITE, Color.TRANSPARENT, 0, Color.WHITE)

	menu_column.add_theme_constant_override("separation", MENU_SEPARATION)
	_umbra_normal_style = _ui_skin.make_button_style(UiSkin.VARIANT_UMBRA, UiSkin.STATE_NORMAL)
	_umbra_selected_style = _ui_skin.make_button_style(UiSkin.VARIANT_UMBRA, UiSkin.STATE_SELECTED)
	for button: Button in [continue_button, start_button, chronicle_button, settings_button, quit_button, boss_button]:
		_apply_menu_button_style(button)
	_connect_umbra_selection_signals()
	_apply_confirmation_button_style(replacement_cancel_button, false)
	_apply_confirmation_button_style(replacement_confirm_button, true)
	boss_button.visible = false

	resume_panel.add_theme_stylebox_override("panel", _make_context_panel_style(EDGE_ACCENT, 0.90))
	_apply_label_style($ResumePanel/ResumeMargin/ResumeVBox/ResumeEyebrow, TEXT_FONT, 14, Color("c9a86c"), Color("100908"), 2)
	_apply_label_style(resume_location_label, UI_FONT, 23, Color("fff0c4"), Color("100908"), 3)
	_apply_label_style(resume_stats_label, TEXT_FONT, 17, Color("e7d7ba"), Color("100908"), 2)

	_apply_label_style(embers_label, UI_FONT, 22, Color("f6d99f"), Color("100908"), 3)
	_apply_label_style(footer_label, TEXT_FONT, 15, Color("dbc59b"), Color("100908"), 2)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	replacement_panel.add_theme_stylebox_override("panel", _make_context_panel_style(DANGER_ACCENT, 0.94))
	_apply_label_style($ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementTitle, UI_FONT, 27, Color("fff1cf"), Color("090708"), 4)
	_apply_label_style($ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementWarning, TEXT_FONT, 15, Color("d9b8a4"), Color("090708"), 2)
	_apply_label_style(replacement_location_label, UI_FONT, 20, Color("ffe2b0"), Color("090708"), 3)
	_apply_label_style(replacement_stats_label, TEXT_FONT, 16, Color("e7d7ba"), Color("090708"), 2)

# Slow embers drifting up through the key art keep the title screen alive.
# They sit above the art and scrim but below every title and menu control.
func _install_title_motes() -> void:
	if _title_motes != null:
		return
	_title_motes = CombatAtmosphere.build_motes(TITLE_MOTE_COUNT)
	_title_motes.name = "TitleMotes"
	add_child(_title_motes)
	move_child(_title_motes, global_scrim.get_index() + 1)
	_layout_title_motes()
	_apply_title_motes_motion(SettingsStore.applied_reduced_motion_enabled())
	if settings_panel != null and settings_panel.has_signal("settings_changed"):
		var on_changed := Callable(self, "_on_title_settings_changed")
		if not settings_panel.is_connected("settings_changed", on_changed):
			settings_panel.connect("settings_changed", on_changed)

func _on_title_settings_changed(settings: Dictionary) -> void:
	_apply_title_motes_motion(SettingsStore.reduced_motion_enabled(settings))

func _apply_title_motes_motion(reduced: bool) -> void:
	if _title_motes == null:
		return
	_title_motes.emitting = not reduced
	_title_motes.visible = not reduced

func _layout_title_motes() -> void:
	if _title_motes == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	_title_motes.position = Vector2(viewport_size.x * 0.58, viewport_size.y * 0.78)
	_title_motes.emission_rect_extents = Vector2(viewport_size.x * 0.44, viewport_size.y * 0.24)

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
	label.add_theme_font_override("font", DISPLAY_FONT)
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
	material.set_shader_parameter("texture_strength", 0.12)
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
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_UMBRA)
	_ui_skin.apply_button_text_overrides(button, Color("f3e5c5"), Color("080606"), Color("8d806b"), 5)
	button.add_theme_color_override("font_hover_color", Color("f3e5c5"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _apply_confirmation_button_style(button: Button, destructive: bool) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 20)
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_LARGE)
	_ui_skin.apply_button_text_overrides(button, Color("f3e5c5"), Color("080606"), Color("8d806b"), 5)
	if not destructive:
		return
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_DESTRUCTIVE)
	_ui_skin.apply_button_text_overrides(button, Color("ffe2d6"), Color("120507"), Color("8d6d68"), 4)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER

func _apply_continue_button_state(primary: bool) -> void:
	_umbra_primary_button = continue_button if primary else start_button
	_restore_umbra_selection()

func _connect_umbra_selection_signals() -> void:
	for button: Button in _umbra_menu_buttons():
		var pointer_highlighted := Callable(self, "_on_umbra_button_pointer_highlighted").bind(button)
		var highlighted := Callable(self, "_on_umbra_button_highlighted").bind(button)
		var departed := Callable(self, "_on_umbra_button_departed")
		if not button.mouse_entered.is_connected(pointer_highlighted):
			button.mouse_entered.connect(pointer_highlighted)
		if not button.focus_entered.is_connected(highlighted):
			button.focus_entered.connect(highlighted)
		if not button.button_down.is_connected(highlighted):
			button.button_down.connect(highlighted)
		if not button.mouse_exited.is_connected(departed):
			button.mouse_exited.connect(departed)
		if not button.focus_exited.is_connected(departed):
			button.focus_exited.connect(departed)
		if not button.button_up.is_connected(departed):
			button.button_up.connect(departed)

func _umbra_menu_buttons() -> Array[Button]:
	var buttons: Array[Button]
	buttons.append(continue_button)
	buttons.append(start_button)
	buttons.append(chronicle_button)
	buttons.append(settings_button)
	buttons.append(quit_button)
	buttons.append(boss_button)
	return buttons

func _on_umbra_button_pointer_highlighted(button: Button) -> void:
	if button == null or button.disabled or not button.visible:
		_restore_umbra_selection()
		return
	_using_keyboard_navigation = false
	# Clear stale navigation focus before a later mouse-down can begin, but only
	# after the pointer reaches a real action. Clearing on arbitrary motion made
	# an idle cursor reset sequential navigation back to Continue Run.
	if Input.get_mouse_button_mask() == 0:
		_clear_menu_keyboard_focus()
	_on_umbra_button_highlighted(button)

func _on_umbra_button_highlighted(button: Button) -> void:
	if button == null or button.disabled or not button.visible:
		_restore_umbra_selection()
		return
	_set_umbra_selected_button(button)

func _on_umbra_button_departed() -> void:
	call_deferred("_restore_umbra_selection")

func _restore_umbra_selection() -> void:
	if settings_panel.visible:
		_set_umbra_selected_button(null)
		return
	# Explicit activation and navigation focus outrank a stale pointer hover.
	# Keep these as full passes so menu order cannot let an earlier hovered
	# action override a later focused action during deferred restoration.
	for button: Button in _umbra_menu_buttons():
		if button.visible and not button.disabled and button.is_pressed():
			_set_umbra_selected_button(button)
			return
	for button: Button in _umbra_menu_buttons():
		if button.visible and not button.disabled and button.has_focus():
			_set_umbra_selected_button(button)
			return
	for button: Button in _umbra_menu_buttons():
		if button.visible and not button.disabled and button.is_hovered():
			_set_umbra_selected_button(button)
			return
	# Keep the last valid choice through pointer gaps and empty-space motion.
	# The primary action is only the initial/fallback selection, not a magnet.
	for button: Button in _umbra_menu_buttons():
		if bool(button.get_meta(UMBRA_SELECTION_META, false)) and button.visible and not button.disabled:
			_set_umbra_selected_button(button)
			return
	var target: Button = _umbra_primary_button
	if target == null or target.disabled or not target.visible:
		target = null
	_set_umbra_selected_button(target)

func _set_umbra_selected_button(selected_button: Button) -> void:
	for button: Button in _umbra_menu_buttons():
		var selected: bool = button == selected_button and not button.disabled and button.visible
		button.set_meta(UMBRA_SELECTION_META, selected)
		button.add_theme_stylebox_override(
			"normal",
			_umbra_selected_style if selected else _umbra_normal_style
		)
		button.queue_redraw()
		var ornament: Control = button.get_node_or_null(UiSkin.BUTTON_ORNAMENT_NAME) as Control
		if ornament != null:
			ornament.queue_redraw()

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

func _reload_progression(replay_closing_receipts: bool = false) -> void:
	var _trace := _boot_trace("profile_and_checkpoint")
	_progression = ProgressionStore.load_data()
	_refresh_saved_run_preview(replay_closing_receipts)
	embers_label.text = _profile_text()
	footer_label.text = "LV %d · EMBERS %d · SKILLS %d/%d" % [
		int(_progression.get("level", 1)),
		int(_progression.get("embers", 0)),
		ProgressionStore.selected_skill_ids(_progression).size(),
		ProgressionStore.skill_points_for_level(999)
	]

func _refresh_saved_run_preview(replay_closing_receipts: bool = false) -> void:
	var checkpoint: Dictionary = ProgressionStore.read_resumable_checkpoint()
	var saved_run: Dictionary = checkpoint.get("state", {})
	if replay_closing_receipts:
		var receipt_source: Dictionary = saved_run
		if checkpoint["status"] == ProgressionStore.RunFile.TERMINAL:
			receipt_source = ProgressionStore.read_resumable_checkpoint(false, true).get("state", {})
		RunPersistence.replay_run_closing_receipts(_progression, receipt_source)
	_saved_run_preview = _build_saved_run_preview(saved_run, checkpoint.get("summary", {}))
	_saved_seed = saved_run.get("seed")
	_saved_run_unavailable = checkpoint["status"] == ProgressionStore.RunFile.UNAVAILABLE
	var can_continue: bool = _saved_run_unavailable or not _saved_run_preview.is_empty()
	if _saved_run_preview.is_empty():
		_replacement_confirmation_open = false
	continue_button.text = "Continue Run" if can_continue else "Continue"
	_set_menu_actions_locked(_replacement_confirmation_open)
	_apply_continue_button_state(can_continue)
	_apply_preview_text(_saved_run_preview)
	_sync_context_panels()

func _build_saved_run_preview(run_state: Dictionary, summary: Dictionary = {}) -> Dictionary:
	if summary.is_empty(): summary = RunPersistence.validated_resume_summary(run_state)
	if summary.is_empty(): return {}
	var depth: int = _saved_room_depth(run_state, summary["coord"])
	return {
		"location": "DEPTH %d · %s" % [depth, str(SAVED_RUN_MODE_LABELS[summary["mode"]])],
		"stats": "HEALTH %d/%d · HELD %d EMBERS" % [summary["hp"], summary["max_hp"], summary["embers"]]
	}

func _saved_room_depth(run_state: Dictionary, coord: Vector2i) -> int:
	var fallback: int = maxi(absi(coord.x), absi(coord.y))
	var rooms_value: Variant = run_state.get("rooms", {})
	if typeof(rooms_value) != TYPE_DICTIONARY:
		return fallback
	var room_value: Variant = (rooms_value as Dictionary).get("%d,%d" % [coord.x, coord.y], {})
	if typeof(room_value) != TYPE_DICTIONARY:
		return fallback
	var depth_value: Variant = (room_value as Dictionary).get("depth", fallback)
	return maxi(0, int(depth_value)) if typeof(depth_value) in [TYPE_INT, TYPE_FLOAT] else fallback

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
	continue_button.disabled = locked or (_saved_run_preview.is_empty() and not _saved_run_unavailable)
	start_button.disabled = locked
	settings_button.disabled = locked
	quit_button.disabled = locked
	boss_button.disabled = locked
	call_deferred("_restore_umbra_selection")
	_sync_demo_links_visibility()

func _update_layout(title_only: bool = false) -> void:
	var _trace := _boot_trace("layout_and_text_measurement")
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_layout_title_motes()
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
	title_shadow_label.position = title_label.position + Vector2(8.0, 7.0)
	title_rim_label.position = title_label.position + Vector2(3.0, 2.0)
	title_label.size = title_size
	title_shadow_label.size = title_size
	title_rim_label.size = title_size
	title_face_blend.position = title_label.position
	title_face_blend.size = title_size
	_layout_title_lines(title_font_size)
	# Only title geometry is needed to warm its glyph sizes. Let the full
	# layout set the other controls' initial minimums at the final viewport.
	if title_only: return

	var menu_y: float = title_y + title_size.y + clampf(viewport_size.y * 0.028, 20.0, 42.0) + TITLE_TO_MENU_EXTRA_GAP
	menu_column.position = Vector2(margin_x, menu_y)
	menu_column.size = Vector2(menu_width, _menu_column_height(button_height))
	for button: Button in [continue_button, start_button, chronicle_button, settings_button, quit_button, boss_button]:
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
	profile_block.visible = not _chronicle.visible and profile_y > menu_y + _menu_column_height(button_height) + 16.0
	call_deferred("_layout_demo_links")
	profile_block.position = Vector2(margin_x, profile_y)
	profile_block.size = Vector2(profile_width, profile_height)

	left_scrim.position = Vector2.ZERO
	left_scrim.size = Vector2.ZERO

	# Settings stands at the right margin, clear of the title, so the game's name stays whole.
	var title_right: float = margin_x + _title_max_line_width(title_font_size) + SETTINGS_TITLE_CLEARANCE
	var panel_width: float = clampf(viewport_size.x - margin_x - title_right, settings_panel.get_combined_minimum_size().x, 900.0)
	var panel_height: float = minf(SettingsPanel.PANEL_MINIMUM_SIZE.y, viewport_size.y - 48.0)
	var panel_x: float = maxf(24.0, viewport_size.x - margin_x - panel_width)
	var panel_y: float = maxf(24.0, (viewport_size.y - panel_height) * 0.5)
	settings_panel.position = Vector2(panel_x, panel_y)
	settings_panel.size = Vector2(panel_width, panel_height)
	if _controller_prompt_bar != null:
		var prompt_bottom: float = clampf(viewport_size.y * 0.032, 20.0, 34.0)
		_controller_prompt_bar.offset_left = -margin_x
		_controller_prompt_bar.offset_top = -prompt_bottom
		_controller_prompt_bar.offset_right = -margin_x
		_controller_prompt_bar.offset_bottom = -prompt_bottom

func _layout_title_lines(title_font_size: int) -> void:
	_ensure_title_line_labels()
	var row_ys: Array = _title_row_y_positions(title_font_size)
	var shared_gradient_height: float = _title_text_height(title_font_size) + TITLE_LINE_VERTICAL_PADDING
	var row_next_x: Array = []
	for row_index: int in range(_title_row_count()):
		row_next_x.append(_title_row_offset_x(title_font_size, row_index))
	for index: int in range(TITLE_LINE_TEXTS.size()):
		var row_index: int = _title_line_row_index(index)
		var line_font_size: int = _title_line_font_size(title_font_size, index)
		var line_text := str(TITLE_LINE_TEXTS[index])
		var line_width: float = DISPLAY_FONT.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, line_font_size).x
		var line_height: float = DISPLAY_FONT.get_height(line_font_size)
		var line_size := Vector2(line_width + 80.0, line_height + TITLE_LINE_VERTICAL_PADDING)
		var line_position := Vector2(float(row_next_x[row_index]), float(row_ys[row_index]))
		_layout_title_line(_title_shadow_lines, index, line_position, line_size, line_font_size)
		_layout_title_line(_title_rim_lines, index, line_position, line_size, line_font_size)
		_layout_title_line(_title_base_lines, index, line_position, line_size, line_font_size)
		_layout_title_line(_title_face_lines, index, line_position, line_size, line_font_size)
		if index < _title_face_materials.size():
			_title_face_materials[index].set_shader_parameter("gradient_offset", line_position.y)
			_title_face_materials[index].set_shader_parameter("gradient_height", shared_gradient_height)
		row_next_x[row_index] = line_position.x + line_width + _title_word_gap(title_font_size)

func _layout_title_line(labels: Array[Label], index: int, position: Vector2, size: Vector2, font_size: int) -> void:
	if index >= labels.size():
		return
	var label: Label = labels[index]
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)

func _menu_column_height(button_height: float) -> float:
	var visible_buttons: int = 5
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
		var line_width: float = DISPLAY_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, line_font_size).x
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
		var line_height: float = DISPLAY_FONT.get_height(_title_line_font_size(font_size, index))
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
	var _trace := _boot_trace("audio_player")
	var entry: Dictionary = MusicLibrary.entry(MusicLibrary.OLD_CASTLE_MENU_TRACK_ID)
	var path: String = str(entry.get("path", ""))
	var stream: AudioStream = AssetLoader.load_audio_stream(path, bool(entry.get("loop", false)))
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
	if InputRouterScript.is_controller_event(event):
		if event is InputEventJoypadButton:
			return (event as InputEventJoypadButton).pressed
		return absf((event as InputEventJoypadMotion).axis_value) >= InputRouterScript.JOYSTICK_ACTIVITY_THRESHOLD
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
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if settings_panel.visible:
		return focus_owner != null and (focus_owner == settings_panel or settings_panel.is_ancestor_of(focus_owner))
	return focus_owner != null and (is_ancestor_of(focus_owner) or settings_panel == focus_owner or settings_panel.is_ancestor_of(focus_owner))

func _clear_menu_keyboard_focus() -> void:
	for button_var: Variant in _focusable_menu_buttons():
		var button := button_var as Button
		if button != null and button.has_focus():
			button.release_focus()

func _focus_default_keyboard_target() -> void:
	if settings_panel.visible:
		settings_back_button.grab_focus()
		return
	var target: Button
	for button: Button in _umbra_menu_buttons():
		if bool(button.get_meta(UMBRA_SELECTION_META, false)) and button.visible and not button.disabled:
			target = button
			break
	if target == null:
		target = continue_button if not continue_button.disabled else start_button
	target.grab_focus()

func _focusable_menu_buttons() -> Array:
	return [continue_button, start_button, chronicle_button, settings_button, quit_button, boss_button, settings_back_button] + _demo_links

func _on_start_button_pressed() -> void:
	var _hitch_span: RefCounted
	if _hitch_trace_enabled:
		_hitch_span = get_node("/root/PerformanceTelemetry").hitch_phase("input:main_menu:new_run")
	if _loading_run:
		return
	_refresh_saved_run_preview()
	if _saved_run_unavailable:
		_on_run_loading_failed()
		return
	if not _saved_run_preview.is_empty():
		_replacement_confirmation_open = true
		_set_menu_actions_locked(true)
		_sync_context_panels()
		_refresh_controller_prompts()
		if _using_keyboard_navigation:
			replacement_cancel_button.grab_focus()
		return
	_begin_new_game()

func _on_replacement_cancel_button_pressed() -> void:
	if _loading_run:
		return
	_replacement_confirmation_open = false
	_set_menu_actions_locked(false)
	_sync_context_panels()
	_refresh_controller_prompts()
	if _using_keyboard_navigation:
		start_button.grab_focus()

func _on_replacement_confirm_button_pressed() -> void:
	if _loading_run:
		return
	_begin_new_game()

func _begin_new_game() -> void:
	if ProgressionStore.unlocked_umbra_depth(_progression) > 0:
		_open_new_descent()
		return
	_change_scene_to_file("res://scenes/run_scene.tscn", _prepare_new_game)

func _open_new_descent() -> void:
	if is_instance_valid(_new_descent_panel): return
	_replacement_confirmation_open = false
	_sync_context_panels()
	_set_menu_actions_locked(true)
	_new_descent_panel = NewDescentPanel.new()
	_new_descent_panel.configure(_progression, ProgressionStore.session_umbra_depth(_progression))
	_new_descent_panel.begin_requested.connect(_on_depth_begin)
	_new_descent_panel.back_requested.connect(_close_new_descent)
	_new_descent_panel.depth_changed.connect(_remember_umbra_depth)
	add_child(_new_descent_panel)
	_sync_demo_links_visibility()
	_new_descent_panel.focus_begin()
	_refresh_controller_prompts()

func _remember_umbra_depth(depth: int) -> void:
	_progression = ProgressionStore.remember_umbra_depth(ProgressionStore.load_data(), depth)
	_refresh_controller_prompts()

func _on_depth_begin(depth: int) -> void:
	_remember_umbra_depth(depth)
	_close_new_descent()
	_change_scene_to_file("res://scenes/run_scene.tscn", _prepare_new_game)

func _close_new_descent() -> void:
	if is_instance_valid(_new_descent_panel):
		remove_child(_new_descent_panel)
		_new_descent_panel.queue_free()
	_new_descent_panel = null
	_set_menu_actions_locked(false)
	_refresh_controller_prompts()
	if _using_keyboard_navigation: start_button.grab_focus()

func _prepare_new_game() -> void:
	var scene_tree: SceneTree = get_tree() if is_inside_tree() else null
	if scene_tree != null and scene_tree.root.has_meta("labyrinth_resume_saved_run"):
		scene_tree.root.remove_meta("labyrinth_resume_saved_run")
	# RunScene writes the replacement before consuming gifts or removing the old
	# save. Keeping it here also preserves recovery when the new save fails.
	_saved_run_preview = {}

func _on_continue_button_pressed() -> void:
	if _loading_run or continue_button.disabled:
		return
	_change_scene_to_file("res://scenes/run_scene.tscn", _prepare_continue)

func _prepare_continue() -> void:
	get_tree().root.set_meta("labyrinth_resume_saved_run", true)

func _on_chronicle_button_pressed() -> void:
	if _loading_run:
		return
	_chronicle.open()
	menu_column.visible = false
	_sync_demo_links_visibility()
	resume_panel.visible = false
	if _controller_prompt_bar != null:
		_controller_prompt_bar.modulate.a = 0

func _on_chronicle_closed() -> void:
	menu_column.visible = true
	_sync_demo_links_visibility()
	_sync_context_panels()
	if _controller_prompt_bar != null:
		_controller_prompt_bar.modulate.a = 1
	_using_keyboard_navigation = true
	chronicle_button.grab_focus()

func _sync_settings_modality() -> void:
	# Block the backdrop without changing the menu's enabled/disabled artwork.
	_settings_input_blocker.visible = settings_panel.visible
	if settings_panel.visible:
		for button: Button in _umbra_menu_buttons():
			if _settings_menu_input.has(button): continue
			_settings_menu_input[button] = {"mouse_filter": button.mouse_filter, "focus_mode": button.focus_mode}
			if bool(button.get_meta(UMBRA_SELECTION_META, false)): _settings_menu_selection = button
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.focus_mode = Control.FOCUS_NONE
		_set_umbra_selected_button(null)
	else:
		for button: Button in _settings_menu_input:
			if not is_instance_valid(button): continue
			button.mouse_filter = int(_settings_menu_input[button]["mouse_filter"])
			button.focus_mode = int(_settings_menu_input[button]["focus_mode"])
		_settings_menu_input.clear()
		if is_instance_valid(_settings_menu_selection): _set_umbra_selected_button(_settings_menu_selection)
		_settings_menu_selection = null
		call_deferred("_restore_umbra_selection")

func _keep_settings_focus(control: Control) -> void:
	if settings_panel.visible and control != null and control != settings_panel and not settings_panel.is_ancestor_of(control):
		settings_back_button.grab_focus()

func _on_chronicle_visibility_changed() -> void:
	# The panel's existing ScreenCrossfade covers this same-frame heading swap.
	for control: Control in [title_label, title_shadow_label, title_rim_label, title_face_blend]:
		control.visible = not _chronicle.visible
	_update_layout()

func _on_settings_button_pressed() -> void:
	if _loading_run:
		return
	if settings_panel.has_method("open"):
		settings_panel.call("open")
	else:
		settings_panel.visible = true
	_sync_context_panels()
	_refresh_controller_prompts()
	_sync_demo_links_visibility()
	if _using_keyboard_navigation:
		settings_back_button.grab_focus()
	else:
		_clear_menu_keyboard_focus()

func _on_settings_back_button_pressed() -> void:
	if _loading_run:
		return
	settings_panel.visible = false
	_sync_demo_links_visibility()
	_sync_context_panels()
	_refresh_controller_prompts()
	if _using_keyboard_navigation:
		settings_button.grab_focus()
	else:
		_clear_menu_keyboard_focus()

func _on_quit_button_pressed() -> void:
	if _loading_run:
		return
	_loading_run = true
	preload("res://scripts/application_shutdown.gd").request(get_tree(), "title_quit")

func cancel_loading_for_quit() -> void:
	_loading_run = true

func _on_boss_button_pressed() -> void:
	if _loading_run:
		return
	_change_scene_to_file("res://scenes/run_scene.tscn", _prepare_boss_run)

func _prepare_boss_run() -> void:
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	get_tree().root.set_meta("labyrinth_debug_boss_run", true)

func _change_scene_to_file(path: String, prepare_run: Callable = Callable()) -> void:
	if _loading_run or not is_inside_tree():
		return
	_loading_run = true
	_replacement_confirmation_open = false
	_sync_context_panels()
	_set_menu_actions_locked(true)
	replacement_confirm_button.disabled = true
	replacement_cancel_button.disabled = true
	_clear_menu_keyboard_focus()
	if _controller_prompt_bar != null:
		_controller_prompt_bar.modulate.a = 0.0
	var transition := MenuRunTransition.new()
	transition.failed.connect(_on_run_loading_failed)
	var new_run_depth: int = ProgressionStore.session_umbra_depth(_progression) if prepare_run == _prepare_new_game else -1
	transition.begin(self, path, prepare_run, new_run_depth, _saved_seed)

func _on_run_loading_failed() -> void:
	if _controller_prompt_bar != null:
		_controller_prompt_bar.modulate.a = 1.0
	_loading_run = false
	replacement_confirm_button.disabled = false
	replacement_cancel_button.disabled = false
	_reload_progression()
	_refresh_controller_prompts()
	if _loading_error == null:
		_loading_error = AcceptDialog.new()
		_loading_error.title = "Unable to enter"
		_loading_error.dialog_text = "The Labyrinth could not be loaded.\nPlease try again."
		_apply_label_style(_loading_error.get_label(), UI_FONT, 24, Color("f4dfb0"), Color("170e16"), 2)
		_apply_confirmation_button_style(_loading_error.get_ok_button(), false)
		_loading_error.confirmed.connect(_restore_menu_focus_after_loading_error)
		_loading_error.canceled.connect(_restore_menu_focus_after_loading_error)
		add_child(_loading_error)
	_loading_error.popup_centered()

func _restore_menu_focus_after_loading_error() -> void:
	if _using_keyboard_navigation:
		_focus_default_keyboard_target()

func _build_demo_links() -> void:
	if not DemoBuild.is_demo():
		return
	for action: String in ["wishlist", "discord"]:
		var link := DemoEndPanel.make_link(action)
		add_child(link)
		_demo_links.append(link)
	profile_block.visibility_changed.connect(_sync_demo_links_visibility)
	quit_button.resized.connect(_layout_demo_links)
	quit_button.item_rect_changed.connect(_layout_demo_links)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(_demo_links[0])
	for index: int in range(_demo_links.size()):
		var link: Button = _demo_links[index]
		link.focus_neighbor_top = link.get_path_to(quit_button if index == 0 else _demo_links[0])
		link.focus_neighbor_bottom = link.get_path_to(_demo_links[1])
		link.focus_neighbor_left = link.get_path_to(link)
		link.focus_neighbor_right = link.get_path_to(link)

func _layout_demo_links() -> void:
	if _demo_links.is_empty():
		return
	var link_origin := Vector2(menu_column.global_position.x + DemoLayout.LINK_OFFSET.x, quit_button.get_global_rect().end.y + DemoLayout.LINK_OFFSET.y)
	if profile_block.visible:
		var last_link_y: float = link_origin.y + float(_demo_links.size() - 1) * DemoLayout.LINK_SEPARATION
		var title_bottom: float = title_label.global_position.y + _title_text_height(title_label.get_theme_font_size("font_size"))
		var shift: float = DemoLayout.upward_shift(_demo_links.back(), last_link_y, embers_label.global_position.y, menu_column.global_position.y, title_bottom)
		menu_column.position.y -= shift
		link_origin.y -= shift
	for index: int in range(_demo_links.size()):
		_demo_links[index].global_position = link_origin + Vector2(0.0, float(index) * DemoLayout.LINK_SEPARATION)
	_sync_demo_links_visibility()

func _sync_demo_links_visibility() -> void:
	for link: Button in _demo_links:
		link.visible = profile_block.visible and menu_column.visible and not settings_panel.visible and not _replacement_confirmation_open and not _loading_run and not is_instance_valid(_new_descent_panel)
