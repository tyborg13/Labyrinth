extends "res://tools/fx20/native_capture.gd"
## A real RunScene and the fx-20 fixed capture clock for both revisions.

const Cases22 = preload("res://tools/fx22/cases.gd")
const SHALE_AREA_RELEASE: float = 0.38 # Original bloom release.
const _OBSERVED_RIGS: Array[String] = ["bile_bloomer_motion", "cinder_ooze_motion", "vaeloryx_motion"]

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if not Cases22.CASES.has(id) or output.is_empty():
		_fail("Provide an FX-22 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx22/native.sh for a native 60 fps cel-look take.")
		return
	var result: Dictionary = await take_case(id, output, _arg("--base-dir"), false)
	if not result.is_empty(): quit()

func _build_case() -> Dictionary:
	var config: Array = Cases22.CASES[_id]
	_opponent_tile = config[2]
	_aim = config[3]
	_card = ""
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": FILLER, "draw": FILLER_DRAW,
		"player_hp": Cases20.PROOF_HP, "player_max_hp": Cases20.PROOF_HP, "player_position": Cases20.coords(_aim),
		"enemy_types": config[0], "enemy_intents": config[1], "enemy_positions": Cases20.coords(_opponent_tile), "umbra_stage": "clear"}
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	Cases22.configure(_id, _combat_engine, state)
	var step: Dictionary = Cases20.enemy_step(_combat_engine, state, config[4], false)
	if step.is_empty() or step.get("kind") != config[4]:
		push_error("FX-22 resolver did not yield a %s step for %s: %s" % [config[4], _id, step.get("kind")])
		return {}
	_steps.append(step)
	_wanted_effect = step["action_type"]
	_take_targets = Cases22.targets(_id, step)
	return {"run": run, "profile": profile, "shots": [], "tile_pairs": {}, "rig": {}, "slide": {},
		"player_from": Cases20.coords(step["player_from"]), "player_to": Cases20.coords(step["player_to"]),
		"terrain_losses": step.get("terrain_losses", [])}

func _watch(board: Control, frame: int, shown: Dictionary) -> void:
	super._watch(board, frame, shown)
	var shot: RefCounted = board._single_shot_fx
	if not shot._shot_id.is_empty() and shot._heads[0].visible:
		var cell: Vector2i = board._nearest_tile_for_world_position(board.get_global_transform().affine_inverse() * shot._heads[0].global_position)
		var source: Vector2 = board._tile_center(shot._from_tile) + shot._launch_offset
		var socket: Variant = board._bile_bloomer_socket_world(shown.get("effect", {}))
		_take_fixture["shots"].append({"frame": frame, "tile": Cases20.coords(cell), "target": Cases20.coords(shot._to_tile),
			"design": shot._shot_id, "progress": shown["effect_progress"], "source": str(source), "from_socket": socket is Vector2 and source.is_equal_approx(socket)})
	for stamp: Node in shot._hits:
		if stamp.lifetime_start >= 0 and stamp.reduced:
			_take_fixture["shot_still"] = int(float(stamp._frame_rect.x) / stamp._frame_rect.z)
	for stamp: Node in board._tile_bursts._stamps:
		var key: String = Cases20.coords(stamp.tile) + ("_front" if stamp.front else "_rear")
		var entry: Dictionary = _take_fixture["tile_pairs"].get_or_add(key, {
			"added": frame, "start": -1, "design": _row_names.get(stamp.sample.y, ""), "clock_delay": stamp.birth - board._tile_bursts._seconds})
		if entry["start"] < 0 and stamp.sample.x >= 0:
			entry["start"] = frame
	for key: String in _OBSERVED_RIGS:
		var motion: Dictionary = shown.get(key, {}).get("enemy_1", {})
		if not motion.is_empty():
			_take_fixture["rig"][frame] = [motion.get("action", ""), motion.get("phase", 0.0)]
	var positions: Dictionary = shown.get("unit_world_positions", {})
	var player_tile: Vector2i = board.combat_state.get("player", {}).get("pos", Fx.INVALID)
	_take_fixture["slide"][frame] = [Cases20.coords(player_tile), str(positions.get("player", ""))]

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var dragon: bool = Cases22.CASES[_id][0] == "vaeloryx"
	var crop_size: Vector2i = BIG_CROP if dragon else CropSize
	var area := Rect2(board._tile_center(_opponent_tile), Vector2.ZERO)
	for tile: Vector2i in _take_targets: area = area.expand(board._tile_center(tile))
	area = area.expand(board._tile_center(_aim))
	var center: Vector2 = board.get_global_transform_with_canvas() * area.get_center()
	var strip: Image
	if not _plan: strip = Image.create_empty(crop_size.x * (1 + CONTACT_COLUMNS.size()), crop_size.y, false, Image.FORMAT_RGB8)
	var release: int = -1
	var contact: int = -1
	var numbers: int = -1
	var columns: Dictionary
	var samples: Dictionary
	var hidden: Array = _take_targets.filter(func(tile: Vector2i) -> bool: return not board._board_tile_is_visible_to_player(tile))
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_case()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and _ended_at < 0: _ended_at = frame
		var shown: Dictionary = board.presentation
		_watch(board, frame, shown)
		var effect: Dictionary = shown.get("effect", {})
		if numbers < 0 and not shown.get("floating_texts", []).is_empty(): numbers = frame
		if effect.get("action_type") == _wanted_effect:
			var t: float = float(shown["effect_progress"])
			samples[frame] = t
			var release_at: float = Dragon.RELEASE if dragon else SHALE_AREA_RELEASE if effect.get("kind") == "aoe" else Shot20.release_for(Attack.style_for_effect(effect))
			var contact_at: float = Dragon.CONTACT if dragon else _run._attack_feedback_start_progress(effect)
			if release < 0 and t >= release_at: release = frame
			if contact < 0 and t + 0.0001 >= contact_at: contact = frame
		# Release and contact can share a sample on a compact or reduced beat.
		var frame_columns: Array[int]
		if frame == release: frame_columns.append(0)
		if contact >= 0 and CONTACT_COLUMNS.has(frame - contact): frame_columns.append(1 + CONTACT_COLUMNS.find(frame - contact))
		for column: int in frame_columns: columns[column] = frame
		if not _plan and not frame_columns.is_empty():
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected a 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			var origin := Vector2i(center.round()) - crop_size / 2
			var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - crop_size), crop_size)
			for column: int in frame_columns:
				strip.blit_rect(image, crop, Vector2i(column * crop_size.x, 0))
				if column == 1 and not _save(image, "native-evidence.png"): return {}
		if _ended_at >= 0 and (contact < 0 or frame >= contact + CONTACT_COLUMNS[-1]): break
	if _ended_at < 0 or columns.size() != 1 + CONTACT_COLUMNS.size():
		_fail("FX-22 did not finish all five samples for " + _id)
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	var report: Dictionary = {"case": _id, "release": release, "contact": contact, "numbers": numbers, "done": _ended_at,
		"frames": stats.get("authored_frames", 0), "duration_usec": stats.get("authored_duration_usec", 0),
		"rendered": stats.get("rendered_frames", 0), "samples": samples, "columns": columns,
		"bursts": _spawns.duplicate(true), "stills": _still_frames.duplicate(), "targets": _take_targets.map(Cases20.coords),
		"hidden": hidden.map(Cases20.coords), "losses": _take_fixture["losses"], "shots": _take_fixture["shots"],
		"tile_pairs": _take_fixture["tile_pairs"], "rig": _take_fixture["rig"], "slide": _take_fixture["slide"],
		"player_from": _take_fixture["player_from"], "player_to": _take_fixture["player_to"],
		"terrain_losses": _take_fixture["terrain_losses"], "shot_still": _take_fixture.get("shot_still", -1)}
	if _id == "shale_aoe":
		report["TODO_DESIGN_SHALE_AOE_REPLACEMENT"] = Cases22.TODO_DESIGN_SHALE_AOE_REPLACEMENT
	return report
