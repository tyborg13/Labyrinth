extends Node
## Tools-only observer. Production only writes env-gated spans; this observer owns sampling.
const COLUMNS: Array = ["frame", "draw_interval_ms", "monitor_process_peak_ms", "monitor_physics_peak_ms", "render_cpu_ms", "render_gpu_ms", "context", "monitors", "events", "observer_previous_us", "focused", "phase_times_us", "phase_frame", "driver_cpu_us", "draw_wall_ms", "main_wall_ms", "frame_setup_ms", "subviewports", "previous_post_draw_us", "first_physics_frame_us", "process_frame_us", "pre_draw_us", "post_draw_us", "pre_process_ms", "physics_wall_ms", "process_wall_ms", "process_end_us", "driver_bucket_us", "hitch_phase_times_us", "complete_interval", "redraws", "redraw_ms_estimate", "redraw_span_ms", "redraw_polygons", "redraw_frame"]
const MONITORS: Array = ["OBJECT_COUNT", "OBJECT_RESOURCE_COUNT", "OBJECT_NODE_COUNT", "OBJECT_ORPHAN_NODE_COUNT", "MEMORY_STATIC", "RENDER_VIDEO_MEM_USED", "RENDER_TEXTURE_MEM_USED", "RENDER_BUFFER_MEM_USED", "RENDER_TOTAL_DRAW_CALLS_IN_FRAME", "RENDER_TOTAL_OBJECTS_IN_FRAME", "RENDER_TOTAL_PRIMITIVES_IN_FRAME", "PHYSICS_2D_ACTIVE_OBJECTS", "PHYSICS_2D_COLLISION_PAIRS", "PHYSICS_2D_ISLAND_COUNT"]
var file: FileAccess
var active: bool = false
var action: String = "startup"
var phase: String = "startup"
var seed: int = 1
var decision: int = 0
var previous_us: int = 0
var observer_previous_us: int = 0
var observer_total_us: int = 0
var observer_max_us: int = 0
var observer_samples: Array[int]
var events: Dictionary = {}
var pipeline_previous: Dictionary = {}
var pipeline_ids: Dictionary = {}
var monitor_ids: Dictionary = {}
var frames: int = 0
var native: bool = false
var failure: String = ""
var unfocused_frames: int = 0
var driver_cpu_us: Dictionary = {}
var driver_total_us: int = 0
var pre_draw_us: int = 0
var first_physics_us: int = 0
var process_us: int = 0
var process_end_us: int = 0
var driver_spans: Array[PackedInt64Array]
var redraw = preload("res://tools/hitch_census/redraw.gd").new()
var telemetry: Node

func _enter_tree() -> void:
	# Attach before gameplay scenes/await continuations are installed.
	process_priority = 2147483647
	get_tree().physics_frame.connect(_physics_boundary)
	get_tree().process_frame.connect(_process_boundary)

func _physics_boundary() -> void:
	if not active: return
	var started: int = Time.get_ticks_usec()
	if first_physics_us == 0: first_physics_us = started
	_account(Time.get_ticks_usec() - started, false)

func _process_boundary() -> void:
	if not active: return
	var now: int = Time.get_ticks_usec()
	redraw.close(now)
	_account(Time.get_ticks_usec() - now, false)
	if not native: _sample(now)
	var resumed: int = Time.get_ticks_usec()
	process_us = now
	process_end_us = 0
	if not native:
		first_physics_us = 0
		previous_us = now
	_account(Time.get_ticks_usec() - resumed, false)

func _process(_delta: float) -> void:
	# Last-priority Node callback: after ordinary _process dispatch, before
	# deferred/message-queue work. Not a claim about an engine frame-end signal.
	if active and not native:
		process_end_us = Time.get_ticks_usec()
		_account(Time.get_ticks_usec() - process_end_us, false)

var subviewports: Dictionary = {}
var rendering_subviewports: Array[Dictionary]


func begin(path: String, run_seed: int, whole_settings: Dictionary = {}) -> void:
	if OS.get_environment("LABYRINTH_HITCH_TRACE") != "1": return
	seed = run_seed
	native = DisplayServer.get_name() != "headless"
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("HITCH TRACE: cannot open " + path)
		return
	for name: String in MONITORS:
		if ClassDB.class_has_integer_constant("Performance", name): monitor_ids[name] = ClassDB.class_get_integer_constant("Performance", name)
	for name: String in ClassDB.class_get_integer_constant_list("RenderingServer"):
		if name.begins_with("RENDERING_INFO_") and ("PIPELINE_COMPILATIONS" in name or "SHADER_COMPILATIONS" in name):
			pipeline_ids[name] = ClassDB.class_get_integer_constant("RenderingServer", name)
			# Zero includes startup work before the observer was attached.
			pipeline_previous[name] = 0
	file.store_line(JSON.stringify({"type": "header", "schema": 3, "redraw_version": 1, "columns": COLUMNS, "native": native, "seed": seed, "monitors": monitor_ids.keys(), "pipeline_counters": pipeline_ids.keys(), "present_timestamp": null, "present_proxy": "RenderingServer.frame_post_draw CPU submission boundary; not scanout", "resource_scope": "instance paths plus inclusive load spans; cache hits sampled at entry; native uploads not separately measured", "cpu_scope": "signal timestamps, not exclusive CPU: first physics_frame, process_frame, frame_pre_draw, frame_post_draw; monitor_process_peak_ms/monitor_physics_peak_ms are once-per-second rolling peaks, never bucket inputs", "timing_version": 3, "whole_settings": whole_settings, "boundary_connections": "_enter_tree before gameplay scene creation; existing autoload listeners may precede the observer", "headless_scope": "first sample is startup partial (complete_interval=false), then process_frame to next process_frame; process_wall_ms ends at last-priority Node._process callback, excluding later deferred/message-queue work", "phase_rule": "native phase_frame == frame; headless phase_frame == frame - 1; drained hitch_phase_times_us independently belong to this sample interval", "draw_split": "draw_wall_ms: frame_pre_draw to frame_post_draw; main_wall_ms: previous post_draw to pre_draw; frame_setup_ms: RenderingServer CPU setup timer; all null headlessly", "subviewport_scope": "pre_draw update-mode/ancestor-visibility candidates, not proof of actual backend draws; CPU timers may be zero/unavailable; subviewport CPU is part of draw, not additive", "godot": Engine.get_version_info(), "cpu": OS.get_processor_name(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "user_dir": ProjectSettings.globalize_path("user://"), "cel_look": OS.get_environment("LABYRINTH_CEL_LOOK")}))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var scan_started: int = Time.get_ticks_usec()
	_scan_subviewports(get_tree().root)
	_account(Time.get_ticks_usec() - scan_started, false)
	get_tree().node_added.connect(_instance_added)
	get_tree().node_removed.connect(_instance_removed)
	telemetry = get_node("/root/PerformanceTelemetry")
	previous_us = Time.get_ticks_usec()
	active = true
	if native:
		RenderingServer.frame_pre_draw.connect(_pre_draw)
		RenderingServer.frame_post_draw.connect(_sample)


func mark(label: String, stage: String = "action") -> void:
	action = label
	phase = stage
	decision += 1
	events["action:" + label] = int(events.get("action:" + label, 0)) + 1

func record_driver_cost(label: String, started: int) -> void:
	if not active: return
	var ended: int = Time.get_ticks_usec()
	redraw.close(started)
	var cost: int = ended - started
	driver_spans.append(PackedInt64Array([started, ended]))
	driver_cpu_us[label] = int(driver_cpu_us.get(label, 0)) + cost
	driver_total_us += cost
	_account(Time.get_ticks_usec() - ended, false)

func _instance_added(node: Node) -> void:
	if not active: return
	var started: int = Time.get_ticks_usec()
	if node is SubViewport: _register_subviewport(node)
	redraw.register(node, _record_redraw)
	var key: String = "instance:" + redraw.key(node)
	events[key] = int(events.get(key, 0)) + 1
	_account(Time.get_ticks_usec() - started, false)

func _scan_subviewports(node: Node) -> void:
	redraw.register(node, _record_redraw)
	if node is SubViewport: _register_subviewport(node)
	for child: Node in node.get_children(): _scan_subviewports(child)

func _record_redraw(node: CanvasItem) -> void:
	if not active: return
	var started: int = Time.get_ticks_usec()
	redraw.record(node, started)
	redraw.pending_end_us = Time.get_ticks_usec()
	_account(redraw.pending_end_us - started, false)

func _register_subviewport(viewport: SubViewport) -> void:
	var ancestors: Array[Node]
	var label: String = ""
	var ancestor: Node = viewport
	while ancestor != null:
		if label.is_empty() and not ancestor.scene_file_path.is_empty():
			label = ancestor.scene_file_path.get_file().get_basename()
		if ancestor is CanvasItem or ancestor is Window: ancestors.append(ancestor)
		ancestor = ancestor.get_parent()
	if label.is_empty():
		var owner_node: Node = viewport.owner
		var script: Script = owner_node.get_script() if owner_node != null else null
		label = script.resource_path.get_file().get_basename() if script != null else "builtin"
	subviewports[viewport.get_instance_id()] = {"node": viewport, "label": label + "/" + str(viewport.name), "ancestors": ancestors}
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)

func _instance_removed(node: Node) -> void:
	if not active: return
	var started: int = Time.get_ticks_usec()
	subviewports.erase(node.get_instance_id())
	_account(Time.get_ticks_usec() - started, false)

func _pre_draw() -> void:
	if not active: return
	pre_draw_us = Time.get_ticks_usec()
	redraw.close(pre_draw_us)
	rendering_subviewports.clear()
	for entry: Dictionary in subviewports.values():
		var viewport: SubViewport = entry["node"]
		if not is_instance_valid(viewport): continue
		var mode: int = viewport.render_target_update_mode
		if mode == SubViewport.UPDATE_DISABLED: continue
		if mode == SubViewport.UPDATE_WHEN_VISIBLE or mode == SubViewport.UPDATE_WHEN_PARENT_VISIBLE:
			var visible: bool = true
			for ancestor: Node in entry["ancestors"]:
				if not is_instance_valid(ancestor):
					visible = false
					break
				if ancestor is CanvasItem and not ancestor.is_visible_in_tree(): visible = false
				if ancestor is Window and not ancestor.visible: visible = false
			if not visible: continue
		rendering_subviewports.append({"rid": viewport.get_viewport_rid(), "label": entry["label"], "size": viewport.size})
	_account(Time.get_ticks_usec() - pre_draw_us, false)

func _subviewport_sample() -> Dictionary:
	var pixels: int = 0
	var cpu_ms: float = 0.0
	var top: Array[Array]
	for entry: Dictionary in rendering_subviewports:
		var size: Vector2i = entry["size"]
		var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(entry["rid"])
		pixels += size.x * size.y
		cpu_ms += cpu
		top.append([entry["label"], size.x, size.y, cpu])
	top.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) > float(b[3]))
	return {"count": rendering_subviewports.size(), "pixels": pixels, "cpu_ms": cpu_ms, "top": top.slice(0, 3)}

func _context() -> Dictionary:
	var telemetry: Node = get_node_or_null("/root/PerformanceTelemetry")
	var context: Dictionary = telemetry.get("_gameplay_context").duplicate() if telemetry != null else {}
	var current: Node = get_tree().current_scene
	var screen: String = str(context.get("mode", "startup"))
	if current != null and not current.has_method("_committed_run_state"): screen = current.scene_file_path.get_file().get_basename()
	for item: Array in [["map_open", "map"], ["character_open", "character"], ["pile_open", "pile"], ["menu_open", "menu"], ["grimoire_open", "grimoire"]]:
		if bool(context.get(item[0], false)): screen = item[1]
	if current != null and current.has_method("_committed_run_state"):
		var settings_panel: Control = current.get("_settings_panel")
		if is_instance_valid(settings_panel) and settings_panel.is_visible_in_tree(): screen = "settings"
		var combat: Dictionary = current.get("_combat_state")
		context["actor"] = combat.get("current_actor", {})
		context["animation_active"] = current.get("_animation_lock")
	context.merge({"screen": screen, "action": action, "phase": phase, "seed": seed, "decision": decision}, true)
	return context

func _sample(boundary_us: int = 0) -> void:
	if not active: return
	var started: int = Time.get_ticks_usec()
	var boundary: int = boundary_us if boundary_us > 0 else started
	var monitors: Dictionary = {}
	for name: String in monitor_ids: monitors[name] = Performance.get_monitor(monitor_ids[name])
	for name: String in pipeline_ids:
		var value: int = RenderingServer.get_rendering_info(pipeline_ids[name])
		var count: int = value - int(pipeline_previous[name])
		if count > 0: events["pipeline:" + name] = count
		pipeline_previous[name] = value
	var current: Node = get_tree().current_scene
	var phase_times: Dictionary = current.get("_runtime_performance_frame_phase_usec").duplicate() if current != null and current.has_method("_committed_run_state") else {}
	var phase_frame: int = int(current.get("_runtime_performance_frame_id")) if not phase_times.is_empty() else -1
	var expected_phase_frame: int = Engine.get_process_frames() if native else Engine.get_process_frames() - 1
	if phase_frame != expected_phase_frame: phase_times = {}
	var hitch_phases: Dictionary = telemetry.take_hitch_phases()
	events.merge(telemetry.take_hitch_events())
	var pre_process: Variant = null
	var physics_wall: Variant = null
	var process_wall: Variant = null
	var driver_buckets: Dictionary = {"pre_process": 0, "physics": 0, "process": 0, "draw": 0}
	if native and frames > 0 and process_us >= previous_us and pre_draw_us >= process_us and process_us > 0:
		var physics_start: int = first_physics_us if first_physics_us > 0 else process_us
		pre_process = float(physics_start - previous_us) / 1000.0
		physics_wall = float(process_us - physics_start) / 1000.0
		process_wall = float(pre_draw_us - process_us) / 1000.0
		for span: PackedInt64Array in driver_spans:
			driver_buckets["pre_process"] += _overlap(span, previous_us, physics_start)
			driver_buckets["physics"] += _overlap(span, physics_start, process_us)
			driver_buckets["process"] += _overlap(span, process_us, pre_draw_us)
			driver_buckets["draw"] += _overlap(span, pre_draw_us, boundary)
	elif not native and process_end_us >= process_us and process_us > 0:
		process_wall = float(process_end_us - process_us) / 1000.0
		for span: PackedInt64Array in driver_spans:
			driver_buckets["process"] += _overlap(span, process_us, process_end_us)
	phase_times.merge(hitch_phases)
	if not hitch_phases.is_empty(): phase_frame = expected_phase_frame
	var focused: bool = DisplayServer.window_is_focused() if native else false
	if native and not focused: unfocused_frames += 1
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	var redraw_sample: Array = redraw.drain(boundary)
	var row: Array = [Engine.get_process_frames(), float(boundary - previous_us) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) if native else null, RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid) if native else null, _context(), monitors, events, observer_previous_us, focused, phase_times, phase_frame, driver_cpu_us, float(boundary - pre_draw_us) / 1000.0 if native and pre_draw_us > 0 else null, float(pre_draw_us - previous_us) / 1000.0 if native and pre_draw_us > 0 else null, RenderingServer.get_frame_setup_time_cpu() if native else null, _subviewport_sample() if native else null, previous_us if native and frames > 0 else null, first_physics_us if first_physics_us > 0 else null, process_us if process_us > 0 else null, pre_draw_us if native and pre_draw_us > 0 else null, boundary if native else null, pre_process, physics_wall, process_wall, process_end_us if not native and process_end_us > 0 else null, driver_buckets, hitch_phases, (frames > 0 and process_us > 0) if native else process_us > 0]
	row.append_array(redraw_sample)
	row.append(expected_phase_frame)
	file.store_line(JSON.stringify(row))
	events = {}
	driver_cpu_us = {}
	driver_spans.clear()
	if native:
		first_physics_us = 0
		process_us = 0
		pre_draw_us = 0
	previous_us = boundary
	frames += 1
	observer_previous_us = Time.get_ticks_usec() - started
	_account(observer_previous_us, true)

func _account(cost: int, sample: bool) -> void:
	observer_total_us += cost
	observer_max_us = maxi(observer_max_us, cost)
	if sample: observer_samples.append(cost)

func finish() -> Dictionary:
	active = false
	observer_samples.sort()
	var flush_start: int = Time.get_ticks_usec()
	if file != null:
		file.flush()
		file.close()
	var result: Dictionary = {"frames": frames, "unfocused_frames": unfocused_frames, "known_driver_total_us": driver_total_us, "known_driver_mean_us": float(driver_total_us) / maxi(frames, 1), "observer_total_us": observer_total_us, "observer_mean_us": float(observer_total_us) / maxi(frames, 1), "observer_max_callback_us": observer_max_us, "observer_sample_p99_us": observer_samples[mini(observer_samples.size() - 1, ceili(observer_samples.size() * 0.99) - 1)] if not observer_samples.is_empty() else 0, "flush_us": Time.get_ticks_usec() - flush_start, "native": native, "failure": failure, "redraw_totals": redraw.totals, "redraw_frames_with_redraw": redraw.frames_with_redraw, "overhead_scope": "redraw recorder + startup scan + sampling + signal/node boundaries + pre_draw + node lifecycle callbacks; A/B calibration measures whole observer impact"}
	return result

func _overlap(span: PackedInt64Array, start: int, end: int) -> int:
	return maxi(0, mini(span[1], end) - maxi(span[0], start))
