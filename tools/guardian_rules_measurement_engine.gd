extends "res://scripts/combat_engine.gd"
## Offline ablation only: frozen Guardian definitions and selection from the
## integration parent. No files, policy scores, search limits or saves change.
const Before = preload("res://tests/fixtures/bos_03_before_guardian_selection.gd")
const METRICS: String = "_guardian_measurement"
var variant: String = "after"
var final_metrics: Dictionary = {}

func configure(value: String) -> void:
	variant = value
	if variant == "after": return
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos_03_before_enemies.json"))
	for id: String in definitions: GameData.enemies()[id] = definitions[id]
	if variant == "pace_only":
		GameData.enemies()["storm_cantor"]["base_initiative"] = 11
		GameData.enemies()["gallows_roc"]["base_initiative"] = 9
		for id: String in ["bell_tender", "roc_fledgling"]:
			GameData.enemies()[id]["encounter_base_initiative"] = {"guardian":12}

func create_combat(seed_value: int, layout: Dictionary, player: Dictionary) -> Dictionary:
	var room: Dictionary = layout.duplicate(true)
	if variant != "after": room.erase("battlefield_rule")
	var state: Dictionary = super.create_combat(seed_value, room, player)
	state[METRICS] = {"helper_kills":0, "summons":0,"beats_fired":0,"beat_damage_to_hero":0,"beat_damage_to_enemies":0,"sequence":0}
	return state

func _assign_enemy_intent(state: Dictionary, index: int, rng: RandomNumberGenerator) -> void:
	if variant == "after":
		super._assign_enemy_intent(state, index, rng)
		return
	var enemy: Dictionary = state["enemies"][index]
	var definition: Dictionary = GameData.enemy_def(str(enemy["type"]))
	if not bool(definition.get("intent_cycle", false)):
		super._assign_enemy_intent(state, index, rng)
		return
	var intents: Array = _scaled_enemy_intents(definition["intents"], int(state.get("room_depth",1)), state, enemy)
	GuardianCombatRules.cleanup(state, enemy)
	var cycle: int = int(enemy.get("guardian_cycle",-1)) + 1
	enemy["guardian_cycle"] = cycle
	var chosen: Dictionary = _surface_prepare_enemy_intent(state, enemy, Before.choose_intent(state, enemy, intents, cycle))
	chosen = Before.with_reinforcements(state, enemy, chosen)
	enemy["intent"] = GuardianCombatRules.commit(self, state, index, chosen)

func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup_action: Dictionary = {}, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
	var pending: int = int(state.get("pending_summon_card_plays",0))
	var after: Dictionary = super._resolve_enemy_action(state, enemy_index, action, rng, followup_action, bleed_steps, action_context)
	# Preserve sum-01's pre-bos-03 exclusion in the offline before/pace cases.
	if variant != "after" and action.get("summon_origin", "") == "guardian_replacement": after["pending_summon_card_plays"] = pending
	return after

func combat_outcome(state: Dictionary) -> String:
	# Query each branch's append-only event cursor before the production ring
	# buffer can retire old events. Only the final committed counters escape.
	if state.has(METRICS):
		var counts: Dictionary = state[METRICS]
		for event: Dictionary in state.get("surface_events", []):
			if int(event["sequence"]) <= int(counts["sequence"]): continue
			match str(event.get("kind", "")):
				"battlefield_rule_fired":
					counts["beats_fired"] += 1
					counts["beat_damage_to_hero"] += int(event.get("damage_to_player",0))
					counts["beat_damage_to_enemies"] += int(event.get("damage_to_enemies",0))
				"actor_death":
					if bool(event.get("unit", {}).get("guardian_helper",false)): counts["helper_kills"] += 1
				"guardian_helper_summoned": counts["summons"] += 1
			counts["sequence"] = int(event["sequence"])
		final_metrics = counts.duplicate(true)
		final_metrics.erase("sequence")
	return super.combat_outcome(state)
