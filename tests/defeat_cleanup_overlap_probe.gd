extends "res://tests/turn_order_animation_probe.gd"
## Production card commit verifies defeat overlap, contact HUD and input release.
const Fixture = preload("res://tests/suites/chain_attack_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/defeat_cleanup_overlap"
var _proof_viewport: SubViewport
var _failures: Array[String]
var _finished: bool = false
var _images: Dictionary = {}
var _metrics: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://overlap_progression.json")
	ProgressionStore.set_run_storage_path("user://overlap_run.save")
	Settings.set_storage_path("user://overlap_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	_proof_viewport = SubViewport.new()
	_proof_viewport.size = VIEWPORT_SIZE
	_proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_proof_viewport)
	await _capture_case(false)
	await _capture_case(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for key: String in _images:
		(_images[key] as Image).save_png("%s/%s.png" % [OUTPUT, key])
	var metrics_file := FileAccess.open("%s/timing.json" % OUTPUT, FileAccess.WRITE)
	metrics_file.store_string(JSON.stringify(_metrics, "  "))
	for failure: String in _failures:
		push_error(failure)
	print(ProjectSettings.globalize_path(OUTPUT))
	print("DEFEAT CLEANUP OVERLAP PROBE: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _capture_case(reduced: bool) -> void:
	var name: String = "reduced" if reduced else "normal"
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_proof_viewport.add_child(instance)
	await create_timer(0.15).timeout
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	instance.set("_settings", settings)
	var progression: Dictionary = instance.get("_progression") as Dictionary
	for prompt: String in Tutorials.prompt_ids():
		progression = Tutorials.resolve_progression(progression, prompt)
	instance.set("_progression", progression)
	var combat = instance.get("_combat_engine")
	var before: Dictionary = Fixture.fixture(combat)
	before["objective"] = {"type": "kill_all"}
	before["room_name"] = "Defeat overlap proof"
	before["deck"]["hand"] = ["frostbolt"]
	before["enemies"][0]["hp"] = 1
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = before
	run["current_room"] = before.get("room_coord")
	run["current_room_layout"] = {"grid": before.get("grid"), "coord": before.get("room_coord"), "type": "combat", "name": "Defeat overlap proof"}
	instance.set("_run_state", run)
	instance.set("_combat_state", before)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	instance.call("_refresh_contextual_combat_tutorial")
	instance.call("_close_dialogue")
	await create_timer(0.25).timeout
	await _remember_image(name + "_00_ready")
	await instance.call("_on_card_pressed", 0)
	_expect(int(instance.get("_selected_card_index")) == 0, "Production card selection must accept Frostbolt")
	_expect((instance.get("_pending_target_tiles") as Array).has(Vector2i(4, 4)), "Fixture target must be offered by production preview")
	var board: Control = instance.get("board_view") as Control
	var hud: Control = instance.get("_combat_objective_hud") as Control
	var detail: Label = hud.find_child("ObjectiveLiveDetail", true, false) as Label
	var clock: Control = instance.get("_turn_order_bar") as Control
	var started: int = Time.get_ticks_usec()
	var timing: Dictionary = {}
	var overlap_seen: bool = false
	var contact_seen: bool = false
	_finished = false
	_commit(instance)
	while not _finished and Time.get_ticks_usec() - started < 8000000:
		var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
		var shown: Dictionary = board.get("combat_state") as Dictionary
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var death_progress: float = -1.0
		for unit: Dictionary in presentation.get("death_animation_units", []):
			if int(unit.get("id", -1)) == 1:
				death_progress = float(unit.get("death_progress", 0.0))
		if death_progress > 0.0 and not timing.has("board_started"):
			timing["board_started"] = elapsed
		if timing.has("board_started") and death_progress < 0.0 and not timing.has("board_finished"):
			timing["board_finished"] = elapsed
		var portrait_progress: float = -1.0
		for slot: Control in _turn_order_slot_controls(clock):
			if str(slot.get_meta("turn_order_actor_key", "")) == "enemy:enemy_1":
				var effect: Control = slot.get_node_or_null("TurnOrderShadowDissolve") as Control
				if effect != null:
					portrait_progress = float(effect.call("dissolve_progress"))
		if portrait_progress >= 0.0 and not timing.has("rail_started"):
			timing["rail_started"] = elapsed
		if timing.has("rail_started") and not bool(instance.get("_turn_order_animating")) and not timing.has("rail_finished"):
			timing["rail_finished"] = elapsed
		if not contact_seen and Fixture.hp(shown, 1) <= 0:
			contact_seen = true
			_expect(detail != null and detail.text.begins_with("3 "), "Objective count must follow the displayed lethal contact immediately")
			await _remember_image(name + "_01_contact")
		if not reduced and not overlap_seen and portrait_progress >= 0.38 and portrait_progress <= 0.80:
			overlap_seen = true
			_expect(death_progress > 0.0 and death_progress < 1.0, "Portrait breakup must run while battlefield death is still in progress")
			_assert_active_player_persists(instance)
			await _remember_image(name + "_02_overlap")
		await process_frame
	timing["input_unlocked"] = float(Time.get_ticks_usec() - started) / 1000000.0
	_expect(_finished and not bool(instance.get("_animation_lock")), "Production card must release input after both cleanup streams finish")
	_expect(contact_seen, "Production playback must expose its lethal contact")
	_expect(not bool(instance.get("_turn_order_animating")), "Input release cannot race unfinished Turn Clock cleanup")
	_expect(int(instance.get("_selected_card_index")) == -1, "Production card must clear target selection")
	_assert_actor_absent(instance, "enemy:enemy_1")
	_assert_vertical_turn_order_geometry(instance)
	if not reduced:
		_expect(overlap_seen, "Normal proof must observe concurrent battlefield and portrait dissolution")
		_expect(timing.has("board_finished") and timing.has("rail_finished"), "Both cleanup streams must settle before input returns")
		if timing.has("board_finished") and timing.has("rail_finished"):
			var last_visual: float = maxf(float(timing["board_finished"]), float(timing["rail_finished"]))
			_expect(float(timing["input_unlocked"]) - last_visual < 0.65, "Input must return promptly after the slower cleanup stream")
	else:
		_expect(not timing.has("rail_started"), "Reduced motion must never start a portrait dissolve")
	await _remember_image(name + "_03_input_ready")
	# A real next input path proves the unlocked board accepts movement selection.
	var player_tile: Vector2i = ((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	await instance.call("_on_board_tile_clicked", player_tile)
	_expect(bool(instance.get("_player_movement_selected")), "Next board click must enter movement selection after the kill")
	_metrics[name] = timing
	instance.queue_free()
	await process_frame

func _commit(instance: Node) -> void:
	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	_finished = true

func _remember_image(key: String) -> void:
	await RenderingServer.frame_post_draw
	var captured: Image = _proof_viewport.get_texture().get_image()
	_expect(captured.get_size() == VIEWPORT_SIZE, "Proof must be rendered natively at1920x1080 UI100")
	_images[key] = captured

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
