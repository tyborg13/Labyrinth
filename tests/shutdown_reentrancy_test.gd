extends SceneTree
## Match perf-78's native callback order: RunScene has left the tree when
## CursorFeedback restores the OS mouse during SceneTree::finalize.
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const FIXTURE_SEED: int = 83
const SETTLE_FRAMES: int = 2
var _scene: Control
var _failures: Array[String]
var _assertions: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://shutdown_reentrancy")
	Store.set_storage_path("user://shutdown_reentrancy/profile.json")
	Store.set_run_storage_path("user://shutdown_reentrancy/run.save")
	_run.call_deferred()

func _run() -> void:
	var profile: Dictionary = Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	for coord: Vector2i in engine.available_moves(state):
		var candidate: Dictionary = engine.move_to_room(state.duplicate(true), coord)
		if str(candidate.get("mode", "")) == "combat":
			state = candidate
			break
	_check(str(state.get("mode", "")) == "combat", "live combat fixture")
	_check(Store.save_data(state["progression"]), "durable profile fixture")
	_check(Store.save_run_state(state), "durable combat fixture")
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_scene.call("_close_dialogue")
	_scene.set("_hand_pointer_position_valid", true)
	_scene.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_check(not _scene.get("_hand_pointer_position_valid"), "live mouse exit still clears the pointer")
	await process_frame
	# Also model native restoration while the scene is still attached. Its
	# notification must stop at the cursor's published exit state.
	var cursor: Node = root.get_node("CursorFeedback")
	cursor.set("_exiting_tree", true)
	_scene.set("_hand_pointer_position_valid", true)
	_scene.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_check(_scene.get("_hand_pointer_position_valid"), "cursor restoration cannot refresh an attached scene")
	cursor.set("_exiting_tree", false)
	_scene.tree_exiting.connect(_check_leaving_scene)
	# perf-78 used this exact signal and root notification, without releasing
	# the cursor early. Headless mouse-mode changes alone cannot trigger it.
	root.get_node("CursorFeedback").tree_exiting.connect(_simulate_macos_shutdown)
	print("QA-74 SHUTDOWN REPRO: armed (real finalize, live combat)")
	quit(0 if _failures.is_empty() else 1)

func _check_leaving_scene() -> void:
	_check(_scene.is_inside_tree(), "exit flag is tested before scene detachment")
	_scene.set("_hand_pointer_position_valid", true)
	for what: int in [Node.NOTIFICATION_WM_MOUSE_EXIT, Control.NOTIFICATION_RESIZED, Node.NOTIFICATION_WM_CLOSE_REQUEST, Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_RESUMED]:
		_scene.notification(what)
	_check(_scene.get("_hand_pointer_position_valid"), "leaving scene ignores pointer/window notifications")
	var board: Control = _scene.get("board_view")
	_check(board.get_viewport() == null, "board detached before parent exit")
	var updates: int = board.get("_static_render_cache_update_count")
	_check(board.call("_static_render_cache_size") == Vector2i.ZERO, "detached cache has no pixel size")
	board.call("_sync_static_render_cache")
	_check(board.get("_static_render_cache_update_count") == updates, "detached cache never renders")

func _simulate_macos_shutdown() -> void:
	_check(is_instance_valid(_scene) and not _scene.is_inside_tree(), "RunScene detached before cursor exit")
	_check(root.get_node("CursorFeedback").is_exiting_tree(), "cursor publishes exit state before native restoration")
	_scene.set("_hand_pointer_position_valid", true)
	_scene.set("_hovered_card_index", -1)
	var state_before: Dictionary = _scene.get("_run_state").duplicate(true)
	root.propagate_notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_check(_scene.get("_hand_pointer_position_valid"), "finalize mouse exit must not enter gameplay handlers")
	_check(_scene.get("_run_state") == state_before, "finalize must preserve run state")
	print("QA-74 SHUTDOWN REENTRANCY TEST RESULT: %s (%d assertions; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertions, _failures.size()])
	for failure: String in _failures: push_error(failure)
	if not _failures.is_empty(): quit(1)

func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok: _failures.append(message)
