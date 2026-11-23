extends SceneTree
## Run through native.sh. An absolute script path runs against either worktree.
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Rule = preload("res://scripts/battlefield_rules/dispatcher.gd")
const UiTooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const GuardianFixture = preload("res://tools/guardian_inspection.gd")
const WarbandFixture = preload("res://tools/warband_inspection.gd")
const DragonFixture = preload("res://tools/dragon_boss_inspection.gd")
const SnareFixture = preload("res://tools/snare_inspection.gd")
const LastLightFixture = preload("res://tools/last_light_inspection.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const BattleFixture = preload("res://tests/suites/en01_enemies_suite.gd")
const BoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const REFERENCE := Vector2i(1920, 1080)
const COMPACT := Vector2i(1280, 800)
const COST_DEPTH: int = 15
const FIXTURE_SEED: int = 7262026
const READY_FRAMES: int = 600
const SETTLE_FRAMES: int = 5
const BOUNDS_TOLERANCE: float = 2.0
const TOOLTIP_POSITION := Vector2(1130, 420)
const TRAP_TILE := Vector2i(5, 4)
const DEFERRED_CARD: String = "shatterline"
const FIXTURE_EMBERS: int = 100
const NOCTYRAX_DEPTH: int = 24
const WARBAND_BIOMES: Dictionary = {"slagmaster": "fire", "dynamo": "lightning", "prior": "shadow"}
const TODO_DESIGN_ashen_reaver_prebattle_rule_placement: String = "Ashen Reaver's pre-battle screen has no Wildfire rule slot."
var _engine := Run.new()
var _combat := Combat.new()
var _base: Dictionary
var _viewport: SubViewport
var _scene: Node
var _size: Vector2i
var _headless: bool
var _before: bool
var _output: String
var _observations: Dictionary
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_size = COMPACT if args.has("--compact") else REFERENCE
	_before = args.has("--before")
	_headless = DisplayServer.get_name() == "headless"
	_output = "user://txt27"
	for arg: String in args:
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	if _headless != args.has("--validate-only"):
		push_error("Pass --validate-only only for a headless layout dry run.")
		quit(1)
		return
	_output = ProjectSettings.globalize_path(_output)
	_expect(DirAccess.make_dir_recursive_absolute(_output) == OK, "Output directory is writable")
	await TestClock.run_scoped(self, func(_scope: TestClock.GlobalScope) -> void: await _fixtures())
	var manifest := FileAccess.open(_output.path_join("layout.json"), FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify({"size": str(_size), "ui_scale": 1.0, "before": _before, "headless": _headless, "observations": _observations, "failures": _failures, "prebattle_rule_placement": TODO_DESIGN_ashen_reaver_prebattle_rule_placement}, "\t"))
	for failure: String in _failures: print("FAIL: " + failure)
	print("TXT27 %s %dx%d: %d surfaces, %d failures. %s" % ["HEADLESS LAYOUT" if _headless else "NATIVE CAPTURE", _size.x, _size.y, _observations.size(), _failures.size(), _output])
	quit(0 if _failures.is_empty() else 1)

func _fixtures() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.set_storage_path("user://txt27-settings.json")
	Store.set_storage_path("user://txt27-profile.json")
	Store.set_run_storage_path("user://txt27-run.save")
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.mode = Window.MODE_WINDOWED
	root.size = _size
	_viewport = SubViewport.new()
	_viewport.size = _size
	var expand: float = maxf(float(REFERENCE.x) / _size.x, float(REFERENCE.y) / _size.y)
	_viewport.size_2d_override = Vector2i((Vector2(_size) * expand).round())
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	Settings.inherit_edge_smoothing(_viewport, root)
	_base = _engine.create_new_run(FIXTURE_SEED, BoonFixture.profile())
	var roc: Dictionary = _guardian("gallows_roc", "encounter")
	_expect(Store.save_run_state(roc), "Saved the isolated Gallows Roc fixture")
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(READY_FRAMES):
		if _scene.initial_presentation_is_ready(): break
		await process_frame
	_expect(_scene.initial_presentation_is_ready(), "Run scene is ready")
	await _battlefield("gallows_roc", roc)
	var prebattle: Dictionary = _guardian("ashen_reaver", "pre_battle")
	await _load(prebattle)
	var preview: Control = _scene.get("_pre_battle_panel")
	_expect(preview.is_visible_in_tree(), "Ashen Reaver pre-battle panel is visible")
	await _capture("ashen_reaver_pre_battle", preview, "Ashen Reaver")
	await _battlefield("ashen_reaver", _engine.begin_pre_battle_combat(prebattle))
	for rule_id: String in WARBAND_BIOMES:
		var state: Dictionary = WarbandFixture.build(_engine, _combat, _base, {"warband_biome": WARBAND_BIOMES[rule_id]})
		await _battlefield(rule_id, state)
		if rule_id == "slagmaster":
			await _slagmaster_order()
	await _battlefield("noctyrax", DragonFixture.build(_engine, _combat, _base, {"dragon_id": "noctyrax", "dragon_depth": NOCTYRAX_DEPTH}))
	await _battlefield("snare_shadow", SnareFixture.build(_engine, _combat, _base, {"snare_biome": "shadow"}))
	await _battlefield("last_light", LastLightFixture.build(_engine, _combat, _base, {}))
	await _event("whispering_well", "ember")
	await _event("ossuary_gamblers", "wager_embers")
	await _event("cinder_supplicant", "hand", true)
	await _boon()
	await _combat_details()
	_scene._character_row_preparation_revision += 1
	_scene._grimoire_row_preparation_revision += 1
	await _settle()
	_scene.queue_free()
	await _settle()
	_viewport.queue_free()
	await _settle()

func _guardian(id: String, study: String) -> Dictionary:
	return GuardianFixture.build(_engine, _combat, _base, {"guardian_id": id, "guardian_case": study})

func _combat_run(battle: Dictionary) -> Dictionary:
	var state: Dictionary = _base.duplicate(true)
	state["mode"] = "combat"
	state["combat_state"] = battle
	state["current_room_layout"] = {"grid": battle["grid"]}
	return state

func _load(state: Dictionary) -> void:
	_scene.call("_load_run_state", state)
	_scene.call("_close_dialogue")
	await _settle()

func _battlefield(id: String, state: Dictionary) -> void:
	await _load(state)
	var hud: Control = _scene.get("_battlefield_rule_hud")
	var sentence: String = str(Rule.data()["instances"][id]["sentence"])
	_expect(hud.is_visible_in_tree(), id + " battlefield rule panel is visible")
	await _capture(id + "_battlefield", hud, sentence)

func _event(id: String, choice_id: String, deferred: bool = false) -> void:
	var state: Dictionary = EventFixture.fixture(id)
	state["umbra_depth"] = COST_DEPTH
	state["progression"][Store.UMBRA_DEPTH_UNLOCKED_KEY] = COST_DEPTH
	state = _engine.set_held_embers(state, FIXTURE_EMBERS)
	if deferred: state["skill_state"] = {"pending_card": DEFERRED_CARD}
	await _load(state)
	var view: Control = _scene.get("_event_view")
	view.finish_animation_for_test()
	var index: int = 0
	for choice: Button in view.choices:
		if choice.choice_id == choice_id: break
		index += 1
	_expect(index < view.choices.size() and view.is_visible_in_tree(), id + " has a live choice")
	if index >= view.choices.size(): return
	var choice: Button = view.choices[index]
	var expected: String = str(choice.choice_label)
	if id == "whispering_well": expected = "Drop an Ember in" if _before else "Drop Embers in"
	if id == "ossuary_gamblers":
		expected = "Stake 50 Embers" if _before else "Stake 65 Embers"
		_expect(str(choice.rows[0].get_parsed_text()).contains("Pay 65 Embers."), id + " cost row scales")
	_expect(view._content_bottom <= view.COLUMN_BOTTOM, id + " choice column fits")
	if deferred:
		view.preview_choice(index)
		await _settle()
		_expect(view.hover_preview.current != null and view.hover_preview.current_line.get("ids", []).has(DEFERRED_CARD) != _before, "Cinder Supplicant hover uses the correct offer for this revision")
	await _capture(id, choice, expected)

func _boon() -> void:
	var state: Dictionary = BoonFixture.state(true)
	Store.save_data(state["progression"])
	await _load(state)
	_scene.call("_speak_to_emaciated_man")
	_scene.call("_complete_current_dialogue_line")
	await _settle()
	var overlay: Control = _scene.get("_opening_boon_flow").overlay
	_expect(overlay != null, "Opening boon modal is live")
	if overlay != null:
		var heirloom: Control = overlay.find_child("Boon_heirloom", true, false)
		await _capture("heirloom", heirloom, "left here last run." if _before else "you left here.")

func _combat_details() -> void:
	var battle: Dictionary = BattleFixture.fixture(["ember_tick"])
	battle["traps"] = [{"pos": TRAP_TILE, "element": "fire", "damage": 4}]
	await _load(_combat_run(battle))
	var board: Control = _scene.get("board_view")
	var enemy: Dictionary = battle["enemies"][0]
	await _scene.call("_on_board_tile_clicked", enemy["pos"])
	await _settle()
	var rect: Rect2 = board.enemy_intent_visual_global_rect("enemy_%d" % int(enemy["id"]))
	_expect(rect.has_area(), "Ember Tick Details has real drawn bounds")
	await _capture("ember_tick_burst", null, "")
	await _scene.call("_on_board_cancel_requested")
	var tile_text: String = board.controller_tooltip_for_tile(TRAP_TILE)
	var tile_tip: Control = board._make_custom_tooltip(tile_text)
	await _tip("fire_trap_hover", tile_tip, "The trap leaves" if _before else "This trap leaves its element as ground on these tiles.")
	for key: String in ["marked", "traps"]:
		await _tip(key + "_glossary", UiTooltip.make_text(Icons.tooltip(key), {}, key), _marked_sentence() if key == "marked" else "Traps hit when entered or attacked")
	_scene.call("_open_grimoire_overlay")
	var grimoire: Control = _scene.get("_grimoire_scrim")
	for entry: String in ["combat:traps", "keyword:marked"]:
		grimoire.call("_on_grimoire_entry_pressed", entry)
		await _capture(entry.replace(":", "_") + "_grimoire", grimoire, _marked_sentence() if entry.ends_with("marked") else "Traps hit when entered or attacked")
	_scene.call("_close_grimoire_overlay")

func _marked_sentence() -> String:
	return "Marked tiles are hit on this enemy's next turn." if _before else "Marked tiles show where this enemy acts on its next turn."

func _slagmaster_order() -> void:
	var state: Dictionary = WarbandFixture.build(_engine, _combat, _base, {"warband_biome": "fire", "warband_case": "pre_battle"})
	await _load(state)
	_scene._prepared_pre_battle_factory = WarbandFixture.prepared(_engine, _combat, state)
	_expect(_scene._show_pre_battle_preview(), "Fire Warband pre-battle opens")
	var battle: Dictionary = _scene._pre_battle_preview_run_state.get("combat_state", {})
	for unit: Dictionary in battle.get("enemies", []):
		if not bool(unit.get("is_leader", false)): continue
		_scene._open_pinned_pre_battle_inspection("enemy", str(unit["type"]), null, unit)
		var panel: Control = _scene.get("_pinned_tooltip_panel")
		var expected: String = "After every second Slagmaster turn, its Fire spreads 1 tile toward you." if _before else "After every second Slagmaster turn, each Fire tile spreads 1 tile in the direction from the Slagmaster to you."
		await _capture("slagmaster_order", panel, expected)
		_scene._close_pinned_tooltip()
		_scene._close_pre_battle_preview()
		return
	_expect(false, "Fire Warband preview has the Slagmaster")

func _tip(id: String, panel: Control, expected: String) -> void:
	_expect(panel != null, id + " tooltip builder returned a real panel")
	if panel == null: return
	_viewport.add_child(panel)
	panel.position = TOOLTIP_POSITION
	await _capture(id, panel, expected)
	panel.queue_free()
	await _settle()

func _capture(id: String, scope: Control, expected: String) -> void:
	await _settle()
	var text_rows: Array[Dictionary]
	if scope != null: _collect_text(scope, text_rows)
	if not expected.is_empty():
		var match_row: Dictionary = {}
		for row: Dictionary in text_rows:
			if str(row["text"]).contains(expected):
				match_row = row
				break
		_expect(not match_row.is_empty(), id + " renders " + expected)
		if not match_row.is_empty(): _expect(bool(match_row["fits"]), id + " rendered copy fits: " + str(match_row))
	_observations[id] = text_rows
	if _headless: return
	await RenderingServer.frame_post_draw
	var capture: Image = _viewport.get_texture().get_image()
	var path: String = _output.path_join(id + ".png")
	_expect(capture.get_size() == _size and capture.save_png(path) == OK, id + " saves at the exact capture size")
	print(path)

func _collect_text(node: Node, rows: Array[Dictionary]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	var value: String = ""
	var fits: bool = true
	if node is RichTextLabel and not node.get_parsed_text().is_empty():
		value = node.get_parsed_text()
		fits = node.get_content_height() <= node.size.y + BOUNDS_TOLERANCE
	elif node is Label:
		value = node.text
		fits = node.get_minimum_size().y <= node.size.y + BOUNDS_TOLERANCE and node.get_minimum_size().x <= node.size.x + BOUNDS_TOLERANCE
	if not value.is_empty():
		_expect(not value.contains("@pattern(") and not value.contains("@kw(") and not value.contains("@term(") and not value.contains("@icon("), str(node.get_path()) + " renders without raw markup")
		rows.append({"node": str(node.get_path()), "text": value, "fits": fits})
	for child: Node in node.get_children():
		_collect_text(child, rows)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
