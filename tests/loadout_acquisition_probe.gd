extends SceneTree

const ElementData = preload("res://scripts/element_data.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
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
	print("PROBE: loading run scene")
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	print("PROBE: run scene ready")
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
	print("PROBE: reward fixture ready")
	_suppress_room_dialogue(instance)
	var reward_widget: Control = _reward_widget(instance, "spark_dart")
	if reward_widget == null:
		_fail("Spark Dart reward widget should be visible")
	else:
		create_timer(0.16).timeout.connect(_capture_named_phase.bind(instance, "magic", "flair"))
		create_timer(0.68).timeout.connect(_capture_named_phase.bind(instance, "magic", "ray"))
		await instance.call("_on_reward_card_pressed", "spark_dart", reward_widget)
		await _settle()
		print("PROBE: reward acquisition complete")
		var badge: Control = instance.get("_loadout_badge") as Control
		if badge == null or not badge.visible:
			_fail("Claimed spell should leave the loadout badge visible")
		await _save_root_screenshot("%s/magic_after_badge.png" % OUTPUT_DIR)
		instance.call("_on_loadout_button_pressed")
		await _settle()
		var magic_new_tag: Control = _loadout_new_tag(instance, "magic", "spark_dart")
		if magic_new_tag == null or not magic_new_tag.visible:
			_fail("Claimed spell should show a NEW tag in Learned Magic")
		await _save_root_screenshot("%s/magic_new_tag_before_hover.png" % OUTPUT_DIR)
		instance.call("_on_loadout_asset_hovered", "magic", "spark_dart")
		await _settle()
		if magic_new_tag != null and magic_new_tag.visible:
			_fail("Spell NEW tag should hide after hover")
		await _save_root_screenshot("%s/magic_new_tag_after_hover.png" % OUTPUT_DIR)
		instance.call("_close_card_upgrade_overlay")
		print("PROBE: magic NEW hover complete")

	var room_state: Dictionary = engine.create_new_run(9138, ProgressionStore.default_data())
	var combat_engine := CombatEngine.new()
	var equipment_tile := Vector2i(3, 4)
	var layout: Dictionary = _equipment_combat_layout(equipment_tile)
	var before_combat: Dictionary = combat_engine.create_combat(9138, layout, {
		"hp": int(room_state.get("player_hp", 1)),
		"max_hp": int(room_state.get("player_max_hp", 1)),
		"deck_cards": (room_state.get("deck_cards", []) as Array).duplicate(),
		"relics": [],
		"hand_size": int(room_state.get("hand_size", 5)),
		"heal_bonus": int(room_state.get("heal_bonus", 0)),
		"cards_per_turn": 2,
		"draw_per_turn": 2,
		"card_upgrades": {},
		"card_mods": {}
	})
	room_state["mode"] = "combat"
	room_state["combat_state"] = before_combat
	instance.call("_load_run_state", room_state)
	await _settle()
	print("PROBE: equipment fixture ready")
	_suppress_room_dialogue(instance)
	var blink_action: Dictionary = {"type": "blink", "range": 99}
	var after_combat: Dictionary = combat_engine.apply_player_action(before_combat, blink_action, equipment_tile)
	if not (after_combat.get("collected_equipment", []) as Array).has("ward_kite"):
		_fail("Production combat pickup should collect Ward Kite")
	create_timer(0.56).timeout.connect(_capture_named_phase.bind(instance, "equipment", "flair"))
	create_timer(1.08).timeout.connect(_capture_named_phase.bind(instance, "equipment", "ray"))
	await instance.call("_animate_player_action_step", before_combat, after_combat, "threaded_path", blink_action, equipment_tile)
	print("PROBE: equipment acquisition complete")
	room_state = engine.set_combat_state(room_state, after_combat)
	instance.set("_run_state", room_state)
	instance.set("_combat_state", after_combat)
	instance.call("_refresh_loadout_badge")
	await _settle()
	if engine.loadout_unread_ids(room_state, "equipment") != ["ward_kite"]:
		_fail("Production run-state merge should mark Ward Kite unread")
	await _save_root_screenshot("%s/equipment_after_badge.png" % OUTPUT_DIR)
	instance.call("_on_loadout_button_pressed")
	await _settle()
	var equipment_new_tag: Control = _loadout_new_tag(instance, "equipment", "ward_kite")
	if equipment_new_tag == null or not equipment_new_tag.visible:
		_fail("Collected equipment should show a NEW tag in Gear")
	await _save_root_screenshot("%s/equipment_new_tag_before_hover.png" % OUTPUT_DIR)
	instance.call("_on_loadout_asset_hovered", "equipment", "ward_kite")
	await _settle()
	if equipment_new_tag != null and equipment_new_tag.visible:
		_fail("Equipment NEW tag should hide after hover")
	await _save_root_screenshot("%s/equipment_new_tag_after_hover.png" % OUTPUT_DIR)
	print("PROBE: equipment NEW hover complete")

	instance.queue_free()
	await process_frame

func _capture_named_phase(instance: Node, kind: String, phase: String) -> void:
	var expected_node_name: String = "LoadoutAcquisitionBurst" if phase == "flair" else "LoadoutAcquisitionBeam"
	if instance.find_child(expected_node_name, true, false) == null:
		_fail("%s %s should render %s" % [kind, phase, expected_node_name])
	await _save_root_screenshot("%s/%s_%s.png" % [OUTPUT_DIR, kind, phase])

func _reward_widget(instance: Node, card_id: String) -> Control:
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox") as Control
	for child: Node in hand_box.get_children():
		if str(child.get_meta("reward_card_id", "")) != card_id:
			continue
		return child.find_child("CardWidget", true, false) as Control
	return null

func _loadout_new_tag(instance: Node, mode: String, asset_id: String) -> Control:
	var scrim: Node = instance.get("_upgrade_scrim") as Node
	if scrim == null:
		return null
	for tag_var: Node in scrim.find_children("LoadoutNewTag", "", true, false):
		if str(tag_var.get_meta("loadout_mode", "")) == mode and str(tag_var.get_meta("asset_id", "")) == asset_id:
			return tag_var as Control
	return null

func _equipment_combat_layout(equipment_tile: Vector2i) -> Dictionary:
	return {
		"name": "Acquisition Proof",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 2),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}],
		"loot": [{
			"kind": "equipment",
			"equipment_id": "ward_kite",
			"pos": equipment_tile
		}]
	}

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
