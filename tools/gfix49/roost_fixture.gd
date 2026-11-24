extends RefCounted

const Factory = preload("res://tools/guardian_inspection.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")

const SEED: int = 7262026 # Existing Guardian inspection seed.
const WEST_OFFSET := Vector2i(-1, 1)
const EAST_OFFSET := Vector2i(1, 1)
const TIE_OFFSET := Vector2i(-1, -1)

static func build(run_engine: RefCounted, combat: RefCounted, offset: Vector2i = WEST_OFFSET) -> Dictionary:
	var run: Dictionary = Factory.build(run_engine, combat, run_engine.create_new_run(SEED, Progression.default_data()),
		{"guardian_id": "gallows_roc", "guardian_case": "beat"})
	var state: Dictionary = run["combat_state"]
	state["player"]["pos"] = state["enemies"][0]["pos"] + offset
	combat.ManeuverRules.record_activation_start(state)
	# Stage the announcement with the hero already on the proof opening tile.
	var instance: Dictionary = state["battlefield_rule"].duplicate(true)
	instance.erase("locked_direction")
	Rules.install(combat, state, instance)
	return run

static func east(state: Dictionary) -> Vector2i:
	return state["enemies"][0]["pos"] + EAST_OFFSET
