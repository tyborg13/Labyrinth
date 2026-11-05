extends RefCounted
## Suspend only drains previously committed writes. Never snapshot live combat
## here: the presentation can be between two safe action boundaries.
const Store = preload("res://scripts/progression_store.gd")
const FADE_OUT_SECONDS: float = 0.15
const FADE_IN_SECONDS: float = 0.3

var _suspended: bool = false
var _owns_volume: bool = false
var _resume_volume: float = 0.0
var _fade: Tween

func handle(scene: Node, what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
		if _suspended: return
		_suspended = true
		var master: int = AudioServer.get_bus_index("Master")
		if not _owns_volume:
			_resume_volume = AudioServer.get_bus_volume_linear(master)
		_owns_volume = true
		_fade_to(scene, master, 0.0, FADE_OUT_SECONDS)
		if not Store.flush_pending_run_saves():
			push_warning("Failed to flush the committed checkpoint on application suspend.")
	elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED and _suspended:
		_suspended = false
		_fade_to(scene, AudioServer.get_bus_index("Master"), _resume_volume, FADE_IN_SECONDS)
		_fade.tween_callback(func() -> void: _owns_volume = false)

func _fade_to(scene: Node, master: int, target: float, seconds: float) -> void:
	if _fade != null: _fade.kill()
	_fade = scene.create_tween()
	_fade.tween_method(_set_volume.bind(master), AudioServer.get_bus_volume_linear(master), target, seconds)

func _set_volume(value: float, master: int) -> void:
	AudioServer.set_bus_volume_linear(master, value)

func dispose() -> void:
	if _fade != null: _fade.kill()
	_fade = null
	if _owns_volume:
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), _resume_volume)
	_owns_volume = false
	_suspended = false
