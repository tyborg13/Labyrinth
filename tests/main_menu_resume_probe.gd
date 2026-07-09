extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

const PROGRESSION_PATH: String = "user://main_menu_resume_probe_progression.json"
const RUN_PATH: String = "user://main_menu_resume_probe_run.save"
const OUTPUT_DIR: String = "user://probes/main_menu_resume_safety_20260709_v4"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_storage()
	await _capture_valid_save_states()
	await _capture_no_save_state()
	await _capture_corrupt_save_state()
	_cleanup_storage()
	await process_frame
	await process_frame
	var steam_service: Node = root.get_node_or_null("SteamService")
	if steam_service != null:
		root.remove_child(steam_service)
		steam_service.free()
	AssetLoader._audio_cache.clear()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture_valid_save_states() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 91
	progression["level"] = 4
	ProgressionStore.save_data(progression)
	var run_state: Dictionary = RunEngine.new().create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["player_hp"] = 175
	run_state["player_max_hp"] = 260
	run_state["held_embers"] = 74
	run_state["unbanked_embers"] = 74
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 175
	player["max_hp"] = 260
	combat_state["player"] = player
	run_state["combat_state"] = combat_state
	ProgressionStore.save_run_state(run_state)
	var instance: Node = await _instantiate_menu()
	await _save_screenshot("%s/valid_resume.png" % OUTPUT_DIR)
	instance.call("_on_start_button_pressed")
	await process_frame
	await _save_screenshot("%s/replacement_confirmation.png" % OUTPUT_DIR)
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _capture_no_save_state() -> void:
	ProgressionStore.clear_saved_run()
	var instance: Node = await _instantiate_menu()
	await _save_screenshot("%s/no_save.png" % OUTPUT_DIR)
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _capture_corrupt_save_state() -> void:
	var file: FileAccess = FileAccess.open(RUN_PATH, FileAccess.WRITE)
	file.store_var({
		"seed": 9081,
		"mode": "combat",
		"current_room": Vector2i.ZERO,
		"current_room_layout": {"width": 9, "height": 9},
		"rooms": {"0,0": {"coord": Vector2i.ZERO, "depth": 0, "type": "combat"}},
		"deck_cards": ["quick_stab"],
		"player_hp": 50,
		"player_max_hp": 100,
		"held_embers": 10,
		"unbanked_embers": 10,
		"combat_state": {}
	}, false)
	file.close()
	var instance: Node = await _instantiate_menu()
	await _save_screenshot("%s/corrupt_save.png" % OUTPUT_DIR)
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _instantiate_menu() -> Node:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance

func _save_screenshot(path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s (error %d)" % [path, error])

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION_PATH))

func _stop_menu_music(instance: Node) -> void:
	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player == null:
		return
	music_player.stop()
	music_player.stream = null
