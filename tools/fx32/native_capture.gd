extends "res://tools/fx18/native_capture.gd"
## The native and headless takes read the same RunScene submissions.

const ForceCases = preload("res://tools/fx32/cases.gd")
const Shot = preload("res://scripts/shot_fx.gd")
const REEL_FRAMES := 6 * FPS
const TAIL_FRAMES := 14
const CONTACT_HOLD := 6
const NO_SAMPLE := -1
const PHASE_EPSILON := 0.0001
const CELLS := Vector2i(640, 360)
const STRIP_NAMES: Array[String] = ["release", "travel-third", "travel-two-thirds", "contact", "contact-plus-100ms", "contact-plus-233ms"]

var _beat: Dictionary
var _reports: Array[Dictionary]
var _printed_rows: Dictionary
var _seen_stamps: Dictionary
var _seen_hits: Dictionary

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if not (id in ForceCases.STRIPS or id == ForceCases.REEL) or output.is_empty():
		_fail("Provide a native FX-32 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx32/native.sh for a native 60 fps cel-look take.")
		return
	var result: Dictionary = await take(id, output, false)
	if result.is_empty(): return
	print(_output)
	quit()

func take(id: String, output: String, reduced: bool) -> Dictionary:
	_case = id
	_output = ProjectSettings.globalize_path(output).simplify_path()
	_reduced = reduced
	_record = id == ForceCases.REEL
	_complete = false
	_beat = {}
	_reports.clear()
	_seen_stamps.clear()
	_seen_hits.clear()
	_printed_rows.clear()
	for row: String in Fx.metadata()["rows"]:
		_printed_rows[int(Fx.metadata()["rows"][row])] = row
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	_options = ForceCases.options(id, DEFAULT_SEED, FILLER, FILLER_DRAW)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty():
		_fail("Could not build " + id)
		return {}
	ForceCases.configure(id, run["combat_state"])
	if not await _start_take({"run": run, "profile": profile}): return {}
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	var result: Dictionary = await _capture()
	_viewport.queue_free()
	await process_frame
	if result.is_empty(): return {}
	var file := FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write take.json.")
		return {}
	file.store_string(JSON.stringify(result, "\t"))
	print("FX-32 TAKE " + _output.path_join("take.json"))
	return result

func _drive_take() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	if _record:
		state = await _player_beat("lodestone_reversal", state, ForceCases.FAR)
		if _failed: return
		state = await _player_beat("cold_shoulder", state, state["enemies"][0]["pos"])
		if _failed: return
		state = await _player_beat("root_snare", state, state["enemies"][0]["pos"])
		if _failed: return
		# Move the proof room to Eclipse for the final attack. The same board,
		# enemies, Health and resolved displacements carry across every beat.
		ForceCases.fog(state)
		_run._render_board_state(state, {})
		await _enemy_beat("lash_hidden", state, 1)
	elif ForceCases.CASES[_case].has("card"):
		await _player_beat(_case, state, ForceCases.CASES[_case]["tile"])
	else:
		await _enemy_beat(_case, state, 0)
	_run._animation_lock = false
	_complete = true

func _player_beat(id: String, state: Dictionary, aim: Vector2i) -> Dictionary:
	var resolved: Dictionary = ForceCases.resolve_player(id, _combat_engine, state, aim)
	if resolved.is_empty():
		_fail("The resolver rejected %s at %s" % [id, aim])
		return {}
	var card: String = ForceCases.CASES[id]["card"]
	var action: Dictionary = resolved["action"]
	_open_beat(id, action["type"], state["player"]["pos"], aim, state, resolved["after"])
	_run._combat_pacing.begin_card()
	_run._begin_action_step_resolution_tracker(card, [action], [aim], false)
	await _run._animate_player_action_step(state, resolved["after"], card, action, aim, resolved["chain_hits"])
	_run._combat_pacing.end_scope()
	_run._combat_state = resolved["after"]
	_run._render_board_state(resolved["after"], {})
	return resolved["after"]

func _enemy_beat(id: String, state: Dictionary, index: int) -> void:
	var resolved: Dictionary = ForceCases.resolve_enemy(id, _combat_engine, state, index)
	if resolved.is_empty() or resolved["step"].is_empty():
		_fail("No resolved enemy attack for " + id)
		return
	var step: Dictionary = resolved["step"]
	_open_beat(id, step.get("action_type", step["kind"]), step["from"], step["to"], state, resolved["after"])
	_beat["hidden_source"] = bool(step.get("hidden_by_umbra", false))
	_run._combat_pacing.begin_enemies()
	await _run._animate_enemy_phase_steps(state, resolved["steps"], resolved["after"])
	_run._combat_pacing.end_scope()

func _open_beat(id: String, action: String, from: Vector2i, to: Vector2i, before: Dictionary, after: Dictionary) -> void:
	var hits: Dictionary = Fx.step_hit_tiles(before, after, _run.board_view._resolved_unit_footprint)
	Fx.include_event_hits(hits, _run._surface_events_between(before, after), before)
	_beat = {"id": id, "action": action, "start": NO_SAMPLE, "release": NO_SAMPLE, "contact": NO_SAMPLE,
		"text": {}, "last": NO_SAMPLE, "shot": "", "flight": {}, "hits": [], "bursts": [], "phases": {},
		"from": ForceCases.cell(from), "to": ForceCases.cell(to), "hidden_source": false,
		"target_hit": hits.has(to), "columns": {}}
	_reports.append(_beat)

func _capture() -> Dictionary:
	var board: Control = _run.board_view
	var strip: Image
	var raw: FileAccess
	if not _plan and _record:
		raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Could not open the FX-32 reel stream.")
			return {}
	elif not _plan:
		strip = Image.create_empty(CanvasSize.x, CanvasSize.y, false, Image.FORMAT_RGB8)
	var done: int = NO_SAMPLE
	var reel_frames: int = 0
	_drive_take()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _failed: return {}
		if _complete and done == NO_SAMPLE: done = frame
		_observe_playback(board, frame)
		var column: int = _strip_column(frame)
		var record_frame: bool = _record and frame < REEL_FRAMES
		if record_frame: reel_frames += 1
		if not _plan and (column >= 0 or record_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected the full 1920x1080 RunScene framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if record_frame:
				raw.store_buffer(image.get_data())
				if frame == _beat.get("contact") and not _save(image, _beat["id"] + "-contact.png"): return {}
			else:
				if not _save(image, STRIP_NAMES[column] + ".png"): return {}
				image.resize(CELLS.x, CELLS.y, Image.INTERPOLATE_LANCZOS)
				@warning_ignore("integer_division")
				var offset := Vector2i((column % 3) * CELLS.x, (column / 3) * CELLS.y + (CanvasSize.y - 2 * CELLS.y) / 2)
				strip.blit_rect(image, Rect2i(Vector2i.ZERO, CELLS), offset)
		if done >= 0 and (reel_frames == REEL_FRAMES if _record else frame >= done + TAIL_FRAMES): break
	if raw != null: raw.close()
	if done < 0 or _reports.is_empty() or _reports.any(func(beat: Dictionary) -> bool: return beat["contact"] < 0):
		_fail("Incomplete FX-32 take " + _case)
		return {}
	if _record and (reel_frames != REEL_FRAMES or _reports[-1]["contact"] >= REEL_FRAMES):
		_fail("The FX-32 reel must capture all four contacts.")
		return {}
	if not _record and not _reduced and _case in ForceCases.STRIPS and _beat["columns"].size() != STRIP_NAMES.size():
		_fail("Missing FX-32 strip frames for " + _case + ": " + str(_beat["columns"]))
		return {}
	if strip != null and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"done": done, "authored_frames": stats.get("authored_frames"), "rendered_frames": stats.get("rendered_frames"),
		"duration_usec": stats.get("authored_duration_usec"), "reel_frames": reel_frames, "beats": _reports.duplicate(true)}

func _strip_column(frame: int) -> int:
	if _record or _reduced or _case not in ForceCases.STRIPS: return NO_SAMPLE
	var column: int = NO_SAMPLE
	if _beat.get("contact", NO_SAMPLE) >= 0:
		match frame - int(_beat["contact"]):
			0: column = 3
			CONTACT_HOLD: column = 4
			TAIL_FRAMES: column = 5
	elif _beat.get("release", NO_SAMPLE) >= 0:
		var phase: float = _beat["phases"].get(frame, -1.0)
		for index: int in range(3):
			if _beat["columns"].has(STRIP_NAMES[index]): continue
			var goal: float = lerpf(_beat["release_phase"], _beat["contact_phase"], float(index) / 3.0)
			if phase + PHASE_EPSILON >= goal: column = index
			break
	if column >= 0: _beat["columns"][STRIP_NAMES[column]] = frame
	return column

func _observe_playback(board: Control, frame: int) -> void:
	if _beat.is_empty(): return
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	var progress: float = shown.get("effect_progress", 0.0)
	var matches: bool = effect.get("action_type", effect.get("kind", "")) == _beat["action"] and 		ForceCases.cell(effect.get("umbra_original_to", effect.get("to", Fx.INVALID))) == _beat["to"]
	if matches:
		if _beat["start"] < 0: _beat["start"] = frame
		_beat["last"] = frame
		_beat["phases"][frame] = progress
		_beat["release_phase"] = Shot.release_for(Attack.style_for_effect(effect))
		_beat["contact_phase"] = Shot.contact_for(effect)
		if _beat["release"] < 0 and progress + PHASE_EPSILON >= _beat["release_phase"]: _beat["release"] = frame
		if _beat["contact"] < 0 and (_reduced or progress + PHASE_EPSILON >= _beat["contact_phase"]):
			_beat["contact"] = frame
		var player = board._single_shot_fx
		if not player._shot_id.is_empty(): _beat["shot"] = player._shot_id
		if player._heads.any(func(head: Node2D) -> bool: return head.visible):
			_beat["flight"][frame] = player._shot_id
	if _beat["start"] < 0: return
	var texts: Array = shown.get("floating_texts", [])
	if not texts.is_empty(): _beat["text"][frame] = JSON.stringify(texts, "", true)
	for hit in board._single_shot_fx._hits:
		if hit.lifetime_start < 0: continue
		var key: String = "%s/%s" % [hit.get_instance_id(), hit.lifetime_start]
		if _seen_hits.has(key): continue
		_seen_hits[key] = true
		_beat["hits"].append({"tile": ForceCases.cell(hit.hit_tile), "row": hit.hit_id, "frame": frame})
	for stamp: Fx.Stamp in board._tile_bursts._stamps:
		var key: int = stamp.get_instance_id()
		var entry: Dictionary = _seen_stamps.get(key, {})
		if entry.is_empty():
			var row: String = str(_printed_rows.get(stamp.sample.y, ""))
			entry = {"tile": ForceCases.cell(stamp.tile), "row": row, "submitted": frame,
				"frame": NO_SAMPLE, "cell": NO_SAMPLE, "progress": progress,
				"tile_visible": board._board_tile_is_visible_to_player(stamp.tile), "front": stamp.front}
			_seen_stamps[key] = entry
			_beat["bursts"].append(entry)
		if stamp.visible and entry["frame"] < 0:
			entry["frame"] = frame
			entry["cell"] = stamp.sample.x
