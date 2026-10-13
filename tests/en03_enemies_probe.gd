extends SceneTree

const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 8 # Probe-only scheduling.
const MID_PROGRESS: float = 0.5 # Proof-only sample, not animation tuning.
const OUTPUT_ROOT: String = "res://output/en03-enemies"
var _output: String
var _errors: Array[String]
var _canvas: SubViewport

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("EN03 ENEMIES PROBE requires a real windowed renderer")
		quit(1)
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	Settings.set_storage_path("user://en03_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_expect(root.content_scale_factor == 1.0 and float(Settings.load_settings()["ui_scale"]) == 1.0, "Probe uses 100% UI scale")
	Store.set_storage_path("user://en03_probe_progression.json")
	Store.set_run_storage_path("user://en03_probe_run.save")
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
	_expect(scene.get_viewport_rect().size == Vector2(VIEWPORT_SIZE), "RunScene renders into the native 1920x1080 canvas")
	scene._load_run_state(Run.new().create_new_run(Fixtures.TEST_SEED, Store.default_data()))
	await _settle()
	await _thrall_captures(scene)
	await _stalker_captures(scene)
	for error: String in _errors: push_error(error)
	print(ProjectSettings.globalize_path(_output))
	print("EN03 ENEMIES PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	scene.queue_free()
	quit(0 if _errors.is_empty() else 1)

func _thrall_captures(scene: Control) -> void:
	var combat := Combat.new()
	var before: Dictionary = Fixtures.thralls()
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	var threat: Dictionary = combat.enemy_threat_tiles(before, 0)
	_expect(threat["projected_attack"].has(before["enemies"][2]["pos"]), "Enemy stands in the beam telegraph")
	_expect(scene.board_view._damage_preview_map().get("enemy_3", {}).get("hp", -1) == int(before["enemies"][2]["hp"]) - 4, "Enemy in beam has a damage preview")
	await _capture("01_thralls_rest_beam_friendly_fire.png")
	var context: Dictionary = combat.enemy_intent_plan(before, 0)
	var after: Dictionary = combat._resolve_enemy_action(before.duplicate(true), 0, Fixtures.action(before), null, {}, [], context)
	var step: Dictionary = combat._enemy_action_step(before, after, 0, Fixtures.action(before), context)
	_expect(step["tiles"] == threat["projected_attack"], "Beam resolved tiles equal captured telegraph")
	scene._animation_lock = true
	scene._render_board_state(before, {"effect": step, "effect_progress": MID_PROGRESS}, true)
	await _settle()
	await _capture("02_thralls_beam_mid_resolution.png")
	await _install(scene, after)
	_expect(after["player"]["shock"] == 1 and after["enemies"][2]["shock"] == 1, "After beam: hero and enemy have Shock")
	await _capture("03_thralls_after_resolution.png")
	var align: Dictionary = Fixtures.state([Fixtures.enemy("arc_thrall", 1, Vector2i(2, 2), "tether"), Fixtures.enemy("arc_thrall", 2, Vector2i(6, 4), "arc_jab")])
	await _install(scene, align)
	scene._on_board_tile_hovered(align["enemies"][0]["pos"])
	await _settle()
	var plan: Dictionary = combat.enemy_intent_plan(align, 0)
	_expect(plan["path"].size() > 1 and plan["projected_attack"].has(align["player"]["pos"]), "Align preview shows the approach and resulting hero beam")
	await _capture("04_thrall_align_move_preview.png")

func _stalker_captures(scene: Control) -> void:
	var combat := Combat.new()
	var before: Dictionary = Fixtures.state([Fixtures.enemy("gloam_stalker", 1, Vector2i(6, 4), "fade")])
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	await _capture("05_stalker_before_fade.png")
	var context: Dictionary = combat.enemy_intent_plan(before, 0)
	var veiled: Dictionary = combat._resolve_enemy_action(before.duplicate(true), 0, Fixtures.action(before), null, {}, [], context)
	var blink: Dictionary = {"kind": "blink", "from": context["blink_from"], "to": context["blink_to"], "actor_key": "enemy_1"}
	scene._animation_lock = true
	scene._render_board_state(before, {"effect": blink, "effect_progress": MID_PROGRESS}, true)
	await _settle()
	await _capture("06_stalker_fade_mid_blink.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = Fixtures.TEST_SEED
	combat._assign_enemy_intent(veiled, 0, rng)
	await _install(scene, veiled)
	scene._on_board_tile_hovered(veiled["enemies"][0]["pos"])
	await _settle()
	_expect(veiled["enemies"][0]["veiled"] and veiled["enemies"][0]["pos"] == Vector2i(3, 4), "Veiled stalker rests behind the hero")
	_expect(veiled["enemies"][0]["intent"]["id"] == "ambush", "Veiled rest shows the forced Ambush intent")
	_expect(scene.board_view.enemy_intent_visual_global_rect("enemy_1").has_area(), "Veiled intent remains visible")
	await _capture("07_stalker_veiled_behind_hero_rest.png")
	context = combat.enemy_intent_plan(veiled, 0)
	var after: Dictionary = combat._resolve_enemy_action(veiled.duplicate(true), 0, Fixtures.action(veiled), null, {}, [], context)
	var wrapper: Dictionary = combat._enemy_action_step(veiled, after, 0, Fixtures.action(veiled), context)
	var strike: Dictionary = wrapper["strike_step"]
	scene._animation_lock = true
	scene._render_board_state(veiled, {"effect": strike, "effect_progress": MID_PROGRESS}, true)
	await _settle()
	await _capture("08_stalker_ambush_mid_strike.png")
	await _install(scene, after)
	_expect(not after["enemies"][0]["veiled"] and after["player"]["hp"] == Fixtures.TEST_HERO_HP - 7, "After Ambush: seven damage and Veil ended")
	await _capture("09_stalker_after_ambush.png")

func _install(scene: Control, value: Dictionary) -> void:
	Fixtures.install(scene, value)
	await _settle()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var capture: Image = _canvas.get_texture().get_image()
	_expect(capture.get_size() == VIEWPORT_SIZE, "Capture is native 1920x1080, without rescaling")
	if capture.save_png("%s/%s" % [_output, name]) != OK: _errors.append("Could not save %s" % name)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
