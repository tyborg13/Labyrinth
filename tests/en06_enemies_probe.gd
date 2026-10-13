extends SceneTree

const Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
const Install = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 8
const MID_PROGRESS: float = 0.5
const MID_HOP_INDEX: int = 1
const OUTPUT_ROOT: String = "res://output/en06-enemies"
var _output: String
var _errors: Array[String]
var _canvas: SubViewport

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("EN06 ENEMIES PROBE requires a real windowed renderer")
		quit(1)
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	Settings.set_storage_path("user://en06_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_expect(root.content_scale_factor == 1.0, "Probe uses 100% UI scale")
	Store.set_storage_path("user://en06_probe_progression.json")
	Store.set_run_storage_path("user://en06_probe_run.save")
	Store.clear_saved_run()
	_output = "%s/%d" % [OUTPUT_ROOT, Time.get_unix_time_from_system()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_canvas.add_child(scene)
	await _settle()
	scene._load_run_state(Run.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	await _settle()
	await _capacitor_captures(scene)
	await _mimic_captures(scene)
	for error: String in _errors: push_error(error)
	print(ProjectSettings.globalize_path(_output))
	print("EN06 ENEMIES PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	scene.queue_free()
	quit(0 if _errors.is_empty() else 1)

func _capacitor_captures(scene: Control) -> void:
	var before: Dictionary = Fixtures.capacitor(2)
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	_expect(scene.board_view._unit_status_badges(before["enemies"][0])[0]["count"] == 2, "Capacitor begins at two visible pips")
	_expect_badge_number(scene, "+1")
	await _capture("01_capacitor_two_pips.png")
	before = Fixtures.capacitor(3)
	# The requested at-rest path includes two enemies and the hero.
	before["enemies"][3]["hp"] = 0
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	var combat := Combat.new()
	var threat: Dictionary = combat.enemy_threat_tiles(before, 0)
	_expect(threat["chain_hits"].size() == 3 and threat["chain_hits"][1]["target_key"] == "player", "At three pips the path includes two enemies and the hero")
	_expect(scene.board_view._damage_preview_map().get("player", {}).get("hp", -1) == Fixtures.TEST_HERO_HP - 5, "Discharge preview reports the predicted hero hit")
	_expect_badge_number(scene, "6")
	await _capture("02_capacitor_discharge_telegraph.png")
	var result: Dictionary = Fixtures.resolve_action(before)
	var hits: Array = result["step"]["chain_hits"]
	var hit: Dictionary = hits[MID_HOP_INDEX]
	var mid: Dictionary = hits[MID_HOP_INDEX - 1]["state"]
	scene._animation_lock = true
	scene._render_board_state(mid, {"effect": {"kind": "chain", "from": hit["from"], "to": hit["to"], "element": "lightning"}, "effect_progress": MID_PROGRESS}, true)
	await _settle()
	await _capture("03_capacitor_mid_chain.png")
	var after: Dictionary = combat.resolve_enemy_turn_with_steps(before, 0)["state"]
	await _install(scene, after)
	_expect(after["enemies"][0]["charge"] == 0 and after["player"]["hp"] == Fixtures.TEST_HERO_HP - 5, "After Discharge: Charge reset and five hero damage")
	await _capture("04_capacitor_after_discharge.png")

func _mimic_captures(scene: Control) -> void:
	var before: Dictionary = Fixtures.mirror_after_play()
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	_expect(before["last_hero_attack_card"] == "whirlwind_slash" and before["enemies"][0]["intent"]["name"] == "Mirror: Whirlwind Slash", "Mimic reveals the real area card just played by the hero")
	_expect(scene.board_view.enemy_intent_tooltip("enemy_1").contains("Whirlwind Slash: 8 damage."), "Mirror tooltip preserves the copied name and base damage")
	_expect_badge_number(scene, "8")
	await _capture("05_mimic_area_copy_intent.png")
	var result: Dictionary = Fixtures.resolve_action(before)
	var step: Dictionary = result["step"]
	var moved: Dictionary = before.duplicate(true)
	if step.has("move_after"): moved.merge(step["move_after"], true)
	scene._animation_lock = true
	scene._render_board_state(moved, {"effect": step, "effect_progress": MID_PROGRESS}, true)
	await _settle()
	await _capture("06_mimic_mid_area_copy.png")
	await _install(scene, result["state"])
	_expect(result["state"]["player"]["hp"] == Fixtures.TEST_HERO_HP - 8, "Resolved copy deals base eight damage")
	await _capture("07_mimic_after_copy.png")

func _expect_badge_number(scene: Control, expected: String) -> void:
	for badge: Dictionary in scene.board_view.presentation.get("threats_at_rest", {}).get("badges", []):
		if badge["key"] == "enemy_1":
			_expect(badge["number"] == expected, "Live intent pill displays exact integer %s" % expected)
			return
	_expect(false, "Live intent pill for enemy_1 is missing")

func _install(scene: Control, value: Dictionary) -> void:
	Install.install(scene, value)
	await _settle()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var capture: Image = _canvas.get_texture().get_image()
	_expect(capture.get_size() == VIEWPORT_SIZE, "SubViewport capture is native 1920x1080 without resizing")
	if capture.save_png("%s/%s" % [_output, name]) != OK: _errors.append("Could not save %s" % name)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
