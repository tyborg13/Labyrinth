extends SceneTree

const Music = preload("res://scripts/music_library.gd")
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
var failures: Array[String]
var action_finished: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for reduced: bool in [false, true]:
		await _test_map_travel(scene, reduced)
	await _test_automatic_map(scene)
	await _test_manual_map_after_blocked_automatic_open(scene)
	await _test_bridge_lifetime(scene)
	await _test_escape_terminal_and_shutdown(scene)
	scene.call("_shutdown_audio")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("MUSIC CONTINUITY TEST: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _test_map_travel(scene: Node, reduced: bool) -> void:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(82271, Progression.default_data())
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	var settings: Dictionary = scene.get("_settings")
	settings["reduced_motion"] = reduced
	scene.set("_settings", settings)
	scene.call("_open_large_map")
	await create_timer(1.0).timeout
	var player: AudioStreamPlayer = scene.get("_music_player")
	var playback: AudioStreamPlayback = player.get_stream_playback()
	var position: float = player.get_playback_position()
	_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID, "Map should start with The Turning Key")
	var destination: Vector2i = engine.available_moves(scene.get("_run_state"))[0]
	action_finished = false
	_travel(scene, destination)
	var began: int = Time.get_ticks_msec()
	while not action_finished and Time.get_ticks_msec() - began < 15000:
		_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID, "Map-to-prebattle travel must not request the board track (reduced=%s)" % reduced)
		_expect(player.get_stream_playback() == playback, "Door animation must retain the same music playback (reduced=%s)" % reduced)
		await process_frame
	await create_timer(0.4).timeout
	_expect(action_finished, "Map travel should reach its destination")
	_expect(str((scene.get("_run_state") as Dictionary).get("mode")) == "pre_battle", "Real room travel should arrive at pre-battle")
	_expect(player.get_stream_playback() == playback and player.get_playback_position() > position, "Pre-battle should continue the map track without restarting (reduced=%s)" % reduced)
	print("Travel continuity reduced_motion=%s: elapsed=%dms" % [reduced, Time.get_ticks_msec() - began])
	# Starting an actual fight should still change to combat music once ready.
	await scene.call("_on_pre_battle_start_pressed")
	await create_timer(0.4).timeout
	_expect(str(scene.get("_active_music_id")) == Music.ASHEN_PURSUIT_TRACK_ID and player.playing, "Beginning a stable normal fight should play Ashen Pursuit")

func _travel(scene: Node, destination: Vector2i) -> void:
	await scene.call("_on_large_map_room_selected", destination)
	action_finished = true

func _test_automatic_map(scene: Node) -> void:
	# A cleared room automatically hands off to the section map during refresh.
	var state: Dictionary = Run.new().create_new_run(82271, Progression.default_data())
	state["rooms"]["0,0"]["type"] = "empty"
	state["rooms"]["0,0"]["cleared"] = true
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	scene.call("_open_large_map")
	await create_timer(1.0).timeout
	var player: AudioStreamPlayer = scene.get("_music_player")
	var playback: AudioStreamPlayback = player.get_stream_playback()
	scene.call("_close_large_map")
	scene.set("_section_map_presented_key", "")
	scene.call("_refresh_ui")
	_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID, "UI refresh must not request an intermediate quiet cue before auto-map opens")
	await create_timer(0.5).timeout
	_expect((scene.get("_large_map_scrim") as Control).visible, "Cleared room should automatically present its map")
	_expect(player.get_stream_playback() == playback, "Automatic map handoff must keep its current playback")
	# Deliberate map closure after presentation should restore the quiet board promptly.
	scene.call("_close_large_map")
	await create_timer(0.4).timeout
	_expect(str(scene.get("_active_music_id")) == Music.LANTERNS_TRACK_ID, "Manual map close should promptly restore a stable quiet room")

func _test_manual_map_after_blocked_automatic_open(scene: Node) -> void:
	# The opening conversation blocks the queued automatic map. Once it ends,
	# manually opening the map must not imply another auto-open is still pending.
	var state: Dictionary = Run.new().create_new_run(82271, Progression.default_data())
	scene.call("_load_run_state", state)
	await create_timer(0.2).timeout
	_expect(bool(scene.get("_dialogue_active")), "Opening conversation should block automatic map presentation")
	_expect(str(scene.get("_section_map_presented_key")).is_empty(), "Blocked auto-map must not count as presented")
	scene.call("_close_dialogue")
	scene.call("_open_large_map")
	await create_timer(0.4).timeout
	_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID, "Manually opened map should play its planning cue")
	scene.call("_close_large_map")
	await create_timer(0.4).timeout
	_expect(not (scene.get("_large_map_scrim") as Control).visible, "Manual map closure should leave the board visible")
	_expect(str(scene.get("_active_music_id")) == Music.LANTERNS_TRACK_ID, "A previously blocked auto-map must not keep planning music on the visible board")

func _test_bridge_lifetime(scene: Node) -> void:
	var state: Dictionary = {"mode": "room", "current_room": Vector2i.ZERO, "rooms": {"0,0": {"type": "empty", "cleared": true}}}
	scene.set("_run_state", state)
	scene.set("_combat_state", {})
	var menu: Control = scene.get("_menu_scrim")
	var map: Control = scene.get("_large_map_scrim")
	for busy_flag: String in ["_animation_lock", "_loadout_acquisition_in_progress", "_relic_claim_in_progress", "_frame_sliced_ui_refresh_active"]:
		menu.visible = true
		await create_timer(1.0).timeout
		var player: AudioStreamPlayer = scene.get("_music_player")
		var playback: AudioStreamPlayback = player.get_stream_playback()
		scene.set(busy_flag, true)
		menu.visible = false
		scene.call("_update_music_for_context", state["rooms"]["0,0"])
		# Longer than the old brief board cue and every normal music fade.
		await create_timer(2.2 if busy_flag == "_animation_lock" else 0.4).timeout
		_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID and player.get_stream_playback() == playback, "Automatic bridge must hold playback for its full lifetime: %s" % busy_flag)
		scene.set(busy_flag, false)
		map.visible = true
		await create_timer(0.4).timeout
		_expect(player.get_stream_playback() == playback, "Bridge ending at another planning surface must not restart: %s" % busy_flag)
		map.visible = false
		await create_timer(0.4).timeout
		_expect(str(scene.get("_active_music_id")) == Music.LANTERNS_TRACK_ID, "Manual navigation after bridge should remain responsive")
	# A bridge ending on the board must retry without needing another UI refresh.
	menu.visible = true
	await create_timer(0.4).timeout
	scene.set("_animation_lock", true)
	menu.visible = false
	await create_timer(0.4).timeout
	scene.set("_animation_lock", false)
	await create_timer(0.4).timeout
	_expect(str(scene.get("_active_music_id")) == Music.LANTERNS_TRACK_ID, "Settled board should automatically receive its cue after a hold")

func _test_escape_terminal_and_shutdown(scene: Node) -> void:
	var state: Dictionary = scene.get("_run_state")
	var menu: Control = scene.get("_menu_scrim")
	menu.visible = true
	await create_timer(1.0).timeout
	var player: AudioStreamPlayer = scene.get("_music_player")
	var playback: AudioStreamPlayback = player.get_stream_playback()
	# Escape is an automatic state even before its animation coroutine begins.
	state["mode"] = "escape"
	scene.set("_run_state", state)
	menu.visible = false
	await create_timer(0.4).timeout
	_expect(str(scene.get("_active_music_id")) == Music.TURNING_KEY_TRACK_ID and player.get_stream_playback() == playback, "Escape bridge must not briefly introduce quiet board music")
	state["mode"] = "pre_battle"
	scene.set("_run_state", state)
	await create_timer(0.4).timeout
	_expect(player.get_stream_playback() == playback, "Escape ending at pre-battle should retain planning playback")
	# Terminal defeat must still win immediately while an earlier request waits.
	state["mode"] = "combat"
	scene.set("_run_state", state)
	scene.set("_animation_lock", true)
	scene.call("_update_music_for_context", {"type": "combat"})
	scene.set("_committed_run_state_override", {"mode": "defeat"})
	scene.call("_queue_music_context_refresh")
	await process_frame
	await process_frame
	_expect(str(scene.get("_active_music_id")) == Music.CHOPIN_DEATH_TRACK_ID, "Defeat should override a pending automatic bridge without waiting for unlock")
	await create_timer(0.4).timeout
	_expect(player.playing and player.stream.get_length() > 29.0 and player.stream.get_length() < 29.2, "Pending bridge should give way to actual Chopin playback")
	scene.set("_committed_run_state_override", {})
	scene.set("_animation_lock", false)
	scene.call("_update_music_for_context", {"type": "combat"})
	await create_timer(0.4).timeout
	scene.set("_animation_lock", true)
	scene.call("_update_music_for_context", {"type": "combat"})
	scene.call("_queue_music_context_refresh")
	scene.call("_shutdown_audio")
	scene.set("_animation_lock", false)
	await create_timer(0.4).timeout
	_expect(not player.playing and player.stream == null, "Shutdown must cancel both held and queued context refreshes")

func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
