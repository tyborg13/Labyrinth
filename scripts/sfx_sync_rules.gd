extends RefCounted

const DATA_PATH: String = "res://data/sfx_cues.json"
static var _cached: Dictionary = {}

static func config() -> Dictionary:
	if _cached.is_empty():
		_cached = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))["rules"]["sync"]
	return _cached

static func duration_cap(cue: String, entry: Dictionary) -> float:
	var policy: Dictionary = config()["duration"]
	if bool(entry.get("loop", false)) or cue.begins_with(str(policy["ambience_prefix"])): return INF
	if entry.get("bus", "") == policy["short_bus"] or cue in policy["short_cues"]:
		return float(policy["caps_seconds"]["short"])
	for prefix: String in policy["short_prefixes"]:
		if cue.begins_with(prefix): return float(policy["caps_seconds"]["short"])
	for prefix: String in policy["spell_prefixes"]:
		if cue.begins_with(prefix): return float(policy["caps_seconds"]["spell"])
	return float(policy["caps_seconds"]["signature"])
