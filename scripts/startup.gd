extends Control
## One-time application entry; returning to main_menu.tscn never replays this.

signal phase_changed(phase: StringName)
signal finished(menu: Control)

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const CanvasPrewarm = preload("res://scripts/canvas_pipeline_prewarm.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const MenuAssets = preload("res://scripts/menu_title_assets.gd")
const Glyphs = preload("res://scripts/ui_glyph_preparation.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const MAKERS_SEAL_PATH := "res://assets/art/ui/boot_splash_makers_seal.png"
const FADE_IN_SECONDS := 0.4
const HOLD_SECONDS := 1.0
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
var _menu_scene_pending: bool
var _quitting: bool
var _fade_tween: Tween
var _fade_duration: float
var _packed_menu: PackedScene
var _prepared_menu: Control
var _staged_viewport: Array
var _staged_viewport_changed: bool
var _audio_preparation_started: bool
var _glyph_preparation_started: bool
static var _hitch_trace_enabled := OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"


func _ready() -> void:
	set_process(false)
	ParallelRuntime.apply_from_environment()
	var _trace := _boot_trace("seal_texture")
	seal.texture = AssetLoader.load_texture_source_first(MAKERS_SEAL_PATH)
	if seal.texture == null:
		_fail("Could not load the Maker's Seal.")
		return
	_trace = _boot_trace("settings")
	_settings = SettingsStore.apply_settings(SettingsStore.load_settings(), get_window())
	_trace = null
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
	_trace = _boot_trace("menu_scene_request")
	var error := SceneLoads.request_for(get_tree(), MENU_SCENE_PATH)
	if error != OK:
		_fail("Could not request the main menu (error %d)." % error)
		return
	_menu_scene_pending = true
	_play_intro.call_deferred()


func _play_intro() -> void:
	# Present black before fading, matching the native engine's black splash.
	await Shutdown.preparation_signal(get_tree())
	if _quitting: return
	_set_phase(&"fade_in")
	await _fade(seal, 1.0, FADE_IN_SECONDS)
	if _quitting: return
	await Shutdown.preparation_signal(get_tree())
	if _quitting: return
	_set_phase(&"hold")
	if _quitting: return
	# Keep a full second at full opacity, independent of loading and fades.
	var hold_until_ms := Clock.ticks_msec() + int(HOLD_SECONDS * 1000.0)
	CanvasPrewarm.start(self, CanvasPrewarm.Recipes.Phase.COVER_INTRO)
	# These textures are independent of the packed scene. Keep the original
	# hold-time art preparation even when the engine scene request is late.
	var tree := get_tree()
	MenuAssets.prepare_for(tree.root, Shutdown.present_preparation.bind(tree), _cover_is_active.bind(self))
	set_process(true)
	while Clock.ticks_msec() < hold_until_ms:
		await get_tree().process_frame
		if _quitting: return
	while not _take_loaded_menu():
		await get_tree().process_frame
		if _quitting: return
	if _packed_menu == null:
		_fail("Could not load the main menu.")
		return
	_set_phase(&"fade_out")
	await _fade(seal, 0.0, FADE_OUT_SECONDS)
	if _quitting: return
	set_process(false)
	CanvasPrewarm.stop(self)
	_set_phase(&"menu_black")
	if _quitting: return
	menu = _reveal_menu()
	if menu == null:
		_fail("The main-menu scene has no Control root.")
		return
	get_tree().current_scene = menu
	_prepare_menu_glyphs(menu)
	# Startup's opaque black stays behind the menu until the reveal is complete.
	await Shutdown.preparation_signal(get_tree())
	if _quitting: return
	_set_phase(&"menu_fade_in")
	await _fade(menu, 1.0, MENU_FADE_SECONDS)
	if _quitting: return
	_release_input()
	_set_phase(&"complete")
	finished.emit(menu)
	queue_free()


func _process(_delta: float) -> void:
	if _quitting or not _take_loaded_menu() or _packed_menu == null: return
	if AssetLoader.preparation_slice_full(): return
	var tree := get_tree()
	var present := Shutdown.present_preparation.bind(tree)
	var active := _cover_is_active.bind(self)
	# Keep construction on the main thread, one stage per frame.
	if _prepared_menu == null:
		_instantiate_menu()
		if _prepared_menu == null:
			set_process(false)
			return
	elif not _prepared_menu.is_inside_tree():
		_attach_prepared_menu(_prepared_menu)
	elif not _audio_preparation_started:
		_audio_preparation_started = true
		var started := Time.get_ticks_usec()
		_prepared_menu.prepare_boot_audio(present, active)
		AssetLoader.count_preparation_work(started)
	elif not _prepared_menu.prepare_next_boot_step():
		set_process(false)
		_prepare_menu_glyphs(_prepared_menu)


func _prepare_menu_glyphs(control: Control) -> void:
	if _glyph_preparation_started: return
	_glyph_preparation_started = true
	# Glyphs use the live controls' font caches. A partial batch can finish
	# during reveal while the same controls rasterize any first-use misses.
	var present := Shutdown.present_preparation.bind(get_tree())
	Glyphs.prepare_hidden_controls_for(self, control, present, _glyphs_are_active.bind(self, control), false, "startup:menu")


func _take_loaded_menu() -> bool:
	if not _menu_scene_pending: return true
	var _trace := _boot_trace("menu_scene_poll")
	if SceneLoads.status_for(get_tree(), MENU_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	_packed_menu = SceneLoads.take_for(get_tree(), MENU_SCENE_PATH) as PackedScene
	_menu_scene_pending = false
	return true


func _instantiate_menu() -> void:
	if _prepared_menu != null: return
	var _trace := _boot_trace("menu_scene_instantiate")
	var started := Time.get_ticks_usec()
	var instance: Node = _packed_menu.instantiate()
	_prepared_menu = instance as Control
	if _prepared_menu == null and instance != null: instance.free()
	AssetLoader.count_preparation_work(started)


func _attach_prepared_menu(control: Control) -> void:
	var _trace := _boot_trace("menu_attach_and_settings_panel")
	var started := Time.get_ticks_usec()
	_staged_viewport = _viewport_layout()
	_viewport.size_changed.connect(_invalidate_staged_viewport, CONNECT_ONE_SHOT)
	control.stage_for_boot()
	control.modulate.a = 0.0
	get_tree().root.add_child(control)
	AssetLoader.count_preparation_work(started)


func _reveal_menu() -> Control:
	var settings: Dictionary = {}
	if is_instance_valid(_prepared_menu) and _prepared_menu.is_inside_tree():
		var _trace := _boot_trace("menu:staged_settings_read")
		settings = SettingsStore.load_settings()
		_trace = null
		if not _staged_layout_matches(settings):
			# Controls such as Settings, Chronicle and controller glyphs size
			# themselves on entry. Run that same setup at the reveal viewport.
			_prepared_menu.get_parent().remove_child(_prepared_menu)
			_prepared_menu.queue_free()
			_prepared_menu = null
	_instantiate_menu()
	var result := _prepared_menu
	_prepared_menu = null
	if result == null: return null
	if result.is_inside_tree():
		result.reveal_from_boot(settings)
	else:
		result.modulate.a = 0.0
		get_tree().root.add_child(result)
	return result


func _staged_layout_matches(settings: Dictionary) -> bool:
	return not _staged_viewport_changed and _staged_viewport == _viewport_layout() and \
		is_equal_approx(float(settings["ui_scale"]), get_window().content_scale_factor) and \
		settings["ui_scale"] == _settings["ui_scale"] and settings["display_mode"] == _settings["display_mode"]


func _viewport_layout() -> Array:
	var window := get_window()
	return [window.size, window.mode, window.content_scale_factor, _viewport.get_visible_rect().size, _viewport.get_oversampling()]


func _invalidate_staged_viewport() -> void:
	_staged_viewport_changed = true


static func _cover_is_active(owner: Variant) -> bool:
	return is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() and \
		not owner._quitting and (owner.phase == &"hold" or owner.phase == &"fade_out")


static func _glyphs_are_active(owner: Variant, control: Variant) -> bool:
	if not is_instance_valid(control) or control.is_queued_for_deletion(): return false
	return is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() and \
		not owner._quitting and owner.phase != &"complete"


func _boot_trace(label: String) -> RefCounted:
	if not _hitch_trace_enabled: return null
	return get_node("/root/PerformanceTelemetry").hitch_phase("startup:" + label)


func _fade(target: CanvasItem, alpha: float, seconds: float) -> void:
	var duration := SettingsStore.motion_duration(seconds, _settings)
	if duration <= 0.0:
		target.modulate.a = alpha
		return
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "modulate:a", alpha, duration)
	_fade_tween = tween
	_fade_duration = duration
	await tween.finished
	_fade_tween = null


func cancel_loading_for_quit() -> void:
	_quitting = true
	set_process(false)
	# During root teardown a sibling can have exited the tree while still
	# parented. Queue it for deletion without mutating the root's child list.
	if is_instance_valid(_prepared_menu): _prepared_menu.queue_free()
	_prepared_menu = null
	# Release the intro continuation before the hidden scene stops processing.
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.custom_step(_fade_duration * 2.0)


func _set_phase(next_phase: StringName) -> void:
	phase = next_phase
	phase_changed.emit(phase)


func _release_input() -> void:
	if not _input_locked:
		return
	_input_locked = false
	if is_instance_valid(_viewport) and not _quitting:
		_viewport.gui_disable_input = _input_was_disabled
	if is_instance_valid(_cursor):
		_cursor.visible = _cursor_was_visible
		_cursor.set_process_input(_cursor_input_was_enabled)


func _exit_tree() -> void:
	if _menu_scene_pending: SceneLoads.abandon_for(get_tree(), MENU_SCENE_PATH)
	_release_input()
	# A scene-bound tween disappears on teardown without emitting finished.
	# Resolve its continuation while the intro can still observe cancellation.
	cancel_loading_for_quit()
	if is_instance_valid(menu):
		menu.modulate.a = 1.0


func _fail(message: String) -> void:
	push_error("Startup: " + message)
	_release_input()
	Shutdown.request(get_tree(), "startup_failure", 1)
