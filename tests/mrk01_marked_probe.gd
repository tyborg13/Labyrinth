extends SceneTree

# Windowed proof at the required native size. --check-only constructs the exact
# same combat states and copy witnesses without touching the window server.
const Fixture = preload("res://tests/helpers/marked_fixture.gd")
const Contract = preload("res://tests/suites/mrk01_marked_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT_DIR: String = "user://mrk01_marked_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const CAPTURE_SEED: int = 20261012
# Debug-only tooltip position; production panel, copy and typography are reused.
const PROOF_TOOLTIP_POSITION := Vector2(48, 160)
const EXPECTED_COMBAT_CASES: int = 9
const PROOF_SHUTDOWN_DRAIN_SECONDS: float = 0.5
var _engine := Combat.new()
var _failed: bool = false
var _check_only: bool = false
var _canvas: SubViewport
var _capture_dir: String = OUTPUT_DIR
var _witnesses: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if OS.get_cmdline_user_args().has("--check-only"):
		_check_only = true
		var cases: Array[Dictionary] = _cases()
		if cases.size() != EXPECTED_COMBAT_CASES: _failed = true
		for key: String in Contract.MOVE_COPY:
			if preload("res://scripts/action_icon_library.gd").description(key) != Contract.MOVE_COPY[key]: _failed = true
		if Grimoire.entry_def("keyword:marked").is_empty(): _failed = true
	_capture_dir = OUTPUT_DIR.path_join(str(int(Time.get_unix_time_from_system())))
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Store.set_storage_path("user://mrk01-probe-profile.json")
	Store.set_run_storage_path("user://mrk01-probe-run.save")
	var profile: Dictionary = Store.default_data()
	profile["ui_scale"] = 1.0
	Store.save_data(profile)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	_capture.call_deferred()

func _cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for type: String in Contract.MARK_IDS:
		var state: Dictionary = Fixture.fixture(_engine, type, CAPTURE_SEED)
		state["enemies"][0]["intent"] = Fixture.intent(type, Contract.MARK_IDS[type])
		result.append({"name": type + "_01_aim", "state": state.duplicate(true)})
		state = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		result.append({"name": type + "_02_marked", "state": state.duplicate(true)})
		state = _engine.resolve_enemy_turn_with_steps(state, 0)["state"]
		result.append({"name": type + "_03_after", "state": state.duplicate(true)})
	return result

func _capture() -> void:
	await process_frame
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var scene: Control = RUN_SCENE.instantiate()
	_canvas.add_child(scene)
	await process_frame
	await process_frame
	for case: Dictionary in _cases():
		var combat: Dictionary = case["state"]
		var run: Dictionary = Run.new().create_new_run(CAPTURE_SEED, Store.default_data())
		var coord := Vector2i(1, 0)
		var layout: Dictionary = {"name": "Mrk01 Proof", "coord": coord, "depth": 2, "type": "combat", "element": "none", "grid": combat["grid"], "player_start": combat["player"]["pos"], "enemies": combat["enemies"], "terrain": combat.get("terrain", []), "traps": combat.get("traps", []), "loot": []}
		run["rooms"]["1,0"] = {"coord": coord, "depth": 2, "type": "combat", "element": "none", "revealed": true, "visited": true, "connections": [], "npcs": []}
		run.merge({"mode": "combat", "current_room": coord, "current_room_layout": layout, "combat_state": combat, "notice": ""}, true)
		run[Grimoire.UNLOCKED_KEY] = Grimoire.ordered_entry_ids(["keyword:marked"])
		scene._load_run_state(run)
		scene._close_dialogue()
		scene._render_board_state(combat, {})
		await process_frame
		await process_frame
		if not is_equal_approx(Typography.ui_scale(scene), 1.0): _failed = true
		var tip: String = scene.board_view.enemy_intent_tooltip("enemy_1")
		_witnesses.append({"case": case["name"], "tooltip": tip, "ui_scale": Typography.ui_scale(scene), "intent": combat["enemies"][0]["intent"]["id"]})
		var panel: Control = scene.board_view._make_custom_tooltip(tip)
		if panel != null:
			scene.add_child(panel)
			panel.position = PROOF_TOOLTIP_POSITION
		await _save_image(case["name"])
		if panel != null:
			panel.queue_free()
			await process_frame
	scene._open_grimoire_overlay()
	scene._on_grimoire_entry_pressed("keyword:marked")
	await process_frame
	await process_frame
	var title: Label = scene.get("_grimoire_detail_title")
	var body: RichTextLabel = scene.get("_grimoire_detail_body")
	if title.text != "Marked" or body.text != Contract.MARKED_DEFINITION or body.get_content_height() > body.size.y + 1.0: _failed = true
	_witnesses.append({"case": "marked_grimoire", "title": title.text, "body": body.text, "body_height": body.get_content_height(), "available_height": body.size.y})
	await _save_image("marked_grimoire")
	var witness_file := FileAccess.open(_capture_dir.path_join("witnesses.json"), FileAccess.WRITE)
	witness_file.store_string(JSON.stringify(_witnesses, "\t") + "\n")
	witness_file.close()
	print("MRK01 WITNESSES: " + ProjectSettings.globalize_path(_capture_dir.path_join("witnesses.json")))
	scene._close_grimoire_overlay()
	# Let the production turn-order refresh finish before destroying its owner.
	await create_timer(PROOF_SHUTDOWN_DRAIN_SECONDS).timeout
	await process_frame
	_canvas.queue_free()
	await process_frame
	if _check_only: print("MRK01 MARKED PROBE CONTRACT: %s (9 combat states, Marked grimoire, 1920x1080, UI scale 100%%; no PNGs)" % ["FAIL" if _failed else "PASS"])
	else: print("MRK01 MARKED PROBE: %s" % ["FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _save_image(name: String) -> void:
	if _check_only:
		await process_frame
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = _canvas.get_texture().get_image()
	var path: String = _capture_dir.path_join(name + ".png")
	if captured.get_size() != VIEWPORT_SIZE or captured.save_png(path) != OK:
		_failed = true
		push_error("MRK01 capture failed: " + path)
	else: print("MRK01 CAPTURE: " + ProjectSettings.globalize_path(path))
