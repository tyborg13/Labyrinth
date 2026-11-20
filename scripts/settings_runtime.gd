extends Node
## Owns settings events that must survive scene transitions.

const Settings = preload("res://scripts/settings_store.gd")
const Suspend = preload("res://scripts/application_suspend.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
# Director 2026-11-20: save half a second after the window stops moving or resizing.
const WINDOW_SAVE_DEBOUNCE_SECONDS: float = 0.5

var _display: Object = DisplayServer
var _last_rect: Rect2i
var _last_screen: int = -1
var _pending_geometry: Dictionary = {}
var _save_timer := Timer.new()
var _audio: RefCounted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(Settings.RUNTIME_GROUP)
	_audio = Suspend.for_tree(get_tree())
	_audio.focus_changed(get_tree().root, _display.window_is_focused())
	_save_timer.one_shot = true
	_save_timer.ignore_time_scale = true
	_save_timer.wait_time = WINDOW_SAVE_DEBOUNCE_SECONDS
	_save_timer.timeout.connect(_save_window)
	add_child(_save_timer)
	set_process(
		_display.get_name() != "headless"
		and not OS.has_environment("LABYRINTH_PROBE_WINDOW")
		and Settings.window_geometry_saves_allowed()
	)

func _exit_tree() -> void:
	if _audio != null:
		_audio.dispose()

func _notification(what: int) -> void:
	if what not in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_RESUMED]:
		return
	if _audio == null or not is_inside_tree() or Shutdown.quit_requested(get_tree()):
		return
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_audio.handle(self, what)
	else:
		_audio.focus_changed(get_tree().root, what == NOTIFICATION_APPLICATION_FOCUS_IN)

func _process(_delta: float) -> void:
	if Shutdown.quit_requested(get_tree()):
		return
	if not Settings.tracks_window_geometry(_display):
		if _last_screen >= 0:
			_last_screen = -1
			_save_window()
		return
	var rect := Rect2i(_display.window_get_position(), _display.window_get_size())
	var screen: int = _display.window_get_current_screen()
	if rect == _last_rect and screen == _last_screen:
		return
	if _last_screen >= 0:
		var snapshot: Dictionary = Settings.window_geometry_snapshot(_display)
		if not snapshot.is_empty():
			_pending_geometry = snapshot
			_save_timer.start()
	_last_rect = rect
	_last_screen = screen

func _save_window() -> void:
	if _pending_geometry.is_empty() or Shutdown.quit_requested(get_tree()):
		return
	if Settings.tracks_window_geometry(_display):
		var rect := Rect2i(_display.window_get_position(), _display.window_get_size())
		# The timer can fire before the process poll on the last resize frame.
		if rect != _last_rect or _display.window_get_current_screen() != _last_screen:
			return
	_flush_pending_window()

func flush_window_memory() -> void:
	var snapshot: Dictionary = Settings.window_geometry_snapshot(_display)
	if not snapshot.is_empty():
		_pending_geometry = snapshot
	_flush_pending_window()

func _flush_pending_window() -> void:
	if _pending_geometry.is_empty():
		return
	if Settings.save_window_geometry_snapshot(_pending_geometry):
		_pending_geometry.clear()
		_save_timer.stop()
	else:
		_save_timer.start()
