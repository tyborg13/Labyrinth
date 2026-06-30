extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://probes/pass_preview"
const PROOF_IMAGE_SIZE: Vector2i = Vector2i(760, 180)
const PIXEL_GLYPHS: Dictionary = {
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
	"6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["11111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
	"/": ["00001", "00001", "00010", "00100", "01000", "10000", "10000"],
	"|": ["00100", "00100", "00100", "00100", "00100", "00100", "00100"],
	",": ["00000", "00000", "00000", "00000", "00100", "00100", "01000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	"!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
	"?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"]
}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_pass_preview_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_pass_preview_probe_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_pass_preview_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_pass_preview_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(123, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_room_coord_of_type(run_engine, run_state, "combat")
	if combat_coord != Vector2i.ZERO:
		run_state = run_engine.move_to_room(run_state, combat_coord)
	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame

	var base_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var danger_state: Dictionary = _pass_preview_probe_state(base_state, "danger")
	_install_pass_preview_probe_state(instance, danger_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "danger")
	_log_pass_preview_text(instance, "danger")
	await _save_root_screenshot("%s/danger.png" % OUTPUT_DIR)

	await instance.call("_on_card_pressed", 0)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "selected card")
	_log_pass_preview_text(instance, "selected")
	await _save_root_screenshot("%s/selected_card.png" % OUTPUT_DIR)

	var move_target: Vector2i = _pass_preview_probe_move_target(instance.get("_pending_target_tiles") as Array, Vector2i(3, 4))
	if move_target.x >= 0:
		instance.call("_on_board_tile_hovered", move_target)
		await process_frame
		await process_frame
		_require_pass_preview_chip(instance, "selected move hover")
		_log_pass_preview_text(instance, "selected_move_hover")
		await _save_root_screenshot("%s/selected_move_hover.png" % OUTPUT_DIR)

	var after_card_state: Dictionary = _pass_preview_probe_after_guarded_step(instance, danger_state)
	_install_pass_preview_probe_state(instance, after_card_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "after card")
	_log_pass_preview_text(instance, "after_card")
	await _save_root_screenshot("%s/after_card.png" % OUTPUT_DIR)

	var safe_state: Dictionary = _pass_preview_probe_state(base_state, "safe")
	_install_pass_preview_probe_state(instance, safe_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "safe")
	_log_pass_preview_text(instance, "safe")
	await _save_root_screenshot("%s/safe.png" % OUTPUT_DIR)

	var layered_state: Dictionary = _pass_preview_probe_state(base_state, "layered")
	_install_pass_preview_probe_state(instance, layered_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "layered")
	_log_pass_preview_text(instance, "layered")
	await _save_root_screenshot("%s/layered.png" % OUTPUT_DIR)

	var unrevealed_state: Dictionary = _pass_preview_probe_state(base_state, "unrevealed")
	_install_pass_preview_probe_state(instance, unrevealed_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "unrevealed")
	_log_pass_preview_text(instance, "unrevealed")
	await _save_root_screenshot("%s/unrevealed.png" % OUTPUT_DIR)

	var lethal_state: Dictionary = _pass_preview_probe_state(base_state, "lethal")
	_install_pass_preview_probe_state(instance, lethal_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "lethal")
	_log_pass_preview_text(instance, "lethal")
	await _save_root_screenshot("%s/lethal.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _first_available_room_coord_of_type(run_engine: RunEngine, run_state: Dictionary, room_type: String) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _install_pass_preview_probe_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_card_play_count_override", -1)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")

func _pass_preview_probe_state(base_state: Dictionary, kind: String) -> Dictionary:
	var state: Dictionary = base_state.duplicate(true)
	var enemy_pos: Vector2i = Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	if kind == "safe":
		enemy_pos = Vector2i(6, 4)
		enemy_intent = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	elif kind == "layered":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 12, "range": 1}]}
	elif kind == "lethal":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 30, "range": 1}]}
	elif kind == "unrevealed":
		enemy_pos = Vector2i(6, 4)
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 3 if kind == "layered" else 0,
		"stoneskin": 4 if kind == "layered" else 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []}
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []},
		"intent": enemy_intent
	}]
	state["illusions"] = []
	state["traps"] = []
	state["terrain"] = []
	state["grid"] = _pass_preview_probe_simple_grid()
	state["deck"] = {
		"hand": ["guarded_step", "quick_stab"],
		"draw": ["patch_up", "bone_dart"],
		"discard": ["sidestep_slash"],
		"burned": [],
		"cycles": 0,
		"fatigue_base": 15
	}
	state["cards_per_turn"] = 2
	state["draw_per_turn"] = 2
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if kind == "unrevealed" else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["pending_player_trap_restriction"] = ""
	state["turn_flags"] = {"first_attack_bonus_used": false, "first_move_bonus_used": false}
	state["initiative_clock"] = 0
	state["activation_seq"] = 1
	state["current_actor"] = {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": 0,
		"seq": 0
	}
	state["turn_queue"] = [{
		"kind": "enemy",
		"actor_key": "enemy_1",
		"enemy_id": 1,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"team": "enemy",
		"time": 1,
		"seq": 1,
		"pos": enemy_pos
	}]
	return state

func _pass_preview_probe_simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
		grid.append(row)
	return grid

func _pass_preview_probe_after_guarded_step(instance: Node, source_state: Dictionary) -> Dictionary:
	var combat_engine = instance.get("_combat_engine")
	var state: Dictionary = source_state.duplicate(true)
	var actions: Array = GameData.card_def("guarded_step").get("actions", [])
	for action_index: int in range(actions.size()):
		if typeof(actions[action_index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[action_index]
		if combat_engine.player_action_needs_target(action):
			var target_tiles: Array = combat_engine.valid_targets_for_player_action(state, action)
			var move_target: Vector2i = _pass_preview_probe_move_target(target_tiles, Vector2i(3, 4))
			if move_target.x >= 0:
				state = combat_engine.apply_player_action(state, action, move_target)
		else:
			state = combat_engine.apply_player_action(state, action)
	return combat_engine.finish_player_card(state, 0)

func _pass_preview_probe_move_target(target_tiles: Array, enemy_pos: Vector2i) -> Vector2i:
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for tile_var: Variant in target_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var distance: int = absi(tile.x - enemy_pos.x) + absi(tile.y - enemy_pos.y)
		if distance > best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

func _require_pass_preview_chip(instance: Node, label: String) -> void:
	var row: Node = _first_node_named(instance, "PassPreviewDamageRow")
	if row == null or _pass_preview_probe_damage_text(row).is_empty():
		push_error("Missing pass preview damage values during %s pass preview probe" % label)

func _log_pass_preview_text(instance: Node, label: String) -> void:
	var row: Node = _first_node_named(instance, "PassPreviewDamageRow")
	var damage_text: String = _pass_preview_probe_damage_text(row)
	var danger_label: Label = _first_node_named(instance, "PassPreviewDanger") as Label
	var danger_text: String = danger_label.text if danger_label != null else ""
	print("%s: %s %s" % [label, damage_text, danger_text])

func _pass_preview_probe_damage_text(row: Node) -> String:
	if row == null:
		return ""
	var parts := PackedStringArray()
	for label: Label in _pass_preview_probe_damage_labels(row):
		parts.append(label.text)
	return " ".join(parts)

func _pass_preview_probe_damage_labels(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label and _pass_preview_probe_is_damage_value(node as Label):
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_pass_preview_probe_damage_labels(child))
	return labels

func _pass_preview_probe_is_damage_value(label: Label) -> bool:
	return [
		"PassPreviewStoneSkinLoss",
		"PassPreviewBlockLoss",
		"PassPreviewHpLoss",
		"PassPreviewZero",
		"PassPreviewDefeat"
	].has(str(label.name))

func _first_node_named(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _first_node_named(child, node_name)
		if found != null:
			return found
	return null

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		var texture = root.get_viewport().get_texture()
		if texture != null:
			image = texture.get_image()
	if image != null and image.get_width() > 0 and image.get_height() > 0:
		image.save_png(output_path)
		return
	_save_pass_preview_chip_proof(output_path)

func _save_pass_preview_chip_proof(output_path: String) -> void:
	var row: Node = _first_node_named(root, "PassPreviewDamageRow")
	var main_text: String = _pass_preview_probe_damage_text(row)
	if main_text.is_empty():
		main_text = "0"
	var danger_label: Label = _first_node_named(root, "PassPreviewDanger") as Label
	var detail_text: String = danger_label.text if danger_label != null else ""
	var image := Image.create(PROOF_IMAGE_SIZE.x, PROOF_IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("160f0d"))
	var accent: Color = _pass_preview_proof_accent(main_text, detail_text)
	image.fill_rect(Rect2i(18, 18, PROOF_IMAGE_SIZE.x - 36, PROOF_IMAGE_SIZE.y - 36), Color("241810"))
	image.fill_rect(Rect2i(24, 24, PROOF_IMAGE_SIZE.x - 48, PROOF_IMAGE_SIZE.y - 48), Color(0.105, 0.075, 0.055, 0.95))
	_draw_proof_rect_outline(image, Rect2i(24, 24, PROOF_IMAGE_SIZE.x - 48, PROOF_IMAGE_SIZE.y - 48), accent)
	image.fill_rect(Rect2i(24, 24, 12, PROOF_IMAGE_SIZE.y - 48), accent.darkened(0.18))
	_draw_proof_text(image, Vector2i(52, 48), main_text.to_upper(), Color("fff0d0"), 3)
	_draw_proof_text(image, Vector2i(52, 106), detail_text.to_upper(), Color("d9cdb4"), 2)
	image.save_png(output_path)
	print("headless chip proof: %s" % ProjectSettings.globalize_path(output_path))

func _pass_preview_proof_accent(main_text: String, detail_text: String) -> Color:
	if main_text.contains("DEFEAT") or detail_text.contains("DANGER") or main_text.contains("-"):
		return Color("d86654")
	return Color("8fcf7d")

func _draw_proof_rect_outline(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, 3), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y + rect.size.y - 3, rect.size.x, 3), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, 3, rect.size.y), color)
	image.fill_rect(Rect2i(rect.position.x + rect.size.x - 3, rect.position.y, 3, rect.size.y), color)

func _draw_proof_text(image: Image, position: Vector2i, text: String, color: Color, scale: int) -> void:
	var cursor_x: int = position.x
	var max_x: int = image.get_width() - 28
	for index: int in range(text.length()):
		var character: String = text.substr(index, 1)
		if character == " ":
			cursor_x += 4 * scale
			continue
		var glyph: Array = PIXEL_GLYPHS.get(character, PIXEL_GLYPHS.get("?"))
		for row: int in range(glyph.size()):
			var pattern: String = str(glyph[row])
			for column: int in range(pattern.length()):
				if pattern.substr(column, 1) == "1":
					image.fill_rect(Rect2i(cursor_x + column * scale, position.y + row * scale, scale, scale), color)
		cursor_x += 6 * scale
		if cursor_x >= max_x:
			break

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
