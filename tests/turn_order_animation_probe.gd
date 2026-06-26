extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

func _initialize() -> void:
	print("turn order probe: start")
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://probes")
	ProgressionStore.set_storage_path("user://labyrinth_progression_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_probe.save")
	ProgressionStore.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	print("turn order probe: scene ready")
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(123, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	print("turn order probe: run loaded")
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			combat_coord = coord
			break
	if combat_coord == Vector2i.ZERO:
		push_error("No combat room available for turn order animation probe.")
		quit(1)
		return
	print("turn order probe: entering combat")
	instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.95).timeout
	await process_frame
	await process_frame
	print("turn order probe: combat ready")
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	_assert_turn_order_slot_count(instance, 10)
	_assert_turn_order_label(instance)
	_assert_turn_order_badges_match_relative_clocks(instance, combat_state)
	await _save_root_screenshot("user://probes/turn_order_anim_00_before.png")
	var combat_engine = instance.get("_combat_engine")
	var scheduled_state: Dictionary = combat_engine.finish_player_activation(combat_state.duplicate(true))
	print("turn order probe: animating")
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), scheduled_state.duplicate(true))
	await create_timer(0.10).timeout
	await process_frame
	_assert_single_turn_order_exit(instance)
	await _save_root_screenshot("user://probes/turn_order_anim_01_remove.png")
	await create_timer(0.20).timeout
	await process_frame
	_assert_turn_order_width_locked(instance)
	await _save_root_screenshot("user://probes/turn_order_anim_02_reflow.png")
	await create_timer(0.20).timeout
	await process_frame
	await _save_root_screenshot("user://probes/turn_order_anim_03_insert.png")
	await create_timer(0.35).timeout
	await process_frame
	_assert_turn_order_slot_count(instance, 10)
	_assert_turn_order_badges_match_relative_clocks(instance, scheduled_state)
	await _save_root_screenshot("user://probes/turn_order_anim_04_final.png")
	print("turn order probe: done")
	print(ProjectSettings.globalize_path("user://probes"))
	instance.queue_free()
	await process_frame
	quit()

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _assert_single_turn_order_exit(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during animation probe.")
		quit(1)
		return
	var exiting: int = 0
	for child_index: int in range(bar.get_child_count()):
		var child: Control = bar.get_child(child_index) as Control
		if child == null:
			continue
		if child.position.y < -2.0 or child.modulate.a < 0.98:
			exiting += 1
	if exiting != 1:
		push_error("Expected exactly one turn order entry exiting; found %d." % exiting)
		quit(1)

func _assert_turn_order_width_locked(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during animation probe.")
		quit(1)
		return
	var locked_width: float = float(instance.get("_turn_order_panel_locked_width"))
	if locked_width <= 0.0:
		push_error("Turn order panel width was not locked during animation.")
		quit(1)
		return
	if absf(panel.custom_minimum_size.x - locked_width) > 0.5:
		push_error("Turn order panel width changed during animation.")
		quit(1)

func _assert_turn_order_slot_count(instance: Node, max_count: int) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during slot-count probe.")
		quit(1)
		return
	if bar.get_child_count() > max_count:
		push_error("Turn order bar showed %d slots; expected at most %d." % [bar.get_child_count(), max_count])
		quit(1)

func _assert_turn_order_label(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during label probe.")
		quit(1)
		return
	var labels: Array[Label] = _labels_under(panel)
	for label: Label in labels:
		if label.text == "TURN\nCLOCK":
			return
	push_error("Turn order panel should be labeled TURN CLOCK.")
	quit(1)

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _assert_turn_order_badges_match_relative_clocks(instance: Node, state: Dictionary) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var combat_engine = instance.get("_combat_engine")
	if bar == null or combat_engine == null:
		push_error("Turn order bar or combat engine missing during badge probe.")
		quit(1)
		return
	var order: Array = combat_engine.current_turn_order(state, 12)
	if order.is_empty() or bar.get_child_count() == 0:
		push_error("Turn order badge probe found no entries.")
		quit(1)
		return
	var count: int = mini(order.size(), bar.get_child_count())
	for index: int in range(count):
		var child: Control = bar.get_child(index) as Control
		if child == null:
			continue
		var entry: Dictionary = order[index] as Dictionary
		var expected: String = str(int(entry.get("eta", 0)))
		var actual: String = str(child.get_meta("turn_order_badge_text", ""))
		if actual != expected:
			push_error("Turn order badge %d showed %s, expected relative clock %s." % [index, actual, expected])
			quit(1)
			return
