extends RefCounted

const INVALID_TARGET := Vector2i(-1, -1)

# Replay only the resolved prefix on a snapshot whose hidden causes have already
# been removed. Targets include a placeholder for each skipped targeted action;
# consume those slots even if filtering changes whether an action can resolve.
static func resolved_prefix(engine: RefCounted, prepared: Dictionary, actions: Array, resolved_count: int, selected_targets: Array[Vector2i]) -> Dictionary:
	var known: Dictionary = prepared
	var target_cursor: int = 0
	for index: int in range(mini(resolved_count, actions.size())):
		var action: Dictionary = actions[index]
		var targeted: bool = engine.player_action_needs_target(action)
		var target: Vector2i = INVALID_TARGET
		if targeted:
			if target_cursor < selected_targets.size(): target = selected_targets[target_cursor]
			target_cursor += 1
		if not engine.player_action_can_resolve(known, action): continue
		if targeted:
			if target.x < 0 or not engine.valid_targets_for_player_action(known, action).has(target): continue
		elif str(action.get("type", "")) == "aoe" and engine.valid_targets_for_player_action(known, action).is_empty():
			continue
		known = engine.apply_player_action(known, action, target)
	return known
