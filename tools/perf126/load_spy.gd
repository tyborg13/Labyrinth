extends RefCounted
## Disposable-project instrumentation only; never loaded by the shipped game.
const THRESHOLD_US: int = 2000

static func load_resource(path: String, type_hint: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Resource:
	var started: int = Time.get_ticks_usec()
	var result: Resource = ResourceLoader.load(path, type_hint, cache_mode)
	record(path, started, "ResourceLoader.load")
	return result

static func record(path: String, started: int, operation: String) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	var elapsed: int = Time.get_ticks_usec() - started
	if elapsed <= THRESHOLD_US: return
	var tree := Engine.get_main_loop() as SceneTree
	var current: Node = tree.current_scene
	var screen: String = str(current.name) if current != null else "autoload"
	var phase: String = str(current.get("phase")) if current != null and current.get_script() != null and "phase" in current else ""
	print("PERF126 LOAD: " + JSON.stringify({"path": path, "operation": operation, "us": elapsed, "ticks_us": started, "frame": Engine.get_process_frames(), "screen": screen, "phase": phase, "stack": get_stack()}))
