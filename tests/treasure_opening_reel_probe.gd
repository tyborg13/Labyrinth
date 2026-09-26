extends "res://tests/treasure_presentation_probe.gd"

const REEL_OUTPUT: String = "user://probes/treasure_opening_reel"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	SettingsStore.set_storage_path("user://treasure_settings.json")
	ProgressionStore.set_storage_path("user://treasure_progression.json")
	ProgressionStore.set_run_storage_path("user://treasure_run.save")
	ProgressionStore.clear_saved_run()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REEL_OUTPUT))
	_proof_viewport = SubViewport.new()
	_proof_viewport.size = Vector2i(1920, 1080)
	_proof_viewport.msaa_2d = Viewport.MSAA_4X
	_proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_proof_viewport)
	_treasure_scene = load("res://scenes/run_scene.tscn").instantiate()
	_proof_viewport.add_child(_treasure_scene)
	await create_timer(0.25).timeout
	var engine := RunEngine.new()
	var base: Dictionary = engine.create_new_run(7321, profile)
	var treasure: Dictionary = _run_state_for_room(engine, base, _first_room_coord_of_type(engine, base, "treasure"), "treasure", Vector2i(1, 0))
	treasure["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	_treasure_scene.call("_load_run_state", treasure)
	_treasure_scene.call("_close_dialogue")
	_treasure_scene.call("_close_large_map")
	var images: Array[Image]
	var times := PackedFloat64Array()
	var start: int = Time.get_ticks_usec()
	var previous: float = -1.0
	var settled_at: float = -1.0
	while true:
		await RenderingServer.frame_post_draw
		var elapsed: float = float(Time.get_ticks_usec() - start) / 1000000.0
		if elapsed - previous >= 1.0 / 30.0:
			images.append(_proof_viewport.get_texture().get_image())
			times.append(elapsed)
			previous = elapsed
		if not bool(_treasure_scene.get("_treasure_reveal_active")) and settled_at < 0.0:
			settled_at = elapsed
		if (settled_at >= 0.0 and elapsed - settled_at >= 0.4) or elapsed > 2.5:
			break
	_expect_treasure(settled_at > 0.0 and _choices().get_child_count() == 3, "Recorded opening finishes before relic options")
	var frames: Array[Dictionary]
	for index: int in range(images.size()):
		var path: String = ProjectSettings.globalize_path(REEL_OUTPUT.path_join("frame_%03d.png" % index))
		_expect_treasure(images[index].get_size() == Vector2i(1920, 1080), "Reel preserves native 1920x1080")
		images[index].save_png(path)
		frames.append({"path": path, "seconds": times[index]})
	var output := FileAccess.open(REEL_OUTPUT.path_join("timing.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"frames": frames, "options_visible_seconds": settled_at, "capture": "Actual production tween, real renderer, wall-clock sample timestamps"}, "\t"))
	output.close()
	images.clear()
	_treasure_scene.queue_free()
	await process_frame
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	for failure: String in _treasure_failures:
		push_error(failure)
	print(ProjectSettings.globalize_path(REEL_OUTPUT))
	print("TREASURE OPENING REEL: %s" % ("PASS" if _treasure_failures.is_empty() else "FAIL"))
	quit(0 if _treasure_failures.is_empty() else 1)
