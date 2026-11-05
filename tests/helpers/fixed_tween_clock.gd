extends RefCounted
## Test-owned simulation time for real production tween tracks. Pause before
## yielding a frame so host scheduling can never consume part of a sample.
const STEP_USEC: int = 10000
var elapsed_usec: int = 0
var tweens: Array[Tween]

func track(tween: Tween) -> void:
	assert(tween != null and tween.is_valid(), "Motion sample owns a valid tween")
	assert(is_zero_approx(tween.get_total_elapsed_time()), "Capture motion before its first engine tick")
	tween.pause()
	tweens.append(tween)

func advance(seconds: float) -> void:
	var remaining_usec: int = int(round(seconds * 1000000.0))
	assert(remaining_usec >= 0, "Test clock only advances")
	while remaining_usec > 0:
		var delta_usec: int = mini(STEP_USEC, remaining_usec)
		elapsed_usec += delta_usec
		remaining_usec -= delta_usec
		# Completion callbacks may resume a coroutine and invalidate other tracks.
		var current: Array[Tween]
		current.assign(tweens)
		for tween: Tween in current:
			if tween.is_valid() and not tween.custom_step(float(delta_usec) / 1000000.0):
				tween.kill()
