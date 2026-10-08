extends "res://tests/runtime_frame_performance_benchmark.gd"

# Diagnostic lane: separate CPU decode, upload submission, and synchronous
# readback. This probe never supplies the game's completed-draw comparison.
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	_render_pulse = RenderPulse.new()
	_render_pulse.size = Vector2.ONE
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_render_pulse)
	await _acquire_probe_window_focus()
	await _settle_render_frames(4)
	var results: Array[Dictionary]
	for path: String in [
		"res://assets/art/ui/section_map/medallion.png",
		"res://assets/art/ui/section_map/panel_frame.png",
		"res://assets/art/effects/ambient_air_wisp_glow_frames.png",
		"res://assets/art/icons/map/scavenger.png",
	]:
		if not FileAccess.file_exists(path): continue
		await _settle_render_frames(3)
		var started: int = Time.get_ticks_usec()
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var read_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		var pixels := Image.new()
		started = Time.get_ticks_usec()
		var error: Error = pixels.load_png_from_buffer(bytes)
		var decode_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		_expect(error == OK, "Diagnostic asset must decode: " + path)
		started = Time.get_ticks_usec()
		var texture: ImageTexture = ImageTexture.create_from_image(pixels)
		var upload_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		var returned: Image = texture.get_image()
		var readback_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		_expect(returned.get_data() == pixels.get_data(), "Diagnostic readback must retain exact source pixels")
		results.append({"path": path, "dimensions": str(pixels.get_size()), "bytes": bytes.size(), "read_ms": read_ms, "decode_ms": decode_ms, "upload_ms": upload_ms, "immediate_readback_ms": readback_ms})
	print("ASSET LOADING DETAIL RESULT: " + JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "viewport": "1920x1080", "results": results, "errors": _errors}))
	quit(0 if _errors.is_empty() else 1)
