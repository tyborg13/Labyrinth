extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/chronicle_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Probe = preload("res://tests/chronicle_probe.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const CardTile = preload("res://scripts/chronicle_card_tile.gd")
const GameData = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/chronicle_rules.gd")
const Elements = preload("res://scripts/element_data.gd")
const TILE_LAYOUT_SETTLE_FRAMES: int = 4
const SCROLL_RECORD_COUNT: int = 15
var failures: Array[String]
var _native_hover_popups: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	Analytics.set_storage_dir("user://chronicle_test_analytics")
	call_deferred("_run")

func _run() -> void:
	Suite.run(_check)
	_test_fixture_cards()
	var canvas: SubViewport = Probe.create_capture_viewport(root)
	_check(canvas.size == Vector2i(1920, 1080) and canvas.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Chronicle proof uses a fixed 1920x1080 render target updated every frame")
	var menu: Control = preload("res://scenes/main_menu.tscn").instantiate()
	canvas.add_child(menu)
	await process_frame
	var button: Button = menu.get_node("MenuColumn/ChronicleButton")
	_check(button.get_index() == menu.get_node("MenuColumn/StartButton").get_index() + 1 and button.get_index() + 1 == menu.get_node("MenuColumn/SettingsButton").get_index(), "Chronicle menu ordering")
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await process_frame
	await Probe.click_button(button, canvas)
	await process_frame
	var panel: Control = menu.get_node("ChroniclePanel")
	_check(panel.visible and panel.get_node("ChronicleFrame").position == Vector2(60, 110) and panel.get_node("ChronicleFrame").size == Vector2(1800, 860), "Chronicle panel opens at approved geometry")
	_check(panel.get_node("ChronicleFrame/DescentList").size.x == 520, "Chronicle list has approved width")
	_check(button.position.y - menu.get_node("MenuColumn/StartButton").position.y == 92 and menu.get_node("MenuColumn/SettingsButton").position.y - button.position.y == 92, "Chronicle keeps 92 px menu spacing")
	_check(panel.find_child("DescentDetail", true, false).get_child(0).text == "Your first descent will be written here.", "Chronicle empty detail copy")
	panel.close()
	_check(button.has_focus() and not panel.visible, "Chronicle close restores menu focus")
	var opened: Array[Dictionary] = Analytics.load_all_events()
	_check(opened.size() == 1 and opened[0]["event_type"] == "chronicle_opened" and opened[0]["payload"]["records"] == 0, "Chronicle emits one additive local open event")
	# Validate both navigation steps through the added Chronicle slot.
	var start: Button = menu.get_node("MenuColumn/StartButton")
	start.grab_focus()
	var navigate := InputEventKey.new()
	navigate.keycode = KEY_DOWN
	navigate.pressed = true
	menu.get_viewport().push_input(navigate, true)
	await process_frame
	_check(button.has_focus(), "Keyboard navigation reaches Chronicle between New Game and Settings")
	menu.get_viewport().push_input(navigate, true)
	await process_frame
	_check(menu.get_node("MenuColumn/SettingsButton").has_focus(), "Keyboard navigation still reaches Settings after Chronicle")
	panel.open(Probe.seeded_profile(), false)
	await process_frame
	await process_frame
	_check(panel.records.size() == 7 and panel.find_child("ChronicleScore", true, false).text == "567", "Approved seven-record proof fixture selects the newest score")
	_check(panel.find_child("ChronicleScore", true, false).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Detail score aligns at the right end of the title row")
	var gear: Control = panel.find_child("Gear_training_sword", true, false)
	_check(gear != null, "Chronicle reuses approved production gear icons")
	if gear != null:
		gear.grab_focus()
		await process_frame
		await process_frame
		_check(panel.get("_focus_tooltip") != null and (panel.get("_focus_tooltip") as Node).find_children("*", "Button", true, false).size() > 0, "Focused gear uses production card previews in the existing tooltip")
		await _test_viewport_hover_entry(panel, gear)
	await _test_card_tiles(panel, canvas)
	panel.select_record(1, true)
	await process_frame
	await process_frame
	var relic: Control = panel.find_child("Relic_iron_lung", true, false)
	if relic != null:
		relic.grab_focus()
		await process_frame
		await process_frame
		var detail_scroller: ScrollContainer = panel.get("_detail_scroll")
		_check(relic.get_global_rect().end.y <= detail_scroller.get_global_rect().end.y, "Icon focus keeps long victory builds visible in the detail scroller")
	var guardian_profile: Dictionary = Probe.seeded_profile()
	guardian_profile[Store.CHRONICLE_RECORDS_KEY][0]["path"][0][0] = "guardian"
	panel.open(guardian_profile, false)
	await process_frame
	var guardian: Dictionary = Guardians.for_boss("tharokh")
	var room_icon: Control = panel.find_child("PathSection0Room0", true, false)
	_check(room_icon.get("texture") == Icons.icon_texture("guardian_" + str(guardian["id"])) and str(room_icon.get("tooltip_title")).begins_with(str(guardian["name"])), "Chronicle reuses the section map's specific guardian emblem and tooltip name")
	var overflow_profile: Dictionary = Probe.seeded_profile()
	overflow_profile[Store.CHRONICLE_RECORDS_KEY][0]["deck"] = Probe.overflow_deck()
	panel.open(overflow_profile, false)
	await process_frame
	await process_frame
	await _test_overflow(panel)
	var profile: Dictionary = Store.default_data()
	for index: int in range(SCROLL_RECORD_COUNT):
		profile = Store.record_chronicle(profile, {"run_id": "ui-%d" % index, "outcome": "defeat", "section_name": "Rime Hall", "section_index": 2, "score_total": 567, "path": [["combat"]], "section_names": ["Worldspine Roots"]})
	panel.open(profile, false)
	await process_frame
	await process_frame
	_check(panel.get_node("ChronicleFrame/DescentList").size.x == 520, "Chronicle scrolling never grows the 520 px list")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	panel._input(down)
	_check(panel.selected_index == 1, "Chronicle keyboard Down selects")
	var bumper := InputEventJoypadButton.new()
	bumper.button_index = JOY_BUTTON_RIGHT_SHOULDER
	bumper.pressed = true
	panel._input(bumper)
	_check(panel.selected_index == 11, "Chronicle RB pages by visible rows")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -0.5
	panel._input(stick)
	_check(panel.selected_index == 10, "Chronicle left stick selects")
	panel._input(stick)
	_check(panel.selected_index == 10, "Chronicle held stick does not skip every motion sample")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_UP
	dpad.pressed = true
	panel._input(dpad)
	_check(panel.selected_index == 9, "Chronicle controller D-pad selects")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	panel._input(back)
	_check(not panel.visible and button.has_focus(), "Chronicle controller B returns to menu")
	menu.queue_free()
	canvas.queue_free()
	await _settle_tiles()
	for failure: String in failures:
		push_error(failure)
	print("CHRONICLE HOVER PROOF: %d native popups; 5 pointer targets" % _native_hover_popups)
	print("CHRONICLE TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL (%d failure(s))" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _settle_tiles() -> void:
	for frame: int in range(TILE_LAYOUT_SETTLE_FRAMES):
		await process_frame

func _test_fixture_cards() -> void:
	for pair: Array in Probe.MOCKUP_SPELLS:
		var definition: Dictionary = GameData.card_def(str(pair[0]))
		_check(not definition.is_empty(), "Fixture card has a production definition: %s" % pair[0])
		var art: String = str(definition.get("art_path", ""))
		_check(not art.is_empty() and CardTile.AssetLoader.load_texture(art) != null, "Fixture card has existing loadable art: %s" % pair[0])
	var elements: Dictionary = {}
	for index: int in [0, 1, 4]:
		var definition: Dictionary = GameData.card_def(str(Probe.MOCKUP_SPELLS[index][0]))
		elements[GameData.card_element_from_def(definition)] = true
	_check(elements.size() == 3, "Replacement fixture cards have three different elements")

func _test_viewport_hover_entry(panel: Control, tile: Control) -> void:
	# Reproduce the old probe artifact independently of the tooltip builders:
	# push_input updates hover hit-testing in an unentered SubViewport, while
	# the native tooltip timer requires the mouse-enter notification as well.
	var viewport: Viewport = panel.get_viewport()
	viewport.gui_release_focus()
	viewport.notify_mouse_exited()
	await Probe.hover_tile(tile, viewport)
	_check(viewport.gui_get_hovered_control() == tile, "Unentered viewport still reports the hovered control")
	_check(Probe._visible_custom_tooltip(viewport) == null, "Unentered viewport reproduces the missing native tooltip")
	viewport.notify_mouse_entered()
	Probe.move_pointer(viewport, Vector2.ZERO)
	await _settle_tiles()
	print("CHRONICLE HOVER REGRESSION: unentered viewport reaches tile without a native popup")

func _test_card_tiles(panel: Control, canvas: Viewport) -> void:
	var profile: Dictionary = Probe.tile_fixture_profile()
	var record: Dictionary = profile[Store.CHRONICLE_RECORDS_KEY][0]
	var normalized: Dictionary = Rules.normalized_record(record)
	_check(normalized["deck"] == record["deck"] and normalized["deck_card_definitions"] == record["deck_card_definitions"], "Additive card definitions preserve saved deck pairs and upgraded definitions")
	var legacy: Dictionary = record.duplicate(true)
	legacy.erase("deck_card_definitions")
	_check(Rules.normalized_record(legacy) == legacy, "Pre-tile Chronicle records normalize without adding or changing fields")
	var storage_path: String = Store._storage_path
	Store.set_storage_path("user://chronicle_tile_compatibility.json")
	_check(Store.save_data(profile), "Card snapshot profile saves")
	var restored: Dictionary = Store.load_data()
	_check(Store.chronicle_records(restored)[0]["deck_card_definitions"] == record["deck_card_definitions"], "Upgraded card snapshot survives profile restart")
	profile[Store.CHRONICLE_RECORDS_KEY][0] = legacy
	_check(Store.save_data(profile) and Store.chronicle_records(Store.load_data())[0] == legacy, "Old Chronicle record survives profile restart unchanged")
	Store.set_storage_path(storage_path)
	panel.open(restored, false)
	await _settle_tiles()
	var spells: GridContainer = panel.find_child("ChronicleSpells", true, false)
	_check(spells.get_child_count() == 4, "Fixture duplicates produce one tile per distinct card")
	var expected_ids: Array = ["chain_bolt", "pale_spark", "quick_stab", "waning_pulse"]
	for index: int in range(expected_ids.size()):
		var tile: Control = spells.get_child(index)
		_check(tile.card_id == expected_ids[index], "Spell tiles retain recorded first-occurrence order %d" % index)
		_check(tile.size == Vector2(48, 64), "Spell tile has the approved 48x64 portrait size")
		_check(tile.get_node("CardArt").texture != null and tile.get_node("CardArt").stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Spell uses its own approved art with centre-crop fill")
	var duplicate: Control = spells.get_child(1)
	var badge: Label = duplicate.get_node("Badge")
	_check(duplicate.count == 3 and badge.text == "×3" and badge.visible, "Duplicate count badge groups all three copies")
	_check(badge.get_theme_font_size("font_size") == 14 and badge.get_theme_font("font") == preload("res://scripts/ui_typography.gd").text_font(), "Count badge uses 14px body font")
	_check(badge.position + badge.size == duplicate.size + Vector2(4, 4), "Count badge overlaps bottom-right edge by four pixels")
	_check(not (spells.get_child(0).get_node("Badge") as Label).visible, "Single copies have no badge")
	_check(spells.get_child(0).element_accent == Elements.accent("lightning") and spells.get_child(2).element_accent == Elements.accent(Elements.NONE), "Elemental and element-less edges use ElementData accents")
	_check(bool(duplicate.card_definition.get("upgraded", false)), "Upgraded definition is preserved without inventing a tile marker")
	duplicate.grab_focus()
	await _settle_tiles()
	var preview: Control = panel.get("_focus_tooltip")
	var widgets: Array[Control] = Probe.card_widgets(preview)
	_check(widgets.size() == 1 and widgets[0].card_id == "pale_spark" and widgets[0]._display_card_def() == duplicate.card_definition, "Focused spell uses the complete production CardWidget and recorded upgraded rules")
	_check(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(preview.get_global_rect()), "Card preview follows existing viewport-clamped placement")
	var tiles: Array[Control] = panel.get("_detail_tiles")
	var expected_names: Array[String]
	for id: String in record["gear"]:
		expected_names.append("Gear_" + id)
	for id: String in expected_ids:
		expected_names.append("Spell_" + id)
	for id: String in record["relics"]:
		expected_names.append("Relic_" + id)
	_check(tiles.size() == expected_names.size(), "Focus chain contains gear, spells, and relics exactly once")
	for index: int in range(tiles.size()):
		_check(tiles[index].name == expected_names[index], "Focus order is gear, spells, relics in recorded order %d" % index)
		if index + 1 < tiles.size():
			_check(tiles[index].get_node(tiles[index].focus_next) == tiles[index + 1], "Tab focus links advance left-to-right through each tile")
	var selected: int = panel.selected_index
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	canvas.push_input(right, true)
	await _settle_tiles()
	_check(canvas.gui_get_focus_owner() == spells.get_child(2) and panel.selected_index == selected, "Controller D-pad traverses spells without changing the selected record")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	canvas.push_input(tab, true)
	await _settle_tiles()
	_check(canvas.gui_get_focus_owner() == spells.get_child(3), "Keyboard Tab advances through spell tiles")
	var left := InputEventJoypadMotion.new()
	left.axis = JOY_AXIS_LEFT_X
	left.axis_value = -0.8
	panel._input(left)
	await _settle_tiles()
	_check(canvas.gui_get_focus_owner() == spells.get_child(2), "Controller stick traverses detail tiles")
	left.axis_value = 0.0
	panel._input(left)
	var relic: Control = panel.find_child("Relic_iron_lung", true, false)
	relic.grab_focus()
	await _settle_tiles()
	_check(panel.get("_focus_tooltip") != null, "Relic focus uses the run HUD tooltip builder")
	await _test_hover(panel, spells.get_child(0), true)
	await _test_hover(panel, relic, false)
	await _test_hover(panel, tiles[0], true)
	var path: Control = panel.find_child("PathSection0Room0", true, false)
	await _test_hover(panel, path, false)
	var selected_row: Control = panel.find_child("DescentRow0", true, false)
	_check(selected_row.get_node(selected_row.focus_next) == path, "Path icons retain a keyboard route before the gear/spell/relic chain")
	_check(is_equal_approx(spells.global_position.x, 670) and is_equal_approx((panel.find_child("ChronicleFeats", true, false) as Control).global_position.x, 1454), "SPELLS starts at x670 and FEATS keeps its existing x1454")
	var detail: VBoxContainer = panel.find_child("DescentDetail", true, false)
	var spells_header: Control = detail.get_child(spells.get_index() - 1)
	var row_a: Control = detail.get_child(spells.get_index() - 3)
	var relics_header: Control = detail.get_child(spells.get_index() + 2)
	_check(is_equal_approx(spells_header.position.y - row_a.get_rect().end.y, 28) and is_equal_approx(relics_header.position.y - spells.get_rect().end.y, 28), "Detail rows use 28px vertical gaps")
	panel.close()
	await _settle_tiles()
	_check(panel.get("_focus_tooltip") == null, "Closing Chronicle clears its preview")
	panel.open(Probe.seeded_profile(), false)

func _test_overflow(panel: Control) -> void:
	await _settle_tiles()
	var spells: GridContainer = panel.find_child("ChronicleSpells", true, false)
	var columns: int = CardTile.columns_for_width(spells.size.x)
	var shown: int = columns * 2 - 1
	_check(Probe.overflow_deck().size() == 45 and spells.get_child_count() == columns * 2, "45 distinct cards fill exactly two rows including overflow socket")
	var overflow: Control = panel.find_child("ChronicleSpellsOverflow", true, false)
	_check(overflow != null and overflow.get_node("OverflowCount").text == "+%d" % (45 - shown) and overflow.remaining.size() == 45 - shown, "Overflow counts distinct unshown cards, including the displaced final tile")
	for index: int in range(shown):
		var tile: Control = spells.get_child(index)
		_check(tile.card_id == Probe.overflow_deck()[index][0], "Overflow preserves recorded deck order %d" % index)
		_check(is_equal_approx(tile.position.x, (index % columns) * 56) and is_equal_approx(tile.position.y, (index / columns) * 72), "Tiles wrap left-to-right at eight pixel spacing")
	_check(overflow.remaining[0]["id"] == Probe.overflow_deck()[shown][0], "Overflow tooltip begins with the first omitted card")
	overflow.grab_focus()
	await _settle_tiles()
	var tooltip: Control = panel.get("_focus_tooltip")
	var labels: Array[Node] = tooltip.find_children("*", "Label", true, false)
	var expected := PackedStringArray()
	for entry: Dictionary in overflow.remaining:
		expected.append("%s ×%d" % [entry["name"], entry["count"]])
	_check(labels.size() == 1 and labels[0].text == "\n".join(expected), "Overflow tooltip lists every omitted card and count on its own line")
	await _test_hover(panel, overflow, false)
	_check(CardTile.shown_count(40, 20) == 40 and CardTile.shown_count(41, 20) == 39 and CardTile.shown_count(45, 1) == 1, "Two-row boundaries reserve an overflow tile only when needed")

func _test_hover(panel: Control, tile: Control, has_cards: bool) -> void:
	var viewport: Viewport = panel.get_viewport()
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	(panel.get("_detail_scroll") as ScrollContainer).ensure_control_visible(tile)
	await _settle_tiles()
	await Probe.hover_tile(tile, viewport)
	await _settle_tiles()
	_check(viewport.gui_get_hovered_control() == tile, "Native pointer hover reaches %s" % tile.name)
	var tooltip: Control = Probe._visible_custom_tooltip(viewport)
	if tooltip != null:
		_native_hover_popups += 1
	_check(tooltip != null, "Native hover creates a custom tooltip: %s" % tile.name)
	if tooltip != null:
		var popup: Window = tooltip.get_window()
		_check(viewport.get_visible_rect().encloses(Rect2(Vector2(popup.position), Vector2(popup.size))), "Native hover tooltip stays inside the viewport")
	if tooltip != null and has_cards:
		_check(not Probe.card_widgets(tooltip).is_empty(), "Native hover tooltip reuses full production card previews")
	Probe.move_pointer(viewport, Vector2.ZERO)
	await _settle_tiles()
