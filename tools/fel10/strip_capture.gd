extends RefCounted
## One physical draw instance from onset through its last drawn frame.

const Store = preload("res://tools/fel10/frame_store.gd")
const SIZE := Store.SIZE
const FRAMES := 25
const CROP_RATIO := Vector2i(4, 3)
const MIN_CROP_UNITS := 120
const MIN_DRAWN_FRAMES := 3
const MIN_COVERAGE := 0.80
const MIN_CHANGED := 0.005

var start_rect: Rect2
var extent: Rect2
var crop: Rect2i
var instance: String
var source: String
var input_index: int
var first_frame: int
var last_frame: int
var count: int
var peak: Image
var peak_index: int = -1
var frames: Array[Image]
var samples: PackedInt32Array
var cooccurring: PackedStringArray
var coverage: float = 1.0
var changed: float = -1.0
var effect_changed: float = -1.0
var ended: bool
var reason: String
var pixel_pending: bool
var _bounds_by_frame: Array[Rect2]
var _other_rects: Dictionary


func _init(observation: Dictionary, input: int, frame: int) -> void:
	start_rect = observation["rect"]
	extent = start_rect
	instance = observation["instance"]
	source = observation["source"]
	input_index = input
	first_frame = frame
	last_frame = frame - 1


func observe(observation: Dictionary, frame: int, draws: Dictionary, effect_id: String) -> void:
	if observation.is_empty():
		ended = true
		return
	var rect: Rect2 = observation["rect"]
	extent = extent.merge(rect)
	_bounds_by_frame.append(rect)
	last_frame = frame
	count += 1
	for id: String in draws:
		if id == effect_id: continue
		for key: String in draws[id]:
			if key == instance: continue
			if not _other_rects.has(id): _other_rects[id] = []
			var other: Rect2 = draws[id][key]["rect"]
			if not _other_rects[id].has(other): _other_rects[id].append(other)


func finish(store: Store, dry: bool) -> void:
	crop = fit_crop(extent)
	samples = sample_indices(count)
	for rect: Rect2 in _bounds_by_frame:
		coverage = minf(coverage, rect.intersection(Rect2(crop)).get_area() / rect.get_area())
	for id: String in _other_rects:
		for rect: Rect2 in _other_rects[id]:
			if rect.intersects(Rect2(crop)):
				cooccurring.append(id)
				break
	cooccurring.sort()
	var failures := PackedStringArray()
	if not ended: failures.append("draw lifetime still active at the replay limit")
	if samples.size() < MIN_DRAWN_FRAMES:
		failures.append("draw path present in %d captured frame(s), minimum %d" % [samples.size(), MIN_DRAWN_FRAMES])
	if coverage < MIN_COVERAGE:
		failures.append("rect coverage %.1f%%, minimum 80%%" % (coverage * 100.0))
	if dry:
		pixel_pending = true
	else:
		_measure(store)
		if changed < 0.0:
			failures.append("pre-fire or active framebuffer unavailable")
		elif effect_changed <= 0.0:
			failures.append("effect rectangle has no changed pixels")
		elif changed < MIN_CHANGED:
			failures.append("peak change %.3f%%, minimum 0.5%%" % (changed * 100.0))
	reason = " / ".join(failures)


func _measure(store: Store) -> void:
	var before: Image = store.read(first_frame - 1)
	if before == null: return
	var baseline: PackedInt32Array = before.get_region(crop).get_data().to_int32_array()
	var best: int = -1
	for offset: int in count:
		var image: Image = store.read(first_frame + offset)
		if image == null:
			changed = -1.0
			return
		var region: Image = image.get_region(crop)
		var limit: Rect2i = pixel_rect(_bounds_by_frame[offset]).intersection(crop)
		limit.position -= crop.position
		var pixels: PackedInt32Array = region.get_data().to_int32_array()
		var score: int = pixel_changes(baseline, pixels, crop.size.x, limit)
		if score > best:
			best = score
			peak = image
			peak_index = offset
		if offset in samples: frames.append(region)
	effect_changed = float(best) / float(crop.get_area())
	var peak_pixels: PackedInt32Array = peak.get_region(crop).get_data().to_int32_array()
	var all_changes: int = pixel_changes(baseline, peak_pixels, crop.size.x, Rect2i(Vector2i.ZERO, crop.size))
	changed = float(all_changes) / float(crop.get_area())


static func pixel_changes(before: PackedInt32Array, after: PackedInt32Array, width: int, box: Rect2i) -> int:
	var count: int = 0
	for y: int in range(box.position.y, box.end.y):
		var row: int = y * width
		for index: int in range(row + box.position.x, row + box.end.x):
			count += int(before[index] != after[index])
	return count


static func pixel_rect(rect: Rect2) -> Rect2i:
	var left := Vector2i(rect.position.floor())
	return Rect2i(left, Vector2i(rect.end.ceil()) - left)


static func fit_crop(rect: Rect2) -> Rect2i:
	var box: Rect2i = pixel_rect(rect)
	var units: int = maxi(MIN_CROP_UNITS, ceili(maxf(float(box.size.x) / CROP_RATIO.x, float(box.size.y) / CROP_RATIO.y)))
	units = mini(units, floori(minf(float(SIZE.x) / CROP_RATIO.x, float(SIZE.y) / CROP_RATIO.y)))
	var size: Vector2i = CROP_RATIO * units
	var start := Vector2i((rect.get_center() - Vector2(size) * 0.5).round())
	return Rect2i(start.clamp(Vector2i.ZERO, SIZE - size), size)


static func sample_indices(length: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var keep: int = mini(length, FRAMES)
	for i: int in keep:
		result.append(roundi(float(i * (length - 1)) / float(maxi(1, keep - 1))))
	return result


func sampling_label() -> String:
	var stride: float = float(maxi(0, count - 1)) / float(maxi(1, samples.size() - 1))
	return "%d/%d frames, stride %.2f, scale %.3f× nearest" % [samples.size(), count, stride, 960.0 / float(crop.size.x)]


func verdict() -> String:
	if not reason.is_empty(): return reason
	if pixel_pending: return "pixel check pending native rendering"
	return "yes"
