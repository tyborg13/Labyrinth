extends RefCounted

const Slices = preload("res://scripts/board_layer_slices.gd")
const FloorPixels = preload("floor_pixels.gd")
const SamplePixels = preload("sample_pixels.gd")
const Trace = preload("trace.gd")
const Rules = preload("res://scripts/board_surface_rules.gd")

static func moment(board: Control, headless: bool) -> Dictionary:
	var tiles: Array[Dictionary]
	var hero: Vector2i = board.combat_state["player"]["pos"]
	var sources: Dictionary = {"lob_marks": board.LobView.floor_marks(board)}
	var tx: Transform2D = board.get_global_transform_with_canvas()
	var hero_threatened: bool = false
	var floor_pixels := FloorPixels.new()
	var commands: Dictionary
	if headless:
		floor_pixels.prepare(board)
		commands = Trace.snapshot(board)
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		var polygon: PackedVector2Array = board._tile_polygon(tile)
		var paint: Dictionary = Slices.threat_paint(board, tile, sources, polygon)
		if paint.is_empty(): continue
		var surface: Dictionary = Rules.surface_at(board.combat_state, tile)
		var tile_row: Dictionary = {"tile": [tile.x, tile.y], "diamond": points(tx * polygon),
			"surface": Rules.kind(str(surface.get("elemental", ""))), "rubble": surface.get("rubble", false),
			"alpha": paint["alpha"], "pulses": paint["hero"]}
		if headless:
			tile_row.merge(commands.get(tile, {"strokes": []}))
			tile_row["samples"] = SamplePixels.sample_floor(board, tile, tx * polygon, floor_pixels, tile_row["surface"] == "fire")
		tiles.append(tile_row)
		hero_threatened = hero_threatened or tile == hero
	return {"tiles": tiles, "hero_threatened": hero_threatened, "hero": [hero.x, hero.y]}

static func points(polygon: PackedVector2Array) -> Array[Array]:
	var result: Array[Array]
	for point: Vector2 in polygon: result.append([point.x, point.y])
	return result
