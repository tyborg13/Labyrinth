extends RefCounted
## Director ladders are cumulative and encounter overrides precede depth scaling.
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Tuning = preload("res://tools/guardian_tuning_ladders.gd")
const GuardianRules = preload("res://scripts/guardian_combat_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const TEST_DEPTHS: Array = [1,9]
const TEST_ROOM_SEED: int = 92
const TEST_LAMPLIGHTER_ROOM: Dictionary = {"coord":Vector2i(2,1),"depth":2,"type":"guardian","element":"shadow","boss_id":"noctyrax"}
const TEST_PLAYER: Dictionary = {"hp":24,"max_hp":24,"deck_cards":["pale_spark"]}

static func run(expect: Callable) -> void:
	var saved_enemies: Dictionary = Data.enemies().duplicate(true)
	var saved_rule: Dictionary = Rules.data()["instances"]["storm_cantor"].duplicate(true)
	for rung: int in range(1,4):
		Tuning.apply("rimejaw",rung)
		var rime: Dictionary = Data.enemy_def("rimejaw")
		expect.call(_damage(rime,"harrowing_pounce")==6,"Rimejaw rungs retain Pounce six")
		expect.call(rime["max_hp"]==(34 if rung>=2 else 38),"Rimejaw HP changes only from rung two")
		expect.call(_damage(rime,"frostbite")==int(5 if rung>=3 else 6),"Rime Bite changes only at rung three")
	for rung: int in range(1,5):
		Tuning.apply("storm_cantor",rung)
		var cantor: Dictionary = Data.enemy_def("storm_cantor")
		expect.call(not Data.enemy_def("bell_tender").has("guardian_intent_action_overrides"),"Historical Cantor ladders exclude final Tender tuning")
		expect.call(cantor["max_hp"]==46 and _damage(cantor,"broken_rhythm")==int(7 if rung>=2 else 5),"Cantor HP and Broken Rhythm ladder is cumulative")
		var cap: int = 2 if rung>=3 else 1
		expect.call(_cap(cantor,"call_the_spark")==cap,"Call the Spark cap changes from rung three")
		var choice: Dictionary = GuardianRules.choose_intent({"enemies":[{"type":"lightning_wisp","hp":Data.enemy_def("lightning_wisp")["max_hp"],"guardian_helper":true}]},{},cantor["intents"],3)
		expect.call(choice["id"]==("call_the_spark" if cap==2 else "lay_the_choir"),"Cantor selection reads authored cap with one living Wisp")
		var rule: Dictionary = Rules.instance_for("storm_cantor")
		var damage: int = 4 if rung==4 else 3
		expect.call(rule["dials"]["damage"]==damage and rule["sentence"].contains("for %d, with Chain 2" % damage),"Peal panel and beat dial change together")
	for rung: int in range(1,6):
		Tuning.apply("last_lamplighter",rung)
		var lamp: Dictionary = Data.enemy_def("last_lamplighter")
		expect.call(_damage(lamp,"last_procession")==6,"Lamplighter rungs retain Procession six")
		expect.call(lamp["max_hp"]==int(36 if rung>=2 else 44),"Lamplighter HP changes from rung two")
		expect.call(_cap(lamp,"snuff")==int(1 if rung>=3 else 2),"Snuff cap changes from rung three")
		expect.call(_damage(lamp,"mourning_hook")==int(3 if rung>=4 else 4),"Mourning Hook changes from rung four")
		var engine := Combat.new()
		var base: Array = Data.enemy_def("wick_shade")["intents"]
		for depth: int in TEST_DEPTHS:
			var guardian: Array = engine._scaled_enemy_intents(base,depth,{"room_type":"guardian"},{"type":"wick_shade"})
			var ordinary: Array = engine._scaled_enemy_intents(base,depth,{"room_type":"combat"},{"type":"wick_shade"})
			for index: int in range(2):
				var expected: Dictionary = base[index].duplicate(true)
				if rung==5: expected["actions"][1]["damage"]=1.0
				var scaled: Dictionary = engine._scale_enemy_intent(expected,depth,{"room_type":"guardian"},{"type":"wick_shade"})
				expect.call(guardian[index]==scaled,"Guardian Shade override applies before ordinary depth scaling")
				expect.call(ordinary[index]==engine._scale_enemy_intent(base[index],depth,{"room_type":"combat"},{"type":"wick_shade"}) and base[index]["actions"][1]["damage"]==2,"Ordinary Shade and Grimoire definition stay at two")
	# Exercise the player-facing inspection path with the final helper override.
	var scene := preload("res://scripts/run_scene.gd").new()
	scene.set("_pre_battle_preview_run_state",{"combat_state":{"room_type":"guardian","room_depth":1}})
	for intent: Dictionary in scene._pre_battle_known_enemy_intents("wick_shade"):
		expect.call(intent["actions"][1]["damage"]==1,"Pre-battle Guardian inspection shows Shade override")
	scene.free()
	_extended(expect)
	_final(expect)
	Data.enemies().clear()
	Data.enemies().merge(saved_enemies,true)
	Rules.data()["instances"]["storm_cantor"]=saved_rule

static func _extended(expect: Callable) -> void:
	for rung: int in range(5,9):
		Tuning.apply_extended("storm_cantor",rung)
		var cantor: Dictionary = Data.enemy_def("storm_cantor")
		expect.call(cantor["intents"][0]["actions"][1]["guardian_count"]==6,"Extended Cantor retains six charged tiles")
		expect.call(cantor["max_hp"]==int(56 if rung>=6 else 46),"Extended Cantor HP changes at rung six")
		expect.call(_damage(cantor,"broken_rhythm")==int(9 if rung>=7 else 7),"Extended Cantor melee changes at rung seven")
		var chain: int = 3 if rung==8 else 2
		var rule: Dictionary = Rules.instance_for("storm_cantor")
		expect.call(rule["dials"]["chain"]==chain and rule["sentence"].contains("for 4, with Chain %d" % chain),"Extended Cantor panel and Chain dial agree")
	for rung: int in range(6,9):
		Tuning.apply_extended("last_lamplighter",rung)
		var lamp: Dictionary = Data.enemy_def("last_lamplighter")
		expect.call(lamp["max_hp"]==30 and _damage(lamp,"last_procession")==int(5 if rung>=7 else 6),"Extended Lamplighter HP and Procession are cumulative")
		var library = preload("res://scripts/guardian_library.gd")
		var helper_count: int = 0 if rung==8 else 1
		expect.call(library.for_guardian("last_lamplighter")["helpers"].size()==helper_count and _cap(lamp,"snuff")==1,"Starting Shade override leaves Snuff cap one")
		var layout: Dictionary = preload("res://scripts/room_generator.gd").new().generate_room(TEST_ROOM_SEED,TEST_LAMPLIGHTER_ROOM.duplicate(true),Vector2i.ZERO)
		var engine := Combat.new()
		var state: Dictionary = engine.create_combat(TEST_ROOM_SEED,layout,TEST_PLAYER.duplicate(true))
		expect.call(state["enemies"].size()==1+helper_count,"Production layout respects initial helper override")
		if helper_count==0:
			state=engine.resolve_enemy_turn_with_steps(state,0)["state"]
			expect.call(state["enemies"].size()==2 and state["enemies"][1]["type"]=="wick_shade" and int(state.get("pending_summon_card_plays",0))==1,"Snuff brings the first Shade and pays from an empty starting roster")

static func _damage(definition: Dictionary, id: String) -> int:
	for intent: Dictionary in definition["intents"]:
		if intent["id"]==id:
			for action: Dictionary in intent["actions"]:
				if action.has("damage"): return int(action["damage"])
	return -1

static func _final(expect: Callable) -> void:
	var engine := Combat.new()
	for rung: int in range(9,13):
		Tuning.apply_final("storm_cantor",rung)
		var cantor: Dictionary = Data.enemy_def("storm_cantor")
		expect.call(cantor["max_hp"]==int(66 if rung>=10 else 56),"Final Cantor HP rises only at rung ten")
		expect.call(_damage(cantor,"broken_rhythm")==int(11 if rung>=11 else 9),"Final Cantor melee rises only at rung eleven")
		expect.call(cantor["intents"][0]["actions"][1].get("guardian_fill_count",false),"Final ladder includes the Choir tile-budget repair")
		var rule: Dictionary = Rules.instance_for("storm_cantor")
		expect.call(int(rule["dials"]["damage"])==3 and int(rule["dials"]["chain"])==2 and rule["sentence"].ends_with("for 3, with Chain 2."),"Every final rung restores approved Peal dials and copy")
		var base: Array = Data.enemy_def("bell_tender")["intents"]
		for depth: int in TEST_DEPTHS:
			var guardian: Array = engine._scaled_enemy_intents(base,depth,{"room_type":"guardian"},{"type":"bell_tender"})
			var ordinary: Array = engine._scaled_enemy_intents(base,depth,{"room_type":"combat"},{"type":"bell_tender"})
			var expected: Dictionary = base[1].duplicate(true)
			if rung==12: expected["actions"][1]["damage"]=4.0
			expect.call(guardian[1]==engine._scale_enemy_intent(expected,depth,{"room_type":"guardian"},{"type":"bell_tender"}),"Rung twelve Tender override precedes depth scaling")
			expect.call(ordinary[1]==engine._scale_enemy_intent(base[1],depth,{"room_type":"combat"},{"type":"bell_tender"}) and base[1]["actions"][1]["damage"]==3,"Ordinary Tender Staff Bolt remains three")
	var scene := preload("res://scripts/run_scene.gd").new()
	scene.set("_pre_battle_preview_run_state",{"combat_state":{"room_type":"guardian","room_depth":1}})
	expect.call(scene._pre_battle_known_enemy_intents("bell_tender")[1]["actions"][1]["damage"]==4,"Pre-battle Guardian inspection shows the Tender override")
	scene.free()

static func _cap(definition: Dictionary, id: String) -> int:
	for intent: Dictionary in definition["intents"]:
		if intent["id"]==id:
			for action: Dictionary in intent["actions"]:
				if action.has("guardian_cap"): return int(action["guardian_cap"])
	return -1
