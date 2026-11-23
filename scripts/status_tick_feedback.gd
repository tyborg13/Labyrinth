extends RefCounted
## Decorate a tick's own loss popup. Cascades
## retain their own source; sharing a tile never transfers status ownership.
const Icons = preload("res://scripts/action_icon_library.gd")

static func cause_icon(step: Dictionary) -> String:
	# Retaliate uses the status_damage transport for a reaction, not a tick.
	# ui-17's tick icons must preserve its existing popup (fix-14 golden).
	if str(step.get("action_type", "")) == "retaliate": return ""
	var explicit: String = str(step.get("status_icon", ""))
	if Icons.KEYWORDS.has(explicit): return explicit
	var status: String = str(step.get("status_id", step.get("label", ""))).to_lower()
	if status in ["fire", "burn"]: return "surface_fire"
	if Icons.KEYWORDS.has(status): return status
	for key: String in Icons.KEYWORDS:
		if str(Icons.KEYWORDS[key]["label"]).to_lower() == status: return key
	return ""

static func decorate(scene: Control, step: Dictionary, entries: Array[Dictionary]) -> Array[Dictionary]:
	var icon: String = cause_icon(step)
	if icon.is_empty(): return entries
	for entry: Dictionary in entries:
		if str(entry.get("reaction_actor_key", "")) != str(step.get("actor_key", "")): continue
		if str(entry.get("reaction", "")) not in ["hit", "block"]: continue
		scene._decorate_status_damage_float(entry, icon)
	return entries

static func enemy_fire_start_losses(scene: Control, events: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary]
	for event: Dictionary in events:
		if event.get("kind") != "surface_damage" or event.get("surface") != "fire":
			continue
		if event.get("trigger") != "start" or event.get("actor_kind") != "enemy":
			continue
		var health_lost: int = int(event.get("health_lost", 0))
		if health_lost <= 0:
			continue
		entries.append_array(scene._status_damage_floating_texts({
			"status_id": "fire", "actor_key": event["actor_key"],
			"tile": event["tile"], "amount": health_lost,
		}))
	return entries
