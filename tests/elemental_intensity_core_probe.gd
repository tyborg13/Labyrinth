extends SceneTree

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const OUTPUT_DIR: String = "user://probes/elemental_intensity_core"
const SPENDER_CARDS: Array[String] = [
	"inferno_ritual",
	"hush_of_winter",
	"storm_relay",
	"vacuum_line",
	"spike_mantle"
]

var _errors: Array[String] = []
var _stamp: int = 0


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_stamp = int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://labyrinth_progression_elemental_intensity_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_elemental_intensity_probe.save")
	ProgressionStore.clear_saved_run()
	print("Capturing funded spender cards...")
	await _capture_spender_cards(true)
	print("Capturing starved spender cards...")
	await _capture_spender_cards(false)
	print("Capturing changed-card scope sheet...")
	await _capture_changed_card_scope_sheet()
	print("Capturing Stirring room...")
	await _capture_intensity_room(1, "stirring")
	print("Capturing Volatile room...")
	await _capture_intensity_room(4, "volatile")
	if _errors.is_empty():
		print("ELEMENTAL INTENSITY VISUAL PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for message: String in _errors:
			push_error(message)
		print("ELEMENTAL INTENSITY VISUAL PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)


func _capture_spender_cards(funded: bool) -> void:
	var state_name: String = "funded" if funded else "starved"
	await _capture_card_sheet(funded, "INTENSITY SPENDERS — %s" % state_name.to_upper(), "spenders_%s" % state_name)


func _capture_changed_card_scope_sheet() -> void:
	await _capture_card_sheet(true, "ELEMENTAL INTENSITY — CHANGED CARDS", "changed_cards")


func _capture_card_sheet(funded: bool, heading_text: String, output_stem: String) -> void:
	var hidden_run_scene: Node = RunSceneScript.new()
	var viewport := _production_viewport()
	var background := ColorRect.new()
	background.name = "SpenderProofBackground"
	background.color = Color("17110e")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	viewport.add_child(background)
	var heading := Label.new()
	heading.text = heading_text
	heading.position = Vector2(0.0, 290.0)
	heading.size = Vector2(1920.0, 32.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", Color("f4dfb8"))
	background.add_child(heading)
	var state: Dictionary = _all_elements_state(funded)
	for index: int in range(SPENDER_CARDS.size()):
		var card_id: String = SPENDER_CARDS[index]
		var display: Dictionary = hidden_run_scene.call("_card_widget_display", card_id, state)
		var slot := Control.new()
		slot.position = Vector2(322.0 + float(index) * 255.0, 335.0)
		slot.custom_minimum_size = Vector2(250.0, 352.0)
		slot.size = Vector2(250.0, 352.0)
		background.add_child(slot)
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = Vector2(250.0, 352.0)
		widget.size = Vector2(250.0, 352.0)
		slot.add_child(widget)
		widget.configure(card_id, false, false, true, false, false, funded, GameData.card_def(card_id))
		widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
		widget.call("_refresh_intensity_spend_frame")
		var spend_frame: Control = widget.get_node_or_null("IntensitySpendFrame") as Control
		_expect(spend_frame != null and spend_frame.visible, "%s should render its inward spend frame" % card_id)
		if spend_frame != null:
			_expect(bool(spend_frame.get("payable")) == funded, "%s spend frame should reflect funded=%s" % [card_id, str(funded)])
		var spend_token: Dictionary = _spend_token(display.get("summary_rows", []))
		_expect(not spend_token.is_empty() and str(spend_token.get("value", "")).begins_with("-"), "%s should show a negative elemental cost" % card_id)
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await _save_viewport(viewport, "%s_%d.png" % [output_stem, _stamp])
	viewport.queue_free()
	hidden_run_scene.free()
	await process_frame


func _capture_intensity_room(intensity: int, band_name: String) -> void:
	var viewport := _production_viewport()
	var background := ColorRect.new()
	background.color = Color("100d0b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	viewport.add_child(background)
	var board: Control = CombatBoardView.new()
	board.position = Vector2(320.0, 120.0)
	board.size = Vector2(1280.0, 840.0)
	background.add_child(board)
	board.set_process(false)
	var state: Dictionary = _room_state(intensity)
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "Fire intensity %d — %s" % [intensity, band_name.capitalize()], "Trap and intent values are live", {}, {}, {})
	await process_frame
	await process_frame
	var particle_count: int = int(board.call("_ambient_particle_count", ElementData.FIRE, 72, intensity))
	var expected_trap_damage: int = CombatEngine.new().trap_damage(state, (state.get("traps", []) as Array)[0] as Dictionary)
	if intensity == 1:
		_expect(expected_trap_damage == 9, "Stirring visual fixture should show the lower 9-damage trap")
	else:
		_expect(expected_trap_damage == 21, "Volatile visual fixture should show the 21-damage trap")
		_expect(particle_count > int(board.call("_ambient_particle_count", ElementData.FIRE, 72, 1)) * 1.5, "Volatile room should visibly increase particle density")
	var rows: Array = board.call("_intent_rows", _intent("cinder_ooze", "cinder_bloom"))
	var bonus_active: bool = _condition_active(rows, "intensity_requirement")
	_expect(bonus_active == (intensity >= 2), "Cinder Bloom gate row should track the live Fire intensity")
	await _save_viewport(viewport, "room_%s_%d.png" % [band_name, _stamp])
	viewport.queue_free()
	await process_frame


func _all_elements_state(funded: bool) -> Dictionary:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(81993, {
		"name": "Spender Proof",
		"type": "combat",
		"depth": 3,
		"element": ElementData.FIRE,
		"grid": _grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 140, "max_hp": 140, "block": 0}],
		"loot": []
	}, {"hp": 24, "max_hp": 24, "deck_cards": SPENDER_CARDS, "relics": [], "hand_size": 5, "heal_bonus": 0})
	state["elemental_intensity"] = {
		ElementData.FIRE: 2 if funded else 0,
		ElementData.ICE: 2 if funded else 0,
		ElementData.LIGHTNING: 2 if funded else 0,
		ElementData.AIR: 2 if funded else 0,
		ElementData.EARTH: 3 if funded else 0
	}
	return state


func _room_state(intensity: int) -> Dictionary:
	var enemy_def: Dictionary = GameData.enemy_def("cinder_ooze")
	return {
		"name": "Cinder Pressure Chamber",
		"room_coord": Vector2i(9, -3),
		"room_depth": 3,
		"room_type": "combat",
		"room_element": ElementData.FIRE,
		"elemental_intensity": {ElementData.FIRE: intensity, ElementData.ICE: 0, ElementData.LIGHTNING: 0, ElementData.AIR: 0, ElementData.EARTH: 0},
		"grid": _grid(),
		"moss": {},
		"player": {"pos": Vector2i(2, 4), "hp": 240, "max_hp": 240, "block": 20, "stoneskin": 0, "burn": 0, "bleed": 0},
		"enemies": [{
			"id": 1,
			"type": "cinder_ooze",
			"pos": Vector2i(5, 3),
			"hp": int(enemy_def.get("max_hp", 140)),
			"max_hp": int(enemy_def.get("max_hp", 140)),
			"block": 0,
			"stoneskin": 0,
			"intent": _intent("cinder_ooze", "cinder_bloom")
		}],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(3, 2), "hp": 8, "max_hp": 8}],
		"traps": [{"id": "fire_pressure_trap", "element": ElementData.FIRE, "pos": Vector2i(4, 4), "base_damage": 10, "damage": 10, "burn": 2, "armed": true}],
		"current_actor": {"kind": "player", "actor_key": "player"},
		"turn_order": [],
		"umbra": {"stage": "clear"}
	}


func _intent(enemy_type: String, intent_id: String) -> Dictionary:
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) == TYPE_DICTIONARY and str((intent_var as Dictionary).get("id", "")) == intent_id:
			return (intent_var as Dictionary).duplicate(true)
	return {}


func _spend_token(rows: Array) -> Dictionary:
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		for token_var: Variant in row_var as Array:
			if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("kind", "")) == "intensity_spend":
				return token_var as Dictionary
	return {}


func _condition_active(rows: Array, kind: String) -> bool:
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		for token_var: Variant in row_var as Array:
			if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("kind", "")) == kind:
				return bool((token_var as Dictionary).get("condition_active", false))
	return false


func _grid() -> Array:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 6 else "floor")
		grid.append(row)
	return grid


func _production_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(viewport)
	return viewport


func _save_viewport(viewport: SubViewport, file_name: String) -> void:
	var image: Image = viewport.get_texture().get_image()
	var production_size := Vector2i(1920, 1080)
	var path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.get_size() == production_size, "%s should capture the production 1920x1080 viewport" % file_name)
	_expect(image.save_png(path) == OK, "%s should save successfully" % file_name)
	print(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
