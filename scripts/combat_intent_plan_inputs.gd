extends RefCounted

# The ordinary plan returns geometry, actor targets and authored actions. Its
# navigation, line-of-sight, trap and conduction queries do not resolve actions
# or read prior player targets, event journals or RNG. Keep every other state
# field, including all actor durability, statuses, surfaces and objectives.
# Authored/special plans can project resolved states; retain their full inputs.
const GEOMETRIC_ACTIONS: PackedStringArray = ["melee", "ranged", "move_toward", "move_away", "block"]
const HISTORY_FIELDS: PackedStringArray = ["log", "analytics", "last_action_target", "last_action_target_actor", "surface_events", "surface_event_sequence", "skill_events", "skill_event_revision", "rng_state"]

static func for_standard_plan(state: Dictionary, intent: Dictionary) -> Dictionary:
	for value: Variant in intent.get("actions", []):
		if not value is Dictionary: return state
		var action: Dictionary = value
		if str(action.get("type", "")) not in GEOMETRIC_ACTIONS or str(action.get("target", "")) == "previous_target":
			return state
	# Own only this outer query projection. The memo still snapshots and compares
	# every retained nested value, so in-place geometry/catalog changes invalidate
	# hits. Resolution and published results continue to use the complete state.
	var inputs: Dictionary = state.duplicate(false)
	for field: String in HISTORY_FIELDS: inputs.erase(field)
	return inputs
