extends SceneTree
## Run one controller route or one tour matrix in a fresh task sandbox.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const BoonFixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Cel = preload("res://scripts/cel_look.gd")
const ViewportCheck = preload("res://tools/hitch_census/viewport.gd")
const Route = preload("res://tools/qa117/route.gd")
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const InputGate = preload("res://tools/hitch_census/demo/input_gate.gd")
const Audit = preload("res://tools/qa117/audit.gd")
const ForecastCheckpoint = preload("res://tools/qa117/forecast_checkpoint.gd")
const Tour = preload("res://tools/qa117/tour.gd")
const DESKTOP_PROOF_SIZE := Vector2i(1920, 1080)
const FIXED_FPS: int = 60
const ROUTE_FRAME_BUDGET: int = 72000
const HEADLESS_MAX_FPS: int = 240
const DEFAULT_SEED: int = 7
const BOOT_FRAMES: int = 8
const CAPTURE_LAYOUT_FRAMES: int = 2
const BOT_READ_S: float = 0.38

class Trace:
	func record_driver_cost(_kind: String, _started: int) -> void: pass

var host: SceneTree = self
var trace := Trace.new()
var milestones: Array[String]
var failure: String
var finished: bool
var output: String
var proof_seed: int
var report: FileAccess
var capture: String
var capture_room: String
var capture_matched: bool
var driver
var input_gate: Node
var audit
var start_frame: int
var sample_count: int
var last_label: String
var matrix: String
var input_steps: Array[String]
var target_size: Vector2i
var target_scale: float
var forecast_proof: bool
var forecast_failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	output = OS.get_environment("QA117_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("user://qa117")
	if Runtime.current_namespace().is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("QA117 requires an isolated runner and a writable evidence directory.")
		quit(1)
		return
	report = FileAccess.open(output.path_join("witness.jsonl"), FileAccess.WRITE)
	if report == null:
		push_error("QA117 could not open witness.jsonl.")
		quit(1)
		return
	capture = OS.get_environment("QA117_CAPTURE")
	capture_room = OS.get_environment("QA117_CAPTURE_ROOM")
	matrix = OS.get_environment("QA117_MATRIX")
	proof_seed = int(OS.get_environment("QA117_SEED")) if OS.has_environment("QA117_SEED") else DEFAULT_SEED
	var native: bool = DisplayServer.get_name() != "headless"
	var settings: Dictionary = Settings.default_settings()
	var desktop: bool = OS.get_environment("QA117_VIEWPORT") == "1920x1080"
	target_size = DESKTOP_PROOF_SIZE if desktop else ViewportCheck.TARGET_SIZE
	forecast_proof = OS.get_environment("QA117_FORECAST_PROOF") == "1"
	target_scale = 1.0 if OS.get_environment("QA117_SCALE") == "100" else float(settings["ui_scale"])
	# The recorded natural route depends on the Deck navigation geometry.
	# Apply other proof framing once the controller has reached its checkpoint.
	var route_size: Vector2i = ViewportCheck.TARGET_SIZE if forecast_proof else target_size
	if not forecast_proof: settings["ui_scale"] = target_scale
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.set_storage_path("user://qa117-settings.json")
	Store.set_storage_path("user://qa117-progression.json")
	Store.set_run_storage_path("user://qa117-run.save")
	Settings.save_settings(settings)
	var returning_profile: bool = OS.get_environment("QA117_RETURNING") == "1"
	Store.save_data(BoonFixture.profile() if returning_profile else Store.default_data())
	Store.clear_saved_run()
	root.mode = Window.MODE_WINDOWED
	root.gui_embed_subwindows = true
	root.size = route_size
	if route_size == DESKTOP_PROOF_SIZE: root.content_scale_size = route_size
	root.content_scale_factor = settings["ui_scale"]
	root.set_meta("labyrinth_performance_probe_seed", proof_seed)
	if not native:
		# Production awaits the post-draw signal even with a dummy renderer.
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	Engine.physics_ticks_per_second = FIXED_FPS
	Engine.max_fps = FIXED_FPS if native else HEADLESS_MAX_FPS
	audit = Audit.new()
	driver = Route.new(self)
	input_gate = InputGate.new()
	input_gate.session = self
	root.add_child(input_gate)
	await frames(BOOT_FRAMES)
	var viewport: Dictionary = ViewportCheck.capture(root)
	viewport.merge({"scale": settings["ui_scale"], "cel": Cel.mode, "cel_entries": Cel._files.size(), "seed": proof_seed,
		"deck": OS.get_environment("SteamDeck"), "demo": OS.get_environment("LABYRINTH_DEMO"), "matrix": matrix,
		"returning_profile": returning_profile, "edge_smoothing": settings["edge_smoothing"],
		"logical_rect": str(root.get_visible_rect())})
	log_event("configuration", viewport)
	if root.size != route_size or (native and viewport["root_pixel_size"] != [route_size.x, route_size.y]) or Cel.mode != "all" or Cel._files.is_empty() or viewport["deck"] != "1":
		fail("Deck viewport or cel configuration mismatch")
		_finish()
		return
	start_frame = Engine.get_process_frames()
	process_frame.connect(_watchdog)
	if matrix.is_empty():
		change_scene_to_file("res://scenes/startup.tscn")
		await driver.run()
	else:
		await Tour.new(self).run(matrix)
	if not finished: _finish()

func _watchdog() -> void:
	if Engine.get_process_frames() - start_frame > ROUTE_FRAME_BUDGET:
		fail("Probe frame budget exhausted at " + last_label)
		_finish()

func frames(count: int) -> void:
	for frame: int in range(count): await process_frame

func hold(seconds: float) -> void:
	var wait: float = seconds
	if DisplayServer.get_name() == "headless" and matrix.is_empty() and seconds in [driver.READ_S, driver.CARD_READ_S]:
		wait = BOT_READ_S
	await create_timer(wait).timeout

func mark(label: String) -> void:
	if not milestones.has(label): milestones.append(label)
	await sample(label)

func log_event(kind: String, data: Dictionary = {}) -> void:
	if finished or report == null: return
	if kind == "input" and (data.get("pressed", false) or absf(float(data.get("axis_value", 0.0))) > 0.0):
		input_steps.append(str(data.get("event", "")))
	report.store_line(JSON.stringify({"kind": kind, "frame": Engine.get_process_frames(), "data": data}))
	if kind != "input": report.flush()

func fail(reason: String) -> void:
	if not failure.is_empty(): return
	failure = reason
	log_event("blocked", {"reason": reason, "state": last_label})
	print("QA117 BLOCKED: " + reason)

func sample(label: String, force: bool = false) -> void:
	if finished or current_scene == null: return
	var state_label: String = audit.label(current_scene, label)
	last_label = state_label
	var key: String = audit.key(current_scene, state_label)
	if not force and audit.seen.has(key): return
	audit.seen[key] = true
	var row: Dictionary = audit.sample(self, current_scene, state_label)
	sample_count += 1
	row["state_index"] = sample_count
	row["buttons_since_prior_state"] = input_steps.duplicate()
	input_steps.clear()
	log_event("state", row)
	print("QA117 STATE %d %s focus=%s findings=%d" % [sample_count, state_label, row["focus"].get("name", ""), row["findings"].size()])
	var forecast_case: String = ForecastCheckpoint.case_id(proof_seed, row["room"], state_label) if forecast_proof else ""
	if not forecast_case.is_empty() and not await ForecastCheckpoint.check(self, current_scene, forecast_case, row):
		forecast_failures.append(forecast_case)
	if state_label == capture and (capture_room.is_empty() or row["room"] == capture_room):
		capture_matched = true
		if forecast_proof and not await _frame_forecast_capture(forecast_case, row):
			fail("Capture profile did not preserve the forecast checkpoint")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var path: String = output.path_join("qa117-" + capture.replace("/", "-") + ".png")
			if image == null or image.get_size() != target_size or image.save_png(path) != OK:
				fail("Native capture failed: " + path)
			else:
				print(path)
		_finish()
		# A capture terminates the replay at the exact sampled state.
		await process_frame

func _frame_forecast_capture(forecast_case: String, row: Dictionary) -> bool:
	if forecast_case.is_empty(): return false
	if root.size == target_size and is_equal_approx(root.content_scale_factor, target_scale): return true
	var scene: Node = current_scene
	var state: Dictionary = scene._combat_state.duplicate(true)
	root.size = target_size
	if target_size == DESKTOP_PROOF_SIZE: root.content_scale_size = target_size
	root.content_scale_factor = target_scale
	await frames(CAPTURE_LAYOUT_FRAMES)
	log_event("capture_configuration", ViewportCheck.capture(root))
	if root.size != target_size or not is_equal_approx(root.content_scale_factor, target_scale): return false
	if current_scene != scene or scene._combat_state != state: return false
	return await ForecastCheckpoint.check(self, scene, forecast_case, row, "capture")

func _finish() -> void:
	if finished: return
	var counts: Dictionary = driver.inputs
	var expected: int = int(counts["joypad_button"]) + int(counts["joypad_motion"])
	var accepted: int = input_gate.accepted
	if sample_count == 0: fail("Probe did not reach a checkpoint")
	if not capture.is_empty() and not capture_matched: fail("Capture state not reached: " + capture)
	if not forecast_failures.is_empty(): fail("Forecast checkpoints failed: " + ", ".join(forecast_failures))
	if expected != accepted: fail("Input gate expected %d controller events, admitted %d" % [expected, accepted])
	log_event("summary", {"states": sample_count, "milestones": milestones, "input": counts, "accepted": accepted,
		"derived": input_gate.derived_controller_events, "suppressed": input_gate.suppressed, "failure": failure, "last_state": last_label})
	finished = true
	report.close()
	print("QA117 RESULT: seed=%d matrix=%s states=%d joypad=%d/%d failure=%s" % [proof_seed, matrix, sample_count, accepted, expected, failure])
	print("QA117 WITNESS: " + output.path_join("witness.jsonl"))
	quit(0 if failure.is_empty() else 1)
