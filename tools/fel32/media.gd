extends SceneTree
## Compose the validated native frames and enlarge identical crops side by side.

const FRAME_SIZE := Vector2i(1920, 1080)
const CROP_SCALE := 3
const CROP_PADDING := 8
const CASES := ["fire", "stone", "hero"]
const ADJACENT := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	for label: String in CASES:
		if not _pair(args[0], label):
			push_error("FEL32 MEDIA: mismatched or empty native proof for " + label)
			quit(1)
			return
	print("FEL32 NATIVE pairs=%d crops=%d output=%s" % [CASES.size(), CASES.size(), args[0]])
	quit()

func _pair(output: String, label: String) -> bool:
	var left: Dictionary = _load(output.path_join("release"), label)
	var right: Dictionary = _load(output.path_join("branch"), label)
	if left.is_empty() or right.is_empty(): return false
	var before: Dictionary = left["geometry"]
	var after: Dictionary = right["geometry"]
	for field: String in ["combat", "turn", "hero", "hero_threatened"]:
		if before[field] != after[field]: return false
	if label == "hero" and not before["hero_threatened"]: return false
	if _ids(before["tiles"]) != _ids(after["tiles"]): return false
	var group: Array[Vector2i] = _largest_group(before["tiles"])
	if group.is_empty(): return false
	var crop: Rect2i = _crop_rect(group, before["tiles"], after["tiles"])
	if not crop.has_area(): return false
	var stem: String = output.path_join(label)
	if _join(left["image"], right["image"]).save_png(stem + "-comparison.png") != OK: return false
	var left_crop: Image = (left["image"] as Image).get_region(crop)
	var right_crop: Image = (right["image"] as Image).get_region(crop)
	for image: Image in [left_crop, right_crop]:
		image.resize(crop.size.x * CROP_SCALE, crop.size.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
	if _join(left_crop, right_crop).save_png(stem + "-crop-3x.png") != OK: return false
	print("FEL32 NATIVE %s combat=%d turn=%d tiles=%d crop_tiles=%d" %
		[label, before["combat"], before["turn"], before["tiles"].size(), group.size()])
	return true

func _load(folder: String, label: String) -> Dictionary:
	var image: Image = Image.load_from_file(folder.path_join(label + ".png"))
	var geometry: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(label + ".json")))
	if image == null or image.get_size() != FRAME_SIZE or not geometry is Dictionary or geometry["tiles"].is_empty(): return {}
	image.convert(Image.FORMAT_RGB8)
	return {"image": image, "geometry": geometry}

func _ids(rows: Array) -> Array[Vector2i]:
	var ids: Array[Vector2i]
	for row: Dictionary in rows: ids.append(Vector2i(row["tile"][0], row["tile"][1]))
	ids.sort()
	return ids

func _largest_group(rows: Array) -> Array[Vector2i]:
	var ids: Array[Vector2i] = _ids(rows)
	var remaining: Dictionary
	for tile: Vector2i in ids: remaining[tile] = true
	var best: Array[Vector2i]
	for start: Vector2i in ids:
		if not remaining.erase(start): continue
		var group: Array[Vector2i]
		group.append(start)
		var index: int = 0
		while index < group.size():
			for step: Vector2i in ADJACENT:
				var next: Vector2i = group[index] + step
				if remaining.erase(next): group.append(next)
			index += 1
		if group.size() > best.size(): best = group
	return best

func _crop_rect(group: Array[Vector2i], before: Array, after: Array) -> Rect2i:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for rows: Array in [before, after]:
		for tile: Dictionary in rows:
			if not group.has(Vector2i(tile["tile"][0], tile["tile"][1])): continue
			for pair: Array in tile["diamond"]:
				var point := Vector2(pair[0], pair[1])
				low = low.min(point)
				high = high.max(point)
	var bounds := Rect2i(Vector2i(low.floor()), Vector2i(high.ceil() - low.floor()))
	return bounds.grow(CROP_PADDING).intersection(Rect2i(Vector2i.ZERO, FRAME_SIZE))

func _join(left: Image, right: Image) -> Image:
	var size: Vector2i = left.get_size()
	var pair := Image.create_empty(size.x * 2, size.y, false, Image.FORMAT_RGB8)
	var rect := Rect2i(Vector2i.ZERO, size)
	pair.blit_rect(left, rect, Vector2i.ZERO)
	pair.blit_rect(right, rect, Vector2i(size.x, 0))
	return pair
