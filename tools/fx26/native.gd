extends "res://tools/fx20/native_capture.gd"

const Cases = preload("res://tools/fx26/cases.gd")
const Chain = preload("res://scripts/chain_attack_feedback.gd")
const Pools = preload("res://scripts/burst_rules.gd")
const SurfaceRules = preload("res://scripts/board_surface_rules.gd")
const TRAVEL_COLUMNS: Array[float] = [0.0, 0.33, 0.66, 1.0]
const TAIL_COLUMNS: Array[int] = [6, 14]
const COLUMN_NAMES: Array[String] = ["release", "flight-33", "flight-66", "contact", "contact-100ms", "contact-233ms"]
const LEGACY: Array[StringName] = [&"fx26_release", &"fx26_travel", &"fx26_generic_travel", &"fx26_hop_arc"]
const REEL_FRAMES: int = 5 * FPS
const RELAY_TARGET := Vector2i(7, 1)

var _is_chain: bool
var _is_terrain_burst: bool
var _area_element: String
var _resolved_hits: Array
var _losses_by_tile: Dictionary

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if output.is_empty() or (id not in Cases.NATIVE_CASES and id != Cases.REEL):
		_fail("Provide an fx-26 native case and output directory.")
		return
	if DisplayServer.get_name() == "headless" or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx26/native.sh for 1920x1080, 60 fps cel-look capture.")
		return
	if not (await take_case(id, output, _arg("--base-dir"), false)).is_empty():
		quit()

func _build_case() -> Dictionary:
	_is_chain = _record or _id in Cases.CHAIN_CASES
	_is_terrain_burst = _id == Cases.TERRAIN_CASE
	_area_element = "" if _is_chain or _is_terrain_burst else _id.get_slice("_", 0)
	_card = "" if _is_terrain_burst else Cases.CHAIN_CARD if _is_chain else Cases.AREAS[_area_element][0]
	_aim = Cases.AIM
	_resolved_hits.clear()
	_losses_by_tile.clear()
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids():
		profile = Tutorial.resolve_progression(profile, prompt)
	var target: Vector2i = Cases.PARKED if _id.ends_with("_empty") else _aim
	var last: Vector2i = RELAY_TARGET if _id == "chain_relay" else Cases.THIRD
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": _card, "draw": FILLER_DRAW,
		"player_hp": Cases.Fixtures23.FIXTURE_HP, "player_max_hp": Cases.Fixtures23.FIXTURE_HP,
		"player_position": Cases20.coords(Hero), "enemy_types": "crawler", "enemy_intents": "skitter_strike",
		"enemy_positions": Cases20.coords(target), "umbra_stage": "clear"}
	if _is_chain:
		_options["enemy_types"] = "crawler,crawler,crawler"
		_options["enemy_intents"] = "skitter_strike,skitter_strike,skitter_strike"
		_options["enemy_positions"] += "," + Cases20.coords(Cases.SECOND) + "," + Cases20.coords(last)
	if _is_terrain_burst:
		_options["hand"] = FILLER
		_options["enemy_types"] = "craghide"
		_options["enemy_intents"] = "groundsplit"
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	for y: int in range(1, 7):
		for x: int in range(3, 8):
			state["grid"][y][x] = "stone"
	if _is_chain:
		state["enemies"][1]["block"] = GameData.fixed_point_amount(Cases.Fixtures23.FULL_BLOCK)
	if _id == "chain_relay":
		SurfaceRules.place(state, Cases.RELAY, "electrified")
	if _is_terrain_burst:
		var crag: Dictionary = state["enemies"][0]
		var fuel: Array[Dictionary] = [{"id": "fx26_outcrop", "kind": "crag_outcrop", "pos": Cases.CRAG_FUEL,
			"hp": Cases.CRAG_FUEL_HP, "max_hp": Cases.CRAG_FUEL_HP, "owner_kind": "enemy", "owner_id": crag["id"]}]
		state["terrain"].assign(fuel)
		var step: Dictionary = Cases.Fixtures23.enemy_step(_combat_engine, state, "terrain_burst")
		if step.is_empty() or step.get("kind") != "aoe": return {}
		_steps.append(step)
	return {"run": run, "profile": profile}

func _start_case() -> bool:
	if _record:
		var settings: Dictionary = Settings.load_settings()
		settings["master_volume"] = 0.0
		if not Settings.save_settings(settings): return false
	return await super._start_case()

func _drive_case() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	if _is_terrain_burst:
		_run._combat_pacing.begin_enemies()
		await _run._animate_enemy_phase_steps(state, _steps)
		_run._combat_pacing.end_scope()
	else:
		state = await _play_card(state, _card)
		if _record:
			await _play_card(state, Cases.AREAS["ice"][0])
	_run._animation_lock = false
	_complete = true

func _play_card(state: Dictionary, card: String) -> Dictionary:
	var action: Dictionary = GameData.card_def(card)["actions"][0].duplicate(true)
	action["_card_id"] = card
	if _area_element == "shadow":
		# No live non-dragon Shadow area exists. Exercise the real resolver
		# with a fixture-local element on an existing targeted area shape.
		action["element"] = _area_element
		action.erase("surface")
		action.erase("surface_bonus")
	var result: Dictionary = _combat_engine.resolve_player_action_for_presentation(state, action, _aim)
	var after: Dictionary = result["state"]
	var hits: Array = result["chain_hits"]
	if card == Cases.CHAIN_CARD:
		for hit: Dictionary in hits:
			_resolved_hits.append({"from": Cases20.coords(hit["from"]), "to": Cases20.coords(hit["to"]), "kind": hit["kind"]})
		if _id == "chain_hidden":
			# The real resolver avoids hidden targets. Apply visibility to its
			# snapshots after resolution to exercise playback losing the last tile.
			Cases.hide_last(state)
			Cases.hide_last(after)
			for hit: Dictionary in hits:
				Cases.hide_last(hit["state"])
	for unit: Dictionary in state["enemies"]:
		for remaining: Dictionary in after["enemies"]:
			if unit["id"] != remaining["id"]: continue
			var lost: Vector3i = Pools.damage_pools(unit) - Pools.damage_pools(remaining)
			_losses_by_tile[Cases20.coords(unit["pos"])] = [lost.x, lost.y, lost.z]
	_run._combat_pacing.begin_card()
	_run._begin_action_step_resolution_tracker(card, [action], [_aim], false)
	await _run._animate_player_action_step(state, after, card, action, _aim, hits)
	_run._combat_pacing.end_scope()
	return after

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var beats: Array[Dictionary]
	var frames: Array[Dictionary]
	var columns: Dictionary
	var recorded: Dictionary
	var reel_order: Array[String]
	var raw: FileAccess
	var strip: Image
	var strip_rows: int = 3 if _is_chain else 1
	if not _plan:
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open the fx-26 reel stream.")
				return {}
		else:
			strip = Image.create_empty(CropSize.x * COLUMN_NAMES.size(), CropSize.y * strip_rows, false, Image.FORMAT_RGB8)
	var offset: int = -1
	var rendered: int = 0
	for key: StringName in LEGACY: Engine.set_meta(key, false)
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
		var effect: Dictionary = shown.get("effect", {})
		var shot: RefCounted = board._single_shot_fx
		var shot_id: String = shot._shot_id if shot._heads[0].visible else ""
		var reel_frame: bool = _record and rendered < REEL_FRAMES
		var new_shot: bool = reel_frame and not shot_id.is_empty() and not recorded.has(shot_id)
		if new_shot:
			recorded[shot_id] = true
			reel_order.append(shot_id)
		if reel_frame: rendered += 1
		var legacy: Array[String]
		for key: StringName in LEGACY:
			if Engine.get_meta(key): legacy.append(String(key).trim_prefix("fx26_"))
			Engine.set_meta(key, false)
		var crops: Array[Vector2i]
		if not effect.is_empty():
			if offset < 0: offset = frame
			var index: int = int(effect.get("chain_index", 0))
			var t: float = float(shown.get("effect_progress", 0.0))
			var style: String = Attack.style_for_effect(effect)
			var release: float = 0.0 if index > 0 else Shot20.release_for(style)
			var contact: float = Chain.HOP_CONTACT if index > 0 else _run._attack_feedback_start_progress(effect)
			var fallback_count: int = (1 if _reduced else 12) if index > 0 else Attack.animation_frame_count(effect, _run.ATTACK_FRAMES, _reduced)
			var count: int = int(shown.get("effect_frame_count", fallback_count))
			var from: Vector2i = effect["from"]
			var to: Vector2i = effect["to"]
			if not _record:
				if index == beats.size():
					beats.append({"contact": -1, "contact_frame": -1, "length": count, "from": Cases20.coords(from), "to": Cases20.coords(to)})
				var beat: Dictionary = beats[index]
				if beat["contact"] < 0 and (_reduced or t >= contact):
					beat["contact"] = frame - offset
					beat["contact_frame"] = roundi(t * count)
				for column: int in TRAVEL_COLUMNS.size():
					if _reduced or t >= lerpf(release, contact, TRAVEL_COLUMNS[column]):
						_schedule(columns, crops, index, column, frame - offset)
			var clip: Array[Vector2]
			if not shot_id.is_empty() and shot._clip_enabled:
				for span: Vector2 in shot._clip_spans.slice(0, int(shot._ink.get_shader_parameter("visible_span_count"))):
					clip.append(span)
			frames.append({"frame": frame - offset, "beat": index, "action_frame": roundi(t * count), "shot": shot_id,
				"legacy": legacy, "target_visible": board._board_tile_is_visible_to_player(to),
				"target_actor_visible": board._visible_units().any(func(unit: Dictionary) -> bool:
					return unit.get("pos") == to and unit.get("role") == "enemy"),
				"to_center": not shot_id.is_empty() and shot._end_offset.is_zero_approx(),
				"level_hop": not shot_id.is_empty() and index > 0 and shot._launch_offset.is_equal_approx(shot._end_offset),
				"clip": clip})
		for index: int in beats.size():
			var touch: int = beats[index]["contact"]
			if touch < 0: continue
			var tail: int = TAIL_COLUMNS.find(frame - offset - touch)
			if tail >= 0: _schedule(columns, crops, index, TRAVEL_COLUMNS.size() + tail, frame - offset)
		_watch(board, frame - offset, shown)
		if not _plan and (not crops.is_empty() or reel_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected an exact 1920x1080 RunScene framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if reel_frame: raw.store_buffer(image.get_data())
			if new_shot and not _save(image, shot_id + "-evidence.png"): return {}
			for cell: Vector2i in crops:
				var beat: Dictionary = beats[cell.y]
				var midpoint: Vector2 = board._tile_center(_tile_coord(beat["from"])).lerp(board._tile_center(_tile_coord(beat["to"])), 0.5)
				var origin := Vector2i((board.get_global_transform_with_canvas() * midpoint).round()) - CropSize / 2
				var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
				var name: String = ("hop-%d-" % cell.y if cell.y > 0 else "") + COLUMN_NAMES[cell.x]
				if not _save(image.get_region(crop), name + ".png"): return {}
				strip.blit_rect(image, crop, cell * CropSize)
				if cell == Vector2i(3, 0) and not _save(image, "native-evidence.png"): return {}
		if _ended_at >= 0:
			if _record and rendered == REEL_FRAMES: break
			if not _record and not beats.is_empty() and beats[-1]["contact"] >= 0 and frame - offset >= int(beats[-1]["contact"]) + TAIL_COLUMNS[-1]: break
	if raw != null: raw.close()
	if _ended_at < 0 or (_record and rendered != REEL_FRAMES) or (not _record and (beats.is_empty() or columns.size() != COLUMN_NAMES.size() * beats.size())):
		_fail("Incomplete fx-26 action or capture schedule for " + _id)
		return {}
	if not _plan and not _record:
		if beats.size() != strip_rows:
			_fail("Unexpected beat count for the fx-26 strip.")
			return {}
		if not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _id, "beats": beats, "samples": frames, "bursts": _spawns.duplicate(true), "resolved_hits": _resolved_hits.duplicate(true),
		"losses": _losses_by_tile.duplicate(true), "frames": stats["authored_frames"], "duration_usec": stats["authored_duration_usec"],
		"done": _ended_at - offset, "columns": columns, "reel_frames": rendered, "reel_order": reel_order}

func _schedule(columns: Dictionary, crops: Array[Vector2i], row: int, column: int, frame: int) -> void:
	var key: String = "%d/%s" % [row, COLUMN_NAMES[column]]
	if columns.has(key): return
	columns[key] = frame
	crops.append(Vector2i(column, row))

func _tile_coord(text: String) -> Vector2i:
	return Vector2i(int(text.get_slice(":", 0)), int(text.get_slice(":", 1)))
