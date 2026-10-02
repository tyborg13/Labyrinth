extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Suite = preload("res://tests/suites/relic_u6_suite.gd")
const Fixture = preload("res://tests/suites/illusion_terrain_suite.gd")
const Rules = preload("res://scripts/illusion_relic_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT := "user://probes/relic_u6"
var view: SubViewport
var scene: Node
var engine := Combat.new()
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://relic_u6_progression.json")
	Progression.set_run_storage_path("user://relic_u6_run.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://relic_u6_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Fixture._install_fixtures()
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
	var state: Dictionary = Suite.state(engine, ["mirror_triptych"])
	for tile: Vector2i in [Vector2i(2, 2), Vector2i(2, 6), Vector2i(4, 7)]: state = engine._create_illusion(state, tile, 3)
	await _aim(state, "hurl_spear", Vector2i(4, 4), "01_mirror_triptych")
	var board: Node = scene.get("board_view")
	assert((board.get("presentation").get("illusion_echo_previews", []) as Array).size() == 3)
	state = Suite.state(engine, ["hollow_puppet"])
	state = engine._create_illusion(state, Vector2i(3, 4), 5)
	await _aim(state, "updraft", Vector2i(3, 4), "02_hollow_puppet")
	assert((board.get("presentation").get("collision_markers", []) as Array).size() == 1)
	state = Suite.state(engine, ["glassway_compass"])
	state = engine._create_illusion(state, Vector2i(3, 4), 4)
	await _aim(state, "flowing_step", Vector2i(3, 4), "03_glassway_compass")
	assert((board.get("presentation").get("preview_units", []) as Array).any(func(unit: Dictionary) -> bool: return str(unit.get("role", "")) == "illusion_preview" and unit.get("pos") == Vector2i(2, 4)))
	state = Suite.state(engine, ["storm_crown"])
	state["enemies"][1]["pos"] = Vector2i(5, 4)
	state["enemies"][2]["pos"] = Vector2i(6, 4)
	await _aim(state, "chain_bolt", Vector2i(4, 4), "04_storm_crown")
	state = Suite.state(engine, ["copper_shod_staff"])
	state["enemies"][1]["pos"] = Vector2i(8, 4)
	state["enemies"][2]["pos"] = Vector2i(8, 6)
	state = engine._create_illusion(state, Vector2i(7, 4), 3)
	state["terrain"] = [{"id": "outcrop_1", "kind": "crag_outcrop", "owner_kind": "player", "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4, "blocks_sight": true, "surface_on_destroy": "rubble"}]
	await _aim(state, "chain_bolt", Vector2i(4, 4), "05_copper_shod_staff")
	assert((board.get("presentation").get("surface_preview_arcs", []) as Array).any(func(arc: Dictionary) -> bool: return arc.get("to") == Vector2i(5, 4)))
	Fixture._remove_fixtures()
	print("RELIC U6 PROBE RESULT: PASS")
	scene.queue_free()
	await process_frame
	quit()
func _aim(state: Dictionary, card: String, target: Vector2i, name: String) -> void:
	state["room_name"] = name.trim_prefix("0").replace("_", " ")
	state["deck"]["hand"] = [card, "mirror_feint", "hall_of_mirrors", "chain_bolt", "yank"]
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	run["relics"] = state["relics"]
	run["current_room"] = state.get("room_coord")
	run["current_room_layout"] = {"grid": state["grid"], "coord": state.get("room_coord"), "type": "combat", "name": state["room_name"]}
	scene.call("_reset_card_resolution")
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	scene.call("_on_card_pressed", 0)
	scene.set("_hovered_board_tile", target)
	scene.call("_refresh_stage_view")
	for i: int in range(8): await process_frame
	scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", target))
	await RenderingServer.frame_post_draw
	var screenshot: Image = view.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png"))) == OK)
