extends RefCounted
## Refresh old offline counters without accepting any changed combat outcome or
## non-geometric counter. Empty-cast records require no combat replay.
const ORIGIN_VERSION: String = "caster_v1"
const GEOMETRY_FIELDS: PackedStringArray = ["skybolt_hits_beyond_5", "skybolt_hits_without_los", "skybolt_casts_beyond_5", "skybolt_casts_without_los", "origin_metric"]

static func needs_replay(record: Dictionary) -> bool:
	var usage: Dictionary = record.get("card_usage", {})
	return usage.get("origin_metric", "") != ORIGIN_VERSION and int(usage.get("casts", {}).get("skybolt", 0)) > 0

static func normalized(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))

static func refresh(previous: Dictionary, replay: Callable) -> Dictionary:
	if not previous.has("card_usage"):
		push_error("Metric refresh requires recorded card counters")
		return {}
	if previous.get("card_usage", {}).get("origin_metric", "") == ORIGIN_VERSION: return previous
	var result: Dictionary = previous.duplicate(true)
	if not needs_replay(previous):
		for field: String in previous.get("card_usage", {}):
			if field.begins_with("skybolt_") and int(previous["card_usage"][field]) != 0:
				push_error("Zero-cast metric refresh found a nonzero Skybolt counter")
				return {}
		result["card_usage"]["origin_metric"] = ORIGIN_VERSION
		return result
	var observed: Dictionary = replay.call()
	var before: Dictionary = previous.duplicate(true)
	var after: Dictionary = observed.duplicate(true)
	before.erase("card_usage")
	after.erase("card_usage")
	if normalized(before) != normalized(after):
		push_error("Metric refresh changed a combat result; original outcomes must be preserved")
		return {}
	before = previous["card_usage"].duplicate(true)
	after = observed["card_usage"].duplicate(true)
	for field: String in GEOMETRY_FIELDS:
		before.erase(field)
		after.erase(field)
	if normalized(before) != normalized(after):
		push_error("Metric refresh changed a non-geometric counter")
		return {}
	result["card_usage"] = observed["card_usage"].duplicate(true)
	return result
