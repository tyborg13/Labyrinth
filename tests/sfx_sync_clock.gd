extends RefCounted

# Test-only wall and visual clocks. Engine.time_scale affects visual time,
# timers and tweens exactly as in production; audio timestamps stay in wall time.
const FRAME_USEC: int = 16667
const START_USEC: int = 10000000
var usec: int = START_USEC
var visual_usec: float = START_USEC
var bank: Node
var timers: Array[Dictionary]
var frames: Array[Dictionary]
var observing: bool = false
var frame_profile: String = "fixed_60"
var frame_index: int = 0
var last_frame_usec: int = FRAME_USEC
var frame_rng := RandomNumberGenerator.new()

func configure(profile: String) -> void:
	frame_profile = profile
	frame_rng.seed = 410
	frame_index = 0

func next_frame_usec() -> int:
	frame_index += 1
	match frame_profile:
		"spikes": return 33333 if frame_index % 7 == 0 else FRAME_USEC
		"fixed_30": return 33333
		"fixed_144": return 6944
		"jitter": return FRAME_USEC + frame_rng.randi_range(-4000, 4000)
	return FRAME_USEC

class ManualTimer:
	extends RefCounted
	signal timeout

func create_timer(seconds: float, _always: bool = true, _physics: bool = false, _ignore_scale: bool = false) -> ManualTimer:
	var timer := ManualTimer.new()
	timers.append({"due": (usec if _ignore_scale else visual_usec) + int(round(seconds * 1000000.0)), "timer": timer, "ignore_scale": _ignore_scale})
	return timer

func step(tree: SceneTree, amount_usec: int = -1) -> void:
	if amount_usec < 0:
		amount_usec = next_frame_usec()
		last_frame_usec = amount_usec
	usec += amount_usec
	var visual_delta: float = float(amount_usec) * Engine.time_scale if not tree.paused else 0.0
	visual_usec += visual_delta
	if bank != null:
		bank.set_test_clock(float(usec) / 1000.0)
		bank.advance(visual_delta / 1000000.0)
	# Snapshot before emitting: a resumed coroutine can schedule another timer.
	var due: Array[Dictionary]
	for pending: Dictionary in timers:
		if float(pending["due"]) <= (float(usec) if pending["ignore_scale"] else visual_usec): due.append(pending)
	for pending: Dictionary in due:
		timers.erase(pending)
		pending["timer"].timeout.emit()
	for tween: Tween in tree.get_processed_tweens():
		tween.pause()
		tween.custom_step(visual_delta / 1000000.0)
	tree.process_frame.emit()

func render(state: Dictionary, shown: Dictionary, stack: Array) -> void:
	if observing:
		frames.append({"time_ms": float(usec) / 1000.0, "state": state.duplicate(true),
			"shown": shown.duplicate(true), "stack": stack})

func mark(label: String, stack: Array) -> void:
	if observing:
		frames.append({"time_ms": float(usec) / 1000.0, "state": {}, "shown": {}, "mark": label, "stack": stack})
