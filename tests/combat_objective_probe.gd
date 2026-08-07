extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const OUTPUT_DIR: String = "user://combat_objective_probe_v1"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const TRAVEL_DIRECTION: Vector2i = Vector2i.UP

var _failed: bool = false

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
	ProgressionStore.set_storage_path("user://combat_objective_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://combat_objective_probe_run.save")
	ProgressionStore.clear_saved_run()
	call_deferred("_capture_objectives")

func _capture_objectives() -> void:
	await process_frame
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")

	var leader_fixture: Dictionary = _find_fixture(CombatObjectiveRules.KILL_LEADER, 3)
	var survive_fixture: Dictionary = _find_fixture(CombatObjectiveRules.SURVIVE, 3)
	var exit_fixture: Dictionary = _find_fixture(CombatObjectiveRules.REACH_EXIT, 3)
	if leader_fixture.is_empty() or survive_fixture.is_empty() or exit_fixture.is_empty():
		_fail("Objective probe should find deterministic fixtures for every new objective")
		_finish(instance)
		return

	await _capture_pre_battle(instance, leader_fixture)
	await _capture_leader(instance, leader_fixture)
	await _capture_survive(instance, survive_fixture)
	await _capture_exit(instance, exit_fixture)
	await _capture_exit_reward_and_departure(instance, exit_fixture)
	_finish(instance)

func _capture_pre_battle(instance: Node, fixture: Dictionary) -> void:
	var state: Dictionary = _base_run_state(fixture)
	state["mode"] = RunEngine.MODE_PRE_BATTLE
	state["combat_state"] = {}
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = TRAVEL_DIRECTION
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	var scrim: Control = instance.get("_pre_battle_scrim") as Control
	var panel: Control = instance.get("_pre_battle_panel") as Control
	var objective_chip: Control = panel.find_child("PreBattleObjectiveChip", true, false) as Control if panel != null else null
	if scrim == null or not scrim.visible or objective_chip == null:
		_fail("Pre-battle proof should visibly include the objective chip")
	else:
		var labels: String = _labels_text(objective_chip)
		if not labels.contains("KILL THE LEADER") or not labels.contains("Slay the marked leader"):
			_fail("Pre-battle objective chip should name and explain Kill the Leader")
		if objective_chip.find_child("PreBattleObjectiveIcon", true, false) == null:
			_fail("Pre-battle objective chip should include its purpose-built icon")
		if not panel.get_global_rect().encloses(objective_chip.get_global_rect()):
			_fail("Pre-battle objective chip should remain fully inside the preview panel")
	await _capture("01_pre_battle_kill_leader.png")

func _capture_leader(instance: Node, fixture: Dictionary) -> void:
	var state: Dictionary = _combat_run_state(fixture)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var objective: Dictionary = combat_state.get("objective", {}) as Dictionary
	var leader_id: int = int(objective.get("leader_id", -1))
	var leader: Dictionary = _enemy_with_id(combat_state, leader_id)
	_assert_live_hud(instance, "KILL THE LEADER", "HP")
	if leader.is_empty() or not bool(leader.get("is_leader", false)):
		_fail("Leader combat proof should retain one visibly marked leader")
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary if board != null else {}
	if board == null or presentation.get("objective_leader_tile", Vector2i(-1, -1)) != leader.get("pos", Vector2i(-2, -2)):
		_fail("Leader combat proof should beacon the leader's board tile")
	elif not _board_has_leader_unit(board, leader_id):
		_fail("Leader combat proof should carry the LEADER unit marker")
	_assert_hud_safe(instance)
	await _capture("02_kill_leader_combat.png")

func _capture_survive(instance: Node, fixture: Dictionary) -> void:
	var state: Dictionary = _combat_run_state(fixture)
	var combat_state: Dictionary = state.get("combat_state", {}) as Dictionary
	var objective: Dictionary = (combat_state.get("objective", {}) as Dictionary).duplicate(true)
	var target_clock: int = int(objective.get("target_clock", 46))
	combat_state["initiative_clock"] = maxi(1, target_clock - 22)
	objective["next_reinforcement_clock"] = mini(target_clock - 1, int(combat_state.get("initiative_clock", 0)) + 8)
	combat_state["objective"] = objective
	state["combat_state"] = combat_state
	state["current_room_layout"] = fixture.get("layout", {}).duplicate(true)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	var spawn_tile: Vector2i = _reinforcement_tile(combat_state)
	var spawned: Dictionary = CombatEngine.new().call("_spawned_enemy_entry", combat_state, "crawler", 99, spawn_tile, false) as Dictionary
	spawned["key"] = "enemy_99"
	spawned["death_frame"] = 7
	spawned["death_progress"] = 0.48
	instance.call("_render_board_state", combat_state, {
		"death_animation_units": [spawned],
		"focus_tiles": [spawn_tile],
		"focus_color": Color(0.50, 0.26, 0.62, 0.22)
	})
	await process_frame
	await process_frame
	_assert_live_hud(instance, "SURVIVE", "Reinforcements in 8")
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary if board != null else {}
	if (presentation.get("death_animation_units", []) as Array).size() != 1:
		_fail("Survival proof should render a reinforcement emerging through the reversed death sheet")
	_assert_hud_safe(instance)
	await _capture("03_survive_reinforcement_emergence.png")

func _capture_exit(instance: Node, fixture: Dictionary) -> void:
	var state: Dictionary = _combat_run_state(fixture)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var objective: Dictionary = combat_state.get("objective", {}) as Dictionary
	var target_tiles: Array[Vector2i] = CombatObjectiveRules.exit_target_tiles(objective)
	var door_tiles: Array[Vector2i] = CombatObjectiveRules.exit_door_tiles(objective)
	_assert_live_hud(instance, "REACH THE EXIT", "marked threshold")
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary if board != null else {}
	if target_tiles.is_empty() or presentation.get("objective_exit_target_tiles", []) != target_tiles:
		_fail("Reach Exit proof should visibly mark every generated threshold tile")
	if door_tiles.is_empty() or not _dictionary_has_all(instance.call("_active_door_tiles_for_board") as Dictionary, door_tiles):
		_fail("Reach Exit proof should render its future exits as active doors during combat")
	if not _dictionary_has_all(instance.call("_objective_exit_labels_for_board", combat_state) as Dictionary, door_tiles):
		_fail("Reach Exit proof should keep direction labels above its objective doors")
	if not _dictionary_has_all(instance.call("_objective_exit_icon_ids_for_board", combat_state) as Dictionary, door_tiles):
		_fail("Reach Exit proof should keep destination room icons above its objective doors")
	var top_door: Vector2i = Vector2i(-1, -1)
	for door_tile: Vector2i in door_tiles:
		if door_tile.y == 0:
			top_door = door_tile
			break
	if board != null and top_door.x >= 0:
		var grid: Array = combat_state.get("grid", []) as Array
		var door_texture: Texture2D = board.call("_door_texture_for_tile", grid, top_door) as Texture2D
		var door_frame: Rect2 = board.call("_door_rect_for_tile", top_door, grid) as Rect2
		var door_draw_rect: Rect2 = board.call("_prop_draw_rect", door_texture, door_frame) as Rect2
		var icon_rect: Rect2 = board.call("_door_icon_visual_rect", door_texture, door_draw_rect) as Rect2
		var board_transform: Transform2D = board.get_global_transform()
		var global_icon_rect := Rect2(board_transform * icon_rect.position, board_transform * icon_rect.end - board_transform * icon_rect.position)
		if global_icon_rect.position.y < 2.0 or global_icon_rect.end.y > float(PROBE_VIEWPORT.y) - 2.0:
			_fail("Reach Exit framing should keep the complete top-door destination icon on-screen")
		if float(board.call("_navigation_zoom_scale_for_presentation", presentation)) >= 1.0:
			_fail("Reach Exit framing should back the default board zoom off slightly for floating door icons")
	if (combat_state.get("enemies", []) as Array).size() < 7 or (combat_state.get("terrain", []) as Array).size() < 8:
		_fail("Reach Exit proof should show its denser enemy and destructible-terrain challenge")
	_assert_hud_safe(instance)
	await _capture("04_reach_exit_combat.png")

func _capture_exit_reward_and_departure(instance: Node, fixture: Dictionary) -> void:
	var state: Dictionary = _combat_run_state(fixture)
	var combat_state: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	var objective: Dictionary = combat_state.get("objective", {}) as Dictionary
	var target_tiles: Array[Vector2i] = CombatObjectiveRules.exit_target_tiles(objective)
	if target_tiles.is_empty():
		_fail("Reach Exit reward proof requires at least one threshold")
		return
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = target_tiles[0]
	combat_state["player"] = player
	state["combat_state"] = combat_state
	var run_engine := RunEngine.new()
	var reward_state: Dictionary = run_engine.finish_combat(state, combat_state)
	var pending_escape: Dictionary = run_engine.pending_escape(reward_state)
	var selected_door: Vector2i = pending_escape.get("door_tile", Vector2i(-1, -1))
	instance.call("_load_run_state", reward_state)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	var reward_board: Dictionary = instance.call("_board_display_state") as Dictionary
	var reward_overlay: Control = instance.get("_relic_choice_overlay") as Control
	if str((instance.get("_run_state") as Dictionary).get("mode", "")) != "reward":
		_fail("Reach Exit should keep the normal reward decision before automatic travel")
	if reward_overlay == null or not reward_overlay.visible:
		_fail("Reach Exit reward proof should display the established reward overlay")
	if (reward_board.get("enemies", []) as Array).size() != (combat_state.get("enemies", []) as Array).size():
		_fail("Every surviving pursuer should remain visible behind the reward")
	if (reward_board.get("terrain", []) as Array).size() != (combat_state.get("terrain", []) as Array).size():
		_fail("Destructible terrain should remain visible behind the reward")
	var active_reward_doors: Dictionary = instance.call("_active_door_tiles_for_board") as Dictionary
	if active_reward_doors.size() != 1 or not active_reward_doors.has(selected_door):
		_fail("Only the threshold door reached by the player should remain active after combat")
	await _capture("05_reach_exit_reward_with_pursuers.png")

	var reward_cards: Array = (reward_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array
	if reward_cards.is_empty():
		_fail("Reach Exit departure proof requires a card reward")
		return
	var escape_state: Dictionary = run_engine.claim_card_reward(reward_state, str(reward_cards[0]))
	instance.set("_run_state", escape_state)
	instance.call("_sync_combat_state_from_run")
	instance.call("_refresh_ui")
	instance.set("_board_presentation", {
		"door_opening": {
			"tile": selected_door,
			"frame": 7,
			"progress": 1.0
		}
	})
	instance.call("_refresh_stage_view")
	await process_frame
	await process_frame
	var departure_board: Dictionary = instance.call("_board_display_state") as Dictionary
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary if board != null else {}
	if str((instance.get("_run_state") as Dictionary).get("mode", "")) != RunEngine.MODE_ESCAPE:
		_fail("Reward completion should enter the non-interactive automatic escape transition")
	if reward_overlay != null and reward_overlay.visible:
		_fail("The reward overlay should clear before the committed door opens")
	if (departure_board.get("enemies", []) as Array).size() != (combat_state.get("enemies", []) as Array).size():
		_fail("Pursuers should remain on the board while the committed door opens")
	if (presentation.get("door_opening", {}) as Dictionary).get("tile", Vector2i(-1, -1)) != selected_door:
		_fail("The door-opening presentation should target the exact threshold door reached")
	await _capture("06_reach_exit_committed_door_opening.png")

func _find_fixture(objective_type: String, depth: int) -> Dictionary:
	var room: Dictionary = _room_metadata(depth)
	var generator := RoomGenerator.new()
	for seed: int in range(1, 500):
		var layout: Dictionary = generator.generate_room(seed, room, TRAVEL_DIRECTION)
		if str((layout.get("objective", {}) as Dictionary).get("type", "")) == objective_type:
			return {"seed": seed, "room": room.duplicate(true), "layout": layout}
	return {}

func _room_metadata(depth: int) -> Dictionary:
	var coord := Vector2i(depth, 0)
	return {
		"name": "Objective Crucible",
		"coord": coord,
		"depth": depth,
		"type": "combat",
		"element": "fire",
		"connections": [
			{"door_dir": Vector2i.UP, "coord": coord + Vector2i.UP, "kind": "outward"},
			{"door_dir": Vector2i.RIGHT, "coord": coord + Vector2i.RIGHT, "kind": "lateral"},
			{"door_dir": Vector2i.DOWN, "coord": coord + Vector2i.DOWN, "kind": "inward"},
			{"door_dir": Vector2i.LEFT, "coord": coord + Vector2i.LEFT, "kind": "lateral"},
		],
		"npcs": [],
		"revealed": true,
		"visited": true,
		"cleared": false,
		"sealed": false,
	}

func _base_run_state(fixture: Dictionary) -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	var run_engine := RunEngine.new()
	var seed: int = int(fixture.get("seed", 1))
	var room: Dictionary = fixture.get("room", {}) as Dictionary
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var state: Dictionary = run_engine.create_new_run(seed, progression)
	state["rooms"] = {_room_key(coord): room.duplicate(true)}
	state["current_room"] = coord
	state["current_room_layout"] = (fixture.get("layout", {}) as Dictionary).duplicate(true)
	state["notice"] = ""
	return state

func _combat_run_state(fixture: Dictionary) -> Dictionary:
	var state: Dictionary = _base_run_state(fixture)
	var snapshot: Dictionary = RunEngine.new().call("_player_snapshot", state) as Dictionary
	snapshot["hp"] = 80
	snapshot["max_hp"] = 80
	var combat_state: Dictionary = CombatEngine.new().create_combat(
		int(fixture.get("seed", 1)),
		(fixture.get("layout", {}) as Dictionary).duplicate(true),
		snapshot
	)
	state["mode"] = "combat"
	state["combat_state"] = combat_state
	state["player_hp"] = 80
	state["player_max_hp"] = 80
	return state

func _reinforcement_tile(state: Dictionary) -> Vector2i:
	var grid: Array = state.get("grid", []) as Array
	var occupied: Dictionary = {}
	occupied[(state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			occupied[(enemy_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for y: int in range(1, grid.size() - 1):
		var row: Array = grid[y]
		for x: int in range(1, row.size() - 1):
			var tile := Vector2i(x, y)
			if str(row[x]) != "wall" and not occupied.has(tile):
				return tile
	return Vector2i(1, 1)

func _enemy_with_id(state: Dictionary, enemy_id: int) -> Dictionary:
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			return enemy_var as Dictionary
	return {}

func _board_has_leader_unit(board: Control, leader_id: int) -> bool:
	for unit_var: Variant in board.call("_visible_units") as Array:
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if int(unit.get("id", -1)) == leader_id and bool(unit.get("is_leader", false)):
			return true
	return false

func _assert_live_hud(instance: Node, title_text: String, detail_text: String) -> void:
	var hud: Control = instance.get("_combat_objective_hud") as Control
	if hud == null or not hud.visible:
		_fail("Combat proof should show the live objective HUD")
		return
	var title: Label = hud.find_child("ObjectiveTitle", true, false) as Label
	var detail: Label = hud.find_child("ObjectiveLiveDetail", true, false) as Label
	if title == null or title.text != title_text:
		_fail("Combat objective HUD should name %s" % title_text)
	if detail == null or not detail.text.contains(detail_text):
		_fail("Combat objective HUD should expose critical live detail: %s" % detail_text)
	if hud.find_child("ObjectiveIcon", true, false) == null:
		_fail("Combat objective HUD should include a purpose-built icon")

func _assert_hud_safe(instance: Node) -> void:
	var hud: Control = instance.get("_combat_objective_hud") as Control
	if hud == null:
		return
	var viewport_rect := Rect2(Vector2.ZERO, PROBE_VIEWPORT)
	if not viewport_rect.encloses(hud.get_global_rect()):
		_fail("Combat objective HUD should remain fully on-screen at 1920x1080")
	var intensity: Control = instance.get("_intensity_bar") as Control
	if intensity == null or not intensity.visible or hud.get_global_rect().position.y < intensity.get_global_rect().end.y + 8.0:
		_fail("Combat objective HUD should sit beneath the elemental intensity indicators")
	var play_meter: Control = instance.get("_play_meter") as Control
	if play_meter != null and play_meter.visible:
		var dock_gap: float = play_meter.get_global_rect().position.y - hud.get_global_rect().end.y
		if dock_gap < 8.0 or dock_gap > 20.0:
			_fail("Combat objective HUD should sit immediately above the Pass/card-play dock")
	var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
	if board_bounds.size.x > 0.0 and board_bounds.size.y > 0.0 and hud.get_global_rect().intersects(board_bounds):
		_fail("Combat objective HUD should remain in the side utility lane instead of covering the board")
	var turn_order: Control = instance.get("_turn_order_panel") as Control
	if turn_order != null and turn_order.visible and hud.get_global_rect().intersects(turn_order.get_global_rect()):
		_fail("Combat objective HUD should not overlap the initiative rail")

func _dictionary_has_all(dictionary: Dictionary, keys: Array[Vector2i]) -> bool:
	for key: Vector2i in keys:
		if not dictionary.has(key):
			return false
	return true

func _labels_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for label_var: Variant in node.find_children("*", "Label", true, false):
		parts.append((label_var as Label).text)
	return "\n".join(parts)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png("%s/%s" % [OUTPUT_DIR, filename])
	if error != OK:
		_fail("Could not save %s" % filename)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

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

func _finish(instance: Node) -> void:
	instance.queue_free()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
