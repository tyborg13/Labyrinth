extends "res://tools/cutout_pipeline/preview.gd"

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--interactive"):
		push_error("Input probe requires --interactive and --case")
		quit(1)
		return
	await super._run()
	await _draw()
	viewer.set_playing(false)
	viewer.show_frame(0)
	# Actual input dispatch through the interactive root/container/viewport.
	var click := InputEventMouseButton.new()
	click.position = Vector2(844, 151)
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click.pressed = false
	root.push_input(click)
	await _draw()
	_check(viewer.frame_index == 1 and not viewer.playing, "Pointer step forwards through SubViewportContainer")
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right)
	right.pressed = false
	root.push_input(right)
	await _draw()
	_check(viewer.frame_index == 2, "Right arrow steps while a button has focus")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	space.pressed = false
	root.push_input(space)
	await _draw()
	_check(viewer.playing, "Space resumes playback")
	viewer.set_playing(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var result_path: String = OUTPUT.path_join("input_result.json")
	var f := FileAccess.open(result_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok": failures.is_empty(), "frame": viewer.frame_index, "errors": failures}))
	f.close()
	print("Saved ", ProjectSettings.globalize_path(result_path))
	print("CUTOUT_INPUT: ", failures)
	quit(0 if failures.is_empty() else 1)
