extends SceneTree

## Real combat action reel. No windowed execution is attempted by the worker.
const Renderer = preload("res://scripts/gust_shrike_cutout/renderer.gd")
const Fixtures = preload("res://tests/suites/en05_enemies_suite.gd")
const BaseFixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const CaptureScene = preload("res://tests/fixtures/gust_shrike_capture_scene.gd")
const Coverage = preload("res://tests/helpers/gust_shrike_capture_contract.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://probes/gust_shrike_cutout"
const SETTLE_FRAMES: int = 8
const RECORD_FPS: float = 30.0
const TEST_MOVE_TARGET := Vector2i(2, 3)
const TEST_MELEE_ORIGIN := Vector2i(5, 4)
const REQUIRED_CLIPS := ["idle", "move", "dive", "talon_rake", "hover", "hit", "death"]
signal recording_finished
var _recording: bool = false
var _frames: Array[Dictionary]
var _seen: Dictionary = {}
var _errors: Array[String]
var _stage: String = ""
var _scene: Control
var _render_viewport: SubViewport
var _logic_only: bool = false
var _started_usec: int = 0
var _action_start_seconds: float = 0.0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_logic_only = OS.get_cmdline_user_args().has("--logic-only")
	if (DisplayServer.get_name() == "headless" and not _logic_only) or not Renderer.available():
		push_error("SHRIKE PRODUCTION PROBE needs the completed promoted rig and a windowed renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_size(SIZE)
	Settings.set_storage_path("user://rr03_settings.json")
	Store.set_storage_path("user://rr03_profile.json")
	Store.set_run_storage_path("user://rr03_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_render_viewport = CaptureViewport.create(root)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set_script(CaptureScene)
	_scene.proof_capture = Callable(self, "_capture_frame")
	_render_viewport.add_child(_scene)
	await _settle()
	_scene._load_run_state(Run.new().create_new_run(BaseFixtures.TEST_SEED, Store.default_data()))
	await _settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var state: Dictionary = Fixtures.shrike()
	await _install(state)
	_stage = "idle"
	_started_usec = Time.get_ticks_usec()
	_recording = true
	_record_frames()
	await create_timer(Renderer.Data.IDLE_SECONDS).timeout
	_recording = false
	await recording_finished
	_action_start_seconds = maxf(Renderer.Data.IDLE_SECONDS, float(_frames[-1]["seconds"]) + 1.0 / RECORD_FPS)
	_stage = "move"
	var path: Array[Vector2i]
	path.assign([state["enemies"][0]["pos"], TEST_MOVE_TARGET])
	await _scene.record_action(_stage, func() -> void: await _scene._animate_actor_along_path(state, "enemy_1", path, {}))
	for intent: String in ["dive", "talon_rake", "hover"]:
		state = Fixtures.shrike()
		if intent == "talon_rake": state["enemies"][0]["pos"] = TEST_MELEE_ORIGIN
		state["enemies"][0]["intent"] = _intent(intent)
		await _install(state)
		_stage = intent
		var engine := Combat.new()
		# Movement is proved separately; use the actual requested resolved verb.
		var action: Dictionary = state["enemies"][0]["intent"]["actions"][-1]
		var context: Dictionary = engine.enemy_intent_plan(state, 0)
		var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 0, action, null, {}, engine._dictionary_values([]), context)
		var step: Dictionary = engine._enemy_action_step(state, after, 0, action, context)
		await _scene.record_action(_stage, func() -> void: await _scene._animate_enemy_phase_steps(state.duplicate(true), [step]))
		if intent == "dive":
			_expect(after["player"]["hp"] < state["player"]["hp"], "Dive applies its existing damage once")
	for lethal: bool in [false, true]:
		state = Fixtures.shrike()
		state["enemies"][0]["pos"] = TEST_MELEE_ORIGIN
		if lethal: state["enemies"][0]["hp"] = 1
		await _install(state)
		_stage = "death" if lethal else "hit"
		var action: Dictionary = Data.card_def("quick_stab")["actions"][0]
		var engine := Combat.new()
		var target: Vector2i = state["enemies"][0]["pos"]
		var after: Dictionary = engine.apply_player_action(state, action, target)
		await _scene.record_action(_stage, func() -> void: await _scene._animate_player_action_step(state, after, "quick_stab", action, target))
		_expect(int(after["enemies"][0]["hp"]) < int(state["enemies"][0]["hp"]), "Real player action produces " + _stage)
	for clip: String in REQUIRED_CLIPS: _expect(_seen.has(clip), "Captured production clip " + clip)
	_errors.append_array(Coverage.errors(_frames, _scene.proof_completions))
	var manifest := FileAccess.open(OUTPUT.path_join("logic_frames.json" if _logic_only else "frames.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"ok": _errors.is_empty(), "size": [1920, 1080], "ui_scale": 1.0,
		"capture": "headless transforms ONLY" if _logic_only else "fixed SubViewport; real action callbacks with a probe frame clock",
		"native_pixels": not _logic_only, "minimum_frames_per_action": Coverage.MIN_FRAMES,
		"completions": _scene.proof_completions, "fixed_step_usec": CaptureScene.PROOF_STEP_USEC,
		"frames": _frames, "clips": _seen.keys(), "errors": _errors}, "\t"))
	manifest.close()
	for error: String in _errors: push_error(error)
	print("SHRIKE PRODUCTION %s: %s (%d frames; six or more per action)" % ["LOGIC ONLY" if _logic_only else "PROBE", "PASS" if _errors.is_empty() else "FAIL", _frames.size()])
	print("SHRIKE PRODUCTION CAPTURES: " + ProjectSettings.globalize_path(OUTPUT))
	_scene.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _record_frames() -> void:
	while _recording:
		if not _recording: break
		await _capture_frame()
		await create_timer(1.0 / RECORD_FPS).timeout
	recording_finished.emit()

func _capture_frame() -> void:
	await process_frame
	await process_frame
	if not _logic_only: await RenderingServer.frame_post_draw
	var renderer: Node = _scene.board_view.unit_cutout_renderer({"type": "gust_shrike", "id": 1})
	if renderer == null: return
	var snapshot: Dictionary = renderer.snapshot()
	var clip: String = str(snapshot["clip"])
	if clip != _stage: return
	var pose_bytes: PackedByteArray
	var pose_image: Image
	if _logic_only:
		var transforms: Array
		var rig: Node = renderer.rigs[snapshot["facing"]]
		for bone: String in rig.bones: transforms.append(str(rig.bones[bone].transform))
		pose_bytes = JSON.stringify(transforms).to_utf8_buffer()
	else:
		pose_image = renderer.texture().get_image()
		pose_image.convert(Image.FORMAT_RGBA8)
		_expect(not pose_image.is_empty() and pose_image.get_used_rect().has_area(), "Visible shrike pixels in " + clip)
		pose_bytes = pose_image.get_data()
		# Invisible RGB must not masquerade as a visible pose change.
		for alpha: int in range(3, pose_bytes.size(), 4):
			if pose_bytes[alpha] == 0:
				pose_bytes[alpha - 3] = 0
				pose_bytes[alpha - 2] = 0
				pose_bytes[alpha - 1] = 0
		pose_image = Image.create_from_data(pose_image.get_width(), pose_image.get_height(), false, Image.FORMAT_RGBA8, pose_bytes)
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(pose_bytes)
	var pose_hash: String = hasher.finish().hex_encode()
	if clip != "idle" and not _frames.is_empty() and _frames[-1]["stage"] == clip:
		var previous: Dictionary = _frames[-1]
		# Multiple production submissions can occur at one clock tick (for
		# example attack-to-popup handoff). Keep one sample of that phase.
		if absf(float(snapshot["phase"]) - float(previous["snapshot"]["phase"])) <= Coverage.PHASE_EPSILON: return
		if previous["pose_sha256"] == pose_hash:
			# Retain an actually observed authored checkpoint when nearest-pixel
			# quantization makes its neighbour identical. Never seek a pose.
			if _closer_checkpoint(clip, float(snapshot["phase"]), float(previous["snapshot"]["phase"])): _frames.pop_back()
			else: return
	var filename: String = "frame_%05d.png" % _frames.size()
	var pose_filename: String = "pose_%05d.png" % _frames.size()
	if not _logic_only:
		var pixels: Image = _render_viewport.get_texture().get_image()
		_expect(pixels.get_size() == SIZE, "1920x1080 production viewport")
		_expect(pixels.save_png(OUTPUT.path_join(filename)) == OK, "Save " + filename)
		_expect(pose_image.save_png(OUTPUT.path_join(pose_filename)) == OK, "Save " + pose_filename)
		var keyframe: String = _stage + "_" + clip + ".png"
		if not FileAccess.file_exists(OUTPUT.path_join(keyframe)): pixels.save_png(OUTPUT.path_join(keyframe))
	var seconds: float = float(Time.get_ticks_usec() - _started_usec) / 1000000.0 if _stage == "idle" else _action_start_seconds + _scene.proof_elapsed_seconds
	_frames.append({"file": filename, "seconds": seconds,
		"stage": _stage, "snapshot": snapshot, "pose_sha256": pose_hash, "pose_file": pose_filename})
	_seen[clip] = true

func _closer_checkpoint(clip: String, current: float, previous: float) -> bool:
	for target: float in Coverage.required_phases(clip):
		if absf(current - target) <= Coverage.phase_tolerance(clip) and absf(current - target) < absf(previous - target): return true
	return false

func _install(state: Dictionary) -> void:
	BaseFixtures.install(_scene, state)
	await _settle()

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _intent(id: String) -> Dictionary:
	for intent: Dictionary in Data.enemy_def("gust_shrike")["intents"]:
		if intent["id"] == id: return intent.duplicate(true)
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition and message not in _errors: _errors.append(message)
