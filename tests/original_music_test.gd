extends SceneTree

const Music = preload("res://scripts/music_library.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	preload("res://tests/suites/original_music_suite.gd").run(Callable(self, "_expect"))
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var state: Dictionary = {"mode": "combat", "current_room": Vector2i.ZERO, "rooms": {"0,0": {"type": "combat"}}}
	scene.set("_run_state", state)
	scene.set("_combat_state", {"room_type": "combat"})
	scene.call("_update_music_for_context", {"type": "combat"})
	await create_timer(1.0).timeout
	_expect(str(scene.get("_active_music_id")) == Music.ASHEN_PURSUIT_TRACK_ID, "Live normal combat should use Ashen")
	var player: AudioStreamPlayer = scene.get("_music_player") as AudioStreamPlayer
	_expect(player != null and player.playing and player.stream is AudioStreamOggVorbis, "Live promoted combat stream should play")
	for surface_name: String in ["_large_map_scrim", "_menu_scrim", "_upgrade_scrim", "_grimoire_scrim", "_pile_scrim"]:
		var surface: Control = scene.get(surface_name) as Control
		surface.visible = true
		await process_frame
		await process_frame
		_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID, "%s should switch to planning music" % surface_name)
		await create_timer(0.3).timeout
		_expect(player.stream is AudioStreamOggVorbis and absf(player.stream.get_length() - 48.0) < 0.01, "Planning stream should replace combat after its outgoing fade")
		var playback: AudioStreamPlayback = player.get_stream_playback()
		scene.call("_update_music_for_context", {"type": "combat"})
		_expect(playback == player.get_stream_playback(), "Repeated context refresh should not restart the same music")
		surface.visible = false
		await process_frame
		await process_frame
		_expect(str(scene.get("_active_music_id")) == Music.ASHEN_PURSUIT_TRACK_ID, "%s closing should restore combat music" % surface_name)
		await create_timer(0.3).timeout
	# Switching directly between planning surfaces should not restart their cue.
	var menu: Control = scene.get("_menu_scrim") as Control
	var map: Control = scene.get("_large_map_scrim") as Control
	menu.visible = true
	await create_timer(0.4).timeout
	var planning_playback: AudioStreamPlayback = player.get_stream_playback()
	menu.visible = false
	map.visible = true
	await process_frame
	await process_frame
	_expect(planning_playback == player.get_stream_playback(), "Switching planning surfaces should retain playback")
	map.visible = false
	state["mode"] = "room"
	state["rooms"] = {"0,0": {"type": "campfire"}}
	scene.set("_run_state", state)
	scene.call("_update_music_for_context", {"type": "campfire"})
	_expect(str(scene.get("_active_music_id")) == Music.LANTERNS_TRACK_ID, "Campfire should activate Lanterns")
	await process_frame
	state["mode"] = "combat"
	scene.set("_run_state", state)
	scene.set("_combat_state", {"room_type": "guardian"})
	scene.call("_update_music_for_context", {"type": "guardian"})
	_expect(str(scene.get("_active_music_id")) == Music.THORNS_TRACK_ID, "Live guardian context should activate Thorns")
	await create_timer(0.4).timeout
	_expect(absf(player.stream.get_length() - 49.655) < 0.01, "Guardian should play the promoted Thorns version")
	state["mode"] = "defeat"
	scene.set("_run_state", state)
	menu.visible = true
	await process_frame
	await process_frame
	_expect(str(scene.get("_active_music_id")) == Music.CHOPIN_DEATH_TRACK_ID, "Open menu must not replace defeat music")
	# Death is reserved at animation start before the displayed state changes.
	state["mode"] = "combat"
	scene.set("_run_state", state)
	scene.set("_animation_lock", true)
	menu.visible = false
	await process_frame
	await process_frame
	_expect(str(scene.get("_active_music_id")) == Music.CHOPIN_DEATH_TRACK_ID, "Deferred menu close must preserve the reserved death cue during animation")
	scene.set("_animation_lock", false)
	scene.call("_shutdown_audio")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("ORIGINAL MUSIC ROUTING/PLAYBACK TEST: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
