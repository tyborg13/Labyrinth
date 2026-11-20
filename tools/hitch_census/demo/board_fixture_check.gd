extends SceneTree
## Exercises both physical inputs from the exact QA cursor position. The
## checkpoint supplies the room; no replay decision or game state is patched.
const Proof = preload("res://tools/hitch_census/demo/board_proof.gd")
const Paths = preload("res://tools/hitch_census/demo/board_paths.gd")
const Route = preload("res://tools/hitch_census/demo/route.gd")
const Joy = preload("res://tools/hitch_census/demo/joypad.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const SETTLE_FRAMES: int = 6
const READY_TIMEOUT_MS: int = 10000
const UI_SCALE: float = 1.0
const DECK_SIZE := Vector2i(1280, 800)
const DESKTOP_SIZE := Vector2i(1920, 1080)
var scene: Node
var board: Control
var failures: Array[String]
var targets: int = 0
var offscreen_targets: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not FileAccess.file_exists(args[0]) or not FileAccess.file_exists(args[1]):
		push_error("Board fixture expects the qa-116 run.save and progression.json")
		quit(2)
		return
	var state: Dictionary = FileAccess.open(args[0], FileAccess.READ).get_var()
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	Store.set_storage_path("user://gfix-19-progression.json")
	Store.set_run_storage_path("user://gfix-19-run.save")
	Settings.set_storage_path("user://gfix-19-settings.json")
	Store.save_data(profile)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["edge_smoothing"] = "off"
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	root.content_scale_size = DESKTOP_SIZE
	root.get_node("InputRouter").call("set_forced_state_for_test", "controller", "steam_deck")
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set("_defer_initial_run_presentation", true)
	root.add_child(scene)
	scene.set("_defer_initial_run_presentation", false)
	board = scene.get("board_view")
	for size: Vector2i in [DECK_SIZE, DESKTOP_SIZE]:
		root.size = size
		await _settle()
		scene.call("_load_run_state", state.duplicate(true))
		scene.call("_close_dialogue")
		scene.set("_animation_lock", false)
		await _settle()
		# Loading this room can schedule the map reveal for the next frame.
		scene.call("_close_large_map")
		var deadline: int = Time.get_ticks_msec() + READY_TIMEOUT_MS
		while not scene.call("_controller_custom_room_available") and Time.get_ticks_msec() < deadline:
			await process_frame
		var scope: Control = scene.call("_controller_focus_scope")
		if not scene.call("_controller_custom_room_available"):
			failures.append("Fixture did not settle into room board input, scope=%s" % scope.name)
			break
		var exits: Dictionary = scene.get("_exit_destinations_by_tile")
		_expect(exits.get(Proof.TARGET_TILE) == Proof.DESTINATION_ROOM, "QA door is still legal")
		var origin: Vector2 = scene.call("_controller_board_point", Proof.TARGET_TILE)
		await _room_input(origin)
		var nav: Dictionary = board.call("navigation_snapshot")
		board.call("set_navigation_zoom", nav["max_zoom"])
		nav = board.call("navigation_snapshot")
		var limits: Rect2 = nav["pan_limits"]
		var viewport: Rect2 = root.get_visible_rect()
		var offscreen: int = offscreen_targets
		for pan: Vector2 in [limits.position, limits.end]:
			board.call("set_navigation_pan", pan)
			await _settle()
			await _zoomed_exits(exits, viewport)
		# The room normally fits within the viewport even at max zoom. Translate
		# the test board past the viewport edge to exercise clipped floor geometry.
		var board_position: Vector2 = board.position
		var target_point: Vector2 = scene.call("_controller_board_point", Proof.TARGET_TILE)
		board.position.x += viewport.end.x - target_point.x + scene.CONTROLLER_TILE_CURSOR_MAGNET_RADIUS
		await _zoomed_exits(exits, viewport)
		_expect(offscreen_targets > offscreen, "Zoom fixture puts a legal exit off-screen at %s" % size)
		board.position = board_position
		board.call("reset_navigation")
	for problem: String in failures:
		print("DEMO BOARD FIXTURE DETAIL: " + problem)
	print("DEMO BOARD FIXTURE: %s (%d zoomed legal targets, %d off-screen, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", targets, offscreen_targets, failures.size()
	])
	quit(0 if failures.is_empty() else 1)

func _room_input(origin: Vector2) -> void:
	_free_cursor(origin)
	await _button(JOY_BUTTON_A)
	_expect(scene.get("_run_state")["current_room"] == Proof.SOURCE_ROOM and scene.get("_controller_focus_candidate").is_empty(), "Free Accept leaves the room and cursor unchanged")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	_expect(scene.get("_controller_focus_candidate").get("tile") == Proof.TARGET_TILE, "D-pad acquires the door under a free cursor")
	_free_cursor(origin)
	var direction: Vector2 = (root.get_visible_rect().get_center() - origin).normalized()
	_motion(JOY_AXIS_LEFT_X, direction.x * Joy.STICK_MAGNITUDE)
	_motion(JOY_AXIS_LEFT_Y, direction.y * Joy.STICK_MAGNITUDE)
	await physics_frame
	await physics_frame
	_motion(JOY_AXIS_LEFT_X, 0.0)
	_motion(JOY_AXIS_LEFT_Y, 0.0)
	_expect(scene.get("_controller_focus_candidate").get("tile") == Proof.TARGET_TILE, "Left stick acquires the same door")

func _zoomed_exits(exits: Dictionary, viewport: Rect2) -> void:
	for tile: Vector2i in exits:
		_free_cursor(viewport.get_center())
		var key: String = scene.call("_controller_tile_key", tile)
		for _step: int in range((exits.size() + 1) * Route.EDGES.size()):
			var current: Dictionary = scene.get("_controller_focus_candidate")
			if current.get("key") == key: break
			var origin: Vector2 = scene.get("_controller_virtual_board_position")
			var candidates: Array[Dictionary] = scene.call("_controller_navigation_candidates")
			var buttons: Dictionary = Paths.first_buttons(current, origin, true, candidates, Route.EDGES)
			if not buttons.has(key): break
			await _button(int(buttons[key]))
		var point: Vector2 = scene.call("_controller_board_point", tile)
		if not viewport.has_point(point): offscreen_targets += 1
		targets += 1
		_expect(board.get("_controller_focus_tile") == tile, "D-pad reaches zoomed exit %s at %s" % [tile, point])

func _free_cursor(origin: Vector2) -> void:
	scene.set("_controller_virtual_board_position", origin)
	scene.call("_controller_enter_board", false)

func _button(index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	root.push_input(event)
	await _settle()
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	root.push_input(released)

func _motion(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event)

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

func _expect(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)
