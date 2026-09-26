extends SceneTree

# Staged renderer proof; actual played attempts are documented separately.
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const OUTPUT: String = "user://probes/dragon_revision"
var scene: Node
var canvas: SubViewport
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://dragon_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Progression.set_storage_path("user://dragon_probe_profile.json")
	Progression.set_run_storage_path("user://dragon_probe_run.save")
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := RunEngine.new()
	var combat := Combat.new()
	for boss_id: String in ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]:
		var options: Dictionary = {"dragon_id":boss_id, "dragon_depth":24 if boss_id=="noctyrax" else 4}
		var seed: int = Factory.seed_for_options(options)
		var original: Dictionary = Factory.build(engine, combat, engine.create_new_run(seed, Progression.default_data()), options)
		var battle: Dictionary = original["combat_state"].duplicate(true)
		for phase: int in range(4):
			var run: Dictionary = original.duplicate(true)
			battle["current_actor"] = original["combat_state"]["current_actor"].duplicate(true)
			battle["player"]["hp"] = original["combat_state"]["player"]["hp"]
			run["combat_state"] = battle.duplicate(true)
			await _load(run)
			scene.call("_set_show_all_enemy_intents",true)
			await scene.call("_on_board_tile_clicked",battle["enemies"][0]["pos"])
			await _capture("%s_%d_%s" % [boss_id, phase, battle["enemies"][0]["intent"]["id"]])
			battle = combat.resolve_enemy_turn_with_steps(battle,0)["state"]
	print("DRAGON REVISION PROOF: ", "PASS" if failures.is_empty() else "FAIL", failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _load(run: Dictionary) -> void:
	scene.call("_load_run_state", run)
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(0.25).timeout

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	if image.get_size() != Vector2i(1920,1080): failures.append("Wrong native rendering size")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if image.save_png(OUTPUT.path_join(label + ".png")) != OK: failures.append("Capture failed: " + label)
