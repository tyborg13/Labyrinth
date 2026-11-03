extends RefCounted
## The saved latch belongs to the instance; no cadence counters are restarted.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Identity = preload("res://scripts/enemy_identity.gd")

static func replace_values(instance: Dictionary, change: Dictionary) -> void:
	for field: String in ["cadence", "dials"]:
		if change.has(field): instance[field].merge(change[field], true)
	instance["sentence"] = change["sentence"]

static func check(state: Dictionary) -> bool:
	var instance: Dictionary = state.get("battlefield_rule", {})
	if not instance.has("at_half_health") or bool(instance.get("half_health_switched", false)): return false
	if str(instance.get("source", {}).get("kind", "")) != "enemy": return false
	for source: Dictionary in state.get("enemies", []):
		if int(source.get("id", -2)) != int(instance["source"].get("id", -1)): continue
		var hp: int = int(source.get("hp", 0))
		var maximum: int = int(source.get("max_hp", 0))
		if hp <= 0 or maximum <= 0 or hp * 2 > maximum: return false
		var change: Dictionary = instance["at_half_health"]
		# Keep held marks/directions unless the switch changes their geometry.
		var changed_dials: Dictionary = change.get("dials", {})
		# An aimed Gust reuses the held announcement until it next announces.
		for field: String in ["direction", "spread"]:
			if changed_dials.has(field) and changed_dials[field] != instance["dials"].get(field) and str(changed_dials[field]) != "aimed": instance.erase("locked_direction")
		for field: String in ["pattern", "length"]:
			if changed_dials.has(field) and changed_dials[field] != instance["dials"].get(field): instance.erase("marks")
		replace_values(instance, change)
		instance["half_health_switched"] = true
		Surfaces.record_event(state, {"kind": "battlefield_rule_switched", "rule": instance["rule"], "source_type": str(source.get("type", "")), "beat_index": int(instance.get("beats_fired", 0)), "banner": "%s GROWS FIERCER" % Identity.display_name(source).get_slice(",", 0).strip_edges().to_upper()})
		return true
	return false
