extends RefCounted

const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const RoutineClock = preload("res://tests/helpers/presentation_routine_clock.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const PostCombatRewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const RunSfxLibrary = preload("res://scripts/run_sfx_library.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const EXPECTED_DURATIONS: Dictionary = {
	RunSfxLibrary.DOOR_OPEN_ID: 1.318844,
	RunSfxLibrary.CAMPFIRE_LOOP_ID: 77.855,
	RunSfxLibrary.REWARD_ACCEPTED_ID: 4.863220,
	RunSfxLibrary.VICTORY_RESOLUTION_ID: 5.062375
}

const EXPECTED_VOLUME_DB: Dictionary = {
	RunSfxLibrary.DOOR_OPEN_ID: -10.0,
	RunSfxLibrary.CAMPFIRE_LOOP_ID: -4.0,
	RunSfxLibrary.REWARD_ACCEPTED_ID: -12.0,
	RunSfxLibrary.VICTORY_RESOLUTION_ID: -7.0
}

static func run(tree: SceneTree, expect: Callable) -> void:
	await TestClock.run_scoped(tree, func(scope: TestClock.GlobalScope) -> void:
		await _run_scoped(scope, tree, expect)
	)

static func _run_scoped(_globals: TestClock.GlobalScope, tree: SceneTree, expect: Callable) -> void:
	_test_registry_and_trimmed_assets(expect)
	_test_victory_timing_contract(expect)
	await _test_live_run_hooks(tree, expect)

static func _test_registry_and_trimmed_assets(expect: Callable) -> void:
	for sfx_id: String in EXPECTED_DURATIONS:
		var entry: Dictionary = RunSfxLibrary.entry(sfx_id)
		var path: String = str(entry.get("path", ""))
		expect.call(not path.is_empty() and FileAccess.file_exists(path), "%s should resolve to a shipped audio asset" % sfx_id)
		var stream: AudioStream = AssetLoader.load_audio_stream(path)
		expect.call(stream != null, "%s should load as a playable audio stream" % sfx_id)
		if stream == null:
			continue
		var expected_duration: float = float(EXPECTED_DURATIONS[sfx_id])
		expect.call(absf(stream.get_length() - expected_duration) <= 0.012, "%s should preserve its measured trimmed duration" % sfx_id)
		expect.call(absf(float(entry.get("trimmed_duration", 0.0)) - expected_duration) <= 0.0001, "%s should document the measured shipped duration" % sfx_id)
		expect.call(is_equal_approx(float(entry.get("volume_db", 99.0)), float(EXPECTED_VOLUME_DB[sfx_id])), "%s should retain its approved mix level" % sfx_id)
		expect.call(not entry.has("duration"), "%s should play its complete trimmed stream without an early stop timer" % sfx_id)

	var ambient: Dictionary = RunSfxLibrary.ambient_entry_for_mode("campfire")
	expect.call(str(ambient.get("id", "")) == RunSfxLibrary.CAMPFIRE_LOOP_ID and bool(ambient.get("loop", false)), "Campfire mode should own the looping fire ambience")
	expect.call(str(RunSfxLibrary.ambient_entry_for_mode("room").get("id", "")) != RunSfxLibrary.CAMPFIRE_LOOP_ID, "Fire ambience should not continue outside campfire mode")
	expect.call(str(RunSfxLibrary.ambient_entry_for_mode("combat").get("id", "")) == RunSfxLibrary.DUNGEON_AMBIENCE_ID, "Combat halls should carry the quiet stone-hall ambience bed")
	expect.call(RunSfxLibrary.ambient_entry_for_mode("victory").is_empty(), "Terminal screens should leave ambience to the music")
	expect.call(str(RunSfxLibrary.entry(RunSfxLibrary.DOOR_OPEN_ID).get("bus", "")) == SettingsStore.WORLD_SFX_BUS, "Door creak should use the room-reverberated world SFX path")
	expect.call(str(ambient.get("bus", "")) == SettingsStore.WORLD_SFX_BUS, "Campfire ambience should use the room-reverberated world SFX path")
	expect.call(str(RunSfxLibrary.entry(RunSfxLibrary.REWARD_ACCEPTED_ID).get("bus", "")) == SettingsStore.UI_SFX_BUS, "Reward acceptance should stay dry on the UI SFX path")
	expect.call(str(RunSfxLibrary.entry(RunSfxLibrary.VICTORY_RESOLUTION_ID).get("bus", "")) == SettingsStore.UI_SFX_BUS, "Victory resolution should stay dry on the UI SFX path")

static func _test_victory_timing_contract(expect: Callable) -> void:
	var cue_seconds: float = float(EXPECTED_DURATIONS[RunSfxLibrary.VICTORY_RESOLUTION_ID])
	var animated_seconds: float = PostCombatRewardSequence.victory_sequence_seconds(false)
	var reduced_seconds: float = PostCombatRewardSequence.victory_sequence_seconds(true)
	expect.call(animated_seconds < 1.0 and animated_seconds < cue_seconds, "Victory should hand off within a second while the musical tail continues")
	expect.call(reduced_seconds <= 0.25, "Reduced-motion Victory should hand off promptly without a musical input lock")
	expect.call(PostCombatRewardSequence.victory_sequence_seconds(false) >= 0.85, "Victory should retain its authored default cadence when no cue is available")

static func _test_live_run_hooks(tree: SceneTree, expect: Callable) -> void:
	await TestClock.run_scoped(tree, func(scope: TestClock.GlobalScope) -> void:
		await _test_live_run_hooks_scoped(scope, tree, expect)
	)

static func _test_live_run_hooks_scoped(_globals: TestClock.GlobalScope, tree: SceneTree, expect: Callable) -> void:
	TestClock.now_usec = TestClock.FIXTURE_START_USEC
	var packed_scene: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(packed_scene != null, "Run scene should load for run SFX coverage")
	if packed_scene == null:
		return
	var instance: Node = packed_scene.instantiate()
	instance.get("_combat_pacing").free()
	var observed := GDScript.new()
	var original: Script = load("res://scripts/run_scene.gd")
	var door: String = TestClock.method_source(original, "_play_door_opening_animation")
	door = door.replace("get_tree().create_timer(", "RoutineClock.timer(get_tree(), ")
	var victory: String = TestClock.method_source(original, "_play_post_combat_victory")
	victory = victory.replace("PostCombatRewardSequence.play_victory", "test_sequence.play_victory")
	var frames: String = TestClock.method_source(original, "_play_timed_animation_frames")
	observed.source_code = """extends "res://scripts/run_scene.gd"
const RoutineClock = preload("res://tests/helpers/presentation_routine_clock.gd")
var test_sequence: Script
""" + door + victory + frames
	assert(observed.reload() == OK)
	instance.set_script(observed)
	instance.set("test_sequence", RoutineClock.sequence_script(PostCombatRewardSequence))
	instance.get("_combat_pacing").free()
	instance.set("_combat_pacing", TestClock.clocked_script(preload("res://scripts/combat_pacing.gd")).new())
	tree.root.add_child(instance)
	await tree.process_frame
	instance.call("_close_dialogue")

	instance.call("_update_ambient_sfx_for_context", "campfire")
	var ambient_player: AudioStreamPlayer = instance.get("_ambient_sfx_player") as AudioStreamPlayer
	expect.call(ambient_player != null and ambient_player.playing, "Entering campfire mode should immediately start its background fire")
	if ambient_player != null:
		expect.call(ambient_player.bus == SettingsStore.WORLD_SFX_BUS, "Campfire ambience should honor the world Sound Effects routing and room reverb")
		expect.call(ambient_player.stream is AudioStreamWAV, "Campfire ambience should use the trimmed WAV stream")
		if ambient_player.stream is AudioStreamWAV:
			var looped_wav: AudioStreamWAV = ambient_player.stream as AudioStreamWAV
			expect.call(looped_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and looped_wav.loop_end > 0, "Campfire ambience should loop sample-accurately without a restart gap")
	instance.call("_update_ambient_sfx_for_context", "room")
	expect.call(str(instance.get("_active_ambient_sfx_id")) == RunSfxLibrary.DUNGEON_AMBIENCE_ID and ambient_player != null and ambient_player.playing, "Leaving campfire mode should hand over from the fire loop to the quiet hall bed")
	instance.call("_update_ambient_sfx_for_context", "victory")
	expect.call(ambient_player != null and not ambient_player.playing and ambient_player.stream == null, "Terminal screens should stop room ambience")

	var door_clock := RoutineClock.new()
	tree.root.add_child(door_clock)
	await instance.call("_play_door_opening_animation", Vector2i(4, 0))
	var door_elapsed: float = float(door_clock.elapsed_usec) / 1000000.0
	door_clock.expect_completed_timers(expect, "Door transition")
	expect.call(door_clock.timers.size() == 1, "Door transition retains its settle timer")
	if not door_clock.timers.is_empty():
		expect.call(door_clock.timers[0].completed and door_clock.timers[0].completed_usec - door_clock.timers[0].started_usec >= 40000, "Door settle retains the full 40 ms before returning")
	var door_seconds: float = float(EXPECTED_DURATIONS[RunSfxLibrary.DOOR_OPEN_ID])
	expect.call(door_elapsed >= door_seconds - 0.06 and door_elapsed <= door_seconds + 0.30, "Door transition should remain gated for the complete trimmed creak")
	expect.call(_has_played_sfx(instance, RunSfxLibrary.DOOR_OPEN_ID), "Door opening should route the creak through a run SFX channel")

	var reward_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["frostbolt"],
		"heal_amount": 0,
		"ember_amount": 0
	}
	instance.set("_run_state", reward_state)
	await instance.call("_on_reward_card_pressed", "frostbolt")
	expect.call((instance.get("_run_state") as Dictionary).get("attuned_magic_cards", []).has("frostbolt"), "Card reward fixture should claim the selected card")
	expect.call(_has_played_sfx(instance, RunSfxLibrary.REWARD_ACCEPTED_ID), "Claiming a card reward should play the accepted-reward cue")

	var relic_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	relic_state["mode"] = "treasure"
	relic_state["relics"] = []
	relic_state["pending_relics"] = ["iron_lung"]
	instance.set("_run_state", relic_state)
	await instance.call("_claim_relic_with_deferred", "iron_lung", "", Rect2())
	expect.call((instance.get("_run_state") as Dictionary).get("relics", []).has("iron_lung"), "Relic reward fixture should claim the selected relic")
	expect.call(_played_sfx_count(instance, RunSfxLibrary.REWARD_ACCEPTED_ID) >= 2, "Card and relic claims should each emit their own accepted-reward cue")

	var victory_board: Dictionary = instance.call("_board_display_state")
	var victory_clock: Node = door_clock
	victory_clock.timers.clear()
	var victory_started_usec: int = victory_clock.elapsed_usec
	await instance.call("_play_post_combat_victory", victory_board)
	var victory_elapsed: float = float(victory_clock.elapsed_usec - victory_started_usec) / 1000000.0
	victory_clock.expect_completed_timers(expect, "Victory beat")
	expect.call(victory_clock.timers.size() == 1, "Victory beat retains its hold timer")
	victory_clock.free()
	var victory_seconds: float = PostCombatRewardSequence.victory_sequence_seconds(false)
	expect.call(victory_elapsed >= victory_seconds - 0.06 and victory_elapsed <= victory_seconds + 0.35, "Victory should finish its visual beat without waiting for the audio tail")
	expect.call(_has_played_sfx(instance, RunSfxLibrary.VICTORY_RESOLUTION_ID), "Victory presentation should play the resolution cue")
	var victory_overlay: Control = instance.get("_post_combat_victory_overlay") as Control
	expect.call(victory_overlay != null and not victory_overlay.visible, "Victory overlay should clear after its visual beat")

	print("RUN SFX GAME CLOCK: door=%.3fs victory=%.3fs" % [door_elapsed, victory_elapsed])
	instance.queue_free()
	await tree.process_frame

static func _has_played_sfx(instance: Node, sfx_id: String) -> bool:
	return _played_sfx_count(instance, sfx_id) > 0

static func _played_sfx_count(instance: Node, sfx_id: String) -> int:
	var count: int = 0
	for player_var: Variant in instance.get("_sfx_players") as Array:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null and str(player.get_meta("sfx_id", "")) == sfx_id:
			count += 1
	return count
