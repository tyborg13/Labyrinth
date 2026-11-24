extends SceneTree

const Fight = preload("fight.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Typography = preload("res://scripts/ui_typography.gd")

var _fight := Fight.new()
var _output: String
var _dry: bool
var _clip: String
var _timeline: Dictionary = {}
var _frames: Dictionary = {}
var _failures: Array[String]
var _erupt_contact: float = -1.0
var _reel_done: bool = false
var _luma_capture: Script

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_dry = args.has("--dry-run") or DisplayServer.get_name() == "headless"
	_output = _arg(args, "--out", "/private/tmp/labyrinth_codex/art-08/verify")
	if not _output.is_absolute_path():
		push_error("Use an absolute --out directory.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	print("ART-08 READY " + _output)
	await _fight.setup(self)
	_check(_fight.viewport.size == Fight.SIZE and is_equal_approx(Typography.ui_scale(_fight.scene), 1.0), "1920x1080 viewport at 100% UI scale")
	_check(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "LABYRINTH_CEL_LOOK=all")
	_check(not _fight.states["burrow"].is_empty() and not _fight.states["erupt"].is_empty(), "Both actions resolved in the real encounter")
	if _failures.is_empty():
		if args.has("--reel"): await _reel()
		else: await _stills(args.has("--before"))
	var report := FileAccess.open(_output.path_join("frames.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"timeline": _timeline, "frames": _frames, "failures": _failures}, "\t"))
		report.close()
	else: _check(false, "writes frames.json")
	_fight.viewport.queue_free()
	await process_frame
	for failure: String in _failures: push_error(failure)
	print("ART-08 %s: %s" % ["HEADLESS" if _dry else "NATIVE", "PASS" if _failures.is_empty() else "FAIL"])
	print(_output)
	quit(0 if _failures.is_empty() else 1)

func _stills(before: bool) -> void:
	if not before: _luma_capture = load("res://tools/art08/luma_capture.gd")
	for kind: String in ["burrow", "erupt"]:
		_clip = kind
		_timeline[kind] = []
		_fight.scene.proof_seconds = 0.0
		_fight.scene.proof_sample = _sample_action
		await _fight.scene.record(_fight.drive.bind(kind))
		if kind == "burrow":
			if not before:
				var verification: Script = load("res://tools/art08/mound_check.gd")
				verification.run(_fight, _check)
			await _idle_still(Fight.BREATH_PEAK_MSEC, Fight.STILLS[0])
			await _idle_still(Fight.BREATH_TROUGH_MSEC, Fight.STILLS[1])
	_check(_frames.size() == Fight.STILLS.size(), "all eight stills were reached")
	_check(float(_frames.get(Fight.STILLS[2], {}).get("root_alpha", 1.0)) == 0.0, "terminal Burrow rig is hidden")
	_check(bool(_frames.get(Fight.STILLS[3], {}).get("burrowed", false)), "post-clip snapshot is burrowed")
	_check(_erupt_contact >= 0.0, "authored Erupt contact was reached")

func _sample_action() -> void:
	var row: Dictionary = _fight.sample(_fight.scene.proof_seconds)
	var rows: Array = _timeline[_clip]
	rows.append(row)
	if _clip == "burrow":
		if row["clip"] == _clip and row["phase"] >= 1.0:
			await _still(Fight.STILLS[2], row)
		elif _frames.has(Fight.STILLS[2]) and row["clip"] != _clip:
			await _still(Fight.STILLS[3], row)
		return
	if row["clip"] != _clip: return
	await _still(Fight.STILLS[4], row)
	if _erupt_contact < 0.0 and float(row["phase"]) >= _fight.contact:
		_erupt_contact = row["seconds"]
		await _still(Fight.STILLS[5], row)
	if _erupt_contact >= 0.0 and float(row["seconds"]) - _erupt_contact >= Fight.ERUPT_TAIL_SECONDS:
		await _still(Fight.STILLS[6], row)

func _idle_still(phase_msec: int, name: String) -> void:
	if not _dry:
		# Select the first refresh after the requested phase on the shipped clock.
		var previous: int = Clock.ticks_msec()
		var next_phase: int = previous - previous % Fight.BURROW_PERIOD_MSEC + phase_msec
		if next_phase <= previous: next_phase += Fight.BURROW_PERIOD_MSEC
		while Clock.ticks_msec() < next_phase:
			await process_frame
	var row: Dictionary = _fight.sample(0.0)
	row["breath_phase_msec"] = phase_msec
	if not _dry: row["sampled_clock_msec"] = Clock.ticks_msec()
	await _still(name, row)
	if name == Fight.STILLS[0]: await _still(Fight.STILLS[7], row, true)

func _still(name: String, row: Dictionary, full: bool = false) -> void:
	if _frames.has(name): return
	var crop: Rect2i = _fight.crop()
	_check(Rect2i(Vector2i.ZERO, Fight.SIZE).encloses(crop), "crop is inside the viewport: " + name)
	var path: String = _output.path_join(name + ".png")
	var record: Dictionary = row.duplicate()
	record["crop"] = str(crop)
	if not _dry:
		var frame: Image = await _image()
		if frame != null:
			_check((frame if full else frame.get_region(crop)).save_png(path) == OK, "saved " + path)
	if _luma_capture != null and _luma_capture.records(name):
		record["luma"] = _luma_capture.capture(_fight, name, crop, row, _output, _dry, _check)
	_frames[name] = record
	print(path)

func _reel() -> void:
	var raw_path: String = _output.path_join("frames.rgb")
	var raw: FileAccess
	if not _dry:
		_check(not Engine.get_write_movie_path().is_empty() and Clock._read_movie_fps() == Fight.FPS, "MovieWriter configured at 60 fps")
		raw = FileAccess.open(raw_path, FileAccess.WRITE)
		if not _check(raw != null, "opens raw reel output"): return
	for frame: int in range(Fight.FPS * Fight.REEL_SECONDS):
		if frame == Fight.REEL_BURROW_FRAME: _fight.drive("burrow")
		if frame == Fight.REEL_ERUPT_FRAME:
			_check(bool(_fight.grub_unit().get("burrowed", false)), "mound rests between clips")
			_play_reel_erupt()
		if _dry: await process_frame
		else:
			var image: Image = await _image()
			if image == null: break
			image.convert(Image.FORMAT_RGB8)
			raw.store_buffer(image.get_data())
			if frame == Fight.REEL_ERUPT_FRAME - 1:
				var preview: String = _output.path_join("reel_preview.png")
				_check(image.save_png(preview) == OK, "saved reel preview")
				print(preview)
			await process_frame
	if raw != null: raw.close()
	_check(_reel_done and not bool(_fight.grub_unit().get("burrowed", true)), "reel completes Erupt")
	print("ART-08 REEL: %d frames scheduled at %d fps" % [Fight.FPS * Fight.REEL_SECONDS, Fight.FPS])
	print(raw_path)

func _play_reel_erupt() -> void:
	await _fight.drive("erupt")
	_reel_done = true

func _image() -> Image:
	await RenderingServer.frame_post_draw
	var frame: Image = _fight.viewport.get_texture().get_image()
	if not _check(frame != null and frame.get_size() == Fight.SIZE, "reads the exact-size SubViewport"): return null
	return frame

func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

func _check(ok: bool, description: String) -> bool:
	if not ok: _failures.append(description)
	return ok
