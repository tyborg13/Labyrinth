extends "res://tests/section_map_flow_probe.gd"
const CombatEngine = preload("res://scripts/combat_engine.gd")

func _initialize() -> void:
	output_dir = "user://section_map_review_v3"
	await _setup()
	var engine := RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(90429, Progression.default_data())
	# Resolve a real route through the first boss so the next section transition
	# and subsequent history inspect the same persisted gameplay state.
	for step: int in range(20):
		state = _resolve_room(engine, state)
		if str(Graph.room(state, state.get("current_room")).get("type", "")) == "boss": break
		var moves: Array = engine.available_moves(state)
		if moves.is_empty(): break
		state = engine.move_to_room(state, moves[0])
	_check(str(state.get("mode", "")) == "room" and str(Graph.room(state, state.get("current_room")).get("type", "")) == "boss", "Actual first boss route resolves all encounters and rewards")
	_load(state)
	await process_frame
	await process_frame
	var panel: Control = instance.get("_large_map_view")
	var scrim: Control = instance.get("_large_map_scrim")
	var enter: Button = panel.get("_continue")
	panel.call("select_room", state.get("current_room"))
	_check(enter.text == "Next section" and not enter.disabled, "Inspecting the defeated boss preserves the onward action")
	await _capture("01_boss_inspected.png")
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	_check(enter.text == "Next section" and not enter.disabled, "Reopening the boss map preserves the onward action")
	await _capture("02_boss_reopened.png")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	panel.call("focus_controller_on_current")
	_check(viewport.gui_get_focus_owner() == enter, "Controller focus starts on Next section")
	await _capture("03_next_section_controller.png")
	var next_entry: Vector2i = Graph.section(state, 1).get("entry")
	await _joy(JOY_BUTTON_A)
	# Room travel owns a timed board transition; wait for the actual committed
	# state rather than a renderer-dependent count of fast probe frames.
	for tick: int in range(100):
		if (instance.get("_run_state") as Dictionary).get("current_room") == next_entry and not bool(instance.get("_animation_lock")):
			break
		await create_timer(0.05).timeout
	await process_frame
	await process_frame
	_check((instance.get("_run_state") as Dictionary).get("current_room") == next_entry, "Controller activation enters the exact next threshold")
	_check(scrim.visible and int(panel.get("viewed_section")) == 1, "The next section map opens after the transition")
	await _capture("04_second_section.png")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var history_tab: Button = (panel.get("_tabs") as HBoxContainer).get_child(0)
	await _pointer_click(history_tab.get_global_rect().get_center())
	_check(int(panel.get("viewed_section")) == 0 and enter.disabled, "Clicking a bronze section tab opens completed history without travel")
	await _capture("05_completed_history.png")
	router.call("set_forced_state_for_test", "controller", "xbox")
	var active_tab: Button = (panel.get("_tabs") as HBoxContainer).get_child(1)
	active_tab.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(int(panel.get("viewed_section")) == 1, "Controller activation returns to the active section tab")
	_check(viewport.gui_get_focus_owner() == (panel.get("_tabs") as HBoxContainer).get_child(1), "Tab focus survives the section refresh")
	await _capture("05b_section_tab_focus.png")
	history_tab = (panel.get("_tabs") as HBoxContainer).get_child(0)
	history_tab.grab_focus()
	await _key(KEY_ENTER)
	_check(int(panel.get("viewed_section")) == 0 and viewport.gui_get_focus_owner() == (panel.get("_tabs") as HBoxContainer).get_child(0), "Keyboard activation also preserves history-tab focus")
	router.call("set_forced_state_for_test", "pointer", "xbox")

	# Three-way choice navigation follows the immediate options in screen order.
	state = engine.create_new_run(90429, Progression.default_data())
	for step: int in range(3):
		state = _resolve_room(engine, state)
		state = engine.move_to_room(state, engine.available_moves(state)[0])
	state = _resolve_room(engine, state)
	_load(state)
	await process_frame
	await process_frame
	var choices: Array = panel.call("available_destinations")
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((panel.get("node_buttons") as Dictionary)[a] as Control).position.y < ((panel.get("node_buttons") as Dictionary)[b] as Control).position.y)
	_check(choices.size() == 3, "Choice navigation fixture reaches the three-way fork")
	router.call("set_forced_state_for_test", "controller", "xbox")
	var first: Control = (panel.get("node_buttons") as Dictionary)[choices[0]]
	first.grab_focus()
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_check(viewport.gui_get_focus_owner() == (panel.get("node_buttons") as Dictionary)[choices[1]], "Controller Down moves directly between immediate choices")
	await _capture("05c_available_navigation.png")
	await _key(KEY_DOWN)
	_check(viewport.gui_get_focus_owner() == (panel.get("node_buttons") as Dictionary)[choices[2]], "Keyboard Down follows the next immediate choice")
	await _key(KEY_DOWN)
	_check(viewport.gui_get_focus_owner() == panel.get("_scout"), "The choice list leads to Scout without trapping focus")
	await _key(KEY_UP)
	_check(viewport.gui_get_focus_owner() == (panel.get("node_buttons") as Dictionary)[choices[2]], "Scout returns focus to the nearest available choice")
	router.call("set_forced_state_for_test", "pointer", "xbox")

	# A distant recoverable pile is visible without revealing its room identity.
	var baseline: Dictionary = engine.create_new_run(81, Progression.default_data())
	var target: Vector2i = Graph.INVALID
	for room: Dictionary in (baseline.get("rooms", {}) as Dictionary).values():
		if int(room.get("section_index", -1)) == 0 and int(room.get("map_step", 0)) >= 8 and str(room.get("type", "")) == "combat":
			target = room.get("coord")
			break
	_check(target != Graph.INVALID, "Recovery fixture locates a distant generated encounter")
	var progression: Dictionary = Progression.prepare_for_new_run(Progression.default_data())
	progression = Progression.record_lost_embers(progression, 23, target, int(progression.get("run_counter", 0)))
	progression = Progression.prepare_for_new_run(progression)
	state = engine.create_new_run(81, progression)
	_load(state)
	instance.call("_open_large_map")
	_check(not bool(Graph.room(state, target).get("revealed", false)), "Recovery presence does not reveal the unknown encounter identity")
	_check((panel.get("node_buttons") as Dictionary).has(target), "The distant recovery landmark is rendered through fog")
	var recovery_button: Control = (panel.get("node_buttons") as Dictionary).get(target)
	_check(bool(recovery_button.call("has_recovery")) and str(panel.call("room_description", target)).contains("23 lost Embers"), "Recovery badge retains the exact lost-Ember amount in focus/hover details")
	panel.call("select_room", target)
	_check(str(panel.get("_preview_text")).contains("23 lost Embers"), "Inspecting the pile explains the recovery amount")
	await _capture("06_recovery_distant.png")
	_check(Progression.save_run_state(state), "Recovery fixture saves before discovery")
	state = engine.repair_loaded_run_state(Progression.load_saved_run())
	_load(state)
	instance.call("_open_large_map")
	_check((panel.get("node_buttons") as Dictionary).has(target), "Recovery landmark survives a saved-run reload")
	panel.call("select_room", target)
	await _capture("07_recovery_resumed.png")
	var fork: Dictionary = {}
	for room: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(room.get("section_index", -1)) == 0 and int(room.get("map_step", 0)) == 6:
			fork = room
			break
	state["current_room"] = fork.get("coord")
	fork["visited"] = true
	fork["cleared"] = true
	Graph.refresh_knowledge(state)
	_load(state)
	instance.call("_open_large_map")
	var found_keeps: bool = false
	var found_leaves: bool = false
	for link: Dictionary in fork.get("connections", []):
		var choice: Vector2i = link.get("coord")
		panel.call("select_room", choice)
		var description: String = str(panel.get("_preview_text"))
		_check(not description.contains("Event"), "Branch consequences omit the Event landmark already bypassed before this fork")
		if Graph.descendants(state, choice).has(target):
			found_keeps = description.contains("Keeps:") and description.contains("23 lost Embers")
		else:
			found_leaves = description.contains("Leaves:") and description.contains("23 lost Embers")
			await _capture("08_recovery_branch_warning.png")
	_check(found_keeps and found_leaves, "Branch previews distinguish keeping and abandoning the recoverable pile")
	state["current_room"] = target
	state["mode"] = "pre_battle"
	state["pre_battle_travel_dir"] = Vector2i.RIGHT
	state = engine.begin_pre_battle_combat(state)
	var combat: Dictionary = state.get("combat_state", {})
	for loot: Dictionary in combat.get("loot", []):
		if str(loot.get("kind", "")) == "dropped_embers":
			combat = CombatEngine.new().apply_player_action(combat, {"type": "blink", "range": 99}, loot.get("pos"))
			break
	state = engine.set_combat_state(state, combat)
	_check(engine.held_embers(state) == 23, "Actual recovery pickup awards the exact lost amount")
	_load(state)
	instance.call("_open_large_map")
	recovery_button = (panel.get("node_buttons") as Dictionary).get(target)
	_check(not bool(recovery_button.call("has_recovery")), "Collected recovery marker disappears")
	await _capture("09_recovery_collected.png")

	state = engine.create_new_run(90429, Progression.default_data())
	for step: int in range(10):
		state = _resolve_room(engine, state)
		if str(Graph.room(state, state.get("current_room")).get("type", "")) == "scavenger": break
		state = engine.move_to_room(state, engine.available_moves(state)[0])
	_load(state)
	await process_frame
	await process_frame
	_check(not scrim.visible and bool(instance.get("_merchant_shop_open")), "The Scavenger shop retains priority on room entry")
	await _capture("10_scavenger_shop.png")
	instance.call("_on_merchant_hide_pressed")
	await process_frame
	await process_frame
	_check(scrim.visible, "Leaving the Scavenger shop opens room selection")
	await _capture("11_scavenger_leave_map.png")
	await _key(KEY_ESCAPE)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	_check(not scrim.visible, "Closing the post-shop map is respected during refresh")
	await _capture("12_scavenger_map_closed.png")
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(output_dir))
	quit(1 if failed else 0)

func _resolve_room(engine: RunEngineScript, source: Dictionary) -> Dictionary:
	var state: Dictionary = source
	for step: int in range(20):
		match str(state.get("mode", "")):
			"pre_battle": state = engine.begin_pre_battle_combat(state)
			"combat":
				var combat: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
				for enemy: Dictionary in combat.get("enemies", []): enemy["hp"] = 0
				var objective: Dictionary = combat.get("objective", {})
				if str(objective.get("type", "")) == Objectives.SURVIVE:
					combat["initiative_clock"] = int(objective.get("target_clock", 0))
				if str(objective.get("type", "")) == Objectives.REACH_EXIT:
					var tiles: Array[Vector2i] = Objectives.exit_target_tiles(objective)
					if not tiles.is_empty(): (combat.get("player", {}) as Dictionary)["pos"] = tiles[0]
				state = engine.finish_combat(state, combat)
			"reward": state = engine.claim_card_reward(state, "")
			"escape": state = engine.continue_pending_escape(state)
			"campfire": state = engine.leave_campfire(state)
			"event": state = engine.resolve_map_event(state, "embers")
			"treasure":
				var relics: Array = state.get("pending_relics", [])
				if not relics.is_empty(): state = engine.claim_relic(state, str(relics[0]))
			_: return state
	return state
