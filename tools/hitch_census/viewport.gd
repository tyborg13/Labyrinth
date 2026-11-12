extends RefCounted
## Window ViewportTexture.get_size() includes canvas stretch in Godot 4.6.1.
## The backing image dimensions are the renderer's pixels. Read once at startup.
## See viewport.cpp:145-173 and window.cpp:1138-1249 in Godot 4.6.1-stable.
const TARGET_SIZE := Vector2i(1280, 800)
const TARGET_UI_SCALE: float = 1.15

static func capture(window: Window) -> Dictionary:
	var native: bool = DisplayServer.get_name() != "headless"
	var started: int = Time.get_ticks_usec()
	var pixels := Vector2i.ZERO
	var readback_ok: bool = false
	var texture: ViewportTexture = window.get_texture()
	var reported_size := Vector2i(texture.get_size())
	var stretch: Vector2 = window.get_stretch_transform().get_scale()
	if native:
		# get_image() reads texture_rid directly; get_size() multiplies by stretch.
		# This single readback happens before any gameplay scene is instantiated.
		var backing: Image = texture.get_image()
		if backing != null and not backing.is_empty():
			pixels = backing.get_size()
			readback_ok = true
	return {
		"native": native,
		"pixel_measurement_version": 2,
		"root_texture_reported_size": [reported_size.x, reported_size.y],
		"canvas_stretch_scale": [stretch.x, stretch.y],
		"startup_capture_us": Time.get_ticks_usec() - started,
		"root_pixel_size": [pixels.x, pixels.y] if readback_ok else null,
		"backing_readback_ok": readback_ok,
		"root_size": [window.size.x, window.size.y],
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"content_scale": window.content_scale_factor,
		"content_scale_size": [window.content_scale_size.x, window.content_scale_size.y],
		"content_scale_mode": window.content_scale_mode,
		"hidpi_allowed": ProjectSettings.get_setting("display/window/dpi/allow_hidpi", true),
		"screen_scale": DisplayServer.screen_get_scale() if native else null,
		"window_mode": window.mode,
		"pixel_size_source": "ViewportTexture.get_image().get_size(): renderer backing image, one startup readback" if native else "unavailable with headless renderer",
	}

static func validate(snapshot: Dictionary) -> Dictionary:
	var failure: String = ""
	var ratio: Variant = null
	if bool(snapshot["native"]) and snapshot.get("root_pixel_size") == null:
		failure = "Renderer backing image is unavailable"
	elif bool(snapshot["native"]):
		var pixels: Array = snapshot["root_pixel_size"]
		var count: int = int(pixels[0]) * int(pixels[1])
		var target: int = TARGET_SIZE.x * TARGET_SIZE.y
		ratio = float(count) / float(target)
		if Vector2i(int(pixels[0]), int(pixels[1])) != TARGET_SIZE:
			failure = "Rendered backing image is not exactly 1280x800"
	if not is_equal_approx(float(snapshot["content_scale"]), TARGET_UI_SCALE):
		failure += ("; " if not failure.is_empty() else "") + "UI scale is not 1.15"
	return {"pixel_count_ratio": ratio, "failure": failure,
		"status": "rejected" if not failure.is_empty() else ("passed" if bool(snapshot["native"]) else "headless_render_unverified")}
