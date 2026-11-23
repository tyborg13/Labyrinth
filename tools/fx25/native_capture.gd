extends "res://tools/fx20/native_capture.gd"
## Real resolver steps presented by RunScene on the existing 60 Hz proof clock.

const Cases25 = preload("res://tools/fx25/cases.gd")
const REEL_FRAMES := 4 * FPS
const CONTACT_EPSILON := 0.0001
const UNSET := -1

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if not (Cases25.NATIVE.has(id) or id == Cases25.REEL) or output.is_empty():
		_fail("Provide a native FX-25 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx25/native.sh for a native 60 fps cel-look take.")
		return
	var report: Dictionary = await take_case(id, output, "", false)
	if not report.is_empty(): quit()

func _build_case() -> Dictionary:
	var reel: bool = _id == Cases25.REEL
	var first: String = "area_ranged" if reel else _id
	var config: Array = Cases25.CASES[first]
	var melee: Array = Cases25.CASES["closing_shade"]
	_opponent_tile = config[3]
	_aim = Cases25.HERO
	_card = ""
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": FILLER, "draw": FILLER_DRAW,
		"player_hp": Cases20.PROOF_HP, "player_max_hp": Cases20.PROOF_HP, "player_position": Cases20.coords(_aim),
		"enemy_types": config[0], "enemy_intents": config[1], "enemy_positions": Cases20.coords(_opponent_tile),
		"umbra_stage": "clear"}
	if reel:
		_options["enemy_types"] += "," + melee[0]
		_options["enemy_intents"] += "," + melee[1]
		_options["enemy_positions"] += "," + Cases20.coords(melee[3])
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	Cases25.configure(first, state)
	var ids: Array[String] = [first]
	if reel: ids.append("closing_shade")
	var beats: Array[Dictionary]
	var before: Dictionary = state
	for index: int in ids.size():
		var resolved: Dictionary = Cases25.step(ids[index], _combat_engine, before, index)
		var step: Dictionary = resolved.get("step", {})
		var hit: Dictionary = Cases25.impact_step(step)
		var tiles: Array[Vector2i] = Cases25.targets(step)
		if hit.get("element") != "shadow" or tiles.is_empty():
			push_error("Missing resolved Shadow impact for %s: %s" % [ids[index], step.get("kind")])
			return {}
		_steps.append(step)
		for tile: Vector2i in tiles:
			if not _take_targets.has(tile): _take_targets.append(tile)
		var after: Dictionary = resolved["after"]
		var terrain_losses: Array = hit.get("terrain_losses", [])
		beats.append({"id": ids[index], "action": hit["action_type"], "actor": hit["actor_key"],
			"center": Cases20.coords(hit.get("center", hit["to"])), "target": Cases20.coords(hit["to"]),
			"tiles": tiles.map(Cases20.coords),
			"hidden": tiles.filter(func(tile: Vector2i) -> bool: return not _combat_engine.is_tile_visible_to_player(after, tile)).map(Cases20.coords),
			"losses": _losses(before, after), "terrain_lost": terrain_losses.map(func(loss: Dictionary) -> String: return Cases20.coords(loss["tile"])),
			"contact": UNSET, "contact_phase": 0.0, "samples": {}, "pairs": {}, "flight": {}, "hits": {}, "legacy": {},
			"replace_targeted": false})
		before = after
	return {"run": run, "profile": profile, "beats": beats}

func _observe_frame(board: Control, frame: int) -> void:
	var shown: Dictionary = board.presentation
	var effect: Dictionary = shown.get("effect", {})
	var phase: float = float(shown.get("effect_progress", 0.0))
	var beat: Dictionary = {}
	for candidate: Dictionary in _take_fixture["beats"]:
		if candidate["actor"] == effect.get("actor_key") and candidate["action"] == effect.get("action_type", effect.get("kind")):
			beat = candidate
			var threshold: float = _run._attack_feedback_start_progress(effect)
			beat["samples"][frame] = phase
			if beat["contact"] == UNSET and (_reduced or phase + CONTACT_EPSILON >= threshold):
				beat["contact"] = frame
				beat["contact_phase"] = phase
			beat["replace_targeted"] = effect.get(Fx.REPLACE_TARGETED, false)
			if effect.get("kind") == "aoe" and not effect.get(Fx.ACTIVE, false) and board._aoe_resolution_footprint_visibility(effect, phase) > 0.0:
				_note_legacy(beat, "area_wash", frame)
			var profile: Dictionary = Dragon.profile(effect)
			if profile.get("geometry") in ["breath", "ground"]:
				if phase >= Dragon.RELEASE and phase < 0.72 and profile["geometry"] == "breath" and not _reduced:
					_note_legacy(beat, "dragon_shadow_stream", frame)
				if _reduced or phase >= Dragon.CONTACT: _note_legacy(beat, "dragon_shadow_impact", frame)
			break
	if beat.is_empty():
		var adapter: Dictionary = shown.get(Shot20.ADAPTER_FLIGHT, {})
		var flight: Dictionary = adapter.get("effect", {})
		for candidate: Dictionary in _take_fixture["beats"]:
			if candidate["contact"] != UNSET: beat = candidate
			elif candidate["actor"] == flight.get("actor_key") and candidate["action"] == flight.get("action_type", flight.get("kind")):
				beat = candidate
				phase = float(adapter["progress"])
	if beat.is_empty(): return
	for decal: Dictionary in shown.get("impact_decals", []):
		if decal.get("element") == "shadow" and not decal.get("baked_strike", false) and board._board_tile_is_visible_to_player(decal["tile"]):
			_note_legacy(beat, "decal:" + Cases20.coords(decal["tile"]), frame)
	var shot: RefCounted = board._single_shot_fx
	if shot._shot_id == "shade" and shot._heads[0].visible:
		var cell: Vector2i = board._nearest_tile_for_world_position(board.get_global_transform().affine_inverse() * shot._heads[0].global_position)
		beat["flight"][frame] = {"tile": Cases20.coords(cell), "row": "shade", "phase": phase}
	for stamp: Node in shot._hits:
		if stamp.lifetime_start < 0 or stamp.hit_id != "hit_gloom": continue
		var key: String = "%d:%d" % [stamp.get_instance_id(), stamp.lifetime_start]
		beat["hits"].get_or_add(key, {"row": stamp.hit_id, "tile": Cases20.coords(stamp.hit_tile), "frame": frame})
	for stamp: Node in board._tile_bursts._stamps:
		var row: String = _row_names.get(stamp.sample.y, "")
		if not row.begins_with("shadow_"): continue
		var key: int = stamp.get_instance_id()
		if not _seen_stamps.has(key): _seen_stamps[key] = beat
		var owner: Dictionary = _seen_stamps[key]
		var entry: Dictionary = owner["pairs"].get_or_add(key, {"row": row, "tile": Cases20.coords(stamp.tile),
			"submitted": frame, "first_visible": UNSET, "delay": stamp.birth - board._tile_bursts._seconds,
			"still": UNSET})
		if entry["first_visible"] == UNSET and stamp.sample.x >= 0:
			entry["first_visible"] = frame
			if stamp.reduced: entry["still"] = stamp.sample.x

func _note_legacy(beat: Dictionary, path: String, frame: int) -> void:
	var interval: Array = beat["legacy"].get_or_add(path, [frame, frame])
	interval[1] = frame

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var bounds := Rect2(board._tile_center(_aim), Vector2.ZERO)
	for tile: Vector2i in _take_targets: bounds = bounds.expand(board._tile_center(tile))
	var center: Vector2 = board.get_global_transform_with_canvas() * bounds.get_center()
	var origin := Vector2i(center.round()) - CropSize / 2
	var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
	var strip: Image
	var raw: FileAccess
	if not _plan:
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open the FX-25 recording stream.")
				return {}
		else:
			strip = Image.create_empty(CropSize.x * CONTACT_COLUMNS.size(), CropSize.y, false, Image.FORMAT_RGB8)
	var columns: Dictionary
	var reel_frames: int = 0
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_case()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and _ended_at == UNSET: _ended_at = frame
		_observe_frame(board, frame)
		var contact: int = _take_fixture["beats"][0]["contact"]
		var column: int = UNSET if contact == UNSET or _record else CONTACT_COLUMNS.find(frame - contact)
		if column >= 0: columns[column] = frame
		var reel_frame: bool = _record and reel_frames < REEL_FRAMES
		if not _plan and (column >= 0 or reel_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected a 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if reel_frame:
				raw.store_buffer(image.get_data())
				if _take_fixture["beats"].any(func(beat: Dictionary) -> bool: return beat["contact"] == frame):
					var evidence: String = "area-contact.png" if frame == contact else "melee-contact.png"
					if not _save(image, evidence): return {}
			else:
				strip.blit_rect(image, crop, Vector2i(column * CropSize.x, 0))
				if column == 0 and not _save(image, "native-evidence.png"): return {}
		if reel_frame: reel_frames += 1
		if _ended_at >= 0 and (reel_frames == REEL_FRAMES if _record else columns.size() == CONTACT_COLUMNS.size()): break
	if _ended_at < 0 or (reel_frames != REEL_FRAMES if _record else columns.size() != CONTACT_COLUMNS.size()):
		_fail("FX-25 did not finish take " + _id)
		return {}
	if raw != null: raw.close()
	if strip != null and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _id, "frames": stats.get("authored_frames", 0), "rendered": stats.get("rendered_frames", 0),
		"duration_usec": stats.get("authored_duration_usec", 0), "done": _ended_at, "beats": _take_fixture["beats"],
		"columns": columns, "reel_frames": reel_frames}
