extends SceneTree

const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const Pacing = preload("res://scripts/combat_pacing.gd")
const Owner = preload("res://tests/suites/combat_enemy_action_clock_suite.gd").ClockOwner
const FRAME_USEC: int = 16667
const HIT_DAMAGE: int = 6
const HERO_STOP_USEC: int = 85000

var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var owner := Owner.new()
	root.add_child(owner)
	var pacing: Node = TestClock.clocked_script(Pacing).new()
	pacing.install(owner)
	pacing.debug_timeline = true

	for speed: String in ["normal", "fast", "fastest"]:
		owner._settings["combat_speed"] = speed
		var base: float = preload("res://scripts/settings_store.gd").combat_speed_scale(owner._settings)
		var space := InputEventKey.new()
		space.physical_keycode = KEY_SPACE
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		var accept := InputEventJoypadButton.new()
		accept.button_index = JOY_BUTTON_A
		_send(pacing, accept, true)
		_send(pacing, mouse, true)
		pacing.begin_enemies()
		_expect_scale(pacing, base, speed + " carried-over A and click")
		_send(pacing, accept, false)
		_send(pacing, mouse, false)
		space.echo = true
		_send(pacing, space, true)
		_expect_scale(pacing, base, speed + " echoed Space")
		space.echo = false

		var step: Dictionary = {"kind": "melee", "actor_key": "enemy_1"}
		await pacing.before_step(step)
		var action_scale: float = base * 0.8
		var windup_start: int = pacing.presentation_usec()
		TestClock.now_usec += FRAME_USEC
		_send(pacing, space, true)
		_expect_scale(pacing, action_scale * 2.0, speed + " mid-action Space press")
		var before_press: int = pacing.presentation_usec()
		_expect_clock(before_press - windup_start, FRAME_USEC * action_scale, "Old scale integrated up to press")
		TestClock.now_usec += FRAME_USEC
		_send(pacing, mouse, true)
		_send(pacing, accept, true)
		_send(pacing, space, false)
		_send(pacing, mouse, false)
		_expect_scale(pacing, action_scale * 2.0, speed + " overlapping holds")
		var before_release: int = pacing.presentation_usec()
		_expect_clock(before_release - before_press, FRAME_USEC * action_scale * 2.0, "Held scale integrated through remaining wind-up frame")
		TestClock.now_usec += FRAME_USEC
		_send(pacing, accept, false)
		_expect_scale(pacing, action_scale, speed + " release frame")
		_expect_clock(pacing.presentation_usec() - before_release, FRAME_USEC * action_scale * 2.0, "Old scale integrated up to release")

		_check_stop(pacing, space, action_scale)
		_send(pacing, space, true)
		var resume: bool = pacing.begin_movement("enemy_1")
		_expect_scale(pacing, base * 2.0, speed + " hurried travel")
		pacing.end_movement(resume)
		pacing.end_scope()
		pacing.begin_enemies()
		_expect_scale(pacing, base, speed + " stale hold cleared")
		pacing.end_scope()
		pacing.begin_card()
		_send(pacing, mouse, true)
		_expect_scale(pacing, base, speed + " hero card ignores hurry")
		pacing.end_scope()

	owner.free()
	if "--pacing-regressions" in OS.get_cmdline_user_args():
		await preload("res://tests/suites/combat_feel_suite.gd").run(self, _expect)
	for failure: String in failures: printerr(failure)
	print("ENEMY HURRY TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check_stop(pacing: Node, space: InputEventKey, action_scale: float) -> void:
	var stop: Node = pacing.hit_stop
	for held: bool in [false, true]:
		_send(pacing, space, held)
		stop.request(HIT_DAMAGE, false, true)
		if stop.duration_usec != HERO_STOP_USEC: failures.append("Real-time hit-stop duration changed")
		TestClock.now_usec += HERO_STOP_USEC - 1
		stop.poll()
		if not stop.active or Engine.time_scale != 0.0: failures.append("Hit-stop ended early")
		# Change the eligible hold during the freeze and restore the current scale.
		_send(pacing, space, not held)
		if Engine.time_scale != 0.0: failures.append("Input interrupted hit-stop")
		TestClock.now_usec += 1
		stop.poll()
		_expect_scale(pacing, action_scale * (1.0 if held else 2.0), "Hit-stop restores current hold")
		stop.cancel()

func _send(pacing: Node, event: InputEvent, pressed: bool) -> void:
	event.pressed = pressed
	if pacing.has_method("observe_hurry_input"): pacing.observe_hurry_input(event)

func _expect_scale(pacing: Node, expected: float, context: String) -> void:
	if not is_equal_approx(Engine.time_scale, expected) or not is_equal_approx(pacing.current_scale(), expected):
		failures.append("%s expected %s, got engine=%s pacing=%s" % [context, expected, Engine.time_scale, pacing.current_scale()])

func _expect_clock(actual: int, expected: float, context: String) -> void:
	if absf(actual - expected) > 1.0:
		failures.append("%s expected %.2f µs, got %d" % [context, expected, actual])

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
