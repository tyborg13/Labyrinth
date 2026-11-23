extends "res://tools/fx20/native_capture.gd"
## Drive the real resolver, Mortar adapter and RunScene at the proof clock.

const Lob28 = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Marked = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Action28 = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Surface28 = preload("res://scripts/board_surface_rules.gd")
const MORTAR := Vector2i(4, 2)
const EMPTY := Vector2i(6, 4)
const HIDDEN := Vector2i(7, 4)
const HIDDEN_CASE_SIGHT: String = "heart"
const CRATE_LOSS: int = 1
const REEL_FRAMES: int = 4 * FPS
const COLUMN_NAMES: Array[String] = ["release", "flight-33", "flight-66", "contact", "contact-100ms", "contact-233ms"]
const ARC_COLUMNS: Array[float] = [0.0, 0.33, 0.66]
const CONTACT_OFFSETS: Array[int] = [0, 6, 14]
const CONTACT_PROGRESS: float = Lob28.ARC_SECONDS / (Lob28.ARC_SECONDS + Lob28.SPLASH_SECONDS)
const LEGACY_TRAVEL: StringName = &"fx28_travel"
const LEGACY_IMPACT: StringName = &"fx28_impact"
const REEL_LEAD_FRAMES: int = 18
const CROP_LIFT_TILES: float = 1.0

func _take() -> void:
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if id not in ["hero", "empty", "recording"] or output.is_empty():
		_fail("Provide an FX-28 --case and --out.")
		return
	if DisplayServer.get_name() == "headless" or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Run tools/fx28/native.sh for a native cel-look take.")
		return
	if not (await take_case(id, output, _arg("--base-dir"), false)).is_empty(): quit()

func _build_case() -> Dictionary:
	_card = ""
	_aim = HIDDEN if _id == "hidden" else EMPTY if _id in ["empty", "crate", "crate_loss"] else Hero
	_opponent_tile = MORTAR
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": FILLER, "draw": FILLER_DRAW,
		"player_hp": HERO_HP, "player_max_hp": HERO_HP, "player_position": _coord(Hero),
		"enemy_types": "slag_mortar", "enemy_intents": "slag_lands", "enemy_positions": _coord(MORTAR), "umbra_stage": "clear"}
	if _id in ["crate", "crate_loss"]: _options["terrain"] = "wooden_crate@" + _coord(_aim)
	var profile: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	state.erase("battlefield_rule")
	if _id == "hidden":
		state["umbra"].merge({"stage": HIDDEN_CASE_SIGHT, "stage_reduction": 0, "light_sources": []}, true)
	else:
		state.erase("umbra")
	for tile: Vector2i in [Hero, MORTAR, _aim, _aim + Vector2i.LEFT, _aim + Vector2i.RIGHT, _aim + Vector2i.UP, _aim + Vector2i.DOWN]:
		state["grid"][tile.y][tile.x] = "stone"
	var mortar: Dictionary = state["enemies"][0]
	var action: Dictionary = mortar["intent"]["actions"][0]
	mortar["lob_center"] = _aim
	mortar["lob_tiles"] = _combat_engine._vector2i_values([_aim, _aim + Vector2i.LEFT, _aim + Vector2i.RIGHT, _aim + Vector2i.UP, _aim + Vector2i.DOWN])
	_take_targets.assign(mortar["lob_tiles"])
	if _record: return {"run": run, "profile": profile}
	var after: Dictionary = Marked.resolve(_combat_engine, state.duplicate(true), 0, action)
	# The real lob resolver leaves wooden crates alone. A second fixture supplies
	# a positive terrain delta to exercise the presentation contract independently.
	if _id == "crate_loss": after["terrain"][0]["hp"] -= CRATE_LOSS
	_steps.append(Marked.animation_step(_combat_engine, state, after, 0, action))
	return {"run": run, "profile": profile}

func _start_case() -> bool:
	if not ProgressionStore.save_data(_take_fixture["profile"]) or not ProgressionStore.save_run_state(_take_fixture["run"]): return false
	if _record:
		var settings: Dictionary = Settings.load_settings()
		settings["master_volume"] = 0.0
		if not Settings.save_settings(settings): return false
	root.size = SinkSize
	root.content_scale_size = SinkSize
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = CanvasSize
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _plan else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene_path: String = _base_dir.path_join("run_scene.tscn")
	_run = (load(scene_path) as PackedScene).instantiate()
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
	if not _record:
		await super._drive_case()
		return
	# Resume a fight with the mark held, then let the normal Pass path
	# resolve the enemy turn and consume it.
	for frame: int in REEL_LEAD_FRAMES: await process_frame
	await _run._on_pass_turn_pressed()
	_complete = true

func _capture_case() -> Dictionary:
	var board: Control = _run.board_view
	var report: Dictionary = {"release": -1, "contact": -1, "numbers": -1, "surfaces": -1, "finish": -1,
		"columns": {}, "head_samples": [], "visible_tiles": [], "timeline": [], "turn_order": [], "reel_frames": 0}
	var columns: Dictionary = report["columns"]
	var samples: Array = report["head_samples"]
	var timeline: Array = report["timeline"]
	var seen: Dictionary
	var snapshot: Dictionary
	var order_animating: bool
	var strip: Image
	var raw: FileAccess
	var area: Rect2 = _crop(board)
	if not _plan:
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Cannot write FX-28 reel frames.")
				return {}
		else:
			strip = Image.create_empty(CropSize.x * COLUMN_NAMES.size(), CropSize.y, false, Image.FORMAT_RGB8)
	for tile: Vector2i in _take_targets:
		if board._board_tile_is_visible_to_player(tile): report["visible_tiles"].append(_coord(tile))
	report["target"] = _coord(_aim)
	report["initial"] = _outcome(board.combat_state, _aim)
	Engine.set_meta(LEGACY_TRAVEL, 0)
	Engine.set_meta(LEGACY_IMPACT, 0)
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_case()
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		var shown: Dictionary = board.presentation
		var effect: Dictionary = shown.get("effect", {})
		var result: Dictionary = _outcome(board.combat_state, _aim)
		var capture_columns: Array[int]
		if effect.get("en04_mechanic") == "lob_land":
			var progress: float = float(shown["effect_progress"])
			if report["release"] < 0: report["release"] = frame
			if progress >= CONTACT_PROGRESS and report["contact"] < 0: report["contact"] = frame
			if progress < CONTACT_PROGRESS:
				var fraction: float = progress / CONTACT_PROGRESS
				var player: RefCounted = board._single_shot_fx
				var head: Node2D = player._heads[0]
				if head.visible:
					var from: Vector2 = Lob28.launch_point(board, effect)
					var to: Vector2 = board._tile_center(effect["to"])
					var lift: float = board._tile_height() * Lob28.APEX_TILES
					var direction: Vector2 = to - from - Vector2(0, 4.0 * lift * (1.0 - 2.0 * fraction))
					var rect: Vector3i = head._frame_rect
					var sheet: Dictionary = Shot20.metadata()["sizes"][player._sheet]["shots"]["ember"]
					var expected: Vector3i = Shot20.frame_rect(sheet, direction * player._physical_scale, fraction * Lob28.ARC_SECONDS, fraction)
					var apex: float = clampf(0.5 - (to.y - from.y) / (8.0 * lift), 0.0, 1.0)
					samples.append({"t": fraction, "cell": rect.x, "row": rect.y, "size": rect.z,
						"expected": [expected.x, expected.y, expected.z], "position_error": head.position.distance_to(Lob28.arc_point(from, to, board._tile_height(), fraction)),
						"grid": player._cells_px, "sheet": player._sheet, "apex": apex})
				for index: int in ARC_COLUMNS.size():
					if not columns.has(COLUMN_NAMES[index]) and fraction >= ARC_COLUMNS[index]:
						capture_columns.append(index)
		if report["contact"] >= 0:
			var age: int = frame - int(report["contact"])
			for index: int in CONTACT_OFFSETS.size():
				if age == CONTACT_OFFSETS[index]: capture_columns.append(ARC_COLUMNS.size() + index)
		if report["numbers"] < 0 and not shown.get("floating_texts", []).is_empty(): report["numbers"] = frame
		if report["surfaces"] < 0 and result["fire"]: report["surfaces"] = frame
		if _complete and report["finish"] < 0: report["finish"] = frame
		if order_animating != _run._turn_order_animating:
			order_animating = _run._turn_order_animating
			report["turn_order"].append([frame, order_animating])
		if result != snapshot or not shown.get("floating_texts", []).is_empty() or not effect.is_empty():
			timeline.append({"frame": frame, "state": result, "text": shown.get("floating_texts", []).size(), "effect": effect.get("en04_mechanic", ""), "progress": shown.get("effect_progress", -1)})
			snapshot = result
		_observe_bursts(board, frame, seen)
		for column: int in capture_columns: columns[COLUMN_NAMES[column]] = frame
		if not _plan:
			if _record and frame < REEL_FRAMES:
				var image: Image = _frame_image()
				if image == null: return {}
				raw.store_buffer(image.get_data())
				report["reel_frames"] += 1
				if frame == report["contact"] and not _save_image(image, "native-evidence.png"): return {}
			elif not _record and not capture_columns.is_empty():
				var image: Image = _frame_image()
				if image == null: return {}
				for column: int in capture_columns:
					strip.blit_rect(image, Rect2i(area), Vector2i(column * CropSize.x, 0))
					if not _save_image(image.get_region(Rect2i(area)), COLUMN_NAMES[column] + ".png"): return {}
				if frame == report["contact"] and not _save_image(image, "native-evidence.png"): return {}
		if _record and frame + 1 >= REEL_FRAMES: break
		if not _record and _complete and frame >= int(report["contact"]) + CONTACT_OFFSETS.back(): break
	report["bursts"] = seen.values()
	report["travel"] = Engine.get_meta(LEGACY_TRAVEL)
	report["impact"] = Engine.get_meta(LEGACY_IMPACT)
	report["clock"] = _run.runtime_animation_clock_snapshot()
	report["final"] = _outcome(board.combat_state, _aim)
	if report["contact"] < 0 or (_record and report["contact"] >= REEL_FRAMES):
		_fail("No Mortar landing in FX-28 take %s (actor=%s intent=%s)" % [_id, _run._combat_state.get("current_actor"), _run._combat_state["enemies"][0].get("intent")])
		return {}
	if not _plan and not _record and (columns.size() != COLUMN_NAMES.size() or not _save_image(strip, "strip.png")):
		_fail("Missing FX-28 strip columns for " + _id)
		return {}
	return report

func _observe_bursts(board: Control, frame: int, seen: Dictionary) -> void:
	for stamp: Node in board._tile_bursts._stamps:
		if not stamp.front or seen.has(stamp.get_instance_id()): continue
		seen[stamp.get_instance_id()] = {"tile": _coord(stamp.tile), "row": _row_names[stamp.sample.y],
			"born": frame, "cell": stamp.sample.x, "reduced": stamp.reduced}

func _outcome(state: Dictionary, tile: Vector2i) -> Dictionary:
	var prop_hp: int = 0
	for prop: Dictionary in state.get("terrain", []):
		if prop.get("pos") == tile: prop_hp = prop["hp"]
	var fire: int
	for marked: Vector2i in _take_targets:
		if Surface28.has_surface(state, marked, "fire"): fire += 1
	return {"health": state["player"]["hp"], "block": state["player"]["block"], "stoneskin": state["player"]["stoneskin"],
		"prop_hp": prop_hp, "fire": fire}

func _crop(board: Control) -> Rect2i:
	var center: Vector2 = board._tile_center(MORTAR).lerp(board._tile_center(_aim), 0.5) - Vector2(0, CROP_LIFT_TILES * board._tile_height())
	center = board.get_global_transform_with_canvas() * center
	var origin: Vector2i = Vector2i(center.round()) - CropSize / 2
	return Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)

func _frame_image() -> Image:
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != CanvasSize:
		_fail("Expected a 1920x1080 FX-28 framebuffer.")
		return null
	image.convert(Image.FORMAT_RGB8)
	return image

func _save_image(image: Image, file: String) -> bool:
	if image.save_png(_output.path_join(file)) != OK:
		_fail("Could not save FX-28 capture " + file)
		return false
	return true
