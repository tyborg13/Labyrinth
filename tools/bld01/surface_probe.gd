extends "res://tests/demo_end_panel_probe.gd"

const BuildInfo = preload("res://scripts/build_info.gd")
const ProbeViewport = preload("res://tools/demo_clips/probe.gd")
const DemoPanel = preload("res://scripts/demo_end_panel.gd")
const BLD_OUTPUT_DIR: String = "user://bld01/1920x1080"
const BLD_UI_SCALE: float = 1.0
const BLD_HELD_EMBERS: int = 236
const BLD_CLEARED_ROOMS: int = 9

var _viewport: SubViewport
var _stamp_loaded: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	OS.set_environment("LABYRINTH_DEMO", "1")
	root.content_scale_size = PROOF_RESOLUTION
	root.size = PROOF_RESOLUTION
	root.content_scale_factor = BLD_UI_SCALE
	ProgressionStore.set_storage_path(PROFILE_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = BLD_UI_SCALE
	SettingsStore.save_settings(settings)
	ProgressionStore.clear_saved_run()
	_original_config = DemoRules.config()
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stamp_arg: int = args.find("--stamp-pack")
	if stamp_arg >= 0 and stamp_arg + 1 < args.size():
		_stamp_loaded = ProjectSettings.load_resource_pack(args[stamp_arg + 1], false)
		_require(_stamp_loaded, "Mount the demo stamp fixture pack")
	if not _validate_only and (not _stamp_loaded or DisplayServer.get_name() == "headless"):
		push_error("BLD01 capture requires a real renderer and --stamp-pack")
		quit(1)
		return
	_viewport = ProbeViewport.create_viewport(root)
	var cursor: Node = root.get_node_or_null("CursorFeedback")
	if cursor != null:
		cursor.call("set_glyph_visibility_suppressed", "bld01", true)
	if not _validate_only:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BLD_OUTPUT_DIR))

	await _check_menu()
	_require(not str(_original_config["feedback_url"]).is_empty() and _original_config["feedback_url"] == _original_config["discord_url"], "Use the protected Discord feedback data")
	await _check_panel("full", true)
	await _check_panel("links", true)
	DemoRules._config = _original_config.duplicate(true)
	DemoRules._config["feedback_url"] = ""
	await _check_panel("full", false)
	await _check_panel("links", false)
	DemoRules._config = _original_config
	if not _validate_only:
		print(ProjectSettings.globalize_path(BLD_OUTPUT_DIR))
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	print("BLD01 SURFACES: %s (%d captures)" % ["PASS" if _failures.is_empty() else "FAIL", _captures])
	quit(0 if _failures.is_empty() else 1)

func _check_menu() -> void:
	ProgressionStore.save_data(ProgressionStore.default_data())
	var menu: Control = MENU_SCENE.instantiate() as Control
	_viewport.add_child(menu)
	await _settle()
	var label: Label = menu.get_node("BuildLabel") as Label
	var profile: Control = menu.get_node("ProfileBlock") as Control
	var detail: Label = profile.get_node("Footer") as Label
	_require(label.text == BuildInfo.label_text(), "Menu shows the build reader's label")
	_require(label.text.begins_with("DEMO BUILD ") if _stamp_loaded else label.text == "DEV BUILD", "Menu uses the stamped demo or development label")
	_require(label.get_line_count() == 1 and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Build label is one right-aligned line")
	_require(label.get_theme_font("font") == detail.get_theme_font("font"), "Build label uses the profile detail font")
	_require(label.get_theme_font_size("font_size") == detail.get_theme_font_size("font_size"), "Build label uses the profile detail size")
	_require(label.get_theme_color("font_color") == detail.get_theme_color("font_color"), "Build label uses the profile detail colour")
	_require(is_zero_approx(float(label.get_theme_constant("outline_size"))), "Build label has no outline")
	_require(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE, "Build label cannot take mouse or keyboard focus")
	_require(is_equal_approx(label.get_global_rect().end.x, PROOF_RESOLUTION.x - profile.position.x) and is_equal_approx(profile.position.x, 72.0), "Build label mirrors the profile's 72 px inset")
	_require(is_equal_approx(label.global_position.y + label.get_line_height(), detail.global_position.y + detail.get_line_height()), "Build label shares the profile detail baseline")
	await _capture("01_demo_menu.png")
	var original_position: Vector2 = label.position
	menu.call("_on_settings_button_pressed")
	profile.position.y += detail.get_line_height()
	profile.hide()
	await _settle()
	_require(label.visible and label.position == original_position, "Build label remains in place when the profile and demo links hide")
	print("BLD01 MENU LABEL: " + label.text)
	await _free(menu)

func _check_panel(kind: String, feedback_enabled: bool) -> void:
	var is_full: bool = kind == "full"
	var instance: Node = RUN_SCENE.instantiate()
	_viewport.add_child(instance)
	await _settle()
	var progression: Dictionary = ProgressionStore.default_data()
	var outcome: String = "victory" if is_full else "defeat"
	var stats: Dictionary = {"rooms_explored": BLD_CLEARED_ROOMS, "enemies_slain": 21, "enemies_killed": 21, "run_seconds": 2460}
	if is_full:
		stats.merge({"guardians_slain": 1, "dragons_slain": ["vyraketh"], "max_kills_one_card": 3})
	else:
		stats["killer"] = {"enemy_type": "vyraketh", "intent_id": "", "damage": 9}
	var state: Dictionary = _section_one_state(RunEngine.new(), progression, outcome, BLD_HELD_EMBERS, BLD_CLEARED_ROOMS, stats)
	if not is_full:
		state.erase("run_result")
		_mark_hearth(state)
	await _install(instance, progression, state)
	var recap: Control = instance.get("_run_end_recap") as Control
	if not is_full:
		instance.call("_seek_run_end_board_reframe", 1.0)
	recap.call("skip_presentation")
	await _settle()
	var panel: DemoPanel = recap.get("_demo_panel") as DemoPanel
	_require(panel != null and panel.kind == kind, "Production recap presents " + kind)
	if panel != null and not panel.links.is_empty():
		var expected: Array[String]
		if not is_full:
			expected.append("WISHLIST ON STEAM ›")
		expected.append("SHARE FEEDBACK ON DISCORD ›" if feedback_enabled else "JOIN THE DISCORD ›")
		var actual: Array = panel.links.map(func(link: Button) -> String: return link.text)
		_require(actual == expected, "%s link list matches %s" % [kind, expected])
		_check_focus(panel)
		if feedback_enabled:
			var opened: Array[String]
			var shell_open: Callable = DemoPanel.shell_open
			DemoPanel.shell_open = func(url: String) -> void: opened.append(url)
			panel.links.back().pressed.emit()
			DemoPanel.shell_open = shell_open
			_require(opened == [_original_config["discord_url"]], "Feedback activation opens the protected Discord URL")
			await _capture("02_demo_full.png" if is_full else "03_demo_links.png")
		print("BLD01 PANEL %s (feedback %s): %s" % [kind, "matches Discord" if feedback_enabled else "empty", actual])
	else:
		_require(false, "Production recap presents at least one link for " + kind)
	await _free(instance)

func _check_focus(panel: DemoPanel) -> void:
	var first: Button = panel.links[0]
	var chronicle: Button = first.get_node_or_null(first.focus_neighbor_top) as Button
	_require(chronicle != null and chronicle.get_node_or_null(chronicle.focus_neighbor_bottom) == first, "Chronicle and the first link navigate vertically")
	for index: int in range(panel.links.size()):
		var link: Button = panel.links[index]
		var previous: Button = panel.links[posmod(index - 1, panel.links.size())]
		var next: Button = panel.links[(index + 1) % panel.links.size()]
		_require(link.get_node_or_null(link.focus_neighbor_left) == previous, "Left focus cycles through the remaining links")
		_require(link.get_node_or_null(link.focus_neighbor_right) == next, "Right focus cycles through the remaining links")
		_require(link.get_node_or_null(link.focus_neighbor_bottom) == panel.primary_plate(), "Link focus returns to the primary plate")

func _capture(filename: String) -> void:
	if _validate_only:
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_require(image.get_size() == PROOF_RESOLUTION, "Capture renders at exactly 1920x1080")
	var path: String = BLD_OUTPUT_DIR.path_join(filename)
	_require(image.save_png(path) == OK, "Save " + filename)
	print("Saved " + ProjectSettings.globalize_path(path))
	_captures += 1
