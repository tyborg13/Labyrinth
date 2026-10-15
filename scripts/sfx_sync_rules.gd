extends RefCounted

const DATA_PATH: String = "res://data/sfx_cues.json"
static var _cached: Dictionary = {}

static func config() -> Dictionary:
	if _cached.is_empty():
		_cached = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))["rules"]["sync"]
	return _cached
