extends Node
class_name CombatHitStop

## Run-scene-owned real-time stop. No resolver, save or RNG access.
signal scale_changing
signal stop_started(duration_ms: float)
signal stop_ended

const MERGE_WINDOW_USEC: int = 120000
var restore_scale: Callable
var active: bool = false
var first_hit_usec: int = -MERGE_WINDOW_USEC - 1
var duration_usec: int = 0
var _previous_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

static func duration_ms(damage: int, killed: bool = false, hero: bool = false, reduced: bool = false) -> float:
	var duration: float = 35.0 if damage <= 0 else 40.0 if damage <= 3 else 65.0 if damage <= 7 else 85.0 if damage <= 11 else 110.0
	if killed:
		duration = maxf(duration, 100.0)
	if hero:
		duration += 20.0
	return duration * (0.5 if reduced else 1.0)

func request(damage: int, killed: bool = false, hero: bool = false, reduced: bool = false, allowed: bool = true, now_usec: int = -1) -> bool:
	if not allowed or (is_inside_tree() and get_tree().paused):
		return false
	var now: int = Time.get_ticks_usec() if now_usec < 0 else now_usec
	var requested: int = int(round(duration_ms(damage, killed, hero, reduced) * 1000.0))
	var merged: bool = now - first_hit_usec <= MERGE_WINDOW_USEC
	if not merged:
		first_hit_usec = now
		duration_usec = requested
	else:
		duration_usec = maxi(duration_usec, requested)
	# A late member never starts a fresh full-duration stop.
	if now >= first_hit_usec + duration_usec:
		return false
	if not active:
		scale_changing.emit()
		_previous_scale = Engine.time_scale
		active = true
		Engine.time_scale = 0.0
		stop_started.emit(float(duration_usec) / 1000.0)
	return true

func poll(now_usec: int = -1) -> void:
	var now: int = Time.get_ticks_usec() if now_usec < 0 else now_usec
	if active and (now >= first_hit_usec + duration_usec or (is_inside_tree() and get_tree().paused)):
		_restore()

func cancel() -> void:
	if active:
		_restore()
	first_hit_usec = -MERGE_WINDOW_USEC - 1
	duration_usec = 0

func _restore() -> void:
	scale_changing.emit()
	active = false
	Engine.time_scale = float(restore_scale.call()) if restore_scale.is_valid() else _previous_scale
	stop_ended.emit()

func _process(_delta: float) -> void:
	poll()

func _exit_tree() -> void:
	cancel()
