extends SceneTree
## Bounded, resource-independent observer smoke; never renderer evidence.
const Trace = preload("res://tools/hitch_census/trace.gd")
const SAMPLE_FRAMES: int = 120
const PROOF_VIEWPORT_SIZE: Vector2i = Vector2i(32, 32)
const LIFECYCLE_VIEWPORT_COUNT: int = 5
const REDRAW_REQUESTS: int = 7
const REDRAW_FRAMES: int = 4
var trace: Node
var output: String

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_start.call_deferred()

func _start() -> void:
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	trace = Trace.new()
	root.add_child(trace)
	var viewport := SubViewport.new()
	viewport.name = "ObserverSmokeViewport"
	viewport.size = PROOF_VIEWPORT_SIZE
	root.add_child(viewport)
	var canvas := Node2D.new()
	canvas.name = "ExistingRedrawFixture"
	root.add_child(canvas)
	trace.begin(output.path_join("frames.jsonl"), 83)
	if trace.active: await _check_redraws(canvas)
	for index: int in SAMPLE_FRAMES:
		await process_frame
	viewport.queue_free()
	await process_frame
	var receipt: Dictionary = trace.finish()
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("HITCH OBSERVER CHECK: " + JSON.stringify(receipt))
	canvas.free()
	if not trace.active and OS.get_environment("LABYRINTH_HITCH_TRACE") != "1":
		assert(int(receipt["observer_total_us"]) == 0)
		print("HITCH OBSERVER OFF: observer_mean_us=0 PASS")
		quit(0)
		return
	_check_trace()
	_check_subviewports()
	print("HITCH OBSERVER ASSERTIONS: schema3 signal timing, lifecycle, visibility, modes, top3 PASS")
	quit(0 if int(receipt["frames"]) >= SAMPLE_FRAMES and not bool(receipt["native"]) else 1)

func _check_trace() -> void:
	var file := FileAccess.open(output.path_join("frames.jsonl"), FileAccess.READ)
	var header: Dictionary = JSON.parse_string(file.get_line())
	assert(int(header["schema"]) == 3)
	var process_values: Array[float]
	var previous_process: int = 0
	var counts: Dictionary = {}
	var frame_counts: Dictionary = {}
	var vertices: int = 0
	var internal_polygons: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty(): continue
		var row: Array = JSON.parse_string(line)
		assert(int(row[header["columns"].find("redraw_frame")]) == int(row[0]) - 1)
		var redraw_counts: Dictionary = row[header["columns"].find("redraws")]
		for label: String in redraw_counts:
			counts[label] = int(counts.get(label, 0)) + int(redraw_counts[label])
			frame_counts[label] = int(frame_counts.get(label, 0)) + 1
		var polygons: Dictionary = row[header["columns"].find("redraw_polygons")]
		vertices += int(polygons.get("builtin:Polygon2D", {}).get("vertices", 0))
		internal_polygons += int(polygons.get("builtin:Polygon2D", {}).get("internal_polygons", 0))
		if not bool(row[header["columns"].find("complete_interval")]):
			assert(row[header["columns"].find("process_wall_ms")] == null)
			continue
		var process_start: int = int(row[header["columns"].find("process_frame_us")])
		var process_end: int = int(row[header["columns"].find("process_end_us")])
		var process_ms: float = float(row[header["columns"].find("process_wall_ms")])
		assert(process_start > previous_process and process_end >= process_start)
		assert(is_equal_approx(process_ms, float(process_end - process_start) / 1000.0))
		previous_process = process_start
		process_values.append(process_ms)
		for column: String in ["draw_wall_ms", "main_wall_ms", "frame_setup_ms", "subviewports"]:
			assert(row[header["columns"].find(column)] == null)
	file.close()
	assert(process_values.max() > process_values.min())
	assert(counts == trace.redraw.totals)
	assert(frame_counts == trace.redraw.frames_with_redraw)
	assert(vertices == 3 and internal_polygons == 1)
	assert(counts.has("res://scripts/custom_cursor_glyph.gd"))
	print("HITCH REDRAW ROWS: frame rule, exact run totals, frames-with-redraw, script key, vertices=3 internal_polygons=1 PASS")

func _check_subviewports() -> void:
	var observer := Trace.new()
	root.add_child(observer)
	observer.begin(output.path_join("lifecycle.jsonl"), 83)
	var parent := Control.new()
	parent.name = "VisibilityParent"
	root.add_child(parent)
	var viewports: Array[SubViewport]
	for index: int in LIFECYCLE_VIEWPORT_COUNT:
		var viewport := SubViewport.new()
		viewport.name = "LifecycleViewport" + str(index)
		viewport.size = PROOF_VIEWPORT_SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		parent.add_child(viewport)
		viewports.append(viewport)
	assert(observer.subviewports.size() == 5)
	viewports[0].render_target_update_mode = SubViewport.UPDATE_ONCE
	viewports[1].render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewports[2].render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewports[3].render_target_update_mode = SubViewport.UPDATE_DISABLED
	observer._pre_draw()
	var sample: Dictionary = observer._subviewport_sample()
	assert(int(sample["count"]) == 4 and int(sample["pixels"]) == 4096)
	assert(sample["top"].size() == 3)
	assert(str(sample["top"][0][0]).ends_with("/LifecycleViewport0"))
	# ONCE may become DISABLED during draw; selection belongs to pre_draw.
	viewports[0].render_target_update_mode = SubViewport.UPDATE_DISABLED
	assert(int(observer._subviewport_sample()["count"]) == 4)
	parent.hide()
	observer._pre_draw()
	assert(int(observer._subviewport_sample()["count"]) == 1)
	parent.free()
	assert(observer.subviewports.is_empty())
	observer.finish()
	observer.free()

func _redraw_total(label: String) -> int:
	return int(trace.redraw.totals.get(label, 0)) + int(trace.redraw.counts.get(label, 0))

func _check_redraws(canvas: Node2D) -> void:
	await process_frame
	await process_frame
	var before: int = _redraw_total("builtin:Node2D")
	for index: int in REDRAW_REQUESTS: canvas.queue_redraw()
	await process_frame
	assert(_redraw_total("builtin:Node2D") - before == 1)
	before = _redraw_total("builtin:Node2D")
	for index: int in REDRAW_FRAMES:
		canvas.queue_redraw()
		await process_frame
	assert(_redraw_total("builtin:Node2D") - before == REDRAW_FRAMES)
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE])
	var polygon_indices: Array[PackedInt32Array]
	polygon_indices.append(PackedInt32Array([0, 1, 2]))
	polygon.polygons = polygon_indices
	root.add_child(polygon)
	await process_frame
	assert(_redraw_total("builtin:Polygon2D") == 1)
	polygon.free()
	# Deterministic timestamps verify charging direction, recorder exclusion,
	# flush termination, multi-flush span, and per-frame aggregates.
	var recorder = preload("res://tools/hitch_census/redraw.gd").new()
	recorder.record(canvas, 1000)
	recorder.pending_end_us = 1010
	recorder.record(canvas, 2010)
	recorder.pending_end_us = 2020
	recorder.close(3020)
	recorder.close(9000)
	var sample: Array = recorder.drain(10000)
	assert(sample[0]["builtin:Node2D"] == 2)
	assert(is_equal_approx(sample[1]["builtin:Node2D"], 2.0))
	assert(is_equal_approx(sample[2], 1.01))
	assert(recorder.frames_with_redraw["builtin:Node2D"] == 1)
	assert(recorder.drain(11000)[0].is_empty())
	print("HITCH REDRAW ASSERTIONS: 7 queue requests = 1 draw; 4 frames = 4 draws; existing/new nodes, polygon, gap accounting PASS")
