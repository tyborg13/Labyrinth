extends RefCounted
## Suspend only drains previously committed writes. Never snapshot live combat
## here: the presentation can be between two safe action boundaries.
const Store = preload("res://scripts/progression_store.gd")
const STATE_META := &"labyrinth_application_suspend"
const FADE_OUT_SECONDS: float = 0.15
const FADE_IN_SECONDS: float = 0.3

var _suspended: bool = false
var _focused: bool = true
var _mute_in_background: bool = false
var _silenced: bool = false
var _owns_volume: bool = false
var _resume_volume: float = 0.0
var _fade: Tween

static func for_tree(tree: SceneTree) -> RefCounted:
	if not tree.root.has_meta(STATE_META):
		var script: Script = load("res://scripts/application_suspend.gd")
		tree.root.set_meta(STATE_META, script.new())
	return tree.root.get_meta(STATE_META)

func handle(scene: Node, what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED and not _suspended:
		_suspended = true
		_update_silence(scene.get_tree().root)
		if not Store.flush_pending_run_saves():
			push_warning("Failed to flush the committed checkpoint on application suspend.")
	elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED and _suspended:
		_suspended = false
		_update_silence(scene.get_tree().root)

func focus_changed(host: Node, focused: bool) -> void:
	_focused = focused
	_update_silence(host)

func apply_audio_settings(host: Node, volume: float, mute_in_background: bool) -> void:
	var master: int = AudioServer.get_bus_index("Master")
	if not _owns_volume:
		AudioServer.set_bus_volume_linear(master, volume)
	elif not is_equal_approx(_resume_volume, volume) and not _silenced:
		_start_resume(host, master, volume)
	_resume_volume = volume
	_mute_in_background = mute_in_background
	_update_silence(host)

func _update_silence(host: Node) -> void:
	var silenced: bool = _suspended or (_mute_in_background and not _focused)
	if silenced == _silenced:
		return
	_silenced = silenced
	var master: int = AudioServer.get_bus_index("Master")
	if _silenced:
		if not _owns_volume:
			_resume_volume = AudioServer.get_bus_volume_linear(master)
		_owns_volume = true
		_fade_to(host, master, 0.0, FADE_OUT_SECONDS)
	else:
		_start_resume(host, master, _resume_volume)

func _start_resume(host: Node, master: int, target: float) -> void:
	_fade_to(host, master, target, FADE_IN_SECONDS)
	_fade.tween_callback(func() -> void: _owns_volume = false)

func _fade_to(scene: Node, master: int, target: float, seconds: float) -> void:
	if _fade != null: _fade.kill()
	_fade = scene.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
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
	_silenced = false
