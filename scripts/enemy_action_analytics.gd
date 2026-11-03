extends RefCounted

# Compound actions carry their approach inside the attack step. Preserve the
# ordinary move event and its arrival losses before the attack's own outcome.
static func steps_for_events(phase_result: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for value: Variant in phase_result.get("steps", []):
		if not value is Dictionary: continue
		var step: Dictionary = value
		if step.has("move_step"):
			var move: Dictionary = (step.get("move_step", {}) as Dictionary).duplicate(true)
			if not move.is_empty():
				for field: String in ["enemy_type", "ai_role", "intent_id"]:
					if step.has(field): move[field] = step[field]
				result.append(move)
		result.append(step)
	return result
