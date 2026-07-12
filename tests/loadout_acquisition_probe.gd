extends SceneTree

const ElementData = preload("res://scripts/element_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://loadout_acquisition_probe"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_loadout_acquisition_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_loadout_acquisition_probe.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	await _capture_acquisitions()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_acquisitions() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")

	var engine := RunEngine.new()
	var reward_state: Dictionary = engine.create_new_run(9137, ProgressionStore.default_data())
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["spark_dart", "frostbolt", "threaded_path"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.call("_load_run_state", reward_state)
	await _settle()
	_suppress_room_dialogue(instance)
	var reward_widget: Control = _reward_widget(instance, "spark_dart")
	if reward_widget == null:
		_fail("Spark Dart reward widget should be visible")
	else:
		create_timer(0.16).timeout.connect(_capture_named_phase.bind(instance, "magic", "flair"))
		create_timer(0.68).timeout.connect(_capture_named_phase.bind(instance, "magic", "ray"))
		await instance.call("_on_reward_card_pressed", "spark_dart", reward_widget)
		await _settle()
		var badge: Control = instance.get("_loadout_badge") as Control
		if badge == null or not badge.visible:
			_fail("Claimed spell should leave the loadout badge visible")
		await _save_root_screenshot("%s/magic_after_badge.png" % OUTPUT_DIR)

	var room_state: Dictionary = engine.create_new_run(9138, ProgressionStore.default_data())
	room_state["mode"] = "room"
	instance.call("_load_run_state", room_state)
	await _settle()
	_suppress_room_dialogue(instance)
	create_timer(0.16).timeout.connect(_capture_named_phase.bind(instance, "equipment", "flair"))
	create_timer(0.68).timeout.connect(_capture_named_phase.bind(instance, "equipment", "ray"))
	await instance.call("_animate_equipment_pickup_acquisition_flair", "ward_kite", Vector2i(4, 4))
	room_state = instance.get("_run_state") as Dictionary
	room_state[RunEngine.UNREAD_LOADOUT_EQUIPMENT_KEY] = ["ward_kite"]
	instance.set("_run_state", room_state)
	instance.call("_refresh_loadout_badge")
	await _settle()
	await _save_root_screenshot("%s/equipment_after_badge.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _capture_named_phase(instance: Node, kind: String, phase: String) -> void:
	var expected_node_name: String = "LoadoutAcquisitionBurst" if phase == "flair" else "LoadoutAcquisitionBeam"
	if instance.find_child(expected_node_name, true, false) == null:
		_fail("%s %s should render %s" % [kind, phase, expected_node_name])
	await _save_root_screenshot("%s/%s_%s.png" % [OUTPUT_DIR, kind, phase])

func _reward_widget(instance: Node, card_id: String) -> Control:
	var hand_box: Control = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox") as Control
	for child: Node in hand_box.get_children():
		if str(child.get_meta("reward_card_id", "")) != card_id:
			continue
		return child.find_child("CardWidget", true, false) as Control
	return null

func _suppress_room_dialogue(instance: Node) -> void:
	instance.call("_close_dialogue")
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	var engine := RunEngine.new()
	var room: Dictionary = engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	instance.set("_last_auto_dialogue_key", instance.call("_dialogue_trigger_key", room))

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		_fail("Could not save %s" % output_path)

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
