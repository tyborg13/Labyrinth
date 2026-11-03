extends Node
## Drives the actual routine's clock, timers and tweens with one injected delta.
## Requested durations are diagnostics; only consumed deltas measure completion.
const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const STEP_USEC: int = 10000
static var active: Node
var elapsed_usec: int = 0
var timers: Array[WaitTimer]
var tweens: Array[Tween]
var _previous_active: Node
var _previous_clock_usec: int

class WaitTimer:
	extends RefCounted
	signal timeout
	var started_usec: int
	var duration_usec: int
	var completed: bool = false
	var completed_usec: int = -1

func _ready() -> void:
	_previous_active = active
	_previous_clock_usec = TestClock.now_usec
	active = self
	process_priority = -200
	TestClock.now_usec = TestClock.FIXTURE_START_USEC

static func timer(_tree: SceneTree, seconds: float) -> WaitTimer:
	var result := WaitTimer.new()
	result.started_usec = active.elapsed_usec
	result.duration_usec = int(round(seconds * 1000000.0))
	active.timers.append(result)
	return result

static func track(tween: Tween) -> void:
	active.tweens.append(tween)
	tween.pause()

static func sequence_script(original: Script) -> GDScript:
	var source: String = TestClock.source_for(original).replace("class_name PostCombatRewardSequence", "")
	var lines := source.split("\n")
	for index: int in range(lines.size()):
		if "var " in lines[index] and ": Tween = " in lines[index]:
			var variable: String = lines[index].strip_edges().split(":")[0].trim_prefix("var ")
			# pol-15 (8169b3dbb) also creates tweens inside the HUD loop.
			var indentation: String = lines[index].left(lines[index].find("var "))
			lines[index] += '\n' + indentation + 'preload("res://tests/helpers/presentation_routine_clock.gd").track(' + variable + ')'
	var script := GDScript.new()
	script.source_code = "\n".join(lines).replace("overlay.get_tree().create_timer(", 'preload("res://tests/helpers/presentation_routine_clock.gd").timer(overlay.get_tree(), ')
	assert(script.reload() == OK, "Clock-driven production sequence compiles")
	return script

func _process(_delta: float) -> void:
	elapsed_usec += STEP_USEC
	TestClock.now_usec += STEP_USEC
	# Snapshot both lists: a resumed routine can schedule its next wait inside a
	# completion signal, and that new wait must not consume an earlier delta.
	var due_timers: Array[WaitTimer]
	due_timers.assign(timers)
	var due_tweens: Array[Tween]
	due_tweens.assign(tweens)
	for wait: WaitTimer in due_timers:
		if not wait.completed and elapsed_usec - wait.started_usec >= wait.duration_usec:
			wait.completed = true
			wait.completed_usec = elapsed_usec
			wait.timeout.emit()
	for tween: Tween in due_tweens:
		if tween.is_valid() and not tween.custom_step(float(STEP_USEC) / 1000000.0): tween.kill()

func expect_completed_timers(expect: Callable, label: String) -> void:
	for wait: WaitTimer in timers:
		expect.call(wait.completed and wait.completed_usec - wait.started_usec >= wait.duration_usec, label + " consumes each complete timer before returning")

func _exit_tree() -> void:
	if active == self:
		active = _previous_active if is_instance_valid(_previous_active) else null
		TestClock.now_usec = _previous_clock_usec
