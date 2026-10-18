extends RefCounted

const ENV: String = "LABYRINTH_BUG_01_DIFF_DUMP"
const OUTPUT: String = "user://bug_01_diff"
const CHANNELS: Array = ["r", "g", "b", "a"]
const MUTATION_ERROR: String = "BUG_01_DELIBERATE_FLOOR_PIXEL_MUTATION"
const MASK_EXTENSION: String = ".webp"
var _entries: Array[Dictionary]

static func enabled() -> bool:
	return OS.get_environment(ENV) == "1"

func has_case(case_id: int) -> bool:
	for entry: Dictionary in _entries:
		if int(entry["case"]) == case_id: return true
	return false

func case_count() -> int:
	return _entries.size()

# Exact RGBA8 differences, including alpha. Equal packed pixels bypass channel
# work; no tolerance, alpha exclusion, resampling or colour correction is used.
static func compare(first: Image, second: Image) -> Dictionary:
	assert(first.get_size() == second.get_size())
	var a: Image = first.duplicate()
	var b: Image = second.duplicate()
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var ad: PackedByteArray = a.get_data()
	var bd: PackedByteArray = b.get_data()
	var ap: PackedInt32Array = ad.to_int32_array()
	var bp: PackedInt32Array = bd.to_int32_array()
	var mask: Image = Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.BLACK)
	var maxima := PackedInt32Array([0, 0, 0, 0])
	var totals := PackedInt64Array([0, 0, 0, 0])
	var changed: int = 0
	var low: Vector2i = a.get_size()
	var high := Vector2i(-1, -1)
	for pixel: int in range(ap.size()):
		if ap[pixel] == bp[pixel]: continue
		var point := Vector2i(pixel % a.get_width(), pixel / a.get_width())
		changed += 1
		low = low.min(point)
		high = high.max(point)
		mask.set_pixelv(point, Color.WHITE)
		for channel: int in range(4):
			var delta: int = absi(int(ad[pixel * 4 + channel]) - int(bd[pixel * 4 + channel]))
			maxima[channel] = maxi(maxima[channel], delta)
			totals[channel] += delta
	return {"mask": mask, "differing_pixel_count": changed, "bounds": Rect2i(low, high - low + Vector2i.ONE) if changed > 0 else Rect2i(), "maxima": maxima, "totals": totals}

static func rect_json(rect: Rect2i) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}

static func metrics(delta: Dictionary, crop: Rect2i) -> Dictionary:
	var count: int = delta["differing_pixel_count"]
	var bounds: Rect2i = delta["bounds"]
	var maxima: PackedInt32Array = delta["maxima"]
	var totals: PackedInt64Array = delta["totals"]
	var maximum: Dictionary = {}
	var mean: Dictionary = {}
	var total: int = 0
	for channel: int in range(4):
		maximum[CHANNELS[channel]] = maxima[channel]
		mean[CHANNELS[channel]] = float(totals[channel]) / float(crop.get_area())
		total += totals[channel]
	return {"differing_pixel_count": count, "bounding_box": rect_json(Rect2i(bounds.position - crop.position, bounds.size)) if count > 0 else null, "bounding_box_viewport": rect_json(bounds) if count > 0 else null, "max_per_channel_delta": maximum, "max_channel_delta": maxi(maxi(maxima[0], maxima[1]), maxi(maxima[2], maxima[3])), "mean_per_channel_delta": mean, "mean_delta": float(total) / float(crop.get_area() * 4), "mean_delta_changed_pixels": float(total) / float(count * 4) if count > 0 else 0.0}

static func mutation_error(before: Image, after: Image, pixel: Vector2i) -> String:
	var a: Color = before.get_pixelv(pixel)
	var b: Color = after.get_pixelv(pixel)
	var delta: Array[int]
	for channel: int in range(4):
		delta.append(absi(roundi(a[channel] * 255.0) - roundi(b[channel] * 255.0)))
	if delta.max() == 0: return ""
	return "%s: viewport pixel (%d,%d), baseline-to-mutated RGBA delta %s" % [MUTATION_ERROR, pixel.x, pixel.y, str(delta)]

func write_case(case_id: int, label: String, original: Image, restored: Image, fresh: Image, board_bounds: Rect2, metadata: Dictionary, output: String = OUTPUT, emit_paths: bool = true, extra_images: Dictionary = {}, extra_pairs: Dictionary = {}) -> Dictionary:
	var images: Dictionary = {"original_submission": original, "restored": restored, "fresh": fresh}
	var mask_names: Dictionary = {}
	var pairs: Dictionary = {
		"restored_vs_original": compare(restored, original),
		"fresh_vs_original": compare(fresh, original),
		"restored_vs_fresh": compare(restored, fresh),
	}
	images.merge(extra_images)
	pairs.merge(extra_pairs)
	var frame := Rect2i(Vector2i.ZERO, restored.get_size())
	var crop := Rect2i(Vector2i(board_bounds.position.floor()), Vector2i(board_bounds.end.ceil() - board_bounds.position.floor())).intersection(frame)
	# Preserve every changed pixel, even if it lies outside geometric board bounds.
	for delta: Dictionary in pairs.values():
		if int(delta["differing_pixel_count"]) > 0:
			crop = crop.merge(delta["bounds"]) if crop.has_area() else delta["bounds"]
	if not crop.has_area(): crop = frame
	var directory: String = output.path_join("case_%03d" % case_id)
	var errors: Array[String]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		errors.append("Cannot create diagnostic directory: " + directory)
	var report: Dictionary = {"case": case_id, "label": label, "source_size": [restored.get_width(), restored.get_height()], "source_formats": [original.get_format(), restored.get_format(), fresh.get_format()], "crop_viewport": rect_json(crop), "measurement": "Absolute RGBA8 channel deltas (0..255), alpha included, no tolerance. Mean over all cropped pixels and all four channels; changed-pixel mean also supplied. Bounding boxes use x/y/width/height with exclusive end.", "metadata": metadata, "images": {}, "comparisons": {}}
	for name: String in pairs:
		var delta: Dictionary = pairs[name]
		var mask_name: String = "diff_mask" if name == "restored_vs_original" else "diff_" + name
		images[mask_name] = delta["mask"]
		mask_names[mask_name] = true
		report["comparisons"][name] = metrics(delta, crop)
	for name: String in images:
		var is_mask: bool = mask_names.has(name)
		var path: String = directory.path_join(name + (MASK_EXTENSION if is_mask else ".png"))
		var cropped: Image = (images[name] as Image).get_region(crop)
		# Binary masks may be correctly all black. Keep lossless data images out
		# of the visual runner's PNG screenshot-variation gate.
		var saved: Error = cropped.save_webp(path, false) if is_mask else cropped.save_png(path)
		if saved != OK:
			errors.append("Cannot save diagnostic image: " + path)
		report["images"][name] = ProjectSettings.globalize_path(path)
		if emit_paths: print(ProjectSettings.globalize_path(path))
	var report_path: String = directory.path_join("report.json")
	_write_json(report_path, report, errors, emit_paths)
	_entries.append({"case": case_id, "label": label, "report": ProjectSettings.globalize_path(report_path)})
	_write_json(output.path_join("index.json"), {"cases": _entries}, errors, emit_paths)
	return {"errors": errors, "report": report, "path": report_path}

static func _write_json(path: String, value: Dictionary, errors: Array[String], emit_path: bool) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append("Cannot save diagnostic JSON: " + path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	if emit_path: print(ProjectSettings.globalize_path(path))
