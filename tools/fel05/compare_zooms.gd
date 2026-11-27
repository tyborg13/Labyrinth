extends SceneTree
## The source strips already use 2x nearest scaling. Crop in native pixels,
## then enlarge the same region on both sides to 4x native scale.

const STRIP_SCALE := 2
const ZOOM := 4
const STRIP_SIZE := Vector2i(960, 720)
const FRAMES := ["frame--01.png", "frame-00.png"]
const STRIKES := {
	"quick-stab": {
		"strip": "01-s0-seed15-0-0_2-t2-melee-01", "crop": Rect2i(212, 97, 128, 138),
	},
	"crushing-step": {
		"strip": "01-s0-seed15-0-0_2-t2-melee-03", "crop": Rect2i(148, 48, 82, 146),
	},
}

func _initialize() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.size() != 3:
		_fail("expected release capture, after capture, and output directory")
		return
	if DirAccess.make_dir_recursive_absolute(paths[2]) != OK:
		_fail("cannot create " + paths[2])
		return
	for strike: String in STRIKES:
		var crop: Rect2i = STRIKES[strike]["crop"]
		var strip: String = STRIKES[strike]["strip"]
		for frame: String in FRAMES:
			var release: Image = _crop(paths[0].path_join(strip).path_join(frame), crop)
			var after: Image = _crop(paths[1].path_join(strip).path_join(frame), crop)
			if release == null or after == null:
				_fail("cannot read the matched frame %s/%s" % [strip, frame])
				return
			var frame_size: Vector2i = crop.size * ZOOM
			var comparison := Image.create_empty(frame_size.x * 2, frame_size.y, false, Image.FORMAT_RGB8)
			comparison.blit_rect(release, Rect2i(Vector2i.ZERO, frame_size), Vector2i.ZERO)
			comparison.blit_rect(after, Rect2i(Vector2i.ZERO, frame_size), Vector2i(frame_size.x, 0))
			var destination: String = paths[2].path_join(strike + "-" + frame)
			if comparison.save_png(destination) != OK:
				_fail("cannot write " + destination)
				return
			print(destination)
	print("FEL05 ZOOM COMPARISONS PASS frames=4 scale=4x release=left after=right")
	quit()

func _crop(path: String, crop: Rect2i) -> Image:
	var source: Image = Image.load_from_file(path)
	if source == null or source.get_size() != STRIP_SIZE: return null
	var image: Image = source.get_region(Rect2i(crop.position * STRIP_SCALE, crop.size * STRIP_SCALE))
	image.convert(Image.FORMAT_RGB8)
	image.resize(crop.size.x * ZOOM, crop.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return image

func _fail(problem: String) -> void:
	printerr("FEL05 ZOOM COMPARISONS FAIL " + problem)
	quit(1)
