extends SceneTree

const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Lifecycle = preload("res://scripts/run_persistence.gd")
const OUTPUT_DIR: String = "res://output/perf-03/quit-flush"
const EXIT_CHECKPOINT: int = 4242
var verify: bool = false

class Host extends Node:
	var _analytics_store = Analytics.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	verify = OS.get_cmdline_user_args().has("--verify")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	Progression.set_run_storage_path(OUTPUT_DIR.path_join("run.save"))
	Analytics.set_storage_dir(OUTPUT_DIR.path_join("analytics"))
	if verify:
		var state: Dictionary = Progression.load_saved_run()
		var events: Array[Dictionary] = Analytics.load_all_events()
		var ok: bool = int(state.get("checkpoint", -1)) == EXIT_CHECKPOINT and events.size() == 1 and events[0]["event_type"] == "perf03_quit"
		print("PERF03 PROCESS QUIT FLUSH RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
		return
	Progression.clear_saved_run()
	Analytics.clear_storage()
	var host := Host.new()
	root.add_child(host)
	Lifecycle.attach(host)
	Progression.queue_run_state({"surface_rules_version": Progression.SURFACE_RULES_VERSION, "checkpoint": EXIT_CHECKPOINT})
	host._analytics_store.write_event("perf03_quit")
	print("PERF03 PROCESS QUIT FIXTURE: both queues pending")
	quit() # No test flush: the engine's actual tree shutdown must flush the jobs.
