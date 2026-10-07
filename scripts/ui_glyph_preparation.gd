extends RefCounted

# Use the same native Font RIDs, shaping, sizes, and outline bitmap caches as
# live controls. This prepares first-use rasterization on the main thread during
# existing loading/travel, without changing font resources or presentation.
const SLICE_USEC: int = 4000

static func text_jobs(text: String, font: Font, size: int, outline: int, shadow_outline: int, viewport_oversampling: float, language: String = "") -> Array[Dictionary]:
	var jobs: Array[Dictionary]
	_append_text(jobs, {}, text, font, size, outline, shadow_outline, language, viewport_oversampling)
	return jobs

static func collect_controls(root: Node) -> Array[Dictionary]:
	var jobs: Array[Dictionary]
	if not is_instance_valid(root) or root.is_queued_for_deletion() or not root.is_inside_tree(): return jobs
	var pending: Array[Node]
	pending.append(root)
	var seen: Dictionary = {}
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree(): continue
		for child: Node in node.get_children(): pending.append(child)
		if node is Label:
			var label: Label = node as Label
			var settings: LabelSettings = label.label_settings
			var font: Font = settings.font if settings != null and settings.font != null else label.get_theme_font("font")
			var size: int = settings.font_size if settings != null else label.get_theme_font_size("font_size")
			var outline: int = settings.outline_size if settings != null else label.get_theme_constant("outline_size")
			var shadow_outline: int = settings.shadow_size if settings != null else label.get_theme_constant("shadow_outline_size")
			var outline_color: Color = settings.outline_color if settings != null else label.get_theme_color("font_outline_color")
			var shadow_color: Color = settings.shadow_color if settings != null else label.get_theme_color("font_shadow_color")
			if outline_color.a <= 0.0: outline = 0
			if shadow_color.a <= 0.0: shadow_outline = 0
			var text: String = label.text.to_upper() if label.uppercase else label.text
			_append_text(jobs, seen, text, font, size, outline, shadow_outline, label.language, label.get_viewport().get_oversampling())
		elif node is Button:
			var button: Button = node as Button
			_append_text(jobs, seen, button.text, button.get_theme_font("font"), button.get_theme_font_size("font_size"), button.get_theme_constant("outline_size"), 0, button.language, button.get_viewport().get_oversampling())
	return jobs

static func _append_text(jobs: Array[Dictionary], seen: Dictionary, text: String, font: Font, size: int, outline: int, shadow_outline: int, language: String = "", viewport_oversampling: float = 1.0) -> void:
	if text.is_empty() or font == null: return
	var line := TextLine.new()
	line.add_string(text, font, size, language)
	var server: TextServer = TextServerManager.get_primary_interface()
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID = glyph["font_rid"]
		if not rid.is_valid(): continue
		var oversampling: float = server.font_get_oversampling(rid)
		if oversampling <= 0.0: oversampling = maxf(1.0 / 64.0, viewport_oversampling)
		var index: int = glyph["index"]
		var glyph_size: int = glyph["font_size"]
		for stroke: int in [0, outline, shadow_outline]:
			if stroke < 0: continue
			var key: Array = [rid, glyph_size, stroke, index, oversampling]
			if seen.has(key): continue
			seen[key] = true
			jobs.append({"font": font, "rid": rid, "size": Vector2i(glyph_size, stroke), "index": index, "oversampling": oversampling})

static func prepare_controls_for(owner: Node, controls: Node, present_frame: Callable, still_active: Callable) -> void:
	if not _active(owner, still_active) or not is_instance_valid(controls): return
	await prepare_jobs_for(owner, collect_controls(controls), present_frame, still_active)

static func prepare_jobs_for(owner: Node, jobs: Array[Dictionary], present_frame: Callable, still_active: Callable) -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	var canvas: RID = RenderingServer.canvas_item_create()
	var started: int = Time.get_ticks_usec()
	for job: Dictionary in jobs:
		if not _active(owner, still_active): break
		var size: Vector2i = job["size"]
		var shifts: int = 1 if server.font_get_subpixel_positioning(job["rid"]) == TextServer.SUBPIXEL_POSITIONING_DISABLED else 4
		for shift: int in range(shifts):
			var position := Vector2(float(shift) * 0.25, 0.0)
			if size.y > 0:
				server.font_draw_glyph_outline(job["rid"], canvas, size.x, size.y, position, job["index"], Color.WHITE, job["oversampling"])
			else:
				server.font_draw_glyph(job["rid"], canvas, size.x, position, job["index"], Color.WHITE, job["oversampling"])
		if Time.get_ticks_usec() - started >= SLICE_USEC:
			RenderingServer.free_rid(canvas)
			await present_frame.call()
			if not _active(owner, still_active): return
			canvas = RenderingServer.canvas_item_create()
			started = Time.get_ticks_usec()
	RenderingServer.free_rid(canvas)

static func _active(owner: Variant, still_active: Callable) -> bool:
	return is_instance_valid(owner) and not owner.is_queued_for_deletion() and bool(still_active.call())
