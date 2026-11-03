extends "res://scripts/combat_engine.gd"
## Passive branch-local observations: speculative hits never enter another
## branch, and only the last committed outcome query exports the observations.
const OBSERVATION: String = "_shadow_observation"
const BLEED_SOURCES: String = "_shadow_bleed_sources"
const RETALIATE_SOURCES: String = "_shadow_retaliate_sources"
const ATTRIBUTION_VERSION: String = "source_origin_v1"
var attack_reduction: int = 0
var room_biome: String = ""
var reduce_intent: String = ""
var reduce_enemy: String = ""
var final_observation: Dictionary = {}

func primary_only_shock() -> bool:
	# MeasurementBot's adapter interface; no card overrides in this experiment.
	return false

func _surface_source(state: Dictionary, action: Dictionary = {}) -> Dictionary:
	var recorded: Dictionary = super._surface_source(state, action)
	if recorded.get("actor_kind", "") != "enemy": return recorded
	var index: int = _enemy_index_for_id(state, int(recorded.get("actor_id", -1)))
	if index >= 0:
		var enemy: Dictionary = state["enemies"][index]
		# Ground retains its painter's identity after the next intent is chosen.
		if str(recorded.get("enemy_type", "")).is_empty(): recorded["enemy_type"] = str(enemy["type"])
		if str(recorded.get("intent_id", "")).is_empty(): recorded["intent_id"] = str(enemy.get("intent", {}).get("id", ""))
	return recorded

func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup_action: Dictionary = {}, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
	if str(action.get("type", "")) == "retaliate" and enemy_index >= 0 and enemy_index < state["enemies"].size():
		var enemy: Dictionary = state["enemies"][enemy_index]
		if int(enemy["hp"]) > 0 and enemy_action_can_resolve(state, action):
			if not state.has(RETALIATE_SOURCES): state[RETALIATE_SOURCES] = {}
			state[RETALIATE_SOURCES][str(int(enemy["id"]))] = {"enemy_type": enemy["type"], "intent_id": enemy.get("intent", {}).get("id", ""), "kind": "retaliate"}
	return super._resolve_enemy_action(state, enemy_index, action, rng, followup_action, bleed_steps, action_context)

func observation(state: Dictionary) -> Dictionary:
	if not state.has(OBSERVATION): state[OBSERVATION] = {"hits": [], "activations": []}
	return state[OBSERVATION]

func combat_outcome(state: Dictionary) -> String:
	final_observation = state.get(OBSERVATION, {"hits": [], "activations": []})
	return super.combat_outcome(state)

func _scale_enemy_intent(base_intent: Dictionary, room_depth: int, depth_state: Dictionary = {}, enemy: Dictionary = {}) -> Dictionary:
	var intent: Dictionary = super._scale_enemy_intent(base_intent, room_depth, depth_state, enemy)
	# Section biome owns this experiment. A shadow-section sample can have,
	# for example, a fire room element; that field must not gate these dials.
	if room_biome != "shadow": return intent
	var targeted: bool = str(intent.get("id", "")) == reduce_intent and str(enemy.get("type", "")) == reduce_enemy and not reduce_intent.is_empty()
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) not in ATTACK_ACTION_TYPES and str(action.get("type", "")) not in BOSS_DAMAGE_ACTION_TYPES and str(action.get("type", "")) != "lightning_strikes": continue
		for field: String in ["damage", "center_damage", "arm_damage"]:
			if not action.has(field) or int(action[field]) <= 0: continue
			if attack_reduction > 0: action[field] = maxi(1, int(action[field]) - attack_reduction)
			if targeted: action[field] = maxi(1, ceili(float(action[field]) * 2.0 / 3.0))
	return intent

func _spawned_enemy_entry(state: Dictionary, enemy_type: String, enemy_id: int, tile: Vector2i, summoned: bool) -> Dictionary:
	var enemy: Dictionary = super._spawned_enemy_entry(state, enemy_type, enemy_id, tile, summoned)
	if bool(state.get("_shadow_hp_override", false)):
		enemy["max_hp"] = maxi(1, ceili(float(enemy["max_hp"]) * 0.75))
		enemy["hp"] = enemy["max_hp"]
	return enemy

func create_combat(run_seed: int, room_layout: Dictionary, player_snapshot: Dictionary) -> Dictionary:
	var state: Dictionary = super.create_combat(run_seed, room_layout, player_snapshot)
	if bool(room_layout.get("_shadow_hp_override", false)): state["_shadow_hp_override"] = true
	return state

func _resolve_enemy_turn_with_steps(state: Dictionary, enemy_index: int, include_commit_steps: bool = true, choose_next_intent: bool = true, accepted: Callable = Callable()) -> Dictionary:
	var owned: Dictionary = state.duplicate(true)
	if enemy_index >= 0 and enemy_index < owned["enemies"].size():
		var enemy: Dictionary = owned["enemies"][enemy_index]
		if int(enemy["hp"]) > 0:
			observation(owned)["activations"].append({"enemy_type": enemy["type"], "intent_id": enemy.get("intent", {}).get("id", ""), "turn": owned["turn"]})
	return super._resolve_enemy_turn_with_steps(owned, enemy_index, include_commit_steps, choose_next_intent, accepted)

func source(state: Dictionary, context: Dictionary, cause: String) -> Dictionary:
	var kind: String = str(context.get("source_kind", cause))
	if cause in ["bleed", "fatigue"]: return {"enemy_type": "non_enemy", "intent_id": cause, "kind": cause}
	if kind == "retaliate" or cause == "retaliate":
		var granted: Dictionary = (state.get(RETALIATE_SOURCES, {}) as Dictionary).get(str(int(context.get("actor_id", -1))), {})
		if not granted.is_empty(): return granted.duplicate(true)
	if kind == "surface_fire": context = context.get("surface_source", context)
	var enemy_type: String = str(context.get("enemy_type", ""))
	var intent_id: String = str(context.get("intent_id", ""))
	if context.get("actor_kind", "") == "enemy":
		var index: int = _enemy_index_for_id(state, int(context.get("actor_id", -1)))
		if index >= 0:
			if enemy_type.is_empty(): enemy_type = str(state["enemies"][index]["type"])
			if intent_id.is_empty(): intent_id = str(state["enemies"][index].get("intent", {}).get("id", ""))
	else:
		enemy_type = "non_enemy"
		intent_id = kind
	return {"enemy_type": enemy_type if not enemy_type.is_empty() else "unattributed", "intent_id": intent_id if not intent_id.is_empty() else kind, "kind": kind}

func _damage_player(state: Dictionary, damage: int, bypass_block: bool, apply_incoming_hit_effects: bool = true, cause: String = "damage", defer_defiance: bool = false) -> Dictionary:
	var previous: int = int(state.get("run_stats", {}).get("damage_received", 0))
	var context: Dictionary = state.get("damage_context", {}).duplicate(true)
	var after: Dictionary = super._damage_player(state, damage, bypass_block, apply_incoming_hit_effects, cause, defer_defiance)
	var lost: int = int(after.get("run_stats", {}).get("damage_received", 0)) - previous
	if lost <= 0: return after
	var sources: Array = []
	if cause == "bleed" and not (after.get(BLEED_SOURCES, []) as Array).is_empty():
		var total: int = 0
		for item: Dictionary in after[BLEED_SOURCES]: total += int(item["amount"])
		for item: Dictionary in after[BLEED_SOURCES]:
			var attributed: Dictionary = item["source"].duplicate(true)
			attributed["kind"] = "bleed"
			attributed["hp_lost"] = float(lost) * float(item["amount"]) / float(total)
			sources.append(attributed)
	else:
		var attributed: Dictionary = source(after, context, cause)
		attributed["hp_lost"] = lost
		sources.append(attributed)
	observation(after)["hits"].append({"turn": int(after.get("turn", 1)), "clock": int(after.get("initiative_clock", 0)), "hp_lost": lost, "lethal": int(after["player"]["hp"]) <= 0, "sources": sources})
	return after

func _apply_action_keywords_to_player(state: Dictionary, action: Dictionary, source_pos: Vector2i) -> Dictionary:
	if int(action.get("bleed", 0)) > 0:
		if not state.has(BLEED_SOURCES): state[BLEED_SOURCES] = []
		state[BLEED_SOURCES].append({"amount": int(action["bleed"]), "source": source(state, state.get("damage_context", {}), "damage")})
	return super._apply_action_keywords_to_player(state, action, source_pos)

func _clear_player_bleed_after_turn(state: Dictionary) -> Dictionary:
	var after: Dictionary = super._clear_player_bleed_after_turn(state)
	after.erase(BLEED_SOURCES)
	return after
