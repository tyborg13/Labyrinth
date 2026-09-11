extends "res://tests/actor_presentation_probe.gd"

## Real resolver spawn branches, preserving each encounter's initial camera.
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
	for kind: String in ["split", "summon", "reinforcement"]:
		await _spawn_case(kind)
	_write_proof()
	for error: String in _errors: push_error(error)
	print("ENCOUNTER FRAMING PROOF: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _spawn_case(kind: String) -> void:
	_active_type = "zekarion" if kind == "summon" else "cinder_ooze" if kind == "split" else "crawler"
	_observer_type = _active_type
	await _fixture(GameData.enemy_def(_active_type)["intents"][0])
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["player"]["hp"] = 20
	state["player"]["max_hp"] = 24
	if kind == "reinforcement":
		state["objective"] = {"type": "survive", "reinforcement_pool": ["grave_surgeon"], "target_clock": 100, "reinforcement_interval": 10, "next_reinforcement_clock": 10}
		var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
		run["current_room_layout"]["objective"] = state["objective"].duplicate(true)
		_instance.set("_run_state", run)
		_instance.set("_board_encounter_key", "")
	_install(state)
	await _settle()
	var width: float = _board.call("_tile_width")
	var origin: Vector2 = _board.call("_board_origin")
	var types: Array = (_board.get("_room_framing").get("encounter_types") as Array).duplicate()
	await _still(kind + "_before_spawn")
	var engine := CombatEngine.new()
	var before: int = (state["enemies"] as Array).size()
	match kind:
		"split":
			state["enemies"][0]["hp"] = 0
			state = engine.call("_trigger_enemy_death_spawn", state, state["enemies"][0])
		"summon":
			state = engine.call("_enemy_summon_minions", state, 0, {"minion_type": "lightning_wisp", "count": 2})
		"reinforcement":
			state["initiative_clock"] = 10
			engine.call("_spawn_due_survival_reinforcements", state)
	_check((state["enemies"] as Array).size() > before, kind + " resolver actually creates its planned creatures")
	_install(state)
	await _settle()
	_check(is_equal_approx(width, _board.call("_tile_width")) and origin.is_equal_approx(_board.call("_board_origin")), kind + " actual spawn preserves the exact camera")
	for enemy: Dictionary in state["enemies"]:
		_check(types.has(str(enemy["type"])), kind + " planned roster contains every realized enemy")
	await _still(kind + "_after_spawn")
	_proof["bounds"].append({"case": kind, "tile_width": width, "reserved_types": types, "spawned_count": (state["enemies"] as Array).size() - before})
