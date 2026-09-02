extends RefCounted

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

static func run(tree: SceneTree, expect: Callable) -> void:
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
		expect.call(not entry.has("duration"), "%s should play its complete trimmed stream without an early stop timer" % sfx_id)

	var ambient: Dictionary = RunSfxLibrary.ambient_entry_for_mode("campfire")
	expect.call(str(ambient.get("id", "")) == RunSfxLibrary.CAMPFIRE_LOOP_ID and bool(ambient.get("loop", false)), "Campfire mode should own the looping fire ambience")
	expect.call(RunSfxLibrary.ambient_entry_for_mode("room").is_empty(), "Fire ambience should not continue outside campfire mode")
	expect.call(str(RunSfxLibrary.entry(RunSfxLibrary.DOOR_OPEN_ID).get("bus", "")) == SettingsStore.WORLD_SFX_BUS, "Door creak should use the room-reverberated world SFX path")
	expect.call(str(ambient.get("bus", "")) == SettingsStore.WORLD_SFX_BUS, "Campfire ambience should use the room-reverberated world SFX path")
	expect.call(str(RunSfxLibrary.entry(RunSfxLibrary.REWARD_ACCEPTED_ID).get("bus", "")) == SettingsStore.UI_SFX_BUS, "Reward acceptance should stay dry on the UI SFX path")
	expect.call(str(RunSfxLibrary.entry(RunSfxLibrary.VICTORY_RESOLUTION_ID).get("bus", "")) == SettingsStore.UI_SFX_BUS, "Victory resolution should stay dry on the UI SFX path")

static func _test_victory_timing_contract(expect: Callable) -> void:
	var cue_seconds: float = float(EXPECTED_DURATIONS[RunSfxLibrary.VICTORY_RESOLUTION_ID])
	var animated_seconds: float = PostCombatRewardSequence.victory_sequence_seconds(cue_seconds, false)
	var reduced_seconds: float = PostCombatRewardSequence.victory_sequence_seconds(cue_seconds, true)
	expect.call(absf(animated_seconds - cue_seconds) <= 0.001, "Victory animation should end with the trimmed resolution cue instead of adding dead space")
	expect.call(absf(reduced_seconds - cue_seconds) <= 0.001, "Reduced-motion Victory should retain the full audio-backed dwell")
	expect.call(PostCombatRewardSequence.victory_sequence_seconds(0.0, false) >= 0.85, "Victory should retain its authored default cadence when no cue is available")

static func _test_live_run_hooks(tree: SceneTree, expect: Callable) -> void:
	var packed_scene: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(packed_scene != null, "Run scene should load for run SFX coverage")
	if packed_scene == null:
		return
	var instance: Node = packed_scene.instantiate()
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
	expect.call(ambient_player != null and not ambient_player.playing and ambient_player.stream == null, "Leaving campfire mode should stop its ambience")

	var door_started_msec: int = Time.get_ticks_msec()
	await instance.call("_play_door_opening_animation", Vector2i(4, 0))
	var door_elapsed: float = float(Time.get_ticks_msec() - door_started_msec) / 1000.0
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
	expect.call((instance.get("_run_state") as Dictionary).get("magic_inventory", []).has("frostbolt"), "Card reward fixture should claim the selected card")
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
	var victory_started_msec: int = Time.get_ticks_msec()
	await instance.call("_play_post_combat_victory", victory_board)
	var victory_elapsed: float = float(Time.get_ticks_msec() - victory_started_msec) / 1000.0
	var victory_seconds: float = float(EXPECTED_DURATIONS[RunSfxLibrary.VICTORY_RESOLUTION_ID])
	expect.call(victory_elapsed >= victory_seconds - 0.06 and victory_elapsed <= victory_seconds + 0.35, "Victory text should linger for the cue and return without an added dead-space hold")
	expect.call(_has_played_sfx(instance, RunSfxLibrary.VICTORY_RESOLUTION_ID), "Victory presentation should play the resolution cue")
	var victory_overlay: Control = instance.get("_post_combat_victory_overlay") as Control
	expect.call(victory_overlay != null and not victory_overlay.visible, "Victory overlay should hand off immediately after its audio-backed sequence")

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
