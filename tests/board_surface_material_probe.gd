extends "res://tests/board_surface_visual_probe.gd"

## The same real board with clear, unoccupied samples and combined materials.
## Four seconds covers complete authored Fire and electrical discharge cycles.
func _initialize() -> void:
	ground_loop_only = true
	await super._initialize()

func _capture(name: String, _settle_frames: int = 8) -> void:
	if name != "01_mixed_ground": return
	state = state.duplicate(true)
	state["surface_rule_overrides"] = {}
	Ground.place(state, Vector2i(3, 6), "fire")
	Ground.place(state, Vector2i(4, 6), "ice")
	Ground.place(state, Vector2i(5, 6), "electrified")
	Ground.place(state, Vector2i(6, 6), "rubble")
	Ground.place(state, Vector2i(7, 6), "ice")
	Ground.place(state, Vector2i(7, 6), "rubble")
	Ground.place(state, Vector2i(8, 6), "electrified")
	Ground.place(state, Vector2i(8, 6), "rubble")
	Ground.place(state, Vector2i(7, 7), "fire")
	Ground.place(state, Vector2i(7, 7), "rubble")
	var run: Dictionary = scene.get("_run_state") as Dictionary
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await super._capture("material_clear_and_combined", 10)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var board: Control = scene.get("board_view") as Control
	var shown: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	shown["ambient_time_seconds"] = 12.0
	shown["reduced_motion"] = true
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	await super._capture("material_reduced_motion", 3)
	shown["reduced_motion"] = false
	var output: String = OUTPUT.path_join("material_loop")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var motion_frames: int = 0 if OS.get_environment("LABYRINTH_MATERIAL_STILLS_ONLY") == "1" else 96
	for frame: int in range(motion_frames):
		shown["ambient_time_seconds"] = 12.0 + float(frame) / 24.0
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
		board.call("_queue_dynamic_redraw")
		await RenderingServer.frame_post_draw
		var screenshot: Image = view.get_texture().get_image()
		assert(screenshot.save_png(ProjectSettings.globalize_path(output.path_join("frame_%03d.png" % frame))) == OK)
	state["surface_rule_overrides"] = {"conductive_fire": true}
	board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown)
	await super._capture("material_stormcoal", 3)
	var large: Dictionary = state.duplicate(true)
	var definition: Dictionary = preload("res://scripts/game_data.gd").enemy_def("zekarion")
	(large["enemies"] as Array).clear()
	(large["enemies"] as Array).append({"id": 91, "type": "zekarion", "pos": Vector2i(5, 5), "footprint": Vector2i(2, 2), "hp": int(definition.get("max_hp", 60)), "max_hp": int(definition.get("max_hp", 60)), "intent": {}})
	Ground.place(large, Vector2i(5, 5), "fire")
	Ground.place(large, Vector2i(5, 5), "rubble")
	Ground.place(large, Vector2i(6, 5), "ice")
	Ground.place(large, Vector2i(6, 5), "rubble")
	Ground.place(large, Vector2i(5, 6), "electrified")
	Ground.place(large, Vector2i(6, 6), "ice")
	run["combat_state"] = large
	scene.set("_run_state", run)
	scene.set("_combat_state", large)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await super._capture("material_large_footprint", 5)
	print("BOARD SURFACE MATERIAL PROBE: PASS")
