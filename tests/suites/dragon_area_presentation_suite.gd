extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")

static func build_run(boss_id: String) -> Dictionary:
	var engine := Run.new()
	var combat := Combat.new()
	var options: Dictionary = {"dragon_id":boss_id,"dragon_depth":4}
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),Store.default_data()),options)
	var state: Dictionary = run["combat_state"]
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["player"]["pos"] = Vector2i(2,4)
	state["enemies"][0]["pos"] = Vector2i(4,3)
	return run

static func declare(state: Dictionary, intent_id: String) -> void:
	var boss: Dictionary = state["enemies"][0]
	var intents: Array = Data.enemy_def(str(boss["type"]))["intents"]
	for index: int in range(intents.size()):
		if str(intents[index]["id"]) != intent_id: continue
		boss["dragon_cycle"] = index-1
		Combat.new()._assign_enemy_intent(state,0,RandomNumberGenerator.new())
		return
	assert(false,"Unknown fixture intent: "+intent_id)

# Actual warning -> player counterplay -> actual resolver. Neither presentation
# code nor the fixture fabricates the resulting attack's affected tiles.
static func canceled_case(boss_id: String) -> Dictionary:
	var run: Dictionary = build_run(boss_id)
	var state: Dictionary = run["combat_state"]
	var combat := Combat.new()
	var action: String
	if boss_id == "vyraketh":
		action = "detonate_cinders"
		var cinders: Array[Vector2i]
		cinders.append_array([Vector2i(2,4),Vector2i(3,4)])
		state["enemies"][0]["cinder_tiles"] = cinders
		for tile: Vector2i in cinders: Surface.place(state,tile,"fire",{"actor_kind":"enemy","actor_id":state["enemies"][0]["id"]})
		declare(state,"crownfire")
	else:
		action = "terrain_burst"
		state["terrain"] = [{"id":"canceled_spire_1","kind":"dragon_spire","pos":Vector2i(3,4),"hp":4,"max_hp":4,"surface_on_destroy":"rubble"},{"id":"canceled_spire_2","kind":"dragon_spire","pos":Vector2i(6,5),"hp":4,"max_hp":4,"surface_on_destroy":"rubble"}]
		declare(state,"faultline")
	var before_counterplay: Array = combat.enemy_threat_tiles(state,0)["attack"].duplicate()
	if boss_id == "vyraketh":
		for tile: Vector2i in Surface.tiles(state,"fire"): Surface.place(state,tile,"ice",{"actor_kind":"player"})
	else:
		for index: int in range(state["terrain"].size()): state = combat._damage_terrain(state,index,4)
	run["combat_state"] = state
	return {"run":run,"action":action,"before_counterplay":before_counterplay}

static func area_step(result: Dictionary, action: String, boss_id: String) -> Dictionary:
	for raw: Dictionary in result["steps"]:
		if str(raw.get("action_type","")) != action: continue
		var step: Dictionary = raw.duplicate(true)
		step["enemy_type"] = boss_id
		return step
	return {}

static func run(expect: Callable) -> void:
	var combat := Combat.new()
	for boss_id: String in ["vyraketh","tharokh"]:
		var fixture: Dictionary = canceled_case(boss_id)
		var state: Dictionary = fixture["run"]["combat_state"]
		expect.call(not fixture["before_counterplay"].is_empty(),boss_id+" starts with a real announced area")
		expect.call((combat.enemy_threat_tiles(state,0)["attack"] as Array).is_empty(),boss_id+" counterplay removes its whole warning")
		var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
		var step: Dictionary = area_step(result,fixture["action"],boss_id)
		expect.call(not step.is_empty() and step.get("tiles",[]).is_empty(),boss_id+" keeps an explicitly empty resolved area")
		expect.call(int(result["state"]["player"]["hp"])==int(state["player"]["hp"]),boss_id+" canceled area causes no player damage")
		expect.call(Profile.tiles(step).is_empty(),boss_id+" canceled area invents no safe-player impact")
	var direct: Dictionary = build_run("vaeloryx")["combat_state"]
	declare(direct,"skyhook")
	var shot: Dictionary = area_step(combat.resolve_enemy_turn_with_steps(direct,0),"ranged","vaeloryx")
	expect.call(not shot.is_empty() and shot.get("tiles",[]).is_empty(),"Actual single-target ranged step uses its ordinary empty area list")
	var shot_tiles: Array[Vector2i] = Profile.tiles(shot)
	expect.call(shot_tiles.size()==1 and shot_tiles[0]==shot.get("to"),"Actual single-target breath retains its target impact")
	var breath: Dictionary = build_run("vyraketh")["combat_state"]
	declare(breath,"cinderfall")
	var breath_step: Dictionary = area_step(combat.resolve_enemy_turn_with_steps(breath,0),"aoe","vyraketh")
	expect.call(not breath_step.is_empty() and not breath_step.get("tiles",[]).is_empty(),"Actual held breath has its declared area")
	expect.call(Profile.tiles(breath_step)==breath_step.get("tiles",[]),"Actual held breath preserves every resolved tile")
	expect.call(Profile.tiles({"kind":"aoe","focus_tiles":[],"to":Vector2i(2,4)}).is_empty(),"An explicit empty focus area remains empty")
