extends SceneTree

const Fixtures = preload("fixtures.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const TIMEOUT_MSEC: int = 20000

class ObserveEngine extends "res://scripts/run_engine.gd":
	var after_departure: int = 0

	func move_to_pre_battle(state: Dictionary, destination: Vector2i) -> Dictionary:
		var tree := Engine.get_main_loop() as SceneTree
		var run: Node = tree.current_scene
		if Assets.preparation_is_stopping(tree.root) or run._leaving_tree:
			after_departure += 1
			var shutdown: RefCounted = tree.root.get_meta(Shutdown.STATE_META)
			shutdown.exit_code = 1
		return super.move_to_pre_battle(state, destination)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Settings.set_storage_path("user://quitwalk-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Store.set_storage_path("user://quitwalk-profile.json")
	Store.set_run_storage_path("user://quitwalk-run.save")
	var fixture: Dictionary = Fixtures.make("graftwright", 0)
	Store.save_data(fixture["state"]["progression"])
	Store.save_run_state(fixture["state"])
	var run: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(run)
	current_scene = run
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while not run.has_installed_run() and Time.get_ticks_msec() < deadline: await process_frame
	run._close_dialogue()
	run._close_large_map()
	run._open_large_map()
	await process_frame
	var engine := ObserveEngine.new()
	run._run_engine = engine
	run._large_map_view.activate_room(fixture["target"])
	if run._large_map_view.activation_coord != fixture["target"]:
		print("TEST RESULT: FAIL — Graftwright map walk did not start")
		quit(1)
		return
	root.tree_exiting.connect(func() -> void:
		var result: String = "PASS" if engine.after_departure == 0 else "FAIL"
		print("TEST RESULT: %s — selected-room generations after departure=%d (expected 0)" % [result, engine.after_departure])
	)
	_request_quit.call_deferred()

func _request_quit() -> void:
	Shutdown.request(self, "perf168_quit_walk")
