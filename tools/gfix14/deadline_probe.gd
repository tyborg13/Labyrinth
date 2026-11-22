extends SceneTree
## One-off fault injection for both shutdown deadlines.

const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const SLOW_LOAD_MSEC: int = 7000
const STALLED_LOAD_MSEC: int = 30000

class DelayedRunSceneLoader extends ResourceFormatLoader:
	var delay_msec: int

	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["tscn"])

	func _recognize_path(path: String, _type: StringName) -> bool:
		return path == SceneLoads.RUN_SCENE_PATH

	func _load(_path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		OS.delay_msec(delay_msec)
		return PackedScene.new()

var _started_usec: int

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var watchdog_case := OS.get_cmdline_user_args().has("watchdog")
	var loader := DelayedRunSceneLoader.new()
	loader.delay_msec = STALLED_LOAD_MSEC if watchdog_case else SLOW_LOAD_MSEC
	ResourceLoader.add_resource_format_loader(loader, true)
	# perf-165: the idle request also starts the title pipeline warm on a menu control.
	var idle_menu := Control.new()
	root.add_child(idle_menu)
	SceneLoads._request_idle(self, idle_menu)
	if ResourceLoader.load_threaded_get_status(SceneLoads.RUN_SCENE_PATH) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		push_error("GFIX14 DEADLINE: delayed load did not start")
		quit(1)
		return
	_started_usec = Time.get_ticks_usec()
	print("GFIX14 DEADLINE: requested quit with load delayed %d ms" % loader.delay_msec)
	if watchdog_case:
		root.close_requested.emit()
	else:
		root.tree_exiting.connect(_report_root_exit, CONNECT_ONE_SHOT)
		quit()

func _report_root_exit() -> void:
	var elapsed_ms := (Time.get_ticks_usec() - _started_usec) / 1000.0
	var retained := ResourceLoader.load_threaded_get_status(SceneLoads.RUN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
	print("GFIX14 DEADLINE: root exit elapsed_ms=%.3f request_in_progress=%s" % [elapsed_ms, retained])
	if not retained:
		push_error("GFIX14 DEADLINE: root waited past its budget and collected the delayed request")
		quit(1)
