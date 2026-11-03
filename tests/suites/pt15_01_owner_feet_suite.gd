extends RefCounted
## Proof-only geometry; sole dimensions below are independent contract values.
const Badges = preload("res://scripts/intent_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")
const Sources = preload("res://tests/pt14_01_source_suite.gd")
const CacheSuite = preload("res://tests/suites/pt15_01_sole_cache_suite.gd")
const ANCHOR := Vector2(500, 500)
const BADGE: Dictionary = {"key": "owner", "number": ""}
const OWNER_BOUNDS := Rect2(400, 400, 200, 120)
const SOLE_TOP: float = 512.8
const SOLE_HEIGHT: float = 7.2
const FOOT_WIDTH: float = 4.0
const EXPECTED_SHIFT: float = 8.0
const EXPECTED_PADDING: float = 4.0
const TORSO_HEIGHT: float = 90.0
const GAP_QUERY := Rect2(490, 514, 4, 4)
const EPSILON: float = 0.001
const EXHAUSTED_FOOT_WIDTH: float = 90.0

static func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

static func shape(parts: Array) -> Dictionary:
	var polygons: Array[PackedVector2Array]
	for part: Rect2 in parts: polygons.append(polygon(part))
	return {"key": "owner", "rect": OWNER_BOUNDS, "polygons": polygons, "weight": 1.0}

static func run(expect: Callable) -> void:
	var font: Font = Badges.Typography.ui_font()
	var right_center: Vector2 = ANCHOR + Badges.FEET_OFFSET
	var right: Rect2 = Badges.chip_rect(right_center, BADGE, font)
	var left_center := Vector2(ANCHOR.x - Badges.FEET_OFFSET.x - (right.end.x - right_center.x), right_center.y)
	var left: Rect2 = Badges.chip_rect(left_center, BADGE, font)
	var right_sole := Rect2(right.position.x, SOLE_TOP, FOOT_WIDTH, SOLE_HEIGHT)
	var left_sole := Rect2(left.end.x - FOOT_WIDTH, SOLE_TOP, FOOT_WIDTH, SOLE_HEIGHT)
	# A taller source polygon proves clipping precedes tight bounding and growth.
	var tall_part := Rect2(right.position.x, OWNER_BOUNDS.position.y, FOOT_WIDTH, OWNER_BOUNDS.size.y)
	var owner: Dictionary = shape([tall_part])
	var sole: Rect2 = Solver.owner_sole_obstacle([owner], "owner")
	expect.call(sole.is_equal_approx(right_sole.grow(EXPECTED_PADDING)), "Sole-band mutation: tight bottom 6 percent bounds grow by exactly 4px on every side")
	expect.call(Solver.coverage(right, [owner], "owner") == 0.0, "Owner stays excluded from coverage and side scoring")
	var placed: Dictionary = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), [owner])
	var expected: Rect2 = right
	expected.position.x += EXPECTED_SHIFT
	expect.call((placed["rect"] as Rect2).is_equal_approx(expected) and not placed["above_everything"], "Sole-obstacle mutation: blocked preferred home slides on its own side")
	expect.call((placed["rect"] as Rect2).is_equal_approx(expected), "Preferred-side mutation: a short slide wins over the other clear home")
	var single: Dictionary = Solver.find_clear(right, left, [sole], [], Rect2(), false, true)
	var both: Dictionary = Solver.find_clear(right, left, [sole], [], Rect2())
	expect.call((single["rect"] as Rect2).is_equal_approx(expected) and both["rect"] == left, "Single-home mutation: one-home search excludes the other clear home")
	var left_owner: Dictionary = shape([left_sole])
	var hero: Dictionary = {"key": "hero", "rect": right, "weight": 2.0}
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), [left_owner, hero])
	expected = left
	expected.position.x -= EXPECTED_SHIFT
	expect.call((placed["rect"] as Rect2).is_equal_approx(expected), "Coverage-preferred left side also slides before trying the other home")
	# Symmetric soles block both homes. The original nearest-clear solver picks
	# an 8px horizontal escape over the farther vertical edge, preserving home.
	owner = shape([right_sole, left_sole])
	sole = Solver.owner_sole_obstacle([owner], "owner")
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), [owner])
	expected = right
	expected.position.x += EXPECTED_SHIFT
	expect.call((placed["rect"] as Rect2).is_equal_approx(expected), "Sole-padding mutation: both homes blocked use the existing nearest-clear search")
	expect.call(not placed["above_everything"] and not (placed["rect"] as Rect2).intersects(sole, false), "Nonfallback chip clears the sole obstacle")
	var clear: Dictionary = Solver.find_clear(right, left, [sole], [], Rect2())
	expect.call(placed["rect"] == clear["rect"], "No separate clearance slide changes the original search homes")
	expect.call(Solver.coverage(GAP_QUERY, [owner]) == 0.0 and sole.intersects(GAP_QUERY, false), "Sole obstacle deliberately bounds the gap between disconnected sole polygons")
	# Subtracting a hole that removes one complete sole tightens the bounds.
	owner["holes"] = [polygon(left_sole)]
	expect.call(Solver.owner_sole_obstacle([owner], "owner").is_equal_approx(right_sole.grow(EXPECTED_PADDING)), "Clipped sole bounds exclude a fully transparent component")
	# Owner-local obstacle arrays must never leak into another chip's HUD input.
	owner = shape([right_sole])
	owner["weight"] = 0.0
	var obstacles: Array[Rect2]
	var shapes: Array[Dictionary]
	shapes.append(owner)
	var before_obstacles: PackedByteArray = var_to_bytes(obstacles)
	var before_shapes: PackedByteArray = var_to_bytes(shapes)
	Badges.place_chip(ANCHOR, BADGE, font, obstacles, [], Rect2(), shapes)
	expect.call(var_to_bytes(obstacles) == before_obstacles and var_to_bytes(shapes) == before_shapes, "Owner-only obstacle never mutates shared obstacles or silhouettes")
	var other_badge: Dictionary = BADGE.duplicate()
	other_badge["key"] = "other_owner"
	placed = Badges.place_chip(ANCHOR, other_badge, font, obstacles, [], Rect2(), shapes)
	expect.call(placed["rect"] == right, "Another owner's chip does not inherit this sole obstacle")
	# A torso above the sole slice contributes no obstacle or scoring weight.
	owner = shape([Rect2(right.position.x, OWNER_BOUNDS.position.y, right.size.x, TORSO_HEIGHT)])
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), [owner])
	var original: Dictionary = Badges.place_chip(ANCHOR, BADGE, font, [], [])
	expect.call(var_to_bytes(placed) == var_to_bytes(original), "Home not touching sole band stays byte-identical")
	expect.call(not Solver.owner_sole_obstacle([owner], "owner").has_area(), "An empty clipped sole shape produces no padded phantom obstacle")
	# There is no local escape when bounds hold y fixed and the broad sole
	# exceeds both 24px search regions. The original preferred home wins.
	owner = shape([OWNER_BOUNDS])
	var bounds := Rect2(left.position, Vector2(right.end.x - left.position.x, right.size.y))
	var right_blocker := Rect2(right.position.x, SOLE_TOP, EXHAUSTED_FOOT_WIDTH, SOLE_HEIGHT)
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], bounds, [shape([right_blocker])])
	expect.call(placed["rect"] == left and not placed["above_everything"], "Exhausted preferred search next tries the other side's home")
	expected = left
	expected.position.x -= EXPECTED_SHIFT
	# Give the left search its full horizontal room while retaining fixed y.
	bounds.position.x -= EXPECTED_SHIFT
	bounds.size.x += EXPECTED_SHIFT
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], bounds, [shape([right_blocker, left_sole])])
	expect.call((placed["rect"] as Rect2).is_equal_approx(expected) and not placed["above_everything"], "Exhausted preferred search and blocked other home next search the other side")
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], bounds, [owner])
	expect.call(placed["rect"] == right and placed["above_everything"], "Exhausted sole obstacle keeps the existing preferred-home fallback")
	expect.call(not Solver.owner_sole_obstacle([owner], "missing").has_area() and not Solver.owner_sole_obstacle([owner], "").has_area(), "Missing owner has no sole obstacle")
	_rest_source_views(expect)
	CacheSuite.run(expect)

static func _rest_source_views(expect: Callable) -> void:
	# Use the existing export-aware fixture with an approved, deliberately
	# different still, so this kills reverting the front to _unit_textures.
	var board: Control = Sources._board()
	var renderer := Sources.RearRenderer.new()
	var source := Sources.RestSource.new()
	source.layout["rest_source"] = "res://assets/units/crawler_cutout/rear/rest.png"
	renderer.add_child(source)
	board.add_child(renderer)
	board.source_key = "enemy_1"
	board.source_renderer = renderer
	var unit: Dictionary = board._units_by_key(board._visible_units())["enemy_1"]
	var original: Texture2D = board._unit_textures["crawler"]
	for facing: String in ["front", "rear"]:
		for mirrored: bool in [false, true]:
			renderer.facing = facing
			renderer.mirrored = mirrored
			renderer.rigs = {facing: source}
			board._unit_textures["crawler"] = original
			var actual: Dictionary = Solver.unit_rest_silhouette(board, unit)
			renderer.rigs = {}
			board._unit_textures["crawler"] = Solver.Assets.load_texture_source_first(source.layout["rest_source"])
			expect.call(actual == Solver.unit_rest_silhouette(board, unit), "Rig rest_source overrides catalog texture in " + facing + " mirrored=" + str(mirrored))
	board.free()
