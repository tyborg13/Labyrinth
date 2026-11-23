extends "res://tools/fx12/native_capture.gd"

const Clock = preload("res://scripts/presentation_clock.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Meteor = preload("res://scripts/surface_card_rules.gd")
const Landing = preload("res://scripts/meteorfall_landing_view.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const EARLY_CELLS: Array[int] = [0, 2, 4]
const BURST_OFFSETS: Array[int] = [0, 6, 18]
const RECORD_PART_FRAMES: int = 100
const CONTACT_HOLD_TOLERANCE: int = 2
const OCCLUDED := Vector2i(3, 3)
const FOGGED := Vector2i(7, 1)
const BOSS_ORIGIN := Vector2i(4, 1)
const STORM_DAMAGE: int = 2
const BOSS_TILES: Array[Vector2i] = [Hero, Vector2i(3, 4), Vector2i(4, 3)]
const TAKES: Dictionary = {
	"skybreak": ["zekarion", "skybreak", "lightning", "lightning_strikes"],
	"board_rule": ["crawler", "", "lightning", "lightning_strikes"],
	"zekarion": ["zekarion", "skybreak", "lightning", "lightning_strikes"],
	"vyraketh": ["vyraketh", "kindle_ground", "fire", "cinder_marks"],
	"meteorfall": ["crawler", "", "fire", "meteor_marks"],
	"icefall": ["hoarfrost_seer", "icefall_land", "ice", "icefall_land"],
	"occlusion": ["zekarion", "skybreak", "lightning", "lightning_strikes"],
	"half_hidden": ["zekarion", "skybreak", "lightning", "lightning_strikes"],
}

var _case: String
var _baseline: String
var _reduced: bool
var _icefall_fallback: bool
var _steps: Array[Dictionary]
var _complete: bool
var _targets: Array[Vector2i]
var _plan_frame: PlanFrame

class PlanFrame extends Node:
	signal presented
	func _process(_delta: float) -> void: presented.emit()

# Headless fixed FPS has no MovieWriter clock. Use the same 60 Hz ticks
# for the stop's unscaled clock so render throughput cannot extend a beat.
class FixedHitStop extends CombatHitStop:
	func request(damage: int, killed: bool = false, hero: bool = false, reduced: bool = false, allowed: bool = true, now_usec: int = -1) -> bool:
		return super.request(damage, killed, hero, reduced, allowed, now_usec if now_usec >= 0 else _clock())

	func poll(now_usec: int = -1) -> void:
		super.poll(now_usec if now_usec >= 0 else _clock())

	func _clock() -> int:
		return roundi(Engine.get_process_frames() * 1000000.0 / FPS)

class FixedPacing extends CombatPacing:
	func install(host: Node) -> void:
		super.install(host)
		hit_stop.free()
		hit_stop = FixedHitStop.new()
		hit_stop.name = "CombatHitStop"
		hit_stop.restore_scale = current_scale
		hit_stop.scale_changing.connect(_sync_clock)
		hit_stop.stop_ended.connect(_release_flashes)
		add_child(hit_stop)

	func _sync_clock() -> void:
		_clock_usec += _movie_clock.advance(Engine.get_process_frames(), 1.0 / FPS, Engine.time_scale, is_inside_tree() and get_tree().paused)

func _take() -> void:
	_case = _arg("--case")
	_output = _arg("--out")
	_baseline = _arg("--baseline-run-script")
	_plan = OS.get_cmdline_user_args().has("--plan")
	_record = OS.get_cmdline_user_args().has("--record-part")
	_reduced = OS.get_cmdline_user_args().has("--reduced-motion")
	_icefall_fallback = OS.get_cmdline_user_args().has("--icefall-fallback")
	if not TAKES.has(_case) or _output.is_empty() or ((_reduced or _icefall_fallback) and not _plan):
		_fail("Provide a known FX-15 case and output directory.")
		return
	if not _plan and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("Run native.sh for 60 fps MovieWriter and cel look.")
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
	var fixture: Dictionary = _build_take()
	if _failed: return
	if not await _start_take(fixture):
		_fail("Could not resume a RunScene fight at 1920x1080 and 100% UI scale.")
		return
	var row: Dictionary = await _observe_take()
	if _failed: return
	var file := FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write take.json.")
		return
	file.store_string(JSON.stringify(row, "\t"))
	print("FX-15 %s %s" % ["PLAN" if _plan else "NATIVE", JSON.stringify(row)])
	_viewport.queue_free()
	await process_frame
	quit()

func _build_take() -> Dictionary:
	var config: Array = TAKES[_case]
	var boss: bool = config[0] in ["zekarion", "vyraketh"]
	var origin: Vector2i = BOSS_ORIGIN if boss else Hero + Vector2i.UP * 2
	_options = {"scenario": "combat", "seed": DEFAULT_SEED, "hand": FILLER, "draw": FILLER_DRAW,
		"player_hp": HERO_HP, "player_max_hp": HERO_HP, "player_position": _coord(Hero),
		"enemy_types": config[0], "enemy_intents": config[1], "enemy_positions": _coord(origin),
		"umbra_stage": "heart" if _case == "half_hidden" else "clear"}
	var profile: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	var run: Dictionary = _build_run_state("combat", profile)
	if run.is_empty(): return {}
	var state: Dictionary = run["combat_state"]
	state.erase("battlefield_rule")
	state["terrain"] = []
	var enemy: Dictionary = state["enemies"][0]
	var resolved_tiles: Array[Vector2i]
	match _case:
		"skybreak": resolved_tiles.assign(BOSS_TILES)
		"vyraketh": resolved_tiles.append(Hero)
		"occlusion": resolved_tiles.append(OCCLUDED)
		"half_hidden": resolved_tiles.assign([Hero, FOGGED])
	if not resolved_tiles.is_empty():
		# Give the real resolver a fixed announced footprint from the fixture.
		var intent: Dictionary = _combat_engine._intent_by_id(GameData.enemy_property(config[0], "intents", []), config[1]).duplicate(true)
		intent["actions"][0]["declared_tiles"] = resolved_tiles
		enemy["intent"] = intent
	match _case:
		"board_rule":
			var rule: Dictionary = {"rule": "lightning_storm", "source": {"kind": "room"},
				"cadence": {"anchor": "after_player_turn", "every": 1}, "dials": {"damage": STORM_DAMAGE}}
			Rules.install(_combat_engine, state, rule)
			Surfaces.place(state, Hero, "electrified")
			state["turn"] = int(state["turn"]) + 1
			Rules.fire(_combat_engine, state.duplicate(true), _steps)
		"meteorfall":
			var action: Dictionary = GameData.card_def("meteorfall")["actions"][0].duplicate(true)
			action["_card_id"] = "meteorfall"
			state = _combat_engine.apply_player_action(state, action, enemy["pos"])
			Meteor.resolve_meteor_marks(_combat_engine, state.duplicate(true), _steps)
		_:
			if _case == "icefall": enemy["icefall_tiles"] = BOSS_TILES.duplicate()
			var result: Dictionary = _combat_engine.resolve_enemy_turn_with_steps(state.duplicate(true), 0)
			for step: Dictionary in result["steps"]:
				if step.get("action_type") == config[3]: _steps.append(step)
	if _steps.size() != 1:
		_fail("Expected one resolved strike step for %s, got %d." % [_case, _steps.size()])
		return {}
	var step: Dictionary = _steps[0]
	_targets.assign(step.get("tiles", step.get("focus_tiles", [])))
	if _targets.is_empty() or (_case == "skybreak" and _targets.size() != BOSS_TILES.size()):
		_fail("Missing planned targets: " + str(step.get("action_type", _case)))
		return {}
	_aim = Hero if _targets.has(Hero) else _targets[0]
	if _case == "half_hidden" and (not _targets.has(FOGGED) or _combat_engine.is_tile_visible_to_player(state, FOGGED)):
		_fail("The fog edge fixture requires both an exposed and an Umbra-covered target.")
	run["combat_state"] = state
	return {"run": run, "profile": profile}

func _start_take(fixture: Dictionary) -> bool:
	if not _plan: return await _start(fixture)
	if not ProgressionStore.save_data(fixture["profile"]) or not ProgressionStore.save_run_state(fixture["run"]): return false
	_viewport = SubViewport.new()
	_viewport.size = CanvasSize
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if not _baseline.is_empty(): _run.set_script(load(_baseline))
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
	return _run._run_state.get("mode") == "combat"

func _drive_take() -> void:
	_run._animation_lock = true
	var state: Dictionary = _run._combat_state.duplicate(true)
	if _icefall_fallback:
		var playback: Script = Icefall if _baseline.is_empty() else load(_baseline.get_base_dir().path_join("enemy_mechanics/icefall_view.gd"))
		await playback.animate(_run, state, _steps[0])
	else:
		await _run._animate_enemy_phase_steps(state, _steps)
	_run._animation_lock = false
	_complete = true

func _is_existing_contact(shown: Dictionary) -> bool:
	var effect: Dictionary = shown.get("effect", {})
	if _case == "board_rule": return bool(shown.get("rule_contact", false))
	if _case == "icefall": return effect.get("icefall_phase") == "puff"
	if Fx.strike_element(effect) != TAKES[_case][2]: return false
	if _reduced: return true
	var boundary: float = Landing.START_PROGRESS + ceili((Dragon.CONTACT - Landing.START_PROGRESS) / Landing.FX_FRAME_PROGRESS) * Landing.FX_FRAME_PROGRESS if _case == "meteorfall" else Attack.feedback_start_progress(effect)
	return float(shown.get("effect_progress", -1.0)) + 0.0001 >= boundary

func _verify_contact(board: Control, row: int, cell: int, element: String) -> bool:
	var visible_targets: Array = _targets.filter(board._board_tile_is_visible_to_player)
	var strike_tiles: Dictionary
	for stamp: Fx.Stamp in board._sky_strikes._stamps:
		if not stamp.visible: continue
		if not visible_targets.has(stamp.tile) or strike_tiles.has(stamp.tile) or stamp.sample != Vector3i(cell, row, 0):
			return false
		if stamp.get_parent() != board._scene_front_effect_render_layers_by_tile.get(stamp.tile): return false
		strike_tiles[stamp.tile] = true
	var burst_tiles: Dictionary
	var rows: Dictionary = Fx.metadata()["rows"]
	for stamp: Fx.Stamp in board._tile_bursts._stamps:
		if not stamp.front or not stamp.visible: continue
		if stamp.sample.y not in [int(rows[element + "_hit_front"]), int(rows[element + "_floor_front"])]: continue
		if not visible_targets.has(stamp.tile) or burst_tiles.has(stamp.tile): return false
		if stamp.sample.x != int(Fx.metadata()["reduced_motion_frame"] if _reduced else 0): return false
		burst_tiles[stamp.tile] = true
	if _case == "occlusion":
		var layer: Node = board._scene_front_effect_render_layers_by_tile[OCCLUDED]
		var hero_layer: Node = board._scene_render_layers_by_tile[Hero]
		if layer.get_index() >= hero_layer.get_index(): return false
	return strike_tiles.size() == visible_targets.size() and burst_tiles.size() == visible_targets.size()

func _observe_take() -> Dictionary:
	var element: String = TAKES[_case][2]
	var data: Dictionary = Fx.strike_metadata()
	var strike: String = data["strike_for_element"][element]
	var row: int = data["rows"][strike + "_front"]
	var cell: int = data["contact_frame"][strike]
	var board: Control = _run.board_view
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(CropSize.x * (EARLY_CELLS.size() + BURST_OFFSETS.size()), CropSize.y, false, Image.FORMAT_RGB8)
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open recording stream.")
				return {}
	var columns: Dictionary
	var first_frames: Dictionary
	var contact: int = -1
	var done: int = -1
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_take()
	for frame: int in TAKE_LIMIT:
		if _plan:
			await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and done < 0: done = frame
		if contact < 0 and _is_existing_contact(board.presentation):
			contact = frame
			if _baseline.is_empty() and not _verify_contact(board, row, cell, element):
				_fail("Missing, duplicate or misaligned strike/burst at the existing contact in %s on frame %d." % [_case, frame])
				return {}
		var sample: int = -1
		for stamp: Fx.Stamp in board._sky_strikes._stamps:
			if stamp.tile == _aim and stamp.visible and stamp.sample.y == row:
				sample = stamp.sample.x
				break
		if sample >= 0 and not first_frames.has(sample): first_frames[sample] = frame
		var capture: Array[int]
		var early: int = EARLY_CELLS.find(sample)
		if early >= 0 and not columns.has(early): capture.append(early)
		if contact >= 0:
			var late: int = BURST_OFFSETS.find(frame - contact)
			if late >= 0: capture.append(EARLY_CELLS.size() + late)
		if not _plan and (not capture.is_empty() or (_record and frame < RECORD_PART_FRAMES)):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected an exact 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if raw != null and frame < RECORD_PART_FRAMES: raw.store_buffer(image.get_data())
			var center: Vector2 = board.get_global_transform_with_canvas() * board._tile_center(_aim)
			var crop := Rect2i(Vector2i(center.round()) - CropSize / 2, CropSize)
			var on_screen: Rect2i = crop.intersection(Rect2i(Vector2i.ZERO, CanvasSize))
			for column: int in capture:
				strip.blit_rect(image, on_screen, Vector2i(column * CropSize.x, 0) + on_screen.position - crop.position)
				if column == EARLY_CELLS.size() and not _save(image, "native-evidence.png"): return {}
		for column: int in capture: columns[column] = true
		if done >= 0 and contact >= 0 and frame >= contact + BURST_OFFSETS[-1] and (not _record or frame >= RECORD_PART_FRAMES - 1): break
	if raw != null: raw.close()
	if contact < 0 or done < 0 or (_record and contact >= RECORD_PART_FRAMES):
		_fail("No complete take (contact=%d, completion=%d)." % [contact, done])
		return {}
	if _baseline.is_empty():
		var falling_frames: int = cell * FPS / int(data["fps"])
		if _reduced and (first_frames.size() != 1 or first_frames.get(cell) != contact):
			_fail("Reduced motion should show only the contact cell.")
			return {}
		if not _reduced and (not first_frames.has(0) or absi(contact - int(first_frames[0]) - falling_frames) > CONTACT_HOLD_TOLERANCE):
			_fail("Strike frame zero should lead contact by %d proof ticks (contact=%d, cells=%s)." % [falling_frames, contact, first_frames])
			return {}
		if _plan and not _reduced and first_frames.size() != int(data["frames"]):
			_fail("Expected every sheet cell in fixed-frame playback, observed %s." % str(first_frames))
			return {}
	if not _plan:
		if columns.size() != EARLY_CELLS.size() + BURST_OFFSETS.size():
			_fail("Incomplete strip columns: %s." % str(columns))
			return {}
		if not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {"case": _case, "contact_frame": contact, "completion_frame": done,
		"authored_frames": stats.get("authored_frames"), "rendered_frames": stats.get("rendered_frames"),
		"authored_duration_usec": stats.get("authored_duration_usec"),
		"first_frames": first_frames, "target": _coord(_aim), "targets": _coord_strings(_targets)}
