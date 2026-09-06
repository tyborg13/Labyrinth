extends "res://tools/board_surface_playtest.gd"

# Replays recorded human-selected commands through the same manual input APIs.
# No saved tactical state or old action definitions are injected into the run.
func _repl() -> void:
	manual = true
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://playtest/board_surface_manual_replay.json"))
	var steps: Array = record["steps"]
	var checkpoints: Array[Dictionary]
	var failed: bool = false
	for index: int in range(steps.size()):
		var step: Dictionary = steps[index]
		print("REPLAY STEP %d %s" % [index, JSON.stringify(step)])
		if not _replay_step(step):
			push_error("Recorded manual decision failed at step %d: %s" % [index, JSON.stringify(step)])
			failed = true
			break
		checkpoints.append({"step": index, "mode": _run_state.get("mode", ""), "room": str(_run_state.get("current_room", Vector2i.ZERO)), "hp": _run_state.get("player_hp", 0), "combat_hp": (_combat_state.get("player", {}) as Dictionary).get("hp", 0)})
	var summary: Dictionary = {"seed": record["seed"], "build": record["build"], "control": "Recorded manual decisions replayed through current command APIs", "recorded_from": record["recorded_from"], "end_reason": _run_state.get("mode", ""), "steps_completed": checkpoints.size(), "failed": failed, "hp": _run_state.get("player_hp", 0), "max_hp": _run_state.get("player_max_hp", 0), "checkpoints": checkpoints, "cards_played": played, "surface_events": counters}
	var file: FileAccess = FileAccess.open(str(_options["output_dir"]).path_join("manual_summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	if str(summary["end_reason"]) != "rested":
		push_error("Manual replay did not reach its recorded natural campfire retreat")
	print("MANUAL REPLAY RESULT %s" % JSON.stringify(summary))
	_print_analytics_summary()

func _replay_step(step: Dictionary) -> bool:
	match str(step["kind"]):
		"room":
			var tile: Vector2i = Vector2i(int(step["tile"][0]), int(step["tile"][1]))
			var moves: Array[Vector2i] = _run_engine.available_moves(_run_state)
			var index: int = moves.find(tile)
			if index < 0:
				return false
			_command_move(index)
			return _run_state.get("current_room", INVALID_TARGET_TILE) == tile
		"walk":
			var tile: Vector2i = Vector2i(int(step["tile"][0]), int(step["tile"][1]))
			_command_walk("%d,%d" % [tile.x, tile.y])
			return (_combat_state.get("player", {}) as Dictionary).get("pos", INVALID_TARGET_TILE) == tile
		"card":
			var hand: Array = (_combat_state.get("deck", {}) as Dictionary).get("hand", [])
			var index: int = hand.find(str(step["card_id"]))
			if index < 0 or not _can_start_card(index, "printed"):
				return false
			_command_card(PackedStringArray(["card", str(index)]))
			if step.has("force_direction"):
				_command_force(PackedStringArray(["force", str(step["force_direction"])]))
			for coords: Array in step["targets"]:
				if _pending.is_empty():
					return false
				if int(coords[0]) < 0:
					_command_skip()
				else:
					_command_target("%d,%d" % [int(coords[0]), int(coords[1])])
			return _pending.is_empty()
		"pass":
			if str(_run_state.get("mode", "")) != "combat":
				return false
			_command_pass()
		"reward":
			if str(_run_state.get("mode", "")) != "reward":
				return false
			_command_reward(PackedStringArray(["reward", "heal"]))
		"rest":
			if str(_run_state.get("mode", "")) != "campfire":
				return false
			_command_rest()
		_:
			return false
	return true
