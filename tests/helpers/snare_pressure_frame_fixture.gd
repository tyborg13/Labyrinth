extends RefCounted
## Identical turn-three performance workload on pre-pressure and current code.
const Original = preload("res://tools/snare_inspection.gd")
const FIXTURE_SEED: int = Original.FIXTURE_SEED
const PRESSURE_PROOF_TURN: int = 3

static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	var initial: Dictionary = options.duplicate(true)
	initial["snare_case"] = "encounter"
	var state: Dictionary = Original.build(engine, combat, source, initial)
	var battle: Dictionary = state["combat_state"]
	for turn: int in range(PRESSURE_PROOF_TURN - 1):
		battle = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
		assert(combat.combat_outcome(battle) == "", "Frame fixture survives to player turn three")
	if str(battle["objective"]["special_variant"]) == "lightning": _prepare_proof_thralls(combat, battle)
	state["combat_state"] = battle
	return state

static func _prepare_proof_thralls(combat: RefCounted, battle: Dictionary) -> void:
	for thrall: Dictionary in battle["enemies"]:
		if str(thrall["type"]) != "arc_thrall" or int(thrall["hp"]) <= 0: continue
		var intents: Array = combat._scaled_enemy_intents(combat.GameData.enemy_def("arc_thrall")["intents"], int(battle["room_depth"]), battle, thrall)
		thrall["intent"] = combat._intent_by_id(intents, "arc_bolt")
