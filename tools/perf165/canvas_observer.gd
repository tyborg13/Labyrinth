extends RefCounted

## One record per render boundary. CanvasItem visibility is a candidate list:
## GDScript cannot inspect submitted canvas draw commands or attribute a
## global counter to an individual RID.

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const COUNTERS := {
	"canvas": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
	"mesh": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	"surface": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
	"draw": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	"specialization": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,
}

var root: Window
var scan_items: bool
var stage := "startup"
var frames: Array[Dictionary]
var _previous_usec: int
var _observer_usec: int
var _pre_draw_usec: int
var _counts: Dictionary
var _previous_items: Dictionary
var _seen: Dictionary
var _shader_labels: Dictionary
var _updating_viewports: Dictionary

func start(window: Window, attribution: bool) -> void:
	root = window
	scan_items = attribution
	_previous_usec = Time.get_ticks_usec()
	for name: String in COUNTERS:
		_counts[name] = RenderingServer.get_rendering_info(COUNTERS[name])
	if scan_items: RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(sample)

func stop() -> void:
	if scan_items: RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	RenderingServer.frame_post_draw.disconnect(sample)

func sample() -> void:
	var now := Time.get_ticks_usec()
	var delta: Dictionary = {}
	for name: String in COUNTERS:
		var count := RenderingServer.get_rendering_info(COUNTERS[name])
		delta[name] = count - int(_counts[name])
		_counts[name] = count
	var scene := root.get_tree().current_scene
	var cover := str(scene.get("phase")) if scene != null and scene.name == &"MenuRunTransition" else ""
	var row := {"frame": Engine.get_process_frames(), "stage": stage, "loading_cover": cover,
		"ms": maxf(0.0, (now - _previous_usec - _observer_usec - _pre_draw_usec) / 1000.0),
		"raw_ms": (now - _previous_usec) / 1000.0,
		"focused": DisplayServer.window_is_focused(), "compilations": delta}
	_previous_usec = now
	if scan_items:
		var items: Dictionary = {}
		_scan(root, items)
		var entered := TypedArrays.dictionaries([])
		var first_seen := TypedArrays.dictionaries([])
		for key: String in items:
			if not _previous_items.has(key): entered.append(items[key])
			if not _seen.has(key): first_seen.append(items[key])
		_previous_items = items
		_seen.merge(items)
		row["new_since_previous_draw"] = entered
		row["first_seen"] = first_seen
	frames.append(row)
	_observer_usec = Time.get_ticks_usec() - now

func _pre_draw() -> void:
	var started := Time.get_ticks_usec()
	_updating_viewports.clear()
	_find_updating_viewports(root)
	_pre_draw_usec = Time.get_ticks_usec() - started

func _find_updating_viewports(node: Node) -> void:
	if node is SubViewport:
		if node.render_target_update_mode == SubViewport.UPDATE_DISABLED: return
		_updating_viewports[node.get_instance_id()] = node.render_target_update_mode
	for child: Node in node.get_children(true): _find_updating_viewports(child)

func _scan(node: Node, result: Dictionary, inherited: Material = null) -> void:
	if node is SubViewport and not _updating_viewports.has(node.get_instance_id()): return
	if node is CanvasLayer and not node.visible: return
	var material: Material
	if node is CanvasItem:
		if not node.is_visible_in_tree(): return
		material = inherited if node.use_parent_material else node.material
		var viewport := node.get_viewport()
		var scope := "main" if viewport == root else str(viewport.get_path())
		var script: Script = node.get_script()
		var kind := node.get_class()
		if script != null: kind += " " + script.resource_path
		var context := {"viewport": scope, "node": str(node.get_path()), "canvas_item_type": kind}
		_add(result, scope, "type", kind, context)
		if material != null:
			var rid := str(material.get_rid().get_id())
			var label := material.resource_path
			if label.is_empty(): label = material.resource_name
			if label.is_empty(): label = material.get_class()
			if material is CanvasItemMaterial:
				label += " blend=%d light=%d" % [material.blend_mode, material.light_mode]
			_add(result, scope, "material", rid, context.merged({"name": label, "rid": rid}))
			if material is ShaderMaterial and material.shader != null:
				var shader: Shader = material.shader
				var shader_rid := str(shader.get_rid().get_id())
				if not _shader_labels.has(shader_rid):
					_shader_labels[shader_rid] = shader.resource_path if not shader.resource_path.is_empty() else "inline:" + shader.code.sha256_text()
				_add(result, scope, "shader", shader_rid, context.merged({"name": _shader_labels[shader_rid], "rid": shader_rid}))
	for child: Node in node.get_children(true): _scan(child, result, material)

func _add(result: Dictionary, scope: String, category: String, key: String, context: Dictionary) -> void:
	var id := "%s|%s|%s" % [scope, category, key]
	if result.has(id): return
	context["kind"] = category
	result[id] = context
