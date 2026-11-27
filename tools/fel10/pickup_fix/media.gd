extends RefCounted
## Export matched crops from the pickup's actual framebuffer.

const SIZE := Vector2i(1920, 1080)
const SAMPLES := 12
const STRIP_COLUMNS := 3
const TRAIL_LENGTH_PX := 56.0
const TRAIL_CROP_MARGIN_PX := 4.0

var output: String
var side: String
var problem: String
var frames: Array[Image]
var positions: Array[Vector2]
var start: Vector2
var target: Vector2
var path: Rect2
var trail_detail: Image
var _movie: FileAccess


func capture_flight(image: Image, center: Vector2) -> void:
	if image != null: frames.append(image)
	positions.append(center)


func capture_trail(image: Image, center: Vector2) -> void:
	var tail: Vector2 = center - (target - start).normalized() * TRAIL_LENGTH_PX
	var bounds: Rect2 = Rect2(center, Vector2.ZERO).expand(tail).grow(TRAIL_CROP_MARGIN_PX)
	trail_detail = _scaled_crop(image, _pixel_rect(bounds), 4)


func write_stills() -> bool:
	var crop: Rect2i = _pixel_rect(path)
	var sample_size: Vector2i = crop.size * 2
	var sheet := Image.create_empty(sample_size.x * STRIP_COLUMNS,
		sample_size.y * (SAMPLES / STRIP_COLUMNS), false, Image.FORMAT_RGB8)
	var midpoint: Image = frames[middle()]
	for index: int in SAMPLES:
		var source: int = roundi(float(index * (frames.size() - 1)) / float(SAMPLES - 1))
		var cell := Vector2i(index % STRIP_COLUMNS, index / STRIP_COLUMNS)
		var sample: Image = _scaled_crop(frames[source], crop, 2)
		sheet.blit_rect(sample, Rect2i(Vector2i.ZERO, sample_size), cell * sample_size)
	if not _save(sheet, side.path_join("loot_pickup-strip-2x.png")): return false
	if not _save(midpoint, side.path_join("halfway-full.png")): return false
	if side == "release":
		var file := FileAccess.open(output.path_join("release/path.rect"), FileAccess.WRITE)
		if file == null or not file.store_var(path, false):
			problem = "could not write release path rectangle"
			return false
		return true
	if not _save(trail_detail, "branch/loot_pickup-trail-4x.png"): return false
	return _pair(midpoint)


func middle() -> int:
	var center: Vector2 = start.lerp(target, 0.5)
	var index: int = 0
	for i: int in range(1, positions.size()):
		if positions[i].distance_squared_to(center) < positions[index].distance_squared_to(center):
			index = i
	return index


func _pair(after: Image) -> bool:
	var before := Image.load_from_file(output.path_join("release/halfway-full.png"))
	var file := FileAccess.open(output.path_join("release/path.rect"), FileAccess.READ)
	if before == null or before.get_size() != SIZE or file == null:
		problem = "release midpoint framebuffer or path is missing"
		return false
	var release_path: Rect2 = file.get_var(false)
	var crop: Rect2i = _pixel_rect(path.merge(release_path))
	var pair := Image.create_empty(crop.size.x * 2, crop.size.y, false, Image.FORMAT_RGB8)
	pair.blit_rect(_scaled_crop(before, crop, 1), Rect2i(Vector2i.ZERO, crop.size), Vector2i.ZERO)
	pair.blit_rect(_scaled_crop(after, crop, 1), Rect2i(Vector2i.ZERO, crop.size), Vector2i(crop.size.x, 0))
	return _save(pair, "halfway-before-after.png")


func capture_movie(image: Image) -> bool:
	if _movie == null:
		_movie = FileAccess.open(output.path_join("movie/frames.rgb"), FileAccess.WRITE)
		if _movie == null:
			problem = "could not open movie frame stream"
			return false
		if not _save(image, "movie/burst.png"): return false
	image.convert(Image.FORMAT_RGB8)
	if not _movie.store_buffer(image.get_data()):
		problem = "could not write movie frame"
		return false
	return true


func finish_movie(image: Image) -> bool:
	_movie = null
	return _save(image, "movie/arrival.png")


func _save(image: Image, relative: String) -> bool:
	var filename: String = output.path_join(relative)
	if image != null and image.save_png(filename) == OK:
		print(filename)
		return true
	problem = "could not write " + filename
	return false


static func _pixel_rect(bounds: Rect2) -> Rect2i:
	var start_px := Vector2i(bounds.position.floor())
	var end_px := Vector2i(bounds.end.ceil())
	return Rect2i(start_px, end_px - start_px).intersection(Rect2i(Vector2i.ZERO, SIZE))


static func _scaled_crop(source: Image, crop: Rect2i, scale_factor: int) -> Image:
	var image: Image = source.get_region(crop)
	image.convert(Image.FORMAT_RGB8)
	if scale_factor > 1:
		image.resize(crop.size.x * scale_factor, crop.size.y * scale_factor, Image.INTERPOLATE_NEAREST)
	return image
