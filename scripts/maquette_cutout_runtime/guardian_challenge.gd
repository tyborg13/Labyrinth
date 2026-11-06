extends RefCounted

## The director baked tremble into constant angular holds. Reduced motion
## keeps the authored endpoints and all anticipation/recovery/swing channels.
static var _reduced_keys: Dictionary = {}

static func without_tremble(data: Dictionary, track: Dictionary, facing: String) -> Array:
	var keys: Array = track["keys"]
	if str(track["channel"]) not in ["lean_deg", "angle_deg"]: return keys
	var cache_key: String = str(data["director_sha256"]) + "/" + facing + "/" + str(track["source"])
	if _reduced_keys.has(cache_key): return _reduced_keys[cache_key]
	var start: Dictionary = {}
	var finish: Dictionary = {}
	for key: Dictionary in keys:
		if is_equal_approx(float(key["at"]), 0.30): start = key
		elif is_equal_approx(float(key["at"]), 0.72): finish = key
	var result: Array = keys
	if not start.is_empty() and not finish.is_empty() and is_equal_approx(float(start["value"]), float(finish["value"])):
		result = []
		for key: Dictionary in keys:
			if float(key["at"]) <= 0.30 or float(key["at"]) >= 0.72: result.append(key)
	_reduced_keys[cache_key] = result
	return result
