extends "res://tests/runtime_frame_performance_benchmark.gd"

# This deliberately reports section CPU timings only. A headless renderer cannot
# measure display pacing, GPU cost, native card raster caching or visual quality.
func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("CPU attribution requires --headless; use runtime_frame for native pacing")
		quit(1)
		return
	ParallelRuntime.apply_from_environment()
	root.size = DEFAULT_VIEWPORT_SIZE
	Engine.max_fps = 120
	OS.low_processor_usage_mode = false
	ProgressionStore.set_storage_path("user://cpu_attribution_progression.json")
	ProgressionStore.set_run_storage_path("user://cpu_attribution_run.save")
	ProgressionStore.clear_saved_run()
	var settings_store = load("res://scripts/settings_store.gd")
	settings_store.set_storage_path("user://cpu_attribution_settings.json")
	var settings: Dictionary = settings_store.default_settings()
	settings["reduced_motion"] = OS.get_environment("LABYRINTH_RUNTIME_PERF_REDUCED_MOTION") == "1"
	settings_store.save_settings(settings)
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await _settle_frames(8)
	_profiled_initial_refresh = true
	var results: Dictionary = {}
	for card_id: String in ["shadow_step", "gust_step", "wildfire_halo"]:
		_install_stress_combat(instance, "specialists")
		await _settle_frames(12)
		var before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		await instance.call("_on_card_pressed", _hand_index(instance, card_id))
		await _settle_frames(2)
		CardWidget.set_layout_instrumentation_enabled(true)
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		for step: int in range(MAX_PREVIEW_STEPS):
			if bool(instance.call("_pending_card_requires_confirmation")):
				await instance.call("_on_confirm_card_play_pressed")
				break
			var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
			if preview.is_empty(): break
			var targets: Array[Vector2i] = _preview_interaction_tiles(instance, preview)
			if targets.is_empty():
				if bool(instance.call("_current_action_can_skip")):
					await instance.call("_on_skip_action_pressed")
				else: break
			else:
				await instance.call("_on_board_tile_clicked", _preferred_target(instance, targets))
			await _settle_frames(2)
		await _settle_frames(2)
		_expect(before != (instance.get("_combat_state") as Dictionary), card_id + " must commit its action")
		_expect(not bool(instance.get("_animation_lock")), card_id + " must finish with input available")
		results[card_id] = {
			"card_layout_profile": CardWidget.layout_instrumentation_snapshot(),
			"committed_hand_queries": instance.call("committed_hand_query_instrumentation_snapshot") if instance.has_method("committed_hand_query_instrumentation_snapshot") else {},
			"stage_profile": instance.call("runtime_performance_instrumentation_snapshot"),
			"stage_frame_profile": instance.call("runtime_performance_frame_instrumentation_snapshot"),
		}
		CardWidget.set_layout_instrumentation_enabled(false)
		instance.call("set_runtime_performance_instrumentation_enabled", false)
	print("ACTION CPU ATTRIBUTION RESULT: " + JSON.stringify({
		"workload_id": "headless_combat_action_cpu_v2", "hand": _workload_hand(), "hand_size": _workload_hand().size(), "measurement": "instrumented CPU sections only; no rendered frame measurements",
		"reduced_motion": bool(settings["reduced_motion"]), "cards": results, "semantic_errors": _errors,
	}))
	instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)
