extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const PLAYER_TILE := Vector2i(2, 4)
const ENEMY_TILE := Vector2i(3, 4)
const TRAP_TILE := Vector2i(2, 3)
const OUTPUT_DIR := "user://death_transition_v1"

var _failures: Array[String] = []
var _capture_enabled: bool = false


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture_enabled = _capture_enabled or OS.get_cmdline_user_args().has("--capture")
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path(OUTPUT_DIR + "/progression.json")
	ProgressionStore.set_run_storage_path(OUTPUT_DIR + "/current_run.save")
	SettingsStore.set_storage_path(OUTPUT_DIR + "/settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	call_deferred("_run")


func _run() -> void:
	var cases: Array[String] = ["card_mixed", "card_player_only", "movement", "enemy_attack", "card_mixed_reduced"]
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var case_index: int = args.find("--case")
	if case_index >= 0 and case_index + 1 < args.size():
		cases.clear()
		cases.append(args[case_index + 1])
	# Enemy rounds deliberately await frame_post_draw to submit lock feedback.
	# Exercise that production path in the companion real-renderer probe.
	if DisplayServer.get_name() == "headless":
		cases.erase("enemy_attack")
		print("Enemy-round death requires the real-renderer companion probe.")
	for case_name: String in cases:
		await _run_case(case_name)
	for failure: String in _failures:
		push_error(failure)
	print("DEATH TRANSITION TEST: %s (%d cases)" % ["PASS" if _failures.is_empty() else "FAIL", cases.size()])
	if _capture_enabled:
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _failures.is_empty() else 1)


func _run_case(case_name: String) -> void:
	ProgressionStore.clear_saved_run()
	ProgressionStore.save_data(ProgressionStore.default_data())
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(instance)
	current_scene = instance
	await process_frame
	await process_frame
	var state: Dictionary = _combat_state(case_name)
	var run_state: Dictionary = RunEngine.new().create_new_run(94301, ProgressionStore.default_data())
	run_state["mode"] = "combat"
	run_state["current_room"] = Vector2i(4, 1)
	run_state["current_room_layout"] = _layout(case_name)
	run_state["combat_state"] = state
	run_state["player_hp"] = 1
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = case_name.ends_with("reduced")
	instance.set("_settings", settings)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	if case_name.begins_with("card_mixed"):
		_assert_mixed_removal_fixture(instance, state)
	await _capture(case_name + "_before.png")
	print("death transition: starting %s" % case_name)
	if case_name == "movement":
		instance.call("_begin_player_movement_selection")
		instance.call("_on_board_tile_clicked", TRAP_TILE)
	elif case_name == "enemy_attack":
		instance.call("_resolve_enemy_round")
	else:
		instance.call("_on_card_pressed", 0)
		instance.call("_on_board_tile_clicked", PLAYER_TILE)
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if str((instance.get("_run_state") as Dictionary).get("mode", "")) == "defeat" and not bool(instance.get("_animation_lock")):
			break
		await process_frame
	var mode: String = str((instance.get("_run_state") as Dictionary).get("mode", ""))
	var locked: bool = bool(instance.get("_animation_lock"))
	var clock_locked: bool = bool(instance.get("_turn_order_animating"))
	_expect(mode == "defeat" and not locked and not clock_locked,
		"%s should finish death: mode=%s animation_lock=%s turn_order_animating=%s music=%s" % [case_name, mode, locked, clock_locked, instance.get("_active_music_id")])
	var recap: Control = instance.get("_run_end_recap") as Control
	_expect(recap != null and recap.visible, case_name + " should open the defeat recap through the live resolution path")
	if mode == "defeat" and recap != null and recap.visible:
		# Let the actual reveal run; do not seek or install a terminal snapshot.
		await create_timer(float(recap.call("presentation_duration")) + 0.1).timeout
		var button: Button = recap.find_child("MainMenuButton", true, false) as Button
		_expect(button != null and button.is_visible_in_tree() and not button.disabled, case_name + " should expose an enabled Main Menu action")
		if button != null:
			button.grab_focus()
			_expect(button.has_focus(), case_name + " should allow keyboard/controller focus on the recap")
		_expect(int(instance.get("_selected_card_index")) == -1, case_name + " should clear selected-card targeting")
		_expect((instance.get("_committed_run_state_override") as Dictionary).is_empty(), case_name + " should release the held commit")
		_expect(not ProgressionStore.has_saved_run(), case_name + " should clear the terminal save")
		var progression_after_death: Dictionary = ProgressionStore.load_data()
		instance.call("_refresh_ui")
		instance.call("_refresh_ui")
		_expect(ProgressionStore.load_data() == progression_after_death, case_name + " should not duplicate terminal progression on refresh")
	await _capture(case_name + "_after.png")
	if mode == "defeat" and recap != null and recap.visible:
		var button: Button = recap.find_child("MainMenuButton", true, false) as Button
		if button != null:
			button.pressed.emit()
		# CursorFeedback intentionally delays scene replacement to show its loading
		# cue. Wait for that real transition, not an arbitrary number of frames.
		var menu_deadline: int = Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < menu_deadline:
			if current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn":
				break
			await process_frame
		_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn", case_name + " should return to the Main Menu when its action is activated")
		await process_frame
		await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	await process_frame


func _assert_mixed_removal_fixture(instance: Node, before_state: Dictionary) -> void:
	var engine := CombatEngine.new()
	var action: Dictionary = GameData.card_def("whirlwind_slash").get("actions", [])[0]
	var after_state: Dictionary = engine.apply_player_action(before_state, action, PLAYER_TILE)
	_expect(int(after_state["player"]["hp"]) <= 0 and int(after_state["enemies"][0]["hp"]) <= 0,
		"Mixed fixture must kill both actors with the actual AOE/trap rules")
	var before_order: Array = instance.call("_turn_order_entries_from_state", before_state)
	var after_order: Array = instance.call("_turn_order_entries_from_state", after_state)
	var defeated: Dictionary = instance.call("_turn_order_defeated_actor_keys", before_state, after_state)
	var styles: Array[String] = []
	for index: int in instance.call("_turn_order_removed_indices", before_order, after_order):
		var actor_key: String = instance.call("_turn_order_actor_key", before_order[index])
		styles.append(instance.call("_turn_order_removal_style", actor_key, defeated))
	_expect(styles.has("slide") and styles.has("shadow_dissolve"),
		"Mixed fixture must exercise concurrent short slide and long dissolve removals")


func _combat_state(case_name: String) -> Dictionary:
	var engine := CombatEngine.new()
	var state: Dictionary = engine.create_combat(94301, _layout(case_name), {
		"hp": 1, "max_hp": 24, "deck_cards": ["whirlwind_slash"], "hand_size": 1, "relics": []
	})
	state["deck"]["hand"] = ["whirlwind_slash"]
	state["deck"]["draw"] = []
	state["deck"]["discard"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["umbra"]["radius"] = 99
	state["cards_played_this_turn"] = 0
	if case_name == "enemy_attack":
		# Give the adjacent crawler an authored attack and schedule enough spent
		# player Time that Pass must actually yield to its activation.
		state["player_turn_time_spent"] = 20
		for intent: Dictionary in GameData.enemy_def("crawler").get("intents", []):
			if str(intent.get("id", "")) == "lunge":
				state["enemies"][0]["intent"] = intent.duplicate(true)
	return state


func _layout(case_name: String) -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var traps: Array = []
	if case_name != "enemy_attack":
		traps.append({"id": "lethal_probe", "pos": TRAP_TILE, "element": "fire", "damage": 4, "base_damage": 4, "armed": true})
	var enemy_hp: int = 100 if case_name in ["card_player_only", "enemy_attack"] else 1
	return {
		"name": "Death Transition Probe", "coord": Vector2i(4, 1), "type": "combat", "element": "fire", "grid": grid,
		"player_start": PLAYER_TILE,
		"enemies": [{"id": 1, "type": "crawler", "pos": ENEMY_TILE, "hp": enemy_hp, "max_hp": enemy_hp, "block": 0}],
		"traps": traps, "terrain": [], "loot": []
	}


func _capture(file_name: String) -> void:
	if not _capture_enabled:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	# Native Metal can expose a Retina backing texture for the 1920x1080
	# logical viewport, as in the existing run-end recap probe.
	if screenshot.get_size() != Vector2i(1920, 1080):
		screenshot.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var error: Error = screenshot.save_png(OUTPUT_DIR + "/" + file_name)
	_expect(error == OK, "Capture should save " + file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
