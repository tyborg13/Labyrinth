extends "res://tests/actor_presentation_probe.gd"

const INPUT = preload("res://scripts/input_router.gd")
const TRANSITION_PROOF: String = "user://probes/board_transition_v1"

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRANSITION_PROOF))
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
	for reduced: bool in [false, true]:
		await _lethal_transition(reduced)
	await _verify_transitions(false)
	await _verify_transitions(true)
	_write_proof()
	for error: String in _errors:
		push_error(error)
	print("BOARD TRANSITION PROOF DIR=" + ProjectSettings.globalize_path(TRANSITION_PROOF))
	print("BOARD TRANSITION PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _lethal_transition(reduced: bool) -> void:
	_active_type = "grave_surgeon"
	_observer_type = "warden"
	await _fixture(GameData.enemy_def(_active_type)["intents"][0], reduced)
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["enemies"].resize(1)
	state["enemies"][0]["hp"] = 1
	state["enemies"][0]["block"] = 0
	state["enemies"][0]["pos"] = Vector2i(4, 4)
	state["player"]["pos"] = Vector2i(4, 5)
	state["player"]["hp"] = 20
	state["player"]["max_hp"] = 24
	state["turn_queue"] = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return str(entry.get("key", "")) != "enemy_2")
	_install(state)
	_instance.call("_refresh_ui")
	await create_timer(0.5).timeout
	var label: String = "reduced" if reduced else "normal"
	var width: float = _board.call("_tile_width")
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test", INPUT.MODALITY_CONTROLLER, INPUT.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _instance.call("_on_card_pressed", 0)
		await _settle()
		await _still(label + "_controller_target")
		var cancel := InputEventAction.new()
		cancel.action = INPUT.ACTION_CANCEL
		cancel.pressed = true
		_check(await _instance.call("_handle_controller_input", cancel), "Controller Cancel remains handled")
		_check(state == _instance.get("_combat_state"), "Controller target/cancel preserves combat state")
		_check(is_equal_approx(width, _board.call("_tile_width")), "Controller target/cancel keeps the fixed room scale")
		router.call("set_forced_state_for_test", INPUT.MODALITY_POINTER, INPUT.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _settle()
		await _still(label + "_pointer_handoff")
		router.call("clear_forced_state_for_test")
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_hovered", Vector2i(4, 4))
	await _settle()
	await _still(label + "_before_lethal")
	var directory: String = TRANSITION_PROOF.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var frames: Array[Dictionary]
	var started: int = Time.get_ticks_usec()
	var previous: Vector2 = _board.position
	_instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	var reward_seen: bool = false
	var mode: String = "combat"
	while Time.get_ticks_usec() - started < 12000000:
		await RenderingServer.frame_post_draw
		var position: Vector2 = _board.position
		mode = str((_instance.get("_run_state") as Dictionary).get("mode", ""))
		var file: String = "%04d.jpg" % frames.size()
		_viewport.get_texture().get_image().save_jpg(directory.path_join(file), 0.94)
		frames.append({"file": file, "seconds": float(Time.get_ticks_usec() - started) / 1000000.0, "y": position.y, "tile_width": _board.call("_tile_width"), "mode": mode})
		_check(is_equal_approx(width, _board.call("_tile_width")), label + " lethal input through reward reveal keeps exact scale")
		if not reduced:
			_check(position.distance_to(previous) < 24.0, "Actual reward transition has no frame jump")
		previous = position
		reward_seen = reward_seen or mode == "reward"
		if reward_seen and not bool(_instance.get("_animation_lock")) and Time.get_ticks_usec() - started > 2500000:
			break
	await create_timer(0.5).timeout
	await _still(label + "_actual_reward")
	_check(reward_seen and mode == "reward", "Actual last-enemy defeat reaches reward mode")
	_check(_instance.call("_reward_choices_available"), "Actual victory produces selectable rewards")
	_check(not bool(_instance.get("_animation_lock")), "Actual reward reveal releases input")
	var framing: RefCounted = _board.get("_room_framing")
	var center: Vector2 = _board.position + (_board.call("_board_origin") as Vector2) + (framing.get("floor_bounds") as Rect2).get_center() * width / 100.0
	_check(absf(center.y - 540.0) < 0.5, "Actual victory centers the board floor")
	_proof["transitions"].append({"mode": label + "_actual_lethal", "samples": frames, "floor_center": [center.x, center.y]})
