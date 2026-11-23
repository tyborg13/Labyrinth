extends Node
## A separate process per route so engine cleanup is part of every observation.

const Shutdown = preload("res://scripts/application_shutdown.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")

const SEED := 83
const FRAME_LIMIT := 120
const ROUTE_TIMEOUT_MSEC := 20000
const WINDOW_SIZE := Vector2i(1920, 1080)
const STORAGE := "user://gfix41"
const TITLE := "res://scenes/main_menu.tscn"
const STARTUP := "res://scenes/startup.tscn"
const IDLE_LOAD_DELAYS_MSEC := {"idle-load": 0, "idle-load-close": 25, "idle-load-late": 75, "idle-load-near-end": 1500}
const OTHER_CASES := ["title", "idle-loaded", "cover", "startup", "pause", "movement", "enemy", "card", "steam"]

var _tree: SceneTree
var _case: String
var _deadline: int
var _native_close: bool
var _armed: bool
var _capture_path: String
var _quit_usec: int

func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): _case = argument.trim_prefix("--case=")
		elif argument == "--native-close": _native_close = true
		elif argument.begins_with("--capture="): _capture_path = argument.trim_prefix("--capture=")
	if not OTHER_CASES.has(_case) and not IDLE_LOAD_DELAYS_MSEC.has(_case):
		_fail("specify one of %s" % str(OTHER_CASES + IDLE_LOAD_DELAYS_MSEC.keys()))
		return
	_deadline = Time.get_ticks_msec() + ROUTE_TIMEOUT_MSEC
	Engine.max_fps = FRAME_LIMIT
	DirAccess.make_dir_recursive_absolute(STORAGE)
	Store.set_storage_path(STORAGE.path_join("profile.json"))
	Store.set_run_storage_path(STORAGE.path_join("run.save"))
	Settings.set_storage_path(STORAGE.path_join("settings.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	if not Settings.save_settings(settings):
		_fail("could not save probe settings")
		return
	_tree.root.size = WINDOW_SIZE
	_tree.root.content_scale_size = WINDOW_SIZE
	_tree.root.set_meta("labyrinth_performance_probe_seed", SEED)
	var headless: bool = DisplayServer.get_name() == "headless"
	if headless: _tree.process_frame.connect(_simulate_draw)
	if _case == "startup":
		var startup: Node = _open(STARTUP)
		if await _until(func() -> bool: return startup._fade_tween != null and startup._fade_tween.is_running(), "startup fade"):
			_request("startup fade tween running")
	elif _case in ["title", "cover", "idle-loaded"] or IDLE_LOAD_DELAYS_MSEC.has(_case):
		await _title()
	else:
		await _combat()

func _title() -> void:
	var title: Node = _open(TITLE)
	if not _capture_path.is_empty():
		if DisplayServer.get_name() == "headless":
			_fail("title capture requires a native renderer")
			return
		await RenderingServer.frame_post_draw
		var image := _tree.root.get_texture().get_image()
		if image == null or image.get_size() != WINDOW_SIZE or image.save_png(_capture_path) != OK:
			_fail("could not save the 1920x1080 title capture")
			return
		print(ProjectSettings.globalize_path(_capture_path))
	match _case:
		"title":
			_request("title ready", title.quit_button)
		"cover":
			title.start_button.pressed.emit()
			if await _until(func() -> bool:
				var cover := _tree.current_scene
				return cover != title and is_instance_valid(cover) and cover._scene_pending
			, "loading cover and accepted threaded load"):
				_request("cover awaiting the threaded scene")
		_:
			await _quit_during_idle_load(title)

func _quit_during_idle_load(title: Control) -> void:
	if not await _until(func() -> bool: return SceneLoads.has_requested_run_scene(_tree), "title idle load"):
		return
	var observed_msec := Time.get_ticks_msec()
	if _case == "idle-loaded":
		if await _until(func() -> bool: return _run_load_status() == ResourceLoader.THREAD_LOAD_LOADED, "completed title idle load"):
			_request("idle load completed at +%dms" % (Time.get_ticks_msec() - observed_msec), title.quit_button)
		return
	var delay_msec: int = IDLE_LOAD_DELAYS_MSEC[_case]
	while Time.get_ticks_msec() - observed_msec < delay_msec:
		await _tree.process_frame
	if _run_load_status() != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_fail("title idle scene load is no longer pending at +%dms" % (Time.get_ticks_msec() - observed_msec))
		return
	var button: Button = null if _case == "idle-load-close" else title.quit_button
	_request("idle threaded scene load pending at +%dms" % (Time.get_ticks_msec() - observed_msec), button)

func _run_load_status() -> ResourceLoader.ThreadLoadStatus:
	return ResourceLoader.load_threaded_get_status(SceneLoads.RUN_SCENE_PATH)

func _combat() -> void:
	var profile: Dictionary = Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	for coord: Vector2i in engine.available_moves(state):
		var candidate: Dictionary = engine.move_to_room(state.duplicate(true), coord)
		if candidate.get("mode") == "combat":
			state = candidate
			break
	if state.get("mode") != "combat" or not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		_fail("could not save combat fixture")
		return
	_tree.root.set_meta("labyrinth_resume_saved_run", true)
	var run: Node = _open(SceneLoads.RUN_SCENE_PATH)
	if not await _until(run.initial_presentation_is_ready, "combat presentation"): return
	run._close_dialogue()
	match _case:
		"pause":
			run.menu_button.pressed.emit()
			if not run._menu_scrim.visible:
				_fail("pause menu did not open")
				return
			_request("pause menu open")
		"movement":
			run._begin_player_movement_selection()
			var targets: Array[Vector2i] = run._player_movement_target_tiles
			if targets.is_empty():
				_fail("fixture has no legal movement")
				return
			run._commit_player_movement(targets[0])
			if run._animation_lock: _request("combat movement in flight")
			else: _fail("movement did not start")
		"enemy", "steam":
			run._on_pass_turn_pressed()
			if await _until(func() -> bool:
				return run._animation_lock and not run._combat_engine.is_player_turn(run._combat_state)
			, "active enemy turn"):
				_request("enemy turn in flight")
		"card":
			await _play_card(run)

func _play_card(run: Node) -> void:
	var hand: Array = run._combat_state["deck"]["hand"]
	for index: int in range(hand.size()):
		if not bool(run._card_play_options_for_index(index).get("printed_playable", false)): continue
		run._on_card_pressed(index)
		while not run._animation_lock and run._selected_card_index == index:
			if run._pending_card_requires_confirmation():
				run._on_confirm_card_play_pressed()
			elif not run._pending_target_tiles.is_empty():
				run._on_board_tile_clicked(run._pending_target_tiles[0])
			else:
				break
		if run._animation_lock:
			if await _until(func() -> bool: return run._card_fx_layer.get_child_count() > 0, "card flight"):
				_request("card resolution proxy in flight")
			return
		run._cancel_card_selection()
	_fail("fixture has no playable card")

func _open(path: String) -> Node:
	var scene := (load(path) as PackedScene).instantiate()
	_tree.root.add_child(scene)
	_tree.current_scene = scene
	return scene

func _simulate_draw() -> void:
	RenderingServer.frame_post_draw.emit()

func _until(condition: Callable, description: String) -> bool:
	while not condition.call():
		if Time.get_ticks_msec() >= _deadline:
			_fail("timed out at " + description)
			return false
		await _tree.process_frame
	return true

func _request(point: String, button: Button = null) -> void:
	print("GFIX41 ARMED %s pid=%d %s" % [_case, OS.get_process_id(), point])
	_armed = true
	_quit_usec = Time.get_ticks_usec()
	_tree.root.tree_exiting.connect(_check_shutdown, CONNECT_ONE_SHOT)
	if _native_close:
		if DisplayServer.get_name() == "headless" or _case not in ["movement", "enemy", "card", "cover", "startup"]:
			_fail("--native-close requires a window-close case on a native renderer")
			return
		print("GFIX41 READY: close the native window now")
		return
	# A minimized window can stop delivering draws. Headless frame simulation
	# supplies the real action's draw boundaries only up to the quit request.
	if _tree.process_frame.is_connected(_simulate_draw): _tree.process_frame.disconnect(_simulate_draw)
	if button != null:
		button.pressed.emit()
	elif _case == "pause":
		_tree.current_scene._on_exit_to_desktop_pressed()
	elif _case == "steam":
		_tree.root.get_node("SteamService")._on_steam_shutdown()
	else:
		_tree.root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_tree.root.close_requested.emit()

func _check_shutdown() -> void:
	var state: RefCounted = _tree.root.get_meta(Shutdown.STATE_META)
	var pending: Dictionary = _tree.root.get_meta(SceneLoads.REQUESTS_META, {})
	print("GFIX41 EXIT %s pending=%s elapsed_ms=%.1f" % [_case, str(pending.keys()), (Time.get_ticks_usec() - _quit_usec) / 1000.0])
	if not _capture_path.is_empty() and not pending.is_empty():
		_fail("title exited with a pending threaded load")
		return
	if _armed and state.drain_completed:
		print("GFIX41 QUIT TEST RESULT: PASS (%s, managed drain complete)" % _case)
	else:
		_fail("managed drain incomplete")

func _fail(message: String) -> void:
	print("GFIX41 QUIT TEST RESULT: FAIL (%s, %s)" % [_case, message])
	_tree.quit(1)
