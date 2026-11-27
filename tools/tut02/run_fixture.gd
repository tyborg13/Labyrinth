extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const SEED: int = 90212
const FIRST_UMBRA_ROUTE: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(2, 1)]
const LATER_SEARCH_ROOMS: int = 5

static func first_umbra(progression: Dictionary) -> Dictionary:
	var run := Run.new()
	var combat := Combat.new()
	var state: Dictionary = run.create_new_run(SEED, progression)
	for destination: Vector2i in FIRST_UMBRA_ROUTE:
		if not run.available_moves(state).has(destination):
			return {}
		state = _travel(run, state, destination)
		if state["mode"] == "combat" and combat.effective_umbra_stage(state["combat_state"]) != Combat.UMBRA_STAGE_CLEAR:
			return state if destination == FIRST_UMBRA_ROUTE.back() else {}
		state = _advance(run, state)
		if state["mode"] != "room":
			return {}
	return {}

static func later_umbra(state: Dictionary) -> Dictionary:
	var run := Run.new()
	return _find_later_fight(run, Combat.new(), _advance(run, state), LATER_SEARCH_ROOMS)

static func has_concealed_enemy(combat: Combat, state: Dictionary) -> bool:
	if combat.effective_umbra_stage(state) == Combat.UMBRA_STAGE_CLEAR:
		return false
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["hp"]) > 0 and not combat.is_enemy_visible_to_player(state, enemy):
			return true
	return false

static func _find_later_fight(run: Run, combat: Combat, state: Dictionary, rooms_left: int) -> Dictionary:
	if rooms_left <= 0 or state["mode"] != "room":
		return {}
	for destination: Vector2i in run.available_moves(state):
		var next: Dictionary = _travel(run, state, destination)
		if next["mode"] == "combat" and has_concealed_enemy(combat, next["combat_state"]):
			return next
		var found: Dictionary = _find_later_fight(run, combat, _advance(run, next), rooms_left - 1)
		if not found.is_empty():
			return found
	return {}

static func _travel(run: Run, state: Dictionary, destination: Vector2i) -> Dictionary:
	var next: Dictionary = run.move_to_pre_battle(state, destination)
	return run.begin_pre_battle_combat(next) if next["mode"] == Run.MODE_PRE_BATTLE else next

static func _advance(run: Run, state: Dictionary) -> Dictionary:
	var next: Dictionary = state
	if next["mode"] == "combat":
		# Only bypass earlier fights. Captured fights retain the generated enemies,
		# Umbra, Light, board and opening hands.
		var combat: Dictionary = next["combat_state"].duplicate(true)
		for enemy: Dictionary in combat["enemies"]:
			enemy["hp"] = 0
		next = run.finish_combat(next, combat)
	match next["mode"]:
		"reward":
			return run.continue_dragon_reward(next) if run.is_dragon_reward(next) else run.skip_reward_for_heal(next)
		"campfire":
			return run.leave_campfire(next)
		"treasure":
			return run.claim_relic(next, "")
	return next
