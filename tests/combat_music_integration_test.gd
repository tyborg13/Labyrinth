extends SceneTree

const MusicLibrary = preload("res://scripts/music_library.gd")
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
	var entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "combat",
		"element": "fire"
	})
	instance.call("_play_music", entry)
	await process_frame
	var player: AudioStreamPlayer = instance.get("_music_player") as AudioStreamPlayer
	_assert(str(instance.get("_active_music_id")) == MusicLibrary.SCHUBERT_COMBAT_TRACK_ID, "Live run scene should activate the Schubert track for ordinary combat")
	_assert(player != null, "Live run scene should create a music player")
	if player != null:
		_assert(player.bus == SettingsStore.MUSIC_BUS, "Schubert playback should use the Music bus")
		_assert(player.playing, "Schubert playback should start in the live run scene")
		_assert(player.stream is AudioStreamOggVorbis, "Live Schubert playback should use the imported Ogg stream")
		if player.stream is AudioStreamOggVorbis:
			var ogg_stream: AudioStreamOggVorbis = player.stream as AudioStreamOggVorbis
			_assert(ogg_stream.loop, "Live Schubert Ogg stream should loop natively")
			_assert(ogg_stream.get_length() > 268.0 and ogg_stream.get_length() < 269.0, "Live Schubert Ogg should retain the verified 4:29 duration")
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
