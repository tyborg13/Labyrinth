extends RefCounted
## The saved sequence is the sole identity for committed board outcomes.
const Ground = preload("res://scripts/board_surface_rules.gd")
const Battlefield = preload("res://scripts/battlefield_rules/analytics.gd")
const Pressure = preload("res://scripts/snare_pressure_analytics.gd")

static func records(combat: Dictionary, context: Dictionary, after_sequence: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var combat_id: String = str(combat.get("analytics", {}).get("combat_id", ""))
	if combat_id.is_empty(): return result
	for event: Dictionary in combat.get("surface_events", []):
		var sequence: int = int(event.get("sequence", 0))
		if sequence <= after_sequence: continue
		var own_context: Dictionary = context.duplicate(false)
		own_context["surface_revision"] = sequence
		own_context["rules_version"] = int(event.get("rules_version", combat.get("surface_event_legacy_rules_version", Ground.RULES_VERSION)))
		var kind: String = str(event.get("kind", ""))
		if kind in ["battlefield_rule_fired", "battlefield_rule_switched"]:
			result.append(Battlefield.record(event, own_context, combat_id))
		elif kind == "snare_pressure":
			result.append(Pressure.record(event, own_context, combat_id))
		else:
			var payload: Dictionary = event.duplicate(true)
			payload["rules_version"] = own_context["rules_version"]
			result.append({"event_type": "surface_event", "context": own_context, "payload": payload, "idempotency_key": "surface_event|%s|%d" % [combat_id, sequence]})
	return result
