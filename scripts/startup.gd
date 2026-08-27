extends Control
## One-time application entry; returning to main_menu.tscn never replays this.

signal phase_changed(phase: StringName)
signal finished(menu: Control)

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const FADE_IN_SECONDS := 0.4
const HOLD_SECONDS := 2.0
const FADE_OUT_SECONDS := 0.35
const MENU_FADE_SECONDS := 0.4

@onready var seal: TextureRect = $Seal

var phase: StringName = &"black"
var menu: Control
var _settings: Dictionary
var _viewport: Viewport
var _input_was_disabled: bool
var _input_locked: bool = false
var _cursor: CanvasLayer
var _cursor_was_visible: bool
var _cursor_input_was_enabled: bool


func _ready() -> void:
	ParallelRuntime.apply_from_environment()
	_settings = SettingsStore.apply_settings(SettingsStore.load_settings(), get_window())
	_viewport = get_viewport()
	_input_was_disabled = _viewport.gui_disable_input
	_viewport.gui_disable_input = true
	_input_locked = true
	_cursor = get_node_or_null("/root/CursorFeedback") as CanvasLayer
	if _cursor != null:
		_cursor_was_visible = _cursor.visible
		_cursor_input_was_enabled = _cursor.is_processing_input()
		_cursor.hide()
		_cursor.set_process_input(false)
	var error := ResourceLoader.load_threaded_request(MENU_SCENE_PATH, "PackedScene")
	if error != OK:
		_fail("Could not request the main menu (error %d)." % error)
		return
	_play_intro.call_deferred()


func _play_intro() -> void:
	# Present black before fading, matching the native engine's black splash.
	await _present_frame()
	_set_phase(&"fade_in")
	await _fade(seal, 1.0, FADE_IN_SECONDS)
	await _present_frame()
	_set_phase(&"hold")
	# Keep a full two seconds at full opacity, independent of loading and fades.
	var hold_until_ms := Time.get_ticks_msec() + int(HOLD_SECONDS * 1000.0)
	while Time.get_ticks_msec() < hold_until_ms:
		await get_tree().process_frame
	while ResourceLoader.load_threaded_get_status(MENU_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(MENU_SCENE_PATH) != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("Could not load the main menu.")
		return
	var packed := ResourceLoader.load_threaded_get(MENU_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("The main-menu resource is not a scene.")
		return
	_set_phase(&"fade_out")
	await _fade(seal, 0.0, FADE_OUT_SECONDS)
	_set_phase(&"menu_black")
	menu = packed.instantiate() as Control
	if menu == null:
		_fail("The main-menu scene has no Control root.")
		return
	menu.modulate.a = 0.0
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	# Startup's opaque black stays behind the menu until the reveal is complete.
	await _present_frame()
	_set_phase(&"menu_fade_in")
	await _fade(menu, 1.0, MENU_FADE_SECONDS)
	_release_input()
	_set_phase(&"complete")
	finished.emit(menu)
	queue_free()


func _fade(target: CanvasItem, alpha: float, seconds: float) -> void:
	var duration := SettingsStore.motion_duration(seconds, _settings)
	if duration <= 0.0:
		target.modulate.a = alpha
		return
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "modulate:a", alpha, duration)
	await tween.finished


func _present_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _set_phase(next_phase: StringName) -> void:
	phase = next_phase
	phase_changed.emit(phase)


func _release_input() -> void:
	if not _input_locked:
		return
	_input_locked = false
	if is_instance_valid(_viewport):
		_viewport.gui_disable_input = _input_was_disabled
	if is_instance_valid(_cursor):
		_cursor.visible = _cursor_was_visible
		_cursor.set_process_input(_cursor_input_was_enabled)


func _exit_tree() -> void:
	_release_input()
	if is_instance_valid(menu):
		menu.modulate.a = 1.0


func _fail(message: String) -> void:
	push_error("Startup: " + message)
	_release_input()
	get_tree().quit(1)
