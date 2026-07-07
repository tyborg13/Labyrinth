extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const OUTPUT_DIR: String = "user://probes/intensity_card_glow"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_intensity_glow_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_intensity_glow_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_intensity_glow_cards()
	quit()

func _capture_intensity_glow_cards() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		push_error("Run scene should load for intensity card glow probe.")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	await process_frame
	await process_frame

	var background := ColorRect.new()
	background.color = Color("1c140f")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	root.add_child(background)

	var active_display: Dictionary = instance.call("_card_widget_display", "venom_claw", _combat_state_for_element(ElementData.EARTH, 15128))
	var inactive_display: Dictionary = instance.call("_card_widget_display", "venom_claw", _combat_state_for_element(ElementData.FIRE, 15129))
	_add_labeled_card(Vector2(104.0, 64.0), "Active: Earth 2+", active_display)
	_add_labeled_card(Vector2(386.0, 64.0), "Inactive: Fire room", inactive_display)
	await process_frame
	await process_frame
	await create_timer(0.10).timeout
	await process_frame

	var stamp: int = int(Time.get_unix_time_from_system())
	var output_path: String = "%s/intensity_card_glow_%d.png" % [OUTPUT_DIR, stamp]
	await _save_root_screenshot(output_path)
	print(ProjectSettings.globalize_path(output_path))
	instance.queue_free()
	background.queue_free()
	await process_frame

func _add_labeled_card(position: Vector2, label_text: String, display: Dictionary) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = position + Vector2(0.0, -34.0)
	label.size = Vector2(250.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("f4dfb8"))
	label.add_theme_color_override("font_outline_color", Color("160c07"))
	label.add_theme_constant_override("outline_size", 2)
	root.add_child(label)

	var slot := Control.new()
	slot.position = position
	slot.custom_minimum_size = Vector2(250.0, 352.0)
	slot.size = Vector2(250.0, 352.0)
	root.add_child(slot)
	var widget: CardWidget = CardWidgetScene.instantiate()
	widget.custom_minimum_size = Vector2(250.0, 352.0)
	widget.size = Vector2(250.0, 352.0)
	slot.add_child(widget)
	widget.configure("venom_claw", false, false, true, false, false, true, GameData.card_def("venom_claw"))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))

func _combat_state_for_element(element_id: String, seed: int) -> Dictionary:
	var combat := CombatEngine.new()
	var layout: Dictionary = {
		"name": "Intensity Glow Probe",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"element": element_id,
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 5),
			"hp": 140,
			"max_hp": 140,
			"block": 0
		}],
		"loot": []
	}
	var state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["venom_claw"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	return state

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "floor")
		grid.append(row)
	return grid

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _clear_probe_output(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		dir.remove(file_name)
	dir.list_dir_end()
