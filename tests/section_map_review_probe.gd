extends "res://tests/section_map_flow_probe.gd"
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RouteFixture = preload("res://tools/guardian_inspection.gd")
const FOG_FIXTURE_SECTION: int = 5
const PICKUP_FIXTURE_RANGE: int = 99

func _initialize() -> void:
	output_dir = "user://section_map_review_v4"
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
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
	_check(engine.is_dragon_reward(state), "Actual first-boss route reaches its dragon reward")
	state["pending_reward"]["intro_pending"] = false
	_load(state)
	await process_frame
	await process_frame
	var panel: Control = instance.get("_large_map_view")
	var scrim: Control = instance.get("_large_map_scrim")
	var reward_button: Button = instance.find_child("DragonRewardContinue", true, false)
	_check(reward_button != null and not scrim.visible, "Dragon reward precedes automatic descent without a map step")
	await _capture("01_dragon_reward.png")
	await _pointer_click(reward_button.get_global_rect().get_center())
	var transition: Node = instance.get("_section_transition")
	_check(transition != null and not scrim.visible, "Reward acknowledgment starts the automatic transition")
	if transition == null:
		quit(1)
		return
	transition.set_process(false)
	transition.advance(maxf(0.0, 0.3 - float(transition.get("elapsed"))))
	await _capture("02_automatic_descent.png")
	transition.advance(1.5 - float(transition.get("elapsed")))
	_check(not scrim.visible and root.get_node("CursorFeedback").call("glyph_visibility_suppressed"), "Only the title card is visible; the map and cursor glyph are suppressed")
	await _capture("03_transition_title.png")
	var next_entry: Vector2i = Graph.section(state, 1).get("entry")
	transition.advance(3.2 - float(transition.get("elapsed")))
	await process_frame
	await process_frame
	_check((instance.get("_run_state") as Dictionary).get("current_room") == next_entry, "Automatic arrival enters the exact next threshold")
	_check(scrim.visible and int(panel.get("viewed_section")) == 1, "The new section map opens after automatic arrival")
	await _capture("04_second_section.png")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var history_tab: Button = (panel.get("_tabs") as HBoxContainer).get_child(0)
	await _pointer_click(history_tab.get_global_rect().get_center())
	_check(int(panel.get("viewed_section")) == 0 and instance.get("_run_state")["current_room"] == next_entry, "Clicking a bronze section tab opens completed history without travel")
	var route_choices_before: int = _route_choices(instance.get("_run_state"))
	var scouts_before: int = int(Graph.section(instance.get("_run_state"), 1).get("scouts", 0))
	var historical_boss: Control = (panel.get("node_buttons") as Dictionary)[state["current_room"]]
	await _pointer_click(historical_boss.get_global_rect().get_center())
	_check(instance.get("_run_state")["current_room"] == next_entry and _route_choices(instance.get("_run_state")) == route_choices_before and int(Graph.section(instance.get("_run_state"), 1).get("scouts", 0)) == scouts_before, "History node activation only inspects; it cannot travel or spend active-section Scout uses")
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

	# Select a generated two-choice fork instead of assuming a fixed route step.
	# Keep the original two-choice assertion and all navigation checks intact.
	state = engine.create_new_run(90429, Progression.default_data())
	for room: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(room.get("section_index", -1)) != 0 or str(room.get("type", "")) not in ["combat", "guardian"]: continue
		if (room.get("connections", []) as Array).size() != 2: continue
		var fork_coord: Vector2i = room["coord"]
		if not RouteFixture._mark_route(state, Vector2i.ZERO, fork_coord): continue
		state["current_room"] = fork_coord
		state["current_room_layout"] = engine._display_layout_for_room(90429, room, Vector2i.RIGHT)
		Graph.refresh_knowledge(state)
		break
	_load(state)
	await process_frame
	await process_frame
	var choices: Array = panel.call("available_destinations")
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ((panel.get("node_buttons") as Dictionary)[a] as Control).position.y < ((panel.get("node_buttons") as Dictionary)[b] as Control).position.y)
	_check(choices.size() == 2, "Choice navigation fixture reaches a neighboring-lane fork")
	if choices.size() != 2:
		quit(1)
		return
	router.call("set_forced_state_for_test", "controller", "xbox")
	var first: Control = (panel.get("node_buttons") as Dictionary)[choices[0]]
	first.grab_focus()
	for choice_index: int in range(1, choices.size()):
		await _joy(JOY_BUTTON_DPAD_DOWN)
		_check(viewport.gui_get_focus_owner() == (panel.get("node_buttons") as Dictionary)[choices[choice_index]], "Controller Down moves directly between immediate choices")
	await _capture("05c_available_navigation.png")

	await _key(KEY_DOWN)
	_check(viewport.gui_get_focus_owner() == panel.get("_scout"), "The choice list leads to Scout without trapping focus")
	await _key(KEY_UP)
	_check(viewport.gui_get_focus_owner() == (panel.get("node_buttons") as Dictionary)[choices.back()], "Scout returns focus to the nearest available choice")
	router.call("set_forced_state_for_test", "pointer", "xbox")

	# Revision 5 reveals Sections I-V completely. Exercise the original recovery
	# fog assertions in Section VI, where the production fog rule still applies.
	var baseline: Dictionary = engine.create_new_run(81, Progression.default_data())
	var target: Vector2i = Graph.INVALID
	for room: Dictionary in (baseline.get("rooms", {}) as Dictionary).values():
		if int(room.get("section_index", -1)) == FOG_FIXTURE_SECTION and int(room.get("map_step", 0)) >= 8 and str(room.get("type", "")) == "combat":
			target = room.get("coord")
			break
	_check(target != Graph.INVALID, "Recovery fixture locates a distant generated encounter")
	var progression: Dictionary = Progression.prepare_for_new_run(Progression.default_data())
	progression = Progression.record_lost_embers(progression, 23, target, int(progression.get("run_counter", 0)))
	progression = Progression.prepare_for_new_run(progression)
	state = engine.create_new_run(81, progression)
	var fog_entry: Vector2i = Graph.section(state, FOG_FIXTURE_SECTION)["entry"]
	for index: int in range(FOG_FIXTURE_SECTION):
		var prior: Dictionary = Graph.section(state, index)
		_check(RouteFixture._mark_route(state, prior["entry"], prior["boss"]), "Recovery fixture preserves a real completed path in each prior section")
		prior["entered"] = true
	_check(RouteFixture._mark_route(state, fog_entry, fog_entry), "Recovery fixture reaches the section with production fog")
	state["current_room"] = fog_entry
	state["current_room_layout"] = engine._display_layout_for_room(81, Graph.room(state, fog_entry), Vector2i.RIGHT)
	Graph.refresh_knowledge(state)
	_load(state)
	instance.call("_open_large_map")
	_check(not bool(Graph.room(state, target).get("revealed", false)), "Recovery presence does not reveal the unknown encounter identity")
	_check((panel.get("node_buttons") as Dictionary).has(target), "The distant recovery landmark is rendered through fog")
	var recovery_button: Control = (panel.get("node_buttons") as Dictionary).get(target)
	_check(bool(recovery_button.call("has_recovery")) and str(panel.call("room_description", target)).contains("23 lost Embers"), "Recovery badge retains the exact lost-Ember amount in focus/hover details")
	await process_frame
	await process_frame
	panel.call("select_room", target)
	_check(str(panel.get("_preview_text")).contains("23 lost Embers"), "Inspecting the pile explains the recovery amount")
	await _capture("06_recovery_distant.png")
	_check(Progression.save_run_state(state), "Recovery fixture saves before discovery")
	state = engine.repair_loaded_run_state(Progression.load_saved_run())
	_load(state)
	instance.call("_open_large_map")
	_check((panel.get("node_buttons") as Dictionary).has(target), "Recovery landmark survives a saved-run reload")
	await process_frame
	await process_frame
	panel.call("select_room", target)
	await _capture("07_recovery_resumed.png")
	var fork: Dictionary = {}
	for room: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(room.get("section_index", -1)) != FOG_FIXTURE_SECTION: continue
		var keeps: bool = false
		var leaves: bool = false
		for link: Dictionary in room.get("connections", []):
			if Graph.descendants(state, link.get("coord")).has(target): keeps = true
			else: leaves = true
		if keeps and leaves:
			fork = room
			break
	_check(not fork.is_empty(), "Neighboring branches still make the recovery route consequential")
	if not fork.is_empty():
		state["current_room"] = fork.get("coord")
		fork["visited"] = true
		fork["cleared"] = true
		Graph.refresh_knowledge(state)
		_load(state)
		instance.call("_open_large_map")
		for link: Dictionary in fork.get("connections", []):
			var choice: Vector2i = link.get("coord")
			var description: String = panel.call("room_description", choice)
			_check(description.split("\n").size() == 2 and not description.contains("Keeps:") and not description.contains("Leaves:") and not description.contains("Next:"), "Recovery route previews remain a compact room name and state")
		await process_frame
		await process_frame
		panel.call("select_room", target)
		await _capture("08_recovery_routes.png")
	state["current_room"] = target
	Graph.room(state, target)["visited"] = true
	Graph.refresh_knowledge(state)
	state["mode"] = "pre_battle"
	state["pre_battle_travel_dir"] = Vector2i.RIGHT
	state = engine.begin_pre_battle_combat(state)
	var combat: Dictionary = state.get("combat_state", {})
	# Isolate pickup behavior from Section VI's initiative and sight rules.
	combat["current_actor"] = {"kind": "player", "key": "player"}
	combat["umbra"]["vision_bonus"] = PICKUP_FIXTURE_RANGE
	for loot: Dictionary in combat.get("loot", []):
		if str(loot.get("kind", "")) == "dropped_embers":
			var action: Dictionary = {"type": "blink", "range": PICKUP_FIXTURE_RANGE}
			_check(CombatEngine.new().valid_targets_for_player_action(combat, action).has(loot.get("pos")), "Recovery fixture has a legal production pickup action")
			combat = CombatEngine.new().apply_player_action(combat, action, loot.get("pos"))
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
	print("SECTION MAP REVIEW PROBE: " + ("FAIL" if failed else "PASS"))
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
			"reward":
				if engine.is_dragon_reward(state): return state
				state = engine.skip_reward_for_heal(state) if str(state.get("pending_reward", {}).get("kind", "")) == "event" else engine.claim_card_reward(state, "")
			"escape": state = engine.continue_pending_escape(state)
			"campfire": state = engine.leave_campfire(state)
			"event": state = engine.resolve_map_event(state, "continue" if str(state.get("event_state", {}).get("page", "choices")) == "result" else EventRules.first_available_choice_id(state))
			"treasure":
				var relics: Array = state.get("pending_relics", [])
				if not relics.is_empty(): state = engine.claim_relic(state, str(relics[0]))
			_: return state
	return state
