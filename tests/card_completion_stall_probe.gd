extends "res://tests/runtime_frame_performance_benchmark.gd"

# Detailed tracing and timing run separately. The timed window includes the whole
# action plus 500 ms after unlock, so deferred hand fitting cannot hide work.
const HAND_POINTER_POLICY: String = "completion_pointer_v1"
const HAND_POINTER_LOCAL_ANCHOR := Vector2(70.0, 160.0)
var _native_pointer_instance: Node = null
var _native_pointer_anchor: Vector2 = Vector2.ZERO
var _native_pointer_returned: bool = false
var _native_pointer_trace: Dictionary = {}
var _probe_instance: Node
var _probe_active: bool = false
var _probe_frames: Array[Dictionary]
var _probe_seen_locked: bool = false
var _probe_unlock_usec: int = 0
var _probe_unlock_frame: int = -1
var _probe_window_position: Vector2i
var _probe_window_size: Vector2i
var _probe_environment_violations: Array[Dictionary]
var _probe_targets: Array[Vector2i]
var _probe_lock_count: int = 0
var _probe_previous_locked: bool = false

func _initialize() -> void:
	_phase_log("initialize")
	ParallelRuntime.apply_from_environment()
	_viewport_size = _requested_viewport_size()
	# Synthetic pointer calls do not wake the desktop event loop the way a real
	# mouse event does. Disable low-processor sleeping for this probe so a target
	# that produces an identical retained visual cannot inject a one-second idle
	# timeout into the frame-pacing sample.
	OS.low_processor_usage_mode = false
	# Native runners can still re-enter the idle governor while the synthetic window
	# is unfocused. A real pointer event wakes that governor; cap its fallback sleep
	# so synthetic input has the same scheduling opportunity without stealing focus.
	OS.low_processor_usage_mode_sleep_usec = 1000
	# The game defaults to fullscreen. A native probe launched from another app can
	# otherwise live in an inactive macOS fullscreen Space and receive Metal
	# drawables at roughly 1 Hz despite normal game-side frame work.
	root.mode = Window.MODE_WINDOWED
	root.size = _viewport_size
	_render_pulse = RenderPulse.new()
	_render_pulse.name = "PerformanceRenderPulse"
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_pulse.position = Vector2.ZERO
	_render_pulse.size = Vector2.ONE
	_render_pulse.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	root.add_child(_render_pulse)
	# Native macOS can throttle Metal drawable delivery for an occluded/background
	# window. Player input is measured in a focused game window, so keep the native
	# probe in that same presentation state instead of benchmarking App Nap.
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_runtime_frame_performance.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_runtime_frame_performance.save")
	ProgressionStore.clear_saved_run()
	var probe_settings_store = load("res://scripts/settings_store.gd")
	probe_settings_store.set_storage_path("user://runtime_performance_settings.json")
	var probe_settings: Dictionary = probe_settings_store.default_settings()
	probe_settings["display_mode"] = "windowed"
	probe_settings["ui_scale"] = 1.0
	probe_settings["reduced_motion"] = OS.get_environment("LABYRINTH_RUNTIME_PERF_REDUCED_MOTION") == "1"
	probe_settings_store.save_settings(probe_settings)
	await process_frame

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_phase_log("scene loaded")
	var instance: Node = packed.instantiate()
	if OS.get_environment("LABYRINTH_STALL_TRACE") == "1":
		instance.set_script(load("res://tests/fixtures/card_completion_trace_scene.gd"))
	root.add_child(instance)
	root.mode = Window.MODE_WINDOWED
	root.size = _viewport_size
	_phase_log("scene ready")
	var sampler := FrameSampler.new()
	sampler.request_render = _render_pulse.pulse
	sampler.observe_frame = _observe_probe_focus
	sampler.measured_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(sampler.measured_viewport_rid, true)
	root.add_child(sampler)
	var initially_focused: bool = await _acquire_probe_window_focus()
	if not initially_focused:
		push_warning("Native probe window was not initially focused; continuing with per-frame focus reclamation.")
	await _settle_frames(8)
	# macOS can deliver the startup fullscreen transition after scene _ready.
	# Apply the authored window size after that transition has settled as well.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.mode = Window.MODE_WINDOWED
	root.size = _viewport_size
	await _settle_frames(8)
	_phase_log("initial settle complete")
	_install_stress_combat(instance, "specialists")
	_set_candidate_batching_enabled(instance)
	_phase_log("stress combat installed")
	await _settle_frames(8)
	await _settle_probe_window()
	await _settle_frames(8)
	if OS.get_environment("LABYRINTH_STALL_INPUT_ONLY") == "1":
		var helper = load("res://tests/fixtures/card_completion_input_cases.gd").new()
		var input_result: Dictionary = await helper.run(self, instance)
		print("CARD COMPLETION INPUT RESULT: " + JSON.stringify(input_result))
		quit(0 if _errors.is_empty() else 1)
		return
	_probe_instance = instance
	RenderingServer.frame_post_draw.connect(_observe_completion_draw)
	var trace_enabled: bool = OS.get_environment("LABYRINTH_STALL_TRACE") == "1"
	var repetitions: int = maxi(1, int(OS.get_environment("LABYRINTH_STALL_REPETITIONS")))
	var card_id: String = OS.get_environment("LABYRINTH_STALL_CARD")
	if card_id.is_empty(): card_id = "gust_step"
	var repetitions_result: Array[Dictionary]
	# One authored warmup is retained separately from measured repetitions.
	for repetition: int in range(repetitions + 1):
		_phase_log("completion %s repetition %d" % [card_id, repetition])
		_install_stress_combat(instance, "specialists")
		await _settle_render_frames(8)
		await _prepare_native_hand_pointer(instance)
		await _select_card(instance, _hand_index(instance, card_id))
		await _settle_render_frames(3)
		var before_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		var before_snapshot: Dictionary = _native_hand_pointer_diagnostic_snapshot(instance)
		_reset_board_render_instrumentation(instance)
		CardWidget.set_layout_instrumentation_enabled(trace_enabled)
		instance.call("set_runtime_performance_instrumentation_enabled", trace_enabled)
		var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
		board.call("set_submission_performance_instrumentation_enabled", trace_enabled)
		_probe_frames.clear()
		_probe_targets.clear()
		_probe_lock_count = 0
		_probe_previous_locked = false
		_probe_environment_violations.clear()
		_probe_window_position = DisplayServer.window_get_position()
		_probe_window_size = DisplayServer.window_get_size()
		_probe_seen_locked = false
		_probe_unlock_usec = 0
		_probe_unlock_frame = -1
		if trace_enabled: instance.call("start_completion_trace")
		# Finish preparation before the sampled draw boundary.
		await _await_render_frame()
		_probe_active = true
		sampler.begin()
		var interaction: Dictionary = await _exercise_preview_steps(instance, false, card_id)
		var guard: int = 0
		while (_probe_unlock_usec == 0 or Time.get_ticks_usec() - _probe_unlock_usec < 500000) and guard < 1000:
			await _await_render_frame()
			guard += 1
		# A slice resumed by frame_post_draw costs the next delivered interval.
		# Prove quiescence while sampling, then include that following draw.
		_expect(_completion_work_quiescent(instance), "Completion work must settle inside the declared window")
		var quiescent_usec: int = Time.get_ticks_usec()
		await _await_render_frame()
		_expect(not _probe_frames.is_empty() and int(_probe_frames.back()["usec"]) > quiescent_usec, "Sampling must include a draw after quiescence")
		var raw: Dictionary = sampler.finish()
		_probe_active = false
		var profile: Dictionary = instance.call("runtime_performance_frame_instrumentation_snapshot") as Dictionary
		var animation_clock: Dictionary = instance.call("runtime_animation_clock_snapshot") as Dictionary
		var trace: Array = instance.call("finish_completion_trace") if trace_enabled else []
		board.call("set_submission_performance_instrumentation_enabled", false)
		instance.call("set_runtime_performance_instrumentation_enabled", false)
		CardWidget.set_layout_instrumentation_enabled(false)
		var after_snapshot: Dictionary = _native_hand_pointer_diagnostic_snapshot(instance)
		var hand: Control = instance.get("hand_box") as Control
		var tween: Tween = hand.get("_emphasis_tween") as Tween
		_expect(_probe_seen_locked and _probe_unlock_usec > 0, "Action must lock then unlock during delivered frames")
		_expect(_probe_lock_count == 1 and not bool(instance.get("_animation_lock")), "Focused action must have exactly one lock cycle and finish unlocked")
		var observed_ids: Array
		for observed: Dictionary in _probe_frames: observed_ids.append(observed["frame"])
		_expect(observed_ids == raw["frame_ids"], "Completion observer and frame sampler must cover the same draws")
		_expect(not _probe_frames.is_empty() and int(_probe_frames.back()["usec"]) - _probe_unlock_usec >= 500000, "Delivered frame coverage must extend at least 500 ms past unlock")
		for index: int in range(hand.get_child_count()):
			var widget: Control = instance.call("_hand_card_control", index) as Control
			var pose: Tween = widget.get("_pose_tween") as Tween if widget != null else null
			_expect(pose == null or not pose.is_valid() or not pose.is_running(), "Card pose must settle within the completion window")
		_expect(guard < 1000, "Action completion must finish inside guard")
		_expect(int(instance.get("_hand_layout_pending_revision")) < 0, "Deferred hand layout must finish within the completion window")
		_expect(tween == null or not tween.is_valid() or not tween.is_running(), "Hand emphasis must settle within the completion window")
		_expect(before_state != instance.get("_combat_state"), "Action must commit a gameplay change")
		_expect(_native_pointer_returned, "Physical pointer must return while the action is locked")
		_expect(_probe_environment_violations.is_empty(), "Pointer, window and focus must stay fixed after the scripted return")
		_expect(int(after_snapshot.get("orphan_nodes", -1)) == 0, "Completion must leave no orphan nodes")
		if instance.has_method("_request_skill_event_analytics"):
			_expect(not instance.get("_skill_analytics_queue").busy(), "Deferred analytics must finish within the measured completion window")
		repetitions_result.append({"warmup": repetition == 0, "card_id": card_id, "raw": raw, "frames": _probe_frames.duplicate(true), "unlock_frame": _probe_unlock_frame, "unlock_usec": _probe_unlock_usec, "profile": profile, "trace": trace, "before": before_snapshot, "after": after_snapshot, "pointer_return": _native_pointer_trace.duplicate(true), "interaction": interaction, "before_state": before_state, "after_state": (instance.get("_combat_state") as Dictionary).duplicate(true), "targets": _probe_targets.duplicate(), "lock_count": _probe_lock_count, "environment_violations": _probe_environment_violations.duplicate(true), "animation_clock": animation_clock, "quiescent_usec": quiescent_usec})
		_native_pointer_instance = null
	var output: Dictionary = {"schema_version": 1, "workload": "card_completion_stall_v1", "settings": probe_settings, "trace_enabled": trace_enabled, "engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "os": OS.get_name(), "viewport": [root.size.x, root.size.y], "repetitions": repetitions_result, "errors": _errors, "focus_observations": _focus_observation_count, "unfocused_observations": _unfocused_observation_count, "focus_pauses": _focus_pause_count}
	print("CARD COMPLETION STALL RESULT: " + JSON.stringify(output))
	instance.queue_free()
	sampler.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _observe_completion_draw() -> void:
	if not _probe_active: return
	# Constant-size observations only; never walk the hand inside timing.
	if _native_pointer_returned and _probe_environment_violations.size() < 16:
		var point: Vector2 = root.get_mouse_position()
		var display_point: Vector2i = DisplayServer.mouse_get_position()
		var returned: Dictionary = _native_pointer_trace.get("after_action_anchor_return", {})
		var recorded_display: Array = returned.get("physical_display_position", [])
		var display_drift: bool = recorded_display.size() != 2
		if not display_drift:
			display_drift = Vector2(display_point).distance_to(Vector2(recorded_display[0], recorded_display[1])) > 2.0
		if point.distance_to(_native_pointer_anchor) > 2.0 or display_drift or DisplayServer.window_get_position() != _probe_window_position or DisplayServer.window_get_size() != _probe_window_size or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED or not DisplayServer.window_is_focused():
			_probe_environment_violations.append({"frame": Engine.get_process_frames(), "pointer": [point.x, point.y], "display_pointer": [display_point.x, display_point.y], "focused": DisplayServer.window_is_focused()})
	var locked: bool = bool(_probe_instance.get("_animation_lock"))
	var now_usec: int = Time.get_ticks_usec()
	var frame: int = Engine.get_process_frames()
	if locked and not _probe_previous_locked: _probe_lock_count += 1
	_probe_previous_locked = locked
	if locked: _probe_seen_locked = true
	if _probe_seen_locked and not locked and _probe_unlock_usec == 0:
		_probe_unlock_usec = now_usec
		_probe_unlock_frame = frame
	_probe_frames.append({"frame": frame, "usec": now_usec, "locked": locked})

func _completion_work_quiescent(instance: Node) -> bool:
	if bool(instance.get("_animation_lock")) or int(instance.get("_hand_layout_pending_revision")) >= 0:
		return false
	if instance.has_method("_request_skill_event_analytics") and instance.get("_skill_analytics_queue").busy():
		return false
	var hand: Control = instance.get("hand_box") as Control
	var emphasis: Tween = hand.get("_emphasis_tween") as Tween
	if emphasis != null and emphasis.is_valid() and emphasis.is_running():
		return false
	for index: int in range(hand.get_child_count()):
		var widget: Control = instance.call("_hand_card_control", index) as Control
		var pose: Tween = widget.get("_pose_tween") as Tween if widget != null else null
		if pose != null and pose.is_valid() and pose.is_running():
			return false
	return true

func _routed_left_click(control: Control, local_position: Vector2, double_click: bool = false) -> float:
	if control == null or control.get_viewport() == null:
		return 0.0
	# Viewport GUI input is expressed in viewport coordinates. Include CanvasLayer
	# transforms so UiLayer controls receive the event at their rendered position.
	var target_viewport: Viewport = control.get_viewport()
	var global_position: Vector2 = control.get_global_transform_with_canvas() * local_position
	if _native_hand_pointer_enabled(): root.warp_mouse(global_position)
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	target_viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = global_position
	press.global_position = global_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.double_click = double_click
	press.pressed = true
	var release := InputEventMouseButton.new()
	release.position = global_position
	release.global_position = global_position
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	var started: int = Time.get_ticks_usec()
	target_viewport.push_input(press, true)
	target_viewport.push_input(release, true)
	_return_native_pointer_during_animation()
	return float(Time.get_ticks_usec() - started) / 1000.0


func _routed_pointer_motion(control: Control, local_position: Vector2) -> void:
	if control == null or control.get_viewport() == null:
		return
	var global_position: Vector2 = control.get_global_transform_with_canvas() * local_position
	if _native_hand_pointer_enabled(): root.warp_mouse(global_position)
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	control.get_viewport().push_input(motion, true)


func _board_pointer_hover(instance: Node, tile: Vector2i) -> void:
	if _probe_active: _probe_targets.append(tile)
	# Exercise the same board-local mouse-motion path as live play. Calling the
	# RunScene signal handler directly skips hit testing, the board's own hover
	# state, cursor changes, HUD-region rebuilds, and redraw invalidation.
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var point: Vector2 = board.call("world_position_for_tile", tile) as Vector2
	if _native_hand_pointer_enabled():
		_routed_pointer_motion(board, point)
		return
	var event := InputEventMouseMotion.new()
	event.position = point
	board.call("_gui_input", event)


func _native_hand_pointer_enabled() -> bool:
	return OS.get_environment("LABYRINTH_RUNTIME_PERF_HAND_POINTER") == "1"


func _native_hand_pointer_snapshot(instance: Node) -> Dictionary:
	var hand: Control = instance.get("hand_box") as Control
	var cards: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	var hovered_index: int = int(instance.get("_hovered_card_index"))
	var routed_control: Control = root.gui_get_hovered_control()
	var routed_index: int = int(instance.call("_hand_card_index_for_widget", routed_control)) if routed_control is CardWidget else -1
	var viewport_position: Vector2 = root.get_mouse_position()
	var display_position: Vector2i = DisplayServer.mouse_get_position()
	var window_position: Vector2i = DisplayServer.window_get_position()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var geometric_hits: Array[int]
	var card_bounds: Array[Dictionary]
	for index: int in range(hand.get_child_count()):
		var widget: Control = instance.call("_hand_card_control", index) as Control
		if widget == null: continue
		var transform: Transform2D = widget.get_global_transform_with_canvas()
		var local_pointer: Vector2 = transform.affine_inverse() * viewport_position
		var contains: bool = widget.is_visible_in_tree() and Rect2(Vector2.ZERO, widget.size).has_point(local_pointer)
		if contains: geometric_hits.append(index)
		card_bounds.append({"index": index, "transform": _native_pointer_transform_values(transform), "size": [widget.size.x, widget.size.y], "contains_pointer": contains})
	var routed_contains: bool = routed_control != null and Rect2(Vector2.ZERO, routed_control.size).has_point(routed_control.get_global_transform_with_canvas().affine_inverse() * viewport_position)
	return {
		"geometric_hand_hit_indices": geometric_hits,
		"hand_card_bounds": card_bounds,
		"routed_control_contains_pointer": routed_contains,
		"viewport_position": [viewport_position.x, viewport_position.y],
		"physical_display_position": [display_position.x, display_position.y],
		"window_position": [window_position.x, window_position.y],
		"window_size": [window_size.x, window_size.y],
		"live_scene_nodes": _subtree_node_count(instance),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"hand_card_ids": cards.duplicate(),
		"hovered_hand_index": hovered_index,
		"hovered_card_id": str(cards[hovered_index]) if hovered_index >= 0 and hovered_index < cards.size() else "",
		"routed_hand_index": routed_index,
		"routed_card_id": str(cards[routed_index]) if routed_index >= 0 and routed_index < cards.size() else "",
		"emphasized_hand_index": hand.call("emphasized_index"),
		"emphasis_strength": hand.call("emphasis_strength"),
		"selected_hand_index": instance.get("_selected_card_index"),
	}


func _native_pointer_transform_values(transform: Transform2D) -> Array:
	return [transform.x.x, transform.x.y, transform.y.x, transform.y.y, transform.origin.x, transform.origin.y]


func _native_hand_pointer_diagnostic_snapshot(instance: Node) -> Dictionary:
	var snapshot: Dictionary = _native_hand_pointer_snapshot(instance)
	var routed: Control = root.gui_get_hovered_control()
	var hand: Control = instance.get("hand_box") as Control
	snapshot["router_path"] = str(routed.get_path()) if routed != null else ""
	snapshot["router_class"] = routed.get_class() if routed != null else ""
	snapshot["hand_transform"] = _native_pointer_transform_values(hand.get_global_transform_with_canvas())
	snapshot["hand_size"] = [hand.size.x, hand.size.y]
	snapshot["hand_layout_revision"] = instance.get("_hand_layout_revision")
	snapshot["hand_layout_pending_revision"] = instance.get("_hand_layout_pending_revision")
	var slots: Array[Dictionary]
	for index: int in range(hand.get_child_count()):
		var slot: Control = hand.get_child(index) as Control
		var widget: Control = instance.call("_hand_card_control", index) as Control
		if slot == null: continue
		var slot_snapshot: Dictionary = {"index": index, "position": [slot.position.x, slot.position.y], "size": [slot.size.x, slot.size.y], "scale": [slot.scale.x, slot.scale.y], "rotation": slot.rotation, "visible": slot.is_visible_in_tree(), "transform": _native_pointer_transform_values(slot.get_global_transform_with_canvas())}
		if widget != null:
			slot_snapshot["widget_transform"] = _native_pointer_transform_values(widget.get_global_transform_with_canvas())
			slot_snapshot["widget_size"] = [widget.size.x, widget.size.y]
			slot_snapshot["widget_local_hovered"] = widget.get("_local_hovered")
			slot_snapshot["widget_mouse_filter"] = widget.mouse_filter
		slots.append(slot_snapshot)
	snapshot["slots"] = slots
	var tooltip_stack: Control = instance.get("_card_focus_tooltip_stack") as Control
	snapshot["tooltip_nodes"] = _subtree_node_count(tooltip_stack) if tooltip_stack != null else 0
	snapshot["tooltip_icons"] = tooltip_stack.call("entry_icon_keys") if tooltip_stack != null else []
	var rail: Control = instance.get("_turn_order_bar") as Control
	snapshot["turn_order_nodes"] = _subtree_node_count(rail) if rail != null else 0
	return snapshot


func _return_native_pointer_during_animation() -> void:
	if _native_pointer_instance == null or _native_pointer_returned or not bool(_native_pointer_instance.get("_animation_lock")):
		return
	_native_pointer_returned = true
	_move_native_hand_pointer(_native_pointer_anchor)
	var viewport_position: Vector2 = root.get_mouse_position()
	var display_position: Vector2i = DisplayServer.mouse_get_position()
	_native_pointer_trace["after_action_anchor_return"] = {"viewport_position": [viewport_position.x, viewport_position.y], "physical_display_position": [display_position.x, display_position.y], "animation_lock": true}
	_native_pointer_trace["returned_during_animation"] = true


func _move_native_hand_pointer(position: Vector2) -> void:
	root.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)


func _settle_native_hand_pointer(instance: Node) -> void:
	var hand: Control = instance.get("hand_box") as Control
	for frame_index: int in range(90):
		await _await_render_frame()
		if frame_index < 5 or int(instance.get("_hand_layout_pending_revision")) >= 0:
			continue
		var fan_tween: Tween = hand.get("_emphasis_tween") as Tween
		if fan_tween != null and fan_tween.is_valid() and fan_tween.is_running():
			continue
		var pose_running: bool = false
		for index: int in range(hand.get_child_count()):
			var widget: Control = instance.call("_hand_card_control", index) as Control
			var pose_tween: Tween = widget.get("_pose_tween") as Tween if widget != null else null
			if pose_tween != null and pose_tween.is_valid() and pose_tween.is_running():
				pose_running = true
				break
		if not pose_running:
			return
	_expect(false, "Controlled pointer setup must settle its authored fan and card pose before measurement")


func _prepare_native_hand_pointer(instance: Node) -> Dictionary:
	if not _native_hand_pointer_enabled():
		return {}
	_expect(DisplayServer.get_name() != "headless", "Controlled hand-pointer workload requires native window input")
	# Fixture installation schedules deferred fan fitting; derive the anchor
	# from its resting geometry before routed selection changes the hand pose.
	await _settle_render_frames(6)
	# An identical warp can produce no native motion. Leave the hand first and
	# deliver matching physical/routed motion so fixture-reset hover cannot carry
	# into the next measured action. Settle normal pose motion outside sampling.
	_move_native_hand_pointer(Vector2(8.0, 8.0))
	await _settle_native_hand_pointer(instance)
	var after_pointer_reset: Dictionary = _native_hand_pointer_snapshot(instance)
	var hand: Control = instance.get("hand_box") as Control
	var requested: Vector2 = hand.get_global_transform_with_canvas() * HAND_POINTER_LOCAL_ANCHOR
	_move_native_hand_pointer(requested)
	var after_warp: Dictionary = _native_hand_pointer_snapshot(instance)
	await _settle_native_hand_pointer(instance)
	var observed: Vector2 = root.get_mouse_position()
	_expect(observed.distance_to(requested) <= 2.0, "Native hand pointer must reach its requested viewport anchor before measurement")
	_native_pointer_instance = instance
	_native_pointer_anchor = requested
	_native_pointer_returned = false
	_native_pointer_trace = {"policy": HAND_POINTER_POLICY, "hand_local_anchor": [HAND_POINTER_LOCAL_ANCHOR.x, HAND_POINTER_LOCAL_ANCHOR.y], "requested_viewport_anchor": [requested.x, requested.y], "after_pointer_reset": after_pointer_reset, "after_warp": after_warp, "after_anchor_settle": _native_hand_pointer_snapshot(instance), "before_input": _native_hand_pointer_snapshot(instance), "returned_during_animation": false}
	return _native_pointer_trace


func _await_render_frame() -> void:
	_return_native_pointer_during_animation()
	# A retained scene may correctly have no dirty gameplay draw command. Pulse a
	# dedicated one-pixel CanvasItem so frame_post_draw denotes the immediately
	# requested frame rather than a later unrelated animation or idle redraw.
	if _render_pulse != null and is_instance_valid(_render_pulse):
		_render_pulse.pulse()
	await RenderingServer.frame_post_draw
	if not DisplayServer.window_is_focused():
		var focus_returned: bool = await _pause_until_probe_focus()
		_expect(focus_returned, "native frame proof must regain focus within its bounded pause")


