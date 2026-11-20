extends RefCounted
## The Pass forecast supplies repeat counts and announced footprint corrections.
## The chip's danger colour describes the announced attack.

const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")

static func record(summary: Dictionary, revision: int) -> Dictionary:
	return {"revision": revision, "activations": summary.get("enemy_activations", {}),
		"unknown": summary.get("unknown_repeat_keys", {}), "died_first_keys": summary.get("died_first_keys", {}),
		"relative_red_areas": summary.get("relative_red_areas", {}),
		"hero_red_contacts": summary.get("hero_red_contacts", {}),
		RedTiles.CONTACT_SOURCES: summary.get(RedTiles.CONTACT_SOURCES, {})}

static func apply(rest: Dictionary, marks: Dictionary, revision: int, at_rest: bool) -> Dictionary:
	if not at_rest or marks.is_empty() or int(marks.get("revision", -1)) != revision: return rest
	var projection: Dictionary = RedTiles.adjust_from_summary(rest, marks)
	var result: Dictionary = projection.duplicate(false)
	var shifted: Dictionary = {}
	for threat: Dictionary in projection.get("threats", []):
		if threat.has("area_forecast_anchor"):
			shifted[threat["key"]] = threat["tiles"]
	var badges: Array[Dictionary]
	for original: Dictionary in rest.get("badges", []):
		var badge: Dictionary = original.duplicate(false)
		var key: String = str(badge.get("key", ""))
		if (marks["died_first_keys"] as Dictionary).has(key):
			badge["danger"] = false
		elif shifted.has(key):
			badge["danger"] = bool(badge.get("acting", false)) and not bool(badge.get("cancelled", false)) and (shifted[key] as Array).has(rest.get("hero_tile"))
		var count: int = int((marks["activations"] as Dictionary).get(key, 0))
		# Known counts include repeats even when their moves are not shown.
		badge["repeats"] = maxi(int(badge.get("repeats", 0)), count) if (marks["unknown"] as Dictionary).has(key) else count
		badges.append(badge)
	result["badges"] = badges
	return result

static func stale(board_rest: Dictionary, marks: Dictionary, revision: int) -> bool:
	var projection: Dictionary = apply(board_rest, marks, revision, true)
	return projection.get("badges", []) != board_rest.get("badges", []) or projection.get("threats", []) != board_rest.get("threats", [])

# Supplements are published with the same exact-revision forecast as the plates.
static func has_floor_supplements(rest: Dictionary, marks: Dictionary) -> bool:
	return marks.get("hero_red_contacts", {}).has(rest.get("hero_tile"))
