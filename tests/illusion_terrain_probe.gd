extends SceneTree

## Real-renderer proof for the wave-4 illusion and terrain board presentation
## (spec/card_mechanics_illusions_terrain.md): a powder keg, a Worldspine cage,
## charged illusions with trait badges, Mirror Feint's placement ghost, and a
## Doppelganger shot whose arc starts at the illusion.
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/chain_attack_suite.gd")
const Suite = preload("res://tests/suites/illusion_terrain_suite.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT := "user://probes/illusion_terrain"
var view: SubViewport
var scene: Node

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://illusion_terrain_progression.json")
	Progression.set_run_storage_path("user://illusion_terrain_run.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://illusion_terrain_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Suite._install_fixtures()
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_2d = Viewport.MSAA_4X
	root.add_child(view)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.2).timeout
	var progression: Dictionary = scene.get("_progression") as Dictionary
	for prompt: String in Tutorials.prompt_ids(): progression = Tutorials.resolve_progression(progression, prompt)
	scene.set("_progression", progression)
	var combat := Combat.new()
	var state: Dictionary = Fixture.fixture(combat)
	# Keg at (3, 5); a Worldspine cage around the far crawler at (8, 7).
	state = combat.apply_player_action(state, combat.card_play_actions("w4c_fx_powder_keg", state)[0], Vector2i(3, 5))
	(state["player"] as Dictionary)["pos"] = Vector2i(6, 6)
	state = combat.apply_player_action(state, combat.card_play_actions("w4c_fx_worldspine", state)[0], Vector2i(8, 7))
	(state["player"] as Dictionary)["pos"] = Vector2i(2, 4)
	state = combat._create_illusion(state, Vector2i(3, 2), 3, {"on_damaged": {"damage": 4, "element": "lightning", "shock": 1}, "source_name": "Ball Lightning"})
	state = combat._create_illusion(state, Vector2i(5, 6), 5, {"ranged_origin": true, "source_name": "Doppelganger"})
	(state["deck"] as Dictionary)["hand"] = ["w4c_fx_shot", "w4c_fx_mirror_feint", "w4c_fx_rockburst", "w4c_fx_empty_husk", "w4c_fx_rampart"]
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	run["current_room"] = state.get("room_coord")
	run["current_room_layout"] = {"grid": state.get("grid"), "coord": state.get("room_coord"), "type": "combat", "name": "Illusion terrain proof"}
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	await _capture("01_keg_spires_badges")
	scene.call("_on_card_pressed", 0)
	scene.set("_hovered_board_tile", Vector2i(6, 4))
	scene.call("_refresh_stage_view")
	await _capture("02_doppelganger_shot_origin")
	scene.call("_reset_card_resolution")
	scene.call("_on_card_pressed", 1)
	scene.set("_hovered_board_tile", Vector2i(4, 4))
	scene.call("_refresh_stage_view")
	await _capture("03_mirror_feint_ghost")
	scene.call("_reset_card_resolution")
	scene.call("_on_card_pressed", 2)
	scene.set("_hovered_board_tile", Vector2i(3, 5))
	scene.call("_refresh_stage_view")
	await _capture("04_rockburst_keg_hover")
	scene.call("_reset_card_resolution")
	for hand: Array in [["w4c_fx_ball_lightning", "w4c_fx_reflected_threat", "w4c_fx_hall_of_mirrors", "w4c_fx_doppelganger", "w4c_fx_ice_sculpture"], ["w4c_fx_shattered_reflection", "w4c_fx_refraction", "w4c_fx_worldbreak", "w4c_fx_powder_keg", "w4c_fx_worldspine"]]:
		var hand_state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
		(hand_state["deck"] as Dictionary)["hand"] = hand
		var hand_run: Dictionary = scene.get("_run_state") as Dictionary
		hand_run["combat_state"] = hand_state
		scene.set("_run_state", hand_run)
		scene.set("_combat_state", hand_state)
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui")
		await _capture("05_hand_%s" % str(hand[0]).trim_prefix("w4c_fx_"))
	Suite._remove_fixtures()
	print("ILLUSION TERRAIN PROBE: PASS")
	scene.queue_free()
	await process_frame
	quit()

func _capture(name: String, settle_frames: int = 8) -> void:
	for i: int in range(settle_frames): await process_frame
	if int(scene.get("_selected_card_index")) >= 0:
		var target: Vector2i = scene.get("_hovered_board_tile")
		if target.x >= 0: scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", target))
	await RenderingServer.frame_post_draw
	var screenshot: Image = view.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png"))) == OK)
