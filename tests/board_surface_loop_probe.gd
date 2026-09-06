extends "res://tests/board_surface_visual_probe.gd"

# Deterministic real-renderer frames for reviewing ground motion at native scale.
func _initialize() -> void:
	ground_loop_only = true
	await super._initialize()

func _capture(name: String, settle_frames: int = 8) -> void:
	if name != "01_mixed_ground": return
	await super._capture(name, settle_frames)
	var output: String = OUTPUT.path_join("loop")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var board: Control = scene.get("board_view") as Control
	for frame: int in range(48):
		var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
		shown["ambient_time_seconds"] = 12.0 + float(frame) / 24.0
		board.call("set_combat_state", board.get("combat_state"), [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = view.get_texture().get_image()
		assert(screenshot.save_png(ProjectSettings.globalize_path(output.path_join("frame_%03d.png" % frame))) == OK)
	print("BOARD SURFACE LOOP PROBE: PASS")
	print(ProjectSettings.globalize_path(output))
