extends "./relic_take.gd"
## Exact-size framebuffer capture. The separate MovieWriter window records audio.

const Clock = preload("res://scripts/presentation_clock.gd")
const CROP := Vector2i(640, 640)
const SNAP_FRAMES: Array[int] = [0, 4, 8, 14, 22, 30]
const CLIP_LEAD_FRAMES := 12
const CLIP_FRAMES := 120
const CASES := {"venom": VENOM, "storm": STORM}

var _out: String
var _plan: bool
var _after: bool
var _clip: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_take.call_deferred()

func _take() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var case_id: String = _arg("--case")
	_out = _arg("--out")
	_plan = args.has("--plan")
	_after = args.has("--after")
	_clip = args.has("--clip")
	if not CASES.has(case_id) or not _out.is_absolute_path() or (_clip and not _after):
		_fail("Provide --case venom|storm, an absolute --out directory, and use --clip only with --after.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	elif DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS:
		_fail("Use the windowed visual probe runner and the 60 fps MovieWriter clock.")
		return
	if OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Set LABYRINTH_CEL_LOOK=all for this take.")
		return
	var sync: ColorRect
	if _clip and not _plan:
		sync = ColorRect.new()
		sync.color = Color.RED
		var layer := CanvasLayer.new()
		root.add_child(layer)
		layer.add_child(sync)
		sync.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not await _open_take(_out, CASES[case_id]):
		_fail("The production relic offer did not appear.")
		return
	# Give the untouched offer a draw before marking the start of the RGB take.
	await process_frame
	if sync != null: sync.color = Color.LIME
	var result: Dictionary = await _record()
	await _close_take()
	if result.is_empty(): return
	var receipt: FileAccess = FileAccess.open(_out.path_join("take.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Could not write take.json.")
		return
	receipt.store_string(JSON.stringify(result, "\t"))
	receipt.close()
	print(_out)
	print("FND-02 %s %s %s" % ["PLAN" if _plan else "NATIVE", case_id, JSON.stringify(result)])
	print("TEST RESULT: PASS")
	quit(0)

func _record() -> Dictionary:
	var raw: FileAccess
	var strip: Image
	if not _plan:
		strip = Image.create_empty(CROP.x * SNAP_FRAMES.size(), CROP.y, false, Image.FORMAT_RGB8)
		if _clip:
			raw = FileAccess.open(_out.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open the RGB stream.")
				return {}
	var sampled: int = 0
	var activation: int = CLIP_LEAD_FRAMES if _clip else 0
	var first_beam: int = -1
	var cut := Rect2i()
	for tick: int in (CLIP_FRAMES if _clip else FRAME_LIMIT):
		if tick == activation:
			_begin_claim()
			cut = Rect2i((Vector2i(_icon_rect.get_center().round()) - CROP / 2).clamp(Vector2i.ZERO, SIZE - CROP), CROP)
		if not _plan: await RenderingServer.frame_post_draw
		var image: Image
		if raw != null:
			image = _read_frame()
			if image == null: return {}
			raw.store_buffer(image.get_data())
		if tick >= activation:
			_sample_claim()
			if first_beam < 0 and _delivery_beam() != null:
				first_beam = Engine.get_process_frames()
				var stamp: Node = _burst()
				if (stamp != null) != _after or (stamp != null and (stamp.frame != 0 or stamp.z_index != _icon_z - 1)):
					_fail("First beam frame has the wrong burst presence, frame, or draw order.")
					return {}
			if first_beam >= 0 and sampled < SNAP_FRAMES.size() and Engine.get_process_frames() - first_beam == SNAP_FRAMES[sampled]:
				if not _plan:
					if image == null: image = _read_frame()
					if image == null: return {}
					if sampled == 0 and not _save(image, "native-evidence.png"): return {}
					strip.blit_rect(image, cut, Vector2i(sampled * CROP.x, 0))
				sampled += 1
			if not _clip and _trace.has("complete") and sampled == SNAP_FRAMES.size(): break
		await process_frame
	if raw != null:
		var write_error: Error = raw.get_error()
		raw.close()
		if write_error != OK:
			_fail("Could not write the RGB stream (%d)." % write_error)
			return {}
	var settled: bool = _trace.has("complete") and _trace.has("motes_end") and sampled == SNAP_FRAMES.size()
	if not settled or (_after and not _trace.has("burst_end")):
		_fail("Incomplete take: %s, crops=%d." % [JSON.stringify(_trace), sampled])
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var result: Dictionary = {"timing": _trace, "crop_position": [cut.position.x, cut.position.y], "snap_frames": SNAP_FRAMES}
	if _clip:
		result["clip"] = {"fps": FPS, "width": SIZE.x, "height": SIZE.y, "frames": CLIP_FRAMES, "lead": CLIP_LEAD_FRAMES}
	return result

func _read_frame() -> Image:
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != SIZE:
		_fail("The recorded SubViewport is not 1920x1080.")
		return null
	image.convert(Image.FORMAT_RGB8)
	return image

func _save(image: Image, file_name: String) -> bool:
	var error: Error = image.save_png(_out.path_join(file_name))
	if error == OK: return true
	_fail("Could not save %s (%d)." % [file_name, error])
	return false
