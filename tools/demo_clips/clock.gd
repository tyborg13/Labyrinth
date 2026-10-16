extends RefCounted

# Movie time, not the time spent rendering/encoding a frame. Installed only by
# the demo harness through the same in-memory seam as sfx_sync_harness.gd.
const FPS: int = 60
const EPOCH_USEC: int = 10000000
static var current: RefCounted
static var badges: GDScript
var frame: int = -1
var usec: int = EPOCH_USEC
var visual_usec: float = EPOCH_USEC
var bank: Node
var observer: Callable

func tick() -> void:
	frame += 1
	usec = EPOCH_USEC + roundi(float(frame) * 1000000.0 / FPS)
	if frame > 0:
		visual_usec += 1000000.0 / FPS * Engine.time_scale
	if is_instance_valid(bank): bank.set_test_clock(float(usec) / 1000.0)

func render(state: Dictionary, shown: Dictionary, _stack: Array = []) -> void:
	if observer.is_valid(): observer.call(state, shown)
