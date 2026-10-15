extends RefCounted

# Test-only clock. No sleeping, engine-time scaling, or audio-device timing.
const FRAME_USEC: int = 16667
const START_USEC: int = 10000000
var usec: int = START_USEC
var bank: Node
var timers: Array[Dictionary]
var frames: Array[Dictionary]
var observing: bool = false

class ManualTimer:
	extends RefCounted
	signal timeout

func create_timer(seconds: float, _always: bool = true, _physics: bool = false, _ignore_scale: bool = false) -> ManualTimer:
	var timer := ManualTimer.new()
	timers.append({"due": usec + int(round(seconds * 1000000.0)), "timer": timer})
	return timer

func step(tree: SceneTree, amount_usec: int = FRAME_USEC) -> void:
	usec += amount_usec
	if bank != null:
		bank.set_test_clock(usec / 1000)
		bank.advance(float(amount_usec) / 1000000.0)
	# Snapshot before emitting: a resumed coroutine can schedule another timer.
	var due: Array[Dictionary]
	for pending: Dictionary in timers:
		if int(pending["due"]) <= usec: due.append(pending)
	for pending: Dictionary in due:
		timers.erase(pending)
		pending["timer"].timeout.emit()
	for tween: Tween in tree.get_processed_tweens():
		tween.pause()
		tween.custom_step(float(amount_usec) / 1000000.0)
	tree.process_frame.emit()

func render(state: Dictionary, shown: Dictionary, stack: Array) -> void:
	if observing:
		frames.append({"time_ms": float(usec) / 1000.0, "state": state.duplicate(true),
			"shown": shown.duplicate(true), "stack": stack})

func mark(label: String, stack: Array) -> void:
	if observing:
		frames.append({"time_ms": float(usec) / 1000.0, "state": {}, "shown": {}, "mark": label, "stack": stack})
