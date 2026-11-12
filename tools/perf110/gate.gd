extends "res://tools/hitch_census/headless_whole.gd"
## Diagnostic-only companion to the unchanged census driver. The census owns
## executed counts/timings; this file records exact consecutive draw inputs per
## instance, without writing production properties or requesting extra draws.
const POLYGON_FIELDS := ["polygon", "uv", "polygons", "color", "vertex_colors",
	"texture", "offset", "skeleton", "internal_vertex_count", "invert_enabled",
	"invert_border", "antialiased", "bones"]
const HEALTH_FIELDS := ["size", "value", "max_value", "segment_count",
	"background_color", "fill_color", "fill_highlight_color", "border_color",
	"separator_color", "separator_width", "border_width", "ghost_color"]
const SCRIPTS := ["res://scripts/segmented_health_bar.gd",
	"res://scripts/ui_tooltip_control.gd", "res://scripts/board_surface_ice_layer.gd",
	"res://scripts/enemy_shadow_dissolve_effect.gd"]
var _input_log: FileAccess
var _previous_inputs: Dictionary = {}
var _events: Dictionary = {}
var _watched: Dictionary = {}

func _initialize() -> void:
	super._initialize()
	DirAccess.make_dir_recursive_absolute(output)
	_input_log = FileAccess.open(output.path_join("draw-inputs.jsonl"), FileAccess.WRITE)
	node_added.connect(_observe)
	node_removed.connect(_forget)
	census_finished.connect(func() -> void: _input_log.flush())

func _observe(node: Node) -> void:
	if not node is CanvasItem: return
	var callback: Callable = _record.bind(node)
	if not node.draw.is_connected(callback): node.draw.connect(callback)

func _forget(node: Node) -> void:
	_previous_inputs.erase(node.get_instance_id())
	_events.erase(node.get_instance_id())
	_watched.erase(node.get_instance_id())

func _event(id: int, source: String) -> void:
	var events: Dictionary = _events.get(id, {})
	events[source] = int(events.get(source, 0)) + 1
	_events[id] = events

func _key(node: Node) -> String:
	var script: Script = node.get_script()
	return script.resource_path if script != null and not script.resource_path.is_empty() else "builtin:" + node.get_class()

func _inputs(node: CanvasItem, key: String) -> Array:
	var values: Array = []
	if node is Polygon2D:
		for field: String in POLYGON_FIELDS: values.append(node.get(field))
	elif key == SCRIPTS[0]:
		for field: String in HEALTH_FIELDS: values.append(node.get(field))
		values.append(node.call("ghost_sample"))
	elif key == SCRIPTS[1]:
		# Control's native draw applies its transform, clip flag and custom rect,
		# even when the script itself has no draw commands.
		values = [node.get_transform(), node.get("size"), node.get("clip_contents")]
	elif key == SCRIPTS[2]:
		values = [node.get("_width"), node.get("_seed"), node.get("_phase")]
	elif key == SCRIPTS[3]:
		# Shader uniforms change pixels directly, not the retained draw command.
		values = [node.get("_draw_texture"), node.get("size")]
	elif key == "builtin:Node2D" and node.has_method("_draw"):
		# Inner script classes have no resource path. Unknown custom drawing is
		# conservatively changed; it must never authorize a redraw suppression.
		values = [Engine.get_process_frames()]
	# Bare Node2D has no draw commands. Its draw signal
	# can be invalidated by engine layout/visibility/property writes nonetheless.
	return values

func _record(node: CanvasItem) -> void:
	var key: String = _key(node)
	if key not in SCRIPTS and key not in ["builtin:Polygon2D", "builtin:Node2D"]: return
	var inputs: Array = _inputs(node, key)
	var id: int = node.get_instance_id()
	if node is Polygon2D and not _watched.has(id):
		_watched[id] = true
		var signals: Array = [[node, "visibility_changed"], [node.get_viewport(), "size_changed"]]
		var skeleton: Node = node.get_node_or_null(node.skeleton)
		if skeleton is Skeleton2D: signals.append([skeleton, "bone_setup_changed"])
		if node.texture != null: signals.append([node.texture, "changed"])
		for pair: Array in signals:
			var callback: Callable = _event.bind(id, str(pair[1]))
			if not pair[0].is_connected(pair[1], callback): pair[0].connect(pair[1], callback)
	var known: bool = _previous_inputs.has(id)
	var unchanged: bool = known and inputs == _previous_inputs[id]
	_previous_inputs[id] = inputs.duplicate(true)
	var invisible: bool = not node.is_visible_in_tree() or node.self_modulate.a == 0.0
	var ancestor: CanvasItem = node
	while ancestor != null:
		invisible = invisible or ancestor.modulate.a == 0.0
		if ancestor.top_level: break
		ancestor = ancestor.get_parent() as CanvasItem
	_input_log.store_line(JSON.stringify({"frame": Engine.get_process_frames(),
		"inputs_version": 2,
		"key": key, "instance": id, "path": str(node.get_path()),
		"previous_draw_known": known, "unchanged": unchanged, "invisible": invisible,
		"events_since_draw": _events.get(id, {})}))
	_events.erase(id)
