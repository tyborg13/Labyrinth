extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const Fixture = preload("res://tools/txt24/fixture.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Router = preload("res://scripts/input_router.gd")
const Splits = preload("res://scripts/enemy_mechanics/split_trait_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const DRAGONS: Array = ["vyraketh", "zekarion", "tharokh", "noctyrax", "iskaldra", "vaeloryx"]
const OTHER_ENEMIES: Array = ["frostglass_lancer", "lightning_wisp", "cinder_ooze"]
const LAYOUT_FRAMES: int = 4
const GEOMETRY_TOLERANCE: float = 1.0
const RELIC_ID: String = "crowncoal_heart"

var _output: String
var _headless: bool
var _captures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	var controller_check: bool = OS.get_cmdline_user_args().has("--controller-check")
	_output = OS.get_environment("TXT35_OUTPUT")
	if not controller_check and (_output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK):
		_fail("Set TXT35_OUTPUT to a writable directory")
		quit(1)
		return
	_setup()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	var router: Node = root.get_node("InputRouter")
	var modality: String = Router.MODALITY_CONTROLLER if controller_check else Router.MODALITY_POINTER
	router.set_forced_state_for_test(modality, Router.FAMILY_XBOX)
	var engine := RunEngine.new()
	var state: Dictionary = _run_with_available_combat(engine)
	var coord: Vector2i = _first_available_combat_coord(engine, state)
	var scene: Node = await _instance(state)
	var ids: Array = (DRAGONS + OTHER_ENEMIES).map(func(id: String) -> String: return "enemy:" + id)
	scene._run_state = BookData.unlock_entries(scene._run_state, ids)["state"]
	scene._on_grimoire_button_pressed()
	var book: Control = scene._grimoire_scrim
	await _layout()
	_expect(is_equal_approx(Typography.ui_scale(book), 1.0), "Grimoire uses 100% UI scale")
	if controller_check:
		_check_controller_open(book)
	else:
		await _capture_pages(book, ids)
	book.close()
	if not controller_check:
		await _inspect_known_moves(scene, engine, state, coord)
		scene.queue_free()
		await process_frame
		await _hover_relic(state)
	router.clear_forced_state_for_test()
	await _settle()
	_viewport.queue_free()
	await process_frame
	print("TXT35 UI PROOF: %s (%s, %d capture states)" %
		["FAIL" if _failed else "PASS", "headless" if _headless else "native", _captures])
	quit(int(_failed))


func _check_controller_open(book: Control) -> void:
	var search: Control = book._grimoire_search_input
	var hint: Control = search.get_node_or_null("ControllerFocusTooltip")
	var covers_title: bool = hint != null and hint.is_visible_in_tree() and hint.get_global_rect().intersects(
		book._grimoire_detail_title.get_global_rect())
	print("TXT35 CONTROLLER OPEN: search focused=%s, hint visible=%s, overlaps title=%s" %
		[search.has_focus(), hint != null and hint.is_visible_in_tree(), covers_title])


func _capture_pages(book: Control, ids: Array) -> void:
	for page_id: String in ids:
		book._on_grimoire_entry_pressed(page_id)
		await _layout()
		var title: Label = book._grimoire_detail_title
		var scroll: ScrollContainer = book._grimoire_detail_scroll
		var moves: Control = book.find_child("GrimoireMoves", true, false)
		_expect(title.text == BookData.entry_def(page_id)["title"] and scroll.scroll_vertical == 0,
			page_id + " opens on the expected page at the top")
		_expect(book._grimoire_search_input.get_node_or_null("ControllerFocusTooltip") == null,
			page_id + " has no controller search hint")
		if moves == null:
			_fail(page_id + " has no Moves section")
			continue
		var enemy_id: String = page_id.trim_prefix("enemy:")
		var stem: String = "enemy_" + enemy_id
		if enemy_id == "vyraketh":
			await _save(stem + "_top")
		if enemy_id in DRAGONS:
			scroll.scroll_vertical = roundi(moves.global_position.y - scroll.global_position.y)
			await _layout()
			_expect(scroll.scroll_vertical > 0, page_id + " scrolls to its moves")
		var bounds: Rect2 = scroll.get_global_rect().grow(GEOMETRY_TOLERANCE)
		_expect(bounds.encloses(moves.get_child(0).get_global_rect()) and bounds.encloses(moves.get_child(1).get_global_rect()),
			page_id + " shows the Moves heading and first move")
		var intents: Array = GameData.enemy_def(enemy_id)["intents"]
		for index: int in range(intents.size()):
			var summary: RichTextLabel = moves.get_child(index * 2 + 1).get_child(1).get_child(1)
			_expect(summary.get_content_height() <= summary.size.y, page_id + " move summary fits")
			var authored: String = intents[index].get("known_summary", "")
			if intents[index]["id"] == "last_eclipse":
				authored = authored.replace("Eclipse X", "Eclipse 1")
			if not authored.is_empty():
				_check_authored_row(summary, authored)
		if enemy_id == "cinder_ooze":
			var token: Dictionary = Splits.trait_token({"type": enemy_id})
			var traits: Control = book.find_child("GrimoireTraits", true, false)
			var copy: String = "On death, this enemy splits into 2 Cinder Droplets within 1 tile."
			_expect(str(token.get("tooltip", "")) == copy, "Cinder Ooze trait token uses the exact copy")
			_expect(traits != null and _rich_text(traits).contains(copy), "Cinder Ooze shows the new Splits sentence")
		await _save(stem + ("_moves" if enemy_id in DRAGONS else ""))


func _check_authored_row(summary: RichTextLabel, authored: String) -> void:
	var rendered: String = summary.get_parsed_text()
	var diagrams: Array[RegExMatch] = Inline.Patterns.matches(authored)
	if diagrams.is_empty():
		_expect(rendered == authored, "Grimoire renders the exact summary " + authored)
		return
	# Inline images do not supply player-facing text. Check each text span
	# beside a diagram and verify the diagram can resolve its authored tiles.
	var start: int = 0
	for diagram: RegExMatch in diagrams:
		var span: String = authored.substr(start, diagram.get_start() - start).strip_edges()
		_expect(rendered.contains(span), "Grimoire renders the text before " + diagram.get_string())
		_expect(not Inline.Patterns.offsets(diagram.get_string(1), int(diagram.get_string(2))).is_empty(),
			"Grimoire diagram resolves " + diagram.get_string())
		start = diagram.get_end()
	var tail: String = authored.substr(start).strip_edges()
	if not tail.is_empty():
		_expect(rendered.contains(tail), "Grimoire renders the text after its diagram")


func _inspect_known_moves(scene: Node, engine: RunEngine, state: Dictionary, coord: Vector2i) -> void:
	scene._load_run_state(_pre_battle_state_for_room(engine, state, coord))
	scene._show_pre_battle_preview()
	await _settle()
	var enemy: Dictionary = Fixture.unit("vyraketh", 0, Fixture.ENEMY)
	var preview: Dictionary = scene._pre_battle_preview_run_state
	preview["combat_state"]["enemies"] = [enemy]
	scene._rebuild_pre_battle_overlay()
	await _layout()
	scene._open_pinned_pre_battle_inspection("enemy", str(enemy["id"]), null, enemy)
	await _layout()
	var panel: Control = scene._pinned_tooltip_panel
	var known: Control = panel.find_child("PreBattleKnownMoves", true, false) if panel != null else null
	if known == null:
		_fail("Vyraketh pre-battle inspection has no Known Moves")
		return
	var effects: Array[Node] = known.find_children("PreBattleMoveEffect*", "Label", true, false)
	var lines := PackedStringArray()
	for effect: Label in effects:
		lines.append(effect.text)
	var authored: int = 0
	for intent: Dictionary in GameData.enemy_def("vyraketh")["intents"]:
		if not intent.has("known_summary"): continue
		authored += 1
		_expect(intent["known_summary"] in lines, "Known Moves renders " + str(intent["name"]))
	_expect(effects.size() == GameData.enemy_def("vyraketh")["intents"].size() and authored == 3,
		"Vyraketh shows every move including three authored summaries")
	await _save("vyraketh_pre_battle")
	scene._close_pinned_tooltip()


func _hover_relic(state: Dictionary) -> void:
	var owned: Dictionary = state.duplicate(true)
	owned["relics"] = [RELIC_ID]
	var scene: Node = await _instance(owned)
	scene._close_large_map()
	await _settle()
	var badge: Control = scene._relic_frame_for_id(RELIC_ID)
	if badge == null:
		_fail("Crowncoal Heart badge is missing")
		return
	await _pointer(badge.get_global_rect().get_center())
	await _settle()
	var stack: Control = scene._card_focus_tooltip_stack
	_expect(stack.is_visible_in_tree() and stack._follow_target == badge, "Crowncoal Heart pointer hover opens its stack")
	var burst: Control
	for panel: Control in stack._panels:
		if panel.get_meta("semantic_key", "") == "burst": burst = panel
	var generic: String = Glossary.definition("burst")
	var relic: Dictionary = GameData.relic_def(RELIC_ID)
	var definition: String = _rich_text(burst) if burst != null else ""
	var expected: String = Inline.plain_text(Inline.Patterns.display_rules(generic)).strip_edges()
	_expect(Glossary.amount_in_text("burst", relic["description"]) == null,
		"Crowncoal Heart does not bind the Fire threshold to Burst")
	_expect(burst != null and burst.is_visible_in_tree() and definition.contains(expected),
		"Crowncoal Heart renders the generic Burst definition")
	print("TXT35 CROWNCOAL BURST: %s" % definition)
	await _save("crowncoal_heart_hover")
	stack.hide_stack(true)


func _rich_text(node: Node) -> String:
	var parts := PackedStringArray()
	for label: RichTextLabel in node.find_children("*", "RichTextLabel", true, false):
		parts.append(label.get_parsed_text().strip_edges())
	return "\n".join(parts)


func _layout() -> void:
	for _frame: int in range(LAYOUT_FRAMES):
		await process_frame


func _save(stem: String) -> void:
	var path: String = _output.path_join(stem + "_1920x1080.png")
	_captures += 1
	if _headless:
		print("WOULD CAPTURE " + path)
		return
	await _capture(path)
	print(path)
