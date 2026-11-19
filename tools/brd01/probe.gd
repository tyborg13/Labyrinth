extends SceneTree
## Release and working-tree evidence. --baseline permits transform differences,
## but fails on broken fixtures or interactions in both modes.
const Fixture = preload("res://tools/brd01/fixture.gd")
const ENCOUNTERS := ["combat", "guardian", "boss"]
const OUTPUTS := [Fixture.DESKTOP, Fixture.DECK]
const SCALES := [1.0, 1.15]
const MAX_HAND: int = 10
const PROOF_ZOOM: float = 1.2
const PROOF_PAN := Vector2(24, 16)
const HOVER_SECONDS: float = 0.3
const READY_FRAME_LIMIT: int = 40

var _scene: Control
var _board: Control
var _router: Node
var _hero_tile: Vector2i
var _context: Dictionary
var _baseline: Dictionary
var _rows: int
var _differences: int
var _failures: Array[String]

func _initialize() -> void:
	Fixture.Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	# Headless Godot omits this render notification. Drive the same continuation
	# used by the game's hover-rest and committed-card presentation.
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	# Retain the actual Window stretch transform and bypass host display-mode
	# changes while the probe requests its two physical output sizes.
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	root.content_scale_size = Fixture.DESKTOP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_router = root.get_node("InputRouter")
	for kind: String in ENCOUNTERS:
		var run: Dictionary = Fixture.encounter(kind)
		if run.get("mode") != "combat":
			_failures.append("Failed to generate " + kind)
			continue
		for output: Vector2i in OUTPUTS:
			for scale: float in SCALES:
				await _display(run, kind, output, scale)
	for failure: String in _failures: print("BRD01 ERROR ", failure)
	var allow_shifts: bool = OS.get_cmdline_user_args().has("--baseline")
	var passed: bool = _failures.is_empty() and (allow_shifts or _differences == 0)
	print("BRD01 PROBE RESULT: %s (%d rows, %d changed rows, %d setup errors)" % [
		"PASS" if passed else "FAIL", _rows, _differences, _failures.size(),
	])
	quit(0 if passed else 1)

func _display(run: Dictionary, kind: String, output: Vector2i, scale: float) -> void:
	root.size = output
	for device: String in ["pointer", "controller"]:
		var family: String = Fixture.Router.FAMILY_STEAM_DECK if output == Fixture.DECK else Fixture.Router.FAMILY_XBOX
		_router.call("set_forced_state_for_test", device, family)
		_scene = Fixture.mount(self, root, run, scale)
		if _scene == null:
			_failures.append("Could not mount %s at %s" % [kind, output])
			break
		_board = _scene.get("board_view")
		var source: Dictionary = _scene.get("_combat_state")
		if source.get("player", {}).is_empty():
			_failures.append("Combat did not load for " + kind)
			_scene.queue_free()
			await process_frame
			continue
		_hero_tile = source["player"]["pos"]
		await Fixture.settle(self)
		var tween: Tween = _scene.get("_board_centering_tween")
		if tween != null and tween.is_running(): await tween.finished
		_context = {
			"encounter": kind, "seed": run["seed"], "room": str(run["current_room"]),
			"enemies": source["enemies"].map(func(enemy: Dictionary) -> String: return str(enemy["type"])),
			"input": device, "output": [output.x, output.y], "ui_scale": scale,
			"logical": str(root.get_visible_rect().size),
		}
		_require(root.size == output and is_equal_approx(root.content_scale_factor, scale), "requested physical output and UI scale")
		for frame: int in range(READY_FRAME_LIMIT):
			if Fixture.ready_for_input(_scene): break
			await process_frame
		_require(Fixture.ready_for_input(_scene), "room entry and HUD budget settled")
		var controller: bool = device == "controller"
		for count: int in range(1, MAX_HAND + 1):
			_context["hand"] = count
			for action: String in Fixture.CARDS:
				Fixture.set_hand(_scene, source, Fixture.CARDS[action], count)
				_prepare_hand(controller)
				await Fixture.settle(self)
				await _selection(action, controller)
			await _hover(controller, count)
		_context["hand"] = MAX_HAND
		await _overlays()
		if not controller: await _pointer_drag_and_pan()
		await _play_summon(controller)
		_scene.queue_free()
		await process_frame

func _prepare_hand(controller: bool) -> void:
	if not controller: return
	_scene.call("_controller_clear_focus_candidate")
	_scene.set("_controller_region", "hand")
	_scene.call("_controller_set_hand_focused", true)
	_scene.set("_controller_hand_index", 0)

func _selection(action: String, controller: bool) -> void:
	_start_case(action)
	if controller: await Fixture.controller_button(_scene, JOY_BUTTON_A)
	else: await _scene.call("_on_card_pressed", 0)
	var targeting: bool = _scene.call("_board_targeting_active")
	var actions: Array = _scene.get("_pending_actions")
	_require(int(_scene.get("_selected_card_index")) == 0 and targeting == (action != "targetless")
		and not actions.is_empty() and actions[0].get("_card_id") == Fixture.CARDS[action], "card reached expected preview")
	_sample("selected")
	await Fixture.settle(self)
	_sample("selected_settled")
	if controller: await Fixture.controller_button(_scene, JOY_BUTTON_B)
	elif action == "targetless": await _scene.call("_on_cancel_requested", false)
	else: await _scene.call("_on_card_pressed", 0)
	_require(int(_scene.get("_selected_card_index")) < 0, "card deselected")
	_sample("deselected")
	await Fixture.settle(self)
	_sample("deselected_settled")

func _hover(controller: bool, count: int) -> void:
	_prepare_hand(controller)
	await Fixture.settle(self)
	_start_case("hand_hover")
	var index: int = count - 1
	if controller: _scene.call("_controller_set_hand_index", index)
	else: _scene.call("_on_card_hover_started", index)
	await Fixture.settle(self)
	_require(int(_scene.get("_hovered_card_index")) == index, "hover entered")
	_sample("hover")
	# One held-tooltip sample per device/output/encounter, in addition to every
	# hand count's hover-enter and hover-exit.
	if count == MAX_HAND:
		await create_timer(HOVER_SECONDS).timeout
		_require((_scene.get("_card_focus_tooltip_stack") as Control).visible, "hand tooltip visible")
		_sample("tooltip")
	if controller: _scene.call("_controller_clear_hand_hover")
	else: _scene.call("_on_card_hover_ended", index)
	await Fixture.settle(self)
	_sample("hover_ended")

func _overlays() -> void:
	_start_case("draw_pile")
	_scene.call("_open_pile_view", "draw")
	await Fixture.settle(self)
	_require((_scene.get("_pile_scrim") as Control).visible, "draw pile visible")
	_sample("open")
	_scene.call("_close_pile_view")
	await Fixture.settle(self)
	_require(not (_scene.get("_pile_scrim") as Control).visible, "draw pile closed")
	_sample("closed")
	_start_case("grimoire")
	_scene.call("_open_grimoire_overlay")
	await Fixture.settle(self)
	_require((_scene.get("_grimoire_scrim") as Control).visible, "Grimoire visible")
	_sample("open")
	_scene.call("_close_grimoire_overlay")
	await Fixture.settle(self)
	_require(not (_scene.get("_grimoire_scrim") as Control).visible, "Grimoire closed")
	_sample("closed")

func _pointer_drag_and_pan() -> void:
	var before: Dictionary = Fixture.coordinates(_board, _hero_tile)
	_board.call("set_navigation_zoom", PROOF_ZOOM)
	_board.call("set_navigation_pan", PROOF_PAN)
	_start_case("drag_after_explicit_camera_input")
	_require(_baseline != before, "explicit camera input moves the board")
	var source: Vector2 = (_scene.call("_hand_card_global_rect", 0) as Rect2).get_center()
	_scene.call("_on_card_drag_started", 0, source)
	_sample("drag_started")
	await _scene.call("_enter_drag_targeting")
	_require(bool(_scene.get("_drag_targeting_active")), "drag entered targeting")
	_sample("drag_targeting")
	await _scene.call("_on_cancel_requested", false)
	await Fixture.settle(self)
	_require(int(_scene.get("_drag_card_index")) < 0 and int(_scene.get("_selected_card_index")) < 0, "drag cancelled")
	_sample("drag_cancelled")

func _play_summon(controller: bool) -> void:
	_prepare_hand(controller)
	await Fixture.settle(self)
	_start_case("summon_commit")
	if controller: await Fixture.controller_button(_scene, JOY_BUTTON_A)
	else: await _scene.call("_on_card_pressed", 0)
	_sample("targeting_open")
	var targets: Array = _scene.get("_pending_target_tiles")
	if targets.is_empty():
		_require(false, "summon has a legal target")
		return
	var tile: Vector2i = targets[0]
	if controller:
		_scene.call("_controller_set_board_tile", tile)
		await Fixture.controller_button(_scene, JOY_BUTTON_A)
	else:
		await _scene.call("_on_board_tile_clicked", tile)
	_sample("play_complete")
	await Fixture.settle(self)
	_require(int(_scene.get("_selected_card_index")) < 0 and not bool(_scene.call("_board_targeting_active")), "playing a summon closed targeting")
	_require(not ((_scene.get("_combat_state") as Dictionary).get("illusions", []) as Array).is_empty(), "summon entered the live board")
	_sample("play_settled")

func _start_case(name: String) -> void:
	_context["case"] = name
	_baseline = Fixture.coordinates(_board, _hero_tile)
	_sample("unselected")

func _sample(phase: String) -> void:
	var transform: Dictionary = Fixture.coordinates(_board, _hero_tile)
	var same: bool = _baseline == transform
	_rows += 1
	if not same: _differences += 1
	var row: Dictionary = _context.duplicate()
	row.merge({"phase": phase, "same": same, "transform": transform})
	print("BRD01 ROW ", JSON.stringify(row, "", true, true))

func _require(condition: bool, message: String) -> void:
	if not condition: _failures.append("%s: %s" % [str(_context), message])
