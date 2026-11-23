extends "res://tools/fx12/native_capture.gd"
## The FX-12 fixture boots the real RunScene and drives its card click handlers.

const CaptureClock = preload("res://scripts/presentation_clock.gd")
const RECORD_SECONDS: int = 5
const SAMPLE_FRAMES: Array[int] = [0, 4, 8, 14, 22, 30]
const INJURED_HP: int = 24
const SUPPORT_FOE := Vector2i(5, 3)
const SUPPORT_ALLY := Vector2i(4, 3)
const ENEMY_HP: int = 40
const WOUNDED_ENEMY_HP: int = 5
const LARGE_FOE := Vector2i(2, 3)
const LARGE_FOE_SUPPORT := Vector2i(3, 2)
const RECORD_PLAYS: int = 4
const REINFORCEMENT_INTERVAL: int = 20
const REINFORCEMENT_TARGET: int = 40
const TICK_INTENT: Dictionary = {"id": "fx13_tick_summon", "name": "Summon", "time": 4,
	"actions": [{"type": "summon_minions", "minion_type": "ember_tick", "count": 1, "summon_cap": 2}]}
const ENEMY_STEP_CASES: Dictionary = {"guard_ally": "block", "enemy_heal": "heal", "block_2x2": "block",
	"guardian_summon": "summon", "dragon_summon": "summon"}
const CAPTURE_CASES: Dictionary = {
	"brace": ["brace", "block"],
	"stone_plate": ["stone_plate", "stoneskin"],
	"glass_mending": ["last_light", "heal"],
	"whetstone": ["whetstone", "empower"],
	"retaliate": ["bristle", "empower"],
	"quicken": ["hourglass_sand", "empower"],
	"mantle": ["crystal_mantle", "mantle"],
	"illusion": ["mirror_image", "illusion"],
	"guard_ally": ["", "block"],
	"enemy_heal": ["", "heal"],
	"tick_summon": ["", "summon"],
	"reinforcement": ["", "summon"],
	"expose_enemy": ["caltrops", "expose"],
	"expose_hero": ["shadow_step", "expose"],
	"block_2x2": ["", "block"],
	"recording": ["brace", "block"],
	"guardian_summon": ["", "summon"],
	"dragon_summon": ["", "summon"],
}
const RECORD_ACTIONS: Array[String] = ["last_light", "mirror_image", ""]
var _case: String
var _baseline_source: String
var _take_finished: bool
var _reduced_plan: bool
var _plan_frame: PlanFrame

class PlanFrame extends Node:
	signal presented

	func _process(_delta: float) -> void:
		presented.emit()

class FixedPacing extends CombatPacing:
	func _sync_clock() -> void:
		_clock_usec += _movie_clock.advance(Engine.get_process_frames(), 1.0 / FPS, Engine.time_scale, is_inside_tree() and get_tree().paused)

func _take() -> void:
	_case = _arg("--case")
	_output = _arg("--out")
	_plan = OS.get_cmdline_user_args().has("--plan")
	_baseline_source = _arg("--baseline-run-script")
	_record = _case == "recording"
	if not CAPTURE_CASES.has(_case) or _output.is_empty():
		_fail("Provide an FX-13 case and output directory.")
		return
	if not _plan and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or CaptureClock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all"):
		_fail("Use native.sh for cel look, MovieWriter, and the validated visual runner.")
		return
	if _plan:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		Engine.max_fps = FPS
		_plan_frame = PlanFrame.new()
		_plan_frame.process_priority = 1000
		root.add_child(_plan_frame)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	_reduced_plan = OS.get_cmdline_user_args().has("--reduced-motion")
	settings["reduced_motion"] = _reduced_plan
	Settings.save_settings(settings)
	var fixture: Dictionary = _make_fx13_fixture()
	if _failed: return
	if not await _start_fx13(fixture):
		_fail("RunScene did not resume with the combat HUD at 100% UI scale.")
		return
	var result: Dictionary = await _capture_fx13()
	if _failed: return
	var file := FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write take.json.")
		return
	file.store_string(JSON.stringify(result, "\t"))
	print("FX-13 %s %s" % ["PLAN" if _plan else "NATIVE", JSON.stringify(result)])
	for frame: int in TEARDOWN_FRAMES:
		if _take_finished and not _run._animation_lock: break
		await process_frame
	_viewport.queue_free()
	await process_frame
	quit(0)

func _make_fx13_fixture() -> Dictionary:
	var card: String = CAPTURE_CASES[_case][0]
	_aim = SUPPORT_ALLY
	_options = {
		"scenario": "combat", "seed": DEFAULT_SEED, "hand": card if not card.is_empty() else FILLER,
		"draw": FILLER_DRAW, "player_hp": INJURED_HP, "player_max_hp": HERO_HP,
		"player_position": _coord(Hero), "enemy_types": "crawler",
		"enemy_positions": _coord(SUPPORT_ALLY), "umbra_stage": "clear",
	}
	match _case:
		"illusion", "expose_hero", "reinforcement", "recording":
			_options["enemy_positions"] = _coord(SUPPORT_FOE)
		"guardian_summon":
			_options["enemy_types"] = "storm_cantor"
			_options["enemy_intents"] = "call_the_spark"
			_options["enemy_positions"] = _coord(SUPPORT_FOE)
		"dragon_summon":
			_options["enemy_types"] = "zekarion"
			_options["enemy_intents"] = "call_wisps"
			_options["enemy_positions"] = _coord(SUPPORT_FOE)
		"guard_ally", "enemy_heal", "block_2x2":
			_options["enemy_types"] = "grave_surgeon,crawler"
			_options["enemy_positions"] = _coord(SUPPORT_FOE) + "," + _coord(SUPPORT_ALLY)
			_options["enemy_intents"] = ("triage_suture" if _case == "enemy_heal" else "field_brace") + ",coil"
	if _case == "recording":
		_options["hand"] = "brace,last_light,mirror_image"
	if _case == "expose_hero":
		_options["surfaces"] = "ice@" + _coord(_aim)
	var progression: Dictionary = Tutorial.dismiss_tutorial(_build_progression())
	for prompt: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, prompt)
	var run: Dictionary = _build_run_state("combat", progression)
	if _failed: return {}
	var state: Dictionary = run["combat_state"]
	state["terrain"] = (state["terrain"] as Array).filter(func(prop: Dictionary) -> bool:
		return Paths.manhattan(Hero, prop["pos"]) > 3)
	var enemies: Array = state["enemies"]
	if _case == "block_2x2":
		enemies[1]["footprint"] = Vector2i(2, 2)
		enemies[1]["pos"] = LARGE_FOE
		enemies[0]["pos"] = LARGE_FOE_SUPPORT
		_aim = enemies[1]["pos"]
	if _case == "enemy_heal":
		enemies[1]["hp"] = WOUNDED_ENEMY_HP
	if _case == "expose_enemy":
		enemies[0]["hp"] = ENEMY_HP
		enemies[0]["max_hp"] = ENEMY_HP
	if _record:
		state["cards_per_turn"] = RECORD_PLAYS
	if _case in ["tick_summon", "recording"]:
		# No production intent summons a Tick. Exercise its ordinary summon step
		# with a proof-only intent while retaining the real resolver and playback.
		enemies[0]["intent"] = TICK_INTENT.duplicate(true)
	if card.is_empty() or _record:
		for actor: Dictionary in state["turn_queue"]:
			actor["time"] = ENEMY_OPENING_TICK
	if _case == "reinforcement":
		state["objective"] = {"type": "survive", "target_clock": REINFORCEMENT_TARGET, "next_reinforcement_clock": ENEMY_OPENING_TICK,
			"reinforcement_interval": REINFORCEMENT_INTERVAL, "reinforcement_pool": ["ember_tick"]}
	return {"run": run, "profile": progression}

func _start_fx13(fixture: Dictionary) -> bool:
	if not _plan: return await _start(fixture)
	if not ProgressionStore.save_data(fixture["profile"]) or not ProgressionStore.save_run_state(fixture["run"]):
		return false
	_viewport = SubViewport.new()
	_viewport.size = CanvasSize
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if not _baseline_source.is_empty():
		var baseline := GDScript.new()
		baseline.resource_path = "res://tools/fx13/HEAD_RunScene.gd"
		baseline.source_code = FileAccess.get_file_as_string(_baseline_source)
		if baseline.reload() != OK: return false
		_run.set_script(baseline)
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

func _drive_fx13() -> void:
	if ENEMY_STEP_CASES.has(_case):
		var state: Dictionary = _run._combat_state.duplicate(true)
		var resolved: Dictionary = _combat_engine.resolve_enemy_turn_with_steps(state, 0)
		var steps: Array = (resolved["steps"] as Array).filter(func(step: Dictionary) -> bool: return step["kind"] == ENEMY_STEP_CASES[_case])
		if steps.size() != 1:
			_fail("The fixture did not resolve the expected enemy step: " + _case)
			return
		await _run._animate_enemy_phase_steps(state, steps)
	elif _case == "reinforcement":
		var state: Dictionary = _run._combat_state.duplicate(true)
		var after: Dictionary = state.duplicate(true)
		after["initiative_clock"] = ENEMY_OPENING_TICK
		var steps: Array = _combat_engine._spawn_due_survival_reinforcements(after)
		if steps.size() != 1:
			_fail("The fixture did not resolve a reinforcement step.")
			return
		await _run._animate_enemy_phase_steps(state, steps)
	else:
		await _play(CAPTURE_CASES[_case][0])
	if _record:
		for card: String in RECORD_ACTIONS:
			await _play(card)
	_take_finished = true

func _capture_fx13() -> Dictionary:
	var effect: String = CAPTURE_CASES[_case][1]
	var row: int = Fx.self_metadata()["rows"][effect + "_front"]
	var board: Control = _run.board_view
	if not _baseline_source.is_empty(): board._self_bursts.ink = null
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(CropSize.x * SAMPLE_FRAMES.size(), CropSize.y, false, Image.FORMAT_RGB8)
		if _record: raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if _record and raw == null:
			_fail("Could not open the five-second recording stream.")
			return {}
	var contact: int = -1
	var complete: int = -1
	var reveal: int = -1
	var reveal_age: float = -1.0
	var birth: float = -1.0
	var tile := Vector2i(-1, -1)
	var crop := Rect2i()
	var next_snap: int = 0
	var recorded_effects: Dictionary
	var baked_rows: Dictionary = Fx.self_metadata()["rows"]
	_drive_fx13()
	for frame: int in TAKE_LIMIT:
		if _plan:
			await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		var layer: Fx = board._self_bursts
		for stamp: Fx.Stamp in layer._stamps:
			if not stamp.front or not stamp.visible: continue
			if frame < FPS * RECORD_SECONDS: recorded_effects[stamp.sample.y] = true
			if contact >= 0 or stamp.sample.y != row: continue
			contact = frame
			birth = stamp.birth
			tile = stamp.tile
			var center: Vector2 = board.get_global_transform_with_canvas() * stamp.position
			crop = Rect2i((Vector2i(center.round()) - CropSize / 2).clamp(Vector2i.ZERO, CanvasSize - CropSize), CropSize)
		if _failed: return {}
		if reveal < 0 and contact >= 0 and effect in ["illusion", "summon"] and _body_visible(board, effect, tile):
			reveal = frame
			reveal_age = layer._seconds - birth
		if complete < 0 and _take_finished and not _run._animation_lock: complete = frame
		var snap: bool = contact >= 0 and next_snap < SAMPLE_FRAMES.size() and frame == contact + SAMPLE_FRAMES[next_snap]
		if not _plan and (snap or (_record and frame < FPS * RECORD_SECONDS)):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected a 1920×1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if raw != null and frame < FPS * RECORD_SECONDS: raw.store_buffer(image.get_data())
			if snap:
				strip.blit_rect(image, crop, Vector2i(next_snap * CropSize.x, 0))
				if next_snap == 0 and not _save(image, "native-evidence.png"): return {}
		if snap: next_snap += 1
		if _record and frame >= FPS * RECORD_SECONDS - 1: break
		if not _record and complete >= 0 and (next_snap == SAMPLE_FRAMES.size() or not _baseline_source.is_empty()):
			break
		if complete >= 0 and contact < 0 and frame - complete > SETTLE_FRAMES: break
	if raw != null: raw.close()
	if (not _record and complete < 0) or (_baseline_source.is_empty() and next_snap != SAMPLE_FRAMES.size()):
		_fail("%s did not finish with all evidence (first=%d, complete=%d, samples=%d)." % [_case, contact, complete, next_snap])
		return {}
	if effect in ["illusion", "summon"] and (reveal < 0 or absf(reveal_age - Fx.reveal_seconds(effect, _reduced_plan)) > 1.0 / FPS):
		_fail("%s reveal had unexpected age %.4f at offset %d." % [_case, reveal_age, reveal - contact])
		return {}
	if _case == "glass_mending" and _baseline_source.is_empty() and not recorded_effects.has(int(baked_rows["stoneskin_front"])):
		_fail("Glass Mending did not play its Stoneskin effect.")
		return {}
	if _record:
		for name: String in ["block", "heal", "stoneskin", "illusion", "summon"]:
			if recorded_effects.has(int(baked_rows[name + "_front"])): continue
			_fail("The five-second recording did not reach " + name)
			return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	if _plan: _plan_frame.queue_free()
	return {"case": _case, "contact_frame": contact, "reveal_frame": reveal, "reveal_age_seconds": reveal_age, "complete_frame": complete, "tile": _coord(tile), "crop": str(crop)}

func _body_visible(board: Control, effect: String, tile: Vector2i) -> bool:
	if effect == "summon":
		for unit: Dictionary in board.presentation.get("death_animation_units", []):
			if unit.get("arrival_animation", false) and unit["pos"] == tile and float(unit["death_progress"]) < 1.0:
				return true
	var units: Array = board.combat_state.get("illusions" if effect == "illusion" else "enemies", [])
	for unit: Dictionary in units:
		if unit["pos"] == tile: return true
	return false
