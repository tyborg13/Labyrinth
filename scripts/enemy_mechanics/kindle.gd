extends RefCounted

const MAX_BONUS: int = 4

static func resolve(state: Dictionary, enemy_index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][enemy_index]
	enemy["kindled_bonus"] = mini(MAX_BONUS, int(enemy.get("kindled_bonus", 0)) + int(action.get("amount", 0)))
	return state

static func available(enemy: Dictionary) -> bool:
	return int(enemy.get("kindled_bonus", 0)) < MAX_BONUS
