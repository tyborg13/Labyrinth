extends RefCounted

# The runtime harness owns the native window, post-draw clock, input routing and
# screenshot settling. Explicit presentation phases below are narrow rendering
# workloads; the hover matrix separately exercises real player input.
const Ground = preload("res://scripts/board_surface_rules.gd")
const SAMPLE_FRAMES: int = 90
const SURFACE_CARDS: Array = ["chain_bolt", "wildfire_halo", "updraft", "frostbolt"]

func run(probe: SceneTree, instance: Node, sampler: Node) -> Dictionary:
	await probe.call("_settle_action_tracker_prewarm", instance)
	var board: Control = instance.get("board_view") as Control
	var result: Dictionary = {
		"schema_version": 2,
		"workload_id": "surface_input_and_retained_rendering_v2",
		"viewport": "1920x1080", "ui_scale": 1.0,
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"sample_boundary": "RenderingServer.frame_post_draw",
		"sample_frames": SAMPLE_FRAMES,
		"hover": {}, "presentation": {}, "idle": {},
	}
	for card_id: String in SURFACE_CARDS:
		probe.call("_install_stress_combat", instance, "specialists")
		var state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		var hand: Array[String]
		hand.append(card_id)
		for filler: String in ["pale_spark", "shadow_step", "threaded_path", "glowstone_ward", "gust_step", "cinder_fusillade"]:
			if filler != card_id: hand.append(filler)
		(state["deck"] as Dictionary)["hand"] = hand
		# A connected conductor field makes the new shared-ground resolver and
		# route preview do real work, while every card respects the hand cap.
		state["surfaces"] = {}
		for y: int in range(2, 7):
			for x: int in range(2, 7):
				state["surfaces"][Ground.tile_key(Vector2i(x, y))] = {"elemental": "electrified", "rubble": false}
		_assign_state(instance, state)
		await probe.call("_settle_render_frames", 8)
		await probe.call("_settle_action_tracker_prewarm", instance)
		var source: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		var click_ms: float = await probe.call("_select_card", instance, 0)
		var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
		var tiles: Array[Vector2i] = probe.call("_preview_interaction_tiles", instance, preview)
		if tiles.size() > 12: tiles.resize(12)
		probe.call("_expect", not tiles.is_empty(), "%s surface workload needs reachable target tiles" % card_id)
		var entry: Dictionary = {"card_click_handler_ms": click_ms, "target_count": tiles.size(), "target_tiles": tiles, "committed_state_digest": _semantic_combat_digest(source)}
		for temperature: String in ["cold", "warm"]:
			instance.call("set_runtime_performance_instrumentation_enabled", true)
			board.call("reset_render_instrumentation")
			var handler_ms: Array[float]
			var submissions: Array[int]
			var pipeline_before: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)
			sampler.call("begin")
			for sweep: int in range(1 if temperature == "cold" else 3):
				for tile: Vector2i in tiles:
					var started: int = Time.get_ticks_usec()
					probe.call("_board_pointer_hover", instance, tile)
					handler_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
					await probe.call("_await_render_frame")
					submissions.append(_semantic_presentation_digest(board.get("presentation") as Dictionary))
			var phase: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
			phase["handler_ms"] = probe.call("_stats", handler_ms)
			phase["raw_handler_ms"] = handler_ms
			phase["stage_profile"] = instance.call("runtime_performance_instrumentation_snapshot")
			phase["board_profile"] = board.call("render_instrumentation_snapshot")
			phase["canvas_pipeline_compilations"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) - pipeline_before
			entry[temperature] = phase
			if temperature == "cold": entry["presentation_digests"] = submissions
		probe.call("_expect", source == instance.get("_combat_state"), "%s hover must not mutate committed combat" % card_id)
		entry["committed_state_unchanged"] = source == instance.get("_combat_state")
		await probe.call("_save_root_screenshot", "surface_%s_preview.png" % card_id)
		await probe.call("_settle_render_frames", 8)
		(result["hover"] as Dictionary)[card_id] = entry
		instance.call("_cancel_card_selection")

	probe.call("_install_stress_combat", instance, "specialists")
	await probe.call("_settle_action_tracker_prewarm", instance)
	await probe.call("_settle_render_frames", 8)
	var state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
	var base: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	for mode: String in ["sparse_preview", "sparse_feedback", "chain_path"]:
		for warmup: int in range(12):
			_submit(board, state, _presentation(base, mode, warmup))
			await probe.call("_await_render_frame")
		board.call("reset_render_instrumentation")
		sampler.call("begin")
		for frame: int in range(SAMPLE_FRAMES):
			_submit(board, state, _presentation(base, mode, frame))
			await probe.call("_await_render_frame")
		var phase: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
		phase["board_profile"] = board.call("render_instrumentation_snapshot")
		phase["scope"] = "explicit presentation submission; not a player-input benchmark"
		(result["presentation"] as Dictionary)[mode] = phase
		await probe.call("_save_root_screenshot", "surface_%s.png" % mode)
		await probe.call("_settle_render_frames", 8)
		_submit(board, state, base.duplicate(true))
		await probe.call("_settle_render_frames", 8)

	for mode: String in ["rubble", "mixed"]:
		var dense: Dictionary = state.duplicate(true)
		dense["surfaces"] = {}
		for y: int in range(1, 8):
			for x: int in range(1, 8):
				var element: String = "" if mode == "rubble" else ["fire", "ice", "electrified"][posmod(x + y, 3)]
				dense["surfaces"][Ground.tile_key(Vector2i(x, y))] = {"elemental": element, "rubble": mode == "rubble" or posmod(x + y, 2) == 0}
		_submit(board, dense, base.duplicate(true))
		await probe.call("_settle_render_frames", 45)
		board.call("reset_render_instrumentation")
		sampler.call("begin")
		for frame: int in range(SAMPLE_FRAMES): await probe.call("_await_render_frame")
		var phase: Dictionary = probe.call("_sampler_phase_result", sampler.call("finish"))
		phase["board_profile"] = board.call("render_instrumentation_snapshot")
		phase["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
		phase["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		phase["orphan_nodes"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		(result["idle"] as Dictionary)[mode] = phase
		await probe.call("_save_root_screenshot", "surface_dense_%s.png" % mode)
		await probe.call("_settle_render_frames", 8)
	result["focus_observations"] = probe.get("_focus_observation_count")
	result["unfocused_observations"] = probe.get("_unfocused_observation_count")
	result["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	result["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	result["orphan_nodes"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	probe.call("_expect", int(result["orphan_nodes"]) == 0, "Surface workload must leave no orphan nodes")
	probe.call("_expect", int(result["unfocused_observations"]) == 0, "Surface timing must stay in the foreground")
	return result

func _semantic_combat_digest(source: Dictionary) -> int:
	var comparable: Dictionary = source.duplicate(true)
	# The application assigns each isolated probe its own analytics combat ID.
	# Keep all rules/RNG/queue/event data, excluding only that transport identity.
	(comparable.get("analytics", {}) as Dictionary).erase("combat_id")
	return hash(comparable)

func _semantic_presentation_digest(shown: Dictionary) -> int:
	var semantic: Dictionary = {}
	for key: String in ["focus_tiles", "path_tiles", "effect", "damage_preview", "friendly_damage_chips", "surface_preview_events", "surface_preview_arcs", "surface_status_preview"]:
		semantic[key] = shown.get(key)
	return hash(semantic)

func _assign_state(instance: Node, state: Dictionary) -> void:
	instance.set("_combat_state", state)
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["combat_state"] = state
	instance.set("_run_state", run)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")

func _submit(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	# Own every submitted dictionary; never mutate the board's retained snapshot.
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

func _presentation(base: Dictionary, mode: String, frame: int) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	var tile: Vector2i = Vector2i(2, 2) if frame % 2 == 0 else Vector2i(6, 6)
	if mode == "sparse_preview":
		result["surface_preview_events"] = [{"kind": "surface_created", "surface": "ice", "tile": tile}]
	elif mode == "sparse_feedback":
		result["surface_feedback_events"] = [{"kind": "surface_created", "surface": "fire", "tile": Vector2i(2, 2)}]
		result["surface_feedback_progress"] = float(frame % 18) / 18.0
	else:
		result["effect"] = {"kind": "chain", "element": "lightning", "path": [Vector2i(1, 2), Vector2i(5, 6), Vector2i(7, 3)]}
		result["effect_progress"] = float(frame % 18) / 18.0
	return result
