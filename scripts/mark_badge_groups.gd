extends RefCounted
## One painter call per source and icon. The tile values are the numbers on
## that icon (null for an unnumbered medallion).

const Surface = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const FRONT_NEIGHBORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]
enum AnchorClass { CLEAR, COVERED, OCCUPIED }

static func anchors(view: Control, numbers_by_tile: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for group: Dictionary in groups(view, numbers_by_tile):
		result.append(group["anchor"])
	return result

static func groups(view: Control, numbers_by_tile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if numbers_by_tile.is_empty(): return result
	var grid: Array = view.combat_state.get("grid", [])
	var remaining: Dictionary = numbers_by_tile.duplicate()
	var board: Control = view._render_instrumentation_owner if is_instance_valid(view._render_instrumentation_owner) else view
	var occupied: Dictionary = _occupants(board) if remaining.size() > 1 else {}
	var to_screen: Transform2D = view.get_global_transform_with_canvas()
	for start: Vector2i in numbers_by_tile:
		if not remaining.erase(start) or not Paths.is_in_bounds(grid, start): continue
		var queue: Array[Vector2i]
		queue.append(start)
		var front := Vector2i(-1, -1)
		var front_point := Vector2(-INF, -INF)
		var front_class: AnchorClass = AnchorClass.OCCUPIED
		var index: int = 0
		while index < queue.size():
			var tile: Vector2i = queue[index]
			index += 1
			if view._board_tile_is_visible_to_player(tile):
				var point: Vector2 = to_screen * view._tile_center(tile)
				var tile_class: AnchorClass = _anchor_class(tile, grid, occupied)
				if front.x < 0 or _comes_before(point, tile_class, front_point, front_class):
					front = tile
					front_point = point
					front_class = tile_class
			# Unseen tiles can connect a group but cannot hold its badge.
			for direction: Vector2i in Paths.DIRS_4:
				var next: Vector2i = tile + direction
				if not remaining.has(next) or remaining[next] != numbers_by_tile[start]: continue
				if not Paths.is_in_bounds(grid, next): continue
				remaining.erase(next)
				queue.append(next)
		if front.x >= 0: result.append({"anchor": front, "tiles": queue})
	return result

static func _anchor_class(tile: Vector2i, grid: Array, occupied: Dictionary) -> AnchorClass:
	if occupied.has(tile) or Paths.tile_id(grid, tile) in Paths.BLOCKING_TILES:
		return AnchorClass.OCCUPIED
	for offset: Vector2i in FRONT_NEIGHBORS:
		var neighbor: Vector2i = tile + offset
		if occupied.get(neighbor, false) or Paths.tile_id(grid, neighbor) in Paths.BLOCKING_TILES:
			return AnchorClass.COVERED
	return AnchorClass.CLEAR

static func _comes_before(point: Vector2, tile_class: AnchorClass, front: Vector2, front_class: AnchorClass) -> bool:
	if tile_class != front_class: return tile_class < front_class
	if point.y != front.y: return point.y > front.y
	return point.x < front.x

static func _occupants(board: Control) -> Dictionary:
	# An isolated painter temporarily narrows its enemy list. The board still
	# owns all living footprints and objects, including the other enemies.
	var state: Dictionary = board.combat_state
	# Membership marks an occupied tile. The value says whether it can cover
	# a medallion on one of the tiles behind it.
	var result: Dictionary = {}
	var player: Dictionary = state.get("player", {})
	if int(player.get("hp", 0)) > 0:
		for tile: Vector2i in Surface.footprint_tiles(player): result[tile] = true
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		var origin: Vector2i = enemy["pos"]
		var size: Vector2i = board._resolved_unit_footprint(enemy)
		for y: int in range(size.y):
			for x: int in range(size.x): result[origin + Vector2i(x, y)] = true
	for field: String in ["illusions", "npcs"]:
		for unit: Dictionary in state.get(field, []):
			if int(unit.get("hp", 1)) <= 0: continue
			for tile: Vector2i in Surface.footprint_tiles(unit): result[tile] = true
	for terrain: Dictionary in state.get("terrain", []):
		if Surface.terrain_is_live(terrain): result[terrain["pos"]] = true
	for prop: Dictionary in board.presentation.get("scene_props", []): result[prop["tile"]] = true
	for loot: Dictionary in state.get("loot", []):
		if not bool(loot.get("claimed", false)) and not result.has(loot["pos"]): result[loot["pos"]] = false
	for field: String in ["traps", "guardian_braziers"]:
		for object: Dictionary in state.get(field, []):
			if not result.has(object["pos"]): result[object["pos"]] = false
	return result
