extends "res://tools/fx20/native_capture.gd"
## Same RunScene and 60 Hz capture clock as FX-20, with contact-only columns.

const Cases24 = preload("res://tools/fx24/cases.gd")
const Ground24 = preload("res://scripts/board_surface_presentation.gd")

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if not Cases24.CASES.has(id) or output.is_empty():
		_fail("Provide an FX-24 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx24/native.sh for the native 60 fps cel-look take.")
		return
	var result: Dictionary = await take_case(id, output, _arg("--base-dir"), false)
	if not result.is_empty(): quit()

func _build_case() -> Dictionary:
	var enemy: Array = Cases24.ENEMIES.get(_id, ["crawler", "skitter_strike", Cases20.FAR, ""])
	var card: Array = Cases24.CARDS.get(_id, ["", 0, Cases20.HERO])
	_card = card[0]
	_opponent_tile = card[2] if not _card.is_empty() else enemy[2]
	_aim = card[2]
	_wanted_effect = ""
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": FILLER if _card.is_empty() else _card, "draw": FILLER_DRAW,
		"player_hp": Cases20.PROOF_HP, "player_max_hp": Cases20.PROOF_HP, "player_position": Cases20.coords(Cases20.HERO),
		"enemy_types": enemy[0], "enemy_intents": enemy[1], "enemy_positions": Cases20.coords(_opponent_tile), "umbra_stage": "clear"}
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	Cases24.configure(_id, _combat_engine, state)
	if Cases24.ENEMIES.has(_id):
		var resolver: RefCounted = Cases24.NoDamageCollision.new() if _id == "push_wall" else _combat_engine
		var step: Dictionary = Cases20.enemy_step(resolver, state, enemy[3], false)
		if step.is_empty(): return {}
		if _id == "push_wall":
			var collisions: Array = step.get("surface_events", []).filter(func(event: Dictionary) -> bool: return event.get("kind") == "force_collision")
			if collisions.size() != 1 or collisions[0].get("total_damage") != 0: return {}
		_steps.append(step)
		_wanted_effect = step["action_type"]
		_take_targets = Dragon.tiles(step)
	elif not _card.is_empty():
		var action: Dictionary = GameData.card_def(_card)["actions"][card[1]]
		_wanted_effect = "aoe" if action["type"] in ["detonate", "burst_terrain", "destroy_illusion"] else action["type"]
		_take_targets.append(_aim)
	else:
		_take_targets.append(Cases24.GROUND if _id in Cases24.SURFACES or _id == "surface_paint" else Cases24.STOP)
	return {"run": run, "profile": profile, "pairs": {}, "flight": {}, "legacy": {}, "events": [], "fades": {}}

func _drive_case() -> void:
	if not _steps.is_empty():
		await super._drive_case()
		return
	var before: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	var after: Dictionary
	if not _card.is_empty():
		var action: Dictionary = GameData.card_def(_card)["actions"][Cases24.CARDS[_id][1]].duplicate(true)
		action["_card_id"] = _card
		var result: Dictionary = _combat_engine.resolve_player_action_for_presentation(before, action, _aim)
		after = result["state"]
		_run._combat_pacing.begin_card()
		_run._begin_action_step_resolution_tracker(_card, [action], [_aim], false)
		await _run._animate_player_action_step(before, after, _card, action, _aim, result["chain_hits"])
		_run._combat_pacing.end_scope()
	else:
		after = Cases24.ground_step(_id, _combat_engine, before.duplicate(true))
		_run._resolved_contact_bursts.begin(before)
		await _run._animate_surface_change(before, after)
	_take_fixture["losses"] = _losses(before, after)
	_run._animation_lock = false
	_complete = true

func _watch(board: Control, frame: int, shown: Dictionary) -> void:
	super._watch(board, frame, shown)
	var effect: Dictionary = shown.get("effect", {})
	var progress: float = float(shown.get("effect_progress", 0.0))
	var shot: RefCounted = board._single_shot_fx
	if not shot._shot_id.is_empty() and shot._heads[0].visible and _take_fixture["flight"].is_empty():
		var source: Vector2 = board._tile_center(shot._from_tile) + shot._launch_offset
		var socket: Vector2 = board._veilbound_acolyte_launch_point(effect, Vector2.INF)
		_take_fixture["flight"] = {"name": shot._shot_id, "frame": frame, "progress": progress,
			"from": Cases20.coords(shot._from_tile), "to": Cases20.coords(shot._to_tile), "same_socket": source.is_equal_approx(socket)}
	for stamp: Node in board._tile_bursts._stamps:
		var key: int = stamp.get_instance_id()
		var pair: Dictionary = _take_fixture["pairs"].get_or_add(key, {"tile": Cases20.coords(stamp.tile),
			"frame": frame, "layer": "front" if stamp.front else "rear", "row": _row_names[stamp.sample.y], "clock_delay": stamp.birth - board._tile_bursts._seconds, "first_sample": -1})
		if pair["first_sample"] < 0 and stamp.sample.x >= 0:
			pair["first_sample"] = stamp.sample.x
			pair["visible_frame"] = frame
	for event: Dictionary in shown.get("surface_feedback_events", []):
		_watch_surface(board, event, shown, frame)
	# The headless take observes the same eligibility guards the old canvas
	# used to submit contacts, without needing its texture rasterization.
	if not effect.get(Fx.REPLACE_TARGETED, false) and not effect.get(Fx.ACTIVE, false) and Attack.uses_authored_elemental_attack(effect) and Shot20.resolve(effect).is_empty():
		var tile: Vector2i = effect.get("to", Fx.INVALID)
		if board._board_tile_is_visible_to_player(tile) and (_reduced or progress >= Attack.feedback_start_progress(effect)):
			_legacy("target_impact", tile, frame)
	if _base_dir.is_empty(): return
	if effect.get("kind") == "aoe" and not effect.get(Fx.ACTIVE, false) and board._aoe_resolution_footprint_visibility(effect, progress) > 0.0:
		for tile: Vector2i in effect.get("tiles", []):
			if board._board_tile_is_visible_to_player(tile): _legacy("area_wash", tile, frame)
	if effect.get("veilbound_acolyte_ranged", false) and Shot20.resolve(effect).is_empty() and progress > Shot20.DEFAULT_RELEASE and progress < 0.82:
		_legacy("needle", effect["to"], frame)
	if effect.get("cinder_ooze_action") == "attack" or effect.get("cinder_droplet_melee", false):
		var tile: Vector2i = effect["to"]
		if progress >= Attack.feedback_start_progress(effect) and not board.presentation["effect"].get("contact_burst_tiles", {}).has(tile):
			_legacy("melee_splash", tile, frame)

func _legacy(kind: String, tile: Vector2i, frame: int) -> void:
	var cell: String = Cases20.coords(tile)
	_take_fixture["legacy"].get_or_add(kind + ":" + cell, {"painter": kind, "tile": cell, "frame": frame})

func _watch_surface(board: Control, event: Dictionary, shown: Dictionary, frame: int) -> void:
	var tile: Vector2i = event.get("tile", Fx.INVALID)
	var broken: String = str(event.get("break_surface", ""))
	var progress: float = float(shown.get("surface_feedback_progress", 0.0))
	if not broken.is_empty():
		var alpha: float = Ground24.leaving_alpha(tile, broken, [event], progress)
		if alpha > 0.0: _take_fixture["fades"][frame] = alpha
	_take_fixture["events"].append([frame, event.get("kind", ""), Cases20.coords(tile), event.get("contact_burst_replaced", "")])
	if not board._board_tile_is_visible_to_player(tile) or (progress >= 1.0 and not _reduced): return
	var mark: String = event.get("contact_burst_replaced", "")
	var element: String = str(event.get("feedback_element", ""))
	if mark.is_empty() and element.is_empty() and broken.is_empty() and progress > 0.0 and event.get("kind") in ["surface_created", "surface_replaced"]:
		_legacy("surface_wash", tile, frame)
	if _base_dir.is_empty():
		if mark.is_empty() and not element.is_empty():
			_legacy("surface_contact", tile, frame)
	else:
		if not broken.is_empty() and mark != "break": _legacy("surface_break", tile, frame)
		if not element.is_empty(): _legacy("surface_contact", tile, frame)
		if event.get("kind") == "force_collision" and mark != "collision": _legacy("collision", tile, frame)

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var bounds := Rect2(board._tile_center(_opponent_tile), Vector2.ZERO).expand(board._tile_center(Cases20.HERO))
	for tile: Vector2i in _take_targets: bounds = bounds.expand(board._tile_center(tile))
	var center: Vector2 = board.get_global_transform_with_canvas() * bounds.get_center()
	var origin: Vector2i = Vector2i(center.round()) - CropSize / 2
	var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
	var strip: Image
	if not _plan: strip = Image.create_empty(CropSize.x * CONTACT_COLUMNS.size(), CropSize.y, false, Image.FORMAT_RGB8)
	var contact: int = -1
	var authored_contact: int = -1
	var progress_at_contact: float = -1.0
	var columns: Array[int]
	var effect_tiles: Array[Vector2i]
	var shown_samples: Array[float]
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
		if not _wanted_effect.is_empty() and effect.get("action_type", effect.get("kind")) == _wanted_effect:
			var progress: float = float(shown.get("effect_progress", 0.0))
			if shown_samples.is_empty() or shown_samples.back() != progress: shown_samples.append(progress)
			if effect_tiles.is_empty(): effect_tiles.assign(effect.get("tiles", _take_targets))
			if contact < 0 and (_reduced or progress + 0.0001 >= Attack.feedback_start_progress(effect)):
				contact = frame
				progress_at_contact = progress
				authored_contact = roundi(progress * int(shown.get("effect_frame_count", 0)))
		if contact < 0 and _wanted_effect.is_empty() and shown.get("surface_feedback_events", []).any(
			func(event: Dictionary) -> bool: return event.get("kind") == Cases24.event_kind(_id)):
			contact = frame
			progress_at_contact = shown.get("surface_feedback_progress", -1.0)
		if contact >= 0 and CONTACT_COLUMNS.has(frame - contact):
			var column: int = CONTACT_COLUMNS.find(frame - contact)
			columns.append(frame)
			if not _plan:
				var image: Image = _viewport.get_texture().get_image()
				if image == null or image.get_size() != CanvasSize:
					_fail("Expected a 1920x1080 framebuffer.")
					return {}
				image.convert(Image.FORMAT_RGB8)
				strip.blit_rect(image, crop, Vector2i(column * CropSize.x, 0))
				if column == 0 and not _save(image, "native-evidence.png"): return {}
		if _ended_at >= 0 and (contact < 0 or frame >= contact + CONTACT_COLUMNS[-1]): break
	if _ended_at < 0 or columns.size() != CONTACT_COLUMNS.size():
		_fail("FX-24 did not finish all four contact samples for " + _id)
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	var tiles: Array[Vector2i] = _take_targets if effect_tiles.is_empty() else effect_tiles
	return {"case": _id, "contact": contact, "authored_contact": authored_contact, "contact_progress": progress_at_contact, "done": _ended_at,
		"frames": stats.get("authored_frames", 0), "duration_usec": stats.get("authored_duration_usec", 0),
		"rendered": stats.get("rendered_frames", 0), "effect_samples": shown_samples, "columns": columns,
		"bursts": _spawns.duplicate(true), "stills": _still_frames.duplicate(), "targets": tiles.map(Cases20.coords),
		"pairs": _take_fixture["pairs"].values(), "flight": _take_fixture["flight"], "legacy": _take_fixture["legacy"].values(),
		"events": _take_fixture["events"], "fades": _take_fixture["fades"], "losses": _take_fixture["losses"]}
