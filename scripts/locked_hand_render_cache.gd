extends RefCounted

# Only capture a hand whose interaction and every visible animation are static.
# Restore before every real hand refresh; the raster is not a live UI substitute.
const CardWidget = preload("res://scripts/card_widget.gd")
const CACHE_MARGIN: float = 40.0

var active: bool = false
var _hand: Control
var _viewport: SubViewport
var _placeholder: Control
var _texture: Sprite2D
var _original_parent: Node
var _original_index: int = -1
var _layout: Dictionary = {}

func capture(hand_box: Control, host: Control) -> void:
	if (
		DisplayServer.get_name() == "headless"
		or active
		or hand_box == null
		or not hand_box.is_inside_tree()
		or not hand_box.is_visible_in_tree()
		or hand_box.get_child_count() <= 0
		or hand_box.size.x <= 1.0
		or hand_box.size.y <= 1.0
		or _has_live_presentation(hand_box)
	):
		return
	var original_parent: Node = hand_box.get_parent()
	if original_parent == null:
		return
	_hand = hand_box
	_original_parent = original_parent
	_original_index = hand_box.get_index()
	_layout = {
		"anchor_left": hand_box.anchor_left,
		"anchor_top": hand_box.anchor_top,
		"anchor_right": hand_box.anchor_right,
		"anchor_bottom": hand_box.anchor_bottom,
		"offset_left": hand_box.offset_left,
		"offset_top": hand_box.offset_top,
		"offset_right": hand_box.offset_right,
		"offset_bottom": hand_box.offset_bottom,
		"position": hand_box.position,
		"size": hand_box.size,
		"custom_minimum_size": hand_box.custom_minimum_size,
		"size_flags_horizontal": hand_box.size_flags_horizontal,
		"size_flags_vertical": hand_box.size_flags_vertical,
		"size_flags_stretch_ratio": hand_box.size_flags_stretch_ratio,
		"rotation": hand_box.rotation,
		"scale": hand_box.scale,
		"pivot_offset": hand_box.pivot_offset,
		"theme": hand_box.theme,
	}
	_placeholder = Control.new()
	_placeholder.name = "LockedHandRenderCachePlaceholder"
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.focus_mode = Control.FOCUS_NONE
	_placeholder.clip_contents = false
	original_parent.add_child(_placeholder)
	original_parent.move_child(_placeholder, _original_index)
	# HandFanContainer derives its minimum size from its card children. The raster
	# placeholder has no equivalent children, so preserve the resolved hand extent
	# explicitly or its parent MarginContainer will collapse it to zero.
	_placeholder.custom_minimum_size = hand_box.size
	_placeholder.size_flags_horizontal = hand_box.size_flags_horizontal
	_placeholder.size_flags_vertical = hand_box.size_flags_vertical
	_placeholder.size_flags_stretch_ratio = hand_box.size_flags_stretch_ratio
	_placeholder.anchor_left = hand_box.anchor_left
	_placeholder.anchor_top = hand_box.anchor_top
	_placeholder.anchor_right = hand_box.anchor_right
	_placeholder.anchor_bottom = hand_box.anchor_bottom
	_placeholder.offset_left = hand_box.offset_left
	_placeholder.offset_top = hand_box.offset_top
	_placeholder.offset_right = hand_box.offset_right
	_placeholder.offset_bottom = hand_box.offset_bottom
	_placeholder.position = hand_box.position
	_placeholder.size = hand_box.size
	_placeholder.rotation = hand_box.rotation
	_placeholder.scale = hand_box.scale
	_placeholder.pivot_offset = hand_box.pivot_offset
	_placeholder.visible = true
	if original_parent is Container:
		(original_parent as Container).queue_sort()

	var cached_hand_size: Vector2 = hand_box.size
	var hand_bounds := Rect2(Vector2.ZERO, cached_hand_size)
	for child: Node in hand_box.get_children():
		if child is Control and child.visible:
			hand_bounds = hand_bounds.merge(child.get_transform() * Rect2(Vector2.ZERO, child.size))
	hand_bounds = hand_bounds.grow(CACHE_MARGIN)
	var pixel_transform: Transform2D = host.get_viewport().get_stretch_transform() * hand_box.get_global_transform_with_canvas()
	var pixel_bounds: Rect2 = pixel_transform * hand_bounds
	var pixel_origin: Vector2 = pixel_bounds.position.floor()
	var required_cache_size := Vector2i(pixel_bounds.end.ceil() - pixel_origin)
	var cache_transform: Transform2D = Transform2D(0.0, -pixel_origin) * pixel_transform
	_viewport = SubViewport.new()
	_viewport.name = "LockedHandRenderCacheViewport"
	_viewport.transparent_bg = true
	_viewport.msaa_2d = host.get_viewport().msaa_2d
	_viewport.canvas_item_default_texture_filter = host.get_viewport().canvas_item_default_texture_filter
	_viewport.oversampling_override = host.get_viewport().get_oversampling()
	_viewport.handle_input_locally = false
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.size = required_cache_size
	# Custom card text uses the logical viewport height to choose typography.
	# Preserve that context even though the raster target only covers the fan.
	_viewport.size_2d_override = Vector2i(host.get_viewport().get_visible_rect().size)
	_viewport.global_canvas_transform = cache_transform
	host.add_child(_viewport)

	_texture = Sprite2D.new()
	_texture.name = "LockedHandRenderCacheTexture"
	_texture.centered = false
	_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Transparent viewport output is already premultiplied. Ordinary alpha
	# blending would darken every disabled card a second time.
	var cache_material := CanvasItemMaterial.new()
	cache_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_texture.material = cache_material
	_texture.texture = _viewport.get_texture()
	_placeholder.add_child(_texture)
	_texture.transform = cache_transform.affine_inverse()

	hand_box.reparent(_viewport, false)
	hand_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hand_box.position = Vector2.ZERO
	hand_box.size = cached_hand_size
	hand_box.rotation = 0.0
	hand_box.scale = Vector2.ONE
	hand_box.pivot_offset = Vector2.ZERO
	# The normal hand inherits the scene theme through its UI ancestors. Preserve
	# that effective theme while the live controls spend the action in a viewport.
	hand_box.theme = host.theme

	active = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if active and is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _has_live_presentation(node: Node) -> bool:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	if node is CardWidget and not (node as CardWidget).can_cache_locked_appearance():
		return true
	# Also fail open for future processing-driven card details, not just today's
	# known pulse and clock. An optimization must not turn off their presentation.
	if node.is_processing() or node.is_physics_processing():
		return true
	for child: Node in node.get_children():
		if _has_live_presentation(child):
			return true
	return false

func restore() -> void:
	var hand_box: Control = _hand
	if not active:
		return
	active = false
	if _texture != null and is_instance_valid(_texture):
		_texture.visible = false
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if (
		hand_box != null
		and is_instance_valid(hand_box)
		and _original_parent != null
		and is_instance_valid(_original_parent)
	):
		hand_box.reparent(_original_parent, false)
		var restored_index: int = mini(
			maxi(0, _original_index),
			_original_parent.get_child_count() - 1
		)
		_original_parent.move_child(hand_box, restored_index)
		hand_box.anchor_left = float(_layout.get("anchor_left", 0.0))
		hand_box.anchor_top = float(_layout.get("anchor_top", 0.0))
		hand_box.anchor_right = float(_layout.get("anchor_right", 0.0))
		hand_box.anchor_bottom = float(_layout.get("anchor_bottom", 0.0))
		hand_box.offset_left = float(_layout.get("offset_left", 0.0))
		hand_box.offset_top = float(_layout.get("offset_top", 0.0))
		hand_box.offset_right = float(_layout.get("offset_right", 0.0))
		hand_box.offset_bottom = float(_layout.get("offset_bottom", 0.0))
		hand_box.position = _layout.get("position", Vector2.ZERO)
		hand_box.size = _layout.get("size", Vector2.ZERO)
		hand_box.custom_minimum_size = _layout.get("custom_minimum_size", Vector2.ZERO)
		hand_box.size_flags_horizontal = int(_layout.get("size_flags_horizontal", Control.SIZE_FILL))
		hand_box.size_flags_vertical = int(_layout.get("size_flags_vertical", Control.SIZE_FILL))
		hand_box.size_flags_stretch_ratio = float(_layout.get("size_flags_stretch_ratio", 1.0))
		hand_box.rotation = float(_layout.get("rotation", 0.0))
		hand_box.scale = _layout.get("scale", Vector2.ONE)
		hand_box.pivot_offset = _layout.get("pivot_offset", Vector2.ZERO)
		hand_box.theme = _layout.get("theme") as Theme
		hand_box.set_emphasized_index(-1, false)
		if _original_parent is Container:
			(_original_parent as Container).queue_sort()
	if _placeholder != null and is_instance_valid(_placeholder):
		_placeholder.queue_free()
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_placeholder = null
	_texture = null
	_original_parent = null
	_original_index = -1
	_layout.clear()
	_hand = null
