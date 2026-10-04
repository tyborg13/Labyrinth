extends "res://tests/combat_hud_badges_test.gd"

const OUTPUT: String = "user://probes/combat_hud_badges"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("COMBAT HUD BADGES PROBE requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == SIZE, "Captures must be native 1920x1080 SubViewport images")
	if image == null:
		return
	if label in ["05_boss_wrapped_relics_charge", "14_boss_relics_rites_spent_defiance"]:
		var grid := _viewport.get_child(0).get("_relic_icon_grid") as Control
		for frame: Control in grid.get_children():
			_assert_badge_pixels(image, frame)
	if label == "09_ready_spent_skill_status_borders":
		for name: String in ["SkillSigilPreview_ghost_stride", "SkillSigilPreview_quick_wits"]:
			_assert_border_pixels(image, _viewport.find_child(name, true, false) as Control)
	_expect(image.save_png("%s/%s.png" % [OUTPUT, label]) == OK, "Capture should save")

func _assert_border_pixels(image: Image, frame: Control) -> void:
	var color: Color = (frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var rect := Rect2i(frame.get_global_rect())
	var matching: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if not Rect2(rect).grow(-2.0).has_point(Vector2(x, y)) and _color_distance(image.get_pixel(x, y), color) < 0.12:
				matching += 1
	_expect(matching >= 12, "Rendered %s must preserve its master accent/status border" % frame.name)

func _assert_badge_pixels(image: Image, frame: Control) -> void:
	_assert_border_pixels(image, frame)
	if not frame.has_meta("relic_id"):
		return
	var background: Image = (frame.get_meta(Background.TEXTURE_META) as Texture2D).get_image()
	var rect := Rect2i(frame.get_global_rect())
	var matching: int = 0
	# This band is inside the border and outside master's icon margin.
	for y: int in range(10, rect.size.y - 10):
		for x: int in range(3, 8):
			if _color_distance(image.get_pixel(rect.position.x + x, rect.position.y + y), background.get_pixel(x, y)) < 0.12:
				matching += 1
	_expect(matching >= 30, "Rendered %s must show the cached accent pool behind its unobscured icon" % frame.get_meta("relic_id"))

func _color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT))
	print("COMBAT HUD BADGES PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
