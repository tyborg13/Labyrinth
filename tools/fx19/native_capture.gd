extends "res://tools/fx15/native_capture.gd"
## Matched fixed-frame RunScene takes, with logic-only observation in headless.

const RuleFixtures = preload("res://tests/suites/battlefield_rules_suite.gd")
const StalkerFixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const PROOF_CROP := Vector2i(960, 720)
const CROP_BODY_HEADROOM: int = 150
const DEPARTURE_OFFSETS: Array[int] = [0, 4, 8, 12]
const ARRIVAL_OFFSETS: Array[int] = [0, 6, 14]
const VIDEO_FRAMES: int = 300
const CARD: String = "shadow_gate"
const FOE := Vector2i(7, 6)
const SHADOW_HERO := Vector2i(5, 5)
const SHADOW_ORIGIN := Vector2i(5, 1)
const STALKER_ORIGIN := Vector2i(6, 4)
const PROOF_SKILL_LEVEL: int = 6
const HERO_FOUR_TILE_TARGET := Vector2i(6, 2)
const DISTANCES: Dictionary = {"hero2": 2, "hero3": 3, "hero4": 4,
	"ghost_stride": 2, "glassway": 2, "afterimage": 2, "recording": 3}
const ENEMY_CASES: Array[String] = ["shadowstep", "fade", "ambush"]
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const DRAW_PROBE := preload("res://tools/fx19/draw_probe.gd")

var _board_source: String
var _origin: Vector2i
var _landing: Vector2i
var _actor: String
var _resolved: Dictionary
var _active_frame: int
var _cues: Array[int]
var _preview: Dictionary
var _fixture_state: Dictionary
var _board_zero: float

func _take() -> void:
	_case = _arg("--case")
	_output = _arg("--out")
	_baseline = _arg("--baseline-run-script")
	_board_source = _arg("--baseline-board-script")
	_plan = OS.get_cmdline_user_args().has("--plan")
	_reduced = OS.get_cmdline_user_args().has("--reduced-motion")
	_record = _case == "recording"
	if (not DISTANCES.has(_case) and not ENEMY_CASES.has(_case)) or _output.is_empty():
		_fail("Provide a known FX-19 case and --out.")
		return
	if not _plan and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("Run tools/fx19/native.sh for native cel look capture at 60 fps.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		_plan_frame = PlanFrame.new()
		_plan_frame.process_priority = 1000
		root.add_child(_plan_frame)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = _reduced
	Settings.save_settings(settings)
	var fixture: Dictionary = _blink_fixture()
	if _failed: return
	if not await _start_blink(fixture):
		_fail("Could not resume a RunScene combat with the HUD at 1920×1080 and 100% UI scale.")
		return
	var receipt: Dictionary = await _observe_blink()
	if _failed: return
	var path: String = _output.path_join("take.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write " + path)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("FX-19 %s %s reduced=%s departure=%d arrival=%d complete=%d cues=%s rows=%d" % [
		"PLAN" if _plan else "NATIVE", _case, _reduced, receipt.departure, receipt.arrival,
		receipt.complete, receipt.cues, receipt.stamps.size()])
	print(path)
	_viewport.queue_free()
	await process_frame
	_validate_blink_take(receipt)
	if not _failed: quit(0)

func _validate_blink_take(_receipt: Dictionary) -> void:
	pass

func _blink_fixture() -> Dictionary:
	_actor = "player"
	var hero: Vector2i = SHADOW_HERO if _case == "shadowstep" else Hero
	var foe: Vector2i = SHADOW_ORIGIN if _case == "shadowstep" else STALKER_ORIGIN if _case in ["fade", "ambush"] else FOE
	_options = {
		"scenario": "combat", "seed": DEFAULT_SEED, "hand": CARD + ("," + CARD if _record else ""),
		"draw": FILLER_DRAW, "player_hp": HERO_HP, "player_max_hp": HERO_HP,
		"player_position": _coord(hero), "enemy_types": "gloam_stalker" if _case in ["fade", "ambush"] else "crawler",
		"enemy_intents": _case if _case in ["fade", "ambush"] else "",
		"enemy_positions": _coord(foe), "umbra_stage": "clear",
	}
	if _case == "glassway": _options["relics"] = "glassway_compass"
	if _case in ["ghost_stride", "afterimage"]:
		_options["level"] = PROOF_SKILL_LEVEL
		_options["skills"] = "ghost_stride,afterimage" if _case == "afterimage" else "ghost_stride"
	var profile: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	state["terrain"] = []
	state["traps"] = []
	state["loot"] = []
	if _case in ["hero4", "fade", "ambush"]:
		state["grid"] = StalkerFixtures.grid()
		run["current_room_layout"]["grid"] = state["grid"].duplicate(true)
	if _record: state["cards_per_turn"] = maxi(int(state["cards_per_turn"]), RECORDING_CARD_PLAYS)
	if _case == "ghost_stride":
		state = _combat_engine.arm_ghost_stride(state)
	if _case == "shadowstep":
		state["umbra"] = {"stage": "heart", "vision_bonus": 0, "stage_reduction": 0}
		Rules.install(_combat_engine, state, RuleFixtures.rule("shadowstep", {"blink": RuleFixtures.TEST_BLINK}))
	_origin = hero
	if DISTANCES.has(_case):
		_aim = hero + Vector2i.UP * int(DISTANCES[_case])
		if _case == "hero4": _aim = HERO_FOUR_TILE_TARGET
		_landing = _aim
		if _case == "glassway": state = _combat_engine._create_illusion(state, _aim, GameData.fixed_point_amount(3))
	else:
		var unit: Dictionary = state["enemies"][0]
		_origin = foe
		_actor = "enemy_%d" % int(unit["id"])
	run["combat_state"] = state
	return {"run": run, "profile": profile}

func _start_blink(fixture: Dictionary) -> bool:
	if not ProgressionStore.save_data(fixture["profile"]) or not ProgressionStore.save_run_state(fixture["run"]): return false
	root.size = SinkSize
	root.content_scale_size = SinkSize
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = CanvasSize
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _plan else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if not _baseline.is_empty():
		var run_script: GDScript = DRAW_PROBE.compile_source(_baseline, "run")
		if run_script == null: return false
		_run.set_script(run_script)
	if _plan or not _board_source.is_empty():
		var path: String = "res://scripts/combat_board_view.gd" if _board_source.is_empty() else _board_source
		var board_script: GDScript = DRAW_PROBE.compile_source(path, "board", _plan)
		if board_script == null: return false
		_run.get_node("BoardUnderlay/CombatBoard").set_script(board_script)
	if _plan:
		_run._combat_pacing.free()
		_run._combat_pacing = FixedPacing.new()
		_run._combat_pacing.install(_run)
	_viewport.add_child(_run)
	_run._close_dialogue()
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2.ONE
	_viewport.push_input(pointer, true)
	for frame: int in READY_FRAMES:
		await process_frame
		var moving: Tween = _run._board_centering_tween
		if _run.initial_presentation_is_ready() and (moving == null or not moving.is_running()): break
	for frame: int in SETTLE_FRAMES: await process_frame
	if _run._run_state.get("mode") != "combat" or not _run.hand_scroll.is_visible_in_tree():
		return false
	return _viewport.size == CanvasSize and is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(_run), 1.0)

func _prepare_blink() -> bool:
	_fixture_state = _run._combat_state.duplicate(true)
	var engine: RefCounted = _run._combat_engine
	var action: Dictionary
	if _case == "shadowstep":
		_steps.clear()
		_resolved = Rules.fire(engine, _fixture_state.duplicate(true), _steps)
		if _steps.size() != 1 or engine.is_tile_visible_to_player(_fixture_state, _origin): return false
	elif _case in ["fade", "ambush"]:
		var resolution: Dictionary = engine.resolve_enemy_turn_with_steps(_fixture_state.duplicate(true), 0, true, false)
		_steps.assign(resolution.get("steps", []))
		_steps = TypedArrays.dictionaries(_steps.filter(func(step: Dictionary) -> bool: return bool(step.get("en03_veil", false))))
		if _steps.size() != 1:
			_fail("Expected a single resolved %s transit step, got %d." % [_case, _steps.size()])
			return false
		_resolved = resolution.get("state", {})
	else:
		if _case in ["glassway", "ghost_stride"]: action = engine.player_movement_action(_fixture_state)
		else: action = GameData.card_def(CARD)["actions"][0]
		if _case == "ghost_stride" and action.get("type") != "blink":
			_fail("Ghost Stride did not arm during fixture setup.")
			return false
		if not engine.valid_targets_for_player_action(_fixture_state, action).has(_aim):
			_fail("Illegal fixture target %s for %s: %s." % [_aim, _case, action])
			return false
		_resolved = engine.apply_player_action(_fixture_state.duplicate(true), action, _aim)
		if _resolved["player"]["pos"] != _aim: return false
		var shown: Dictionary = _run._preview_effect_for_target(_fixture_state, _origin, _aim, action)
		if shown.get("kind") != "blink": return false
		if _plan: _preview = DRAW_PROBE.preview(_run.board_view, shown)
		return true
	var arrival: Dictionary = _run._animation_actor_unit(_resolved, _actor)
	_landing = arrival.get("pos", Vector2i(-1, -1))
	if _landing.x < 0 or _landing == _origin or not engine.is_tile_visible_to_player(_resolved, _landing):
		_fail("%s did not resolve to a distinct visible landing (%s to %s)." % [_case, _origin, _landing])
		return false
	return true

func _drive_blink() -> void:
	if _case in ENEMY_CASES:
		_run._animation_lock = true
		await _run._animate_enemy_phase_steps(_fixture_state.duplicate(true), _steps)
		_run._animation_lock = false
	elif _case in ["glassway", "ghost_stride"]:
		_run._begin_player_movement_selection()
		await _run._on_board_tile_clicked(_aim)
	else:
		await _play(CARD)
		if _record:
			_aim = Hero
			await _play(CARD)
	_complete = true

func _observe_blink() -> Dictionary:
	if not _prepare_blink():
		_fail("Resolver fixture failed for %s." % _case)
		return {}
	var board: Control = _run.board_view
	var stamp_rows: Dictionary = Fx.self_metadata()["rows"]
	var relevant_rows: Array[int] = [stamp_rows["summon_rear"], stamp_rows["summon_front"], stamp_rows["illusion_rear"], stamp_rows["illusion_front"]]
	var stamps: Dictionary
	var departure: int = -1
	var departure_seconds: float = -1.0
	var arrival_seconds: float = -1.0
	var arrival: int = -1
	var done: int = -1
	var traces: Array
	var strip: Image
	var raw: FileAccess
	var columns: Dictionary
	var crop := Rect2i()
	_run._ensure_sfx_bank()
	_run._sfx_bank.cue_requested.connect(_observe_cue)
	if not _plan and _record:
		raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Could not open recording stream.")
			return {}
	elif not _plan:
		strip = Image.create_empty(PROOF_CROP.x * (DEPARTURE_OFFSETS.size() + ARRIVAL_OFFSETS.size()), PROOF_CROP.y, false, Image.FORMAT_RGB8)
	_active_frame = Engine.get_process_frames()
	_board_zero = board._self_bursts._seconds
	_drive_blink()
	for observation: int in TAKE_LIMIT:
		if _plan:
			await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		var frame: int = Engine.get_process_frames() - _active_frame
		var effect: Dictionary = board.presentation.get("effect", {})
		var in_transit: bool = effect.get("kind") == "blink" and not effect.get("preview", false) and effect.get("from") == _origin and effect.get("to") == _landing
		var caption: bool = _case == "shadowstep" and board.presentation.get("battlefield_rule_caption", {}).get("rule") == "shadowstep"
		if departure < 0 and (in_transit or caption):
			departure = frame
			departure_seconds = board._self_bursts._seconds - _board_zero
			if not _record:
				crop = _crop_for(board)
				if crop.size != PROOF_CROP:
					_fail("The Blink crop cannot cover both tiles.")
					return {}
		if departure >= 0 and arrival < 0 and _landing_presented(board):
			arrival = frame
			arrival_seconds = board._self_bursts._seconds - _board_zero
		if _complete and done < 0: done = frame
		if _plan and in_transit:
			traces.append(DRAW_PROBE.resolved(board, effect, float(board.presentation.get("effect_progress", 0.0))))
		for stamp: Fx.Stamp in board._self_bursts._stamps:
			if not relevant_rows.has(stamp.sample.y): continue
			var id: int = stamp.get_instance_id()
			if not stamps.has(id):
				stamps[id] = {"tile": _coord(stamp.tile), "row": stamp.sample.y, "born_frame": stamp.birth_frame - _active_frame,
					"start_seconds": stamp.birth - _board_zero,
					"first": -1, "reveal": -1, "frames": [], "still": stamp.reduced,
					"depth": stamp.get_parent() == (board._scene_front_effect_render_layers_by_tile if stamp.front else board._scene_back_effect_render_layers_by_tile).get(board.draw_tile_for_unit_origin(stamp.unit, stamp.tile)),
					"center": stamp.position.is_equal_approx(board.world_position_for_unit_origin(stamp.unit, stamp.tile))}
			if stamp.visible:
				var entry: Dictionary = stamps[id]
				if entry.first < 0: entry.first = frame
				if entry.reveal < 0 and stamp.sample.x >= Fx.self_metadata()["reduced_motion_frame"]: entry.reveal = frame
				if not entry.frames.has(stamp.sample.x): entry.frames.append(stamp.sample.x)
		if not _plan and _record and observation < VIDEO_FRAMES:
			var image: Image = _viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			if image.get_size() != CanvasSize:
				_fail("Recording framebuffer has unexpected dimensions.")
				return {}
			raw.store_buffer(image.get_data())
			if frame == arrival and not _save(image, "native-evidence.png"): return {}
		elif not _record:
			var indices: Array[int]
			var early: int = DEPARTURE_OFFSETS.find(frame - departure) if departure >= 0 else -1
			var late: int = ARRIVAL_OFFSETS.find(frame - arrival) if arrival >= 0 else -1
			if early >= 0: indices.append(early)
			if late >= 0: indices.append(DEPARTURE_OFFSETS.size() + late)
			if not indices.is_empty():
				var segment: Image
				if not _plan:
					var image: Image = _viewport.get_texture().get_image()
					if image.get_size() != CanvasSize:
						_fail("Native framebuffer has unexpected dimensions.")
						return {}
					image.convert(Image.FORMAT_RGB8)
					if late == 0 and not _save(image, "native-evidence.png"): return {}
					segment = image.get_region(crop)
				for column: int in indices:
					if not _plan: strip.blit_rect(segment, Rect2i(Vector2i.ZERO, PROOF_CROP), Vector2i(column * PROOF_CROP.x, 0))
					columns[column] = frame
		if done >= 0 and arrival >= 0 and frame >= maxi(arrival + ARRIVAL_OFFSETS[-1], departure + DEPARTURE_OFFSETS[-1]) and (not _record or observation + 1 >= VIDEO_FRAMES):
			break
	if raw != null: raw.close()
	if arrival < 0 or done < 0 or departure < 0 or (_record and _cues.size() != 2):
		_fail("Incomplete Blink take %s, departure=%d arrival=%d complete=%d cues=%s" % [_case, departure, arrival, done, _cues])
		return {}
	if not _record and columns.size() != DEPARTURE_OFFSETS.size() + ARRIVAL_OFFSETS.size():
		_fail("Missing native strip frame(s): %s" % [columns])
		return {}
	if strip != null and not _save(strip, "strip.png"): return {}
	return {"case": _case, "reduced": _reduced, "departure": departure, "arrival": arrival,
		"departure_seconds": departure_seconds, "arrival_seconds": arrival_seconds,
		"complete": done, "cues": _cues, "origin": _coord(_origin), "landing": _coord(_landing),
		"stamps": stamps.values(), "preview": _preview, "transit_draws": traces, "crop": str(crop), "columns": columns}

func _landing_presented(board: Control) -> bool:
	return board._visible_units_cache.any(func(unit: Dictionary) -> bool:
		if unit.get("key") != _actor: return false
		var positions: Dictionary = board.presentation.get("unit_world_positions", {})
		if positions.has(_actor):
			return (positions[_actor] as Vector2).is_equal_approx(board.world_position_for_unit_origin(unit, _landing))
		return unit.get("pos") == _landing
	)

func _observe_cue(cue: String, _result: String) -> void:
	if cue == "move.blink": _cues.append(Engine.get_process_frames() - _active_frame)

func _crop_for(board: Control) -> Rect2i:
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var a: Vector2 = transform * board._tile_center(_origin)
	var b: Vector2 = transform * board._tile_center(_landing)
	var midpoint: Vector2 = (a + b) * 0.5 - Vector2(0, CROP_BODY_HEADROOM)
	var top_left: Vector2i = Vector2i(midpoint) - PROOF_CROP / 2
	top_left = top_left.clamp(Vector2i.ZERO, CanvasSize - PROOF_CROP)
	var crop := Rect2i(top_left, PROOF_CROP)
	if not crop.has_point(Vector2i(a)) or not crop.has_point(Vector2i(b)): return Rect2i()
	return crop
