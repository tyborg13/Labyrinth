extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const Relics = preload("res://scripts/surface_relic_rules.gd")

static func run(expect: Callable) -> void:
	var combat: Combat = Combat.new()
	_test_large_ice_trap_arrival(combat, expect)
	_test_detonate_trap_event(combat, expect)
	_test_hidden_conductive_bridge(combat, expect)
	_test_mid_move_rubble_cost(combat, expect)
	_test_hidden_aoe_chain_head(combat, expect)
	_test_atomic_lethal_outcome(combat, expect)
	_test_invalid_paid_technique(combat, expect)
	_test_authored_specialist_shock_fuel(combat, expect)
	_test_enemy_attack_route_survival(combat, expect)

static func _test_large_ice_trap_arrival(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["enemies"][0]["footprint"] = Vector2i(2, 2)
	state["enemies"][0]["pos"] = Vector2i(4, 3)
	state["traps"] = [{"id": "new_ice_wake", "pos": Vector2i(5, 3), "element": "ice", "damage": 10}]
	state = combat.surface_actor_arrival(state, "enemy", 1, Vector2i(3, 3))
	expect.call((state["traps"] as Array).is_empty() and Ground.element_at(state, Vector2i(5, 4)) == "ice", "Large actor fixture enters the Ice trap and receives its new wake beneath its footprint")
	expect.call(not bool(state["enemies"][0].get("chilled", false)), "Large actor entering an Ice trap must not gain Chill from the newly painted wake during that same arrival")
	state = (combat._resolve_enemy_start_of_turn(state, 0) as Dictionary)["state"]
	expect.call(bool(state["enemies"][0].get("chilled", false)), "The large actor's next start activates Chill from the Ice trap wake")

static func _test_detonate_trap_event(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["enemies"][0]["pos"] = Vector2i(5, 3)
	state["traps"] = [{"id": "detonate_target", "pos": Vector2i(5, 3), "element": "fire", "damage": 10}]
	Ground.place(state, Vector2i(4, 3), "fire")
	state = combat.apply_player_action(state, {"type": "detonate", "damage": 20, "range": 5, "element": "fire"}, Vector2i(4, 3))
	var triggers: int = 0
	for event: Dictionary in state.get("surface_events", []):
		if str(event.get("kind", "")) == "trap_triggered":
			triggers += 1
	expect.call((state["traps"] as Array).is_empty() and triggers == 1, "Direct Detonate triggers a trap in its blast exactly once")
	expect.call(int(state["enemies"][0]["hp"]) == 970, "Detonate's target takes the printed hit plus the triggered trap's center hit, with no wake contact damage")
	expect.call(Ground.element_at(state, Vector2i(4, 3)) == "fire", "The trap may repaint already-consumed Detonate fuel without recursively exploding it")

static func _test_hidden_conductive_bridge(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["umbra"]["stage"] = "heart"
	state["umbra"]["light_sources"] = [{"pos": Vector2i(4, 3), "radius": 1, "duration": 3}, {"pos": Vector2i(8, 3), "radius": 0, "duration": 3}]
	state["enemies"].append(Base.enemy(2, Vector2i(8, 3)))
	for x: int in range(5, 9):
		Ground.place(state, Vector2i(x, 3), "electrified")
	expect.call(combat.is_tile_visible_to_player(state, Vector2i(5, 3)) and not combat.is_tile_visible_to_player(state, Vector2i(6, 3)) and combat.is_enemy_visible_to_player(state, state["enemies"][1]), "Visibility fixture has two lit islands separated by hidden conducting ground")
	var disconnected: Dictionary = state.duplicate(true)
	Ground.remove(disconnected, Vector2i(6, 3), "electrified", "test")
	var action: Dictionary = {"type": "ranged", "damage": 20, "range": 5, "element": "lightning", "chain": 1}
	var result: Dictionary = combat.resolve_player_action_for_presentation(state, action, Vector2i(4, 3))
	var separate: Dictionary = combat.resolve_player_action_for_presentation(disconnected, action, Vector2i(4, 3))
	expect.call(_route(result) == _route(separate), "Adding a hidden conductive bridge must not alter the visible Chain preview route")
	expect.call(Ground.element_at(result["state"], Vector2i(5, 3)) == "electrified", "A relay useful only through hidden ground must not be spent as a visible dead end")
	expect.call(int(result["state"]["enemies"][1]["hp"]) == 1000, "The distant lit enemy remains unreachable through hidden conducting ground")

static func _route(result: Dictionary) -> Array:
	var route: Array = []
	for hit: Dictionary in result.get("chain_hits", []):
		route.append({"kind": hit.get("kind", ""), "from": hit.get("from"), "to": hit.get("to"), "enemy_id": hit.get("enemy_id", -1)})
	return route

static func _test_mid_move_rubble_cost(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["enemies"][0]["pos"] = Vector2i(7, 3)
	state["traps"] = [{"id": "movement_earth", "pos": Vector2i(3, 3), "element": "earth", "damage": 0}]
	# The two-step request initially fits. Its first step creates Rubble on the
	# second step, so remaining allowance must be checked against the changed board.
	var grouped: Dictionary = combat.apply_player_movement(state, Vector2i(4, 3))
	var split: Dictionary = combat.apply_player_movement(state, Vector2i(3, 3))
	split = combat.apply_player_movement(split, Vector2i(4, 3))
	expect.call(grouped["player"]["pos"] == split["player"]["pos"] and grouped["player_movement_remaining"] == split["player_movement_remaining"], "A trap creating Rubble mid-move must cost the same for one movement request and split clicks")
	expect.call(grouped["player"]["pos"] == Vector2i(3, 3) and int(grouped["player_movement_remaining"]) == 1, "The already-spent two-point pool must stop before a newly created two-cost Rubble step")

static func _test_hidden_aoe_chain_head(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["umbra"]["stage"] = "heart"
	state["umbra"]["light_sources"] = [{"pos": Vector2i(5, 3), "radius": 0, "duration": 3}, {"pos": Vector2i(7, 3), "radius": 0, "duration": 3}]
	state["enemies"].append(Base.enemy(2, Vector2i(6, 3)))
	state["enemies"].append(Base.enemy(3, Vector2i(7, 3)))
	expect.call(not combat.is_enemy_visible_to_player(state, state["enemies"][1]) and combat.is_enemy_visible_to_player(state, state["enemies"][2]), "AOE Chain fixture has a hidden footprint occupant and a separate lit enemy")
	var action: Dictionary = {"type": "aoe", "damage": 20, "range": 6, "pattern": [[0, 0], [1, 0], [2, 0]], "rotate": false, "element": "lightning", "chain": 1}
	var result: Dictionary = combat.resolve_player_action_for_presentation(state, action, Vector2i(5, 3))
	expect.call(int(result["state"]["enemies"][1]["hp"]) == 980, "Ordinary AOE footprint still damages its hidden occupant without exposing it")
	expect.call(int(result["state"]["enemies"][2]["hp"]) == 1000, "An unseen AOE victim must not become a Chain head to reach a separate lit enemy")
	var exposes_hidden: bool = false
	for hit: Dictionary in result.get("chain_hits", []):
		if int(hit.get("enemy_id", -1)) == 2:
			exposes_hidden = true
	expect.call(not exposes_hidden, "A Chain presentation trace must not expose a hidden AOE victim as an actor beat")

static func _test_atomic_lethal_outcome(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["player"]["pos"] = Vector2i(3, 3)
	state["player"]["hp"] = 10
	state["enemies"][0]["hp"] = 10
	state["enemies"][0]["is_leader"] = true
	state["objective"] = {"type": "kill_leader"}
	state["relics"] = ["ember_siphon"]
	Ground.place(state, Vector2i(4, 3), "fire")
	state = combat.apply_player_action(state, {"type": "detonate", "damage": 20, "range": 5, "element": "fire"}, Vector2i(4, 3))
	expect.call(int(state["player"]["hp"]) == 0 and int(state["enemies"][0]["hp"]) == 0 and combat.combat_outcome(state) == "defeat", "An atomic self-and-leader Detonate remains defeat; death healing cannot erase the player's lethal hit")
	var deaths: Dictionary = {}
	for event: Dictionary in state.get("surface_events", []):
		if str(event.get("kind", "")) == "actor_death":
			deaths[str(event.get("actor_key", ""))] = true
	expect.call(deaths.size() == 2, "The lethal blast records both actor deaths before terminal outcome evaluation")

static func _test_invalid_paid_technique(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = Base.fixture(combat)
	state["relics"] = ["thornmail_brooch"]
	state["player"]["stoneskin"] = 4
	Relics.configure(state)
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = combat.resolve_player_action_for_presentation(state, {"type": "melee", "damage": 20, "range": 1, "_surface_relic_modes": ["cross"]}, Vector2i(8, 3))
	expect.call(result["state"] == before and state == before and (result["chain_hits"] as Array).is_empty(), "An out-of-range paid Faultline technique changes no payment, surface, combat, or preview state")

static func _test_authored_specialist_shock_fuel(combat: Combat, expect: Callable) -> void:
	var reviewed: Dictionary = {"zekarion": ["storm_claw", "skybreak", "tempest_breath"], "lightning_wisp": ["static_lash", "blinding_arc"]}
	for enemy_id: String in reviewed:
		for intent: Dictionary in GameData.enemy_def(enemy_id).get("intents", []):
			if not (reviewed[enemy_id] as Array).has(str(intent.get("id", ""))):
				continue
			for action: Dictionary in intent.get("actions", []):
				expect.call(int(action.get("shock", 0)) == 0, "%s/%s has no free baseline Shock" % [enemy_id, intent["id"]])
			if not intent.has("surface_fuel"):
				continue
			var state: Dictionary = Base.fixture(combat)
			state["enemies"][0]["type"] = enemy_id
			Ground.place(state, Vector2i(4, 3), "electrified")
			var prepared: Dictionary = combat._surface_prepare_enemy_intent(state, state["enemies"][0], intent)
			var paid_state: Dictionary = state.duplicate(true)
			var paid: Dictionary = combat._surface_pay_enemy_fuel(paid_state, paid_state["enemies"][0], prepared)
			paid_state = combat._resolve_enemy_action(paid_state, 0, paid["actions"][1])
			expect.call(int(paid_state["player"].get("shock", 0)) == 1 and Ground.element_at(paid_state, Vector2i(4, 3)).is_empty(), "%s gains exactly one Shock only after consuming its selected fuel" % enemy_id)
			Ground.remove(state, Vector2i(4, 3), "electrified", "denied_by_player")
			var denied: Dictionary = combat._surface_pay_enemy_fuel(state, state["enemies"][0], prepared)
			state = combat._resolve_enemy_action(state, 0, denied["actions"][1])
			expect.call(int(state["player"].get("shock", 0)) == 0 and int(state["player"]["hp"]) < 1000, "%s denied fuel retains its direct attack but loses all specialist Shock" % enemy_id)

static func _pursuit_fixture(combat: Combat, hp: int = 1) -> Dictionary:
	var state: Dictionary = Base.fixture(combat)
	state["enemies"][0]["hp"] = hp
	for intent: Dictionary in GameData.enemy_def("crawler")["intents"]:
		if str(intent.get("id", "")) == "skitter_strike":
			state["enemies"][0]["intent"] = intent
	Ground.place(state, Vector2i(3, 3), "fire")
	return state

static func _test_enemy_attack_route_survival(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = _pursuit_fixture(combat)
	var before: Dictionary = state.duplicate(true)
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect.call(not (plan["path"] as Array).has(Vector2i(3, 3)) and (plan["path"] as Array).size() == 4, "A one-HP crawler uses its safe three-step route to melee instead of the lethal one-step Fire route")
	expect.call(state == before, "Hazard route prediction must not damage actors, consume traps or award rewards in the live state")
	var after: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)["state"]
	expect.call(int(after["enemies"][0]["hp"]) == 1 and int(after["player"]["hp"]) < 1000, "The safe authored pursuit survives and resolves its melee attack")
	for defense: String in ["block", "stoneskin"]:
		state = _pursuit_fixture(combat)
		state["enemies"][0][defense] = 1
		plan = combat.enemy_intent_plan(state, 0)
		expect.call(plan["path"] == [Vector2i(4, 3), Vector2i(3, 3)], "Current %s makes the direct Fire route survivable and cheaper than detouring" % defense)
		# Block is deliberately tested within a live movement action: normal turn
		# start expires old Block before making its plan. Stoneskin also persists.
		var live_context: Dictionary = plan.duplicate(true)
		live_context["action_index"] = int(plan["movement_action_index"])
		after = combat._resolve_enemy_action(state, 0, {"type": "move_toward", "range": 3}, null, {}, [], live_context)
		expect.call(int(after["enemies"][0]["hp"]) == 1 and int(after["enemies"][0][defense]) == 0, "The predicted %s absorption matches actual Fire entry" % defense)
	# An unavoidable hazard stays a legal route, even when it is lethal.
	for hp: int in [1, 2]:
		state = _pursuit_fixture(combat, hp)
		for y: int in range((state["grid"] as Array).size()):
			if y != 3:
				for x: int in range((state["grid"][y] as Array).size()):
					state["grid"][y][x] = "wall"
		plan = combat.enemy_intent_plan(state, 0)
		expect.call(plan["path"] == [Vector2i(4, 3), Vector2i(3, 3)], "Unavoidable Fire never becomes an impassable AI wall")
		after = combat.resolve_enemy_turn_with_steps(state, 0)["state"]
		expect.call(int(after["enemies"][0]["hp"]) == hp - 1, "An unavoidable route resolves its actual entry damage")
	# A healthy actor can choose bounded damage over a substantially longer route.
	state = _pursuit_fixture(combat, 10)
	state["grid"][2][3] = "wall"
	state["grid"][4][3] = "wall"
	state["enemies"][0]["intent"]["actions"][0]["range"] = 7
	plan = combat.enemy_intent_plan(state, 0)
	expect.call(plan["path"] == [Vector2i(4, 3), Vector2i(3, 3)], "Finite hazard cost permits a healthy crawler's short damaging route over a long safe detour")
	# Two newly entered burning footprint tiles still deal one contact packet.
	state = _pursuit_fixture(combat, 2)
	state["enemies"][0]["footprint"] = Vector2i(2, 2)
	Ground.place(state, Vector2i(3, 4), "fire")
	var record: Dictionary = {"tile": Vector2i(3, 3), "path": [Vector2i(4, 3), Vector2i(3, 3)], "steps": 1, "trap_cost": 3}
	var prediction: Dictionary = combat._enemy_attack_route_prediction(state, state["enemies"][0], record)
	expect.call(bool(prediction["survives"]) and int(prediction["health_lost"]) == 1, "Large-body route survival predicts one Fire contact per entry step, not one per burning footprint tile")
