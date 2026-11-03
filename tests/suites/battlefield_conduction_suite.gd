extends RefCounted
## Mixed-age lightning witnesses: rule beats and ordinary attacks share a planner.
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Boss = preload("res://tests/suites/dragon_boss_suite.gd")
const Guardian = preload("res://tests/suites/guardian_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const MIXED_DAMAGE: int = 5
const ZEKARION_PHASES: int = 6

class ObservedCombat extends "res://scripts/combat_engine.gd":
	var beat_plans: int = 0
	var mixed_plans: int = 0
	var fresh_conductors: int = 0

	func _board_attack_plan(state: Dictionary, action: Dictionary, impact: Array[Vector2i], actor_kind: String) -> Dictionary:
		var plan: Dictionary = super._board_attack_plan(state,action,impact,actor_kind)
		if bool(action.get("_battlefield_all_units",false)):
			beat_plans += 1
			var fresh: bool = false
			for tile: Vector2i in BoardSurfaceRules.tiles(state,"electrified"):
				if BoardSurfaceRules.BeatFuel.eligible(state,BoardSurfaceRules.surface_at(state,tile).get("elemental_source",{})): continue
				fresh = true
				if plan["used_conductors"].has(tile): fresh_conductors += 1
			if fresh: mixed_plans += 1
		return plan

static func run(expect: Callable) -> void:
	_mixed_age(expect)
	_zekarion(expect)
	_cantor_chain(expect)

static func _mixed_age(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(engine)
	Rules.install(engine,state,Base.rule("lightning_storm",{"damage":MIXED_DAMAGE,"chain":0}))
	Surface.place(state,Vector2i(3,5),"electrified",{"actor_kind":"enemy"})
	state = engine.prepare_next_player_turn(state)
	for tile: Vector2i in [Vector2i(4,5),Vector2i(5,5)]: Surface.place(state,tile,"electrified",{"actor_kind":"enemy"})
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Rules.forecast(engine,state)
	var after: Dictionary = engine.finish_player_activation(state)
	expect.call(state==before,"Mixed-age beat forecast and scheduler leave the supplied snapshot untouched")
	expect.call(forecast["hits"].is_empty(),"Mixed-age Damage 5/Chain 0 forecast cannot conduct through fresh (4,5)/(5,5) to the hero")
	expect.call(after["player"]["hp"]==state["player"]["hp"],"Mixed-age scheduled beat cannot deal Damage 5 through fresh ground")
	expect.call(_conductors(engine,state,after)==[Vector2i(3,5)],"Mixed-age beat conducts only its mature tile")
	expect.call(forecast==Rules.Outcomes.project(engine,state,after),"Mixed-age beat forecast equals resolution")
	# The same geometry must still conduct immediately for ordinary attacks.
	var action: Dictionary = {"type":"lightning_strikes","element":"lightning","damage":MIXED_DAMAGE,"chain":0}
	var ordinary: Dictionary = engine._resolve_board_attack(state.duplicate(true),action,engine.INVALID_TILE,"enemy",1,{},engine._vector2i_values([Vector2i(3,5)]))
	expect.call(state["player"]["hp"]-ordinary["player"]["hp"]==MIXED_DAMAGE,"Ordinary lightning still conducts through fresh ground immediately")
	state = engine.advance_to_next_player_turn_with_steps(after)["state"]
	forecast = Rules.forecast(engine,state)
	after = engine.finish_player_activation(state)
	expect.call(state["player"]["hp"]-after["player"]["hp"]==MIXED_DAMAGE and not forecast["hits"].is_empty(),"The next player activation enables the formerly fresh conductors")

static func _zekarion(expect: Callable) -> void:
	var engine := ObservedCombat.new()
	var state: Dictionary = Boss._boss_combat_state("zekarion")
	for phase: int in range(ZEKARION_PHASES):
		var result: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))
		state = result["state"]
	expect.call(engine.beat_plans>0 and engine.mixed_plans>0,"Zekarion's six production-scheduler phases plan Overload with mature strikes and fresh conductor candidates")
	expect.call(engine.fresh_conductors==0,"Zekarion's production-scheduler beats never route through fresh conductors (used %d)" % engine.fresh_conductors)
	expect.call(int(state["battlefield_rule"].get("beats_fired",0))>0,"Zekarion regression resolves production Overload beats")

static func _cantor_chain(expect: Callable) -> void:
	var engine := ObservedCombat.new()
	var state: Dictionary = Guardian.new().guardian_fixture("storm_cantor")
	# The arena seeds (5,5) at creation; isolate a genuinely new relay instead
	# of accidentally repainting that mature tile with a no-op placement.
	state["surfaces"].clear()
	state["enemies"].resize(2)
	state["enemies"][0]["pos"] = Vector2i(1,1)
	state["enemies"][1]["pos"] = Vector2i(3,5)
	state["player"]["pos"] = Vector2i(7,5)
	Surface.place(state,Vector2i(3,5),"electrified",{"actor_kind":"enemy"})
	state = engine.prepare_next_player_turn(state)
	Surface.place(state,Vector2i(5,5),"electrified",{"actor_kind":"enemy"})
	var forecast: Dictionary = Rules.forecast(engine,state)
	var after: Dictionary = Rules.fire(engine,state.duplicate(true))
	expect.call(int(state["battlefield_rule"]["dials"]["damage"])==3 and int(state["battlefield_rule"]["dials"]["chain"])==2,"Cantor witness uses production Peal Damage 3 / Chain 2")
	expect.call(not _hero_hit(forecast) and after["player"]["hp"]==state["player"]["hp"],"Cantor Chain 2 cannot relay from its struck helper through fresh (5,5) to the hero")
	expect.call(engine.fresh_conductors==0,"Cantor forecast and committed Peal exclude the fresh Chain relay")
	expect.call(forecast==Rules.Outcomes.project(engine,state,after),"Cantor mixed-age Chain 2 forecast equals resolution")
	# Ordinary Chain retains the same relay, even when a rule owns the room.
	var action: Dictionary = {"type":"lightning_strikes","element":"lightning","damage":3,"chain":2}
	var ordinary: Dictionary = state.duplicate(true)
	ordinary["player"]["pos"] = Vector2i(5,6)
	ordinary["enemies"][0]["pos"] = Vector2i(7,5)
	var plan: Dictionary = engine._board_attack_plan(ordinary,action,engine._vector2i_values([Vector2i(3,5)]),"player")
	expect.call(plan["used_conductors"].has(Vector2i(5,5)),"Ordinary Chain 2 still uses the fresh relay in a Cantor fight")

static func _hero_hit(forecast: Dictionary) -> bool:
	for hit: Dictionary in forecast["hits"]:
		if str(hit["actor_key"])=="player": return true
	return false

static func _conductors(engine: RefCounted, before: Dictionary, after: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for event: Dictionary in engine._surface_events_since(before,after):
		if event.get("kind","")=="surface_conducted": result.append(event["tile"])
	return result
