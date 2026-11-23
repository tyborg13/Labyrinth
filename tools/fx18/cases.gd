extends RefCounted
## Real resolver inputs for the visual and headless takes.

const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Profile = preload("res://scripts/dragon_presentation.gd")
const BOSS_ORIGIN := Vector2i(4, 1)
const HERO := Vector2i(4, 4)
const FUEL_TILES: Array[Vector2i] = [Vector2i(3, 4), Vector2i(5, 4)]
const ILLUSION_ID: int = 91
const ILLUSION_HP: int = 1
const SPIRE_HP: int = 4
const SHATTERSTORM_ARMOR: int = 2
const BLOCK_WITNESS: int = 20
const PROOF_HP: int = 30
const LAST_GATE: int = 24
const FIRST_GATE: int = 4
const CASES: Dictionary = {
	"cinder_breath": ["vyraketh", "cinderfall", "aoe", "breath", "fire"],
	"crownfire": ["vyraketh", "crownfire", "detonate_cinders", "ground", "fire"],
	"bedrock_breath": ["tharokh", "bedrock_breath", "aoe", "breath", "earth"],
	"faultline": ["tharokh", "faultline", "terrain_burst", "ground", "earth"],
	"skyhook": ["vaeloryx", "skyhook", "ranged", "breath", "air"],
	"hollow_gale": ["vaeloryx", "hollow_gale", "aoe", "ground", "air"],
	"eye_of_storm": ["vaeloryx", "eye_of_storm", "aoe", "ground", "air"],
	"whiteout_lance": ["iskaldra", "whiteout_lance", "aoe", "breath", "ice"],
	"crystal_mantle": ["iskaldra", "crystal_mantle", "ranged", "breath", "ice"],
	"shatterstorm": ["iskaldra", "shatterstorm", "aoe", "ground", "ice"],
	"storm_lash": ["zekarion", "storm_claw", "ranged", "breath", "lightning"],
	"call_wisps": ["zekarion", "call_wisps", "ranged", "breath", "lightning"],
	"overload": ["zekarion", "tempest_breath", "ranged", "ground", "lightning"],
	"starless_breath": ["noctyrax", "starless_breath", "aoe", "breath", "shadow"],
	"night_coil": ["noctyrax", "night_coil", "aoe", "breath", "shadow"],
	"meteorfall_followup": ["vyraketh", "kindle_ground", "ranged", "breath", "fire"],
	"faultline_followup": ["tharokh", "faultline", "ranged", "breath", "earth"],
	"eye_of_storm_followup": ["vaeloryx", "eye_of_storm", "melee", "ground", "air"],
}
const STRIPS: Array[String] = [
	"cinder_breath", "crownfire", "bedrock_breath", "faultline", "hollow_gale",
	"whiteout_lance", "shatterstorm", "overload", "storm_lash", "starless_breath",
]

static func fixture(id: String, engine: RefCounted, combat: RefCounted, profile: Dictionary, seed: int, witness: String) -> Dictionary:
	var config: Array = CASES[id]
	var options: Dictionary = {
		"seed": seed, "dragon_id": config[0],
		"dragon_depth": LAST_GATE if config[0] == "noctyrax" else FIRST_GATE,
	}
	var run: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), profile), options)
	var state: Dictionary = run["combat_state"]
	var boss: Dictionary = {}
	for unit: Dictionary in state["enemies"]:
		if unit["type"] == config[0]: boss = unit
	if boss.is_empty(): return {}
	state.erase("battlefield_rule")
	state["enemies"] = [boss]
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["illusions"] = []
	state["surface_events"] = []
	var hero: Dictionary = state["player"]
	hero["pos"] = HERO
	hero["hp"] = PROOF_HP
	hero["max_hp"] = PROOF_HP
	run["player_hp"] = PROOF_HP
	run["player_max_hp"] = PROOF_HP
	hero["block"] = 0
	hero["stoneskin"] = 0
	boss["pos"] = BOSS_ORIGIN
	if id == "eye_of_storm_followup": hero["pos"] = HERO + Vector2i.UP
	if id == "shatterstorm": boss["frost_armor"] = SHATTERSTORM_ARMOR
	state["umbra"]["stage"] = "heart" if witness == "fog" else "clear"
	state["umbra"]["stage_reduction"] = 0
	_seed_fuel(state, boss, id)
	_declare(combat, state, boss, config[1], seed)
	boss = state["enemies"][0]
	var intent: Dictionary = boss["intent"]
	var actions: Array[Dictionary]
	for action: Dictionary in intent["actions"]:
		if action.get("type") == config[2]: actions.append(action)
	if actions.size() != 1: return {}
	intent["actions"] = actions
	intent.erase("committed_plan")
	if witness == "pools":
		hero["block"] = BLOCK_WITNESS
		var tiles: Array = actions[0].get("declared_tiles", [])
		for tile: Vector2i in tiles:
			if tile == HERO: continue
			state["illusions"] = [{"id": ILLUSION_ID, "pos": tile, "hp": ILLUSION_HP, "max_hp": ILLUSION_HP}]
			break
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state.duplicate(true), 0, false)
	for step: Dictionary in result["steps"]:
		if step.get("action_type") != config[2]: continue
		step["enemy_type"] = config[0]
		step["intent_id"] = config[1]
		return {"run": run, "profile": profile, "step": step, "actor": boss}
	return {}

static func _declare(combat: RefCounted, state: Dictionary, boss: Dictionary, intent_id: String, seed: int) -> void:
	var data: Dictionary = GameData.enemy_def(boss["type"])
	var order: Array = (data.get("cycle_order", []) as Array).duplicate()
	boss["dragon_cycle_order"] = order.duplicate()
	if order.is_empty():
		for intent: Dictionary in data["intents"]: order.append(intent["id"])
	boss["dragon_cycle"] = order.find(intent_id) - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	combat._assign_enemy_intent(state, 0, rng)

static func _seed_fuel(state: Dictionary, boss: Dictionary, id: String) -> void:
	if id == "crownfire":
		boss["cinder_tiles"] = FUEL_TILES.duplicate()
		for tile: Vector2i in FUEL_TILES:
			Surface.place(state, tile, "fire", {"actor_kind": "enemy", "actor_id": boss["id"]})
	elif id == "faultline":
		for tile: Vector2i in FUEL_TILES:
			state["terrain"].append({"id": "fx18_spire_%s" % tile, "kind": "crag_outcrop",
				"owner_kind": "enemy", "owner_id": boss["id"], "pos": tile, "hp": SPIRE_HP,
				"max_hp": SPIRE_HP, "surface_on_destroy": "rubble"})
