extends RefCounted

# Use the same native Font RIDs, shaping, sizes, and outline bitmap caches as
# live controls. This prepares first-use rasterization on the main thread during
# existing loading/travel, without changing font resources or presentation.
const SLICE_USEC: int = 4000
const Assets = preload("res://scripts/asset_loader.gd")
static var _hitch_trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"

static func text_jobs(text: String, font: Font, size: int, outline: int, shadow_outline: int, viewport_oversampling: float, language: String = "") -> Array[Dictionary]:
	var jobs: Array[Dictionary]
	_append_text(jobs, {}, text, font, size, outline, shadow_outline, language, viewport_oversampling)
	return jobs

static func text_request(text: String, font: Font, size: int, outline: int, shadow_outline: int, oversampling: float, language: String) -> Dictionary:
	return {"text": text, "font": font, "size": size, "outline": outline, "shadow_outline": shadow_outline,
		"oversampling": oversampling, "language": language}

static func _fit_text_request(request: Dictionary) -> int:
	var size: int = request["size"]
	if not request.has("fit_text"): return size
	var width: float = request["font"].get_string_size(request["fit_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	size = mini(size, floori(float(size) * float(request["fit_width"]) / maxf(1.0, width)))
	var fitted: Dictionary = request["fitted_sizes"]
	if fitted.has(size): return -1
	fitted[size] = true
	return size

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
		_collect_control(node, jobs, seen)
	return jobs

static func _collect_control(node: Node, jobs: Array[Dictionary], seen: Dictionary) -> void:
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

# Walk the completed hidden view once. Shaping each Control and warming its
# bitmaps both draw from the same frame budget as the view's constructors.
static func prepare_hidden_controls_for(owner: Node, controls: Node, present: Callable, alive: Callable,
		include_hidden_children: bool = true, trace_prefix: String = "preparation:encounter:hidden_view") -> void:
	var jobs: Array[Dictionary]
	var pending: Array[Node]
	var seen: Dictionary = {}
	var span: RefCounted
	pending.append(controls)
	while not pending.is_empty() and _active(owner, alive):
		if Assets.preparation_slice_full():
			span = null
			await Assets.wait_for_preparation_slice(present, alive)
		if not _active(owner, alive): return
		var node: Node = pending.pop_back()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree(): continue
		# The staging root itself is hidden. Explicitly hidden panels below
		# that root can be skipped when only the initial screen needs warming.
		if not include_hidden_children and node != controls and node is CanvasItem and not node.visible: continue
		var started: int = Time.get_ticks_usec()
		if _hitch_trace_enabled and span == null: span = _trace_hidden_glyphs(owner, trace_prefix, "shape")
		for child: Node in node.get_children(): pending.append(child)
		_collect_control(node, jobs, seen)
		Assets.count_preparation_work(started)
	span = null
	if _active(owner, alive): await prepare_jobs_for(owner, jobs, present, alive, Callable(), 0, true, trace_prefix)

static func prepare_jobs_for(owner: Node, jobs: Array[Dictionary], present_frame: Callable, still_active: Callable, record_slice: Callable = Callable(), started: int = 0, shared_slice: bool = false,
		trace_prefix: String = "preparation:encounter:hidden_view") -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	var canvas: RID = RenderingServer.canvas_item_create()
	if started == 0: started = Time.get_ticks_usec()
	var cursor: int = 0
	var glyphs: Array[Dictionary]
	var request: Dictionary = {}
	var fitted_size: int
	var span: RefCounted
	# Fitting, shaping and drawing share one budget. Each iteration runs just
	# one of those operations so an expensive first-use font size can yield.
	while (cursor < jobs.size() or not glyphs.is_empty() or not request.is_empty()) and _active(owner, still_active):
		if shared_slice and Assets.preparation_slice_full():
			span = null
			RenderingServer.free_rid(canvas)
			await Assets.wait_for_preparation_slice(present_frame, still_active)
			if not _active(owner, still_active): return
			canvas = RenderingServer.canvas_item_create()
			continue
		var step_started: int = Time.get_ticks_usec() if shared_slice else 0
		if shared_slice and _hitch_trace_enabled and span == null: span = _trace_hidden_glyphs(owner, trace_prefix, "raster")
		if not glyphs.is_empty():
			_draw_glyph(server, canvas, glyphs.pop_back())
		elif not request.is_empty():
			_append_text(glyphs, {}, request["text"], request["font"], fitted_size, request["outline"], request["shadow_outline"], request["language"], request["oversampling"])
			glyphs.reverse()
			request = {}
		else:
			var job: Dictionary = jobs[cursor]
			cursor += 1
			if job.has("text"):
				fitted_size = _fit_text_request(job)
				if fitted_size > 0: request = job
			else:
				_draw_glyph(server, canvas, job)
		if shared_slice:
			Assets.count_preparation_work(step_started)
		elif Time.get_ticks_usec() - started >= SLICE_USEC:
			RenderingServer.free_rid(canvas)
			if record_slice.is_valid(): record_slice.call("opening_objective_glyph_slice", started)
			await present_frame.call()
			if not _active(owner, still_active): return
			canvas = RenderingServer.canvas_item_create()
			started = Time.get_ticks_usec()
	RenderingServer.free_rid(canvas)
	if record_slice.is_valid(): record_slice.call("opening_objective_glyph_slice", started)

static func _trace_hidden_glyphs(owner: Node, trace_prefix: String, step: String) -> RefCounted:
	return owner.get_tree().root.get_node("PerformanceTelemetry").hitch_phase(trace_prefix + ":glyph_" + step)

static func _draw_glyph(server: TextServer, canvas: RID, job: Dictionary) -> void:
	var size: Vector2i = job["size"]
	var shifts: int = 1 if server.font_get_subpixel_positioning(job["rid"]) == TextServer.SUBPIXEL_POSITIONING_DISABLED else 4
	for shift: int in range(shifts):
		var position := Vector2(float(shift) * 0.25, 0.0)
		if size.y > 0:
			server.font_draw_glyph_outline(job["rid"], canvas, size.x, size.y, position, job["index"], Color.WHITE, job["oversampling"])
		else:
			server.font_draw_glyph(job["rid"], canvas, size.x, position, job["index"], Color.WHITE, job["oversampling"])

static func _active(owner: Variant, still_active: Callable) -> bool:
	return is_instance_valid(owner) and not owner.is_queued_for_deletion() and bool(still_active.call())
