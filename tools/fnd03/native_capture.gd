extends "./gain_take.gd"
## Capture the game SubViewport. The small MovieWriter window records synced audio.

const Clock = preload("res://scripts/presentation_clock.gd")
const PROOF_CASES: Array[String] = ["shop_card", "shop_gear", "event_relic", "event_card", "dragon"]
const CROP := Vector2i(640, 640)
const CROP_FRAMES: Array[int] = [0, 4, 8, 14, 22, 30]
const ARRIVAL_OFFSETS: Array[int] = [0, 6]
const ARRIVAL_FILES: Array[String] = ["arrival.png", "arrival-plus-100ms.png"]
const CLIP_LEAD := 8
const CLIP_LENGTH := 96
const CAPTURE_LIMIT := 144

var _out: String
var _plan: bool
var _after: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture.call_deferred()

func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var case_id: String = _option("--case")
	_out = _option("--out")
	_plan = args.has("--plan")
	_after = args.has("--after")
	if not _out.is_absolute_path() or case_id not in PROOF_CASES or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_abort("Supply an approved --case, absolute --out and LABYRINTH_CEL_LOOK=all.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	elif DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS:
		_abort("Use the windowed visual probe runner and its 60 fps movie clock.")
		return
	var sync: ColorRect
	if _after and not _plan:
		var layer := CanvasLayer.new()
		root.add_child(layer)
		sync = ColorRect.new()
		layer.add_child(sync)
		sync.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sync.color = Color.RED
	if not await _open_gain(_out, case_id, false):
		_abort("Could not prepare the live fixture: " + case_id)
		return
	await process_frame
	if sync != null: sync.color = Color.LIME
	var receipt: Dictionary = await _record()
	await _close_gain()
	if receipt.is_empty():
		_abort("The take did not satisfy the frame contract.")
		return
	var file: FileAccess = FileAccess.open(_out.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_abort("Could not write take.json.")
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print(_out)
	print("FND-03 %s %s %s" % ["PLAN" if _plan else "NATIVE", case_id, JSON.stringify(receipt)])
	print("TEST RESULT: PASS")
	quit(0)

func _record() -> Dictionary:
	var raw: FileAccess
	var strip: Image
	if not _plan:
		strip = Image.create_empty(CROP.x * CROP_FRAMES.size(), CROP.y, false, Image.FORMAT_RGB8)
		if _after:
			raw = FileAccess.open(_out.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null: return {}
	var sampled: int
	var arrivals: int
	var crop := Rect2i()
	var arrival_crop := Rect2i()
	var arrival_frame: int = -1
	for tick: int in CAPTURE_LIMIT:
		if tick == CLIP_LEAD: _activate_gain()
		if not _plan: await RenderingServer.frame_post_draw
		var image: Image
		if raw != null and tick < CLIP_LENGTH:
			image = _read_frame()
			if image == null: return {}
			raw.store_buffer(image.get_data())
		if tick >= CLIP_LEAD:
			_sample_gain()
			var frame: int = Engine.get_process_frames() - take_origin_frame
			var start: int = _gain_start()
			if start >= 0 and sampled < CROP_FRAMES.size() and frame - start == CROP_FRAMES[sampled]:
				if sampled == 0:
					if take_trace.bursts.size() != int(_after) or take_art.size == Vector2.ZERO: return {}
					crop = _crop_at(take_art.get_center())
				if not _plan:
					if image == null: image = _read_frame()
					if image == null: return {}
					if sampled == 0 and not _save_frame(image, "native-evidence.png"): return {}
					strip.blit_rect(image, crop, Vector2i(sampled * CROP.x, 0))
				sampled += 1
			if _after and arrivals < ARRIVAL_OFFSETS.size():
				if arrival_frame < 0: arrival_frame = _arrival_frame()
				if arrival_frame >= 0 and frame >= arrival_frame + ARRIVAL_OFFSETS[arrivals]:
					# The headless sampler can observe a signal on the next process tick.
					if not _plan and frame != arrival_frame + ARRIVAL_OFFSETS[arrivals]: return {}
					if arrivals == 0: arrival_crop = _crop_at(take_destination)
					if not _plan:
						if image == null: image = _read_frame()
						if image == null or not _save_frame(image.get_region(arrival_crop), ARRIVAL_FILES[arrivals]): return {}
					arrivals += 1
		if tick + 1 >= CLIP_LENGTH and sampled == CROP_FRAMES.size() and (not _after or arrivals == ARRIVAL_OFFSETS.size()) and _take_settled(): break
		await process_frame
	if raw != null:
		var error: Error = raw.get_error()
		raw.close()
		if error != OK: return {}
	if sampled != CROP_FRAMES.size() or (_after and arrivals != ARRIVAL_OFFSETS.size()) or not _take_settled(): return {}
	if not _plan and not _save_frame(strip, "strip.png"): return {}
	var result: Dictionary = {
		"timing": take_trace.timing, "effects": take_trace.effects, "snap_frames": CROP_FRAMES,
		"crop_position": _point(Vector2(crop.position)),
	}
	if _after:
		result["arrival"] = {"frame": arrival_frame, "offsets": ARRIVAL_OFFSETS, "crop_position": _point(Vector2(arrival_crop.position))}
		result["clip"] = {"fps": FPS, "width": VIEWPORT_SIZE.x, "height": VIEWPORT_SIZE.y, "frames": CLIP_LENGTH, "lead": CLIP_LEAD}
	return result

func _gain_start() -> int:
	if take_spec[0] == "dragon": return take_trace.timing.get("beam", -1)
	return -1 if take_trace.effects.is_empty() else int(take_trace.effects[0].start)

func _arrival_frame() -> int:
	if take_spec[0] == "dragon": return take_trace.timing.get("beam_end", -1)
	if take_trace.effects.is_empty(): return -1
	return take_trace.effects[0].get("flight_end" if take_spec[0] == "shop" else "arrived", -1)

func _take_settled() -> bool:
	if take_spec[0] == "dragon": return take_trace.timing.has("complete")
	return not take_trace.effects.is_empty() and take_trace.effects[0].has("end")

func _crop_at(centre: Vector2) -> Rect2i:
	var corner: Vector2i = (Vector2i(centre.round()) - CROP / 2).clamp(Vector2i.ZERO, VIEWPORT_SIZE - CROP)
	return Rect2i(corner, CROP)

func _read_frame() -> Image:
	var image: Image = take_viewport.get_texture().get_image()
	if image == null or image.get_size() != VIEWPORT_SIZE: return null
	image.convert(Image.FORMAT_RGB8)
	return image

func _save_frame(image: Image, name: String) -> bool:
	return image.save_png(_out.path_join(name)) == OK

func _abort(reason: String) -> void:
	_fail(reason)
	print("TEST RESULT: FAIL")
	quit(1)
