extends SceneTree

# Director baseline for the status/defense badge redesign (owner request 2026-10-25): a Warband board with
# Block, Stoneskin and every unit status on the hero and three enemies, at 1920x1080, 100% UI scale.
# Copy to tests/_status_capture_probe.gd, run through tools/visual_probe_runner.py --no-headless, then delete it.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://status-captures"
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://status-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var engine := Run.new()
	var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "earth", "warband_tier": 2})
	var state: Dictionary = run["combat_state"]
	var clean: bool = OS.get_cmdline_user_args().has("--clean")
	var player: Dictionary = state["player"] if not clean else {}
	player["block"] = 6
	player["stoneskin"] = 4
	player["bleed"] = 2
	player["expose"] = 1
	var looks: Array = [
		{"block": 5, "chilled": true, "shock": 1},
		{"stoneskin": 3, "bleed": 3, "expose": 2, "immobilize": true},
		{"freeze": 1, "block": 8},
		{"petrify": 1, "stoneskin": 2, "bleed": 1},
	]
	var index: int = 0
	for enemy: Dictionary in state.get("enemies", []):
		if clean or int(enemy.get("hp", 0)) <= 0 or index >= looks.size(): continue
		enemy.merge(looks[index], true)
		index += 1
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png(OUTPUT.path_join("clean_board.png" if clean else "statuses_board.png"))
	print("STATUS captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit()
