extends SceneTree
## Windowed-only proof. Run through visual_probe_runner.py; never emulate a GPU
## capture in headless mode. Uses only production art, UI and cursor assets.
const Fixture = preload("res://tools/ptf05/fixture.gd")
const Host = preload("res://tests/card_targeting_audit_host.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/ptf-05b/captures"
const PROOF_TIMEOUT_SECONDS: float = 20.0
var scene: Node
var finished: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("PTF05 capture requires a windowed renderer")
		quit(1)
		return
	root.size = Fixture.Base.PROOF_SIZE
	root.content_scale_size = Fixture.Base.PROOF_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Settings.set_storage_path("user://ptf05_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://ptf05_profile.json")
	Store.set_run_storage_path("user://ptf05_run.save")
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	create_timer(PROOF_TIMEOUT_SECONDS).timeout.connect(func() -> void:
		if not finished: _require(false, "Capture did not finish within %.0f seconds" % PROOF_TIMEOUT_SECONDS)
	)
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Host)
	root.add_child(scene)
	await Fixture.Base.settle(self)
	for id: String in Fixture.CASES:
		Fixture.install(scene, id)
		await Fixture.select(scene, id)
		var board: Control = scene.get("board_view")
		var tile: Vector2i = Fixture.tile_for(id)
		var local_point: Vector2 = Fixture.Base.pointer_point(board, tile)
		if not _require(local_point != Vector2.INF, "No exposed pointer point for " + id): return
		if not _require(board.call("_tile_at_point", local_point) == tile, "Pointer point must hit intended floor tile: " + id): return
		var point: Vector2 = board.get_global_transform_with_canvas() * local_point
		board.call("_clear_hover_for_navigation")
		root.warp_mouse(point)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true)
		if not _require((board.get("_last_pointer_position") as Vector2).is_equal_approx(local_point), "Board GUI did not receive motion: " + id): return
		await Fixture.Base.settle(self)
		if not _require(scene.get("_hovered_board_tile") == tile, "Pointer hover must reach tile for " + id): return
		if id not in ["floor_hover", "strike", "reach", "maul_floor_strike"]:
			await scene.call("_on_board_tile_clicked", tile)
			var feedback = scene.call("_click_feedback")
			if not _require(feedback.reason_label.visible and feedback.reason_label.text == Fixture.REASONS[id], "Reason missing: " + id): return
		elif id == "floor_hover":
			var feedback = scene.call("_click_feedback")
			feedback._update_labels()
			if not _require(feedback.get_child_count() == 1 and not feedback.reason_label.visible, "Floor hover must show no notice"): return
		elif id == "strike":
			if not _require((board.call("_build_damage_preview_map", board.get("presentation")) as Dictionary).has("enemy_1"), "Strike preview missing"): return
		elif id == "maul_floor_strike":
			var preview: Dictionary = scene.call("_active_card_preview")
			if not _require(not (scene.call("_shortcut_plan_for_tile", preview, tile) as Dictionary).is_empty(), "Maul floor shortcut missing"): return
		else:
			if not _require(not (board.get("presentation").get("attack_reach_tiles", []) as Array).is_empty(), "Reach tint missing"): return
		var hold_until: int = preload("res://scripts/presentation_clock.gd").ticks_usec(false) + 350000
		while preload("res://scripts/presentation_clock.gd").ticks_usec(false) < hold_until:
			await process_frame
		await RenderingServer.frame_post_draw
		if not _require(scene.get("_hovered_board_tile") == tile, "Final capture hover must equal intended floor tile: " + id): return
		var path: String = OUTPUT_DIR.path_join(id + ".png")
		if not _require(root.get_texture().get_image().save_png(path) == OK, "Cannot save " + path): return
		print(path)
	print("PTF05 CAPTURE: PASS (all reasons, quiet floor hover, strike preview, Dull Bolt reach)")
	finished = true
	scene.queue_free()
	await process_frame
	quit()

func _require(condition: bool, message: String) -> bool:
	if condition: return true
	finished = true
	push_error("PTF05 CAPTURE: FAIL: " + message)
	quit(1)
	return false
