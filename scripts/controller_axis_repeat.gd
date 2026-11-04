extends RefCounted
## Discrete analog actions latch until neutral; motion samples never repeat steps.
signal stepped(axis: int, direction: int)

const RELEASE_THRESHOLD: float = 0.30
const INITIAL_DELAY_SECONDS: float = 0.40
const REPEAT_INTERVAL_SECONDS: float = 0.12
const TIME_EPSILON_SECONDS: float = 0.000001

var _axes: Dictionary = {}

func sample(axis: int, value: float, enter_threshold: float) -> void:
	if absf(value) < RELEASE_THRESHOLD:
		_axes.erase(axis)
	elif not _axes.has(axis) and absf(value) >= enter_threshold:
		var direction: int = int(signf(value))
		_axes[axis] = {"direction": direction, "elapsed": 0.0, "next": INITIAL_DELAY_SECONDS}
		stepped.emit(axis, direction)

func advance(delta: float) -> void:
	for axis: int in _axes.keys():
		var held: Dictionary = _axes[axis]
		held["elapsed"] += delta
		while float(held["elapsed"]) + TIME_EPSILON_SECONDS >= float(held["next"]):
			held["next"] += REPEAT_INTERVAL_SECONDS
			stepped.emit(axis, int(held["direction"]))
			if not _axes.has(axis): break

func reset() -> void:
	_axes.clear()
