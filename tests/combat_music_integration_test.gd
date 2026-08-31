extends SceneTree

const MusicLibrary = preload("res://scripts/music_library.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(run_scene != null, "Run scene should load for combat-music integration proof")
	if run_scene == null:
		_finish()
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var boss_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "boss",
		"boss_id": "zekarion"
	})
	_assert(str(boss_entry.get("id", "")) == MusicLibrary.ZEKARION_BOSS_TRACK_ID, "Boss combat should keep its existing route before terminal defeat")
	var death_entry: Dictionary = MusicLibrary.entry_for_context("defeat", {
		"type": "boss",
		"boss_id": "zekarion"
	})
	var death_path: String = str(death_entry.get("path", ""))
	_assert(str(death_entry.get("id", "")) == MusicLibrary.CHOPIN_DEATH_TRACK_ID, "Defeat mode should override even boss combat with the Chopin death route")
	_assert(death_path == "res://assets/audio/music/chopin_op35_funeral_march_death_loop.ogg", "Defeat mode should select the promoted Chopin asset")
	_assert(FileAccess.get_sha256(death_path) == "f005bda46c395579b32f0afeb749b5e16775efa2ecee5203e2a4bacd872b2569", "The live death route should use the exact owner-approved v05 Ogg")
	_assert(bool(death_entry.get("loop", false)), "The death route should request native looping")
	var entry: Dictionary = MusicLibrary.entry_for_context(RunEngine.MODE_PRE_BATTLE, {
		"type": "combat",
		"element": "fire"
	})
	instance.call("_play_music", entry)
	await process_frame
	var player: AudioStreamPlayer = instance.get("_music_player") as AudioStreamPlayer
	_assert(str(instance.get("_active_music_id")) == MusicLibrary.SCHUBERT_COMBAT_TRACK_ID, "Live run scene should activate the Schubert track in ordinary pre-battle")
	_assert(player != null, "Live run scene should create a music player")
	if player != null:
		_assert(player.bus == SettingsStore.MUSIC_BUS, "Schubert playback should use the Music bus")
		_assert(player.playing, "Schubert playback should start in the live run scene")
		_assert(player.stream is AudioStreamOggVorbis, "Live Schubert playback should use the imported Ogg stream")
		if player.stream is AudioStreamOggVorbis:
			var ogg_stream: AudioStreamOggVorbis = player.stream as AudioStreamOggVorbis
			_assert(ogg_stream.loop, "Live Schubert Ogg stream should loop natively")
			_assert(ogg_stream.get_length() > 268.0 and ogg_stream.get_length() < 269.0, "Live Schubert Ogg should retain the verified 4:29 duration")
		var combat_stream: AudioStream = player.stream
		player.volume_db = -5.5
		var player_death_units: Array[Dictionary] = []
		player_death_units.append({"role": "player"})
		var enemy_death_units: Array[Dictionary] = []
		enemy_death_units.append({"role": "enemy"})
		instance.set("_committed_run_state_override", {"mode": "combat"})
		instance.call("_start_terminal_defeat_music_if_needed", player_death_units)
		_assert(str(instance.get("_active_music_id")) == MusicLibrary.SCHUBERT_COMBAT_TRACK_ID, "Nonterminal player defeat should not replace combat music")
		instance.set("_committed_run_state_override", {"mode": "defeat"})
		instance.call("_start_terminal_defeat_music_if_needed", enemy_death_units)
		_assert(str(instance.get("_active_music_id")) == MusicLibrary.SCHUBERT_COMBAT_TRACK_ID, "Enemy defeat should not start death music in a terminal state")
		instance.set("_committed_run_state_override", {})
		instance.set("_run_state", {
			"mode": "combat",
			"current_room": Vector2i.ZERO,
			"rooms": {"0,0": {"type": "combat"}},
			"combat_state": {}
		})
		var lethal_combat_state: Dictionary = {
			"player": {"hp": 0, "max_hp": 24, "pos": Vector2i(2, 4)},
			"enemies": [{"id": 1, "type": "crawler", "hp": 14, "max_hp": 14, "pos": Vector2i(3, 4)}],
			"room_type": "combat",
			"grid": [],
			"terrain": [],
			"traps": [],
			"loot": []
		}
		instance.call("_start_terminal_defeat_music_if_needed", player_death_units, lethal_combat_state)
		_assert(str(instance.get("_active_music_id")) == MusicLibrary.CHOPIN_DEATH_TRACK_ID, "Terminal player death should reserve the Chopin route as soon as the death animation starts")
		_assert(player.stream == combat_stream, "Combat music should remain attached while its outgoing fade begins")
		var death_transition: Tween = instance.get("_music_tween") as Tween
		_assert(death_transition != null and death_transition.is_valid(), "Terminal player death should schedule the fade-out, stream swap, and fade-in as one transition")
		await create_timer(0.7).timeout
		_assert(player.stream is AudioStreamOggVorbis, "The death transition should switch to the promoted Chopin Ogg after combat fades out")
		if player.stream is AudioStreamOggVorbis:
			var death_stream: AudioStreamOggVorbis = player.stream as AudioStreamOggVorbis
			_assert(death_stream.loop, "The live death-screen Ogg should loop natively")
			_assert(death_stream.get_length() > 29.0 and death_stream.get_length() < 29.2, "The live death-screen Ogg should retain the verified 29-second loop")
		_assert(player.playing, "Chopin playback should continue through the defeat recap")
		await create_timer(1.3).timeout
		_assert(absf(player.volume_db - -7.0) < 0.15, "The death track should complete its gentle fade-in at the configured level")
		instance.call("_play_music", entry)
		await process_frame
		_assert(str(instance.get("_active_music_id")) == MusicLibrary.SCHUBERT_COMBAT_TRACK_ID, "Leaving defeat mode should replace death music with the next context route")
		instance.call("_shutdown_audio")
		_assert(not player.playing and player.stream == null, "Leaving the run scene should stop and release death music")
	instance.queue_free()
	await process_frame
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT MUSIC INTEGRATION TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("COMBAT MUSIC INTEGRATION TEST: FAIL (%d failures)" % _failures.size())
	quit(1)
