extends RefCounted

const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Cache = preload("res://scripts/tooltip_loop_cache.gd")
const Loop = preload("res://scripts/tooltip_loop_view.gd")
const FPS: int = 30 # The tip-05 MovieWriter clock and the installed recordings.
const SECONDS: int = 5
const CAMERA_PADDING: int = 24
const ASPECT_UNITS := Vector2i(16, 9)

static func surface_bounds(control: Control, rect: Rect2) -> Rect2:
	return control.get_global_transform_with_canvas() * rect

static func camera(board: Rect2, panel: Rect2) -> Rect2i:
	var canvas := Rect2(Vector2.ZERO, Vector2(Playback.SIZE))
	var wanted: Rect2 = board.merge(panel).grow(CAMERA_PADDING).intersection(canvas)
	var units: int = ceili(maxf(wanted.size.x / ASPECT_UNITS.x, wanted.size.y / ASPECT_UNITS.y))
	var extent: Vector2i = ASPECT_UNITS * units
	var origin: Vector2i = Vector2i((wanted.get_center() - Vector2(extent) / 2.0).floor())
	return Rect2i(origin.clamp(Vector2i.ZERO, Playback.SIZE - extent), extent)

static func seek_middle(tree: SceneTree, window: Control) -> float:
	var source_frames: int = 0
	for frame: int in range(Playback.READY_FRAME_LIMIT):
		source_frames = int(Cache.shared().header(window.asset_path).get("count", 0))
		if source_frames > 1: break
		await tree.process_frame
	if source_frames < 2: return -1.0
	var index: int = floori(float(source_frames) / 2.0)
	window.proof_seconds = (float(index) + 0.5) / FPS
	if not await _frame_ready(tree, window, index): return -1.0
	print("TXT-13 MID-LOOP %s: frame %d of %d" % [window.asset_path.get_file(), index, source_frames])
	return window.proof_seconds

static func _frame_ready(tree: SceneTree, window: Control, index: int) -> bool:
	for frame: int in range(Playback.READY_FRAME_LIMIT):
		await tree.process_frame
		if window.displayed_frame == index and float(window.get("_fade")) >= Loop.FADE_IN_SECONDS: return true
	return false

static func record(tree: SceneTree, viewport: SubViewport, window: Control, crop: Rect2i, midpoint: float, path: String) -> String:
	var file := FileAccess.open(path + ".rgb", FileAccess.WRITE)
	if file == null: return "could not open raw footage"
	var count: int = int(Cache.shared().header(window.asset_path)["count"])
	var period: float = float(count) / FPS + Loop.HOLD_SECONDS + Loop.CROSSFADE_SECONDS
	var loop_rect := Rect2i(surface_bounds(window, window.window_rect()))
	var previous: PackedByteArray
	var motion: bool = false
	for index: int in range(FPS * SECONDS):
		var seconds: float = midpoint + float(index) / FPS
		var source_frame: int = mini(floori(fmod(seconds, period) * FPS), count - 1)
		window.proof_seconds = seconds
		# Cache uploads can miss a renderer tick. Wait without adding duplicate
		# output frames so the exported timeline still runs at the authored speed.
		if not await _frame_ready(tree, window, source_frame):
			return "loop timed out on frame %d" % source_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		if image == null or image.get_size() != Playback.SIZE: return "renderer did not return a frame"
		if not motion:
			var pixels: PackedByteArray = image.get_region(loop_rect).get_data()
			motion = not previous.is_empty() and pixels != previous
			previous = pixels
		var picture: Image = image.get_region(crop)
		picture.convert(Image.FORMAT_RGB8)
		file.store_buffer(picture.get_data())
	if file.get_error() != OK: return "could not write raw footage"
	file.close()
	if not motion: return "loop window pixels stayed still"
	var report := FileAccess.open(path + ".json", FileAccess.WRITE)
	if report == null: return "could not open footage metadata"
	report.store_string(JSON.stringify({"crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y], "frames": FPS * SECONDS, "fps": FPS, "still_seconds": midpoint}) + "\n")
	return ""
