extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const Layout = preload("res://tools/txt36/page_layout.gd")
const Router = preload("res://scripts/input_router.gd")
const Search = preload("res://scripts/grimoire_search.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const LORE_QUERIES: Dictionary = {
	"ember_tick": "furnace",
	"ember_hoarder": "gorged",
	"slag_mortar": "strapped",
	"ash_hound": "scorched",
	"hoarfrost_seer": "hermit",
	"glacial_mirror": "pane",
	"rime_whelp": "snapping",
	"rime_spitter": "toad",
	"arc_thrall": "collar",
	"storm_capacitor": "unleashes",
	"bell_tender": "masked",
	"gale_herald": "banners",
	"gust_shrike": "hawk",
	"roc_fledgling": "roost",
	"burrow_grub": "chewing",
	"briar_weaver": "gardener",
	"stoneback_mite": "plates",
	"gloam_stalker": "sickles",
	"hollow_mimic": "armor",
	"wick_shade": "lost",
	"ashen_reaver": "falchion",
	"rimejaw": "skull",
	"storm_cantor": "hymns",
	"gallows_roc": "roost",
	"craghide": "centuries",
	"last_lamplighter": "keeper",
}
const CREATURES: String = "creatures"
const LAYOUT_FRAMES: int = 4

var _output: String
var _headless: bool
var _tops: int
var _bottoms: int
var _searches: int
var _pointer_opens: int


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_output = OS.get_environment("TXT36_OUTPUT")
	if not _output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("Set TXT36_OUTPUT to an absolute writable directory")
		quit(1)
		return

	_setup()
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)

	var scene: Node = await _instance(_run_with_available_combat(RunEngine.new()))
	scene._close_large_map()
	await _settle()
	var expected_order: Array[String] = _unlock_creatures(scene)
	scene._on_grimoire_button_pressed()
	var book: Control = scene._grimoire_scrim
	await _layout()
	_expect(is_equal_approx(Typography.ui_scale(book), 1.0), "Grimoire uses 100% UI scale")
	var section: Button = _nav_button(book, "section", CREATURES)
	if section == null:
		_fail("Creatures section is missing")
	else:
		book._grimoire_entry_scroll.ensure_control_visible(section)
		await _layout()
		await _click(section)
		await _settle()
		await _browse(book, expected_order)
		await _search(book)
	book.close()
	router.clear_forced_state_for_test()
	_viewport.queue_free()
	await process_frame
	print("TXT36 BROWSE: %d pointer opens, %d list-button signal opens" %
		[_pointer_opens, _tops - _pointer_opens])
	print("TXT36 PAGE PROOF: %s (%s, %d tops, %d bottoms, %d search hits)" %
		["FAIL" if _failed else "PASS", "headless" if _headless else "native", _tops, _bottoms, _searches])
	quit(int(_failed))


func _unlock_creatures(scene: Node) -> Array[String]:
	var ordered_ids: Array[String]
	var unlock_order: Array[String]
	for entry: Dictionary in BookData.data()["entries"]:
		if entry["section"] == CREATURES:
			ordered_ids.append(entry["id"])
	for entry: Dictionary in BookData.entries():
		unlock_order.append(entry["id"])
	unlock_order.reverse()
	var unlock: Dictionary = BookData.unlock_entries(scene._run_state, unlock_order)
	scene._run_state = unlock["state"]
	for enemy_id: String in LORE_QUERIES:
		_expect(_page_id(enemy_id) in unlock["added"], enemy_id + " unlocks through the catalog")
	return ordered_ids


func _browse(book: Control, expected_order: Array[String]) -> void:
	var observed: Array[String]
	for button: Button in book._grimoire_nav_buttons:
		if button.get_meta("grimoire_nav_kind", "") == "entry":
			observed.append(button.get_meta("grimoire_nav_id"))
	_expect(observed == expected_order, "All unlocked creature rows follow data order")
	print("TXT36 LIST: %d entries, data order=%s" % [observed.size(), observed == expected_order])
	for enemy_id: String in LORE_QUERIES:
		var id: String = _page_id(enemy_id)
		var button: Button = _nav_button(book, "entry", id)
		if button == null:
			_fail(id + " is missing from the Creatures list")
			continue
		var list_scroll: ScrollContainer = book._grimoire_entry_scroll
		var offset: float = button.get_global_rect().get_center().y - list_scroll.get_global_rect().get_center().y
		list_scroll.scroll_vertical += roundi(offset)
		await _layout()
		if list_scroll.get_global_rect().has_point(button.get_global_rect().get_center()):
			await _click(button)
			_pointer_opens += int(book._grimoire_selected_entry == id)
		else:
			var bar: VScrollBar = list_scroll.get_v_scroll_bar()
			print("TXT36 NAV OUT OF VIEW %s: content=%.0f, viewport=%.0f, scroll=%.0f, max=%.0f, page=%.0f" %
				[id, book._grimoire_section_list.size.y, list_scroll.size.y, bar.value, bar.max_value, bar.page])
			# Preserve page evidence if the nav range disappears after a rebuild.
			# Use the actual list Button's action without changing the scroll control.
			_expect(not button.disabled and button.is_visible_in_tree(), id + " has an enabled creature list row")
			button.pressed.emit()
		await _layout()
		var entry: Dictionary = BookData.entry_def(id)
		var scroll: ScrollContainer = book._grimoire_detail_scroll
		if book._grimoire_selected_entry != id or scroll.scroll_vertical != 0:
			_fail(id + " should open at the top from its list row")
			continue
		var page: Dictionary = Layout.inspect_top(book, entry, _expect)
		var stem: String = "enemy_" + enemy_id
		await _save(stem + "_top")
		_tops += 1
		var has_bottom: bool = bool(page.get("overflow", false))
		if has_bottom:
			scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
			await _layout()
			Layout.inspect_bottom(book, page, _expect)
			await _save(stem + "_bottom")
			_bottoms += 1
		print("TXT36 PAGE %02d/%02d %s: %d moves, %d traits, rule=%s, bottom=%s" %
			[observed.find(id) + 1, observed.size(), id, page.get("moves", 0),
			page.get("traits", 0), page.get("rule", false), has_bottom])


func _search(book: Control) -> void:
	for enemy_id: String in LORE_QUERIES:
		var id: String = _page_id(enemy_id)
		var entry: Dictionary = BookData.entry_def(id)
		var word: String = LORE_QUERIES[enemy_id]
		var lore_words: PackedStringArray = Search.normalize(" ".join(entry["lore"])).split(" ", false)
		_expect(word in lore_words, id + " query is an exact word in the protected lore")
		var title_hit: bool = _query_hit(book, id, entry["title"], "title")
		var lore_hit: bool = _query_hit(book, id, word, "rules")
		_searches += int(title_hit) + int(lore_hit)
		print("TXT36 SEARCH %s: title=%s, lore %s=%s" % [id, title_hit, word, lore_hit])


func _query_hit(book: Control, id: String, query: String, match_kind: String) -> bool:
	var input: LineEdit = book._grimoire_search_input
	input.text = query
	input.text_changed.emit(query)
	var button: Button = _nav_button(book, "entry", id)
	var hit: bool = false
	for result: Dictionary in book._grimoire_search_results:
		if result["entry"]["id"] == id:
			hit = result["match_kind"] == match_kind and button != null and button.is_visible_in_tree()
			break
	_expect(hit, "%s search finds %s as a %s match" % [query, id, match_kind])
	return hit


func _nav_button(book: Control, kind: String, id: String) -> Button:
	for button: Button in book._grimoire_nav_buttons:
		if button.get_meta("grimoire_nav_kind", "") == kind and button.get_meta("grimoire_nav_id", "") == id:
			return button
	return null


func _page_id(enemy_id: String) -> String:
	return "enemy:" + enemy_id


func _layout() -> void:
	for _frame: int in range(LAYOUT_FRAMES):
		await process_frame


func _save(stem: String) -> void:
	var path: String = _output.path_join(stem + "_1920x1080.png")
	if _headless:
		print("WOULD CAPTURE " + path)
		return
	await _capture(path)
	if FileAccess.file_exists(path):
		print(path)
