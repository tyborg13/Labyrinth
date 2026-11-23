extends RefCounted

const LayoutCheck = preload("res://tools/pol67/layout_check.gd")


static func viewport_geometry(viewport: Viewport) -> Dictionary:
	var scale: Vector2 = viewport.get_stretch_transform().get_scale()
	var logical: Vector2 = viewport.get_visible_rect().size
	return {
		"path": "shipping_window" if viewport is Window else "subviewport",
		"logical_size": [logical.x, logical.y],
		"stretch": [scale.x, scale.y],
	}


static func layout_hits(viewport: Viewport, shot: String, source: Node) -> Array[Dictionary]:
	if viewport is SubViewport:
		return LayoutCheck.scan(viewport, shot, source)
	# The legacy checker consumes logical Control coordinates and gets its
	# bounds from a SubViewport. The detached bounds viewport renders nothing.
	var bounds := SubViewport.new()
	bounds.size = Vector2i(viewport.get_visible_rect().size)
	var hits: Array[Dictionary]
	if source == viewport:
		for child: Node in source.get_children():
			hits.append_array(LayoutCheck.scan(bounds, shot, child))
	else:
		hits = LayoutCheck.scan(bounds, shot, source)
	bounds.free()
	# The scanner's stand-in has integer dimensions. Discard edge hits that
	# came only from rounding the Window's actual logical size down.
	return hits.filter(func(hit: Dictionary) -> bool:
		if hit["kind"] != "outside_viewport": return true
		var values: Array = hit["rect"]
		var rect := Rect2(values[0], values[1], values[2], values[3])
		return not viewport.get_visible_rect().grow(LayoutCheck.EDGE_EPSILON_PX).encloses(rect)
	)


static func control_rects(viewport: Viewport, source: Node) -> Dictionary:
	var result: Dictionary = {}
	var stretch: Transform2D = viewport.get_stretch_transform()
	if source == viewport:
		for child: Node in source.get_children():
			if not child is Window:
				_collect(child, "", stretch, result)
	else:
		_collect(source, "", stretch, result)
	return result


static func dialogue_paint_rects(dialogue: Control, stretch: Transform2D) -> Dictionary:
	var result: Dictionary = {}
	for part: String in ["DialogueInkBand", "DialoguePortrait", "DialoguePortraitShadow", "DialogueHoodHalo"]:
		var control := dialogue.find_child(part, true, false) as TextureRect
		if control == null or not control.is_visible_in_tree() or control.texture == null:
			continue
		var image: Image = control.texture.get_image()
		if image == null or image.is_empty():
			continue
		var rect := Rect2(image.get_used_rect())
		if part == "DialoguePortrait":
			# The shader exposes the head above the rim and masks the bust.
			var window: Vector4 = (control.material as ShaderMaterial).get_shader_parameter("frame_window")
			var bounds := Rect2i(image.get_used_rect())
			var head: Rect2i = bounds.intersection(Rect2i(0, 0, image.get_width(), ceili(window.y)))
			var bust: Rect2i = bounds.intersection(Rect2i(ceili(window.x), ceili(window.y), floori(window.z) - ceili(window.x), floori(window.w) - ceili(window.y)))
			var head_paint: Rect2i = _paint_inside(image, head)
			var bust_paint: Rect2i = _paint_inside(image, bust)
			rect = Rect2(head_paint.merge(bust_paint) if head_paint.has_area() and bust_paint.has_area() else (head_paint if head_paint.has_area() else bust_paint))
		rect = stretch * control.get_global_transform_with_canvas() * rect
		var parent := control.get_parent() as Control
		if parent.clip_contents:
			rect = rect.intersection(stretch * parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, parent.size))
		result[part] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return result


static func _paint_inside(image: Image, region: Rect2i) -> Rect2i:
	if not region.has_area(): return Rect2i()
	var used: Rect2i = image.get_region(region).get_used_rect()
	return Rect2i(used.position + region.position, used.size)


static func _collect(node: Node, path: String, to_pixels: Transform2D, result: Dictionary) -> void:
	if node.is_queued_for_deletion() or node is SubViewport or node.name == &"DialogueContinueDiamond":
		return
	if (node is CanvasItem and not node.is_visible_in_tree()) or (node is CanvasLayer and not node.visible):
		return
	var part := str(node.name)
	if part.begins_with("@"):
		# Godot's anonymous names use a process-global allocation counter.
		part = "@%s[%d]" % [node.get_class(), node.get_index(true)]
	var key: String = path.path_join(part)
	if node is Control:
		var rect: Rect2 = to_pixels * node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
		if rect.has_area():
			result[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	for child: Node in node.get_children(true):
		if not child is Window:
			_collect(child, key, to_pixels, result)
