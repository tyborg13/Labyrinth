extends RefCounted

const SettingsStore = preload("res://scripts/settings_store.gd")
const CursorFeedbackScript = preload("res://scripts/cursor_feedback.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	SettingsStore.ensure_audio_buses()
	var world_index: int = AudioServer.get_bus_index(SettingsStore.WORLD_SFX_BUS)
	var ui_index: int = AudioServer.get_bus_index(SettingsStore.UI_SFX_BUS)
	var music_index: int = AudioServer.get_bus_index(SettingsStore.MUSIC_BUS)
	expect.call(world_index >= 0, "Audio routing should provision the World SFX bus")
	expect.call(ui_index >= 0, "Audio routing should provision the UI SFX bus")
	expect.call(music_index >= 0, "Audio routing should preserve the Music bus")
	if world_index < 0 or ui_index < 0 or music_index < 0:
		return

	expect.call(AudioServer.get_bus_send(world_index) == SettingsStore.SFX_BUS, "World SFX should inherit the player SFX volume through the SFX bus")
	expect.call(AudioServer.get_bus_send(ui_index) == SettingsStore.SFX_BUS, "UI SFX should inherit the player SFX volume through the SFX bus")
	expect.call(_reverb_count(world_index) == 1, "World SFX should contain exactly one room reverb")
	expect.call(_reverb_count(ui_index) == 0, "UI SFX should remain free of room reverb")
	expect.call(_reverb_count(music_index) == 0, "Music should remain free of runtime room reverb in this pass")
	var sfx_index: int = AudioServer.get_bus_index(SettingsStore.SFX_BUS)
	var quiet_settings: Dictionary = SettingsStore.default_settings()
	quiet_settings["sfx_volume"] = 0.42
	SettingsStore.apply_audio_settings(quiet_settings)
	var expected_sfx_db: float = linear_to_db(0.42) + SettingsStore.SFX_HEADROOM_DB
	expect.call(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), expected_sfx_db), "The shared SFX parent should keep applying player volume and mix headroom to both child paths")
	var muted_settings: Dictionary = quiet_settings.duplicate(true)
	muted_settings["sfx_volume"] = 0.0
	SettingsStore.apply_audio_settings(muted_settings)
	expect.call(AudioServer.is_bus_mute(sfx_index), "Muting SFX should silence both world and UI child paths at their shared parent")
	SettingsStore.apply_audio_settings(SettingsStore.default_settings())

	var reverb_index: int = _reverb_index(world_index)
	if reverb_index >= 0:
		var reverb := AudioServer.get_bus_effect(world_index, reverb_index) as AudioEffectReverb
		expect.call(AudioServer.is_bus_effect_enabled(world_index, reverb_index), "World room reverb should be enabled")
		expect.call(is_equal_approx(reverb.dry, SettingsStore.WORLD_REVERB_DRY), "World room reverb should retain the full direct signal")
		expect.call(is_equal_approx(reverb.wet, SettingsStore.WORLD_REVERB_WET), "World room reverb should use the restrained wet mix")
		expect.call(reverb.wet <= 0.15, "World room reverb should stay below an overtly wet combat mix")
		expect.call(is_equal_approx(reverb.predelay_msec, SettingsStore.WORLD_REVERB_PREDELAY_MSEC), "World room reverb should preserve transient clarity with short pre-delay")
		expect.call(is_equal_approx(reverb.room_size, SettingsStore.WORLD_REVERB_ROOM_SIZE), "World room reverb should use the authored chamber size")
		expect.call(is_equal_approx(reverb.damping, SettingsStore.WORLD_REVERB_DAMPING), "World room reverb should use the authored dark damping")
		expect.call(is_equal_approx(reverb.hipass, SettingsStore.WORLD_REVERB_HIPASS), "World room reverb should trim low-frequency buildup")

	SettingsStore.ensure_audio_buses()
	expect.call(_reverb_count(world_index) == 1, "Repeated audio setup should not duplicate the world room reverb")

	var run_scene: Node = RunSceneScript.new()
	var world_player := run_scene.call("_acquire_sfx_player") as AudioStreamPlayer
	run_scene.call("_ensure_music_player")
	var music_player := run_scene.get("_music_player") as AudioStreamPlayer
	expect.call(world_player != null and world_player.bus == SettingsStore.WORLD_SFX_BUS, "Run-scene effects should play through the reverberant world path")
	expect.call(music_player != null and music_player.bus == SettingsStore.MUSIC_BUS, "Run-scene music should remain on the unchanged dry Music bus")
	run_scene.free()

	var cursor_feedback: Node = CursorFeedbackScript.new()
	cursor_feedback.call("_create_audio_players")
	var cursor_players: Array = cursor_feedback.get("_audio_players") as Array
	expect.call(not cursor_players.is_empty(), "Cursor feedback should create dry UI audio players")
	for player_var: Variant in cursor_players:
		var cursor_player := player_var as AudioStreamPlayer
		expect.call(cursor_player != null and cursor_player.bus == SettingsStore.UI_SFX_BUS, "Every cursor feedback player should use the dry UI path")
	cursor_feedback.free()

static func _reverb_count(bus_index: int) -> int:
	var count: int = 0
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectReverb:
			count += 1
	return count

static func _reverb_index(bus_index: int) -> int:
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectReverb:
			return effect_index
	return -1
