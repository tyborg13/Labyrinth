extends SceneTree
## Perf-145 fault injection. Runs against release and either performance branch.

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const SAVE := "user://perf-145-run.save"
const OLD_SEED := 144
const NEW_SEED := 145
const LATE_SEED := 146
const GRAPH_DEPTH := 0
const RECOVERY_EMBERS := 5
const RECOVERY_ROOM := Vector2i(1, 0)
const RECOVERY_RUN_INDEX := -1
const FRAME_LIMIT := 120
const WAIT_USEC := 30000000
const HELD_GRAPH_SAMPLE_USEC := 200000

class FakeSteam extends RefCounted:
	signal steam_shutdown

var _case: String
var _storage := "user://"
var _deadline: int
var _menu: Control
var _fake_steam: FakeSteam
var _held: RefCounted

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): _case = argument.trim_prefix("--case=")
		elif argument.begins_with("--storage="): _storage = argument.trim_prefix("--storage=")
	_start.call_deferred()

func _start() -> void:
	_deadline = Time.get_ticks_usec() + WAIT_USEC
	Engine.max_fps = FRAME_LIMIT
	Store.set_run_storage_path(SAVE)
	var profile_path := _storage.path_join("perf-145-profile.json")
	Store.set_storage_path(profile_path)
	if _case == "clock": Store.set_run_storage_path(_storage.path_join("perf-145-clock.save"))
	Settings.set_storage_path("user://perf-145-settings.json")
	Analytics.set_storage_dir("user://perf-145-events")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	var profile: Dictionary = Store.default_data()
	if _case == "profile": profile = Store.record_lost_embers(profile, RECOVERY_EMBERS, RECOVERY_ROOM, RECOVERY_RUN_INDEX)
	if not Settings.save_settings(settings) or (not FileAccess.file_exists(profile_path) and not Store.save_data(profile)):
		_fail("could not write fixture")
		return
	root.set_meta("labyrinth_performance_probe_seed", NEW_SEED)
	match _case:
		"replacement", "empty", "profile": await _failed_checkpoint(profile)
		"steam", "debug-seed": await _held_graph()
		"clock": await _clock()
		_: _fail("unknown case")

func _failed_checkpoint(profile: Dictionary) -> void:
	var previous := _case != "empty"
	if previous:
		var checkpoint: Dictionary = Run.new().create_new_run(OLD_SEED, profile)
		checkpoint["surface_rules_version"] = Store.SURFACE_RULES_VERSION
		if not Store.save_run_state(checkpoint):
			_fail("could not write previous checkpoint")
			return
	var obstruction: String = ProjectSettings.globalize_path(SAVE + ".tmp")
	if DirAccess.make_dir_absolute(obstruction) != OK:
		_fail("could not obstruct the first checkpoint")
		return
	if previous:
		print("PERF145 ORIGINAL ", ProjectSettings.globalize_path(SAVE), " ", FileAccess.get_sha256(SAVE))
	else:
		print("PERF145 ORIGINAL ", ProjectSettings.globalize_path(SAVE), " missing")
	_open_title()
	_start_run(previous)
	if not await _until(func() -> bool: return int(Store.load_data().get("run_counter", 0)) == 1, "waiting for first checkpoint attempt"): return
	var queued: bool = Store._run_writer.busy()
	var error_dialog: bool = is_instance_valid(_menu) and is_instance_valid(_menu._loading_error) and _menu._loading_error.visible
	print("PERF145 FAILED_WRITE queued=", queued, " dialog=", error_dialog, " disk_seed=", Store.load_saved_run().get("seed", -1), " run_counter=", Store.load_data()["run_counter"])
	if _case == "profile":
		print("PERF145 PROFILE marker_lost=", Store.recovery_marker(Store.load_data()).is_empty())
		_native_close()
		return
	if DirAccess.remove_absolute(obstruction) != OK:
		_fail("could not clear the transient obstruction")
		return
	if _case == "empty":
		if not await _until(func() -> bool:
			return _run_visible() or (is_instance_valid(_menu) and is_instance_valid(_menu._loading_error) and _menu._loading_error.visible)
		, "waiting for reveal or error dialog"): return
		print("PERF145 EMPTY revealed=", _run_visible(), " has_seed=", _run_visible() and current_scene._run_state.has("seed"),
			" has_graph=", _run_visible() and not current_scene._run_state.get("map_sections", []).is_empty())
	print("PERF145 CLOSE_REQUEST")
	_native_close()

func _held_graph() -> void:
	_open_title()
	if _case == "steam":
		var steam := root.get_node("SteamService")
		_fake_steam = FakeSteam.new()
		steam._steam = _fake_steam
		steam._connect_stats_callbacks()
		print("PERF145 STEAM connected=", not _fake_steam.steam_shutdown.get_connections().is_empty())
	_start_run(false)
	var cover := root.get_node("MenuRunTransition")
	if not await _until(func() -> bool: return is_instance_valid(cover.destination), "waiting for loading destination"): return
	var staged: Node = cover.destination
	if not staged.has_method("adopt_initial_run_graph"):
		if _case == "steam":
			_fake_steam.steam_shutdown.emit()
			if not await _until(_run_visible, "waiting for release reveal"): return
			print("PERF145 STEAM committed_seed=", Store.load_saved_run().get("seed", -1))
		else:
			root.set_meta("labyrinth_performance_probe_seed", LATE_SEED)
			if not await _until(_run_visible, "waiting for release reveal"): return
			print("PERF145 DEBUG no_background_graph=true seed=", current_scene._run_state.get("seed", -1))
		quit()
		return
	var preparation: Script = load("res://scripts/initial_run_graph.gd")
	_held = preparation.Preparation.new()
	_held.seed = NEW_SEED
	_held.depth = GRAPH_DEPTH
	staged.adopt_initial_run_graph(_held)
	if not await _until(func() -> bool: return staged._defer_initial_run_presentation and staged._initial_run_graph == _held, "waiting for graph consumer"): return
	if _case == "steam":
		_fake_steam.steam_shutdown.emit()
		print("PERF145 STEAM cancelled=", _held.cancellation.is_cancelled(), " disk_seed=", Store.load_saved_run().get("seed", -1))
		if _held.cancellation.is_cancelled(): return
		# The old branch continues to a durable save after Steam's request.
		var graph: Dictionary = {"seed": NEW_SEED}
		preload("res://scripts/section_map_graph.gd").initialize(graph)
		graph.erase("seed")
		_held.graph = graph
		_held.pending = false
		if not await _until(_run_visible, "waiting for boot despite Steam shutdown"): return
		print("PERF145 STEAM committed_seed=", Store.load_saved_run().get("seed", -1))
	else:
		root.set_meta("labyrinth_performance_probe_seed", LATE_SEED)
	var end := Time.get_ticks_usec() + HELD_GRAPH_SAMPLE_USEC
	while Time.get_ticks_usec() < end: await process_frame
	print("PERF145 HELD cancelled=", _held.cancellation.is_cancelled(), " pending=", _held.pending, " disk_seed=", Store.load_saved_run().get("seed", -1))
	if _case == "debug-seed" and _held.cancellation.is_cancelled():
		if not await _until(_run_visible, "waiting for the replacement seed"): return
		print("PERF145 DEBUG seed=", current_scene._run_state.get("seed", -1), " disk_seed=", Store.load_saved_run().get("seed", -1))
	_native_close()

func _clock() -> void:
	root.remove_meta("labyrinth_performance_probe_seed")
	_open_title()
	_start_run(false)
	if not await _until(_run_visible, "waiting for automatic seed"): return
	print("PERF145 CLOCK seed=", current_scene._run_state.get("seed", -1))
	current_scene._on_abandon_run_pressed()
	if not await _until(func() -> bool: return current_scene != null and current_scene.has_node("MenuColumn"), "waiting for title after abandon"): return
	print("PERF145 CLOCK abandoned=", not Store.has_saved_run())
	_native_close()

func _open_title() -> void:
	_menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	_menu.get_node("MusicPlayer").stop()
	var watch: Node = _menu.get_node_or_null("RunSceneIdlePreload")
	if watch != null: watch.set_process(false)

func _start_run(replace: bool) -> void:
	_menu.start_button.pressed.emit()
	if replace: _menu.replacement_confirm_button.pressed.emit()

func _native_close() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	root.close_requested.emit()
	if auto_accept_quit: quit()

func _run_visible() -> bool:
	return current_scene != null and current_scene.has_method("initial_presentation_is_ready") and not root.gui_disable_input

func _until(condition: Callable, label: String) -> bool:
	while not bool(condition.call()):
		if Time.get_ticks_usec() >= _deadline:
			_fail(label)
			return false
		await process_frame
	return true

func _fail(message: String) -> void:
	push_error("PERF145 PROBE " + message)
	quit(1)
