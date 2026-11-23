extends "res://tools/fx20/native_capture.gd"
## Both modes play real resolver results through RunScene on the 60 Hz movie clock.

const Cases23 = preload("res://tools/fx23/cases.gd")
const BurstRules = preload("res://scripts/burst_rules.gd")
const MaquetteAction = preload("res://scripts/maquette_cutout_runtime/action.gd")
const TRAVEL_COLUMNS: Array[float] = [0.0, 0.33, 0.66, 1.0]
const AFTER_CONTACT_COLUMNS: Array[int] = [6, 14]
const COLUMN_NAMES: Array[String] = ["release", "flight-33", "flight-66", "contact", "contact-100ms", "contact-233ms"]
const REEL_FRAMES: int = 4 * FPS
const LEGACY_FLIGHT: StringName = &"fx23_legacy_flight"
const LEGACY_RELEASE: StringName = &"fx23_legacy_release"
const FOG_STAGE: String = "eclipse"

var _loss: Vector3i
var _trace: bool
var _fog_proof: bool
var _recorded_shots: Dictionary

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if output.is_empty() or (not Cases23.HERO_CASES.has(id) and not Cases23.inventory().has(id) and id != Cases23.RECORDING):
		_fail("Provide an FX-23 case and output directory.")
		return
	if DisplayServer.get_name() == "headless" or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx23/native.sh for 1920x1080, 60 fps cel-look capture.")
		return
	if not (await take_case(id, output, _arg("--base-dir"), false)).is_empty():
		quit()

func _build_case() -> Dictionary:
	_record = _id == Cases23.RECORDING
	_loss = Vector3i.ZERO
	_trace = false
	_recorded_shots.clear()
	var hero_case: bool = _record or Cases23.HERO_CASES.has(_id)
	var config: Array = Cases23.HERO_CASES.get(_id, Cases23.HERO_CASES["fire_hit"]) if hero_case else Cases23.inventory()[_id]
	_card = config[0] if hero_case else ""
	_wanted_effect = config[2]
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	if Cases23.DRAGON_CASES.has(_id):
		var fixture: Dictionary = Spells18.fixture(Cases23.DRAGON_CASES[_id], _run_engine, _combat_engine, profile, DEFAULT_SEED, "")
		if fixture.is_empty(): return {}
		_steps.append(fixture["step"])
		_opponent_tile = fixture["actor"]["pos"]
		_aim = fixture["step"].get("to", Cases23.HERO)
		return fixture
	_opponent_tile = Cases23.TARGET
	_aim = (Cases23.EMPTY_TARGET if _id == "fire_floor" else _opponent_tile) if hero_case else Cases23.HERO
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": _card if hero_case else FILLER, "draw": FILLER_DRAW,
		"player_hp": Cases23.FIXTURE_HP, "player_max_hp": Cases23.FIXTURE_HP, "player_position": Cases20.coords(Cases23.HERO),
		"enemy_types": "crawler" if hero_case else config[0], "enemy_intents": "skitter_strike" if hero_case else config[1],
		"enemy_positions": Cases20.coords(_opponent_tile), "umbra_stage": "clear"}
	if _id == "lightning_chain":
		_options["enemy_types"] = "crawler,crawler"
		_options["enemy_intents"] = "skitter_strike,skitter_strike"
		_options["enemy_positions"] += "," + Cases20.coords(Cases23.CHAIN_TARGET)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	Cases20.configure(_id, _combat_engine, state)
	state["grid"][Cases23.EMPTY_TARGET.y][Cases23.EMPTY_TARGET.x] = "stone"
	if _id == "lightning_chain":
		state["grid"][Cases23.CHAIN_TARGET.y][Cases23.CHAIN_TARGET.x] = "stone"
	if _id == "fire_blocked":
		state["enemies"][0]["block"] = GameData.fixed_point_amount(Cases23.FULL_BLOCK)
	if _fog_proof:
		state["umbra"]["stage"] = FOG_STAGE
		state["umbra"]["stage_reduction"] = 0
		state["umbra"]["light_sources"] = []
	if not hero_case:
		var step: Dictionary = Cases23.enemy_step(_combat_engine, state, config[2])
		if step.is_empty(): return {}
		_steps.append(step)
		_aim = step.get("to", Cases23.HERO)
	return {"run": run, "profile": profile}

func _start_case() -> bool:
	if _record:
		var settings: Dictionary = Settings.default_settings()
		settings["master_volume"] = 0.0
		if not Settings.save_settings(settings): return false
	return await super._start_case()

func _drive_case() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	if not _card.is_empty():
		state = await _play_card(state, _card)
		if _record:
			await _play_card(state, Cases23.LIGHTNING_CARD)
	else:
		var before: Dictionary = state.duplicate(true)
		_run._combat_pacing.begin_enemies()
		await _run._animate_enemy_phase_steps(state, _steps)
		_run._combat_pacing.end_scope()
		_loss = BurstRules.damage_pools(before["player"]) - BurstRules.damage_pools(state["player"])
	_run._animation_lock = false
	_complete = true

func _play_card(state: Dictionary, card: String) -> Dictionary:
	var action: Dictionary = GameData.card_def(card)["actions"][0].duplicate(true)
	action["_card_id"] = card
	var result: Dictionary = _combat_engine.resolve_player_action_for_presentation(state, action, _aim)
	var after: Dictionary = result["state"]
	_loss = BurstRules.damage_pools(state["enemies"][0]) - BurstRules.damage_pools(after["enemies"][0])
	_trace = _run._has_electrical_trace(result["chain_hits"])
	_run._combat_pacing.begin_card()
	_run._begin_action_step_resolution_tracker(card, [action], [_aim], false)
	await _run._animate_player_action_step(state, after, card, action, _aim, result["chain_hits"])
	_run._combat_pacing.end_scope()
	return after

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var midpoint: Vector2 = board._tile_center(Cases23.HERO).lerp(board._tile_center(_opponent_tile), 0.5)
	var origin := Vector2i((board.get_global_transform_with_canvas() * midpoint).round()) - CropSize / 2
	var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
	var strip: Image
	var raw: FileAccess
	if not _plan:
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open FX-23 reel stream.")
				return {}
		else:
			strip = Image.create_empty(CropSize.x * COLUMN_NAMES.size(), CropSize.y, false, Image.FORMAT_RGB8)
	var columns: Array[int]
	var flight_frames: Array[int]
	var normalized_frames: Array[int]
	var effect_seen: bool = false
	var resolved: String = ""
	var authored_count: int = 0
	var authored_contact: int = -1
	var contact: int = -1
	var offset: int = -1
	var ends_at_center: bool = false
	var caster_visible: bool = board._board_tile_is_visible_to_player(_opponent_tile)
	var clip_start: float = -1.0
	var rendered: int = 0
	Engine.set_meta(LEGACY_FLIGHT, false)
	Engine.set_meta(LEGACY_RELEASE, false)
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
		_watch(board, frame, shown)
		var progress: float = float(shown.get("effect_progress", 0.0))
		var adapter_clock: Vector2i = Vector2i.ZERO
		if _id == Cases23.ARC_BOLT:
			var motion: Dictionary = shown.get("arc_thrall_motion", {}).get(_steps[0]["actor_key"], {})
			if motion.get("clip") == "tether":
				adapter_clock = _arc_bolt_frame(motion)
				if effect.is_empty() and contact < 0:
					effect = _steps[0]
					progress = Shot20.contact_adapter_progress(effect, motion)
		var current_shot: String = str(board._single_shot_fx._shot_id)
		var draws: bool = board._single_shot_fx._heads[0].visible
		if draws:
			_recorded_shots[current_shot] = true
			var shot: RefCounted = board._single_shot_fx
			if shot._heads[0]._masked:
				clip_start = shot._clip_spans[0].x
		var current_columns: Array[int]
		if effect.get("action_type", effect.get("kind", "")) == _wanted_effect:
			effect_seen = true
			if not current_shot.is_empty(): resolved = current_shot
			authored_count = int(shown.get("effect_frame_count", Attack.animation_frame_count(effect, 1, _reduced)))
			var profile: Dictionary = Dragon.profile(effect)
			var release_at: float = Dragon.RELEASE if not profile.is_empty() else Shot20.release_for(Attack.style_for_effect(effect))
			var contact_at: float = _run._attack_feedback_start_progress(effect)
			if _reduced: release_at = contact_at
			var action_frame: int = roundi(progress * authored_count)
			if adapter_clock != Vector2i.ZERO:
				authored_count = adapter_clock.x
				action_frame = adapter_clock.y
			if offset < 0: offset = frame
			if draws:
				flight_frames.append(frame - offset)
				if not normalized_frames.has(action_frame): normalized_frames.append(action_frame)
				if effect.get("kind") == "aoe":
					ends_at_center = board._single_shot_fx._end_offset.is_zero_approx()
			if contact < 0 and (_reduced or progress + 0.0001 >= contact_at):
				contact = frame
				authored_contact = action_frame
			if not _record:
				while columns.size() < TRAVEL_COLUMNS.size():
					var threshold: float = lerpf(release_at, contact_at, TRAVEL_COLUMNS[columns.size()])
					if progress + 0.0001 < threshold and not _reduced: break
					current_columns.append(columns.size())
					columns.append(frame)
		if not _record and contact >= 0 and AFTER_CONTACT_COLUMNS.has(frame - contact):
			current_columns.append(columns.size())
			columns.append(frame)
		var reel_frame: bool = _record and rendered < REEL_FRAMES
		if reel_frame: rendered += 1
		if not _plan and (not current_columns.is_empty() or reel_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected the exact 1920x1080 RunScene framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if reel_frame: raw.store_buffer(image.get_data())
			for column: int in current_columns:
				var frame_crop: Image = image.get_region(crop)
				strip.blit_rect(frame_crop, Rect2i(Vector2i.ZERO, CropSize), Vector2i(column * CropSize.x, 0))
				if not _save(frame_crop, COLUMN_NAMES[column] + ".png"): return {}
				if column == 3 and not _save(image, "native-evidence.png"): return {}
			if reel_frame and draws and not FileAccess.file_exists(_output.path_join(current_shot + "-evidence.png")):
				if not _save(image, current_shot + "-evidence.png"): return {}
		if _ended_at >= 0:
			if _record and rendered == REEL_FRAMES: break
			if not _record and contact >= 0 and frame >= contact + AFTER_CONTACT_COLUMNS[-1]: break
	if raw != null: raw.close()
	if not effect_seen or _ended_at < 0 or (not _record and columns.size() != COLUMN_NAMES.size()):
		_fail("Incomplete FX-23 action or sample schedule for " + _id)
		return {}
	if not _plan and not _record and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {
		"case": _id, "shot": resolved, "draw_frames": flight_frames, "action_draw_frames": normalized_frames,
		"contact": contact - offset, "action_contact": authored_contact, "action_frames": authored_count,
		"frames": stats.get("authored_frames", 0), "duration_usec": stats.get("authored_duration_usec", 0), "done": _ended_at - offset,
		"legacy_flight": Engine.get_meta(LEGACY_FLIGHT), "legacy_release": Engine.get_meta(LEGACY_RELEASE),
		"bursts": _spawns.duplicate(true), "loss": [_loss.x, _loss.y, _loss.z],
		"aim": Cases20.coords(_aim), "ends_at_center": ends_at_center, "electrical_trace": _trace,
		"caster_visible": caster_visible, "clip_start": clip_start,
		"columns": columns, "reel_frames": rendered, "recorded_shots": _recorded_shots.keys(),
	}

func _arc_bolt_frame(motion: Dictionary) -> Vector2i:
	var clip: Dictionary = MaquetteAction.data_for("arc_thrall")["clips"][motion["clip"]]
	var count: int = MaquetteAction.frames_for("arc_thrall", motion["clip"])
	var contact: float = float(clip["contact"])
	var boundary: int = ceili(contact * (count - 1))
	var phase: float = float(motion["phase"])
	var frame: float = lerpf(0, boundary, phase / contact) if phase <= contact else lerpf(boundary, count - 1, inverse_lerp(contact, 1.0, phase))
	return Vector2i(count, roundi(frame) + 1)
