extends "res://tools/fx18/native_capture.gd"

const Fixtures = preload("res://tools/fx33/cases.gd")
const ShotFx = preload("res://scripts/shot_fx.gd")
const PainterLog = preload("res://tools/fx33/painter_log.gd")
const STRIP_CROP := Vector2i(640, 480)
const REEL_FRAMES: int = 6 * FPS
const TAIL_FRAMES: int = 32
const INTER_CARD_SECONDS: float = 0.45
const MISSING_FRAME: int = -1

var _done_at: int
var _playing: String
var _actions: Dictionary
var _stamps: Dictionary
var _strike_samples: Array[Dictionary]
var _shot_contacts: Dictionary
var _ledger: Array[Dictionary]
var _resolved: Dictionary
var _view_frames: Dictionary
var _capacitor_contacts: Array[Dictionary]
var _spark_flight: Dictionary

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if id not in Fixtures.STRIPS + ["recording"] or not output.is_absolute_path():
		_fail("Use tools/fx33/native.sh with an absolute --out directory.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Native proof requires 60 fps MovieWriter and cel look all.")
		return
	if not (await take_case(id, output, false)).is_empty():
		print(output)
		quit()

func take_case(id: String, output: String, reduced: bool) -> Dictionary:
	_case = id
	_output = output
	_reduced = reduced
	_record = id == "recording"
	_complete = false
	_done_at = MISSING_FRAME
	_playing = ""
	_actions.clear()
	_stamps.clear()
	_strike_samples.clear()
	_shot_contacts.clear()
	_ledger.clear()
	_resolved.clear()
	_view_frames.clear()
	_capacitor_contacts.clear()
	_spark_flight.clear()
	DirAccess.make_dir_recursive_absolute(output)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	_options = Fixtures.options(id, DEFAULT_SEED)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty():
		_fail("Could not build " + id)
		return {}
	Fixtures.configure(id, run["combat_state"])
	if not await _start_take({"run": run, "profile": profile}):
		_fail("Could not resume " + id)
		return {}
	var board: Control = _run.board_view
	var origin_frame: int = Engine.get_process_frames() + 1
	var crop: Rect2i = _crop(board)
	var images: Dictionary
	var raw: FileAccess
	if not _plan and _record:
		raw = FileAccess.open(output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Could not open reel stream.")
			return {}
	PainterLog.calls.clear()
	PainterLog.stamp_requests.clear()
	PainterLog.hop_feedback.clear()
	PainterLog.active = true
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_take()
	var reel_count: int = 0
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and _done_at == MISSING_FRAME: _done_at = frame
		_observe_frame(board, frame)
		var columns: Array[int] = _columns()
		var column: int = columns.find(frame)
		var recording: bool = _record and frame < REEL_FRAMES
		if recording: reel_count += 1
		if not _plan and (recording or column >= 0):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected the exact 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if recording:
				raw.store_buffer(image.get_data())
				if frame == _contact("burst") and not _save(image, "burst-contact.png"): return {}
				if frame == _contact("chain_bolt") and not _save(image, "chain-contact.png"): return {}
			elif column >= 0:
				images[column] = image.get_region(crop)
				if column == 1 and not _save(image, "native-evidence.png"): return {}
		if _done_at >= 0 and frame >= _done_at + TAIL_FRAMES and (not _record or reel_count == REEL_FRAMES): break
	if raw != null: raw.close()
	PainterLog.active = false
	if _done_at < 0:
		_fail("Playback did not finish: " + id)
		return {}
	if not _plan and not _record and not _save_strip(images): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	var painters: Dictionary
	for site: String in PainterLog.calls: painters[site] = (PainterLog.calls[site] as Dictionary).size()
	var requests: Array[Dictionary] = PainterLog.stamp_requests.duplicate(true)
	for request: Dictionary in requests: request["frame"] -= origin_frame
	var report: Dictionary = {"case": id, "reduced": reduced, "done": _done_at, "columns": _columns(),
		"reel_frames": reel_count, "clock": stats, "actions": _actions.duplicate(true),
		"frames": _ledger.duplicate(true), "stamps": _stamps.values().duplicate(true),
		"strikes": _strike_samples.duplicate(true), "shots": _shot_contacts.values().duplicate(true), "painters": painters, "requests": requests,
		"resolved": _resolved.duplicate(true), "view_frames": _view_frames.duplicate(true),
		"capacitor_contacts": _capacitor_contacts.duplicate(true), "spark_flight": _spark_flight.duplicate(true)}
	_viewport.queue_free()
	await process_frame
	var file := FileAccess.open(output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write take.json.")
		return {}
	file.store_string(JSON.stringify(report, "\t"))
	print("FX-33 TAKE " + output.path_join("take.json"))
	return report

func _drive_take() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	match _case:
		"tick", "hoarder", "hidden":
			state = await _card(state, "quick_stab", "melee", Fixtures.TICK)
		"kindled_tick":
			await _enemy(state)
			state = _run._combat_state.duplicate(true)
			state["player"]["block"] = Fixtures.BLOCK
			_resolved["kindle"] = state["enemies"][0].get("kindled_bonus", 0)
			state = await _card(state, "quick_stab", "melee", Fixtures.TICK)
		"hidden_trace":
			state = await _hidden_burst_take(state)
		"recording":
			state = await _card(state, "quick_stab", "melee", Fixtures.TICK)
			await create_timer(INTER_CARD_SECONDS).timeout
			state = await _card(state, "chain_bolt", "ranged", Fixtures.PRIMARY)
		"chain_bolt", "storm_salvo", "chain_conduction", "spark_conduction", "storm_relay", "root_snare", "lodestone_reversal", "volt_surge":
			var card: String = {"chain_conduction": "chain_bolt", "spark_conduction": "spark_dart"}.get(_case, _case)
			var kind: String = "pull" if card == "lodestone_reversal" else "aoe" if card == "volt_surge" else "ranged"
			state = await _card(state, card, kind, Fixtures.PRIMARY)
		"immolation":
			state = await _card(state, "immolation", "detonate", Fixtures.HERO + Vector2i.RIGHT)
		"lightning_storm":
			_playing = _case
			Rules.install(_combat_engine, state, {"rule": "lightning_storm", "source": {"kind": "room"},
				"cadence": {"anchor": "after_player_turn", "every": 1}, "dials": {"damage": Fixtures.STORM_DAMAGE}})
			state["turn"] = int(state["turn"]) + 1
			var steps: Array[Dictionary]
			var after: Dictionary = Rules.fire(_combat_engine, state.duplicate(true), steps)
			await _play_enemy_steps(state, after, steps)
			state = after
		_:
			await _enemy(state)
			state = _run._combat_state
	_run._combat_state = state
	_run._render_board_state(state, {})
	_run._animation_lock = false
	_complete = true

func _card(state: Dictionary, card: String, kind: String, aim: Vector2i) -> Dictionary:
	for definition: Dictionary in Fixtures.Data.card_def(card).get("actions", []):
		if definition["type"] != kind: continue
		var action: Dictionary = definition.duplicate(true)
		action["_card_id"] = card
		var result: Dictionary = _combat_engine.resolve_player_action_for_presentation(state, action, aim)
		var after: Dictionary = result["state"]
		_resolved[card] = {"changed": after != state, "chain": result.get("chain_hits", []).map(
			func(hit: Dictionary) -> Array: return [hit.get("kind", ""), str(hit.get("to")), hit.get("path", []).size()])}
		_resolved["bursts"] = _burst_records(after)
		_playing = card
		_run._combat_pacing.begin_card()
		_run._begin_action_step_resolution_tracker(card, [action], [aim], false)
		await _run._animate_player_action_step(state, after, card, action, aim, result.get("chain_hits", []))
		_run._combat_pacing.end_scope()
		_run._combat_state = after
		_run._render_board_state(after, {})
		return after
	_fail("Missing " + card + " " + kind)
	return state

func _enemy(state: Dictionary) -> void:
	var result: Dictionary = _combat_engine.resolve_enemy_turn_with_steps(state, 0)
	var after: Dictionary = result["state"]
	_playing = _case
	await _play_enemy_steps(state, after, result["steps"])
	_run._combat_state = after

func _hidden_burst_take(state: Dictionary) -> Dictionary:
	const Ownership = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd")
	const Trace = preload("res://scripts/reaction_presentation_trace.gd")
	var trace: Dictionary = {"capture_reactions": true}
	_combat_engine._surface_death_trace = trace
	var after: Dictionary = _combat_engine._damage_enemy(state.duplicate(true), 0, Fixtures.KILL_HP)
	_combat_engine._surface_death_trace = {}
	var cascades: Array = trace.get("cascades", [])
	if cascades.is_empty():
		_fail("Hidden witness requires a resolver-produced traced Burst.")
		return state
	var events: Array = after.get("death_burst_events", [])
	var step: Dictionary = Ownership._cascade_step(_combat_engine, cascades[0])
	step = _combat_engine._umbra_marked_enemy_status_step(state, after, step, int(events[0]["id"]))
	if not step.get("hidden_by_umbra", false):
		_fail("Hidden witness source must be concealed.")
		return state
	_playing = _case
	var playback: Dictionary = state.duplicate(true)
	playback.merge(events[0]["before"], true)
	var phase: Dictionary = Trace.complete_turn({"state": after, "steps": [step]})
	await _play_enemy_steps(playback, after, phase["steps"])
	return after

func _play_enemy_steps(state: Dictionary, after: Dictionary, steps: Array) -> void:
	_resolved["steps"] = steps.map(func(step: Dictionary) -> String: return str(step.get("action_type", step.get("kind"))))
	_resolved["bursts"] = _burst_records(after)
	for step: Dictionary in steps:
		if step.get("action_type") != "chain_discharge": continue
		var prior: Dictionary = state
		var hops: Array[Dictionary]
		for hit: Dictionary in step["chain_hits"]:
			var tile: Vector2i = hit["to"]
			var impact: Dictionary = Fx.step_hit_tiles(prior, hit["state"], _run.board_view._resolved_unit_footprint)
			var new_bursts: Array = hit["state"].get("death_burst_events", []).slice(prior.get("death_burst_events", []).size())
			hops.append({"tile": Fixtures.coord(tile), "from": Fixtures.coord(hit["from"]),
				"row": "hit" if impact.has(tile) else "floor", "bursts": new_bursts.map(func(event: Dictionary) -> int: return event["id"])})
			prior = hit["state"]
		_resolved["capacitor_hops"] = hops
	_run._combat_pacing.begin_enemies()
	await _run._animate_enemy_phase_steps(state, steps, after)
	_run._combat_pacing.end_scope()

func _burst_records(state: Dictionary) -> Array:
	return state.get("death_burst_events", []).map(func(event: Dictionary) -> Dictionary:
		var source: Vector2i = event["tile"]
		var hits: Dictionary = Fx.hit_tiles(event["before"], event["after"])
		hits[source] = true
		var rows: Dictionary
		for tile: Vector2i in event["tiles"]: rows[Fixtures.coord(tile)] = "hit" if hits.has(tile) else "floor"
		return {"id": event["id"], "source": Fixtures.coord(source), "damage": event["damage"], "rows": rows})

func _observe_frame(board: Control, frame: int) -> void:
	var shown: Dictionary = board.presentation
	var hops: Array = _resolved.get("capacitor_hops", [])
	while _capacitor_contacts.size() < mini(hops.size(), PainterLog.hop_feedback.size()):
		var index: int = _capacitor_contacts.size()
		var feedback: Dictionary = PainterLog.hop_feedback[index]
		var contact: Dictionary = hops[index].duplicate(true)
		contact["frame"] = frame
		contact["losses"] = feedback["losses"]
		var visible: Array = feedback["visible"]
		contact["visible"] = visible.map(Fixtures.coord)
		_capacitor_contacts.append(contact)
	var shot_fx: ShotFx = board._single_shot_fx
	if shot_fx._shot_id == "spark" and shot_fx._chain_hop and shot_fx._heads[0].visible:
		var route: String = Fixtures.coord(shot_fx._from_tile) + "→" + Fixtures.coord(shot_fx._to_tile)
		var samples: Array = _spark_flight.get_or_add(route, [])
		samples.append(frame)
	var effect: Dictionary = shown.get("effect", {})
	var progress: float = shown.get("effect_progress", 0.0)
	if not effect.is_empty() and _playing != "":
		var route: String = str(effect.get("chain_index", 0))
		if effect.get("kind") == "chain" and not effect.has("chain_index"):
			route = str(effect.get("to"))
		var key: String = _playing + "/" + str(effect.get("kind")) + "/" + route
		var action: Dictionary = _actions.get_or_add(key, {"first": frame, "contact": MISSING_FRAME, "last": frame})
		action["last"] = frame
		var contact: float = _run._attack_feedback_start_progress(effect)
		if effect.get("kind") == "chain": contact = preload("res://scripts/chain_attack_feedback.gd").HOP_CONTACT
		if action["contact"] < 0 and (_reduced or progress >= contact):
			action["contact"] = frame
		if effect.get("kind") == "chain" and board.has_method("_surface_conduction_alpha") and float(board.call("_surface_conduction_alpha")) > 0.0:
			for branch: Dictionary in effect.get("branches", [effect]):
				if branch.get("path", []).size() > 1:
					_view_frames[frame] = true
					break
	var burst: Dictionary = shown.get("en01_burst", {})
	if not burst.is_empty():
		var record: Dictionary = _actions.get_or_add("burst/" + str(burst.get("id", -1)),
			{"first": frame, "contact": frame, "last": frame, "visible": []})
		record["last"] = frame
		if record["first"] == frame:
			record["visible"] = burst.get("tiles", []).filter(board._board_tile_is_visible_to_player).map(Fixtures.coord)
	var pools: Array = []
	for unit: Dictionary in [board.combat_state.get("player", {})] + board.combat_state.get("enemies", []):
		pools.append([unit.get("id", "hero"), unit.get("hp", 0), unit.get("block", 0),
			unit.get("stoneskin", 0), unit.get("frost_armor", 0)])
	var ghosts: Dictionary
	var tracker: HealthGhostTracker = board.health_ghost_tracker
	for key: String in tracker._bars: ghosts[key] = tracker.sample(key)
	var texts: Array = shown.get("floating_texts", [])
	_ledger.append({"pools": pools, "defiance": board.combat_state.get("defiance_remaining", 0),
		"health_bars": ghosts, "texts": texts.duplicate(true)})
	for stamp: Fx.Stamp in board._tile_bursts._stamps:
		if not _stamps.has(stamp.get_instance_id()):
			_stamps[stamp.get_instance_id()] = {"tile": Fixtures.coord(stamp.tile), "row": stamp.sample.y,
				"layer": "front" if stamp.front else "rear", "submitted": frame,
				"delay": snappedf(stamp.birth - board._tile_bursts._seconds, 0.000001),
				"visible_at_submission": board._board_tile_is_visible_to_player(stamp.tile), "start": MISSING_FRAME}
		var entry: Dictionary = _stamps[stamp.get_instance_id()]
		if entry["start"] < 0 and stamp.visible:
			entry["start"] = frame
			entry["cell"] = stamp.sample.x
	for shot: ShotFx.Stamp in board._single_shot_fx._hits:
		if shot.visible and shot.lifetime_start >= 0:
			var key: String = "%s/%s" % [shot.get_instance_id(), shot.lifetime_start]
			_shot_contacts.get_or_add(key, {"frame": frame, "tile": Fixtures.coord(shot.hit_tile), "name": shot.hit_id})
	for stamp: Fx.Stamp in board._sky_strikes._stamps:
		if stamp.visible:
			_strike_samples.append({"frame": frame, "tile": Fixtures.coord(stamp.tile), "sheet": board._sky_strikes.sheet_index,
				"row": stamp.sample.y, "cell": stamp.sample.x})

func _contact(id: String) -> int:
	for key: String in _actions:
		if key.begins_with(id + "/"): return _actions[key]["contact"]
	return MISSING_FRAME

func _columns() -> Array[int]:
	var frames: Array[int]
	if _record: return frames
	var contact: int = _contact("burst" if _case == "tick" else _case)
	if _case == "spark_conduction": contact = _actions.get("spark_dart/chain/1", {}).get("contact", MISSING_FRAME)
	if _case == "capacitor" and not _capacitor_contacts.is_empty(): contact = _capacitor_contacts[0]["frame"]
	if _case == "tick": frames.append(_contact("quick_stab"))
	if contact >= 0:
		for offset: int in ([0, 6, 14, 22] if _case == "tick" else [0, 6, 14]): frames.append(contact + offset)
	return frames

func _crop(board: Control) -> Rect2i:
	var tile: Vector2i = Fixtures.TICK if _case in ["tick", "capacitor"] else Fixtures.PRIMARY
	var center: Vector2 = board._tile_center(tile)
	if _case == "spark_conduction": center = center.lerp(board._tile_center(Fixtures.CONDUCTION_TARGET), 0.5)
	center = board.get_global_transform_with_canvas() * center
	return Rect2i((Vector2i(center.round()) - STRIP_CROP / 2).clamp(Vector2i.ZERO, CanvasSize - STRIP_CROP), STRIP_CROP)

func _save_strip(images: Dictionary) -> bool:
	var count: int = 5 if _case == "tick" else 3
	if images.size() != count:
		_fail("Missing native strip columns for " + _case)
		return false
	var strip := Image.create_empty(STRIP_CROP.x * count, STRIP_CROP.y, false, Image.FORMAT_RGB8)
	for column: int in range(count):
		strip.blit_rect(images[column], Rect2i(Vector2i.ZERO, STRIP_CROP), Vector2i(column * STRIP_CROP.x, 0))
	return _save(strip, "strip.png")
