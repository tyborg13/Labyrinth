extends RefCounted

## Up-front room envelope: geometry scales with tiles, health bars stay in pixels.
## Actor positions, visibility, facing, death and hand focus never change this fit.
const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const GameData = preload("res://scripts/game_data.gd")
const REFERENCE_WIDTH: float = 100.0
const HUD_HALF_WIDTH: float = 71.0
const HUD_HEIGHT: float = 34.0
const HUD_CLEARANCE: float = 10.0
var signature: String = ""
var body_bounds := Rect2()
var floor_bounds := Rect2()
var head_bounds := Rect2()
var _has_heads: bool = false

func capture(board: Control, room_signature: String, tiles: Array[Vector2i]) -> void:
	signature = room_signature
	body_bounds = Rect2()
	floor_bounds = Rect2()
	head_bounds = Rect2()
	_has_heads = false
	# The owner temporarily resolves reference-width geometry at origin zero.
	# Include doors, pillars and fixed room props, even when no actor is near them.
	for rect: Rect2 in board.call("rendered_visual_rects", false):
		body_bounds = rect if not body_bounds.has_area() else body_bounds.merge(rect)
	for tile: Vector2i in tiles:
		var center: Vector2 = _tile_center(Vector2(tile))
		var rect := Rect2(center - Vector2(50, 25), Vector2(100, 70))
		floor_bounds = rect if not floor_bounds.has_area() else floor_bounds.merge(rect)
	body_bounds = body_bounds.merge(floor_bounds)
	var grid: Array = (board.get("combat_state") as Dictionary).get("grid", [])
	# Reserve the roster up front, including possible summons and hidden enemies.
	# Large actors only contribute at origins that hold their complete footprint.
	# This is a profile budget, not a scan of today's visible occupants.
	var profiles: Array[Dictionary]
	for unit_type: String in ActorPresentation.PROFILES:
		var definition: Dictionary = GameData.enemy_def(unit_type)
		var raw_footprint: Array = definition.get("footprint", [1, 1])
		profiles.append({"type": unit_type, "footprint": Vector2i(int(raw_footprint[0]), int(raw_footprint[1])),
			"scale": REFERENCE_WIDTH * 1.03 * float(definition.get("art_scale", 1.0)) / 255.0,
			"body": ActorPresentation.body_envelope(unit_type), "height": ActorPresentation.height_above_floor(unit_type)})
	for tile: Vector2i in tiles:
		if not _fits(grid, tile, Vector2i.ONE):
			continue
		var center: Vector2 = _tile_center(Vector2(tile))
		body_bounds = body_bounds.merge(Rect2(center + Vector2(-55, -88), Vector2(110, 112)))
		_add_head(center + Vector2(0, -82))
		for profile: Dictionary in profiles:
			var footprint: Vector2i = profile["footprint"]
			if not _fits(grid, tile, footprint):
				continue
			var foot: Vector2 = _tile_center(Vector2(tile) + Vector2(footprint - Vector2i.ONE) * 0.5)
			var source_scale: float = profile["scale"]
			var source: Rect2 = profile["body"]
			body_bounds = body_bounds.merge(Rect2(foot + source.position * source_scale, source.size * source_scale))
			_add_head(foot - Vector2(0, float(profile["height"]) * source_scale))

func bounds(tile_width: float) -> Rect2:
	var factor: float = tile_width / REFERENCE_WIDTH
	var result := Rect2(body_bounds.position * factor, body_bounds.size * factor)
	if _has_heads:
		var hud := Rect2(head_bounds.position * factor - Vector2(HUD_HALF_WIDTH, HUD_HEIGHT + HUD_CLEARANCE),
			head_bounds.size * factor + Vector2(HUD_HALF_WIDTH * 2.0, HUD_HEIGHT))
		result = result.merge(hud)
	return result

func tile_width(available: Rect2, maximum: float) -> float:
	var low: float = 1.0
	var high: float = maximum
	for iteration: int in range(18):
		var candidate: float = (low + high) * 0.5
		var size: Vector2 = bounds(candidate).size
		if size.x <= available.size.x and size.y <= available.size.y:
			low = candidate
		else:
			high = candidate
	return low

func origin(available: Rect2, tile_width: float) -> Vector2:
	return available.get_center() - bounds(tile_width).get_center()

func _add_head(point: Vector2) -> void:
	head_bounds = head_bounds.expand(point) if _has_heads else Rect2(point, Vector2.ZERO)
	_has_heads = true

static func _tile_center(tile: Vector2) -> Vector2:
	return Vector2((tile.x - tile.y) * 50.0, (tile.x + tile.y) * 25.0)

static func _fits(grid: Array, origin: Vector2i, footprint: Vector2i) -> bool:
	for y: int in range(origin.y, origin.y + footprint.y):
		if y < 0 or y >= grid.size():
			return false
		for x: int in range(origin.x, origin.x + footprint.x):
			if x < 0 or x >= (grid[y] as Array).size() or str(grid[y][x]) in ["wall", "pillar", "void", "empty"]:
				return false
	return true
