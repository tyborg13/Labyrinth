extends RefCounted

const Ground = preload("res://scripts/board_surface_rules.gd")

# Display snapshots only. Never pass retained bodies/fuel back to a resolver:
# earlier actions in a card must still consume their real simulated targets.
static func display_state(projected: Dictionary, committed: Dictionary) -> Dictionary:
	var shown: Dictionary = projected.duplicate(false)
	for collection: String in ["enemies", "illusions", "terrain", "traps"]:
		var projected_by_id: Dictionary = _by_id(projected.get(collection, []))
		var entries: Array = []
		for current: Dictionary in committed.get(collection, []):
			var id: String = str(current.get("id", ""))
			var next: Dictionary = projected_by_id.get(id, {})
			var destroyed: bool = _destroyed(next, collection)
			var held: Dictionary = (current if next.is_empty() or (collection == "terrain" and destroyed) else next).duplicate(true)
			if destroyed: held["pos"] = current.get("pos", Vector2i.ZERO)
			for field: String in ["hp", "block", "stoneskin"]:
				if current.has(field): held[field] = current[field]
			entries.append(held)
			projected_by_id.erase(id)
		for next: Dictionary in projected.get(collection, []):
			if projected_by_id.has(str(next.get("id", ""))): entries.append(next.duplicate(true))
		shown[collection] = entries
	# A consumed surface stays visible; a new surface is still previewed normally.
	var surfaces: Dictionary = (projected.get("surfaces", {}) as Dictionary).duplicate(true)
	for key: Variant in committed.get("surfaces", {}):
		var held: Dictionary = (surfaces.get(key, {}) as Dictionary).duplicate(true)
		var current: Dictionary = committed["surfaces"][key]
		for layer: Variant in current:
			held[layer] = current[layer].duplicate(true) if current[layer] is Dictionary else current[layer]
		surfaces[key] = held
	shown["surfaces"] = surfaces
	return shown

static func object_losses(before: Dictionary, after: Dictionary) -> Dictionary:
	var losses: Dictionary = {}
	for collection: String in ["terrain", "traps"]:
		var after_by_id: Dictionary = _by_id(after.get(collection, []))
		for current: Dictionary in before.get(collection, []):
			var id: String = str(current.get("id", ""))
			if id.is_empty() or _destroyed(current, collection): continue
			var next: Dictionary = after_by_id.get(id, {})
			var destroyed: bool = _destroyed(next, collection)
			var hp: int = maxi(0, int(next.get("hp", 0)))
			var loss: int = maxi(0, int(current.get("hp", 0)) - hp)
			if destroyed or loss > 0:
				losses[("terrain_" if collection == "terrain" else "trap_") + id] = {"hp": hp, "hp_loss": loss, "lethal": destroyed}
	return losses

static func triggered_traps(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var after_by_id: Dictionary = _by_id(after.get("traps", []))
	for trap: Dictionary in before.get("traps", []):
		var next: Dictionary = after_by_id.get(str(trap.get("id", "")), {})
		if next.is_empty() or (bool(next.get("triggered", false)) and not bool(trap.get("triggered", false))):
			result.append(trap.duplicate(true))
	return result

static func _destroyed(entry: Dictionary, collection: String) -> bool:
	if entry.is_empty(): return true
	if collection == "terrain": return not Ground.terrain_is_live(entry)
	if collection == "traps": return false
	return int(entry.get("hp", 0)) <= 0

static func _by_id(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in entries: result[str(entry.get("id", ""))] = entry
	return result
