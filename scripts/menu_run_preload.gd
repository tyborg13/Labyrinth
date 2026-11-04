extends Node

## One menu-to-run resource request, shared by idle preparation and activation.
## The engine owns the pending request; the tree retains its activated result.
## Leave polling/retrieval under the loading canvas, so title frames never join
## the request. Other title surfaces neither cancel nor restart the preload.
const RUN_SCENE_PATH: String = "res://scenes/run_scene.tscn"
const JOB_NAME: String = "MenuRunPreload"
const IDLE_SECONDS: float = 1.0

var _requested: bool = false
var _packed: PackedScene

func _exit_tree() -> void:
	# A title/Chronicle exit can leave the idle request unclaimed. Join it while
	# script and resource loaders are still alive, before engine teardown begins.
	if _requested and _packed == null:
		_packed = ResourceLoader.load_threaded_get(RUN_SCENE_PATH) as PackedScene

class IdleWatch extends Node:
	var request: Callable
	var _last_input_usec: int

	func _ready() -> void:
		_last_input_usec = Time.get_ticks_usec()

	func _input(_event: InputEvent) -> void:
		_last_input_usec = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _last_input_usec < int(IDLE_SECONDS * 1000000.0): return
		request.call()
		queue_free()

static func watch_menu(menu: Control) -> void:
	var existing: Node = menu.get_tree().root.get_node_or_null(JOB_NAME)
	if existing != null and existing._requested: return
	var watch := IdleWatch.new()
	watch.name = "RunSceneIdlePreload"
	watch.request = request_for.bind(menu.get_tree(), RUN_SCENE_PATH)
	menu.add_child(watch)

static func request_for(tree: SceneTree, path: String) -> Error:
	if path != RUN_SCENE_PATH:
		return ResourceLoader.load_threaded_request(path, "PackedScene")
	var job: Node = tree.root.get_node_or_null(JOB_NAME)
	if job == null:
		job = load("res://scripts/menu_run_preload.gd").new()
		job.name = JOB_NAME
		job.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(job)
	if job._requested and status_for(tree, path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
		return OK
	var error: Error = ResourceLoader.load_threaded_request(path, "PackedScene")
	job._requested = error == OK
	return error

static func status_for(tree: SceneTree, path: String) -> ResourceLoader.ThreadLoadStatus:
	var job: Node = tree.root.get_node_or_null(JOB_NAME) if path == RUN_SCENE_PATH else null
	if job != null and job._packed != null: return ResourceLoader.THREAD_LOAD_LOADED
	return ResourceLoader.load_threaded_get_status(path)

static func get_for(tree: SceneTree, path: String) -> PackedScene:
	var job: Node = tree.root.get_node_or_null(JOB_NAME) if path == RUN_SCENE_PATH else null
	if job == null: return ResourceLoader.load_threaded_get(path) as PackedScene
	if job._packed == null: job._packed = ResourceLoader.load_threaded_get(path) as PackedScene
	return job._packed
