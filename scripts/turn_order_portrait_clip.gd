extends RefCounted
## Keep the native TextureRect quad/UV/filter and use retained native polygon
## coverage instead of clip_children's per-portrait screen read/copy pass.
## Unsupported composition and a changed mask's first frame use the original.
const Coverage = preload("res://scripts/turn_order_portrait_coverage.gd")
static var force_original_for_tests: bool = false
static var _shader: Shader
const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D coverage : repeat_disable, filter_nearest;
uniform int coverage_channel;
uniform uint coverage_bit;
void fragment() {
	// One texel is one render-target pixel: no resampling or edge threshold.
	uint flags = uint(round(texelFetch(coverage, ivec2(FRAGCOORD.xy), 0)[coverage_channel] * 255.0));
	if ((flags & coverage_bit) == 0u) { discard; }
}
"""
var active: bool = false
var _mask: Control
var _portrait: TextureRect
var _material: ShaderMaterial
var _coverage: RefCounted
var _slot: int = -1

func install(mask: Control) -> void:
	_mask = mask
	RenderingServer.frame_pre_draw.connect(refresh)
	mask.tree_exiting.connect(_detach, CONNECT_ONE_SHOT)
	refresh()

func _supported(child: TextureRect) -> bool:
	if force_original_for_tests or not _mask.is_visible_in_tree() or _mask.size.x < 4.0 or _mask.size.y < 4.0 or child == null or child.get_child_count(true) != 0 or child.use_parent_material:
		return false
	if child.material != null and child.material != _material:
		return false
	if child.get_transform().x != Vector2.RIGHT or child.get_transform().y != Vector2.DOWN or child.is_set_as_top_level():
		return false
	var viewport: Viewport = _mask.get_viewport()
	# The authored draw_colored_polygon has binary coverage with MSAA Off.
	# Other coverage/composition modes keep their original renderer unchanged.
	if viewport.msaa_2d != Viewport.MSAA_DISABLED or viewport.transparent_bg or viewport.use_hdr_2d or _mask.material != null:
		return false
	var ancestor: CanvasItem = _mask
	while ancestor != null:
		# Clip-only blends children into a backbuffer, then applies mask opacity
		# again. Preserve that composition during every fade.
		if ancestor.modulate.a != 1.0 or ancestor is CanvasGroup or ancestor.material != null:
			return false
		if ancestor != _mask and ancestor.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
			return false
		ancestor = null if ancestor.is_set_as_top_level() else ancestor.get_parent() as CanvasItem
	return _mask.self_modulate.a == 1.0

func refresh() -> void:
	if not is_instance_valid(_mask): return
	var child: TextureRect = _mask.get_child(0) as TextureRect if _mask.get_child_count() == 1 else null
	if not _supported(child):
		_restore()
		_release_coverage()
		return
	if _portrait != child:
		_restore()
		_portrait = child
	if _coverage == null:
		_coverage = Coverage.acquire(_mask.get_viewport())
		_slot = _coverage.reserve()
		if _slot < 0:
			_coverage = null
			return
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER_CODE
		_material = ShaderMaterial.new()
		_material.shader = _shader
		_material.set_shader_parameter("coverage", _coverage.texture())
		_material.set_shader_parameter("coverage_channel", _slot / Coverage.BITS_PER_CHANNEL)
		_material.set_shader_parameter("coverage_bit", 1 << (_slot % Coverage.BITS_PER_CHANNEL))
	_coverage.update(_slot, _mask)
	if not _coverage.is_ready(_slot):
		# Never display a stale mask while resize, scale, shape, or any ancestor
		# transform changes. Keep native clipping until this raster completes.
		_restore()
		return
	if child.material != _material: child.material = _material
	if not active:
		active = true
		_mask.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		RenderingServer.canvas_item_clear(_mask.get_canvas_item())
		_mask.queue_redraw()

func _restore() -> void:
	if not active: return
	active = false
	if is_instance_valid(_portrait) and _portrait.material == _material:
		_portrait.material = null
	if is_instance_valid(_mask):
		_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		RenderingServer.canvas_item_clear(_mask.get_canvas_item())
		if _mask.size.x >= 4.0 and _mask.size.y >= 4.0:
			RenderingServer.canvas_item_add_polygon(_mask.get_canvas_item(), _mask.call("window_points", _mask.size, _mask.get("skew")), PackedColorArray([Color.WHITE]))
		_mask.queue_redraw()

func _release_coverage() -> void:
	if _coverage != null: _coverage.release(_slot)
	_coverage = null
	_slot = -1
	_material = null

func _detach() -> void:
	_restore()
	_release_coverage()
	if RenderingServer.frame_pre_draw.is_connected(refresh): RenderingServer.frame_pre_draw.disconnect(refresh)
	_mask = null
	_portrait = null
