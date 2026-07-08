extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const OUTPUT_DIR: String = "user://probes/intensity_card_glow"
const ELEMENT_SAMPLES: Array = [
	{"element": ElementData.FIRE, "card": "firebrand_volley", "label": "Fire"},
	{"element": ElementData.ICE, "card": "frostbolt", "label": "Ice"},
	{"element": ElementData.LIGHTNING, "card": "spark_dart", "label": "Lightning"},
	{"element": ElementData.AIR, "card": "vacuum_line", "label": "Air"},
	{"element": ElementData.EARTH, "card": "venom_claw", "label": "Earth"}
]

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

	var active_state: Dictionary = _all_elements_combat_state()
	var start_position := Vector2(44.0, 64.0)
	var card_gap: float = -66.0
	for index: int in range(ELEMENT_SAMPLES.size()):
		var sample: Dictionary = ELEMENT_SAMPLES[index]
		var card_id: String = str(sample.get("card", ""))
		var display: Dictionary = instance.call("_card_widget_display", card_id, active_state)
		_add_labeled_card(
			start_position + Vector2(float(index) * (250.0 + card_gap), 0.0),
			"%s active" % str(sample.get("label", "")),
			card_id,
			display,
			index
		)
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

func _add_labeled_card(position: Vector2, label_text: String, card_id: String, display: Dictionary, draw_order: int) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = position + Vector2(0.0, -34.0)
	label.size = Vector2(250.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = ELEMENT_SAMPLES.size() + 12
	label.add_theme_color_override("font_color", Color("f4dfb8"))
	label.add_theme_color_override("font_outline_color", Color("160c07"))
	label.add_theme_constant_override("outline_size", 2)
	root.add_child(label)

	var slot := Control.new()
	slot.position = position
	slot.custom_minimum_size = Vector2(250.0, 352.0)
	slot.size = Vector2(250.0, 352.0)
	slot.z_index = draw_order
	root.add_child(slot)
	var widget: CardWidget = CardWidgetScene.instantiate()
	widget.custom_minimum_size = Vector2(250.0, 352.0)
	widget.size = Vector2(250.0, 352.0)
	slot.add_child(widget)
	widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))

func _all_elements_combat_state() -> Dictionary:
	var cards: Array[String] = []
	for sample_var: Variant in ELEMENT_SAMPLES:
		var sample: Dictionary = sample_var
		cards.append(str(sample.get("card", "")))
	var combat := CombatEngine.new()
	var layout: Dictionary = {
		"name": "Intensity Glow Probe",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"element": ElementData.EARTH,
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
	var state: Dictionary = combat.create_combat(15130, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": cards,
		"relics": [],
		"hand_size": cards.size(),
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = cards
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["elemental_intensity"] = {
		ElementData.FIRE: 3,
		ElementData.ICE: 3,
		ElementData.LIGHTNING: 3,
		ElementData.AIR: 3,
		ElementData.EARTH: 3
	}
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
