extends RefCounted

## Measure the existing 1920x1080/100% board registration. Headless callers use
## geometry only; they never claim a renderer capture.
const SIZE := Vector2i(1920, 1080)
const PROOF_SETTLE_FRAMES: int = 8
const PROOF_RUN_SEED: int = 91210
const PROOF_TILE := Vector2i(2, 4)
const PROOF_NEXT_TILE := Vector2i(3, 4)

static func measure(tree: SceneTree, creature: String) -> Dictionary:
	var Settings = preload("res://scripts/settings_store.gd")
	Settings.set_storage_path("user://gait01_geometry_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	tree.root.size = SIZE
	tree.root.content_scale_size = SIZE
	Settings.apply_settings(settings, tree.root, false)
	var host: SubViewport = preload("res://tests/gust_shrike_capture_viewport.gd").create(tree.root)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	host.add_child(scene)
	for frame: int in range(PROOF_SETTLE_FRAMES): await tree.process_frame
	var Store = preload("res://scripts/progression_store.gd")
	scene._load_run_state(preload("res://scripts/run_engine.gd").new().create_new_run(PROOF_RUN_SEED, Store.default_data()))
	var Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
	var actors: Array[Dictionary]
	actors.assign([Fixtures.enemy(creature, 1, PROOF_TILE, "")])
	Fixtures.install(scene, Fixtures.state(actors))
	for frame: int in range(PROOF_SETTLE_FRAMES): await tree.process_frame
	var result: Dictionary = {"scale": scene.board_view.source_pixel_scale_for_type(creature),
		"step": scene.board_view._tile_center(PROOF_TILE).distance_to(scene.board_view._tile_center(PROOF_NEXT_TILE))}
	host.queue_free()
	for frame: int in range(PROOF_SETTLE_FRAMES): await tree.process_frame
	return result
