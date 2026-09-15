extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Fixtures = preload("res://tests/suites/guardian_suite.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	var fixture := Fixtures.new()
	var state: Dictionary = fixture.fixture("", [Vector2i(4,1)])
	state["enemies"][0]["block"] = 0
	var seed := Vector2i(3,1)
	Surfaces.place(state,seed,"fire")
	var actions: Array = engine.card_play_actions("cinderline_tempo",state)
	expect.call(engine.valid_targets_for_player_action(state,actions[0]).has(seed),"Linked Detonate can aim at empty Fire")
	expect.call(not engine.valid_targets_for_player_action(state,actions[0]).has(Vector2i(2,1)),"Plain bolt does not gain unrelated empty ground targets")
	var after: Dictionary = engine.apply_player_action(state,actions[0],seed)
	expect.call(after["enemies"][0]["hp"]==state["enemies"][0]["hp"],"Ground bolt has no phantom enemy hit")
	expect.call(not engine.player_action_needs_target(actions[1]),"Detonate reuses the single card target")
	after=engine.apply_player_action(after,actions[1],Vector2i(-1,-1))
	expect.call(after["enemies"][0]["hp"]==94 and not Surfaces.has_surface(after,seed,"fire"),"Ground Detonate damages an adjacent enemy and consumes Fire")
	for type: String in ["melee","ranged","push","pull"]:
		var surface_attack: Dictionary = {"type":type,"range":2,"damage":2,"surface":"fire"}
		expect.call(engine.valid_targets_for_player_action(state,surface_attack).has(Vector2i(2,2)),type+" surface attack accepts empty floor")
		var placed: Dictionary = engine.apply_player_action(state,surface_attack,Vector2i(2,2))
		expect.call(Surfaces.has_surface(placed,Vector2i(2,2),"fire"),type+" ground target creates surface")
		expect.call(not engine.valid_targets_for_player_action(state,surface_attack).has(Vector2i(5,5)),type+" retains range")
	state["grid"][1][2]="wall"
	expect.call(not engine.valid_targets_for_player_action(state,actions[0]).has(seed),"Ground bolt retains line of sight")
	state=fixture.fixture("cragbound_gauntlet",[Vector2i(3,1)])
	state["enemies"][0]["block"]=0
	var earth: Dictionary = engine.card_play_actions("root_snare",state)[0]
	expect.call(int(earth.get("outcrop_health",0))==3,"Gauntlet modifies ranged Earth action")
	expect.call(not (engine.card_play_actions("pale_spark",state)[0] as Dictionary).has("outcrop_health"),"Gauntlet leaves other elements unchanged")
	var direct: Dictionary = engine.apply_player_action(state,earth,Vector2i(3,1))
	expect.call(direct["terrain"].is_empty() and direct["enemies"][0]["hp"]==98,"Occupied Earth target retains ordinary spell outcome")
	state["enemies"][0]["hp"]=1
	direct=engine.apply_player_action(state,earth,Vector2i(3,1))
	expect.call(direct["terrain"].is_empty(),"Killing an enemy does not turn its occupied target into an outcrop")
	state=fixture.fixture("cragbound_gauntlet",[Vector2i(7,7)])
	var area: Dictionary = engine.card_play_actions("grave_dust_satchel",state)[0]
	after=engine.apply_player_action(state,area,Vector2i(2,2))
	expect.call(after["terrain"].size()==1 and after["terrain"][0]["pos"]==Vector2i(2,2),"Area Earth spell creates one outcrop at the center")
	expect.call(not engine.valid_targets_for_player_action(after,earth).has(Vector2i(0,0)),"Outcrops cannot be raised in walls")
	var creation_events: Array = after["surface_events"].filter(func(event: Dictionary)->bool: return str(event.get("kind",""))=="terrain_created")
	expect.call(creation_events.size()==1 and creation_events[0]["source"].get("card_id","")=="grave_dust_satchel","Outcrop outcome records normal card provenance once")
	var self_area: Dictionary = Data._apply_relic_action_mod({"element":"earth","actions":[{"type":"aoe","range":0,"damage":2}]},{"element":"earth","type":"card_action_mod","action_types":["ranged","aoe"],"min_range":1,"field":"outcrop_health","amount":3})
	expect.call(not self_area["actions"][0].has("outcrop_health"),"Self-centered Earth actions do not gain outcrop placement")

	var run_engine:=preload("res://scripts/run_engine.gd").new()
	var study: Dictionary=preload("res://tools/guardian_inspection.gd").build(run_engine,engine,run_engine.create_new_run(7262026,preload("res://scripts/progression_store.gd").default_data()),{"guardian_id":"ashen_reaver","guardian_case":"ground_targeting"})
	var studied: Dictionary=study["combat_state"]
	expect.call(not (study["relics"] as Array).has("ashen_brand") and studied["deck"]["hand"][0]=="cinderline_tempo","Ground-target fixture has a real Detonate card and no trophy")
	expect.call(engine.valid_targets_for_player_action(studied,engine.card_play_actions("cinderline_tempo",studied)[0]).has(Vector2i(3,5)),"Saved study places empty Fire in normal Detonate reach")
