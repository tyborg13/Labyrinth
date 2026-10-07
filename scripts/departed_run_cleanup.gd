extends Node

const TITLE_PATH: String = "res://scenes/main_menu.tscn"
const RUN_PATH: String = "res://scenes/run_scene.tscn"
const SLICE_USEC: int = 4000

var _pending: Array[Node]
var _skip_first_frame: bool = true
var _released_nodes: int = 0
var _slice_count: int = 0
var _maximum_slice_usec: int = 0

# Keep SceneTree's load/instantiate/error handling, exit callbacks, deferred
# current_scene assignment and scene_changed signal. Only a departed run's
# children leave the native all-at-once deletion path. Its root still dies at
# the original scene-change boundary, canceling root-owned continuations.
static func change_scene_to_file(tree: SceneTree, path: String) -> Error:
	var previous: Node = tree.current_scene
	var retire: bool = path == TITLE_PATH and is_instance_valid(previous) and previous.scene_file_path == RUN_PATH
	var result: Error = tree.change_scene_to_file(path)
	if result != OK or not retire or not is_instance_valid(previous): return result
	var drain := new()
	drain.name = "DepartedRunCleanup"
	drain.process_mode = Node.PROCESS_MODE_ALWAYS
	# A freed scene cannot receive new viewport/router/server signals. Give its
	# detached children that same boundary while their CPU destruction is sliced.
	_disconnect_external_receivers(tree, previous)
	for child: Node in previous.get_children(true):
		previous.remove_child(child)
		drain._pending.append(child)
	tree.root.add_child(drain)
	return result

static func _disconnect_external_receivers(tree: SceneTree, previous: Node) -> void:
	var sources: Array[Object]
	sources.append(tree)
	sources.append(tree.root)
	sources.append(RenderingServer)
	for node: Node in tree.root.get_children(): sources.append(node)
	for source: Object in sources:
		for signal_info: Dictionary in source.get_signal_list():
			var signal_name: StringName = signal_info["name"]
			for connection: Dictionary in source.get_signal_connection_list(signal_name):
				var callback: Callable = connection["callable"]
				var target: Node = callback.get_object() as Node
				if is_instance_valid(target) and (target == previous or previous.is_ancestor_of(target)):
					source.disconnect(signal_name, callback)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(true)
	else:
		set_process(false)
		RenderingServer.frame_post_draw.connect(_on_presented_frame)

func _process(_delta: float) -> void:
	_on_presented_frame()

func _on_presented_frame() -> void:
	if _skip_first_frame:
		_skip_first_frame = false
		return
	var started: int = Time.get_ticks_usec()
	while not _pending.is_empty():
		var value: Variant = _pending.back()
		if not is_instance_valid(value):
			_pending.pop_back()
		else:
			var node: Node = value
			if node.get_child_count(true) > 0:
				_pending.append(node.get_child(node.get_child_count(true) - 1, true))
			else:
				_pending.pop_back()
				node.free()
				_released_nodes += 1
		if Time.get_ticks_usec() - started >= SLICE_USEC: break
	_slice_count += 1
	_maximum_slice_usec = maxi(_maximum_slice_usec, Time.get_ticks_usec() - started)
	if _pending.is_empty():
		if RenderingServer.frame_post_draw.is_connected(_on_presented_frame):
			RenderingServer.frame_post_draw.disconnect(_on_presented_frame)
		queue_free()

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_presented_frame):
		RenderingServer.frame_post_draw.disconnect(_on_presented_frame)
	# App shutdown owns synchronous completion. A detached branch never survives
	# its root-owned drain, even if rendering stops before the next slice.
	while not _pending.is_empty():
		var node: Variant = _pending.pop_back()
		if is_instance_valid(node): node.free()
