extends "res://tests/controller_screen_sweep.gd"

const Cases = preload("res://tests/ux15/family_cases.gd")
const Glyph = preload("res://scripts/input_glyph.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const PromptBar = preload("res://scripts/controller_prompt_bar.gd")
const Wording = preload("res://scripts/input_wording.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const PROBE_OUTPUT: String = "/private/tmp/labyrinth_codex/ux-15"
const SHEET_SCALES = [1.0, 1.5]
const SHEET_MARGIN := Vector2(28, 26)
const SHEET_ROW_HEIGHT: float = 43.0
const SHEET_GLYPH_COLUMNS := Vector3(260, 393, 526)
const SHEET_ACTION_PREFIX: String = "controller_"

var _headless: bool
var _family_trace: Array[String]
var _measured_labels: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	_output_dir = PROBE_OUTPUT
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output_arg: int = args.find("--output-dir")
	if output_arg >= 0 and output_arg + 1 < args.size():
		_output_dir = args[output_arg + 1]
	_headless = DisplayServer.get_name() == "headless"
	_run.call_deferred()

func _run() -> void:
	if _headless and not OS.get_cmdline_user_args().has("--logic-only"):
		push_error("Renderer proof requires a display. Use --logic-only for headless checks.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	if _headless:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		_expect(DirAccess.make_dir_recursive_absolute(_output_dir) == OK, "Capture directory available")
		_expect(CelLook.mode == "all", "Combat capture runs with the cel look enabled")
	_setup_run_fixture()
	await _check_live_surfaces()
	if not _headless and _failures.is_empty():
		_router.set_forced_state_for_test(Router.MODALITY_CONTROLLER, Router.FAMILY_PLAYSTATION)
		await _save_capture("combat_playstation_cel.png")
	_scene.queue_free()
	await _settle()
	await _check_sheets()
	for failure: String in _failures:
		push_error(failure)
	print("UX-15 PLAYSTATION PROMPTS: %s (%s)" % [
		"PASS" if _failures.is_empty() else "FAIL", "headless semantics" if _headless else "native captures",
	])
	quit(0 if _failures.is_empty() else 1)

func _setup_run_fixture() -> void:
	Store.set_storage_path("user://ux15_profile.json")
	Store.set_run_storage_path("user://ux15_run.save")
	Settings.set_storage_path("user://ux15_settings.json")
	Analytics.set_storage_dir("user://ux15_analytics")
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	# The fixture replaces device queries. Signals, input handling and all UI
	# reactions still use the production router and the actual game controls.
	root.get_node("InputRouter").name = "OriginalInputRouter"
	_router = Cases.FixtureRouter.new()
	_router.name = "InputRouter"
	root.add_child(_router)
	_router.set_modality(Router.MODALITY_CONTROLLER)
	Cases.new().check_tables(_expect, _router)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set("_defer_initial_run_presentation", true)
	_viewport.add_child(_scene)
	_scene.set("_defer_initial_run_presentation", false)

func _check_live_surfaces() -> void:
	await _settle()
	await _load(_combat_state())
	var fixtures := VBoxContainer.new()
	_viewport.add_child(fixtures)
	var bar := PromptBar.new()
	fixtures.add_child(bar)
	bar.set_prompts([{"action": Router.ACTION_ACCEPT, "label": "Select"}])
	var bar_prompt: Control = bar._prompt_row.get_child(0)
	var dialogue_label := Label.new()
	fixtures.add_child(dialogue_label)
	Wording.bind_dialogue(dialogue_label)
	dialogue_label.get_node("InputWording").set_wording({"controller_text": "Continue"})
	var dialogue_prompt: Control = fixtures.get_node("DialogueInputPrompt")
	var pass_chip: Control = _scene.find_child("PassPreviewChip", true, false)
	var tutorial_prompt: Control = _scene.get("_contextual_combat_prompt")
	tutorial_prompt.configure(Tutorial.phase_definition(Tutorial.PHASE_PASS_TURN), [pass_chip.get_global_rect()])
	_router.controller_family_changed.connect(func(family: String) -> void: _family_trace.append(family))
	await _check_surfaces(Router.FAMILY_XBOX, bar_prompt, dialogue_prompt, tutorial_prompt._controller_action)
	Input.joy_connection_changed.emit(Cases.PLAYSTATION_DEVICE, true)
	_expect(_router.active_device_id() == Cases.PLAYSTATION_DEVICE, "PlayStation connection claims the active device")
	await _check_surfaces(Router.FAMILY_PLAYSTATION, bar_prompt, dialogue_prompt, tutorial_prompt._controller_action)
	_press_activity(Cases.DECK_DEVICE)
	await _check_surfaces(Router.FAMILY_STEAM_DECK, bar_prompt, dialogue_prompt, tutorial_prompt._controller_action)
	_press_activity(Cases.PLAYSTATION_DEVICE)
	await _check_surfaces(Router.FAMILY_PLAYSTATION, bar_prompt, dialogue_prompt, tutorial_prompt._controller_action)
	_press_activity(Cases.PLAYSTATION_DEVICE)
	_expect(_family_trace == ["playstation", "steam_deck", "playstation"], "Family signal fires once per change: %s" % str(_family_trace))
	print("UX-15 LIVE FAMILY SIGNALS: %s" % str(_family_trace))
	fixtures.queue_free()
	tutorial_prompt.clear_prompt()
	await _settle()

func _press_activity(device_id: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device_id
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	_router.record_input_activity(event)

func _check_surfaces(family: String, bar: Control, dialogue: Control, tip: Control) -> void:
	for prompt: Control in [bar, dialogue, tip]:
		_expect(prompt._glyph.family == family, "%s follows %s synchronously" % [prompt.name, family])
	await _settle()
	var badges: Array = _scene.get("_controller_glyph_badges").badges_snapshot()
	for action: StringName in [Router.ACTION_PASS, Router.ACTION_HAND_TOGGLE, Router.ACTION_MENU, Router.ACTION_MAP]:
		_expect(badges.any(func(badge: Dictionary) -> bool:
			return badge["action"] == str(action) and badge["family"] == family
		), "Combat %s badge follows %s" % [action, family])
	for badge: Dictionary in badges:
		_expect(badge["family"] == family, "All visible combat badges use %s" % family)
	for control: Control in [_scene.get("mini_map_overlay"), _scene.get("_section_map_hud_button")]:
		_expect(control.tooltip_text == "Map", "Map tooltip stays shortcut-free in %s mode" % family)
	_scene.call("_set_show_all_enemy_intents", false)
	var details: Control = _scene.get("_enemy_intent_toggle_button")
	_expect(details.tooltip_text == "Show every enemy's full plan", "Details tooltip stays shortcut-free in %s mode" % family)

func _check_sheets() -> void:
	_expect(Glyph.preferred_size(Router.ACTION_MAP_ZOOM) == Vector2(68, 27), "Map Zoom uses the 68x27 paired key")
	for ui_scale: float in SHEET_SCALES:
		var logical_size := Vector2i(Vector2(PROOF_SIZE) / ui_scale)
		_viewport.size_2d_override = logical_size
		_viewport.size_2d_override_stretch = true
		var sheet := Control.new()
		_viewport.add_child(sheet)
		sheet.size = Vector2(logical_size)
		var panel_size := Vector2(sheet.size.x * 0.5, sheet.size.y)
		_add_sheet_panel(sheet, Vector2.ZERO, panel_size, Palette.INK_1, Palette.TEXT)
		_add_sheet_panel(sheet, Vector2(panel_size.x, 0), panel_size, Palette.PATTERN_ORIGIN_FILL, Palette.INK_1)
		if not _headless and _failures.is_empty():
			await _save_capture("glyph_sheet_%d.png" % roundi(ui_scale * 100.0))
		sheet.queue_free()
		await _settle()
	print("UX-15 LABEL FIT: %d labels measured at 100%% and 150%%" % _measured_labels)

func _add_sheet_panel(sheet: Control, origin: Vector2, panel_size: Vector2, fill: Color, ink: Color) -> void:
	var background := ColorRect.new()
	background.position = origin
	background.size = panel_size
	background.color = fill
	sheet.add_child(background)
	for column: int in range(Cases.FAMILIES.size()):
		_add_sheet_label(background, Cases.FAMILY_NAMES[column], Vector2(SHEET_GLYPH_COLUMNS[column] - 54.0, SHEET_MARGIN.y), ink)
	var row: int = 1
	for action: StringName in Cases.LABELS:
		var y: float = SHEET_MARGIN.y + row * SHEET_ROW_HEIGHT
		var caption: String = str(action).trim_prefix(SHEET_ACTION_PREFIX).capitalize()
		_add_sheet_label(background, caption, Vector2(SHEET_MARGIN.x, y), ink)
		for column: int in range(Cases.FAMILIES.size()):
			var glyph := Glyph.new()
			background.add_child(glyph)
			glyph.configure(action, Cases.FAMILIES[column])
			glyph.reset_size()
			glyph.position = Vector2(SHEET_GLYPH_COLUMNS[column] - glyph.size.x * 0.5, y)
			_expect(Rect2(Vector2.ZERO, panel_size).encloses(glyph.get_rect()), "Sheet fits %s at %s" % [action, panel_size])
			_expect(glyph._glyph_text() == Cases.LABELS[action][column], "Sheet contains the intended %s glyph" % action)
			_check_label_fit(glyph)
		row += 1

func _check_label_fit(glyph: Glyph) -> void:
	var action: StringName = glyph.action_name
	var face: bool = action in Glyph.FACE_ACTIONS
	if action == &"controller_dpad" or (face and glyph.family == Router.FAMILY_PLAYSTATION):
		return
	var label_size: int = glyph._rounded_key_label_size()
	# Interior width excludes the rounded-key inset and border on each side.
	var badge_width: float = glyph.size.x - 6.0
	var diameter: float = minf(glyph.size.x, glyph.size.y)
	if face:
		label_size = Typography.scaled_size(glyph, 16)
		badge_width = diameter * 0.84 - 2.5
	elif action == &"controller_move" or action == Router.ACTION_EMPOWER:
		label_size = Typography.scaled_size(glyph, Glyph.STICK_LABEL_SIZE)
		badge_width = diameter * 0.78 - 2.0
	elif action == Router.ACTION_MAP_ZOOM:
		_expect(label_size == Typography.scaled_size(glyph, 13), "Map Zoom uses the scaled 13 pt shoulder label")
	var font: Font = Typography.ui_font()
	if font == null:
		font = glyph.get_theme_default_font()
	var width: float = font.get_string_size(glyph._glyph_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	_measured_labels += 1
	_expect(width <= badge_width, "%s %s label at %d pt spills (%.1f px into %.1f px interior)" % [
		glyph.family, action, label_size, width, badge_width,
	])

func _add_sheet_label(parent: Control, content: String, at: Vector2, ink: Color) -> void:
	var label := Label.new()
	label.text = content
	label.position = at
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)

func _save_capture(filename: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == PROOF_SIZE, filename + " is 1920x1080")
	if image != null:
		var path: String = _output_dir.path_join(filename)
		_expect(image.save_png(path) == OK, filename + " saves")
		print(path)
