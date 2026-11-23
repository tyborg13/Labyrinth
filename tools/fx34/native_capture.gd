extends "res://tools/fx18/native_capture.gd"

const Fixture = preload("res://tools/fx34/cases.gd")
const Audit = preload("res://tools/fx34/audit.gd")
const ShotFx = preload("res://scripts/shot_fx.gd")
const CROP := Vector2i(640, 640)
const SPARK_OFFSETS: Array[int] = [0, 2, 4, 6, 10, 18]
const MISSED_OFFSETS: Array[int] = [0, 4, 8, 14, 22, 30]
const SPARK_EVIDENCE_COLUMN: int = 3
const MISS_EVIDENCE_COLUMN: int = 2
const BASE_MISS_EVIDENCE_COLUMN: int = 3
const REEL_PART_FRAMES: int = 3 * FPS
const TAIL_FRAMES: int = 32

var _origin: int
var _resolved_case: Dictionary
var _missed_state: Dictionary
var _ledger: Array[Dictionary]
var _stamps: Dictionary
var _shots: Dictionary
var _submissions: Dictionary
var _column_frames: Array[int]

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if id not in Fixture.NATIVE_CASES or not output.is_absolute_path():
		_fail("Provide an FX-34 case and absolute --out directory.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx34/native.sh for a 60 fps native cel-look take.")
		return
	_record = OS.get_cmdline_user_args().has("--record")
	if not (await take_case(id, output, false)).is_empty():
		print(output)
		quit()

func take_case(id: String, output: String, reduced: bool) -> Dictionary:
	_case = id
	_output = output
	_reduced = reduced
	_origin = -1
	_complete = false
	_ledger.clear()
	_stamps.clear()
	_shots.clear()
	_submissions.clear()
	_column_frames.clear()
	DirAccess.make_dir_recursive_absolute(output)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	_options = Fixture.options(id, DEFAULT_SEED)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty():
		_fail("Could not build " + id)
		return {}
	Fixture.configure(id, run["combat_state"])
	if not await _start_take({"run": run, "profile": profile}):
		_fail("Could not resume " + id)
		return {}
	_viewport.audio_listener_enable_2d = true
	var report: Dictionary = await _observe_fx34()
	_viewport.queue_free()
	await process_frame
	if report.is_empty(): return {}
	var report_path: String = output.path_join("take.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write " + report_path)
		return {}
	file.store_string(JSON.stringify(report, "\t"))
	print("FX-34 TAKE " + report_path)
	return report

func _drive_action() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	var chain: bool = _case in Fixture.CHAIN_CASES
	var card: String = Fixture.SPARK if chain else Fixture.FINISHER
	var aim: Vector2i = Fixture.Witness.PRIMARY if chain else Fixture.Witness.TICK
	var action: Dictionary = Fixture.Witness.Data.card_def(card)["actions"][0].duplicate(true)
	action["_card_id"] = card
	_resolved_case = _combat_engine.resolve_player_action_for_presentation(state, action, aim)
	var after: Dictionary = _resolved_case["state"]
	_run._animation_lock = true
	_run._combat_pacing.begin_card()
	_run._begin_action_step_resolution_tracker(card, [action], [aim], false)
	await _run._animate_player_action_step(state, after, card, action, aim, _resolved_case["chain_hits"])
	_run._combat_pacing.end_scope()
	_run._combat_state = after
	_run._render_board_state(after, {})
	if not chain:
		if _combat_engine.combat_outcome(after) != "victory":
			_fail("The finisher did not resolve a victory.")
			return
		var salvaged: Array[String]
		if _case == "salvaged": salvaged.append(Fixture.SECOND_ID)
		_missed_state = await _run._animate_missed_equipment_resolution(after, salvaged)
	_run._animation_lock = false
	_complete = true

func _observe_fx34() -> Dictionary:
	var board: Control = _run.board_view
	var chain: bool = _case in Fixture.CHAIN_CASES
	var offsets: Array[int] = SPARK_OFFSETS if chain else MISSED_OFFSETS
	var evidence_column: int = MISS_EVIDENCE_COLUMN
	if chain: evidence_column = SPARK_EVIDENCE_COLUMN
	elif OS.get_cmdline_user_args().has("--baseline"): evidence_column = BASE_MISS_EVIDENCE_COLUMN
	var crop := Rect2i()
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(CROP.x * offsets.size(), CROP.y, false, Image.FORMAT_RGB8)
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open the reel stream.")
				return {}
	var done: int = -1
	var reel_frames: int = 0
	var first_movie_frame: int = -1
	_missed_state.clear()
	Audit.reset()
	Audit.headless = _plan
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_action()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and done < 0: done = frame
		_observe_frame(board, frame)
		if frame == _origin: crop = _crop(board, chain)
		var column: int = offsets.find(frame - _origin) if _origin >= 0 else -1
		if column >= 0: _column_frames.append(frame)
		var recording: bool = _record and frame < REEL_PART_FRAMES
		if recording:
			reel_frames += 1
			if first_movie_frame < 0: first_movie_frame = Engine.get_frames_drawn()
		if not _plan and (recording or column >= 0):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected the exact 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if recording: raw.store_buffer(image.get_data())
			if column >= 0:
				var visible: Rect2i = crop.intersection(Rect2i(Vector2i.ZERO, CanvasSize))
				strip.blit_rect(image, visible, Vector2i(column * CROP.x, 0) + visible.position - crop.position)
				if column == evidence_column and not _save(image, "native-evidence.png"): return {}
		if done >= 0 and _column_frames.size() == offsets.size() and frame >= done + TAIL_FRAMES and (not _record or reel_frames == REEL_PART_FRAMES):
			break
	Audit.active = false
	Audit.manual = false
	if raw != null: raw.close()
	if done < 0 or _column_frames.size() != offsets.size() or (_record and reel_frames != REEL_PART_FRAMES):
		_fail("Incomplete FX-34 take for " + _case)
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var paths: Array = _resolved_case["chain_hits"].map(func(hit: Dictionary) -> Dictionary:
		return {"kind": hit["kind"], "to": _coord(hit["to"]), "path": hit.get("path", []).map(_coord)})
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"done": done, "origin": _origin, "columns": _column_frames.duplicate(), "crop": str(crop),
		"evidence_frame": _column_frames[evidence_column],
		"movie_first_frame": first_movie_frame, "reel_frames": reel_frames,
		"paths": paths, "loot": _missed_state.get("loot", []), "missed": _missed_state.get("missed_equipment", []),
		"notice": _run.log_label.text, "clock": stats, "beats": Audit.beats.duplicate(true), "frames": _ledger.duplicate(true),
		"stamps": _stamps.values().duplicate(true), "shots": _shots.values().duplicate(true),
		"submissions": _submissions.duplicate(true), "items": Audit.items.values().duplicate(true),
		"painters": Audit.painters.duplicate(), "primitives": Audit.primitives.duplicate()}

func _observe_frame(board: Control, frame: int) -> void:
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	var progress: float = shown.get("effect_progress", 0.0)
	var index: int = effect.get("chain_index", 0)
	var missed: float = shown.get("missed_equipment_progress", -1.0)
	if _origin < 0 and (index == 1 or missed >= 0.0): _origin = frame
	var texts: Array = shown.get("floating_texts", [])
	_ledger.append({"kind": effect.get("kind", ""), "index": index, "progress": progress,
		"missed": missed, "texts": texts.duplicate(true)})
	if index == 1 or missed >= 0.0:
		_submissions.get_or_add(str(progress) if index == 1 else str(missed), frame)
		if _plan: _audit_draws(board, effect, missed)
	for stamp: Fx.Stamp in board._tile_bursts._stamps:
		if stamp.visible: _observe_stamp(board, stamp, frame, index, progress, missed)
	for shot: ShotFx.Stamp in board._single_shot_fx._hits:
		if shot.visible and shot.lifetime_start >= 0:
			var key: String = "%s/%s" % [shot.get_instance_id(), shot.lifetime_start]
			_shots.get_or_add(key, {"frame": frame, "tile": _coord(shot.hit_tile), "name": shot.hit_id})

func _observe_stamp(board: Control, stamp: Fx.Stamp, frame: int, index: int, progress: float, missed: float) -> void:
	var id: int = stamp.get_instance_id()
	if not _stamps.has(id):
		var scene_tile: CanvasItem = board._scene_render_layers_by_tile[stamp.tile]
		var unit: String = ""
		for actor: Dictionary in board._visible_units_cache:
			if not Rect2i(actor["pos"], board._resolved_unit_footprint(actor)).has_point(stamp.tile): continue
			unit = str(actor.get("key", "player"))
			scene_tile = board._scene_render_layers_by_tile[board._effective_unit_tile(actor)]
			break
		var parent: CanvasItem = stamp.get_parent()
		var depth: int = parent.get_index() - scene_tile.get_index()
		var sample: int = roundi(missed * 10.0) + 1 if missed >= 0.0 else roundi(progress * (1 if _reduced else 12))
		_stamps[id] = {"tile": _coord(stamp.tile), "row": stamp.sample.y, "front": stamp.front,
			"start": frame, "beat": index, "sample": sample, "unit": unit, "depth": depth,
			"z": parent.z_index + stamp.z_index - scene_tile.z_index, "cells": []}
	var cells: Array = _stamps[id]["cells"]
	if not cells.has(stamp.sample.x): cells.append(stamp.sample.x)
	_stamps[id]["last"] = frame
	_stamps[id]["last_age"] = snappedf(board._tile_bursts._seconds - stamp.birth, 0.000001)
	_stamps[id]["last_delta"] = snappedf(board.get_process_delta_time(), 0.000001)

func _audit_draws(board: Control, effect: Dictionary, missed: float) -> void:
	Audit.manual = true
	if effect.get("kind") == "chain" and board.has_method("_surface_conduction_alpha") and board.call("_surface_conduction_alpha") > 0.0:
		var dependencies = preload("res://scripts/board_surface_render_dependencies.gd")
		for tile: Vector2i in dependencies.changed_tiles({}, board.presentation, {"effect": true}):
			if board._board_tile_is_visible_to_player(tile): board.call("_draw_surface_conduction_on", board, tile)
	if missed < 0.0:
		Audit.manual = false
		return
	board._prop_command_cache.recording = true
	board._prop_command_cache.commands = []
	for loot: Dictionary in board.combat_state.get("loot", []):
		var tile: Vector2i = loot["pos"]
		if not board._board_tile_is_visible_to_player(tile) or loot.get("claimed", false): continue
		if board._missed_equipment_disintegration_progress(loot) < 0.0: continue
		var texture: Texture2D = board._loot_texture(loot)
		if texture != null: board._draw_equipment_pickup(tile, board._loot_rect_for_tile(tile, texture, loot), texture, loot)
	board._prop_command_cache.recording = false
	board._prop_command_cache.commands = []
	Audit.manual = false

func _crop(board: Control, chain: bool) -> Rect2i:
	var center: Vector2 = board._tile_center(Fixture.FIRST_GEAR)
	if chain:
		center = board._tile_center(Fixture.Witness.PRIMARY).lerp(board._tile_center(Fixture.Witness.CONDUCTION_TARGET), 0.5)
	return Rect2i(Vector2i((board.get_global_transform_with_canvas() * center).round()) - CROP / 2, CROP)
