extends RefCounted
## atk-03 (director 2026-11-13): at rest, a foe's compact intent disc is red when
## any of its activations before the hero's next turn hurts the hero in the PASS
## forecast from the hero's own tile. Until that forecast is ready for this exact
## state the disc keeps the at-rest threat rule; it adopts the forecast once, and
## the record stays fixed for the rest of that idle. A foe whose later move stays
## unknown keeps the at-rest rule as well. Presentation only.

# Disc marks of one at-rest PASS summary for one committed state revision.
static func record(summary: Dictionary, revision: int) -> Dictionary:
	return {"revision": revision, "hits": summary.get("enemy_hits", {}), "activations": summary.get("enemy_activations", {}), "unknown": summary.get("unknown_repeat_keys", {})}

static func apply(rest: Dictionary, marks: Dictionary, revision: int, at_rest: bool) -> Dictionary:
	if not at_rest or marks.is_empty() or int(marks.get("revision", -1)) != revision: return rest
	var result: Dictionary = rest.duplicate(false)
	var badges: Array[Dictionary]
	for original: Dictionary in rest.get("badges", []):
		var badge: Dictionary = original.duplicate(false)
		var key: String = str(badge.get("key", ""))
		var unknown: bool = (marks["unknown"] as Dictionary).has(key)
		badge["danger"] = (marks["hits"] as Dictionary).has(key) or (unknown and bool(original.get("danger", false)))
		badge["repeats"] = maxi(int(badge.get("repeats", 0)), int((marks["activations"] as Dictionary).get(key, 0)))
		badges.append(badge)
	result["badges"] = badges
	return result

# True when the board still shows discs this record would change.
static func stale(board_rest: Dictionary, marks: Dictionary, revision: int) -> bool:
	var applied: Array = apply(board_rest, marks, revision, true).get("badges", [])
	var shown: Array = board_rest.get("badges", [])
	for index: int in range(mini(applied.size(), shown.size())):
		if bool(applied[index].get("danger", false)) != bool(shown[index].get("danger", false)): return true
		if int(applied[index].get("repeats", 0)) != int(shown[index].get("repeats", 0)): return true
	return false
