extends RefCounted

const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const RoutineClock = preload("res://tests/helpers/presentation_routine_clock.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const PostCombatRewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const RunSfxLibrary = preload("res://scripts/run_sfx_library.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const EventViewScript = preload("res://scripts/event_view.gd")
const EventFixtures = preload("res://tests/suites/event_view_suite.gd")
const HearthPresentation = preload("res://scripts/ember_hearth_presentation.gd")
const CursorFeedback = preload("res://scripts/cursor_feedback.gd")
const CueRouter = preload("res://scripts/sfx_cue_router.gd")
const CHOICE_GUARD_PROOF_SECONDS: float = 0.09
const CARD_PLAY_PROOF_CLOCK_MSEC: int = 10000

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
	await _test_choice_and_card_play_feedback(tree, expect)

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

static func _test_choice_and_card_play_feedback(tree: SceneTree, expect: Callable) -> void:
	var heard: Array[String]
	var sound: Callable = func(entry: Dictionary) -> void:
		heard.append(str(entry.get("id", "")))
		if entry.get("id", "") == RunSfxLibrary.HEARTH_FOCUS_ID:
			expect.call(entry == RunSfxLibrary.entry(RunSfxLibrary.HEARTH_FOCUS_ID), "Event and Hearth use the exact same entry, including bus, level and duration")
	var view := EventViewScript.new()
	tree.root.add_child(view)
	var router := CueRouter.new()
	router.bind_map_hover(view)
	view.present(EventFixtures.fixture("whispering_well", true), true, sound)
	view.finish_animation_for_test()
	heard.clear()
	await _wait_choice_guard(tree)
	view.choices[0].mouse_entered.emit()
	expect.call(heard.count(RunSfxLibrary.HEARTH_FOCUS_ID) == 1, "Automatic initial focus does not consume the first pointer hover cue")
	view.choices[0].mouse_exited.emit()
	for button: Button in view.choices: button.release_focus()
	heard.clear()
	await _wait_choice_guard(tree)
	var choice: Button = view.choices[1]
	choice.mouse_entered.emit()
	var hover_count: int = heard.count(RunSfxLibrary.HEARTH_FOCUS_ID)
	await _wait_choice_guard(tree)
	choice.grab_focus()
	expect.call(heard.count(RunSfxLibrary.HEARTH_FOCUS_ID) == hover_count, "Hover then focus remains one choice highlight beyond the cooldown")
	choice.mouse_exited.emit()
	choice.mouse_entered.emit()
	expect.call(heard.count(RunSfxLibrary.HEARTH_FOCUS_ID) == hover_count, "Hover re-entry while focused does not tick twice")
	choice.mouse_exited.emit()
	choice.release_focus()
	await _wait_choice_guard(tree)
	view.move_focus(1)
	var focus_count: int = heard.count(RunSfxLibrary.HEARTH_FOCUS_ID) - hover_count
	expect.call(hover_count == 1 and focus_count == 1, "Event hover and controller focus request the Hearth cue")
	expect.call(CursorFeedback.cue_owns_feedback(choice, true), "Event choices suppress the shared focus voice")
	# An immediate distinct highlight uses the Hearth's same 80 ms guard.
	for button: Button in view.choices: button.release_focus()
	view.choices[0].mouse_entered.emit()
	expect.call(heard.count(RunSfxLibrary.HEARTH_FOCUS_ID) == hover_count + focus_count, "Rapid choice changes retain the Hearth repeat guard")
	print("AU02 EVENT FEEDBACK: hover=%d focus=%d" % [hover_count, focus_count])
	view.queue_free()
	await tree.process_frame
	var panel := Control.new()
	tree.root.add_child(panel)
	panel.set_meta("choice_revealed", true)
	heard.clear()
	var hearth := HearthPresentation.new()
	hearth.emphasize(panel, panel, true, sound)
	hearth.emphasize(panel, panel, true, sound)
	expect.call(heard == [RunSfxLibrary.HEARTH_FOCUS_ID], "Hearth comparison requests one cue for a repeated highlight")
	panel.free()
	await _test_card_play_gain_feedback(tree, expect)

static func _test_card_play_gain_feedback(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	scene.call("_close_dialogue")
	scene.call("_ensure_sfx_bank")
	var bank: Node = scene.get("_sfx_bank")
	bank.set_test_clock(CARD_PLAY_PROOF_CLOCK_MSEC)
	bank.play("card.select")
	var normal_gain: float = float(bank.last_play["selected"]["gain"])
	var played_before: int = int(bank.cues["card.select"]["played"])
	var voices_before: int = bank.cues["card.select"]["voices"].size()
	var requests: Array[Dictionary]
	bank.cue_requested.connect(func(id: String, result: String) -> void:
		if id == "card.select":
			requests.append({"result": result, "frame": Engine.get_process_frames(),
				"gain": bank.last_play["selected"]["gain"]})
	)
	scene.set("_card_play_budget_override", {"ordinary_remaining": 2, "banked_remaining": 0, "total_remaining": 2})
	scene.call("_animate_card_play_reward", 3)
	expect.call(requests.size() == 1 and requests[0]["result"] == "played" and requests[0]["frame"] == Engine.get_process_frames(), "One returned Card Play sounds on the meter pulse's starting frame, even immediately after selection")
	expect.call(not requests.is_empty() and is_equal_approx(float(requests[0]["gain"]), normal_gain - 4.0), "Returned Card Play uses card.select exactly 4 dB below normal")
	await tree.create_timer(0.3).timeout
	expect.call(requests.size() == 1, "The settle animation adds no delayed sound requests")
	expect.call(int(scene.get("_card_play_count_override")) == 3, "Card Play feedback retains the existing meter update")
	var before: Dictionary = {"death_rewards": []}
	var after: Dictionary = {"death_rewards": [{"card_plays": 1}, {"card_plays": 2}]}
	scene.call("_animate_death_rewards", before, after)
	expect.call(requests.size() == 4 and int(bank.cues["card.select"]["played"]) == played_before + 4, "A multi-kill plays one cue per returned play without cooldown suppression")
	for index: int in range(1, requests.size()):
		expect.call(requests[index]["frame"] == Engine.get_process_frames() and requests[index]["result"] == "played" and is_equal_approx(float(requests[index]["gain"]), normal_gain - 4.0), "Every multi-kill return sounds on the one existing meter pulse frame at minus 4 dB")
	await tree.create_timer(0.3).timeout
	await scene.call("_animate_death_rewards", after, after)
	var router: RefCounted = scene.get("_sfx_router")
	router.card_play_gain(0)
	router.card_play_gain(-1)
	expect.call(requests.size() == 4, "Unchanged rewards and non-gains do not replay feedback")
	expect.call(bank.cues["card.select"]["voices"].size() == voices_before, "Returned plays keep the existing card.select voice cap")
	expect.call(bank.play("card.select") == 0.0, "Normal selection still obeys its original cooldown")
	bank.set_test_clock(CARD_PLAY_PROOF_CLOCK_MSEC + int(bank.cues["card.select"]["entry"]["cooldown_ms"]))
	bank.play("card.select")
	expect.call(is_equal_approx(float(bank.last_play["selected"]["gain"]), normal_gain), "Normal card.select level remains unchanged after returned-play feedback")
	print("AU02 CARD PLAY FEEDBACK: 4 returned plays; card.select gain_db=-4; same-frame dispatch")
	scene.queue_free()
	await tree.process_frame

static func _wait_choice_guard(tree: SceneTree) -> void:
	# SceneTreeTimer can consume a cold fixture's preceding frame delta; the
	# production Hearth and event guards both explicitly use wall time.
	var deadline: int = Time.get_ticks_msec() + ceili(CHOICE_GUARD_PROOF_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline: await tree.process_frame
