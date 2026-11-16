extends RefCounted
## Authoring proof only; observes production presentation without changing it.
const Fixture = preload("res://tools/tooltip_loops/tip05_fixture.gd")
var mark_seen: bool = false
var airborne_seen: bool = false
var outcrop_seen: bool = false
var landing_seen: bool = false
var landing: Vector2i

func observe(board: Control, sample: int, errors: Array[String]) -> void:
	for threat: Dictionary in board.presentation.get("threats_at_rest", {}).get("threats", []):
		if threat.get("key") == "snare_pressure" and (threat.get("tiles", []) as Array).has(Fixture.CRAWLER): mark_seen = true
	if sample == 1 and not mark_seen: errors.append("Upheaval frame zero must retain the production mark on the Crawler tile")
	if board.presentation.get("unit_throw_ground_positions", {}).has("enemy_1"): airborne_seen = true
	for terrain: Dictionary in board.combat_state.get("terrain", []):
		if terrain["pos"] == Fixture.CRAWLER and terrain.get("kind") == "crag_outcrop": outcrop_seen = true
	var enemy: Dictionary = board.combat_state["enemies"][0]
	if enemy["pos"] != Fixture.CRAWLER:
		landing_seen = true
		landing = enemy["pos"]

func finish(board_numbers: Dictionary, fixture: Dictionary, result: Dictionary) -> Array[String]:
	var errors: Array[String]
	if not (mark_seen and airborne_seen and outcrop_seen and landing_seen): errors.append("Upheaval must present the room mark, Outcrop, production throw and arrival")
	if landing != result["final"]["enemies"][0]["pos"] or not Fixture.PATCH.has_point(landing): errors.append("Upheaval's presented landing must match the real in-patch landing")
	var damage: int = int(fixture["state"]["enemies"][0]["hp"]) - int(result["final"]["enemies"][0]["hp"])
	if damage > 0 and not board_numbers.has("enemy_1:-%d" % damage): errors.append("Upheaval must show its production landing number")
	return errors

func report() -> Dictionary:
	return {"mark_seen": mark_seen, "airborne_seen": airborne_seen, "outcrop_seen": outcrop_seen, "landing_seen": landing_seen, "landing": var_to_str(landing), "landing_inside_patch": Fixture.PATCH.has_point(landing)}
