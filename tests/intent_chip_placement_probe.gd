extends SceneTree
## Matched before/after native proof. --check-only validates setup headlessly.
const Cases = preload("res://tests/fixtures/intent_chip_cases.gd")
const Suite = preload("res://tests/suites/intent_chip_placement_suite.gd")
const ProofBoard = preload("res://tests/fixtures/intent_chip_proof_board.gd")
const RenderProof = preload("res://tests/suites/encounter_tables_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 8
const READY_TIMEOUT_SECONDS: float = 20.0
const PROOF_SECONDS: float = 0.55
const OUTPUT: String = "user://probes/pt14-04"
const CAPTURE_CASES: Array = ["owner", "air_pre_battle", "air_opening", "air_midfight", "shadow_warband"]
var check_only: bool = false
var failures: Array[String]
var captures: Array[Dictionary]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	check_only = OS.get_cmdline_user_args().has("--check-only")
	call_deferred("_run")

func _run() -> void:
	if not check_only and DisplayServer.get_name() == "headless":
		_expect(false, "Windowed renderer required for pixel proof")
		_finish()
		return
	Settings.set_storage_path("user://intent-chip-proof-settings.json")
	Store.set_storage_path("user://intent-chip-proof-progression.json")
	Store.set_run_storage_path("user://intent-chip-proof-run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = UI_SCALE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.msaa_2d = root.msaa_2d
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for study: String in CAPTURE_CASES: await _case(study)
	var file := FileAccess.open(OUTPUT.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": UI_SCALE, "check_only": check_only, "captures": captures, "errors": failures}, "\t"))
	print(ProjectSettings.globalize_path(OUTPUT))
	canvas.queue_free()
	await process_frame
	_finish()

func _case(study: String) -> void:
	var run: Dictionary = Cases.owner_run() if study == "owner" else Cases.warband_run("shadow" if study == "shadow_warband" else "air", 2, study == "air_midfight")
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(ProofBoard)
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	var board: Control = scene.get("board_view")
	var state: Dictionary = run["combat_state"]
	if study == "air_pre_battle":
		var pre: Dictionary = run.duplicate(true)
		pre.merge({"mode": "pre_battle", "pre_battle_pending": true, "pre_battle_travel_dir": Vector2i.UP, "combat_state": {}}, true)
		scene.set("_run_state", pre)
		scene.set("_prepared_pre_battle_factory", Cases.Warband.prepared(Cases.Run.new(), Cases.Combat.new(), pre))
		_expect(bool(scene.call("_show_pre_battle_preview")), "Air Warband production pre-battle opens")
		await _settle()
	else:
		var presentation: Dictionary = board.presentation.duplicate(true)
		presentation["threats_proof_seconds"] = PROOF_SECONDS
		presentation["torch_mote_proof_seconds"] = PROOF_SECONDS
		if study == "owner": presentation.merge(Cases.owner_presentation(board), true)
		_submit(board, state, presentation)
		await _settle()
		Suite.check_board(board, study, _expect)
		if study == "owner":
			var layouts: Array[Dictionary] = Suite.Badges.layouts(board, board.presentation["threats_at_rest"]["badges"])
			_expect(layouts.size() == 1 and layouts[0]["center"] == Suite.homes(board, layouts[0])[1], "Native owner fixture takes lower left")
	var prepared: bool = await _ready(board)
	if not prepared:
		scene.queue_free()
		await process_frame
		return
	# Capture the state actually installed by this case, including pre-battle.
	state = (board.get("combat_state") as Dictionary).duplicate(true)
	# Hold all processing and cutout poses for a matched pair. The real retained
	# board redraw path remains active; this does not replace production art.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for before: bool in [true, false]:
		var presentation: Dictionary = board.presentation.duplicate(true)
		presentation["intent_chip_proof_before"] = before
		_submit(board, state, presentation)
		await _settle()
		var rest: Dictionary = board.presentation.get("threats_at_rest", {})
		var layouts: Array[Dictionary] = Suite.Pt13.layouts(board, rest.get("badges", [])) if before else Suite.Badges.layouts(board, rest.get("badges", []))
		var max_distance: float = 0.0
		var fallbacks: int = 0
		var mirrors: int = 0
		var coverage: float = 0.0
		var shapes: Array[Dictionary] = Suite.Solver.rest_silhouettes(board, board._visible_units())
		for layout: Dictionary in layouts:
			var origins: Array[Vector2] = Suite.homes(board, layout)
			max_distance = maxf(max_distance, minf((layout["center"] as Vector2).distance_to(origins[0]), (layout["center"] as Vector2).distance_to(origins[1])))
			if layout["above_everything"]: fallbacks += 1
			if (layout["center"] as Vector2).distance_squared_to(origins[1]) < (layout["center"] as Vector2).distance_squared_to(origins[0]): mirrors += 1
			coverage += Suite.Solver.coverage(layout["rect"], shapes, layout["key"])
		var name: String = "%s_%s_1920x1080.png" % [study, "before" if before else "after"]
		var path: String = OUTPUT.path_join(name)
		if not check_only:
			await RenderingServer.frame_post_draw
			_expect(board.drawn_before == before and board.drawn_chip_layouts == layouts, "Renderer submitted the selected before/after chip geometry")
			var image: Image = canvas.get_texture().get_image()
			_expect(image != null and image.get_size() == SIZE, "Native capture is exactly 1920x1080")
			if image != null: _expect(image.save_png(path) == OK, "Capture writes " + path)
		captures.append({"case": study, "before": before, "captured": not check_only, "prepared": prepared, "drawn_checked": not check_only, "board_enemies": (state.get("enemies", []) as Array).size(), "path": ProjectSettings.globalize_path(path), "chips": layouts.size(), "fallbacks": fallbacks, "max_distance": max_distance, "mirrors": mirrors, "weighted_coverage": coverage})
		print("INTENT CHIP CAPTURE: " + JSON.stringify(captures.back()))
	scene.queue_free()
	await process_frame

func _ready(board: Control) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var errors: Array[String]
	while Time.get_ticks_msec() < deadline:
		# Pre-battle may prepare a different roster from the input run. Always
		# inspect the board's current state rather than an earlier fixture copy.
		var state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
		var visible: Dictionary = state.duplicate(false)
		visible["enemies"] = (state.get("enemies", []) as Array).filter(func(enemy: Dictionary) -> bool: return Cases.Combat.new().is_enemy_visible_to_player(state, enemy))
		errors = RenderProof.renderer_readiness_errors(board, visible)
		if errors.is_empty():
			# Headless proof checks preparation, never claims renderer draws.
			if check_only: return true
			board.drawn_unit_keys.clear()
			board._queue_dynamic_redraw()
			await RenderingServer.frame_post_draw
			await process_frame
			if state != board.get("combat_state"): continue
			for key: String in board._units_by_key(board._visible_units()):
				if not board.drawn_unit_keys.has(key): errors.append(key + " not drawn")
			if errors.is_empty(): return true
		await process_frame
	_expect(false, "Native actors prepared and drawn: " + "; ".join(errors))
	return false

func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	board.set_combat_state(state, board.move_tiles, board.attack_tiles, board.selected_tile, board.status_label, board.status_detail, board.exit_tiles, board.exit_icon_ids, presentation)
	# The proof selector is deliberately outside production invalidation keys.
	board._queue_dynamic_redraw()

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("INTENT CHIP PROBE RESULT: %s (%d states; %d failures; check_only=%s)" % ["PASS" if failures.is_empty() else "FAIL", captures.size(), failures.size(), check_only])
	quit(0 if failures.is_empty() else 1)
