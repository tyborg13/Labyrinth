extends "res://tools/hitch_census/driver.gd"

const SCREENSHOT: String = "tharokh-combat-1920.png"

func mark(label: String, stage: String = "action") -> void:
	super.mark(label, stage)
	if label == "tharokh" and stage == "tour_visible": _capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		errors.append("Combat texture visual proof requires a native renderer")
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1920, 1080) or not is_equal_approx(root.content_scale_factor, 1.0):
		errors.append("Combat texture visual proof requires 1920×1080 at 100% UI scale")
		return
	var path: String = output.path_join(SCREENSHOT)
	if image.save_png(path) != OK:
		errors.append("Could not write " + path)
		return
	print(path)
	print("PERF-161 VISUAL PROOF: PASS 1920x1080 scale=1.0")
