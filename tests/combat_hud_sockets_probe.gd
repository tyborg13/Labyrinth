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
		if label == "05_boss_wrapped_relics_charge":
			for node: Node in _viewport.find_children("*", "Button", true, false):
				if node is Socket and node.has_meta("relic_id"):
					_assert_accent_pixels(image, node as Socket)
			_assert_accent_pixels(image, _viewport.get_child(0).get("_defiance_badge") as Socket)
		if label == "08_spent_defiance_controller_inspection":
			_assert_accent_pixels(image, _viewport.get_child(0).get("_defiance_badge") as Socket)
		if label == "09_ready_spent_skill_status_rings":
			_assert_status_pixels(image, "SkillSigilPreview_ghost_stride", Palette.TEXT_3)
			_assert_status_pixels(image, "SkillSigilPreview_quick_wits", Palette.ALLY)
		if label in ["10_rite_controller_inspection", "14_accent_with_inner_status"]:
			var rite := _viewport.find_child("ActiveRite_0", true, false) as Socket
			_assert_accent_pixels(image, rite)
			if label == "14_accent_with_inner_status":
				_assert_ring_pixels(image, rite, Palette.ALLY, _accent_radius(rite) - 2.0, "inset status")
		_expect(image.save_png("%s/%s.png" % [OUTPUT, label]) == OK, "Capture should save")

func _accent_radius(socket: Socket) -> float:
	return socket._ring_radius(Rect2(Vector2.ZERO, socket.size), "inner_radius") - 1.0

func _assert_accent_pixels(image: Image, socket: Socket) -> void:
	_expect(socket != null and socket.is_visible_in_tree(), "Accent proof must render a visible socket")
	if socket != null:
		_assert_ring_pixels(image, socket, Color(socket.accent_color, 0.9), _accent_radius(socket), "accent")

func _assert_status_pixels(image: Image, node_name: String, color: Color) -> void:
	var socket := _viewport.find_child(node_name, true, false) as Socket
	_expect(socket != null and socket.is_visible_in_tree(), "Status proof must render a visible preview socket")
	if socket == null:
		return
	_assert_ring_pixels(image, socket, color, _accent_radius(socket), "status")

func _assert_ring_pixels(image: Image, socket: Socket, color: Color, radius: float, role: String) -> void:
	var rect := Rect2i(socket.get_global_rect())
	var center: Vector2 = socket.get_global_rect().get_center()
	var matching: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if absf((Vector2(x, y) + Vector2.ONE * 0.5).distance_to(center) - radius) > 0.65:
				continue
			var pixel: Color = image.get_pixel(x, y)
			if absf(pixel.r - color.r * color.a) + absf(pixel.g - color.g * color.a) + absf(pixel.b - color.b * color.a) < 0.16:
				matching += 1
	if matching < 12:
		print("SOCKET RING PIXEL PROOF: ", socket.name, " role=", role, " rect=", rect, " matching=", matching)
	_expect(matching >= 12, "Rendered %s must show its %s ring at the specified radius" % [socket.name, role])

func _finish() -> void:
	print(ProjectSettings.globalize_path(OUTPUT))
	print("COMBAT HUD SOCKETS PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
