extends RefCounted

## Deterministic player-inspection setups. Encounter fixtures keep production
## scaling, initiative, card limits and save flow; mechanic studies stage only
## their opening board and then use ordinary gameplay.
const Guardians = preload("res://scripts/guardian_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Rules = preload("res://scripts/guardian_combat_rules.gd")
const CASES = ["encounter", "pre_battle", "map_entry", "map_choice", "relic", "reward", "outage", "telegraph", "outcrops", "summon"]

static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	var id: String = str(options.get("guardian_id", "ashen_reaver"))
	var study: String = str(options.get("guardian_case", "encounter"))
	var info: Dictionary = Guardians.for_guardian(id)
	assert(not info.is_empty() and CASES.has(study))
	var room: Dictionary = {}
	for candidate: Dictionary in state["rooms"].values():
		if str(candidate.get("guardian_id", "")) == id:
			room = candidate
			break
	assert(not room.is_empty())
	_loadout(state, options, int(room["section_index"]), id)
	var coord: Vector2i = room["coord"]
	var travel: Vector2i = Vector2i(0,-1)
	for prior: Dictionary in state["rooms"].values():
		for connection: Dictionary in prior.get("connections", []):
			if connection["coord"] == coord: travel = connection["door_dir"]
	state["guardian_inspection"] = {"id":id,"case":study,"section":room["section_index"]}
	state["notice"] = ""
	if study in ["map_entry", "map_choice"]:
		coord = Graph.section(state, int(room["section_index"]))["entry"]
		if study == "map_choice":
			for prior: Dictionary in state["rooms"].values():
				if int(prior.get("section_index", -1)) == int(room["section_index"]) and int(prior.get("map_step", -1)) == 3 and Graph.descendants(state, prior["coord"]).has(room["coord"]):
					coord = prior["coord"]
					break
		_mark_route(state, Graph.section(state, int(room["section_index"]))["entry"], coord)
		room = Graph.room(state, coord)
		room["cleared"] = true
		room["revealed"] = true
		room["visited"] = true
		state["current_room"] = coord
		state["mode"] = "room"
		state["combat_state"] = {}
		state["current_room_layout"] = engine._display_layout_for_room(int(state["seed"]), room, Vector2i.ZERO)
		Graph.refresh_knowledge(state)
		return state
	room["cleared"] = false
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	state["current_room"] = coord
	state["current_room_layout"] = engine._display_layout_for_room(int(state["seed"]), room, travel)
	state["mode"] = "pre_battle"
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = travel
	state["combat_state"] = {}
	Graph.refresh_knowledge(state)
	if study == "pre_battle": return state
	state = engine.begin_pre_battle_combat(state)
	var battle: Dictionary = state["combat_state"]
	if study == "relic":
		state = _relic_study(engine, combat, state, info)
		battle = state["combat_state"]
	elif study == "reward":
		battle["enemies"][0]["hp"] = 0
		return engine.finish_combat(state, battle)
	elif study == "outage":
		assert(id == "last_lamplighter")
		# End a normal activation through the initiative scheduler, stopping
		# after the first Snuff when control returns to the player.
		battle["player_turn_time_spent"] = 6
		battle = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
		assert(combat.is_player_turn(battle))
		assert(not bool(battle["guardian_braziers"][0]["lit"]))
		battle["player"]["hp"] = state["player_hp"]
	elif study in ["outcrops","summon"]:
		assert(id==("craghide" if study=="outcrops" else "storm_cantor"))
		# Advance the real opening setup intent and stop at the next player turn.
		battle["player_turn_time_spent"]=7
		battle=combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
		assert(combat.is_player_turn(battle))
		if study=="summon":
			for helper: Dictionary in battle["enemies"]:
				if str(helper["type"])=="lightning_wisp":helper["hp"]=0
			var rng := RandomNumberGenerator.new()
			rng.seed=51
			battle["enemies"][0]["guardian_cycle"]=2
			combat._assign_enemy_intent(battle,0,rng)
		battle["player"]["hp"]=state["player_hp"]
	elif study == "telegraph":
		var rng := RandomNumberGenerator.new()
		rng.seed = 51
		battle["enemies"][0]["guardian_cycle"] = 1
		combat._assign_enemy_intent(battle,0,rng)
	if study != "relic": _seed_hand(battle, ["chain_bolt","stone_plate","shadow_step","cleaver_hook","patch_up"])
	state["combat_state"] = battle
	return state

static func _mark_route(state: Dictionary, start: Vector2i, destination: Vector2i) -> bool:
	var current: Dictionary = Graph.room(state, start)
	if start != destination:
		var found: bool = false
		for link: Dictionary in current.get("connections", []):
			if Graph.descendants(state, link["coord"]).has(destination) and _mark_route(state, link["coord"], destination):
				found = true
				break
		if not found: return false
	current["cleared"] = true
	current["visited"] = true
	current["revealed"] = true
	return true

static func _loadout(state: Dictionary, options: Dictionary, section: int, id: String) -> void:
	if str(options.get("equip", "")).is_empty():
		state["equipped_equipment"]["weapon"] = "iron_cleaver"
		state["equipped_equipment"]["offhand"] = "ward_kite"
		state["collected_equipment"] = state["equipped_equipment"].values()
	if str(options.get("attuned_magic", "")).is_empty():
		state["attuned_magic_cards"] = ["chain_bolt","stone_plate","cinderline_tempo","rimeplate_lock","basalt_guard","gust_step"]
	if str(options.get("relics", "")).is_empty():
		state["relics"] = ["iron_buckler"] if section == 0 else ["iron_buckler","reinforced_shield"]
	state["deck_cards"] = Data.compile_deck_cards(state["equipped_equipment"], state["attuned_magic_cards"], state.get("equipped_items", []))
	state["magic_inventory"] = state["attuned_magic_cards"].duplicate()
	state["card_upgrades"] = {}
	if section >= 2: state["card_upgrades"] = {"chain_bolt":1,"cleaver_hook":1}
	state["player_hp"] = state["player_max_hp"]

static func _seed_hand(battle: Dictionary, desired: Array) -> void:
	var deck: Dictionary = battle["deck"]
	var remaining: Array = []
	for pile: String in ["hand","draw","discard"]: remaining.append_array(deck.get(pile, []))
	var hand: Array = []
	for id: String in desired:
		if remaining.has(id):
			remaining.erase(id)
			hand.append(id)
	while hand.size() < 5 and not remaining.is_empty(): hand.append(remaining.pop_front())
	deck["hand"] = hand
	deck["draw"] = remaining
	deck["discard"] = []

static func _relic_study(engine: RefCounted, combat: RefCounted, state: Dictionary, info: Dictionary) -> Dictionary:
	state["relics"].append(info["relic"])
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9): row.append("wall" if x==0 or y==0 or x==8 or y==8 else "stone")
		grid.append(row)
	var enemies: Array = []
	for tile: Vector2i in [Vector2i(3,4),Vector2i(4,4),Vector2i(5,4)]:
		enemies.append({"id":enemies.size()+1,"type":"crawler","pos":tile,"hp":12,"max_hp":12})
	var layout: Dictionary = {"name":"Guardian trophy study","type":"combat","depth":1,"grid":grid,"player_start":Vector2i(2,4),"enemies":enemies,"loot":[],"terrain":[],"traps":[]}
	var battle: Dictionary = combat.create_combat(int(state["seed"]),layout,engine._player_snapshot(state))
	state["current_room_layout"] = layout
	var room: Dictionary = Graph.room(state, state["current_room"])
	room["type"] = "combat"
	room.erase("guardian_id")
	room.erase("guardian_relic")
	room.erase("boss_id")
	match str(info["relic"]):
		"ashen_brand":
			for tile: Vector2i in [Vector2i(3,4),Vector2i(4,4),Vector2i(4,5)]: Surfaces.place(battle,tile,"fire")
			_seed_hand(battle,["cinderline_tempo","shadow_step","stone_plate","patch_up","chain_bolt"])
		"winters_spur":
			battle["player"]["pos"] = Vector2i(1,2)
			for x: int in range(2,7): Surfaces.place(battle,Vector2i(x,2),"ice")
			Surfaces.place(battle,Vector2i(5,2),"rubble")
		"resonant_clapper":
			_seed_hand(battle,["chain_bolt","stone_plate","gust_step","patch_up","shadow_step"])
		"galehook_talon":
			_seed_hand(battle,["kite_bash","gust_step","cleaver_hook","stone_plate","shadow_step"])
		"cragbound_gauntlet":
			battle["player"]["pos"] = Vector2i(2,6)
			battle["player"]["stoneskin"] = 7
			battle = combat.use_guardian_command(battle,"raise_cover",Vector2i(3,6))
			battle["terrain"][0]["hp"] = 4
			battle["player_movement_remaining"] = 2
			battle["player"]["stoneskin"] = 5
		"procession_lantern":
			battle["player"]["pos"] = Vector2i(2,6)
			battle["illusions"] = [{"id":1,"pos":Vector2i(3,3),"hp":3,"max_hp":3}]
			battle["next_illusion_id"] = 2
			battle["umbra"]["stage"] = "advancing"
	state["combat_state"] = battle
	return state
