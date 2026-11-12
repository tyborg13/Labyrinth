extends "res://tools/hitch_census/driver.gd"
## Owner-only renderer proof. prepare_capture.py sets the census copy to 1080p/100%.
const CAPTURE_SETTLE_FRAMES: int = 60
var room_ready_frame: int = -1
var map_ready_frame: int = -1
var room_saved: bool = false
var map_saved: bool = false

func _process(delta: float) -> bool:
	if DisplayServer.get_name() == "headless":
		push_error("PERF126 CAPTURE: requires the owner's window server")
		quit(2)
		return false
	if current_scene != null and current_scene.has_method("_committed_run_state"):
		if not room_saved:
			if room_ready_frame < 0: room_ready_frame = Engine.get_process_frames()
			if Engine.get_process_frames() - room_ready_frame >= CAPTURE_SETTLE_FRAMES:
				room_saved = true
				_save.call_deferred("first-room.png")
		var map: Control = current_scene.get("_large_map_scrim") as Control
		if map != null and map.is_visible_in_tree() and not map_saved:
			if map_ready_frame < 0: map_ready_frame = Engine.get_process_frames()
			if Engine.get_process_frames() - map_ready_frame >= CAPTURE_SETTLE_FRAMES:
				map_saved = true
				_save.call_deferred("section-map.png")
	return super._process(delta)

func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var map: Control = current_scene.get("_large_map_scrim") as Control
	var map_visible: bool = map != null and map.is_visible_in_tree()
	if (file == "first-room.png" and map_visible) or (file == "section-map.png" and not map_visible):
		push_error("PERF126 CAPTURE: scene changed before capture " + file)
		quit(1)
		return
	var image: Image = root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1920, 1080) or image.save_png(output.path_join(file)) != OK:
		push_error("PERF126 CAPTURE: invalid image " + file)
		quit(1)
		return
	print("PERF126 CAPTURE: " + output.path_join(file))
	if file == "section-map.png": finish("capture_complete")
