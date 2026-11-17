extends RefCounted
## Continuous recorder observations; geometry/commands are not native pixel proof.
const Fixture = preload("res://tools/tooltip_loops/trap_fixture.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Terrain = preload("res://tools/tooltip_loops/terrain_checks.gd")
var trigger_seen: bool = false
var push_seen: bool = false
var final_plus_seen: bool = false
var all_tiles_in_frame: bool = true

func observe(board: Control, crop: Rect2i, errors: Array[String]) -> void:
	if not board.presentation.get("trap_effects", []).is_empty(): trigger_seen = true
	if board.presentation.has("unit_world_positions") and board.presentation["unit_world_positions"].has("enemy_2"): push_seen = true
	for tile: Vector2i in Fixture.affected_tiles():
		for vertex: Vector2 in board._tile_polygon(tile):
			if not Rect2(crop).has_point(board.get_global_transform_with_canvas() * vertex): all_tiles_in_frame = false
	var element: String = str(board.capture_id).trim_prefix("trap_")
	if element == "air": return
	var complete: bool = true
	for tile: Vector2i in Fixture.affected_tiles():
		if not Ground.has_surface(board.combat_state, tile, Ground.kind(element)) or not Terrain._surface_visible(board, tile, Ground.kind(element)): complete = false
	if complete: final_plus_seen = true
	if not all_tiles_in_frame and not errors.has("Trap's five tiles must remain in the loop frame"): errors.append("Trap's five tiles must remain in the loop frame")

func finish(board: Control, fixture: Dictionary, errors: Array[String]) -> Dictionary:
	var damage: int = int(fixture["state"]["traps"][0]["base_damage"])
	if not trigger_seen: errors.append("Trap loop must show the production trigger effect")
	if not board.seen_numbers.has("enemy_1:-%d" % damage): errors.append("Trap loop must show the Crawler's real damage number")
	if fixture["id"] == "trap_air":
		if not push_seen: errors.append("Air loop must show the production push moving the far Crawler")
	elif not final_plus_seen: errors.append("Trap loop must show production ground art on all five tiles")
	return {"trigger_seen": trigger_seen, "push_seen": push_seen, "final_plus_seen": final_plus_seen, "all_tiles_in_frame": all_tiles_in_frame, "damage": damage}
