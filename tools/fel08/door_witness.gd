extends RefCounted

const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const Tooltip = preload("res://scripts/board_tile_tooltip.gd")

const OBJECTIVE_DIRECTION := Vector2i.UP
const LOCKED_DIRECTION := Vector2i.RIGHT
const PLAIN_DOOR := Vector2i(4, 8)
const OPEN_ENTRY := {"title": "Exit", "description": "Reach the marked tile in front to escape.", "icon": ""}
const SEALED_ENTRY := {"title": "Sealed exit", "description": "Blocks movement and sight.", "icon": ""}
const PLAIN_ENTRY := {"title": "Door", "description": "Blocks movement and sight.", "icon": ""}
const THRESHOLD_TOOLTIP := "Objective threshold · Reach this tile to clear the encounter."
const VISION_BONUS: int = Combat.UMBRA_UNLIMITED_RADIUS


static func run(probe: SceneTree) -> bool:
	Store.set_run_storage_path("user://fel08_door_witness.save")
	Store.set_storage_path("user://fel08_door_witness_profile.json")
	var path: String = probe.FIXTURES.path_join(probe.DOOR).path_join(probe.Checkpoint.RUN_FILE)
	var state: Dictionary = Store._load_run_dictionary(path)
	if state.is_empty(): return _fail(probe, "cannot read the ordinary door fixture")
	var objective_exit: Dictionary = _ordinary_fixture(state)
	if objective_exit.is_empty(): return _fail(probe, "ordinary fixture has no north connection")
	var scene: Node = await _mount(probe, state)
	if scene == null: return false
	var board: Control = scene.get("board_view")
	if not await _hover(probe, scene, "ordinary_exit", objective_exit["door_tile"], OPEN_ENTRY, "exit-hover.png"): return false
	if not _has_threshold_tooltip(board, objective_exit["target_tile"]):
		return _fail(probe, "ordinary threshold lost its existing tooltip")
	if not await _hover(probe, scene, "plain_exit_options", PLAIN_DOOR, PLAIN_ENTRY, "door-hover.png"): return false
	if not await _hover(probe, scene, "locked_visited", Objectives.door_tile_for_direction(LOCKED_DIRECTION), PLAIN_ENTRY): return false
	if probe._dry and not _edge_checks(probe, scene): return false
	await _unmount(probe)

	var room: Dictionary = state.duplicate(true)
	room["mode"] = "room"
	room["combat_state"] = {}
	Graph.room(room, room["current_room"])["cleared"] = true
	scene = await _mount(probe, room)
	if scene == null: return false
	if not await _hover(probe, scene, "active_room", objective_exit["door_tile"], {}): return false
	await _unmount(probe)

	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Snare.FIXTURE_SEED, Store.default_data())
	for study: String in ["first_turn", "kept_open", "first_seal"]:
		var snare_state: Dictionary = Snare.build(engine, combat, source, {"snare_case": study})
		snare_state["combat_state"]["umbra"]["vision_bonus"] = VISION_BONUS
		var exits: Array = snare_state["combat_state"]["objective"]["exits"]
		scene = await _mount(probe, snare_state)
		if scene == null: return false
		if study == "first_turn":
			if exits[0].get("role") != "jailer" or exits[1].get("role") != "sealing" or exits[1].get("kept_open"):
				return _fail(probe, "Snare first turn did not supply the gaoler and timed exits")
			if not await _hover(probe, scene, "snare_gaoler", exits[0]["door_tile"], OPEN_ENTRY): return false
			if not await _hover(probe, scene, "snare_timed", exits[1]["door_tile"], OPEN_ENTRY): return false
		elif study == "kept_open":
			if not exits[1].get("kept_open"): return _fail(probe, "Snare exit was not kept open")
			if not await _hover(probe, scene, "snare_kept_open", exits[1]["door_tile"], OPEN_ENTRY): return false
		elif not await _hover(probe, scene, "snare_sealed", exits[1]["door_tile"], SEALED_ENTRY, "sealed-exit-hover.png"):
			return false
		await _unmount(probe)
	print("FEL08 DOOR WITNESS PASS combat=7 room=1 threshold=unchanged")
	return true


static func _ordinary_fixture(state: Dictionary) -> Dictionary:
	var current_room: Dictionary = Graph.room(state, state["current_room"])
	var objective_exit: Dictionary = {}
	for connection: Dictionary in current_room["connections"]:
		var direction: Vector2i = connection["door_dir"]
		if direction == OBJECTIVE_DIRECTION:
			objective_exit = {"direction": direction, "coord": connection["coord"],
				"door_tile": Objectives.door_tile_for_direction(direction),
				"target_tile": Objectives.exit_target_tile_for_direction(direction)}
		elif direction == LOCKED_DIRECTION:
			var destination: Dictionary = Graph.room(state, connection["coord"])
			destination["visited"] = true
			destination["sealed"] = true
	var objective: Dictionary = {"type": Objectives.REACH_EXIT, "exits": [objective_exit]}
	state["combat_state"]["objective"] = objective
	state["combat_state"]["umbra"]["vision_bonus"] = VISION_BONUS
	return objective_exit


static func _mount(probe: SceneTree, state: Dictionary, resume_saved: bool = false) -> Node:
	if resume_saved:
		if not Store.save_run_state(state):
			_fail(probe, "could not write the resume fixture")
			return null
		probe.root.set_meta("labyrinth_resume_saved_run", true)
	probe._viewport = SubViewport.new()
	probe._viewport.size = probe.Checkpoint.VIEWPORT_SIZE
	probe._viewport.msaa_2d = Viewport.MSAA_4X
	probe._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	probe._viewport.gui_embed_subwindows = true
	probe.root.add_child(probe._viewport)
	probe._inside = false
	if not probe._dry: probe._show_native_preview()
	var scene: Node = probe._instantiate_run_scene()
	probe._viewport.add_child(scene)
	await probe.process_frame
	if resume_saved:
		if not scene.call("has_installed_run"):
			_fail(probe, "Continue did not install the saved fixture")
			return null
	else:
		scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await probe._point(probe.NO_POINTER)
	await probe._settle()
	if state["mode"] == "room": scene.call("_close_large_map")
	if not probe._dry:
		for frame: int in range(probe.ENTRY_FRAMES): await probe.process_frame
		await probe.create_timer(probe.ENTRY_SECONDS).timeout
	var deadline: int = Time.get_ticks_msec() + probe.BOARD_READY_TIMEOUT_MSEC
	while not _board_ready(scene, state["mode"]):
		if Time.get_ticks_msec() >= deadline:
			_fail(probe, "door scene did not finish framing in " + str(state["mode"]))
			return null
		await probe.process_frame
	return scene


static func _board_ready(scene: Node, mode: String) -> bool:
	var centering: Tween = scene.get("_board_centering_tween")
	if centering != null and centering.is_running(): return false
	return scene.call("_combat_objective_board_is_framed") if mode == "combat" else scene.call("initial_presentation_is_ready")


static func _unmount(probe: SceneTree) -> void:
	probe._viewport.queue_free()
	if is_instance_valid(probe._window_frame): probe._window_frame.queue_free()
	await probe.process_frame


static func _edge_checks(probe: SceneTree, scene: Node) -> bool:
	var board: Control = scene.get("board_view")
	var shown: Dictionary = board.presentation
	var hidden: Dictionary = shown.duplicate()
	hidden["locked_door_tiles"] = {}
	var locked_tile: Vector2i = Objectives.door_tile_for_direction(LOCKED_DIRECTION)
	_submit_board(board, hidden)
	if board.call("_display_tile_id", "door", locked_tile) != "wall" or not str(board.call("controller_tooltip_for_tile", locked_tile)).is_empty():
		return _fail(probe, "a connection rendered as wall retained a door panel")
	_submit_board(board, shown)
	var run_state: Dictionary = scene.get("_run_state")
	for mode: String in ["reward", "escape", "combat"]:
		run_state["mode"] = mode
		_submit_board(board, shown)
		var focus: String = board.call("controller_tooltip_for_tile", PLAIN_DOOR)
		if focus.is_empty() == (mode == "combat"):
			return _fail(probe, "held tooltip cache did not follow mode " + mode)
	var original: Dictionary = board.combat_state
	var marked_state: Dictionary = original.duplicate(true)
	marked_state["meteor_marks"] = [{"tiles": [PLAIN_DOOR], "damage": probe.METEOR_DAMAGE}]
	board.combat_state = marked_state
	var marks: Dictionary = Tooltip.mark_entries(board)
	var marked: Array[Dictionary] = Tooltip.build_entries(board, PLAIN_DOOR, marks, {}, {})
	board.combat_state = original
	if probe._titles(marked) != ["Door", "Meteorfall"]:
		return _fail(probe, "marked door did not preserve stack order: " + str(marked))
	print("FEL08 DOOR EDGE PASS inactive=[] reward=[] escape=[] marked=[Door, Meteorfall]")
	return true


static func _has_threshold_tooltip(board: Control, tile: Vector2i) -> bool:
	var sources: Array = board.call("_retained_render_layers")
	sources.append(board)
	var center: Vector2 = board.call("_tile_center", tile)
	for source: Control in sources:
		for region: Dictionary in source.get("_tooltip_regions"):
			if region.get("tooltip") == THRESHOLD_TOOLTIP and (region["rect"] as Rect2).has_point(center):
				return true
	return false


static func _submit_board(board: Control, shown: Dictionary) -> void:
	board.set_combat_state(board.combat_state, board.move_tiles, board.attack_tiles, board.selected_tile,
		board.status_label, board.status_detail, board.exit_tiles, board.exit_icon_ids, shown, true)


static func _hover(probe: SceneTree, scene: Node, label: String, tile: Vector2i, entry: Dictionary, filename: String = "") -> bool:
	var board: Control = scene.get("board_view")
	if not probe._at_rest(scene) and not await probe._reset_hover(scene, board):
		return _fail(probe, label + " pointer reset failed")
	await probe._settle()
	var target: Vector2 = probe.Census.center(board, tile)
	await probe._point(target)
	await probe._settle(true)
	if not probe._dry: await RenderingServer.frame_post_draw
	var mode: String = (scene.get("_run_state") as Dictionary)["mode"]
	var mouse: Array[Dictionary] = probe._popup_entries(board)
	var focus: Dictionary = scene.call("_controller_candidate_for_tile", tile)
	var focus_entries: Array[Dictionary] = Tooltip.decode(str(focus.get("detail_key", "")))
	var expected: Array[Dictionary]
	if not entry.is_empty(): expected.append(entry)
	print("FEL08 DOOR %s tile=%s mode=%s mouse=%s focus=%s" % [label, tile, mode, probe._titles(mouse), probe._titles(focus_entries)])
	if scene.get("_hovered_board_tile") != tile or probe._viewport.gui_get_hovered_control() != board:
		return _fail(probe, "%s hover wanted %s at %s, got %s over %s" % [label, tile, target, scene.get("_hovered_board_tile"), probe._viewport.gui_get_hovered_control()])
	if mode != ("room" if entry.is_empty() else "combat") or mouse != expected or focus_entries != expected:
		return _fail(probe, "%s expected %s, mouse=%s focus=%s" % [label, expected, mouse, focus_entries])
	if entry.is_empty() and (focus.get("detail") != "Travel through this door" or str(scene.call("_room_hover_hint")).is_empty()):
		return _fail(probe, label + " lost its existing focus detail or destination hint")
	if not probe._dry and not filename.is_empty():
		var path: String = probe._destination.path_join(filename)
		var image: Image = probe._viewport.get_texture().get_image()
		if image == null or image.get_size() != probe.Checkpoint.VIEWPORT_SIZE or image.save_png(path) != OK:
			return _fail(probe, "cannot save " + path)
		print(path)
	return true


static func _fail(probe: SceneTree, message: String) -> bool:
	probe._fail("FEL08 DOOR " + message)
	return false
