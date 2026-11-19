extends "res://tests/fix18/draw_origin_test.gd"

## Inspection --launch opens MainMenu with this save. Follow its real Continue
## transition; pre_battle then presses the production Begin handler.
# int-09: seed 7262031 finds a pre-battle room with a visible Lancer on the merged revision-7 catalog.
const ENTRY_FRAME_BUDGET: int = 3600
const ENTRY_WORKER_GRACE_MSEC: int = 60_000

func _capture_run() -> void:
	_options = _parse_capture_args(OS.get_cmdline_user_args())
	if not OS.get_environment(OUTPUT_ENV).is_empty(): _capture_output = OS.get_environment(OUTPUT_ENV)
	var scenario: String = OS.get_environment("FIX18_ENTRY_SCENARIO")
	if scenario.is_empty(): scenario = _capture_label
	_options["scenario"] = scenario
	var progression: Dictionary = _build_progression()
	for prompt: String in CaptureTutorial.prompt_ids(): progression = CaptureTutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state(scenario, progression)
	_check(not run.is_empty(), "Build " + scenario + " fixture")
	_check(ProgressionStore.save_data(progression), "Save entry progression")
	_check(ProgressionStore.save_run_state(run), "Save entry fixture")
	var settings: Dictionary = CaptureSettings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = CaptureSettings.DISPLAY_WINDOWED
	_check(CaptureSettings.save_settings(settings), "Save entry settings")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = FRAME_SIZE
	root.content_scale_factor = 1.0
	root.size = FRAME_SIZE
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.call("_on_continue_button_pressed")
	var start_frame: int = Engine.get_process_frames()
	var start_msec: int = Time.get_ticks_msec()
	while current_scene == null or not current_scene.has_method("initial_presentation_is_ready") or not current_scene.call("initial_presentation_is_ready"):
		var elapsed_frames: int = Engine.get_process_frames() - start_frame
		var elapsed_msec: int = Time.get_ticks_msec() - start_msec
		# Slow frames must get their preparation steps, and fast headless
		# polling must give the asset worker time. The runner caps a hard stall.
		if elapsed_frames >= ENTRY_FRAME_BUDGET and elapsed_msec >= ENTRY_WORKER_GRACE_MSEC:
			_check(false, "Entry preparation timed out: %s (%d frames, %d ms)" % [scenario, elapsed_frames, elapsed_msec])
			await _capture_finish()
			return
		await process_frame
	_capture_scene = current_scene
	_capture_board = _capture_scene.get("board_view") as Control
	if scenario == "pre_battle":
		_check(str((_capture_scene.get("_run_state") as Dictionary).get("mode")) == "pre_battle", "Real pre-battle screen precedes Begin")
		# Test-only prepared roster. The normal Begin handler still owns combat
		# entry, renderer adoption, opening-hand presentation and board submission.
		var factory: Dictionary = (_capture_scene.get("_prepared_pre_battle_factory") as Dictionary).duplicate(true)
		factory["combat_state"] = _apply_enemy_overrides(factory["combat_state"])
		_capture_scene.set("_prepared_pre_battle_factory", factory)
		await _capture_scene.call("_on_pre_battle_start_pressed")
	await _settle_capture()
	_check(not (_capture_board.get("combat_state") as Dictionary).get("enemies", []).is_empty(), "Entry has enemies: " + scenario)
	print("FIX18 ENTRY PATH: ", scenario)
	await _capture_finish()
