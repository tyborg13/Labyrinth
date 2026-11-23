extends SceneTree
## Captures a production RunScene in either revision. --validate-only checks layout without a renderer.
const CombatFixture = preload("res://tests/suites/en01_enemies_suite.gd")
const BoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const GuardianFixture = preload("res://tools/guardian_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const DeathBurstView = preload("res://scripts/enemy_mechanics/death_burst_view.gd")

const FRAME_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const RUN_SEED: int = 7262026
const READY_FRAMES: int = 600
const SETTLE_FRAMES: int = 5
const CROP_MARGIN: float = 8.0
const CROP_SCALE: int = 2
const DETAILS_POSITION := Vector2(1170, 355)
const RETALIATE_FIXTURE_AMOUNT: int = 3
const FIXTURES := ["ember_tick", "cinder_ooze", "hollow_mimic", "ember_hoarder"]
const TICK_TRAP: Dictionary = {"pos": Vector2i(5, 4), "element": "fire", "damage": 4}

var _scene: Node
var _viewport: SubViewport
var _before: bool
var _headless: bool
var _output: String
var _failures: Array[String]
var _observations: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_before = args.has("--before")
	_headless = DisplayServer.get_name() == "headless"
	_output = "user://pol73"
	for arg: String in args:
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	if _headless != args.has("--validate-only"):
		push_error("Pass --validate-only only for a headless layout dry run.")
		quit(1)
		return
	_output = ProjectSettings.globalize_path(_output)
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Cannot create proof folder " + _output)
		quit(1)
		return
	await TestClock.run_scoped(self, func(_scope: TestClock.GlobalScope) -> void: await _fixtures())
	var manifest := FileAccess.open(_output.path_join("layout.json"), FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify({"size": [FRAME_SIZE.x, FRAME_SIZE.y], "ui_scale": UI_SCALE,
			"before": _before, "headless": _headless, "observations": _observations, "failures": _failures}, "\t"))
	_expect(manifest != null, "layout.json is writable")
	for failure: String in _failures: print("FAIL: " + failure)
	print("POL73 %s %s 1920x1080: %d surfaces, %d failures." % [
		"HEADLESS LAYOUT" if _headless else "NATIVE CAPTURE", "before" if _before else "after", _observations.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _fixtures() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = true
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.set_storage_path("user://pol73-settings.json")
	Store.set_storage_path("user://pol73-profile.json")
	Store.set_run_storage_path("user://pol73-run.save")
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.mode = Window.MODE_WINDOWED
	root.size = FRAME_SIZE
	_viewport = SubViewport.new()
	_viewport.size = FRAME_SIZE
	_viewport.size_2d_override = FRAME_SIZE
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	Settings.inherit_edge_smoothing(_viewport, root)
	var engine := Run.new()
	var base: Dictionary = engine.create_new_run(RUN_SEED, BoonFixture.profile())
	var startup: Dictionary = GuardianFixture.build(engine, Combat.new(), base, {"guardian_id": "gallows_roc", "guardian_case": "encounter"})
	_expect(Store.save_run_state(startup), "Saved the isolated startup encounter")
	root.set_meta("labyrinth_resume_saved_run", true)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	for frame: int in range(READY_FRAMES):
		if _scene.initial_presentation_is_ready(): break
		await process_frame
	if _scene.initial_presentation_is_ready():
		for enemy_type: String in FIXTURES:
			await _hover_enemy(_combat_run(base, enemy_type), enemy_type)
	else:
		_expect(false, "Run scene is ready")
	_scene._character_row_preparation_revision += 1
	_scene._grimoire_row_preparation_revision += 1
	await _settle()
	_viewport.queue_free()
	await _settle()

func _combat_run(base: Dictionary, enemy_type: String) -> Dictionary:
	var battle: Dictionary = CombatFixture.fixture([enemy_type])
	if enemy_type == "ember_tick":
		battle["traps"] = [TICK_TRAP.duplicate()]
	if enemy_type == "hollow_mimic":
		var enemy: Dictionary = battle["enemies"][0]
		# Show existing Retaliate with a separate, upcoming Shade Bolt.
		enemy["intent"] = preload("res://scripts/game_data.gd").enemy_def(enemy_type)["intents"][1].duplicate(true)
		preload("res://scripts/retaliate_rules.gd").gain(enemy, {"amount": RETALIATE_FIXTURE_AMOUNT})
	var run: Dictionary = base.duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = battle
	run["current_room_layout"] = {"grid": battle["grid"]}
	return run

func _hover_enemy(run: Dictionary, enemy_type: String) -> void:
	_scene.call("_load_run_state", run)
	_scene.call("_close_dialogue")
	await _settle()
	var board: Control = _scene.get("board_view")
	var enemy: Dictionary = run["combat_state"]["enemies"][0]
	var actor_key: String = "enemy_%d" % int(enemy["id"])
	var tile: Vector2i = enemy["pos"]
	_expect(board._update_hover_at(board.world_position_for_tile(tile)) == tile, enemy_type + " uses the board hover path")
	await _settle()
	var layout: Dictionary = {}
	var rect: Rect2 = board.enemy_intent_visual_global_rect(actor_key)
	for entry: Dictionary in board.get("_hud_layout_entries_cache"):
		if entry.get("actor_key") == actor_key: layout = entry["layout"]; break
	var rows: Array = layout.get("rows", [])
	var names := PackedStringArray()
	for row: Array in rows:
		for token: Dictionary in row:
			names.append("%s %s" % [token.get("icon", ""), token.get("value", "")])
	var title: String = str(layout.get("intent_name", ""))
	_expect(title == enemy["intent"]["name"] and not rows.is_empty(), enemy_type + " shows its upcoming move and numbers")
	var has_death_burst: bool = rows.any(func(row: Array) -> bool: return row.any(func(token: Dictionary) -> bool: return bool(token.get("burst_trait", false))))
	var has_split: bool = names.has("splits Splits 2")
	_expect(has_death_burst == (_before and enemy_type in ["ember_tick", "ember_hoarder"]), enemy_type + " has the expected death Burst visibility")
	_expect(has_split == (_before and enemy_type == "cinder_ooze"), enemy_type + " has the expected split visibility")
	var padded: Rect2 = rect.grow(CROP_MARGIN)
	var origin := Vector2i(padded.position.floor())
	var crop := Rect2i(origin, Vector2i(padded.end.ceil()) - origin).intersection(Rect2i(Vector2i.ZERO, FRAME_SIZE))
	_expect(rect.has_area() and crop.has_area(), enemy_type + " intent has on-screen bounds")
	_observations[enemy_type] = {"intent": title, "tokens": Array(names), "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y]}
	await _capture(enemy_type, crop)
	if not _before and enemy_type == "ember_tick":
		await _tick_details(board, actor_key)
	if enemy_type == "hollow_mimic":
		_expect(not names.has("retaliate %d" % RETALIATE_FIXTURE_AMOUNT), "Already-active Retaliate is absent from Shade Bolt")
		_expect(not _status_tooltip(board, actor_key, "retaliate").is_empty(), "The live Retaliate status still has a tooltip")

func _status_tooltip(board: Control, actor_key: String, icon: String) -> String:
	var visibility = board.get("plate_visibility")
	for unit: Dictionary in visibility.actors():
		if unit.get("key") != actor_key: continue
		for entry: Dictionary in visibility.status_entries(unit):
			if entry.get("icon") == icon:
				return board._get_tooltip((entry["rect"] as Rect2).get_center())
	return ""

func _tick_details(board: Control, actor_key: String) -> void:
	var text: String = _status_tooltip(board, actor_key, "burst")
	var sentence: String = DeathBurstView.rules_sentence(DeathBurstView.Rules.damage(_scene.get("_combat_state")["enemies"][0]))
	_expect(text.contains(sentence), "Tick's existing trait chip opens the Burst details")
	if not text.contains(sentence): return
	var panel: Control = board._make_custom_tooltip(text)
	_viewport.add_child(panel)
	panel.position = DETAILS_POSITION
	await _settle()
	_expect(panel.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(FRAME_SIZE)).encloses(panel.get_global_rect()), "Tick's details panel fits in the frame")
	_observations["ember_tick_details"] = {"tooltip": text}
	await _capture("ember_tick_details")
	panel.free()

func _capture(id: String, crop: Rect2i = Rect2i()) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_expect(frame.get_size() == FRAME_SIZE, id + " captures the exact SubViewport size")
	_save(frame, id + "_frame")
	if crop.has_area():
		var intent: Image = frame.get_region(crop)
		intent.resize(crop.size.x * CROP_SCALE, crop.size.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
		_save(intent, id + "_intent_2x")

func _save(image: Image, name: String) -> void:
	var path: String = _output.path_join(name + ".png")
	var result: Error = image.save_png(path)
	_expect(result == OK, "Saved " + path)
	if result == OK: print(path)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: _failures.append(message)
