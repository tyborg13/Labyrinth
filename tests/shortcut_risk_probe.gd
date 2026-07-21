extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const INVALID_TARGET_TILE: Vector2i = Vector2i(-999999, -999999)

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://probes"))
	ProgressionStore.set_storage_path("user://labyrinth_progression_shortcut_risk_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_shortcut_risk_probe.save")
	ProgressionStore.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_require(packed != null, "Run scene should load for shortcut risk probe.")
	if _failed:
		quit(1)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await _capture_movement_risk_previews(instance)
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path("user://probes"))
	quit(1 if _failed else 0)

func _capture_movement_risk_previews(instance: Node) -> void:
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	var combat := CombatEngine.new()
	var layout: Dictionary = {
		"name": "Shortcut Risk Probe",
		"coord": Vector2i.ZERO,
		"type": "combat",
		"element": "lightning",
		"grid": _probe_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 140,
			"max_hp": 140,
			"block": 0
		}],
		"traps": [{
			"id": "probe_shock_trap",
			"pos": Vector2i(3, 4),
			"element": "lightning",
			"damage": 4,
			"shock": 1
		}],
		"loot": [{
			"id": "probe_shield",
			"kind": "rusty_shield",
			"pos": Vector2i(4, 4),
			"amount": 5
		}],
		"terrain": []
	}
	var combat_state: Dictionary = combat.create_combat(2231, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["guarded_step", "sidestep_slash"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step", "sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	await _assert_plain_movement_risk_preview(instance, board_view)
	if _failed:
		return
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	await _assert_shortcut_risk_preview(instance, board_view)

func _assert_plain_movement_risk_preview(instance: Node, board_view: Node) -> void:
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	_require(bool(preview.get("playable", false)), "Plain movement risk probe card should be playable.")
	if _failed:
		return
	await instance.call("_begin_card_preview", 0, preview)
	await process_frame
	await process_frame
	var move_tile := Vector2i(4, 4)
	instance.call("_on_board_tile_hovered", move_tile)
	await process_frame
	await process_frame
	var presentation: Dictionary = board_view.get("presentation")
	var path_tiles: Array = presentation.get("path_tiles", [])
	_require(path_tiles.has(Vector2i(3, 4)) and path_tiles.has(Vector2i(4, 4)), "Plain movement hover should show the chosen movement path before commit.")
	var movement_risk_chips: Array = presentation.get("movement_risk_chips", [])
	var chip_labels: Array = _chip_labels(movement_risk_chips)
	_require(chip_labels.has("-4 HP"), "Plain movement hover should preview trap HP loss before commit.")
	_require(chip_labels.has("Shock"), "Plain movement hover should preview trap status before commit.")
	_require(chip_labels.has("+5 Block"), "Plain movement hover should preview pickup gain before commit.")
	var effect: Dictionary = presentation.get("effect", {})
	_require(str(effect.get("kind", "")) == "move", "Plain movement risk hover should remain a move preview.")
	if _failed:
		return
	_save_shortcut_risk_proof("user://probes/run_plain_movement_risk_preview.png", path_tiles, movement_risk_chips, INVALID_TARGET_TILE)
	var label_text := PackedStringArray()
	for label_var: Variant in chip_labels:
		label_text.append(str(label_var))
	print("Plain movement risk preview labels: %s" % ", ".join(label_text))

func _assert_shortcut_risk_preview(instance: Node, board_view: Node) -> void:
	var preview: Dictionary = instance.call("_card_preview_for_index", 1)
	_require(bool(preview.get("playable", false)), "Shortcut risk probe card should be playable.")
	if _failed:
		return
	await instance.call("_begin_card_preview", 1, preview)
	await process_frame
	await process_frame
	var enemy_tile := Vector2i(5, 4)
	instance.call("_on_board_tile_hovered", enemy_tile)
	await process_frame
	await process_frame
	var presentation: Dictionary = board_view.get("presentation")
	var path_tiles: Array = presentation.get("path_tiles", [])
	_require(path_tiles.has(Vector2i(3, 4)) and path_tiles.has(Vector2i(4, 4)), "Shortcut hover should show the movement path to the attack position.")
	var movement_risk_chips: Array = presentation.get("movement_risk_chips", [])
	var chip_labels: Array = _chip_labels(movement_risk_chips)
	_require(chip_labels.has("-4 HP"), "Shortcut hover should preview trap HP loss before commit.")
	_require(chip_labels.has("Shock"), "Shortcut hover should preview trap status before commit.")
	_require(chip_labels.has("+5 Block"), "Shortcut hover should preview pickup gain before commit.")
	var effect: Dictionary = presentation.get("effect", {})
	_require(not (effect.get("damage_preview", {}) as Dictionary).is_empty(), "Shortcut hover should keep the follow-up attack damage preview visible.")
	if _failed:
		return
	_save_shortcut_risk_proof("user://probes/run_shortcut_risk_preview.png", path_tiles, movement_risk_chips, enemy_tile)
	var label_text := PackedStringArray()
	for label_var: Variant in chip_labels:
		label_text.append(str(label_var))
	print("Shortcut risk preview labels: %s" % ", ".join(label_text))

func _chip_labels(movement_risk_chips: Array) -> Array:
	var labels: Array = []
	for chip_var: Variant in movement_risk_chips:
		if typeof(chip_var) == TYPE_DICTIONARY:
			labels.append(str((chip_var as Dictionary).get("label", "")))
	return labels

func _save_shortcut_risk_proof(output_path: String, path_tiles: Array, movement_risk_chips: Array, enemy_tile: Vector2i) -> void:
	var image: Image = Image.create(720, 420, false, Image.FORMAT_RGBA8)
	image.fill(Color("18120f"))
	for y: int in range(1, 7):
		for x: int in range(1, 7):
			_fill_diamond(image, _proof_tile_center(Vector2i(x, y)), 29, 15, Color("2d2420"))
	for tile_var: Variant in path_tiles:
		if typeof(tile_var) == TYPE_VECTOR2I:
			_fill_diamond(image, _proof_tile_center(tile_var as Vector2i), 29, 15, Color(0.24, 0.67, 0.74, 0.90))
	for index: int in range(maxi(0, path_tiles.size() - 1)):
		if typeof(path_tiles[index]) == TYPE_VECTOR2I and typeof(path_tiles[index + 1]) == TYPE_VECTOR2I:
			_draw_image_line(image, _proof_tile_center(path_tiles[index]), _proof_tile_center(path_tiles[index + 1]), Color("80e4f2"), 4)
	_fill_diamond(image, _proof_tile_center(Vector2i(2, 4)), 23, 12, Color("f1d18b"))
	_fill_diamond(image, _proof_tile_center(Vector2i(3, 4)), 23, 12, Color("d85f54"))
	_fill_diamond(image, _proof_tile_center(Vector2i(4, 4)), 23, 12, Color("83d088"))
	if enemy_tile.x >= 0:
		_fill_diamond(image, _proof_tile_center(enemy_tile), 24, 13, Color("f08c53"))
	var chip_slot_by_tile: Dictionary = {}
	for chip_var: Variant in movement_risk_chips:
		if typeof(chip_var) != TYPE_DICTIONARY:
			continue
		var chip: Dictionary = chip_var
		var tile: Vector2i = chip.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			continue
		var slot: int = int(chip_slot_by_tile.get(tile, 0))
		chip_slot_by_tile[tile] = slot + 1
		var center: Vector2 = _proof_tile_center(tile) + Vector2(0.0, -34.0 - float(slot) * 18.0)
		_fill_chip_rect(image, center, str(chip.get("kind", "")))
	image.save_png(output_path)

func _proof_tile_center(tile: Vector2i) -> Vector2:
	return Vector2(360.0 + float(tile.x - tile.y) * 38.0, 72.0 + float(tile.x + tile.y) * 19.0)

func _fill_diamond(image: Image, center: Vector2, half_width: int, half_height: int, color: Color) -> void:
	for y_offset: int in range(-half_height, half_height + 1):
		var width: int = int(roundf(float(half_width) * (1.0 - absf(float(y_offset)) / float(maxi(1, half_height)))))
		for x_offset: int in range(-width, width + 1):
			_set_image_pixel_safe(image, int(roundf(center.x)) + x_offset, int(roundf(center.y)) + y_offset, color)

func _fill_chip_rect(image: Image, center: Vector2, kind: String) -> void:
	var color: Color = Color("d8b96f")
	match kind:
		"danger":
			color = Color("ef8b62")
		"status":
			color = Color("f3d762")
		"pickup":
			color = Color("83d088")
	var rect := Rect2i(int(center.x) - 34, int(center.y) - 7, 68, 14)
	image.fill_rect(rect.grow(2), Color(0.0, 0.0, 0.0, 0.55))
	image.fill_rect(rect, Color(color.r * 0.36, color.g * 0.36, color.b * 0.36, 1.0))
	for x: int in range(rect.position.x, rect.end.x):
		_set_image_pixel_safe(image, x, rect.position.y, color)
		_set_image_pixel_safe(image, x, rect.end.y - 1, color)
	for y: int in range(rect.position.y, rect.end.y):
		_set_image_pixel_safe(image, rect.position.x, y, color)
		_set_image_pixel_safe(image, rect.end.x - 1, y, color)

func _draw_image_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width: int) -> void:
	var steps: int = maxi(1, int(from_point.distance_to(to_point)))
	for step: int in range(steps + 1):
		var point: Vector2 = from_point.lerp(to_point, float(step) / float(steps))
		for y_offset: int in range(-width, width + 1):
			for x_offset: int in range(-width, width + 1):
				if x_offset * x_offset + y_offset * y_offset <= width * width:
					_set_image_pixel_safe(image, int(roundf(point.x)) + x_offset, int(roundf(point.y)) + y_offset, color)

func _set_image_pixel_safe(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	printerr("TEST RESULT: FAIL %s" % message)

func _probe_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var upper_row: Array = grid[3]
	upper_row[3] = "wall"
	grid[3] = upper_row
	var lower_row: Array = grid[5]
	lower_row[3] = "wall"
	grid[5] = lower_row
	return grid
