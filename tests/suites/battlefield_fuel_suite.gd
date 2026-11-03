extends RefCounted
## bos-04: fresh fuel through production activation scheduling, not direct beats.
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Boss = preload("res://tests/suites/dragon_boss_suite.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Store = preload("res://scripts/progression_store.gd")
const PROOF_HP: int = 1000
const LONG_ACTIVATION_TIME: int = 60
const SAVE_PATH: String = "user://bos04_fuel.save"

static func run(expect: Callable) -> void:
	_generic_scheduler(expect)
	_provenance(expect)
	_cantor(expect)
	_dragon_scheduler(expect,"zekarion")
	_dragon_scheduler(expect,"vyraketh")
	_iskaldra(expect)
	preload("res://tests/suites/battlefield_conduction_suite.gd").run(expect)

static func _generic_scheduler(expect: Callable) -> void:
	var engine := Combat.new()
	for id: String in ["wildfire","frostbite","lightning_storm","upheaval"]:
		var state: Dictionary = Base.battle(engine)
		state["player"]["hp"] = PROOF_HP
		state["player"]["max_hp"] = PROOF_HP
		var dials: Dictionary = {"wildfire":{"spread":"all"},"frostbite":{"damage":2},"lightning_storm":{"damage":2,"chain":0},"upheaval":{"pattern":"line_between","length":3,"health":2}}[id]
		var instance: Dictionary = Base.rule(id,dials,id=="upheaval")
		# All use the real after-player boundary here. Production boss cadences
		# are independently pinned; no clock or resolver shortcut is used.
		instance["cadence"] = {"anchor":"after_player_turn","every":1}
		Rules.install(engine,state,instance)
		if id=="upheaval":
			# Replanning after an early beat would now produce different geometry.
			state["player"]["pos"] = Vector2i(7,5)
		var surface: String = {"wildfire":"fire","frostbite":"ice","lightning_storm":"electrified","upheaval":""}[id]
		if not surface.is_empty(): Surfaces.place(state,state["player"]["pos"],surface,{"actor_kind":"player"})
		var before: Dictionary = state.duplicate(true)
		var fresh_forecast: Dictionary = Rules.forecast(engine,state)
		var fresh: Dictionary = engine.finish_player_activation(state)
		expect.call(fresh_forecast["hits"].is_empty() and _tile_count(fresh_forecast)==0,id+" fresh fuel has no danger forecast")
		expect.call(fresh["surfaces"]==before["surfaces"] and fresh["terrain"]==before["terrain"] and fresh["player"]["hp"]==before["player"]["hp"],id+" same-activation scheduler beat leaves fresh fuel visible and unused")
		if id=="upheaval":
			expect.call(fresh["battlefield_rule"]["marks"]==before["battlefield_rule"]["marks"],"Fresh Upheaval marks survive hero movement and an ineligible beat")
			expect.call(fresh["battlefield_rule"]["marks_source"]==before["battlefield_rule"]["marks_source"],"Fresh Upheaval marks retain their exact provenance across an early beat")
		state = engine.advance_to_next_player_turn_with_steps(fresh)["state"]
		expect.call(int(state["turn"])==int(before["turn"])+1,id+" production scheduler begins the next player activation")
		var mature_forecast: Dictionary = Rules.forecast(engine,state)
		expect.call(not mature_forecast["hits"].is_empty() or _tile_count(mature_forecast)>0,id+" next activation makes old fuel eligible")
		var after: Dictionary = engine.finish_player_activation(state)
		var actual: Dictionary = Rules.Outcomes.project(engine,state,after)
		for key: String in ["hits","tiles"]: expect.call(mature_forecast[key]==actual[key],id+" mature scheduler resolution equals forecast "+key)
		if id=="wildfire":
			# Fire entry remains immediate, independently of beat eligibility.
			var hazard: Dictionary = Base.battle(engine)
			Surfaces.place(hazard,Vector2i(6,5),"fire")
			var hp: int = hazard["player"]["hp"]
			hazard["player"]["pos"] = Vector2i(6,5)
			hazard = engine.surface_actor_arrival(hazard,"player",-1,Vector2i(5,5))
			expect.call(hazard["player"]["hp"]==hp-Surfaces.FIRE_ENTRY_DAMAGE,"Fresh Fire keeps ordinary entry damage")

static func _tile_count(forecast: Dictionary) -> int:
	var count: int = 0
	for tiles: Array in forecast["tiles"].values(): count += tiles.size()
	return count

static func _provenance(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(engine)
	var tile: Vector2i = state["player"]["pos"]
	Surfaces.place(state,tile,"fire",{"actor_kind":"enemy","actor_id":1,"source_kind":"battlefield_rule","rule":"wildfire"})
	var source: Dictionary = Surfaces.surface_at(state,tile)["elemental_source"].duplicate(true)
	expect.call(source.get("laid_player_activation",-1)==state["turn"] and source["rule"]=="wildfire","Ground preserves beat provenance and records its lay activation")
	state = engine.prepare_next_player_turn(state)
	Surfaces.place(state,tile,"fire",{"actor_kind":"player"})
	expect.call(Surfaces.surface_at(state,tile)["elemental_source"]==source,"A no-op repaint never refreshes old ground")
	expect.call(Surfaces.fuel_tiles(state,"fire").has(tile),"Existing Fire matures at player-activation start")
	Surfaces.place(state,tile,"ice",{"actor_kind":"player"})
	expect.call(Surfaces.fuel_tiles(state,"ice").is_empty(),"An elemental replacement starts a new eligibility boundary")
	Surfaces.place(state,tile,"rubble",{"actor_kind":"room"})
	expect.call(Surfaces.fuel_tiles(state,"rubble").is_empty(),"Rubble uses the same independent ground-layer boundary")
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	file.store_var({"combat_state":state}); file.close()
	var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
	expect.call(loaded["surfaces"]==state["surfaces"] and Surfaces.fuel_tiles(loaded,"ice").is_empty(),"Continue preserves fresh fuel timestamps and eligibility")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Surfaces.surface_at(state,tile)["elemental_source"].erase("laid_player_activation")
	expect.call(Surfaces.fuel_tiles(state,"ice").has(tile),"Legacy ground without a timestamp retains its announced eligibility")

static func _cantor(expect: Callable) -> void:
	var engine := Combat.new()
	var layout: Dictionary = Rooms.new().generate_room(92,{"coord":Vector2i(2,1),"depth":2,"type":"guardian","element":"lightning","boss_id":"zekarion"},Vector2i.ZERO)
	var state: Dictionary = engine.create_combat(92,layout,{"hp":24,"max_hp":24,"deck_cards":["daybreak","daybreak","reprise","reprise","reprise"]})
	for id: String in ["daybreak","daybreak","reprise","reprise"]:
		var index: int = state["deck"]["hand"].find(id)
		expect.call(index>=0 and engine.hand_card_has_play_budget(state,index),"Cantor reproducer legally plays "+id)
		state = engine.prepare_player_card(state,index)
		var actions: Array = engine.card_play_actions(id,state)
		for action: Dictionary in actions: state = engine.apply_player_action(state,action)
		state = engine.finish_player_card(state,index,engine.card_plays_spent_for_actions(actions))
	expect.call(state["player_turn_time_spent"]==26 and engine.cards_remaining_this_turn(state)==0,"Cantor exact legal sequence spends 26 Time and all plays")
	var result: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))
	var after: Dictionary = result["state"]
	var intents: Array[String]
	for step: Dictionary in result["steps"]:
		if step.get("kind","")=="intent": intents.append(str(step.get("intent_name","")))
	var beats: Array = after.get("surface_events",[]).filter(func(event: Dictionary) -> bool: return event.get("kind","")=="battlefield_rule_fired")
	expect.call(after["initiative_clock"]==35 and beats.size()==1,"Cantor scheduler still reaches Choir/helpers/Peal before clock 35: "+str(intents))
	if not beats.is_empty(): expect.call(beats[0]["affected_units"]==0 and beats[0]["damage_to_player"]==0,"Cantor Peal cannot strike Choir's six same-phase tiles")
	expect.call(Surfaces.tiles(after,"electrified").size()>=6,"Choir's fresh ground stays visible")

static func _dragon_scheduler(expect: Callable, id: String) -> void:
	var engine := Combat.new()
	var state: Dictionary = Boss._boss_combat_state(id)
	state["player_turn_time_spent"] = LONG_ACTIVATION_TIME
	var observations: Dictionary = {"fresh_beats":0,"violations":0}
	var accepted: Callable = _observe_fresh.bind(engine,observations)
	state = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state,accepted),accepted)["state"]
	expect.call(int(observations["fresh_beats"])>0,id+" production scheduler lays fuel and resolves a beat within the same enemy phase")
	expect.call(int(observations["violations"])==0,id+" same-phase fresh fuel never enters a beat forecast")
	# These first-phase beats have no older fuel: no beat may change ground or hit.
	for event: Dictionary in state.get("surface_events",[]):
		if event.get("kind","")=="battlefield_rule_fired": expect.call(event["affected_units"]==0 and event["tiles_changed"]==0,id+" scheduler beat excludes all newly laid fuel")

static func _observe_fresh(state: Dictionary, engine: RefCounted, observations: Dictionary) -> void:
	Commit.accept(engine,state)
	var instance: Dictionary = Rules.active(state)
	if instance.is_empty(): return
	var surface: String = {"wildfire":"fire","frostbite":"ice","lightning_storm":"electrified"}.get(str(instance["rule"]),"")
	if surface.is_empty(): return
	var fresh: Array[Vector2i]
	for tile: Vector2i in Surfaces.tiles(state,surface):
		if int(Surfaces.surface_at(state,tile).get("elemental_source",{}).get("laid_player_activation",state.get("turn",1)))==int(state.get("turn",1)): fresh.append(tile)
	if fresh.is_empty(): return
	observations["fresh_beats"] += 1
	var forecast: Dictionary = Rules.forecast(engine,state)
	# With no mature fuel, even chained lightning cannot start.
	if fresh.size()==Surfaces.tiles(state,surface).size() and (not forecast["hits"].is_empty() or _tile_count(forecast)>0): observations["violations"] += 1
	if surface=="ice" and fresh.has(state["player"]["pos"]):
		observations["fresh_hero_ice"] = int(observations.get("fresh_hero_ice",0))+1
		for hit: Dictionary in forecast["hits"]:
			if str(hit["actor_key"])=="player": observations["violations"] += 1

static func _iskaldra(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Boss._boss_combat_state("iskaldra")
	var observations: Dictionary = {"fresh_beats":0,"violations":0}
	var accepted: Callable = _observe_fresh.bind(engine,observations)
	var whiteout_seen: bool = false
	for phase: int in range(4):
		if phase==1:
			expect.call(int(state["enemies"][0].get("frost_armor",0))>0,"Iskaldra reproduction crosses half Health after Mantle")
			state["enemies"][0]["hp"] = int(state["enemies"][0]["max_hp"])/2
			state = Commit.accept(engine,state)
		var result: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state,accepted),accepted)
		state = result["state"]
		for step: Dictionary in result["steps"]:
			if str(step.get("kind",""))=="intent" and str(step.get("intent_name",""))=="Whiteout Lance": whiteout_seen = true
	expect.call(whiteout_seen,"Iskaldra scheduler regression includes the production Whiteout intent")
	expect.call(int(observations.get("fresh_hero_ice",0))>0,"Iskaldra scheduler regression includes fresh Ice under the hero")
	expect.call(observations["fresh_beats"]>0 and observations["violations"]==0,"Iskaldra helper/Whiteout fresh Ice is never immediate Frostbite fuel")
