extends "res://tools/hitch_census/headless_whole.gd"
## Diagnose native invalidations of the empty tooltip host without changing it.
const TARGET: String = "res://scripts/ui_tooltip_control.gd"
const NATIVE_FIELDS := ["scale", "rotation", "pivot_offset", "position", "size", "clip_contents"]
var _log: FileAccess
var _pending: Dictionary = {}
var _drawn: Dictionary = {}
var _previous: Dictionary = {}

func _initialize() -> void:
	super._initialize()
	DirAccess.make_dir_recursive_absolute(output)
	_log = FileAccess.open(output.path_join("tooltip-triggers.jsonl"), FileAccess.WRITE)
	node_added.connect(_observe)
	census_finished.connect(func() -> void: _log.flush())

func _observe(node: Node) -> void:
	if not node is Control or node.get_script() == null or node.get_script().resource_path != TARGET: return
	for event: String in ["resized", "visibility_changed", "theme_changed", "item_rect_changed", "child_order_changed"]:
		var callback: Callable = _event.bind(node.get_instance_id(), event)
		if not node.is_connected(event, callback): node.connect(event, callback)
	var draw_callback: Callable = _drawn_host.bind(node)
	if not node.draw.is_connected(draw_callback): node.draw.connect(draw_callback)

func _event(id: int, event: String) -> void:
	var events: Array = _pending.get(id, [])
	events.append({"event": event, "frame": Engine.get_process_frames(), "stack": get_stack()})
	_pending[id] = events

func _drawn_host(node: Control) -> void:
	var id: int = node.get_instance_id()
	var inputs: Array = []
	var changed: Array = []
	for field: String in NATIVE_FIELDS: inputs.append(node.get(field))
	if _previous.has(id):
		for index: int in range(NATIVE_FIELDS.size()):
			if inputs[index] != _previous[id][index]: changed.append(NATIVE_FIELDS[index])
	_previous[id] = inputs
	_log.store_line(JSON.stringify({"frame": Engine.get_process_frames(), "path": str(node.get_path()),
		"repeat": _drawn.has(id), "native_fields_changed": changed, "events": _pending.get(id, [])}))
	_drawn[id] = true
	_pending.erase(id)
