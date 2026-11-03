extends RefCounted
const Probe = preload("res://tests/helpers/blocked_prompt_clock_probe.gd")
const Clock = preload("res://tests/helpers/presentation_test_clock.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const FRAME_SECONDS: float = 1.0 / 60.0
const WARMUP_FRAMES: int = 6
const CADENCE_FRAMES: int = 60
const DRIFT_FRAMES: int = 6000
const ENGINE_PROOF_SECONDS: float = 1.0
const WATCHDOG_MSEC: int = 10000
const OBSERVER_PRIORITY_OFFSET: int = 1
const REFERENCE_PRIORITY_OFFSET: int = -2
const NONZERO_EPOCH_USEC: int = 11234567

static func run(expect: Callable) -> void:
	var script: Script = Probe.run_observed_script()
	var previous_scale: float = Engine.time_scale
	var previous_clock: int = Clock.now_usec
	for scale: float in [0.5, 1.0, 2.0]:
		Engine.time_scale = scale
		for reduced: bool in [false, true]:
			for warmup: int in [0, WARMUP_FRAMES]:
				for arrival: String in ["before_process", "after_process", "after_draw"]:
					for epoch: int in [0, NONZERO_EPOCH_USEC]:
						_parent_comparison(script, scale, reduced, warmup, arrival, epoch, expect)
	Engine.time_scale = previous_scale
	_drift(script, expect)
	Clock.now_usec = previous_clock
	print("PROMPT PARENT COMPARISON: 72 cases / input orders / first and drawn prompts / 0.5x, 1x, 2x / reduced motion / zero and nonzero uptime")

static func _fixture(script: Script, reduced: bool) -> Control:
	var prompt: Control = script.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(prompt)
	prompt.set_process(false)
	prompt.configure(Tutorial.phase_definition(Tutorial.PHASE_CANCEL_CARD), [], [], reduced)
	return prompt

static func _submit(prompt: Control) -> void:
	prompt.draw.emit()
	prompt.get("_feedback").draw.emit()

static func _parent_comparison(script: Script, scale: float, reduced: bool, warmup: int, arrival: String, epoch: int, expect: Callable) -> void:
	var parent := Probe.ParentClock.new()
	parent.reduced_motion = reduced
	Clock.now_usec = epoch
	parent.now_msec = floori(float(epoch) / 1000.0)
	var prompt: Control = _fixture(script, reduced)
	var feedback: Label = prompt.get("_feedback")
	for frame: int in range(1, warmup + 1):
		Clock.now_usec = epoch + roundi(float(frame) * FRAME_SECONDS * 1000000.0)
		parent.now_msec = floori(float(Clock.now_usec) / 1000.0)
		prompt._process(FRAME_SECONDS * scale)
		_submit(prompt)
	var parent_hide: int = -1
	var current_hide: int = -1
	var phase_matches: bool = true
	var clock_matches: bool = true
	var context: String = "arrival=%s warmup=%d scale=%.1f reduced=%s epoch=%d" % [arrival, warmup, scale, reduced, epoch]
	for frame: int in range(1, CADENCE_FRAMES + 1):
		if frame == 1 and arrival == "before_process":
			parent.show_blocked()
			prompt.show_blocked("Use Cancel first.")
		Clock.now_usec = epoch + roundi(float(warmup + frame) * FRAME_SECONDS * 1000000.0)
		parent.now_msec = floori(float(Clock.now_usec) / 1000.0)
		parent.process_frame()
		prompt._process(FRAME_SECONDS * scale)
		if frame == 1 and arrival == "after_process":
			parent.show_blocked()
			prompt.show_blocked("Use Cancel first.")
		_submit(prompt)
		if frame == 1 and arrival == "after_draw":
			parent.show_blocked()
			prompt.show_blocked("Use Cancel first.")
		if parent_hide < 0 and not parent.feedback_visible: parent_hide = frame
		if current_hide < 0 and not feedback.visible: current_hide = frame
		clock_matches = clock_matches and prompt._presentation_msec() == _frame_msec(warmup + frame)
		phase_matches = phase_matches and is_equal_approx(Probe.pulse(prompt), parent.pulse())
	expect.call(clock_matches, "Parent clock advances at unscaled 60 fps: " + context)
	expect.call(phase_matches, "Parent pulse phase matches every submitted frame: " + context)
	expect.call(parent_hide > 0 and current_hide == parent_hide, "Parent hide frame matches input/process/draw order: %s parent=%d current=%d" % [context, parent_hide, current_hide])
	expect.call(parent_hide == (54 if arrival == "before_process" else 55), "Parent fixture retains its exact 900 ms window: " + context)
	print("PROMPT CADENCE %s: parent=%d current=%d pulse_matches=%s" % [context, parent_hide, current_hide, phase_matches])
	prompt.free()

static func _frame_msec(frame: int) -> int:
	return floori(roundf(float(frame) * FRAME_SECONDS * 1000000.0) / 1000.0)

static func _drift(script: Script, expect: Callable) -> void:
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 1.0
	var prompt: Control = _fixture(script, false)
	var parent := Probe.ParentClock.new()
	var matches: bool = true
	for frame: int in range(1, DRIFT_FRAMES + 1):
		Clock.now_usec = NONZERO_EPOCH_USEC + roundi(float(frame) * FRAME_SECONDS * 1000000.0)
		parent.now_msec = floori(float(Clock.now_usec) / 1000.0)
		prompt._process(FRAME_SECONDS)
		_submit(prompt)
		matches = matches and is_equal_approx(Probe.pulse(prompt), parent.pulse())
	expect.call(matches, "Parent pulse phase has no drift over 6000 steady frames")
	prompt.free()
	Engine.time_scale = previous_scale

class EngineSamples:
	extends Node
	var prompt: Control
	var reference: Timer
	var previous_left: float = float(WATCHDOG_MSEC) / 1000.0
	var expected_seconds: float = 0.0
	var frames: int = 0
	var clock_matches: bool = true
	var pulse_matches: bool = true
	var lifetime_matches: bool = true
	var first_hidden_msec: int = -1
	func _process(_delta: float) -> void:
		var delivered: float = previous_left - reference.time_left
		previous_left = reference.time_left
		expected_seconds += clampf(delivered, 0.0, 0.1)
		frames += 1
		var msec: int = floori(roundf(expected_seconds * 1000000.0) / 1000.0)
		clock_matches = clock_matches and is_equal_approx(float(prompt.get("_presentation_seconds")), expected_seconds)
		pulse_matches = pulse_matches and is_equal_approx(Probe.pulse(prompt), 0.78 + 0.22 * sin(float(msec) * 0.005))
		var visible: bool = prompt.get("_feedback").visible
		lifetime_matches = lifetime_matches and visible == (msec < 900)
		if not visible and first_hidden_msec < 0: first_hidden_msec = msec

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var script: Script = Probe.run_observed_script()
	var previous_scale: float = Engine.time_scale
	var previous_clock: int = Clock.now_usec
	var previous_fps: int = Engine.max_fps
	Engine.max_fps = CADENCE_FRAMES
	for scale: float in [1.0, 2.0, 0.0]:
		Engine.time_scale = scale
		# Let the engine's next delta reflect the new scale before sampling it.
		await tree.process_frame
		await tree.process_frame
		Clock.now_usec = 0
		var prompt: Control = _fixture(script, false)
		var samples := EngineSamples.new()
		samples.prompt = prompt
		samples.process_priority = prompt.process_priority + OBSERVER_PRIORITY_OFFSET
		tree.root.add_child(samples)
		var reference := Timer.new()
		reference.one_shot = true
		reference.ignore_time_scale = true
		reference.process_callback = Timer.TIMER_PROCESS_IDLE
		reference.process_priority = prompt.process_priority + REFERENCE_PRIORITY_OFFSET
		samples.add_child(reference)
		reference.start(float(WATCHDOG_MSEC) / 1000.0)
		samples.reference = reference
		prompt.show_blocked("Use Cancel first.")
		_submit(prompt)
		prompt.set_process(true)
		var deadline: int = Time.get_ticks_msec() + WATCHDOG_MSEC
		while samples.expected_seconds < ENGINE_PROOF_SECONDS and Time.get_ticks_msec() < deadline:
			await tree.process_frame
		expect.call(samples.expected_seconds >= ENGINE_PROOF_SECONDS, "Timeout waiting for one second of unscaled prompt frame delivery at %.1fx" % scale)
		expect.call(samples.clock_matches, "Engine-delivered prompt frames use unscaled time at %.1fx" % scale)
		expect.call(samples.pulse_matches, "Engine-delivered prompt pulse matches the parent at %.1fx" % scale)
		expect.call(samples.lifetime_matches and samples.first_hidden_msec >= 900, "Engine-delivered prompt retains the 900 ms parent lifetime at %.1fx" % scale)
		print("PROMPT ENGINE CLOCK scale=%.1f frames=%d first_hidden_unscaled_ms=%d clock_matches=%s pulse_matches=%s lifetime_matches=%s" % [scale, samples.frames, samples.first_hidden_msec, samples.clock_matches, samples.pulse_matches, samples.lifetime_matches])
		samples.free()
		prompt.free()
	Engine.time_scale = previous_scale
	Clock.now_usec = previous_clock
	Engine.max_fps = previous_fps
