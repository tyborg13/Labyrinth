extends SceneTree
## Title and covered boot proof for each resumable mode.

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Checkpoint = preload("res://scripts/run_checkpoint.gd")
const SEED := 83
const DEADLINE_USEC := 30_000_000
const VIEWPORT := Vector2i(1920, 1080)
const FRAME_LIMIT := 120
const RUN_SCENE := "res://scenes/run_scene.tscn"
const MARKER := "perf146_mode_checkpoint"
const EVENT_ID := "lost_cartographer"
const HEIRLOOM := "undertaker_plate"

class QuitAfterReward extends RunScene:
	func _continue_pending_escape_after_reward() -> bool:
		# Stop after the real reward handler has committed its checkpoint and
		# before its awaited travel. The next process runs unmodified travel.
		if str(_run_state.get("mode")) == "escape":
			print("PERF146 MODE_QUIT escape reward_committed=true")
			_on_exit_to_desktop_pressed()
		return false

var _engine = Run.new()
var _case: String
var _output: String
var _write_on_quit: bool
var _capture: bool
var _deadline: int
var _save: String

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): _case = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		elif argument == "--write-on-quit": _write_on_quit = true
		elif argument == "--capture": _capture = true
	_run.call_deferred()

func _run() -> void:
	_deadline = Time.get_ticks_usec() + DEADLINE_USEC
	Engine.max_fps = FRAME_LIMIT
	root.mode = Window.MODE_WINDOWED
	root.size = VIEWPORT
	_save = _output.path_join("current_run.save")
	Store.set_storage_path("user://perf146-mode-profile.json")
	Store.set_run_storage_path(_save)
	Settings.set_storage_path("user://perf146-mode-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": true}, true)
	if not Settings.save_settings(settings):
		_fail("could not write settings")
		return
	if _write_on_quit:
		await _write_quit_fixture()
		return
	var expected_mode: String = "event" if _case == "event-result" else _case
	if _case not in ["event", "escape"]:
		var fixture := _fixture()
		fixture[MARKER] = _case
		if not _save_fixture(fixture): return
	var saved: Dictionary = Store.load_saved_run()
	if saved.get("mode") != expected_mode or saved.get(MARKER) != _case:
		_fail("missing checkpoint for " + expected_mode)
		return
	if not _rejects_incomplete_mode(saved, expected_mode):
		_fail("incomplete mode data passed the checkpoint validator")
		return
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	if menu.continue_button.disabled or menu.resume_location_label.text.is_empty():
		_fail("title hid Continue")
		return
	if _case == "event" and not menu.resume_location_label.text.ends_with("EVENT"):
		_fail("event label is missing")
		return
	if _case == "escape" and not menu.resume_location_label.text.ends_with("REACH EXIT"):
		_fail("escape label is missing")
		return
	if _capture and not await _capture_frame("title"): return
	menu.continue_button.pressed.emit()
	if not await _until(func() -> bool: return current_scene.name != &"MenuRunTransition", "waiting for covered Continue"): return
	var run: Node = current_scene
	if run == menu or not run.has_method("has_installed_run") or not run.has_installed_run():
		_fail("Continue did not install the checkpoint")
		return
	if _case == "escape":
		var destination: Vector2i = saved["pending_escape"]["destination"]
		if not await _until(func() -> bool:
			return run._run_state.get("current_room") == destination and run._run_state.get("pending_escape", {}).is_empty()
		, "waiting for the saved escape route"): return
		if run._run_state["reward_cards"] != saved["reward_cards"] or run._run_state["reward_cards"].is_empty():
			_fail("the claimed reward changed on resume")
			return
	elif run._run_state.get("mode") != expected_mode or run._run_state.get("current_room") != saved.get("current_room"):
		_fail("resume changed the saved mode or room")
		return
	if expected_mode == "event":
		var event: Dictionary = saved["event_state"]
		if not is_instance_valid(run._event_view) or not run._event_view.visible or run._event_view.page != event["page"] or run._run_state["event_state"] != event:
			_fail("resumed event lost its choice or result page")
			return
	var same_run: bool = run._run_state.get(MARKER) == _case and run._run_state.get("seed") == saved.get("seed") and run._run_state.get("player_hp") == saved.get("player_hp")
	if not same_run:
		_fail("resumed run lost its identity or Health")
		return
	if _capture and not await _capture_frame("resumed"): return
	print("PERF146 MODE ", _case, " title_continue=true same_run=true mode_after=", run._run_state["mode"], " room=", run._run_state["current_room"])
	_stop_voices(root)
	await process_frame
	await process_frame
	quit()

func _rejects_incomplete_mode(saved: Dictionary, mode: String) -> bool:
	if mode not in ["event", "escape"]: return true
	var invalid: Dictionary = saved.duplicate(true)
	if mode == "event":
		invalid["event_state"].erase("page")
	else:
		invalid["pending_escape"].erase("target_tile")
	return Checkpoint.validated_resume_summary(invalid).is_empty()

func _write_quit_fixture() -> void:
	var fixture: Dictionary = _escape_reward() if _case == "escape" else _fixture()
	if not _save_fixture(fixture): return
	var run: Node = (load(RUN_SCENE) as PackedScene).instantiate()
	if _case == "escape": run.set_script(QuitAfterReward)
	root.set_meta("labyrinth_resume_saved_run", true)
	root.add_child(run)
	current_scene = run
	if not run.has_installed_run():
		_fail("could not install quit fixture")
		return
	run._run_state[MARKER] = _case
	run._close_dialogue()
	if _case == "event":
		if not is_instance_valid(run._event_view) or not run._event_view.visible or run._event_view.page != "choices":
			_fail("quit fixture did not show event choices")
			return
		print("PERF146 MODE_QUIT event choices_visible=true")
		Shutdown.request(self, "mode_probe")
	else:
		var reward: String = run._run_state["pending_reward"]["cards"][0]
		run._on_reward_card_pressed(reward)
		await _until(func() -> bool:
			return int(root.get_meta(Shutdown.STATE_META).requested_usec) > 0
		, "waiting to quit after claim")

func _fixture() -> Dictionary:
	match _case:
		"room": return _new_room()
		"campfire", "graftwright", "treasure", "event": return _first_room(_case)
		"event-result": return _engine.resolve_map_event(_first_room("event"), "embers")
		"pre_battle": return _first_room("combat", true)
		"combat": return _first_room("combat")
		"reward": return _escape_reward()
		"victory", "defeat": return _heirloom_fixture()
	return {}

func _new_room() -> Dictionary:
	var profile: Dictionary = Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var state: Dictionary = _engine.create_new_run(SEED, profile)
	if Boons.pending(state): state = Boons.choose(_engine, state, "")
	return state

func _first_room(kind: String, pre_battle: bool = false) -> Dictionary:
	var state := _new_room()
	var moves: Array[Vector2i] = _engine.available_moves(state)
	if moves.is_empty(): return {}
	var destination: Vector2i = moves.front()
	var room: Dictionary = Graph.room(state, destination)
	room.merge({"type": kind, "cleared": false, "npcs": []}, true)
	if kind == "event": room["event_id"] = EVENT_ID
	return _engine.move_to_pre_battle(state, destination) if pre_battle else _engine.move_to_room(state, destination)

func _escape_reward() -> Dictionary:
	var combat := _first_room("combat")
	var current: Vector2i = combat["current_room"]
	var room: Dictionary = Graph.room(combat, current)
	var exits: Array = room.get("connections", []).filter(func(link: Dictionary) -> bool:
		return link.get("kind") == "outward" and combat["rooms"].has(Graph.key(link["coord"]))
	)
	if exits.is_empty(): return {}
	var link: Dictionary = exits.front()
	var destination: Vector2i = link["coord"]
	Graph.room(combat, destination).merge({"type": "campfire", "revealed": true, "sealed": false}, true)
	var direction: Vector2i = link["door_dir"]
	var tile: Vector2i = Objectives.exit_target_tile_for_direction(direction)
	var board: Dictionary = combat["combat_state"]
	board["objective"] = {"type": Objectives.REACH_EXIT, "exits": [{
		"target_tile": tile, "door_tile": Objectives.door_tile_for_direction(direction),
		"direction": direction, "coord": destination, "kind": "outward"
	}]}
	board["player"]["pos"] = tile
	var reward: Dictionary = _engine.finish_combat(combat, board)
	if reward.get("mode") != "reward" or reward.get("pending_escape", {}).is_empty(): return {}
	reward["pending_reward"]["intro_pending"] = false
	return reward

func _heirloom_fixture() -> Dictionary:
	var state := _first_room("combat")
	state["collected_equipment"].append(HEIRLOOM)
	state["equipped_equipment"]["armor"] = HEIRLOOM
	if _case == "defeat":
		var board: Dictionary = state["combat_state"]
		board["player"]["hp"] = 0
		return _engine.finish_combat(state, board)
	# Continue a final milestone on the same legal demo map.
	state["mode"] = "reward"
	state["pending_reward"] = {"kind": "dragon", "milestone_id": "perf146", "final_boss": true}
	return _engine.continue_dragon_reward(state)

func _save_fixture(fixture: Dictionary) -> bool:
	if fixture.is_empty() or not Store.save_data(fixture["progression"]) or not Store.save_run_state(fixture):
		_fail("could not write mode fixture")
		return false
	return true

func _stop_voices(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	for child: Node in node.get_children(): _stop_voices(child)

func _until(ready: Callable, failure: String) -> bool:
	while not bool(ready.call()):
		if Time.get_ticks_usec() >= _deadline:
			_fail(failure)
			return false
		await process_frame
	return true

func _capture_frame(stem: String) -> bool:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var path := _output.path_join(stem + ".png")
	if frame == null or frame.is_empty() or frame.save_png(path) != OK:
		_fail("could not capture " + path)
		return false
	print(path)
	return true

func _fail(message: String) -> void:
	push_error("PERF146 mode " + _case + ": " + message)
	quit(1)
