extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const BookSearch = preload("res://scripts/grimoire_search.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Fixture = preload("res://tools/txt24/fixture.gd")
const Router = preload("res://scripts/input_router.gd")
const LEADING_INLINE_SPACES: String = "(?m)^ +"
const LAYOUT_FRAMES: int = 4
const STICK_DELTA: float = 0.1
const SCROLL_DOWN: float = 1.0
const SCROLL_UP: float = -1.0
const RULES_PAGES: Array = [
	"basic:map", "combat:defiance", "combat:targeting", "combat:fatigue",
	"keyword:card_play", "combat:cinder_marks", "combat:crystal_armor", "combat:boss_eclipse",
]
const CAPTURE_CREATURES: Array = [
	"enemy:harrier", "enemy:cinder_ooze", "enemy:grave_surgeon", "enemy:lightning_wisp",
	"enemy:zekarion", "enemy:vyraketh", "enemy:noctyrax",
]

var _output: String
var _before: bool
var _headless: bool
var _captures: int = 0
var _leading_spaces := RegEx.create_from_string(LEADING_INLINE_SPACES)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output = OS.get_environment("TXT34_OUTPUT")
	_before = OS.get_environment("TXT34_VERSION") == "before"
	_headless = DisplayServer.get_name() == "headless"
	if _output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("Set TXT34_OUTPUT to a writable directory")
		quit(1)
		return
	_setup()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	router.set_forced_state_for_test(Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	var coord: Vector2i = _first_available_combat_coord(engine, state)
	var book_entries: Array = RULES_PAGES.duplicate()
	for entry: Dictionary in BookData.entries():
		if entry.has("enemy_id"): book_entries.append(entry["id"])
	var scene: Node = await _instance(state)
	scene._run_state = BookData.unlock_entries(scene._run_state, book_entries)["state"]
	scene._open_grimoire_overlay()
	var book: Control = scene._grimoire_scrim
	_expect(is_equal_approx(Typography.ui_scale(book), 1.0), "Grimoire uses 100% UI scale")
	var inventory: Dictionary = {}
	var pinned_lore: Dictionary = {}
	var pinned_rules: Dictionary = {}
	if not _before:
		pinned_lore = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/txt20_rules_copy.json"))["grimoire_lore"]
		pinned_rules = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pla02_grimoire_pages.json"))["pages"]
	for page_id: String in book_entries:
		book._on_grimoire_entry_pressed(page_id)
		await _layout_frames()
		var entry: Dictionary = BookData.entry_def(page_id)
		if not _before:
			if page_id in RULES_PAGES:
				_expect(entry["body"] == pinned_rules[page_id], page_id + " matches the updated rules fixture")
			else:
				_expect(not entry.has("body") and entry["lore"] == pinned_lore[page_id], page_id + " matches the lore fixture")
		inventory[page_id] = _read_page(book, entry)
		if page_id in CAPTURE_CREATURES or page_id in RULES_PAGES:
			var stem: String = page_id.replace(":", "_")
			await _save(stem + ("_top" if page_id == "enemy:vyraketh" else ""))
			if page_id == "enemy:vyraketh":
				if not _before: await _scroll_proof(book)
				await _save(stem + "_bottom")
	if not _before:
		var results: Array[Dictionary] = BookSearch.search(BookData.entries(), BookData.sections(), "gobbet")
		_expect(not results.is_empty() and results.front()["entry"]["id"] == "enemy:cinder_droplet",
			"Search ranks the creature whose lore contains gobbet")
	book.close()
	await _inspect_harrier(scene, engine, state, coord, inventory)
	Fixture.save_json(_output.path_join("inventory.json"), inventory)
	scene._close_pinned_tooltip()
	router.clear_forced_state_for_test()
	await _settle()
	_viewport.queue_free()
	await process_frame
	print("TXT34 PAGE PROOF: %s (%s, %d pages, %d capture states)" %
		["FAIL" if _failed else "PASS", "headless" if _headless else "native", book_entries.size(), _captures])
	quit(int(_failed))


func _layout_frames() -> void:
	for _frame: int in range(LAYOUT_FRAMES):
		await process_frame


func _read_page(book: Control, entry: Dictionary) -> Dictionary:
	var id: String = entry["id"]
	var body: RichTextLabel = book._grimoire_detail_body
	var title: Label = book._grimoire_detail_title
	var plain: String = _leading_spaces.sub(body.get_parsed_text(), "", true).strip_edges()
	var expected: String = "\n\n".join(entry.get("lore", entry.get("body", [])))
	# Device-specific bindings and inline text are normalized just as the page displays them.
	var markup: String = book._grimoire_body_text(entry)
	_expect(title.text == entry["title"] and body.is_visible_in_tree(), id + " selects the expected page")
	_expect(plain == Inline.plain_text(Inline.Patterns.display_rules(markup)).strip_edges(), id + " renders the complete body")
	_expect(body.get_content_height() <= body.size.y, id + " has no clipped body text")
	_expect(book._grimoire_detail_panel.get_global_rect().encloses(title.get_global_rect()), id + " keeps the header in the pane")
	_expect(not entry.has("lore") or markup == expected, id + " uses the exact lore paragraphs")
	var sections: Array = []
	if not _before and entry.has("enemy_id"):
		sections = _check_sections(book, entry)
	elif not _before:
		_expect(not book._grimoire_detail_scroll.visible and body.scroll_active, id + " keeps the article layout")
	print("TXT34 PAGE %s | body=%dpx text=%dpx sections=%s" % [id, body.size.y, body.get_content_height(), sections])
	return {"title": title.text, "body": plain, "sections": sections}


func _check_sections(book: Control, entry: Dictionary) -> Array:
	var enemy_id: String = entry["enemy_id"]
	var instance: Dictionary = Rules.instance_for(enemy_id)
	var rule: Control = book.find_child("GrimoireBattlefieldRule", true, false)
	_expect((rule == null) == instance.is_empty(), enemy_id + " only shows a battlefield rule when present")
	if rule != null:
		var rule_text: VBoxContainer = rule.get_child(1).get_child(1)
		_expect(rule_text.get_child(1).get_parsed_text() == instance["sentence"], enemy_id + " shows the rule sentence verbatim")
		if instance.has("at_half_health"):
			_expect(rule_text.get_child(2).text == "At half Health"
				and rule_text.get_child(3).get_parsed_text() == instance["at_half_health"]["sentence"],
				enemy_id + " shows its half-Health caption and sentence")
	var traits: Control = book.find_child("GrimoireTraits", true, false)
	if enemy_id == "cinder_ooze":
		_expect(traits != null and _labels_text(traits).contains("Splits 2"), "Cinder Ooze shows Split")
	if enemy_id == "zekarion":
		_expect(traits != null and _labels_text(traits).contains("Immune"), "Zekarion shows Immune")
	var intents: Array = GameData.enemy_def(enemy_id)["intents"]
	var moves: Control = book.find_child("GrimoireMoves", true, false)
	_expect(moves != null and moves.get_child_count() == 1 + intents.size() * 2, enemy_id + " shows all moves and separators")
	if moves != null:
		_expect(_labels_text(moves.get_child(0)) == "Moves\nBase values", enemy_id + " labels the move values")
		for index: int in range(intents.size()):
			var row: HBoxContainer = moves.get_child(index * 2 + 1)
			var intent: Dictionary = intents[index]
			var row_labels: String = _labels_text(row)
			var summary: RichTextLabel = row.get_child(1).get_child(1)
			_expect(row_labels == "%s\nTime %d" % [intent["name"], int(intent["time"])], enemy_id + " preserves move order, name and Time")
			_expect(row.size.y >= 52 and summary.get_content_height() <= summary.size.y
				and row.get_child(0).size == Vector2(40, 40), enemy_id + " fits its row summary and socket")
	var scroll: ScrollContainer = book._grimoire_detail_scroll
	_expect(scroll.visible and scroll.scroll_vertical == 0 and scroll.is_ancestor_of(book._grimoire_detail_body),
		enemy_id + " opens at the top of the detail scroll")
	_expect(not scroll.is_ancestor_of(book._grimoire_detail_title), enemy_id + " has a fixed header")
	var sections: Array = []
	if book._grimoire_detail_content.get_child_count() > 0:
		for inset: Control in book._grimoire_detail_content.get_child(0).get_children():
			sections.append(str(inset.get_child(0).name))
	var expected: Array = []
	if rule != null: expected.append("GrimoireBattlefieldRule")
	if traits != null: expected.append("GrimoireTraits")
	if moves != null: expected.append("GrimoireMoves")
	_expect(sections == expected, enemy_id + " follows battlefield rule, traits, moves order")
	return sections


func _scroll_proof(book: Control) -> void:
	var scroll: ScrollContainer = book._grimoire_detail_scroll
	var title_rect: Rect2 = book._grimoire_detail_title.get_global_rect()
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	_expect(bar.visible, "Vyraketh overflows the right pane")
	var nav_position: int = book._grimoire_entry_scroll.scroll_vertical
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = scroll.get_global_rect().get_center()
	_viewport.push_input(wheel, true)
	await _layout_frames()
	var wheel_position: int = scroll.scroll_vertical
	_expect(wheel_position > 0 and book._grimoire_entry_scroll.scroll_vertical == nav_position, "Wheel advances the creature pane")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = SCROLL_UP
	_viewport.push_input(stick, true)
	book._process(STICK_DELTA)
	_expect(scroll.scroll_vertical < wheel_position, "Right stick scrolls back up")
	stick.axis_value = SCROLL_DOWN
	_viewport.push_input(stick, true)
	book._process(STICK_DELTA)
	_expect(scroll.scroll_vertical > 0, "Right stick scrolls down")
	stick.axis_value = 0.0
	_viewport.push_input(stick, true)
	bar.value = bar.max_value
	await _layout_frames()
	_expect(scroll.scroll_vertical == roundi(bar.max_value - bar.page), "Capture reaches the bottom of the move table")
	_expect(book._grimoire_detail_title.get_global_rect() == title_rect, "Scrolling leaves the header fixed")
	print("TXT34 SCROLL: wheel=%d, bottom=%d, fixed header" % [wheel_position, scroll.scroll_vertical])


func _inspect_harrier(scene: Node, engine: RunEngine, state: Dictionary, coord: Vector2i, inventory: Dictionary) -> void:
	scene._load_run_state(_pre_battle_state_for_room(engine, state, coord))
	scene._show_pre_battle_preview()
	await _settle()
	var preview: Dictionary = scene._pre_battle_preview_run_state
	var harrier: Dictionary = Fixture.unit("harrier", 0, Fixture.ENEMY)
	preview["combat_state"]["enemies"] = [harrier]
	scene._rebuild_pre_battle_overlay()
	await _layout_frames()
	scene._open_pinned_pre_battle_inspection("enemy", str(harrier["id"]), null, harrier)
	await _layout_frames()
	var panel: Control = scene._pinned_tooltip_panel
	_expect(panel != null and panel.find_child("PreBattleKnownMoves", true, false) != null, "Real pre-battle inspection opens for Bone Harrier")
	if panel != null:
		inventory["inspection"] = _inspection_tree(panel)
	await _save("bone_harrier_pre_battle")


func _inspection_tree(node: Node) -> Array:
	var children: Array = []
	for child: Node in node.get_children():
		children.append(_inspection_tree(child))
	var state: Dictionary = {}
	if node is Control:
		state = {"position": str(node.position), "size": str(node.size), "tooltip": node.tooltip_text}
	if node is Label: state["text"] = node.text
	if node is RichTextLabel: state["text"] = node.get_parsed_text()
	if node.has_meta("icon_key"): state["icon"] = node.get_meta("icon_key")
	return [node.get_class(), state, children]


func _save(stem: String) -> void:
	var path: String = _output.path_join(stem + "_1920x1080.png")
	_captures += 1
	if _headless:
		print("WOULD CAPTURE " + path)
		return
	await RenderingServer.frame_post_draw
	var png: Image = _viewport.get_texture().get_image()
	_expect(png != null and png.get_size() == PROBE_VIEWPORT and png.save_png(path) == OK,
		"Capture saves at 1920x1080: " + path)
	print(path)
