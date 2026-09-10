extends "res://tests/enemy_cutout_roster_gameplay_probe.gd"

## The roster sweep also covers misses. These valid-target cases require the
## three fixed-pattern AoEs to play their authored clip in the combined runtime.
const AOE_CASES := {
	# Cinder Bloom deals 4 damage, then its Fire tile deals 3 at turn start.
	"cinder_ooze": {"intent": "cinder_bloom", "player": Vector2i(4, 5), "clip": "bloom", "hp": 193},
	"iskaldra": {"intent": "shatterstorm", "player": Vector2i(4, 2), "clip": "storm", "hp": 193},
	"noctyrax": {"intent": "night_coil", "player": Vector2i(4, 3), "clip": "coil", "hp": 190}
}

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProgressionStore.set_storage_path("user://roster_progression.json")
	ProgressionStore.set_run_storage_path("user://roster_run.save")
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
	_observer_type = "lightning_wisp"
	for actor: String in AOE_CASES:
		_active_type = actor
		var case: Dictionary = AOE_CASES[actor]
		var selected_intent: Dictionary = {}
		for intent: Dictionary in GameData.enemy_def(actor)["intents"]:
			if str(intent["id"]) == str(case["intent"]):
				selected_intent = intent
		_check(not selected_intent.is_empty(), actor + " has the requested AoE")
		await _fixture(selected_intent)
		# Move only the player onto a known tile in the existing fixed AoE pattern.
		var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		state["player"]["pos"] = case["player"]
		var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
		run["combat_state"] = state
		run["current_room_layout"]["player_start"] = case["player"]
		_instance.set("_run_state", run)
		_instance.call("_sync_combat_state_from_run")
		_instance.call("_refresh_ui")
		await _settle()
		await _pass_and_record(actor + "_" + str(case["intent"]) + "_hit", false)
		var result: Dictionary = _manifest["clips"][-1]
		var saw_clip: bool = false
		var saw_effect: bool = false
		for sample: Dictionary in result["samples"]:
			saw_clip = saw_clip or str(sample["animation"].get("clip", "")) == str(case["clip"])
			saw_effect = saw_effect or not (sample["effect"] as Dictionary).is_empty()
		_check(saw_clip, actor + " plays distinct " + str(case["clip"]) + " on a valid AoE target")
		_check(saw_effect, actor + " emits the resolved AoE effect")
		_check(int(result["player_hp"]) == int(case["hp"]), actor + " preserves exact AoE and turn-start damage")
		result["target_tile"] = [case["player"].x, case["player"].y]
		result["required_clip"] = case["clip"]
		print("ROSTER AOE PROOF: completed " + actor)
		_write_manifest()
	_manifest["errors"] = _errors
	_write_manifest()
	for error: String in _errors:
		push_error(error)
	print("ENEMY CUTOUT ROSTER AOE TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)
