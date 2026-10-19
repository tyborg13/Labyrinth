extends RefCounted

const PROOF_SETTLE_FRAMES: int = 8
const PROOF_RUN_SEED: int = 91210

## Measure the existing 1920x1080/100% production board registration for the
## comparison, rather than choosing an actor size in the proof camera.
static func measure(tree: SceneTree) -> Dictionary:
	var Settings = preload("res://scripts/settings_store.gd")
	Settings.set_storage_path("user://rr21_comparison_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, tree.root, false)
	var host: SubViewport = preload("res://tests/gust_shrike_capture_viewport.gd").create(tree.root)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	host.add_child(scene)
	for frame: int in range(PROOF_SETTLE_FRAMES): await tree.process_frame
	var Store = preload("res://scripts/progression_store.gd")
	scene._load_run_state(preload("res://scripts/run_engine.gd").new().create_new_run(PROOF_RUN_SEED, Store.default_data()))
	var Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
	var actors: Array[Dictionary]
	actors.assign([Fixtures.enemy("briar_weaver",1,Vector2i(2,4),"lash_of_thorns")])
	Fixtures.install(scene, Fixtures.state(actors))
	for frame: int in range(PROOF_SETTLE_FRAMES): await tree.process_frame
	var result: Dictionary = {"briar_weaver": scene.board_view.source_pixel_scale_for_type("briar_weaver"),
		"protagonist": scene.board_view.protagonist_source_pixel_scale()}
	host.queue_free()
	await tree.process_frame
	return result
