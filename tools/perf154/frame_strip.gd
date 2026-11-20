extends "res://tools/perf154/probe.gd"
## Untimed frame-by-frame evidence. Headless mode emits paint inputs only.

const LAST_STRIP_FRAME: int = 8
const FULL_FRAME: int = 4
const BETWEEN_ACTION_FRAMES: int = 30
var _strip_origin_frame: int
var _representative_dir: String

func _run() -> void:
	_output = _argument("--output=")
	_representative_dir = _argument("--representatives=")
	var kind: String = _argument("--encounter=")
	var bundle: String = _argument("--fixtures=")
	var setup_check: bool = OS.get_cmdline_user_args().has("--headless-check")
	if _output.is_empty() or kind not in ENCOUNTERS or not FileAccess.file_exists(bundle) or setup_check != _headless:
		_finish("Frame strip requires --output, --encounter, --fixtures, and movie mode or --headless-check.")
		return
	if not _headless and (_representative_dir.is_empty() or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != CAPTURE_FPS):
		_finish("Native frame strips require --representatives and the 60 FPS movie clock.")
		return
	var archive: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(bundle))
	if archive.get("schema") != FIXTURE_SCHEMA or archive.get("seed") != SEED:
		_finish("Invalid perf134 fixture bundle.")
		return
	_fixtures = archive["cases"]
	_fixture_digest = FileAccess.get_sha256(bundle)
	_capture = kind
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = View.Settings.COMBAT_NORMAL
	settings["reduced_motion"] = false
	if not View.Settings.save_settings(settings):
		_finish("Could not save strip settings.")
		return
	_make_canvas()
	if not await _open(kind):
		_finish()
		return
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	if not await _prepare_select():
		_finish("Could not put the controller on the opening card.")
		return
	var chip: Button = _scene._selected_card_forecast_chip()
	if not is_instance_valid(chip) or not chip.is_visible_in_tree() or chip.disabled:
		_finish("The starting Pass control was not ready.")
		return
	_strip_origin_frame = Engine.get_process_frames()
	if _headless:
		# The dummy renderer cannot record a movie. Advance the real FadeDriver
		# against numbered frames so the semantic receipt includes painted alpha.
		var fade: Node = chip.get_node_or_null("PassForecastFocusTooltip/ForecastFade")
		if fade == null:
			_finish("The starting forecast panel is missing.")
			return
		fade.set("clock", _headless_movie_ticks)
	var actions: Dictionary = {}
	var settled_panels: Dictionary = {}
	actions["select"] = await _capture_action("select", JOY_BUTTON_A)
	var original_tile: Vector2i = _scene._hovered_board_tile
	if _scene._selected_card_index != OPENING_CARD_INDEX or not _scene._pending_target_tiles.has(original_tile):
		_finish("A failed to select a card and reach its initial aim.")
		return
	await _wait_frames(BETWEEN_ACTION_FRAMES)
	if (not _scene._selection_forecast_baseline and not _scene._selected_pass_work.settled(_scene)) or not _current_forecast_ready():
		_finish("A forecast failed to settle before retarget.")
		return
	settled_panels["select"] = _panel_witness(_scene._selected_card_forecast_chip())
	actions["retarget"] = await _capture_action("retarget", JOY_BUTTON_DPAD_RIGHT)
	if _scene._hovered_board_tile == original_tile or not _scene._pending_target_tiles.has(_scene._hovered_board_tile):
		_finish("D-pad failed to retarget to a different legal tile.")
		return
	await _wait_frames(BETWEEN_ACTION_FRAMES)
	if not _current_forecast_ready():
		_finish("Retarget forecast failed to settle before cancel.")
		return
	settled_panels["retarget"] = _panel_witness(_scene._selected_card_forecast_chip())
	actions["cancel"] = await _capture_action("cancel", JOY_BUTTON_B)
	if _scene._selected_card_index >= 0 or _scene._selected_pass_pending() or _scene._selected_card_forecast_chip().disabled:
		_finish("B failed to cancel selection and restore Pass.")
		return
	if not _scene._selection_forecast_baseline:
		await _check_early_retarget()
	var report: FileAccess = FileAccess.open(_output.path_join("frames.json"), FileAccess.WRITE)
	if report == null:
		_finish("Could not write the frame strip witness.")
		return
	report.store_string(JSON.stringify({"encounter": kind, "fixture_sha256": _fixture_digest,
		"movie": not _headless, "fps": CAPTURE_FPS, "size": [SIZE.x, SIZE.y],
		"ui_scale": 1.0, "actions": actions, "settled_panels": settled_panels}) + "\n")
	report.close()
	print("PERF-154 FRAME STRIP: PASS (%s, %d frames, %s)" % [
		kind, actions.size() * (LAST_STRIP_FRAME + 1), "paint inputs" if _headless else "native movie"])
	_finish()

func _headless_movie_ticks() -> int:
	return int(float(Engine.get_process_frames() - _strip_origin_frame) * 1000000.0 / float(CAPTURE_FPS))

func _check_early_retarget() -> void:
	await _wait_frames(BETWEEN_ACTION_FRAMES)
	if not await _prepare_select():
		_errors.append("Could not prepare retarget before the initial forecast.")
		return
	_button(JOY_BUTTON_A)
	_check_immediate_selection("early retarget")
	var initial_tile: Vector2i = _scene._hovered_board_tile
	_button(JOY_BUTTON_DPAD_RIGHT)
	await _wait_frames(1)
	if _scene._hovered_board_tile == initial_tile or not _current_forecast_ready():
		_errors.append("Early retarget did not publish its forecast on the first draw.")
	await _wait_frames(BETWEEN_ACTION_FRAMES)
	if _scene._selected_pass_work._revision >= 0 or not _current_forecast_ready():
		_errors.append("The initial forecast worker survived early retarget.")
	_button(JOY_BUTTON_B)

func _capture_action(action: String, button: int) -> Array[Dictionary]:
	var frames: Array[Dictionary]
	var before_frame: int = Engine.get_process_frames()
	_button(button)
	for index: int in range(LAST_STRIP_FRAME + 1):
		await _wait_frames(1)
		var frame: int = Engine.get_process_frames()
		if frame != before_frame + index + 1:
			_errors.append("%s omitted a frame at index %d" % [action, index])
			break
		if action == "retarget" and index == 0 and not _current_forecast_ready():
			_errors.append("Retarget forecast was absent on the first draw.")
		var witness: Dictionary = _frame_witness()
		witness["index"] = index
		witness["movie_frame"] = frame - _strip_origin_frame
		witness["clock_usec"] = _headless_movie_ticks() if _headless else Clock.ticks_usec(false)
		frames.append(witness)
		if not _headless:
			var picture: Image = _canvas.get_texture().get_image()
			picture.convert(Image.FORMAT_RGBA8)
			_save_frame(picture, _output.path_join("%s-%02d.png" % [action, index]))
			if index == FULL_FRAME:
				_save_frame(picture, _representative_dir.path_join(action + "-full.png"), true)
	return frames

func _save_frame(picture: Image, path: String, advertise: bool = false) -> void:
	if picture.get_size() != SIZE or picture.save_png(path) != OK:
		_errors.append("Could not capture " + path)
	elif advertise:
		print(path)

func _frame_witness() -> Dictionary:
	var chip: Button = _scene._selected_card_forecast_chip()
	var art: TextureRect = chip.get_node("PassForecastFrameArtHost")
	var edge: Control = chip.get_node("PassForecastContent/PassFocusEdgeCue")
	var action: Label = chip.get_node("PassForecastContent/PassActionLabel")
	return {
		"selected": _scene._selected_card_index, "aim": str(_scene._hovered_board_tile),
		"face": {"box": _rect(art.get_global_rect().merge(chip.get_global_rect())),
			"visible": chip.is_visible_in_tree(), "label": action.text,
			"state": str(chip.get_meta("pass_interaction_state", "")),
			"texture_state": str(art.get_meta("pass_forecast_art_state", "")),
			"tint": art.modulate.to_html(), "focus_edge": edge.is_visible_in_tree()},
		"panel": _panel_witness(chip),
	}

func _panel_witness(chip: Button) -> Dictionary:
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip")
	if panel == null: return {"box": [], "visible": false, "alpha": 0.0, "rows": []}
	return {"box": _rect(panel.get_global_rect()), "visible": panel.is_visible_in_tree(),
		"alpha": panel.modulate.a, "rows": panel.get_meta("forecast_rows", []).duplicate(true)}

func _rect(rect: Rect2) -> Array:
	var start: Vector2 = rect.position.floor()
	var end: Vector2 = rect.end.ceil()
	return [int(start.x), int(start.y), int(end.x), int(end.y)]
