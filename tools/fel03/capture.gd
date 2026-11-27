extends SceneTree
## Stage the saved fights, then drive the same production inputs in both modes.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Settings = preload("res://scripts/settings_store.gd")
const InputPlan = preload("res://tools/fel03/fight_input.gd")
const Evidence = preload("res://tools/fel03/evidence.gd")
const FrameOutput = preload("res://tools/fel03/frame_output.gd")
const CapturePacing = preload("res://tools/fel03/capture_pacing.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const FIXTURES := "res://tools/fel01/samples"
const FIXTURE_COUNT := 3
const FPS := Evidence.FPS
const SETTLE_SECONDS := 0.35
const NATIVE_SETTLE_FRAMES := 90
const NATIVE_SETTLE_SECONDS := 2.0
const READY_LIMIT_FRAMES := 5 * FPS
const SAMPLE_PRIORITY := 1000
const FIGHT_LIMIT_FRAMES := 30 * FPS
const TODO_DESIGN_fx13_when_only_fx12_occurs := "No natural fx-13 appeared. The brief allows a Block replay when neither comparison occurs."
const NO_POINTER := Vector2(-1, -1)

var _dry: bool
var _viewport: SubViewport
var _run_scene: Node
var _evidence: Evidence
var _output: FrameOutput
var _comparisons: Dictionary
var _drive_finished: bool
var _drive_failed: String
var _block_tried: bool
var _strips: int
var _captions: int


class HeadlessDraw extends Node:
	func _process(_delta: float) -> void:
		RenderingServer.frame_post_draw.emit()


func _initialize() -> void:
	Runtime.apply_from_environment()
	_dry = OS.get_cmdline_user_args().has("--dry-run")
	RenderingServer.frame_post_draw.connect(_record_frame)
	call_deferred("_run")


func _run() -> void:
	if _dry != (DisplayServer.get_name() == "headless"):
		_fail("use native.sh or native.sh --dry-run")
		return
	if not _dry and (Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS):
		_fail("native capture requires a fixed 60 Hz MovieWriter clock")
		return
	if _dry:
		var draw := HeadlessDraw.new()
		draw.process_priority = SAMPLE_PRIORITY
		root.add_child(draw)
	if not _dry:
		_output = FrameOutput.new()
		_output.destination = OS.get_environment("FEL03_CAPTURE_DIR")
		if _output.destination.is_empty() or not DirAccess.dir_exists_absolute(_output.destination):
			_fail("native.sh must provide a fresh capture directory")
			return
		if not await _output.prepare_labels(self):
			_fail(_output.problem)
			return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel03_capture_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save isolated settings")
		return
	var ids: PackedStringArray = DirAccess.get_directories_at(FIXTURES)
	ids.sort()
	if ids.size() != FIXTURE_COUNT:
		_fail("expected %d sample fixtures in %s" % [FIXTURE_COUNT, FIXTURES])
		return
	for id: String in ids:
		if not await _capture_fight(id, false): return
	if _comparisons.is_empty():
		for id: String in ids:
			if not await _capture_fight(id, true): return
			if _block_tried: break
		if not _block_tried: _note("No playable Block card remains in the fixture hands.")
	if not _comparisons.has("fx12"): _note("No fx-12 comparison occurred.")
	if not _comparisons.has("fx13"):
		_note(TODO_DESIGN_fx13_when_only_fx12_occurs if _comparisons.has("fx12") and not _block_tried
			else "No fx-13 comparison occurred.")
	if _output != null and not _output.write_index():
		_fail(_output.problem)
		return
	print("FEL03 %s PASS strips=%d captions=%d" % ["DRY RUN" if _dry else "NATIVE", _strips, _captions])
	quit()


func _capture_fight(id: String, fallback: bool) -> bool:
	if not await _resume(id): return false
	_evidence = Evidence.new()
	_evidence.comparisons = _comparisons
	_evidence.comparisons_only = fallback
	_run_scene._combat_pacing.step_seen = _evidence.step_seen
	_drive_finished = false
	_drive_failed = ""
	var first_frame: int = _evidence.frame
	while _evidence.frame - first_frame < Evidence.RADIUS:
		await process_frame
	_drive.call_deferred(fallback)
	var deadline: int = _evidence.frame + FIGHT_LIMIT_FRAMES
	while not _drive_finished and _evidence.problem.is_empty() and _evidence.frame < deadline:
		await process_frame
	if not _drive_finished or not _drive_failed.is_empty():
		return _fail("%s %s" % [id, _drive_failed if not _drive_failed.is_empty() else "did not finish the fight: " + _evidence.problem])
	var last_frame: int = _evidence.frame + Evidence.RADIUS
	while _evidence.frame < last_frame:
		await process_frame
	if not _evidence.finish(): return _fail(id + " " + _evidence.problem)
	var evidence: Evidence = _evidence
	_evidence = null
	if not _report(id, evidence): return false
	for frame: int in READY_LIMIT_FRAMES:
		if not _run_scene._turn_order_animating: break
		await process_frame
	_viewport.queue_free()
	await process_frame
	return true


func _record_frame() -> void:
	if _evidence != null: _evidence.sample(_run_scene, _viewport, _dry)


func _drive(fallback: bool) -> void:
	_drive_failed = await _play_turn(fallback)
	_drive_finished = true


func _play_turn(fallback: bool) -> String:
	var plan: Dictionary = InputPlan.melee_plan(_run_scene)
	if plan.is_empty():
		if not fallback: _evidence.notes.append("No playable melee card can hit an adjacent enemy, including after legal movement.")
	else:
		if plan.has("move") and not await InputPlan.move(_run_scene, plan["move"]):
			return "production movement did not reach %s" % str(plan["move"])
		var hand: Array = _run_scene._combat_state["deck"]["hand"]
		_evidence.hero_action = _run_scene._card_def(hand[plan["index"]], _run_scene._combat_state)["name"]
		if not fallback:
			var aim: String = " as a self-centred sweep" if plan.has("sweep") else " at %s" % str(plan["target"])
			var movement: String = " after moving to %s" % str(plan["move"]) if plan.has("move") else ""
			_evidence.notes.append("Hero plays %s%s%s." % [_evidence.hero_action, aim, movement])
		if not await InputPlan.play(_run_scene, plan): return "hero melee did not resolve"
	if fallback:
		var block: Dictionary = InputPlan.block_plan(_run_scene)
		if block.is_empty():
			_evidence.notes.append("No playable Block card in this fixture after hero melee.")
			return ""
		_block_tried = true
		var card: String = _run_scene._combat_state["deck"]["hand"][block["index"]]
		_evidence.notes.append("Comparison replay adds the fixture's %s." % _run_scene._card_def(card)["name"])
		if not await InputPlan.play(_run_scene, block): return "Block comparison card did not resolve"
	var state: Dictionary = _run_scene._combat_state
	if _run_scene._run_state["mode"] != "combat" or not _run_scene._combat_engine.is_player_turn(state):
		return "cannot Pass after playing the hero turn"
	_evidence.enemy_turn = true
	await _run_scene._on_pass_turn_pressed()
	if is_same(state, _run_scene._combat_state): return "production Pass did not resolve"
	_evidence.notes.append("Pass resolved through the full enemy sequence.")
	return ""


func _resume(id: String) -> bool:
	var source: String = FIXTURES.path_join(id)
	var working: String = ProjectSettings.globalize_path("user://fel03_work").path_join(id)
	if not Checkpoint.stage(source, working):
		return _fail("cannot stage " + source)
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()
	root.set_meta("labyrinth_resume_saved_run", true)
	_run_scene = RunScene.instantiate()
	_run_scene._combat_pacing.free()
	var pacing := CapturePacing.new()
	pacing.dry = _dry
	_run_scene._combat_pacing = pacing
	pacing.install(_run_scene)
	_viewport.add_child(_run_scene)
	var pointer := InputEventMouseMotion.new()
	pointer.position = NO_POINTER
	pointer.global_position = NO_POINTER
	pointer.relative = NO_POINTER - _viewport.get_mouse_position()
	_viewport.push_input(pointer, true)
	await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame
	await process_frame
	if not _dry:
		# Match fel-01's room entrance and shader warm-up.
		for frame: int in NATIVE_SETTLE_FRAMES: await process_frame
		await create_timer(NATIVE_SETTLE_SECONDS).timeout
	if not _run_scene.has_installed_run():
		return _fail(id + " production Continue did not install a run")
	if not is_equal_approx(Typography.ui_scale(_run_scene), 1.0):
		return _fail(id + " is not at 100% UI scale")
	var differences: Dictionary = Checkpoint.compare(_run_scene, source)
	if not differences.is_empty():
		print(JSON.stringify(differences))
		return _fail(id + " production Continue changed " + ", ".join(differences.keys()))
	print("FEL03 RESUME PASS " + id)
	for frame: int in READY_LIMIT_FRAMES:
		var centering: Tween = _run_scene._board_centering_tween
		if _run_scene.initial_presentation_is_ready() and (centering == null or not centering.is_running()):
			return true
		await process_frame
	return _fail(id + " presentation did not settle")


func _report(id: String, evidence: Evidence) -> bool:
	for note: String in evidence.notes:
		_note(id + " " + note)
	for index: int in evidence.strips.size():
		var strip: Dictionary = evidence.strips[index]
		if strip["frames"].size() != 2 * Evidence.RADIUS + 1:
			return _fail(id + " incomplete strip")
		var element: String = strip["element"]
		print("FEL03 STRIP %s %s attacker=%s action=%s trail=%s elemental=%s element=%s contact=%d crop=%s frames=%d" % [
			id, strip["category"], strip["attacker"], strip["action"], strip["trail"], element != "none",
			element, strip["contact"], strip["crop"], strip["frames"].size()])
		if _output != null and not _output.write_strip(id, strip, index + 1): return _fail(_output.problem)
		_strips += 1
	for index: int in evidence.captions.size():
		var caption: Dictionary = evidence.captions[index]
		print("FEL03 CAPTION %s %s actions=%s rect=%s font=%d duration=%d frames full=%d" % [
			id, caption["text"], caption["actions"], caption["rect"], caption["font_px"], caption["duration"], caption["full"]])
		if _output != null and not _output.write_caption(id, caption, index + 1): return _fail(_output.problem)
		_captions += 1
	return true


func _note(note: String) -> void:
	print("FEL03 NOTE " + note)
	if _output != null: _output.add_note(note)


func _fail(message: String) -> bool:
	printerr("FEL03 FAIL " + message)
	quit(1)
	return false
