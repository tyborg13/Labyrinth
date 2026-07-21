extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://probes/enemy_pathfinding"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const INVALID_TILE: Vector2i = Vector2i(-999, -999)
const EXPECTED_ENEMY_PATH_COLOR: Color = Color("b78cff")

var _errors: Array[String]
var _move_animation_complete: bool = false
var _player_move_animation_complete: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://labyrinth_enemy_pathfinding_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_enemy_pathfinding_probe_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_enemy_pathfinding_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("ENEMY PATHFINDING PROBE: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("ENEMY PATHFINDING PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)

func _capture_enemy_pathfinding_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_errors.append("Run scene should load for enemy pathfinding visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(18473, ProgressionStore.default_data()))
	await _settle_ui()

	var safe_layout: Dictionary = _layout("Safe Route Around Trap", _open_grid())
	var safe_state: Dictionary = _combat_state(
		18473,
		safe_layout,
		Vector2i(3, 2),
		Vector2i(5, 4),
		3,
		[{"id": "safe_route_trap", "element": "fire", "pos": Vector2i(4, 4), "damage": 4, "armed": true}]
	)
	var combat := CombatEngine.new()
	var safe_plan: Dictionary = combat.enemy_intent_plan(safe_state, 0)
	var safe_path: Array[Vector2i] = _vector2i_array(safe_plan.get("path", []))
	_expect(bool(safe_plan.get("attack_available", false)), "Safe-route scenario should end in a legal melee attack")
	_expect(not safe_path.has(Vector2i(4, 4)), "Enemy should take an equal-length safe route instead of crossing the trap")
	_expect(safe_path.size() == 4, "Enemy should move exactly three steps to its first attack-enabling tile")
	await _install_and_hover(instance, safe_layout, safe_state, Vector2i(5, 4))
	_assert_board_projection(instance, safe_plan, "safe route")
	await _save_root_screenshot("%s/01_safe_route.png" % OUTPUT_DIR)
	await _capture_mid_route_animation(instance, safe_state, safe_plan)
	await _capture_player_mid_route_animation(instance, safe_layout, safe_state)

	var forced_layout: Dictionary = _layout("Forced Progress Through Trap", _forced_choke_grid())
	var forced_state: Dictionary = _combat_state(
		18479,
		forced_layout,
		Vector2i(2, 4),
		Vector2i(5, 4),
		2,
		[{"id": "forced_route_trap", "element": "fire", "pos": Vector2i(4, 4), "damage": 4, "armed": true}]
	)
	var forced_plan: Dictionary = combat.enemy_intent_plan(forced_state, 0)
	var forced_path: Array[Vector2i] = _vector2i_array(forced_plan.get("path", []))
	_expect(bool(forced_plan.get("attack_available", false)), "Forced corridor scenario should still end in a legal melee attack")
	_expect(forced_path == _vector2i_array([Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4)]), "Enemy should cross the only available trapped corridor when that is required to attack")
	await _install_and_hover(instance, forced_layout, forced_state, Vector2i(5, 4))
	_assert_board_projection(instance, forced_plan, "forced trap route", false)
	await _save_root_screenshot("%s/03_forced_trap_route.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _capture_mid_route_animation(instance: Node, combat_state: Dictionary, plan: Dictionary) -> void:
	var animated_state: Dictionary = combat_state.duplicate(true)
	var path: Array[Vector2i] = _vector2i_array(plan.get("path", []))
	var actor_key: String = str(plan.get("enemy_key", "enemy_1"))
	var move_step: Dictionary = {
		"kind": "move",
		"actor_key": actor_key,
		"actor_name": "Deliberate Hunter",
		"from": path[0],
		"to": path[path.size() - 1],
		"path": path,
		"label": "Advance",
		"target_losses": [],
		"enemy_losses": [],
		"terrain_losses": [],
		"triggered_traps": []
	}
	_move_animation_complete = false
	call_deferred("_run_move_animation", instance, animated_state, move_step)
	await create_timer(0.50).timeout
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var world_positions: Dictionary = presentation.get("unit_world_positions", {}) as Dictionary
	_expect(_vector2i_array(presentation.get("path_tiles", [])) == path, "Mid-animation frame should retain the full ordered multi-segment path")
	var path_color: Color = presentation.get("path_color", Color.TRANSPARENT)
	_expect(path_color.is_equal_approx(EXPECTED_ENEMY_PATH_COLOR), "Mid-animation enemy path should use the purple shared-arrow treatment")
	_expect(world_positions.has(actor_key), "Mid-animation frame should place the enemy between segment endpoints")
	await _save_root_screenshot("%s/02_multisegment_animation.png" % OUTPUT_DIR)
	var wait_frames: int = 0
	while not _move_animation_complete and wait_frames < 180:
		await process_frame
		wait_frames += 1
	_expect(_move_animation_complete, "Multi-segment movement animation should complete")
	var moved_enemy: Dictionary = (animated_state.get("enemies", []) as Array)[0]
	_expect(moved_enemy.get("pos", INVALID_TILE) == plan.get("destination", INVALID_TILE), "Multi-segment movement animation should apply the planned destination")

func _run_move_animation(instance: Node, animated_state: Dictionary, move_step: Dictionary) -> void:
	await instance.call("_animate_move_step", animated_state, move_step)
	_move_animation_complete = true

func _capture_player_mid_route_animation(instance: Node, layout: Dictionary, base_state: Dictionary) -> void:
	var before_state: Dictionary = base_state.duplicate(true)
	before_state["player"] = {"pos": Vector2i(3, 2), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	before_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"name": "Distant Observer",
		"pos": Vector2i(6, 6),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0
	}]
	before_state["traps"] = [{"id": "player_route_trap", "element": "fire", "pos": Vector2i(4, 2), "damage": 4, "armed": true}]
	var action: Dictionary = {"type": "move", "range": 4}
	var target_tile := Vector2i(5, 2)
	var combat := CombatEngine.new()
	var path: Array[Vector2i] = combat.path_for_player_action(before_state, action, target_tile)
	_expect(path.size() == 5, "Player animation scenario should produce a four-step route around the trap")
	if path.size() < 2:
		return
	_expect(path[0] == Vector2i(3, 2) and path[path.size() - 1] == target_tile, "Player animation route should retain its requested endpoints")
	_expect(not path.has(Vector2i(4, 2)), "Player animation route should preserve the engine's trap-avoiding waypoint choice")
	var after_state: Dictionary = combat.apply_player_action(before_state.duplicate(true), action, target_tile)
	_expect((after_state.get("player", {}) as Dictionary).get("pos", INVALID_TILE) == target_tile, "Player animation scenario should resolve at the route destination")
	await _install_and_hover(instance, layout, before_state, Vector2i(6, 6))

	_player_move_animation_complete = false
	call_deferred("_run_player_move_animation", instance, before_state.duplicate(true), after_state, action, target_tile)
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = {}
	var world_positions: Dictionary = {}
	for _frame: int in range(60):
		await process_frame
		presentation = board.get("presentation") as Dictionary
		world_positions = presentation.get("unit_world_positions", {}) as Dictionary
		if world_positions.has("player"):
			break
	_expect(world_positions.has("player"), "Player movement animation should expose an in-flight world position")
	_expect(_vector2i_array(presentation.get("path_tiles", [])) == path, "Player movement animation should retain the full ordered path arrow")
	if world_positions.has("player"):
		var player_world_position: Vector2 = world_positions.get("player", Vector2.ZERO)
		var segment_start: Vector2 = board.call("world_position_for_tile", path[0])
		var segment_end: Vector2 = board.call("world_position_for_tile", path[1])
		var direct_end: Vector2 = board.call("world_position_for_tile", path[path.size() - 1])
		_expect(_distance_to_segment(player_world_position, segment_start, segment_end) < 1.0, "Player should animate on the route's first segment")
		_expect(_distance_to_segment(player_world_position, segment_start, direct_end) > 1.0, "Player should not animate on the direct start-to-destination line")
	await _save_root_screenshot("%s/04_player_bent_route_animation.png" % OUTPUT_DIR)
	var wait_frames: int = 0
	while not _player_move_animation_complete and wait_frames < 240:
		await process_frame
		wait_frames += 1
	_expect(_player_move_animation_complete, "Player multi-segment movement animation should complete")

func _run_player_move_animation(instance: Node, before_state: Dictionary, after_state: Dictionary, action: Dictionary, target_tile: Vector2i) -> void:
	await instance.call("_animate_player_action_step", before_state, after_state, "threaded_path", action, target_tile)
	_player_move_animation_complete = true

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment: Vector2 = segment_end - segment_start
	if segment.length_squared() <= 0.0001:
		return point.distance_to(segment_start)
	var progress: float = clampf((point - segment_start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(segment_start + segment * progress)

func _install_and_hover(instance: Node, layout: Dictionary, combat_state: Dictionary, enemy_tile: Vector2i) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_hovered_board_tile", INVALID_TILE)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await _settle_ui()
	instance.call("_on_board_tile_hovered", enemy_tile)
	await _settle_ui()

func _assert_board_projection(instance: Node, plan: Dictionary, scenario: String, require_move_union: bool = true) -> void:
	var board: Control = instance.get_node(BOARD_PATH) as Control
	if board == null:
		_errors.append("%s should expose the combat board" % scenario)
		return
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_expect(_vector2i_array(presentation.get("path_tiles", [])) == _vector2i_array(plan.get("path", [])), "%s should render the exact planned path" % scenario)
	var path_color: Color = presentation.get("path_color", Color.TRANSPARENT)
	_expect(path_color.is_equal_approx(EXPECTED_ENEMY_PATH_COLOR), "%s should shade the shared movement arrows purple" % scenario)
	_expect(presentation.get("projected_destination", INVALID_TILE) == plan.get("destination", INVALID_TILE), "%s should render the exact planned destination" % scenario)
	_expect(_vector2i_array(presentation.get("projected_attack_tiles", [])) == _vector2i_array(plan.get("projected_attack", [])), "%s should render the exact projected attack tiles" % scenario)
	if require_move_union:
		_expect(not (board.get("move_tiles") as Array).is_empty(), "%s should retain the conservative movement union" % scenario)
	_expect(not (board.get("attack_tiles") as Array).is_empty(), "%s should retain the conservative attack union" % scenario)

func _combat_state(seed: int, layout: Dictionary, player_pos: Vector2i, enemy_pos: Vector2i, move_range: int, traps: Array) -> Dictionary:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": player_pos, "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"name": "Deliberate Hunter",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": {
			"name": "Relentless Claw",
			"actions": [
				{"type": "move_toward", "range": move_range},
				{"type": "melee", "damage": 4, "range": 1}
			]
		}
	}]
	state["terrain"] = []
	state["traps"] = traps.duplicate(true)
	state["illusions"] = []
	state["rng_state"] = seed
	state["current_actor"] = {"kind": "player", "key": "player"}
	return state

func _layout(room_name: String, grid: Array) -> Dictionary:
	return {
		"name": room_name,
		"coord": Vector2i(1, 0),
		"type": "combat",
		"depth": 1,
		"umbra_stage": "clear",
		"grid": grid,
		"player_start": Vector2i(3, 2),
		"enemies": [],
		"terrain": [],
		"traps": [],
		"loot": []
	}

func _open_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _forced_choke_grid() -> Array:
	var grid: Array = _open_grid()
	(grid[3] as Array)[5] = "wall"
	(grid[4] as Array)[6] = "wall"
	(grid[5] as Array)[5] = "wall"
	return grid

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _settle_ui() -> void:
	for _frame: int in range(8):
		await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_width() != VIEWPORT_SIZE.x or image.get_height() != VIEWPORT_SIZE.y:
		# Metal exposes the Retina backing texture, so normalize the native render
		# to the probe's declared logical proof resolution before validation.
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(output_path) != OK:
		_errors.append("Enemy pathfinding probe could not save %s" % output_path)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
