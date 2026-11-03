extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const BoardSurfaces = preload("res://scripts/board_surface_rules.gd")
const PLAYER_TILE := Vector2i(2, 4)
const ENEMY_TILE := Vector2i(3, 4)
const TRAP_TILE := Vector2i(2, 3)
const OUTPUT_DIR := "user://death_transition_v1"
const RAIL_LIFETIME_RUN_SEED: int = 94301
# The old Whirlwind fixture relied on adjacent trap blast damage. Rules v5
# (0cc1ac028b) replaced that blast with ground placement. Detonate still hits
# every actor in its cross: 4 damage exceeds the card's 2 Block and our 1 HP.
const LETHAL_CARD_ID: String = "cinder_second"
const TEARDOWN_SETTLE_FRAMES: int = 32
const SHARED_TILE_RUN_SEED: int = 101
const SHARED_TILE_HERO := Vector2i(5, 3)
const SHARED_TILE_DESTINATION := Vector2i(5, 2)
const SHARED_TILE_ENEMY_ID: int = 2

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
	if DisplayServer.get_name() == "headless":
		# Logical enemy/death playback awaits a submitted draw boundary. This
		# mirrors the headless hunt and never produces renderer/capture proof.
		process_frame.connect(_headless_draw_boundary)
	call_deferred("_run")


func _run() -> void:
	var cases: Array[String] = ["card_mixed", "card_player_only", "movement", "enemy_attack", "card_mixed_reduced"]
	cases.append("shared_tile")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var case_index: int = args.find("--case")
	if case_index >= 0 and case_index + 1 < args.size():
		cases.clear()
		cases.append(args[case_index + 1])
	if args.has("--rail-lifetimes-only"):
		cases.clear()
	await _run_animation_lifetime_cases()
	for case_name: String in cases:
		await _run_case(case_name)
	# Let deferred renderer/resource releases drain after the last scene exits.
	for frame: int in range(TEARDOWN_SETTLE_FRAMES):
		await process_frame
	for failure: String in _failures:
		push_error(failure)
	print("DEATH TRANSITION TEST: %s (%d cases)" % ["PASS" if _failures.is_empty() else "FAIL", cases.size()])
	if _capture_enabled:
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _failures.is_empty() else 1)


func _run_animation_lifetime_cases() -> void:
	ProgressionStore.clear_saved_run()
	ProgressionStore.save_data(ProgressionStore.default_data())
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(instance)
	current_scene = instance
	await process_frame
	var state: Dictionary = _combat_state("card_mixed")
	var run_state: Dictionary = RunEngine.new().create_new_run(RAIL_LIFETIME_RUN_SEED, ProgressionStore.default_data())
	run_state["mode"] = "combat"
	run_state["current_room"] = Vector2i(4, 1)
	run_state["current_room_layout"] = _layout("card_mixed")
	run_state["combat_state"] = state
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await process_frame
	var failures_before: int = _failures.size()
	await preload("res://tests/suites/turn_order_lifetime_suite.gd").run(self, instance, _expect)
	print("TURN ORDER LIFETIME TEST: %s" % ("PASS" if _failures.size() == failures_before else "FAIL"))
	failures_before = _failures.size()
	preload("res://tests/suites/animation_submission_suite.gd").run(instance, _expect)
	print("ANIMATION STATE SUBMISSION TEST: %s" % ("PASS" if _failures.size() == failures_before else "FAIL"))
	instance.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _run_case(case_name: String) -> void:
	if case_name == "shared_tile":
		await _run_shared_tile_movement_case()
		return
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
		instance.call("_on_board_tile_clicked", ENEMY_TILE)
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
	print("DEATH TRANSITION STATE: %s mode=%s hp=%s animation_lock=%s turn_order_animating=%s recap=%s" % [case_name, mode, (instance.get("_run_state") as Dictionary).get("player_hp"), locked, clock_locked, recap != null and recap.visible])
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


func _run_shared_tile_movement_case() -> void:
	# Seed 101's stalled hero and Grub 2 shared (5,3), with movement left but no
	# card plays. Also cover ordinary enemies and illusions: priority is the
	# hero's tile, not an exception for burrowed enemies.
	var failures_before: int = _failures.size()
	var router: Node = root.get_node("InputRouter")
	for input_case: String in ["pointer", "controller", "keyboard_card", "other_enemy", "illusion", "pointer_exhausted", "controller_exhausted"]:
		router.call("set_forced_state_for_test", "pointer", "steam_deck")
		ProgressionStore.clear_saved_run()
		ProgressionStore.save_data(ProgressionStore.default_data())
		var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(instance)
		current_scene = instance
		await process_frame
		var run_state: Dictionary = _shared_tile_run_state(input_case)
		var state: Dictionary = run_state["combat_state"]
		var engine := CombatEngine.new()
		var exhausted: bool = input_case.ends_with("_exhausted")
		_expect(engine.player_movement_remaining(state) == 0 if exhausted else engine.player_movement_targets(state).has(SHARED_TILE_DESTINATION), input_case + " fixture has the requested movement budget")
		if input_case != "keyboard_card":
			_expect(engine.cards_remaining_this_turn(state) == 0, input_case + " fixture cannot rely on a card to escape")
		instance.call("_load_run_state", run_state)
		instance.call("_close_dialogue")
		await process_frame
		await process_frame
		var board: Node = instance.get("board_view")
		if input_case == "pointer":
			instance.call("_on_board_tile_hovered", SHARED_TILE_HERO)
			await process_frame
			_expect(bool(instance.call("_hovered_tile_has_visible_enemy", SHARED_TILE_HERO)) and not str(board.call("enemy_intent_tooltip", "enemy_2")).is_empty(), "Shared-tile hover retains the Grub's information")
			await _capture("shared_tile_hover.png")
			var rail_found: bool = false
			for slot: Node in (instance.get("_turn_order_bar") as Node).get_children():
				if str(slot.get_meta("turn_order_actor_key", "")) != "enemy:enemy_2": continue
				rail_found = true
				slot.mouse_entered.emit()
				_expect((board.get("presentation").get("focus_actor_keys", []) as Array).has("enemy_2"), "Turn-order strip can still focus the sharing Grub")
				await _capture("shared_tile_rail.png")
				slot.mouse_exited.emit()
				break
			_expect(rail_found, "Sharing Grub retains its turn-order strip entry")
		var destination: Vector2i = SHARED_TILE_DESTINATION
		if input_case == "keyboard_card":
			# Keyboard's existing movement entry is Move/Blink card targeting.
			await instance.call("_on_card_pressed", 0)
			instance.call("_controller_set_board_tile", SHARED_TILE_HERO)
			var direction := InputEventKey.new()
			direction.keycode = KEY_UP
			direction.pressed = true
			await instance.call("_input", direction)
			destination = instance.get("_controller_board_tile")
			_expect(destination != SHARED_TILE_HERO and (instance.get("_pending_target_tiles") as Array).has(destination), "Keyboard selects a legal Move destination from the shared tile")
			var accept := InputEventKey.new()
			accept.keycode = KEY_ENTER
			accept.pressed = true
			await instance.call("_input", accept)
		else:
			if input_case.begins_with("controller"):
				router.call("set_forced_state_for_test", "controller", "steam_deck")
				instance.call("_controller_enter_board", false)
				var accept := InputEventJoypadButton.new()
				accept.button_index = JOY_BUTTON_A
				accept.pressed = true
				await instance.call("_input", accept)
			else:
				await instance.call("_on_board_tile_clicked", SHARED_TILE_HERO)
			if exhausted:
				var inspected: bool = not bool(instance.get("_player_movement_selected")) and int(instance.get("_focused_intent_enemy_id")) == SHARED_TILE_ENEMY_ID
				_expect(inspected and (board.get("presentation").get("expanded_enemy_actor_keys", []) as Array).has("enemy_2"), input_case + " opens the sharing Grub's detailed intent when movement is exhausted")
				if input_case.begins_with("controller"):
					_expect(str(instance.get("_controller_region")) == "board", "Exhausted controller inspection keeps focus on the board")
				print("SHARED TILE INSPECTION: %s detailed_intent=%s region=%s" % [input_case, inspected, instance.get("_controller_region")])
				instance.queue_free()
				current_scene = null
				await process_frame
				await process_frame
				continue
			_expect(bool(instance.get("_player_movement_selected")) and int(instance.get("_focused_intent_enemy_id")) == -1, input_case + " hero-tile selection must choose movement before a sharing unit")
			if input_case == "pointer": await _capture("shared_tile_selected.png")
			if input_case == "controller":
				instance.call("_controller_set_board_tile", destination)
				var accept := InputEventJoypadButton.new()
				accept.button_index = JOY_BUTTON_A
				accept.pressed = true
				await instance.call("_input", accept)
			else:
				await instance.call("_on_board_tile_clicked", destination)
		var after_state: Dictionary = instance.get("_combat_state")
		var moved: bool = after_state.get("player", {}).get("pos") == destination
		_expect(moved and not bool(instance.get("_animation_lock")), input_case + " must leave the shared tile through the normal movement path")
		print("SHARED TILE INPUT: %s moved=%s position=%s animation_lock=%s" % [input_case, moved, after_state.get("player", {}).get("pos"), instance.get("_animation_lock")])
		if input_case == "pointer": await _capture("shared_tile_moved.png")
		instance.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	router.call("clear_forced_state_for_test")
	print("SHARED TILE MOVEMENT TEST: %s" % ("PASS" if _failures.size() == failures_before else "FAIL"))


func _shared_tile_run_state(input_case: String) -> Dictionary:
	var layout: Dictionary = _layout("enemy_attack")
	layout["player_start"] = SHARED_TILE_HERO
	var enemy: Dictionary = layout["enemies"][0]
	enemy["id"] = SHARED_TILE_ENEMY_ID
	enemy["type"] = "burrow_grub" if input_case != "other_enemy" else "crawler"
	enemy["pos"] = ENEMY_TILE if input_case == "illusion" else SHARED_TILE_HERO
	var engine := CombatEngine.new()
	var state: Dictionary = engine.create_combat(SHARED_TILE_RUN_SEED, layout, {
		"hp": 24, "max_hp": 24, "deck_cards": ["guarded_step" if input_case == "keyboard_card" else "brace"], "hand_size": 1, "relics": []
	})
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["umbra"]["radius"] = 99
	state["cards_played_this_turn"] = 0 if input_case == "keyboard_card" else engine.cards_remaining_this_turn(state)
	if input_case.ends_with("_exhausted"):
		state["player_movement_remaining"] = 0
	if input_case != "other_enemy":
		state["enemies"][0]["burrowed"] = true
		state["enemies"][0]["erupt_tile"] = SHARED_TILE_HERO + Vector2i.DOWN
		state["enemies"][0]["intent"] = GameData.enemy_def("burrow_grub")["intents"][1].duplicate(true)
	if input_case == "illusion":
		state["illusions"] = [{"id": 1, "pos": SHARED_TILE_HERO, "hp": 4, "max_hp": 4}]
	var run_state: Dictionary = RunEngine.new().create_new_run(SHARED_TILE_RUN_SEED, ProgressionStore.default_data())
	run_state["mode"] = "combat"
	run_state["current_room"] = layout["coord"]
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	return run_state


func _assert_mixed_removal_fixture(instance: Node, before_state: Dictionary) -> void:
	var engine := CombatEngine.new()
	var after_state: Dictionary = engine.prepare_player_card(before_state, 0)
	for action: Dictionary in GameData.card_def(LETHAL_CARD_ID).get("actions", []):
		after_state = engine.apply_player_action(after_state, action, ENEMY_TILE)
		if engine.combat_outcome(after_state) == "defeat": break
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
		"hp": 1, "max_hp": 24, "deck_cards": [LETHAL_CARD_ID], "hand_size": 1, "relics": []
	})
	state["deck"]["hand"] = [LETHAL_CARD_ID]
	state["deck"]["draw"] = []
	state["deck"]["discard"] = []
	if case_name != "enemy_attack" and case_name != "movement":
		BoardSurfaces.place(state, ENEMY_TILE, "fire")
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
		traps.append({"id": "lethal_probe", "pos": TRAP_TILE if case_name == "movement" else ENEMY_TILE, "element": "fire", "damage": 4, "base_damage": 4, "armed": true})
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


func _headless_draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()
