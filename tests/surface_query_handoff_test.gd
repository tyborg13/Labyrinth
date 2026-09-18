extends "res://tests/runtime_frame_performance_benchmark.gd"

# Exercise the actual surface-ability coroutine and durable boundary. Frame
# timings here are intentionally not used as performance evidence.
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	OS.set_environment("LABYRINTH_RUNTIME_PERF_CAPPED_HAND", "1")
	ProgressionStore.set_storage_path("user://surface_query_profile.json")
	ProgressionStore.set_run_storage_path("user://surface_query_run.save")
	_profiled_initial_refresh = true
	call_deferred("_surface_proof")

func _surface_proof() -> void:
	var rows: Array[Dictionary]
	for mode: String in ["normal", "reduced", "cancelled_preparation"]:
		ProgressionStore.clear_saved_run()
		var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
		root.add_child(instance)
		await process_frame
		await process_frame
		_install_stress_combat(instance, "specialists")
		var settings: Dictionary = instance.get("_settings") as Dictionary
		settings["reduced_motion"] = mode == "reduced"
		_prepare_manual_skill_state(instance, "prismatic_instinct")
		instance.call("_begin_surface_skill_selection", "prismatic_instinct")
		instance.call("_choose_surface_skill_kind", "ice")
		var tiles: Array[Vector2i] = instance.get("_surface_skill_tiles")
		_expect(not tiles.is_empty(), "Surface proof needs a legal authored target")
		if tiles.is_empty(): break
		var tile: Vector2i = tiles[0]
		var before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		var expected: Dictionary = _combat.use_surface_skill(before, "prismatic_instinct", "ice", tile)
		_expect(expected != before, "The surface action must have a real effect")
		# Include the scene's existing analytics cursor staging, as the complete
		# enemy-round oracle does. Restore progression after oracle construction.
		var progression_before: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
		var staged: Dictionary = instance.call("_stage_combat_skill_event_analytics_for_state", instance.get("_run_state"), expected)
		expected = _combat.normalize_player_movement_pool(staged.get("combat_state", {}))
		instance.set("_progression", progression_before)
		_expect(ProgressionStore.save_run_state(instance.get("_run_state")), "Pre-action save succeeds")
		var disk_before: Dictionary = ProgressionStore.load_saved_run()
		instance.call("set_runtime_performance_instrumentation_enabled", true)
		instance.call("_commit_surface_skill_tile", tile)
		_expect(bool(instance.get("_animation_lock")), "Surface animation still starts before commit")
		_expect(instance.get("_combat_state") == before and ProgressionStore.load_saved_run() == disk_before, "Scheduling does not publish or save the future state")
		var frames: int = 0
		while bool(instance.get("_animation_lock")) and frames < 1000:
			if mode == "cancelled_preparation": instance.call("_cancel_committed_hand_queries")
			_expect(instance.get("_combat_state") == before, "The old committed state remains live throughout the animation")
			await process_frame
			frames += 1
		_expect(not bool(instance.get("_animation_lock")), "Surface animation completes within the bounded frame guard")
		var actual: Dictionary = instance.get("_combat_state") as Dictionary
		var differences: Array[String]
		for key: String in expected:
			if actual.get(key) != expected[key]: differences.append(key)
		for key: String in actual:
			if not expected.has(key): differences.append(key)
		_expect(actual == expected, "Surface commit equals the complete engine result: " + str(differences))
		var disk_after: Dictionary = ProgressionStore.load_saved_run()
		_expect(disk_after != disk_before and disk_after.get("combat_state") == expected, "The authored post-animation boundary durably saves the complete result")
		var stats: Dictionary = instance.call("committed_hand_query_instrumentation_snapshot")
		if mode == "cancelled_preparation":
			_expect(int(stats.get("adopted_cards", 0)) == 0, "Cancelled preparation uses the ordinary synchronous fallback")
		else:
			_expect(int(stats.get("adopted_cards", 0)) > 0, "The real surface caller adopts prepared cards")
		rows.append({"mode": mode, "frames": frames, "queries": stats, "mismatched_state_keys": differences})
		instance.queue_free()
		await process_frame
		await process_frame
	print("SURFACE QUERY HANDOFF RESULT: " + JSON.stringify({"cases": rows, "errors": _errors}))
	print("TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)
