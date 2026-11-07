extends RefCounted

const RunScoreRules = preload("res://scripts/run_score_rules.gd")
const SLICE_USEC: int = 4000

var _running: bool = false
var _prepared_inputs: Array = []

func schedule(host: Control, recap: Control) -> void:
	if _running or recap.visible: return
	var inputs: Array = _inputs(host)
	if _prepared_inputs == inputs: return
	_running = true
	_prepare.call_deferred(weakref(host), weakref(recap), inputs)

static func _inputs(host: Control) -> Array:
	return [RunScoreRules.identity(host._run_state), host.get_viewport_rect().size, host.get_viewport().get_oversampling()]

static func _active(owner: WeakRef, recap_owner: WeakRef, inputs: Array) -> bool:
	var host: Variant = owner.get_ref()
	var recap: Variant = recap_owner.get_ref()
	return is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and is_instance_valid(recap) and not recap.is_queued_for_deletion() and not recap.visible and str(host._run_state.get("mode", "")) not in ["victory", "defeat", "embrace"] and _inputs(host) == inputs

static func _window_open(host: Control) -> bool:
	# Never run in startup/loading, the first map, or any later map. The first
	# scheduling point is the existing victory animation, after the real fight.
	return host._initial_ui_complete and not host._large_map_scrim.visible and str(host._run_state.get("mode", "")) in ["reward", "room", "event"]

static func _present_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw

static func _wait_for_window(owner: WeakRef, recap_owner: WeakRef, inputs: Array, tree: SceneTree) -> bool:
	await _present_frame(tree)
	while _active(owner, recap_owner, inputs):
		if _window_open(owner.get_ref()): return true
		await _present_frame(tree)
	return false

func _prepare(owner: WeakRef, recap_owner: WeakRef, inputs: Array) -> void:
	if not _active(owner, recap_owner, inputs):
		_running = false
		return
	var host: Control = owner.get_ref()
	var recap: Control = recap_owner.get_ref()
	var tree: SceneTree = host.get_tree()
	var batches: Array[Callable] = recap.first_use_glyph_batches(host._run_state)
	for batch: Callable in batches:
		if not await _wait_for_window(owner, recap_owner, inputs, tree):
			_running = false
			return
		var started: int = Time.get_ticks_usec()
		var jobs: Array[Dictionary]
		_shape_batch(batch, jobs)
		host._record_runtime_performance_phase("recap_glyph_shaping_preparation", started)
		var cursor: Dictionary = {"job": 0, "shift": 0}
		while int(cursor["job"]) < jobs.size():
			# Shaping and rasterization never share a slice. An individual
			# subpixel glyph draw is the smallest native text-server operation.
			if not await _wait_for_window(owner, recap_owner, inputs, tree):
				_running = false
				return
			started = Time.get_ticks_usec()
			_draw_slice(jobs, cursor)
			host._record_runtime_performance_phase("recap_glyph_raster_preparation", started)
	# Let pending font-atlas updates reach an ordinary frame before marking ready.
	if await _wait_for_window(owner, recap_owner, inputs, tree): _prepared_inputs = inputs
	_running = false

static func _shape_batch(batch: Callable, jobs: Array[Dictionary]) -> void:
	var shaped: Array[Dictionary] = batch.call()
	jobs.append_array(shaped)

static func _draw_slice(jobs: Array[Dictionary], cursor: Dictionary) -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	var canvas: RID = RenderingServer.canvas_item_create()
	var started: int = Time.get_ticks_usec()
	while int(cursor["job"]) < jobs.size():
		var job: Dictionary = jobs[int(cursor["job"])]
		var size: Vector2i = job["size"]
		var position := Vector2(float(cursor["shift"]) * 0.25, 0.0)
		if size.y > 0:
			server.font_draw_glyph_outline(job["rid"], canvas, size.x, size.y, position, job["index"], Color.WHITE, job["oversampling"])
		else:
			server.font_draw_glyph(job["rid"], canvas, size.x, position, job["index"], Color.WHITE, job["oversampling"])
		cursor["shift"] = int(cursor["shift"]) + 1
		var shifts: int = 1 if server.font_get_subpixel_positioning(job["rid"]) == TextServer.SUBPIXEL_POSITIONING_DISABLED else 4
		if int(cursor["shift"]) >= shifts:
			cursor["job"] = int(cursor["job"]) + 1
			cursor["shift"] = 0
		if Time.get_ticks_usec() - started >= SLICE_USEC: break
	RenderingServer.free_rid(canvas)
