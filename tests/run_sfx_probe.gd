extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunSfxLibrary = preload("res://scripts/run_sfx_library.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://run_sfx_probe_v1"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_run_sfx_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_run_sfx_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_run_sfx_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	_configure_window()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_states()
	print("RUN_SFX_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _configure_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)

func _capture_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for run SFX visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")

	var door_done: Dictionary = {"done": false}
	_track_door_sequence(instance, door_done)
	await create_timer(0.42).timeout
	var door_presentation: Dictionary = (instance.get("_board_presentation") as Dictionary).get("door_opening", {}) as Dictionary
	_assert(not door_presentation.is_empty(), "Door proof should capture the real opening animation")
	_assert(_has_played_sfx(instance, RunSfxLibrary.DOOR_OPEN_ID, true), "Door proof should capture the creak while it is playing")
	await _save_root_screenshot("%s/01_door_opening_audio_sync_1920x1080_ui100.png" % OUTPUT_DIR)
	await _wait_for_completion(door_done, 2.0, "door opening")

	var engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	var base_state: Dictionary = engine.create_new_run(89173, progression)
	var campfire_coord: Vector2i = _first_room_coord_of_type(engine, base_state, "campfire")
	_assert(campfire_coord != Vector2i.ZERO, "Run SFX probe should locate a campfire room")
	if campfire_coord != Vector2i.ZERO:
		var campfire_state: Dictionary = _run_state_for_room(engine, base_state, campfire_coord, "campfire")
		instance.call("_load_run_state", campfire_state)
		await _settle()
		var ambient_player: AudioStreamPlayer = instance.get("_ambient_sfx_player") as AudioStreamPlayer
		_assert(ambient_player != null and ambient_player.playing, "Campfire proof should capture the active fire ambience")
		if ambient_player != null and ambient_player.stream is AudioStreamWAV:
			_assert((ambient_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Campfire proof should use the sample-accurate loop stream")
		else:
			_fail("Campfire proof should expose its looped WAV stream")
		await _save_root_screenshot("%s/02_campfire_looping_audio_1920x1080_ui100.png" % OUTPUT_DIR)

	var reward_state: Dictionary = _combat_reward_state(engine)
	var victory_board: Dictionary = ((reward_state.get("pending_reward", {}) as Dictionary).get("board_state", {}) as Dictionary).duplicate(true)
	instance.call("_load_run_state", reward_state)
	await _settle()
	await _save_root_screenshot("%s/03_reward_offer_before_accepted_audio_1920x1080_ui100.png" % OUTPUT_DIR)
	await instance.call("_on_reward_card_pressed", "frostbolt")
	_assert(_has_played_sfx(instance, RunSfxLibrary.REWARD_ACCEPTED_ID), "Card claim proof should emit the accepted-reward cue")

	var victory_done: Dictionary = {"done": false, "elapsed": 0.0}
	_track_victory_sequence(instance, victory_board, victory_done)
	await create_timer(0.72).timeout
	var victory_overlay: Control = instance.get("_post_combat_victory_overlay") as Control
	_assert(victory_overlay != null and victory_overlay.visible, "Victory proof should capture the visible Victory text")
	_assert(_has_played_sfx(instance, RunSfxLibrary.VICTORY_RESOLUTION_ID, true), "Victory proof should capture the resolution cue while it is playing")
	await _save_root_screenshot("%s/04_victory_resolution_audio_sync_1920x1080_ui100.png" % OUTPUT_DIR)
	await _wait_for_completion(victory_done, 6.0, "victory resolution")
	var victory_cue_seconds: float = float(RunSfxLibrary.entry(RunSfxLibrary.VICTORY_RESOLUTION_ID).get("trimmed_duration", 0.0))
	var captured_wall_seconds: float = float(victory_done.get("elapsed", 0.0))
	print("VICTORY_CAPTURE_WALL_SECONDS=%.3f cue=%.3f" % [captured_wall_seconds, victory_cue_seconds])
	# PNG readback/encoding deliberately stalls this visual probe's main thread.
	# The headless live timing test owns the tight no-dead-space bound; here we
	# only reject a visibly added timer beyond that known capture overhead.
	_assert(captured_wall_seconds >= victory_cue_seconds - 0.06 and captured_wall_seconds <= victory_cue_seconds + 0.90, "Victory visual proof should not add a second linger after the cue")
	_assert(victory_overlay != null and not victory_overlay.visible, "Victory overlay should clear immediately after the audio-backed sequence")

	instance.queue_free()
	await process_frame

func _track_door_sequence(instance: Node, completion: Dictionary) -> void:
	await instance.call("_play_door_opening_animation", Vector2i(4, 0))
	completion["done"] = true

func _track_victory_sequence(instance: Node, board_state: Dictionary, completion: Dictionary) -> void:
	var started_msec: int = Time.get_ticks_msec()
	await instance.call("_play_post_combat_victory", board_state)
	completion["elapsed"] = float(Time.get_ticks_msec() - started_msec) / 1000.0
	completion["done"] = true

func _wait_for_completion(completion: Dictionary, timeout_seconds: float, label: String) -> void:
	var started_msec: int = Time.get_ticks_msec()
	while not bool(completion.get("done", false)):
		if float(Time.get_ticks_msec() - started_msec) / 1000.0 >= timeout_seconds:
			_fail("Timed out waiting for %s" % label)
			return
		await create_timer(0.02).timeout

func _run_state_for_room(engine: RunEngine, source_state: Dictionary, coord: Vector2i, mode: String) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [coord.x, coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _combat_reward_state(engine: RunEngine) -> Dictionary:
	var state: Dictionary = engine.create_new_run(89179, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_room_coord_of_type(engine, state, "combat")
	_assert(combat_coord != Vector2i.ZERO, "Run SFX probe should expose an available combat room")
	if combat_coord == Vector2i.ZERO:
		return state
	state = engine.move_to_room(state, combat_coord)
	if str(state.get("mode", "")) == RunEngine.MODE_PRE_BATTLE:
		state = engine.begin_pre_battle_combat(state)
	var victory_state: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	var enemies: Array = (victory_state.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	victory_state["enemies"] = enemies
	state = engine.finish_combat(state, victory_state)
	_assert(str(state.get("mode", "")) == "reward", "Run SFX probe combat should resolve into a reward")
	var pending_reward: Dictionary = (state.get("pending_reward", {}) as Dictionary).duplicate(true)
	pending_reward["cards"] = ["spark_dart", "frostbolt", "firebrand_volley"]
	pending_reward["heal_amount"] = RunEngine.REWARD_HEAL
	pending_reward["ember_amount"] = 0
	pending_reward["intro_pending"] = false
	state["pending_reward"] = pending_reward
	state["player_hp"] = 12
	state["player_max_hp"] = 24
	return state

func _first_available_room_coord_of_type(engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for coord_var: Variant in engine.available_moves(state):
		var coord: Vector2i = coord_var as Vector2i
		if str(engine.room_metadata(state, coord).get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _first_room_coord_of_type(engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO

func _has_played_sfx(instance: Node, sfx_id: String, require_playing: bool = false) -> bool:
	for player_var: Variant in instance.get("_sfx_players") as Array:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player == null or str(player.get_meta("sfx_id", "")) != sfx_id:
			continue
		if not require_playing or player.playing:
			return true
	return false

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Run SFX proof should capture a renderer image")
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	if not is_equal_approx(scale_x, scale_y):
		_fail("Run SFX proof should preserve 1920x1080 proportions, got %s" % source_size)
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."] or dir.current_is_dir():
			continue
		DirAccess.remove_absolute(absolute_dir.path_join(entry))
	dir.list_dir_end()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
