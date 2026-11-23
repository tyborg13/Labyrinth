extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Room = preload("res://tools/hoarder_inspection.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const FixedPacing = preload("res://tools/fx15/native_capture.gd").FixedPacing
const Clock = preload("res://scripts/presentation_clock.gd")
const Pixels = preload("pixels.gd")
const BasePixels = preload("base_pixels.gd")
const LoadingCover = preload("loading_cover.gd")

const FPS: int = 60
const STRIDE: int = 6
const PULSE_FRAMES: int = 72
const SETTLE_FRAMES: int = 12
const READY_LIMIT: int = 360
const PLAYBACK_LIMIT: int = 480
const DEATH_PHASES: Array[float] = [0.10, 0.45, 0.78]
const HERO_TILE := Vector2i(4, 4)
const SUBJECTS: Array[String] = ["tick_plus2", "tick_plus4", "hoarder"]
const STAGED_TILES: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 4), Vector2i(3, 4)]
const CROP_SIZE := Vector2i(180, 180)
const CROP_SCALE: int = 3
const CARD: String = "quick_stab"
const LETHAL_HP: int = 1
const TEARDOWN_FRAMES: int = 32

var _output: String
var _plan: bool
var _before: bool
var _round0_order: bool
var _scene: Control
var _board: Control
var _combat := Combat.new()
var _state: Dictionary
var _subject_ids: Dictionary
var _pending: bool
var _failed: bool
var _samples: Dictionary
var _strip: Image

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_index: int = args.find("--out")
	_output = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else ""
	_plan = args.has("--plan")
	_before = args.has("--before")
	_round0_order = args.has("--round0-order")
	if not _check(_output.is_absolute_path(), "Provide an absolute --out path."): return
	if not _check(_plan or (DisplayServer.get_name() != "headless" and not Engine.get_write_movie_path().is_empty() and Clock._read_movie_fps() == FPS
			and OS.get_environment("LABYRINTH_CEL_LOOK") == "all"), "Native capture requires cel look all, a renderer and the 60 fps presentation clock."): return
	if _plan: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	DirAccess.make_dir_recursive_absolute(_output)
	if not await _start_fight(): return
	if _round0_order:
		await _finish()
		return
	for subject: String in ["tick_plus2", "tick_plus4", "tick_plus4", "hoarder"]:
		if not await _play_kindle(subject): return
	for frame: int in SETTLE_FRAMES: await _frame()
	if not _capture("kindled", SUBJECTS): return
	var glow_nodes: Array[Node] = _board.find_children("KindleGlow_*", "Node2D", true, false)
	if not _check((glow_nodes.size() > 0) == _before, "Unexpected legacy KindleGlow node count %d." % glow_nodes.size()): return
	print("FX-38 %s Fire fight: Tick +2, Tick +4, Hoarder +2; legacy glow nodes=%d" % ["BASE" if _before else "AFTER", glow_nodes.size()])
	if not _before:
		if not _check_sprite_profiles(): return
		if not await _pulse(): return
		if not _check(await _pixel_proof(), "Kindle pixel proof failed."): return
		if not await _hit(false): return
		if not await _hit(true): return
	var report: FileAccess = FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if not _check(report != null, "Cannot write take.json."): return
	report.store_string(JSON.stringify({"plan": _plan, "cel": OS.get_environment("LABYRINTH_CEL_LOOK"), "samples": _samples}, "\t"))
	print("FX-38 %s %s PASS (%d captures) %s" % ["BEFORE" if _before else "AFTER", "PLAN" if _plan else "NATIVE", _samples.size(), _output.path_join("take.json")])
	await _finish()

func _finish() -> void:
	current_scene = null
	_scene.queue_free()
	for frame: int in TEARDOWN_FRAMES: await process_frame
	quit()

func _start_fight() -> bool:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(Store.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var engine := Run.new()
	var run: Dictionary = Room.build(engine, _combat, engine.create_new_run(Room.FIXTURE_SEED, profile), {})
	_state = run["combat_state"]
	if not _check(_state.get("room_element") == "fire", "Expected a generated Fire Hoarder room."): return false
	var ticks: Array[int]
	for enemy: Dictionary in _state["enemies"]:
		if enemy["type"] == "ember_tick": ticks.append(enemy["id"])
		if enemy["type"] == "ember_hoarder": _subject_ids["hoarder"] = enemy["id"]
	if not _check(ticks.size() >= 2 and _subject_ids.has("hoarder"), "Generated Fire room lacks the three proof actors."): return false
	_subject_ids["tick_plus2"] = ticks[0]
	_subject_ids["tick_plus4"] = ticks[1]
	if not _stage_tiles(): return false
	if not _check(Store.save_data(profile) and Store.save_run_state(run), "Could not save the proof fight."): return false
	# The real cover hands off SceneTree.current_scene, which lives under root.
	root.size = CaptureViewport.SIZE
	root.content_scale_size = CaptureViewport.SIZE
	root.content_scale_factor = 1.0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var cover := LoadingCover.new()
	if not _check(await cover.enter(self), "Title Continue did not finish its loading cover."): return false
	_scene = cover.scene
	_board = _scene.board_view
	var label: String = "ROUND 0" if _round0_order else "BASE" if _before else "ROUND 1"
	if not _check(cover.verify(_board, label, not _before and not _round0_order), "Cover/board shader order or Kindle code differed."): return false
	if _round0_order: return true
	if _plan:
		_scene._combat_pacing.free()
		_scene._combat_pacing = FixedPacing.new()
		_scene._combat_pacing.install(_scene)
	_scene._close_dialogue()
	for frame: int in READY_LIMIT:
		await _frame()
		var moving: Tween = _scene._board_centering_tween
		if _scene.initial_presentation_is_ready() and (moving == null or not moving.is_running()): break
	return _check(Vector2i(root.get_visible_rect().size) == CaptureViewport.SIZE and _scene._run_state.get("mode") == "combat"
		and is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(_scene), 1.0)
		and _scene.hand_scroll.is_visible_in_tree(), "Expected a 1920×1080 resumed combat with the HUD at 100% UI scale.")

func _stage_tiles() -> bool:
	var reserved: Array[Vector2i]
	reserved.assign(STAGED_TILES)
	reserved.append(HERO_TILE)
	for tile: Vector2i in reserved:
		if not _check(_combat._tile_is_passable(_state, tile), "Proof tile is blocked: %s." % tile): return false
	_state["player"]["pos"] = HERO_TILE
	for index: int in SUBJECTS.size():
		_state["enemies"][_index(SUBJECTS[index])]["pos"] = STAGED_TILES[index]
	for enemy: Dictionary in _state["enemies"]:
		if _subject_ids.values().has(enemy["id"]) or not reserved.has(enemy["pos"]): continue
		for tile: Vector2i in _combat._all_passable_tiles(_state):
			if reserved.has(tile) or _combat._occupied_enemy_tiles(_state).has(tile): continue
			enemy["pos"] = tile
			reserved.append(tile)
			break
		if not _check(not STAGED_TILES.has(enemy["pos"]) and enemy["pos"] != HERO_TILE, "Proof tiles overlap another enemy."): return false
	return true

func _play_kindle(subject: String) -> bool:
	var index: int = _index(subject)
	var enemy: Dictionary = _state["enemies"][index]
	var old_bonus: int = int(enemy.get("kindled_bonus", 0))
	enemy["intent"] = _combat._intent_by_id(Data.enemy_property(enemy["type"], "intents", []), "kindle").duplicate(true)
	var action: Dictionary = enemy["intent"]["actions"][0]
	var context: Dictionary = _combat.enemy_intent_plan(_state, index)
	var resolved: Dictionary = _combat._resolve_enemy_action(_state.duplicate(true), index, action, null, {}, _combat._dictionary_values([]), context)
	var step: Dictionary = _combat._enemy_action_step(_state, resolved, index, action, context)
	if not _check(step.get("action_type") == "kindle" and resolved["enemies"][index].get("kindled_bonus") == old_bonus + 2, "Real Kindle failed to add +2 for " + subject): return false
	_play(func() -> void: await _scene._animate_enemy_phase_steps(_state.duplicate(true), [step]))
	for frame: int in PLAYBACK_LIMIT:
		await _frame()
		if not _pending: break
	if not _check(not _pending and _unit(subject).get("kindled_bonus") == old_bonus + 2, "Kindle playback failed for " + subject): return false
	_state = resolved
	print("FX-38 KINDLE %s +%d" % [subject, old_bonus + 2])
	return true

func _pulse() -> bool:
	for frame: int in range(PULSE_FRAMES + 1):
		await _frame()
		if frame % STRIDE != 0: continue
		if not _capture("pulse_%02d" % frame, SUBJECTS): return false
	var span: int = int(_samples["pulse_72"]["clock_ms"]) - int(_samples["pulse_00"]["clock_ms"])
	var expected_span: int = roundi(1000.0 * PULSE_FRAMES / FPS)
	if not _plan:
		if not _check(absi(span - expected_span) <= 1, "Presentation-clock pulse span differs from 1.2 s."): return false
		if not _save(_strip, "pulse_strip.png"): return false
	print("FX-38 PULSE %d frames at %d fps, stride %d%s" % [PULSE_FRAMES + 1, FPS, STRIDE, " (planned)" if _plan else ", clock %d ms" % span])
	return true

func _hit(lethal: bool) -> bool:
	var subject: String = "tick_plus2"
	var index: int = _index(subject)
	var target: Vector2i = _state["enemies"][index]["pos"]
	var before: Dictionary = _state.duplicate(true)
	if lethal:
		before["enemies"][index]["hp"] = LETHAL_HP
		_scene._render_board_state(before, {})
		for frame: int in SETTLE_FRAMES: await _frame()
	var action: Dictionary = Data.card_def(CARD)["actions"][0]
	before["current_actor"] = {"kind": "player", "key": "player"}
	var result: Dictionary = _combat.resolve_player_action_for_presentation(before, action, target)
	var after: Dictionary = result["state"]
	var health: int = after["enemies"][index]["hp"]
	if not _check((health == 0) == lethal and health < before["enemies"][index]["hp"], "Quick Stab failed to deliver the intended hit."): return false
	_play(func() -> void: await _play_hit(before, after, action, target, result["chain_hits"]))
	var captured: int = 0
	var key: String = "enemy_%d" % int(_subject_ids[subject])
	for frame: int in PLAYBACK_LIMIT:
		await _frame()
		var unit: Dictionary = _unit(subject)
		if not lethal and captured == 0 and int(unit.get("kindled_bonus", 0)) == 2 and _board._unit_impact_strength(unit) > 0.0:
			if not _capture("hit_flash", [subject]): return false
			print("FX-38 HIT FLASH frame=%d opacity=%.4f" % [frame, _board._unit_impact_strength(unit)])
			captured += 1
		if lethal and captured < DEATH_PHASES.size() and _board._enemy_shadow_dissolve_effects_by_key.has(key):
			var phase: float = _board._death_dissolve_progress(unit)
			if phase >= DEATH_PHASES[captured] and phase < 1.0:
				if not _capture("death_%d" % captured, [subject]): return false
				print("FX-38 DISSOLVE frame=%d phase=%.4f" % [frame, phase])
				captured += 1
		if not _pending: break
	_state = after
	return _check(not _pending and captured == (DEATH_PHASES.size() if lethal else 1), "Incomplete %s playback (%d captures)." % ["dissolve" if lethal else "hit flash", captured])

func _play_hit(before: Dictionary, after: Dictionary, action: Dictionary, target: Vector2i, chain_hits: Array) -> void:
	_scene._animation_lock = true
	_scene._combat_pacing.begin_card()
	await _scene._animate_player_action_step(before, after, CARD, action, target, chain_hits)
	_scene._combat_pacing.end_scope()
	_scene._animation_lock = false

func _check_sprite_profiles() -> bool:
	var kindle: Script = load("res://scripts/enemy_mechanics/kindle_view.gd")
	var profile: int = Pixels.Art.ACTOR
	var material: ShaderMaterial = _board.material
	var shared: bool = material == _board._art_treatment.material
	for canvas: Control in _board._scene_render_layers_by_tile.values():
		shared = shared and canvas.material == material
	for body: Node in _board.find_children("UnitBody_*", "Control", true, false):
		shared = shared and (body as Control).material == material
	if not _check(shared and material.get_shader_parameter("kindle_strengths") == Vector2(kindle.GLOW_ALPHA, kindle.CAPPED_GLOW_ALPHA)
			and material.get_shader_parameter("kindle_orange") == Vector3(kindle.ORANGE.r, kindle.ORANGE.g, kindle.ORANGE.b),
			"Board actor canvases must share the configured Kindle material."): return false
	for subject: String in SUBJECTS:
		var unit: Dictionary = _unit(subject).duplicate()
		var expected: int = profile + (kindle.CAPPED_PROFILE_OFFSET if subject == "tick_plus4" else kindle.GLOW_PROFILE_OFFSET)
		if not _check(kindle.sprite_profile(unit, profile) == expected, "Kindle sprite profile missing for " + subject): return false
		unit["death_animation"] = true
		if not _check(kindle.sprite_profile(unit, profile) == profile, "Kindle sprite profile survived death."): return false
		unit["death_animation"] = false
		unit["kindled_bonus"] = 0
		if not _check(kindle.sprite_profile(unit, profile) == profile, "Kindle sprite profile survived bonus reset."): return false
	print("FX-38 PROFILES PASS (three actors, death, bonus reset)")
	return true

func _pixel_proof() -> bool:
	if not BasePixels.check_inactive_source(): return false
	if _plan: return Pixels.check_reference()
	var material: ShaderMaterial = _board.material.duplicate()
	var base: ShaderMaterial = BasePixels.material_for(_board, material)
	var hero: Dictionary = _board._visible_units().filter(func(unit: Dictionary) -> bool: return unit.get("key") == "player")[0]
	if not await Pixels.check_non_kindle(self, _board._texture_for_unit(hero), material, base): return false
	if not await BasePixels.check_floor(self, _board): return false
	for subject: String in SUBJECTS:
		var unit: Dictionary = _unit(subject)
		var texture: Texture2D = _board._texture_for_unit(unit)
		var rig: Node = _board.unit_cutout_renderer(unit)
		var facing: String = str(rig.snapshot().get("facing", "")) if is_instance_valid(rig) else "static"
		if not await Pixels.renderer(self, texture, material, base, "%s/%s" % [subject, facing]): return false
	return true

func _capture(name: String, subjects: Array) -> bool:
	var crops: Dictionary
	for subject: String in subjects:
		var unit: Dictionary = _unit(subject)
		if not _check(not unit.is_empty(), "Missing proof draw unit " + subject): return false
		var rect: Rect2 = _board._unit_texture_draw_rect(unit, _board._unit_center(unit))
		var center: Vector2 = _board.get_global_transform_with_canvas() * rect.get_center()
		var corner: Vector2i = Vector2i(center.round()) - CROP_SIZE / 2
		crops[subject] = Rect2i(corner.clamp(Vector2i.ZERO, CaptureViewport.SIZE - CROP_SIZE), CROP_SIZE)
	_samples[name] = {"crops": str(crops), "clock_ms": Clock.ticks_msec()}
	if _plan: return true
	var image: Image = root.get_texture().get_image()
	if not _check(image != null and image.get_size() == CaptureViewport.SIZE, "Framebuffer size differs from 1920×1080."): return false
	if not _save(image, "%s_full.png" % name): return false
	for subject: String in subjects:
		var crop: Image = image.get_region(crops[subject])
		crop.resize(CROP_SIZE.x * CROP_SCALE, CROP_SIZE.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
		if not _save(crop, "%s_%s_3x.png" % [name, subject]): return false
		if name.begins_with("pulse_") and subject == "tick_plus4":
			var column: int = name.trim_prefix("pulse_").to_int() / STRIDE
			if _strip == null:
				_strip = Image.create_empty(crop.get_width() * (PULSE_FRAMES / STRIDE + 1), crop.get_height(), false, crop.get_format())
			_strip.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(column * crop.get_width(), 0))
	return true

func _frame() -> void:
	await process_frame
	if not _plan: await RenderingServer.frame_post_draw

func _save(image: Image, filename: String) -> bool:
	var path: String = _output.path_join(filename)
	if not _check(image.save_png(path) == OK, "Could not save " + path): return false
	print(path)
	return true

func _unit(subject: String) -> Dictionary:
	var key: String = "enemy_%d" % int(_subject_ids[subject])
	for unit: Dictionary in _board._visible_units():
		if unit.get("key") == key: return unit
	return {}

func _index(subject: String) -> int:
	for index: int in _state["enemies"].size():
		if _subject_ids[subject] == _state["enemies"][index]["id"]: return index
	return -1

func _play(action: Callable) -> void:
	_pending = true
	await action.call()
	_pending = false

func _check(value: bool, message: String) -> bool:
	if value: return true
	if not _failed: push_error(message)
	_failed = true
	quit(1)
	return false
