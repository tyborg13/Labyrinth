extends "res://tests/event_view_probe.gd"
## Owner-run windowed proof of the exact Hunted copy on the production HUD.
const TUNE_PROOF_DIRECTORY: String = "user://tune01_proof"
func _probe() -> void:
	Settings.set_storage_path("user://tune01_proof_settings.json")
	Store.set_storage_path("user://tune01_proof_profile.json")
	Store.set_run_storage_path("user://tune01_proof.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	root.size = PROOF_SIZE
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(PROOF_READY_FRAMES):
		if bool(_scene.call("initial_presentation_is_ready")): break
		await process_frame
	_expect(bool(_scene.call("initial_presentation_is_ready")), "Production HUD prepared")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TUNE_PROOF_DIRECTORY))
	await _present(Suite.combat_fixture())
	var manager: RefCounted = _scene.get("_omen_badges")
	_expect(manager.badges.has("hunted"), "Hunted production badge present")
	if manager.badges.has("hunted"):
		manager.badges["hunted"].grab_focus()
		await process_frame
		await _capture("hunted_focus.png")
		settings["reduced_motion"] = true
		Settings.save_settings(settings)
		_scene.call("_on_settings_changed", settings)
		await process_frame
		await _capture("hunted_reduced_motion.png")
	for failure: String in _failures: push_error(failure)
	print("TUNE01_HUNTED_PROBE: %d failures" % _failures.size())
	print("TUNE01_CAPTURES: " + ProjectSettings.globalize_path(TUNE_PROOF_DIRECTORY))
	_scene.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)
func _capture(filename: String, _event_id: String = "") -> void:
	for frame: int in range(PROOF_POST_DRAW_FRAMES): await RenderingServer.frame_post_draw
	var capture: Image = _viewport.get_texture().get_image()
	_expect(capture.get_size() == PROOF_SIZE, "1920x1080 capture")
	_expect(capture.save_png(TUNE_PROOF_DIRECTORY.path_join(filename)) == OK, "Capture writes " + filename)
