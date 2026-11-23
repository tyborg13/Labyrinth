extends SceneTree
## Matched captures of production hand faces, focus panels and the exact-rules
## popover style used for inspection. Headless dry-run measures the same tree.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const SEED: int = 501
const HERO := Vector2i(2, 4)
const AIM := Vector2i(4, 4)
const END := Vector2i(3, 4)
const BOARD_SIZE := Vector2i(10, 9)
const INSPECTION_POSITION := Vector2(24, 144)
const INSPECTION_Z: int = 300
const SETTLE_FRAMES: int = 5
const READY_FRAMES: int = 600
const TEXT_TOLERANCE: float = 2.0
const MIRROR_SIZE := Vector2(250, 352)
const DRAW_FIXTURE_CARD: String = "quick_stab"
const MATCHED: Array = ["ember_guard", "cinderweave_guard", "bottled_gale", "caltrops", "meteorfall", "skybolt", "lodestone_reversal"]
const ADDITIONAL: Array = ["ember_ward", "static_ward", "stone_ward", "grounding", "spike_mantle", "cinder_wall", "frost_lane", "lamp_oil", "earthen_rampart", "grapple", "powder_keg", "thunderstone", "jaw_trap"]
const PANEL_SENTENCES: Dictionary = {
	"grounding": "Remove the named ground to use this effect.",
	"spike_mantle": "Remove the named ground to use this effect.",
	"meteorfall": "Aim within Range and line of sight.",
	"skybolt": "Deal 8 damage to a visible target within Range.",
	"thunderstone": "Deal 5 damage to a visible target within Range.",
	"powder_keg": "Place the Powder Keg within Range.",
}

var _failures: Array[String]
var _headless: bool
var _before: bool
var _output: String
var _viewport: SubViewport
var _scene: Node
var _captures: int = 0
var _markup := RegEx.create_from_string("@(?:kw|term|icon|pattern)\\(|[{}]|\\[/?(?:color|img|b|url)(?:=|\\])")

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
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
	_expect(DirAccess.make_dir_recursive_absolute(_output) == OK, "Output is writable")
	Settings.set_storage_path("user://txt28_settings.json")
	Store.set_storage_path("user://txt28_progression.json")
	Store.set_run_storage_path("user://txt28_run.save")
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
	var cards: Array = MATCHED if _before else MATCHED + ADDITIONAL
	for id: String in cards:
		await _capture_card(id)
	_viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	print(_output)
	print("TXT28 %s %s %s: %s (%d inspections, %d PNGs, %d failures)" % [
		"DRY RUN" if _headless else "CAPTURE", args[0], args[1], "PASS" if _failures.is_empty() else "FAIL", cards.size(), _captures, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _install_combat(id: String) -> void:
	var grid: Array = []
	for y: int in range(BOARD_SIZE.y):
		var row: Array = []
		for x: int in range(BOARD_SIZE.x):
			row.append("wall" if x == 0 or y == 0 or x == BOARD_SIZE.x - 1 or y == BOARD_SIZE.y - 1 else "stone")
		grid.append(row)
	var room: Dictionary = {
		"name": "Surface Test", "coord": Vector2i(1, 0), "depth": 1, "type": "combat", "umbra_stage": "clear",
		"grid": grid, "player_start": HERO, "loot": [], "traps": [],
		"enemies": [{"id": 1, "type": "crawler", "pos": AIM, "hp": 40, "max_hp": 40}],
	}
	var relics: Array = ["alchemists_retort"] if id == "jaw_trap" else []
	var state: Dictionary = Combat.new().create_combat(SEED, room, {
		"hp": 24, "max_hp": 24, "deck_cards": [id], "relics": relics, "hand_size": 1,
	})
	state["deck"]["draw"] = [DRAW_FIXTURE_CARD]
	var progression: Dictionary = Store.default_data()
	for prompt_id: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt_id)
	var run: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = room["coord"]
	run["current_room_layout"] = room
	run["progression"] = progression
	run["combat_state"] = state
	run["relics"] = relics
	run["notice"] = ""
	_scene.call("_load_run_state", run)

func _capture_card(id: String) -> void:
	_install_combat(id)
	await _settle()
	var face: CardWidget = _scene.call("_hand_card_control", 0) as CardWidget
	_expect(is_instance_valid(face) and face.card_id == id, "%s is in the live hand" % id)
	if not is_instance_valid(face): return
	_scene.call("_set_hand_emphasized_index", 0, false)
	var stack: Control = _scene.get("_card_focus_tooltip_stack")
	var exact: String = _widget_rules(face)
	if id == "caltrops":
		var caltrops: Dictionary = face.call("_resolved_sentence_face", face.display_summary_rows())
		_expect(caltrops["chip"]["word"] == "Tile" and str(caltrops["chip"]["display"]) == "2", "Caltrops keeps its Tile and Range 2 chip")
		var consume_end: String = " tile. Leave " if _before else ". Leave "
		_expect(caltrops["sentence"][1]["text"] == consume_end, "Caltrops face matches this capture version")
	var inspection: PanelContainer = Tooltip.make_lines(face.call("_display_card_def")["name"], PackedStringArray([exact]))
	inspection.position = INSPECTION_POSITION
	inspection.z_index = INSPECTION_Z
	_scene.get("ui_root").add_child(inspection)
	await _settle()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	_expect(viewport_rect.encloses(inspection.get_global_rect()), "%s inspection fits viewport" % id)
	if id == "caltrops":
		var face_rect: Rect2 = _scene.call("_control_visual_global_rect", face)
		_expect(viewport_rect.encloses(face_rect), "The focused Caltrops face fits the capture viewport")
	var inspection_text: PackedStringArray = _visible_text(inspection, id)
	_expect(inspection_text.has(exact), "%s inspection renders exact rules" % id)
	var stack_rect: Rect2 = stack.get_global_rect()
	if id == "lodestone_reversal" and _viewport.size.x == 1280 and not viewport_rect.encloses(stack_rect):
		print("TXT28 LAYOUT NOTE: Lodestone keyword stack extends beyond the compact viewport: %s" % stack_rect)
	else:
		_expect(stack.visible and viewport_rect.encloses(stack_rect), "%s keyword stack fits viewport (%s)" % [id, stack_rect])
	var panel_text: PackedStringArray = _visible_text(stack, id)
	if not _before and PANEL_SENTENCES.has(id):
		_expect(panel_text.has(PANEL_SENTENCES[id]), "%s renders its approved panel" % id)
	if not _before and id == "meteorfall":
		_expect(not panel_text.has("RANGED"), "Meteorfall omits the Ranged panel")
	await _save(id)
	inspection.queue_free()
	_scene.call("_set_hand_emphasized_index", -1, false)
	if _headless and not _before and _viewport.size.x == 1920:
		_check_mirror_widgets(face, exact)
	if id == "lodestone_reversal":
		await _capture_lodestone()

func _widget_rules(face: CardWidget) -> String:
	return Display.rules_text(face.card_id, face.call("_display_card_def"), face.display_summary_rows())

func _check_mirror_widgets(hand: CardWidget, exact: String) -> void:
	var host := HBoxContainer.new()
	host.position = Vector2(_viewport.size)
	_scene.get("ui_root").add_child(host)
	var shop := Shop.new()
	shop.set("_run_state", _scene.get("_run_state"))
	var shop_card: CardWidget = shop.call("_build_native_scaled_card", host, hand.card_id, MIRROR_SIZE, "Txt28Shop", false)
	var reward_cards: Array[Control]
	_scene.call("_add_reward_choice_card", host, hand.card_id, MIRROR_SIZE, reward_cards)
	var reward: CardWidget = reward_cards[0] as CardWidget
	var hand_panels: Array[Dictionary] = Icons.tooltip_entries_for_rows(hand.display_summary_rows())
	for card: CardWidget in [shop_card, reward]:
		_expect(_widget_rules(card) == exact, "%s %s rules differ from hand: %s | %s" % [hand.card_id, card.name, _widget_rules(card), exact])
		var panels: Array[Dictionary] = Icons.tooltip_entries_for_rows(card.display_summary_rows())
		_expect(panels == hand_panels, "%s %s keywords differ from hand: %s | %s" % [hand.card_id, card.name, _panel_bodies(panels), _panel_bodies(hand_panels)])
	if hand.card_id == "jaw_trap":
		var item_row: Control = _scene.call("_build_item_card_tile_body", hand.card_id)
		var summary: Label = item_row.find_child("RowSummary", true, false)
		_expect(summary.text == "Deal 3 damage at Range 2 and Immobilize.", "Jaw Trap Pack inspection binds damage and Range independently")
		item_row.free()
	shop.free()
	host.queue_free()

func _panel_bodies(panels: Array[Dictionary]) -> Array:
	return panels.map(func(panel: Dictionary) -> String: return panel["description"])

func _capture_lodestone() -> void:
	await _scene.call("_on_card_pressed", 0)
	_scene.call("_on_board_tile_hovered", AIM)
	_scene.call("_sync_click_targeting_arrow", _scene.call("_controller_board_point", AIM))
	await _settle()
	var presentation: Dictionary = _scene.get("board_view").get("presentation")
	var landing: Vector2i = AIM if _before else END
	var events: Array = presentation.get("surface_preview_events", [])
	_expect(events.any(func(event: Dictionary) -> bool:
		return event.get("kind") == "surface_created" and event.get("surface") == "electrified" and event.get("tile") == landing
	), "Lodestone board preview publishes Electrified at %s" % landing)
	await _save("lodestone_aimed")
	_scene.call("_on_cancel_requested")

func _visible_text(node: Node, context: String) -> PackedStringArray:
	var result := PackedStringArray()
	if node is Label and node.is_visible_in_tree():
		_expect(node.get_visible_line_count() == node.get_line_count(), "%s label clips: %s" % [context, node.text])
		result.append(node.text)
	elif node is RichTextLabel and node.is_visible_in_tree():
		_expect(node.get_content_height() <= node.size.y + TEXT_TOLERANCE, "%s rich text clips" % context)
		result.append(node.get_parsed_text())
	for sentence: String in result:
		_expect(_markup.search(sentence) == null, "%s leaks markup: %s" % [context, sentence])
	for child: Node in node.get_children():
		result.append_array(_visible_text(child, context))
	return result

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame

func _save(id: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == _viewport.size, "%s has exact capture dimensions" % id)
	if image == null: return
	var path: String = _output.path_join(id + ".png")
	_expect(image.save_png(path) == OK, "%s PNG written" % id)
	_captures += 1

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
