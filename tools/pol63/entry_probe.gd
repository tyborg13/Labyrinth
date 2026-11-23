extends "res://tools/pol63/state_probe.gd"
## Compare a combat checkpoint with entry through its actual incoming door.

class ObservedRunScene extends "res://scripts/run_scene.gd":
	var capture: Dictionary = {}
	var fixture_battle: Dictionary = {}
	var force_unframed: bool = false
	var render_frame: int = 0
	var first_attempt: int = -1
	var retry_frames: Array[int]

	func _ready() -> void:
		RenderingServer.frame_pre_draw.connect(_count_render_frame)
		super._ready()

	func _count_render_frame() -> void:
		render_frame += 1

	func _combat_objective_dock_frame_signal() -> Signal:
		# The census submits dummy frames. Use the same deadline clock as a
		# native run so the proof measures the frame that receives the paint.
		return RenderingServer.frame_pre_draw

	func _combat_objective_board_is_framed() -> bool:
		return not force_unframed and super._combat_objective_board_is_framed()

	func _retry_combat_objective_dock() -> void:
		if capture.is_empty() and not _combat_objective_dock_home.has_area():
			retry_frames.append(render_frame)
		super._retry_combat_objective_dock()

	func _combat_objective_hud_target_rect() -> Rect2:
		if first_attempt < 0 and _combat_objective_hud.visible and _run_state.get("mode") == "combat":
			first_attempt = render_frame
		var target := super._combat_objective_hud_target_rect()
		if capture.is_empty() and _combat_objective_dock_home.has_area():
			capture = geometry()
			capture["frame"] = Engine.get_process_frames()
			capture["target"] = rect_values(target)
			capture["retry_frames"] = retry_frames.duplicate()
			capture["wait_frames"] = maxi(0, _combat_objective_dock_wait_frames)
		return target

	func geometry() -> Dictionary:
		return {
			"bounds": rect_values(_combat_objective_board_bounds()),
			"budget_current": _board_hud_budget.key == _board_hud_budget.environment(self),
			"framing_applied": is_same(board_view.presentation.get("board_fit_exclusions"), _board_hud_budget.exclusions),
			"board_mode": board_view.presentation.get("board_framing_mode", ""),
			"board_current": board_view.combat_state.get("grid") == _combat_state.get("grid"),
			"hand_pending": _hand_layout_pending_revision,
			"home": rect_values(_combat_objective_dock_home),
			"render_frame": render_frame,
			"first_attempt": first_attempt,
			"forced_unframed": force_unframed,
		}

	func _on_pre_battle_start_pressed() -> void:
		if not fixture_battle.is_empty() and _run_state.get("mode") == "pre_battle":
			# Install the exact census roster, tiles, and deck in the normal
			# Start factory. Door selection, combat handoff, and intro stay live.
			_prepared_pre_battle_factory = _run_engine.prepare_pre_battle_combat(_run_state)
			_prepared_pre_battle_factory["combat_state"] = fixture_battle
		await super._on_pre_battle_start_pressed()

	static func rect_values(rect: Rect2) -> Array:
		return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


var _first_paint: Dictionary = {}
var _first_dock: Dictionary = {}
var _dock_drift: String = ""
var _entry: LayoutInput


func _run() -> void:
	_options = _parse_args()
	_headless = DisplayServer.get_name() == "headless"
	if _options.is_empty() or _headless != _options.has("--dry-run"):
		_finish("Expected matching headless/dry-run mode and census arguments.")
		return
	if Runtime.apply_from_environment().is_empty():
		_finish("Expected isolated Godot storage.")
		return
	for pair: Array in [
		["--save", Store.DEFAULT_RUN_STORAGE_PATH],
		["--profile", Store.DEFAULT_STORAGE_PATH],
		["--settings", Settings.DEFAULT_STORAGE_PATH],
	]:
		if DirAccess.copy_absolute(_options[pair[0]], ProjectSettings.globalize_path(pair[1])) != OK:
			_finish("Failed to install %s." % pair[0])
			return
	var shot: Dictionary = JSON.parse_string(_options["--shot"])
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = shot.get("ui_scale", 1.0)
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	var fixture: Dictionary = Store.load_saved_run()
	var destination: Vector2i = fixture["current_room"]
	var normal: bool = shot.get("entry") == "door"
	if normal and not _install_predecessor(fixture, destination):
		_finish("No available incoming door to %s." % destination)
		return
	if _headless:
		Engine.max_fps = HEADLESS_FPS
		process_frame.connect(_submit_headless_frame)
	var dimensions: PackedStringArray = str(_options["--size"]).split("x")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d")) as Viewport.MSAA
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_capture_tree = _viewport
	_screen = load("res://scenes/run_scene.tscn").instantiate()
	_screen.set_script(ObservedRunScene)
	_screen.set("force_unframed", shot.get("force_unframed", false))
	if normal:
		_screen.set("fixture_battle", fixture["combat_state"])
	_entry = LayoutInput.new(self, _viewport, _screen, shot)
	RenderingServer.frame_post_draw.connect(_observe_frame)
	root.set_meta("labyrinth_resume_saved_run", true)
	_viewport.add_child(_screen)
	_result["run_seed"] = fixture["seed"]
	_result["mode"] = "combat"
	_result["ui_scale"] = root.content_scale_factor
	if normal:
		var error: String = await _entry.enter_door(destination)
		if not error.is_empty():
			_finish(error)
			return
	if not await _entry.wait_for_idle():
		_finish("Combat did not reach settled idle.")
		return
	_record("first_visible", _first_paint)
	_record("first_docked_objective", _first_dock)
	_record("home_capture", _screen.get("capture"))
	var idle: Dictionary = _snapshot()
	_record("settled_idle", idle)
	if shot.get("check_entry"):
		var error: String = _validate_entry(idle, shot)
		if not error.is_empty():
			_finish(error)
			return
	if shot.get("force_unframed"):
		var play: Dictionary = await _entry.play_first_card()
		_record("first_card", {"render_frame": _screen.get("render_frame")}.merged(play))
		_finish(play.get("error", ""))
		return
	if shot.get("deadline_proof") and not shot.get("exercise_layout", false):
		_finish("")
		return
	if not shot.get("exercise_layout", false):
		var error: String = await _entry.reach()
		if not error.is_empty():
			_finish(error)
			return
		var frame_image: Image = await _settle(_entry, null)
		if _result["capped"]:
			_finish("Requested census state did not settle.")
			return
		if not _headless and frame_image.save_png(_options["--png"]) != OK:
			_finish("Could not save the native entry capture.")
			return
		if not _headless: print(_options["--png"])
		_finish("")
		return
	var error: String = await _entry.exercise()
	_finish(_dock_drift if error.is_empty() and shot.get("check_entry") else error)


func _install_predecessor(fixture: Dictionary, destination: Vector2i) -> bool:
	var engine := RunEngine.new()
	for room: Dictionary in fixture["rooms"].values():
		for connection: Dictionary in room.get("connections", []):
			if connection.get("coord") != destination: continue
			var checkpoint: Dictionary = fixture.duplicate(true)
			var previous: Vector2i = room["coord"]
			var key: String = engine._room_key(previous)
			var previous_room: Dictionary = checkpoint["rooms"][key]
			previous_room["sealed"] = false
			previous_room["visited"] = true
			previous_room["cleared"] = true
			checkpoint["rooms"][engine._room_key(destination)]["visited"] = false
			checkpoint["mode"] = "room"
			checkpoint["combat_state"] = {}
			checkpoint["current_room"] = previous
			checkpoint["current_room_layout"] = engine._display_layout_for_room(
				fixture["seed"], previous_room, Vector2i.ZERO)
			if destination in engine.available_moves(checkpoint):
				var tile: Vector2i = preload("res://scripts/room_generator.gd").door_tile_for_direction(connection["door_dir"])
				var grid: Array = checkpoint["current_room_layout"]["grid"]
				if tile.y >= grid.size() or tile.x >= grid[tile.y].size():
					# Some incoming authored rooms use a smaller grid than the
					# route's door coordinates. Reuse the fixture's full-size
					# board geometry for this approach, with the real route.
					checkpoint["current_room_layout"] = fixture["current_room_layout"].duplicate(true)
					checkpoint["current_room_layout"]["coord"] = previous
				print("POL63 APPROACH ", previous, " -> ", destination, " by ", tile)
				return Store.save_run_state(checkpoint)
	return false


func _observe_frame() -> void:
	if not _screen.is_node_ready() or _screen.get("_run_state").get("mode") != "combat":
		return
	var stack: Dictionary = _entry.painted_stack()
	if _first_paint.is_empty() and (stack.values().any(func(rect: Array) -> bool: return not rect.is_empty())):
		_first_paint = _snapshot()
	var hud: Control = _screen.get("_combat_objective_hud")
	if _first_dock.is_empty() and not stack["objective"].is_empty() and not hud.get("intro_active"):
		_first_dock = _snapshot()
	elif not _first_dock.is_empty() and _dock_drift.is_empty():
		if not LayoutInput.same_stack(stack, _first_dock["stack"]):
			_dock_drift = "The rendered dock moved at frame %d." % Engine.get_process_frames()


func _snapshot() -> Dictionary:
	var row: Dictionary = _screen.call("geometry")
	row["frame"] = Engine.get_process_frames()
	row["stack"] = _entry.painted_stack()
	row["intro_phase"] = _screen.get("_combat_objective_hud").get("intro_phase")
	return row


func _record(phase: String, row: Dictionary) -> void:
	var shot: Dictionary = JSON.parse_string(_options["--shot"])
	print("POL63_ENTRY ", JSON.stringify({
		"case": shot["shot"], "entry": shot["entry"], "phase": phase,
		"seed": _result["run_seed"], "size": _options["--size"], "ui_scale": _result["ui_scale"],
	}.merged(row)))


func _validate_entry(idle: Dictionary, shot: Dictionary) -> String:
	var captured: Dictionary = _screen.get("capture")
	if captured.is_empty():
		return "The opening dock was never captured."
	if not shot.get("force_unframed", false) and (not captured["budget_current"] or not captured["framing_applied"] or not captured["board_current"] or captured["board_mode"] != "combat"):
		return "Opening dock was captured before the combat board was framed."
	if _first_paint.is_empty() or _first_dock.is_empty():
		return "The first painted stack or dock frame was not observed."
	if shot.get("deadline_proof"):
		var error: String = _validate_deadline(captured, idle, shot)
		if not error.is_empty(): return error
	for key: String in idle["stack"]:
		if not LayoutInput.same_rect(_first_dock["stack"][key], idle["stack"][key]):
			return "First docked %s differs from its settled rectangle." % key
		if not _first_paint["stack"][key].is_empty() and not LayoutInput.same_rect(_first_paint["stack"][key], idle["stack"][key]):
			return "First painted %s differs from its settled rectangle." % key
	return _dock_drift


func _validate_deadline(captured: Dictionary, idle: Dictionary, shot: Dictionary) -> String:
	var limit: int = 30
	var first_attempt: int = captured["first_attempt"]
	var painted_after: int = _first_paint["render_frame"] - first_attempt
	if first_attempt < 0 or painted_after > limit:
		return "The dock missed its first-visible deadline."
	if not is_equal_approx(_result["ui_scale"], shot.get("ui_scale", 1.0)):
		return "The requested UI scale was not applied."
	if shot["entry"] == "door" and idle["intro_phase"] != "settled":
		return "The door-entry objective intro did not finish."
	var retries: Array = captured["retry_frames"]
	if shot.get("force_unframed"):
		if captured["wait_frames"] != limit or painted_after != limit or retries.size() != limit:
			return "The fallback must capture and paint on the thirtieth retry frame."
		for index: int in range(retries.size()):
			if retries[index] != first_attempt + index + 1:
				return "The fallback missed a frame between its first attempt and capture."
	elif captured["wait_frames"] >= limit:
		return "A normal entry used the fallback."
	return ""
