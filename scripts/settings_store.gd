extends RefCounted
class_name SettingsStore

const InputRouterScript = preload("res://scripts/input_router.gd")

const DEFAULT_STORAGE_PATH: String = "user://settings.json"
const SETTINGS_SCHEMA: int = 1

const DISPLAY_FULLSCREEN: String = "fullscreen"
const DISPLAY_WINDOWED: String = "windowed"
const DIALOGUE_STANDARD: String = "standard"
const DIALOGUE_FAST: String = "fast"
const DIALOGUE_INSTANT: String = "instant"

const MASTER_BUS: String = "Master"
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const WORLD_SFX_BUS: String = "World SFX"
const UI_SFX_BUS: String = "UI SFX"
const SFX_HEADROOM_DB: float = -3.0

# A restrained, dark chamber response: enough tail to place attacks in the
# labyrinth without softening their transient timing or turning rapid combat
# into a wash.
const WORLD_REVERB_ROOM_SIZE: float = 0.62
const WORLD_REVERB_DAMPING: float = 0.72
const WORLD_REVERB_SPREAD: float = 0.78
const WORLD_REVERB_HIPASS: float = 0.20
const WORLD_REVERB_DRY: float = 1.0
const WORLD_REVERB_WET: float = 0.13
const WORLD_REVERB_PREDELAY_MSEC: float = 24.0
const WORLD_REVERB_PREDELAY_FEEDBACK: float = 0.08

const STANDARD_DIALOGUE_CHARACTERS_PER_SECOND: float = 34.0
const FAST_DIALOGUE_CHARACTERS_PER_SECOND: float = 92.0
const SUPPORTED_UI_SCALES := [0.90, 1.00, 1.15, 1.25]
const DEFAULT_WINDOWED_SIZE := Vector2i(1600, 900)
const MINIMUM_WINDOWED_SIZE := Vector2i(960, 540)
const WINDOW_SCREEN_MARGIN := Vector2i(64, 64)

static var _storage_path: String = DEFAULT_STORAGE_PATH

static func set_storage_path(path: String) -> void:
	_storage_path = path if not path.is_empty() else DEFAULT_STORAGE_PATH

static func storage_path() -> String:
	return _storage_path

static func default_settings() -> Dictionary:
	return {
		"settings_schema": SETTINGS_SCHEMA,
		"master_volume": 0.80,
		"music_volume": 0.70,
		"sfx_volume": 0.80,
		"display_mode": DISPLAY_FULLSCREEN,
		"ui_scale": default_ui_scale(),
		"dialogue_speed": DIALOGUE_STANDARD,
		"reduced_motion": false
	}

static func default_ui_scale(deck_platform: bool = InputRouterScript.platform_is_steam_deck()) -> float:
	return 1.15 if deck_platform else 1.00

static func normalize_settings(data: Variant) -> Dictionary:
	var defaults: Dictionary = default_settings()
	if typeof(data) != TYPE_DICTIONARY:
		return defaults
	var source: Dictionary = data
	var normalized: Dictionary = defaults.duplicate(true)
	normalized["master_volume"] = clampf(_number_or_default(source.get("master_volume"), float(defaults["master_volume"])), 0.0, 1.0)
	normalized["music_volume"] = clampf(_number_or_default(source.get("music_volume"), float(defaults["music_volume"])), 0.0, 1.0)
	normalized["sfx_volume"] = clampf(_number_or_default(source.get("sfx_volume"), float(defaults["sfx_volume"])), 0.0, 1.0)
	var display_mode: String = str(source.get("display_mode", defaults["display_mode"]))
	if display_mode not in [DISPLAY_FULLSCREEN, DISPLAY_WINDOWED]:
		display_mode = str(defaults["display_mode"])
	normalized["display_mode"] = display_mode
	normalized["ui_scale"] = nearest_supported_ui_scale(_number_or_default(source.get("ui_scale"), float(defaults["ui_scale"])))
	var dialogue_speed: String = str(source.get("dialogue_speed", defaults["dialogue_speed"]))
	if dialogue_speed not in [DIALOGUE_STANDARD, DIALOGUE_FAST, DIALOGUE_INSTANT]:
		dialogue_speed = str(defaults["dialogue_speed"])
	normalized["dialogue_speed"] = dialogue_speed
	normalized["reduced_motion"] = _bool_or_default(source.get("reduced_motion"), bool(defaults["reduced_motion"]))
	normalized["settings_schema"] = SETTINGS_SCHEMA
	return normalized

static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(_storage_path):
		return default_settings()
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.READ)
	if file == null:
		return default_settings()
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return default_settings()
	return normalize_settings(json.data)

static func save_settings(settings: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalize_settings(settings), "\t"))
	return true

static func clear_storage() -> void:
	if FileAccess.file_exists(_storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_storage_path))

static func restore_defaults(window: Window = null) -> Dictionary:
	var settings: Dictionary = default_settings()
	save_settings(settings)
	apply_settings(settings, window)
	return settings

static func apply_settings(settings: Dictionary, window: Window = null, apply_display_mode: bool = true) -> Dictionary:
	var normalized: Dictionary = normalize_settings(settings)
	apply_audio_settings(normalized)
	if window != null:
		window.content_scale_factor = float(normalized["ui_scale"])
		if apply_display_mode:
			_apply_display_mode(str(normalized["display_mode"]))
	return normalized

static func ensure_audio_buses() -> void:
	for bus_name: String in [MUSIC_BUS, SFX_BUS, WORLD_SFX_BUS, UI_SFX_BUS]:
		_ensure_audio_bus(bus_name)
	_route_audio_bus(WORLD_SFX_BUS, SFX_BUS)
	_route_audio_bus(UI_SFX_BUS, SFX_BUS)
	_ensure_world_sfx_reverb()

static func apply_audio_settings(settings: Dictionary) -> void:
	var normalized: Dictionary = normalize_settings(settings)
	ensure_audio_buses()
	_apply_bus_volume(MASTER_BUS, float(normalized["master_volume"]))
	_apply_bus_volume(MUSIC_BUS, float(normalized["music_volume"]))
	_apply_bus_volume(SFX_BUS, float(normalized["sfx_volume"]), SFX_HEADROOM_DB)

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

static func dialogue_is_instant(settings: Dictionary) -> bool:
	return str(normalize_settings(settings)["dialogue_speed"]) == DIALOGUE_INSTANT

static func reduced_motion_enabled(settings: Dictionary) -> bool:
	return bool(normalize_settings(settings)["reduced_motion"])

static func motion_duration(seconds: float, settings: Dictionary) -> float:
	return 0.0 if reduced_motion_enabled(settings) else maxf(0.0, seconds)

static func safe_windowed_size(requested: Vector2i, usable_screen_size: Vector2i) -> Vector2i:
	var bounded_usable := Vector2i(maxi(1, usable_screen_size.x), maxi(1, usable_screen_size.y))
	var margin := Vector2i(
		mini(WINDOW_SCREEN_MARGIN.x, maxi(0, bounded_usable.x - 640)),
		mini(WINDOW_SCREEN_MARGIN.y, maxi(0, bounded_usable.y - 360))
	)
	var maximum := Vector2i(
		bounded_usable.x - margin.x,
		bounded_usable.y - margin.y
	)
	var minimum := Vector2i(
		mini(MINIMUM_WINDOWED_SIZE.x, maximum.x),
		mini(MINIMUM_WINDOWED_SIZE.y, maximum.y)
	)
	var candidate: Vector2i = requested if requested.x > 0 and requested.y > 0 else DEFAULT_WINDOWED_SIZE
	return Vector2i(
		clampi(candidate.x, minimum.x, maximum.x),
		clampi(candidate.y, minimum.y, maximum.y)
	)

static func _apply_display_mode(display_mode: String) -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	var current_mode: int = DisplayServer.window_get_mode()
	if display_mode == DISPLAY_FULLSCREEN:
		if current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var requested_size: Vector2i = DisplayServer.window_get_size() if current_mode == DisplayServer.WINDOW_MODE_WINDOWED else DEFAULT_WINDOWED_SIZE
	if current_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var safe_size: Vector2i = safe_windowed_size(requested_size, usable_rect.size)
	DisplayServer.window_set_size(safe_size)
	DisplayServer.window_set_position(usable_rect.position + (usable_rect.size - safe_size) / 2)

static func _apply_bus_volume(bus_name: String, volume: float, headroom_db: float = 0.0) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped: float = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped <= 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clamped, 0.0001)) + headroom_db)

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
	var bus_index: int = AudioServer.get_bus_index(WORLD_SFX_BUS)
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
	reverb.room_size = WORLD_REVERB_ROOM_SIZE
	reverb.damping = WORLD_REVERB_DAMPING
	reverb.spread = WORLD_REVERB_SPREAD
	reverb.hipass = WORLD_REVERB_HIPASS
	reverb.dry = WORLD_REVERB_DRY
	reverb.wet = WORLD_REVERB_WET
	reverb.predelay_msec = WORLD_REVERB_PREDELAY_MSEC
	reverb.predelay_feedback = WORLD_REVERB_PREDELAY_FEEDBACK
	AudioServer.set_bus_effect_enabled(bus_index, reverb_index, true)

static func _number_or_default(value: Variant, fallback: float) -> float:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return float(value)
	return fallback

static func _bool_or_default(value: Variant, fallback: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback
