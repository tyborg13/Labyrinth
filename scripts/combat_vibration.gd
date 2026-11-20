extends RefCounted

const MERGE_WINDOW_USEC: int = preload("res://scripts/combat_hit_stop.gd").MERGE_WINDOW_USEC

var start_vibration: Callable = Input.start_joy_vibration
var stop_vibration: Callable = Input.stop_joy_vibration
var ticks_usec: Callable = Time.get_ticks_usec
var device_id: int = -1
var _started_usec: int = 0
var _weak: float = 0.0
var _strong: float = 0.0
var _seconds: float = 0.0

func has_active_pulse() -> bool:
	if device_id >= 0 and int(ticks_usec.call()) - _started_usec >= _seconds * 1000000.0:
		device_id = -1
	return device_id >= 0

func request(device: int, weak: float, strong: float, seconds: float) -> void:
	var now: int = ticks_usec.call()
	if device_id != device:
		stop()
	var merged: bool = device_id == device and now - _started_usec <= MERGE_WINDOW_USEC
	if merged:
		weak = maxf(_weak, weak)
		strong = maxf(_strong, strong)
		if weak == _weak and strong == _strong:
			return
		# Godot replaces both motor magnitudes together. Send only the time
		# remaining on the merged pulse, measured from the original hit.
		seconds = maxf(_seconds, seconds)
	else:
		_started_usec = now
	device_id = device
	_weak = weak
	_strong = strong
	_seconds = seconds
	start_vibration.call(device, weak, strong, seconds - float(now - _started_usec) / 1000000.0)

func stop() -> void:
	if device_id >= 0:
		stop_vibration.call(device_id)
		device_id = -1
