extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const DEFAULT_VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const WARMUP_FRAMES: int = 45
const IDLE_FRAMES: int = 150
const OUTPUT_DIR: String = "user://performance/runtime_frame_benchmark"
const WORKLOAD_ID: String = "depth_13_live_run_interaction_matrix_v8"
const HAND: Array[String] = [
	"threaded_path",
	"sidestep_slash",
	"bone_dart",
	"wildfire_halo",
	"glowstone_ward",
	"shadow_step",
	"gust_step",
	"static_pivot",
	"thunderline",
	"cinder_fusillade",
]
const EXECUTION_CARDS: Array[String] = HAND
const RELICS: Array[String] = [
	"ember_lens",
	"pilgrim_boots",
	"mirror_shard",
	"storm_capacitor",
	"frost_prism",
	"gale_tabi",
	"anchor_chain",
	"venom_signet",
	"basalt_calendar",
	"bloodglass_knife",
	"borrowed_hourglass",
	"cinderbrand_tongs",
	"cold_mirror",
	"dawnstitch_cord",
	"fivefold_knot",
	"thunder_relay",
]
const SKILLS: Array[String] = [
	"quick_wits",
	"encore",
	"prismatic_instinct",
	"rehearsed_escape",
	"makeshift_tool",
	"carry_the_guard",
	"measured_breath",
	"pain_remembers",
	"sure_footed",
	"afterimage",
	"borrowed_time",
	"last_reserve",
	"plunderers_step",
	"living_shadow",
	"open_arsenal",
	"confluence",
	"long_dawn",
	"witchlight",
	"dawnbrand",
]
const MANUAL_SKILLS: Array[String] = [
	"quick_wits",
	"encore",
	"prismatic_instinct",
	"rehearsed_escape",
	"makeshift_tool",
	"carry_the_guard",
]
const COMPOSITIONS: Array[String] = ["specialists", "split_swarm", "dragon_support"]
const MAX_PREVIEW_STEPS: int = 12
const BLINK_PREVIEW_STEADY_FRAMES: int = 120
const BLINK_PREVIEW_SWEEP_FRAMES: int = 90
const MAX_ANIMATION_SETTLE_FRAMES: int = 900

class FrameSampler:
	extends Node

	var active: bool = false
	var previous_tick_usec: int = 0
	var frame_intervals_ms: Array[float] = []
	var process_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var objects_in_frame: Array[float] = []
	var primitives_in_frame: Array[float] = []

	func _ready() -> void:
		process_priority = 1000
		set_process(true)

	func begin() -> void:
		frame_intervals_ms.clear()
		process_ms.clear()
		draw_calls.clear()
		objects_in_frame.clear()
		primitives_in_frame.clear()
		previous_tick_usec = Time.get_ticks_usec()
		active = true

	func finish() -> Dictionary:
		active = false
		return {
			"frame_interval_ms": frame_intervals_ms.duplicate(),
			"process_ms": process_ms.duplicate(),
			"draw_calls": draw_calls.duplicate(),
			"objects_in_frame": objects_in_frame.duplicate(),
			"primitives_in_frame": primitives_in_frame.duplicate(),
		}

	func _process(_delta: float) -> void:
		if not active:
			return
		var now_tick: int = Time.get_ticks_usec()
		frame_intervals_ms.append(float(now_tick - previous_tick_usec) / 1000.0)
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitives_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		previous_tick_usec = now_tick

class RenderPulse:
	extends Control

	var phase: bool = false

	func pulse() -> void:
		phase = not phase
		queue_redraw()

	func _draw() -> void:
		# An imperceptible changing pixel forces a real render boundary without
		# invalidating or rebuilding any gameplay-retained layer.
		var alpha: float = 0.001 if phase else 0.002
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 1.0, 1.0, alpha), true)

var _errors: Array[String] = []
var _combat := CombatEngine.new()
var _validated_prevalidated_action_types: Dictionary = {}
var _profiled_initial_refresh: bool = false
var _render_pulse: RenderPulse = null
var _focus_observation_count: int = 0
var _unfocused_observation_count: int = 0
var _viewport_size: Vector2i = DEFAULT_VIEWPORT_SIZE

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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_viewport_size)
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
	await process_frame

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_phase_log("scene loaded")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	_phase_log("scene ready")
	var sampler := FrameSampler.new()
	root.add_child(sampler)
	var initially_focused: bool = await _acquire_probe_window_focus()
	if not initially_focused:
		push_error("RUNTIME FRAME PERF RESULT: FAIL native probe window could not become focused")
		instance.queue_free()
		sampler.queue_free()
		await process_frame
		quit(1)
		return
	await _settle_frames(8)
	_phase_log("initial settle complete")
	_install_stress_combat(instance, "specialists")
	_phase_log("stress combat installed")
	await _settle_frames(8)
	if OS.get_environment("LABYRINTH_RUNTIME_PERF_ATTRIBUTION_ONLY") == "1":
		_set_umbra_visual_time(instance, 42.0)
		_set_umbra_shape_batching(instance, false)
		await _settle_render_frames(4)
		_reset_board_render_instrumentation(instance)
		sampler.begin()
		for _frame: int in range(90):
			await _await_render_frame()
		var unbatched_frames: Dictionary = _sampler_phase_result(sampler.finish())
		var unbatched_profile: Dictionary = _board_render_instrumentation(instance)
		await _save_root_screenshot("dense_attribution_unbatched.png")
		var unbatched_attribution: Dictionary = await _measure_draw_call_attribution(instance)
		_set_umbra_shape_batching(instance, true)
		await _settle_render_frames(4)
		_reset_board_render_instrumentation(instance)
		sampler.begin()
		for _frame: int in range(90):
			await _await_render_frame()
		var batched_frames: Dictionary = _sampler_phase_result(sampler.finish())
		var batched_profile: Dictionary = _board_render_instrumentation(instance)
		_expect(int(unbatched_profile.get("umbra_shape_batch_mesh_update_count", -1)) == 0, "disabled Umbra batching must execute the authored immediate-draw reference path")
		_expect(int(batched_profile.get("umbra_shape_batch_mesh_count", 0)) > 0, "batched Umbra rendering must retain pooled meshes")
		_expect(int(batched_profile.get("umbra_shape_batch_mesh_update_count", 0)) > 0, "active Umbra presentation must update its pooled geometry batches")
		_expect(int(batched_profile.get("umbra_shape_batch_mesh_create_count", -1)) == 0, "steady-state Umbra rendering must reuse its warmed mesh pool without allocations")
		await _save_root_screenshot("dense_attribution_batched.png")
		var batched_attribution: Dictionary = await _measure_draw_call_attribution(instance)
		_expect(int(batched_attribution.get("all_visible", 999999)) <= int(unbatched_attribution.get("all_visible", 0)) - 1200, "dense Umbra batching must collapse at least 1,200 completed-frame draw calls")
		var unbatched_layers: Dictionary = unbatched_attribution.get("board_layers", {}) as Dictionary
		var batched_layers: Dictionary = batched_attribution.get("board_layers", {}) as Dictionary
		var unbatched_world: int = int((unbatched_layers.get("world", {}) as Dictionary).get("attributed_draw_calls", 0))
		var batched_world: int = int((batched_layers.get("world", {}) as Dictionary).get("attributed_draw_calls", 999999))
		_expect(batched_world * 10 <= unbatched_world, "Umbra world-layer draw calls must fall by at least 90 percent")
		print("RUNTIME DRAW ATTRIBUTION A/B: %s" % JSON.stringify({
			"unbatched": unbatched_attribution,
			"unbatched_frames": unbatched_frames,
			"unbatched_profile": unbatched_profile,
			"batched": batched_attribution,
			"batched_frames": batched_frames,
			"batched_profile": batched_profile,
		}))
		instance.queue_free()
		sampler.queue_free()
		await process_frame
		ProgressionStore.clear_saved_run()
		quit(0 if _errors.is_empty() else 1)
		return
	var cold_interaction: Dictionary = await _measure_cold_interaction(instance, sampler)
	_install_stress_combat(instance, "specialists")
	await _settle_frames(2)
	for _frame: int in range(WARMUP_FRAMES):
		await _await_render_frame()
	_phase_log("warmup complete")

	var prewarm_remaining_before_startup_idle: int = (instance.get("_action_tracker_prewarm_queue") as Array).size()
	var startup_prewarm_idle: Dictionary = await _measure_idle(sampler)
	var prewarm_remaining_after_startup_idle: int = (instance.get("_action_tracker_prewarm_queue") as Array).size()
	var prewarm_settle_frames: int = await _settle_action_tracker_prewarm(instance)
	var initial_nodes: int = _subtree_node_count(instance)
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var idle: Dictionary = await _measure_idle(sampler)
	await _save_root_screenshot("dense_idle.png")
	await _settle_render_frames(4)
	_phase_log("startup and settled idle complete")
	var preview_matrix: Dictionary = await _measure_preview_matrix(instance)
	_phase_log("preview matrix complete")
	var blink_preview_workload: Dictionary = await _measure_blink_preview_workload(instance, sampler)
	_phase_log("blink preview workload complete")
	var live_save_blink_workload: Dictionary = await _measure_live_save_blink_workload(instance, sampler)
	_phase_log("live save blink workload complete")
	var ranged_trap_hand_regression: Dictionary = await _measure_ranged_trap_hand_regression(instance)
	_phase_log("ranged trap hand regression complete")
	var focused_run: bool = OS.get_environment("LABYRINTH_RUNTIME_PERF_FOCUSED") == "1"
	var focused_actions: bool = OS.get_environment("LABYRINTH_RUNTIME_PERF_FOCUSED_ACTIONS") == "1"
	var focused_interactions: bool = OS.get_environment("LABYRINTH_RUNTIME_PERF_FOCUSED_INTERACTIONS") == "1"
	var composition_matrix: Dictionary = {}
	var interaction_matrix: Dictionary = {}
	var umbra_stage_matrix: Dictionary = {}
	var flurry_scaling: Dictionary = {}
	if not focused_run or focused_interactions:
		interaction_matrix = await _measure_interaction_matrix(instance)
	if not focused_run:
		umbra_stage_matrix = await _measure_umbra_stage_matrix(instance)
		flurry_scaling = await _measure_flurry_scaling(instance)
		composition_matrix = await _measure_composition_matrix(instance)
	_phase_log("composition matrix complete")
	var action_matrix: Dictionary = {}
	var ability_action_matrix: Dictionary = {}
	var enemy_round_matrix: Dictionary = {}
	if not focused_run or focused_actions:
		action_matrix = await _measure_action_matrix(instance, sampler)
		ability_action_matrix = await _measure_ability_action_matrix(instance, sampler)
	if not focused_run:
		enemy_round_matrix = await _measure_enemy_round_matrix(instance, sampler)
	var action_visual_proof: Dictionary = {}
	if not focused_run or focused_actions:
		action_visual_proof = await _capture_wildfire_action_visuals(instance)
	_phase_log("action matrix complete")
	_install_stress_combat(instance, "specialists")
	await _settle_frames(8)
	var final_nodes: int = _subtree_node_count(instance)
	_install_stress_combat(instance, "specialists")
	await _settle_frames(8)
	var repeated_install_nodes: int = _subtree_node_count(instance)
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var board_instrumentation: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var finally_focused: bool = DisplayServer.window_is_focused()
	var card_click_frame_completion: Dictionary = _duration_phase_result(
		preview_matrix.get("card_click_frame_completion_samples", []) as Array[float],
		"interaction_frame_completion"
	)
	var cold_preview_hover_frame_completion: Dictionary = _duration_phase_result(
		preview_matrix.get("cold_hover_frame_completion_samples", []) as Array[float],
		"cold_interaction_frame_completion"
	)
	var preview_hover_frame_completion: Dictionary = _duration_phase_result(
		preview_matrix.get("hover_frame_completion_samples", []) as Array[float],
		"interaction_frame_completion"
	)
	var throttle_samples: Array[Dictionary] = []
	_collect_throttle_samples(idle, "idle", throttle_samples)
	_collect_throttle_samples(cold_interaction, "cold_interaction", throttle_samples)
	_collect_throttle_samples(preview_matrix, "preview_matrix", throttle_samples)
	_collect_throttle_samples(card_click_frame_completion, "card_click_frame_completion", throttle_samples)
	_collect_throttle_samples(cold_preview_hover_frame_completion, "cold_preview_hover_frame_completion", throttle_samples)
	_collect_throttle_samples(preview_hover_frame_completion, "preview_hover_frame_completion", throttle_samples)
	_collect_throttle_samples(blink_preview_workload, "blink_preview_workload", throttle_samples)
	_collect_throttle_samples(live_save_blink_workload, "live_save_blink_workload", throttle_samples)
	_collect_throttle_samples(action_matrix, "action_matrix", throttle_samples)
	_collect_throttle_samples(ability_action_matrix, "ability_action_matrix", throttle_samples)
	_collect_throttle_samples(enemy_round_matrix, "enemy_round_matrix", throttle_samples)
	_expect(repeated_install_nodes <= final_nodes, "repeating the same live fixture install must not grow the settled node tree")
	_expect(final_orphans <= initial_orphans, "live runtime workload must not increase orphan nodes")
	_expect(bool(board_instrumentation.get("split_layers_active", false)), "live RunScene must use retained combat-board layers")
	_expect(finally_focused and _unfocused_observation_count == 0, "native frame proof must remain focused for every observed rendered frame")
	_expect(throttle_samples.is_empty(), "native frame proof must not contain a >=500 ms delivery-throttle signature")

	var results: Dictionary = {
		"schema_version": 3,
		"workload_id": WORKLOAD_ID,
		"viewport": "%dx%d" % [_viewport_size.x, _viewport_size.y],
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"probe_low_processor_usage_mode": OS.low_processor_usage_mode,
		"probe_low_processor_usage_mode_sleep_usec": OS.low_processor_usage_mode_sleep_usec,
		"probe_foreground_window": initially_focused and finally_focused and _unfocused_observation_count == 0,
		"probe_focus_observations": _focus_observation_count,
		"probe_unfocused_observations": _unfocused_observation_count,
		"probe_throttle_threshold_ms": 500.0,
		"probe_throttle_samples": throttle_samples,
		"probe_window_mode": "windowed",
		"probe_render_pulse": true,
		"warmup_frames": WARMUP_FRAMES,
		"depth": 13,
		"hand_card_count": HAND.size(),
		"relic_count": RELICS.size(),
		"skill_count": SKILLS.size(),
		"composition_ids": COMPOSITIONS.duplicate(),
		"idle": idle,
		"cold_interaction": cold_interaction,
		"startup_prewarm_idle": startup_prewarm_idle,
		"prewarm_remaining_before_startup_idle": prewarm_remaining_before_startup_idle,
		"prewarm_remaining_after_startup_idle": prewarm_remaining_after_startup_idle,
		"prewarm_settle_frames": prewarm_settle_frames,
		"card_click_handler": _duration_phase_result(preview_matrix.get("card_click_handler_samples", []) as Array[float], "input_handler"),
		"card_click_frame_completion": card_click_frame_completion,
		"cold_preview_hover_handler": _duration_phase_result(preview_matrix.get("cold_hover_handler_samples", []) as Array[float], "input_handler"),
		"cold_preview_hover_frame_completion": cold_preview_hover_frame_completion,
		"cold_preview_canvas_pipeline_compilations": int(preview_matrix.get("cold_canvas_pipeline_compilations", 0)),
		"preview_hover_handler": _duration_phase_result(preview_matrix.get("hover_handler_samples", []) as Array[float], "input_handler"),
		"preview_hover_frame_completion": preview_hover_frame_completion,
		"warm_preview_canvas_pipeline_compilations": int(preview_matrix.get("warm_canvas_pipeline_compilations", 0)),
		"target_step_completion": _combined_target_step_completion_phase(action_matrix),
		"action_completion": _combined_action_completion_phase(action_matrix),
		"preview_matrix": preview_matrix.get("cards", {}),
		"blink_preview_workload": blink_preview_workload,
		"live_save_blink_workload": live_save_blink_workload,
		"ranged_trap_hand_regression": ranged_trap_hand_regression,
		"composition_matrix": composition_matrix,
		"interaction_matrix": interaction_matrix,
		"umbra_stage_matrix": umbra_stage_matrix,
		"flurry_scaling": flurry_scaling,
		"action_play": _combined_action_phase(action_matrix),
		"action_matrix": action_matrix,
		"action_visual_proof": action_visual_proof,
		"ability_action_matrix": ability_action_matrix,
		"enemy_round_matrix": enemy_round_matrix,
		"initial_nodes": initial_nodes,
		"final_nodes": final_nodes,
		"repeated_install_nodes": repeated_install_nodes,
		"initial_orphan_nodes": initial_orphans,
		"final_objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"final_orphan_nodes": final_orphans,
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"board_instrumentation": board_instrumentation,
		"semantic_errors": _errors,
	}
	if _errors.is_empty():
		print("RUNTIME FRAME PERF RESULT: %s" % JSON.stringify(results))
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		push_error("RUNTIME FRAME PERF RESULT: FAIL %s" % JSON.stringify(results))
	instance.queue_free()
	sampler.queue_free()
	await process_frame
	ProgressionStore.clear_saved_run()
	quit(0 if _errors.is_empty() else 1)

func _measure_idle(sampler: FrameSampler) -> Dictionary:
	sampler.begin()
	for _frame: int in range(IDLE_FRAMES):
		await _await_render_frame()
	return _sampler_phase_result(sampler.finish())

func _measure_draw_call_attribution(instance: Node) -> Dictionary:
	# Toggle one already-rendered surface at a time and let the renderer settle.
	# This attributes steady-state draw calls without rebuilding the authored
	# fixture or changing the order/depth of any retained gameplay layer.
	var result: Dictionary = {}
	await _settle_render_frames(3)
	result["all_visible"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var surfaces: Dictionary = {
		"board": instance.get_node_or_null("BoardUnderlay/CombatBoard"),
		"hand_box": instance.get("hand_box"),
		"hand_row": instance.get("hand_row"),
		"relic_bar": instance.get("relic_bar"),
		"turn_order": instance.get("_turn_order_panel"),
		"top_bar": instance.get_node_or_null("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar"),
		"left_action_stack": instance.get("left_action_stack"),
	}
	for surface_name: String in surfaces:
		var surface: CanvasItem = surfaces.get(surface_name, null) as CanvasItem
		if surface == null or not surface.visible:
			continue
		surface.visible = false
		await _settle_render_frames(3)
		var hidden_draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		result[surface_name] = {
			"hidden_draw_calls": hidden_draw_calls,
			"attributed_draw_calls": maxi(0, int(result["all_visible"]) - hidden_draw_calls),
		}
		surface.visible = true
		await _settle_render_frames(3)
	var board: Control = surfaces.get("board", null) as Control
	if board != null and board.has_method("_retained_render_layers"):
		var board_layers: Dictionary = {}
		var retained_layers: Array = board.call("_retained_render_layers") as Array
		var board_visible_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		for layer_kind: String in ["ambient", "overlays", "ground", "path", "world", "scene_tile", "foreground", "hud", "effects"]:
			var matching_layers: Array[CanvasItem]
			for layer_var: Variant in retained_layers:
				var layer: CanvasItem = layer_var as CanvasItem
				if layer != null and str(layer.get("_render_layer_kind")) == layer_kind:
					matching_layers.append(layer)
			for layer: CanvasItem in matching_layers:
				layer.visible = false
			await _settle_render_frames(3)
			var hidden_draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			board_layers[layer_kind] = {
				"hidden_draw_calls": hidden_draw_calls,
				"attributed_draw_calls": maxi(0, board_visible_calls - hidden_draw_calls),
				"layer_count": matching_layers.size(),
			}
			for layer: CanvasItem in matching_layers:
				layer.visible = true
			await _settle_render_frames(3)
		result["board_layers"] = board_layers
	return result

func _set_umbra_shape_batching(instance: Node, enabled: bool) -> void:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null:
		return
	board.set("_umbra_shape_batch_enabled", enabled)
	board.queue_redraw()
	if board.has_method("_retained_render_layers"):
		for layer_var: Variant in board.call("_retained_render_layers") as Array:
			var layer: Control = layer_var as Control
			if layer == null:
				continue
			layer.set("_umbra_shape_batch_enabled", enabled)
			layer.queue_redraw()

func _set_umbra_visual_time(instance: Node, time_seconds: float) -> void:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null:
		return
	var render_sources: Array[Control]
	render_sources.append(board)
	if board.has_method("_retained_render_layers"):
		for layer_var: Variant in board.call("_retained_render_layers") as Array:
			var layer: Control = layer_var as Control
			if layer != null:
				render_sources.append(layer)
	for source: Control in render_sources:
		var source_presentation: Dictionary = (source.get("presentation") as Dictionary).duplicate(true)
		source_presentation["umbra_time_seconds"] = time_seconds
		source.set("presentation", source_presentation)
		source.queue_redraw()

func _reset_board_render_instrumentation(instance: Node) -> void:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board != null and board.has_method("reset_render_instrumentation"):
		board.call("reset_render_instrumentation")

func _board_render_instrumentation(instance: Node) -> Dictionary:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null or not board.has_method("render_instrumentation_snapshot"):
		return {}
	return board.call("render_instrumentation_snapshot") as Dictionary

func _measure_cold_interaction(instance: Node, sampler: FrameSampler) -> Dictionary:
	# Run before the explicit warmup and action-tracker prewarm settle. This is the
	# first real routed card interaction a player can perform in the dense fixture.
	var hand_index: int = _hand_index(instance, "shadow_step")
	_expect(hand_index >= 0, "cold interaction workload requires Shadow Step in hand")
	if hand_index < 0:
		return {}
	var prewarm_remaining_before: int = (instance.get("_action_tracker_prewarm_queue") as Array).size()
	sampler.begin()
	var card_click_handler_ms: float = await _select_card(instance, hand_index)
	await _await_render_frame()
	var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
	_expect(not targets.is_empty(), "cold interaction workload must expose a live hover target")
	var hover_handler_ms: float = 0.0
	if not targets.is_empty():
		var hover_started: int = Time.get_ticks_usec()
		_board_pointer_hover(instance, _preferred_target(instance, targets))
		hover_handler_ms = float(Time.get_ticks_usec() - hover_started) / 1000.0
		await _await_render_frame()
	var sampled: Dictionary = sampler.finish()
	instance.call("_cancel_card_selection")
	await _await_render_frame()
	var card_click_samples: Array[float]
	card_click_samples.append(card_click_handler_ms)
	var preview_hover_samples: Array[float]
	preview_hover_samples.append(hover_handler_ms)
	return {
		"prewarm_remaining_before": prewarm_remaining_before,
		"prewarm_remaining_after": (instance.get("_action_tracker_prewarm_queue") as Array).size(),
		"card_click_handler": _duration_phase_result(card_click_samples, "input_handler"),
		"preview_hover_handler": _duration_phase_result(preview_hover_samples, "input_handler"),
		"rendered_frames": _sampler_phase_result(sampled),
		"target_count": targets.size(),
	}

func _settle_action_tracker_prewarm(instance: Node) -> int:
	var waited_frames: int = 0
	while (
		bool(instance.get("_action_tracker_prewarm_scheduled"))
		or not (instance.get("_action_tracker_prewarm_queue") as Array).is_empty()
	) and waited_frames < 2000:
		await _await_render_frame()
		waited_frames += 1
	_expect(waited_frames < 2000, "action-tracker prewarm must finish within a bounded frame budget")
	await _settle_frames(2)
	return waited_frames

func _measure_preview_matrix(instance: Node) -> Dictionary:
	var all_card_click_handler_samples: Array[float] = []
	var all_card_click_frame_completion_samples: Array[float]
	var all_cold_hover_handler_samples: Array[float]
	var all_cold_hover_frame_completion_samples: Array[float]
	var all_hover_handler_samples: Array[float] = []
	var all_hover_frame_completion_samples: Array[float]
	var cold_canvas_pipeline_compilations: int = 0
	var warm_canvas_pipeline_compilations: int = 0
	var cards: Dictionary = {}
	for card_id: String in _benchmark_card_ids():
		_phase_log("preview %s" % card_id)
		_install_stress_combat(instance, "specialists")
		await _settle_frames(4)
		var hand_index: int = _hand_index(instance, card_id)
		_expect(hand_index >= 0, "%s must exist in the live benchmark hand" % card_id)
		if hand_index < 0:
			continue
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		var card_click_pipelines_before: int = _canvas_pipeline_compilation_count()
		var click_started: int = Time.get_ticks_usec()
		var click_handler_ms: float = await _select_card(instance, hand_index)
		await _await_render_frame()
		var click_frame_completion_ms: float = float(Time.get_ticks_usec() - click_started) / 1000.0
		var card_click_pipeline_compilations: int = _canvas_pipeline_compilation_count() - card_click_pipelines_before
		var click_stage_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		all_card_click_handler_samples.append(click_handler_ms)
		all_card_click_frame_completion_samples.append(click_frame_completion_ms)
		var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
		board.call("reset_render_instrumentation")
		var cold_result: Dictionary = await _measure_current_preview_hovers(instance)
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		board.call("reset_render_instrumentation")
		var card_result: Dictionary = await _measure_current_preview_hovers(instance)
		card_result["stage_profile"] = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		var board_profile: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
		card_result["board_profile"] = board_profile
		var hover_handler_samples: Array[float] = card_result.get("hover_handler_samples", []) as Array[float]
		var hover_frame_completion_samples: Array[float] = card_result.get("hover_frame_completion_samples", []) as Array[float]
		var cold_hover_handler_samples: Array[float] = cold_result.get("hover_handler_samples", []) as Array[float]
		var cold_hover_frame_completion_samples: Array[float] = cold_result.get("hover_frame_completion_samples", []) as Array[float]
		cold_canvas_pipeline_compilations += int(cold_result.get("canvas_pipeline_compilations", 0))
		warm_canvas_pipeline_compilations += int(card_result.get("canvas_pipeline_compilations", 0))
		all_cold_hover_handler_samples.append_array(cold_hover_handler_samples)
		all_cold_hover_frame_completion_samples.append_array(cold_hover_frame_completion_samples)
		all_hover_handler_samples.append_array(hover_handler_samples)
		all_hover_frame_completion_samples.append_array(hover_frame_completion_samples)
		card_result["card_click_handler_ms"] = click_handler_ms
		card_result["card_click_frame_completion_ms"] = click_frame_completion_ms
		card_result["card_click_canvas_pipeline_compilations"] = card_click_pipeline_compilations
		card_result["card_click_stage_profile"] = click_stage_profile
		card_result["cold_hover_handler"] = _duration_phase_result(cold_hover_handler_samples, "input_handler")
		card_result["cold_hover_frame_completion"] = _duration_phase_result(cold_hover_frame_completion_samples, "cold_interaction_frame_completion")
		card_result["cold_canvas_pipeline_compilations"] = int(cold_result.get("canvas_pipeline_compilations", 0))
		card_result["hover_handler"] = _duration_phase_result(hover_handler_samples, "input_handler")
		card_result["hover_frame_completion"] = _duration_phase_result(hover_frame_completion_samples, "interaction_frame_completion")
		card_result["warm_canvas_pipeline_compilations"] = int(card_result.get("canvas_pipeline_compilations", 0))
		if int(card_result.get("total_target_count", 0)) > 0:
			_expect(int(board_profile.get("dynamic_draw_count", 0)) > 0, "%s preview target sweeps must execute retained-layer redraws" % card_id)
		card_result.erase("hover_handler_samples")
		card_result.erase("hover_frame_completion_samples")
		card_result.erase("canvas_pipeline_compilation_deltas")
		cards[card_id] = card_result
		_phase_log("preview %s result %s" % [card_id, JSON.stringify({
			"hover": card_result.get("hover_handler", {}),
			"stage_profile": card_result.get("stage_profile", {}),
			"board_profile": card_result.get("board_profile", {}),
		})])
		# GPU readback and PNG encoding are synchronous proof work. Capture only after
		# every timed cold/warm sample so Metal completion cannot contaminate the next
		# interaction distribution.
		if card_id in ["threaded_path", "wildfire_halo", "gust_step", "thunderline"]:
			var capture_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
			var capture_targets: Array[Vector2i] = _preview_interaction_tiles(instance, capture_preview)
			if not capture_targets.is_empty():
				_board_pointer_hover(instance, _preferred_target(instance, capture_targets))
				await _await_render_frame()
				await _save_root_screenshot("%s_preview.png" % card_id)
				await _settle_render_frames(4)
		instance.call("_cancel_card_selection")
		await _await_render_frame()
	return {
		"card_click_handler_samples": all_card_click_handler_samples,
		"card_click_frame_completion_samples": all_card_click_frame_completion_samples,
		"cold_hover_handler_samples": all_cold_hover_handler_samples,
		"cold_hover_frame_completion_samples": all_cold_hover_frame_completion_samples,
		"cold_canvas_pipeline_compilations": cold_canvas_pipeline_compilations,
		"hover_handler_samples": all_hover_handler_samples,
		"hover_frame_completion_samples": all_hover_frame_completion_samples,
		"warm_canvas_pipeline_compilations": warm_canvas_pipeline_compilations,
		"cards": cards,
	}

func _measure_current_preview_hovers(instance: Node) -> Dictionary:
	var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
	_validate_prevalidated_action_equivalence(preview)
	_validate_pass_preview_progression_equivalence(instance, preview, targets)
	var hover_handler_samples: Array[float] = []
	var hover_frame_completion_samples: Array[float]
	var canvas_pipeline_compilation_deltas: Array[int]
	for target: Vector2i in targets:
		var pipelines_before: int = _canvas_pipeline_compilation_count()
		var hover_started: int = Time.get_ticks_usec()
		_board_pointer_hover(instance, target)
		hover_handler_samples.append(float(Time.get_ticks_usec() - hover_started) / 1000.0)
		# A queued CanvasItem redraw does not execute during RenderingServer.force_draw.
		# Cross a real post-draw boundary so this covers the same retained-layer work
		# and frame completion that the player sees after every target hover.
		await _await_render_frame()
		hover_frame_completion_samples.append(float(Time.get_ticks_usec() - hover_started) / 1000.0)
		canvas_pipeline_compilation_deltas.append(_canvas_pipeline_compilation_count() - pipelines_before)
	return {
		"hover_handler_samples": hover_handler_samples,
		"hover_frame_completion_samples": hover_frame_completion_samples,
		"canvas_pipeline_compilation_deltas": canvas_pipeline_compilation_deltas,
		"canvas_pipeline_compilations": _int_array_sum(canvas_pipeline_compilation_deltas),
		"step_count": 1 if not preview.is_empty() else 0,
		"total_target_count": targets.size(),
		"max_target_count": targets.size(),
	}

func _canvas_pipeline_compilation_count() -> int:
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS))

func _int_array_sum(values: Array[int]) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total

func _measure_blink_preview_workload(instance: Node, sampler: FrameSampler) -> Dictionary:
	_install_stress_combat(instance, "specialists")
	await _settle_frames(4)
	var hand_index: int = _hand_index(instance, "shadow_step")
	_expect(hand_index >= 0, "dense Blink workload requires Shadow Step in hand")
	if hand_index < 0:
		return {}
	await _select_card(instance, hand_index)
	await _await_render_frame()
	var initial_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	_expect(str((initial_preview.get("action", {}) as Dictionary).get("type", "")) == "blink", "Shadow Step must begin on its authored Blink target step")
	var initial_targets: Array[Vector2i] = _preview_interaction_tiles(instance, initial_preview)
	if initial_targets.is_empty():
		_expect(false, "Shadow Step Blink must expose at least one live target")
		return {}
	return await _measure_active_blink_preview(instance, sampler, {
		"source": "synthetic_dense",
		"card_id": "shadow_step",
		"prior_target_steps": 0,
	})

func _measure_live_save_blink_workload(instance: Node, sampler: FrameSampler) -> Dictionary:
	var source_path: String = OS.get_environment("LABYRINTH_RUNTIME_PERF_LIVE_SAVE_PATH").strip_edges()
	if source_path.is_empty():
		return {"available": false, "reason": "LABYRINTH_RUNTIME_PERF_LIVE_SAVE_PATH not set"}
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return {"available": false, "reason": "save could not be opened", "path": source_path}
	var loaded_var: Variant = source_file.get_var(false)
	source_file.close()
	if typeof(loaded_var) != TYPE_DICTIONARY:
		return {"available": false, "reason": "save root is not a Dictionary", "path": source_path}
	var loaded_run: Dictionary = (loaded_var as Dictionary).duplicate(true)
	instance.call("_load_run_state", loaded_run)
	await _settle_frames(8)
	var state: Dictionary = instance.get("_combat_state") as Dictionary
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	var deck: Dictionary = state.get("deck", {}) as Dictionary
	var metadata: Dictionary = {
		"available": true,
		"path": source_path,
		"depth": int(run_state.get("depth", -1)),
		"mode": str(run_state.get("mode", "")),
		"hand_count": (deck.get("hand", []) as Array).size(),
		"enemy_count": (state.get("enemies", []) as Array).size(),
		"illusion_count": (state.get("illusions", []) as Array).size(),
		"trap_count": (state.get("traps", []) as Array).size(),
		"terrain_count": (state.get("terrain", []) as Array).size(),
		"loot_count": (state.get("loot", []) as Array).size(),
		"relic_count": (state.get("relics", run_state.get("relics", [])) as Array).size(),
		"skill_count": (state.get("skill_ids", run_state.get("skill_ids", [])) as Array).size(),
	}
	if str(run_state.get("mode", "")) != "combat" or state.is_empty():
		metadata["measured"] = false
		metadata["reason"] = "save is not currently in combat"
		return metadata
	var blink_selection: Dictionary = await _select_live_save_blink_preview(instance)
	metadata.merge(blink_selection, true)
	if not bool(blink_selection.get("selected", false)):
		metadata["measured"] = false
		return metadata
	var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var guard_steps: int = 0
	while not preview.is_empty() and str((preview.get("action", {}) as Dictionary).get("type", "")) != "blink" and guard_steps < MAX_PREVIEW_STEPS:
		var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
		if targets.is_empty():
			metadata["measured"] = false
			metadata["reason"] = "pre-Blink target step had no accepted live target"
			return metadata
		_board_pointer_click(instance, _preferred_target(instance, targets))
		await _await_render_frame()
		preview = instance.call("_active_card_preview") as Dictionary
		guard_steps += 1
	if preview.is_empty() or str((preview.get("action", {}) as Dictionary).get("type", "")) != "blink":
		metadata["measured"] = false
		metadata["reason"] = "selected mode did not reach a Blink target step"
		return metadata
	var measured: Dictionary = await _measure_active_blink_preview(instance, sampler, {
		"source": "live_save",
		"prior_target_steps": guard_steps,
	})
	metadata.merge(measured, true)
	metadata["measured"] = true
	return metadata

func _select_live_save_blink_preview(instance: Node) -> Dictionary:
	var state: Dictionary = instance.get("_combat_state") as Dictionary
	var hand: Array = ((state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	for hand_index: int in range(hand.size()):
		var card_id: String = str(hand[hand_index])
		var actions: Array = _combat.card_play_actions(card_id, state)
		var contains_blink: bool = false
		for action_var: Variant in actions:
			if typeof(action_var) == TYPE_DICTIONARY and str((action_var as Dictionary).get("type", "")) == "blink":
				contains_blink = true
				break
		if not contains_blink:
			continue
		await _select_card(instance, hand_index)
		return {"selected": true, "card_id": card_id, "play_kind": "play"}
	for hand_index: int in range(hand.size()):
		var options: Dictionary = instance.call("_card_play_options_for_index", hand_index) as Dictionary
		if not bool(options.get("blink_playable", false)):
			continue
		await _select_card(instance, hand_index, "blink")
		if int(instance.get("_selected_card_index")) == hand_index:
			return {"selected": true, "card_id": str(hand[hand_index]), "play_kind": "blink"}
	return {"selected": false, "reason": "no playable printed or fallback Blink was found in the current hand"}

func _measure_active_blink_preview(instance: Node, sampler: FrameSampler, context: Dictionary) -> Dictionary:
	var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var action: Dictionary = preview.get("action", {}) as Dictionary
	_expect(str(action.get("type", "")) == "blink", "Blink workload must measure the actual Blink target step")
	var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
	_expect(not targets.is_empty(), "Blink workload must expose at least one accepted destination")
	if targets.is_empty():
		return context
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	instance.call("set_runtime_performance_instrumentation_enabled", true)
	board.call("set_submission_performance_instrumentation_enabled", true)
	board.call("reset_render_instrumentation")
	var cold_handler_samples: Array[float] = []
	var cold_frame_completion_samples: Array[float]
	for target: Vector2i in targets:
		var handler_started: int = Time.get_ticks_usec()
		_board_pointer_hover(instance, target)
		cold_handler_samples.append(float(Time.get_ticks_usec() - handler_started) / 1000.0)
		await _await_render_frame()
		cold_frame_completion_samples.append(float(Time.get_ticks_usec() - handler_started) / 1000.0)
	var warm_handler_samples: Array[float] = []
	var warm_frame_completion_samples: Array[float]
	for reverse_index: int in range(targets.size() - 1, -1, -1):
		var target: Vector2i = targets[reverse_index]
		var handler_started: int = Time.get_ticks_usec()
		_board_pointer_hover(instance, target)
		warm_handler_samples.append(float(Time.get_ticks_usec() - handler_started) / 1000.0)
		await _await_render_frame()
		warm_frame_completion_samples.append(float(Time.get_ticks_usec() - handler_started) / 1000.0)
	var steady_target: Vector2i = _preferred_target(instance, targets)
	_board_pointer_hover(instance, steady_target)
	await _await_render_frame()
	sampler.begin()
	for _frame: int in range(BLINK_PREVIEW_STEADY_FRAMES):
		await _await_render_frame()
	var steady_sample: Dictionary = _sampler_phase_result(sampler.finish())
	var sweep_handler_samples: Array[float] = []
	sampler.begin()
	for frame_index: int in range(BLINK_PREVIEW_SWEEP_FRAMES):
		var target: Vector2i = targets[frame_index % targets.size()]
		var handler_started: int = Time.get_ticks_usec()
		_board_pointer_hover(instance, target)
		sweep_handler_samples.append(float(Time.get_ticks_usec() - handler_started) / 1000.0)
		await _await_render_frame()
	var sweep_sample: Dictionary = _sampler_phase_result(sampler.finish())
	await _save_root_screenshot("blink_preview_%s.png" % str(context.get("source", "workload")))
	await _settle_render_frames(4)
	var result: Dictionary = context.duplicate(true)
	result.merge({
		"target_count": targets.size(),
		"range": int(action.get("range", 0)),
		"cold_hover_handler": _duration_phase_result(cold_handler_samples, "input_handler"),
		"cold_hover_frame_completion": _duration_phase_result(cold_frame_completion_samples, "interaction_frame_completion"),
		"warm_hover_handler": _duration_phase_result(warm_handler_samples, "input_handler"),
		"warm_hover_frame_completion": _duration_phase_result(warm_frame_completion_samples, "interaction_frame_completion"),
		"steady_preview_frames": steady_sample,
		"target_sweep_frames": sweep_sample,
		"target_sweep_handler": _duration_phase_result(sweep_handler_samples, "input_handler"),
		"stage_profile": instance.call("runtime_performance_instrumentation_snapshot") as Dictionary,
		"board_submission_profile": board.call("submission_performance_instrumentation_snapshot") as Dictionary,
		"board_profile": board.call("render_instrumentation_snapshot") as Dictionary,
	}, true)
	board.call("set_submission_performance_instrumentation_enabled", false)
	instance.call("set_runtime_performance_instrumentation_enabled", false)
	return result

func _measure_interaction_matrix(instance: Node) -> Dictionary:
	_phase_log("interaction matrix")
	_install_stress_combat(instance, "specialists")
	await _settle_frames(3)
	var results: Dictionary = {}
	var details: Dictionary = {}
	var samples: Array[float] = []
	for index: int in range(HAND.size()):
		var card_id: String = HAND[index]
		var card_enter_ms: float = _timed_call(instance, "_on_card_hover_started", [index])
		samples.append(card_enter_ms)
		RenderingServer.force_draw(false)
		var card_exit_ms: float = _timed_call(instance, "_on_card_hover_ended", [index])
		samples.append(card_exit_ms)
		details["card_hover:%s" % card_id] = {"enter_ms": card_enter_ms, "exit_ms": card_exit_ms}
	results["card_hover_enter_exit"] = _duration_phase_result(samples, "input_handler")

	samples.clear()
	for y: int in range(1, 8):
		for x: int in range(1, 8):
			var hover_started: int = Time.get_ticks_usec()
			_board_pointer_hover(instance, Vector2i(x, y))
			samples.append(float(Time.get_ticks_usec() - hover_started) / 1000.0)
	results["board_hover_no_card"] = _duration_phase_result(samples, "input_handler")

	samples.clear()
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var enemies: Array = combat_state.get("enemies", []) as Array
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	for enemy_index: int in range(enemies.size()):
		var enemy_var: Variant = enemies[enemy_index]
		var enemy: Dictionary = enemy_var as Dictionary
		var tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var actor_key: String = "enemy:%d" % int(enemy.get("id", -1))
		var threat_started: int = Time.get_ticks_usec()
		_combat.enemy_threat_tiles(combat_state, enemy_index)
		var threat_ms: float = float(Time.get_ticks_usec() - threat_started) / 1000.0
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		board.call("set_submission_performance_instrumentation_enabled", true)
		var enemy_enter_ms: float = _timed_call(instance, "_on_turn_order_enemy_hovered", [tile, actor_key])
		var stage_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		var submission_profile: Dictionary = board.call("submission_performance_instrumentation_snapshot") as Dictionary
		instance.call("set_runtime_performance_instrumentation_enabled", false)
		board.call("set_submission_performance_instrumentation_enabled", false)
		var enemy_exit_ms: float = _timed_call(instance, "_on_turn_order_enemy_unhovered", [tile, actor_key])
		samples.append(enemy_enter_ms)
		samples.append(enemy_exit_ms)
		details["enemy_hover:%s" % str(enemy.get("type", "unknown"))] = {
			"threat_compute_ms": threat_ms,
			"enter_ms": enemy_enter_ms,
			"exit_ms": enemy_exit_ms,
			"stage_profile": stage_profile,
			"submission_profile": submission_profile,
		}
	results["turn_order_enemy_hover"] = _duration_phase_result(samples, "input_handler")

	samples.clear()
	for zoom: float in [0.82, 1.18, 0.95, 1.08, 1.0]:
		samples.append(_timed_call(board, "set_navigation_zoom", [zoom, board.size * 0.5]))
	for pan: Vector2 in [Vector2(-120, -60), Vector2(120, 60), Vector2(-80, 90), Vector2.ZERO]:
		samples.append(_timed_call(board, "set_navigation_pan", [pan, true]))
	results["board_zoom_pan"] = _duration_phase_result(samples, "synchronous_ui_operation")

	samples.clear()
	var drag_index: int = _hand_index(instance, "gust_step")
	samples.append(_timed_call(instance, "_on_card_drag_started", [drag_index]))
	for zone: String in ["play", ""]:
		samples.append(_timed_call(instance, "_update_drag_overlay_hover", [zone]))
	samples.append(_timed_call(instance, "_cancel_drag_play"))
	results["card_drag_play_zone_cancel"] = _duration_phase_result(samples, "input_handler")

	samples.clear()
	for pile_kind: String in ["draw", "discard", "burn"]:
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		var pile_open_ms: float = _timed_call(instance, "_open_pile_view", [pile_kind])
		var pile_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		instance.call("set_runtime_performance_instrumentation_enabled", false)
		samples.append(pile_open_ms)
		# Let the native renderer consume the opened pooled-card hierarchy through
		# the normal frame boundary. A synchronous force_draw can race freed pooled
		# meshes and report renderer errors that gameplay never triggers.
		await _await_render_frame()
		var pile_close_ms: float = _timed_call(instance, "_close_pile_view")
		samples.append(pile_close_ms)
		await process_frame
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		var pile_reopen_ms: float = _timed_call(instance, "_open_pile_view", [pile_kind])
		var pile_reopen_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		instance.call("set_runtime_performance_instrumentation_enabled", false)
		samples.append(pile_reopen_ms)
		var pile_reclose_ms: float = _timed_call(instance, "_close_pile_view")
		samples.append(pile_reclose_ms)
		await process_frame
		details["pile:%s" % pile_kind] = {
			"open_ms": pile_open_ms,
			"close_ms": pile_close_ms,
			"reopen_ms": pile_reopen_ms,
			"reclose_ms": pile_reclose_ms,
			"profile": pile_profile,
			"reopen_profile": pile_reopen_profile,
		}
	results["pile_open_close"] = _duration_phase_result(samples, "synchronous_ui_operation")
	_verify_pile_card_definition_invalidation(instance)

	samples.clear()
	samples.append(_timed_call(instance, "_open_menu_overlay"))
	samples.append(_timed_call(instance, "_open_settings_overlay"))
	samples.append(_timed_call(instance, "_close_settings_overlay"))
	samples.append(_timed_call(instance, "_close_menu_overlay"))
	results["menu_settings_open_close"] = _duration_phase_result(samples, "synchronous_ui_operation")

	samples.clear()
	samples.append(_timed_call(instance, "_open_grimoire_overlay"))
	samples.append(_timed_call(instance, "_on_grimoire_search_text_changed", ["fire move enemy relic"] ))
	samples.append(_timed_call(instance, "_on_grimoire_section_pressed", ["combat"]))
	samples.append(_timed_call(instance, "_close_grimoire_overlay"))
	results["grimoire_open_search_section_close"] = _duration_phase_result(samples, "synchronous_ui_operation")

	samples.clear()
	for mode: String in ["equipment", "magic", "skills"]:
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		var character_open_ms: float = _timed_call(instance, "_open_character_overlay", [mode])
		var character_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		instance.call("set_runtime_performance_instrumentation_enabled", false)
		var skill_tree_profile: Dictionary = {}
		var skill_tree_var: Variant = instance.get("_skill_tree_view")
		if mode == "skills" and typeof(skill_tree_var) == TYPE_OBJECT and is_instance_valid(skill_tree_var):
			skill_tree_profile = (skill_tree_var as Object).call("performance_metrics") as Dictionary
		samples.append(character_open_ms)
		RenderingServer.force_draw(false)
		var character_close_ms: float = _timed_call(instance, "_close_card_upgrade_overlay")
		samples.append(character_close_ms)
		await process_frame
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		var character_reopen_ms: float = _timed_call(instance, "_open_character_overlay", [mode])
		var character_reopen_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
		instance.call("set_runtime_performance_instrumentation_enabled", false)
		samples.append(character_reopen_ms)
		var character_reclose_ms: float = _timed_call(instance, "_close_card_upgrade_overlay")
		samples.append(character_reclose_ms)
		await process_frame
		details["character:%s" % mode] = {
			"open_ms": character_open_ms,
			"close_ms": character_close_ms,
			"reopen_ms": character_reopen_ms,
			"reclose_ms": character_reclose_ms,
			"profile": character_profile,
			"reopen_profile": character_reopen_profile,
			"skill_tree_profile": skill_tree_profile,
		}
	results["character_overlay_modes"] = _duration_phase_result(samples, "synchronous_ui_operation")

	# The compact ABILITIES sigil is its own dense interaction surface and can
	# rebuild a multi-page palette independently of the full character screen.
	samples.clear()
	instance.call("_close_skill_status_popover", false)
	var ability_open_ms: float = _timed_call(instance, "_toggle_skill_status_popover")
	samples.append(ability_open_ms)
	RenderingServer.force_draw(false)
	var ability_select_samples: Array[float] = []
	instance.call("set_runtime_performance_instrumentation_enabled", true)
	for skill_id: String in SKILLS:
		ability_select_samples.append(_timed_call(instance, "_select_skill_status_skill", [skill_id]))
		samples.append(ability_select_samples[ability_select_samples.size() - 1])
	var ability_select_profile: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
	instance.call("set_runtime_performance_instrumentation_enabled", false)
	var ability_next_page_ms: float = _timed_call(instance, "_on_skill_status_page_pressed", [1])
	var ability_previous_page_ms: float = _timed_call(instance, "_on_skill_status_page_pressed", [-1])
	samples.append(ability_next_page_ms)
	samples.append(ability_previous_page_ms)
	var ability_close_ms: float = _timed_call(instance, "_close_skill_status_popover")
	samples.append(ability_close_ms)
	await process_frame
	var ability_reopen_ms: float = _timed_call(instance, "_toggle_skill_status_popover")
	samples.append(ability_reopen_ms)
	RenderingServer.force_draw(false)
	var ability_reclose_ms: float = _timed_call(instance, "_close_skill_status_popover")
	samples.append(ability_reclose_ms)
	results["ability_palette_open_select_page_close"] = _duration_phase_result(samples, "synchronous_ui_operation")
	details["ability_palette"] = {
		"open_ms": ability_open_ms,
		"select": _duration_phase_result(ability_select_samples, "synchronous_ui_operation"),
		"select_profile": ability_select_profile,
		"next_page_ms": ability_next_page_ms,
		"previous_page_ms": ability_previous_page_ms,
		"close_ms": ability_close_ms,
		"reopen_ms": ability_reopen_ms,
		"reclose_ms": ability_reclose_ms,
	}

	# Native tooltip creation is delayed by Godot, so synthesize the actual build
	# for every owned relic instead of assuming a populated bar is enough proof.
	samples.clear()
	var relic_tooltip_details: Dictionary = {}
	var sampled_relic_ids: Array[String]
	var relic_icon_grid_var: Variant = instance.get("_relic_icon_grid")
	if typeof(relic_icon_grid_var) == TYPE_OBJECT and is_instance_valid(relic_icon_grid_var):
		for child: Node in (relic_icon_grid_var as Node).get_children():
			if not child.has_meta("relic_id") or not child.has_method("_make_custom_tooltip"):
				continue
			var relic_id: String = str(child.get_meta("relic_id", ""))
			sampled_relic_ids.append(relic_id)
			var tooltip_text: String = str((child as Control).tooltip_text) if child is Control else ""
			var tooltip_started: int = Time.get_ticks_usec()
			var tooltip_var: Variant = child.call("_make_custom_tooltip", tooltip_text)
			var tooltip_ms: float = float(Time.get_ticks_usec() - tooltip_started) / 1000.0
			samples.append(tooltip_ms)
			relic_tooltip_details[relic_id] = tooltip_ms
			if typeof(tooltip_var) == TYPE_OBJECT and is_instance_valid(tooltip_var):
				(tooltip_var as Object).free()
	var expected_relic_ids: Array[String]
	for relic_id: String in RELICS:
		expected_relic_ids.append(relic_id)
	sampled_relic_ids.sort()
	expected_relic_ids.sort()
	_expect(samples.size() == RELICS.size(), "relic tooltip workload must sample every authored relic")
	_expect(sampled_relic_ids == expected_relic_ids, "relic tooltip workload must sample the authored relic ids")
	results["relic_tooltip_build"] = _duration_phase_result(samples, "synchronous_ui_operation")
	details["relic_tooltips"] = relic_tooltip_details
	results["details"] = details
	return results

func _verify_pile_card_definition_invalidation(instance: Node) -> void:
	var original_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var original_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	instance.call("_open_pile_view", "discard")
	var original_entry: Dictionary = {}
	for entry_var: Variant in instance.get("_pile_dialog_card_pool") as Array:
		var entry: Dictionary = entry_var as Dictionary
		var button: Button = entry.get("button", null) as Button
		if str(entry.get("card_id", "")) == "shadow_step" and button != null and button.visible:
			original_entry = entry
			break
	_expect(not original_entry.is_empty(), "pile invalidation workload requires a visible pooled Shadow Step")
	if original_entry.is_empty():
		instance.call("_close_pile_view")
		return
	var original_widget: Control = original_entry.get("widget", null) as Control
	var original_definition_hash: int = hash(original_widget.get("_card_override"))
	instance.call("_close_pile_view")

	var modified_state: Dictionary = original_state.duplicate(true)
	var relics: Array = (modified_state.get("relics", []) as Array).duplicate()
	relics.erase("pilgrim_boots")
	modified_state["relics"] = relics
	instance.set("_combat_state", modified_state)
	var modified_run_state: Dictionary = original_run_state.duplicate(true)
	modified_run_state["combat_state"] = modified_state
	modified_run_state["relics"] = relics.duplicate()
	instance.set("_run_state", modified_run_state)
	instance.call("_open_pile_view", "discard")
	var expected_definition: Dictionary = instance.call("_card_def", "shadow_step", modified_state) as Dictionary
	var refreshed_definition_hash: int = -1
	for entry_var: Variant in instance.get("_pile_dialog_card_pool") as Array:
		var entry: Dictionary = entry_var as Dictionary
		var button: Button = entry.get("button", null) as Button
		if str(entry.get("card_id", "")) != "shadow_step" or button == null or not button.visible:
			continue
		var widget: Control = entry.get("widget", null) as Control
		refreshed_definition_hash = hash(widget.get("_card_override"))
		break
	_expect(refreshed_definition_hash == hash(expected_definition), "pooled pile cards must refresh when their upgraded or modified definition changes")
	_expect(refreshed_definition_hash != original_definition_hash, "pile definition invalidation workload must exercise a real visual definition change")
	instance.call("_close_pile_view")
	instance.set("_combat_state", original_state)
	instance.set("_run_state", original_run_state)


func _measure_umbra_stage_matrix(instance: Node) -> Dictionary:
	var results: Dictionary = {}
	for stage_id: String in ["clear", "pressing", "eclipse"]:
		_phase_log("umbra stage %s" % stage_id)
		_install_stress_combat(instance, "specialists")
		var state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = stage_id
		state["umbra"] = umbra
		instance.set("_combat_state", state)
		var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
		run_state["combat_state"] = state
		instance.set("_run_state", run_state)
		instance.call("_mark_combat_preview_state_changed")
		instance.call("_refresh_ui")
		await _settle_frames(2)
		var stage_results: Dictionary = {}
		for card_id: String in ["bone_dart", "gust_step"]:
			await _select_card(instance, _hand_index(instance, card_id))
			var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
			var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
			var samples: Array[float] = []
			for target: Vector2i in targets:
				var hover_started: int = Time.get_ticks_usec()
				_board_pointer_hover(instance, target)
				samples.append(float(Time.get_ticks_usec() - hover_started) / 1000.0)
			stage_results[card_id] = {"target_count": targets.size(), "hover": _duration_phase_result(samples, "input_handler")}
			instance.call("_cancel_card_selection")
		results[stage_id] = stage_results
	return results

func _measure_flurry_scaling(instance: Node) -> Dictionary:
	_install_stress_combat(instance, "specialists")
	var results: Dictionary = {}
	var cinder_index: int = _hand_index(instance, "cinder_fusillade")
	for repeat_count: int in [1, 4, 10, 20]:
		var state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		state["cards_per_turn"] = repeat_count
		state["cards_played_this_turn"] = 0
		state["death_bonus_card_plays_this_turn"] = 0
		state["card_play_bonus_this_turn"] = 0
		instance.set("_combat_state", state)
		instance.call("_mark_combat_preview_state_changed")
		var actions: Array = _combat.card_play_actions("cinder_fusillade", state)
		var shortcut_playable: bool = bool(instance.call("_card_preview_continuation_is_playable", state, actions, 0, false, true, true))
		var reference_playable: bool = bool(instance.call("_card_preview_continuation_is_playable", state, actions, 0, false, true, false))
		_expect(shortcut_playable == reference_playable, "Flurry skip-suffix shortcut must match the full continuation walk at %d repeats" % repeat_count)
		var started: int = Time.get_ticks_usec()
		var options: Dictionary = instance.call("_card_play_options_for_index", cinder_index) as Dictionary
		results[str(repeat_count)] = {
			"option_build_ms": float(Time.get_ticks_usec() - started) / 1000.0,
			"playable": bool(options.get("printed_playable", false)),
			"action_count": ((options.get("play", {}) as Dictionary).get("actions", []) as Array).size(),
		}
	return results

func _timed_call(target: Object, method_name: String, arguments: Array = []) -> float:
	var started: int = Time.get_ticks_usec()
	target.callv(method_name, arguments)
	return float(Time.get_ticks_usec() - started) / 1000.0

func _routed_left_click(control: Control, local_position: Vector2) -> float:
	if control == null or control.get_viewport() == null:
		return 0.0
	var global_position: Vector2 = control.get_global_transform() * local_position
	var motion := InputEventMouseMotion.new()
	motion.position = global_position
	motion.global_position = global_position
	control.get_viewport().push_input(motion)
	var press := InputEventMouseButton.new()
	press.position = global_position
	press.global_position = global_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	var release := InputEventMouseButton.new()
	release.position = global_position
	release.global_position = global_position
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	var started: int = Time.get_ticks_usec()
	control.get_viewport().push_input(press)
	control.get_viewport().push_input(release)
	return float(Time.get_ticks_usec() - started) / 1000.0

func _board_pointer_click(instance: Node, tile: Vector2i) -> float:
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	return _routed_left_click(board, board.call("world_position_for_tile", tile) as Vector2)

func _board_pointer_hover(instance: Node, tile: Vector2i) -> void:
	# Exercise the same board-local mouse-motion path as live play. Calling the
	# RunScene signal handler directly skips hit testing, the board's own hover
	# state, cursor changes, HUD-region rebuilds, and redraw invalidation.
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var event := InputEventMouseMotion.new()
	event.position = board.call("world_position_for_tile", tile) as Vector2
	board.call("_gui_input", event)

func _measure_composition_matrix(instance: Node) -> Dictionary:
	var results: Dictionary = {}
	for composition_id: String in COMPOSITIONS:
		_phase_log("composition %s" % composition_id)
		_install_stress_combat(instance, composition_id)
		await _settle_frames(4)
		var composition_result: Dictionary = {}
		for card_id: String in ["threaded_path", "bone_dart", "wildfire_halo", "shadow_step"]:
			var hand_index: int = _hand_index(instance, card_id)
			if hand_index < 0:
				continue
			await _select_card(instance, hand_index)
			await _await_render_frame()
			var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
			var targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
			var samples: Array[float] = []
			for target: Vector2i in targets:
				var started: int = Time.get_ticks_usec()
				_board_pointer_hover(instance, target)
				samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
				await process_frame
			composition_result[card_id] = {
				"target_count": targets.size(),
				"hover": _duration_phase_result(samples, "input_handler"),
			}
			instance.call("_cancel_card_selection")
			await _await_render_frame()
		results[composition_id] = composition_result
	return results

func _measure_action_matrix(instance: Node, sampler: FrameSampler) -> Dictionary:
	var results: Dictionary = {}
	for card_id: String in _benchmark_card_ids():
		_phase_log("action %s" % card_id)
		_install_stress_combat(instance, "specialists")
		await _settle_frames(3)
		var hand_index: int = _hand_index(instance, card_id)
		if hand_index < 0:
			continue
		await _select_card(instance, hand_index)
		await _await_render_frame()
		var before_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		sampler.begin()
		var action_started: int = Time.get_ticks_usec()
		var interaction: Dictionary = {}
		if bool(instance.call("_pending_card_requires_confirmation")):
			var confirm_started: int = Time.get_ticks_usec()
			var player_tile: Vector2i = (((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
			_board_pointer_click(instance, player_tile)
			await process_frame
			var confirm_wait_frames: int = 0
			while bool(instance.get("_animation_lock")) and confirm_wait_frames < MAX_ANIMATION_SETTLE_FRAMES:
				await _await_render_frame()
				confirm_wait_frames += 1
			_expect(confirm_wait_frames < MAX_ANIMATION_SETTLE_FRAMES, "%s routed self-tile confirmation must settle before the deadlock guard" % card_id)
			interaction = {"step_completion_samples": [float(Time.get_ticks_usec() - confirm_started) / 1000.0]}
		else:
			interaction = await _exercise_preview_steps(instance, false, card_id)
		await _await_render_frame()
		var action_completion_ms: float = float(Time.get_ticks_usec() - action_started) / 1000.0
		var sampled: Dictionary = sampler.finish()
		var phase: Dictionary = _sampler_phase_result(sampled)
		phase["action_completion_ms"] = action_completion_ms
		phase["target_step_completion"] = _duration_phase_result(interaction.get("step_completion_samples", []) as Array[float], "interaction_step_completion")
		phase["animation_settle_frame_samples"] = interaction.get("animation_settle_frame_samples", [])
		phase["interaction_steps"] = int(interaction.get("step_count", 0))
		phase["state_changed"] = before_state != (instance.get("_combat_state") as Dictionary)
		_expect(bool(phase["state_changed"]), "%s confirmed play must change committed combat state" % card_id)
		_expect(int(phase.get("sample_count", 0)) > 0, "%s committed play must produce sampled animation frames" % card_id)
		results[card_id] = phase
	return results

func _capture_wildfire_action_visuals(instance: Node) -> Dictionary:
	# Replay visual proof only after every timed action sampler has stopped. GPU
	# readback, resize, and PNG encoding are synchronous and must never share a
	# timing window with the action whose visuals they document.
	_install_stress_combat(instance, "specialists")
	await _settle_frames(4)
	var hand_index: int = _hand_index(instance, "wildfire_halo")
	_expect(hand_index >= 0, "Wildfire visual replay requires Wildfire Halo in hand")
	if hand_index < 0:
		return {}
	await _select_card(instance, hand_index)
	await _await_render_frame()
	var interaction_steps: int = 0
	while not bool(instance.call("_pending_card_requires_confirmation")) and interaction_steps < MAX_PREVIEW_STEPS:
		var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
		var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
		if targets.is_empty():
			break
		var target: Vector2i = _preferred_target(instance, targets)
		_board_pointer_hover(instance, target)
		_board_pointer_click(instance, target)
		await process_frame
		interaction_steps += 1
	_expect(bool(instance.call("_pending_card_requires_confirmation")), "Wildfire visual replay must reach self-tile confirmation")
	if bool(instance.call("_pending_card_requires_confirmation")):
		var player_tile: Vector2i = (((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
		_board_pointer_click(instance, player_tile)
	var captured: Array[String] = []
	var capture_frames: Dictionary = {
		18: "action_effect_18.png",
		28: "action_effect_28.png",
		38: "action_effect_38.png",
	}
	for frame_index: int in range(1, 39):
		await _await_render_frame()
		if capture_frames.has(frame_index):
			var file_name: String = str(capture_frames[frame_index])
			await _save_root_screenshot(file_name)
			captured.append(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
	var wait_frames: int = 0
	while bool(instance.get("_animation_lock")) and wait_frames < MAX_ANIMATION_SETTLE_FRAMES:
		await _await_render_frame()
		wait_frames += 1
	_expect(wait_frames < MAX_ANIMATION_SETTLE_FRAMES, "Wildfire visual replay must settle before the deadlock guard")
	await _settle_frames(3)
	return {
		"captured_paths": captured,
		"interaction_steps": interaction_steps,
		"post_capture_settle_frames": wait_frames,
		"timed": false,
	}

func _measure_ability_action_matrix(instance: Node, sampler: FrameSampler) -> Dictionary:
	var results: Dictionary = {}
	for skill_id: String in MANUAL_SKILLS:
		_phase_log("ability action %s" % skill_id)
		_install_stress_combat(instance, "specialists")
		_prepare_manual_skill_state(instance, skill_id)
		await _settle_frames(3)
		var before_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		_expect(_combat.skill_is_ready(before_state, skill_id), "%s must be ready in its authored ability workload" % skill_id)
		sampler.begin()
		var started: int = Time.get_ticks_usec()
		var routed_controls: Dictionary = await _activate_skill_through_viewport(instance, skill_id)
		var selection_zone: String = str(instance.get("_combat_skill_card_selection_zone"))
		if selection_zone == "hand":
			var hand_indices: Array = instance.get("_combat_skill_card_selection_indices") as Array
			if not hand_indices.is_empty():
				var selection_button: Button = instance.find_child("SkillHandSelectionCard_%d" % int(hand_indices[0]), true, false) as Button
				_expect(selection_button != null and selection_button.visible and not selection_button.disabled, "%s hand choice must expose a live selection button" % skill_id)
				if selection_button != null and selection_button.visible and not selection_button.disabled:
					_routed_left_click(selection_button, selection_button.size * 0.5)
					routed_controls["selection"] = selection_button.name
		elif selection_zone == "discard":
			var discard_indices: Array = instance.get("_combat_skill_card_selection_indices") as Array
			if not discard_indices.is_empty():
				var selection_button: Button = _visible_pile_selection_button(instance, int(discard_indices[0]))
				_expect(selection_button != null and not selection_button.disabled, "%s discard choice must expose a live pile selection button" % skill_id)
				if selection_button != null and not selection_button.disabled:
					_routed_left_click(selection_button, selection_button.size * 0.5)
					routed_controls["selection"] = selection_button.name
		var wait_frames: int = 0
		while bool(instance.get("_animation_lock")) and wait_frames < MAX_ANIMATION_SETTLE_FRAMES:
			await _await_render_frame()
			wait_frames += 1
		await _await_render_frame()
		var post_skill_card_click: Dictionary = await _verify_post_skill_hand_pointer_input(instance, skill_id)
		var total_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		var sampled: Dictionary = sampler.finish()
		var phase: Dictionary = _sampler_phase_result(sampled)
		phase["total_ms"] = total_ms
		phase["wait_frames"] = wait_frames
		phase["routed_controls"] = routed_controls
		phase["post_skill_card_click"] = post_skill_card_click
		phase["state_changed"] = before_state != (instance.get("_combat_state") as Dictionary)
		_expect(bool(phase["state_changed"]), "%s activation must change committed combat state" % skill_id)
		_expect(wait_frames < MAX_ANIMATION_SETTLE_FRAMES, "%s activation animation must settle before the deadlock guard" % skill_id)
		results[skill_id] = phase
	return results

func _activate_skill_through_viewport(instance: Node, skill_id: String) -> Dictionary:
	var routed: Dictionary = {}
	var sigil: Button = instance.find_child("SkillSigil", true, false) as Button
	_expect(sigil != null and sigil.visible and not sigil.disabled, "%s must open from the live ability sigil" % skill_id)
	if sigil == null or not sigil.visible or sigil.disabled:
		return routed
	_routed_left_click(sigil, sigil.size * 0.5)
	routed["sigil"] = sigil.name
	await process_frame
	var status_tiles: Dictionary = instance.get("_skill_status_tiles") as Dictionary
	var status_tile: Button = status_tiles.get(skill_id, null) as Button
	var page_guard: int = 0
	while status_tile != null and not status_tile.visible and page_guard < 20:
		var skill_ids: Array[String] = instance.get("_skill_status_skill_ids") as Array[String]
		var target_index: int = skill_ids.find(skill_id)
		var visible_ids: Array[String] = instance.call("_skill_status_visible_ids") as Array[String]
		var visible_last_index: int = skill_ids.find(visible_ids[visible_ids.size() - 1]) if not visible_ids.is_empty() else -1
		var page_button: Button = (
			instance.find_child("NextSkillStatusPage", true, false) as Button
			if target_index > visible_last_index
			else instance.find_child("PreviousSkillStatusPage", true, false) as Button
		)
		_expect(page_button != null and page_button.visible and not page_button.disabled, "%s palette page must be reachable through live page controls" % skill_id)
		if page_button == null or not page_button.visible or page_button.disabled:
			break
		_routed_left_click(page_button, page_button.size * 0.5)
		await process_frame
		status_tiles = instance.get("_skill_status_tiles") as Dictionary
		status_tile = status_tiles.get(skill_id, null) as Button
		page_guard += 1
	_expect(status_tile != null and status_tile.visible and str(status_tile.get_meta("skill_status", "")) == "READY", "%s ability palette tile must refresh to READY in the authored live workload" % skill_id)
	if status_tile == null or not status_tile.visible:
		return routed
	_routed_left_click(status_tile, status_tile.size * 0.5)
	routed["tile"] = status_tile.name
	await process_frame
	var action_button: Button = instance.find_child("ActivateSelectedSkill", true, false) as Button
	_expect(action_button != null and action_button.visible and not action_button.disabled, "%s must activate through the live palette action button" % skill_id)
	if action_button != null and action_button.visible and not action_button.disabled:
		_routed_left_click(action_button, action_button.size * 0.5)
		routed["activate"] = action_button.name
		await process_frame
	return routed

func _visible_pile_selection_button(instance: Node, source_index: int) -> Button:
	var cards: Container = instance.get("_pile_dialog_cards") as Container
	if cards == null:
		return null
	for child: Node in cards.get_children():
		var button: Button = child as Button
		if button != null and button.visible and int(button.get_meta("source_card_index", -1)) == source_index:
			return button
	return null

func _verify_post_skill_hand_pointer_input(instance: Node, skill_id: String) -> Dictionary:
	var hand: Array = (((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array)
	for hand_index: int in range(hand.size()):
		var widget: Control = instance.call("_hand_card_control", hand_index) as Control
		if widget == null or not widget.visible or widget.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		var handler_ms: float = await _select_card(instance, hand_index)
		var selected: bool = int(instance.get("_selected_card_index")) == hand_index
		_expect(selected, "%s pooled hand must accept a real card click after skill selection" % skill_id)
		instance.call("_cancel_card_selection")
		await _await_render_frame()
		return {"hand_index": hand_index, "handler_ms": handler_ms, "selected": selected}
	_expect(false, "%s must leave at least one pointer-interactive pooled hand card" % skill_id)
	return {"selected": false}

func _prepare_manual_skill_state(instance: Node, skill_id: String) -> void:
	var state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	var hand: Array = (deck.get("hand", []) as Array).duplicate()
	if skill_id == "encore":
		var discard: Array = (deck.get("discard", []) as Array).duplicate()
		# Encore needs both a free hand slot and a non-item card in discard. Build
		# that authored boundary explicitly instead of shrinking an over-cap stress
		# hand by only one card.
		while hand.size() >= CombatEngine.MAX_HAND_SIZE and not hand.is_empty():
			discard.append(hand.pop_back())
		if discard.is_empty():
			discard.append("bone_dart")
		deck["discard"] = discard
	elif skill_id == "rehearsed_escape" and not hand.is_empty():
		hand[0] = "patch_up"
	elif skill_id == "makeshift_tool" and not hand.is_empty():
		hand[0] = "crimson_draught"
	deck["hand"] = hand
	state["deck"] = deck
	instance.set("_combat_state", state)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")

func _measure_enemy_round_matrix(instance: Node, sampler: FrameSampler) -> Dictionary:
	var results: Dictionary = {}
	for composition_id: String in COMPOSITIONS:
		_phase_log("enemy round %s" % composition_id)
		_install_stress_combat(instance, composition_id)
		await _settle_frames(3)
		var before_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		sampler.begin()
		var started: int = Time.get_ticks_usec()
		await instance.call("_on_pass_turn_pressed")
		await _await_render_frame()
		var total_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		var sampled: Dictionary = sampler.finish()
		var result: Dictionary = _sampler_phase_result(sampled)
		result["total_ms"] = total_ms
		result["state_changed"] = before_state != (instance.get("_combat_state") as Dictionary)
		_expect(bool(result["state_changed"]), "%s pass must execute the enemy round" % composition_id)
		results[composition_id] = result
	return results

func _exercise_preview_steps(instance: Node, measure_all_hovers: bool, workload_id: String = "card") -> Dictionary:
	var hover_samples: Array[float] = []
	var step_completion_samples: Array[float]
	var animation_settle_frame_samples: Array[int]
	var steps: int = 0
	var total_targets: int = 0
	var max_targets: int = 0
	while not bool(instance.call("_pending_card_requires_confirmation")) and steps < MAX_PREVIEW_STEPS:
		var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
		if preview.is_empty():
			break
		var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
		total_targets += targets.size()
		max_targets = maxi(max_targets, targets.size())
		if targets.is_empty():
			if bool(instance.call("_current_action_can_skip")):
				var skip_started: int = Time.get_ticks_usec()
				var skip_button: Button = instance.find_child("ActionContextSkip", true, false) as Button
				_expect(skip_button != null and not skip_button.disabled, "skippable action must route through the live Skip button")
				if skip_button != null and not skip_button.disabled:
					_routed_left_click(skip_button, skip_button.size * 0.5)
				await process_frame
				await _await_render_frame()
				step_completion_samples.append(float(Time.get_ticks_usec() - skip_started) / 1000.0)
				steps += 1
				continue
			break
		_validate_prevalidated_action_equivalence(preview)
		if measure_all_hovers:
			for target: Vector2i in targets:
				var hover_started: int = Time.get_ticks_usec()
				_board_pointer_hover(instance, target)
				await _await_render_frame()
				hover_samples.append(float(Time.get_ticks_usec() - hover_started) / 1000.0)
		var chosen_target: Vector2i = _preferred_target(instance, targets)
		var click_started: int = Time.get_ticks_usec()
		_board_pointer_hover(instance, chosen_target)
		_board_pointer_click(instance, chosen_target)
		await process_frame
		var animation_wait_frames: int = 0
		while bool(instance.get("_animation_lock")) and animation_wait_frames < MAX_ANIMATION_SETTLE_FRAMES:
			await _await_render_frame()
			animation_wait_frames += 1
		animation_settle_frame_samples.append(animation_wait_frames)
		_expect(animation_wait_frames < MAX_ANIMATION_SETTLE_FRAMES, "%s step %d must settle before the animation deadlock guard" % [workload_id, steps + 1])
		await _await_render_frame()
		step_completion_samples.append(float(Time.get_ticks_usec() - click_started) / 1000.0)
		steps += 1
	return {
		"hover_samples": hover_samples,
		"step_completion_samples": step_completion_samples,
		"animation_settle_frame_samples": animation_settle_frame_samples,
		"step_count": steps,
		"total_target_count": total_targets,
		"max_target_count": max_targets,
		"reached_confirmation": bool(instance.call("_pending_card_requires_confirmation")),
	}

func _validate_prevalidated_action_equivalence(preview: Dictionary) -> void:
	var action: Dictionary = preview.get("action", {}) as Dictionary
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["melee", "ranged", "aoe", "push", "pull"] or _validated_prevalidated_action_types.has(action_type):
		return
	var valid_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	if valid_targets.is_empty():
		return
	var state: Dictionary = preview.get("state", {}) as Dictionary
	var target_tile: Vector2i = valid_targets[0]
	var validated: Dictionary = _combat.apply_player_action(state, action, target_tile)
	var prevalidated: Dictionary = _combat.apply_prevalidated_player_action(state, action, target_tile)
	_expect(validated == prevalidated, "%s prevalidated preview resolution must match normal action resolution" % action_type)
	_validated_prevalidated_action_types[action_type] = true

func _validate_pass_preview_progression_equivalence(instance: Node, preview: Dictionary, targets: Array[Vector2i]) -> void:
	if targets.is_empty() or bool(preview.get("orientation_pending", false)):
		return
	var actions: Array = preview.get("actions", []) as Array
	var action_index: int = int(preview.get("action_index", -1))
	if action_index < 0 or action_index >= actions.size():
		return
	var action: Dictionary = preview.get("action", {}) as Dictionary
	var state: Dictionary = preview.get("state", {}) as Dictionary
	var target: Vector2i = targets[0]
	var resolved: Dictionary = _combat.apply_player_action(state, action, target)
	var legacy_preview: Dictionary = instance.call(
		"_card_preview_from_state",
		str(preview.get("card_id", "")),
		resolved,
		actions,
		action_index + 1
	) as Dictionary
	var legacy_state: Dictionary = instance.call("_pass_preview_state_after_pending_preview", legacy_preview) as Dictionary
	var linear_state: Dictionary = instance.call("_pass_preview_state_after_resolved_target", resolved, actions, action_index + 1) as Dictionary
	_expect(linear_state == legacy_state, "%s linear pass-preview progression must match full continuation construction" % str(preview.get("card_id", "card")))

func _preview_interaction_tiles(instance: Node, preview: Dictionary) -> Array[Vector2i]:
	if bool(preview.get("orientation_pending", false)):
		return _vector2i_array(instance.call("_direction_choice_tiles", preview.get("orientation_target", Vector2i(-1, -1))))
	# Exercise only targets the live input handler will accept. Raw engine preview
	# tiles may include Umbra-hidden choices that are intentionally removed from
	# the board's pending target list.
	return _vector2i_array(instance.get("_pending_target_tiles"))

func _preferred_target(instance: Node, targets: Array[Vector2i]) -> Vector2i:
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var board_center: Vector2 = board.size * 0.5
	var chosen: Vector2i = targets[0]
	var chosen_distance: float = -1.0
	for target: Vector2i in targets:
		var point: Vector2 = board.call("world_position_for_tile", target) as Vector2
		var distance: float = point.distance_squared_to(board_center)
		if distance > chosen_distance:
			chosen = target
			chosen_distance = distance
	return chosen

func _select_card(instance: Node, hand_index: int, play_kind: String = "play") -> float:
	var widget: Control = instance.call("_hand_card_control", hand_index) as Control
	_expect(widget != null and widget.visible, "card click must route through a visible pooled CardWidget")
	_expect(widget != null and widget.mouse_filter == Control.MOUSE_FILTER_STOP, "interactive pooled CardWidget must accept viewport-routed input")
	if widget == null:
		return 0.0
	var hand: Array = (((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array)
	var local_x: float = widget.size.x - 18.0 if hand_index == hand.size() - 1 else 18.0
	var handler_ms: float = _routed_left_click(widget, Vector2(local_x, minf(72.0, widget.size.y * 0.24)))
	await process_frame
	if int(instance.get("_selected_card_index")) != hand_index and int(instance.get("_card_action_choice_index")) == hand_index:
		var option_button: Button = instance.find_child("CardActionChoice%s" % play_kind.capitalize(), true, false) as Button
		_expect(option_button != null and not option_button.disabled, "%s mode must be reachable through its live choice button" % play_kind)
		if option_button != null and not option_button.disabled:
			handler_ms += _routed_left_click(option_button, option_button.size * 0.5)
			await process_frame
	_expect(int(instance.get("_selected_card_index")) == hand_index, "card click must enter the requested preview mode")
	return handler_ms

func _measure_ranged_trap_hand_regression(instance: Node) -> Dictionary:
	_install_stress_combat(instance, "specialists")
	await _settle_frames(4)
	var hand_box_before: Control = instance.get("hand_box") as Control
	var geometry_before: Dictionary = _hand_geometry_diagnostics(instance, hand_box_before)
	var hand_before: Array = (((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array)
	var hand_index: int = hand_before.find("bone_dart")
	_expect(hand_index >= 0, "ranged trap regression requires Bone Dart in hand")
	if hand_index < 0:
		return {}
	await _select_card(instance, hand_index)
	await _await_render_frame()
	var trap_tile := Vector2i(2, 2)
	var pending_tiles: Array[Vector2i] = _vector2i_array(instance.get("_pending_target_tiles"))
	_expect(pending_tiles.has(trap_tile), "Bone Dart must be able to target the authored ranged trap")
	if not pending_tiles.has(trap_tile):
		return {}
	_board_pointer_click(instance, trap_tile)
	await process_frame
	if bool(instance.call("_pending_card_requires_confirmation")):
		var player_tile: Vector2i = (((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
		_board_pointer_click(instance, player_tile)
		await process_frame
	var wait_frames: int = 0
	while bool(instance.get("_animation_lock")) and wait_frames < MAX_ANIMATION_SETTLE_FRAMES:
		await _await_render_frame()
		wait_frames += 1
	_expect(wait_frames < MAX_ANIMATION_SETTLE_FRAMES, "ranged trap action must settle before the animation deadlock guard")
	await _settle_frames(6)
	var hand_box: Control = instance.get("hand_box") as Control
	var hand_after: Array = (((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array)
	_expect(hand_after.size() == hand_before.size() - 1, "ranged trap play must remove exactly one card from hand")
	_expect(hand_box != null and hand_box.get_child_count() == hand_after.size(), "post-trap hand must render every remaining card exactly once")
	var expected_size: Vector2 = instance.call("_hand_card_size", hand_after.size(), false) as Vector2
	var geometry_after: Dictionary = _hand_geometry_diagnostics(instance, hand_box)
	var slot_diagnostics: Array[Dictionary]
	if hand_box != null:
		for index: int in range(hand_box.get_child_count()):
			var slot: Control = hand_box.get_child(index) as Control
			var widget: Control = instance.call("_hand_card_control", index) as Control
			if slot == null or widget == null:
				continue
			var visual_rect: Rect2 = instance.call("_control_visual_global_rect", widget) as Rect2
			slot_diagnostics.append({
				"index": index,
				"slot_size": slot.size,
				"slot_minimum": slot.custom_minimum_size,
				"slot_scale": slot.scale,
				"slot_anchors": Vector4(slot.anchor_left, slot.anchor_top, slot.anchor_right, slot.anchor_bottom),
				"widget_visual_size": visual_rect.size,
			})
			_expect(slot.anchor_left == 0.0 and slot.anchor_top == 0.0 and slot.anchor_right == 0.0 and slot.anchor_bottom == 0.0, "post-trap pooled hand slot %d must use top-left anchors" % index)
			_expect(slot.size.is_equal_approx(expected_size), "post-trap pooled hand slot %d must retain authored card dimensions" % index)
			_expect(widget.size.is_equal_approx(Vector2(250.0, 352.0)), "post-trap pooled card %d must retain its native CardWidget dimensions" % index)
			_expect(visual_rect.size.x <= expected_size.x * 1.10 and visual_rect.size.y <= expected_size.y * 1.10, "post-trap pooled card %d must not stretch beyond its rotated hand envelope" % index)
	await _save_root_screenshot("ranged_trap_hand.png")
	await _settle_render_frames(4)
	return {
		"wait_frames": wait_frames,
		"hand_count_before": hand_before.size(),
		"hand_count_after": hand_after.size(),
		"expected_card_size": expected_size,
		"geometry_before": geometry_before,
		"geometry_after": geometry_after,
		"slots": slot_diagnostics,
	}

func _hand_geometry_diagnostics(instance: Node, hand_box: Control) -> Dictionary:
	var result: Dictionary = {}
	if hand_box == null:
		return result
	result["hand_box_size"] = hand_box.size
	result["hand_box_scale"] = hand_box.scale
	result["hand_box_global_scale"] = hand_box.get_global_transform().get_scale()
	if hand_box.get_child_count() == 0:
		return result
	var slot: Control = hand_box.get_child(0) as Control
	var widget: Control = instance.call("_hand_card_control", 0) as Control
	var scaler: Control = widget.get_parent() as Control if widget != null else null
	if slot != null:
		result["slot_size"] = slot.size
		result["slot_scale"] = slot.scale
		result["slot_global_scale"] = slot.get_global_transform().get_scale()
	if scaler != null:
		result["scaler_size"] = scaler.size
		result["scaler_scale"] = scaler.scale
		result["scaler_global_scale"] = scaler.get_global_transform().get_scale()
	if widget != null:
		result["widget_size"] = widget.size
		result["widget_minimum"] = widget.custom_minimum_size
		result["widget_combined_minimum"] = widget.get_combined_minimum_size()
		result["widget_scale"] = widget.scale
		result["widget_global_scale"] = widget.get_global_transform().get_scale()
		result["widget_anchors"] = Vector4(widget.anchor_left, widget.anchor_top, widget.anchor_right, widget.anchor_bottom)
		result["widget_offsets"] = Vector4(widget.offset_left, widget.offset_top, widget.offset_right, widget.offset_bottom)
		result["widget_top_level"] = widget.top_level
	return result

func _install_stress_combat(instance: Node, composition_id: String) -> Dictionary:
	_phase_log("install %s: reset" % composition_id)
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = {
		"name": "Depth 13 Runtime Performance Chamber",
		"coord": Vector2i(13, 0),
		"depth": 13,
		"section_index": 3,
		"type": "combat",
		"element": "lightning",
		"grid": _stress_grid(),
		"player_start": Vector2i(4, 4),
		"enemies": _composition_enemies(composition_id),
		"traps": _stress_traps(),
		"loot": _stress_loot(),
		"terrain": _stress_terrain(),
	}
	var combat_state: Dictionary = _combat.create_combat(13009021 + COMPOSITIONS.find(composition_id), layout, {
		"hp": 120,
		"max_hp": 120,
		"deck_cards": HAND.duplicate(),
		"relics": RELICS.duplicate(),
		"skill_ids": SKILLS.duplicate(),
		"hand_size": HAND.size(),
		# Keep the rendered interaction matrix at a high but plausible turn budget.
		# Pathological flurry scaling is measured separately without waiting for
		# hundreds of post-draw frames to make the rest of the matrix unreachable.
		"cards_per_turn": 4,
		"draw_per_turn": HAND.size(),
		"heal_bonus": 0,
	})
	_phase_log("install %s: combat created" % composition_id)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = HAND.duplicate()
	var stress_draw: Array = []
	var stress_discard: Array = []
	for _repeat: int in range(3):
		stress_draw.append_array(HAND)
	for _repeat: int in range(2):
		stress_discard.append_array(HAND)
	deck["draw"] = stress_draw
	deck["discard"] = stress_discard
	deck["burned"] = HAND.duplicate()
	combat_state["deck"] = deck
	combat_state["player"] = {
		"pos": Vector2i(4, 4),
		"hp": 120,
		"max_hp": 120,
		"block": 30,
		"stoneskin": 20,
		"burn": 3,
		"bleed": 2,
		"expose": 1,
		"poison": {"damage": 2, "delay": 3},
	}
	combat_state["skill_ids"] = SKILLS.duplicate()
	combat_state["relics"] = RELICS.duplicate()
	combat_state["illusions"] = _stress_illusions()
	combat_state["elemental_intensity"] = {"fire": 6, "ice": 6, "lightning": 6, "air": 6, "earth": 6}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"immobilized": false, "frozen": false, "shocked": false}
	_enrich_enemy_states(combat_state)
	_phase_log("install %s: combat enriched" % composition_id)

	var progression: Dictionary = ProgressionStore.default_data()
	progression["level"] = 14
	progression["skill_ids"] = SKILLS.duplicate()
	progression["run_counter"] = 2
	instance.set("_progression", progression)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["depth"] = 13
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = combat_state
	run_state["relics"] = RELICS.duplicate()
	run_state["skill_ids"] = SKILLS.duplicate()
	run_state["progression"] = progression.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	_phase_log("install %s: state assigned" % composition_id)
	instance.call("_mark_combat_preview_state_changed")
	if composition_id == "specialists" and not _profiled_initial_refresh:
		_profiled_initial_refresh = true
		_profile_initial_refresh_parts(instance)
	_phase_log("install %s: refreshing ui" % composition_id)
	instance.call("_refresh_ui")
	_phase_log("install %s: ui refreshed" % composition_id)
	return combat_state

func _profile_initial_refresh_parts(instance: Node) -> void:
	for method_name: String in [
		"_refresh_relic_bar",
		"_refresh_turn_order_bar",
		"_refresh_combat_objective_hud",
		"_refresh_elemental_intensity_bar",
		"_refresh_pile_counts",
		"_refresh_card_play_meter",
		"_refresh_action_step_tracker",
		"_refresh_pile_visuals",
		"_refresh_choice_bar",
		"_refresh_stage_view",
		"_refresh_pile_interaction_states",
		"_refresh_visibility",
		"_refresh_contextual_combat_tutorial",
	]:
		var started: int = Time.get_ticks_usec()
		_phase_log("diagnostic %s start" % method_name)
		instance.call(method_name)
		_phase_log("diagnostic %s %.3f ms" % [method_name, float(Time.get_ticks_usec() - started) / 1000.0])
	for card_id: String in HAND:
		var hand_index: int = _hand_index(instance, card_id)
		var started: int = Time.get_ticks_usec()
		_phase_log("diagnostic card options %s start" % card_id)
		instance.call("_card_play_options_for_index", hand_index)
		_phase_log("diagnostic card options %s %.3f ms" % [card_id, float(Time.get_ticks_usec() - started) / 1000.0])
	var hand_started: int = Time.get_ticks_usec()
	instance.call("_refresh_hand_panel")
	_phase_log("diagnostic _refresh_hand_panel cached %.3f ms" % (float(Time.get_ticks_usec() - hand_started) / 1000.0))

func _stress_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	(grid[1] as Array)[4] = "pillar"
	(grid[7] as Array)[4] = "pillar"
	return grid

func _composition_enemies(composition_id: String) -> Array:
	match composition_id:
		"split_swarm":
			return [
				_enemy(1, "cinder_ooze", Vector2i(1, 1)),
				_enemy(2, "cinder_droplet", Vector2i(3, 1)),
				_enemy(3, "cinder_droplet", Vector2i(5, 1)),
				_enemy(4, "cinder_droplet", Vector2i(7, 1)),
				_enemy(5, "grave_surgeon", Vector2i(1, 6)),
				_enemy(6, "acolyte", Vector2i(3, 6)),
				_enemy(7, "veilbound_acolyte", Vector2i(5, 6)),
				_enemy(8, "lightning_wisp", Vector2i(7, 6)),
				_enemy(9, "crawler", Vector2i(7, 4)),
			]
		"dragon_support":
			return [
				_enemy(1, "vaeloryx", Vector2i(5, 1)),
				_enemy(2, "veilbound_acolyte", Vector2i(1, 1)),
				_enemy(3, "lightning_wisp", Vector2i(3, 1)),
				_enemy(4, "chainbound_gaoler", Vector2i(1, 6)),
				_enemy(5, "grave_surgeon", Vector2i(7, 6)),
			]
		_:
			return [
				_enemy(1, "crawler", Vector2i(1, 1)),
				_enemy(2, "harrier", Vector2i(3, 1)),
				_enemy(3, "cinder_ooze", Vector2i(5, 1)),
				_enemy(4, "frostglass_lancer", Vector2i(7, 1)),
				_enemy(5, "chainbound_gaoler", Vector2i(1, 6)),
				_enemy(6, "bile_bloomer", Vector2i(7, 6)),
				_enemy(7, "lightning_wisp", Vector2i(7, 4)),
			]

func _enemy(enemy_id: int, enemy_type: String, pos: Vector2i) -> Dictionary:
	return {"id": enemy_id, "type": enemy_type, "pos": pos}

func _enrich_enemy_states(combat_state: Dictionary) -> void:
	var enemies: Array = combat_state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 999
		enemy["max_hp"] = 999
		enemy["block"] = 20 + index
		enemy["stoneskin"] = 3 + posmod(index, 3)
		enemy["burn"] = 2 + posmod(index, 4)
		enemy["bleed"] = 1 + posmod(index, 3)
		enemy["freeze"] = 1 if index % 3 == 0 else 0
		enemy["shock"] = 1 if index % 3 == 1 else 0
		enemy["immobilize"] = index % 4 == 0
		enemy["poison"] = {"damage": 2 + posmod(index, 2), "delay": 2 + posmod(index, 3)}
		enemies[index] = enemy
	combat_state["enemies"] = enemies

func _stress_illusions() -> Array:
	return [
		{"id": 1, "pos": Vector2i(2, 3), "hp": 8, "max_hp": 8},
		{"id": 2, "pos": Vector2i(6, 3), "hp": 8, "max_hp": 8},
		{"id": 3, "pos": Vector2i(2, 5), "hp": 8, "max_hp": 8},
		{"id": 4, "pos": Vector2i(6, 5), "hp": 8, "max_hp": 8},
	]

func _stress_traps() -> Array:
	var elements: Array[String] = ["fire", "ice", "lightning", "air", "earth"]
	var positions: Array[Vector2i] = _vector2i_array([
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
		Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6),
	])
	var traps: Array = []
	for index: int in range(positions.size()):
		traps.append({
			"id": "runtime_trap_%d" % index,
			"pos": positions[index],
			"element": elements[index % elements.size()],
			"damage": 12,
			"burn": 3 if index % elements.size() == 0 else 0,
			"freeze": 1 if index % elements.size() == 1 else 0,
			"armed": true,
		})
	return traps

func _stress_loot() -> Array:
	return [
		{"id": "runtime_ember_1", "kind": "embers", "amount": 3, "pos": Vector2i(2, 2), "claimed": false},
		{"id": "runtime_ember_2", "kind": "embers", "amount": 4, "pos": Vector2i(6, 2), "claimed": false},
		{"id": "runtime_vial_1", "kind": "healing_vial", "amount": 5, "pos": Vector2i(2, 6), "claimed": false},
		{"id": "runtime_vial_2", "kind": "healing_vial", "amount": 5, "pos": Vector2i(6, 6), "claimed": false},
		{"id": "runtime_equipment_1", "kind": "equipment", "equipment_id": "training_sword", "pos": Vector2i(1, 4), "claimed": false},
		{"id": "runtime_equipment_2", "kind": "equipment", "equipment_id": "training_shield", "pos": Vector2i(7, 4), "claimed": false},
	]

func _stress_terrain() -> Array:
	return [
		{"id": "runtime_crate_1", "kind": "wooden_crate", "pos": Vector2i(3, 3), "hp": 20, "max_hp": 20},
		{"id": "runtime_crate_2", "kind": "wooden_crate", "pos": Vector2i(5, 3), "hp": 20, "max_hp": 20},
		{"id": "runtime_crate_3", "kind": "wooden_crate", "pos": Vector2i(3, 5), "hp": 20, "max_hp": 20},
		{"id": "runtime_crate_4", "kind": "wooden_crate", "pos": Vector2i(5, 5), "hp": 20, "max_hp": 20},
	]

func _hand_index(instance: Node, card_id: String) -> int:
	var deck: Dictionary = (instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary
	return (deck.get("hand", []) as Array).find(card_id)

func _benchmark_card_ids() -> Array[String]:
	var filter_text: String = OS.get_environment("LABYRINTH_RUNTIME_PERF_CARD_FILTER").strip_edges()
	if filter_text.is_empty():
		return HAND.duplicate()
	var requested: Dictionary = {}
	for card_id: String in filter_text.split(",", false):
		requested[card_id.strip_edges()] = true
	var result: Array[String] = []
	for card_id: String in HAND:
		if requested.has(card_id):
			result.append(card_id)
	return result

func _combined_action_phase(action_matrix: Dictionary) -> Dictionary:
	var intervals: Array[float] = []
	var process_samples: Array[float] = []
	var draw_samples: Array[float] = []
	var object_samples: Array[float] = []
	var primitive_samples: Array[float] = []
	for card_id: String in action_matrix:
		var card_result: Dictionary = action_matrix.get(card_id, {}) as Dictionary
		intervals.append_array(card_result.get("raw_frame_intervals_ms", []) as Array[float])
		process_samples.append_array(card_result.get("raw_process_ms", []) as Array[float])
		draw_samples.append_array(card_result.get("raw_draw_calls", []) as Array[float])
		object_samples.append_array(card_result.get("raw_objects_in_frame", []) as Array[float])
		primitive_samples.append_array(card_result.get("raw_primitives_in_frame", []) as Array[float])
	return _phase_result(intervals, process_samples, draw_samples, object_samples, primitive_samples)

func _combined_target_step_completion_phase(action_matrix: Dictionary) -> Dictionary:
	var samples: Array[float]
	for card_id: String in action_matrix:
		var card_result: Dictionary = action_matrix.get(card_id, {}) as Dictionary
		var target_step: Dictionary = card_result.get("target_step_completion", {}) as Dictionary
		for value_var: Variant in target_step.get("raw_duration_ms", []):
			if typeof(value_var) in [TYPE_FLOAT, TYPE_INT]:
				samples.append(float(value_var))
	return _duration_phase_result(samples, "interaction_step_completion")

func _combined_action_completion_phase(action_matrix: Dictionary) -> Dictionary:
	var samples: Array[float]
	for card_id: String in action_matrix:
		var card_result: Dictionary = action_matrix.get(card_id, {}) as Dictionary
		if card_result.has("action_completion_ms"):
			samples.append(float(card_result.get("action_completion_ms", 0.0)))
	return _duration_phase_result(samples, "action_completion")

func _sampler_phase_result(sampled: Dictionary) -> Dictionary:
	var result: Dictionary = _phase_result(
		sampled.get("frame_interval_ms", []) as Array[float],
		sampled.get("process_ms", []) as Array[float],
		sampled.get("draw_calls", []) as Array[float],
		sampled.get("objects_in_frame", []) as Array[float],
		sampled.get("primitives_in_frame", []) as Array[float]
	)
	result["raw_frame_intervals_ms"] = sampled.get("frame_interval_ms", [])
	result["raw_process_ms"] = sampled.get("process_ms", [])
	result["raw_draw_calls"] = sampled.get("draw_calls", [])
	result["raw_objects_in_frame"] = sampled.get("objects_in_frame", [])
	result["raw_primitives_in_frame"] = sampled.get("primitives_in_frame", [])
	return result

func _phase_result(
	intervals: Array[float],
	process_samples: Array[float] = [],
	draw_samples: Array[float] = [],
	object_samples: Array[float] = [],
	primitive_samples: Array[float] = []
) -> Dictionary:
	return {
		"sample_count": intervals.size(),
		"raw_intervals_ms": intervals.duplicate(),
		"frame_interval_ms": _stats(intervals),
		"process_ms": _stats(process_samples),
		"draw_calls": _stats(draw_samples),
		"objects_in_frame": _stats(object_samples),
		"primitives_in_frame": _stats(primitive_samples),
		"frames_over_16_67_ms": _count_over(intervals, 16.67),
		"frames_over_20_ms": _count_over(intervals, 20.0),
		"frames_over_33_33_ms": _count_over(intervals, 33.33),
	}

func _duration_phase_result(durations_ms: Array[float], measurement_class: String) -> Dictionary:
	return {
		"measurement_class": measurement_class,
		"sample_count": durations_ms.size(),
		"raw_duration_ms": durations_ms.duplicate(),
		"duration_ms": _stats(durations_ms),
	}

func _stats(source: Array[float]) -> Dictionary:
	var values: Array[float] = source.duplicate()
	values.sort()
	if values.is_empty():
		return {"median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "mean": 0.0}
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
		"max": values[values.size() - 1],
		"mean": total / float(values.size()),
	}

func _percentile(sorted_values: Array[float], percentile: float) -> float:
	var index: int = clampi(int(ceil(float(sorted_values.size()) * percentile)) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]

func _count_over(values: Array[float], threshold: float) -> int:
	var count: int = 0
	for value: float in values:
		if value > threshold:
			count += 1
	return count

func _vector2i_array(values: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value: Variant in values as Array:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _save_root_screenshot(file_name: String) -> void:
	await _await_render_frame()
	var image: Image = root.get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	# Retina windows return the backing texture at device-pixel resolution even
	# though the authored viewport is 1920x1080. Normalize proof output to the UI
	# rubric's required logical resolution.
	if image.get_size() != _viewport_size:
		image.resize(_viewport_size.x, _viewport_size.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.get_size() == _viewport_size, "%s must capture %dx%d" % [file_name, _viewport_size.x, _viewport_size.y])
	_expect(image.save_png(path) == OK, "%s could not be saved" % file_name)

func _requested_viewport_size() -> Vector2i:
	var requested: String = OS.get_environment("LABYRINTH_RUNTIME_PERF_VIEWPORT_SIZE").strip_edges().to_lower()
	var dimensions: PackedStringArray = requested.split("x", false, 1)
	if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
		return DEFAULT_VIEWPORT_SIZE
	var width: int = int(dimensions[0])
	var height: int = int(dimensions[1])
	if width < 640 or height < 480:
		return DEFAULT_VIEWPORT_SIZE
	return Vector2i(width, height)

func _await_render_frame() -> void:
	# A retained scene may correctly have no dirty gameplay draw command. Pulse a
	# dedicated one-pixel CanvasItem so frame_post_draw denotes the immediately
	# requested frame rather than a later unrelated animation or idle redraw.
	if _render_pulse != null and is_instance_valid(_render_pulse):
		_render_pulse.pulse()
	await RenderingServer.frame_post_draw
	_focus_observation_count += 1
	if not DisplayServer.window_is_focused():
		_unfocused_observation_count += 1

func _acquire_probe_window_focus() -> bool:
	# The host runner activates the launched PID after Godot creates its startup
	# log. Give that external request a bounded wall-clock window; uncapped process
	# frames can exhaust a frame-count loop before the watchdog observes startup.
	for _attempt: int in range(60):
		DisplayServer.window_move_to_foreground()
		await create_timer(0.05).timeout
		if DisplayServer.window_is_focused():
			return true
	return false

func _collect_throttle_samples(value: Variant, path: String, result: Array[Dictionary]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value as Dictionary
		if dictionary.has("raw_frame_intervals_ms"):
			for sample_var: Variant in dictionary.get("raw_frame_intervals_ms", []):
				if typeof(sample_var) in [TYPE_FLOAT, TYPE_INT] and float(sample_var) >= 500.0:
					result.append({"path": path, "measurement_class": "frame_interval", "duration_ms": float(sample_var)})
		var measurement_class: String = str(dictionary.get("measurement_class", ""))
		if measurement_class in ["interaction_frame_completion", "cold_interaction_frame_completion"]:
			for sample_var: Variant in dictionary.get("raw_duration_ms", []):
				if typeof(sample_var) in [TYPE_FLOAT, TYPE_INT] and float(sample_var) >= 500.0:
					result.append({"path": path, "measurement_class": measurement_class, "duration_ms": float(sample_var)})
		for key_var: Variant in dictionary.keys():
			var key: String = str(key_var)
			if key in ["raw_frame_intervals_ms", "raw_intervals_ms", "raw_duration_ms", "raw_process_ms", "raw_draw_calls", "raw_objects_in_frame", "raw_primitives_in_frame"]:
				continue
			_collect_throttle_samples(dictionary[key_var], "%s.%s" % [path, key], result)
	elif typeof(value) == TYPE_ARRAY:
		var values: Array = value as Array
		for index: int in range(values.size()):
			_collect_throttle_samples(values[index], "%s[%d]" % [path, index], result)

func _settle_frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame

func _settle_render_frames(count: int) -> void:
	for _frame: int in range(count):
		await _await_render_frame()

func _subtree_node_count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _subtree_node_count(child)
	return total

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _phase_log(message: String) -> void:
	print("RUNTIME FRAME PERF PHASE: %s (%d ms)" % [message, Time.get_ticks_msec()])
