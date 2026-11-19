extends RefCounted
## Tracks accepted engine loads through startup, title idle and the cover.
## Idle issues only the release scene request. The cover claims it, and
## shutdown keeps pumping until accepted requests settle.

const RUN_SCENE_PATH := "res://scenes/run_scene.tscn"
const IDLE_SECONDS: float = 1.0
const REQUESTS_META := &"labyrinth_threaded_loads"
const PACKED_SCENE_META := &"labyrinth_loaded_run_scene"

class IdleWatch extends Node:
	var request: Callable
	var _last_input_usec: int

	func _ready() -> void:
		_last_input_usec = Time.get_ticks_usec()

	func _input(_event: InputEvent) -> void:
		_last_input_usec = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if get_viewport().gui_disable_input: return
		if Time.get_ticks_usec() - _last_input_usec < int(IDLE_SECONDS * 1000000.0): return
		request.call()
		queue_free()

static func watch_menu(menu: Control) -> void:
	var tree := menu.get_tree()
	if has_requested_run_scene(tree): return
	var watch := IdleWatch.new()
	watch.name = "RunSceneIdlePreload"
	watch.request = request_for.bind(tree, RUN_SCENE_PATH)
	menu.add_child(watch)

static func has_requested_run_scene(tree: SceneTree) -> bool:
	return tree.root.has_meta(PACKED_SCENE_META) or _pending(tree).has(RUN_SCENE_PATH)

class Request extends RefCounted:
	var abandoned: bool
	var frame: int
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS

static func request_for(tree: SceneTree, path: String, type_hint: String = "PackedScene") -> Error:
	if path == RUN_SCENE_PATH and tree.root.has_meta(PACKED_SCENE_META): return OK
	var pending := _pending(tree)
	if pending.has(path):
		pending[path].abandoned = false
		return OK
	var error := ResourceLoader.load_threaded_request(path, type_hint)
	if error == OK:
		var request := Request.new()
		request.frame = Engine.get_process_frames()
		pending[path] = request
		tree.root.set_meta(REQUESTS_META, pending)
	return error

static func status_for(tree: SceneTree, path: String) -> ResourceLoader.ThreadLoadStatus:
	if path == RUN_SCENE_PATH and tree.root.has_meta(PACKED_SCENE_META): return ResourceLoader.THREAD_LOAD_LOADED
	var request: Request = _pending(tree).get(path)
	if request == null: return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	var frame := Engine.get_process_frames()
	# Godot can synchronize the renderer when checking an in-flight request.
	if request.frame != frame:
		request.frame = frame
		request.status = ResourceLoader.load_threaded_get_status(path)
	return request.status

static func take_for(tree: SceneTree, path: String) -> Resource:
	if path == RUN_SCENE_PATH and tree.root.has_meta(PACKED_SCENE_META):
		return tree.root.get_meta(PACKED_SCENE_META)
	var resource := _take_pending(tree, path)
	if path == RUN_SCENE_PATH and resource is PackedScene:
		tree.root.set_meta(PACKED_SCENE_META, resource)
	return resource

static func _take_pending(tree: SceneTree, path: String) -> Resource:
	var status := status_for(tree, path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return null
	if not _pending(tree).erase(path): return null
	# Failed tokens must also be collected before a retry can request the path.
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: return null
	return ResourceLoader.load_threaded_get(path)

static func abandon_for(tree: SceneTree, path: String) -> void:
	var request: Request = _pending(tree).get(path)
	if request == null or request.abandoned: return
	request.abandoned = true
	_reap_abandoned.call_deferred(tree, path, request)

static func _reap_abandoned(tree: SceneTree, path: String, request: Request) -> void:
	while request.abandoned and is_same(_pending(tree).get(path), request):
		if status_for(tree, path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_take_pending(tree, path)
			return
		await tree.process_frame

static func drain_for_shutdown(tree: SceneTree) -> bool:
	var pending := _pending(tree)
	for path: String in pending.keys():
		_take_pending(tree, path)
	return pending.is_empty()

static func _pending(tree: SceneTree) -> Dictionary:
	if tree.root.has_meta(REQUESTS_META): return tree.root.get_meta(REQUESTS_META)
	return {}
