extends RefCounted

const MAX_HERO_OVERLAP_DISTANCE: int = 3
const Isolation = preload("res://scripts/board_threat_isolation.gd")

static func find(board: Control) -> Dictionary:
	var threats: Array = board.presentation.get("threats_at_rest", {}).get("threats", [])
	var counts: Dictionary = {}
	for threat: Dictionary in threats:
		for tile: Vector2i in threat.get("tiles", []): counts[tile] = int(counts.get(tile, 0)) + 1
	var overlap := Vector2i(-1, -1)
	var empty := Vector2i(-1, -1)
	var hero: Vector2i = board.combat_state.get("player", {}).get("pos", Vector2i(-1, -1))
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if tile == hero or not Isolation.enemy_at_tile(board, tile).is_empty(): continue
		if not Isolation.enemy_at_point(board, board.call("world_position_for_tile", tile)).is_empty(): continue
		if int(counts.get(tile, 0)) == 2 and absi(tile.x - hero.x) + absi(tile.y - hero.y) <= MAX_HERO_OVERLAP_DISTANCE: overlap = tile
		if not counts.has(tile) and _clear_floor(board, tile): empty = tile
	var enemy: Dictionary = {}
	var ordered: Array = threats.duplicate(false)
	ordered.sort_custom(_clear_attack_first)
	for threat: Dictionary in ordered:
		for candidate: Dictionary in board.combat_state.get("enemies", []):
			if "enemy_%d" % int(candidate["id"]) == str(threat["key"]):
				var unit: Dictionary = Isolation.enemy_at_tile(board, candidate["pos"])
				if unit.is_empty(): continue
				var body: Vector2 = board.call("_unit_draw_rect", unit).get_center()
				var hit: Dictionary = Isolation.enemy_at_tile(board, board.call("_tile_at_point", body))
				if hit.is_empty(): hit = Isolation.enemy_at_point(board, body)
				if str(hit.get("key", "")) != str(threat["key"]): continue
				enemy = candidate
				break
		if not enemy.is_empty(): break
	return {"enemy": enemy, "overlap": overlap, "empty": empty}

static func _clear_attack_first(a: Dictionary, b: Dictionary) -> bool:
	var first: Dictionary = a.get("plan", {})
	var second: Dictionary = b.get("plan", {})
	var first_ranged: bool = str(first.get("projected_attack_action", {}).get("type", "")) == "ranged"
	var second_ranged: bool = str(second.get("projected_attack_action", {}).get("type", "")) == "ranged"
	if first_ranged != second_ranged: return first_ranged
	return (first.get("projected_path", []) as Array).size() > (second.get("projected_path", []) as Array).size()

static func _clear_floor(board: Control, tile: Vector2i) -> bool:
	var state: Dictionary = board.combat_state
	if str(state["grid"][tile.y][tile.x]) not in ["stone", "ember"]: return false
	for terrain: Dictionary in state.get("terrain", []):
		if terrain.get("pos") == tile and int(terrain.get("hp", 0)) > 0: return false
	for trap: Dictionary in state.get("traps", []):
		if trap.get("pos") == tile: return false
	for loot: Dictionary in state.get("loot", []):
		if loot.get("pos") == tile and not bool(loot.get("claimed", false)): return false
	return true
