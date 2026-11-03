extends "res://scripts/run_engine.gd"
## Offline ladder adapter. Production factories and reward paths stay intact.
const Combat = preload("res://scripts/combat_engine.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
var health_resets: int = 0

func _player_snapshot(run_state: Dictionary) -> Dictionary:
	# Both synchronous and pre-battle factories call this immediately before
	# CombatEngine creation, after route selection and room-layout generation.
	run_state["player_hp"] = int(run_state["player_max_hp"])
	health_resets += 1
	return super._player_snapshot(run_state)

static func victory_transition(actual: Dictionary) -> Dictionary:
	# Never mutate the measured fight. Only this private copy enters finish_combat.
	var state: Dictionary = actual.duplicate(true)
	state["player"]["hp"] = maxi(1, int(state["player"]["hp"]))
	var objective: Dictionary = state["objective"]
	var kind: String = str(objective.get("type", Objectives.KILL_ALL))
	if kind == Objectives.REACH_EXIT:
		var exits: Array = objective.get("exits", [])
		assert(not exits.is_empty(), "Ladder exit objective needs an authored exit")
		var selected: Dictionary = exits[0]
		for exit: Dictionary in exits:
			if not bool(exit.get("sealed", false)):
				selected = exit
				break
		selected["sealed"] = false
		state["player"]["pos"] = selected["target_tile"]
	elif kind == Objectives.SURVIVE:
		state["initiative_clock"] = maxi(int(state["initiative_clock"]), int(objective["target_clock"]))
	else:
		# The normal leader victory clears followers without their kill rewards.
		# Defeat All pays remaining deaths through the production currency rules;
		# no damage, kill statistics, death effects or relic procs are fabricated.
		for enemy: Dictionary in state.get("enemies", []):
			if int(enemy.get("hp", 0)) <= 0: continue
			var leader: bool = bool(enemy.get("is_leader", false)) or int(enemy.get("id", -1)) == int(objective.get("leader_id", -2))
			var earns: bool = kind == Objectives.KILL_ALL or leader
			if str(state.get("room_type", "")) == "boss": earns = bool(GameData.enemy_def(str(enemy["type"])).get("boss_bar", false))
			if earns:
				var reward: int = 0 if bool(enemy.get("guardian_helper", false)) else int(GameData.enemy_def(str(enemy["type"])).get("reward_embers", 0))
				reward = OmenRules.ember_drop(state, reward)
				if DepthRules.enemy_class(enemy) == "dragon": reward = DepthRules.dragon_embers(state, reward)
				if SnareRules.active(state) and bool(enemy.get("snare_hunter", false)): reward = 0
				state["room_embers"] = int(state.get("room_embers", 0)) + reward
			enemy["hp"] = 0
			enemy["objective_cleared"] = true
		if kind == Objectives.KILL_LEADER:
			objective["completed_by_leader"] = true
			if str(objective.get("special_type", "")) == "ember_hoarder":
				objective["hoarder_caught"] = true
				objective["hoarder_caught_turn"] = state["turn"]
				objective["goal_met"] = true
	assert(Combat.new().combat_outcome(state) == "victory", "Ladder transition must be a normal victory end")
	return state

static func clamp_health(state: Dictionary, record: Dictionary) -> void:
	if int(state["player_hp"]) < 1:
		state["player_hp"] = 1
		record["noncombat_health_clamps"] += 1

static func event_native_clamps(state: Dictionary, choice_id: String, engine: RefCounted) -> int:
	# EventRules already clamps HP at 1. Replay its effects on private copies
	# only to count those native clamps, without changing the committed choice.
	var current: Dictionary = state.duplicate(true)
	var id: String = EventRules.current_id(state)
	var rng: RandomNumberGenerator = EventRules.rng_for(state, "choice|%s" % choice_id)
	var clamps: int = 0
	for effect: Dictionary in EventRules.choice_def(id, choice_id).get("effects", []):
		var type: String = str(effect["type"])
		if type in ["hp", "heal", "heal_percent"]:
			var value: int = DepthRules.event_value(current, type, int(effect.get("amount", 0)))
			if type == "heal_percent": value = roundi(float(current["player_max_hp"]) * float(effect["percent"]) / 100.0)
			if int(current["player_hp"]) + value < 1: clamps += 1
		current = EventRules.apply_effects(current, [effect], rng, engine)["state"]
	return clamps
