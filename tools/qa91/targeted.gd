extends SceneTree
## The qa-89 certified fixtures through production Continue and action handlers.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Difficulty = preload("res://scripts/difficulty_tier_rules.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const ARRIVAL_TEST_ID: int = 99001
const ARRIVAL_TEST_TILE := Vector2i(2, 2)
const TIMEOUT_MSEC: int = 20000
const SETTLE_FRAMES: int = 8
const PROOF_DEATH_PROGRESS: float = 0.25

var scene: Node
var failures: Array[String]
var checks: int = 0
var output: String = "user://qa91"
var capture: bool = false
var watched_id: int = -1
var samples: Array[Dictionary]
var death_capture_pending: bool = false
var death_captured: bool = false


func _initialize() -> void:
	Runtime.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--output-dir")
	if index >= 0: output = args[index + 1]
	# Copy the certified source into this process's isolated profile before Continue.
	index = args.find("--source-save")
	if index >= 0:
		var save_error: Error = DirAccess.copy_absolute(args[index + 1], ProjectSettings.globalize_path(Store.DEFAULT_RUN_STORAGE_PATH))
		if save_error != OK:
			push_error("Could not copy the certified run save: %s" % error_string(save_error))
			quit(2)
			return
	index = args.find("--source-profile")
	if index >= 0:
		var profile_error: Error = DirAccess.copy_absolute(args[index + 1], ProjectSettings.globalize_path(Store.DEFAULT_STORAGE_PATH))
		if profile_error != OK:
			push_error("Could not copy the certified progression: %s" % error_string(profile_error))
			quit(2)
			return
	capture = args.has("--capture")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if DisplayServer.get_name() == "headless":
		process_frame.connect(_queue_headless_sample)
	else:
		RenderingServer.frame_pre_draw.connect(_observe)
		RenderingServer.frame_post_draw.connect(_capture_death)
	call_deferred("_run")


func _run() -> void:
	var certified: Dictionary = Store.load_saved_run()
	var scenario: String = str(certified.get("inspection_fixture", {}).get("summary", ""))
	if scenario not in ["storm_trap", "storm_chain_spawn", "hunted_cap"]:
		push_error("Expected a certified qa-91 save")
		quit(2)
		return
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = Settings.COMBAT_FASTEST
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	await _resume()
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	_expect(before.get("enemies", []) == certified["combat_state"]["enemies"], "Continue preserves certified enemies")
	if scenario == "hunted_cap":
		await _hunted(certified, before)
	else:
		await _storm(before, scenario)
	for failure: String in failures: push_error("QA91 " + scenario + ": " + failure)
	print("QA91_TARGET %s: %s (%d checks, %d failures)" % [scenario, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _resume() -> void:
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while not scene.call("initial_presentation_is_ready") and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(scene.call("initial_presentation_is_ready"), "Production presentation becomes ready")
	for frame: int in range(SETTLE_FRAMES): await process_frame
	scene.call("_close_dialogue")


func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while (scene.get("_animation_lock") or scene.get("_turn_order_animating")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not scene.get("_animation_lock"), "Resolution releases animation lock")
	_expect(not scene.get("_turn_order_animating"), "Turn-order playback settles")
	for frame: int in range(SETTLE_FRAMES): await process_frame


func _storm(before: Dictionary, scenario: String) -> void:
	watched_id = int(before["enemies"][0]["id"])
	await _capture_next("storm_trap_before.png")
	scene.call("_on_pass_turn_pressed")
	await _settle()
	var run: Dictionary = scene.get("_run_state")
	var reward: Dictionary = run.get("pending_reward", {})
	var after: Dictionary = reward.get("board_state", {})
	_expect(run["mode"] == "reward" and not reward.get("cards", []).is_empty(), "Last-enemy win grants reward choices")
	_expect(not after.is_empty() and after["traps"].is_empty(), "Storm triggers the occupied trap")
	_expect(after.get("surface_events", []).any(func(event: Dictionary) -> bool: return event.get("kind") == "battlefield_rule_fired"), "Committed Storm beat fired")
	var held: bool = false
	var progressed: bool = false
	var continuous: bool = true
	var rewarded_after_death: bool = true
	for sample: Dictionary in samples:
		var progress: float = sample["death_progress"]
		if sample["reward"]:
			rewarded_after_death = rewarded_after_death and progressed and progress < 0.0
		elif held and sample["living"]:
			continuous = false
		elif not held and not sample["living"] and progress < 0.0:
			continuous = false
		held = held or is_zero_approx(progress)
		progressed = progressed or progress > 0.0
	_expect(held and continuous, "Victim stays through the hit and never returns to its living pose")
	_expect(progressed, "Victim advances its normal death sequence")
	_expect(rewarded_after_death, "Reward appears after the final death pose")
	if scenario == "storm_chain_spawn":
		_check_chain_spawn(after)
	if capture: _expect(death_captured, "Native proof captured an advancing death pose")
	await _capture_next("storm_trap_reward.png")
	_expect(_write_trace(scenario), "Storm frame trace written")
	print("QA91_STORM held=%s progressed=%s continuous=%s reward_after_death=%s" % [held, progressed, continuous, rewarded_after_death])


func _check_chain_spawn(after: Dictionary) -> void:
	var chain_seen: bool = false
	var progressed_at: Dictionary = {}
	for index: int in range(samples.size()):
		var sample: Dictionary = samples[index]
		chain_seen = chain_seen or sample["chain"]
		for id: int in sample["deaths"]:
			if not progressed_at.has(id) and float(sample["deaths"][id]) > 0.0: progressed_at[id] = index
	var arrivals: Array = after.get("enemies", []).filter(func(enemy: Dictionary) -> bool: return enemy["type"] == "cinder_droplet")
	_expect(chain_seen and progressed_at.has(2), "Chain arc and its original target's death both play")
	_expect(arrivals.size() == 2 and arrivals.all(func(enemy: Dictionary) -> bool: return int(enemy["hp"]) == 0), "Both split arrivals die on their own traps")
	for enemy: Dictionary in arrivals:
		var progress_index: int = int(progressed_at.get(int(enemy["id"]), -1))
		_expect(progress_index > int(progressed_at.get(watched_id, -1)), "Lethal arrival plays after the parent starts its death")
	print("QA91_CHAIN_SPAWN arc=%s progressed_at=%s arrivals=%d" % [chain_seen, progressed_at, arrivals.size()])


func _write_trace(scenario: String) -> bool:
	var file := FileAccess.open(output.path_join(scenario + ".json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(samples, "\t"))
	return true


func _observe() -> void:
	if watched_id < 0 or not is_instance_valid(scene): return
	var board: Node = scene.get("board_view")
	var shown: Dictionary = board.get("presentation")
	var state: Dictionary = board.get("combat_state")
	var deaths: Dictionary = {}
	for death: Dictionary in shown.get("death_animation_units", []):
		deaths[int(death.get("id", -1))] = float(death["death_progress"])
	var death_progress: float = float(deaths.get(watched_id, -1.0))
	var living: bool = death_progress < 0.0 and state.get("enemies", []).any(
		func(enemy: Dictionary) -> bool: return int(enemy["id"]) == watched_id and int(enemy["hp"]) > 0)
	var sample: Dictionary = {"death_progress": death_progress, "living": living, "deaths": deaths,
		"chain": shown.get("effect", {}).get("kind") == "chain",
		"reward": scene.get("_run_state").get("mode") == "reward", "rule_contact": shown.get("rule_contact", false),
		"rail_animating": scene.get("_turn_order_animating")}
	if samples.is_empty() or samples.back() != sample: samples.append(sample)
	if capture and not death_captured and death_progress >= PROOF_DEATH_PROGRESS and death_progress < 1.0:
		death_capture_pending = true


func _queue_headless_sample() -> void:
	_defer_headless_sample.call_deferred()


func _defer_headless_sample() -> void:
	_sample_headless.call_deferred()


func _sample_headless() -> void:
	_observe()
	RenderingServer.frame_post_draw.emit()


func _capture_death() -> void:
	if not death_capture_pending: return
	death_capture_pending = false
	death_captured = true
	_save_capture("storm_trap_death.png")


func _capture_next(filename: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_save_capture(filename)


func _save_capture(filename: String) -> void:
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and picture.get_size() == PROOF_SIZE, "Exact 1920x1080 capture")
	if picture != null:
		var path: String = output.path_join(filename)
		_expect(picture.save_png(path) == OK, "Saved " + filename)
		print(path)


func _hunted(certified: Dictionary, before: Dictionary) -> void:
	var witness: Dictionary = certified["qa89_roster_witness"]
	_expect(Difficulty.starter_count(before) == Difficulty.MAX_STARTERS, "Exactly five generated starters")
	_expect(int(witness["raw"].get("encounter_trimmed_enemies", 0)) > 0, "Certified roster already has a trim")
	for index: int in range(before["enemies"].size()):
		var base_hp: int = witness["baseline"]["enemies"][index]["max_hp"]
		var expected: int = ceili(float(base_hp) * 1.2)
		var enemy: Dictionary = before["enemies"][index]
		print("QA91_HUNTED %s baseline=%d expected=%d actual=%d" % [enemy["type"], base_hp, expected, enemy["max_hp"]])
		_expect(enemy["max_hp"] == expected and enemy["hp"] == expected, "Hunted multiplies final baseline Health once for enemy %s" % enemy["id"])
	_expect(before.get(Omens.START_APPLIED_KEY, []).count("hunted") == 1, "Hunted feedback applies once")
	_expect(scene.get("_omen_badges").badges.has("hunted"), "Production HUD shows the Hunted badge")
	var engine := Combat.new()
	var targets: Array[Vector2i] = engine.player_movement_targets(before)
	_expect(not targets.is_empty(), "Mid-fight move offered")
	if not targets.is_empty():
		scene.call("_begin_player_movement_selection")
		scene.call("_on_board_tile_clicked", targets[0])
		await _settle()
	var mid: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	_expect(mid != before, "Production input changes the fight before saving")
	scene.call("_save_run_progress")
	scene.queue_free()
	await process_frame
	await process_frame
	await _resume()
	var resumed: Dictionary = scene.get("_combat_state")
	_expect(resumed["enemies"] == mid["enemies"], "Mid-fight Health survives save and Continue")
	_expect(resumed.get("difficulty_stats", {}) == mid.get("difficulty_stats", {}), "Frozen arrival table survives Continue")
	var arrival_before: Dictionary = engine._spawned_enemy_entry(mid, "crawler", ARRIVAL_TEST_ID, ARRIVAL_TEST_TILE, false)
	var arrival_after: Dictionary = engine._spawned_enemy_entry(resumed, "crawler", ARRIVAL_TEST_ID, ARRIVAL_TEST_TILE, false)
	_expect(arrival_before["max_hp"] == arrival_after["max_hp"], "Arrival Health survives Continue")
	_expect(scene.get("_omen_badges").badges.has("hunted"), "Hunted badge survives Continue")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
