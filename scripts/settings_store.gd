extends RefCounted
class_name SettingsStore

const InputRouterScript = preload("res://scripts/input_router.gd")
const ApplicationSuspend = preload("res://scripts/application_suspend.gd")
const WindowGeometry = preload("res://scripts/settings_window_geometry.gd")

const DEFAULT_STORAGE_PATH: String = "user://settings.json"
const SETTINGS_SCHEMA: int = 1
const RUNTIME_GROUP := &"settings_runtime"
const WINDOWED_APPLIED_META := &"settings_windowed_applied"
const DESKTOP_SESSION_ENV := ["XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION"]

const DISPLAY_FULLSCREEN: String = "fullscreen"
const DISPLAY_WINDOWED: String = "windowed"
const EDGE_SMOOTHING_HIGH: String = "high"
const EDGE_SMOOTHING_LOW: String = "low"
const EDGE_SMOOTHING_OFF: String = "off"
const STEAM_DECK_EDGE_SMOOTHING_DEFAULT: String = EDGE_SMOOTHING_OFF
const EDGE_SMOOTHING_VIEWPORT_GROUP: StringName = &"settings_edge_smoothing_viewports"
const DIALOGUE_STANDARD: String = "standard"
const DIALOGUE_FAST: String = "fast"
const DIALOGUE_INSTANT: String = "instant"
const BOARD_HEALTH_ALWAYS: String = "always"
const BOARD_HEALTH_CONTEXTUAL: String = "on_hover_and_aim"
const DEFAULT_BOARD_HEALTH_BARS: String = BOARD_HEALTH_CONTEXTUAL
const BOARD_HEALTH_GROUP: StringName = &"board_health_settings"
static var _applied_board_health_bars: String = DEFAULT_BOARD_HEALTH_BARS

const COMBAT_NORMAL: String = "normal"
const COMBAT_FAST: String = "fast"
const COMBAT_FASTEST: String = "fastest"

const MASTER_BUS: String = "Master"
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const WORLD_SFX_BUS: String = "World SFX"
const UI_SFX_BUS: String = "UI SFX"
const SILENT_VOLUME_LINEAR: float = 0.0001
const SFX_HEADROOM_DB: float = -3.0

# A restrained, dark chamber response: enough tail to place attacks in the
# labyrinth without softening their transient timing or turning rapid combat
# into a wash.
const WORLD_REVERB_ROOM_SIZE: float = 0.50
const WORLD_REVERB_DAMPING: float = 0.72
const WORLD_REVERB_SPREAD: float = 0.78
const WORLD_REVERB_HIPASS: float = 0.20
const WORLD_REVERB_DRY: float = 1.0
const WORLD_REVERB_WET: float = 0.08
const WORLD_REVERB_PREDELAY_MSEC: float = 24.0
const WORLD_REVERB_PREDELAY_FEEDBACK: float = 0.08

# Music shares the short chamber character, but its sustained material needs a
# lighter, darker return so the mastered score remains forward and intelligible.
const MUSIC_REVERB_ROOM_SIZE: float = 0.50
const MUSIC_REVERB_DAMPING: float = 0.78
const MUSIC_REVERB_SPREAD: float = 0.80
const MUSIC_REVERB_HIPASS: float = 0.30
const MUSIC_REVERB_DRY: float = 1.0
const MUSIC_REVERB_WET: float = 0.04
const MUSIC_REVERB_PREDELAY_MSEC: float = 28.0
const MUSIC_REVERB_PREDELAY_FEEDBACK: float = 0.04

# Mastering chain. A slow, gentle compressor glues stacked hits, card cues and
# UI ticks into one consistent SFX layer; a transparent brick-wall limiter on
# Master keeps simultaneous impacts from ever clipping the output.
const SFX_GLUE_THRESHOLD_DB: float = -16.0
const SFX_GLUE_RATIO: float = 2.5
const SFX_GLUE_ATTACK_US: float = 6000.0
const SFX_GLUE_RELEASE_MS: float = 140.0
# No makeup gain: owner-auditioned cue levels stay where they were set.
const SFX_GLUE_GAIN_DB: float = 0.0
const MASTER_LIMITER_CEILING_DB: float = -0.8
const MASTER_LIMITER_RELEASE_S: float = 0.12
# A neutral gain stage on the Music bus lets stingers dip the score under them
# without touching the player's volume setting or the score's own fades.
const MUSIC_DUCK_EFFECT_NAME: String = "MusicDuck"

const STANDARD_DIALOGUE_CHARACTERS_PER_SECOND: float = 34.0
const FAST_DIALOGUE_CHARACTERS_PER_SECOND: float = 92.0
const SUPPORTED_UI_SCALES := [0.90, 1.00, 1.15, 1.25]

static var _storage_path: String = DEFAULT_STORAGE_PATH
static var _pending_preferences: Dictionary = {}
# Runtime preference belongs to apply_settings, not disk persistence. Shared
# decorative controls can check it without polling user:// during rendering.
static var _applied_reduced_motion: bool = false

static func set_storage_path(path: String) -> void:
	var resolved: String = path if not path.is_empty() else DEFAULT_STORAGE_PATH
	if _storage_path != resolved:
		_pending_preferences.clear()
		_storage_path = resolved

static func storage_path() -> String:
	return _storage_path

static func default_settings() -> Dictionary:
	return {
		"settings_schema": SETTINGS_SCHEMA,
		"master_volume": 0.80,
		"music_volume": 0.70,
		"sfx_volume": 0.80,
		"ui_volume": 1.0,
		"mute_in_background": false,
		"display_mode": DISPLAY_FULLSCREEN,
		"ui_scale": default_ui_scale(),
		"edge_smoothing": default_edge_smoothing(),
		"dialogue_speed": DIALOGUE_STANDARD,
		"combat_speed": COMBAT_NORMAL,
		"hero_facing": "persist",
		"board_health_bars": DEFAULT_BOARD_HEALTH_BARS,
		"reduced_motion": false,
		"controller_vibration": true
	}

static func default_ui_scale(deck_platform: bool = InputRouterScript.platform_is_steam_deck()) -> float:
	return 1.15 if deck_platform else 1.00

static func default_edge_smoothing() -> String:
	return STEAM_DECK_EDGE_SMOOTHING_DEFAULT if OS.get_environment("SteamDeck") == "1" else EDGE_SMOOTHING_HIGH

static func normalize_settings(data: Variant) -> Dictionary:
	var normalized: Dictionary = default_settings()
	if typeof(data) != TYPE_DICTIONARY:
		return normalized
	var source: Dictionary = data
	for key: String in ["master_volume", "music_volume", "sfx_volume", "ui_volume"]:
		normalized[key] = clampf(_number_or_default(source.get(key), float(normalized[key])), 0.0, 1.0)
	normalized["mute_in_background"] = _bool_or_default(source.get("mute_in_background"), false)
	var mode: String = str(source.get("display_mode", normalized["display_mode"]))
	if mode in [DISPLAY_FULLSCREEN, DISPLAY_WINDOWED]:
		normalized["display_mode"] = mode
	normalized["ui_scale"] = nearest_supported_ui_scale(_number_or_default(source.get("ui_scale"), float(normalized["ui_scale"])))
	var smoothing: String = str(source.get("edge_smoothing", normalized["edge_smoothing"]))
	if smoothing in [EDGE_SMOOTHING_HIGH, EDGE_SMOOTHING_LOW, EDGE_SMOOTHING_OFF]:
		normalized["edge_smoothing"] = smoothing
	normalized.merge(_normalize_window_geometry(source))
	var dialogue_speed: String = str(source.get("dialogue_speed", normalized["dialogue_speed"]))
	if dialogue_speed not in [DIALOGUE_STANDARD, DIALOGUE_FAST, DIALOGUE_INSTANT]:
		dialogue_speed = str(normalized["dialogue_speed"])
	normalized["dialogue_speed"] = dialogue_speed
	var combat_speed: String = str(source.get("combat_speed", COMBAT_NORMAL))
	normalized["combat_speed"] = combat_speed if combat_speed in [COMBAT_NORMAL, COMBAT_FAST, COMBAT_FASTEST] else COMBAT_NORMAL
	normalized["reduced_motion"] = _bool_or_default(source.get("reduced_motion"), false)
	normalized["controller_vibration"] = controller_vibration_enabled(source)
	var hero_facing: String = str(source.get("hero_facing", "persist"))
	normalized["hero_facing"] = hero_facing if hero_facing in ["persist", "snap"] else "persist"
	var board_health: String = str(source.get("board_health_bars", DEFAULT_BOARD_HEALTH_BARS))
	normalized["board_health_bars"] = board_health if board_health in [BOARD_HEALTH_ALWAYS, BOARD_HEALTH_CONTEXTUAL] else DEFAULT_BOARD_HEALTH_BARS
	normalized["settings_schema"] = SETTINGS_SCHEMA
	return normalized

static func _normalize_window_geometry(source: Dictionary) -> Dictionary:
	var size: Variant = source.get("window_size")
	var position: Variant = source.get("window_position")
	var screen: Variant = source.get("window_screen")
	var screen_size: Variant = source.get("window_screen_size")
	if not _is_window_vector(size, 2) or not _is_window_vector(position, 2) or not _is_window_integer(screen):
		return {}
	if screen_size == null:
		# Earlier geometry records stored absolute coordinates and a full screen rect.
		var legacy_rect: Variant = source.get("window_screen_rect")
		if not _is_window_vector(legacy_rect, 4):
			return {}
		position = [int(position[0]) - int(legacy_rect[0]), int(position[1]) - int(legacy_rect[1])]
		screen_size = [legacy_rect[2], legacy_rect[3]]
	if not _is_window_vector(position, 2) or not _is_window_vector(screen_size, 2):
		return {}
	if size[0] <= 0 or size[1] <= 0 or screen < 0 or screen_size[0] <= 0 or screen_size[1] <= 0:
		return {}
	var geometry := {
		"window_size": [int(size[0]), int(size[1])],
		"window_position": [int(position[0]), int(position[1])],
		"window_screen": int(screen),
		"window_screen_size": [int(screen_size[0]), int(screen_size[1])],
	}

	var neighbors: Variant = source.get("window_screen_neighbors")
	if neighbors is Array:
		var valid_neighbors: Array = []
		for rect: Variant in neighbors:
			if _is_window_vector(rect, 4) and rect[2] > 0 and rect[3] > 0:
				valid_neighbors.append([int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])])
		geometry["window_screen_neighbors"] = valid_neighbors
	return geometry

static func _is_window_vector(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for component: Variant in value:
		if not _is_window_integer(component):
			return false
	return true

static func _is_window_integer(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and number >= -2147483648.0 and number <= 2147483647.0

static func load_settings() -> Dictionary:
	var settings: Dictionary = _read_settings()
	settings.merge(_pending_preferences, true)
	return settings

static func _read_settings() -> Dictionary:
	if not FileAccess.file_exists(_storage_path):
		return default_settings()
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.READ)
	if file == null:
		return default_settings()
	var contents: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(contents) != OK:
		return default_settings()
	return normalize_settings(json.data)

static func has_unsaved_preferences() -> bool:
	return not _pending_preferences.is_empty()

static func save_preferences(settings: Dictionary) -> bool:
	if save_settings(settings):
		return true
	# Geometry can still change independently while a preference save is blocked.
	var normalized: Dictionary = normalize_settings(settings)
	for key: String in default_settings():
		_pending_preferences[key] = normalized[key]
	return false

static func save_settings(settings: Dictionary) -> bool:
	var normalized: Dictionary = normalize_settings(settings)
	var payload: String = JSON.stringify(normalized, "\t")
	var temp_path: String = "%s.tmp" % _storage_path
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	# Validate before replacing the live file. An interrupted temp file is never
	# loaded; malformed live settings retain the existing defaults fallback.
	var written: String = FileAccess.get_file_as_string(temp_path)
	if write_error != OK or written != payload or typeof(JSON.parse_string(written)) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	# Same-directory rename replaces the destination without exposing a partial
	# settings file or a gap where an existing valid profile is missing.
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(_storage_path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	_pending_preferences.clear()
	return true

static func clear_storage() -> void:
	_pending_preferences.clear()
	for path: String in [_storage_path, "%s.tmp" % _storage_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func restore_defaults(window: Window = null) -> Dictionary:
	var previous: Dictionary = load_settings()
	var settings: Dictionary = default_settings()
	settings.merge(_normalize_window_geometry(previous))
	save_preferences(settings)
	apply_settings(settings, window)
	return settings

static func apply_settings(settings: Dictionary, window: Window = null, apply_display_mode: bool = true) -> Dictionary:
	var normalized: Dictionary = normalize_settings(settings)
	_applied_reduced_motion = bool(normalized["reduced_motion"])
	_applied_board_health_bars = str(normalized["board_health_bars"])
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for board: Node in tree.get_nodes_in_group(BOARD_HEALTH_GROUP):
			board.call("refresh_plate_visibility")
	apply_audio_settings(normalized)
	_apply_edge_smoothing(str(normalized["edge_smoothing"]))
	if window != null:
		window.content_scale_factor = float(normalized["ui_scale"])
		if apply_display_mode:
			_apply_display_mode(normalized, window)
	return normalized

static func inherit_edge_smoothing(viewport: SubViewport, source: Viewport) -> void:
	# Only these caches follow the scene viewport. Pixel FX deliberately retain
	# their own disabled MSAA and never join this group.
	viewport.msaa_2d = source.msaa_2d
	viewport.add_to_group(EDGE_SMOOTHING_VIEWPORT_GROUP)

static func _apply_edge_smoothing(value: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var samples: Viewport.MSAA = Viewport.MSAA_4X
	match value:
		EDGE_SMOOTHING_LOW: samples = Viewport.MSAA_2X
		EDGE_SMOOTHING_OFF: samples = Viewport.MSAA_DISABLED
	tree.root.msaa_2d = samples
	for node: Node in tree.get_nodes_in_group(EDGE_SMOOTHING_VIEWPORT_GROUP):
		var viewport := node as SubViewport
		if viewport == null or viewport.msaa_2d == samples:
			continue
		viewport.msaa_2d = samples
		# Both caches retain a raster with updates disabled. Re-render their
		# retained commands so the new edge quality is visible this frame.
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

static func ensure_audio_buses() -> void:
	for bus_name: String in [MUSIC_BUS, SFX_BUS, WORLD_SFX_BUS, UI_SFX_BUS]:
		_ensure_audio_bus(bus_name)
	_route_audio_bus(WORLD_SFX_BUS, SFX_BUS)
	_route_audio_bus(UI_SFX_BUS, SFX_BUS)
	_ensure_world_sfx_reverb()
	_ensure_music_reverb()
	_ensure_sfx_glue_compressor()
	_ensure_master_limiter()
	_ensure_music_duck()

static func music_duck_effect() -> AudioEffectAmplify:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0:
		return null
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectAmplify and effect.resource_name == MUSIC_DUCK_EFFECT_NAME:
			return effect as AudioEffectAmplify
	return null

static func _ensure_music_duck() -> void:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0 or music_duck_effect() != null:
		return
	var amplify := AudioEffectAmplify.new()
	amplify.resource_name = MUSIC_DUCK_EFFECT_NAME
	amplify.volume_db = 0.0
	AudioServer.add_bus_effect(bus_index, amplify, 0)

static func _ensure_sfx_glue_compressor() -> void:
	var bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	if bus_index < 0:
		return
	var compressor: AudioEffectCompressor = _find_bus_effect(bus_index, "AudioEffectCompressor") as AudioEffectCompressor
	if compressor == null:
		compressor = AudioEffectCompressor.new()
		AudioServer.add_bus_effect(bus_index, compressor)
	compressor.threshold = SFX_GLUE_THRESHOLD_DB
	compressor.ratio = SFX_GLUE_RATIO
	compressor.attack_us = SFX_GLUE_ATTACK_US
	compressor.release_ms = SFX_GLUE_RELEASE_MS
	compressor.gain = SFX_GLUE_GAIN_DB
	compressor.mix = 1.0

static func _ensure_master_limiter() -> void:
	var bus_index: int = AudioServer.get_bus_index(MASTER_BUS)
	if bus_index < 0:
		return
	var limiter: AudioEffectHardLimiter = _find_bus_effect(bus_index, "AudioEffectHardLimiter") as AudioEffectHardLimiter
	if limiter == null:
		limiter = AudioEffectHardLimiter.new()
		AudioServer.add_bus_effect(bus_index, limiter)
	limiter.ceiling_db = MASTER_LIMITER_CEILING_DB
	limiter.pre_gain_db = 0.0
	limiter.release = MASTER_LIMITER_RELEASE_S

static func _find_bus_effect(bus_index: int, effect_class: String) -> AudioEffect:
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if effect != null and effect.is_class(effect_class):
			return effect
	return null

static func apply_audio_settings(settings: Dictionary) -> void:
	var normalized: Dictionary = normalize_settings(settings)
	ensure_audio_buses()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var master: int = AudioServer.get_bus_index(MASTER_BUS)
		var master_volume: float = float(normalized["master_volume"])
		AudioServer.set_bus_mute(master, master_volume <= SILENT_VOLUME_LINEAR)
		ApplicationSuspend.for_tree(tree).apply_audio_settings(tree.root, maxf(master_volume, SILENT_VOLUME_LINEAR), bool(normalized["mute_in_background"]))
	else:
		_apply_bus_volume(MASTER_BUS, float(normalized["master_volume"]))
	_apply_bus_volume(MUSIC_BUS, float(normalized["music_volume"]))
	_apply_bus_volume(SFX_BUS, float(normalized["sfx_volume"]), SFX_HEADROOM_DB)
	_apply_bus_volume(UI_SFX_BUS, float(normalized["ui_volume"]))

static func audio_route_is_audible(bus: StringName, gain_db: float) -> bool:
	var index: int = AudioServer.get_bus_index(bus)
	while index >= 0:
		if AudioServer.is_bus_mute(index):
			return false
		gain_db += AudioServer.get_bus_volume_db(index)
		if index == 0:
			return db_to_linear(gain_db) > SILENT_VOLUME_LINEAR
		# Godot sends only to earlier buses. An invalid send goes to Master.
		var send: int = AudioServer.get_bus_index(AudioServer.get_bus_send(index))
		index = send if send >= 0 and send < index else 0
	return false

static func nearest_supported_ui_scale(value: float) -> float:
	var nearest: float = float(SUPPORTED_UI_SCALES[0])
	var nearest_distance: float = absf(value - nearest)
	for scale_var: Variant in SUPPORTED_UI_SCALES:
		var scale: float = float(scale_var)
		var distance: float = absf(value - scale)
		if distance < nearest_distance:
			nearest = scale
			nearest_distance = distance
	return nearest

static func dialogue_characters_per_second(settings: Dictionary) -> float:
	match str(normalize_settings(settings)["dialogue_speed"]):
		DIALOGUE_FAST:
			return FAST_DIALOGUE_CHARACTERS_PER_SECOND
		DIALOGUE_INSTANT:
			return INF
		_:
			return STANDARD_DIALOGUE_CHARACTERS_PER_SECOND

static func combat_speed_scale(settings: Dictionary) -> float:
	match str(settings.get("combat_speed", COMBAT_NORMAL)):
		COMBAT_FAST:
			return 1.5
		COMBAT_FASTEST:
			return 2.0
		_:
			return 1.0

static func dialogue_is_instant(settings: Dictionary) -> bool:
	return str(normalize_settings(settings)["dialogue_speed"]) == DIALOGUE_INSTANT

static func applied_reduced_motion_enabled() -> bool:
	return _applied_reduced_motion

static func reduced_motion_enabled(settings: Dictionary) -> bool:
	return bool(normalize_settings(settings)["reduced_motion"])

static func controller_vibration_enabled(settings: Dictionary) -> bool:
	return _bool_or_default(settings.get("controller_vibration"), true)

static func motion_duration(seconds: float, settings: Dictionary) -> float:
	return 0.0 if reduced_motion_enabled(settings) else maxf(0.0, seconds)

static func safe_windowed_size(requested: Vector2i, usable_screen_size: Vector2i) -> Vector2i:
	return WindowGeometry.safe_windowed_size(requested, usable_screen_size)

static func _apply_display_mode(settings: Dictionary, window: Window, display: Object = DisplayServer) -> void:
	if display.get_name() == "headless" or OS.has_environment("LABYRINTH_PROBE_WINDOW"):
		return
	var mode: int = display.window_get_mode()
	if settings["display_mode"] == DISPLAY_FULLSCREEN:
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			if window.has_meta(WINDOWED_APPLIED_META):
				if window.is_inside_tree():
					window.get_tree().call_group(RUNTIME_GROUP, "flush_window_memory")
				else:
					save_window_geometry(display)
			display.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		window.remove_meta(WINDOWED_APPLIED_META)
		return
	if window.has_meta(WINDOWED_APPLIED_META) and mode in [
		DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_MINIMIZED
	]:
		return
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		display.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if WindowGeometry.restore_native_window(settings, display):
		window.set_meta(WINDOWED_APPLIED_META, true)

static func tracks_window_geometry(display: Object = DisplayServer) -> bool:
	return (
		display.get_name() != "headless"
		and not OS.has_environment("LABYRINTH_PROBE_WINDOW")
		and display.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	)

static func window_geometry_saves_allowed() -> bool:
	if not OS.get_environment("GAMESCOPE_WAYLAND_DISPLAY").strip_edges().is_empty():
		return false
	var has_desktop_session: bool = false
	for key: String in DESKTOP_SESSION_ENV:
		var session: String = OS.get_environment(key).strip_edges().to_lower()
		if "gamescope" in session:
			return false
		has_desktop_session = has_desktop_session or not session.is_empty()
	return has_desktop_session or not InputRouterScript.platform_is_steam_deck()

static func window_geometry_snapshot(display: Object = DisplayServer) -> Dictionary:
	if not tracks_window_geometry(display) or not window_geometry_saves_allowed():
		return {}
	var screen: int = display.window_get_current_screen()
	var screens: Array[Rect2i] = WindowGeometry.screen_rects(display)
	if screen < 0 or screen >= screens.size():
		return {}
	var screen_rect: Rect2i = screens[screen]
	var size: Vector2i = display.window_get_size()
	if not screen_rect.has_area() or size.x <= 0 or size.y <= 0:
		return {}
	var position: Vector2i = display.window_get_position() - screen_rect.position
	return {
		"window_size": [size.x, size.y],
		"window_position": [position.x, position.y],
		"window_screen": screen,
		"window_screen_size": [screen_rect.size.x, screen_rect.size.y],
		"window_screen_neighbors": WindowGeometry.screen_neighbors(screens, screen),
	}

static func save_window_geometry(display: Object = DisplayServer) -> bool:
	return save_window_geometry_snapshot(window_geometry_snapshot(display))

static func save_window_geometry_snapshot(geometry: Dictionary) -> bool:
	if geometry.is_empty() or not window_geometry_saves_allowed():
		return false
	var settings: Dictionary = load_settings()
	if _normalize_window_geometry(settings) == geometry:
		return true
	settings.merge(geometry, true)
	return save_settings(settings)

static func _apply_bus_volume(bus_name: String, volume: float, headroom_db: float = 0.0) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped: float = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped <= SILENT_VOLUME_LINEAR)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clamped, SILENT_VOLUME_LINEAR)) + headroom_db)

static func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

static func _route_audio_bus(bus_name: String, destination_bus: String) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.get_bus_index(destination_bus) < 0:
		return
	if AudioServer.get_bus_send(bus_index) != destination_bus:
		AudioServer.set_bus_send(bus_index, destination_bus)

static func _ensure_world_sfx_reverb() -> void:
	_ensure_reverb(
		WORLD_SFX_BUS,
		WORLD_REVERB_ROOM_SIZE,
		WORLD_REVERB_DAMPING,
		WORLD_REVERB_SPREAD,
		WORLD_REVERB_HIPASS,
		WORLD_REVERB_DRY,
		WORLD_REVERB_WET,
		WORLD_REVERB_PREDELAY_MSEC,
		WORLD_REVERB_PREDELAY_FEEDBACK
	)

static func _ensure_music_reverb() -> void:
	_ensure_reverb(
		MUSIC_BUS,
		MUSIC_REVERB_ROOM_SIZE,
		MUSIC_REVERB_DAMPING,
		MUSIC_REVERB_SPREAD,
		MUSIC_REVERB_HIPASS,
		MUSIC_REVERB_DRY,
		MUSIC_REVERB_WET,
		MUSIC_REVERB_PREDELAY_MSEC,
		MUSIC_REVERB_PREDELAY_FEEDBACK
	)

static func _ensure_reverb(
	bus_name: String,
	room_size: float,
	damping: float,
	spread: float,
	hipass: float,
	dry: float,
	wet: float,
	predelay_msec: float,
	predelay_feedback: float
) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var reverb: AudioEffectReverb
	var reverb_index: int = -1
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectReverb:
			reverb = effect as AudioEffectReverb
			reverb_index = effect_index
			break
	if reverb == null:
		reverb = AudioEffectReverb.new()
		AudioServer.add_bus_effect(bus_index, reverb)
		reverb_index = AudioServer.get_bus_effect_count(bus_index) - 1
	reverb.room_size = room_size
	reverb.damping = damping
	reverb.spread = spread
	reverb.hipass = hipass
	reverb.dry = dry
	reverb.wet = wet
	reverb.predelay_msec = predelay_msec
	reverb.predelay_feedback = predelay_feedback
	AudioServer.set_bus_effect_enabled(bus_index, reverb_index, true)

static func _number_or_default(value: Variant, fallback: float) -> float:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return float(value)
	return fallback

static func _bool_or_default(value: Variant, fallback: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback

static func hero_facing_mode(settings: Dictionary) -> String:
	# Hidden A/B launch override; it never adds a control to Options.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--hero-facing" and args[index + 1] in ["persist", "snap"]: return args[index + 1]
	return str(settings.get("hero_facing", "persist"))
