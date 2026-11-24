extends RefCounted
## Hover the real control through Godot GUI input and capture its embedded popup.
const POPUP_TIMEOUT_MSEC: int = 2000

static func prepare(viewport: SubViewport) -> void:
	viewport.gui_embed_subwindows = true
	# These probes feed a standalone SubViewport. There is no container to
	# relay the window's pointer entry before the synthetic motion arrives.
	viewport.notify_mouse_entered()

static func move_pointer(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - viewport.get_mouse_position()
	viewport.push_input(motion, true)

static func has_visible_tooltip(viewport: Viewport) -> bool:
	for popup: Window in viewport.get_embedded_subwindows():
		if popup is PopupPanel and popup.visible and popup.theme_type_variation == &"TooltipPanel": return true
	return false

static func popup_for(owner: Control, expected: String) -> Window:
	var viewport: Viewport = owner.get_viewport()
	if viewport.gui_get_hovered_control() != owner: return null
	for popup: Window in viewport.get_embedded_subwindows():
		if not popup is PopupPanel or not popup.visible or not popup.is_embedded(): continue
		if popup.theme_type_variation != &"TooltipPanel" or popup.get_parent() != owner: continue
		var bounds := Rect2(Vector2(popup.position), Vector2(popup.size))
		if not bounds.has_area() or not viewport.get_visible_rect().encloses(bounds): continue
		if visible_text(popup).to_lower().split("\n").has(expected.to_lower()): return popup
	return null

static func visible_text(node: Node) -> String:
	var lines := PackedStringArray()
	for child: Node in node.get_children(true):
		if child is CanvasItem and (not child.is_visible_in_tree() or child.modulate.a <= 0.0): continue
		if child is Label and child.self_modulate.a > 0.0 and child.get_global_rect().has_area():
			lines.append(child.text)
		elif child is RichTextLabel and child.self_modulate.a > 0.0 and child.get_global_rect().has_area():
			lines.append(child.get_parsed_text())
		var nested: String = visible_text(child)
		if not nested.is_empty(): lines.append(nested)
	return "\n".join(lines)

static func capture(owner: Control, point: Vector2, expected: String, path: String) -> String:
	var viewport: Viewport = owner.get_viewport()
	var tree: SceneTree = owner.get_tree()
	move_pointer(viewport, point)
	var deadline: int = Time.get_ticks_msec() + POPUP_TIMEOUT_MSEC
	var popup: Window = popup_for(owner, expected)
	while popup == null and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		popup = popup_for(owner, expected)
	if popup == null:
		return "No embedded tooltip for %s at %s (hovered %s, %d embedded windows)" % [
			owner.name, point, viewport.gui_get_hovered_control(), viewport.get_embedded_subwindows().size()]
	if DisplayServer.get_name() == "headless":
		print("WOULD CAPTURE " + path)
	else:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(popup) or popup_for(owner, expected) != popup:
			return "Tooltip closed before the capture frame"
		var frame: Image = viewport.get_texture().get_image()
		if frame == null or frame.get_size() != Vector2i(viewport.get_visible_rect().size):
			return "Capture viewport returned an invalid image"
		var error: Error = frame.save_png(path)
		if error != OK: return "Cannot save %s: %s" % [path, error_string(error)]
		print(path)
	print("GFIX54 EMBEDDED TOOLTIP: %s | %s | %s" % [
		path.get_file(), Rect2i(popup.position, popup.size), JSON.stringify(visible_text(popup))])
	return ""
