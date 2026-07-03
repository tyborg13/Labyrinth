extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const BACKGROUND_ART_PATH: String = "res://assets/art/ui/main_menu_umbra_dragon.png"
const HEADER_FONT = preload("res://fonts/LabyrinthCrumble-Header.tres")
const REGULAR_FONT = preload("res://fonts/LabyrinthCrumble-Regular.tres")

const TITLE_TEXT: String = "Escape the Umbra"
const PROFILE_TEXT: String = "Profile: Reaver"
const TITLE_BASE_SIZE: int = 106
const TITLE_MIN_SIZE: int = 42
const MENU_FONT_SIZE: int = 28
const MENU_BUTTON_HEIGHT: float = 64.0
const MENU_BUTTON_HEIGHT_COMPACT: float = 54.0
const MENU_BUTTON_MIN_WIDTH: float = 332.0
const MENU_BUTTON_MAX_WIDTH: float = 420.0
const MENU_SEPARATION: int = 10
const EDGE_ACCENT := Color("d69b47")

@onready var background_art: TextureRect = $MenuArt
@onready var global_scrim: ColorRect = $GlobalScrim
@onready var left_scrim: ColorRect = $LeftScrim
@onready var title_shadow_label: Label = $TitleShadow
@onready var title_label: Label = $Title
@onready var menu_column: VBoxContainer = $MenuColumn
@onready var continue_button: Button = $MenuColumn/ContinueButton
@onready var start_button: Button = $MenuColumn/StartButton
@onready var settings_button: Button = $MenuColumn/SettingsButton
@onready var quit_button: Button = $MenuColumn/QuitButton
@onready var boss_button: Button = $MenuColumn/BossButton
@onready var profile_block: VBoxContainer = $ProfileBlock
@onready var embers_label: Label = $ProfileBlock/Embers
@onready var footer_label: Label = $ProfileBlock/Footer
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_title_label: Label = $SettingsPanel/SettingsMargin/SettingsVBox/SettingsTitle
@onready var settings_back_button: Button = $SettingsPanel/SettingsMargin/SettingsVBox/SettingsBackButton

var _progression: Dictionary = {}
var _using_keyboard_navigation: bool = false
var _music_player: AudioStreamPlayer

func _ready() -> void:
	ParallelRuntime.apply_from_environment()
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
	left_scrim.color = Color(0.011, 0.012, 0.018, 0.66)

	_apply_title_style(title_label, Color("fff1c8"), Color("070403"), 13)
	_apply_title_style(title_shadow_label, Color("000000"), Color("000000"), 14)
	title_shadow_label.modulate = Color(0.0, 0.0, 0.0, 0.70)

	menu_column.add_theme_constant_override("separation", MENU_SEPARATION)
	for button: Button in [continue_button, start_button, settings_button, quit_button, boss_button, settings_back_button]:
		_apply_menu_button_style(button)
	boss_button.visible = false

	_apply_label_style(embers_label, HEADER_FONT, 22, Color("f6d99f"), Color("100908"), 3)
	_apply_label_style(footer_label, REGULAR_FONT, 15, Color("dbc59b"), Color("100908"), 2)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	settings_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_apply_label_style(settings_title_label, HEADER_FONT, 32, Color("fff1cf"), Color("090708"), 5)

func _apply_title_style(label: Label, color: Color, outline_color: Color, outline_size: int) -> void:
	label.text = TITLE_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HEADER_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)

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
	button.add_theme_stylebox_override("normal", _make_menu_button_style(Color(0.02, 0.024, 0.033, 0.72), EDGE_ACCENT.darkened(0.24), 0.0))
	button.add_theme_stylebox_override("hover", _make_menu_button_style(Color(0.07, 0.071, 0.082, 0.86), EDGE_ACCENT.lightened(0.12), 2.0))
	button.add_theme_stylebox_override("focus", _make_menu_button_style(Color(0.08, 0.078, 0.088, 0.90), EDGE_ACCENT.lightened(0.18), 3.0))
	button.add_theme_stylebox_override("pressed", _make_menu_button_style(Color(0.015, 0.016, 0.022, 0.90), Color("f0c978"), 0.0, 2.0))
	button.add_theme_stylebox_override("disabled", _make_menu_button_style(Color(0.02, 0.02, 0.026, 0.42), Color("5f5140"), 0.0))
	button.add_theme_color_override("font_color", Color("f3e5c5"))
	button.add_theme_color_override("font_hover_color", Color("fff4d8"))
	button.add_theme_color_override("font_focus_color", Color("fff4d8"))
	button.add_theme_color_override("font_pressed_color", Color("dfc48f"))
	button.add_theme_color_override("font_disabled_color", Color("8d806b"))
	button.add_theme_color_override("font_outline_color", Color("080606"))
	button.add_theme_constant_override("outline_size", 4)

func _make_menu_button_style(background: Color, accent: Color, expand: float = 0.0, pressed_offset: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.border_width_left = 6
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 24
	style.content_margin_top = 8 + pressed_offset
	style.content_margin_right = 18
	style.content_margin_bottom = maxf(4.0, 8 - pressed_offset)
	style.expand_margin_left = expand
	style.expand_margin_top = expand
	style.expand_margin_right = expand
	style.expand_margin_bottom = expand
	return style

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

func _reload_progression() -> void:
	_progression = ProgressionStore.load_data()
	var has_saved_run: bool = ProgressionStore.has_saved_run()
	continue_button.disabled = not has_saved_run
	embers_label.text = PROFILE_TEXT
	footer_label.text = "LV %d  |  EMBERS %d  |  BOUND %d" % [
		int(_progression.get("level", 1)),
		int(_progression.get("embers", 0)),
		_bound_magick_count()
	]

func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var margin_x: float = clampf(viewport_size.x * 0.04, 30.0, 72.0)
	var title_y: float = clampf(viewport_size.y * 0.052, 26.0, 62.0)
	var menu_width: float = clampf(viewport_size.x * 0.22, MENU_BUTTON_MIN_WIDTH, MENU_BUTTON_MAX_WIDTH)
	var button_height: float = MENU_BUTTON_HEIGHT_COMPACT if viewport_size.y < 700.0 else MENU_BUTTON_HEIGHT
	var title_max_width: float = minf(viewport_size.x - margin_x * 2.0, maxf(420.0, viewport_size.x * 0.68))
	var title_font_size: int = _fitted_title_font_size(title_max_width)
	var title_height: float = maxf(HEADER_FONT.get_height(title_font_size), 54.0)
	var title_size := Vector2(title_max_width, title_height + 30.0)

	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_shadow_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.position = Vector2(margin_x, title_y)
	title_shadow_label.position = title_label.position + Vector2(14.0, 13.0)
	title_label.size = title_size
	title_shadow_label.size = title_size

	var menu_y: float = title_y + title_size.y + clampf(viewport_size.y * 0.028, 20.0, 42.0)
	menu_column.position = Vector2(margin_x, menu_y)
	menu_column.size = Vector2(menu_width, _menu_column_height(button_height))
	for button: Button in [continue_button, start_button, settings_button, quit_button, boss_button]:
		button.custom_minimum_size = Vector2(menu_width, button_height)
	settings_back_button.custom_minimum_size = Vector2(minf(250.0, menu_width), button_height)

	var profile_width: float = minf(menu_width + 72.0, viewport_size.x - margin_x * 2.0)
	var profile_height: float = 86.0
	var profile_y: float = viewport_size.y - profile_height - clampf(viewport_size.y * 0.055, 34.0, 64.0)
	profile_block.visible = profile_y > menu_y + _menu_column_height(button_height) + 16.0
	profile_block.position = Vector2(margin_x, profile_y)
	profile_block.size = Vector2(profile_width, profile_height)

	var left_width: float = margin_x + menu_width + clampf(viewport_size.x * 0.045, 64.0, 128.0)
	left_scrim.position = Vector2.ZERO
	left_scrim.size = Vector2(left_width, viewport_size.y)

	var panel_width: float = minf(390.0, maxf(300.0, viewport_size.x - margin_x * 2.0))
	var panel_height: float = 214.0
	var panel_x: float = margin_x + menu_width + 38.0
	var panel_y: float = menu_y
	if panel_x + panel_width + margin_x > viewport_size.x:
		panel_x = margin_x
		panel_y = minf(viewport_size.y - panel_height - 24.0, menu_y + _menu_column_height(button_height) + 22.0)
	settings_panel.position = Vector2(panel_x, maxf(24.0, panel_y))
	settings_panel.size = Vector2(panel_width, panel_height)

func _menu_column_height(button_height: float) -> float:
	var visible_buttons: int = 4
	return float(visible_buttons) * button_height + float(visible_buttons - 1) * float(MENU_SEPARATION)

func _fitted_title_font_size(max_width: float) -> int:
	var font_size: int = TITLE_BASE_SIZE
	while font_size > TITLE_MIN_SIZE:
		var text_width: float = HEADER_FONT.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if text_width <= max_width:
			return font_size
		font_size -= 2
	return TITLE_MIN_SIZE

func _bound_magick_count() -> int:
	var total: int = (_progression.get("card_upgrades", {}) as Dictionary).size()
	for mods_var: Variant in (_progression.get("card_mods", {}) as Dictionary).values():
		if typeof(mods_var) == TYPE_ARRAY:
			total += (mods_var as Array).size()
	return total

func _play_menu_music() -> void:
	var entry: Dictionary = MusicLibrary.entry(MusicLibrary.RELIC_ROOM_TRACK_ID)
	var path: String = str(entry.get("path", ""))
	var stream: AudioStream = AssetLoader.load_audio_stream(path)
	if stream == null:
		return
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
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
	if get_tree().root.has_meta("labyrinth_resume_saved_run"):
		get_tree().root.remove_meta("labyrinth_resume_saved_run")
	if ProgressionStore.has_saved_run():
		_progression = ProgressionStore.set_embers(ProgressionStore.load_data(), 0)
		ProgressionStore.save_data(_progression)
	ProgressionStore.clear_saved_run()
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _on_continue_button_pressed() -> void:
	if continue_button.disabled:
		return
	get_tree().root.set_meta("labyrinth_resume_saved_run", true)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")

func _on_settings_button_pressed() -> void:
	settings_panel.visible = true
	if _using_keyboard_navigation:
		settings_back_button.grab_focus()
	else:
		_clear_menu_keyboard_focus()

func _on_settings_back_button_pressed() -> void:
	settings_panel.visible = false
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
