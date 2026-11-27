extends "res://tools/fel03/frame_output.gd"
## Individual crops and peaks retain native evidence. Family sheets draw only
## verified rows. The Unverified sheet has every unresolved ID, even with no frames.

const Capture = preload("res://tools/fel10/strip_capture.gd")
const PREVIEW_SIZE := Vector2i(192, 144)
const UNVERIFIED_PREVIEW := Vector2i(96, 72)
const FAMILY_WIDTH := Capture.FRAMES * PREVIEW_SIZE.x

var _previews: Dictionary


func write_effect(tree: SceneTree, row: Dictionary, strip: Capture, result: Dictionary, retry: bool) -> bool:
	var id: String = row["id"]
	var relative: String = id.path_join("retry") if retry else id
	var folder: String = destination.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		problem = "cannot create " + folder
		return false
	var width: int = COLUMNS * FRAME_SIZE.x
	var rows: int = _row(strip.frames.size() - 1) + 1
	var sheet := Image.create_empty(width, rows * FRAME_SIZE.y + LABEL_HEIGHT, false, Image.FORMAT_RGB8)
	var labels: Image = await _headers(tree, width, [_title(row, result)])
	if labels == null: return false
	sheet.blit_rect(labels, Rect2i(0, 0, width, LABEL_HEIGHT), Vector2i.ZERO)
	var preview := Image.create_empty(FAMILY_WIDTH, PREVIEW_SIZE.y, false, Image.FORMAT_RGB8)
	for n: int in strip.frames.size():
		var frame: Image = strip.frames[n]
		frame.convert(Image.FORMAT_RGB8)
		frame.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_NEAREST)
		if not _save_png(frame, folder.path_join("frame-%04d.png" % strip.samples[n])): return false
		var cell := Vector2i((n % COLUMNS) * FRAME_SIZE.x, _row(n) * FRAME_SIZE.y + LABEL_HEIGHT)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME_SIZE), cell)
		frame.resize(PREVIEW_SIZE.x, PREVIEW_SIZE.y, Image.INTERPOLATE_NEAREST)
		preview.blit_rect(frame, Rect2i(Vector2i.ZERO, PREVIEW_SIZE), Vector2i(n * PREVIEW_SIZE.x, 0))
	result["strip"] = relative.path_join(id + "-strip.png")
	result["peak_path"] = relative.path_join(id + "-peak.png")
	result["sequence"] = relative + "/"
	if not _save_png(sheet, destination.path_join(result["strip"])): return false
	if not _save_png(strip.peak, destination.path_join(result["peak_path"])): return false
	# The visual runner checks verified evidence and the two sheet classes.
	# Failed attempts remain linked in the index for diagnosis.
	if result["verified"] == "yes":
		print(destination.path_join(result["strip"]))
		print(destination.path_join(result["peak_path"]))
	_previews[id] = preview
	return true


func write_family_sheets(tree: SceneTree, plan: Array[Dictionary], results: Dictionary) -> bool:
	var families: Dictionary
	var unverified: Array[Dictionary]
	for row: Dictionary in plan:
		if results[row["id"]]["verified"] != "yes":
			unverified.append(row)
			continue
		var family: String = row["family"]
		if not families.has(family): families[family] = []
		families[family].append(row)
	var lines := PackedStringArray([
		"# Combat effects census", "",
		"1920 × 1080 at 100% UI scale with the full cel look. Crops follow the effect’s drawn bounds across its lifetime. Frames are kept in order at 60 Hz and sampled evenly when more than 25 were drawn. Peak change is measured in the effect bounds against the same crop before onset.", "",
		"## Family sheets", "",
	])
	for family: String in families:
		var filename: String = "family-" + family + ".png"
		if not await _family(tree, families[family], results, filename, PREVIEW_SIZE): return false
		lines.append("- [%s](%s)" % [family, filename])
	if not await _family(tree, unverified, results, "family-unverified.png", UNVERIFIED_PREVIEW): return false
	lines.append("- [Unverified](family-unverified.png)")
	lines.append_array(["", "## Strips in inventory order", "",
		"| Effect | Draw path | Strip | Frames | Peak | Verified | Co-occurring |",
		"| --- | --- | --- | --- | --- | --- | --- |"])
	for row: Dictionary in plan:
		var id: String = row["id"]
		var result: Dictionary = results[id]
		var links: Array[String]
		if result.has("strip"):
			links.append("[Strip](%s)" % result["strip"])
			links.append("[%d/%d](%s)" % [result["frames"], result["lifetime"], result["sequence"]])
			links.append("[Frame %d](%s)" % [result["peak"], result["peak_path"]])
		else:
			links.assign(["—", "—", "—"])
		var others: PackedStringArray = result.get("cooccurring", PackedStringArray())
		lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [
			id, _cell(row["path"]), links[0], links[1], links[2], _cell(result["verified"]),
			"—" if others.is_empty() else ", ".join(others)])
	lines.append_array(["", "## Unverified", ""])
	for row: Dictionary in unverified:
		var id: String = row["id"]
		var result: Dictionary = results[id]
		lines.append("- `%s` — %s" % [id, result["verified"]])
	if unverified.is_empty(): lines.append("None.")
	if not _write_text("index.md", "\n".join(lines) + "\n"): return false
	var records: Array[Dictionary]
	for row: Dictionary in plan:
		var record: Dictionary = results[row["id"]].duplicate()
		record["id"] = row["id"]
		records.append(record)
	return _write_text("capture-evidence.json", JSON.stringify(records, "\t") + "\n")


func _write_text(name: String, contents: String) -> bool:
	var file := FileAccess.open(destination.path_join(name), FileAccess.WRITE)
	if file != null and file.store_string(contents): return true
	problem = "cannot write " + name
	return false


func _family(tree: SceneTree, rows: Array, results: Dictionary, filename: String, miniature: Vector2i) -> bool:
	var width: int = Capture.FRAMES * miniature.x
	var row_height: int = miniature.y + LABEL_HEIGHT
	var sheet := Image.create_empty(width, row_height * maxi(rows.size(), 1), false, Image.FORMAT_RGB8)
	var texts: Array[String]
	for row: Dictionary in rows: texts.append(_title(row, results[row["id"]]))
	if texts.is_empty(): texts.append("No unverified effects.")
	var labels: Image = await _headers(tree, width, texts)
	if labels == null: return false
	for index: int in texts.size():
		var y: int = index * row_height
		sheet.blit_rect(labels, Rect2i(0, index * LABEL_HEIGHT, width, LABEL_HEIGHT), Vector2i(0, y))
		if index >= rows.size(): continue
		var preview: Image = _previews.get(rows[index]["id"])
		if preview == null: continue
		if miniature != PREVIEW_SIZE:
			preview = preview.duplicate()
			preview.resize(width, miniature.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(preview, Rect2i(0, 0, width, miniature.y), Vector2i(0, y + LABEL_HEIGHT))
	var path: String = destination.path_join(filename)
	if not _save_png(sheet, path): return false
	print(path)
	return true


func _headers(tree: SceneTree, width: int, titles: Array) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, titles.size() * LABEL_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var backing := ColorRect.new()
	backing.color = Color.BLACK
	backing.size = Vector2(viewport.size)
	viewport.add_child(backing)
	for index: int in titles.size():
		var label := Label.new()
		label.text = titles[index]
		label.position = Vector2(12, index * LABEL_HEIGHT)
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		viewport.add_child(label)
	tree.root.add_child(viewport)
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var size: Vector2i = viewport.size
	viewport.queue_free()
	if image == null or image.get_size() != size:
		problem = "could not render strip headers"
		return null
	image.convert(Image.FORMAT_RGB8)
	return image


static func _title(row: Dictionary, result: Dictionary) -> String:
	return "%s  |  %s  |  %s  |  %s" % [
		row["id"], row["path"], result.get("scale_stride", "No frames"),
		"Verified" if result["verified"] == "yes" else result["verified"]]
