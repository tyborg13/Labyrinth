extends SceneTree
## Production Continue, synthetic in-viewport hover, then one real Pass.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Instrument = preload("res://tools/fel14/instrument.gd")
const Trace = preload("res://tools/fel14/paint_trace.gd")
const Frame = preload("res://tools/fel14/frame.gd")
const Report = preload("res://tools/fel14/report.gd")
const Native = preload("res://tools/fel14/native_capture.gd")
const FIXTURES := "res://tools/fel01/fixtures"
const ACKNOWLEDGED_HOVER := "res://tools/fel01/census.md"
const FIXTURE_COUNT := 12
const PROOF_FPS := 60
const MOVIE_FPS := 30
const BOOT_MAX_FRAMES := 600
const HOVER_MAX_FRAMES := 120
const HOVER_SETTLE_FRAMES := 21
const TURN_MAX_FRAMES := 3600
const NO_POINTER := Vector2(-1, -1)

var _viewport: SubViewport
var _scene: Node
var _board: Control
var _frame := Frame.new()
var _report := Report.new()
var _native := Native.new()
var _headless: bool
var _fixture_id: String
var _fixture_start: int
var _frames_by_beat: Dictionary = {}
var _pass_done: bool
var _previous_popups: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	Trace.fps = MOVIE_FPS if OS.get_environment("FEL14_MOVIE") == "1" else PROOF_FPS
	if _headless:
		# The dummy renderer executes CanvasItem draws and omits the hardware
		# submission signal that production pacing awaits.
		process_frame.connect(_headless_frame)
	else:
		RenderingServer.frame_post_draw.connect(_presented_action)
	if not Instrument.install():
		_fail(Instrument.failure)
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel14_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save isolated settings")
		return
	if not _native.prepare(_headless, OS.get_environment("FEL14_CAPTURE_DIR")):
		_fail(_native.failure)
		return
	var hover: Dictionary = _hover_tiles()
	var fixtures: PackedStringArray = DirAccess.get_directories_at(FIXTURES)
	fixtures.sort()
	if fixtures.size() != FIXTURE_COUNT or hover.size() != FIXTURE_COUNT:
		_fail("expected 12 fixtures and Hover tiles")
		return
	for fixture: String in fixtures:
		if not _native.movie.is_empty() and fixture != _native.movie["fixture"]: continue
		if not hover.has(fixture) or not await _fixture(fixture, hover[fixture]):
			if not hover.has(fixture): _fail("missing Hover tile for " + fixture)
			return
	if not _native.round_shots.is_empty() or not _native.movie.is_empty():
		if not _native.finish_round(_headless):
			_fail(_native.failure)
			return
		quit()
		return
	if _headless:
		if not _report.finish(OS.get_environment("FEL14_DRY_RUN") != "1"):
			_fail(_report.failure)
			return
		print("FEL14 CENSUS PASS fixtures=%d states=%d labels=%d collisions=%d" %
			[fixtures.size(), _report.states.size(), _report.label_count, _report.collision_count])
		if OS.get_environment("FEL14_DRY_RUN") == "1":
			if not _native.dry_replay(_report.states, _report.worst):
				_fail(_native.failure)
				return
			print("FEL14 NATIVE DRY RUN PASS fixtures=%d captures=%d" % [fixtures.size(), _report.worst.size()])
	else:
		if not _native.finish():
			_fail(_native.failure)
			return
		print("FEL14 NATIVE CAPTURE PASS fixtures=%d captures=%d" % [fixtures.size(), _native.targets.size()])
	quit()

func _hover_tiles() -> Dictionary:
	var rows: Dictionary = {}
	var regex := RegEx.create_from_string("(?m)^\\| \\[([^\\]]+)\\]\\(fixtures/[^)]+\\).*\\| \\((\\d+), (\\d+)\\) \\|$")
	for line: RegExMatch in regex.search_all(FileAccess.get_file_as_string(ACKNOWLEDGED_HOVER)):
		rows[line.get_string(1)] = Vector2i(line.get_string(2).to_int(), line.get_string(3).to_int())
	return rows

func _fixture(id: String, tile: Vector2i) -> bool:
	_fixture_id = id
	_fixture_start = Engine.get_process_frames()
	_frames_by_beat.clear()
	Trace.reset()
	var source: String = FIXTURES.path_join(id)
	var staged: String = ProjectSettings.globalize_path("user://fel14").path_join(id)
	if not Checkpoint.stage(source, staged): return _fail("cannot stage " + id)
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()
	root.set_meta("labyrinth_resume_saved_run", true)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_scene = packed.instantiate()
	_viewport.add_child(_scene)
	_point(NO_POINTER)
	var initial_ready: bool = false
	for _tick: int in range(BOOT_MAX_FRAMES):
		await process_frame
		if _ready_for_input() and not Trace.canvases.is_empty():
			initial_ready = true
			break
	if not initial_ready: return _fail(id + " Continue did not reach first input")
	var differences: Dictionary = Checkpoint.compare(_scene, source)
	if not differences.is_empty(): return _fail(id + " Continue changed " + ", ".join(differences.keys()))
	_board = _scene.get("board_view")
	if not _record(_sample("rest"), ["rest"]): return false
	# Wait only for production centring before submitting a pointer coordinate.
	var centering: Tween = _scene.get("_board_centering_tween")
	for _tick: int in range(HOVER_MAX_FRAMES):
		if centering == null or not centering.is_running(): break
		await process_frame
		centering = _scene.get("_board_centering_tween")
	var hover_ready: bool = false
	for _tick: int in range(HOVER_MAX_FRAMES):
		_point(_board.get_global_transform_with_canvas() * (_board.call("_tile_center", tile) as Vector2))
		await process_frame
		if _scene.get("_hovered_board_tile") != tile: continue
		var reveal: Node = _board.get("_occlusion_reveal")
		if reveal.focus_tile != tile: continue
		var settled: bool = true
		for target: Dictionary in reveal.targets.values():
			if not target["on"] or not is_equal_approx(float(target["progress"]), 1.0):
				settled = false
				break
		if settled and _tick + 1 >= HOVER_SETTLE_FRAMES:
			hover_ready = true
			break
	if not hover_ready: return _fail(id + " could not hover " + str(tile))
	var hovered: Dictionary = _sample("hover")
	hovered["hover"] = [tile.x, tile.y]
	if not _record(hovered, ["hover"]): return false
	_point(NO_POINTER)
	await process_frame
	Trace.tracking = true
	_previous_popups = _frame.popup_scores()
	_pass_done = false
	var previous_turn: int = (_scene.get("_combat_state") as Dictionary).get("turn", -1)
	_pass.call_deferred()
	var reached_boundary: bool = false
	for _tick: int in range(TURN_MAX_FRAMES):
		await process_frame
		if _pass_done and not _scene.get("_animation_lock"):
			reached_boundary = true
			break
	if not reached_boundary: return _fail(id + " Pass exceeded the enemy round frame budget. Last beat %s. Pass done %s. Locked %s" % [Trace.displayed, _pass_done, _scene.get("_animation_lock")])
	var mode: String = str((_scene.get("_run_state") as Dictionary).get("mode", ""))
	var state: Dictionary = _scene.get("_combat_state")
	var player_turn: bool = _scene.get("_combat_engine").is_player_turn(state)
	var outcome: String = _scene.get("_combat_engine").combat_outcome(state) if not state.is_empty() else ""
	if mode == "combat" and outcome.is_empty() and (not player_turn or int(state.get("turn", -1)) <= previous_turn):
		return _fail(id + " Pass did not advance to the next input")
	# Include the frame where control returns to the hero in the movie.
	if not _native.movie.is_empty():
		if _headless: await process_frame
		else: await RenderingServer.frame_post_draw
	Trace.tracking = false
	for entry: Dictionary in _frames_by_beat.values():
		var first: Dictionary = entry["first"]
		var peak: Dictionary = entry.get("peak", {})
		var tags: Array[String] = ["first"]
		if not peak.is_empty() and peak["frame"] == first["frame"]: tags.append("peak")
		if not _record(first, tags): return false
		if not peak.is_empty() and peak["frame"] != first["frame"]:
			if not _record(peak, ["peak"]): return false
	_report.fixtures.append({"id": id, "hover": [tile.x, tile.y], "displayed_beats": _frames_by_beat.size(),
		"start_turn": previous_turn, "end_turn": state.get("turn", -1), "end_mode": mode, "outcome": outcome})
	print("FEL14 FIXTURE PASS %s hover=%s beats=%d end=%s" % [id, tile, _frames_by_beat.size(), outcome if not outcome.is_empty() else mode])
	_viewport.queue_free()
	await process_frame
	return true

func _pass() -> void:
	await _scene.call("_on_pass_turn_pressed")
	_pass_done = true

func _ready_for_input() -> bool:
	if not _scene.call("initial_presentation_is_ready") or _scene.get("_animation_lock") or _scene.get("_dialogue_active"):
		return false
	var state: Dictionary = _scene.get("_combat_state")
	return not state.is_empty() and _scene.get("_combat_engine").is_player_turn(state)

func _point(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = position - _viewport.get_mouse_position()
	_viewport.push_input(motion, true)

func _headless_frame() -> void:
	_presented_action()
	RenderingServer.frame_post_draw.emit()

func _presented_action() -> void:
	if not Trace.tracking: return
	if not _native.movie.is_empty():
		if not _native.record_movie(Trace.displayed, _viewport, _headless): _fail(_native.failure)
		return
	var popups: Dictionary = _frame.popup_scores()
	if not Trace.displayed.is_empty(): _observe_action(Trace.displayed, popups)
	_previous_popups = popups

func _observe_action(beat: Dictionary, popups: Dictionary) -> void:
	var key: int = beat["number"]
	var entry: Dictionary = _frames_by_beat.get_or_add(key, {"score": 0.0})
	if not entry.has("first"):
		entry["first"] = _sample("enemy_turn", beat, "first")
		entry["carried_popups"] = _previous_popups
	var score: float = 0.0
	for popup: String in popups:
		if not (entry["carried_popups"] as Dictionary).has(popup):
			score += float(popups[popup])
	if score > float(entry["score"]):
		entry["score"] = score
		entry["peak"] = _sample("enemy_turn", beat, "peak")

func _sample(phase: String, beat: Dictionary = {}, candidate: String = "") -> Dictionary:
	var result: Dictionary = _frame.sample(_scene, _board)
	result["fixture"] = _fixture_id
	result["phase"] = phase
	result["frame"] = Engine.get_process_frames() - _fixture_start
	result["beat"] = beat.duplicate()
	if not _headless and _native.needs_image(result, candidate):
		result["image"] = _viewport.get_texture().get_image()
	return result

func _record(sample: Dictionary, tags: Array[String]) -> bool:
	if not _native.movie.is_empty(): return true
	var result: Dictionary = Frame.evaluate(sample)
	result["fixture"] = sample["fixture"]
	result["phase"] = sample["phase"]
	result["frame"] = sample["frame"]
	result["beat"] = sample["beat"]
	result["samples"] = tags
	if sample.has("hover"): result["hover"] = sample["hover"]
	if not _native.round_shots.is_empty():
		if not _native.record_round(result, sample.get("image"), _headless): return _fail(_native.failure)
		return true
	if _headless:
		if result["labels"].is_empty(): return _fail("%s has no label paint in %s" % [_fixture_id, result["phase"]])
		_report.add(result)
	elif not _native.record(result, sample.get("image")):
		return _fail(_native.failure)
	return true

func _fail(message: String) -> bool:
	printerr("FEL14 CENSUS FAIL " + message)
	quit(1)
	return false
