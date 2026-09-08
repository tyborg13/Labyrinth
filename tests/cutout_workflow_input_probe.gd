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
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	motion.global_position = click.global_position
	root.push_input(motion, true)
	await _draw()
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await _draw()
	_check(viewer.frame_index == 1 and not viewer.playing, "Pointer step forwards through SubViewportContainer")
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right, true)
	right.pressed = false
	root.push_input(right, true)
	await _draw()
	_check(viewer.frame_index == 2, "Right arrow steps while a button has focus")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	space.pressed = false
	root.push_input(space, true)
	await _draw()
	_check(viewer.playing, "Space resumes playback")
	viewer.set_playing(false)
	var nonloop: String = ""
	for clip: String in viewer.rig.config["clips"]:
		if not bool(viewer.rig.config["clips"][clip]["loop"]):
			nonloop = clip
			break
	_check(not nonloop.is_empty(), "Input fixture needs a nonlooping clip to check replay")
	if not nonloop.is_empty():
		viewer.select(viewer.rig.facing, nonloop)
		viewer.set_playing(true)
		viewer._process(float(viewer.rig.config["clips"][nonloop]["duration"]) + 0.02)
		var last_frame: int = int(viewer.rig.config["clips"][nonloop]["frames"]) - 1
		_check(not viewer.playing and viewer.frame_index == last_frame, "Nonlooping action stops at its last frame")
		_check(viewer.status.text.ends_with("Paused") and viewer.pause_button.text == "Play", "Playback status updates immediately")
		await _draw()
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = viewer.pause_button.get_global_rect().get_center()
		click.global_position = click.position
		motion = InputEventMouseMotion.new()
		motion.position = click.position
		motion.global_position = click.global_position
		root.push_input(motion, true)
		await _draw()
		click.pressed = true
		root.push_input(click, true)
		click.pressed = false
		root.push_input(click, true)
		_check(viewer.playing and viewer.frame_index == 0, "Pointer Play restarts a completed action: playing=%s frame=%d click=%s" % [viewer.playing, viewer.frame_index, click.position])
		viewer.set_playing(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var result_path: String = OUTPUT.path_join("input_result.json")
	var f := FileAccess.open(result_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok": failures.is_empty(), "frame": viewer.frame_index, "errors": failures}))
	f.close()
	print("Saved ", ProjectSettings.globalize_path(result_path))
	print("CUTOUT_INPUT: ", failures)
	quit(0 if failures.is_empty() else 1)
