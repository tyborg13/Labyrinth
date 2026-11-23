extends "res://tools/scn02/live_entry_probe.gd"
## Compare framing on a generated route, using game-written checkpoints for Continue.

const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Events = preload("res://scripts/event_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const REFERENCE_SCALE: float = 1.0
const SCALED_REFERENCE: float = 1.15
const COMPACT_SIZE := Vector2i(1280, 800)
const SECOND_FIGHT := Vector2i(0, 1)
const CONFIGURATIONS: Dictionary = {
	"desktop": [SIZE, REFERENCE_SCALE],
	"compact": [COMPACT_SIZE, REFERENCE_SCALE],
	"scaled": [SIZE, SCALED_REFERENCE],
}

var _host: Viewport
var _scene: PackedScene
var _entry_path: String
var _configuration: String


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" or args.size() != 3 or not CONFIGURATIONS.has(args[2]):
		_fail("Expected a room, an entry path and a desktop/compact/scaled configuration.")
		return
	var scenario: String = args[0]
	if (not CASES.has(scenario) and scenario not in ["waypoint", "reward_after_room"]) \
		or args[1] not in ["reference", "continue", "walk_after_continue"] \
		or (scenario == "waypoint" and args[1] == "walk_after_continue"):
		_fail("Expected a supported reference/continue/walk_after_continue route.")
		return
	_entry_path = args[1]
	_configuration = args[2]
	if Runtime.apply_from_environment().is_empty():
		_fail("Expected a task-local user directory.")
		return
	if Store.has_saved_run():
		_fail("Reference requires a fresh run with no existing checkpoint.")
		return
	var settings: Dictionary = Settings.load_settings()
	var size: Vector2i = CONFIGURATIONS[_configuration][0]
	var ui_scale: float = CONFIGURATIONS[_configuration][1]
	settings["ui_scale"] = ui_scale
	var profile: Dictionary = Tutorial.dismiss_tutorial(Store.default_data())
	if not Settings.save_settings(settings) or not Store.save_data(profile):
		_fail("Could not prepare the isolated New Run profile.")
		return
	Engine.max_fps = FPS
	process_frame.connect(func() -> void: RenderingServer.force_draw(false))
	if ui_scale == REFERENCE_SCALE:
		var viewport := SubViewport.new()
		viewport.size = size
		viewport.msaa_2d = root.msaa_2d
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		_host = viewport
	else:
		# Window content scaling changes the logical size. A fixed SubViewport
		# ignores that transform even when its containing window is scaled.
		root.size = size
		_host = root
	_scene = load("res://scenes/run_scene.tscn")
	root.set_meta(InitialGraph.SEED_OVERRIDE, SEED)
	_open_run(false)
	if not await _wait(func() -> bool: return _screen.call("initial_presentation_is_ready")):
		_fail("New Run did not present the Central Waypoint.")
		return
	var run: Dictionary = _screen.get("_run_state")
	if run.get("seed") != SEED or not _entered(Vector2i.ZERO, "room"):
		_fail("New Run did not start at the Central Waypoint with the requested seed.")
		return
	if scenario == "waypoint":
		if not await _record_destination(Vector2i.ZERO, "room", scenario):
			_fail("Could not measure the Central Waypoint.")
			return
	else:
		var destination: Vector2i = SECOND_FIGHT if scenario == "reward_after_room" else CASES[scenario]
		var path: Array[Vector2i] = Route.find(run, destination)
		var target: String = "reward" if scenario == "reward_after_room" else scenario
		if path.is_empty() or not await _walk(path, target):
			_fail("Could not complete the %s route." % scenario)
			return
	_screen.queue_free()
	if _host != root: _host.queue_free()
	await process_frame
	print("GFIX36 PROBE RESULT: PASS — %s / %s / %s" % [scenario, _entry_path, _configuration])
	quit(0)


func _walk(path: Array[Vector2i], scenario: String) -> bool:
	var won_fight: bool = false
	for destination: Vector2i in path:
		var final_room: bool = destination == path.back()
		if final_room and _entry_path == "walk_after_continue":
			var run: Dictionary = _screen.get("_run_state")
			var predecessor: Vector2i = run["current_room"]
			var room: Dictionary = _engine.room_metadata(run, predecessor)
			if not room.get("cleared", false): return false
			print("GFIX36 CONTINUE PREDECESSOR %s (%s)" % [predecessor, room["type"]])
			if not await _reopen(predecessor, "room"): return false
		if not await _enter_door(destination):
			return false
		var mode: String = (_screen.get("_run_state") as Dictionary)["mode"]
		if mode == RunEngine.MODE_PRE_BATTLE:
			if not await _win() or not await _settled(destination, "reward", "reward"):
				return false
			won_fight = true
			if final_room and scenario == "reward":
				if not await _record_destination(destination, "reward", "reward"): return false
			await _screen.call("_on_skip_reward_pressed")
			if not await _wait(_entered.bind(destination, "room")): return false
			if final_room and scenario == "reward":
				if not await _wait(func() -> bool: return not _has_running_tweens()): return false
				return await _record_destination(destination, "room", "cleared_plain")
			continue
		if final_room:
			var expected_mode: String = "room" if scenario == "scavenger" else scenario
			if not await _settled(destination, expected_mode, scenario): return false
			return won_fight and await _record_destination(destination, expected_mode, scenario)
		if not await _leave_intermediate_room(destination, mode): return false
	return won_fight


func _open_run(resume: bool) -> void:
	_screen = _scene.instantiate() as Control
	if resume: root.set_meta("labyrinth_resume_saved_run", true)
	_host.add_child(_screen)


func _reopen(destination: Vector2i, mode: String) -> bool:
	_screen.queue_free()
	await process_frame
	var saved: Dictionary = Store.load_checkpoint_for_resume()
	if saved.get("current_room") != destination or saved.get("mode") != mode:
		print("GFIX36 CHECKPOINT Expected %s in %s, got %s in %s" % [mode, destination, saved.get("mode"), saved.get("current_room")])
		return false
	_open_run(true)
	return await _wait(func() -> bool: return _screen.call("initial_presentation_is_ready") and _entered(destination, mode))


func _record_destination(destination: Vector2i, mode: String, scenario: String) -> bool:
	if _entry_path == "continue":
		if not await _reopen(destination, mode): return false
		if scenario in ["reward", "campfire", "treasure", "scavenger"] and not await _settled(destination, mode, scenario): return false
	if not await _wait(func() -> bool: return not _has_running_tweens()): return false
	_record(scenario)
	return true


func _enter_door(destination: Vector2i) -> bool:
	if _screen.get("_dialogue_active"): _screen.call("_close_dialogue")
	if (_screen.get("_large_map_scrim") as Control).visible: _screen.call("_close_large_map")
	var run: Dictionary = _screen.get("_run_state")
	var door: Vector2i = _screen.call("_door_tile_for_destination", destination)
	print("GFIX36 REFERENCE DOOR %s via %s to %s" % [run["current_room"], door, destination])
	if door.x < 0: return false
	_screen.get("board_view").emit_signal("tile_clicked", door)
	return await _wait(func() -> bool:
		return (_screen.get("_run_state") as Dictionary)["current_room"] == destination and not _screen.get("_animation_lock"))


func _win() -> bool:
	await _screen.call("_on_pre_battle_start_pressed")
	var run: Dictionary = _screen.get("_run_state")
	if not await _wait(_entered.bind(run["current_room"], "combat")): return false
	run = _screen.get("_run_state")
	var combat: Dictionary = run["combat_state"].duplicate(true)
	var foes: Array = combat["enemies"]
	if foes.is_empty(): return false
	for foe: Dictionary in foes:
		foe["hp"] = 0
	var target: Dictionary = foes[0]
	target["hp"] = FINISHER_TARGET_HP
	target["block"] = 0
	var grid: Array = combat["grid"]
	var player_tile: Vector2i = combat["player"]["pos"]
	var action: Dictionary = GameData.card_def(FINISHER_CARD)["actions"][0]
	var candidates: Array[Vector2i] = PathUtils.diamond_tiles(player_tile, int(action["range"]), grid)
	candidates.push_front(FINISHER_TARGET_TILE)
	var combat_engine: RefCounted = _screen.get("_combat_engine")
	var legal_tile := Vector2i(-1, -1)
	for tile: Vector2i in candidates:
		if tile == player_tile or not PathUtils.is_passable(grid, tile): continue
		target["pos"] = tile
		if combat_engine.valid_targets_for_player_action(combat, action).has(tile):
			legal_tile = tile
			break
	if legal_tile.x < 0:
		print("GFIX36 REFERENCE No legal finishing tile in %s" % run["current_room"])
		return false
	# Only prepare the last hit. The live card handlers commit the actual
	# action, outcome and checkpoint in the same scene that opened the door.
	combat["deck"]["hand"] = [FINISHER_CARD]
	_screen.set("_run_state", _engine.set_combat_state(run, combat))
	_screen.call("_sync_combat_state_from_run")
	_screen.call("_refresh_ui")
	await process_frame
	await _screen.call("_on_card_pressed", 0)
	if not (_screen.get("_pending_target_tiles") as Array).has(legal_tile):
		print("GFIX36 REFERENCE Finishing tile %s rejected in %s" % [legal_tile, run["current_room"]])
		return false
	_screen.get("board_view").emit_signal("tile_clicked", legal_tile)
	return true


func _leave_intermediate_room(destination: Vector2i, mode: String) -> bool:
	match mode:
		"room":
			return true
		"campfire":
			_screen.call("_on_campfire_linger_pressed")
		"treasure":
			if not await _settled(destination, mode, "treasure"): return false
			var run: Dictionary = _screen.get("_run_state")
			await _screen.call("_on_relic_pressed", run["pending_relics"][0])
		"event":
			var run: Dictionary = _screen.get("_run_state")
			_screen.call("_on_section_map_event", Events.first_available_choice_id(run))
			if (_screen.get("_run_state") as Dictionary).get("event_state", {}).get("page") == "result":
				_screen.call("_on_section_map_event", "continue")
		_:
			print("GFIX36 UNEXPECTED ROUTE MODE %s" % mode)
			return false
	return await _wait(_entered.bind(destination, "room"))


func _record(scenario: String) -> void:
	var stage: Dictionary = StageState.read(_screen)
	var budget: RefCounted = _screen.call("_active_board_hud_budget") if _screen.has_method("_active_board_hud_budget") else _screen.get("_board_hud_budget")
	var board: Control = _screen.get("board_view")
	var fit: Rect2 = board.get("presentation").get("board_fit_rect", Rect2())
	print("GFIX36 SAMPLE %s" % JSON.stringify({
		"case": scenario,
		"path": _entry_path,
		"configuration": _configuration,
		"viewport": str(_screen.get_viewport_rect().size),
		"ui_scale": root.content_scale_factor,
		"room": stage["room"],
		"mode": stage["mode"],
		"fit_origin": [fit.position.x, fit.position.y],
		"fit_size": stage["board_fit_size"],
		"tile_width": stage["tile_width"],
		"board_rect": stage["board_rect"],
		"budget_key": str(budget.get("key")),
		"desktop_hand_top": budget.get("desktop_hand_top"),
		"collapsed_strip": budget.get("collapsed_strip"),
	}))
