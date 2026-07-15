extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://ember_reward_feedback_probe")
	ProgressionStore.set_storage_path("user://ember_reward_feedback_probe/progression.json")
	ProgressionStore.set_run_storage_path("user://ember_reward_feedback_probe/current_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_feedback()
	quit(0)

func _capture_feedback() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene did not load")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_load_run_state", RunEngine.new().create_new_run(456, ProgressionStore.default_data()))
	await process_frame
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	var run_engine = instance.get("_run_engine")
	for coord: Vector2i in run_engine.available_moves(run_state):
		if str((run_engine.room_metadata(run_state, coord) as Dictionary).get("type", "")) == "combat":
			instance.call("_on_map_view_room_selected", coord)
			break
	await create_timer(0.95).timeout
	await process_frame
	instance.call("_on_pre_battle_start_pressed")
	await create_timer(0.20).timeout
	await process_frame
	instance.call("_close_dialogue")
	var fx_layer: Control = instance.get("_card_fx_layer") as Control
	var stats: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/StatsLabel") as Label
	var sprite_count_before: int = _direct_sprite_count(fx_layer)
	var sfx_count_before: int = (instance.get("_sfx_players") as Array).size()
	var death_states: Dictionary = _aggregated_death_reward_states(instance)
	instance.call("_animate_death_rewards", death_states.get("before", {}), death_states.get("after", {}))
	await create_timer(0.07).timeout
	await process_frame
	var gain_label: Label = _ember_gain_label(fx_layer)
	if gain_label == null or gain_label.text != "+18":
		_fail("Expected one combined +18 header label for two death rewards")
		return
	if not stats.get_global_rect().grow(20.0).intersects(gain_label.get_global_rect()):
		_fail("Ember gain label was not attached to the header counter")
		return
	if _direct_sprite_count(fx_layer) != sprite_count_before:
		_fail("Ember feedback spawned a board-traveling sprite")
		return
	if (instance.get("_sfx_players") as Array).size() != sfx_count_before:
		_fail("Ember feedback acquired an SFX channel")
		return
	_save_root_screenshot("user://ember_reward_feedback_probe/ember_counter_roll.png")
	await create_timer(0.28).timeout
	await process_frame
	var expected_total: int = int(death_states.get("expected_total", 58))
	if not stats.text.ends_with("EMBERS %d" % expected_total):
		_fail("Ember counter did not settle on the combined total of %d" % expected_total)
		return
	if _ember_gain_label(fx_layer) != null:
		_fail("Ember gain label lingered after the brief counter roll")
		return
	_save_root_screenshot("user://ember_reward_feedback_probe/ember_counter_settled.png")
	print(ProjectSettings.globalize_path("user://ember_reward_feedback_probe"))
	instance.queue_free()
	await process_frame

func _aggregated_death_reward_states(instance: Node) -> Dictionary:
	var before_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var run_engine = instance.get("_run_engine")
	var held_embers: int = int(run_engine.call("held_embers", instance.get("_run_state")))
	before_state["room_embers"] = 40
	before_state["death_rewards"] = []
	var after_state: Dictionary = before_state.duplicate(true)
	after_state["room_embers"] = 58
	after_state["death_rewards"] = [
		{"embers": 8, "card_plays": 0, "tile": Vector2i(3, 4)},
		{"embers": 10, "card_plays": 0, "tile": Vector2i(5, 4)}
	]
	return {"before": before_state, "after": after_state, "expected_total": held_embers + 58}

func _direct_sprite_count(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is Sprite2D:
			count += 1
	return count

func _ember_gain_label(node: Node) -> Label:
	for child: Node in node.get_children():
		if child is Label and not child.is_queued_for_deletion() and bool(child.get_meta("ember_counter_feedback", false)):
			return child as Label
	return null

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
