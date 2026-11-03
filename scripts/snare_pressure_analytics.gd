extends RefCounted
## Additive JSONL records use the saved surface sequence for retry-safe identity.
static func records(combat: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var combat_id: String = str(combat.get("analytics", {}).get("combat_id", ""))
	if combat_id.is_empty(): return result
	for event: Dictionary in combat.get("surface_events", []):
		if str(event.get("kind", "")) == "snare_pressure": result.append(record(event, context, combat_id))
	return result

static func record(event: Dictionary, context: Dictionary, combat_id: String) -> Dictionary:
	return {"event_type": "snare_pressure", "context": context,
		"payload": {"id": event["id"], "player_turn": event["player_turn"], "tiles": event["tiles"]},
		"idempotency_key": "snare_pressure|%s|%d" % [combat_id, int(event["sequence"])]}
