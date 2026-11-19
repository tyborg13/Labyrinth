extends SceneTree
## Fixed combat decisions, followed by an isolated delayed-checkpoint frame probe.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Events = preload("res://scripts/analytics_store.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const Policy = preload("res://tools/hitch_census/whole_policy.gd")
const SEED: int = 83
const DECISIONS: int = 15
const FIXTURE_HEALTH: int = 9999
const SETTLE_FRAMES: int = 8
const FRAME_CAP: int = 120
const FRAME_BUDGET_USEC: int = 20000
const TIMEOUT_SECONDS: int = 90
const WORKER_DELAY_MSEC: int = 300
const WRITE_BUDGET_USEC: int = 2000
const REQUIRED_PHASES: Array[String] = Array([
	"deferred_checkpoint_write", "deferred_analytics_batch", "combat_checkpoint_persist_storage",
], TYPE_STRING, "", null)
const SIZE := Vector2i(1920, 1080)

class FramePulse extends Node2D:
	const PULSE_OPACITY: float = 0.01
	var _tick: bool = false

	func _process(_delta: float) -> void:
		_tick = not _tick
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 1.0, 1.0, PULSE_OPACITY) if _tick else Color(0.0, 0.0, 0.0, PULSE_OPACITY))

var _frame_ticks: Array[int]
var _actions: Array[String]
var _headless: bool

func _initialize() -> void:
	Runtime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://persistence-probe-profile.json")
	Store.set_run_storage_path("user://persistence-probe-run.save")
	Events.set_storage_dir("user://persistence-probe-events")
	var settings := preload("res://scripts/settings_store.gd")
	settings.set_storage_path("user://persistence-probe-settings.json")
	var values: Dictionary = settings.default_settings()
	values["combat_speed"] = settings.COMBAT_NORMAL
	values["display_mode"] = "windowed"
	values["ui_scale"] = 1.0
	settings.save_settings(values)
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	Engine.max_fps = FRAME_CAP
	OS.low_processor_usage_mode = false
	if _headless:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var fixture := Fixtures.new()
	var state: Dictionary = fixture.make("combat", SEED, {"player_hp": FIXTURE_HEALTH,
		"player_max_hp": FIXTURE_HEALTH, "enemy_hp": FIXTURE_HEALTH})
	fixture.free()
	if str(state.get("mode", "")) != "combat" or not Store.save_data(state["progression"]):
		_fail("combat fixture could not be prepared")
		return
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._load_run_state(state)
	scene._close_dialogue()
	var policy := Policy.new()
	policy.rng = RandomNumberGenerator.new()
	policy.rng.seed = SEED
	policy.no_embrace = true
	await _settle()
	var baseline: Script
	if OS.get_cmdline_user_args().has("--baseline"):
		baseline = load("res://tmp/perf-133/baseline_timing.gd")
		if baseline == null:
			_fail("baseline attribution patch is required for this mode")
			return
		baseline.take_sections()
	scene.set_runtime_performance_instrumentation_enabled(true)
	var deadline: int = Time.get_ticks_usec() + TIMEOUT_SECONDS * 1000000
	while _actions.size() < DECISIONS and Time.get_ticks_usec() < deadline:
		if str(scene._run_state.get("mode", "")) != "combat":
			break
		var offers: Array = policy.offers(scene)
		if offers.is_empty():
			await process_frame
			continue
		var action: Dictionary = policy.choose(scene, offers)
		_actions.append(str(action["kind"]))
		policy.dispatch(scene, action)
		await _settle()
	if _actions.size() != DECISIONS:
		_fail("expected %d combat decisions, got %s" % [DECISIONS, _actions])
		return
	while Store._run_writer.busy() or Events._writer.busy():
		if Time.get_ticks_usec() >= deadline:
			_fail("combat writes did not drain")
			return
		await process_frame
	var sections: Dictionary = scene.runtime_performance_instrumentation_snapshot()
	if baseline != null:
		sections.merge(baseline.take_sections(), true)
	var measured: Dictionary = {}
	for key: String in sections:
		if key in REQUIRED_PHASES or key.begins_with("checkpoint_write_") or key.begins_with("analytics_write_"):
			measured[key] = sections[key]
	var errors: Array[String]
	for phase: String in REQUIRED_PHASES:
		if not measured.has(phase):
			errors.append("missing phase " + phase)
		elif baseline == null and int(measured[phase]["max_usec"]) > WRITE_BUDGET_USEC:
			errors.append("main-thread phase exceeds budget: " + phase)
	if not _headless and (Vector2i(root.get_visible_rect().size) != SIZE or not is_equal_approx(root.content_scale_factor, 1.0)):
		errors.append("expected 1920×1080 at 100% UI scale")
	var analytics_wait: int = int(measured.get("analytics_write_barrier_wait", {}).get("max_usec", 0))
	if analytics_wait > WRITE_BUDGET_USEC: errors.append("analytics durability wait exceeds budget")
	var sleep_result: Dictionary = {}
	if OS.get_cmdline_user_args().has("--slow-worker"):
		sleep_result = await _sleep_probe(scene, deadline)
	if not sleep_result.is_empty() and not bool(sleep_result["passed"]): errors.append("delayed worker frame budget")
	var result: Dictionary = {"display": DisplayServer.get_name(), "size": str(root.size), "ui_scale": root.content_scale_factor,
		"decisions": _actions, "sections": measured, "sleep": sleep_result, "errors": errors}
	print("PERF133 PERSISTENCE RESULT: " + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame
	while bool(current_scene.get("_animation_lock")):
		await process_frame

func _sleep_probe(scene: Node, deadline: int) -> Dictionary:
	# The renderer samples actual post-draw intervals, and the headless adapter
	# samples process intervals. Use the real worker start/end to select overlap.
	var pulse: FramePulse
	if not _headless:
		pulse = FramePulse.new()
		root.add_child(pulse)
		await RenderingServer.frame_post_draw
	var writer: RefCounted = Store._run_writer
	writer.set("probe_delay_msec", WORKER_DELAY_MSEC)
	var record_tick: Callable = func() -> void: _frame_ticks.append(Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(record_tick)
	if _headless: await process_frame
	else: await RenderingServer.frame_post_draw
	var completed: int = writer.completed
	Store.queue_run_state(scene._committed_run_state())
	while writer.completed == completed and Time.get_ticks_usec() < deadline:
		await process_frame
	if _headless: await process_frame
	else: await RenderingServer.frame_post_draw
	RenderingServer.frame_post_draw.disconnect(record_tick)
	if pulse != null: pulse.queue_free()
	writer.set("probe_delay_msec", 0)
	var worker_started: int = int(writer.get("last_worker_started_usec"))
	var worker_duration: int = int(writer.get("last_worker_usec"))
	var intervals: Array[int]
	for index: int in range(1, _frame_ticks.size()):
		if _frame_ticks[index] > worker_started and _frame_ticks[index - 1] < worker_started + worker_duration:
			intervals.append(_frame_ticks[index] - _frame_ticks[index - 1])
	var max_usec: int = 0 if intervals.is_empty() else int(intervals.max())
	var passed: bool = writer.completed > completed and worker_duration >= WORKER_DELAY_MSEC * 1000 and max_usec > 0 and max_usec <= FRAME_BUDGET_USEC
	return {"passed": passed, "worker_usec": worker_duration, "max_frame_usec": max_usec, "frame_count": intervals.size()}

func _fail(reason: String) -> void:
	push_error("PERF133: " + reason)
	quit(1)
