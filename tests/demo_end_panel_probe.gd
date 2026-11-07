extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const Recap = preload("res://scripts/run_end_recap_overlay.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const MENU_SCENE = preload("res://scenes/main_menu.tscn")
const OUTPUT_DIR: String = "user://demo_end_panel_probe/1920x1080"
const PROOF_RESOLUTION: Vector2i = Vector2i(1920, 1080)
const PROFILE_PATH: String = "user://dmo03_probe_profile.json"
const RUN_PATH: String = "user://dmo03_probe_run.save"
const SETTINGS_PATH: String = "user://dmo03_probe_settings.json"
const TEST_FEEDBACK_URL: String = "https://example.invalid/dmo-03-feedback"
const MENU_RUN_TEST_SEED: int = 90211
const SKILLS_TEST_SEED: int = 90212

var _validate_only: bool = false
var _original_config: Dictionary
var _clear_model: Dictionary
var _captures: int = 0
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	OS.set_environment("LABYRINTH_DEMO", "1")
	root.content_scale_size = PROOF_RESOLUTION
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = PROOF_RESOLUTION
	if not _validate_only:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(PROOF_RESOLUTION)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path(PROFILE_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	SettingsStore.save_settings(SettingsStore.default_settings())
	ProgressionStore.clear_saved_run()
	_original_config = DemoRules.config()
	call_deferred("_run")

func _run() -> void:
	_require(DemoBuild.is_demo(), "The dmo-01 editor hook must enable demo mode")
	_require(_validate_only or DisplayServer.get_name() != "headless", "Captures require a real renderer; use --validate-only for headless checks")
	# Review stills hide the in-game cursor glyph, which otherwise lands wherever the real pointer sits.
	var cursor: Node = root.get_node_or_null("CursorFeedback")
	if cursor != null: cursor.call("set_glyph_visibility_suppressed", "demo_end_panel_probe", true)
	_feedback(true)
	await _demo_clear(false)
	await _demo_clear(true)
	_feedback(false)
	await _demo_clear(false, true)
	_feedback(true)
	await _links_row("defeat", "05_links_defeat.png")
	await _links_row("embrace", "06_links_withdrawal.png")
	await _main_menu()
	await _settings_in_run()
	await _keystone()
	OS.set_environment("LABYRINTH_DEMO", "0")
	await _full_recap()
	DemoRules._config = _original_config
	for failure: String in _failures: printerr("FAIL: " + failure)
	print("DEMO_END_PANEL_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("DEMO END PANEL PROBE %s: %s (%d states)" % ["VALIDATION" if _validate_only else "CAPTURE", "PASS" if _failures.is_empty() else "FAIL", _captures])
	quit(0 if _failures.is_empty() else 1)

func _feedback(enabled: bool) -> void:
	# In-memory fixture only: the protected owner-authored file stays untouched.
	DemoRules._config = _original_config.duplicate(true)
	DemoRules._config["feedback_url"] = TEST_FEEDBACK_URL if enabled else ""

func _demo_clear(overflow: bool, no_feedback: bool = false) -> void:
	var instance: Node = await _fresh_run_scene()
	var progression: Dictionary = ProgressionStore.default_data()
	var stats: Dictionary = {
		"rooms_explored": 9, "enemies_slain": 21, "enemies_killed": 21, "guardians_slain": 1,
		"dragons_slain": ["vyraketh"], "max_kills_one_card": 3, "run_seconds": 2460,
	}
	if overflow:
		stats.merge({"guardians_unscathed": ["rimejaw"], "dragons_flawless": ["vyraketh"], "max_single_hit": 20})
	var state: Dictionary = _section_one_state(RunEngine.new(), progression, "victory", 236, 9, stats)
	await _install(instance, progression, state)
	var recap: Control = instance.get("_run_end_recap") as Control
	recap.call("skip_presentation")
	await _settle()
	var model: Dictionary = recap.call("recap_model")
	var scored: Dictionary = model["score"]
	_require((scored["lines"] as Array).size() + (scored["feats"] as Array).size() == (8 if overflow else 5), "Clear fixture must have the requested row count")
	_require(model.get("demo_end_panel_kind") == "full", "Clear must integrate DemoRules through the real recap")
	var panel: Control = recap.get("_demo_panel") as Control
	_require(panel != null, "Demo clear panel exists")
	if panel == null:
		await _free(instance)
		return
	var plate: Button = panel.get("wishlist_plate") as Button
	plate.grab_focus()
	_require(plate.global_position.distance_to(Vector2(1010, 952)) <= 2, "Wishlist plate matches approved origin within 2px")
	_require((panel.get_node_or_null("DemoFeedbackLink") == null) == no_feedback, "Feedback visibility follows the fixture URL")
	if overflow:
		_require(bool((recap.get("_feat_rows") as Control).visible), "Eight rows use split ledger")
		await _capture("03_demo_clear_eight_rows.png")
	elif no_feedback:
		await _capture("04_demo_clear_no_feedback.png")
	else:
		_clear_model = model.duplicate(true)
		await _capture("01_demo_clear.png")
		var discord: Button = panel.get_node("DemoDiscordLink") as Button
		discord.grab_focus()
		_require(bool(discord.get_meta("umbra_selected")) and not bool(plate.get_meta("umbra_selected")), "Discord focus owns recap selection")
		await _capture("02_demo_clear_discord_focus.png")
	await _free(instance)

func _links_row(outcome: String, filename: String) -> void:
	var instance: Node = await _fresh_run_scene()
	var progression: Dictionary = ProgressionStore.default_data()
	var state: Dictionary = _section_one_state(RunEngine.new(), progression, "defeat" if outcome == "defeat" else "victory", 180, 9, {
		"rooms_explored": 9, "enemies_slain": 18, "enemies_killed": 18, "run_seconds": 2100,
		"killer": {"enemy_type": "vyraketh", "intent_id": "", "damage": 9} if outcome == "defeat" else {},
	})
	state["mode"] = outcome
	state["victory"] = false
	state["game_over"] = outcome == "defeat"
	state.erase("run_result")
	_mark_hearth(state)
	await _install(instance, progression, state)
	var recap: Control = instance.get("_run_end_recap") as Control
	if outcome == "defeat": instance.call("_seek_run_end_board_reframe", 1.0)
	recap.call("skip_presentation")
	await _settle()
	_require((recap.call("recap_model") as Dictionary).get("demo_end_panel_kind") == "links", "Post-Hearth %s shows one-time links" % outcome)
	await _capture(filename)
	await _free(instance)

func _main_menu() -> void:
	ProgressionStore.save_data(ProgressionStore.default_data())
	var menu: Control = MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	await _settle()
	var first: Button = menu.get_node("DemoWishlistLink") as Button
	var quit_button: Control = menu.get_node("MenuColumn/QuitButton") as Control
	var expected := Vector2(menu.get_node("MenuColumn").global_position.x + 26, quit_button.get_global_rect().end.y + 12)
	_require(first.global_position.distance_to(expected) <= 2, "Menu Wishlist matches approved placement within 2px")
	await _capture("07_main_menu.png")
	first.grab_focus()
	await _capture("08_main_menu_wishlist_focus.png")
	menu.call("_on_settings_button_pressed")
	await _settle()
	_require(not first.visible, "Menu links hide under Settings")
	await _capture("09_settings_main_menu.png")
	await _free(menu)

func _settings_in_run() -> void:
	var instance: Node = await _fresh_run_scene()
	instance.call("_load_run_state", RunEngine.new().create_new_run(MENU_RUN_TEST_SEED, ProgressionStore.default_data()))
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_open_menu_overlay")
	instance.call("_open_settings_overlay")
	await _settle()
	var panel: Control = instance.get("_settings_panel") as Control
	var discord: Control = panel.find_child("DemoDiscordLink", true, false) as Control
	_require(absf(discord.get_global_rect().end.x - (panel.get_global_rect().end.x - 30)) <= 2, "Run Settings links match approved right inset within 2px")
	await _capture("10_settings_in_run.png")
	await _free(instance)

func _keystone() -> void:
	var instance: Node = await _fresh_run_scene()
	var progression: Dictionary = ProgressionStore.default_data()
	progression["level"] = 3
	progression["skill_ids"] = ["quick_wits", "measured_breath"]
	ProgressionStore.save_data(progression)
	instance.set("_progression", progression)
	instance.call("_load_run_state", RunEngine.new().create_new_run(SKILLS_TEST_SEED, progression))
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_open_character_overlay", "skills")
	await _settle()
	var tree: Control = instance.get("_skill_tree_view") as Control
	tree.call("focus_skill", "encore")
	await _settle()
	for skill_id: String in ["encore", "open_arsenal", "confluence", "last_door", "open_sky"]:
		var node: Control = tree.call("node_for_skill", skill_id) as Control
		var tag: Label = node.get_node("DemoKeystoneCaption") as Label
		_require(absf(tag.position.y - node.size.y - 6) <= 2, "Keystone teaser matches approved 6px gap")
	await _capture("11_skills_keystone.png")
	await _free(instance)

func _full_recap() -> void:
	var instance: Node = await _fresh_run_scene()
	var state: Dictionary = _section_one_state(RunEngine.new(), ProgressionStore.default_data(), "victory", 236, 9, {"rooms_explored": 9})
	await _install(instance, ProgressionStore.default_data(), state)
	var recap: Control = instance.get("_run_end_recap") as Control
	recap.call("present", _clear_model)
	recap.call("skip_presentation")
	await _settle()
	_require(recap.get("_demo_panel") == null, "The same recap creates no demo controls in a full build")
	await _capture("12_full_build_recap.png")
	await _free(instance)

func _mark_hearth(state: Dictionary) -> void:
	for room: Dictionary in (state["rooms"] as Dictionary).values():
		if str(room.get("type", "")) == "campfire" and int(room.get("section_index", 0)) == 0:
			room["visited"] = true
			return
	_require(false, "The first section fixture must contain its Ember Hearth")

func _fresh_run_scene() -> Node:
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await _settle()
	return instance

func _free(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame

func _settle() -> void:
	for i: int in range(6):
		await process_frame

func _install(instance: Node, progression: Dictionary, state: Dictionary) -> void:
	ProgressionStore.save_data(progression)
	instance.set("_progression", progression.duplicate(true))
	instance.call("_load_run_state", state)
	await process_frame
	await process_frame

func _section_one_state(engine: RunEngine, progression: Dictionary, outcome: String, held_embers: int, cleared_rooms: int, run_stats: Dictionary) -> Dictionary:
	var coord := Vector2i(8, 0)
	var state: Dictionary = engine.create_new_run(8841 + held_embers * 3 + coord.x, progression)
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	var marked: int = 0
	for room_key_var: Variant in rooms.keys():
		if marked >= cleared_rooms:
			break
		var candidate: Dictionary = (rooms[room_key_var] as Dictionary).duplicate(true)
		if int(candidate.get("depth", 0)) <= 0 or str(room_key_var) == "%d,%d" % [coord.x, coord.y]:
			continue
		candidate["visited"] = true
		candidate["cleared"] = true
		rooms[room_key_var] = candidate
		marked += 1
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["section_index"] = 0
	room["map_step"] = 10
	room["type"] = "boss"
	room["boss_id"] = "vyraketh"
	state["map_sections"][0]["boss_id"] = "vyraketh"
	state["map_sections"][0]["room_count"] = 10
	rooms["%d,%d" % [coord.x, coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), state)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(int(state.get("seed", 0)), layout, engine.call("_player_snapshot", state) as Dictionary)
	combat_state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	if outcome == "defeat":
		var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
		player["hp"] = 0
		combat_state["player"] = player
	else:
		var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
		for index: int in range(enemies.size()):
			var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
			enemy["hp"] = 0
			enemies[index] = enemy
		combat_state["enemies"] = enemies
	state["mode"] = "combat"
	state["combat_state"] = combat_state
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["_probe_terminal_combat_state"] = combat_state.duplicate(true)
	state = engine.finish_combat(state, combat_state)
	state["mode"] = outcome
	state["victory"] = outcome == "victory"
	state = preload("res://scripts/opening_boon_rules.gd").leave_heirloom(state, "")
	state["game_over"] = outcome == "defeat"
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	state["progression"] = progression.duplicate(true)
	return state

func _capture(filename: String) -> void:
	await _settle()
	_captures += 1
	if _validate_only: return
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	_require(image.get_size() == PROOF_RESOLUTION, "Capture must be native 1920x1080")
	if image.get_size() != PROOF_RESOLUTION: return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	_require(image.save_png(path) == OK, "Capture saves successfully: " + filename)
	print("Saved " + ProjectSettings.globalize_path(path))

func _require(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
