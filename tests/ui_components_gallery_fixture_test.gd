extends "res://tests/ui_components_gallery_probe.gd"

# Validate the gallery's fixture under headless without capturing an image.
# Visual acceptance still requires the real-renderer gallery probe.
func _run() -> void:
	_build_gallery()
	await process_frame
	await process_frame
	_assert_gallery()
	_sockets[2].grab_focus()
	await _hover(_sockets[1])
	_check(_sockets[1].is_hovered() and _sockets[2].has_focus(), "Socket fixture must support native hover and focus")
	_strips[2].grab_focus()
	await _hover(_strips[1])
	_check(_strips[1].is_hovered() and _strips[2].has_focus(), "Strip fixture must support native hover and focus")
	for row: int in range(3):
		var focused: Button = _socket_grid[Vector2i(2, row)] as Button
		var hovered: Button = _socket_grid[Vector2i(1, row)] as Button
		focused.grab_focus()
		await _hover(hovered)
		_check(focused.has_focus() and hovered.is_hovered(), "Every socket size must show native hover and focus")
	print("TEST RESULT: FAIL ui_components_gallery_fixture" if _failed else "TEST RESULT: PASS ui_components_gallery_fixture")
	quit(1 if _failed else 0)
