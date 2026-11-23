extends SceneTree
## Exact-size production surfaces with the same layout checks in headless mode.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const GrimoirePanel = preload("res://scripts/grimoire_panel.gd")
const InputWording = preload("res://scripts/input_wording.gd")
const Measure = preload("res://tests/helpers/card_summary_fit_measure.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Menu = preload("res://scenes/main_menu.tscn")

const SEED: int = 501
const HERO := Vector2i(2, 4)
const FOE := Vector2i(4, 4)
const BOARD_SIZE := Vector2i(10, 9)
const PROOF_HP: int = 24
const PROOF_FOE_HP: int = 40
const PROOF_DEPTH: int = 3
const PROOF_ROOM := Vector2i(1, 0)
const DRAW_CARD: String = "quick_stab"
const INSPECTION_POSITION := Vector2(24, 144)
const INSPECTION_Z: int = 300
const SETTLE_FRAMES: int = 5
const READY_FRAMES: int = 600
const TEXT_TOLERANCE: float = 2.0
const STACK_MARGIN: float = 8.0
const CARD_IDS: Array = ["serrated_slip", "frost_circuit", "vortex", "worldroot_stride", "lodestone_reversal"]
const COMPACT_CARD: String = "lodestone_reversal"
const COPY_BEFORE: Dictionary = {
	"frost_circuit": "On Ice: do the same on each connected Ice tile.",
	"vortex": "Choose a tile within Range 3. Pull each enemy within 2 tiles of the chosen tile 2 tiles toward that tile.",
	"worldroot_stride": "Leave Rubble under you.",
}
const COPY_AFTER: Dictionary = {
	"frost_circuit": "On Ice: also on each connected Ice tile.",
	"vortex": "Choose a tile within Range 3. Pull each enemy within 2 tiles of that tile 2 tiles toward that tile.",
	"worldroot_stride": "Leave Rubble on your tile.",
}

var _failures: Array[String]
var _before: bool
var _headless: bool
var _output: String
var _viewport: SubViewport
var _scene: Control
var _captures: int
var _markup := RegEx.create_from_string("@(?:kw|term|icon|pattern)\\(|[{}]|\\[/?(?:color|img|b|url)(?:=|\\])")
var _face_diagnostics := RegEx.create_from_string("\\{[^}]+\\}|#")

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or args[0] not in ["before", "after"] or args[1] not in ["1920x1080", "1280x800"]:
		push_error("Usage: capture.gd -- before|after 1920x1080|1280x800 /absolute/output")
		quit(2)
		return
	_before = args[0] == "before"
	_headless = DisplayServer.get_name() == "headless"
	_output = args[2]
	var dimensions: PackedStringArray = args[1].split("x")
	var resolution := Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	_expect(OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Proof requires LABYRINTH_CEL_LOOK=all")
	_expect(DirAccess.make_dir_recursive_absolute(_output) == OK, "Output folder is writable")
	Settings.set_storage_path("user://txt30-settings.json")
	Store.set_storage_path("user://txt30-progression.json")
	Store.set_run_storage_path("user://txt30-run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = resolution
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = RunScene.instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(READY_FRAMES):
		if _scene.call("initial_presentation_is_ready"): break
		await process_frame
	_expect(bool(_scene.call("initial_presentation_is_ready")), "RunScene booted")
	for id: String in CARD_IDS:
		await _check_card(id)
	await _check_foe_hint()
	_scene.queue_free()
	await process_frame
	await _check_new_tag()
	var ground: Dictionary = Grimoire.entry_def("combat:surface_techniques")
	var ground_text: String = InputWording.grimoire_body(ground, false)
	var rider: String = "On Ice, Frost Circuit does the same on each connected Ice tile." if _before else COPY_AFTER["frost_circuit"]
	_expect(ground_text.contains(rider) and _markup.search(ground_text) == null, "Grimoire Ground Techniques uses the matching Frost Circuit rider")
	_viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	print(_output)
	print("TXT30 %s %s %s: %s (%d cards, 2 captions, %d PNGs, %d failures)" % [
		"DRY RUN" if _headless else "CAPTURE", args[0], args[1], "PASS" if _failures.is_empty() else "FAIL",
		CARD_IDS.size(), _captures, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _install_card(id: String) -> void:
	var grid: Array = []
	for y: int in range(BOARD_SIZE.y):
		var row: Array = []
		for x: int in range(BOARD_SIZE.x):
			row.append("wall" if x == 0 or y == 0 or x == BOARD_SIZE.x - 1 or y == BOARD_SIZE.y - 1 else "stone")
		grid.append(row)
	var room: Dictionary = {
		"name": "Surface Test", "coord": PROOF_ROOM, "depth": 1, "type": "combat", "umbra_stage": "clear",
		"grid": grid, "player_start": HERO, "loot": [], "traps": [],
		"enemies": [{"id": 1, "type": "crawler", "pos": FOE, "hp": PROOF_FOE_HP, "max_hp": PROOF_FOE_HP}],
	}
	var state: Dictionary = Combat.new().create_combat(SEED, room, {
		"hp": PROOF_HP, "max_hp": PROOF_HP, "deck_cards": [id], "hand_size": 1,
	})
	state["deck"]["draw"] = [DRAW_CARD]
	var progression: Dictionary = Store.default_data()
	for prompt_id: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt_id)
	var run: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = room["coord"]
	run["current_room_layout"] = room
	run["progression"] = progression
	run["combat_state"] = state
	run["notice"] = ""
	_scene.call("_load_run_state", run)

func _check_card(id: String) -> void:
	_install_card(id)
	await _settle()
	var face := _scene.call("_hand_card_control", 0) as CardWidget
	_expect(face != null and face.card_id == id, "%s is in the live hand" % id)
	if face == null: return
	_scene.call("_set_hand_emphasized_index", 0, false)
	await _settle()
	_check_face(face)

	var definition: Dictionary = face.call("_display_card_def")
	var exact: String = _rules(face)
	var expected: Dictionary = COPY_BEFORE if _before else COPY_AFTER
	if expected.has(id):
		_expect(exact.contains(expected[id]), "%s exact inspection copy is current: %s" % [id, exact])
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var stack: Control = _scene.get("_card_focus_tooltip_stack")
	var stack_rect: Rect2 = stack.get_global_rect()
	if id == COMPACT_CARD:
		_expect(stack.visible, "Lodestone's live keyword stack is visible")
		var safe: Rect2 = viewport_rect.grow(-STACK_MARGIN)
		_expect(stack_rect.position.y < safe.position.y if _before and _is_compact() else safe.encloses(stack_rect),
			"Lodestone keyword stack has the expected bounds: %s in %s" % [stack_rect, safe])
		_visible_text(stack, id)

	var inspection: PanelContainer = Tooltip.make_lines(definition["name"], PackedStringArray([exact]))
	inspection.position = INSPECTION_POSITION
	inspection.z_index = INSPECTION_Z
	_scene.get("ui_root").add_child(inspection)
	await _settle()
	_expect(viewport_rect.encloses(inspection.get_global_rect()), "%s inspection fits the viewport" % id)
	_expect(_visible_text(inspection, id).has(exact), "%s renders its exact inspection copy" % id)
	print("TXT30 FIT %s %s | inspection=%s keyword_stack=%s rules=%s" % [
		_viewport.size, id, inspection.get_global_rect(), stack_rect, exact])
	if (_is_compact() and id == COMPACT_CARD) or (not _is_compact() and id in ["vortex", "worldroot_stride"]):
		await _save(id + "_inspection")
	inspection.hide()
	inspection.queue_free()
	if not _is_compact() and id in ["serrated_slip", "frost_circuit"]:
		await _save(id + "_face")
	if not _is_compact() and not _before and _headless and id != COMPACT_CARD:
		await _check_mirrors(face, exact)
	_scene.call("_set_hand_emphasized_index", -1, false)

func _check_face(face: CardWidget) -> void:
	var definition: Dictionary = face.call("_display_card_def")
	var measured: Dictionary = Measure.measure(face, definition)
	_expect(Measure.fits(measured) and float(measured["overflow_y"]) <= TEXT_TOLERANCE,
		"%s face clips: %s" % [face.card_id, measured])
	_visible_text(face, face.card_id)
	# The sentence face draws directly from the layout plan. Its diagnostic
	# line text tags the drawn icons and numerals for the fit audit.
	var lines := PackedStringArray()
	for line: Dictionary in face.sentence_face_plan().get("lines", []):
		lines.append(_face_diagnostics.sub(line["text"], "", true).replace("~", " "))
	var text: String = " ".join(lines)
	_expect(_markup.search(text) == null, "%s sentence face has no raw markup" % face.card_id)
	print("TXT30 FACE %s %s | lines=%d overflow_y=%.2f" % [
		_viewport.size, face.name, lines.size(), measured["overflow_y"]])
	match face.card_id:
		"serrated_slip":
			_expect(text.contains("++4") if _before else (text.contains("+4") and not text.contains("++4")), "Serrated Slip shows the matching bonus prefix: " + text)
		"frost_circuit":
			var rider: String = "do the same on each connected" if _before else "also on each connected"
			_expect(text.contains(rider), "Frost Circuit shows the matching rider: " + text)
		"worldroot_stride":
			_expect(text.contains("on your tile."), "Worldroot Stride face retains the approved Rubble destination: " + text)
		"vortex":
			var has_diagram: bool = false
			for row: Array in face.display_summary_rows():
				for token: Dictionary in row:
					if str(token.get("icon", "")) == "aoe_pattern": has_diagram = true
			_expect(has_diagram, "Vortex face keeps its area diagram")

func _rules(face: CardWidget) -> String:
	return Display.rules_text(face.card_id, face.call("_display_card_def"), face.display_summary_rows())

func _check_mirrors(hand: CardWidget, exact: String) -> void:
	var host := HBoxContainer.new()
	host.position = Vector2(_viewport.size)
	_scene.get("ui_root").add_child(host)
	var shop := Shop.new()
	shop.set("_run_state", _scene.get("_run_state"))
	var shop_card: CardWidget = shop.call("_build_native_scaled_card", host, hand.card_id, Shop.NATIVE_CARD_SIZE, "Txt30Shop", false)
	var reward_cards: Array[Control]
	_scene.call("_add_reward_choice_card", host, hand.card_id, _scene.call("_reward_choice_card_size", 3, true), reward_cards)
	var grimoire: Control = _scene.get("_grimoire_scrim")
	var grimoire_preview: Control = grimoire.call("_build_card_preview_widget", hand.card_id, GrimoirePanel.GRIMOIRE_CARD_PREVIEW_SIZE, false)
	host.add_child(grimoire_preview)
	var grimoire_card := grimoire_preview.get_node("CardScaleFrame").get_child(0) as CardWidget
	await _settle()
	for card: CardWidget in [shop_card, reward_cards[0], grimoire_card]:
		_expect(_rules(card) == exact, "%s %s inspection differs from hand: %s" % [hand.card_id, card.name, _rules(card)])
		_check_face(card)
	for entry_id: String in [Grimoire.magick_entry_id(hand.card_id), Grimoire.equipment_card_entry_id(hand.card_id)]:
		var entry: Dictionary = Grimoire.entry_def(entry_id)
		if entry.is_empty(): continue
		var text: String = InputWording.grimoire_body(entry, false)
		_expect(text.contains(exact) and _markup.search(text) == null, "%s Grimoire article uses exact inspection copy" % hand.card_id)
	print("TXT30 MIRRORS %s | reward, Scavenger detail and Grimoire" % hand.card_id)
	shop.free()
	host.queue_free()

func _check_foe_hint() -> void:
	var engine: RefCounted = _scene.get("_run_engine")
	var run: Dictionary = engine.create_new_run(SEED, Store.default_data())
	for coord: Vector2i in engine.available_moves(run):
		if str(engine.room_metadata(run, coord).get("type", "")) != "combat": continue
		run = engine.move_to_pre_battle(run, coord)
		break
	_scene.call("_load_run_state", run)
	_scene.call("_close_dialogue")
	for frame: int in range(READY_FRAMES):
		var hint: Label = _scene.find_child("PreBattleFoeHint", true, false)
		if hint != null and hint.is_visible_in_tree(): break
		await process_frame
	await _settle()
	var hint: Label = _scene.find_child("PreBattleFoeHint", true, false)
	_expect(hint != null and hint.is_visible_in_tree(), "Pre-battle foe hint is visible")
	if hint == null: return
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var font_size: int = hint.get_theme_font_size("font_size")
	_expect(font_size == (13 if _before else 14) and viewport_rect.encloses(hint.get_global_rect()), "Pre-battle hint keeps the expected size and fits the viewport")
	_visible_text(hint, "pre-battle hint")
	print("TXT30 FIT %s PreBattleFoeHint | font=%d bounds=%s" % [_viewport.size, font_size, hint.get_global_rect()])
	if not _is_compact(): await _save("pre_battle")

func _check_new_tag() -> void:
	var profile: Dictionary = Store.default_data()
	profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = PROOF_DEPTH
	profile[Store.UMBRA_DEPTH_SELECTED_KEY] = PROOF_DEPTH
	Store.save_data(profile)
	Store.clear_saved_run()
	var menu := Menu.instantiate()
	_viewport.add_child(menu)
	await _settle()
	menu.call("_on_start_button_pressed")
	await _settle()
	var picker: Control = menu.get("_new_descent_panel")
	_expect(picker != null, "New Run opens the depth picker")
	if picker == null: return
	var tag: Control = picker.find_child("DepthNewTag", true, false)
	var label: Label = picker.find_child("DepthNewText", true, false)
	_expect(tag != null and label != null and label.is_visible_in_tree(), "New Run shows the NEW tag")
	if tag == null or label == null: return
	var font_size: int = label.get_theme_font_size("font_size")
	_expect(label.text == "NEW" and font_size == (12 if _before else 14), "NEW tag has the expected text and font size")
	_expect(tag.size == (Vector2(52, 18) if _before else Vector2(58, 20)), "NEW tag has the expected dimensions")
	_expect(tag.get_global_rect().encloses(label.get_global_rect()) and tag.get_global_rect().get_center().is_equal_approx(label.get_global_rect().get_center())
		and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "NEW text is centered inside the tag")
	_visible_text(label, "NEW tag")
	print("TXT30 FIT %s DepthNewTag | font=%d bounds=%s text_bounds=%s" % [_viewport.size, font_size, tag.get_global_rect(), label.get_global_rect()])
	if not _is_compact(): await _save("new_run")

func _visible_text(node: Node, context: String) -> PackedStringArray:
	var result := PackedStringArray()
	if node is Label and node.is_visible_in_tree():
		_expect(node.get_visible_line_count() == node.get_line_count(), "%s clips: %s" % [context, node.text])
		result.append(node.text)
	elif node is RichTextLabel and node.is_visible_in_tree():
		_expect(node.get_content_height() <= node.size.y + TEXT_TOLERANCE, "%s rich text clips" % context)
		result.append(node.get_parsed_text())
	for line: String in result:
		_expect(_markup.search(line) == null, "%s leaks markup: %s" % [context, line])
	for child: Node in node.get_children():
		result.append_array(_visible_text(child, context))
	return result

func _is_compact() -> bool:
	return _viewport.size.x == 1280

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _save(id: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == _viewport.size, "%s has exact capture dimensions" % id)
	if image == null: return
	_expect(image.save_png(_output.path_join(id + ".png")) == OK, "%s PNG written" % id)
	_captures += 1

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
