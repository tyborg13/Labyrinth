extends "res://tools/ptf08/defect_checks.gd"

const D5_SETTINGS = preload("res://scripts/settings_store.gd")
const D5_TYPOGRAPHY = preload("res://scripts/ui_typography.gd")
const D5_SIZE := Vector2i(1920, 1080)
const D5_UI_SCALE: float = 1.0
const D5_IMAGE: String = "res://output/gfix-15/d5_brace_pending_1920x1080.png"

func _initialize() -> void:
	_initialize_test_storage()
	var settings: Dictionary = D5_SETTINGS.default_settings()
	settings["ui_scale"] = D5_UI_SCALE
	settings["display_mode"] = "windowed"
	D5_SETTINGS.save_settings(settings)
	root.size = D5_SIZE
	root.content_scale_size = D5_SIZE
	var canvas := SubViewport.new()
	canvas.size = D5_SIZE
	canvas.msaa_2d = root.msaa_2d
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = preload("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	await install("brace", 14)
	await select_brace_with_pointer(canvas)
	var panel: Control = chip().get_node("PassForecastFocusTooltip")
	var rows: String = d5_panel_rows(panel)
	var bounds: Rect2 = panel.get_global_rect()
	_assert(bool(scene.call("_pending_card_requires_confirmation")), "D5 capture has Brace pending via pointer input")
	_assert(panel.is_visible_in_tree() and is_equal_approx(panel.modulate.a, 1.0), "D5 capture shows the fully visible panel")
	_assert(canvas.size == D5_SIZE and is_equal_approx(D5_TYPOGRAPHY.ui_scale(scene), D5_UI_SCALE), "D5 capture is 1920x1080 at 100% UI scale")
	_assert(bounds.has_area() and Rect2(Vector2.ZERO, Vector2(D5_SIZE)).encloses(bounds), "D5 capture fits the full Pass panel")
	_assert(chip().disabled and rows == "time:+5 | block:−5", "D5 capture shows the confirmation forecast beside disabled Pass")
	if DisplayServer.get_name() != "headless" and _failures.is_empty():
		await RenderingServer.frame_post_draw
		var path: String = ProjectSettings.globalize_path(D5_IMAGE)
		var directory_ready: bool = DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK
		var image: Image = canvas.get_texture().get_image()
		var saved: bool = directory_ready and image != null and image.get_size() == D5_SIZE and image.save_png(path) == OK
		_assert(saved, "D5 capture writes a native PNG")
		if saved: print(path)
	print("D5 CAPTURE rows=", rows, " panel_bounds=", bounds)
	scene.queue_free()
	await process_frame
	for failure: String in _failures: print("FAIL: " + failure)
	print("D5 CAPTURE RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
