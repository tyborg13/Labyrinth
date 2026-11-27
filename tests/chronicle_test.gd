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
const ChroniclePanel = preload("res://scripts/chronicle_panel.gd")
const RunPreload = preload("res://scripts/menu_run_preload.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const ASH_TEST_PROFILE_PATH: String = "user://chronicle_ash_regression.json"
const ASH_TEST_RUN_PATH: String = "user://chronicle_ash_regression.save"
const ASH_INSTALL_COUNT: int = 3
const ASH_TEST_SEED: int = 6
const ASH_TEST_CARD_ID: String = "ash_qa136_spell"
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
	_test_definition_deltas()
	_test_definition_cache_distinct_records()
	_test_relic_definition_round_trip()
	_test_tooltip_placement()
	var canvas: SubViewport = Probe.create_capture_viewport(root)
	_check(canvas.size == Vector2i(1920, 1080) and canvas.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Chronicle proof uses a fixed 1920x1080 render target updated every frame")
	var menu: Control = preload("res://scenes/main_menu.tscn").instantiate()
	canvas.add_child(menu)
	await process_frame
	var resume: Button = menu.get_node("MenuColumn/ContinueButton")
	var start: Button = menu.get_node("MenuColumn/StartButton")
	var button: Button = menu.get_node("MenuColumn/ChronicleButton")
	var grimoire: Button = menu.get_node("MenuColumn/GrimoireButton")
	var settings: Button = menu.get_node("MenuColumn/SettingsButton")
	var quit_button: Button = menu.get_node("MenuColumn/QuitButton")
	var title_buttons: Array[Button] = [resume, start, button, grimoire, settings, quit_button]
	for index: int in range(1, title_buttons.size()):
		_check(title_buttons[index].get_index() == title_buttons[index - 1].get_index() + 1, "Title order places %s directly after %s" % [title_buttons[index].name, title_buttons[index - 1].name])
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await process_frame
	var profile_was_visible: bool = menu.get_node("ProfileBlock").visible
	await Probe.click_button(button, canvas)
	await process_frame
	var panel: Control = menu.get_node("ChroniclePanel")
	_check(panel.visible and panel.get_node("ChronicleFrame").position == Vector2(60, 110) and panel.get_node("ChronicleFrame").size == Vector2(1800, 860), "Chronicle panel opens at approved geometry")
	_check(panel.get_node("ChronicleFrame/DescentList").size.x == 520, "Chronicle list has approved width")
	_check(button.position.y - start.position.y == 92, "New Game to Chronicle keeps 92 px spacing")
	_check(grimoire.position.y - button.position.y == 92, "Chronicle to Grimoire keeps 92 px spacing")
	_check(settings.position.y - grimoire.position.y == 92, "Grimoire to Settings keeps 92 px spacing")
	_check(panel.find_child("ChronicleEmpty", true, false).text == "Your runs will be written here.", "Chronicle empty body copy")
	for node_name: String in ["Title", "TitleShadow", "TitleRim", "TitleFaceBlend", "ProfileBlock"]:
		_check(not menu.get_node(node_name).visible, "Chronicle hides menu heading: " + node_name)
	menu.call("_update_layout")
	_check(not menu.get_node("ProfileBlock").visible, "Menu layout keeps the profile hidden while Chronicle is open")
	panel.close()
	_check(button.has_focus() and not panel.visible, "Chronicle close restores menu focus")
	for node_name: String in ["Title", "TitleShadow", "TitleRim", "TitleFaceBlend"]:
		_check(menu.get_node(node_name).visible, "Chronicle close restores menu title: " + node_name)
	_check(menu.get_node("ProfileBlock").visible == profile_was_visible, "Chronicle close restores the responsive profile visibility")
	var opened: Array[Dictionary] = Analytics.load_all_events()
	_check(opened.size() == 1 and opened[0]["event_type"] == "chronicle_opened" and opened[0]["payload"]["records"] == 0, "Chronicle emits one additive local open event")
	# Continue has no checkpoint in this fixture. Walk from New Game to Quit.
	start.grab_focus()
	for index: int in range(2, title_buttons.size()):
		var navigate := InputEventKey.new()
		navigate.keycode = KEY_DOWN
		navigate.pressed = true
		canvas.push_input(navigate, true)
		await process_frame
		_check(title_buttons[index].has_focus(), "Keyboard navigation reaches %s after %s" % [title_buttons[index].name, title_buttons[index - 1].name])
		var release := navigate.duplicate() as InputEventKey
		release.pressed = false
		canvas.push_input(release, true)
		await process_frame
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
	await _test_five_section_layout(panel)
	await _test_relic_wrap(panel)
	await _test_deleted_cards_and_path_focus(panel)
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
	await _test_legacy_content_save(panel)
	menu.queue_free()
	canvas.queue_free()
	await _settle_tiles()
	await _test_preload_teardown()
	for failure: String in failures:
		push_error(failure)
	print("CHRONICLE HOVER PROOF: %d native popups; 5 pointer targets" % _native_hover_popups)
	print("CHRONICLE TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL (%d failure(s))" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _test_legacy_content_save(panel: Control) -> void:
	Store.set_storage_path(ASH_TEST_PROFILE_PATH)
	Store.set_run_storage_path(ASH_TEST_RUN_PATH)
	const InitialGraph = preload("res://scripts/initial_run_graph.gd")
	root.set_meta(InitialGraph.SEED_OVERRIDE, ASH_TEST_SEED)
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	await process_frame
	var state: Dictionary = scene.get("_run_state")
	var profile: Dictionary = Store.load_data()
	var record: Dictionary = Probe.seeded_profile()[Store.CHRONICLE_RECORDS_KEY][0]
	record["killer_text"] = "Felled by an Ash Hound"
	record["relics"] = ["ashen_brand", "liturgy_of_ash"]
	profile[Store.CHRONICLE_RECORDS_KEY] = [record]
	profile[Store.GRIMOIRE_UNLOCKED_KEY] = ["enemy:ash_hound", "enemy:ashen_reaver", "omen:tithe_of_ash"]
	profile[Store.GRIMOIRE_UNREAD_KEY] = profile[Store.GRIMOIRE_UNLOCKED_KEY].duplicate()
	var current_ids: Dictionary = {}
	for live: Array in [
		["enemy", "ash_hound"], ["enemy", "ashen_reaver"], ["event", "ash_confessional"],
		["relic", "ashen_brand"], ["relic", "ashen_phylactery"], ["relic", "liturgy_of_ash"],
		["omen", "tithe_of_ash"]
	]:
		current_ids[live[1]] = live[1]
		var qualified: String = "%s:%s" % live
		current_ids[qualified] = qualified
	profile["qa136_catalog_ids"] = current_ids
	state["qa136_catalog_ids"] = current_ids
	_check(Store.save_data(profile), "Save the current-ID profile before repeated run installs")
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(ASH_TEST_PROFILE_PATH)
	for index: int in ASH_INSTALL_COUNT:
		scene.set("_progression", Store.load_data())
		scene.call("_load_run_state", state)
		_check(FileAccess.get_file_as_bytes(ASH_TEST_PROFILE_PATH) == original_bytes, "Current content and Chronicle bytes survive install %d" % (index + 1))

	var retired: Array = ["ashline_tempo", "ashweave_guard", "ashweave_mail", "ashen_buckler", "ash_bolt", "ashfall", "ash"]
	var expected: Array = ["cinderline_tempo", "cinderweave_guard", "cinderweave_mail", "iron_buckler", "dust_bolt", "cinderfall", "stone"]
	profile["qa136_legacy_ids"] = retired
	profile["qa136_profile_text"] = "Ash Hound"
	profile[Store.LAST_RUN_RESULT_KEY] = {
		"result_id": "qa136-legacy-score",
		"lines": [{"label": "ash", "detail": "Ash Hound"}],
		"killer": {"enemy_type": "ash_hound", "name": "ash"}
	}
	profile[Store.GRIMOIRE_UNLOCKED_KEY] = ["enemy:cinder", "omen:tithe_of_ash"]
	profile[Store.GRIMOIRE_UNREAD_KEY] = profile[Store.GRIMOIRE_UNLOCKED_KEY].duplicate()
	record["killer_text"] = "Felled by an cinder Hound"
	record["relics"] = ["cinder", "liturgy_of_cinder"]
	record["deck"] = [["cinder", 2], ["cinder_wall", 1]]
	record["deck_card_definitions"] = {"cinder": {"upgrade_count": 1}}
	_check(Store.save_data(profile), "Save the old and previously damaged IDs")
	var legacy: Dictionary = state.duplicate(true)
	legacy[RunEngine.RUN_CONTENT_SCHEMA_KEY] = RunEngine.RUN_CONTENT_SCHEMA - 1
	legacy["qa136_legacy_ids"] = retired
	legacy["qa136_legacy_keys"] = {"card:ash_bolt": "moved", "ashfall": "old", "cinderfall": "live"}
	legacy["qa136_legacy_text"] = "Ash Hound"
	legacy["progression"] = profile
	scene.set("_progression", Store.load_data())
	scene.call("_load_run_state", legacy)
	var migrated: Dictionary = scene.get("_run_state")
	var persisted: Dictionary = Store.load_data()
	_check(persisted.get("qa136_legacy_ids") == expected and migrated.get("qa136_legacy_ids") == expected, "All seven retired IDs migrate in installed profiles and old runs")
	_check(migrated.get("qa136_legacy_keys") == {"card:dust_bolt": "moved", "cinderfall": "live"}, "Legacy prefixed keys migrate and the canonical key wins a collision")
	_check(migrated.get("qa136_catalog_ids") == current_ids, "Current bare and namespaced keys and values survive the legacy run neutralizer")
	_check(migrated.get("qa136_legacy_text") == "cinder Hound" and persisted.get("qa136_profile_text") == "Ash Hound", "Only a legacy run uses the free-text neutralizer")
	_check(persisted[Store.CHRONICLE_RECORDS_KEY][0]["killer_text"] == "Felled by an cinder Hound", "Old run installation left previously printed history on disk")
	var result: Dictionary = persisted[Store.LAST_RUN_RESULT_KEY]
	_check(result["lines"][0]["label"] == "ash" and result["killer"]["name"] == "ash", "Profile migration leaves printed score rows and killer names untouched")
	var stored_ids: Array = persisted[Store.GRIMOIRE_UNLOCKED_KEY]
	var known: Array[String] = Grimoire.normalize_entry_ids(stored_ids)
	var without_unknown: Array = stored_ids.duplicate()
	without_unknown.erase("enemy:cinder")
	_check(stored_ids.has("enemy:cinder") and known == Grimoire.normalize_entry_ids(without_unknown) and not known.has("enemy:ash_hound"), "Unknown discovery contributes zero to the displayed count")
	var unlocked: Array = scene.call("_unlock_grimoire_entries", ["enemy:ash_hound"])
	_check(unlocked.has("enemy:ash_hound"), "Meeting the foe rediscovered its actual page")
	for index: int in ASH_INSTALL_COUNT:
		scene.set("_progression", Store.load_data())
		scene.call("_load_run_state", scene.get("_run_state"))
	var rediscovered: Dictionary = Store.load_data()
	_check(rediscovered[Store.GRIMOIRE_UNLOCKED_KEY].has("enemy:ash_hound"), "Rediscovered page stays unlocked across later run installs")
	_check(rediscovered[Store.GRIMOIRE_UNLOCKED_KEY].has("enemy:cinder") and rediscovered[Store.GRIMOIRE_UNREAD_KEY].has("enemy:cinder"), "Rediscovery keeps hidden corrupted IDs in both on-disk lists")
	scene.queue_free()
	await _settle_tiles()

	var spell: Dictionary = GameData.cards()["pale_spark"].duplicate(true)
	GameData.cards()[ASH_TEST_CARD_ID] = spell
	var damaged_bytes: PackedByteArray = FileAccess.get_file_as_bytes(ASH_TEST_PROFILE_PATH)
	panel.open(rediscovered, false)
	await _settle_tiles()
	var subline := panel.find_child("ChronicleSubline", true, false) as RichTextLabel
	var liturgy: Node = panel.find_child("Relic_liturgy_of_ash", true, false)
	_check(subline.get_parsed_text().ends_with("Felled by an Ash Hound"), "Chronicle displays the original killer name")
	_check(liturgy != null and liturgy.get("texture") != null and liturgy.get("tooltip_title") == GameData.relic_def("liturgy_of_ash")["name"], "Unique relic repair displays its existing icon and name")
	_check(panel.find_child("Relic_cinder", true, false) == null and panel.find_child("Relic_ashen_brand", true, false) == null and panel.find_child("Relic_ashen_phylactery", true, false) == null, "Ambiguous relic is absent without evidence")
	var spell_tile: Control = panel.find_child("Spell_" + ASH_TEST_CARD_ID, true, false)
	_check(spell_tile != null and spell_tile.get("count") == 2 and panel.find_child("Spell_cinder_wall", true, false) != null, "Deck resolves damaged IDs and counts while preserving real Cinder IDs")
	var display: Dictionary = Rules.display_build(rediscovered[Store.CHRONICLE_RECORDS_KEY][0])
	_check(display["card_definitions"].get(ASH_TEST_CARD_ID, {}).get("upgrade_count") == 1, "The recovered card keeps the recorded delta")
	GameData.cards()["cinder"] = spell
	_check(Rules.display_build(rediscovered[Store.CHRONICLE_RECORDS_KEY][0])["deck"][0][0] == "cinder", "An exact catalog ID named cinder takes precedence over a repair")
	GameData.cards().erase("cinder")
	var evidence: Dictionary = rediscovered.duplicate(true)
	var evidence_record: Dictionary = evidence[Store.CHRONICLE_RECORDS_KEY][0]
	evidence_record["relic_icon_paths"] = [GameData.relic_def("ashen_brand")["icon_path"]]
	panel.open(evidence, false)
	await _settle_tiles()
	_check(panel.find_child("Relic_ashen_brand", true, false) != null, "Stored icon path uniquely identifies one ambiguous relic")
	evidence_record.erase("relic_icon_paths")
	evidence_record["relic_names"] = [GameData.relic_def("ashen_phylactery")["name"]]
	_check(Rules.display_build(evidence_record)["relics"].has("ashen_phylactery"), "Stored printed name uniquely identifies the other ambiguous relic")
	_check(FileAccess.get_file_as_bytes(ASH_TEST_PROFILE_PATH) == damaged_bytes, "Drawing repaired Chronicle records never rewrites profile bytes")
	GameData.cards().erase(ASH_TEST_CARD_ID)
	panel.close()
	Store.set_storage_path("")
	Store.set_run_storage_path("")

func _test_preload_teardown() -> void:
	# Model an explicit run request abandoned while the tree remains live.
	_check(RunPreload.request_for(self, RunPreload.RUN_SCENE_PATH) == OK, "Run-scene request was accepted")
	RunPreload.abandon_for(self, RunPreload.RUN_SCENE_PATH)
	while RunPreload.status_for(self, RunPreload.RUN_SCENE_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		await process_frame
	_check(ResourceLoader.load_threaded_get_status(RunPreload.RUN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "Abandoned request releases its engine token on live frames")

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

func _test_definition_deltas() -> void:
	var state := {"chronicle_path": [["combat"]], "deck_cards": ["pale_spark", "chain_bolt"], "relics": [], "seed": 8821}
	_check(Rules.build_record(state, "victory", {})["deck_card_definitions"] == {}, "Unmodified build_record stores no card definitions")
	state["relics"] = ["storm_capacitor"]
	var snapshots: Dictionary = Rules.build_record(state, "victory", {})["deck_card_definitions"]
	_check(snapshots.keys() == ["chain_bolt"], "Run relic stores only the card whose printed rules changed")
	_check(not JSON.stringify(snapshots).contains('"_'), "Saved card deltas contain no internal combat or relic tags")
	var upgraded: Dictionary = GameData.card_def_with_card_mods("pale_spark", {"pale_spark": [Probe.TILE_FIXTURE_UPGRADE_MOD]})
	var expected := {"actions": upgraded["actions"], "base_card_id": "pale_spark", "upgraded": true, "upgrade_count": 1}
	var delta: Dictionary = Rules.card_definition_delta("pale_spark", upgraded)
	_check(delta == JSON.parse_string(JSON.stringify(expected)), "An upgraded card stores exactly its changed public fields")
	upgraded["id"] = "pale_spark"
	_check(JSON.parse_string(JSON.stringify(Rules.card_definition("pale_spark", {"pale_spark": delta}))) == JSON.parse_string(JSON.stringify(upgraded)), "Upgraded delta resolves to the complete printed card")
	var record: Dictionary = Probe.seeded_profile()[Store.CHRONICLE_RECORDS_KEY][0].duplicate(true)
	record["deck"] = [["pale_spark", 1], ["retired_snapshot_only", 1], ["empty_definition", 1], ["invalid_definition", 1]]
	record["deck_card_definitions"] = {
		"pale_spark": {"name": GameData.card_def("pale_spark")["name"], "_card_element": "light"},
		"retired_snapshot_only": {"actions": [{"amount": 2, "_card_action_types": ["melee"]}], "_runtime": true},
		"empty_definition": {}, "invalid_definition": ["bad"], "not_in_deck": {"name": "Drop me"}
	}
	var normalized: Dictionary = Rules.normalized_record(record)["deck_card_definitions"]
	_check(normalized == {"pale_spark": {"name": GameData.card_def("pale_spark")["name"]}, "retired_snapshot_only": {"actions": [{"amount": 2.0}]}}, "Normalization sanitizes stored deltas without rebuilding them or requiring live card ids")
	_check(typeof(normalized.get("retired_snapshot_only", {}).get("actions", [{}])[0].get("amount")) == TYPE_FLOAT, "Normalization canonicalizes nested integers as floats")
	_check(record["deck_card_definitions"]["retired_snapshot_only"].has("_runtime"), "Normalization leaves the supplied record unchanged")
	var next: Dictionary = record.duplicate(true)
	next["run_id"] += "-next"
	var history: Array[Dictionary] = Rules.normalized_records([record, next])
	history[0]["deck_card_definitions"]["retired_snapshot_only"]["actions"][0]["amount"] = 99.0
	_check(history[1]["deck_card_definitions"]["retired_snapshot_only"]["actions"][0]["amount"] == 2.0 and record["deck_card_definitions"]["retired_snapshot_only"]["actions"][0]["amount"] == 2, "Repeated deltas normalize into independent copies without changing the input")

func _test_definition_cache_distinct_records() -> void:
	var first: Dictionary = Probe.seeded_profile()[Store.CHRONICLE_RECORDS_KEY][0].duplicate(true)
	first["deck"] = [["pale_spark", 1]]
	first["deck_card_definitions"] = {"pale_spark": {"actions": [{"type": "ranged", "damage": 2.0}]}}
	var second: Dictionary = first.duplicate(true)
	second["run_id"] += "-different-delta"
	second["deck_card_definitions"]["pale_spark"]["actions"][0]["damage"] = 9.0
	var history: Array[Dictionary] = Rules.normalized_records([first, second])
	_check(history[0]["deck_card_definitions"] == first["deck_card_definitions"], "First record retains its stored changes for a shared card id")
	_check(history[1]["deck_card_definitions"] == second["deck_card_definitions"], "Second record retains different stored changes for the same card id")

func _test_relic_definition_round_trip() -> void:
	var deck: Array = GameData.cards().keys().slice(0, 45)
	var state := {"chronicle_path": [["combat"]], "deck_cards": deck, "relics": ["crown_of_surplus", "leaden_pommel"], "seed": 8821}
	var record: Dictionary = Rules.build_record(state, "victory", {})
	_check(record["deck_card_definitions"].size() >= 40, "Relic round-trip fixture stores modifications for at least 40 cards")
	var restored: Dictionary = Rules.normalized_record(JSON.parse_string(JSON.stringify(record)))
	_check(restored["deck_card_definitions"] == record["deck_card_definitions"], "Relic deltas survive save normalization unchanged")
	for id: String in deck:
		var resolved: Dictionary = Rules.card_definition(id, restored["deck_card_definitions"])
		var printed: Dictionary = Rules._public_card_value(GameData.card_def_for_progression(id, state))
		_check(not JSON.stringify(resolved).contains('"_'), "Resolved relic card contains no internal tags: %s" % id)
		_check(JSON.parse_string(JSON.stringify(resolved)) == printed, "Normalized relic card matches its printed definition: %s" % id)

func _test_tooltip_placement() -> void:
	var bounds := Rect2(0, 0, 1920, 1080)
	var extent := Vector2(300, 400)
	var cases: Array[Rect2] = [Rect2(700, 200, 48, 64), Rect2(700, 900, 48, 64), Rect2(700, 350, 48, 400), Rect2(1800, 350, 48, 400)]
	for index: int in range(cases.size()):
		var anchor: Rect2 = cases[index]
		var rect := Rect2(ChroniclePanel.focus_tooltip_position(anchor, extent, bounds), extent)
		_check(bounds.encloses(rect) and not rect.intersects(anchor), "Focus placement stays visible without covering its tile: case %d" % index)
		match index:
			0: _check(rect.position.y == anchor.end.y, "Focus preview prefers below")
			1: _check(rect.end.y == anchor.position.y, "Focus preview falls back above")
			2: _check(rect.position.x == anchor.end.x, "Focus preview falls back right")
			3: _check(rect.end.x == anchor.position.x, "Focus preview falls back left")
	var crowded_anchor := Rect2(950, 500, 48, 64)
	var crowded_extent := Vector2(1200, 800)
	_check(crowded_extent.x > maxf(crowded_anchor.position.x, bounds.end.x - crowded_anchor.end.x) and crowded_extent.y > maxf(crowded_anchor.position.y, bounds.end.y - crowded_anchor.end.y), "Last-resort preview cannot fit on any side of its tile")
	var crowded_preview := Rect2(ChroniclePanel.focus_tooltip_position(crowded_anchor, crowded_extent, bounds), crowded_extent)
	_check(bounds.encloses(crowded_preview), "Last-resort focus placement keeps the whole preview on screen")

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
		_check(tile.get_node("CardArt").texture.get_size() == Vector2(CardTile.ART_SIZE), "Tile art is downscaled to its rendered size")
		_check(tile.get_node("CardArt").texture == CardTile.tile_art(tile.card_definition["art_path"]), "Tile art reuses the cached high-quality crop")
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
	_check(not preview.get_global_rect().intersects(duplicate.get_global_rect()), "Focused card preview never covers the spell tile")
	var tiles: Array[Control] = panel.get("_detail_tiles")
	var expected_names: Array[String]
	for id: String in record["gear"]:
		expected_names.append("Gear_" + id)
	for id: String in record["relics"]:
		expected_names.append("Relic_" + id)
	for id: String in expected_ids:
		expected_names.append("Spell_" + id)
	_check(tiles.size() == expected_names.size(), "Focus chain contains gear, spells, and relics exactly once")
	for index: int in range(tiles.size()):
		_check(tiles[index].name == expected_names[index], "Focus order follows gear, relics, spells in visual order %d" % index)
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
	_check(is_equal_approx(spells.global_position.x, 670) and is_equal_approx((panel.find_child("ChronicleFeats", true, false) as Control).global_position.x, 1450), "SPELLS starts at x670 and FEATS moves to x1450")
	var detail: VBoxContainer = panel.find_child("DescentDetail", true, false)
	var spells_header: Control = detail.get_child(spells.get_index() - 1)
	var build_row: Control = panel.find_child("ChronicleBuildRow", true, false)
	var path_row: Control = panel.find_child("ChroniclePathRow", true, false)
	_check(is_equal_approx(spells_header.position.y - build_row.get_rect().end.y, 28) and is_equal_approx(build_row.position.y - path_row.get_rect().end.y, 28), "Detail rows use 28px vertical gaps")
	var gear: Control = panel.find_child("ChronicleGear", true, false)
	var relics: Control = panel.find_child("ChronicleRelics", true, false)
	_check(relics.global_position.x - gear.get_global_rect().end.x == 40 and relics.global_position.y == gear.global_position.y, "Gear and wrapping relics share one row with a 40px gap")
	_check((panel.find_child("ChronicleFeats", true, false) as Control).global_position.y == (panel.find_child("ChroniclePath", true, false) as Control).global_position.y, "Feats and path headers are top-aligned")
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

func _test_five_section_layout(panel: Control) -> void:
	panel.open(Probe.five_section_overflow_profile(), false)
	await _settle_tiles()
	var detail: Control = panel.find_child("DescentDetail", true, false)
	var scroller: ScrollContainer = panel.get("_detail_scroll")
	print("CHRONICLE FIVE-SECTION LAYOUT: detail=%s viewport=%s" % [detail.get_global_rect(), scroller.get_global_rect()])
	_check(panel.records[0]["path"].size() == 5, "Overflow visibility fixture includes five path sections")
	_check(scroller.scroll_vertical == 0 and scroller.get_global_rect().encloses(detail.get_global_rect()), "Five-section overflow record is fully visible at rest without scrolling")
	var badge: Label = (panel.find_child("ChronicleSpells", true, false) as GridContainer).get_child(Probe.BOTTOM_ROW_DUPLICATE_INDEX).get_node("Badge")
	_check(badge.text == "×3" and scroller.get_global_rect().encloses(badge.get_global_rect()), "Bottom-row count pill is fully visible at rest")
	for tile: Control in panel.get("_detail_tiles"):
		tile.grab_focus()
		await _settle_tiles()
		var tooltip: Control = panel.get("_focus_tooltip")
		_check(tooltip != null and not tooltip.get_global_rect().intersects(tile.get_global_rect()), "Focus tooltip never covers %s" % tile.name)

func _test_deleted_cards_and_path_focus(panel: Control) -> void:
	var profile: Dictionary = Probe.seeded_profile()
	var record: Dictionary = profile[Store.CHRONICLE_RECORDS_KEY][0]
	record["gear"] = []
	record["relics"] = []
	record["deck"] = [["deleted_fire_spell", 2]]
	record["deck_card_definitions"] = {"deleted_fire_spell": {"name": "Old name", "description": "Old rules"}}
	panel.open(profile, false)
	await _settle_tiles()
	var tile: Control = panel.find_child("Spell_deleted_fire_spell", true, false)
	_check(tile.get_node("CardArt").texture == CardTile.tile_art(CardTile.CARD_BACK_PATH), "Deleted card uses the existing card-back art")
	tile.grab_focus()
	await _settle_tiles()
	var tooltip: Control = panel.get("_focus_tooltip")
	var labels: Array[Node] = tooltip.find_children("*", "Label", true, false)
	_check(labels.size() == 1 and labels[0].text == "Deleted Fire Spell", "Deleted card tooltip shows only its id in Title Case")
	record["deck"] = []
	panel.open(profile, false)
	await _settle_tiles()
	var row: Control = panel.find_child("DescentRow0", true, false)
	var path: Array[Node] = panel.find_child("DescentDetail", true, false).find_children("PathSection*Room*", "Button", true, false)
	_check(row.get_node(row.focus_next) == path[0] and row.get_node(row.focus_neighbor_right) == path[0], "A record without build tiles links list focus into its path")
	for index: int in range(path.size() - 1):
		_check(path[index].get_node(path[index].focus_next) == path[index + 1], "Path-only focus follows recorded room order")
	_check(path.back().get_node(path.back().focus_next) == panel.get_node("ChronicleFrame/ChronicleClose"), "Path-only focus reaches Close after the final room")

func _test_relic_wrap(panel: Control) -> void:
	var profile: Dictionary = Probe.seeded_profile()
	profile[Store.CHRONICLE_RECORDS_KEY][0]["relics"] = GameData.relics().keys().slice(0, 14)
	panel.open(profile, false)
	await _settle_tiles()
	var relics: Control = panel.find_child("ChronicleRelics", true, false)
	var flow: HFlowContainer = relics.get_child(1)
	_check(flow.get_child(13).position.y > flow.get_child(0).position.y, "Relics wrap onto a second row within the remaining width")
	for tile: Control in flow.get_children():
		_check(relics.get_global_rect().encloses(tile.get_global_rect()), "Every wrapped relic stays inside its column")

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
