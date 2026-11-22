extends SceneTree
## Match the review's startup resize and controller switch against release.

const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const ORIGINAL_ASPECT := Vector2i(1440, 900)
const WIDER_ASPECT := Vector2i(1600, 900)
const WIDE_WINDOW := Vector2i(1680, 720)
const NARROW_WINDOW := Vector2i(1280, 720)
const PORTRAIT_WINDOW := Vector2i(1080, 1080)
const LARGE_UI_SCALE: float = 1.25
const SMALL_UI_SCALE: float = 0.9
const CHECKPOINT_SEED: int = 167
const PROFILE_EMBERS: int = 91
const BASE_MUTATION_DELAY: float = 0.25
const SETTLE_FRAMES: int = 12
const PAGE_NODES := ["MenuArt", "Title", "TitleShadow", "TitleRim", "TitleFaceBlend", "ProfileBlock",
	"ResumePanel", "MenuColumn", "ControllerPromptBar", "DemoWishlistLink", "DemoDiscordLink"]

var _scenario: String
var _startup: Control
var _menu: Control
var _packed: PackedScene
var _staged: WeakRef

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_scenario = args[0] if args.size() == 1 else ""
	if _scenario not in ["stable", "aspect", "aspect-controller-after", "aspect-reverse",
			"wide-to-narrow", "scale-down", "scale-up", "resize-and-scale", "resize-round-trip",
			"viewport-scale-before-stage"]:
		push_error("Unknown startup edge fixture: " + _scenario)
		quit(2)
		return
	var settings := Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = true
	settings["ui_scale"] = 1.0 if _scenario in ["scale-up", "resize-and-scale"] else LARGE_UI_SCALE
	root.min_size = Vector2i.ZERO
	root.size = _initial_window_size()
	assert(Settings.save_settings(settings))
	var profile := Progression.default_data()
	profile["embers"] = PROFILE_EMBERS
	assert(Progression.save_data(profile))
	assert(Progression.save_run_state(Run.new().create_new_run(CHECKPOINT_SEED, profile)))
	if _scenario != "aspect-controller-after":
		root.get_node("InputRouter").set_forced_state_for_test("controller", "steam_deck")

	# Match the review's warm PackedScene fixture so the mutation takes place
	# inside the authored hold, even when the project has a cold loader.
	_packed = load("res://scenes/main_menu.tscn")
	_startup = load("res://scenes/startup.tscn").instantiate()
	_startup.finished.connect(func(menu: Control) -> void: _menu = menu)
	root.add_child(_startup)
	current_scene = _startup
	while _startup.phase != &"hold": await process_frame
	if _scenario == "viewport-scale-before-stage":
		root.content_scale_factor = SMALL_UI_SCALE
	if "_prepared_menu" in _startup:
		if _scenario == "resize-round-trip":
			await _wait_for_staged(false)
			assert(_startup.phase == &"hold")
			root.size = WIDER_ASPECT
		await _wait_for_staged(true)
		assert(_staged != null and _startup.phase == &"hold", "Fixture missed the completed staged menu.")
	else:
		await create_timer(BASE_MUTATION_DELAY).timeout
		assert(_startup.phase == &"hold")
	_mutate_hold(settings)

	while not is_instance_valid(_menu): await process_frame
	if _staged != null:
		assert((_staged.get_ref() == _menu) == (_scenario == "stable"),
			"An unchanged viewport should retain its staged menu. A changed viewport should rebuild it.")
	var idle := _menu.get_node_or_null("RunSceneIdlePreload")
	if idle != null: idle.set_process(false)
	await _settle_frames()
	assert(current_scene == _menu and not root.gui_disable_input)
	var report := {
		"scenario": _scenario,
		"window": str(root.size),
		"viewport": str(root.get_visible_rect().size),
		"ui_scale": root.content_scale_factor,
		"title": _title_snapshot(),
	}
	if _scenario == "aspect-controller-after":
		await _switch_to_controller()
		report["title_after_controller_input"] = _title_snapshot()
	_menu.get_node("MenuColumn/ChronicleButton").pressed.emit()
	await _settle_frames()
	var chronicle := _menu.get_node("ChroniclePanel") as Control
	assert(chronicle.visible, "Chronicle must open to exercise its prompt layout.")
	report["chronicle"] = _snapshot(chronicle)
	chronicle.close()
	_menu.get_node("MenuColumn/SettingsButton").pressed.emit()
	await _settle_frames()
	var panel := _menu.get_node("SettingsPanel") as Control
	assert(panel.visible, "Settings must open to exercise its complete layout.")
	report["settings"] = _snapshot(panel)
	print("PERF167 EDGES ", JSON.stringify(report))
	(_menu.get_node("MusicPlayer") as AudioStreamPlayer).stop()
	await process_frame
	quit()

func _initial_window_size() -> Vector2i:
	match _scenario:
		"aspect-reverse": return WIDER_ASPECT
		"wide-to-narrow": return WIDE_WINDOW
		_: return ORIGINAL_ASPECT

func _wait_for_staged(complete: bool) -> void:
	while is_instance_valid(_startup) and _startup.phase == &"hold":
		var staged: Control = _startup.get("_prepared_menu")
		if is_instance_valid(staged) and staged.is_inside_tree():
			if not complete or bool(_startup.get("_glyph_preparation_started")):
				_staged = weakref(staged)
				return
		await process_frame
	_staged = null

func _mutate_hold(settings: Dictionary) -> void:
	match _scenario:
		"aspect", "aspect-controller-after":
			root.size = WIDER_ASPECT
		"aspect-reverse", "resize-round-trip":
			root.size = ORIGINAL_ASPECT
		"wide-to-narrow":
			root.size = NARROW_WINDOW
		"scale-up", "resize-and-scale", "scale-down":
			if _scenario == "resize-and-scale": root.size = PORTRAIT_WINDOW
			settings["ui_scale"] = SMALL_UI_SCALE if _scenario == "scale-down" else LARGE_UI_SCALE
			assert(Settings.save_settings(settings))

func _switch_to_controller() -> void:
	for press: int in range(2):
		for down: bool in [true, false]:
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_LEFT_STICK
			event.pressed = down
			root.push_input(event, true)
		await process_frame
	assert(root.get_node("InputRouter").using_controller(), "Fixture must switch to controller after reveal.")
	await _settle_frames()

func _settle_frames() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _title_snapshot() -> Dictionary:
	var controls := {}
	for path: String in PAGE_NODES:
		var node := _menu.get_node_or_null(path) as Control
		if node != null: _collect(node, path, controls)
	return controls

func _snapshot(control: Control) -> Dictionary:
	var controls := {}
	_collect(control, str(control.name), controls)
	return controls

func _collect(control: Control, path: String, controls: Dictionary) -> void:
	var row := {
		"rect": str(control.get_global_rect()),
		"minimum": str(control.custom_minimum_size),
		"visible": control.is_visible_in_tree(),
	}
	if control is Label or control is Button:
		row["text"] = control.text
		row["font_size"] = control.get_theme_font_size("font_size")
	if control is Button:
		row["focused"] = control.has_focus()
		row["disabled"] = control.disabled
	controls[path] = row
	for node: Node in control.get_children():
		if node is Control:
			var local_path := str(node.name)
			if local_path.begins_with("@"): local_path = node.get_class() + str(node.get_index())
			_collect(node, path + "/" + local_path, controls)
