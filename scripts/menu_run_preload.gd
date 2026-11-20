extends RefCounted
## Tracks accepted engine loads through startup, title idle and the cover.
## The idle request belongs to the root, even if the title leaves the tree.
## The cover can claim it later, and shutdown attempts to drain it.

const RUN_SCENE_PATH := "res://scenes/run_scene.tscn"
const IDLE_SECONDS: float = 1.0
const ENGINE_STOP_LOAD_BUDGET_USEC: int = 5000000
const SHUTDOWN_LOAD_POLL_USEC: int = 1000
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
	watch.request = _request_idle.bind(tree)
	menu.add_child(watch)

static func has_requested_run_scene(tree: SceneTree) -> bool:
	return tree.root.has_meta(PACKED_SCENE_META) or _pending(tree).has(RUN_SCENE_PATH)

class Request extends RefCounted:
	var abandoned: bool
	var idle: bool
	var frame: int
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS

static func _request_idle(tree: SceneTree) -> void:
	if has_requested_run_scene(tree): return
	if request_for(tree, RUN_SCENE_PATH) == OK:
		_pending(tree)[RUN_SCENE_PATH].idle = true

static func request_for(tree: SceneTree, path: String, type_hint: String = "PackedScene") -> Error:
	if path == RUN_SCENE_PATH and tree.root.has_meta(PACKED_SCENE_META): return OK
	var pending := _pending(tree)
	if pending.has(path):
		pending[path].abandoned = false
		pending[path].idle = false
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

static func drain_for_shutdown(tree: SceneTree, wait_for_idle_preload: bool = true) -> bool:
	var pending := _pending(tree)
	var settled := true
	for path: String in pending.keys():
		var request: Request = pending[path]
		if request.idle:
			if not wait_for_idle_preload: continue
			if request.status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				status_for(tree, path)
				settled = false
				continue
		_take_pending(tree, path)
		if pending.has(path): settled = false
	return settled

static func finish_shutdown(root: Window) -> void:
	var pending: Dictionary = root.get_meta(REQUESTS_META, {})
	var deadline_usec := Time.get_ticks_usec() + ENGINE_STOP_LOAD_BUDGET_USEC
	for path: String in pending.keys():
		if not _finish_pending(pending, path, deadline_usec): return

static func _finish_pending(pending: Dictionary, path: String, deadline_usec: int) -> bool:
	if not pending.has(path): return true
	# Engine stops such as --quit-after reach tree exit without another frame.
	# Leave unfinished loads to Godot when the shared teardown budget expires.
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_usec() < deadline_usec:
		status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(path)
			return true
		var remaining_usec := deadline_usec - Time.get_ticks_usec()
		if remaining_usec <= 0: return false
		# Godot 4.6.1 can publish terminal status before releasing its worker
		# reference. Leave one scheduling turn before collecting that token.
		OS.delay_usec(mini(SHUTDOWN_LOAD_POLL_USEC, remaining_usec))
	if Time.get_ticks_usec() >= deadline_usec: return false
	if pending.erase(path): ResourceLoader.load_threaded_get(path)
	return true

static func _pending(tree: SceneTree) -> Dictionary:
	if tree.root != null and tree.root.has_meta(REQUESTS_META): return tree.root.get_meta(REQUESTS_META)
	return {}
