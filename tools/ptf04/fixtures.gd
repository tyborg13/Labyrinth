extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
# Invisible, deterministic proof inputs; no production tuning lives here.
const PROOF_SEED: int = 90210
const HELD_BEFORE_FIGHT: int = 16
const FATAL_FIGHT_EARNINGS: int = 18
const PROOF_SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-04"

static func combat_run(guided: bool = false) -> Dictionary:
	var engine := Run.new()
	var progression: Dictionary = Store.default_data()
	progression[Tutorial.PROGRESSION_KEY] = Tutorial.default_state()
	if not guided: progression = Tutorial.dismiss_tutorial(progression)
	var state: Dictionary = engine.create_new_run(PROOF_SEED, progression)
	if guided: state = Guided.mark_run_eligible(state)
	state = engine.move_to_room(state, engine.available_moves(state)[0])
	if str(state["mode"]) == "pre_battle": state = engine.begin_pre_battle_combat(state)
	return engine.set_held_embers(state, HELD_BEFORE_FIGHT)

static func fatal_combat(state: Dictionary) -> Dictionary:
	var combat: Dictionary = state["combat_state"].duplicate(true)
	combat["player"]["hp"] = 0
	combat["room_embers"] = FATAL_FIGHT_EARNINGS
	return combat
