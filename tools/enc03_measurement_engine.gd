extends "res://tools/encounter_measurement_engine.gd"
## Count only the committed phase entry point used by policy v2. Its speculative
## phase previews use preview_revealed_enemy_actions_before_player_turn_with_steps.
var action_mix: Dictionary = empty_mix()

static func empty_mix() -> Dictionary:
	return {"lob": 0, "lob_mark": 0, "lob_land": 0, "brace": 0, "scatter": 0, "retreat": 0}

static func count_steps(steps: Array, counts: Dictionary, slag_actor_keys: PackedStringArray = PackedStringArray()) -> void:
	for step: Dictionary in steps:
		var enemy_type: String = str(step.get("enemy_type", ""))
		# The captain's keep_distance move predates typed action annotations.
		# Attribute that committed step using the room's actual actor identity.
		if enemy_type != "slag_mortar" and not (enemy_type.is_empty() and slag_actor_keys.has(str(step.get("actor_key", "")))): continue
		var mechanic: String = str(step.get("en04_mechanic", ""))
		if mechanic in ["lob_mark", "lob_land"]:
			counts["lob"] += 1
			counts[mechanic] += 1
		elif str(step.get("kind", "")) == "block" and str(step.get("intent_id", "")) == "brace": counts["brace"] += 1
		elif str(step.get("kind", "")) in ["attack", "ranged"] and str(step.get("intent_id", "")) == "scatter_shot": counts["scatter"] += 1
		elif str(step.get("kind", "")) == "move" and str(step.get("label", "")) == "Retreat": counts["retreat"] += 1

func advance_to_next_player_turn_with_steps(state: Dictionary, accepted: Callable = Callable()) -> Dictionary:
	var slag_actor_keys: PackedStringArray
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) == "slag_mortar": slag_actor_keys.append("enemy_%d" % int(enemy["id"]))
	var result: Dictionary = super.advance_to_next_player_turn_with_steps(state, accepted)
	count_steps(result["steps"], action_mix, slag_actor_keys)
	return result
