extends "res://tests/protagonist_cutout_gameplay_probe.gd"

const Playback = preload("res://tests/fixtures/hero_facing_run_scene.gd")
const Facing = preload("res://scripts/hero_facing_state.gd")
const Settings = preload("res://scripts/settings_store.gd")
const GOLDEN: String = "res://tests/fixtures/hero_facing_snap.csv"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://hero_golden_profile.json")
	ProgressionStore.set_run_storage_path("user://hero_golden_run.save")
	root.size = SIZE
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_instance.set_script(Playback)
	root.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view")
	_instance.get("_settings")["hero_facing"] = default_mode()
	await _fixture(Vector2i(3, 4), Vector2i(4, 3), false, ["quick_stab", "brace", "bone_dart", "patch_up", "sidestep_slash"], 24, [Vector2i(2, 3)])
	_instance.get("_settings")["hero_facing"] = default_mode()
	_instance.call("_sync_combat_state_from_run")
	var engine: RefCounted = _instance.get("_combat_engine")
	var state: Dictionary = _instance.get("_combat_state").duplicate(true)
	for entry: Dictionary in [
		{"label": "move", "action": {"type": "move", "range": 1}, "target": Vector2i(3, 3)},
		{"label": "target", "action": {"type": "melee", "damage": 1, "range": 1}, "target": Vector2i(4, 3)},
		{"label": "self", "action": {"type": "block", "amount": 2}, "target": Vector2i(-1, -1)},
	]:
		var after: Dictionary = engine.apply_player_action(state, entry["action"], entry["target"])
		_instance.proof_label = entry["label"]
		await _instance.call("_animate_player_action_step", state, after, "", entry["action"], entry["target"])
		_instance.call("_render_board_state", after, {})
		state = after
		if Settings.hero_facing_mode(_instance.get("_settings")) == "persist":
			var expected: Dictionary = state[Facing.KEY]
			_assert(_snapshot()["facing"] == expected["facing"] and _snapshot()["mirrored"] == expected["mirrored"], "Action settles to its saved facing: " + entry["label"])
	for index: int in range(2):
		state["enemies"][index]["intent"] = {"id": "skitter_strike", "name": "Skitter Strike", "time": 5, "actions": [{"type": "melee", "damage": 4, "range": 1}]}
		var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, index)
		_instance.proof_label = "hit_%d" % index
		await _instance.call("_animate_enemy_phase_steps", state.duplicate(true), resolved["steps"])
		state = resolved["state"]
		_instance.call("_render_board_state", state, {})
		if Settings.hero_facing_mode(_instance.get("_settings")) == "persist":
			_assert(_snapshot()["facing"] == state[Facing.KEY]["facing"] and _snapshot()["mirrored"] == state[Facing.KEY]["mirrored"], "Hit settles to its source facing: %d" % index)
	var actual: String = "\n".join(_instance.proof_frames) + "\n"
	if Settings.hero_facing_mode(_instance.get("_settings")) == "persist":
		var contacted: bool = false
		var before_hit_hp: int = -1
		for observation: Dictionary in _instance.proof_observations:
			if observation["label"] != "hit_1": continue
			if before_hit_hp < 0: before_hit_hp = int(observation["hp"])
			contacted = contacted or int(observation["hp"]) < before_hit_hp
			_assert(observation["facing"] == ("rear" if contacted else "front") and observation["mirrored"], "Second source turns on its actual impact frame: " + JSON.stringify(observation))
		_assert(contacted, "Real second-source attack emitted an impact frame")
		var run: Dictionary = _instance.get("_run_state").duplicate(true)
		run["combat_state"] = state
		_assert(ProgressionStore.save_run_state(run), "Production save serializer accepts additive facing")
		var loaded: Dictionary = ProgressionStore.load_saved_run()
		_instance.set("_defer_initial_run_presentation", true)
		_instance.proof_label = ""
		_instance.call("_load_run_state", loaded)
		_instance.call("_refresh_ui")
		_assert(_instance.get("_combat_state")[Facing.KEY] == state[Facing.KEY], "Continue restores saved facing through the real scene load")
		_assert(_snapshot()["facing"] == state[Facing.KEY]["facing"] and _snapshot()["mirrored"] == state[Facing.KEY]["mirrored"], "Continue renders the saved facing")
		loaded["combat_state"].erase(Facing.KEY)
		_instance.call("_load_run_state", loaded)
		_assert(_instance.get("_combat_state")[Facing.KEY] == Facing.initial(loaded["combat_state"]), "Old save initializes nearest enemy through real load")
		print("HERO FACING GAMEPLAY: %s (%d scripted frames)" % ["PASS" if _errors.is_empty() else "FAIL", _instance.proof_frames.size()])
	else:
		_assert(actual.to_utf8_buffer() == FileAccess.get_file_as_bytes(GOLDEN), "Snap facing per authored frame is byte-identical to the pre-change scripted fight")
		print("HERO FACING SNAP GOLDEN: %s (%d frames)" % ["PASS" if _errors.is_empty() else "FAIL", _instance.proof_frames.size()])
	_instance.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	quit(0 if _errors.is_empty() else 1)

func default_mode() -> String:
	return "snap"
