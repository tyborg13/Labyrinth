extends RefCounted

## Load-boundary conversion for live combat and continuation snapshots. Keep the saved
## intent's name, Time, damage scaling and next-intent scheduling.
static func migrate(run: Dictionary) -> void:
	# Only resumable states own executable enemy intents. Analytics, history
	# and checkpoint metadata are immutable records even when their keys match.
	if run.get("combat_state") is Dictionary: _combat(run["combat_state"])
	if run.get("pending_combat_checkpoints") is Array:
		for checkpoint: Variant in run["pending_combat_checkpoints"]:
			if checkpoint is Dictionary and checkpoint.get("state") is Dictionary: _combat(checkpoint["state"])

static func _combat(state: Dictionary) -> void:
	if not state.get("player") is Dictionary or not state.get("enemies") is Array: return
	for enemy: Dictionary in state.get("enemies", []):
		enemy.erase("veiled")
		if enemy.get("intent") is Dictionary: _intent(enemy["intent"])

static func _intent(intent: Dictionary) -> void:
	if intent.get("actions") is Array:
		var actions: Array = []
		var converted: bool = false
		for action: Dictionary in intent["actions"]:
			if bool(action.get("ends_veil", false)): action["ambush"] = true
			action.erase("ends_veil")
			if str(action.get("type", "")) == "dive_line":
				actions.append({"type": "move_toward", "range": int(action.get("max_length", 4))})
				# Keep saved ordinary riders and scaling metadata; retire only
				# the bespoke geometry/direction fields.
				var attack: Dictionary = action.duplicate(true)
				attack.erase("max_length")
				attack.erase("side_push")
				attack.merge({"type": "aoe", "damage": int(action.get("damage", 4)), "committed_shape": "swept_path", "push": int(action.get("side_push", 1)), "element": str(action.get("element", "air"))}, true)
				actions.append(attack)
				converted = true
			else: actions.append(action)
		if converted:
			intent["actions"] = actions
			intent.erase("committed_plan")
