extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Map = preload("res://scripts/section_map_graph.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
static func run(expect: Callable) -> void:
	var suite = new()
	suite._run()
	for failure: String in suite.failures: expect.call(false, failure)
	expect.call(suite.failures.is_empty(), "Guardian encounter and relic contracts")

func _run() -> void:
	_test_relics()
	_test_encounter_edges()
	_test_relic_edges()
	_test_reward_flow()
	_test_cover_and_force_boundaries()
	_test_relic_forecast_regressions()
	_test_inspection_rules()
	var names = preload("res://scripts/combat_objective_rules.gd")
	check(names.display_name("kill_all")=="Defeat All Enemies","ordinary all-enemy objective says Defeat")
	check(names.title_for_objective({"type":"kill_leader","leader_type":"warden"})=="Defeat the Leader","ordinary leader stays generic")
	for boss: String in Guardians.DEFINITIONS:
		var info: Dictionary = Guardians.for_boss(boss)
		check(names.title_for_objective({"type":"kill_leader","leader_type":info["id"]})=="Defeat "+info["name"],"Guardian objective names "+info["name"])
		check(names.title_for_objective({"type":"kill_leader","leader_type":boss})=="Defeat "+str(preload("res://scripts/game_data.gd").enemy_def(boss)["name"]),"dragon objective names "+boss)
	var engine := Combat.new()
	var generator := Rooms.new()
	for boss: String in Guardians.DEFINITIONS:
		var info: Dictionary = Guardians.for_boss(boss)
		var room: Dictionary = {"coord":Vector2i(2,1),"depth":2,"type":"guardian","element":info["element"],"boss_id":boss}
		var layout: Dictionary = generator.generate_room(92,room,Vector2i.ZERO)
		var state: Dictionary = engine.create_combat(92,layout,{"hp":24,"max_hp":24,"deck_cards":["pale_spark"]})
		check(str(state["objective"]["type"])=="kill_leader",boss+" leader objective")
		check(state["enemies"].size()>=2,boss+" helpers")
		check(state["enemies"][0]["intent"].has("committed_plan"),boss+" committed intent")
		var before: Dictionary = state["enemies"][0]["intent"].duplicate(true)
		state["player"]["pos"] = Vector2i(1,1)
		var plan: Dictionary = engine.enemy_intent_plan(state,0)
		check(plan["projected_attack"]==before["committed_plan"]["projected_attack"],boss+" telegraph holds")
		for turn: int in range(8):
			state["player"]["hp"] = 24
			state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
		print("Guardian exercised: ",info["name"])
	for seed_value: int in range(10):
		var run: Dictionary = {"seed":seed_value}
		Map.initialize(run)
		var counts: Dictionary = {}
		for room: Dictionary in run["rooms"].values():
			if room["type"]=="guardian": counts[room["section_index"]]=int(counts.get(room["section_index"],0))+1
		check(counts.size()==6,"six guardian sections")
		for count: int in counts.values():check(count==1,"one per section")


func fixture(relic: String, positions: Array) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9): row.append("wall" if x==0 or y==0 or x==8 or y==8 else "stone")
		grid.append(row)
	var enemies: Array = []
	for pos: Vector2i in positions: enemies.append({"id":enemies.size()+1,"type":"warden","pos":pos,"hp":100,"max_hp":100})
	return Combat.new().create_combat(5,{"name":"Relic contract","type":"combat","depth":1,"grid":grid,"player_start":Vector2i(1,1),"enemies":enemies},{"hp":24,"max_hp":24,"relics":[relic],"deck_cards":["pale_spark"]})

func _test_relics() -> void:
	var engine := Combat.new()
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	var state: Dictionary = fixture("winters_spur",[Vector2i(7,7)])
	for tile: Vector2i in [Vector2i(2,1),Vector2i(3,1),Vector2i(4,1)]: surfaces.place(state,tile,"ice")
	state["player_movement_remaining"]=1
	check(engine.player_movement_targets(state).has(Vector2i(4,1)),"Spur reaches end of straight Ice for one Move")
	var moved: Dictionary = engine.apply_player_movement(state,Vector2i(4,1))
	check(moved["player"]["pos"]==Vector2i(4,1) and moved["player_movement_remaining"]==0,"Spur actual cost matches plan")
	state=fixture("resonant_clapper",[Vector2i(2,1),Vector2i(3,1),Vector2i(4,1)])
	for enemy: Dictionary in state["enemies"]: enemy["block"]=0
	var chained: Dictionary = engine.apply_player_action(state,{"type":"ranged","range":4,"damage":4,"chain":1},Vector2i(2,1))
	check(chained["enemies"][0]["hp"]==96 and chained["enemies"][1]["hp"]==95 and chained["enemies"][2]["hp"]==94,"Clapper damage is 4,5,6")
	state=fixture("ashen_brand",[Vector2i(4,4)])
	state["player"]["pos"]=Vector2i(2,4)
	state["enemies"][0]["block"]=0
	for tile: Vector2i in [Vector2i(3,4),Vector2i(4,4),Vector2i(5,4)]: surfaces.place(state,tile,"fire")
	var blast: Dictionary = engine.apply_player_action(state,{"type":"detonate","range":2,"damage":4},Vector2i(3,4))
	check(blast["enemies"][0]["hp"]==94,"Brand overlaps three crosses into one six-damage hit")
	check(blast["player"]["hp"]==20,"Brand preserves self-danger")
	check(not surfaces.has_surface(blast,Vector2i(5,4),"fire"),"Brand consumes connected Fire beyond original targeting range")
	state=fixture("galehook_talon",[Vector2i(2,1),Vector2i(3,1),Vector2i(4,1)])
	for enemy: Dictionary in state["enemies"]: enemy["block"]=0
	var forced: Dictionary = engine.apply_player_action(state,{"type":"melee","range":1,"damage":1,"push":2},Vector2i(2,1))
	check(forced["enemies"][0]["pos"]==Vector2i(4,1) and forced["enemies"][2]["pos"]==Vector2i(6,1),"Talon carries contiguous row two steps")
	check(forced["enemies"][1]["hp"]==100,"Talon does not grant collateral damage")
	state=fixture("cragbound_gauntlet",[Vector2i(7,7)])
	state["player"]["stoneskin"]=7
	var cover: Dictionary = engine.use_guardian_command(state,"raise_cover",Vector2i(2,1))
	check(cover["terrain"].size()==1 and cover["terrain"][0]["hp"]==7 and cover["player"]["stoneskin"]==0,"Cover banks all current armor")
	cover=engine._damage_terrain(cover,0,2)
	cover=engine.use_guardian_command(cover,"reclaim_cover",Vector2i(2,1))
	check(cover["terrain"].is_empty() and cover["player"]["stoneskin"]==5 and cover["player_movement_remaining"]==0,"Reclaim refunds surviving HP and spends remaining Move")
	state=fixture("procession_lantern",[Vector2i(7,7)])
	state["illusions"]=[{"id":1,"pos":Vector2i(4,4),"hp":2,"max_hp":2}]
	state["umbra"]["stage"]="heart"
	var procession: Dictionary = engine.apply_illusion_movement(state,1,Vector2i(5,4))
	check(procession["illusions"][0]["pos"]==Vector2i(5,4) and procession["player"]["pos"]==Vector2i(1,1),"Procession moves the decoy through darkness without moving player")
	check(procession["player_movement_remaining"]==1 and engine.effective_light_sources(procession).is_empty(),"Procession shares Move and grants no Light")
	var objectives=preload("res://scripts/combat_objective_rules.gd")
	check(objectives.display_name("kill_all")=="Defeat All Enemies","Defeat all copy")
	check(objectives.title_for_objective({"type":"kill_leader","leader_type":"warden"})=="Defeat the Leader","Ordinary leader copy")
	check(objectives.title_for_objective({"type":"kill_leader","leader_type":"ashen_reaver"})=="Defeat Ashen Reaver","Named guardian objective")
	print("Guardian relic contracts exercised")

func guardian_fixture(id: String, depth: int = 2, travel: Vector2i = Vector2i.ZERO) -> Dictionary:
	var info: Dictionary = Guardians.for_guardian(id)
	var boss_id: String = ""
	for candidate: String in Guardians.DEFINITIONS:
		if Guardians.DEFINITIONS[candidate]["id"] == id: boss_id = candidate
	var layout: Dictionary = Rooms.new().generate_room(92,{"coord":Vector2i(2,1),"depth":depth,"type":"guardian","element":info["element"],"boss_id":boss_id},travel)
	return Combat.new().create_combat(92,layout,{"hp":24,"max_hp":24,"deck_cards":["pale_spark"]})

func set_cycle(engine: RefCounted, state: Dictionary, slot: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	state["enemies"][0]["guardian_cycle"] = slot-1
	engine._assign_enemy_intent(state,0,rng)

func _test_encounter_edges() -> void:
	var engine := Combat.new()
	var rules = preload("res://scripts/guardian_combat_rules.gd")
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	var data = preload("res://scripts/game_data.gd")
	var paths = preload("res://scripts/path_utils.gd")
	for info: Dictionary in Guardians.DEFINITIONS.values():
		for depth: int in [2,6,10,14,18,22]:
			for entry: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
				var opening: Dictionary = guardian_fixture(info["id"],depth,entry)
				var occupied: Dictionary = {opening["player"]["pos"]:true}
				for actor: Dictionary in opening["enemies"]:
					check(paths.is_passable(opening["grid"],actor["pos"]) and not occupied.has(actor["pos"]),info["id"]+" rotated arena spawn is legal")
					occupied[actor["pos"]] = true
					check(paths.manhattan(opening["player"]["pos"],actor["pos"])>=3,info["id"]+" entry halo")
					var expected: int = ceili(float(data.enemy_def(actor["type"])["max_hp"])*(1.0+.08*int((depth-1)/4)))
					check(actor["max_hp"]==expected,info["id"]+" standard section HP scaling")
	var state: Dictionary = guardian_fixture("ashen_reaver")
	state = engine._damage_enemy(state,1,100)
	check(state["room_embers"]==0 and state["death_bonus_card_plays_this_turn"]==1,"finite helper grants one play and zero Embers")
	state = guardian_fixture("storm_cantor")
	state = engine._damage_enemy(state,1,100)
	check(state["death_bonus_card_plays_this_turn"]==0 and state["room_embers"]==0,"initial renewable wisp cannot farm rewards")
	set_cycle(engine,state,3)
	state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
	check(state["enemies"].size()==4 and state["enemies"][3]["summoned"],"Cantor replaces missing wisp with scheduled summoned actor")
	var summoned_id: int = state["enemies"][3]["id"]
	check(summoned_id>state["enemies"][2]["id"],"summon has a new stable id")
	set_cycle(engine,state,3)
	state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
	check(state["enemies"].size()==4,"Cantor wastes occupied summon slot")
	for status: String in ["freeze","shock"]:
		state = guardian_fixture("last_lamplighter")
		state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
		check(not state["guardian_braziers"][0]["lit"] and state["guardian_braziers"][1]["lit"],"Snuff preserves one light")
		check(state["enemies"].size()==3,"Snuff adds one temporary shade beside original")
		state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
		state["enemies"][0][status] = 1
		state = bytes_to_var(var_to_bytes(state))
		state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
		check(state["guardian_braziers"][0]["lit"] and state["guardian_braziers"][1]["lit"],status+" skipped Procession restores lights")
		check(state["enemies"][1]["hp"]>0 and state["enemies"][2]["hp"]==0 and state["enemies"][2]["departed"],status+" cleanup removes only outage shade without death reward")
		check(state["enemies"][0]["guardian_cycle"]==3,status+" advances the encounter cycle")
	state = fixture("",[Vector2i(7,7)])
	for y: int in range(1,8): state["grid"][y][4] = "wall"
	state["grid"][4][4] = "stone"
	check(not rules.preserves_routes(engine,state,Vector2i(4,4)),"outcrop cannot close a one-cell bridge between open rooms")
	check(rules.preserves_routes(engine,state,Vector2i(2,2)),"outcrop may redirect an open floor route")
	state = guardian_fixture("craghide")
	state["terrain"] = [{"kind":"crag_outcrop","owner_id":1,"pos":Vector2i(3,4),"hp":3},{"kind":"crag_outcrop","owner_id":1,"pos":Vector2i(5,4),"hp":3}]
	state["player"]["pos"] = Vector2i(4,4)
	set_cycle(engine,state,1)
	check(engine.enemy_intent_plan(state,0)["projected_attack"].has(Vector2i(2,4)),"quake shows declared outcrop threats")
	state = engine._damage_terrain(state,0,3)
	check(not engine.enemy_intent_plan(state,0)["projected_attack"].has(Vector2i(2,4)),"destroyed outcrop removes its quake tiles before resolution")
	var hp_before: int = state["player"]["hp"]
	state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
	check(hp_before-state["player"]["hp"]==7,"Groundsplit deals one ordinary hit from the surviving outcrop")
	state = guardian_fixture("rimejaw")
	state["player"]["pos"] = Vector2i(4,7)
	set_cycle(engine,state,1)
	var original: Dictionary = engine.enemy_intent_plan(state,0)
	var path: Array = original["path"]
	check(path.size()>1,"pounce fixture has an approach")
	if path.size()>1:
		state["terrain"].append({"kind":"raised_cover","pos":path[1],"hp":3,"max_hp":3,"owner_kind":"player"})
		var blocked: Dictionary = engine.enemy_intent_plan(state,0)
		check(blocked["path"].size()==1 and blocked["projected_attack"].is_empty(),"held approach preview stops at newly raised cover")
		var start: Vector2i = state["enemies"][0]["pos"]
		state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
		check(state["enemies"][0]["pos"]==start and state["player"]["hp"]==24,"blocked pounce cannot overlap cover or attack from its old endpoint")
	state = guardian_fixture("ashen_reaver")
	set_cycle(engine,state,2)
	state = engine.resolve_enemy_turn_with_steps(state,0)["state"]
	check(state["enemies"][0]["expose"]==3,"missed Reaver Fall still creates its punish window")

func _test_relic_edges() -> void:
	var engine := Combat.new()
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	var rules = preload("res://scripts/guardian_relic_rules.gd")
	var state: Dictionary = fixture("winters_spur",[Vector2i(7,7)])
	for tile: Vector2i in [Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3)]: surfaces.place(state,tile,"ice")
	check(engine.movement_cost_for_path(state,[Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3)])==2,"Spur charges a new straight segment after a corner")
	surfaces.place(state,Vector2i(3,2),"rubble")
	check(engine.movement_cost_for_path(state,[Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3)])==3,"Spur retains Rubble exit cost")
	state["relics"].append("procession_lantern")
	state["illusions"] = [{"id":1,"pos":Vector2i(2,1),"hp":3,"max_hp":3}]
	check(int(engine.illusion_movement_plan(state,1)["costs"].get(Vector2i(3,3),999))>2,"Illusion never inherits player's Ice discount")
	state = fixture("cragbound_gauntlet",[Vector2i(7,7)])
	state["player"]["stoneskin"] = 7
	var before: Dictionary = state.duplicate(true)
	check(engine.use_guardian_command(state,"raise_cover",Vector2i(1,1))==before,"invalid occupied cover target costs nothing")
	state["player_turn_restrictions"]["frozen"] = true
	check(engine.guardian_command_targets(state,"raise_cover").is_empty(),"Freeze prevents cover utility")
	state["player_turn_restrictions"]["frozen"] = false
	state = engine.use_guardian_command(state,"raise_cover",Vector2i(2,1))
	state = bytes_to_var(var_to_bytes(state))
	check(state["terrain"][0]["owner_kind"]=="player" and state["terrain"][0]["hp"]==7,"cover retains ownership and HP across serialization")
	state = engine._damage_terrain(state,0,7)
	check(surfaces.has_surface(state,Vector2i(2,1),"rubble") and engine.guardian_command_targets(state,"reclaim_cover").is_empty(),"destroyed cover leaves Rubble and cannot refund armor")
	state = fixture("galehook_talon",[Vector2i(2,1),Vector2i(3,1),Vector2i(4,1)])
	for actor: Dictionary in state["enemies"]: actor["block"]=0
	state["grid"][1][6] = "wall"
	state = engine.apply_player_action(state,{"type":"melee","range":1,"damage":1,"push":3},Vector2i(2,1))
	check(state["enemies"][0]["pos"]==Vector2i(3,1) and state["enemies"][2]["pos"]==Vector2i(5,1),"Talon stops the whole line at the first obstruction")
	state = fixture("galehook_talon",[Vector2i(2,1),Vector2i(4,1)])
	state["enemies"][0]["footprint"] = Vector2i(2,2)
	for actor: Dictionary in state["enemies"]: actor["block"]=0
	state = engine.apply_player_action(state,{"type":"melee","range":1,"damage":1,"push":1},Vector2i(2,1))
	check(state["enemies"][0]["pos"]==Vector2i(3,1) and state["enemies"][1]["pos"]==Vector2i(5,1),"Talon joins adjacent large and small full footprints")
	state = fixture("resonant_clapper",[Vector2i(2,1),Vector2i(6,1)])
	for actor: Dictionary in state["enemies"]: actor["block"]=0
	for x: int in range(2,7): surfaces.place(state,Vector2i(x,1),"electrified")
	state = engine.apply_player_action(state,{"type":"ranged","range":4,"damage":4,"element":"lightning"},Vector2i(2,1))
	check(state["enemies"][0]["hp"]==96 and state["enemies"][1]["hp"]==96,"Clapper does not enhance conduction without intrinsic Chain")
	state = fixture("resonant_clapper",[Vector2i(2,1),Vector2i(4,1),Vector2i(5,1)])
	for actor: Dictionary in state["enemies"]: actor["block"]=0
	surfaces.place(state,Vector2i(3,1),"electrified")
	state = engine.apply_player_action(state,{"type":"ranged","range":4,"damage":4,"chain":1},Vector2i(2,1))
	check(state["enemies"][1]["hp"]==95 and state["enemies"][2]["hp"]==94,"empty Chain relays do not increment damage hop")
	check(rules.boosted(3,2,25)==5 and rules.boosted(3,1,25)==4,"relic bonus rounds the combined amount half-up")
	state = fixture("procession_lantern",[Vector2i(5,4)])
	state["umbra"]["stage"] = "heart"
	state["illusions"] = [{"id":1,"pos":Vector2i(4,4),"hp":3,"max_hp":3}]
	check((engine.illusion_movement_plan(state,1)["paths"] as Dictionary).has(Vector2i(5,4)),"hidden occupancy does not leak into Illusion preview")
	var after: Dictionary = engine.apply_illusion_movement(state,1,Vector2i(5,4))
	check(after["illusions"][0]["pos"]==Vector2i(4,4),"actual hidden occupancy stops the decoy without overlap")
	check(after["player"]["pos"]==state["player"]["pos"] and engine.visible_enemy_ids(after).is_empty(),"unlit decoy neither moves hero nor grants vision")

func _test_reward_flow() -> void:
	var factory = preload("res://tools/guardian_inspection.gd")
	var run_engine = preload("res://scripts/run_engine.gd").new()
	var combat := Combat.new()
	var progression = preload("res://scripts/progression_store.gd")
	var data = preload("res://scripts/game_data.gd")
	var exclusives: Array[String] = []
	for id: String in data.relics():
		if bool(data.relic_def(id).get("exclusive_guardian",false)): exclusives.append(id)
	check(exclusives.size()==6,"six exclusive Guardian trophies")
	for info: Dictionary in Guardians.DEFINITIONS.values():
		var route: Dictionary = factory.build(run_engine,combat,run_engine.create_new_run(7262026,progression.default_data()),{"guardian_id":info["id"],"guardian_case":"map_choice"})
		for node: Dictionary in route["rooms"].values():
			if str(node.get("guardian_id",""))!=info["id"]:continue
			# Some middle paths begin with a noncombat room before the Guardian.
			# The map-choice fixture intentionally opens before that branch choice.
			for prior: Dictionary in route["rooms"].values():
				for link: Dictionary in prior.get("connections",[]):
					if link["coord"]==node["coord"]:
						route["current_room"]=prior["coord"]
						prior["cleared"]=true
			var entered: Dictionary = run_engine.move_to_pre_battle(route,node["coord"])
			check(str(entered["mode"])=="pre_battle",info["id"]+" map choice enters pre-battle")
		var state: Dictionary = factory.build(run_engine,combat,run_engine.create_new_run(7262026,progression.default_data()),{"guardian_id":info["id"],"guardian_case":"encounter"})
		var battle: Dictionary = state["combat_state"].duplicate(true)
		battle["enemies"][0]["hp"] = 0
		var reward: Dictionary = run_engine.finish_combat(state,battle)
		check(reward["mode"]=="treasure" and reward["pending_relics"]==[info["relic"]],"leader defeat awards only "+info["relic"])
		check(reward["combat_state"].is_empty(),"remaining helpers are cleared without forcing another fight")
		var resumed: Dictionary = bytes_to_var(var_to_bytes(reward))
		var claimed: Dictionary = run_engine.claim_relic(resumed,info["relic"])
		check(claimed["relics"].count(info["relic"])==1 and claimed["guardian_reward"].is_empty(),"trophy claim persists once and clears pending state")
		claimed = run_engine.finish_combat(claimed,battle)
		claimed = run_engine.claim_relic(claimed,info["relic"])
		check(claimed["relics"].count(info["relic"])==1 and claimed["pending_relics"].is_empty(),"replayed completed Guardian cannot reoffer its trophy")
		for offer: String in run_engine._generate_relic_choices(state,Vector2i(1,0)):
			check(not exclusives.has(offer),"exclusive trophies never leak into ordinary offers")

func _test_cover_and_force_boundaries() -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture("cragbound_gauntlet",[Vector2i(4,1)])
	state["player"]["stoneskin"]=3
	state=engine.use_guardian_command(state,"raise_cover",Vector2i(2,1))
	var shot: Dictionary = {"type":"ranged","range":4,"damage":4}
	check(not engine.valid_targets_for_player_action(state,shot).has(Vector2i(4,1)),"raised cover blocks the player's ranged attack sight")
	check(engine.valid_targets_for_player_action(state,shot).has(Vector2i(2,1)),"the blocking cover itself remains attackable")
	check(not engine.combat_line_of_sight(state,Vector2i(4,1),Vector2i(1,1)),"cover blocks enemy attack sight too")
	state=fixture("",[Vector2i(2,4)])
	for y: int in range(1,8):
		for x: int in range(1,8): state["grid"][y][x]="stone" if y==4 else "wall"
	state["player"]["pos"]=Vector2i(6,4)
	state["terrain"]=[{"id":"weak_cover","kind":"raised_cover","pos":Vector2i(4,4),"hp":2,"max_hp":2,"owner_kind":"player"}]
	state["enemies"][0]["intent"]={"id":"approach","name":"Approach","time":5,"actions":[{"type":"move_toward","range":2},{"type":"melee","range":1,"damage":3}]}
	state=engine.resolve_enemy_turn_with_steps(state,0)["state"]
	check(int(state["terrain"][0]["hp"])==0 and not engine._occupied_actor_tiles(state).has(Vector2i(4,4)),"normal enemy AI clears weak cover on its route")
	state=fixture("galehook_talon",[Vector2i(2,1),Vector2i(3,1)])
	state["player"]["pos"]=Vector2i(4,1)
	for actor: Dictionary in state["enemies"]: actor["block"]=0
	state=engine.apply_player_action(state,{"type":"ranged","range":4,"damage":1,"pull":2},Vector2i(2,1))
	check(state["enemies"][0]["pos"]==Vector2i(2,1) and state["enemies"][1]["pos"]==Vector2i(3,1),"Talon never carries a group into the player")
	state=fixture("resonant_clapper",[Vector2i(3,1),Vector2i(3,3),Vector2i(4,1),Vector2i(4,3)])
	for actor: Dictionary in state["enemies"]: actor["block"]=0
	var heads: Array[Vector2i] = [Vector2i(3,1),Vector2i(3,3)]
	state=engine._resolve_board_attack(state,{"type":"aoe","range":3,"damage":4,"chain":1},Vector2i(3,1),"player",-1,{},heads)
	check(state["enemies"][0]["hp"]==96 and state["enemies"][1]["hp"]==96,"multiple native Chain heads each start at base damage")
	check(state["enemies"][2]["hp"]==95 and state["enemies"][3]["hp"]==95,"each head owns a distinct first hop without a global counter")


func _test_relic_forecast_regressions() -> void:
	var engine := Combat.new()
	var surfaces = preload("res://scripts/board_surface_rules.gd")
	var data = preload("res://scripts/game_data.gd")
	var state: Dictionary = fixture("ashen_brand",[Vector2i(4,3)])
	state["player"]["pos"]=Vector2i(4,4)
	state["enemies"][0]["block"]=0
	surfaces.place(state,Vector2i(4,3),"fire")
	var phoenix: Dictionary = data.card_def("phoenix_cleave")["actions"][-1]
	var result: Dictionary = engine.apply_player_action(state,phoenix)
	check(result["enemies"][0]["hp"]==90 and not surfaces.has_surface(result,Vector2i(4,3),"fire"),"Brand preserves Phoenix Cleave's automatic Detonate")
	state=fixture("ashen_brand",[Vector2i(2,4),Vector2i(6,4)])
	state["player"]["pos"]=Vector2i(4,4)
	for enemy: Dictionary in state["enemies"]:enemy["block"]=0
	for tile: Vector2i in [Vector2i(2,4),Vector2i(3,4),Vector2i(5,4),Vector2i(6,4)]:surfaces.place(state,tile,"fire")
	var pattern: Dictionary = {"type":"detonate","target":"player","damage":4,"pattern":[[-1,0],[1,0]],"rotate":false}
	result=engine.apply_player_action(state,pattern)
	check(result["enemies"][0]["hp"]==95 and result["enemies"][1]["hp"]==95,"Brand expands both disconnected Fire seeds beyond a multi-tile pattern")
	for tile: Vector2i in [Vector2i(2,4),Vector2i(3,4),Vector2i(5,4),Vector2i(6,4)]:check(not surfaces.has_surface(result,tile,"fire"),"Brand consumes every seeded component")
	state=fixture("ashen_brand",[Vector2i(4,4)])
	state["player"]["pos"]=Vector2i(4,5)
	state["enemies"][0]["block"]=0
	for tile: Vector2i in [Vector2i(3,4),Vector2i(4,4),Vector2i(5,4)]:surfaces.place(state,tile,"fire")
	pattern["pattern"]=[[-1,-1],[1,-1]]
	result=engine.apply_player_action(state,pattern)
	check(result["enemies"][0]["hp"]==94,"Two pattern seeds in one Fire component cannot double-count its crosses")
	var attack: Dictionary = {"type":"ranged","range":4,"damage":4,"chain":1,"push":1}
	state=fixture("galehook_talon",[Vector2i(2,1),Vector2i(3,1),Vector2i(5,1)])
	for enemy: Dictionary in state["enemies"]:enemy["block"]=0
	state["enemies"][0]["hp"]=1
	var preview: Dictionary = engine.surface_preview_for_player_action(state,attack,Vector2i(2,1))
	result=engine.apply_player_action(state,attack,Vector2i(2,1))
	check(result["enemies"][0]["hp"]==0 and result["enemies"][1]["hp"]==96 and result["enemies"][2]["hp"]==96,"Talon's defeated Chain head leaves both live hops available")
	# B moves beside C; C's own Push then carries their newly contiguous group.
	check(result["enemies"][1]["pos"]==Vector2i(5,1) and result["enemies"][2]["pos"]==Vector2i(6,1),"Talon resolves each new native target's live group after a defeated head")
	check(preview["state"]["enemies"]==result["enemies"] and preview["chain_hits"].size()==3,"Talon lethal-head preview matches committed actors and full route")
	for with_talon: bool in [false,true]:
		state=fixture("resonant_clapper",[Vector2i(2,1),Vector2i(4,1),Vector2i(6,1)])
		if with_talon:state["relics"].append("galehook_talon")
		for enemy: Dictionary in state["enemies"]:enemy["block"]=0
		state["enemies"][1]["hp"]=5
		preview=engine.surface_preview_for_player_action(state,attack,Vector2i(2,1))
		result=engine.apply_player_action(state,attack,Vector2i(2,1))
		check(result["enemies"][1]["hp"]==0 and result["enemies"][1]["pos"]==Vector2i(4,1),"Clapper's amplified lethal hop cannot Push its defeated victim")
		check(result["enemies"][2]["hp"]==100 and result["enemies"][2]["pos"]==Vector2i(6,1),"Clapper cannot continue Chain from an imaginary displaced position")
		check(preview["chain_hits"].size()==2 and preview["state"]["enemies"]==result["enemies"],"Clapper lethal-hop forecast matches commitment, including Talon combination")

func _test_inspection_rules() -> void:
	var data = preload("res://scripts/game_data.gd")
	for info: Dictionary in Guardians.DEFINITIONS.values():
		var summary: String = Guardians.inspection_summary({"type":info["id"]})
		check(summary.contains("Defeat "+str(info["name"])) and summary.contains("remaining helpers leave"), "Guardian inspection explains victory for "+str(info["id"]))
		for helper: String in info["helpers"]:
			var detail: String = Guardians.inspection_summary({"type":helper,"guardian_helper":true})
			check(not detail.is_empty() and detail.contains("Embers"), "Guardian helper inspection explains return and reward for "+helper)
	check(Guardians.inspection_summary({"type":"lightning_wisp"}).is_empty(), "ordinary Wisps do not inherit Guardian reinforcement rules")
	check(Guardians.inspection_summary({"type":"wick_shade","guardian_helper":true}).contains("starting Shade stays"), "Shade inspection distinguishes temporary and starting helpers")
	var snuff: Dictionary = data.enemy_def("last_lamplighter")["intents"][0]
	var procession: Dictionary = data.enemy_def("last_lamplighter")["intents"][2]
	check(Guardians.intent_notes(snuff).contains("Extinguishes one arena brazier until Last Procession finishes"), "Snuff inspection explains outage duration")
	check(Guardians.intent_notes(procession).contains("Freeze or Shock") and Guardians.intent_notes(procession).contains("dismisses Shades summoned by Snuff"), "Procession inspection explains unconditional light and Shade cleanup")
	check(Guardians.intent_notes(data.enemy_def("ashen_reaver")["intents"][2]).contains("3 Expose"), "Executioner inspection explains Expose recovery")
	check(Guardians.intent_notes(data.enemy_def("rimejaw")["intents"][0]).contains("Leaves Ice"), "Rime Trail inspection explains trailing Ice")
	check(Guardians.intent_notes(data.enemy_def("craghide")["intents"][1]).contains("destroyed outcrops cannot burst"), "Groundsplit inspection explains destructible counterplay")

	var icons = preload("res://scripts/action_icon_library.gd")
	var summon_text: String = icons.plain_text_for_rows(icons.rows_for_actions(snuff["actions"]))
	check(summon_text.contains("Summon") and not summon_text.contains("Shock"), "Snuff summary identifies summoning rather than Shock")

	var peal_text: String = icons.plain_text_for_rows(icons.rows_for_actions(data.enemy_def("storm_cantor")["intents"][1]["actions"]))
	check(peal_text.contains("Conducted hits:") and not peal_text.contains("Shape Ground"), "Peal describes its actual conducted-hit condition")
	check(Guardians.intent_notes(data.enemy_def("rime_spitter")["intents"][0]).contains("Leaves Ice at the end"), "Rime Needle inspection explains terminal Ice")

	var upheaval_text: String = icons.plain_text_for_rows(icons.rows_for_actions(data.enemy_def("craghide")["intents"][0]["actions"]))
	check(upheaval_text.contains("Raise Terrain") and not upheaval_text.contains("Stoneskin"), "Upheaval identifies terrain creation rather than armor")
	var burst_text: String = icons.plain_text_for_rows(icons.rows_for_actions(data.enemy_def("craghide")["intents"][1]["actions"]))
	check(burst_text.contains("Outcrop burst") and not burst_text.contains("Spire"), "Groundsplit identifies surviving outcrops")
	var rooms := Rooms.new()
	for entry: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN]:
		var layout: Dictionary = rooms.generate_room(92,{"coord":Vector2i(2,1),"depth":2,"type":"guardian","element":"air","boss_id":"vaeloryx"},entry)
		check(layout["traps"].size()==2, "Roc retains both authored Air traps for every entrance")
		for trap: Dictionary in layout["traps"]:
			check(trap["element"]=="air" and trap["damage"]>0,"Roc traps use the ordinary scaled Air trap")
			check(str(layout["grid"][trap["pos"].y][trap["pos"].x])=="stone", "Roc traps rotate onto legal floor")
			for enemy: Dictionary in layout["enemies"]:check(enemy["pos"]!=trap["pos"],"Roc traps do not overlap starting actors")
			for loot: Dictionary in layout["loot"]:check(loot["pos"]!=trap["pos"],"Roc traps do not overlap staged loot")
