extends RefCounted
## Native-only image export. Compose sheets from the same crops as the PNG sequence.

const Evidence = preload("res://tools/fel03/evidence.gd")
const SCALE := 2
const COLUMNS := 5
const FRAME_SIZE := Evidence.CROP * SCALE
const LABEL_HEIGHT := 28
const LABEL_FONT_SIZE := 20
const FRAME_COUNT := 2 * Evidence.RADIUS + 1

var destination: String
var problem: String
var _label_bands: Image
var _strips: Array[String]
var _captions: Array[String]
var _notes: Array[String]


func prepare_labels(tree: SceneTree) -> bool:
	var bands := SubViewport.new()
	bands.size = Vector2i(FRAME_SIZE.x * COLUMNS, LABEL_HEIGHT * _rows())
	bands.render_target_update_mode = SubViewport.UPDATE_ONCE
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.size = Vector2(bands.size)
	bands.add_child(background)
	for index: int in FRAME_COUNT:
		var label := Label.new()
		label.text = offset_label(index - Evidence.RADIUS)
		label.position = Vector2((index % COLUMNS) * FRAME_SIZE.x, _row(index) * LABEL_HEIGHT)
		label.size = Vector2(FRAME_SIZE.x, LABEL_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		bands.add_child(label)
	tree.root.add_child(bands)
	await RenderingServer.frame_post_draw
	_label_bands = bands.get_texture().get_image()
	var expected: Vector2i = bands.size
	bands.queue_free()
	if _label_bands == null or _label_bands.get_size() != expected:
		problem = "could not read the sheet label bands"
		return false
	_label_bands.convert(Image.FORMAT_RGB8)
	return true


func add_note(note: String) -> void:
	_notes.append("- " + note)


func write_strip(id: String, row: Dictionary, index: int) -> bool:
	var stem: String = "%s-%s-%02d" % [id, row["category"], index]
	var folder: String = destination.path_join(stem)
	if DirAccess.make_dir_absolute(folder) != OK:
		problem = "cannot create " + folder
		return false
	var row_height: int = FRAME_SIZE.y + LABEL_HEIGHT
	var width: int = FRAME_SIZE.x * COLUMNS
	var sheet := Image.create_empty(width, row_height * _rows(), false, Image.FORMAT_RGB8)
	for band: int in _rows():
		sheet.blit_rect(_label_bands, Rect2i(0, band * LABEL_HEIGHT, width, LABEL_HEIGHT),
			Vector2i(0, band * row_height))
	for frame_index: int in FRAME_COUNT:
		var image: Image = row["frames"][frame_index]
		image.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_NEAREST)
		var filename: String = "frame-%s.png" % offset_label(frame_index - Evidence.RADIUS)
		if not _save_png(image, folder.path_join(filename)): return false
		var cell := Vector2i((frame_index % COLUMNS) * FRAME_SIZE.x, _row(frame_index) * row_height + LABEL_HEIGHT)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME_SIZE), cell)
	var sheet_name: String = stem + "-sheet.png"
	var path: String = destination.path_join(sheet_name)
	if not _save_png(sheet, path): return false
	print(path)
	_strips.append("| %s | [%s](%s) · [frames](%s/) | %s | %s | %s | %s | %s | %d | %s |" % [
		id, row["category"], sheet_name, stem, _cell(row["attacker"]), _cell(row["action"]), row["trail"],
		"yes" if row["element"] != "none" else "no", row["element"], row["contact"], row["crop"]])
	return true


func write_caption(id: String, row: Dictionary, index: int) -> bool:
	var filename: String = "%s-caption-%02d.png" % [id, index]
	var path: String = destination.path_join(filename)
	if not _save_png(row["image"], path): return false
	print(path)
	_captions.append("| %s | [%s](%s) | %s | %d | %s | %d | %d frames (%.3f s) |" % [
		id, _cell(row["text"]), filename, row["actor"], row["full"], row["rect"], row["font_px"],
		row["duration"], float(row["duration"]) / Evidence.FPS])
	return true


func write_index() -> bool:
	var path: String = destination.path_join("index.md")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		problem = "cannot open " + path
		return false
	var contents: String = """# Fel-03 melee and enemy captions

1920 × 1080 at 100%% UI scale, sampled at 60 Hz. Melee frame 0 is the production attack-feedback boundary. Baked comparison frame 0 is the first visible front stamp. Frame offsets are relative to frame 0. Caption duration is measured in displayed frames.

## Strips

| Fixture | Strip | Attacker | Action | Trail or burst | Elemental | Element | Contact frame | Crop in viewport pixels |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
%s

## Captions

| Fixture | Caption frame | Actor | Fully shown frame | Label rect in viewport pixels | Font (px) | On-screen duration |
| --- | --- | --- | --- | --- | --- | --- |
%s

## Fixture notes

%s
""" % ["\n".join(_strips), "\n".join(_captions), "\n".join(_notes)]
	if not file.store_string(contents):
		problem = "cannot write " + path
		return false
	return true


func _save_png(image: Image, path: String) -> bool:
	if image.save_png(path) == OK: return true
	problem = "cannot write " + path
	return false


static func offset_label(offset: int) -> String:
	return ("%s%02d" % ["-" if offset < 0 else "+", absi(offset)]) if offset != 0 else "00"


static func _cell(value: String) -> String:
	return value.replace("|", "\\|").replace("\n", " ")


static func _row(index: int) -> int:
	@warning_ignore("integer_division")
	return index / COLUMNS


static func _rows() -> int:
	return _row(FRAME_COUNT - 1) + 1
