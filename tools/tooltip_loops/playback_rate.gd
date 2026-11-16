extends RefCounted
## Authoring-only measurement: first through last presented action frame.
const READY_FRAMES: int = 300 # Debug stream-readiness watchdog.
const FPS: float = 30.0

static func measure(tree: SceneTree, window: Control, count: int) -> Dictionary:
	window.proof_seconds = -1.0
	window._elapsed = 0.0
	for frame: int in range(READY_FRAMES):
		await tree.process_frame
		if window.displayed_frame == 0: break
	if window.displayed_frame != 0 or count < 2:
		return {"fps": 0.0, "reason": "first_action_frame_unavailable", "changes": 0}
	var started: int = Time.get_ticks_usec()
	var previous: int = 0
	var changes: int = 0
	var finished: int = started
	var reason: String = "action_deadline"
	var duration: float = float(count) / FPS
	var previous_cursor: float = float(window._elapsed)
	var previous_usec: int = started
	# Never include the terminal frame's hold or the cross-fade. Dropped action
	# frames reduce changes; they are not credited as presented frames.
	while window._elapsed < duration:
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		var cursor: float = float(window._elapsed)
		var current: int = int(window.displayed_frame)
		if current > previous and cursor <= duration + 0.000001:
			changes += 1
			previous = current
		finished = now
		if cursor > duration and cursor > previous_cursor:
			finished = previous_usec + int(float(now - previous_usec) * clampf((duration - previous_cursor) / (cursor - previous_cursor), 0.0, 1.0))
		if current == count - 1 and cursor <= duration + 0.000001:
			reason = "last_action_frame"
			break
		previous_cursor = cursor
		previous_usec = now
	var seconds: float = float(finished - started) / 1000000.0
	return {"fps": float(changes) / seconds if seconds > 0.0 else 0.0, "changes": changes, "seconds": seconds, "first_frame": 0, "last_frame": previous, "action_frames": count, "reason": reason, "hold_included": false, "crossfade_included": false}
