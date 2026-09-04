extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

const OUTPUT_DIR: String = "user://probes/umbra_action_animation_v1"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const ENEMY_ID: int = 71
const ENEMY_KEY: String = "enemy_71"
const PLAYER_TILE := Vector2i(2, 4)
const HIDDEN_SOURCE := Vector2i(6, 4)
const UMBRA_EDGE := Vector2i(4, 4)

var _errors: Array[String] = []
var _animation_complete: bool = false


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://umbra_action_animation_progression.json")
	ProgressionStore.set_run_storage_path("user://umbra_action_animation_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("UMBRA ACTION ANIMATION PROBE: PASS")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("UMBRA ACTION ANIMATION PROBE: FAIL (%d)" % _errors.size())
	quit(1)


func _capture_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Umbra action proof should load RunScene")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	instance.call("_close_dialogue")
	await _capture_emerging_move(instance)
	await _capture_hidden_ranged_attack(instance, false, false)
	await _capture_hidden_ranged_attack(instance, false, true)
	await _capture_hidden_ranged_attack(instance, true, true)
	instance.queue_free()
	await process_frame


func _capture_emerging_move(instance: Node) -> void:
	var state: Dictionary = _combat_state()
	_install_state(instance, state)
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	_expect(not (board.get("presentation") as Dictionary).get("visible_enemy_ids", []).has(ENEMY_ID), "Movement proof should begin with the enemy concealed")
	await _save_root_screenshot("%s/01_move_before_boundary.png" % OUTPUT_DIR)
	var step: Dictionary = {
		"kind": "move",
		"actor_key": ENEMY_KEY,
		"actor_name": "Crawler",
		"label": "Advance",
		"from": HIDDEN_SOURCE,
		"to": UMBRA_EDGE,
		"path": [HIDDEN_SOURCE, Vector2i(5, 4), UMBRA_EDGE],
		"target_losses": [],
		"enemy_losses": [],
		"terrain_losses": [],
		"triggered_traps": [],
		"hidden_by_umbra": true,
		"revealed_after_action": true,
	}
	_animation_complete = false
	call_deferred("_run_hidden_step", instance, state, step)
	var captured_hidden_motion: bool = false
	var captured_visible_motion: bool = false
	for _frame: int in range(180):
		await process_frame
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var positions: Dictionary = presentation.get("unit_world_positions", {}) as Dictionary
		if positions.has(ENEMY_KEY) and not (presentation.get("visible_enemy_ids", []) as Array).has(ENEMY_ID) and not captured_hidden_motion:
			captured_hidden_motion = true
			await _save_root_screenshot("%s/02_move_hidden_segment.png" % OUTPUT_DIR)
		if positions.has(ENEMY_KEY) and (presentation.get("visible_enemy_ids", []) as Array).has(ENEMY_ID):
			captured_visible_motion = true
			_expect((presentation.get("umbra_action_visible_actor_keys", []) as Array).has(ENEMY_KEY), "Visible movement frame should explicitly admit the emerging actor")
			await _save_root_screenshot("%s/03_move_emerging_segment.png" % OUTPUT_DIR)
			break
	_expect(captured_hidden_motion, "Movement proof should observe interpolated motion while the enemy remains concealed")
	_expect(captured_visible_motion, "Movement proof should observe the enemy interpolating after it crosses into visibility")
	await _wait_for_animation()
	var moved_enemy: Dictionary = (state.get("enemies", []) as Array)[0] as Dictionary
	_expect(moved_enemy.get("pos", Vector2i(-1, -1)) == UMBRA_EDGE, "Emerging movement should settle on the resolved destination")
	await _save_root_screenshot("%s/04_move_visible_destination.png" % OUTPUT_DIR)


func _capture_hidden_ranged_attack(instance: Node, reduced_motion: bool, capture_impact: bool) -> void:
	var state: Dictionary = _combat_state()
	_install_state(instance, state)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", SettingsStore.normalize_settings(settings))
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var step: Dictionary = {
		"kind": "ranged",
		"action_type": "ranged",
		"actor_key": ENEMY_KEY,
		"actor_name": "Crawler",
		"label": "Shot",
		"enemy_type": "crawler",
		"element": "fire",
		"from": HIDDEN_SOURCE,
		"to": PLAYER_TILE,
		"tiles": [],
		"hp_loss": 3,
		"block_loss": 0,
		"stoneskin_loss": 0,
		"target_losses": [],
		"terrain_losses": [],
		"triggered_traps": [],
		"impact_actor_keys": ["player"],
		"hidden_by_umbra": true,
		"revealed_after_action": false,
	}
	_animation_complete = false
	call_deferred("_run_hidden_step", instance, state, step)
	var captured_frame: bool = false
	for _frame: int in range(180):
		await process_frame
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var effect: Dictionary = presentation.get("effect", {}) as Dictionary
		if not bool(effect.get("umbra_action_clipped", false)):
			if _animation_complete:
				break
			continue
		_expect(effect.get("from", Vector2i(-1, -1)) == UMBRA_EDGE, "Hidden projectile should begin on the first visible tile at the Umbra edge")
		_expect(effect.get("to", Vector2i(-1, -1)) == PLAYER_TILE, "Hidden projectile should retain its visible target")
		_expect(effect.get("umbra_original_from", Vector2i(-1, -1)) == HIDDEN_SOURCE, "Hidden projectile should retain its concealed source only as non-rendered animation metadata")
		_expect(str(effect.get("actor_name", "")) == "Unknown Presence", "Hidden projectile presentation should keep the source anonymous")
		_expect(not (presentation.get("visible_enemy_ids", []) as Array).has(ENEMY_ID), "Animating a hidden projectile must not reveal its source enemy")
		var progress: float = float(presentation.get("effect_progress", 0.0))
		if reduced_motion:
			await _save_root_screenshot("%s/07_ranged_reduced_motion_impact.png" % OUTPUT_DIR)
			captured_frame = true
			break
		if not capture_impact and progress >= 0.04 and progress <= 0.08:
			await _save_root_screenshot("%s/05_ranged_emerging_travel.png" % OUTPUT_DIR)
			captured_frame = true
			break
		if capture_impact and progress >= 0.40:
			await _save_root_screenshot("%s/06_ranged_visible_impact.png" % OUTPUT_DIR)
			captured_frame = true
			break
	if reduced_motion:
		_expect(captured_frame, "Reduced-motion proof should retain one readable visible impact frame")
	elif capture_impact:
		_expect(captured_frame, "Ranged proof should capture the visible target impact")
	else:
		_expect(captured_frame, "Ranged proof should capture the projectile traveling out of the Umbra")
	await _wait_for_animation()
	_expect(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 17, "Hidden ranged animation should apply damage exactly once")


func _run_hidden_step(instance: Node, state: Dictionary, step: Dictionary) -> void:
	await instance.call("_animate_hidden_umbra_enemy_step", state, step)
	_animation_complete = true


func _wait_for_animation() -> void:
	for _frame: int in range(240):
		if _animation_complete:
			return
		await process_frame
	_expect(_animation_complete, "Umbra action animation should complete within the probe budget")


func _install_state(instance: Node, state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = Vector2i(1, 0)
	run_state["current_room_layout"] = _layout()
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_close_dialogue")
	instance.call("_refresh_ui")


func _combat_state() -> Dictionary:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(97131, _layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
	})
	state["player"] = {"pos": PLAYER_TILE, "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [{
		"id": ENEMY_ID,
		"type": "crawler",
		"pos": HIDDEN_SOURCE,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": {"id": "umbra_probe", "name": "Hidden Shot", "actions": [{"type": "ranged", "damage": 3, "range": 8}]},
	}]
	state["terrain"] = []
	state["traps"] = []
	state["illusions"] = []
	state["current_actor"] = {"kind": "enemy", "key": ENEMY_KEY}
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = "heart"
	umbra["stage_reduction"] = 0
	umbra["light_sources"] = []
	state["umbra"] = umbra
	return state


func _layout() -> Dictionary:
	return {
		"name": "Umbra Action Animation Proof",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"depth": 18,
		"umbra_stage": "heart",
		"grid": _grid(),
		"player_start": PLAYER_TILE,
		"enemies": [{"id": ENEMY_ID, "type": "crawler", "pos": HIDDEN_SOURCE}],
		"terrain": [],
		"traps": [],
		"loot": [],
	}


func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid


func _settle_ui() -> void:
	for _frame: int in range(8):
		await process_frame
	RenderingServer.force_draw()
	await process_frame


func _save_root_screenshot(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.save_png(output_path) == OK, "Could not save %s" % output_path)


func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
