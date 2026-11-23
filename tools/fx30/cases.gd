extends RefCounted
## Real Noctyrax resolver fixtures. The legacy cases inject retired descriptors.

const DragonCases = preload("res://tools/fx18/cases.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Committed = preload("res://scripts/guardian_combat_rules.gd")
const Dragon = preload("res://scripts/dragon_presentation.gd")
const Paths = preload("res://scripts/path_utils.gd")
const BOSS := "noctyrax"
const HERO := DragonCases.HERO
const BOSS_ORIGIN := DragonCases.BOSS_ORIGIN
const CLAW_ORIGIN := Vector2i(4, 0)
const CRATE_HP: int = 30
const CRATE_ID: int = 92
const NEAR_ILLUSION := Vector2i(5, 4)
const LEGACY_REFUGE := {"type": "aoe", "damage": 5, "range": 0, "element": "shadow",
	"committed_shape": "refuge", "field_radius": 3, "field_anchor": "player"}
const LEGACY_RANGED := {"type": "ranged", "damage": 10, "range": 4, "element": "shadow", "pierce": true}
const REEL := "recording"
const STRIPS: Array[String] = ["starless_breath", "night_coil", "last_eclipse"]
const WITNESSES: Array[String] = ["starless_breath", "night_coil", "last_eclipse",
	"starless_hidden", "night_coil_blocked", "eclipse_hidden", "eclipse_miss",
	"starless_reduced", "coil_reduced", "eclipse_reduced", "refuge", "ranged", "void_claw"]

static func build(id: String, engine: RefCounted, combat: RefCounted, profile: Dictionary, seed: int) -> Dictionary:
	var options := {"seed": seed, "dragon_id": BOSS, "dragon_depth": DragonCases.LAST_GATE}
	var run: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), profile), options)
	var state: Dictionary = run["combat_state"]
	var boss: Dictionary = state["enemies"].filter(func(unit: Dictionary) -> bool: return unit["type"] == BOSS)[0]
	boss["pos"] = BOSS_ORIGIN
	if id == "void_claw": boss["pos"] = CLAW_ORIGIN
	state["enemies"] = [boss]
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["surface_events"] = []
	state["illusions"] = []
	state.erase("battlefield_rule")
	var hero: Dictionary = state["player"]
	hero["pos"] = HERO
	hero["hp"] = DragonCases.PROOF_HP
	hero["max_hp"] = DragonCases.PROOF_HP
	run["player_hp"] = hero["hp"]
	run["player_max_hp"] = hero["max_hp"]
	hero["block"] = DragonCases.BLOCK_WITNESS if id == "night_coil_blocked" else 0
	hero["stoneskin"] = 0
	var umbra: Dictionary = state["umbra"]
	umbra["stage"] = "eclipse" if id == "starless_hidden" else "clear"
	umbra["stage_reduction"] = 0
	umbra["light_sources"] = []
	if id in ["starless_hidden", "last_eclipse", "eclipse_hidden", "eclipse_reduced", "refuge", REEL]:
		for brazier: Dictionary in state["guardian_braziers"]: brazier["lit"] = false
	if id in ["refuge", "eclipse_miss"]:
		state["guardian_braziers"][0]["pos"] = HERO
		state["guardian_braziers"][0]["lit"] = id == "eclipse_miss"

	var intent_id: String = _intent_id(id)
	_declare(combat, state, intent_id, seed)
	if id in ["refuge", "ranged"]: _legacy_intent(id, state, combat)
	if id.begins_with("starless") or id == REEL:
		var shot: Dictionary = state["enemies"][0]["intent"]["actions"][0]
		for tile: Vector2i in shot.get("declared_tiles", []):
			if tile == HERO or Paths.manhattan(HERO, tile) != 1: continue
			state["terrain"].append({"id": CRATE_ID, "kind": "wooden_crate", "pos": tile, "hp": CRATE_HP, "max_hp": CRATE_HP})
			_declare(combat, state, intent_id, seed)
			break
	elif intent_id == "last_eclipse" and id != "eclipse_miss":
		var tile: Vector2i = NEAR_ILLUSION
		if id == "eclipse_hidden":
			var dark: Dictionary = state.duplicate(true)
			dark["umbra"]["boss_eclipse_stage"] = "eclipse"
			dark["umbra"]["boss_eclipse_activations"] = 2
			for candidate: Vector2i in combat._umbra_eclipse_threat_tiles(state):
				if candidate != HERO and not combat.is_tile_visible_to_player(dark, candidate) and combat._enemy_index_at_tile(state, candidate) < 0:
					tile = candidate
					break
		state["illusions"].append({"id": DragonCases.ILLUSION_ID, "pos": tile, "hp": DragonCases.ILLUSION_HP, "max_hp": DragonCases.ILLUSION_HP})

	var steps: Array[Dictionary]
	var result: Dictionary = _resolve(combat, state, steps)
	if id == REEL:
		var second: Dictionary = result["state"]
		_declare(combat, second, "last_eclipse", seed)
		_resolve(combat, second, steps)
	return {"run": run, "profile": profile, "steps": steps}

static func _intent_id(id: String) -> String:
	if id.begins_with("starless") or id in [REEL, "ranged"]: return "starless_breath"
	if id.begins_with("night_coil") or id == "coil_reduced": return "night_coil"
	if id == "void_claw": return id
	return "last_eclipse"

static func _declare(combat: RefCounted, state: Dictionary, id: String, seed: int) -> void:
	var cycle: Array = GameData.enemy_def(BOSS)["intents"].map(func(intent: Dictionary) -> String: return intent["id"])
	var authored: Array = GameData.enemy_property(BOSS, "cycle_order", [])
	if not authored.is_empty(): cycle = authored
	var boss: Dictionary = state["enemies"][0]
	boss["dragon_cycle_order"] = authored
	boss["dragon_cycle"] = cycle.find(id) - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	combat._assign_enemy_intent(state, 0, rng)

static func _legacy_intent(id: String, state: Dictionary, combat: RefCounted) -> void:
	var boss: Dictionary = state["enemies"][0]
	var intent: Dictionary = boss["intent"].duplicate(true)
	var action: Dictionary = (LEGACY_REFUGE if id == "refuge" else LEGACY_RANGED).duplicate()
	intent["actions"] = [action]
	intent.erase("committed_plan")
	if id == "refuge": intent = Committed.commit_owned(combat, state, 0, intent)
	boss["intent"] = intent

static func _resolve(combat: RefCounted, state: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	var resolved: Dictionary = combat.resolve_enemy_turn_with_steps(state.duplicate(true), 0, false)
	for step: Dictionary in resolved["steps"]:
		if step.get("kind") not in ["aoe", "ranged", "melee", "summon", "move"]: continue
		steps.append(step)
	return resolved
