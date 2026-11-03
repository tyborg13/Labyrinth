extends RefCounted

## Partial board snapshots used by the existing compound enemy presentations.
static func snapshot(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["player", "enemies", "surfaces", "traps", "terrain", "loot"]:
		if state.has(key): result[key] = state[key].duplicate(true)
	return result
