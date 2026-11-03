extends RefCounted
## Saved surface sequence + combat id keep committed beats retry-safe in JSONL.
const FIELDS: Array = ["rule", "source_kind", "source_type", "beat_index", "affected_units", "tiles_changed", "damage_to_player", "damage_to_enemies", "half_health_switched"]
static func records(combat: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var combat_id: String = str(combat.get("analytics", {}).get("combat_id", ""))
	if combat_id.is_empty(): return result
	for event: Dictionary in combat.get("surface_events", []):
		if str(event.get("kind", "")) in ["battlefield_rule_fired", "battlefield_rule_switched"]: result.append(record(event, context, combat_id))
	return result

static func record(event: Dictionary, context: Dictionary, combat_id: String) -> Dictionary:
	var payload: Dictionary = {}
	var kind: String = str(event["kind"])
	var fields: Array = ["rule", "source_type", "beat_index"] if kind == "battlefield_rule_switched" else FIELDS
	for field: String in fields: payload[field] = event.get(field, false) if field == "half_health_switched" else event[field]
	return {"event_type": kind, "context": context, "payload": payload, "idempotency_key": "%s|%s|%d" % [kind, combat_id, int(event["sequence"])]}
