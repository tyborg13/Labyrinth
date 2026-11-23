extends "res://tools/fx25/native_capture.gd"
## Capture the existing two resolver fixtures with the same sampling clock and camera.

const TAKES35: Array[String] = ["area_ranged", "closing_shade"]
const CROP_100MS_TICK := 6
const CROP_ZOOM := 2

func _take() -> void:
	var output: String = _arg("--out")
	var id: String = _arg("--case")
	var plan: bool = OS.get_cmdline_user_args().has("--plan")
	if id not in TAKES35 or output.is_empty() or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx35/native.sh to capture a Shadow take.")
		return
	if plan:
		_install_headless_clock()
	elif DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS:
		_fail("Native FX-35 proof requires the 60 fps MovieWriter clock.")
		return
	for sheet: Dictionary in Fx.metadata()["sizes"]:
		var path: String = sheet["atlas"]
		var source: Image = Image.load_from_file(path)
		if source == null or ResourceLoader.exists(path):
			_fail("Expected the staged source atlas at " + path)
			return
		source.convert(Image.FORMAT_L8)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(source.get_data())
		if digest.finish().hex_encode() != sheet["sha256_pixels"]:
			_fail("Wrong staged atlas pixels at " + path)
			return
	var report: Dictionary = await take_case(id, output, "", plan)
	if not report.is_empty(): quit()

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var bounds := Rect2(board._tile_center(_aim), Vector2.ZERO)
	for tile: Vector2i in _take_targets: bounds = bounds.expand(board._tile_center(tile))
	var center: Vector2 = board.get_global_transform_with_canvas() * bounds.get_center()
	var origin := Vector2i(center.round()) - CropSize / 2
	var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(CropSize.x * CONTACT_COLUMNS.size(), CropSize.y, false, Image.FORMAT_RGB8)
		raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Could not open the FX-35 recording stream.")
			return {}
	var columns: Dictionary
	var clip_frames: int = 0
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_case()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and _ended_at == UNSET: _ended_at = frame
		_observe_frame(board, frame)
		var contact: int = _take_fixture["beats"][0]["contact"]
		var offset: int = UNSET if contact == UNSET else frame - contact
		var column: int = CONTACT_COLUMNS.find(offset)
		if column >= 0: columns[column] = frame
		var clip_frame: bool = clip_frames < REEL_FRAMES
		if clip_frame: clip_frames += 1
		if not _plan and (column >= 0 or clip_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected a 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if clip_frame: raw.store_buffer(image.get_data())
			if column >= 0:
				strip.blit_rect(image, crop, Vector2i(column * CropSize.x, 0))
				if column == 0 and not _save(image, "native-evidence.png"): return {}
				if offset == CROP_100MS_TICK:
					var zoom: Image = image.get_region(crop)
					zoom.resize(CropSize.x * CROP_ZOOM, CropSize.y * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
					if not _save(zoom, "100ms-2x.png"): return {}
		if _ended_at >= 0 and clip_frames == REEL_FRAMES and columns.size() == CONTACT_COLUMNS.size(): break
	if _ended_at < 0 or clip_frames != REEL_FRAMES or columns.size() != CONTACT_COLUMNS.size():
		_fail("FX-35 did not finish take " + _id)
		return {}
	if raw != null: raw.close()
	if strip != null and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _id, "frames": stats.get("authored_frames", 0), "rendered": stats.get("rendered_frames", 0),
		"duration_usec": stats.get("authored_duration_usec", 0), "done": _ended_at, "beats": _take_fixture["beats"],
		"columns": columns, "clip_frames": clip_frames}
