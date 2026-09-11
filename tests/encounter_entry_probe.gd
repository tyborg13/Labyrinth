extends "res://tests/actor_presentation_probe.gd"

const EntrySuite = preload("res://tests/suites/actor_presentation_suite.gd")
const Framing = preload("res://scripts/board_framing.gd")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF))
	ProgressionStore.set_storage_path("user://presentation_progression.json")
	ProgressionStore.set_run_storage_path("user://presentation_run.save")
	ProgressionStore.clear_saved_run()
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	var index: int = 0
	for run: Dictionary in EntrySuite.entry_run_states():
		await _entry_case(run, index)
		index += 1
	_write_proof()
	for error: String in _errors: push_error(error)
	print("ENCOUNTER ENTRY PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _entry_case(run: Dictionary, index: int) -> void:
	# Keep the generated combat and enemy-free display layout unmodified.
	var progression: Dictionary = run["progression"].duplicate(true)
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	run["progression"] = progression
	_instance.set("_progression", progression)
	_instance.set("_run_state", run)
	_instance.set("_board_encounter_key", "")
	_instance.call("_sync_combat_state_from_run")
	_instance.set("_animation_lock", false)
	_instance.call("_refresh_ui")
	await _settle()
	await create_timer(0.45).timeout
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var expected: Array[String] = Framing.possible_enemy_types(state)
	var actual: Array = (_board.get("_room_framing").get("encounter_types") as Array).duplicate()
	_check(not expected.is_empty() and (run["current_room_layout"]["enemies"] as Array).is_empty(), "Room entry keeps combat enemies separate from the display layout")
	_check(actual == expected, "Live board reserves the actual generated roster and spawn closure")
	var width: float = _board.call("_tile_width")
	var origin: Vector2 = _board.call("_board_origin")
	var label: String = "entry_" + str(index)
	await _still(label)
	_active_type = str(state["enemies"][0]["type"])
	var raw: Array = GameData.enemy_def(_active_type).get("footprint", [1, 1])
	var footprint := Vector2i(int(raw[0]), int(raw[1]))
	var tile := Vector2i(-1, -1)
	for y: int in range((state["grid"] as Array).size()):
		for x: int in range((state["grid"][y] as Array).size()):
			var candidate := Vector2i(x, y)
			if Framing._fits(state["grid"], candidate, footprint) and (tile.x < 0 or x + y < tile.x + tile.y):
				tile = candidate
	state["enemies"][0]["pos"] = tile
	_install(state)
	var router: Node = root.get_node_or_null("InputRouter")
	var input: Script = load("res://scripts/input_router.gd")
	router.call("set_forced_state_for_test", input.MODALITY_CONTROLLER, input.FAMILY_STEAM_DECK)
	_instance.call("_refresh_controller_interface")
	await _settle()
	_assert_actor_inside(_active_type, label + "_top_controller")
	_check(is_equal_approx(width, _board.call("_tile_width")) and origin.is_equal_approx(_board.call("_board_origin")), "Generated encounter movement and controller header keep the original camera")
	await _still(label + "_top_controller")
	router.call("clear_forced_state_for_test")
	_instance.call("_refresh_controller_interface")
	await _settle()
	_proof["bounds"].append({"case": label, "types": actual, "tile_width": width, "top_actor": _active_type, "empty_display_enemies": true})
