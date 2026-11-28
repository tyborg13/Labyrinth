extends "res://tools/fel30/media.gd"
## Pair native crops with identical pixel extents, release left and branch right.

const PAIR_CELL := Vector2i(880, 190)
const PAIR_COLUMNS: int = 2
const CROP_PADDING: int = 18

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and _build_pairs(args[0], args[1]):
		quit()
		return
	push_error("FEL34 media could not assemble the selected caption pairs")
	quit(1)

func _build_pairs(selection_path: String, output: String) -> bool:
	var selection: Variant = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
	if not selection is Array or selection.size() != 13:
		return false
	var font: FontFile = load(FONT_PATH)
	var release: Dictionary = _frames(output.path_join("release"))
	var branch: Dictionary = _frames(output.path_join("branch"))
	var crops: String = output.path_join("crops")
	if font == null or DirAccess.make_dir_recursive_absolute(crops) != OK:
		return false
	var sheet := Image.create_empty(PAIR_CELL.x * PAIR_COLUMNS, PAIR_CELL.y * ceili(float(selection.size()) / PAIR_COLUMNS), false, Image.FORMAT_RGB8)
	sheet.fill(SHEET_BACKGROUND)
	for entry: Dictionary in selection:
		var key: String = entry["key"]
		var left: Dictionary = release.get(key, {})
		var right: Dictionary = branch.get(key, {})
		if left.get("text") != entry["text"] or right.get("text") != entry["text"]:
			push_error("FEL34 media missing paired caption at " + key)
			return false
		var pair: Image = _pair(left, right)
		if pair == null or pair.save_png(crops.path_join("%02d-%s.png" % [int(entry["rank"]), key])) != OK:
			return false
		var index: int = int(entry["rank"]) - 1
		var origin := Vector2i(index % PAIR_COLUMNS, index / PAIR_COLUMNS) * PAIR_CELL
		var factor: float = minf(float(PAIR_CELL.x - 24) / pair.get_width(), float(PAIR_CELL.y - 46) / pair.get_height())
		pair.resize(roundi(pair.get_width() * factor), roundi(pair.get_height() * factor), Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(pair, Rect2i(Vector2i.ZERO, pair.get_size()), origin + Vector2i((PAIR_CELL.x - pair.get_width()) / 2, 24))
		_caption(sheet, font, origin + Vector2i(12, 19), "%02d  Release | Branch" % int(entry["rank"]))
		_caption(sheet, font, origin + Vector2i(12, PAIR_CELL.y - 7), entry["text"])
	if sheet.save_png(output.path_join("sheet.png")) != OK:
		return false
	print("FEL34 MEDIA pairs=%d crops=%s sheet=%s" % [selection.size(), crops, output.path_join("sheet.png")])
	return true

func _frames(directory: String) -> Dictionary:
	var rows: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(directory.path_join("moments.jsonl")).split("\n", false):
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.has("frame"):
			rows[row["key"]] = row
	return rows

func _pair(left: Dictionary, right: Dictionary) -> Image:
	var area: Rect2i = _bounds(left["actual_rect"]).merge(_bounds(right["actual_rect"])).grow(CROP_PADDING)
	area = area.intersection(Rect2i(Vector2i.ZERO, SOURCE_SIZE))
	var output_size: Vector2i = area.size * CROP_SCALE
	if output_size.x <= 0 or output_size.y <= 0: return null
	var pair := Image.create_empty(output_size.x * 2, output_size.y, false, Image.FORMAT_RGB8)
	var index: int = 0
	for row: Dictionary in [left, right]:
		var source: Image = Image.load_from_file(row["frame"])
		if source == null or source.get_size() != SOURCE_SIZE: return null
		var crop: Image = source.get_region(area)
		crop.convert(Image.FORMAT_RGB8)
		crop.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		pair.blit_rect(crop, Rect2i(Vector2i.ZERO, output_size), Vector2i(index * output_size.x, 0))
		index += 1
	return pair

func _bounds(data: Array) -> Rect2i:
	var start := Vector2i(floori(data[0]), floori(data[1]))
	var end := Vector2i(ceili(data[0] + data[2]), ceili(data[1] + data[3]))
	return Rect2i(start, end - start)
