extends "res://tools/fx25/native_capture.gd"

const Maquette = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Sockets = preload("res://scripts/maquette_cutout_runtime/effect_sockets.gd")
const STRIPS: Array[String] = ["shade_bolt", "echo", "veil_needle", "area_ranged"]
const FOG_CASES: Array[String] = ["hidden_source", "hidden_target"]
const FOG_TARGET := Vector2i(4, 3)
const FOG_TARGET_HERO := Vector2i(4, 5)
const RETALIATE_CASE := "echo_retaliate"
const FLIGHT_COLUMNS: Array[float] = [0.0, 1.0 / 3.0, 2.0 / 3.0]

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if (id not in STRIPS and id != Cases25.REEL) or output.is_empty():
		_fail("Provide an FX-27 native case and output directory.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx27/native.sh for a native 60 fps cel-look take.")
		return
	var base: String = _arg("--base-dir")
	var report: Dictionary = await take_case(id, output, base, false)
	if report.is_empty(): return
	var beat: Dictionary = report["beat"]
	var missing_flight: bool = not base.is_empty() and id in ["shade_bolt", "echo"]
	var hit_count: int = 0 if not base.is_empty() and id == "area_ranged" else 1
	if beat["flight"].is_empty() != missing_flight or beat["hits"].size() != hit_count or not beat["legacy"].is_empty():
		_fail("FX-27 native take has unexpected shot, contact, or decal submissions: " + id)
		return
	quit()

func _build_case() -> Dictionary:
	var id: String = _id
	if id == Cases25.REEL or id in FOG_CASES: _id = "shade_bolt"
	elif id == RETALIATE_CASE: _id = "echo"
	var fixture: Dictionary = super._build_case()
	_id = id
	if fixture.is_empty(): return {}
	var beat: Dictionary = fixture["beats"][0]
	beat.merge({"scheduled_release": UNSET, "authored_release": UNSET, "expected_release": UNSET, "authored_contact": UNSET,
		"shot_release": UNSET, "clip": [], "launch_at_hand": false, "aimed_centre": false,
		"retaliate": {"frame": UNSET, "amount": 0}})
	if id in FOG_CASES and not _set_fog_case(fixture, beat):
		push_error("Missing resolved Umbra endpoint for " + id)
		return {}
	if id == RETALIATE_CASE and not _append_retaliate(fixture):
		push_error("Missing Echo's resolved Retaliate action.")
		return {}
	return fixture

func _append_retaliate(fixture: Dictionary) -> bool:
	var state: Dictionary = fixture["run"]["combat_state"]
	var first: Dictionary = Cases25.step("echo", _combat_engine, state)
	var before: Dictionary = first["after"]
	var second: Dictionary = before["enemies"][0]["intent"]["actions"][1]
	var after: Dictionary = _combat_engine._resolve_enemy_action(before.duplicate(true), 0, second)
	var step: Dictionary = _combat_engine._enemy_action_step(before, after, 0, second)
	if step.get("kind") != "status" or not step.get("enemy_after", {}).has(RetaliateRules.STATE_KEY): return false
	_steps.append(step)
	return true

func _set_fog_case(fixture: Dictionary, beat: Dictionary) -> bool:
	var state: Dictionary = fixture["run"]["combat_state"]
	state["umbra"]["stage"] = "eclipse"
	state["umbra"]["stage_reduction"] = 0
	state["umbra"]["light_sources"] = []
	if _id == "hidden_source":
		_steps[0]["hidden_by_umbra"] = true
		return not _combat_engine.is_tile_visible_to_player(state, _opponent_tile)
	state["umbra"]["light_sources"] = [{"pos": _opponent_tile, "radius": 0}]
	state["player"]["pos"] = FOG_TARGET_HERO
	_combat_engine._create_illusion(state, FOG_TARGET, GameData.fixed_point_amount(Cases20.PROOF_HP))
	var resolved: Dictionary = Cases25.step("shade_bolt", _combat_engine, state)
	var step: Dictionary = resolved.get("step", {})
	if step.get("to") != FOG_TARGET or not _combat_engine.is_tile_visible_to_player(state, _opponent_tile) or _combat_engine.is_tile_visible_to_player(state, FOG_TARGET): return false
	_steps[0] = step
	_take_targets.assign([FOG_TARGET])
	beat["target"] = Cases20.coords(FOG_TARGET)
	beat["tiles"] = [beat["target"]]
	beat["hidden"] = beat["tiles"].duplicate()
	return true

func _observe_frame(board: Control, frame: int) -> void:
	super._observe_frame(board, frame)
	var beat: Dictionary = _take_fixture["beats"][0]
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	var shot: RefCounted = board._single_shot_fx
	if _id == RETALIATE_CASE and beat["retaliate"]["frame"] == UNSET:
		var actor: Dictionary = Maquette.actor_for(board.combat_state, beat["actor"])
		var amount: int = int(actor.get(RetaliateRules.STATE_KEY, {}).get("amount", 0))
		if amount > 0: beat["retaliate"] = {"frame": frame, "amount": amount}
	for decal: Dictionary in shown.get("impact_decals", []):
		var tile: Vector2i = decal.get("tile", Vector2i(-1, -1))
		if not decal.get("baked_strike", false) and beat["tiles"].has(Cases20.coords(tile)) and board._board_tile_is_visible_to_player(tile):
			_note_legacy(beat, "decal:" + Cases20.coords(tile), frame)
	if beat["contact"] == frame:
		beat["aimed_centre"] = shot._to_tile == _aim and shot._end_offset.is_zero_approx()
	var pose: Dictionary = shown.get("hollow_mimic_motion", {}).get(beat["actor"], {})
	var authored_frame: int
	if pose.get("clip") == "bolt" and beat["action"] == "ranged":
		var frames: int = Maquette.frames_for("hollow_mimic", "bolt")
		var limit: float = float(Maquette.data_for("hollow_mimic")["clips"]["bolt"]["contact"])
		var mark: int = ceili(limit * (frames - 1))
		var phase: float = pose["phase"]
		var pose_frame: float = phase * mark / limit if phase <= limit else mark + (phase - limit) * (frames - 1 - mark) / (1.0 - limit)
		authored_frame = 1 if _reduced else roundi(pose_frame) + 1
		var standard: int = ceili(Shot20.release_for(Attack.style_for_effect(_steps[0])) * frames)
		beat["expected_release"] = standard if standard <= mark else 16
	elif effect.get("actor_key") == beat["actor"]:
		var frames: int = int(shown.get("effect_frame_count", 1))
		authored_frame = roundi(float(shown.get("effect_progress", 0.0)) * frames)
		beat["expected_release"] = ceili(Shot20.release_for(Attack.style_for_effect(effect)) * frames)
	if beat["scheduled_release"] == UNSET and authored_frame > 0 and authored_frame >= beat["expected_release"]:
		beat["scheduled_release"] = frame
	if beat["contact"] == frame: beat["authored_contact"] = authored_frame
	if shot._shot_id != "shade" or not shot._heads[0].visible:
		return
	if beat["shot_release"] == UNSET:
		beat["shot_release"] = frame
		beat["authored_release"] = authored_frame
		var origin: Vector2 = board._tile_center(shot._from_tile)
		var fallback: Vector2 = origin + Vector2(0.0, -24.0)
		var socket: Vector2 = Sockets.launch_point(board, shot._effect, fallback)
		beat["launch_at_hand"] = not socket.is_equal_approx(fallback) and (origin + shot._launch_offset).is_equal_approx(socket)
		var count: int = int(shot._ink.get_shader_parameter("visible_span_count"))
		if shot._clip_enabled:
			for index: int in count:
				var span: Vector2 = shot._clip_spans[index]
				beat["clip"].append([span.x, span.y])
	# The previous observer only sees normal effect submissions, which the
	# adapter deliberately withholds until gameplay contact.
	beat["flight"][frame] = {"row": "shade", "phase": shot._last_progress}

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var bounds := Rect2(board._tile_center(_opponent_tile), Vector2.ZERO).expand(board._tile_center(_aim))
	for tile: Vector2i in _take_targets: bounds = bounds.expand(board._tile_center(tile))
	var centre: Vector2 = board.get_global_transform_with_canvas() * bounds.get_center()
	var crop := Rect2i((Vector2i(centre.round()) - CropSize / 2).clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
	var raw: FileAccess
	if _record and not _plan:
		raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Could not open the FX-27 recording stream.")
			return {}
	var crops: Dictionary
	var reel_frames: int
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_case()
	var beat: Dictionary = _take_fixture["beats"][0]
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and _ended_at == UNSET: _ended_at = frame
		_observe_frame(board, frame)
		var end: int = beat["contact"] + CONTACT_COLUMNS[-1] if beat["contact"] != UNSET else TAKE_LIMIT
		var reel_frame: bool = _record and reel_frames < REEL_FRAMES
		var strip_frame: bool = not _record and beat["scheduled_release"] != UNSET and frame <= end
		if not _plan and (reel_frame or strip_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected a 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if reel_frame: raw.store_buffer(image.get_data())
			else: crops[frame] = image.get_region(crop)
			if frame == beat["contact"] and not _save(image, "native-evidence.png"): return {}
		if reel_frame: reel_frames += 1
		if _ended_at != UNSET and (reel_frames == REEL_FRAMES if _record else frame >= end): break
	if raw != null: raw.close()
	if _ended_at == UNSET or beat["contact"] == UNSET or (_record and reel_frames != REEL_FRAMES):
		_fail("FX-27 did not finish take " + _id)
		return {}
	var release: int = beat["scheduled_release"] if beat["scheduled_release"] != UNSET else beat["contact"]
	var contact: int = beat["contact"]
	var columns: Array[int]
	for fraction: float in FLIGHT_COLUMNS: columns.append(roundi(lerpf(release, contact, fraction)))
	for tail: int in CONTACT_COLUMNS: columns.append(contact + tail)
	if not _plan and not _record:
		var strip := Image.create_empty(CropSize.x * columns.size(), CropSize.y, false, Image.FORMAT_RGB8)
		for column: int in columns.size():
			strip.blit_rect(crops[columns[column]], Rect2i(Vector2i.ZERO, CropSize), Vector2i(CropSize.x * column, 0))
		if not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _id, "frames": stats.get("authored_frames", 0), "rendered": stats.get("rendered_frames", 0),
		"duration_usec": stats.get("authored_duration_usec", 0), "done": _ended_at, "beat": beat,
		"columns": columns, "reel_frames": reel_frames}
