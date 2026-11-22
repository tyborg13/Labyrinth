extends SceneTree
## Headless reproductions of the close, resize and live-save review findings.

const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CHECKPOINT_SEED: int = 167
const UPDATED_EMBERS: int = 444
const LARGE_UI_SCALE: float = 1.25
const BASE_HOLD_MUTATION_MS: int = 800
const SETTLE_FRAMES: int = 20
const WIDE_WINDOW := Vector2i(1680, 720)
const NARROW_WINDOW := Vector2i(1280, 720)
const ORIGINAL_ASPECT := Vector2i(1440, 900)
const WIDER_ASPECT := Vector2i(1600, 900)
const EXPECTED_BUTTON_WIDTH: float = 422.4
const EXPECTED_RESUME_GAP: float = 24.0
const EXPECTED_PROMPT_SIZE: int = 17

var _mode: String
var _startup: Control
var _menu: Control
var _cached_menu: PackedScene
var _staged_menu_exited: bool
var _failures: Array[String]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_mode = args[0] if args.size() == 1 else ""
	if _mode not in ["close", "direct", "width", "disk", "aspect"]:
		push_error("Expected one mode: close, direct, width, disk or aspect.")
		quit(2)
		return
	var closing := _mode in ["close", "direct"]
	Settings.set_storage_path("user://perf167_review_settings.json")
	Progression.set_storage_path("user://perf167_review_profile.json")
	Progression.set_run_storage_path("user://perf167_review_run.save")
	var settings := Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = not closing
	settings["ui_scale"] = LARGE_UI_SCALE if _mode == "aspect" else 1.0
	root.min_size = Vector2i.ZERO
	if _mode == "width": root.size = WIDE_WINDOW
	if _mode == "aspect": root.size = ORIGINAL_ASPECT
	_expect(Settings.save_settings(settings), "Initial settings should save.")
	var profile := Progression.default_data()
	_expect(Progression.save_data(profile), "Initial profile should save.")
	var run_state: Dictionary = {}
	if _mode in ["width", "disk"]:
		run_state = RunEngineScript.new().create_new_run(CHECKPOINT_SEED, profile)
	if _mode == "width":
		_expect(Progression.save_run_state(run_state), "Width case should start with a checkpoint.")
	root.get_node("InputRouter").set_forced_state_for_test("controller", "steam_deck")

	# Preload only for these checks so the fixture can change state inside the
	# authored hold regardless of how long a cold PackedScene request takes.
	_cached_menu = load("res://scenes/main_menu.tscn")
	_startup = load("res://scenes/startup.tscn").instantiate()
	_startup.finished.connect(func(menu: Control) -> void: _menu = menu)
	root.add_child(_startup)
	current_scene = _startup
	while _startup.phase != &"hold": await process_frame
	var staged := await _wait_for_staged_menu()
	if not is_instance_valid(_startup) or _startup.phase != &"hold":
		_expect(false, "Fixture failed to reach prepared controls during the seal hold.")
		_finish()
		return
	_expect(root.gui_disable_input, "Splash should still hold the input lock.")
	if closing:
		_close_while_staged(staged)
		return

	match _mode:
		"width":
			root.size = NARROW_WINDOW
		"disk":
			profile["embers"] = UPDATED_EMBERS
			_expect(Progression.save_data(profile), "Updated profile should save.")
			_expect(Progression.save_run_state(run_state), "Checkpoint should save during the hold.")
			var checkpoint := Progression.read_resumable_checkpoint()
			_expect(checkpoint.get("state", {}).get("seed") == CHECKPOINT_SEED, "New checkpoint should be readable before reveal.")
			settings["ui_scale"] = LARGE_UI_SCALE
			_expect(Settings.save_settings(settings), "Updated UI scale should save.")
		"aspect":
			root.size = WIDER_ASPECT

	while not is_instance_valid(_menu): await process_frame
	var idle := _menu.get_node_or_null("RunSceneIdlePreload")
	if idle != null: idle.set_process(false)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_assert_ready_menu()
	(_menu.get_node("MusicPlayer") as AudioStreamPlayer).stop()
	await process_frame
	_finish()

func _wait_for_staged_menu() -> Control:
	# The same fixture can run against the merge base, which has no staged
	# instance. On a candidate, mutate only after staging has really finished.
	if not "_prepared_menu" in _startup:
		await create_timer(float(BASE_HOLD_MUTATION_MS) / 1000.0).timeout
		return null
	while is_instance_valid(_startup) and _startup.phase == &"hold":
		var staged: Control = _startup.get("_prepared_menu")
		if is_instance_valid(staged) and staged.is_inside_tree() and bool(_startup.get("_glyph_preparation_started")):
			return staged
		await process_frame
	return null

func _close_while_staged(staged: Control) -> void:
	var candidate := "_prepared_menu" in _startup
	if candidate:
		_expect(is_instance_valid(staged) and not staged.visible, "Close must exercise an attached, hidden menu.")
		if is_instance_valid(staged):
			staged.tree_exited.connect(func() -> void: _staged_menu_exited = true, CONNECT_ONE_SHOT)
	root.tree_exited.connect(_verify_shutdown.bind(candidate), CONNECT_ONE_SHOT)
	if _mode == "direct":
		quit(0 if _failures.is_empty() else 1)
		return
	root.close_requested.emit()
	_expect(root.gui_disable_input, "Window close should keep input locked through shutdown.")
	_expect(not _startup.is_processing(), "Window close should stop staged construction immediately.")
	if candidate:
		_expect(_startup.get("_prepared_menu") == null and staged.is_queued_for_deletion(), "Close should queue the staged menu for deletion.")
	if not _failures.is_empty(): quit(1)

func _verify_shutdown(candidate: bool) -> void:
	_expect(not is_instance_valid(_menu), "Startup should exit without revealing a menu.")
	_expect(not candidate or _staged_menu_exited, "The staged menu should exit cleanly with the root.")
	_print_result()

func _assert_ready_menu() -> void:
	_expect(current_scene == _menu and not root.gui_disable_input, "Menu should become current and restore input.")
	var continued := _menu.get_node("MenuColumn/ContinueButton") as Button
	var resume := _menu.get_node("ResumePanel") as Control
	if _mode in ["width", "disk"]:
		_expect(not continued.disabled and continued.text == "Continue Run" and resume.visible, "The current checkpoint should enable Continue Run and show the resume card.")
		_expect(root.gui_get_focus_owner() == continued, "Controller should focus Continue Run.")
	match _mode:
		"width":
			var resume_edge := resume.get_global_rect().position.x
			for button: Button in _menu.get_node("MenuColumn").get_children():
				if not button.visible: continue
				var rect := button.get_global_rect()
				_expect(is_equal_approx(rect.size.x, EXPECTED_BUTTON_WIDTH), "%s retains stale width: %.3f." % [button.name, rect.size.x])
				_expect(is_equal_approx(resume_edge - rect.end.x, EXPECTED_RESUME_GAP), "%s does not retain the 24 px resume gap." % button.name)
		"disk":
			var footer := _menu.get_node("ProfileBlock/Footer") as Label
			var panel := _menu.get_node("SettingsPanel") as SettingsPanel
			_expect("EMBERS %d" % UPDATED_EMBERS in footer.text, "Footer should show the updated profile embers.")
			_expect(is_equal_approx(root.content_scale_factor, LARGE_UI_SCALE), "Reveal should apply the updated UI scale.")
			_expect(is_equal_approx(float(panel.current_settings()["ui_scale"]), LARGE_UI_SCALE), "Settings panel should use the updated UI scale.")
		"aspect":
			var prompts := _menu.get_node("ControllerPromptBar").find_children("*", "Label", true, false)
			var sizes: Dictionary = {}
			for label: Label in prompts:
				sizes[label.text] = label.get_theme_font_size("font_size")
			_expect(Typography.scaled_size(_menu, Typography.SIZE_BODY) == EXPECTED_PROMPT_SIZE, "Fixture should cross the original prompt sizing breakpoint.")
			_expect(sizes == {"Select": EXPECTED_PROMPT_SIZE, "Navigate": EXPECTED_PROMPT_SIZE}, "Prompt sizes at reveal: %s." % sizes)

func _finish() -> void:
	_print_result()
	quit(0 if _failures.is_empty() else 1)

func _print_result() -> void:
	print("PERF167 REVIEW %s TEST RESULT: %s (%d failures)" % [_mode, "PASS" if _failures.is_empty() else "FAIL", _failures.size()])

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failures.append(message)
	push_error(message)
