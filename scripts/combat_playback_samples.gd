extends RefCounted

## Catch up interpolation without discarding a discrete playback state. Each
## required sample gets its own process/draw boundary, even past the deadline;
## the absolute authored clock is never restarted or slowed down.
static func play(scene: Node, schedule: Array, hold_end_usec: int, render: Callable, required: Array[int]) -> int:
	var origin: int = scene._combat_pacing.presentation_usec()
	var index: int = 0
	var rendered: int = 0
	while true:
		var elapsed: int = scene._combat_pacing.presentation_usec() - origin
		var due: int = index
		while due + 1 < schedule.size() and int(schedule[due + 1]) <= elapsed: due += 1
		for boundary: int in required:
			if boundary >= index and boundary < due:
				due = boundary
				break
		var submitted: bool = due < schedule.size() and int(schedule[due]) <= elapsed
		if submitted:
			render.call(due)
			rendered += 1
			index = due + 1
		if elapsed >= hold_end_usec and index >= schedule.size():
			# A required terminal step can become due on this slow frame too.
			# Interpolation-only endpoints keep their existing immediate hand-off.
			if submitted and required.has(due): await scene.get_tree().process_frame
			break
		await scene.get_tree().process_frame
	return rendered
