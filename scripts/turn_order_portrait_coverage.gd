extends RefCounted
## One retained, render-target-sized coverage texture per source viewport.
## Native polygon rasterization must see the SAME projection and transform
## multiplication order, including the ancestors. Cropping/reprojecting a small
## mask can move vertices across the GPU's subpixel raster grid. Only occupied
## portrait pixels are drawn; the target updates once when geometry changes.
## Each portrait owns one RGB bit, so overlapping portraits remain independent.
## MSAA/HDR/fades retain clip_children (see turn_order_portrait_clip.gd).
## Godot 4.6.1: renderer_canvas_cull.cpp and renderer_canvas_render_rd.cpp.
const BITS_PER_CHANNEL: int = 8
const CAPACITY: int = BITS_PER_CHANNEL * 3
const COVERAGE_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec3 coverage_flag;
void fragment() { COLOR = vec4(coverage_flag, 1.0); }
"""
static var _instances: Dictionary = {}
static var _shader: Shader
var _source_id: int
var _viewport: SubViewport
var _entries: Dictionary = {}
var _viewport_signature: Array = []
var _revision: int = 0
var _completed_revision: int = 0
var _pending: bool = false
var requested_updates: int = 0
var completed_updates: int = 0

static func acquire(source: Viewport) -> RefCounted:
	var key: int = source.get_instance_id()
	if not _instances.has(key):
		var next := new()
		next._source_id = key
		next._viewport = SubViewport.new()
		next._viewport.name = "TurnOrderPortraitCoverageViewport"
		next._viewport.disable_3d = true
		next._viewport.world_2d = World2D.new()
		next._viewport.msaa_2d = source.msaa_2d
		next._viewport.use_hdr_2d = source.use_hdr_2d
		next._viewport.transparent_bg = true
		next._viewport.handle_input_locally = false
		next._viewport.gui_disable_input = true
		next._viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		next._viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		source.add_child(next._viewport, false, Node.INTERNAL_MODE_BACK)
		RenderingServer.frame_post_draw.connect(next._after_draw)
		_instances[key] = next
	return _instances[key]

func texture() -> ViewportTexture:
	return _viewport.get_texture()

func reserve() -> int:
	for slot: int in range(CAPACITY):
		if not _entries.has(slot):
			_entries[slot] = {"signature": [], "canvas": RID(), "items": [], "material": null, "revision": 0}
			return slot
	return -1

func update(slot: int, mask: Control) -> void:
	var source: Viewport = mask.get_viewport()
	var viewport_signature: Array = [source.size, source.get_final_transform(), source.snap_2d_transforms_to_pixel, source.snap_2d_vertices_to_pixel]
	if viewport_signature != _viewport_signature:
		_viewport.size = source.size
		_viewport.global_canvas_transform = source.get_final_transform()
		_viewport.snap_2d_transforms_to_pixel = source.snap_2d_transforms_to_pixel
		_viewport.snap_2d_vertices_to_pixel = source.snap_2d_vertices_to_pixel
		_viewport_signature = viewport_signature
		_invalidate()
		for entry: Dictionary in _entries.values(): entry["revision"] = _revision
	var chain: Array[CanvasItem]
	var ancestor: CanvasItem = mask
	while ancestor != null:
		chain.push_front(ancestor)
		ancestor = null if ancestor.is_set_as_top_level() else ancestor.get_parent() as CanvasItem
	var signature: Array = [mask.get_canvas_transform(), mask.size, mask.get("skew")]
	for item: CanvasItem in chain: signature.append(item.get_transform())
	var entry: Dictionary = _entries[slot]
	if signature == entry["signature"]: return
	var points: PackedVector2Array = mask.call("window_points", mask.size, mask.get("skew"))
	_free_commands(entry)
	var canvas: RID = RenderingServer.canvas_create()
	entry["canvas"] = canvas
	RenderingServer.viewport_attach_canvas(_viewport.get_viewport_rid(), canvas)
	RenderingServer.viewport_set_canvas_transform(_viewport.get_viewport_rid(), canvas, mask.get_canvas_transform())
	var parent: RID = canvas
	for item: CanvasItem in chain:
		var copy: RID = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(copy, parent)
		RenderingServer.canvas_item_set_transform(copy, item.get_transform())
		entry["items"].append(copy)
		parent = copy
	if _shader == null:
		_shader = Shader.new()
		_shader.code = COVERAGE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _shader
	var flag := Vector3.ZERO
	flag[slot / BITS_PER_CHANNEL] = float(1 << (slot % BITS_PER_CHANNEL)) / 255.0
	material.set_shader_parameter("coverage_flag", flag)
	entry["material"] = material
	RenderingServer.canvas_item_set_material(parent, material.get_rid())
	# Same command, vertices, triangulation and AA path as PortraitMask._draw.
	# The fragment writes an exact UNORM8 bit rather than visible colour.
	RenderingServer.canvas_item_add_polygon(parent, points, PackedColorArray([Color.WHITE]))
	entry["signature"] = signature
	_invalidate()
	entry["revision"] = _revision

func is_ready(slot: int) -> bool:
	return _entries.has(slot) and int(_entries[slot]["revision"]) > 0 and int(_entries[slot]["revision"]) <= _completed_revision

func _invalidate() -> void:
	_revision += 1
	if not _pending: requested_updates += 1
	_pending = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _after_draw() -> void:
	if not _pending: return
	_completed_revision = _revision
	completed_updates += 1
	_pending = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _free_commands(entry: Dictionary) -> void:
	for item: RID in entry["items"]: RenderingServer.free_rid(item)
	entry["items"].clear()
	var canvas: RID = entry["canvas"]
	if canvas.is_valid(): RenderingServer.free_rid(canvas)
	entry["canvas"] = RID()
	entry["material"] = null

func release(slot: int) -> void:
	if not _entries.has(slot): return
	_free_commands(_entries[slot])
	_entries.erase(slot)
	if not _entries.is_empty():
		# Other portraits can still use their independent bits in the old
		# raster; erase this slot before it is reused by the next capture.
		_invalidate()
		return
	if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.queue_free()
	_instances.erase(_source_id)
