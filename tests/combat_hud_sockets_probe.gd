extends "res://tests/combat_hud_sockets_test.gd"

const OUTPUT: String = "user://probes/combat_hud_sockets"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("COMBAT HUD SOCKETS PROBE requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == SIZE, "Captures must be native 1920x1080 SubViewport images")
	if image != null:
		_expect(image.save_png("%s/%s.png" % [OUTPUT, label]) == OK, "Capture should save")

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT))
	print("COMBAT HUD SOCKETS PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
