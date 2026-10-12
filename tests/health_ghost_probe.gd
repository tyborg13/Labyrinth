extends SceneTree

const Suite = preload("res://tests/suites/health_ghost_suite.gd")
const Tracker = preload("res://scripts/health_ghost_tracker.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")

const PROBE_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "res://output/feel-02/health_ghost"
const CONTRACT_PATH: String = OUTPUT_DIR + "/proof_contract.json"
const ENEMY_CAPTURE_TIMES: Array = [0.1, 0.5, 0.75, 1.0]
const ENEMY_CAPTURE_NAMES: Array = ["enemy_hit_010.png", "enemy_hit_050.png", "enemy_hit_075.png", "enemy_hit_100.png"]
const HERO_CAPTURE_SECONDS: float = 0.1
const HEAL_CAPTURE_SECONDS: float = 0.05
const REDUCED_CAPTURE_SECONDS: float = 0.1
const REDUCED_CLEAR_SECONDS: float = 0.4
const PROOF_CONTRACT: Dictionary = {
	"min_images": 10,
	"expected_sizes": ["1920x1080"],
	"required_images": [
		{"pattern": "*enemy_hit_010.png", "width": 1920, "height": 1080},
		{"pattern": "*enemy_hit_050.png", "width": 1920, "height": 1080},
		{"pattern": "*enemy_hit_075.png", "width": 1920, "height": 1080},
		{"pattern": "*enemy_hit_100.png", "width": 1920, "height": 1080},
		{"pattern": "*hero_hit_010.png", "width": 1920, "height": 1080},
		{"pattern": "*hero_heal_005.png", "width": 1920, "height": 1080},
		{"pattern": "*boss_hit_010.png", "width": 1920, "height": 1080},
		{"pattern": "*reduced_motion_010.png", "width": 1920, "height": 1080},
		{"pattern": "*reduced_motion_040.png", "width": 1920, "height": 1080},
		{"pattern": "*enemy_death_010.png", "width": 1920, "height": 1080},
	],
}

var _failures: Array[String]
var _verify_only: bool = false
var _scene: Node
var _viewport: SubViewport
var _tracker: RefCounted
var _combat: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_verify_only = OS.get_cmdline_user_args().has("--verify-only")
	if OS.get_cmdline_user_args().has("--emit-proof-contract"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		var contract: FileAccess = FileAccess.open(CONTRACT_PATH, FileAccess.WRITE)
		if contract == null:
			push_error("Could not write health ghost proof contract")
			quit(1)
			return
		var proof: Dictionary = PROOF_CONTRACT.duplicate(true)
		for entry: Dictionary in proof["required_images"]:
			entry["regions"] = [{"rect": [0, 0, PROBE_SIZE.x, PROBE_SIZE.y], "min_luma_range": 8, "min_luma_stdev": 2}]
		contract.store_string(JSON.stringify(proof, "\t") + "\n")
		print("HEALTH GHOST PROOF CONTRACT: %s" % ProjectSettings.globalize_path(CONTRACT_PATH))
		quit(0)
		return
	Progression.set_storage_path("user://health_ghost_probe/progression.json")
	Progression.set_run_storage_path("user://health_ghost_probe/run.save")
	Settings.set_storage_path("user://health_ghost_probe/settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://health_ghost_probe/analytics")
	Progression.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_viewport = SubViewport.new()
	_viewport.name = "HealthGhost1920x1080"
	_viewport.size = PROBE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_scene)
	await Suite.settle(self)
	await _install_fixture(false)
	var original: Dictionary = (_scene.get("_combat_state") as Dictionary).duplicate(true)
	var enemy: Dictionary = (_combat["enemies"] as Array)[0]
	var enemy_key: String = "enemy_%d" % int(enemy["id"])
	var enemy_hp: float = float(enemy["hp"])
	_combat["enemies"][0]["hp"] = enemy_hp - Suite.FIXTURE_DAMAGE
	_submit()
	var previous_time: float = 0.0
	for index: int in range(ENEMY_CAPTURE_TIMES.size()):
		var elapsed: float = ENEMY_CAPTURE_TIMES[index]
		_tracker.advance(elapsed - previous_time)
		previous_time = elapsed
		var progress: float = clampf((elapsed - Tracker.HOLD_SECONDS) / Tracker.DRAIN_SECONDS, 0.0, 1.0)
		_expect(is_equal_approx(_tracker.ghost_value(enemy_key), enemy_hp - Suite.FIXTURE_DAMAGE * progress * progress), "Enemy ghost has its exact authored position at %.2f s" % elapsed)
		await _capture(ENEMY_CAPTURE_NAMES[index])
	_expect((_scene.get("_combat_state") as Dictionary) == original, "Capturing presentation snapshots leaves committed combat state untouched")

	await _install_fixture(false)
	var hero_hp: float = float(_combat["player"]["hp"])
	_combat["player"]["hp"] = hero_hp - Suite.FIXTURE_HERO_DAMAGE
	_submit()
	_tracker.advance(HERO_CAPTURE_SECONDS)
	_assert_hero_hud(Vector2(hero_hp - Suite.FIXTURE_HERO_DAMAGE, hero_hp))
	await _capture("hero_hit_010.png")
	_combat["player"]["hp"] = hero_hp - Suite.FIXTURE_HERO_DAMAGE + Suite.FIXTURE_HEAL
	_submit()
	_tracker.advance(HEAL_CAPTURE_SECONDS)
	_expect(_tracker.sample("player")["heal_range"] == Vector2(hero_hp - Suite.FIXTURE_HERO_DAMAGE, float(_combat["player"]["hp"])), "Heal flash covers just the newly healed range")
	_expect(is_equal_approx(float(_tracker.sample("player")["heal_flash"]), 0.75), "Heal flash is fading at 0.05 s")
	_assert_hero_hud(Vector2(float(_combat["player"]["hp"]), float(_combat["player"]["hp"])))
	await _capture("hero_heal_005.png")

	await _install_fixture(true)
	var boss: Dictionary = _scene.call("_boss_unit_for_health_overlay", _combat)
	var boss_key: String = "enemy_%d" % int(boss["id"])
	var boss_hp: float = float(boss["hp"])
	for unit: Dictionary in _combat["enemies"]:
		if int(unit["id"]) == int(boss["id"]):
			unit["hp"] = boss_hp - Suite.FIXTURE_DAMAGE
	_submit()
	_tracker.advance(HERO_CAPTURE_SECONDS)
	var boss_bar: Control = _scene.get("_boss_health_bar")
	_expect(boss_bar.is_visible_in_tree() and boss_bar.ghost_key == boss_key, "Boss proof shows the production encounter overlay")
	_expect(boss_bar.ghost_sample()["ghost_range"] == Vector2(boss_hp - Suite.FIXTURE_DAMAGE, boss_hp), "Boss overlay shares the exact ghost range")
	await _capture("boss_hit_010.png")

	await _install_fixture(false)
	_combat["enemies"][0]["hp"] = float(_combat["enemies"][0]["hp"]) - Suite.FIXTURE_DAMAGE
	_submit({"reduced_motion": true})
	_tracker.advance(REDUCED_CAPTURE_SECONDS)
	_expect(_tracker.reduced_motion and _tracker.ghost_value(enemy_key) == enemy_hp, "Reduced motion holds a static ghost")
	await _capture("reduced_motion_010.png")
	_tracker.advance(REDUCED_CLEAR_SECONDS - REDUCED_CAPTURE_SECONDS)
	_expect(is_equal_approx(_tracker.ghost_value(enemy_key), enemy_hp - Suite.FIXTURE_DAMAGE), "Reduced motion clears the ghost in one step at 0.4 s")
	await _capture("reduced_motion_040.png")

	await _install_fixture(false)
	var death_unit: Dictionary = (_combat["enemies"][0] as Dictionary).duplicate(true)
	death_unit["key"] = enemy_key
	death_unit["role"] = "enemy"
	death_unit["death_progress"] = 0.0
	_combat["enemies"] = []
	_submit({"death_animation_units": [death_unit]})
	_tracker.advance(HERO_CAPTURE_SECONDS)
	_expect(_tracker.sample(enemy_key)["ghost_range"] == Vector2(0.0, enemy_hp), "Death bar receives the lethal ghost despite the removed enemy")
	await _capture("enemy_death_010.png")
	_scene.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	if not _verify_only:
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("HEALTH GHOST PROBE %s: %s" % ["HEADLESS SEMANTICS" if _verify_only else "CAPTURE", "PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)

func _install_fixture(boss: bool) -> void:
	var settings: Dictionary = (_scene.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = false
	_scene.set("_settings", settings)
	_scene.call("_load_run_state", Suite.fixture_run(boss))
	_scene.call("_close_dialogue")
	_scene.call("_close_large_map")
	_scene.set("_animation_lock", false)
	await Suite.settle(self)
	_combat = (_scene.get("_combat_state") as Dictionary).duplicate(true)
	_tracker = (_scene.get("board_view") as Control).health_ghost_tracker
	# Sample the production renderer with an exact, deterministic presentation
	# clock. GPU readback and fixture settling must not advance a sampled ghost.
	(_tracker.get("_clock") as Node).set_process(false)
	var log_panel: Control = _scene.get_node_or_null("UIRoot/LogPanel") as Control
	if log_panel != null:
		log_panel.visible = false

func _submit(presentation: Dictionary = {}) -> void:
	if presentation.has("reduced_motion"):
		var settings: Dictionary = (_scene.get("_settings") as Dictionary).duplicate(true)
		settings["reduced_motion"] = presentation["reduced_motion"]
		_scene.set("_settings", settings)
	_scene.call("_render_board_state", _combat, presentation)
	(_tracker.get("_clock") as Node).set_process(false)

func _assert_hero_hud(expected_range: Vector2) -> void:
	var meters: int = 0
	for node: Node in _scene.find_children("TurnOrderHealthBar", "", true, false):
		if str(node.get("ghost_key")) != "player":
			continue
		meters += 1
		_expect(node.call("ghost_sample")["ghost_range"] == expected_range, "Hero HUD meter and board share the same ghost range")
	_expect(meters > 0, "Hero capture includes a visible HUD health meter")
	var board: Control = _scene.get("board_view")
	_expect((board.get("_hud_health_rects_cache") as Dictionary).has("player"), "Hero capture includes its production board health bar")

func _capture(filename: String) -> void:
	if _verify_only:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await Suite.settle(self)
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "Capture has a rendered frame: %s" % filename)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == PROBE_SIZE, "Capture is exactly 1920x1080: %s" % filename)
	_expect(image.save_png(OUTPUT_DIR.path_join(filename)) == OK, "Capture saves: %s" % filename)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
