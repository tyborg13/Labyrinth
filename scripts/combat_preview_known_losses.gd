extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const ENGINE_RESOURCE_PATH: String = "res://scripts/combat_engine.gd"

# PASS consumes only known losses/uncertainty and stops before an actor repeats.
# Rescheduling uses the intent just resolved, not the next roll. For this closed
# deterministic subset, selecting unrevealed future intents cannot affect any
# announced action. Full-state previews, all other loadouts/mechanics and real
# combat keep the ordinary selector and exact RNG continuation.
static func can_defer_unrevealed_selection(engine: RefCounted, state: Dictionary) -> bool:
	var script: Script = engine.get_script()
	if script == null or script.resource_path != ENGINE_RESOURCE_PATH: return false
	for field: String in ["relics", "skill_ids"]:
		if not state.get(field, []) is Array: return false
	if str(state.get("room_type", "")) not in ["combat", "special"]: return false
	if str(state.get("objective", {}).get("type", "")) not in ["kill_all", "kill_leader"]: return false
	if not engine._relic_effects(state).is_empty() or not (state.get("skill_ids", []) as Array).is_empty(): return false
	if state.get("equipped_equipment", {}) != Data.starting_equipped_equipment(): return false
	for field: String in ["equipment_grafts", "relic_flags", "skill_flags", "self_flags"]:
		var values: Variant = state.get(field, {})
		if not values is Dictionary or not values.is_empty(): return false
	for field: String in ["equipped_items", "illusions", "_surface_pending_deaths"]:
		var values: Variant = state.get(field, [])
		if not values is Array or not values.is_empty(): return false
	for enemy: Dictionary in state.get("enemies", []):
		var definition: Dictionary = Data.enemy_def(str(enemy.get("type", "")))
		if bool(definition.get("guardian", false)) or bool(definition.get("dragon_cycle", false)) or bool(definition.get("boss", false)): return false
		var spawn: Variant = definition.get("death_spawn", {})
		if not spawn is Dictionary or not spawn.is_empty() or not str(definition.get("death_surface", "")).is_empty(): return false
		for action: Dictionary in enemy.get("intent", {}).get("actions", []):
			if str(action.get("type", "")) not in ["move_toward", "move_away", "melee", "ranged", "aoe", "push", "pull", "block", "heal", "gain_charge", "chain_discharge", "call_wind", "tether_beam", "dive_line", "surface"]: return false
	return true
