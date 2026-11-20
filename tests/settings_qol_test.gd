extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const WindowGeometry = preload("res://scripts/settings_window_geometry.gd")
const Suspend = preload("res://scripts/application_suspend.gd")
const SettingsRuntime = preload("res://scripts/settings_runtime.gd")
const SettingsPanelScript = preload("res://scripts/settings_panel.gd")
const ExistingSettingsProof = preload("res://tests/settings_probe.gd")
const TEST_STORAGE: String = "user://ux12_settings_test.json"
const LEGACY_SCALE: float = 1.25
const DISPLAY_KEYS := ["display_mode", "ui_scale", "edge_smoothing"]
const MASTER_FIXTURE_VOLUME: float = 0.60
const UI_FIXTURE_VOLUME: float = 0.35
const SFX_FIXTURE_VOLUME: float = 0.55
const PRIMARY_USABLE_RECT := Rect2i(0, 0, 1920, 1080)
const SECONDARY_USABLE_RECT := Rect2i(-1800, 40, 1800, 1000)
const SAVED_WINDOW_RECT := Rect2i(-1700, 110, 1200, 700)
const OFF_SCREEN_POSITION := Vector2i(9000, -9000)
const SECONDARY_SCREEN: int = 1

const SECONDARY_SCREEN_RECT := Rect2i(-1800, 0, 1800, 1080)
const OTHER_SCREEN_RECT := Rect2i(1920, 0, 1600, 900)
const DECORATION_FIXTURE := Vector4i(8, 32, 12, 10)
const EXTERNAL_MUSIC_VOLUME: float = 0.25
const WINDOWS_TOP_GUARD: int = 40
const SHIFTED_SAVED_SCREEN := Rect2i(1920, 0, 1920, 1080)
const OFFSET_FIXTURE := Vector2i(100, 110)
const TASKBAR_HEIGHT: int = 48
const TALL_CLIENT_HEIGHT: int = 1020
const TALL_WINDOW_RECT := Rect2i(100, 40, 1200, TALL_CLIENT_HEIGHT)
const GAME_MODE_WINDOW_RECT := Rect2i(0, 0, 1280, 800)
const DESKTOP_ENV_KEYS := ["XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION", "GAMESCOPE_WAYLAND_DISPLAY"]

class TestDisplay extends RefCounted:
	var backend: String = "X11"
	var focused: bool = true
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN
	var position: Vector2i = Vector2i(0, 0)
	var size: Vector2i = Vector2i(1920, 1080)
	var active_screen: int = 0
	var primary_screen: int = 0
	var screens: Array[Rect2i] = []
	var usable_rects: Array[Rect2i] = []
	var decorations: Vector4i

	func get_name() -> String: return backend
	func get_primary_screen() -> int: return primary_screen
	func get_screen_count() -> int: return screens.size()
	func screen_get_position(screen: int) -> Vector2i: return screens[screen].position
	func screen_get_size(screen: int) -> Vector2i: return screens[screen].size
	func screen_get_usable_rect(screen: int) -> Rect2i: return usable_rects[screen]
	func window_get_current_screen() -> int: return active_screen
	func window_is_focused() -> bool: return focused
	func window_get_mode() -> int: return mode
	func window_get_position() -> Vector2i: return position
	func window_get_size() -> Vector2i: return size
	func window_get_position_with_decorations() -> Vector2i:
		return position - Vector2i(decorations.x, decorations.y)
	func window_get_size_with_decorations() -> Vector2i:
		return size + Vector2i(decorations.x + decorations.z, decorations.y + decorations.w)
	func window_set_mode(value: int) -> void: mode = value
	func window_set_size(value: Vector2i) -> void: size = value
	func window_set_position(value: Vector2i) -> void:
		position = value
		for index: int in screens.size():
			if screens[index].has_point(position):
				active_screen = index
				break

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Settings.set_storage_path(TEST_STORAGE)
	var old_deck: String = OS.get_environment("SteamDeck")
	var had_deck: bool = OS.has_environment("SteamDeck")
	var desktop_environment := {}
	for key: String in DESKTOP_ENV_KEYS:
		if OS.has_environment(key):
			desktop_environment[key] = OS.get_environment(key)
		OS.unset_environment(key)
	OS.set_environment("XDG_CURRENT_DESKTOP", "KDE")
	_test_flat_settings()
	_test_window_restore()
	_test_native_window_rules()
	_test_shifted_origin_and_smaller_work_area()
	_test_fitting_windows_rect()
	_test_main_display_change()
	_test_deck_game_mode()
	_test_maximize_flush()
	OS.set_environment("SteamDeck", "0")
	Settings.clear_storage()
	await _test_audio_and_panel()
	_test_unfocused_startup()
	var defaults: Dictionary = Settings.default_settings()
	Settings.save_settings(defaults)
	ExistingSettingsProof.verify_atomic_writes(_expect, defaults)
	Settings.clear_storage()
	if had_deck:
		OS.set_environment("SteamDeck", old_deck)
	else:
		OS.unset_environment("SteamDeck")
	for key: String in DESKTOP_ENV_KEYS:
		if desktop_environment.has(key):
			OS.set_environment(key, desktop_environment[key])
		else:
			OS.unset_environment(key)
	print("Settings QoL checks: %d passed, %d failed" % [_checks - _failures, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _test_flat_settings() -> void:
	OS.set_environment("SteamDeck", "0")
	var legacy := {
		"display_mode": Settings.DISPLAY_WINDOWED,
		"ui_scale": LEGACY_SCALE,
		"edge_smoothing": Settings.EDGE_SMOOTHING_LOW,
	}
	_write_raw_settings(legacy)
	var loaded: Dictionary = Settings.load_settings()
	_expect(_legacy_display_reader(loaded) == legacy, "Legacy display preferences load from the flat keys")
	_expect(loaded["ui_volume"] == 1.0 and not loaded["mute_in_background"], "Legacy audio retains the old mix and focus behavior")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_STORAGE))
	_expect(on_disk == legacy, "Reading a legacy file leaves it intact")
	loaded["ui_volume"] = UI_FIXTURE_VOLUME
	loaded["mute_in_background"] = true
	loaded.merge(_saved_window_settings())
	_expect(Settings.save_settings(loaded), "New settings save to the flat file")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_STORAGE))
	_expect(not payload.has("device_settings") and _legacy_display_reader(payload) == legacy, "New file remains readable through legacy flat keys")
	_expect(payload["mute_in_background"] and payload["ui_volume"] == UI_FIXTURE_VOLUME and payload.has("window_screen_size"), "New audio and window settings are additive flat keys")
	OS.set_environment("SteamDeck", "1")
	var deck_defaults: Dictionary = Settings.default_settings()
	_expect(deck_defaults["ui_scale"] == 1.15 and deck_defaults["edge_smoothing"] == Settings.EDGE_SMOOTHING_OFF, "Missing settings retain the existing Deck display defaults")
	_expect(_legacy_display_reader(Settings.load_settings()) == legacy, "Saved flat display settings take precedence over Deck defaults")

	# An old writer retains its known flat preferences and drops additive keys.
	_write_raw_settings(_legacy_display_reader(payload))
	var old_writer_result: Dictionary = Settings.load_settings()
	_expect(old_writer_result["ui_volume"] == 1.0 and not old_writer_result["mute_in_background"] and not old_writer_result.has("window_size"), "An older writer dropping new keys leads to their defaults")
	var malformed: Dictionary = Settings.normalize_settings({"ui_volume": -1, "mute_in_background": "on"})
	_expect(malformed["ui_volume"] == 0.0 and not malformed["mute_in_background"], "Invalid new audio fields normalize to safe values")
	OS.set_environment("SteamDeck", "0")
	_expect(Settings.restore_defaults(root) == Settings.default_settings(), "Restore Defaults resets the flat preferences")

func _write_raw_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(TEST_STORAGE, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	file.close()

func _legacy_display_reader(source: Dictionary) -> Dictionary:
	var display := {}
	for key: String in DISPLAY_KEYS:
		display[key] = source[key]
	return display

func _saved_window_settings() -> Dictionary:
	var offset: Vector2i = SAVED_WINDOW_RECT.position - SECONDARY_SCREEN_RECT.position
	return {
		"window_size": [SAVED_WINDOW_RECT.size.x, SAVED_WINDOW_RECT.size.y],
		"window_position": [offset.x, offset.y],
		"window_screen": SECONDARY_SCREEN,
		"window_screen_size": [SECONDARY_SCREEN_RECT.size.x, SECONDARY_SCREEN_RECT.size.y],
	}

func _test_window_restore() -> void:
	var screens: Array[Rect2i] = [PRIMARY_USABLE_RECT, SECONDARY_SCREEN_RECT]
	var usable_rects: Array[Rect2i] = [PRIMARY_USABLE_RECT, SECONDARY_USABLE_RECT]
	var saved: Dictionary = _saved_window_settings()
	_expect(WindowGeometry.restore_rect(saved, screens, usable_rects, 0) == SAVED_WINDOW_RECT, "Restore uses the saved monitor and preserves valid geometry")
	var off_screen: Dictionary = saved.duplicate(true)
	off_screen["window_position"] = [OFF_SCREEN_POSITION.x, OFF_SCREEN_POSITION.y]
	_expect(WindowGeometry.restore_rect(off_screen, screens, usable_rects, 0) == Rect2i(-1200, 40, 1200, 700), "Off-screen position clamps within the saved usable rectangle")
	var oversized: Dictionary = saved.duplicate(true)
	oversized["window_size"] = [SECONDARY_USABLE_RECT.size.x + 1, SECONDARY_USABLE_RECT.size.y + 1]
	var centered := Rect2i(160, 90, 1600, 900)
	var resized: Rect2i = WindowGeometry.restore_rect(oversized, screens, usable_rects, 0)
	_expect(SECONDARY_USABLE_RECT.encloses(resized) and resized.size.y < oversized["window_size"][1], "Oversized saved rectangle shrinks on the matching monitor")
	var missing_screen: Dictionary = saved.duplicate(true)
	missing_screen["window_screen_size"] = [OTHER_SCREEN_RECT.size.x, OTHER_SCREEN_RECT.size.y]
	_expect(WindowGeometry.restore_rect(missing_screen, screens, usable_rects, 0) == centered, "Missing saved monitor falls back to the centered window")
	_expect(Settings.save_settings(saved), "Window geometry saves")
	var loaded: Dictionary = Settings.load_settings()
	_expect(WindowGeometry.restore_rect(loaded, screens, usable_rects, 0) == SAVED_WINDOW_RECT, "Window geometry survives the JSON round-trip")
	saved.erase("window_position")
	_expect(not Settings.normalize_settings(saved).has("window_screen"), "Incomplete geometry is discarded together")

func _test_native_window_rules() -> void:
	var display := TestDisplay.new()
	var screens: Array[Rect2i] = [PRIMARY_USABLE_RECT, SECONDARY_SCREEN_RECT]
	var usable_rects: Array[Rect2i] = [PRIMARY_USABLE_RECT, SECONDARY_USABLE_RECT]
	display.screens = screens
	display.usable_rects = usable_rects
	var saved: Dictionary = _saved_window_settings()
	saved["display_mode"] = Settings.DISPLAY_WINDOWED
	OS.set_environment("SteamDeck", "1")
	display.mode = DisplayServer.WINDOW_MODE_WINDOWED
	_expect(Settings.tracks_window_geometry(display), "Native windowed mode supports tracking before a settings-driven transition")
	display.mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	var window := Window.new()
	Settings._apply_display_mode(saved, window, display)
	_expect(Rect2i(display.position, display.size) == SAVED_WINDOW_RECT, "Deck Desktop Mode restores the saved geometry")
	_expect(Settings.tracks_window_geometry(display) and Settings.save_window_geometry(display), "Deck Desktop Mode tracks and persists native window geometry")
	var persisted: Dictionary = Settings.load_settings()
	_expect(persisted.get("window_screen_size") == saved["window_screen_size"] and persisted.get("window_position") == saved["window_position"], "Window save persists the monitor dimensions and relative position")
	window.free()
	OS.set_environment("SteamDeck", "0")

	display.screens.reverse()
	display.usable_rects.reverse()
	display.primary_screen = 1
	display.active_screen = 1
	_expect(_restore_with_display(saved, display) == SAVED_WINDOW_RECT, "Restore finds the same-sized monitor after its index changes")
	display.screens[0] = OTHER_SCREEN_RECT
	display.usable_rects[0] = OTHER_SCREEN_RECT
	display.active_screen = 0
	_expect(_restore_with_display(saved, display) == Rect2i(160, 90, 1600, 900), "A reused index falls back to the primary when no screen matches the saved size")

	display.backend = "Windows"
	display.decorations = DECORATION_FIXTURE
	var windows_saved: Dictionary = saved.duplicate(true)
	windows_saved["window_position"] = [OFF_SCREEN_POSITION.y, OFF_SCREEN_POSITION.y]
	windows_saved["window_screen_size"] = [PRIMARY_USABLE_RECT.size.x, PRIMARY_USABLE_RECT.size.y]
	_expect(_restore_with_display(windows_saved, display).position == Vector2i(DECORATION_FIXTURE.x, DECORATION_FIXTURE.y), "Measured decorations keep the title bar and left border on screen")
	windows_saved["window_position"] = [OFF_SCREEN_POSITION.x, OFF_SCREEN_POSITION.x]
	var bottom_right: Rect2i = _restore_with_display(windows_saved, display)
	_expect(bottom_right.end == PRIMARY_USABLE_RECT.end - Vector2i(DECORATION_FIXTURE.z, DECORATION_FIXTURE.w), "Measured decorations keep the bottom and right borders on screen")
	display.decorations = Vector4i.ZERO
	windows_saved["window_position"] = [0, OFF_SCREEN_POSITION.y]
	_expect(_restore_with_display(windows_saved, display).position.y == WINDOWS_TOP_GUARD, "Windows reserves 40 px above the client area when title dimensions are unavailable")

func _restore_with_display(settings: Dictionary, display: TestDisplay) -> Rect2i:
	display.mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	var window := Window.new()
	Settings._apply_display_mode(settings, window, display)
	window.free()
	return Rect2i(display.position, display.size)

func _test_shifted_origin_and_smaller_work_area() -> void:
	var screens: Array[Rect2i] = [PRIMARY_USABLE_RECT, SHIFTED_SAVED_SCREEN]
	var saved: Dictionary = _saved_window_settings()
	saved.erase("window_screen_size")
	saved["window_screen_rect"] = [SHIFTED_SAVED_SCREEN.position.x, SHIFTED_SAVED_SCREEN.position.y, SHIFTED_SAVED_SCREEN.size.x, SHIFTED_SAVED_SCREEN.size.y]
	saved["window_position"] = [SHIFTED_SAVED_SCREEN.position.x + OFFSET_FIXTURE.x, OFFSET_FIXTURE.y]
	saved = Settings.normalize_settings(saved)
	var shifted := WindowGeometry.restore_rect(saved, screens, screens, SECONDARY_SCREEN)
	_expect(shifted.position == OFFSET_FIXTURE + screens[SECONDARY_SCREEN].position, "Unplugging a different monitor preserves the saved offset when the desktop origin shifts")
	# Windows reindexes the remaining monitors in this fixture, while the saved
	# index still denotes the primary. Its old absolute bounds now describe the right monitor.
	var after_unplug: Array[Rect2i] = [SHIFTED_SAVED_SCREEN, PRIMARY_USABLE_RECT]
	shifted = WindowGeometry.restore_rect(saved, after_unplug, after_unplug, SECONDARY_SCREEN)
	_expect(shifted.position == OFFSET_FIXTURE, "A same-sized saved index takes priority over matching obsolete desktop coordinates")

	var work_area: Rect2i = SHIFTED_SAVED_SCREEN
	work_area.size.y -= TASKBAR_HEIGHT
	var usable: Array[Rect2i] = [PRIMARY_USABLE_RECT, work_area]
	saved["window_size"] = [SAVED_WINDOW_RECT.size.x, TALL_CLIENT_HEIGHT]
	var clamped: Rect2i = WindowGeometry.restore_rect(saved, screens, usable, 0, DECORATION_FIXTURE)
	_expect(work_area.encloses(clamped) and clamped.size.y < TALL_CLIENT_HEIGHT, "A newly visible taskbar shrinks the restored window on the saved monitor")

func _test_fitting_windows_rect() -> void:
	var display := TestDisplay.new()
	display.backend = "Windows"
	display.decorations = DECORATION_FIXTURE
	var screens: Array[Rect2i] = [PRIMARY_USABLE_RECT]
	display.screens = screens
	display.usable_rects = screens
	var saved := {
		"display_mode": Settings.DISPLAY_WINDOWED,
		"window_size": [TALL_WINDOW_RECT.size.x, TALL_WINDOW_RECT.size.y],
		"window_position": [TALL_WINDOW_RECT.position.x, TALL_WINDOW_RECT.position.y],
		"window_screen": 0,
		"window_screen_size": [PRIMARY_USABLE_RECT.size.x, PRIMARY_USABLE_RECT.size.y],
	}
	_expect(_restore_with_display(saved, display) == TALL_WINDOW_RECT, "Windows restores the exact saved rectangle when its decorations fit")

func _test_main_display_change() -> void:
	var display := TestDisplay.new()
	display.backend = "macOS"
	var before: Array[Rect2i] = [PRIMARY_USABLE_RECT, SHIFTED_SAVED_SCREEN]
	display.screens = before
	display.usable_rects = before
	display.mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.size = SAVED_WINDOW_RECT.size
	display.window_set_position(OFFSET_FIXTURE)
	Settings.save_settings({"display_mode": Settings.DISPLAY_WINDOWED})
	Settings.save_window_geometry(display)
	var saved: Dictionary = Settings.load_settings()
	# The new main display becomes index zero and moves the desktop origin.
	var translated: Rect2i = PRIMARY_USABLE_RECT
	translated.position -= SHIFTED_SAVED_SCREEN.position
	var after: Array[Rect2i] = [PRIMARY_USABLE_RECT, translated]
	display.screens = after
	display.usable_rects = after
	display.active_screen = 0
	_expect(_restore_with_display(saved, display).position == translated.position + OFFSET_FIXTURE, "macOS restores the same monitor after a main-display change swaps equal-sized indices")

func _test_deck_game_mode() -> void:
	var display := TestDisplay.new()
	var screens: Array[Rect2i] = [GAME_MODE_WINDOW_RECT]
	display.screens = screens
	display.usable_rects = screens
	display.mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.size = GAME_MODE_WINDOW_RECT.size
	var desktop: Dictionary = _saved_window_settings()
	Settings.save_settings(desktop)
	var before: Dictionary = Settings.load_settings()
	OS.set_environment("SteamDeck", "1")
	OS.set_environment("XDG_CURRENT_DESKTOP", "gamescope")
	var runtime := SettingsRuntime.new()
	runtime.set("_display", display)
	root.add_child(runtime)
	runtime.set_process(false)
	runtime.flush_window_memory()
	_expect(Settings.load_settings() == before, "Quitting in gamescope preserves the Deck Desktop Mode placement")
	runtime.free()
	Settings.save_settings(before)
	OS.unset_environment("XDG_CURRENT_DESKTOP")
	_expect(not Settings.save_window_geometry(display) and Settings.load_settings() == before, "A Deck handheld without a desktop session cannot save window placement")
	OS.set_environment("XDG_CURRENT_DESKTOP", "KDE")
	OS.set_environment("SteamDeck", "0")

func _test_maximize_flush() -> void:
	var display := TestDisplay.new()
	var screens: Array[Rect2i] = [PRIMARY_USABLE_RECT, SECONDARY_SCREEN_RECT]
	display.screens = screens
	display.usable_rects = screens
	display.mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.size = SAVED_WINDOW_RECT.size
	var runtime := SettingsRuntime.new()
	runtime.set("_display", display)
	root.add_child(runtime)
	runtime.set_process(false)
	Settings.clear_storage()
	runtime._process(0.0)
	display.window_set_position(SAVED_WINDOW_RECT.position)
	runtime._process(0.0)
	var saved_before_maximize: Dictionary = Settings.load_settings()
	_expect(not saved_before_maximize.has("window_size"), "A move within the debounce is still pending")
	display.mode = DisplayServer.WINDOW_MODE_MAXIMIZED
	display.size = SECONDARY_SCREEN_RECT.size
	display.window_set_position(SECONDARY_SCREEN_RECT.position)
	runtime._process(0.0)
	var saved: Dictionary = Settings.load_settings()
	_expect(WindowGeometry.restore_rect(saved, screens, screens, 0) == SAVED_WINDOW_RECT, "Maximizing flushes the pending normal geometry instead of saving maximized bounds")
	runtime.free()

func _test_unfocused_startup() -> void:
	var display := TestDisplay.new()
	display.focused = false
	var runtime := SettingsRuntime.new()
	runtime.set("_display", display)
	root.add_child(runtime)
	runtime.set_process(false)
	var preferences: Dictionary = Settings.default_settings()
	preferences["mute_in_background"] = true
	preferences["master_volume"] = MASTER_FIXTURE_VOLUME
	Settings.apply_audio_settings(preferences)
	var audio: RefCounted = Suspend.for_tree(self)
	_step_fade(audio, Suspend.FADE_OUT_SECONDS)
	var master: int = AudioServer.get_bus_index(Settings.MASTER_BUS)
	_expect(is_zero_approx(AudioServer.get_bus_volume_linear(master)), "Starting unfocused with Mute in background enabled fades without a focus-out notification")
	runtime.free()

func _test_audio_and_panel() -> void:
	var preferences: Dictionary = Settings.default_settings()
	preferences["master_volume"] = MASTER_FIXTURE_VOLUME
	preferences["sfx_volume"] = SFX_FIXTURE_VOLUME
	Settings.save_settings(preferences)
	var panel := SettingsPanelScript.new()
	root.add_child(panel)
	await process_frame
	var controls: Dictionary = panel.get("_controls")
	var mute: OptionButton = controls["mute_in_background"]
	var interface: HSlider = controls["ui_volume"]["slider"]
	_expect(mute.item_count == 2 and mute.get_item_text(0) == "Off" and mute.get_item_text(1) == "On" and mute.selected == 0, "Panel opens with the authored Off and On options")
	_expect((controls["sfx_volume"]["slider"] as HSlider).find_next_valid_focus() == interface and interface.find_next_valid_focus() == mute, "Focus moves from Sound effects through Interface to Mute in background")
	var ui: int = AudioServer.get_bus_index(Settings.UI_SFX_BUS)
	var sfx: int = AudioServer.get_bus_index(Settings.SFX_BUS)
	var world: int = AudioServer.get_bus_index(Settings.WORLD_SFX_BUS)
	var master: int = AudioServer.get_bus_index(Settings.MASTER_BUS)
	var sfx_db: float = AudioServer.get_bus_volume_db(sfx)
	var world_db: float = AudioServer.get_bus_volume_db(world)
	_expect(interface.value == 1.0 and is_zero_approx(AudioServer.get_bus_volume_db(ui)), "Interface starts at unity gain")
	interface.value = UI_FIXTURE_VOLUME
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(ui), UI_FIXTURE_VOLUME), "Interface slider applies to UI SFX")
	_expect(AudioServer.get_bus_send(ui) == Settings.SFX_BUS and is_equal_approx(AudioServer.get_bus_volume_db(sfx), sfx_db) and is_equal_approx(AudioServer.get_bus_volume_db(world), world_db), "Interface uses the existing SFX send and leaves other buses at their set gain")
	interface.value = 0.0
	_expect(AudioServer.is_bus_mute(ui), "0% Interface mutes UI SFX")

	var audio: RefCounted = Suspend.for_tree(self)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME) and audio.get("_fade") == null, "Off leaves audio untouched on focus out")
	mute.item_selected.emit(1)
	_step_fade(audio, Suspend.FADE_OUT_SECONDS * 0.5)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME * 0.5), "Turning On while unfocused starts the suspend fade")
	interface.value = UI_FIXTURE_VOLUME
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME * 0.5), "Reapplying audio settings during fade does not break silence")
	_step_fade(audio, Suspend.FADE_OUT_SECONDS)
	_expect(is_zero_approx(AudioServer.get_bus_volume_linear(master)), "Focus-out fade reaches silence")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_step_fade(audio, Suspend.FADE_IN_SECONDS * 0.5)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME * 0.5), "Focus in starts the existing resume fade")
	_step_fade(audio, Suspend.FADE_IN_SECONDS)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME), "Focus-in restores the master setting")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_step_fade(audio, Suspend.FADE_OUT_SECONDS)
	_expect(is_zero_approx(AudioServer.get_bus_volume_linear(master)), "With On saved, a later focus-out notification also fades to silence")
	audio.handle(panel, Node.NOTIFICATION_APPLICATION_PAUSED)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(is_zero_approx(AudioServer.get_bus_volume_linear(master)), "Focus in keeps the audio silent during application suspend")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_step_fade(audio, Suspend.FADE_IN_SECONDS)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME), "Application resume releases the shared fade after regaining focus")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_step_fade(audio, Suspend.FADE_OUT_SECONDS)
	mute.item_selected.emit(0)
	_step_fade(audio, Suspend.FADE_IN_SECONDS)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(master), MASTER_FIXTURE_VOLUME), "Turning Off while unfocused restores audio")
	var saved: Dictionary = Settings.load_settings()
	_expect(not saved["mute_in_background"] and is_equal_approx(saved["ui_volume"], UI_FIXTURE_VOLUME), "Both settings persist through panel controls")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var external: Dictionary = saved.duplicate(true)
	external["music_volume"] = EXTERNAL_MUSIC_VOLUME
	external["ui_scale"] = LEGACY_SCALE
	Settings.save_settings(external)
	interface.value = 1.0
	var merged: Dictionary = Settings.load_settings()
	_expect(merged["music_volume"] == EXTERNAL_MUSIC_VOLUME and merged["ui_scale"] == LEGACY_SCALE and merged["ui_volume"] == 1.0, "Panel edits merge only the edited preference onto the latest file")
	_expect((controls["music_volume"]["slider"] as HSlider).value == EXTERNAL_MUSIC_VOLUME, "Open panel reflects the merged file after saving")
	var blocked_path: String = ProjectSettings.globalize_path(TEST_STORAGE + ".tmp")
	DirAccess.make_dir_absolute(blocked_path)
	interface.value = UI_FIXTURE_VOLUME
	var status_label: Label = panel.get("_status_label")
	_expect(status_label.text == "Could not save" and is_equal_approx(interface.value, UI_FIXTURE_VOLUME), "A failed write keeps the applied change and displays Could not save")
	panel.open()
	_expect(status_label.text == "Could not save" and is_equal_approx(interface.value, UI_FIXTURE_VOLUME), "Reopening preserves unsaved preferences and the save failure status")
	DirAccess.remove_absolute(blocked_path)
	var music: HSlider = controls["music_volume"]["slider"]
	music.value = MASTER_FIXTURE_VOLUME
	var recovered: Dictionary = Settings.load_settings()
	_expect(is_equal_approx(interface.value, UI_FIXTURE_VOLUME) and is_equal_approx(recovered["ui_volume"], UI_FIXTURE_VOLUME) and is_equal_approx(recovered["music_volume"], MASTER_FIXTURE_VOLUME), "The next successful edit saves both the retained in-memory change and the new edit")
	panel.queue_free()
	await process_frame

func _step_fade(audio: RefCounted, seconds: float) -> void:
	var fade: Tween = audio.get("_fade")
	if fade != null:
		fade.custom_step(seconds)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
