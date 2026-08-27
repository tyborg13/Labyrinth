extends CanvasLayer
## Keeps the actual menu above the destination until its initial layout is drawn.

signal phase_changed(phase: StringName)
signal finished(destination: Node)
signal failed

const SettingsStore = preload("res://scripts/settings_store.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const MESSAGE := "Entering the Labyrinth"
const DOT_SECONDS := 0.38
const REVEAL_SECONDS := 0.22
const MENU_MUSIC_FADE_OUT_SECONDS := 0.2
const MUSIC_GAP_SECONDS := 0.1
const ROOM_MUSIC_FADE_IN_SECONDS := 0.3

var phase: StringName = &"loading"
var message_label: Label
var destination: Node
var _surface: Control
var _menu: Control
var _menu_parent: Node
var _menu_process_mode: ProcessMode
var _menu_music: AudioStreamPlayer
var _menu_music_process_mode: ProcessMode
var _destination_process_mode: ProcessMode
var _viewport: Viewport
var _input_was_disabled: bool
var _input_locked: bool = false
var _cursor: Node
var _cursor_input_was_enabled: bool
var _settings: Dictionary
var _elapsed: float = 0.0
var _path: String
var _prepare_run: Callable

func begin(menu: Control, path: String, prepare_run: Callable) -> void:
	name = "MenuRunTransition"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = menu
	_menu_parent = menu.get_parent()
	_menu_process_mode = menu.process_mode
	_menu_music = menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if _menu_music != null:
		_menu_music_process_mode = _menu_music.process_mode
		# Disabling menu input must not pause its inherited audio processing.
		_menu_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_path = path
	_prepare_run = prepare_run
	_settings = SettingsStore.load_settings()
	_viewport = menu.get_viewport()
	_input_was_disabled = _viewport.gui_disable_input
	_viewport.gui_disable_input = true
	_input_locked = true
	_cursor = menu.get_node_or_null("/root/CursorFeedback")
	if _cursor != null:
		_cursor_input_was_enabled = _cursor.is_processing_input()
		_cursor.set_process_input(false)
		_cursor.call("begin_loading")
	_menu_parent.add_child(self)
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	# No scene replacement or viewport snapshot: even expensive main-thread
	# instantiation leaves the last drawn menu/loading frame on screen.
	get_tree().current_scene = self
	menu.reparent(_surface, false)
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.017, 0.032, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(center)
	message_label = Label.new()
	message_label.text = MESSAGE + "..."
	message_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(message_label, UiTypography.ROLE_BANNER)
	message_label.add_theme_color_override("font_color", Color("f4dfb0"))
	message_label.add_theme_color_override("font_outline_color", Color("170e16"))
	message_label.add_theme_constant_override("outline_size", 6)
	UiTypography.apply_stone_text(message_label)
	center.add_child(message_label)
	_update_dots()
	_load_destination.call_deferred()

func _process(delta: float) -> void:
	_elapsed += delta
	_update_dots()

func _update_dots() -> void:
	if message_label == null:
		return
	# Reveal characters in an already-shaped full label so the words never
	# shift sideways as the suffix cycles through one, two, three, zero dots.
	message_label.visible_characters = -1 if SettingsStore.reduced_motion_enabled(_settings) else MESSAGE.length() + (1 + int(_elapsed / DOT_SECONDS)) % 4

func _load_destination() -> void:
	await _present_frame()
	var error := ResourceLoader.load_threaded_request(_path, "PackedScene")
	if error != OK:
		_fail()
		return
	while ResourceLoader.load_threaded_get_status(_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(_path) != ResourceLoader.THREAD_LOAD_LOADED:
		_fail()
		return
	var packed := ResourceLoader.load_threaded_get(_path) as PackedScene
	if packed == null or not packed.can_instantiate():
		_fail()
		return
	_set_phase(&"preparing")
	destination = packed.instantiate()
	if destination == null:
		_fail()
		return
	# Only commit New Run replacement / resume intent after loading succeeds.
	if _prepare_run.is_valid():
		_prepare_run.call()
	if destination.has_method("defer_initial_music_until_reveal"):
		destination.call("defer_initial_music_until_reveal")
	_destination_process_mode = destination.process_mode
	destination.process_mode = Node.PROCESS_MODE_DISABLED
	_menu_parent.add_child(destination)
	# RunScene._ready builds the room synchronously, then its hand layout waits
	# two process frames before scheduling additional hand/dock fitting. Allow
	# that first refresh to run, then use the room's live readiness contract;
	# a frame count alone can reveal a still-hidden Pass button in reduced motion.
	for frame: int in range(3):
		await get_tree().process_frame
	while true:
		await _present_frame()
		if not destination.has_method("initial_presentation_is_ready") or bool(destination.call("initial_presentation_is_ready")):
			break
		await get_tree().process_frame
	_set_phase(&"revealing")
	var duration := SettingsStore.motion_duration(REVEAL_SECONDS, _settings)
	if duration > 0.0:
		var tween := create_tween().set_ignore_time_scale(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_surface, "modulate:a", 0.0, duration)
		await tween.finished
	_surface.hide()
	get_tree().current_scene = destination
	destination.process_mode = _destination_process_mode
	# The room is playable immediately; its music waits for the outgoing
	# track to fade out completely and a brief quiet beat. Never overlap.
	_handoff_menu_music_to_room()
	_release_input()
	_set_phase(&"complete")
	finished.emit(destination)
	queue_free()

func _present_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func _set_phase(value: StringName) -> void:
	phase = value
	phase_changed.emit(value)

func _release_input() -> void:
	if not _input_locked:
		return
	_input_locked = false
	if is_instance_valid(_viewport):
		_viewport.gui_disable_input = _input_was_disabled
	if is_instance_valid(_cursor):
		_cursor.set_process_input(_cursor_input_was_enabled)
		_cursor.call("end_loading")

func _fail() -> void:
	_menu.reparent(_menu_parent, false)
	_menu.process_mode = _menu_process_mode
	_restore_menu_music_process_mode()
	get_tree().current_scene = _menu
	_release_input()
	failed.emit()
	queue_free()

func _handoff_menu_music_to_room() -> void:
	# Room ownership cancels the sequence safely if the player leaves.
	var tween := destination.create_tween().set_ignore_time_scale(true)
	if is_instance_valid(_menu_music):
		var music := _menu_music
		_menu_music = null
		music.name = "MenuMusicTail"
		music.reparent(destination)
		music.process_mode = _menu_music_process_mode
		tween.tween_property(music, "volume_linear", 0.0, MENU_MUSIC_FADE_OUT_SECONDS)
		tween.tween_callback(music.stop)
		tween.tween_callback(music.queue_free)
	tween.tween_interval(MUSIC_GAP_SECONDS)
	if destination.has_method("start_initial_music_after_loading"):
		tween.tween_callback(Callable(destination, "start_initial_music_after_loading").bind(ROOM_MUSIC_FADE_IN_SECONDS))

func _restore_menu_music_process_mode() -> void:
	if is_instance_valid(_menu_music):
		_menu_music.process_mode = _menu_music_process_mode

func _exit_tree() -> void:
	_release_input()
	_restore_menu_music_process_mode()
	if is_instance_valid(destination):
		destination.process_mode = _destination_process_mode
