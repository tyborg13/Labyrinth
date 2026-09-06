extends RefCounted
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/board_surface_rules.gd")

static func run(expect: Callable) -> void:
	var engine: CombatEngine = CombatEngine.new()
	var state: Dictionary = fixture(engine)
	Rules.place(state, Vector2i(3, 3), "fire")
	Rules.place(state, Vector2i(3, 3), "rubble")
	expect.call(Rules.element_at(state, Vector2i(3, 3)) == "fire" and Rules.has_rubble(state, Vector2i(3, 3)), "Two independent layers coexist")
	var revision: int = state["surface_revision"]
	Rules.place(state, Vector2i(3, 3), "fire")
	expect.call(state["surface_revision"] == revision, "Identical repaint has no event or contact")
	Rules.place(state, Vector2i(3, 3), "ice")
	expect.call(Rules.element_at(state, Vector2i(3, 3)) == "ice" and Rules.has_rubble(state, Vector2i(3, 3)), "Element replacement preserves Rubble")
	# Creation does not contact; actual entry and activation do.
	state = fixture(engine)
	Rules.place(state, Vector2i(2, 3), "fire")
	expect.call(int(state["player"]["hp"]) == 1000, "Fire painting beneath player does not deal damage")
	state["player"]["pos"] = Vector2i(3, 3)
	Rules.place(state, Vector2i(3, 3), "fire")
	state = engine.surface_actor_arrival(state, "player", -1, Vector2i(2, 3))
	expect.call(int(state["player"]["hp"]) == 1000 - GameData.fixed_point_amount(1), "Each newly entered burning tile deals one")
	state = engine._resolve_player_start_of_turn(state)
	expect.call(int(state["player"]["hp"]) == 1000 - GameData.fixed_point_amount(3), "Fire own start deals two once")
	# Ice arrival gives Chilled; an Ice hit consumes support and freezes once.
	state = fixture(engine)
	Rules.place(state, Vector2i(4, 3), "ice")
	expect.call(not bool(state["enemies"][0].get("chilled", false)), "Ice painting does not Chill")
	state = engine.surface_actor_arrival(state, "enemy", 1, Vector2i(4, 2))
	expect.call(bool(state["enemies"][0].get("chilled", false)), "Ice entry activates Chill")
	state = engine.apply_player_action(state, {"type":"ranged", "damage":20, "range":5, "element":"ice"}, Vector2i(4, 3))
	expect.call(int(state["enemies"][0]["hp"]) == 1000 - 20 - GameData.fixed_point_amount(1), "Pre-hit Chill adds one natural direct damage")
	expect.call(int(state["enemies"][0]["freeze"]) == 1 and Rules.element_at(state, Vector2i(4, 3)).is_empty(), "Ice hit freezes and consumes Ice")
	Rules.place(state, Vector2i(4, 3), "ice")
	var turn: Dictionary = engine._resolve_enemy_start_of_turn(state, 0)
	state = turn["state"]
	expect.call(bool(turn["skip_all"]) and not bool(state["enemies"][0].get("chilled", false)), "Frozen skipped start suppresses Ice reactivation")
	# Connected Lightning does not cross an air gap; native Chain may.
	state = fixture(engine)
	state["enemies"].append(enemy(2, Vector2i(6, 3)))
	state["enemies"].append(enemy(3, Vector2i(6, 5)))
	for tile: Vector2i in [Vector2i(4,3),Vector2i(5,3),Vector2i(6,3),Vector2i(5,2),Vector2i(6,5)]:
		Rules.place(state,tile,"electrified")
	state = engine.apply_player_action(state, {"type":"ranged", "damage":20, "range":5, "element":"lightning"}, Vector2i(4,3))
	expect.call(int(state["enemies"][0]["hp"]) == 980 and int(state["enemies"][1]["hp"]) == 980 and int(state["enemies"][2]["hp"]) == 1000, "Ordinary Lightning hits cardinal component once, no air gap")
	expect.call(Rules.tiles(state,"electrified").size() == 1, "Discharge consumes empty component branches as well")
	state = fixture(engine)
	state["enemies"].append(enemy(2,Vector2i(7,3)))
	Rules.place(state,Vector2i(5,3),"electrified")
	Rules.place(state,Vector2i(6,3),"electrified")
	state = engine.apply_player_action(state,{"type":"ranged","damage":20,"range":5,"element":"none","chain":1},Vector2i(4,3))
	expect.call(int(state["enemies"][1]["hp"]) == 980 and Rules.tiles(state,"electrified").is_empty(), "Neutral Chain1 can relay multiple hops without target cap")
	# Atomic Detonate union includes the player, ignores overlapping blasts.
	state = fixture(engine)
	state["player"]["pos"] = Vector2i(3,3)
	Rules.place(state,Vector2i(3,3),"fire")
	Rules.place(state,Vector2i(4,3),"fire")
	state = engine.apply_player_action(state,{"type":"detonate","damage":60,"range":4,"pattern":[[0,0],[1,0]],"rotate":false},Vector2i(3,3))
	expect.call(int(state["player"]["hp"]) == 940 and int(state["enemies"][0]["hp"]) == 940, "Detonate shared union damages each actor only once")
	expect.call(Rules.tiles(state,"fire").is_empty(), "Detonate consumes selected fuel atomically")
	# Weighted movement and minimum progress are allowance-scoped.
	state = fixture(engine)
	Rules.place(state,Vector2i(3,3),"rubble")
	var path: Array[Vector2i]
	path.assign([Vector2i(2,3),Vector2i(3,3)])
	expect.call(engine.movement_cost_for_path(state,path,1,true) == 1 and engine.movement_cost_for_path(state,path,1,false) == 2, "Fresh allowance minimum progress does not reset per click")
	state["player_movement_remaining"] = 1
	expect.call(not engine.player_movement_targets(state).has(Vector2i(3,3)), "Spent movement allowance cannot enter Rubble with last point")
	# Traps hit the center, then place four disjoint wake tiles.
	state = fixture(engine)
	state["traps"] = [{"pos":Vector2i(4,3),"element":"lightning","damage":30}]
	state = engine._trigger_trap_at_index(state,0)
	expect.call(int(state["enemies"][0]["hp"]) == 970 and int(state["player"]["hp"]) == 1000, "Trap direct damage only affects center occupant")
	expect.call(Rules.tiles(state,"electrified").size() == 4 and Rules.element_at(state,Vector2i(4,3)).is_empty(), "Trap wake is cardinal and excludes center")
	# Revealed fuel is exact, denied fuel cannot silently pick another tile.
	state = fixture(engine)
	Rules.place(state,Vector2i(4,4),"electrified")
	var intent: Dictionary = engine._surface_prepare_enemy_intent(state,state["enemies"][0],{"surface_fuel":{"surface":"electrified","range":1,"action_bonuses":{"0":{"shock":1}}},"actions":[{"type":"ranged","damage":20}]})
	Rules.remove(state,Vector2i(4,4),"electrified","test")
	Rules.place(state,Vector2i(5,3),"electrified")
	intent = engine._surface_pay_enemy_fuel(state,state["enemies"][0],intent)
	expect.call(bool(intent.get("_surface_fuel_denied",false)) and not (intent["actions"][0] as Dictionary).has("shock"), "Enemy fuel denial preserves baseline and does not substitute nearby fuel")

	_test_large_actors_and_sources(engine, expect)
	_test_enemy_and_trace_integration(engine, expect)
	_test_event_tail_and_illusion_contact(engine, expect)
	_test_real_card_source_survives_saved_ground(engine, expect)
	_test_dynamic_movement_allowance(engine, expect)

static func _test_large_actors_and_sources(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["enemies"][0]["footprint"] = Vector2i(2,2)
	state["enemies"][0]["pos"] = Vector2i(5,3)
	for tile: Vector2i in [Vector2i(6,3),Vector2i(6,4)]:
		Rules.place(state,tile,"fire")
		Rules.place(state,tile,"rubble")
	state = engine.surface_actor_arrival(state,"enemy",1,Vector2i(4,3))
	expect.call(int(state["enemies"][0]["hp"]) == 1000-GameData.fixed_point_amount(1), "Large actor entering two Fire tiles receives one hazard per step")
	expect.call(Rules.entry_cost(state,state["enemies"][0],Vector2i(4,3),Vector2i(5,3)) == 2,"Large actor Rubble cost is maximum newly entered tile cost")
	for tile: Vector2i in [Vector2i(5,3),Vector2i(6,4)]:
		Rules.place(state,tile,"ice")
	state = engine.surface_actor_arrival(state,"enemy",1,Vector2i(4,3))
	state = engine.apply_player_action(state,{"type":"ranged","damage":20,"range":8,"element":"ice"},Vector2i(5,3))
	expect.call(int(state["enemies"][0]["freeze"]) == 1 and Rules.tiles(state,"ice").is_empty(),"Freezing a large actor consumes every supporting Ice tile")
	state = fixture(engine)
	state["enemies"][0]["hp"] = GameData.fixed_point_amount(1)
	state["enemies"][0]["pos"] = Vector2i(5,3)
	state["damage_context"] = {"source_kind":"direct_attack","player_card":true}
	Rules.place(state,Vector2i(5,3),"fire")
	state = engine.surface_actor_arrival(state,"enemy",1,Vector2i(4,3))
	expect.call(int(state.get("death_bonus_card_plays_this_turn",0)) == 1,"Card-caused Fire arrival kill grants one ordinary play")
	var death: Dictionary = {}
	for event: Dictionary in state.get("surface_events",[]):
		if str(event.get("kind","")) == "actor_death":
			death = event
	expect.call(str(death.get("source_kind","")) == "surface_fire" and bool(death.get("player_card",false)),"Lethal source preserves Fire vs direct attack and causal card credit")
	state = fixture(engine)
	state["enemies"][0]["hp"] = GameData.fixed_point_amount(1)
	Rules.place(state,Vector2i(4,3),"fire")
	state = engine._resolve_enemy_start_of_turn(state,0)["state"]
	expect.call(int(state.get("death_bonus_card_plays_this_turn",0)) == 0 and int(state.get("pending_relic_card_plays",0)) == 0,"Passive enemy-start Fire kill creates no future card play")
	state = fixture(engine)
	state["player"]["pos"] = Vector2i(3,3)
	state["enemies"].append(enemy(2,Vector2i(4,4)))
	state["traps"] = [{"id":"air_trap","pos":Vector2i(4,3),"element":"air","damage":30}]
	state = engine._trigger_trap_at_index(state,0)
	expect.call(state["enemies"][0]["pos"] == Vector2i(4,3) and state["player"]["pos"] == Vector2i(2,3) and state["enemies"][1]["pos"] == Vector2i(4,5),"Air trap keeps center occupant and pushes cardinal neighbors outward")
	state = fixture(engine)
	state["objective"] = {"type":"kill_leader"}
	state["enemies"][0]["is_leader"] = true
	state["enemies"][0]["hp"] = 30
	var follower: Dictionary = enemy(2,Vector2i(5,3))
	follower["hp"] = 30
	state["enemies"].append(follower)
	Rules.place(state,Vector2i(4,3),"fire")
	state = engine.apply_player_action(state,{"type":"detonate","damage":60,"range":5},Vector2i(4,3))
	expect.call((state.get("death_rewards",[]) as Array).size() == 2,"Detonate resolves all victims before leader-clear bookkeeping")

static func _test_enemy_and_trace_integration(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	state["enemies"].append(enemy(2,Vector2i(4,4)))
	Rules.place(state,Vector2i(4,3),"electrified")
	state = engine.apply_player_action(state,{"type":"aoe","damage":20,"range":5,"pattern":[[0,0],[0,1]],"rotate":false,"element":"lightning","surface_bonus":{"surface":"electrified","subject":"consumed","shock":1}},Vector2i(4,3))
	expect.call(int(state["enemies"][0]["shock"]) == 1 and int(state["enemies"][1].get("shock",0)) == 0,"Specialist Shock only applies to electrically assisted victims")
	state = fixture(engine)
	state["enemies"].append(enemy(2,Vector2i(6,4)))
	for tile: Vector2i in [Vector2i(4,3),Vector2i(5,3),Vector2i(5,4),Vector2i(6,4)]:
		Rules.place(state,tile,"electrified")
	var result: Dictionary = engine.resolve_player_action_for_presentation(state,{"type":"ranged","damage":20,"range":5,"element":"lightning"},Vector2i(4,3))
	var routed: bool = false
	for hit: Dictionary in result.get("chain_hits",[]):
		if str(hit.get("kind","")) != "conduction":
			continue
		var path: Array = hit.get("path",[])
		routed = path.size() == 4
		for index: int in range(1,path.size()):
			routed = routed and (absi(path[index].x-path[index-1].x)+absi(path[index].y-path[index-1].y) == 1)
	expect.call(routed,"Conduction presentation follows actual cardinal surface path")
	state = fixture(engine)
	state["enemies"][0]["pos"] = Vector2i(7,3)
	for x: int in range(2,7):
		Rules.place(state,Vector2i(x,3),"electrified")
	var shot: Dictionary = {"type":"ranged","damage":20,"range":1,"element":"lightning"}
	expect.call(engine._enemy_action_reaches_target(state,state["enemies"][0],shot,{"kind":"player","pos":Vector2i(2,3)}),"Enemy Lightning recognizes a reachable network impact beyond direct target range")
	state = engine._resolve_enemy_action(state,0,shot)
	expect.call(int(state["player"]["hp"]) == 980 and Rules.tiles(state,"electrified").is_empty(),"Enemy ordinary Lightning uses and consumes the same connected network")

	state = fixture(engine)
	state["enemies"].append(enemy(2,Vector2i(7,3)))
	for tile: Vector2i in [Vector2i(3,3),Vector2i(5,3),Vector2i(6,3)]:
		Rules.place(state,tile,"electrified")
	state = engine.apply_player_action(state,{"type":"ranged","range":5,"damage":20,"element":"none","chain":1},Vector2i(4,3))
	expect.call(int(state["enemies"][1]["hp"]) == 980 and Rules.element_at(state,Vector2i(3,3)) == "electrified","Chain rejects nearby dead-end relay and consumes only useful route")
	state = fixture(engine)
	state["enemies"].append(enemy(2,Vector2i(6,3)))
	Rules.place(state,Vector2i(5,3),"electrified")
	state = engine.apply_player_action(state,{"type":"ranged","range":5,"damage":20,"element":"none","chain":2},Vector2i(4,3))
	expect.call(int(state["enemies"][1]["hp"]) == 980 and Rules.element_at(state,Vector2i(5,3)) == "electrified","Chain prefers a direct valid hop over spending unnecessary relay")

static func fixture(engine: CombatEngine) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String]
		for x: int in range(10):
			row.append("wall" if x==0 or y==0 or x==9 or y==8 else "stone")
		grid.append(row)
	var room: Dictionary = {"name":"Surface Test","coord":Vector2i(1,0),"depth":1,"type":"combat","grid":grid,"player_start":Vector2i(2,3),"enemies":[enemy(1,Vector2i(4,3))],"loot":[],"traps":[]}
	return engine.create_combat(501,room,{"hp":1000,"max_hp":1000,"deck_cards":["quick_stab","brace","brace"],"skill_ids":[],"relics":[],"hand_size":1,"heal_bonus":0})

static func enemy(id: int, tile: Vector2i) -> Dictionary:
	return {"id":id,"type":"crawler","pos":tile,"hp":1000,"max_hp":1000,"block":0,"stoneskin":0}

static func _test_event_tail_and_illusion_contact(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	var before: Dictionary = state.duplicate(true)
	state = engine.apply_player_action(state, {"type": "surface", "surface": "fire", "range": 4}, Vector2i(3, 3))
	state = engine.apply_player_action(state, {"type": "block", "amount": 2})
	expect.call(engine._surface_events_since(before, state).size() == 1, "A multi-action card's later utility must not erase its earlier surface event")
	state = fixture(engine)
	state["illusions"] = [{"id": 10, "pos": Vector2i(3, 4), "hp": 100, "max_hp": 100}]
	Rules.place(state, Vector2i(3, 4), "ice")
	state = engine.surface_actor_arrival(state, "illusion", 10, Vector2i(3, 5))
	var target: Dictionary = {"kind": "illusion", "id": 10, "pos": Vector2i(3, 4)}
	state = engine._damage_actor_target(state, target, 3, false, {"type": "ranged", "element": "ice"})
	state = engine._apply_action_keywords_to_target(state, target, {"type": "ranged", "element": "ice", "damage": 3}, Vector2i(4, 3))
	expect.call(int(state["illusions"][0]["hp"]) == 97 - GameData.fixed_point_amount(1), "Ice-supported illusions share Chilled direct-damage vulnerability")
	expect.call(int(state["illusions"][0].get("freeze", 0)) == 1 and Rules.element_at(state, Vector2i(3, 4)).is_empty(), "An Ice hit on a chilled illusion consumes its supporting Ice")

static func _test_real_card_source_survives_saved_ground(engine: CombatEngine, expect: Callable) -> void:
	var state: Dictionary = fixture(engine)
	var card_id: String = "cinder_fusillade"
	state["deck"]["hand"] = [card_id]
	var actions: Array = engine.card_play_actions(card_id, state)
	expect.call(actions.size() == 2, "Real Flurry source fixture expands the two available card plays")
	var total_damage: int = 0
	for action: Dictionary in actions:
		expect.call(str(action.get("_card_id", "")) == card_id, "Every expanded Flurry action keeps its stable card ID")
		total_damage += int(action.get("damage", 0))
	state["enemies"][0]["hp"] = total_damage + GameData.fixed_point_amount(2)
	for action: Dictionary in actions:
		state = engine.apply_player_action(state, action, Vector2i(4, 3))
	state = engine.finish_player_card(state, 0, engine.card_plays_spent_for_actions(actions))
	expect.call(str(Rules.surface_at(state, Vector2i(4, 3)).get("elemental_source", {}).get("card_id", "")) == card_id, "Real card resolution stores the creator's card ID on persistent Fire")
	# Variant serialization is the same representation used by encounter saves.
	var restored: Dictionary = bytes_to_var(var_to_bytes(state)) as Dictionary
	var before: Dictionary = restored.duplicate(true)
	var phase: Dictionary = engine._resolve_enemy_start_of_turn(restored, 0)
	var after: Dictionary = phase["state"]
	var saw_fire: bool = false
	var saw_death: bool = false
	for event: Dictionary in engine._surface_events_since(before, after):
		if str(event.get("kind", "")) == "surface_damage":
			saw_fire = str(event.get("source", {}).get("card_id", "")) == card_id and not bool(event.get("source", {}).get("player_card", true))
		if str(event.get("kind", "")) == "actor_death":
			saw_death = str(event.get("source", {}).get("card_id", "")) == card_id and str(event.get("source_kind", "")) == "surface_fire"
	expect.call(saw_fire and saw_death, "Saved Fire keeps its painter card attribution in later passive damage and death events")
	expect.call(int(after.get("death_bonus_card_plays_this_turn", 0)) == 0, "Remembering a card ID never makes a passive Fire kill refund a play")
	state = fixture(engine)
	state["enemies"][0]["hp"] = 1
	var basic_action: Dictionary = engine.card_play_actions("quick_stab", state)[0]
	state["player"]["pos"] = Vector2i(3, 3)
	state = engine.apply_player_action(state, basic_action, Vector2i(4, 3))
	var basic_attributed: bool = false
	for event: Dictionary in state.get("surface_events", []):
		if str(event.get("kind", "")) == "actor_death":
			basic_attributed = str(event.get("source", {}).get("card_id", "")) == "quick_stab"
	expect.call(basic_attributed, "Ordinary starter-card direct kills use the same central attribution")
	var raw_action: Dictionary = {"type": "surface", "surface": "fire", "range": 4}
	state = engine.apply_player_action(fixture(engine), raw_action, Vector2i(4, 3))
	expect.call(not raw_action.has("_card_id") and str(Rules.surface_at(state, Vector2i(4, 3)).get("elemental_source", {}).get("card_id", "")).is_empty(), "Anonymous action APIs do not acquire a fabricated or stale card identity")
	expect.call(not (GameData.card_def(card_id).get("actions", [])[0] as Dictionary).has("_card_id"), "Runtime attribution does not mutate the shared card definition")


static func _test_dynamic_movement_allowance(engine: CombatEngine, expect: Callable) -> void:
	var initial: Dictionary = fixture(engine)
	initial["enemies"][0]["pos"] = Vector2i(7, 3)
	initial["relics"] = ["pilgrim_boots"]
	initial["player_movement_capacity"] = 3
	initial["player_movement_remaining"] = 3
	initial["traps"] = [{"id": "ground_changes_cost", "pos": Vector2i(3, 3), "element": "earth", "damage": 0}]
	var player_result: Dictionary = engine.apply_player_movement(initial, Vector2i(4, 3))
	expect.call(player_result["player"]["pos"] == Vector2i(4, 3) and int(player_result["last_player_movement"]["spent"]) == 3, "Walk charges the actual increased cost of Rubble painted earlier in the same request")
	var card_result: Dictionary = engine.apply_player_action(initial, {"type": "move", "range": 2}, Vector2i(4, 3))
	expect.call(card_result["player"]["pos"] == Vector2i(3, 3), "Card movement stops before a trap-created Rubble step that exceeds its allowance")
	var enemy_initial: Dictionary = fixture(engine)
	enemy_initial["enemies"][0]["pos"] = Vector2i(4, 3)
	enemy_initial["traps"] = [{"id": "enemy_ground_changes_cost", "pos": Vector2i(5, 3), "element": "earth", "damage": 0}]
	var path: Array[Vector2i]
	path.assign([Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)])
	var context: Dictionary = {}
	var enemy_result: Dictionary = engine._move_enemy_along_planned_path(enemy_initial.duplicate(true), 0, path, context, 2)
	expect.call(enemy_result["enemies"][0]["pos"] == Vector2i(5, 3) and int(context["movement_spent"]) == 1, "Enemy walking stops before newly painted Rubble beyond its remaining allowance")
	context = {}
	enemy_result = engine._move_enemy_along_planned_path(enemy_initial.duplicate(true), 0, path, context, 3)
	expect.call(enemy_result["enemies"][0]["pos"] == Vector2i(6, 3) and int(context["movement_spent"]) == 3, "Enemy walking spends the same actual changing-ground costs as player movement")
