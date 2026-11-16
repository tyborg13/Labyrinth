extends "res://tools/atk08/receipts.gd"
## Targeted headless receipts using the atk-08 observer and production inputs.
## ATK12_SAVE_DIR is a receipt repro. ATK12_BEFORE=1 omits only the repair.
## Uses the inherited --seed / --output-dir / --health options and ATK08 settings.
const QUIET_FRAMES: int = 8
const IDLE_FRAME_LIMIT: int = 10000
var replay_failures: Array[String]

func _enter_scene(resume: bool) -> void:
	if resume: root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	var hooked: GDScript = hooked_scene_script()
	if OS.get_environment("ATK12_BEFORE") == "1":
		var before := GDScript.new()
		before.source_code = preload("res://tools/atk12/scene_source.gd").before(hooked.source_code)
		if before.reload() != OK:
			push_error("atk-12 before scene failed to compile")
			quit(1)
			return
		hooked = before
	scene.set_script(hooked)
	scene.set("receipt", self)
	root.add_child(scene)
	current_scene = scene

func _start() -> void:
	var save_dir: String = OS.get_environment("ATK12_SAVE_DIR")
	for name: String in ["progression.json", "run.save"]:
		assert(DirAccess.copy_absolute(save_dir.path_join(name), output.path_join(name)) == OK, "copy receipt save")
	var settings: Dictionary = Settings.load_settings()
	settings["combat_speed"] = speed
	settings["reduced_motion"] = reduced
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Engine.time_scale = time_scale
	receipts = FileAccess.open(output.path_join("receipts.jsonl"), FileAccess.WRITE)
	_write({"kind": "config", "speed": speed, "reduced_motion": reduced, "time_scale": time_scale, "seed": hunt_seed, "health": hunt_health, "before": OS.get_environment("ATK12_BEFORE") == "1", "save_dir": save_dir})
	_enter_scene(true)
	await _idle()
	var expected: Dictionary = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("combat_state.txt")))
	var state: Dictionary = scene.get("_combat_state")
	_check(state.get("player", {}).get("pos") == expected.get("player", {}).get("pos") and state.get("enemies") == expected.get("enemies"), "resumed receipt board")
	var expected_actor: String = OS.get_environment("ATK12_EXPECT_ACTOR")
	if not expected_actor.is_empty():
		_check((state.get("enemies", []) as Array).any(func(enemy: Dictionary) -> bool: return str(enemy.get("type", "")) == expected_actor), "receipt contains " + expected_actor)
	var decisions: Array = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("decisions.txt")))
	for action: Dictionary in decisions:
		if str(action.get("kind", "")).begins_with("side_"): continue
		if action.has("method"):
			scene.callv(str(action["method"]), action.get("args", []))
		elif str(action.get("kind", "")) == "move":
			scene.call("_on_board_tile_clicked", (scene.get("_combat_state") as Dictionary)["player"]["pos"])
			if bool(scene.get("_player_movement_selected")): scene.call("_on_board_tile_clicked", action["tile"])
		else:
			_check(false, "unsupported receipt decision: " + str(action))
		await _idle()
	for key: String in popups.keys(): _finalize_popup(key, last_clock)
	var final_file := FileAccess.open(output.path_join("final_state.txt"), FileAccess.WRITE)
	final_file.store_string(var_to_str(scene.get("_combat_state")))
	final_file.close()
	_write({"kind": "totals", "losses": loss_count, "popups": popup_count, "frames": frame_index, "outcome": "replay", "failures": replay_failures})
	receipts.flush()
	print("ATK12 REPLAY: %s (%d losses, %d popups)" % ["PASS" if replay_failures.is_empty() else "FAIL", loss_count, popup_count])
	scene.queue_free()
	for frame: int in range(QUIET_FRAMES): await process_frame
	quit(0 if replay_failures.is_empty() else 1)

func _idle() -> void:
	var quiet: int = 0
	for frame: int in range(IDLE_FRAME_LIMIT):
		await process_frame
		_sample()
		quiet = 0 if bool(scene.get("_animation_lock")) or bool(scene.get("_dialogue_active")) else quiet + 1
		if quiet >= QUIET_FRAMES: return
	_check(false, "receipt replay idle watchdog")

func _persist_repro(row: Dictionary) -> void:
	row["repro"] = OS.get_environment("ATK12_SAVE_DIR")

func _record_rules(before: Dictionary, after: Dictionary) -> void:
	for event: Dictionary in after.get("surface_events", []):
		if int(event.get("sequence", 0)) <= int(before.get("surface_event_sequence", 0)): continue
		if str(event.get("kind", "")) == "battlefield_rule_fired":
			_write({"kind": "rule_fired", "event": event, "round": round_index})

func on_slice_begin(host: Node, animated_state: Dictionary, steps: Array, resolved_state: Dictionary) -> void:
	if slice_prev.is_empty(): _record_rules(round_begin_state, animated_state)
	super.on_slice_begin(host, animated_state, steps, resolved_state)

func on_slice_end(host: Node, animated_state: Dictionary, steps: Array, resolved_state: Dictionary) -> void:
	_record_rules(slice_ctx.get("before", {}), resolved_state)
	super.on_slice_end(host, animated_state, steps, resolved_state)

func _check(ok: bool, message: String) -> void:
	if not ok:
		replay_failures.append(message)
		push_error(message)
