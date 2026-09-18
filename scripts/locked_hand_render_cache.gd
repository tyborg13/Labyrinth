extends RefCounted

# A static locked hand is rendered once, but its controls keep their tree,
# theme and layout. Only the renderer attachment moves to the capture parent.
const CardWidget = preload("res://scripts/card_widget.gd")
const CACHE_MARGIN: float = 40.0
var active: bool = false
var _hand: Control
var _viewport: SubViewport
var _capture_parent: Node2D
var _texture: Sprite2D
var _cache_material: CanvasItemMaterial
var _capture_generation: int = 0
var _watched: Array[Signal]
var _geometry_watched: Array[CanvasItem]
var _geometry_snapshots: Array
var _geometry_check_pending: bool = false
var _first_capture_draw: bool = false
var _draw_watched: Array[CanvasItem]
var _appearance_watched: Array[CanvasItem]
var _appearance_snapshots: Array
var _opaque_ancestors: Array[CanvasItem]
var _mouse_behavior: int = 0
var _focus_behavior: int = 0

func capture(hand_box: Control, host: Control) -> void:
	var started: int = Time.get_ticks_usec() if host != null and host.has_method("_record_runtime_performance_phase") and bool(host.get("_runtime_performance_instrumentation_enabled")) else 0
	if DisplayServer.get_name() == "headless" or active or not is_instance_valid(hand_box) or not is_instance_valid(host):
		return
	if not hand_box.is_inside_tree() or not hand_box.is_visible_in_tree() or hand_box.get_child_count() <= 0 or hand_box.size.x <= 1.0 or hand_box.size.y <= 1.0:
		return
	if _has_live_presentation(hand_box) or not _supported_ancestors(hand_box):
		return
	var original_parent: Node = hand_box.get_parent()
	if original_parent == null or _parent_item(hand_box) == null:
		return
	# Locking clears the targeting emphasis through a queued fan sort. Apply that
	# already-requested pose before measuring/capturing its final geometry.
	if hand_box.has_method("apply_layout_immediately"):
		hand_box.apply_layout_immediately()
	var hand_bounds := Rect2(Vector2.ZERO, hand_box.size)
	for child: Node in hand_box.get_children():
		if child is Control and child.visible:
			hand_bounds = hand_bounds.merge(child.get_transform() * Rect2(Vector2.ZERO, child.size))
	hand_bounds = hand_bounds.grow(CACHE_MARGIN)
	var pixel_transform: Transform2D = host.get_viewport().get_stretch_transform() * hand_box.get_global_transform_with_canvas()
	var pixel_bounds: Rect2 = pixel_transform * hand_bounds
	var pixel_origin: Vector2 = pixel_bounds.position.floor()
	var required_cache_size := Vector2i(pixel_bounds.end.ceil() - pixel_origin)
	var cache_transform: Transform2D = Transform2D(0.0, -pixel_origin) * pixel_transform
	if is_zero_approx(hand_box.get_transform().determinant()):
		return
	if not is_instance_valid(_viewport) or _viewport.get_parent() != host:
		if is_instance_valid(_viewport):
			_viewport.queue_free()
		_viewport = SubViewport.new()
		_viewport.name = "LockedHandRenderCacheViewport"
		host.add_child(_viewport)
		_capture_parent = Node2D.new()
		_capture_parent.name = "LockedHandCaptureParent"
		_viewport.add_child(_capture_parent)
	_viewport.transparent_bg = true
	_viewport.msaa_2d = host.get_viewport().msaa_2d
	_viewport.canvas_item_default_texture_filter = host.get_viewport().canvas_item_default_texture_filter
	_viewport.canvas_item_default_texture_repeat = host.get_viewport().canvas_item_default_texture_repeat
	_viewport.oversampling_override = host.get_viewport().get_oversampling()
	_viewport.handle_input_locally = false
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.size = required_cache_size
	_viewport.size_2d_override = Vector2i(host.get_viewport().get_visible_rect().size)
	_viewport.global_canvas_transform = cache_transform
	# The Control still owns its local transform. Compensate above it instead of
	# overriding its RID transform, which a pending Container sort can rewrite.
	_capture_parent.transform = hand_box.get_transform().affine_inverse()
	_texture = Sprite2D.new()
	_texture.name = "LockedHandRenderCacheTexture"
	_texture.centered = false
	_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _cache_material == null:
		_cache_material = CanvasItemMaterial.new()
		_cache_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_texture.material = _cache_material
	_texture.texture = _viewport.get_texture()
	_texture.z_index = hand_box.z_index
	_texture.z_as_relative = hand_box.z_as_relative
	_texture.show_behind_parent = hand_box.show_behind_parent
	original_parent.add_child(_texture)
	original_parent.move_child(_texture, hand_box.get_index() + 1)
	_texture.transform = hand_box.get_transform() * cache_transform.affine_inverse()
	_hand = hand_box
	_mouse_behavior = hand_box.mouse_behavior_recursive
	_focus_behavior = hand_box.focus_behavior_recursive
	hand_box.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	hand_box.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	RenderingServer.canvas_item_set_parent(hand_box.get_canvas_item(), _capture_parent.get_canvas_item())
	active = true
	_first_capture_draw = true
	_capture_generation += 1
	var generation: int = _capture_generation
	_watch(host.tree_exiting)
	_watch(_viewport.tree_exiting)
	_watch(hand_box.tree_exiting)
	_watch(hand_box.visibility_changed)
	_watch(hand_box.child_order_changed)
	_watch(hand_box.theme_changed)
	_watch(host.get_viewport().size_changed)
	# Layout invalidation restores live drawing synchronously, before the next
	# render. No screenshot may outlive the geometry it represents.
	var ancestor: CanvasItem = hand_box
	while ancestor != null:
		_watch_geometry(ancestor)
		ancestor = _parent_item(ancestor)
	_watch_appearance(hand_box)
	ancestor = _parent_item(hand_box)
	while ancestor != null:
		_opaque_ancestors.append(ancestor)
		ancestor = _parent_item(ancestor)
	_watch_visual_descendants(hand_box)
	RenderingServer.frame_pre_draw.connect(_validate_appearance)
	if started > 0:
		host.call("_record_runtime_performance_phase", "locked_hand_capture", started)
	await RenderingServer.frame_post_draw
	if active and generation == _capture_generation and is_instance_valid(_viewport):
		_first_capture_draw = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _watch(event: Signal) -> void:
	if not event.is_connected(restore):
		event.connect(restore)
		_watched.append(event)

func _watch_visual_descendants(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is CanvasItem:
			_watch_geometry(child)
			_watch(child.visibility_changed)
			_watch(child.tree_exiting)
			_watch(child.child_order_changed)
			child.draw.connect(_on_cached_redraw)
			_draw_watched.append(child)
			if child is CardWidget:
				_watch_appearance(child)
		_watch_visual_descendants(child)

func _on_cached_redraw() -> void:
	# Initial queued draw commands belong to the captured frame. A later redraw
	# means the retained content changed; restore before that frame is rendered.
	if active and not _first_capture_draw:
		restore()

func _appearance_signature(item: CanvasItem) -> Array:
	return [item.modulate, item.self_modulate, item.z_index, item.z_as_relative, item.show_behind_parent]

func _watch_appearance(item: CanvasItem) -> void:
	_appearance_watched.append(item)
	_appearance_snapshots.append(_appearance_signature(item))

func _validate_appearance() -> void:
	# Ancestor opacity affects each overlapping primitive separately; applying
	# it to a flattened raster cannot reproduce that composition. Keep that case
	# live. Watch only the hand and card roots for server-only tint/depth writes;
	# the current CardWidget refresh paths redraw nested content or restore the
	# cache before replacing it. Arbitrary renderer-only nested writes are not
	# part of that locked-card contract.
	for ancestor: CanvasItem in _opaque_ancestors:
		if not is_instance_valid(ancestor) or ancestor.modulate.a != 1.0:
			restore()
			return
	for index: int in range(_appearance_watched.size()):
		var item: CanvasItem = _appearance_watched[index]
		if not is_instance_valid(item) or _appearance_signature(item) != _appearance_snapshots[index]:
			restore()
			return

func _watch_geometry(item: CanvasItem) -> void:
	_geometry_watched.append(item)
	_geometry_snapshots.append(_geometry_signature(item))
	item.item_rect_changed.connect(_queue_geometry_check)

func _geometry_signature(item: CanvasItem) -> Array:
	return [item.get_transform(), item.size if item is Control else Vector2.ZERO]

func _queue_geometry_check() -> void:
	if not active or _geometry_check_pending:
		return
	_geometry_check_pending = true
	# Container sorting temporarily resets rotation/scale before restoring the
	# same fan pose. Validate its completed layout before the render, rather than
	# invalidating the raster on those unchanged intermediate assignments.
	call_deferred("_validate_geometry", _capture_generation)

func _validate_geometry(generation: int) -> void:
	if not active or generation != _capture_generation:
		return
	_geometry_check_pending = false
	for index: int in range(_geometry_watched.size()):
		var item: CanvasItem = _geometry_watched[index]
		if not is_instance_valid(item) or _geometry_signature(item) != _geometry_snapshots[index]:
			restore()
			return

func _parent_item(item: CanvasItem) -> CanvasItem:
	return null if item.is_set_as_top_level() else item.get_parent() as CanvasItem

func _supported_ancestors(hand: Control) -> bool:
	var ancestor: CanvasItem = hand
	while ancestor != null:
		if ancestor.modulate.a != 1.0 or ancestor is CanvasGroup or ancestor.material != null or ancestor.use_parent_material or ancestor.is_set_as_top_level():
			return false
		ancestor = _parent_item(ancestor)
	return true

func _has_live_presentation(node: Node) -> bool:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	if node is CanvasLayer or (node is CanvasItem and (node as CanvasItem).is_set_as_top_level()):
		return true
	if node is Control and (node.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_ENABLED or node.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_ENABLED):
		return true
	if node is CardWidget and not (node as CardWidget).can_cache_locked_appearance():
		return true
	if node.is_processing() or node.is_physics_processing():
		return true
	for child: Node in node.get_children():
		if _has_live_presentation(child):
			return true
	return false

func restore() -> void:
	if not active:
		return
	active = false
	_capture_generation += 1
	for event: Signal in _watched:
		if is_instance_valid(event.get_object()) and event.is_connected(restore):
			event.disconnect(restore)
	_watched.clear()
	for item: CanvasItem in _geometry_watched:
		if is_instance_valid(item) and item.item_rect_changed.is_connected(_queue_geometry_check):
			item.item_rect_changed.disconnect(_queue_geometry_check)
	_geometry_watched.clear()
	for item: CanvasItem in _draw_watched:
		if is_instance_valid(item) and item.draw.is_connected(_on_cached_redraw):
			item.draw.disconnect(_on_cached_redraw)
	_draw_watched.clear()
	_appearance_watched.clear()
	_appearance_snapshots.clear()
	_opaque_ancestors.clear()
	if RenderingServer.frame_pre_draw.is_connected(_validate_appearance):
		RenderingServer.frame_pre_draw.disconnect(_validate_appearance)
	_first_capture_draw = false
	_geometry_snapshots.clear()
	_geometry_check_pending = false
	if is_instance_valid(_texture):
		_texture.visible = false
		_texture.queue_free()
	_texture = null
	if is_instance_valid(_hand):
		if _hand.is_inside_tree():
			var parent: CanvasItem = _parent_item(_hand)
			RenderingServer.canvas_item_set_parent(_hand.get_canvas_item(), parent.get_canvas_item() if parent != null else _hand.get_canvas())
		_hand.mouse_behavior_recursive = _mouse_behavior
		_hand.focus_behavior_recursive = _focus_behavior
		if _hand.has_method("emphasized_index") and _hand.emphasized_index() >= 0:
			_hand.set_emphasized_index(-1, false)
	_hand = null
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
