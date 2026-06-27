extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

func _initialize() -> void:
	print("turn order projection probe: start")
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://probes")
	ProgressionStore.set_storage_path("user://labyrinth_progression_projection_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_projection_probe.save")
	ProgressionStore.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(123, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = _first_combat_coord(run_engine, run_state)
	if combat_coord == Vector2i.ZERO:
		_fail("No combat room available for turn order projection probe.")
		return
	print("turn order projection probe: entering combat")
	instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.95).timeout
	await process_frame
	await process_frame
	print("turn order projection probe: combat ready")
	var card_index: int = _first_selectable_card_index(instance)
	if card_index < 0:
		_fail("No selectable playable card available for turn order projection probe.")
		return
	var combat_state: Dictionary = instance.get("_combat_state")
	var combat_engine = instance.get("_combat_engine")
	var card_id: String = str(instance.call("_card_id_for_hand_index", card_index))
	var card_def: Dictionary = instance.call("_card_def", card_id, combat_state)
	var expected_name: String = str(card_def.get("name", card_id))
	var expected_time: int = int(combat_engine.card_time_cost_from_def(card_def))
	_assert_no_card_projection(instance)
	await _save_root_screenshot("user://probes/turn_order_projection_00_before.png")
	instance.call("_on_card_hover_started", card_index)
	await process_frame
	await process_frame
	_assert_card_projection(instance, expected_name, expected_time, "hover")
	await _save_root_screenshot("user://probes/turn_order_projection_01_hover.png")
	var preview: Dictionary = instance.call("_card_preview_for_index", card_index)
	if bool(preview.get("complete", false)):
		_fail("Selected projection proof needs a card that previews before resolving.")
		return
	await instance.call("_begin_card_preview", card_index, preview)
	await process_frame
	await process_frame
	_assert_card_projection(instance, expected_name, expected_time, "selected")
	await _save_root_screenshot("user://probes/turn_order_projection_02_selected.png")
	print("turn order projection probe: card %s time %d" % [expected_name, expected_time])
	print(ProjectSettings.globalize_path("user://probes"))
	instance.queue_free()
	await process_frame
	quit()

func _first_combat_coord(run_engine: RefCounted, run_state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			return coord
	return Vector2i.ZERO

func _first_selectable_card_index(instance: Node) -> int:
	var combat_state: Dictionary = instance.get("_combat_state")
	var hand: Array = (combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		var preview: Dictionary = instance.call("_card_preview_for_index", index)
		if bool(preview.get("playable", false)) and not bool(preview.get("complete", false)):
			return index
	return -1

func _assert_no_card_projection(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		_fail("Turn order bar missing before projection.")
		return
	for child: Node in bar.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		if int(slot.get_meta("turn_order_projection_time_cost", 0)) > 0:
			_fail("Turn order showed a card projection before card hover or selection.")
			return

func _assert_card_projection(instance: Node, expected_name: String, expected_time: int, phase: String) -> void:
	var slot: Control = _card_projection_slot(instance, expected_name, expected_time)
	if slot == null:
		_fail("Turn order did not show projected player slot for %s during %s." % [expected_name, phase])
		return
	var tooltip: String = str(slot.get_meta("turn_order_tooltip", ""))
	if not tooltip.contains(expected_name) or not tooltip.contains("+%d time" % expected_time):
		_fail("Projected slot tooltip did not name %s and +%d time during %s." % [expected_name, expected_time, phase])
		return
	var badge: Node = _first_node_named(slot, "ProjectionPreviewBadge")
	if badge == null:
		_fail("Projected slot was missing the visible card/time badge during %s." % phase)
		return
	var labels: Array[Label] = _labels_under(badge)
	for label: Label in labels:
		if label.text.contains(expected_name) and label.text.contains("+%d" % expected_time):
			return
	_fail("Projected slot badge did not name %s and +%d during %s." % [expected_name, expected_time, phase])

func _card_projection_slot(instance: Node, expected_name: String, expected_time: int) -> Control:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		return null
	for child: Node in bar.get_children():
		var slot: Control = child as Control
		if slot == null:
			continue
		if not bool(slot.get_meta("turn_order_projected", false)):
			continue
		if str(slot.get_meta("turn_order_projection_card_name", "")) != expected_name:
			continue
		if int(slot.get_meta("turn_order_projection_time_cost", 0)) != expected_time:
			continue
		return slot
	return null

func _first_node_named(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _first_node_named(child, node_name)
		if found != null:
			return found
	return null

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
