extends "res://tools/fx15/native_capture.gd"
## One fixture and observation path for the fixed-rate plan and native captures.

const Cases20 = preload("res://tools/fx20/cases.gd")
const Spells18 = preload("res://tools/fx18/cases.gd")
const Shot20 = preload("res://scripts/shot_fx.gd")
const Reflect20 = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const Reflection = preload("res://scripts/enemy_mechanics/reflect.gd")
const BIG_CROP := Vector2i(960, 720)
const CONTACT_COLUMNS: Array[int] = [0, 6, 14, 22]
const RECORD_FRAMES := 5 * FPS

var _base_dir: String
var _id: String
var _take_fixture: Dictionary
var _opponent_tile: Vector2i
var _take_targets: Array[Vector2i]
var _card: String
var _wanted_effect: String
var _ended_at: int
var _spawns: Dictionary
var _seen_stamps: Dictionary
var _view_rows: Dictionary
var _reflected_headings: Dictionary
var _row_names: Dictionary
var _still_frames: Dictionary

func _take() -> void:
	_id = _arg("--case")
	_output = _arg("--out")
	_base_dir = _arg("--base-dir")
	_record = _id == "recording"
	if not Cases20.MATRIX.has(_id) or _output.is_empty():
		_fail("Provide an FX-20 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx20/native.sh for a native 60 fps cel-look take.")
		return
	var result: Dictionary = await take_case(_id, _output, _base_dir, false)
	if not result.is_empty(): quit()

func _install_headless_clock() -> void:
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_plan_frame = PlanFrame.new()
	_plan_frame.process_priority = 1000
	root.add_child(_plan_frame)

func take_case(id: String, output: String, base_dir: String, headless: bool, reduced: bool = false) -> Dictionary:
	_id = id
	_output = output
	_base_dir = base_dir
	_plan = headless
	_record = id == "recording"
	_reduced = reduced
	_complete = false
	_ended_at = -1
	_spawns.clear()
	_seen_stamps.clear()
	_view_rows.clear()
	_still_frames.clear()
	_reflected_headings.clear()
	_steps.clear()
	_take_targets.clear()
	DirAccess.make_dir_recursive_absolute(_output)
	for name: String in Fx.metadata()["rows"]:
		_row_names[int(Fx.metadata()["rows"][name])] = name
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	_take_fixture = _build_case()
	if _take_fixture.is_empty() or not await _start_case():
		_fail("Could not prepare a resolved FX-20 take for " + id)
		return {}
	var report: Dictionary = await _capture_case()
	# Detached turn-order transitions may still be settling after the captured
	# action has completed. Let them release their tweens before freeing RunScene.
	for frame: int in TEARDOWN_FRAMES:
		if not _run._turn_order_animating: break
		await process_frame
	_viewport.queue_free()
	await process_frame
	if report.is_empty(): return {}
	var path: String = _output.path_join("take.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write " + path)
		return {}
	file.store_string(JSON.stringify(report, "\t"))
	print("FX-20 TAKE %s %s" % ["headless" if _plan else "renderer", path])
	return report

func _build_case() -> Dictionary:
	_card = ""
	_wanted_effect = ""
	if Cases20.EXTRA.has(_id):
		_case = Cases20.EXTRA[_id]
		var fixture: Dictionary = _build_take()
		_take_targets.assign(_targets)
		_wanted_effect = _steps[0].get("action_type", "") if not _steps.is_empty() else ""
		_opponent_tile = Cases20.FAR
		return fixture
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	if Cases20.SPELLS.has(_id):
		var fixture: Dictionary = Spells18.fixture(_id, _run_engine, _combat_engine, profile, DEFAULT_SEED, "")
		if fixture.is_empty(): return {}
		_steps.append(fixture["step"])
		_take_targets = Dragon.tiles(_steps[0])
		_wanted_effect = _steps[0]["action_type"]
		_opponent_tile = fixture["actor"]["pos"]
		return fixture
	var player: bool = Cases20.PLAYER.has(_id)
	var config: Array = Cases20.PLAYER[_id] if player else Cases20.ENEMY[_id]
	_card = config[0] if player else ""
	_opponent_tile = config[3] if player else config[2]
	_aim = config[4] if player else Cases20.HERO
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": _card if player else FILLER, "draw": FILLER_DRAW,
		"player_hp": Cases20.PROOF_HP, "player_max_hp": Cases20.PROOF_HP, "player_position": Cases20.coords(Cases20.HERO),
		"enemy_types": config[1] if player else config[0], "enemy_intents": config[2] if player else config[1],
		"enemy_positions": Cases20.coords(_opponent_tile), "umbra_stage": "clear"}
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	Cases20.configure(_id, _combat_engine, state)
	if not player:
		var step: Dictionary = Cases20.enemy_step(_combat_engine, state, config[3], _id == "refraction_cancelled")
		if step.is_empty(): return {}
		_steps.append(step)
		_wanted_effect = step["action_type"]
		_take_targets = Dragon.tiles(step)
	else:
		_wanted_effect = "reflected_projectile" if config[1] == "glacial_mirror" else "detonate" if _id == "trap_area" else "ranged"
		_take_targets.append(_aim)
	return {"run": run, "profile": profile}

func _start_case() -> bool:
	if not ProgressionStore.save_data(_take_fixture["profile"]) or not ProgressionStore.save_run_state(_take_fixture["run"]): return false
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
	if not _base_dir.is_empty():
		_run.set_script(load(_base_dir.path_join("run_scene.gd")))
		_run.get_node("BoardUnderlay/CombatBoard").set_script(load(_base_dir.path_join("combat_board_view.gd")))
	_run._combat_pacing.free()
	_run._combat_pacing = FixedPacing.new()
	_run._combat_pacing.install(_run)
	_viewport.add_child(_run)
	_run._close_dialogue()
	for frame: int in READY_FRAMES:
		await process_frame
		var moving: Tween = _run._board_centering_tween
		if _run.initial_presentation_is_ready() and (moving == null or not moving.is_running()): break
	for frame: int in SETTLE_FRAMES: await process_frame
	return _run._run_state.get("mode") == "combat" and _run.hand_scroll.is_visible_in_tree() and is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(_run), 1.0)

func _drive_case() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	if not _card.is_empty():
		var index: int = 1 if _id == "trap_area" else 0
		var action: Dictionary = GameData.card_def(_card)["actions"][index].duplicate(true)
		action["_card_id"] = _card
		var result: Dictionary = _combat_engine.resolve_player_action_for_presentation(state, action, _aim)
		var after: Dictionary = result["state"]
		var losses: Dictionary = _losses(state, after)
		_take_fixture["losses"] = losses
		_take_fixture["bounces"] = Reflection.bounces_between(state, after).size()
		_take_fixture["triggered"] = _combat_engine._triggered_traps_between(state, after).size()
		_run._combat_pacing.begin_card()
		_run._begin_action_step_resolution_tracker(_card, [action], [_aim], false)
		await _run._animate_player_action_step(state, after, _card, action, _aim, result["chain_hits"])
		_run._combat_pacing.end_scope()
		state = after
		if _record:
			_wanted_effect = "refraction"
			_steps.append(Cases20.enemy_step(_combat_engine, state, "aoe", false))
	if not _steps.is_empty():
		_run._combat_pacing.begin_enemies()
		var before: Dictionary = state.duplicate(true)
		var adapter: Dictionary
		var adapter_path: String
		if _id == "refraction_fallback":
			adapter = preload("res://scripts/maquette_cutout_runtime/presentation.gd").integration_for("glacial_mirror")
			adapter_path = adapter["action_adapter"]
			adapter.erase("action_adapter")
		await _run._animate_enemy_phase_steps(state, _steps)
		if not adapter_path.is_empty(): adapter["action_adapter"] = adapter_path
		_run._combat_pacing.end_scope()
		if _card.is_empty(): _take_fixture["losses"] = _losses(before, state)
	_run._animation_lock = false
	_complete = true

func _losses(before: Dictionary, after: Dictionary) -> Dictionary:
	var old: Dictionary = before["player"]
	var next: Dictionary = after["player"]
	return {"hp": old["hp"] - next["hp"], "block": old["block"] - next["block"], "stoneskin": old["stoneskin"] - next["stoneskin"]}

func _watch(board: Control, frame: int, shown: Dictionary) -> void:
	var effect: Dictionary = shown.get("effect", {})
	if not shown.get("impact_decals", []).is_empty():
		for decal: Dictionary in shown["impact_decals"]:
			if not decal.get("baked_strike", false):
				_record_spawn("decal:" + Cases20.coords(decal["tile"]), decal["tile"], "legacy_decal", frame)
	for stamp: Node in board._tile_bursts._stamps:
		if not stamp.front: continue
		_record_spawn("tile:%d" % stamp.get_instance_id(), stamp.tile, _row_names.get(stamp.sample.y, str(stamp.sample.y)), frame)
		if stamp.reduced: _still_frames[Cases20.coords(stamp.tile)] = stamp.sample.x
	# The falling front is travel. The rear/front TileBurst pair is its impact.
	for stamp: Node in board._sky_strikes._stamps:
		_view_rows[Cases20.coords(stamp.tile)] = stamp.sample.y
	var shot: RefCounted = board._single_shot_fx
	for stamp: Node in shot._hits:
		if stamp.lifetime_start >= 0:
			_record_spawn("shot:%d:%d" % [stamp.get_instance_id(), stamp.lifetime_start], stamp.hit_tile, stamp.hit_id, frame)
	var reflected: Node2D = shot.get("_reflected_head")
	if is_instance_valid(reflected) and reflected.visible:
		var travel: Dictionary = Reflect20.projectile_frame(shown["effect_progress"], effect["en05_outbound_seconds"])
		if float(travel["travel"]) > 0.25 and float(travel["travel"]) < 0.75:
			var leg: String = "return" if travel["returning"] else "outbound"
			var step: float = absf(float(travel["travel"]) - 0.5)
			if not _reflected_headings.has(leg) or step < _reflected_headings[leg]["distance"]:
				_reflected_headings[leg] = {"distance": step, "cell": reflected._frame_rect.x, "design": shot._shot_id}
	if effect.get("veilbound_acolyte_melee", false):
		var layer: Control = board._effects_render_layer
		if not layer._enemy_strike_trail.resolved.is_empty():
			_take_fixture["trail"] = layer._enemy_strike_trail.resolved.get("sampler", "")

func _record_spawn(id: String, tile: Vector2i, design: String, frame: int) -> void:
	if _seen_stamps.has(id): return
	_seen_stamps[id] = true
	var entries: Array = _spawns.get_or_add(Cases20.coords(tile), [])
	entries.append({"design": design, "frame": frame})

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var crop_size: Vector2i = BIG_CROP if Cases20.LARGE_CROP.has(_id) else CropSize
	var area := Rect2(board._tile_center(_opponent_tile), Vector2.ZERO)
	for tile: Vector2i in _take_targets: area = area.expand(board._tile_center(tile))
	area = area.expand(board._tile_center(Cases20.HERO))
	var center: Vector2 = board.get_global_transform_with_canvas() * area.get_center()
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(crop_size.x * (1 + CONTACT_COLUMNS.size()), crop_size.y, false, Image.FORMAT_RGB8)
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open the FX-20 recording stream.")
				return {}
	var release: int = -1
	var contact: int = -1
	var numbers: int = -1
	var clip_frames: int = 0
	var shown_effects: Dictionary
	var columns: Dictionary
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
		var effect: Dictionary = shown.get("effect", {})
		_watch(board, frame, shown)
		if numbers < 0 and not shown.get("floating_texts", []).is_empty(): numbers = frame
		if not effect.is_empty():
			var action: String = str(effect.get("action_type", effect.get("kind", "")))
			shown_effects[action] = true
			if action == _wanted_effect and (_id != "icefall" or effect.get("icefall_phase") == "puff"):
				var t: float = float(shown.get("effect_progress", 0.0))
				var release_at: float = Dragon.RELEASE if _id in Cases20.LARGE_CROP or _id in Cases20.SPELLS else Shot20.release_for(Attack.style_for_effect(effect))
				var contact_at: float = _run._attack_feedback_start_progress(effect)
				if action == "refraction": contact_at = Dragon.CONTACT
				if action == "reflected_projectile":
					release_at = 0.0
					contact_at = 1.0
				if release < 0 and t >= release_at: release = frame
				if contact < 0 and t + 0.0001 >= contact_at: contact = frame
		# The cutout's action clock exists before its contact-only effect.
		var mirror_motion: Dictionary = shown.get("glacial_mirror_motion", {}).get("enemy_1", {})
		if _wanted_effect == "refraction" and mirror_motion.get("clip") == "refraction":
			if float(mirror_motion["phase"]) >= Dragon.RELEASE and release < 0: release = frame
			if numbers >= 0 and contact < 0: contact = numbers
		if contact < 0 and numbers >= 0: contact = numbers
		var column: int = -1
		if frame == release: column = 0
		elif contact >= 0 and CONTACT_COLUMNS.has(frame - contact):
			column = 1 + CONTACT_COLUMNS.find(frame - contact)
		if column >= 0: columns[column] = frame
		var record_frame: bool = _record and frame < RECORD_FRAMES
		if record_frame: clip_frames += 1
		if not _plan and (column >= 0 or record_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected an exact 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if record_frame and raw != null: raw.store_buffer(image.get_data())
			if column >= 0:
				var origin := Vector2i(center.round()) - crop_size / 2
				var crop := Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - crop_size), crop_size)
				strip.blit_rect(image, crop, Vector2i(column * crop_size.x, 0))
				if column == 1 and not _save(image, "native-evidence.png"): return {}
		if _ended_at >= 0 and (not _record or clip_frames == RECORD_FRAMES) and (contact < 0 or frame >= contact + CONTACT_COLUMNS[-1]): break
	if raw != null: raw.close()
	if _ended_at < 0 or (_record and (clip_frames != RECORD_FRAMES or not shown_effects.has("refraction"))):
		_fail("The FX-20 take did not complete: " + _id)
		return {}
	if not _plan and (columns.size() != 1 + CONTACT_COLUMNS.size() or not _save(strip, "strip.png")):
		_fail("Could not capture all five columns for " + _id)
		return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _id, "release": release, "contact": contact, "numbers": numbers, "done": _ended_at,
		"frames": stats.get("authored_frames", 0), "rendered": stats.get("rendered_frames", 0),
		"duration_usec": stats.get("authored_duration_usec", 0), "effects": shown_effects, "bursts": _spawns.duplicate(true),
		"strikes": _view_rows.duplicate(), "trail": _take_fixture.get("trail", ""), "headings": _reflected_headings.duplicate(true),
		"losses": _take_fixture.get("losses", {}), "bounces": _take_fixture.get("bounces", 0), "triggered": _take_fixture.get("triggered", 0),
		"targets": _take_targets.map(Cases20.coords), "hidden": hidden.map(Cases20.coords), "stills": _still_frames.duplicate(),
		"columns": columns, "clip_frames": clip_frames}
