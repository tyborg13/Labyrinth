extends RefCounted
## atk-03 (director 2026-11-13): at rest, a foe's compact intent disc is red when
## any of its activations before the hero's next turn hurts the hero in the PASS
## forecast from the hero's own tile. Until that forecast is ready for this exact
## state the disc keeps the at-rest threat rule; it adopts the forecast once, and
## the record stays fixed for the rest of that idle. A foe whose later move stays
## unknown keeps the at-rest rule as well. Presentation only.
## atk-09: the same record also carries the red tiles' forecast part (later
## activations' struck tiles, foes that die first; pass_forecast_red_tiles.gd).
## atk-11: a hovered destination's or card's own forecast is applied the same way
## (stage_hover_refresh.gd), and the record marks what strikes the hero's tile.

const RedTiles = preload("res://scripts/pass_forecast_red_tiles.gd")

# Disc marks of one at-rest PASS summary for one committed state revision.
static func record(summary: Dictionary, revision: int) -> Dictionary:
	return {"revision": revision, "hits": summary.get("enemy_hits", {}), "activations": summary.get("enemy_activations", {}), "unknown": summary.get("unknown_repeat_keys", {}),
		"later": summary.get("later_red_tiles", {}), "died_first": summary.get("died_first_keys", {}), "hero": summary.get("hero_red_owners", {})}

static func apply(rest: Dictionary, marks: Dictionary, revision: int, at_rest: bool, focus: String = "") -> Dictionary:
	if not at_rest or marks.is_empty() or int(marks.get("revision", -1)) != revision: return rest
	var result: Dictionary = rest.duplicate(false)
	var badges: Array[Dictionary]
	for original: Dictionary in rest.get("badges", []):
		var badge: Dictionary = original.duplicate(false)
		var key: String = str(badge.get("key", ""))
		var unknown: bool = (marks["unknown"] as Dictionary).has(key)
		badge["danger"] = (marks["hits"] as Dictionary).has(key) or (unknown and bool(original.get("danger", false)))
		var count: int = int((marks["activations"] as Dictionary).get(key, 0))
		# Known counts replace the queue projection, including when a foe dies
		# before a projected repeat. An unknown later move keeps its disclosure.
		badge["repeats"] = maxi(int(badge.get("repeats", 0)), count) if unknown else count
		badges.append(badge)
	result["badges"] = badges
	return RedTiles.adjust(result, marks.get("later", {}), marks.get("died_first", {}), focus, marks.get("hero", {}))

# True when the board still shows discs this record would change.
static func stale(board_rest: Dictionary, marks: Dictionary, revision: int) -> bool:
	var applied: Array = apply(board_rest, marks, revision, true).get("badges", [])
	var shown: Array = board_rest.get("badges", [])
	for index: int in range(mini(applied.size(), shown.size())):
		if bool(applied[index].get("danger", false)) != bool(shown[index].get("danger", false)): return true
		if int(applied[index].get("repeats", 0)) != int(shown[index].get("repeats", 0)): return true
	return RedTiles.signature(apply(board_rest, marks, revision, true)) != RedTiles.signature(board_rest)
