extends SceneTree

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://probes/save_resume_inspection_20260709_v10"

var _combat_engine: CombatEngine = CombatEngine.new()

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://save_resume_inspection_progression.json")
	ProgressionStore.set_run_storage_path(ProgressionStore.DEFAULT_RUN_STORAGE_PATH)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var use_existing_fixture: bool = args.has("--use-existing-fixture")
	var functional_only: bool = args.has("--functional-only")
	if use_existing_fixture:
		var existing_fixture: Dictionary = ProgressionStore.load_saved_run()
		_assert(not existing_fixture.is_empty(), "Existing-fixture mode requires current_run.save")
		_assert(typeof(existing_fixture.get("inspection_fixture", null)) == TYPE_DICTIONARY, "Existing-fixture mode requires inspection metadata")
	else:
		_seed_probe_fixture()
	if not functional_only:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	root.size = Vector2i(1440, 900)
	var first: Node = await _resume_run_scene()
	first.set("_settings", {"reduced_motion": true})
	first.call("_close_dialogue")
	if not functional_only:
		root.size = Vector2i(1440, 900)
		await _settle_ui()
		await _save_root_screenshot("%s/01_before_committed_action_1440x900.png" % OUTPUT_DIR)
	var first_combat: Dictionary = (first.get("_combat_state") as Dictionary).duplicate(true)
	var hand: Array = ((first_combat.get("deck", {}) as Dictionary).get("hand", []) as Array)
	var patch_index: int = hand.find("patch_up")
	_assert(patch_index >= 0, "Inspection fixture should open before Patch Up is committed")
	var actions: Array = (_combat_engine.card_def("patch_up", first_combat).get("actions", []) as Array).duplicate(true)
	var resolved: Dictionary = first_combat.duplicate(true)
	for action_var: Variant in actions:
		if typeof(action_var) == TYPE_DICTIONARY:
			resolved = _combat_engine.apply_player_action(resolved, action_var as Dictionary)
	await first.call("_play_player_card", patch_index, resolved, actions, _empty_targets())
	root.size = Vector2i(1280, 800)
	first.call("_refresh_ui")
	await _settle_ui()
	var expected: Dictionary = (first.call("_committed_run_state") as Dictionary).duplicate(true)
	_assert(ProgressionStore.load_saved_run() == expected, "Committed inspection action should be written before quit")
	if not functional_only:
		await _save_root_screenshot("%s/02_after_committed_action_1280x800.png" % OUTPUT_DIR)

	root.remove_child(first)
	first.free()
	await process_frame
	var resumed: Node = await _resume_run_scene()
	resumed.set("_settings", {"reduced_motion": true})
	resumed.call("_close_dialogue")
	root.size = Vector2i(1280, 800)
	resumed.call("_refresh_ui")
	await _settle_ui()
	var resumed_state: Dictionary = (resumed.call("_committed_run_state") as Dictionary).duplicate(true)
	_assert(resumed_state == expected, "Inspection Continue should restore the exact mid-combat committed state")
	_assert(typeof(resumed_state.get("inspection_fixture", null)) == TYPE_DICTIONARY, "Resume should retain inspection namespace metadata")
	var resumed_deck: Dictionary = ((resumed_state.get("combat_state", {}) as Dictionary).get("deck", {}) as Dictionary)
	_assert((resumed_deck.get("burned", []) as Array).has("patch_up"), "Resume should keep the committed exhausted card instead of resetting the fixture")

	resumed.queue_free()
	await process_frame
	var steam_service: Node = root.get_node_or_null("SteamService")
	if steam_service != null:
		root.remove_child(steam_service)
		steam_service.free()
	AssetLoader._audio_cache.clear()
	if not functional_only:
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: PASS — inspection action survives quit/relaunch")
	quit(0)

func _seed_probe_fixture() -> void:
	ProgressionStore.clear_saved_run()
	var progression: Dictionary = ProgressionStore.default_data()
	_assert(ProgressionStore.save_data(progression), "Inspection probe should save progression")
	var fixture: Dictionary = RunEngine.new().create_debug_boss_run(progression)
	fixture["debug_boss_run"] = false
	fixture["inspection_fixture"] = {
		"scenario": "combat",
		"namespace": ParallelRuntime.current_namespace(),
		"summary": "Mid-combat save/resume persistence proof"
	}
	var combat_state: Dictionary = (fixture.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = maxi(1, int(player.get("max_hp", 1)) - 50)
	combat_state["player"] = player
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["patch_up", "quick_stab", "guarded_step", "sidestep_slash"]
	deck["draw"] = ["bloody_lunge", "hamstring_shot"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["cards_played_this_turn"] = 0
	fixture["combat_state"] = combat_state
	_assert(ProgressionStore.save_run_state(fixture), "Inspection probe should seed current_run.save")

func _resume_run_scene() -> Node:
	root.size = Vector2i(1440, 900)
	root.set_meta("labyrinth_resume_saved_run", true)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance

func _empty_targets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	return result

func _settle_ui() -> void:
	for _frame: int in range(10):
		await process_frame
	RenderingServer.force_draw()
	for _frame: int in range(3):
		await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var texture: Texture2D = root.get_viewport().get_texture()
	var image: Image = texture.get_image()
	var target_size: Vector2i = Vector2i(1440, 900) if output_path.contains("1440x900") else Vector2i(1280, 800) if output_path.contains("1280x800") else image.get_size()
	if image.get_size() != target_size:
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	_assert(image.save_png(output_path) == OK, "Should write proof screenshot %s" % output_path)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
