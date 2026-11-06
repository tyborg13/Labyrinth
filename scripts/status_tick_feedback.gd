extends RefCounted
## Reuse the existing Bleed popup treatment for a tick's own losses. Cascades
## retain their own source; sharing a tile never transfers status ownership.
const Icons = preload("res://scripts/action_icon_library.gd")
const Receipts = preload("res://scripts/status_tick_receipts.gd")

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
		scene._decorate_bleed_damage_float(entry, icon)
	return entries

static func player_losses(scene: Control, before: Dictionary, after: Dictionary, entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in entries:
		var text: String = str(entry.get("text", ""))
		var field: String = "block" if text.ends_with(" B") else "stoneskin" if text.ends_with(" S") else "hp"
		var loss: int = maxi(0, int(before.get("player", {}).get(field, 0)) - int(after.get("player", {}).get(field, 0)))
		var tick: int = mini(loss, Receipts.player_bleed_loss(before, after, field))
		if tick > 0:
			var status_entry: Dictionary = entry.duplicate(true)
			var suffix: String = " B" if field == "block" else " S" if field == "stoneskin" else ""
			status_entry["text"] = "-%d%s" % [tick, suffix]
			scene._decorate_bleed_damage_float(status_entry, "bleed")
			result.append(status_entry)
			if tick == loss: continue
			entry["text"] = "-%d%s" % [loss - tick, suffix]
		result.append(entry)
	return result
