extends SceneTree

# Windowed real-renderer proof only. --check-only parses/builds all proof states
# headlessly without attempting a capture or accessing the window server.
const Suite = preload("res://tests/suites/en02_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall.gd")
const IcefallView = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT_DIR: String = "user://en02_enemies_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const PROOF_SEED: int = 20261012
const MID_FALL_ELAPSED_SECONDS: float = 0.09
const MID_WIND_PROGRESS: float = 0.5
var _engine: RefCounted = Combat.new()
var _failed: bool = false
var _canvas: SubViewport

func _initialize() -> void:
	Parallel.apply_from_environment()
	if OS.get_cmdline_user_args().has("--check-only"):
		var cases: Array[Dictionary] = _cases()
		if cases.size() != 8: _failed = true
		print("EN02 ENEMIES PROBE CONTRACT: %s (%d states, 1920x1080, UI scale 100%%)" % ["FAIL" if _failed else "PASS", cases.size()])
		quit(1 if _failed else 0)
		return
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Store.set_storage_path("user://en02_probe_profile.json")
	Store.set_run_storage_path("user://en02_probe_run.save")
	var profile: Dictionary = Store.default_data()
	profile["ui_scale"] = 1.0
	Store.save_data(profile)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_capture_cases")

func _cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	var ice: Dictionary = Suite.fixture(_engine)
	ice["enemies"][0]["intent"] = Suite.intent("hoarfrost_seer", "icefall")
	ice = _engine.resolve_enemy_turn_with_steps(ice, 0)["state"]
	result.append({"name": "01_icefall_marks", "state": ice.duplicate(true), "presentation": {}})
	ice["player"]["pos"] = Vector2i(3, 6)
	var action: Dictionary = Suite.intent("hoarfrost_seer", "icefall_land")["actions"][0]
	var after_ice: Dictionary = _engine._resolve_enemy_action(ice.duplicate(true), 0, action)
	var ice_step: Dictionary = Icefall.animation_step(_engine, ice, after_ice, 0, action)
	ice_step["icefall_puff_seconds"] = IcefallView.PUFF_SECONDS
	result.append({"name": "02_icicles_mid_fall", "state": ice.duplicate(true), "presentation": {"effect": ice_step, "effect_progress": MID_FALL_ELAPSED_SECONDS / (IcefallView.FALL_SECONDS + float(ice_step["icefall_puff_seconds"]))}})
	result.append({"name": "03_ice_pillars", "state": after_ice, "presentation": {}})
	var gale: Dictionary = Suite.fixture(_engine, "gale_herald")
	# A damaging surface beside the hero binds the proof to the brief's scenario.
	Surfaces.place(gale, Vector2i(6, 5), "fire")
	gale["enemies"][0]["intent"] = Suite.intent("gale_herald", "call_the_wind")
	result.append({"name": "04_call_wind_dashed_preview", "state": gale.duplicate(true), "presentation": {"en02_wind_time_seconds": 0.0}})
	gale = _engine._resolve_enemy_action(gale, 0, Suite.intent("gale_herald", "call_the_wind")["actions"][0])
	result.append({"name": "05_wind_at_rest_hud", "state": gale.duplicate(true), "presentation": {"en02_wind_time_seconds": 0.0}})
	var steps: Array[Dictionary]
	var after_gale: Dictionary = Wind.end_turn(_engine, gale.duplicate(true), steps)
	result.append({"name": "06_wind_mid_push", "state": gale.duplicate(true), "wind_after": after_gale, "presentation": {"effect": steps[0], "effect_progress": MID_WIND_PROGRESS, "en02_wind_time_seconds": 0.0}})
	result.append({"name": "07_wind_after_push_hud", "state": after_gale, "presentation": {"en02_wind_time_seconds": 0.0}})
	result.append({"name": "08_wind_reduced_motion", "state": gale.duplicate(true), "presentation": {"reduced_motion": true, "en02_wind_time_seconds": 0.0}})
	return result

func _capture_cases() -> void:
	await process_frame
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var scene: Control = RUN_SCENE.instantiate()
	_canvas.add_child(scene)
	await process_frame
	await process_frame
	scene._close_dialogue()
	for case: Dictionary in _cases():
		var combat: Dictionary = case["state"]
		var run: Dictionary = Run.new().create_new_run(PROOF_SEED, Store.default_data())
		var coord := Vector2i(1, 0)
		var layout: Dictionary = {"name": "En02 Proof", "coord": coord, "depth": 2, "type": "combat", "element": "none", "grid": combat["grid"], "player_start": combat["player"]["pos"], "enemies": combat["enemies"], "terrain": combat.get("terrain", []), "traps": combat.get("traps", []), "loot": []}
		run["rooms"]["1,0"] = {"coord": coord, "depth": 2, "type": "combat", "element": "none", "revealed": true, "visited": true, "connections": [], "npcs": []}
		run.merge({"mode": "combat", "current_room": coord, "current_room_layout": layout, "combat_state": combat, "notice": ""}, true)
		scene._load_run_state(run)
		scene._close_dialogue()
		await process_frame
		await process_frame
		if not is_equal_approx(Typography.ui_scale(scene), 1.0):
			_failed = true
			push_error("EN02 UI scale must be 100%")
		var presentation: Dictionary = case["presentation"].duplicate(true)
		if case.has("wind_after"):
			var positions: Dictionary = {}
			for actor: Dictionary in Wind.actors(combat, combat["wind"]["direction"]):
				var from: Vector2 = scene.board_view._tile_center(actor["unit"]["pos"])
				var to: Vector2 = scene.board_view._tile_center(_engine._surface_actor(case["wind_after"], actor["kind"], actor["id"])["pos"])
				positions[_engine._surface_actor_key(actor["kind"], actor["id"])] = from.lerp(to, MID_WIND_PROGRESS)
			presentation["unit_world_positions"] = positions
		scene._render_board_state(combat, presentation)
		WindView.refresh_chip(scene)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = _canvas.get_texture().get_image()
		var path: String = "%s/%s.png" % [OUTPUT_DIR, case["name"]]
		if image.get_size() != VIEWPORT_SIZE or image.save_png(path) != OK:
			_failed = true
			push_error("EN02 capture failed: %s" % path)
		else: print("EN02 CAPTURE: %s" % ProjectSettings.globalize_path(path))
	_canvas.queue_free()
	await process_frame
	print("EN02 ENEMIES PROBE: %s" % ["FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)
