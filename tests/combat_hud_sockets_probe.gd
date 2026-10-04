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
		if label == "12_ready_spent_skill_status_rings":
			_assert_status_pixels(image, "SkillSigilPreview_ghost_stride", Palette.TEXT_3)
			_assert_status_pixels(image, "SkillSigilPreview_quick_wits", Palette.ALLY)
		_expect(image.save_png("%s/%s.png" % [OUTPUT, label]) == OK, "Capture should save")

func _assert_status_pixels(image: Image, node_name: String, color: Color) -> void:
	var socket: Control = _viewport.find_child(node_name, true, false) as Control
	_expect(socket != null and socket.is_visible_in_tree(), "Status proof must render a visible preview socket")
	if socket == null:
		return
	var rect := Rect2i(socket.get_global_rect())
	var matching: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var pixel: Color = image.get_pixel(x, y)
			if absf(pixel.r - color.r) + absf(pixel.g - color.g) + absf(pixel.b - color.b) < 0.12:
				matching += 1
	if matching < 12:
		print("STATUS PIXEL PROOF: ", node_name, " rect=", rect, " matching=", matching, " parent=", socket.get_parent().get_global_rect())
	_expect(matching >= 12, "Rendered %s must show its status-colored inner ring" % node_name)

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT))
	print("COMBAT HUD SOCKETS PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
