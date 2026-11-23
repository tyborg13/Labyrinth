extends "res://tools/fx34/native_capture.gd"
## Replay the real finish and use its board, pickup pose and notice to sample
## exact opacity fractions between the authored playback's discrete samples.

const GearDraw = preload("res://tools/mrg16/gear_draw_probe.gd")
const SAMPLE_PERCENT: Array[int] = [0, 25, 50, 75, 100]
const DETAIL_PERCENT: int = 50
const TILE_CROP := Vector2i(320, 240)
const DETAIL_ZOOM: int = 2

func _take() -> void:
	_plan = OS.get_cmdline_user_args().has("--plan")
	var output: String = _arg("--out")
	if not output.is_absolute_path():
		_fail("Provide an absolute --out directory for the gear fade.")
		return
	if _plan:
		_install_plan_clock()
	elif DisplayServer.get_name() == "headless" or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/mrg16/native.sh for the native gear fade.")
		return
	var report: Dictionary = await take_case("missed", output, false)
	if report.is_empty(): return
	print("MRG-16 GEAR CAPTURE PLAN PASS (5 opacity samples, 0 failures) " + output if _plan else output)
	quit()

func _observe_fx34() -> Dictionary:
	var board: Control = _run.board_view
	var victory: Dictionary
	var shown: Dictionary
	var loot: Dictionary
	_drive_action()
	for frame: int in TAKE_LIMIT:
		await _next_sample()
		if shown.is_empty() and board.presentation.get("missed_equipment_progress", -1.0) == 0.0:
			victory = board.combat_state.duplicate(true)
			shown = board.presentation.duplicate(true)
			for entry: Dictionary in victory["loot"]:
				if entry.get("equipment_id") == Fixture.FIRST_ID:
					loot = entry
					break
		if _complete: break
	if not _complete or loot.is_empty():
		_fail("The live victory did not start and complete the missed gear fade.")
		return {}

	var center: Vector2 = board.get_global_transform_with_canvas() * board._tile_center(Fixture.FIRST_GEAR)
	var origin: Vector2i = (Vector2i(center.round()) - TILE_CROP / 2).clamp(Vector2i.ZERO, CanvasSize - TILE_CROP)
	var crop := Rect2i(origin, TILE_CROP)
	var strip: Image
	if not _plan:
		strip = Image.create_empty(TILE_CROP.x * SAMPLE_PERCENT.size(), TILE_CROP.y, false, Image.FORMAT_RGB8)
	var receipts: Array[Dictionary]
	var bounds: String
	for percent: int in SAMPLE_PERCENT:
		var progress: float = float(percent) / 100.0
		shown["missed_equipment_progress"] = progress
		_run._render_board_state(victory, shown.duplicate(true))
		await _next_sample()
		var sample: Dictionary = GearDraw.sample(board, loot)
		if percent == 0: bounds = sample.get("bounds", "")
		if not GearDraw.matches(sample, progress, bounds):
			_fail("Unexpected draw commands at %d%%: %s" % [percent, sample])
			return {}
		receipts.append({"percent": percent, "draw": sample})
		if _plan: continue
		var image: Image = _viewport.get_texture().get_image()
		if image == null or image.get_size() != CanvasSize:
			_fail("Expected a 1920x1080 framebuffer.")
			return {}
		image.convert(Image.FORMAT_RGB8)
		if not _save(image, "fade-%03d.png" % percent): return {}
		strip.blit_rect(image, crop, Vector2i(receipts.size() - 1, 0) * TILE_CROP)
		if percent == DETAIL_PERCENT:
			var detail: Image = image.get_region(crop)
			detail.resize(TILE_CROP.x * DETAIL_ZOOM, TILE_CROP.y * DETAIL_ZOOM, Image.INTERPOLATE_NEAREST)
			if not _save(detail, "tile-2x.png"): return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	return {"samples": receipts, "crop": str(crop), "size": str(CanvasSize), "ui_scale": 1.0, "notice": _run.log_label.text}

func _next_sample() -> void:
	if _plan:
		await _plan_frame.presented
	else:
		await process_frame
		await RenderingServer.frame_post_draw
