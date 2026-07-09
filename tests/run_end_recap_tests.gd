extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunEndRecapOverlay = preload("res://scripts/run_end_recap_overlay.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://run_end_recap_progression_test.json")
	ProgressionStore.set_run_storage_path("user://run_end_recap_saved_run_test.save")
	call_deferred("_run")

func _run() -> void:
	ProgressionStore.clear_saved_run()
	_test_recap_model_values()
	await _test_overlay_action_signals()
	await _test_run_scene_progression_and_actions()
	if _failures.is_empty():
		print("RUN END RECAP TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("RUN END RECAP TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _test_recap_model_values() -> void:
	var run_state: Dictionary = {
		"current_room": Vector2i(4, 0),
		"rooms": {
			"0,0": {"depth": 0, "type": "start", "cleared": true},
			"1,0": {"depth": 1, "type": "combat", "cleared": true},
			"2,0": {"depth": 2, "type": "treasure", "cleared": true},
			"3,0": {"depth": 3, "type": "boss", "cleared": true},
			"4,0": {"depth": 4, "type": "combat", "cleared": false}
		},
		"deck_cards": ["quick_stab", "patch_up", "pale_spark", "guarded_step"],
		"attuned_magic_cards": ["pale_spark"],
		"relics": ["iron_lung", "ember_lens", "pilgrim_boots"],
		"equipped_equipment": {"weapon": "training_sword"}
	}
	var progression: Dictionary = ProgressionStore.record_lost_embers(
		ProgressionStore.default_data(),
		37,
		Vector2i(4, 0),
		2
	)
	var defeat: Dictionary = RunEndRecapOverlay.build_model(run_state, progression, "defeat", 37)
	_assert(int(defeat.get("depth", -1)) == 4, "Defeat recap should use current-room depth")
	_assert(int(defeat.get("rooms_cleared", -1)) == 3, "Rooms cleared should count committed non-start cleared rooms")
	_assert(str(defeat.get("boss_result", "")) == "1 guardian defeated", "Defeat recap should derive prior boss clears")
	_assert(str(defeat.get("ember_label", "")) == "EMBERS LOST" and int(defeat.get("ember_amount", -1)) == 37, "Defeat recap should show the committed lost ember amount")
	_assert(str(defeat.get("recovery_status", "")) == "Recovery marker set · Depth 4 · 37 embers", "Defeat recap should match the committed recovery marker")
	var highlights: Array = defeat.get("build_highlights", []) as Array
	_assert(highlights.size() == 3, "Build recap should include deck, relic, and equipment highlights")
	_assert(str(highlights[0]) == "4-card deck · 1 attuned", "Build recap should derive deck and attunement counts")
	_assert(str(highlights[1]) == "Relics · Iron Lung, Ember Lens +1", "Build recap should derive named relic highlights")

	var zero_defeat: Dictionary = RunEndRecapOverlay.build_model(
		run_state,
		ProgressionStore.record_lost_embers(ProgressionStore.default_data(), 0, Vector2i(4, 0), 2),
		"defeat",
		0
	)
	_assert(str(zero_defeat.get("recovery_status", "")) == "No marker · no embers left behind", "Zero-ember defeat should not promise a recovery marker")
	var victory: Dictionary = RunEndRecapOverlay.build_model(run_state, ProgressionStore.default_data(), "victory", 0)
	_assert(str(victory.get("ember_label", "")) == "EMBERS BANKED" and int(victory.get("ember_amount", -1)) == 0, "Zero-ember victory should explicitly show a zero banked result")
	_assert(str(victory.get("boss_result", "")) == "Final boss defeated", "Victory recap should report the final boss result")

func _test_overlay_action_signals() -> void:
	var overlay := RunEndRecapOverlay.new()
	root.add_child(overlay)
	await process_frame
	var model: Dictionary = RunEndRecapOverlay.build_model(
		{"current_room": Vector2i.ZERO, "rooms": {}, "deck_cards": []},
		ProgressionStore.default_data(),
		"victory",
		12
	)
	overlay.present(model)
	var action_counts: Dictionary = {"new_run": 0, "main_menu": 0}
	overlay.new_run_pressed.connect(func() -> void: action_counts["new_run"] = int(action_counts["new_run"]) + 1)
	overlay.main_menu_pressed.connect(func() -> void: action_counts["main_menu"] = int(action_counts["main_menu"]) + 1)
	var new_run_button: Button = overlay.find_child("NewRunButton", true, false) as Button
	var main_menu_button: Button = overlay.find_child("MainMenuButton", true, false) as Button
	_assert(new_run_button != null and new_run_button.text == "New Run", "Recap should expose a clear New Run action")
	_assert(main_menu_button != null and main_menu_button.text == "Main Menu", "Recap should expose a clear Main Menu action")
	if new_run_button != null:
		new_run_button.pressed.emit()
	if main_menu_button != null:
		main_menu_button.pressed.emit()
	_assert(int(action_counts["new_run"]) == 1, "New Run button should emit exactly one action")
	_assert(int(action_counts["main_menu"]) == 1, "Main Menu button should emit exactly one action")
	overlay.set_motion_enabled(false)
	_assert(not overlay.motion_enabled(), "Recap should expose a decoupled motion switch for future reduced-motion settings")
	overlay.queue_free()
	await process_frame

func _test_run_scene_progression_and_actions() -> void:
	var engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	ProgressionStore.save_data(progression)
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var victory_state: Dictionary = _terminal_state(engine, progression, Vector2i(8, 0), "victory", 53)
	instance.call("_load_run_state", victory_state)
	await process_frame
	var recap: Control = instance.get("_run_end_recap") as Control
	_assert(recap != null and recap.visible, "Victory should display the run recap over the board")
	var victory_model: Dictionary = recap.call("recap_model") if recap != null else {}
	_assert(int(victory_model.get("ember_amount", -1)) == 53, "Victory display should preserve the pre-clear carried amount")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 53, "Victory should commit banked embers before displaying the recap")
	_assert(engine.held_embers(instance.get("_run_state")) == 0, "Victory should clear embers from the ended run after banking")
	var victory_new_run_button: Button = recap.find_child("NewRunButton", true, false) as Button if recap != null else null
	if victory_new_run_button != null:
		victory_new_run_button.pressed.emit()
	await process_frame
	var restarted_state: Dictionary = instance.get("_run_state") as Dictionary
	_assert(str(restarted_state.get("mode", "")) == "room", "Victory New Run should begin a fresh run")
	_assert(engine.held_embers(restarted_state) == 53, "Victory New Run should carry the banked ember result")

	progression = restarted_state.get("progression", {}) as Dictionary
	var defeat_state: Dictionary = _terminal_state(engine, progression, Vector2i(2, 0), "defeat", 41)
	instance.call("_load_run_state", defeat_state)
	await process_frame
	recap = instance.get("_run_end_recap") as Control
	var defeat_model: Dictionary = recap.call("recap_model") if recap != null else {}
	_assert(int(defeat_model.get("ember_amount", -1)) == 41, "Defeat display should preserve the pre-clear lost amount")
	var committed_defeat: Dictionary = ProgressionStore.load_data()
	var marker: Dictionary = ProgressionStore.recovery_marker(committed_defeat)
	_assert(int(committed_defeat.get("embers", -1)) == 0, "Defeat should commit zero carried embers")
	_assert(int(marker.get("amount", -1)) == 41 and ProgressionStore.recovery_coord(committed_defeat) == Vector2i(2, 0), "Defeat should commit the displayed recovery marker")
	var defeat_new_run_button: Button = recap.find_child("NewRunButton", true, false) as Button if recap != null else null
	if defeat_new_run_button != null:
		defeat_new_run_button.pressed.emit()
	await process_frame
	var recovery_run: Dictionary = instance.get("_run_state") as Dictionary
	_assert(str(recovery_run.get("mode", "")) == "room" and engine.held_embers(recovery_run) == 0, "Defeat New Run should begin fresh without lost embers")
	var recovery_room: Dictionary = engine.room_metadata(recovery_run, Vector2i(2, 0))
	_assert(bool(recovery_room.get("recovery_marker", false)) and int(recovery_room.get("recovery_amount", 0)) == 41, "Defeat New Run should stage the committed recovery marker")

	var menu_state: Dictionary = _terminal_state(engine, recovery_run.get("progression", {}) as Dictionary, Vector2i(1, 0), "defeat", 0)
	instance.call("_load_run_state", menu_state)
	await process_frame
	current_scene = instance
	recap = instance.get("_run_end_recap") as Control
	var menu_button: Button = recap.find_child("MainMenuButton", true, false) as Button if recap != null else null
	if menu_button != null:
		menu_button.pressed.emit()
	await process_frame
	await process_frame
	_assert(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "Main Menu action should leave the ended run for the main menu")
	_assert(not ProgressionStore.has_saved_run(), "Main Menu action should clear any ended-run save")
	if current_scene != null:
		var finished_scene: Node = current_scene
		var music_player: AudioStreamPlayer = finished_scene.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if music_player != null:
			music_player.stop()
			music_player.stream = null
		current_scene = null
		finished_scene.free()
		await process_frame
		await create_timer(0.08).timeout

func _terminal_state(engine: RunEngine, progression: Dictionary, coord: Vector2i, outcome: String, held_embers: int) -> Dictionary:
	var state: Dictionary = engine.create_new_run(7319 + coord.x * 17 + held_embers, progression)
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = outcome == "victory"
	if outcome == "victory":
		room["type"] = "boss"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = outcome
	state["victory"] = outcome == "victory"
	state["game_over"] = outcome == "defeat"
	state["player_hp"] = 0 if outcome == "defeat" else int(state.get("player_max_hp", 1))
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["progression"] = progression.duplicate(true)
	return state

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
