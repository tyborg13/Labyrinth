extends RefCounted

const Factory = preload("res://tools/guardian_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const PROOF_SEED: int = 61027
const PROOF_UMBRA_STAGE: String = "clear"

static func build() -> Dictionary:
	var run := Run.new()
	var combat := Combat.new()
	var state: Dictionary = Factory.build(run, combat, run.create_new_run(PROOF_SEED, Store.default_data()), {
		"guardian_id": "storm_cantor", "guardian_case": "encounter"
	})
	var battle: Dictionary = state["combat_state"]
	# Same real arena, authored actor and Call the Spark as the CLI inspection
	# fixture. Start without a Wisp so this is the authored move, not an automatic
	# replacement injected by with_reinforcements.
	battle["enemies"] = [battle["enemies"][0]]
	select_summon(combat, battle)
	battle["umbra"]["stage"] = PROOF_UMBRA_STAGE
	battle = combat._initialize_initiative_queue(battle)
	return run.set_combat_state(state, battle)

static func select_summon(combat: RefCounted, battle: Dictionary, index: int = 0) -> void:
	var enemy: Dictionary = battle["enemies"][index]
	var definition: Dictionary = Data.enemy_def(str(enemy["type"]))
	var intents: Array = definition.get("intents", [])
	for slot: int in range(intents.size()):
		if not (intents[slot]["actions"] as Array).any(func(action: Dictionary) -> bool: return str(action.get("type", "")) == "summon_minions"): continue
		# Test/proof setup selects the cycle position, then lets production choose,
		# scale, add missing-helper metadata and commit the authored warning.
		enemy["dragon_cycle" if bool(definition.get("dragon_cycle", false)) else "guardian_cycle"] = slot - 1
		enemy["intent"] = {}
		var rng := RandomNumberGenerator.new()
		rng.seed = PROOF_SEED
		combat._assign_enemy_intent(battle, index, rng)
		return
