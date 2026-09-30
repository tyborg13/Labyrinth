extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Host = preload("res://tests/card_targeting_audit_host.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var combat := CombatEngine.new()
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	instance.set_script(Host)
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	var rows: Array = []
	var upgrade_count: int = 0
	for id: String in GameData.cards():
		var state: Dictionary = state_for(combat, id)
		var actions: Array = combat.card_play_actions(id, state)
		_assert_one_decision(combat, actions, id, expect)
		for option: Dictionary in GameData.upgrade_options_for_element(id, {"kind":"action", "key":"action:new"}, {}):
			var upgraded: Dictionary = GameData.card_def_with_card_mods(id, {id:[option]})
			_assert_one_decision(combat, upgraded["actions"], "%s + %s" % [id,option["label"]], expect)
			upgrade_count += 1
		_install(instance, state)
		var preview: Dictionary = instance.call("_card_preview_for_index", 0)
		expect.call(bool(preview.get("playable",false)), "%s audit fixture supplies a usable card" % id)
		if not bool(preview.get("playable",false)): continue
		await instance.call("_on_card_pressed", 0)
		expect.call(int(instance.get("_selected_card_index")) == 0, "%s selects directly" % id)
		expect.call(instance.get("_combat_state") == state, "%s selection does not commit automatic prefix effects" % id)
		expect.call(not bool(instance.call("_current_action_can_skip")), "%s never offers Skip Step" % id)
		var tracker: Control = instance.get("_action_step_tracker")
		expect.call((instance.get("_action_step_tracker_steps") as Node).get_child_count() == 0, "%s never builds numbered steps" % id)
		for child: Node in (instance.get("_action_context_command_bar") as Node).get_children():
			expect.call(not (child as Button).text in ["Skip","Cancel"], "%s has no legacy selection buttons" % id)
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		right.position = Vector2(1900,1060) # HUD, outside the board GUI receiver.
		await instance.call("_input", right)
		expect.call(int(instance.get("_selected_card_index")) < 0 and instance.get("_combat_state") == state, "%s right-click cancels without cost anywhere" % id)
		await instance.call("_on_card_pressed", 0)
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		await instance.call("_input", escape)
		expect.call(int(instance.get("_selected_card_index")) < 0 and instance.get("_combat_state") == state, "%s Escape cancels without cost" % id)
		var targets: Array = (preview.get("target_tiles",[]) as Array).duplicate()
		var shortcuts: Dictionary = instance.call("_preview_shortcuts_for_current_action",preview)
		for tile: Vector2i in (shortcuts.get("plans",{}) as Dictionary):
			if not targets.has(tile): targets.append(tile)
		if bool(preview.get("complete",false)): targets = [state["player"]["pos"]]
		# Every offered target, including movement-only and combined enemy choices.
		for tile: Vector2i in targets:
			_install(instance,state)
			await instance.call("_on_card_pressed",0)
			await instance.call("_on_board_tile_clicked",tile)
			expect.call(int(instance.get("commits")) == 1 and int(instance.get("_selected_card_index")) < 0, "%s at %s completes after one board click" % [id,tile])
		rows.append({"id":id,"name":GameData.card_def(id)["name"],"actions":actions.map(func(a:Dictionary)->String:return str(a["type"])),"targets_exercised":targets.size(),"targetless":bool(preview.get("complete",false)),"shortcut_targets":(shortcuts.get("plans",{}) as Dictionary).size()})
		await tree.process_frame
	await _test_worldroot(instance, combat, expect)
	_test_force_range(combat,expect)
	instance.queue_free()
	await tree.process_frame
	var output := "user://card_targeting_audit.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"cards":rows,"card_count":rows.size(),"action_upgrade_count":upgrade_count},"\t"))
	print("CARD TARGETING AUDIT: ", rows.size(), " cards, ", upgrade_count, " upgrades; ", ProjectSettings.globalize_path(output))

static func _assert_one_decision(combat: CombatEngine, actions: Array, context: String, expect: Callable) -> void:
	var targets: Array = []
	for action: Dictionary in actions:
		if combat.player_action_needs_target(action) and not bool(action.get("reuse_previous_target",false)): targets.append(action)
	var combined: bool = targets.size() == 2 and str(targets[0]["type"]) in ["move","blink"] and str(targets[1]["type"]) in ["melee","ranged","push","pull"] and bool(targets[1].get("required",false))
	expect.call(targets.size() <= 1 or combined, "%s must expose at most one decision (or a supported one-click approach)" % context)

static func state_for(combat: CombatEngine, id: String) -> Dictionary:
	var state: Dictionary = Fixture._combat_state(combat,id,Vector2i(3,4),20260929)
	state["player"]["hp"] = 12
	state["player"]["max_hp"] = 24
	state["player"]["stoneskin"] = 8
	state["enemies"].append({"id":2,"type":"crawler","pos":Vector2i(4,4),"hp":100,"max_hp":100})
	state["enemies"].append({"id":3,"type":"crawler","pos":Vector2i(2,2),"hp":100,"max_hp":100})
	# A diagonal neighbor lets diagonal-only sweeps (Sweeping Haft) find a target.
	state["enemies"].append({"id":4,"type":"crawler","pos":Vector2i(3,5),"hp":100,"max_hp":100})
	state["deck"] = {"hand":[id,"brace"],"draw":["brace","brace","brace"],"discard":[],"burned":[],"cycles":0}
	state["current_actor"] = {"kind":"player","key":"player"}
	state["cards_played_this_turn"] = 0
	state["umbra"] = combat.call("_initial_umbra_state",Fixture._live_combat_layout("clear",Vector2i(3,4)))
	state.erase("player_turn_restrictions")
	for tile: Vector2i in [Vector2i(2,4),Vector2i(3,4),Vector2i(4,4),Vector2i(3,3),Vector2i(2,3)]:
		state = Surface.place(state,tile,"fire")
	return state

static func _install(instance: Node, state: Dictionary) -> void:
	instance.call("_reset_card_resolution")
	instance.set("commits",0)
	instance.set("_dialogue_active",false)
	instance.set("_animation_lock",false)
	instance.set("_guided_tutorial_phase_id","")
	instance.set("_combat_state",state.duplicate(true))
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = instance.get("_combat_state")
	run["current_room_layout"] = Fixture._live_combat_layout("clear",Vector2i(3,4))
	instance.set("_run_state",run)
	instance.call("_mark_combat_preview_state_changed")

static func _test_force_range(combat: CombatEngine, expect: Callable) -> void:
	for id: String in GameData.cards():
		for action: Dictionary in GameData.card_def(id)["actions"]:
			if not str(action["type"]) in ["push","pull"] or int(action.get("damage",0)) <= 0: continue
			for distance: int in range(1,int(action.get("range",1))+2):
				var tile := Vector2i(2+distance,4)
				var state: Dictionary = Fixture._combat_state(combat,id,tile,20260929)
				var in_range: bool = distance <= int(action.get("range",1))
				expect.call(combat.valid_targets_for_player_action(state,action).has(tile) == in_range,"%s accepts distances 1..range, rejects range+1 (distance %d)" % [id,distance])
				if in_range:
					var after: Dictionary = combat.apply_player_action(state,action,tile)
					expect.call(int(after["enemies"][0]["hp"]) < 100,"%s hits even when force cannot displace an adjacent target" % id)
	var blocked: Dictionary = Fixture._combat_state(combat,"gust_step",Vector2i(3,4),1)
	expect.call(not combat.valid_targets_for_player_action(blocked,{"type":"pull","amount":2,"range":2,"damage":0}).has(Vector2i(3,4)),"A zero-damage Pull on an adjacent enemy does nothing and stays illegal")
	expect.call(combat.valid_targets_for_player_action(blocked,{"type":"push","amount":2,"range":2,"damage":0}).has(Vector2i(3,4)),"A zero-damage Push that moves or collides is a legal target")
	blocked["grid"][4][3] = "wall"
	blocked["enemies"][0]["pos"] = Vector2i(4,4)
	expect.call(not combat.valid_targets_for_player_action(blocked,{"type":"pull","amount":2,"range":2,"damage":3}).has(Vector2i(4,4)),"Damage does not bypass line of sight")

static func _test_worldroot(instance: Node, combat: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = state_for(combat, "quick_stab")
	state["relics"] = ["worldroot_idol"]
	state["enemies"] = [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 100, "max_hp": 100}]
	for x: int in range(2, 5): Surface.place(state, Vector2i(x, 4), "rubble")
	_install(instance, state)
	await instance.call("_on_card_pressed", 0)
	var action: Dictionary = {"type": "melee", "damage": 3, "range": 1, "_surface_relic_modes": ["remote"]}
	instance.call("_select_surface_relic_variant", action)
	var target := Vector2i(5, 4)
	expect.call((instance.get("_pending_target_tiles") as Array).has(target), "Worldroot offers the enemy without an origin pick")
	expect.call(combat.action_with_automatic_origin(state, action, target).get("_origin_tile") == Vector2i(4, 4), "Worldroot chooses a connected legal origin deterministically")
	var forecast: Dictionary = combat.surface_preview_for_player_action(state, action, target)["state"]
	expect.call(int(forecast["enemies"][0]["hp"]) == 97 and not Surface.has_rubble(forecast, Vector2i(4, 4)), "Worldroot preview includes hit and origin payment")
	await instance.call("_on_board_cancel_requested")
	expect.call(instance.get("_combat_state") == state and int(instance.get("_selected_card_index")) < 0, "Worldroot cancels without paying Rubble")
	await instance.call("_on_card_pressed", 0)
	instance.call("_select_surface_relic_variant", action)
	await instance.call("_on_board_tile_clicked", target)
	var result: Dictionary = instance.get("committed_result")
	expect.call(int(instance.get("commits")) == 1 and int(instance.get("_selected_card_index")) < 0, "Worldroot completes with one enemy click")
	expect.call(int(result["enemies"][0]["hp"]) == 97 and not Surface.has_rubble(result, Vector2i(4, 4)), "Worldroot committed hit/payment match preview")
	var rejected: Dictionary = state.duplicate(true)
	Surface.remove(rejected, Vector2i(3, 4), "rubble", "test")
	expect.call(not combat.valid_targets_for_player_action(rejected, action).has(target), "Disconnected Worldroot origins cannot extend reach")
	expect.call(combat.apply_player_action(rejected, action, target) == rejected, "Invalid Worldroot cannot spend or hit")
