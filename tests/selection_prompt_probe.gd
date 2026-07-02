extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://selection_prompt_probe"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_selection_prompt_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_selection_prompt_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_selection_prompts()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_selection_prompts() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for selection prompt probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	await _capture_reward_prompt(instance)
	await _capture_treasure_prompt(instance)

	instance.queue_free()
	await process_frame

func _capture_reward_prompt(instance: Node) -> void:
	var probe_run_engine := RunEngine.new()
	var base_state: Dictionary = probe_run_engine.create_new_run(321, ProgressionStore.default_data())
	var reward_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, Vector2i(1, 0), "reward", Vector2i(1, 0))
	reward_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash", "patch_up"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.call("_load_run_state", reward_state)
	await _settle_prompt()
	_assert_prompt_ready(instance, "GROW YOUR POWER")
	var shimmer_start: String = _shimmer_text(instance)
	await _save_root_screenshot("%s/reward_prompt.png" % OUTPUT_DIR)
	await _advance_prompt_motion(1.15)
	var shimmer_after: String = _shimmer_text(instance)
	if shimmer_start == shimmer_after:
		_fail("Expected reward prompt shimmer to advance over time")
	await _save_root_screenshot("%s/reward_prompt_shimmer.png" % OUTPUT_DIR)

func _capture_treasure_prompt(instance: Node) -> void:
	var probe_run_engine := RunEngine.new()
	var base_state: Dictionary = probe_run_engine.create_new_run(321, ProgressionStore.default_data())
	var treasure_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "treasure")
	if treasure_coord == Vector2i.ZERO:
		_fail("Probe run should include a treasure room")
		return
	var treasure_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, treasure_coord, "treasure", Vector2i(1, 0))
	treasure_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	instance.call("_load_run_state", treasure_state)
	await _settle_prompt()
	_assert_prompt_ready(instance, "CLAIM YOUR TREASURE")
	await _save_root_screenshot("%s/treasure_prompt.png" % OUTPUT_DIR)

func _assert_prompt_ready(instance: Node, expected_text: String) -> void:
	var prompt_title: Label = instance.get("_relic_choice_title") as Label
	var prompt_effect: Control = instance.get("_relic_choice_title_effect") as Control
	if prompt_title == null or not prompt_title.visible or prompt_title.text != expected_text:
		_fail("Expected visible selection prompt title: %s" % expected_text)
	if prompt_effect == null or not prompt_effect.visible:
		_fail("Expected visible animated title effect for: %s" % expected_text)
	var shimmer_label: RichTextLabel = null
	if prompt_effect != null:
		shimmer_label = prompt_effect.get_node_or_null("TreasureTitleShimmer") as RichTextLabel
	if shimmer_label == null or not shimmer_label.bbcode_enabled:
		_fail("Expected glyph shimmer layer for: %s" % expected_text)

func _shimmer_text(instance: Node) -> String:
	var prompt_effect: Control = instance.get("_relic_choice_title_effect") as Control
	if prompt_effect == null:
		return ""
	var shimmer_label := prompt_effect.get_node_or_null("TreasureTitleShimmer") as RichTextLabel
	if shimmer_label == null:
		return ""
	return shimmer_label.text

func _settle_prompt() -> void:
	root.warp_mouse(Vector2(8.0, 8.0))
	await process_frame
	await process_frame
	await process_frame

func _advance_prompt_motion(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame

func _run_state_for_room(probe_run_engine: RunEngine, source_state: Dictionary, coord: Vector2i, mode: String, travel_dir: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = mode == "room"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _first_room_coord_of_type(probe_run_engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(probe_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	_clear_probe_output_absolute(absolute_dir)

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
