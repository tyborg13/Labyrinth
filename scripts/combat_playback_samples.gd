extends RefCounted

## Catch up interpolation without discarding a discrete playback state. Each
## required sample gets its own process/draw boundary, even past the deadline;
## the absolute authored clock is never restarted or slowed down.
signal finished

var _schedule: Array
var _hold_end_usec: int
var _required: Array[int]
var _render: Callable
var _record: Callable
var _origin: int
var _index: int
var _rendered: int
var _terminal_submitted: bool

func _init(schedule: Array, hold_end_usec: int, required: Array[int], render: Callable, record: Callable) -> void:
	_schedule = schedule
	_hold_end_usec = hold_end_usec
	_required = required
	_render = render
	_record = record

func play(pacing: Node) -> Variant:
	_origin = pacing.presentation_usec()
	return finished if _advance(pacing) else null

func _advance(pacing: Node) -> bool:
	if _terminal_submitted:
		_finish()
		return false
	var elapsed: int = pacing.presentation_usec() - _origin
	var due: int = _index
	while due + 1 < _schedule.size() and int(_schedule[due + 1]) <= elapsed: due += 1
	for boundary: int in _required:
		if boundary >= _index and boundary < due:
			due = boundary
			break
	var submitted: bool = due < _schedule.size() and int(_schedule[due]) <= elapsed
	if submitted:
		_render.call(due)
		_rendered += 1
		_index = due + 1
	if elapsed >= _hold_end_usec and _index >= _schedule.size():
		# Required terminal samples still get their own draw boundary.
		if not submitted or not _required.has(due):
			_finish()
			return false
		_terminal_submitted = true
	# Keep the sampler alive only while the scene owns a pending frame.
	var playback: RefCounted = self
	pacing.next_playback_frame().connect(func() -> void: playback._advance(pacing), CONNECT_ONE_SHOT)
	return true

func _finish() -> void:
	_record.call(_rendered)
	finished.emit()
