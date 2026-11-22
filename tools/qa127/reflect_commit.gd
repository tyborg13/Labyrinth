extends "res://tools/pla01/reflect_preview_probe.gd"
## Reuse the approved cases and capture first, then click the same target.

const MAX_COMMIT_MSEC: int = 10000
const ACTOR_FIELDS: Array[String] = ["hp", "block", "stoneskin", "pos"]

func _shot(name: String) -> void:
	await super._shot(name)
	var scene: Node = _viewport.get_child(0)
	var row: Dictionary = _report[name.trim_prefix("pla01_reflect_")]
	var cache: Dictionary = scene._surface_preview_cache
	var before: Dictionary = scene._combat_state.duplicate(true)
	var expected: Dictionary = cache.get("state", {}).duplicate(true)
	if expected.is_empty():
		_fail(name + ": no aimed state to compare with the committed click")
		return
	scene._on_board_tile_clicked(MIRROR_TILE)
	var deadline: int = Time.get_ticks_msec() + MAX_COMMIT_MSEC
	while scene._animation_lock and Time.get_ticks_msec() < deadline:
		await process_frame
	var actual: Dictionary = scene._combat_state
	var compared: Dictionary = {
		"player": [_actor(expected["player"]), _actor(actual.get("player", {}))],
		"defiance": [expected.get("defiance_remaining"), actual.get("defiance_remaining")],
		"bounces": [Reflect.bounces_between(before, expected), Reflect.bounces_between(before, actual)],
	}
	for enemy: Dictionary in expected["enemies"]:
		var id: int = int(enemy["id"])
		var unit: Dictionary = scene._combat_engine._surface_actor(actual, "enemy", id)
		compared["enemy_%d" % id] = [_actor(enemy), _actor(unit)]
	var matches: bool = true
	for field: String in compared:
		var pair: Array = compared[field]
		if pair[0] == pair[1]: continue
		matches = false
		_fail("%s: %s preview/commit differs: %s" % [name, field, str(pair)])
	var committed: bool = actual.get("deck", {}).get("hand", []).size() < before["deck"]["hand"].size()
	_check(committed and not scene._animation_lock, name + ": the click committed and released input")
	row["commit_matches"] = matches and committed and not scene._animation_lock
	row["commit_comparison"] = compared
	print("QA127 REFLECT COMMIT %s: %s" % [name, "PASS" if row["commit_matches"] else "FAIL"])

func _actor(unit: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ACTOR_FIELDS:
		result[field] = unit.get(field)
	return result
