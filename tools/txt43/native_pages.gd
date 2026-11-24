extends RefCounted

const BookData = preload("res://scripts/grimoire_library.gd")
const BookPanel = preload("res://scripts/grimoire_panel.gd")
const LAYOUT_FRAMES: int = 4
const SCROLL_INSET: int = 24
const GEOMETRY_TOLERANCE: float = 1.0
const PAGES: Dictionary = {
	"gust_shrike": {"GrimoireTraits": "Flying", "GrimoireMoves": "Dive"},
	"frostglass_lancer": {"GrimoireMoves": "Refract Guard"},
	"craghide": {"GrimoireMoves": "Groundsplit"},
	"burrow_grub": {"GrimoireMoves": "Erupt"},
	"ember_hoarder": {"GrimoireMoves": "Kindle"},
	"storm_capacitor": {"GrimoireTraits": "Charge"},
	"iskaldra": {"GrimoireMoves": "Crystal Mantle"},
	"grave_surgeon": {"GrimoireMoves": "Field Brace"},
}

static func capture_all(viewport: SubViewport, output: String, expect: Callable, capture: Callable) -> int:
	var tree: SceneTree = viewport.get_tree()
	var book := BookPanel.new()
	viewport.add_child(book)
	book.build()
	var ids: Array[String]
	for enemy_id: String in PAGES:
		ids.append("enemy:" + enemy_id)
	book.set_catalog(BookData.unlock_entries({}, ids)["state"])
	book.open(null)
	await _layout(tree)
	var captured: int = 0
	for enemy_id: String in PAGES:
		var entry_id: String = "enemy:" + enemy_id
		var entry: Dictionary = BookData.entry_def(entry_id)
		expect.call(not entry.is_empty(), entry_id + " is in the production Grimoire")
		if entry.is_empty(): continue
		book._on_grimoire_entry_pressed(entry_id)
		await _layout(tree)
		expect.call(book._grimoire_detail_title.text == entry["title"], entry_id + " opens the correct page")
		var rows: Array[Control]
		for section_name: String in PAGES[enemy_id]:
			var title: String = PAGES[enemy_id][section_name]
			var row: Control = _find_row(book.find_child(section_name, true, false), title)
			expect.call(row != null, entry_id + " shows " + title)
			if row != null: rows.append(row)
		if rows.size() != PAGES[enemy_id].size(): continue
		if not await _reveal(tree, book._grimoire_detail_scroll, rows):
			expect.call(false, entry_id + " capture must show each requested row fully")
			continue
		var path: String = output.path_join("grimoire_%s_1920x1080.png" % enemy_id)
		if DisplayServer.get_name() == "headless":
			print("WOULD CAPTURE " + path)
		else:
			await capture.call(path)
			if not FileAccess.file_exists(path): continue
			print(path)
		print("TXT43 GRIMOIRE CAPTURE: %s | %s" % [enemy_id, JSON.stringify(PAGES[enemy_id].values())])
		captured += 1
	book.close()
	book.queue_free()
	await tree.process_frame
	return captured

static func _find_row(section: Control, title: String) -> Control:
	if section == null: return null
	for index: int in range(1, section.get_child_count(), 2):
		var row: Control = section.get_child(index)
		var label: Label = row.get_child(1).get_child(0)
		if label.text == title: return row
	return null

static func _reveal(tree: SceneTree, scroll: ScrollContainer, rows: Array[Control]) -> bool:
	var bounds: Rect2 = rows[0].get_global_rect()
	for row: Control in rows:
		bounds = bounds.merge(row.get_global_rect())
	scroll.scroll_vertical += roundi(bounds.position.y - scroll.global_position.y) - SCROLL_INSET
	await _layout(tree)
	for row: Control in rows:
		if not scroll.get_global_rect().grow(GEOMETRY_TOLERANCE).encloses(row.get_global_rect()): return false
		var rules: RichTextLabel = row.get_child(1).get_child(1)
		if rules.get_content_height() > rules.size.y + GEOMETRY_TOLERANCE: return false
	return true

static func _layout(tree: SceneTree) -> void:
	for _frame: int in LAYOUT_FRAMES:
		await tree.process_frame
