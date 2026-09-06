extends SceneTree

# The retired off-board threshold fixture is now real conduction and paid cross
# geometry. Keep this entry point useful for targeted feedback and reduced-motion
# regression captures without maintaining a second combat presentation pipeline.
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/chain_attack_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const OUTPUT := "user://relic_damage_feedback_probe"
var scene: Node
var view: SubViewport
var finished: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://relic_feedback_profile.json")
	Progression.set_run_storage_path("user://relic_feedback.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://relic_feedback_settings.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var combat := Combat.new()
	for reduced: bool in [false, true]:
		var settings: Dictionary = Settings.default_settings()
		settings["ui_scale"] = 1.0
		settings["reduced_motion"] = reduced
		settings["music_volume"] = 0.0
		settings["sfx_volume"] = 0.0
		Settings.save_settings(settings)
		scene = load("res://scenes/run_scene.tscn").instantiate()
		view.add_child(scene)
		await create_timer(0.1).timeout
		var electrical: Dictionary = Fixture.fixture(combat)
		electrical["relics"] = ["ion_spool"]
		(electrical["enemies"][1] as Dictionary)["pos"] = Vector2i(5, 4)
		(electrical["enemies"][1] as Dictionary)["block"] = 2
		(electrical["enemies"][2] as Dictionary)["stoneskin"] = 2
		for tile: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]: Ground.place(electrical, tile, "electrified")
		var action: Dictionary = {"type": "ranged", "range": 5, "damage": 4, "element": "lightning"}
		var resolved: Dictionary = combat.resolve_player_action_for_presentation(electrical, action, Vector2i(4, 4))
		assert(Fixture.hp(electrical, 1) - Fixture.hp(resolved["state"], 1) == 4)
		assert(Fixture.hp(electrical, 3) - Fixture.hp(resolved["state"], 3) == 2)
		assert(Fixture.hp(electrical, 2) - Fixture.hp(resolved["state"], 2) == 2)
		await _capture_action(electrical, resolved, action, "conduction_" + ("reduced" if reduced else "normal"))
		var earth: Dictionary = Fixture.fixture(combat)
		(earth["player"] as Dictionary)["pos"] = Vector2i(3, 4)
		(earth["player"] as Dictionary)["stoneskin"] = 8
		earth["relics"] = ["thornmail_brooch"]
		(earth["enemies"][1] as Dictionary)["pos"] = Vector2i(4, 5)
		action = {"type": "melee", "range": 1, "damage": 4, "element": "earth", "_surface_relic_modes": ["cross"]}
		resolved = combat.resolve_player_action_for_presentation(earth, action, Vector2i(4, 4))
		assert(int(resolved["state"]["player"]["stoneskin"]) == 4)
		assert(Fixture.hp(earth, 1) - Fixture.hp(resolved["state"], 1) == 4)
		assert(Fixture.hp(earth, 3) - Fixture.hp(resolved["state"], 3) == 4)
		await _capture_action(earth, resolved, action, "cross_" + ("reduced" if reduced else "normal"))
		scene.queue_free()
		await process_frame
	print("RELIC DAMAGE FEEDBACK PROBE: PASS")
	print(ProjectSettings.globalize_path(OUTPUT))
	quit()

func _capture_action(before: Dictionary, resolved: Dictionary, action: Dictionary, filename: String) -> void:
	var run: Dictionary = scene.get("_run_state") as Dictionary
	run["mode"] = "combat"
	run["combat_state"] = before
	scene.set("_run_state", run)
	scene.set("_combat_state", before)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	await process_frame
	_start_animation(before, resolved, action)
	var captured: bool = false
	while not finished:
		await RenderingServer.frame_post_draw
		var board: Control = scene.get("board_view") as Control
		var presentation: Dictionary = board.get("presentation") as Dictionary
		if not captured and not (presentation.get("floating_texts", []) as Array).is_empty():
			var image: Image = view.get_texture().get_image()
			assert(image.get_size() == Vector2i(1920, 1080))
			assert(image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename + ".png"))) == OK)
			captured = true
	assert(captured, "Each real action must show damage feedback, including reduced motion")

func _start_animation(before: Dictionary, resolved: Dictionary, action: Dictionary) -> void:
	finished = false
	await scene.call("_animate_player_action_step", before, resolved["state"], "chain_bolt", action, Vector2i(4, 4), resolved.get("chain_hits", []))
	finished = true
