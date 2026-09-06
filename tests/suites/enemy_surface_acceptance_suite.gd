extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const GameData = preload("res://scripts/game_data.gd")

static func run(expect: Callable) -> void:
	var combat: Combat = Combat.new()
	_test_physical_approach(combat, expect)
	_test_ooze_denial_and_split(combat, expect)
	_test_bloomer_gaoler_angle(combat, expect)
	_test_surgeon_ice_counterplay(combat, expect)
	_test_lancer_lane(combat, expect)
	_test_worldspine_denial(combat, expect)
	_test_crownfire_shared_denial(combat, expect)
	_test_iskaldra_two_step_freeze(combat, expect)
	_test_specialist_shock_fuel(combat, expect)
	_test_electrical_opponent_sets(combat, expect)
	_test_eclipse_ground_and_air_cascade(combat, expect)

static func _state(combat: Combat, id: String) -> Dictionary:
	var state: Dictionary = Base.fixture(combat)
	state["enemies"][0]["type"] = id
	state["enemies"][0].erase("footprint")
	state["enemies"][0] = combat._normalized_enemy(state["enemies"][0])
	return state

static func _intent(combat: Combat, id: String, intent_id: String) -> Dictionary:
	for intent: Dictionary in GameData.enemy_def(id)["intents"]:
		if str(intent["id"]) == intent_id:
			return combat._scale_enemy_intent(intent, 1)
	return {}

static func _test_ooze_denial_and_split(combat: Combat, expect: Callable) -> void:
	var initial: Dictionary = _state(combat, "cinder_ooze")
	Ground.place(initial, Vector2i(4, 4), "fire")
	var prepared: Dictionary = combat._surface_prepare_enemy_intent(initial, initial["enemies"][0], _intent(combat, "cinder_ooze", "slag_shell"))
	var paid_state: Dictionary = initial.duplicate(true)
	var paid: Dictionary = combat._surface_pay_enemy_fuel(paid_state, paid_state["enemies"][0], prepared)
	Ground.remove(initial, Vector2i(4, 4), "fire", "denied")
	Ground.place(initial, Vector2i(5, 3), "fire")
	var denied: Dictionary = combat._surface_pay_enemy_fuel(initial, initial["enemies"][0], prepared)
	expect.call(int(paid["actions"][0]["amount"]) > int(denied["actions"][0]["amount"]) and Ground.element_at(initial, Vector2i(5, 3)) == "fire", "Ooze shell loses its selected fuel bonus without substituting nearby Fire")
	initial["enemies"][0]["hp"] = 1
	for tile: Vector2i in [Vector2i(4, 3), Vector2i(3, 3), Vector2i(5, 3), Vector2i(4, 2), Vector2i(4, 4)]:
		Ground.place(initial, tile, "fire")
	var action: Dictionary = {"type": "aoe", "range": 5, "damage": 1000, "pattern": [[0,0],[1,0],[-1,0],[0,1],[0,-1]], "rotate": false, "element": "none"}
	var result: Dictionary = combat.apply_player_action(initial, action, Vector2i(4, 3))
	var children: int = 0
	for enemy: Dictionary in result["enemies"]:
		if bool(enemy.get("summoned", false)):
			children += 1
			expect.call(int(enemy["hp"]) == int(enemy["max_hp"]) - GameData.fixed_point_amount(1), "Ooze children receive arrival Fire once and never the completed lethal AOE")
	expect.call(children == 2 and int(result.get("death_bonus_card_plays_this_turn", 0)) == 1, "Ooze split creates two children after its one ordinary kill refund")
	result = combat.apply_player_action(result, action, Vector2i(4, 3))
	expect.call(int(result.get("death_bonus_card_plays_this_turn", 0)) == 1, "Killing summoned droplets cannot farm ordinary enemy-death card plays")

static func _test_bloomer_gaoler_angle(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = _state(combat, "bile_bloomer")
	state["player"]["pos"] = Vector2i(5, 3)
	Ground.place(state, Vector2i(5, 3), "fire")
	state = combat._resolve_enemy_action(state, 0, _intent(combat, "bile_bloomer", "spore_mark")["actions"][1])
	expect.call(Ground.has_rubble(state, Vector2i(5, 3)) and Ground.element_at(state, Vector2i(5, 3)) == "fire", "Shale Mark adds movement control while preserving shared Fire")
	state["enemies"][0]["type"] = "chainbound_gaoler"
	state["enemies"][0]["pos"] = Vector2i(2, 3)
	state["player"]["pos"] = Vector2i(6, 3)
	state["player"]["hp"] = 1000
	state["player"]["expose"] = 0
	var angled: Dictionary = state.duplicate(true)
	angled["player"]["pos"] = Vector2i(4, 5)
	var pull: Dictionary = _intent(combat, "chainbound_gaoler", "chain_reel")["actions"][0]
	var straight: Dictionary = combat._resolve_enemy_action(state, 0, pull)
	angled = combat._resolve_enemy_action(angled, 0, pull)
	expect.call(straight["player"]["pos"] == Vector2i(3, 3), "Gaoler pull crosses Rubble without charging voluntary movement allowance")
	expect.call(int(straight["player"]["hp"]) + GameData.fixed_point_amount(1) == int(angled["player"]["hp"]), "Changing the pull angle keeps the direct attack but avoids the prepared Fire crossing")

static func _test_surgeon_ice_counterplay(combat: Combat, expect: Callable) -> void:
	var initial: Dictionary = _state(combat, "grave_surgeon")
	initial["enemies"][0]["pos"] = Vector2i(6, 3)
	var ally: Dictionary = Base.enemy(2, Vector2i(3, 3))
	ally["hp"] = 500
	initial["enemies"].append(ally)
	Ground.place(initial, Vector2i(3, 3), "ice")
	Ground.place(initial, Vector2i(3, 3), "rubble")
	initial = combat.surface_actor_arrival(initial, "enemy", 2, Vector2i(3, 4))
	var action: Dictionary = _intent(combat, "grave_surgeon", "field_brace")["actions"][1]
	var cleared: Dictionary = combat._resolve_enemy_action(initial.duplicate(true), 0, action)
	expect.call(not bool(cleared["enemies"][1].get("chilled", false)) and Ground.element_at(cleared, Vector2i(3, 3)).is_empty() and Ground.has_rubble(cleared, Vector2i(3, 3)), "Surgeon removes prepared Ice and its Chill while preserving independent Rubble")
	var frozen: Dictionary = initial.duplicate(true)
	frozen["enemies"][1]["freeze"] = 1
	frozen = combat._resolve_enemy_action(frozen, 0, action)
	expect.call(int(frozen["enemies"][1]["freeze"]) == 1, "Clearing Ice never cleanses an already Frozen ally")
	initial["enemies"][0]["pos"] = Vector2i(8, 6)
	var displaced: Dictionary = combat._resolve_enemy_action(initial, 0, action)
	expect.call(Ground.element_at(displaced, Vector2i(3, 3)) == "ice" and bool(displaced["enemies"][1]["chilled"]), "Displacing Surgeon out of support range preserves the prepared Ice target")

static func _test_lancer_lane(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = _state(combat, "frostglass_lancer")
	var lunge: Dictionary = _intent(combat, "frostglass_lancer", "glass_lunge")["actions"][1]
	state = combat._resolve_enemy_action(state, 0, lunge)
	expect.call(Ground.element_at(state, state["player"]["pos"]) == "ice" and not bool(state["player"].get("chilled", false)), "Lancer paints its attack lane after the hit without immediate Chill")
	state = combat.apply_player_movement(state, Vector2i(2, 4))
	state = combat._resolve_enemy_action(state, 0, _intent(combat, "frostglass_lancer", "frost_pin")["actions"][0])
	expect.call(int(state["player"].get("freeze", 0)) == 0, "Leaving the Lancer's Ice lane avoids the later Ice conversion")
	Ground.place(state, Vector2i(3, 3), "ice")
	state = combat._move_enemy_in_direction(state, 0, Vector2i.LEFT, 1, true)
	expect.call(bool(state["enemies"][0].get("chilled", false)), "Pushing the Lancer into shared Ice activates its own Chill")
	state = combat.apply_player_action(state, {"type": "ranged", "range": 5, "damage": 1, "element": "ice"}, Vector2i(3, 3))
	expect.call(int(state["enemies"][0].get("freeze", 0)) == 1, "The player can convert the Lancer's shared Ice setup into Freeze")

static func _test_worldspine_denial(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = _state(combat, "tharokh")
	for y: int in range(1, 8):
		for x: int in range(1, 9):
			Ground.place(state, Vector2i(x, y), "fire")
			Ground.place(state, Vector2i(x, y), "rubble")
	state = combat._resolve_enemy_action(state, 0, _intent(combat, "tharokh", "stonewake")["actions"][0])
	for terrain: Dictionary in state["terrain"]:
		expect.call(Ground.surface_at(state, terrain["pos"]).is_empty(), "Raising a Worldspine removes both obscured ground layers")
	state = _state(combat, "tharokh")
	state["enemies"][0]["pos"] = Vector2i(6, 1)
	state["player"]["pos"] = Vector2i(3, 3)
	state["terrain"] = [{"id":"denied_spine","kind":"dragon_spire","pos":Vector2i(4,3),"hp":5,"max_hp":5,"surface_on_destroy":"rubble"}, {"id":"surviving_spine","kind":"dragon_spire","pos":Vector2i(7,5),"hp":5,"max_hp":5,"surface_on_destroy":"rubble"}]
	expect.call(combat._terrain_burst_tiles(state, 1).has(Vector2i(3, 3)), "Live selected Worldspine initially threatens the adjacent player")
	state = combat.apply_player_action(state, {"type":"ranged","range":5,"damage":5,"element":"none"}, Vector2i(4,3))
	expect.call(not combat._terrain_burst_tiles(state, 1).has(Vector2i(3, 3)) and Ground.has_rubble(state, Vector2i(4,3)), "Destroying the nearby Worldspine removes its Faultline coverage and leaves only local Rubble")
	state = combat._resolve_enemy_action(state, 0, _intent(combat, "tharokh", "faultline")["actions"][0])
	expect.call(int(state["player"]["hp"]) == 1000 and Ground.has_rubble(state, Vector2i(7,5)), "The surviving distant Worldspine still ruptures without restoring denied coverage")

static func _test_crownfire_shared_denial(combat: Combat, expect: Callable) -> void:
	var initial: Dictionary = _state(combat, "vyraketh")
	initial["enemies"][0]["pos"] = Vector2i(7, 3)
	initial["enemies"][0]["cinder_tiles"] = [Vector2i(5, 3)]
	initial["player"]["pos"] = Vector2i(4, 3)
	Ground.place(initial, Vector2i(5, 3), "fire")
	Ground.place(initial, Vector2i(8, 5), "fire")
	var action: Dictionary = _intent(combat, "vyraketh", "crownfire")["actions"][0]
	var fizzle: Dictionary = initial.duplicate(true)
	Ground.place(fizzle, Vector2i(5, 3), "ice")
	fizzle = combat._resolve_enemy_action(fizzle, 0, action)
	expect.call(int(fizzle["player"]["hp"]) == 1000 and int(fizzle["enemies"][0]["hp"]) == 1000 and Ground.element_at(fizzle, Vector2i(5,3)) == "ice" and Ground.element_at(fizzle, Vector2i(8,5)) == "fire", "Fully denied Crownfire fizzles and neither consumes replacement Ice nor substitutes unselected Fire")
	var displaced: Dictionary = combat._move_enemy_in_direction(initial, 0, Vector2i.LEFT, 2, true)
	var before: int = int(displaced["enemies"][0]["hp"])
	displaced = combat._resolve_enemy_action(displaced, 0, action)
	expect.call(int(displaced["enemies"][0]["hp"]) == before - int(action["damage"]) and int(displaced["player"]["hp"]) == 1000 - int(action["damage"]), "Displacing Vyraketh into the selected union makes its own Crownfire hit boss and player once each")
	expect.call(Ground.element_at(displaced, Vector2i(5,3)).is_empty() and Ground.element_at(displaced, Vector2i(8,5)) == "fire", "Crownfire consumes only the surviving selected Fire")

static func _test_iskaldra_two_step_freeze(combat: Combat, expect: Callable) -> void:
	var state: Dictionary = _state(combat, "iskaldra")
	var attack: Dictionary = _intent(combat, "iskaldra", "whiteout_lance")["actions"][0]
	state = combat._resolve_enemy_action(state, 0, attack)
	expect.call(not bool(state["player"].get("chilled", false)) and int(state["player"].get("freeze", 0)) == 0, "Iskaldra's first Ice painter cannot skip the shared setup rule")
	state = combat._resolve_player_start_of_turn(state)
	state = combat._resolve_enemy_action(state, 0, attack)
	expect.call(int(state["player"].get("freeze", 0)) == 1, "Iskaldra converts Ice only after the player's contact activation")
	state = combat._resolve_enemy_action(state, 0, attack)
	state = combat._resolve_player_start_of_turn(state)
	state = combat._resolve_enemy_action(state, 0, attack)
	expect.call(int(state["player"].get("freeze", 0)) == 0 and not bool(state["player"].get("chilled", false)), "Repeated Ice hits cannot immediately re-freeze through the skipped activation's protected contact window")

static func _test_specialist_shock_fuel(combat: Combat, expect: Callable) -> void:
	for record: Array in [["lightning_wisp", "blinding_arc"], ["zekarion", "tempest_breath"]]:
		var id: String = str(record[0])
		var initial: Dictionary = _state(combat, id)
		Ground.place(initial, Vector2i(4,3), "electrified")
		var prepared: Dictionary = combat._surface_prepare_enemy_intent(initial, initial["enemies"][0], _intent(combat, id, str(record[1])))
		var paid_state: Dictionary = initial.duplicate(true)
		var paid: Dictionary = combat._surface_pay_enemy_fuel(paid_state, paid_state["enemies"][0], prepared)
		Ground.remove(initial, Vector2i(4,3), "electrified", "denied")
		Ground.place(initial, Vector2i(3,3), "electrified")
		var denied: Dictionary = combat._surface_pay_enemy_fuel(initial, initial["enemies"][0], prepared)
		var denied_attack: Dictionary = denied["actions"][-1]
		var paid_attack: Dictionary = paid["actions"][-1]
		expect.call(int(denied_attack.get("shock", 0)) == 0 and int(paid_attack.get("shock", 0)) == 1, "%s specialist Shock exists only when its exact shown Electrified fuel was paid" % id)
		initial = combat._resolve_enemy_action(initial, 0, denied_attack)
		paid_state = combat._resolve_enemy_action(paid_state, 0, paid_attack)
		expect.call(int(initial["player"].get("shock", 0)) == 0 and int(paid_state["player"].get("shock", 0)) == 1, "%s actual baseline shot loses Shock when fuel is denied" % id)

static func _test_eclipse_ground_and_air_cascade(combat: Combat, expect: Callable) -> void:
	var initial: Dictionary = _state(combat, "noctyrax")
	initial["umbra"]["light_sources"] = []
	Ground.place(initial, initial["player"]["pos"], "fire")
	var lit: Dictionary = initial.duplicate(true)
	lit["umbra"]["light_sources"] = [{"pos":lit["player"]["pos"],"radius":1,"duration":3}]
	var eclipse: Dictionary = _intent(combat, "noctyrax", "last_eclipse")["actions"][0]
	var dark: Dictionary = combat._resolve_enemy_action(initial, 0, eclipse)
	lit = combat._resolve_enemy_action(lit, 0, eclipse)
	expect.call(int(dark["player"]["hp"]) == 1000 - int(eclipse["damage"]) and int(lit["player"]["hp"]) == 1000, "Glowing Fire grants no Eclipse protection; an actual Light source on the same ground does")
	var cascade: Dictionary = Base.fixture(combat)
	cascade["player"]["pos"] = Vector2i(3,3)
	cascade["enemies"][0]["pos"] = Vector2i(4,4)
	cascade["enemies"][0]["footprint"] = Vector2i(2,2)
	cascade["traps"] = [{"id":"air_first","pos":Vector2i(4,3),"element":"air","damage":10}, {"id":"air_second","pos":Vector2i(2,3),"element":"air","damage":10}]
	var shot: Dictionary = {"type":"ranged","range":5,"damage":1,"element":"none"}
	var preview: Dictionary = combat.resolve_player_action_for_presentation(cascade, shot, Vector2i(4,3))
	var actual: Dictionary = combat.apply_player_action(cascade, shot, Vector2i(4,3))
	expect.call(actual == preview["state"] and (actual["traps"] as Array).is_empty() and actual["player"]["pos"] == Vector2i(2,3) and int(actual["player"]["hp"]) == 990, "Air trap cascade follows the exact preview and triggers the second center once")
	expect.call(actual["enemies"][0]["pos"] == Vector2i(4,5), "A large adjacent body receives one outward Air wake displacement")


static func _test_physical_approach(combat: Combat, expect: Callable) -> void:
	for id: String in ["crawler", "warden"]:
		var state: Dictionary = _state(combat, id)
		for y: int in range(1, 8):
			if y == 3:
				continue
			for x: int in range(1, 9):
				state["grid"][y][x] = "wall"
		Ground.place(state, Vector2i(3,3), "rubble")
		Ground.place(state, Vector2i(3,3), "fire")
		state = combat._resolve_enemy_action(state, 0, {"type":"move_toward","range":1})
		expect.call(state["enemies"][0]["pos"] == Vector2i(3,3) and int(state["enemies"][0]["hp"]) == 999, "%s makes minimum progress through Rubble while paying shared Fire entry" % id)

static func _test_electrical_opponent_sets(combat: Combat, expect: Callable) -> void:
	var initial: Dictionary = _state(combat, "lightning_wisp")
	initial["enemies"][0]["pos"] = Vector2i(7,3)
	initial["enemies"].append(Base.enemy(2, Vector2i(4,3)))
	initial["illusions"] = [{"id":5,"pos":Vector2i(3,3),"hp":100,"max_hp":100}]
	for x: int in range(2,5):
		Ground.place(initial, Vector2i(x,3), "electrified")
	var network: Dictionary = combat._resolve_enemy_action(initial, 0, {"type":"ranged","range":5,"damage":10,"element":"lightning"})
	expect.call(int(network["player"]["hp"]) == 990 and int(network["illusions"][0]["hp"]) == 90 and int(network["enemies"][1]["hp"]) == 1000, "Enemy conduction hits player and illusions once while excluding allied actors")
	initial = _state(combat, "lightning_wisp")
	initial["enemies"][0]["pos"] = Vector2i(7,3)
	initial["enemies"].append(Base.enemy(2, Vector2i(3,3)))
	initial["illusions"] = [{"id":5,"pos":Vector2i(4,3),"hp":100,"max_hp":100}]
	var chain: Dictionary = combat._resolve_board_attack(initial, {"type":"ranged","range":5,"damage":10,"element":"none","chain":1}, Vector2i(2,3), "enemy", 1)
	expect.call(int(chain["player"]["hp"]) == 990 and int(chain["illusions"][0]["hp"]) == 100 and int(chain["enemies"][1]["hp"]) == 1000, "Enemy Chain cannot use an allied body to bridge a gap between its opponents")
