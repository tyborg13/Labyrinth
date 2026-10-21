extends RefCounted

# spx-02 installs the director's immutable file. Both paths use this one reader
# so combat can be implemented against the staged contract before integration.
const DATA_PATH: String = "res://data/special_encounters.json"
const STAGED_PATH: String = "res://spec/peer_benchmark/staged/spx/special_encounters.json"
static var _data: Dictionary = {}

static func definition(id: String) -> Dictionary:
	if _data.is_empty():
		var path: String = DATA_PATH if FileAccess.file_exists(DATA_PATH) else STAGED_PATH
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(parsed is Dictionary, "Invalid director special encounter data: " + path)
		_data = parsed
	return (_data["types"][id] as Dictionary).duplicate(true)

static func is_warband(room: Dictionary) -> bool:
	return str(room.get("type", "")) == "special" and str(room.get("special_type", "")) == "warband"
