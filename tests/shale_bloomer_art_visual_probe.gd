extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/chain_attack_suite.gd")
const GameData = preload("res://scripts/game_data.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/shale_bloomer_art"
var view: SubViewport
var scene: Node
var board: Control

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://shale_art_progression.json")
	Progression.set_run_storage_path("user://shale_art_run.save")
	Settings.set_storage_path("user://shale_art_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_2d = Viewport.MSAA_4X
	root.add_child(view)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.3).timeout
	var progression: Dictionary = scene.get("_progression") as Dictionary
	for prompt: String in Tutorials.prompt_ids():
		progression = Tutorials.resolve_progression(progression, prompt)
	scene.set("_progression", progression)
	var combat: Combat = Combat.new()
	var state: Dictionary = Fixture.fixture(combat)
	state["name"] = "Shale Bloomer art proof"
	state["enemies"][0]["type"] = "bile_bloomer"
	state["enemies"][0]["intent"] = GameData.enemy_def("bile_bloomer")["intents"][0].duplicate(true)
	state["enemies"][0]["pos"] = Vector2i(5, 4)
	state["enemies"][1]["pos"] = Vector2i(7, 3)
	state["enemies"][2]["pos"] = Vector2i(8, 7)
	state["enemies"].remove_at(3)
	state["terrain"] = [{"id": 31, "type": "crate", "pos": Vector2i(3, 3), "hp": 5, "max_hp": 5}, {"id": 32, "type": "barrel", "pos": Vector2i(6, 6), "hp": 5, "max_hp": 5}]
	state["grid"][2][2] = "pillar"
	state["grid"][2][8] = "pillar"
	state["deck"]["hand"] = ["thorn_skewer", "frostbolt", "chain_bolt", "updraft", "brace"]
	Ground.place(state, Vector2i(5, 4), "rubble")
	Ground.place(state, Vector2i(5, 5), "rubble")
	Ground.place(state, Vector2i(6, 4), "fire")
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	run["current_room"] = state.get("room_coord")
	run["current_room_layout"] = {"grid": state.get("grid"), "coord": state.get("room_coord"), "type": "combat", "name": "Shale Bloomer art proof"}
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	await create_timer(0.2).timeout
	board = scene.get("board_view") as Control
	var idle_layout: Dictionary = board.call("_unit_idle_sheet_layout", "bile_bloomer")
	var death_layout: Dictionary = board.call("_unit_death_sheet_layout", "bile_bloomer")
	assert(int(idle_layout["columns"]) == 4 and int(idle_layout["rows"]) == 2 and bool(idle_layout["ping_pong"]))
	assert(int(death_layout["columns"]) == 4 and int(death_layout["rows"]) == 4 and not bool(death_layout["ping_pong"]))
	var indices: Array = board.call("_idle_frame_indices", idle_layout)
	assert(indices == [0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1], "Shared ping-pong drops the duplicate closing pose and reverses interior frames")
	var unit: Dictionary = {"type": "bile_bloomer", "role": "enemy", "id": 1, "key": "enemy_1"}
	var frames: Array = board.call("_unit_idle_frames", unit)
	assert(frames.size() == 12 and (frames[0] as Texture2D).get_size() == Vector2(255, 255), "The 4x2 idle atlas must yield native 255px square frames")
	var reference_frames: Array = board.call("_load_death_frames_for_art_path", "bile_bloomer", str(GameData.enemy_def("bile_bloomer")["art_path"]))
	assert(reference_frames.size() == 16 and (reference_frames[0] as Texture2D).get_size() == Vector2(255, 255), "The independent 4x4 death reference atlas must still slice into 16 native 255px frames")
	assert((board.call("_unit_death_frames", unit) as Array).is_empty(), "Enemy gameplay retains its established procedural dissolve")
	var portrait_path: String = str(scene.call("_combat_portrait_path", "bile_bloomer"))
	var portrait: Texture2D = preload("res://scripts/asset_loader.gd").load_texture(portrait_path)
	assert(portrait != null and portrait.get_size() == Vector2(128, 128))
	await _capture("01_furnished_combat_and_portrait")
	board.set_process(false)
	var frame_seconds: float = float(board.call("_unit_idle_frame_seconds", unit))
	for index: int in range(frames.size()):
		board.set("_idle_elapsed", (float(index) + 0.05) * frame_seconds)
		board.call("_process", 0.0)
		await _capture("idle_%02d_source_%02d" % [index, int(indices[index])])
	scene.call("_on_turn_order_enemy_hovered", Vector2i(5, 4), "enemy_1")
	await _capture("02_shale_intent_and_portrait")
	scene.call("_on_turn_order_enemy_unhovered", Vector2i(5, 4), "enemy_1")
	var dead: Dictionary = state.duplicate(true)
	dead["enemies"][0]["hp"] = 0
	var units: Array = scene.call("_defeated_enemy_units_between_states", state, dead)
	assert(units.size() == 1 and bool(board.call("_unit_uses_procedural_shadow_dissolve", units[0])))
	for progress: float in [0.0, 0.2, 0.45, 0.7, 0.98]:
		var animated: Dictionary = (units[0] as Dictionary).duplicate(true)
		animated["death_progress"] = progress
		scene.call("_render_board_state", dead, {"death_animation_units": [animated]})
		await _capture("death_%02d" % int(progress * 100))
	var file: FileAccess = FileAccess.open(OUTPUT.path_join("metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"idle_layout": idle_layout, "idle_source_indices": indices, "idle_frame_count": frames.size(), "death_reference_layout": death_layout, "death_reference_frame_count": reference_frames.size(), "gameplay_death": "procedural_shadow_dissolve", "portrait_path": portrait_path}, "\t"))
	file.close()
	scene.queue_free()
	await process_frame
	print("SHALE BLOOMER ART PROBE: PASS")
	print(ProjectSettings.globalize_path(OUTPUT))
	quit()

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = view.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png"))) == OK)
