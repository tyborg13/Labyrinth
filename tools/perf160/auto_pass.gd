extends "res://tools/perf160/probe.gd"

const CARD: String = "stone_plate"
const SPENT_PLAYS: int = 1
const MOVEMENT_LEFT: int = 0

func _run() -> void:
	_output = _argument("--output=")
	var bundle: String = _argument("--fixtures=")
	if _output.is_empty() or not FileAccess.file_exists(bundle):
		_finish("Supply --output=DIR and --fixtures=the perf-140 fixture bundle.")
		return
	_fixtures = bytes_to_var(FileAccess.get_file_as_bytes(bundle)).get("cases", {})
	var state: Dictionary = _fixtures["normal"]["combat_state"]
	state["cards_played_this_turn"] = SPENT_PLAYS
	state["player_movement_remaining"] = MOVEMENT_LEFT
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["combat_speed"] = View.Settings.COMBAT_NORMAL
	settings["display_mode"] = "windowed"
	View.Settings.save_settings(settings)
	Analytics.set_storage_dir("user://perf160-auto")
	_make_canvas()
	_telemetry = root.get_node("PerformanceTelemetry")
	if not await _open("normal"):
		_finish()
		return
	_press(JOY_BUTTON_X)
	if not _scene._controller_hand_focused: _press(JOY_BUTTON_X)
	await _wait_frames(INPUT_SETTLE_FRAMES)
	var hand: Array = state["deck"]["hand"]
	var index: int = hand.find(CARD)
	if index < 0 or not _scene._controller_hand_focused or _scene._combat_engine.cards_remaining_this_turn(_scene._combat_state) != 1:
		_finish("The archive did not supply Stone Plate with one Card Play remaining.")
		return
	_scene._controller_set_hand_index(index)
	_press(JOY_BUTTON_A)
	await _wait_frames(INPUT_SETTLE_FRAMES)
	if _scene._selected_card_index != index or not _scene._pending_card_requires_confirmation():
		_finish("Controller Accept did not select the fixture's targetless card.")
		return
	var initial_turn: int = int(_scene._combat_state["turn"])
	_telemetry.take_hitch_phases()
	_last_boundary = Time.get_ticks_usec()
	_record_frames = true
	_cohort = "A_confirm"
	_press(JOY_BUTTON_A)
	await _wait_frames(1)
	var settled: bool = await _wait_for_action()
	await _wait_frames(READY_SETTLE_FRAMES)
	_record_frames = false
	var final: Dictionary = _scene._combat_state.duplicate(true)
	final.erase("analytics")
	var turn_end: Dictionary = {}
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type") == "player_turn_ended" and int(event.get("turn", -1)) == initial_turn:
			if not turn_end.is_empty(): _errors.append("Duplicate turn-ended receipt.")
			turn_end = event["payload"]
	if not settled or int(final["turn"]) <= initial_turn or turn_end.get("end_reason") != "auto" or _first_ready.is_empty():
		_errors.append("Controller A did not exhaust the player turn and publish the next ready hand.")
	var file := FileAccess.open(_output.path_join("auto-pass.json"), FileAccess.WRITE)
	if file == null:
		_finish("Could not write the auto-Pass receipt.")
		return
	file.store_string(JSON.stringify({"first_ready": _first_ready, "turn_end": turn_end,
		"combat": _combat_digest(final)}, "\n") + "\n")
	file.close()
	_scene.queue_free()
	await _wait_frames(2)
	print("PERF-160 AUTO PASS: %s (%d errors)" % ["PASS" if _errors.is_empty() else "FAIL", _errors.size()])
	_finish()

func _press(button: int) -> void:
	_button(button, true)
	_button(button, false)
