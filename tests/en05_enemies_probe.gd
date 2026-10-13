extends SceneTree

const Fixtures = preload("res://tests/suites/en05_enemies_suite.gd")
const BaseFixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const ReflectView = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const DiveView = preload("res://scripts/enemy_mechanics/dive_view.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 8 # Probe-only scheduling, matching existing probes.
const MID_PROGRESS: float = 0.5
const RETURN_PROGRESS: float = 0.85
const OUTPUT_ROOT: String = "res://output/en05-enemies"
var _output: String
var _errors: Array[String]
var _canvas: SubViewport

func _initialize() -> void:
	Runtime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("EN05 ENEMIES PROBE requires a real windowed renderer")
		quit(1)
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	Settings.set_storage_path("user://en05_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_expect(root.content_scale_factor == 1.0, "Probe uses 100% UI scale")
	Store.set_storage_path("user://en05_probe_progression.json")
	Store.set_run_storage_path("user://en05_probe_run.save")
	Store.clear_saved_run()
	_output = "%s/%d" % [OUTPUT_ROOT, Time.get_unix_time_from_system()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(scene)
	await _settle()
	scene._load_run_state(Run.new().create_new_run(BaseFixtures.TEST_SEED, Store.default_data()))
	await _settle()
	await _mirror(scene)
	await _shrike(scene)
	scene.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	print("EN05 ENEMIES PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print("EN05 ENEMIES CAPTURES: %s" % ProjectSettings.globalize_path(_output))
	quit(0 if _errors.is_empty() else 1)

func _mirror(scene: Control) -> void:
	var engine := Combat.new()
	var before: Dictionary = Fixtures.mirror()
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	await _capture("01_mirror_rest_refraction.png")
	var slot: int = scene._combat_state["deck"]["hand"].find("pale_spark")
	_expect(slot >= 0, "Fixture has the actual ranged card in hand")
	await scene._on_card_pressed(slot)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	_expect(scene.board_view.presentation.has("en05_reflect_preview"), "Real card aim exposes reflection number and marker on hero")
	_expect(scene.board_view._damage_preview_map().has("player"), "Real card preview shows hero health loss")
	await _capture("02_reflect_ranged_card_preview.png")
	var action: Dictionary = preload("res://scripts/game_data.gd").card_def("pale_spark")["actions"][0]
	var after: Dictionary = engine.apply_player_action(before, action, before["enemies"][0]["pos"])
	var outbound: float = scene.ATTACK_FRAMES * scene.ATTACK_FRAME_SECONDS * ReflectView.PROJECTILE_TRAVEL_FRACTION
	var effect: Dictionary = ReflectView.reflected_effect(before, action, before["enemies"][0]["pos"], outbound)
	scene._animation_lock = true
	scene._render_board_state(before, {"effect": effect, "effect_progress": RETURN_PROGRESS}, true)
	await _settle()
	_expect(ReflectView.projectile_frame(RETURN_PROGRESS, outbound)["returning"], "Capture samples the actual return phase")
	await _capture("03_reflected_projectile_mid_return.png")
	await _install(scene, after)
	await _capture("04_after_reflection.png")
	var beam: Dictionary = before["enemies"][0]["intent"]["actions"][0]
	after = engine._resolve_enemy_action(before.duplicate(true), 0, beam)
	var step: Dictionary = engine._enemy_action_step(before, after, 0, beam)
	scene._animation_lock = true
	scene._render_board_state(before, {"effect": step, "effect_progress": MID_PROGRESS}, true)
	await _settle()
	await _capture("05_refraction_mid_beam.png")
	await _install(scene, after)
	await _capture("06_after_refraction.png")

func _shrike(scene: Control) -> void:
	var engine := Combat.new()
	var before: Dictionary = Fixtures.shrike()
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	_expect(scene.board_view.presentation["enemy_threat_previews"].any(func(threat: Dictionary) -> bool: return str(threat.get("enemy_key", "")) == "enemy_1" and threat.get("projected_attack", []).size() == 4), "Dive line telegraphs four tiles with two intermediate units")
	_expect(scene.board_view.presentation.get("displacement_paths", []).has(engine._vector2i_values([Vector2i(3, 4), Vector2i(3, 5)])) and scene.board_view.presentation.get("displacement_paths", []).has(engine._vector2i_values([Vector2i(4, 4), Vector2i(4, 5)])), "Aligned rest preview shows both approved right-hand pushes")
	await _capture("07_dive_rest_two_units_on_path.png")
	var action: Dictionary = before["enemies"][0]["intent"]["actions"][0]
	var context: Dictionary = engine.enemy_intent_plan(before, 0)
	var after: Dictionary = engine._resolve_enemy_action(before.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
	var step: Dictionary = engine._enemy_action_step(before, after, 0, action, context)
	scene._animation_lock = true
	scene._render_board_state(before, DiveView.flight_frame(scene.board_view, before, step, MID_PROGRESS), true)
	await _settle()
	await _capture("08_dive_mid_flight.png")
	await _install(scene, after)
	_expect(engine._enemy_distance_to_tile(after["enemies"][0], after["player"]["pos"]) == 1, "Dive ends on tile before hero")
	_expect(after["enemies"][1]["pos"] == Vector2i(3, 5) and after["enemies"][2]["pos"] == Vector2i(4, 5) and after["player"]["pos"] == before["player"]["pos"], "After Dive shows right-hand pushes without moving hero")
	await _capture("09_after_dive.png")
	before = Fixtures.blocked_landing()
	await _install(scene, before)
	scene._on_board_tile_hovered(before["enemies"][0]["pos"])
	await _settle()
	_expect(not scene.board_view.presentation.get("damage_preview", {}).has("player"), "Blocked landing rest preview excludes hero damage")
	_expect(scene.board_view.presentation["enemy_threat_previews"].any(func(threat: Dictionary) -> bool: return threat.get("enemy_key") == "enemy_1" and threat.get("projected_attack_target") == Vector2i(4, 4) and threat.get("projected_attack", []).size() == 2), "Blocked landing rest telegraph ends at stop tile")
	await _capture("10_dive_blocked_landing_rest.png")
	after = engine._resolve_enemy_action(before.duplicate(true), 0, action)
	await _install(scene, after)
	_expect(after["enemies"][0]["pos"] == Vector2i(4, 4) and after["player"]["hp"] == before["player"]["hp"], "Blocked Dive stops at last free tile without hero damage")
	await _capture("11_after_blocked_dive.png")

func _install(scene: Control, state: Dictionary) -> void:
	BaseFixtures.install(scene, state)
	await _settle()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var capture: Image = _canvas.get_texture().get_image()
	_expect(capture.get_size() == VIEWPORT_SIZE, "Capture is native 1920x1080 without rescaling")
	if capture.save_png("%s/%s" % [_output, name]) != OK: _errors.append("Could not save %s" % name)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
