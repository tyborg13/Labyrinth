extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Install = preload("res://tests/suites/en03_enemies_suite.gd")
const Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
const TooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const InlineText = preload("res://scripts/inline_icon_text.gd")
const EventText = preload("res://scripts/event_view_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const GraftFixture = preload("res://tests/suites/graftwright_suite.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://text_rewrite_probe"
# Debug-only proof placement and settling; production layouts remain unchanged.
const PROOF_TOOLTIP_POSITION := Vector2(1140, 280)
const PROOF_CARD_POSITION := Vector2(700, 320)
const PROOF_CARD_SIZE := Vector2(250, 352)
const SETTLE_FRAMES: int = 8
const PROOF_TOKEN_MARKUP: String = "Gain @kw(block). Gain @term(health|Health)."
const PROOF_STYLE_WIDTH: float = 520.0
const PROOF_EVENT_POSITION := Vector2(1140, 540)
const PROOF_DEFINITION_POSITION := Vector2(1140, 680)
const PROOF_HOVER_STEP: int = 2
var _logic_only: bool = false
var _errors: Array[String]
var _canvas: SubViewport
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	_logic_only = OS.get_cmdline_user_args().has("--verify-logic")
	if DisplayServer.get_name() == "headless" and not _logic_only:
		push_error("TEXT REWRITE PROBE requires a real renderer")
		quit(1)
		return
	Store.set_storage_path("user://text_rewrite_profile.json")
	Store.set_run_storage_path("user://text_rewrite_run.save")
	Settings.set_storage_path("user://text_rewrite_settings.json")
	Store.clear_saved_run()
	Settings.clear_storage()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_expect(root.content_scale_factor == 1.0, "100% UI scale")
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(scene)
	await _settle()
	scene._load_run_state(Run.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	await _settle()
	var combat: Dictionary = Fixtures.capacitor(3)
	Install.install(scene, combat)
	scene._close_dialogue()
	scene._close_large_map()
	await _settle()
	var enemy: Dictionary = combat["enemies"][0]
	_expect(enemy["intent"]["id"] == "discharge" and enemy["intent"]["name"] == "Arc Burst", "Arc Burst keeps its saved intent id")
	scene._on_board_tile_hovered(enemy["pos"])
	await _settle()
	var badge: Dictionary = scene.board_view._unit_status_badges(enemy)[0]
	_expect(badge["tooltip"] == Icons.tooltip("charge") + "\n3/3", "Live Charge status uses glossary plus live count")
	await _tooltip(scene.board_view, badge["tooltip"], "status_charge")
	var intent_text: String = scene.board_view.enemy_intent_tooltip("enemy_1")
	_expect(intent_text.contains("Arc Burst") and intent_text.contains(Icons.description("charge")), "Live Arc Burst intent explains Charge")
	await _tooltip(scene.board_view, intent_text, "intent_arc_burst")
	var meter: Control = scene.get("_movement_meter") as Control
	_expect(meter.visible and meter.mouse_filter != Control.MOUSE_FILTER_IGNORE, "Live Movement meter receives tooltip hover")
	_expect(meter.tooltip_text.begins_with(Icons.tooltip("movement") + "\n"), "Movement resource uses its own glossary entry")
	await _tooltip(meter, meter.tooltip_text, "movement_meter")
	for intent: Dictionary in Data.enemy_def("vaeloryx").get("intents", []):
		if intent["id"] != "hollow_gale": continue
		for action: Dictionary in intent["actions"]:
			_expect(Icons.action_icon_key(action) == "gale_force", "Every live Hollow Gale action uses its approved identity")
			_expect(Icons.tokens_for_action(action)[0]["icon"] == "gale_force", "Hollow Gale damage chips expose the glossary icon")
	await _duration_card(scene)
	await _duration_skills(scene)
	await _grimoire_pages(scene)
	await _token_styles(scene)
	await _graft_result(scene)
	scene.queue_free()
	await _settle()
	for error: String in _errors: push_error(error)
	print("TEXT REWRITE %s: %s (%d checks, %d failures)" % ["PROBE LOGIC" if _logic_only else "VISUAL PROOF", "PASS" if _errors.is_empty() else "FAIL", _checks, _errors.size()])
	if not _logic_only: print("TEXT_REWRITE_PROOF_DIR=" + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _tooltip(owner: Control, text: String, capture: String) -> void:
	# Build through the real owner's tooltip factory; placement is proof-only.
	var panel: Control = owner._make_custom_tooltip(text) as Control
	_expect(panel != null, capture + " uses the production tooltip factory")
	if panel == null: return
	_canvas.add_child(panel)
	panel.position = PROOF_TOOLTIP_POSITION
	await _settle()
	_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(panel.get_global_rect()), capture + " fits the viewport")
	await _capture(capture)
	panel.queue_free()
	await _settle()

func _duration_card(scene: Control) -> void:
	scene.hide()
	var card: Control = load("res://scenes/card_widget.tscn").instantiate()
	card.position = PROOF_CARD_POSITION
	card.custom_minimum_size = PROOF_CARD_SIZE
	card.size = PROOF_CARD_SIZE
	card.configure("lantern_shot")
	_canvas.add_child(card)
	var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(Data.card_def("lantern_shot")), ["time"])
	var titles: Array[String]
	for entry: Dictionary in entries:
		if entry["icon"] == "time": titles.append(entry["title"])
	_expect(titles == ["Time", "Turns"], "Identical duration art has distinct Time and Turns panels")
	var stack := Stack.new()
	_canvas.add_child(stack)
	stack.show_for(card, entries)
	await _settle()
	await _capture("card_time_and_turns")
	stack.queue_free()
	card.queue_free()
	scene.show()
	await _settle()

func _duration_skills(scene: Control) -> void:
	var skill_ids: Array[String] = ["long_dawn", "sunpath", "afterglow"]
	scene._toggle_skill_status_popover()
	scene._refresh_skill_status_popover(skill_ids)
	scene._layout_skill_status_popover()
	await _settle()
	for skill_id: String in skill_ids:
		scene._show_skill_status_page_for_skill(skill_id)
		await _settle()
		var description: RichTextLabel = scene.get("_skill_status_detail_description") as RichTextLabel
		var approved: String = Icons.description(Skills.icon_key(skill_id))
		_expect(Skills.description(skill_id) == approved, skill_id + " detail uses exact approved glossary wording")
		_expect(description.visible and description.get_meta("inline_concept_keys") == InlineText.concept_keys(approved), skill_id + " live Abilities detail renders approved concepts")
		_expect(not description.get_meta("inline_concept_keys").has("time"), skill_id + " has no duration icon mapped to Time")
		var hovered: Array[String]
		for y: int in range(0, int(description.size.y), PROOF_HOVER_STEP):
			for x: int in range(0, int(description.size.x), PROOF_HOVER_STEP):
				var tooltip: String = description.get_tooltip(Vector2(x, y))
				if not tooltip.is_empty() and not hovered.has(tooltip): hovered.append(tooltip)
		_expect(not hovered.has(Icons.tooltip("time")), skill_id + " hit testing never returns the Time tooltip")
		for key: String in InlineText.icon_keys(approved):
			_expect(hovered.has(Icons.tooltip(key)), skill_id + " retains live glossary hover for " + key)
		await _capture("ability_" + skill_id)
	scene._close_skill_status_popover(false)
	await _settle()

func _grimoire_pages(scene: Control) -> void:
	var state: Dictionary = scene._run_state.duplicate(true)
	var ids: Array[String]
	for entry: Dictionary in Grimoire.entries(): ids.append(entry["id"])
	state[Grimoire.UNLOCKED_KEY] = ids
	state[Grimoire.UNREAD_KEY] = []
	state["progression"][Grimoire.UNLOCKED_KEY] = ids.duplicate()
	state["progression"][Grimoire.UNREAD_KEY] = []
	scene._load_run_state(state)
	scene._close_dialogue()
	scene._open_grimoire_overlay()
	await _settle()
	for id: String in ["keyword:illuminate", "keyword:surface_consume", "keyword:chilled", "combat:surface_techniques", "combat:card_plays"]:
		scene._on_grimoire_entry_pressed(id)
		await _settle()
		var expected: Dictionary = Grimoire.entry_def(id)
		_expect(scene._grimoire_detail_title.text == expected["title"], "Grimoire title follows approved data: " + id)
		_expect(scene._grimoire_detail_body.get_parsed_text().contains(str(expected["body"][0])), "Grimoire body follows approved data: " + id)
		await _capture("grimoire_" + id.replace(":", "_"))
	scene._close_grimoire_overlay()

func _token_styles(scene: Control) -> void:
	scene.hide()
	var host := Control.new()
	host.size = Vector2(VIEWPORT_SIZE)
	_canvas.add_child(host)
	var card: Control = load("res://scenes/card_widget.tscn").instantiate()
	card.position = PROOF_CARD_POSITION
	card.custom_minimum_size = PROOF_CARD_SIZE
	card.size = PROOF_CARD_SIZE
	card.configure("quick_stab")
	host.add_child(card)
	card.set_display_overrides(PROOF_TOKEN_MARKUP)
	await _settle()
	var description: RichTextLabel = card.desc_label
	_expect(description.visible and not description.get_parsed_text().contains("@"), "Card description expands explicit tokens")
	_expect(_card_word_hover(card, description), "Card description token words retain glossary hover")
	card.set_display_overrides("", [], [[Icons.rules_text_token(PROOF_TOKEN_MARKUP)]])
	await _settle()
	var rules: RichTextLabel = card.find_child("SummaryRulesText", true, false) as RichTextLabel
	_expect(rules != null and not rules.get_parsed_text().contains("@"), "Card rules rows expand explicit tokens")
	if rules != null:
		_expect(not rules.hint_underlined and rules.get_theme_font("normal_font") == Typography.text_font(), "Card tokens inherit their text font without underline")
		_expect(_card_word_hover(card, rules), "Card rules token words retain glossary hover")
	var relic: Dictionary = Data.relic_def("obsidian_heart")
	var relic_panel: Control = TooltipPanel.make_text(relic["name"] + "\n" + relic["description"])
	relic_panel.position = PROOF_TOOLTIP_POSITION
	host.add_child(relic_panel)
	var event_label: RichTextLabel = EventText.label(PROOF_TOKEN_MARKUP, PROOF_STYLE_WIDTH, Typography.SIZE_BODY_LARGE, Palette.TEXT, false, true)
	event_label.position = PROOF_EVENT_POSITION
	host.add_child(event_label)
	_expect(not event_label.hint_underlined and not event_label.get_parsed_text().contains("@"), "Toned event text uses the shared keyword style")
	var definition: Control = TooltipPanel.make_text("Glossary token fixture\n" + PROOF_TOKEN_MARKUP)
	definition.position = PROOF_DEFINITION_POSITION
	host.add_child(definition)
	var definition_words: Array[Node] = definition.find_children("*", "RichTextLabel", true, false)
	_expect(definition_words.size() == 1 and not (definition_words[0] as RichTextLabel).hint_underlined, "Glossary definition tokens use the shared style")
	_expect(InlineText.KEYWORD_COLOR == Palette.GOLD_BRIGHT, "Every token surface shares the approved gold")
	await _settle()
	await _capture("token_styles")
	host.queue_free()
	scene.show()
	await _settle()

func _card_word_hover(card: Control, words: RichTextLabel) -> bool:
	for y: int in range(0, int(words.size.y), PROOF_HOVER_STEP):
		for x: int in range(0, int(words.size.x), PROOF_HOVER_STEP):
			var point: Vector2 = words.get_global_transform() * Vector2(x, y)
			if card._tooltip_for_icon_at(point) == Icons.tooltip("block"):
				return true
	return false

func _graft_result(scene: Control) -> void:
	var grafted: Dictionary = Run.new().graft_equipment(GraftFixture.fixture(), "undertaker_plate", "patched_cloak", 1, 1)
	scene._load_run_state(grafted)
	await _settle()
	var result_line: Label = scene.find_child("ConsumedEquipment", true, false) as Label
	_expect(result_line != null and result_line.text == "Patched Cloak destroyed", "Graft result uses the approved donor verb and item name")
	await _capture("graftwright_result")

func _capture(name: String) -> void:
	if _logic_only: return
	await RenderingServer.frame_post_draw
	var capture: Image = _canvas.get_texture().get_image()
	_expect(capture != null and capture.get_size() == VIEWPORT_SIZE, name + " is native 1920x1080")
	if capture != null:
		var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(name + ".png"))
		_expect(capture.save_png(path) == OK, "Saved " + name)
		print("TEXT_REWRITE_CAPTURE=" + path)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _errors.append(message)
