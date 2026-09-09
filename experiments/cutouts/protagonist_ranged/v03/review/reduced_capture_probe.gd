extends "res://tests/protagonist_ranged_gameplay_probe.gd"
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = DisplayServer.get_name() != "headless"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_OUTPUT))
	ProgressionStore.set_storage_path("user://ranged_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://ranged_probe_run.save")
	ProgressionStore.clear_saved_run()
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_render_viewport = root
	if _capture:
		var surface := SubViewport.new()
		surface.size = SIZE
		surface.disable_3d = true
		surface.world_2d = World2D.new()
		surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		_render_viewport = surface
	_render_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	_texture_id = int(_snapshot()["texture_id"])
	await _play_ranged("guiding_flare", "reduced_cast", Vector2i(0,-2), 37, true)
	await _play_ranged("pale_spark", "reduced_shoot", Vector2i(-2,0), 37, true)
	var file := FileAccess.open(PROOF_OUTPUT + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"records":_ranged_records,"errors":_errors},"\t"))
	file.close()
	_instance.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	print("PROTAGONIST RANGED GAMEPLAY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(PROOF_OUTPUT))
	quit(0 if _errors.is_empty() else 1)
