extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const OUTPUT_DIR: String = "user://probes/umbra_preview_privacy_v1"
const PROBE_VIEWPORT := Vector2i(1920, 1080)
const PLAYER_TILE := Vector2i(2, 4)
const HIDDEN_ENEMY_TILE := Vector2i(6, 4)


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://umbra_preview_privacy_progression.json")
	ProgressionStore.set_run_storage_path("user://umbra_preview_privacy_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_privacy_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _capture_privacy_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Umbra preview privacy proof should load RunScene")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var combat := CombatEngine.new()
	var layout: Dictionary = _combat_layout()
	var state: Dictionary = combat.create_combat(86100, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state.erase("player_turn_restrictions")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_refresh_ui")
	await _settle_ui()

	var baseline_radius: int = combat.effective_umbra_radius(state)
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0] as Dictionary
	var enemy_id: int = int(enemy.get("id", -1))
	var enemy_tile: Vector2i = enemy.get("pos", HIDDEN_ENEMY_TILE)
	_expect(not combat.visible_enemy_ids(state).has(enemy_id), "Privacy probe enemy should begin concealed")

	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	var move_target := Vector2i(5, 4)
	instance.call("_on_board_tile_hovered", move_target)
	await _settle_ui()
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	_expect((board.get("combat_state") as Dictionary).get("player", {}).get("pos", Vector2i.ZERO) == PLAYER_TILE, "Move hover should keep the player at the committed tile")
	_expect(int((board.get("presentation") as Dictionary).get("umbra_radius", -1)) == baseline_radius, "Move hover should keep the committed Umbra radius")
	await _save_root_screenshot("%s/01_move_hover_committed_vision.png" % OUTPUT_DIR)

	await instance.call("_on_board_tile_clicked", move_target)
	await _settle_ui()
	board = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var locked_presentation: Dictionary = board.get("presentation") as Dictionary
	_expect(bool(instance.get("_pending_umbra_commit_locked")), "Choosing an Umbra move should lock the pending card decision")
	_expect((board.get("combat_state") as Dictionary).get("player", {}).get("pos", Vector2i.ZERO) == PLAYER_TILE, "Locked move preview should still render the committed player tile")
	_expect(not (locked_presentation.get("visible_enemy_ids", []) as Array).has(enemy_id), "Locked move preview should not reveal the enemy behind the Umbra")
	_expect(int(locked_presentation.get("umbra_radius", -1)) == baseline_radius, "Locked move preview should keep the committed Umbra radius")
	await _save_root_screenshot("%s/02_move_choice_committed_vision.png" % OUTPUT_DIR)

	instance.call("_reset_card_resolution")
	var cases: Array = [
		{"name": "light", "action": {"type": "illuminate", "range": 8, "radius": 2, "duration": 2}, "target": enemy_tile},
		{"name": "vision", "action": {"type": "vision", "amount": 4, "duration": 1}, "target": Vector2i(-1, -1)},
		{"name": "truesight", "action": {"type": "truesight", "duration": 1}, "target": Vector2i(-1, -1)},
		{"name": "dispel", "action": {"type": "dispel_umbra", "amount": 2}, "target": Vector2i(-1, -1)}
	]
	for case_var: Variant in cases:
		var case: Dictionary = case_var as Dictionary
		var first_action: Dictionary = case.get("action", {}) as Dictionary
		var preview_state: Dictionary = combat.apply_player_action(state, first_action, case.get("target", Vector2i(-1, -1)))
		var followup_action: Dictionary = {"type": "ranged", "damage": 4, "range": 9}
		var raw_targets: Array[Vector2i] = combat.valid_targets_for_player_action(preview_state, followup_action)
		_expect(raw_targets.has(enemy_tile), "%s preview should simulate the hidden follow-up target" % str(case.get("name", "")))
		instance.set("_selected_card_index", 0)
		instance.set("_pending_actions", [first_action, followup_action])
		instance.set("_pending_action_index", 1)
		instance.set("_pending_selected_targets", instance.call("_vector2i_array", [case.get("target", Vector2i(-1, -1))]))
		instance.set("_pending_target_tiles", raw_targets)
		instance.set("_preview_combat_state", preview_state)
		instance.set("_pending_umbra_commit_locked", false)
		instance.set("_hovered_board_tile", enemy_tile)
		instance.call("_mark_preview_selection_changed")
		instance.call("_refresh_stage_view")
		await _settle_ui()
		board = instance.get_node("BoardUnderlay/CombatBoard") as Control
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var active_preview: Dictionary = instance.call("_active_card_preview")
		_expect(int(presentation.get("umbra_radius", -1)) == baseline_radius, "%s preview should keep the committed Umbra radius" % str(case.get("name", "")))
		_expect((presentation.get("umbra_light_sources", []) as Array).is_empty(), "%s preview should not render a simulated light source" % str(case.get("name", "")))
		_expect(not (presentation.get("visible_enemy_ids", []) as Array).has(enemy_id), "%s preview should not reveal the hidden enemy" % str(case.get("name", "")))
		_expect(not (board.get("attack_tiles") as Array).has(enemy_tile), "%s preview should not show a hidden follow-up target" % str(case.get("name", "")))
		_expect(not (active_preview.get("target_tiles", []) as Array).has(enemy_tile), "%s preview target list should preserve committed knowledge" % str(case.get("name", "")))
		_expect((presentation.get("effect", {}) as Dictionary).is_empty(), "%s preview should not draw an effect on the hidden follow-up target" % str(case.get("name", "")))
		await _save_root_screenshot("%s/03_%s_followup_committed_vision.png" % [OUTPUT_DIR, str(case.get("name", ""))])

	instance.queue_free()
	await process_frame


func _combat_layout() -> Dictionary:
	return {
		"name": "Umbra Preview Privacy Proof",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": "air",
		"umbra_stage": "heart",
		"grid": _open_grid(),
		"player_start": PLAYER_TILE,
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": HIDDEN_ENEMY_TILE,
			"hp": 100,
			"max_hp": 100,
			"block": 0
		}],
		"traps": [],
		"terrain": [],
		"loot": []
	}


func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid


func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame


func _save_root_screenshot(output_path: String) -> void:
	_expect(DisplayServer.get_name() != "headless", "Umbra preview privacy proof requires the real renderer")
	var texture: Texture2D = root.get_viewport().get_texture()
	var image: Image = texture.get_image()
	_expect(image != null, "Umbra preview privacy proof should capture a renderer image")
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	var proportional: bool = is_equal_approx(scale_x, scale_y) and is_equal_approx(float(source_size.x) / float(source_size.y), float(PROBE_VIEWPORT.x) / float(PROBE_VIEWPORT.y))
	_expect(proportional, "Umbra preview privacy proof should preserve 1920x1080 aspect ratio, got %s" % source_size)
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.save_png(output_path) == OK, "Umbra preview privacy proof should save %s" % output_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _clear_probe_output(absolute_dir: String) -> void:
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
			_clear_probe_output(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
