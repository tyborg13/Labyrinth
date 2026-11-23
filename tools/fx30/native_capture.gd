extends "res://tools/fx18/native_capture.gd"
## Capture the same resolver playback in the native renderer and the headless clock.

const NoctyraxCases = preload("res://tools/fx30/cases.gd")
const REEL_FRAMES: int = 5 * FPS
const STRIP_COLUMNS: int = 5
const NO_FRAME: int = -1
const RELEASE_EPSILON: float = 0.0001

var _beats: Array[Dictionary]
var _stamp_owners: Dictionary

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if not (id in NoctyraxCases.STRIPS or id == NoctyraxCases.REEL) or output.is_empty():
		_fail("Provide a native FX-30 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx30/native.sh for a native 60 fps cel-look take.")
		return
	var report: Dictionary = await take_case(id, output)
	if not report.is_empty():
		print(output)
		quit()

func take_case(id: String, output: String) -> Dictionary:
	_case = id
	_output = output
	_reduced = id.ends_with("_reduced")
	_record = id == NoctyraxCases.REEL
	_complete = false
	_steps.clear()
	_targets.clear()
	_beats.clear()
	_stamp_owners.clear()
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = _reduced
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var fixture: Dictionary = NoctyraxCases.build(id, _run_engine, _combat_engine, profile, DEFAULT_SEED)
	_steps.assign(fixture["steps"])
	if not await _start_take(fixture): return {}
	_prepare_beats()
	if _beats.is_empty():
		_fail("No resolved attack for " + id + ": " + str(_steps.map(func(step: Dictionary) -> String: return str(step.get("kind")))))
		return {}
	var report: Dictionary = await _capture()
	_viewport.queue_free()
	await process_frame
	if report.is_empty(): return {}
	var file := FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write take.json.")
		return {}
	file.store_string(JSON.stringify(report, "\t"))
	print("FX-30 TAKE %s" % _output.path_join("take.json"))
	return report

func _prepare_beats() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	for step: Dictionary in _steps:
		var before: Dictionary = state.duplicate(true)
		_run._apply_animation_step(state, step)
		if step.get("kind") not in ["aoe", "ranged", "melee"]: continue
		var tiles: Array[Vector2i] = Dragon.tiles(step)
		var hits: Dictionary = Fx.hit_tiles(before, state, _run.board_view._resolved_unit_footprint)
		var hit_tiles: Array[Vector2i] = tiles.filter(func(tile: Vector2i) -> bool: return hits.has(tile))
		var player: Dictionary = before["player"]
		var player_after: Dictionary = state["player"]
		_beats.append({
			"step": step, "tiles": tiles, "hit_tiles": hit_tiles, "before": before, "after": state.duplicate(true),
			"report": {"action": step["action_type"], "intent": step["intent_id"], "kind": step["kind"], "profile": Dragon.profile(step),
				"release": NO_FRAME, "contact": NO_FRAME, "numbers": NO_FRAME, "phases": {}, "text": {}, "stamps": {},
				"tiles": tiles.map(_coord), "hit_tiles": hit_tiles.map(_coord), "visible_hits": [], "hidden_at_contact": [],
				"player_from": _coord(player["pos"]), "player_to": _coord(player_after["pos"]),
				"hp_loss": player["hp"] - player_after["hp"], "block_loss": player["block"] - player_after["block"],
				"terrain_before": before["terrain"].map(func(prop: Dictionary) -> int: return prop["hp"]),
				"terrain_after": state["terrain"].map(func(prop: Dictionary) -> int: return prop["hp"]),
				"illusions_after": _combat_engine._live_illusions(state).size(), "eclipse_activations": state["umbra"].get("boss_eclipse_activations", 0),
				"area_active": false, "shot_frames": 0}
		})
		for tile: Vector2i in tiles:
			if not _targets.has(tile): _targets.append(tile)

func _capture() -> Dictionary:
	var board: Control = _run.board_view
	var bounds := Rect2(board._tile_center(NoctyraxCases.HERO), Vector2.ZERO)
	for tile: Vector2i in _targets: bounds = bounds.expand(board._tile_center(tile))
	var center: Vector2 = board.get_global_transform_with_canvas() * bounds.get_center()
	var crop := Rect2i((Vector2i(center.round()) - DRAGON_CROP / 2).clamp(Vector2i.ZERO, CanvasSize - DRAGON_CROP), DRAGON_CROP)
	var strip: Image
	var raw: FileAccess
	if not _plan:
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open the FX-30 recording stream.")
				return {}
		else:
			strip = Image.create_empty(DRAGON_CROP.x * STRIP_COLUMNS, DRAGON_CROP.y, false, Image.FORMAT_RGB8)
	var columns: Dictionary
	var finished: int = NO_FRAME
	var reel_frames: int = 0
	var first: Dictionary = _beats[0]["report"]
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_take()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and finished == NO_FRAME: finished = frame
		_observe_frame(board, frame)
		var column: int = NO_FRAME
		if not _record:
			if first["release"] == frame and not _reduced: column = 0
			elif first["contact"] >= 0 and CONTACT_OFFSETS.has(frame - first["contact"]):
				column = 1 + CONTACT_OFFSETS.find(frame - first["contact"])
		if column >= 0: columns[column] = frame
		var record_frame: bool = _record and reel_frames < REEL_FRAMES
		if record_frame: reel_frames += 1
		if not _plan and (column >= 0 or record_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected the full 1920x1080 RunScene framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if record_frame:
				raw.store_buffer(image.get_data())
				for beat: Dictionary in _beats:
					if beat["report"]["contact"] == frame and not _save(image, beat["report"]["intent"] + "-contact.png"): return {}
			else:
				strip.blit_rect(image, crop, Vector2i(column * DRAGON_CROP.x, 0))
				if column == 1 and not _save(image, "native-evidence.png"): return {}
		if finished >= 0 and (reel_frames == REEL_FRAMES if _record else columns.size() == STRIP_COLUMNS - int(_reduced)): break
	if raw != null: raw.close()
	if finished < 0 or (reel_frames != REEL_FRAMES if _record else columns.size() != STRIP_COLUMNS - int(_reduced)):
		_fail("Incomplete FX-30 take %s: %s" % [_case, first])
		return {}
	if strip != null and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _case, "done": finished, "authored_frames": stats.get("authored_frames"),
		"rendered_frames": stats.get("rendered_frames"), "authored_duration_usec": stats.get("authored_duration_usec"),
		"columns": columns, "reel_frames": reel_frames, "steps": _steps.map(func(step: Dictionary) -> String: return step["kind"]),
		"summons": _steps.filter(func(step: Dictionary) -> bool: return step.get("kind") == "summon").map(
			func(step: Dictionary) -> Array: return step.get("spawned_enemies", []).map(func(unit: Dictionary) -> String: return unit["type"])),
		"beats": _beats.map(func(beat: Dictionary) -> Dictionary: return beat["report"])}

func _observe_frame(board: Control, frame: int) -> void:
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	var progress: float = shown.get("effect_progress", 0.0)
	for beat: Dictionary in _beats:
		var step: Dictionary = beat["step"]
		if effect.get("actor_key") != step.get("actor_key") or effect.get("action_type") != step.get("action_type") or effect.get("intent_id") != step.get("intent_id"): continue
		var report: Dictionary = beat["report"]
		report["phases"][frame] = progress
		if report["release"] < 0 and progress + RELEASE_EPSILON >= Dragon.RELEASE: report["release"] = frame
		if report["contact"] < 0 and (_reduced or progress + RELEASE_EPSILON >= _run._attack_feedback_start_progress(effect)):
			report["contact"] = frame
			report["visible_hits"] = beat["hit_tiles"].filter(board._board_tile_is_visible_to_player).map(_coord)
			report["hidden_at_contact"] = beat["tiles"].filter(func(tile: Vector2i) -> bool: return not board._board_tile_is_visible_to_player(tile)).map(_coord)
		var texts: Array = shown.get("floating_texts", [])
		if not texts.is_empty():
			if report["numbers"] < 0: report["numbers"] = frame
			report["text"][frame] = JSON.stringify(texts, "", true)
		report["area_active"] = bool(effect.get(Fx.ACTIVE, false))
		if not board._single_shot_fx._shot_id.is_empty(): report["shot_frames"] += 1
		if _plan:
			for stamp: Fx.Stamp in board._tile_bursts._stamps:
				var owner: String = _stamp_owners.get_or_add(stamp.get_instance_id(), report["intent"])
				if owner != report["intent"]: continue
				_observe_stamp(report["stamps"], stamp, frame, progress, board)
		break

func _observe_stamp(stamps: Dictionary, stamp: Fx.Stamp, frame: int, progress: float, board: Control) -> void:
	var entry: Dictionary = stamps.get_or_add(_coord(stamp.tile), {"submitted": frame, "progress": progress,
		"delay": stamp.birth - board._tile_bursts._seconds, "visible": NO_FRAME, "rows": {}, "instances": {},
		"visible_at_submission": board._board_tile_is_visible_to_player(stamp.tile)})
	var depth: String = "front" if stamp.front else "rear"
	entry["rows"][depth] = stamp.sample.y
	entry["instances"][str(stamp.get_instance_id())] = depth
	if stamp.visible and entry["visible"] < 0:
		entry["visible"] = frame
		entry["cell"] = stamp.sample.x
