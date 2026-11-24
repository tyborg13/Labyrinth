extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const BookPanel = preload("res://scripts/grimoire_panel.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const CombatBoard = preload("res://scripts/combat_board_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Router = preload("res://scripts/input_router.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const CAPTURE_IDS: Array[String] = ["glacial_mirror", "gust_shrike", "cinder_ooze"]
const CATALOG_COUNT: int = 44
const ENEMY_FIXTURE_ID: int = 1
const LAYOUT_FRAMES: int = 4
const GEOMETRY_TOLERANCE: float = 1.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture: bool = not OS.get_environment("TXT37_OUTPUT").is_empty()
	var before: bool = args.has("--before")
	var override_path: String = OS.get_environment("TXT37_GRIMOIRE")
	if not override_path.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(override_path))
		if not parsed is Dictionary or not parsed.has("entries"):
			_fail("Invalid TXT37_GRIMOIRE override")
			quit(1)
			return
		BookData._cache = parsed
	_setup()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	var book := BookPanel.new()
	_viewport.add_child(book)
	book.build()
	var pages: Array[String]
	for entry: Dictionary in BookData.entries():
		var enemy_id: String = str(entry.get("enemy_id", ""))
		if not enemy_id.is_empty():
			pages.append(enemy_id)
	_expect(pages.size() == CATALOG_COUNT, "Expected %d creature pages" % CATALOG_COUNT)
	_expect(GameData.enemies().size() == CATALOG_COUNT, "Expected the full creature catalog")
	if not override_path.is_empty():
		_expect(pages.size() == GameData.enemies().size() and pages.all(
			func(enemy_id: String) -> bool: return GameData.enemies().has(enemy_id)),
			"Expanded pages cover the enemy catalog")
	book.set_catalog(BookData.unlock_entries({}, pages.map(
		func(enemy_id: String) -> String: return "enemy:" + enemy_id))["state"])
	book.open(null)
	await _layout()
	_expect(is_equal_approx(Typography.ui_scale(book), 1.0), "Grimoire uses 100% UI scale")
	_expect(_viewport.size == PROBE_VIEWPORT, "Grimoire proof uses 1920x1080")
	var board := CombatBoard.new()
	var combat := Combat.new()
	var checked: Dictionary = {}
	var selected: Array[String] = CAPTURE_IDS if capture else pages
	for enemy_id: String in selected:
		var entry_id: String = "enemy:" + enemy_id
		book._on_grimoire_entry_pressed(entry_id)
		await _layout()
		_expect(book._grimoire_detail_title.text == str(BookData.entry_def(entry_id).get("title", ""))
			and book.find_child("GrimoireMoves", true, false) != null, entry_id + " opens its creature page")
		var badges: Array[Dictionary] = _base_badges(board, combat, enemy_id)
		var section: Control = book.find_child("GrimoireTraits", true, false)
		var rows: Array[Dictionary] = _page_rows(section, badges)
		checked[enemy_id] = {"badges": badges.map(func(badge: Dictionary) -> String: return badge["icon"]),
			"page": rows.map(func(row: Dictionary) -> String: return row["icon"]), "rows": rows}
		if not before:
			_check_traits(enemy_id, rows, badges)
		if capture:
			await _capture_traits(book, section, enemy_id)
	board.free()
	book.close()
	router.clear_forced_state_for_test()
	_viewport.queue_free()
	await process_frame
	if not capture:
		print("TXT37 INVENTORY " + JSON.stringify(checked))
	var mode: String = "native" if DisplayServer.get_name() != "headless" else "headless"
	print("TXT37 PAGES: %s (%s, %d %s)" % ["FAIL" if _failed else "PASS",
		mode, checked.size(), "capture states" if capture else "creatures"])
	quit(int(_failed))


func _base_badges(board: Control, combat: RefCounted, enemy_id: String) -> Array[Dictionary]:
	var enemy: Dictionary = combat._spawned_enemy_entry({}, enemy_id, ENEMY_FIXTURE_ID, Vector2i.ZERO, false)
	board.combat_state = {"enemies": [enemy]}
	var units: Array[Dictionary] = board._build_visible_units()
	_expect(units.size() == 1 and units[0]["type"] == enemy_id, enemy_id + " enters the combat board")
	var result: Array[Dictionary]
	if not units.is_empty():
		for badge: Dictionary in board._unit_status_presentation_badges(units[0]):
			if badge["status_class"] == "trait":
				result.append({"icon": badge["icon"], "tooltip": badge["tooltip"], "count": badge.get("count", 0)})
	return result


func _page_rows(section: Control, badges: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary]
	if section == null:
		return rows
	var icons: Dictionary = {}
	for badge: Dictionary in badges:
		var texture: Texture2D = Icons.icon_texture(badge["icon"])
		_expect(texture != null, str(badge["icon"]) + " resolves to a trait icon")
		if texture != null:
			icons[texture] = badge["icon"]
	for index: int in range(1, section.get_child_count(), 2):
		var row: Control = section.get_child(index)
		var socket: Control = row.get_child(0)
		var icon: TextureRect = socket.find_children("*", "TextureRect", true, false)[0]
		var text: Control = row.get_child(1)
		var title: Label = text.get_child(0)
		var details: RichTextLabel = text.get_child(1)
		rows.append({"icon": icons.get(icon.texture, "unmatched"), "title": title.text,
			"details": details.get_parsed_text().strip_edges()})
	return rows


func _check_traits(enemy_id: String, rows: Array[Dictionary], badges: Array[Dictionary]) -> void:
	_expect(rows.size() == badges.size(), enemy_id + " has the same number of rows and trait badges")
	for index: int in range(mini(rows.size(), badges.size())):
		var row: Dictionary = rows[index]
		var badge: Dictionary = badges[index]
		var icon: String = badge["icon"]
		var tooltip: String = badge["tooltip"]
		var parts: PackedStringArray = tooltip.split("\n", true, 1)
		var title: String = Icons.label(icon) if parts.size() == 1 else parts[0]
		var details: String = parts[-1]
		if icon == "burst":
			title += " %d" % int(badge["count"])
		_expect(row["icon"] == icon and row["title"] == title and row["details"] == details,
			"%s matches combat badge %s at row %d. Got %s" % [enemy_id, icon, index, row])


func _capture_traits(book: Control, section: Control, enemy_id: String) -> void:
	if section == null:
		_fail(enemy_id + " has no Traits section to capture")
		return
	var output: String = OS.get_environment("TXT37_OUTPUT")
	var scroll: ScrollContainer = book._grimoire_detail_scroll
	scroll.scroll_vertical += roundi(section.global_position.y - scroll.global_position.y)
	await _layout()
	_expect(scroll.scroll_vertical > 0, enemy_id + " scrolls to Traits")
	_expect(scroll.get_global_rect().grow(GEOMETRY_TOLERANCE).encloses(section.get_global_rect()),
		enemy_id + " shows the whole Traits section")
	for rules: RichTextLabel in section.find_children("*", "RichTextLabel", true, false):
		_expect(rules.get_content_height() <= rules.size.y + GEOMETRY_TOLERANCE,
			enemy_id + " fits the trait tooltip text")
	var path: String = output.path_join("enemy_%s_traits_1920x1080.png" % enemy_id)
	if DisplayServer.get_name() == "headless":
		print("WOULD CAPTURE " + path)
	else:
		await _capture(path)
		print(path)


func _layout() -> void:
	for _frame: int in range(LAYOUT_FRAMES):
		await process_frame
