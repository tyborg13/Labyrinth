extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const BossSuite = preload("res://tests/suites/dragon_boss_suite.gd")
const Shapes = preload("res://scripts/committed_pattern_shapes.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")

var failed: int = 0

func _initialize() -> void:
	_test_kindle_holds_ground()
	_test_kindle_pressure_and_counterplay()
	_test_edge_shapes()
	_test_held_approach_and_damage()
	_test_footprint_trap_prediction()
	_test_worldspine_choices()
	var opening: Dictionary = BossSuite._boss_combat_state("tharokh", 4)
	expect(int(opening["turn_queue"][0]["time"]) == 12, "Stonewake must resolve after the first ordinary two-card turn")
	_test_air_evade_and_displacement()
	_test_ice_ground_budget()
	_test_storm_marks_conduction_and_cap()
	_test_summoned_wisp_activation()
	_test_eclipse_refuges()
	BossSuite.run(expect)
	if failed == 0: print("Dragon committed patterns passed.")
	quit(1 if failed else 0)

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _test_kindle_holds_ground() -> void:
	var combat = Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("vyraketh")
	var boss: Dictionary = state["enemies"][0]
	var declared: Array = boss["intent"]["actions"][0]["declared_tiles"].duplicate()
	state["player"]["pos"] = Vector2i(6, 6)
	expect(combat.enemy_threat_tiles(state, 0)["attack"] == declared or _same_tiles(combat.enemy_threat_tiles(state, 0)["attack"], declared), "Kindle must not retarget when the player moves")
	state = BossSuite._resolve_boss_turn(state)
	expect(_same_tiles(Surface.tiles(state, "fire"), declared), "Kindle must ignite its displayed cells")
	for tile: Vector2i in declared: Surface.place(state, tile, "ice")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["intent"]["id"] == "cinder_maw", "Denied Crownfire must advance to an attack, not restart setup")
	for tile: Vector2i in declared: expect(Surface.has_surface(state, tile, "ice"), "Crownfire must preserve replacement Ice")

func _test_kindle_pressure_and_counterplay() -> void:
	var combat = Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("vyraketh")
	state["terrain"] = []
	state["traps"] = []
	state["player"]["pos"] = Vector2i(1,4)
	state["enemies"][0]["pos"] = Vector2i(4,3)
	state["enemies"][0]["dragon_cycle"] = -1
	var rng := RandomNumberGenerator.new()
	combat._assign_enemy_intent(state,0,rng)
	var marked: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	expect(_same_tiles(marked,[Vector2i(3,3),Vector2i(3,4),Vector2i(4,5)]), "Kindle must pressure both melee approach cells and the nearer exterior corner")
	state = BossSuite._resolve_boss_turn(state)
	var hp: int = state["enemies"][0]["hp"]
	var unpushed: Dictionary = BossSuite._resolve_boss_turn(state.duplicate(true))
	expect(int(unpushed["enemies"][0]["hp"]) == hp - 8, "Holding the dragon beside its Fire must reward Crownfire self-damage")
	state["enemies"][0]["pos"] += Vector2i.RIGHT
	var pushed: Dictionary = BossSuite._resolve_boss_turn(state)
	expect(int(pushed["enemies"][0]["hp"]) == hp, "Pushing away from the L must buy space at the cost of Crownfire self-damage")

func _test_edge_shapes() -> void:
	var combat = Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("vyraketh")
	state["terrain"] = []
	var action := {"committed_shape":"crescent", "pattern_footprint":[2,2], "range":2}
	var affected: Array[Vector2i] = Shapes.footprint_shape(combat, state, Vector2i(4,3), Vector2i.LEFT, action)
	var expected: Array[Vector2i] = []
	for x: int in [2,3]:
		for y: int in [2,3,4,5]: expected.append(Vector2i(x,y))
	for x: int in [4,5]:
		for y: int in [2,5]: expected.append(Vector2i(x,y))
	expect(_same_tiles(affected, expected), "Maw must cover both front rows and side edges symmetrically")
	expect(not affected.has(Vector2i(6,3)) and not affected.has(Vector2i(6,4)), "Maw must leave a rear melee reward for reaching the far side")
	action["committed_shape"] = "fan"
	action["range"] = 3
	affected = Shapes.footprint_shape(combat, state, Vector2i(5,3), Vector2i.LEFT, action)
	expect(affected.size() == 12, "Cinderfall must form a bounded 2/4/6 fan")
	expect(not affected.has(Vector2i(5,2)) and not affected.has(Vector2i(5,5)), "Cinderfall must leave close lateral flanks open")

func _test_held_approach_and_damage() -> void:
	var combat = Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("vyraketh")
	state["terrain"] = []
	state["traps"] = []
	state["player"]["pos"] = Vector2i(1,4)
	state["enemies"][0]["dragon_cycle"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	combat._assign_enemy_intent(state, 0, rng)
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect(not (plan["projected_attack"] as Array).is_empty(), "Maw must present an actionable attack pattern")
	var safe: Dictionary = state.duplicate(true)
	safe["player"]["pos"] = Vector2i(7,6)
	var changed: Dictionary = combat.enemy_intent_plan(safe, 0)
	expect(_same_tiles(changed["projected_attack"], plan["projected_attack"]), "Moving away must not rotate the declared attack")
	expect(changed["path"] == plan["path"], "The declared approach must not chase the player's new position")
	var hp: int = safe["player"]["hp"]
	safe = BossSuite._resolve_boss_turn(safe)
	expect(int(safe["player"]["hp"]) == hp, "Escaping the declared Maw must avoid its damage")
	var hit: Dictionary = BossSuite._boss_combat_state("vyraketh")
	hit["terrain"] = []
	hit["traps"] = []
	hit["player"]["pos"] = Vector2i(3,3)
	hit["enemies"][0]["pos"] = Vector2i(4,3)
	hit["enemies"][0]["dragon_cycle"] = 1
	combat._assign_enemy_intent(hit,0,rng)
	expect((combat.enemy_intent_plan(hit,0)["projected_attack"] as Array).has(hit["player"]["pos"]), "A player who stays in front must be shown in Maw's damage cells")
	var before: int = hit["player"]["hp"]
	hit = BossSuite._resolve_boss_turn(hit)
	expect(int(hit["player"]["hp"]) == before - 12, "Standing in the displayed Maw must take its advertised 12 damage")
	var frozen: Dictionary = combat.enemy_intent_plan(state, 0, {}, true, true)
	expect((frozen["projected_attack"] as Array).is_empty(), "Disabling the dragon must remove its damage preview")

func _same_tiles(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for tile: Variant in a:
		if not b.has(tile): return false
	return true

func _empty_arena(boss_id: String) -> Dictionary:
	var state: Dictionary = BossSuite._boss_combat_state(boss_id)
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["player"]["pos"] = Vector2i(1,4)
	state["enemies"][0]["pos"] = Vector2i(4,3)
	return state

func _declare(state: Dictionary, cycle: int) -> void:
	state["enemies"][0]["dragon_cycle"] = cycle - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	Combat.new()._assign_enemy_intent(state,0,rng)

func _test_worldspine_choices() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("tharokh")
	_declare(state,0)
	var marks: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	expect(marks.size()==2, "Stonewake must mark two destructible obstacles in an open arena")
	var denied: Dictionary = state.duplicate(true)
	denied["player"]["pos"] = marks[0]
	denied = BossSuite._resolve_boss_turn(denied)
	expect(combat._terrain_index_at_tile(denied,marks[0])<0, "Occupying a Stonewake mark must deny its spire, never trap the player inside terrain")
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).size()==2, "Stonewake must resolve its shown obstacle count")
	var blockers: Dictionary = combat._enemy_path_blockers(state,state["enemies"][0],true,false)
	var exits: int = 0
	for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if combat._enemy_can_occupy_anchor(state,state["enemies"][0],state["enemies"][0]["pos"]+direction,blockers): exits += 1
	expect(exits>=2,"Worldspines must leave two exits for the dragon's whole footprint")
	_declare(state,0)
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).size()==2,"Repeated Stonewake must not exceed its live cap")
	_declare(state,2)
	var intact: Array = combat.enemy_threat_tiles(state,0)["attack"]
	var spire: Dictionary = combat._dragon_spires(state)[0]
	state = combat._damage_terrain_indices(state,[combat._terrain_index_at_tile(state,spire["pos"])],100)
	var broken: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(broken.size()<intact.size(),"Breaking a Worldspine must immediately remove its unique Faultline cells")
	expect(Surface.has_surface(state,spire["pos"],"rubble"),"Destroyed Worldspines leave shared Rubble")
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).is_empty(),"Faultline must break the surviving spires after resolving")

func _test_air_evade_and_displacement() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("vaeloryx")
	state["player"]["pos"] = Vector2i(3,4)
	_declare(state,0)
	var threatened: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(threatened.has(Vector2i(3,4)),"Gale must advertise damage in front of the dragon")
	var hp: int = state["player"]["hp"]
	var stayed: Dictionary = BossSuite._resolve_boss_turn(state.duplicate(true))
	expect(stayed["player"]["hp"]==hp-6 and stayed["player"]["pos"]==Vector2i(1,4),"Staying in Gale must take six damage and two tiles of displacement")
	state["player"]["pos"] = Vector2i(4,5)
	expect(not combat.enemy_threat_tiles(state,0)["attack"].has(Vector2i(4,5)),"A lateral step must escape Gale's committed direction")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["player"]["hp"]==hp and state["player"]["pos"]==Vector2i(4,5),"Escaping Gale must avoid both damage and forced movement")

func _test_ice_ground_budget() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("iskaldra")
	_declare(state,0)
	state = BossSuite._resolve_boss_turn(state)
	var hp: int = state["enemies"][0]["hp"]
	state = combat._damage_enemy(state,0,2,true)
	expect(state["enemies"][0]["hp"]==hp and state["enemies"][0]["frost_armor"]==0,"A low-damage hit must peel one Mantle layer without spending boss HP")
	state = combat._damage_enemy(state,0,9,true)
	expect(state["enemies"][0]["hp"]==hp-9,"A follow-up heavy hit must land after armor is peeled")
	_declare(state,1)
	var affected: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(affected.size()>2,"Lance should threaten more tiles than it coats")
	state = BossSuite._resolve_boss_turn(state)
	expect(Surface.tiles(state,"ice").size()==2,"Whiteout Lance must leave exactly two Ice tiles, not flood its entire damage lane")
	Surface.place(state,state["enemies"][0]["pos"],"ice")
	_declare(state,0)
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["frost_armor"]==2,"Ice fuel under Iskaldra must add one layer up to the cap of two")

func _test_storm_marks_conduction_and_cap() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("zekarion")
	# The opening minions remain part of the same two-Wisp cap.
	_declare(state,0)
	var marks: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"].duplicate()
	state["player"]["pos"] = Vector2i(7,7)
	expect(_same_tiles(combat.enemy_threat_tiles(state,0)["attack"],marks),"Skybreak must hold its marks when the player moves")
	var connected: Dictionary = state.duplicate(true)
	for tile: Vector2i in [Vector2i(1,4),Vector2i(2,4),Vector2i(3,4)]: Surface.place(connected,tile,"electrified")
	connected["player"]["pos"] = Vector2i(3,4)
	expect(not marks.has(Vector2i(3,4)) and combat.enemy_threat_tiles(connected,0)["attack"].has(Vector2i(3,4)),"Skybreak must advertise conducted damage beyond its fixed marks")
	var marked_hp: int = connected["player"]["hp"]
	connected = BossSuite._resolve_boss_turn(connected)
	expect(connected["player"]["hp"]==marked_hp-6,"Skybreak's conducted warning must match its six damage")
	state = BossSuite._resolve_boss_turn(state)
	expect(_same_tiles(Surface.tiles(state,"electrified"),marks),"Skybreak must leave Electrified on its fixed strike cells")
	state["surfaces"] = {}
	state["player"]["pos"] = Vector2i(1,4)
	_declare(state,1)
	# Connect the held lane to a safe-looking lateral floor cell.
	for tile: Vector2i in [Vector2i(3,4),Vector2i(3,5),Vector2i(3,6)]: Surface.place(state,tile,"electrified")
	state["player"]["pos"] = Vector2i(3,6)
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	expect(not action["declared_tiles"].has(Vector2i(3,6)),"Electrical witness must sit outside Tempest's geometric lane")
	expect(combat.enemy_threat_tiles(state,0)["attack"].has(Vector2i(3,6)),"Tempest preview must include the connected off-lane player")
	var broken: Dictionary = state.duplicate(true)
	Surface.place(broken,Vector2i(3,5),"fire")
	expect(not combat.enemy_threat_tiles(broken,0)["attack"].has(Vector2i(3,6)),"Replacing a connector must remove the off-lane electrical threat")
	var hp: int = state["player"]["hp"]
	var struck: Dictionary = BossSuite._resolve_boss_turn(state)
	expect(struck["player"]["hp"]==hp-7 and struck["player"]["shock"]==1,"The displayed conducted hit must apply Tempest damage and its Shock bonus")
	broken = BossSuite._resolve_boss_turn(broken)
	expect(broken["player"]["hp"]==hp,"Breaking the electrical route must avoid the off-lane damage")
	_declare(struck,3)
	expect((combat.enemy_threat_tiles(struck,0)["summon"] as Array).is_empty(),"A full Wisp cap must not preview another summon")
	struck = BossSuite._resolve_boss_turn(struck)
	expect(struck["enemies"].size()==3,"A full Wisp cap must not create a third helper")
	struck["enemies"][1]["hp"] = 0
	_declare(struck,3)
	struck = BossSuite._resolve_boss_turn(struck)
	var living: int = 0
	for enemy: Dictionary in struck["enemies"]:
		if enemy["type"]=="lightning_wisp" and enemy["hp"]>0: living += 1
	expect(living==2,"A later Call may replace one defeated Wisp without exceeding the cap")
	var summoned: Dictionary = struck["enemies"][-1]
	var embers: int = struck.get("room_embers",0)
	var plays: int = struck.get("death_bonus_card_plays_this_turn",0)
	struck = combat._damage_enemy(struck,struck["enemies"].size()-1,100)
	expect(bool(summoned.get("summoned",false)) and struck.get("room_embers",0)==embers and struck.get("death_bonus_card_plays_this_turn",0)==plays,"Replacement Wisp death must award neither Embers nor a card play")
	var claw: Dictionary = _empty_arena("zekarion")
	_declare(claw,2)
	claw = BossSuite._resolve_boss_turn(claw)
	expect(Surface.tiles(claw,"electrified").size()==1,"Storm Claw leaves one conductor, not a flooded crescent")

func _test_summoned_wisp_activation() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("zekarion")
	for enemy: Dictionary in state["enemies"]:
		if enemy["type"] == "lightning_wisp": enemy["hp"] = 0
	_declare(state, 3)
	state["turn_queue"] = [combat._enemy_actor_entry(state, state["enemies"][0], 20, 0)]
	state["current_actor"] = {"kind":"transition"}
	state = combat.advance_one_activation_with_steps(state)["state"]
	var summoned: Dictionary = state["enemies"][-1]
	expect(bool(summoned.get("summoned", false)), "Call Wisps activation must create a replacement helper")
	var entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == int(summoned["id"]))
	expect(entries.size() == 1, "The newly summoned Wisp must enter the turn clock exactly once")
	if entries.size() != 1: return
	expect(int(entries[0]["time"]) > int(state["initiative_clock"]), "A summoned Wisp must wait its advertised initiative delay")
	state = bytes_to_var(var_to_bytes(state))
	var resumed_entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == int(summoned["id"]))
	expect(resumed_entries == entries, "Saving and resuming must preserve the Wisp's single scheduled activation")
	# Stand beside the helper so either of its ordinary attacks can connect.
	var occupied: Dictionary = combat._enemy_blocking_tiles(state)
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var neighbor: Vector2i = summoned["pos"] + direction
		if preload("res://scripts/path_utils.gd").is_passable(state["grid"], neighbor) and not occupied.has(neighbor):
			state["player"]["pos"] = neighbor
			break
	# Its first ordinary intent must execute through the same clock as the boss.
	var hp: int = int(state["player"]["hp"])
	var wisp_time: int = int(entries[0]["time"])
	state = combat.advance_one_activation_with_steps(state)["state"]
	expect(int(state["initiative_clock"]) == wisp_time, "The replacement Wisp must receive the next due activation")
	expect(int(state["player"]["hp"]) < hp, "The scheduled Wisp must actually attack, not only display an intent")
	var next_entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == int(summoned["id"]))
	expect(next_entries.size() == 1 and int(next_entries[0]["time"]) > wisp_time, "The acting Wisp must reschedule once after its attack")

func _test_eclipse_refuges() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("noctyrax")
	_declare(state,0)
	var first: int = state["enemies"][0]["intent"]["actions"][0]["brazier_id"]
	var refuge: Vector2i
	var snuffed: Vector2i
	for brazier: Dictionary in state["guardian_braziers"]:
		if brazier["id"]==first: snuffed=brazier["pos"]
		else: refuge=brazier["pos"]
	state["player"]["pos"] = refuge
	expect(not combat.enemy_threat_tiles(state,0)["attack"].has(refuge),"The surviving refuge must be visibly safe before Eclipse")
	state["player"]["pos"] = snuffed
	expect(combat.enemy_threat_tiles(state,0)["attack"].has(snuffed),"The refuge being snuffed must be unsafe in the same damage preview")
	state["player"]["pos"] = refuge
	var hp: int = state["player"]["hp"]
	state = BossSuite._resolve_boss_turn(state)
	expect(state["player"]["hp"]==hp,"Standing in surviving light must avoid Eclipse damage")
	expect((state["guardian_braziers"] as Array).filter(func(b: Dictionary)->bool: return b["lit"]).size()==1,"Eclipse must extinguish exactly one refuge")
	state = bytes_to_var(var_to_bytes(state))
	_declare(state,3)
	state = BossSuite._resolve_boss_turn(state)
	expect((state["guardian_braziers"] as Array).all(func(b: Dictionary)->bool: return b["lit"]),"Braziers must relight after Shadow Coil before the next Eclipse")
	var second: int = state["enemies"][0]["intent"]["actions"][0]["brazier_id"]
	expect(second!=first,"Successive Eclipses must alternate refuge identities across serialization")
	for direction: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
		for seed: int in [71,72,73]:
			var room: Dictionary = preload("res://scripts/room_generator.gd").new().generate_room(seed,BossSuite._boss_room_metadata("noctyrax",24),direction)
			for brazier: Dictionary in room["guardian_braziers"]:
				for key: String in ["terrain","traps","loot"]:
					for object: Dictionary in room[key]: expect(object["pos"]!=brazier["pos"],"Noctyrax refuge must remain readable and unobstructed for every entry")
				for enemy: Dictionary in room["enemies"]: expect(not Surface.footprint_tiles(enemy).has(brazier["pos"]),"Noctyrax refuge must not overlap an actor footprint")

func _test_footprint_trap_prediction() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("tharokh")
	_declare(state,1)
	var intent: Dictionary = state["enemies"][0]["intent"]
	# Hold this authored two-step approach, then change an off-anchor tile.
	intent["committed_plan"]["path"] = [Vector2i(4,3),Vector2i(3,3),Vector2i(2,3)]
	intent["committed_plan"]["destination"] = Vector2i(2,3)
	state["traps"] = [{"id":"off_anchor_earth","pos":Vector2i(3,4),"element":"earth","damage":0}]
	var plan: Dictionary = combat.enemy_intent_plan(state,0)
	var result: Dictionary = BossSuite._resolve_boss_turn(state)
	expect(plan["destination"]==Vector2i(3,3),"Preview must account for trap-created Rubble under the dragon's full footprint")
	expect(result["enemies"][0]["pos"]==plan["destination"],"The held charge must stop at the same anchor as its off-anchor trap preview")
