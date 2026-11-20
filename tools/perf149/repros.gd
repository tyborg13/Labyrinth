extends "res://tools/perf149/probe.gd"
## Drive the reviewer's same-frame gestures and pressure every rendered frame.

const Persistence = preload("res://scripts/run_persistence.gd")
const NEXT_TURN_TIMEOUT_MSEC: int = 25000
const PRESSURE_FRAMES_AFTER_TURN: int = 150
const CHECKPOINT_FRAMES: int = 120
const PENDING_WRITE_MSEC: int = 100

var _press_every_draw: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	if _headless: process_frame.connect(_review_frame)
	call_deferred("_run")

func _review_frame() -> void:
	if _press_every_draw:
		var key := InputEventKey.new()
		key.keycode = KEY_J
		key.pressed = true
		_canvas.push_input(key, true)
	RenderingServer.frame_post_draw.emit()

func _run() -> void:
	var bundle: String = _argument("--fixtures=")
	if not _headless or not FileAccess.file_exists(bundle):
		_finish("Review repros require headless Godot and --fixtures=PATH")
		return
	_fixtures = bytes_to_var(FileAccess.get_file_as_bytes(bundle)).get("cases", {})
	var settings: Dictionary = View.Settings.default_settings()
	settings["reduced_motion"] = true
	settings["ui_scale"] = 1.0
	View.Settings.save_settings(settings)
	_make_canvas()
	var case_name: String = _argument("--case=")
	if case_name not in ["details", "target", "route", "starvation", "departure"]:
		_finish("Choose --case=details|target|route|starvation|departure")
		return
	if not await _open("normal"):
		_finish()
		return
	match case_name:
		"details": _same_frame_details()
		"target": await _cancelled_targets()
		"route": await _cancelled_route()
		"starvation": await _spammed_unlock()
		"departure": await _departure_during_submit()
	_scene.queue_free()
	await process_frame
	print("PERF-149 REPRO %s: %s" % [case_name, "PASS" if _errors.is_empty() else "FAIL"])
	_finish()

func _same_frame_details() -> void:
	var details: Button = _scene._enemy_intent_toggle_button
	var chip: Button = _scene._selected_card_forecast_chip()
	var original: bool = _scene._show_all_enemy_intents
	_click(chip.get_global_rect().get_center())
	var disabled: bool = details.disabled
	_click(details.get_global_rect().get_center())
	if not _scene._animation_lock or not disabled or original != _scene._show_all_enemy_intents:
		_errors.append("Same-frame Details click survived mouse Pass")

func _cancelled_targets() -> void:
	if not await _select_card(): return
	var original_targets: int = _board.move_tiles.size()
	_button(JOY_BUTTON_Y, true)
	_button(JOY_BUTTON_Y, false)
	if original_targets == 0 or not _scene._animation_lock or not _board.move_tiles.is_empty() or _scene._selected_card_index >= 0:
		_errors.append("Movement targeting survived controller Y")

func _cancelled_route() -> void:
	if not await _select_card(): return
	var targets: Array[Vector2i] = _board.move_tiles.duplicate()
	for tile: Vector2i in targets:
		_hover(tile)
		await _wait_frames(1)
		if (_board.presentation.get("path_tiles", []) as Array).size() > 1: break
	var path: Array = _board._retained_presentation.get("path_tiles", [])
	if path.size() < 2 or not _board._focus_tiles_lookup_cache.has(path.back()):
		_errors.append("Movement hover did not show a hero route and its highlighted tiles")
		return
	# Sample the first draw before the resolver's post-draw refresh can run.
	RenderingServer.frame_post_draw.connect(_check_first_locked_route, CONNECT_ONE_SHOT)
	_button(JOY_BUTTON_Y, true)
	_button(JOY_BUTTON_Y, false)
	await _wait_frames(1)

func _check_first_locked_route() -> void:
	if (
		not _scene._animation_lock or not _board.move_tiles.is_empty()
		or not (_board.presentation.get("path_tiles", []) as Array).is_empty()
		or not (_board._retained_presentation.get("path_tiles", []) as Array).is_empty()
		or not _board._focus_tiles_lookup_cache.is_empty()
	):
		_errors.append("Movement route or its highlighted tiles survived the first locked draw")

func _spammed_unlock() -> void:
	var before: int = int(_scene._combat_state["turn"])
	_button(JOY_BUTTON_Y, true)
	_button(JOY_BUTTON_Y, false)
	_press_every_draw = true
	var deadline: int = Time.get_ticks_msec() + NEXT_TURN_TIMEOUT_MSEC
	while int(_scene._combat_state["turn"]) == before and Time.get_ticks_msec() < deadline:
		await process_frame
	# Keep pressing while the hero turn settles, as in the original repro.
	for index: int in range(PRESSURE_FRAMES_AFTER_TURN):
		if not _scene._animation_lock: break
		await process_frame
	var after: int = int(_scene._combat_state["turn"])
	print("PERF-149 REPRO TURN: %d -> %d, locked=%s" % [before, after, _scene._animation_lock])
	if after != before + 1 or _scene._animation_lock:
		_errors.append("Continuous input kept the next hero turn locked")
	_press_every_draw = false

func _departure_during_submit() -> void:
	var actor: Dictionary = _scene._combat_state["current_actor"].duplicate(true)
	_scene.set_runtime_performance_instrumentation_enabled(true)
	_button(JOY_BUTTON_Y, true)
	_button(JOY_BUTTON_Y, false)
	for index: int in range(CHECKPOINT_FRAMES):
		await process_frame
		if _scene._runtime_performance_counts.has("enemy_round_initial_snapshots"): break
	if not _scene._runtime_performance_counts.has("enemy_round_initial_snapshots") or not _scene._committed_run_state_override.is_empty():
		_errors.append("Did not reach the uncommitted receipt boundary")
		return
	View.Store._run_writer.probe_delay_msec = PENDING_WRITE_MSEC
	View.Store.queue_owned_run_state(_scene._committed_run_state(), "perf149_repro_pre_pass")
	_scene._leaving_tree = true
	_scene.process_mode = Node.PROCESS_MODE_DISABLED
	await Persistence.save_for_departure(_scene)
	var saved: Dictionary = View.Store.load_saved_run()
	var receipts: Array = Analytics.load_all_events().filter(func(event: Dictionary) -> bool: return event["event_type"] == "player_turn_ended")
	if saved.get("combat_state", {}).get("current_actor", {}) != actor or not receipts.is_empty() or not _scene._committed_run_state_override.is_empty():
		_errors.append("Departure advanced the turn after freezing the previous actor")
