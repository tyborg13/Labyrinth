extends SceneTree

## Real-renderer proof for the wave-4 purpose-built icons
## (spec/icon_identity_policy.md): a native-size contact sheet of every
## ActionIconLibrary keyword icon (64px and the 24px row size, new identities
## outlined), then the combat HUD with the new icons in card rows, the player's
## stance badges, a Petrified enemy and a powder keg on the board.
## Run: python3 tools/visual_probe_runner.py tests/wave4_icon_identity_probe.gd --task-id <id> --no-headless --expect-size 1920x1080 --min-images 3
const Combat = preload("res://scripts/combat_engine.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ManeuverRules = preload("res://scripts/maneuver_rules.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/chain_attack_suite.gd")
const ManeuverSuite = preload("res://tests/suites/maneuver_suite.gd")
const SurfaceSuite = preload("res://tests/suites/card_mechanics_surfaces_suite.gd")
const IllusionSuite = preload("res://tests/suites/illusion_terrain_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT := "user://probes/wave4_icon_identity"
const NEW_ICON_KEYS: Array = ["swap", "petrify", "cleanse", "skate", "anchored", "fireproof", "surface_convert", "discharge", "all_enemies", "illusion_swap", "shatter_illusion"]
const SHEET_COLUMNS: int = 12
var view: SubViewport
var failed: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Progression.set_storage_path("user://wave4_icon_progression.json")
	Progression.set_run_storage_path("user://wave4_icon_run.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://wave4_icon_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_2d = Viewport.MSAA_4X
	root.add_child(view)
	await _contact_sheet()
	await _combat_hud()
	print("WAVE4 ICON IDENTITY PROBE: ", "PASS" if failed == 0 else "FAIL (%d)" % failed)
	quit(1 if failed else 0)

func _contact_sheet() -> void:
	var sheet := Control.new()
	sheet.size = Vector2(1920, 1080)
	view.add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("1d1813")
	background.size = sheet.size
	sheet.add_child(background)
	var keys: Array = ActionIcons.KEYWORDS.keys()
	var cell := Vector2(158.0, 92.0)
	for index: int in range(keys.size()):
		var key: String = str(keys[index])
		var origin := Vector2(12.0 + float(index % SHEET_COLUMNS) * cell.x, 10.0 + floorf(float(index) / float(SHEET_COLUMNS)) * cell.y)
		var texture: Texture2D = ActionIcons.icon_texture(key)
		expect(texture != null, "%s icon should load" % key)
		if key in NEW_ICON_KEYS:
			var outline := ReferenceRect.new()
			outline.border_color = Color("e7b45a")
			outline.border_width = 2.0
			outline.editor_only = false
			outline.position = origin - Vector2(4.0, 4.0)
			outline.size = Vector2(cell.x - 6.0, cell.y - 4.0)
			sheet.add_child(outline)
		for spec: Array in [[Vector2(0.0, 0.0), 64.0], [Vector2(72.0, 20.0), 24.0]]:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = origin + (spec[0] as Vector2)
			icon.size = Vector2(float(spec[1]), float(spec[1]))
			sheet.add_child(icon)
		var label := Label.new()
		label.text = key
		label.position = origin + Vector2(0.0, 66.0)
		label.size = Vector2(cell.x - 10.0, 18.0)
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("ffd98a") if key in NEW_ICON_KEYS else Color("cbbfa8"))
		sheet.add_child(label)
	for key: String in NEW_ICON_KEYS:
		expect(ActionIcons.KEYWORDS.has(key), "%s should be a registered keyword icon" % key)
	await _capture("01_keyword_icon_contact_sheet")
	sheet.queue_free()
	await process_frame

func _combat_hud() -> void:
	ManeuverSuite._install_fixtures()
	SurfaceSuite._install_fixtures()
	IllusionSuite._install_fixtures()
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.2).timeout
	var progression: Dictionary = scene.get("_progression") as Dictionary
	for prompt: String in Tutorials.prompt_ids(): progression = Tutorials.resolve_progression(progression, prompt)
	scene.set("_progression", progression)
	var combat := Combat.new()
	var state: Dictionary = Fixture.fixture(combat)
	state = combat.apply_player_action(state, combat.card_play_actions("w4c_fx_powder_keg", state)[0], Vector2i(3, 5))
	state = combat.apply_player_action(state, combat.card_play_actions("w4b_petrify", state)[0], Vector2i(4, 4))
	for flag: String in ManeuverRules.FLAG_ORDER:
		ManeuverRules.gain_flag(state, {"flag": flag}, "Icon proof")
	# Ground and an illusion so the surface and illusion cards are playable, not dimmed.
	for placement: Array in [[Vector2i(6, 4), "fire"], [Vector2i(5, 4), "electrified"], [Vector2i(5, 5), "electrified"], [Vector2i(3, 6), "ice"], [Vector2i(4, 6), "ice"]]:
		Surface.place(state, placement[0] as Vector2i, str(placement[1]), {"actor_kind": "test"})
	state = combat._create_illusion(state, Vector2i(2, 6), 4, {"source_name": "Icon proof"})
	var petrified: bool = false
	for enemy: Dictionary in state.get("enemies", []):
		petrified = petrified or int(enemy.get("petrify", 0)) > 0
	expect(petrified, "The fixture enemy should be Petrified")
	var keg_present: bool = false
	for terrain: Dictionary in state.get("terrain", []):
		keg_present = keg_present or str(terrain.get("kind", "")) == "powder_keg"
	expect(keg_present, "The fixture board should hold a powder keg")
	var hands: Array = [
		["w4b_changing_winds", "w4b_petrify", "w4b_skate", "w4b_unpick", "w4b_windbreak"],
		["w4a_fx_frost_circuit", "w4a_fx_discharge", "w4a_fx_stoke", "w4c_fx_empty_husk", "w4c_fx_shattered_reflection"],
	]
	for hand_index: int in range(hands.size()):
		var hand_state: Dictionary = state.duplicate(true)
		(hand_state["deck"] as Dictionary)["hand"] = hands[hand_index]
		var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
		run["mode"] = "combat"
		run["combat_state"] = hand_state
		run["current_room"] = hand_state.get("room_coord")
		run["current_room_layout"] = {"grid": hand_state.get("grid"), "coord": hand_state.get("room_coord"), "type": "combat", "name": "Wave-4 icon proof"}
		scene.set("_run_state", run)
		scene.set("_combat_state", hand_state)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_reset_card_resolution")
		scene.call("_refresh_ui")
		await _capture("0%d_combat_hand_%s" % [hand_index + 2, "maneuver" if hand_index == 0 else "surface_illusion"])
	IllusionSuite._remove_fixtures()
	SurfaceSuite._remove_fixtures()
	ManeuverSuite._remove_fixtures()
	scene.queue_free()
	await process_frame

func _capture(name: String, settle_frames: int = 8) -> void:
	for i: int in range(settle_frames): await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = view.get_texture().get_image()
	expect(screenshot.get_size() == Vector2i(1920, 1080), "%s should capture at 1920x1080" % name)
	expect(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png"))) == OK, "%s should save" % name)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed += 1
		push_error(message)
