extends RefCounted
## Synthetic geometry is proof-only. All thresholds/weights are asserted
## independently from production constants so the required mutations are killed.
const Badges = preload("res://scripts/intent_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")
const Cases = preload("res://tests/fixtures/intent_chip_cases.gd")
const Sources = preload("res://tests/pt14_01_source_suite.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const ANCHOR := Vector2(500, 500)
const BADGE: Dictionary = {"key": "enemy_1", "number": ""}
const ANIMATION_TIMES: Array = [0.0, 0.53]
const BOB_DISTANCE: float = 120.0
const TEST_CHIP_SIZE := Vector2(32, 32)
const ANIMATED_BODY_SIZE := Vector2(100, 32)
const NEAR_TIE_SIZE := Vector2(28, 32)
const EXACT_MARGIN_SIZE := Vector2(27.2, 32)
const SLIDE_TEST_OFFSET := Vector2(0, 8)
const STRIPE_PADDING: float = 10.0
const EMPTY_FLOOR_HERO_OFFSET := Vector2(80, 32)

class AnimatedBoard extends Board:
	# Model both an idle frame and a moving body/bob without moving its rest
	# floor anchor. Any use of animated draw bounds must change side here.
	func _unit_draw_rect(unit: Dictionary) -> Rect2:
		if unit.get("key") == "player":
			var enemy: Dictionary = _units_by_key(_visible_units())["enemy_1"]
			var home: Vector2 = _unit_center(enemy) + Badges.FEET_OFFSET
			return Rect2(home - TEST_CHIP_SIZE * 0.5 + Vector2(-BOB_DISTANCE if _idle_elapsed > 0.0 else 0.0, 0), ANIMATED_BODY_SIZE)
		return super._unit_draw_rect(unit)

static func run(expect: Callable) -> void:
	var font: Font = Badges.Typography.ui_font()
	var right: Rect2 = Badges.chip_rect(ANCHOR + Badges.FEET_OFFSET, BADGE, font)
	var center: Vector2 = ANCHOR + Badges.FEET_OFFSET
	var left_center := Vector2(ANCHOR.x - Badges.FEET_OFFSET.x - (right.end.x - center.x), center.y)
	var left: Rect2 = Badges.chip_rect(left_center, BADGE, font)
	var board := AnimatedBoard.new()
	board.size = Cases.SIZE
	var state: Dictionary = Cases.owner_state()
	var rest: Dictionary = Badges.build(Cases.Combat.new(), state, state)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"threats_at_rest": rest})
	var units: Dictionary = board._units_by_key(board._visible_units())
	var hero: Dictionary = Solver.unit_rest_silhouette(board, units["player"])
	var enemy: Dictionary = Solver.unit_rest_silhouette(board, units["enemy_1"])
	expect.call(hero.get("weight") == 2.0 and enemy.get("weight") == 1.0 and Solver.PROP_WEIGHT == 0.5, "Rest silhouette roles have exact hero/unit/prop weights")
	var shapes: Array[Dictionary]
	shapes.append({"key": "player", "rect": right, "weight": hero.get("weight", 0.0)})
	shapes.append({"key": "enemy_2", "rect": left, "weight": enemy.get("weight", 0.0)})
	var placed: Dictionary = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), shapes)
	expect.call(placed["center"] == left_center, "Hero-weight mutation: equal hero/enemy area avoids the hero")
	shapes.assign([{"key": "enemy_2", "rect": left, "weight": 1.0}])
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), shapes)
	expect.call(placed["center"] == center, "Mirror-covered case keeps clear lower right")
	shapes.assign([{"key": "enemy_2", "rect": right, "weight": 1.0}, {"key": "enemy_3", "rect": Rect2(left.position, NEAR_TIE_SIZE), "weight": 1.0}])
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), shapes)
	expect.call(placed["center"] == center, "No-margin mutation: a 12.5 percent coverage advantage keeps home")
	# Exactly 15% is still home. Rect-only coverage is exact, not sampled.
	shapes[1]["rect"] = Rect2(left.position, EXACT_MARGIN_SIZE)
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], Rect2(), shapes)
	expect.call(placed["center"] == center, "Exactly 15 percent is not enough to switch sides")
	shapes.assign([{"key": "player", "rect": right, "weight": 2.0}])
	placed = Badges.place_chip(ANCHOR, BADGE, font, [left], [], Rect2(), shapes)
	expect.call(placed["center"] == center and not placed["above_everything"], "Less-covered side blocked by HUD takes the HUD-clear home")
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [{"rect": left}], Rect2(), shapes)
	expect.call(placed["center"] == center, "Earlier chips are hard HUD, not coverage")
	placed = Badges.place_chip(ANCHOR, BADGE, font, [], [], right, shapes)
	expect.call(placed["center"] == center, "Less-covered mirror outside viewport takes home")
	var stripe := Rect2(left.position.x - STRIPE_PADDING, right.end.y - SLIDE_TEST_OFFSET.y, right.end.x - left.position.x + 2.0 * STRIPE_PADDING, SLIDE_TEST_OFFSET.y)
	placed = Badges.place_chip(ANCHOR, BADGE, font, [stripe], [], Rect2(), shapes)
	expect.call(placed["center"] == left_center - SLIDE_TEST_OFFSET and not placed["above_everything"], "Equal-distance bounded slides prefer coverage-chosen mirror")
	placed = Badges.place_chip(ANCHOR, BADGE, font, [right.grow(24), left.grow(24)], [], Rect2(), shapes)
	expect.call(placed["center"] == left_center and placed["above_everything"], "Exhausted bounded search falls back at chosen mirror")
	shapes.assign([{"key": "enemy_1", "rect": right, "weight": 2.0}])
	expect.call(Solver.coverage(right, shapes, "enemy_1") == 0.0, "Owner silhouette never contributes coverage")
	# Polygon has a transparent half inside its tight bounds. Bounding boxes
	# must not replace the preferred existing opaque rest polygons.
	shapes.assign([{"rect": right, "weight": 0.5, "polygons": [PackedVector2Array([right.position, right.end, Vector2(right.position.x, right.end.y)])]}])
	expect.call(is_equal_approx(Solver.coverage(right, shapes), right.get_area() * 0.25), "Polygon coverage counts opaque triangle area with prop weight")
	var presentation: Dictionary = board.presentation.duplicate(true)
	presentation.merge(Cases.owner_presentation(board), true)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	animation_check(board, rest["badges"], "synthetic_mid_bob", expect)
	# Keep the inherited pt13 fixture intact. This additional empty-floor case
	# independently proves complete hero clearance, which its broad sword-inclusive
	# rest silhouette cannot achieve at either fixed home in the inherited case.
	presentation["unit_world_positions"]["player"] = board._unit_center(units["enemy_1"]) + EMPTY_FLOOR_HERO_OFFSET
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	var layouts: Array[Dictionary] = Badges.layouts(board, rest["badges"])
	var badge: Dictionary = layouts[0]
	var owner_center: Vector2 = board._unit_center(units["enemy_1"])
	var home: Rect2 = Badges.chip_rect(owner_center + Badges.FEET_OFFSET, badge, font)
	var hero_shapes: Array[Dictionary]
	hero_shapes.append(Solver.unit_rest_silhouette(board, units["player"]))
	expect.call(Solver.coverage(home, hero_shapes) > home.get_area() * 0.15, "Empty-floor owner case reproduces hero-covered home")
	var sole: Rect2 = Solver.owner_sole_obstacle(Solver.rest_silhouettes(board, board._visible_units()), badge["key"])
	var left_home: Rect2 = Badges.chip_rect(Vector2(owner_center.x - Badges.FEET_OFFSET.x - (home.end.x - owner_center.x - Badges.FEET_OFFSET.x), owner_center.y + Badges.FEET_OFFSET.y), badge, font)
	expect.call(left_home.intersects(sole, false) and not home.intersects(sole, false), "Empty-floor fixture has a sole-blocked left home and a clear right home")
	var preferred_distance: float = (badge["rect"] as Rect2).position.distance_to(left_home.position)
	expect.call(preferred_distance > 0.0 and preferred_distance <= 24.0 and not (badge["rect"] as Rect2).intersects(sole, false) and not badge["above_everything"], "Empty-floor owner case slides within 24px on the preferred left side before trying the right home")
	board.free()

static func animation_check(board: Control, badges: Array, label: String, expect: Callable) -> void:
	var saved: float = board._idle_elapsed
	var renderers: Dictionary = {}
	for unit: Dictionary in board._visible_units():
		var renderer: Node = board.unit_cutout_renderer(unit)
		if is_instance_valid(renderer):
			renderers[renderer] = {"phase": renderer.get("phase"), "idle": renderer.get("_idle_seconds")}
			renderer.set("phase", ANIMATION_TIMES[0])
			renderer.set("_idle_seconds", ANIMATION_TIMES[0])
	board._idle_elapsed = ANIMATION_TIMES[0]
	var first: Array[Dictionary] = Badges.layouts(board, badges)
	board._idle_elapsed = ANIMATION_TIMES[1]
	for renderer: Node in renderers:
		renderer.set("phase", ANIMATION_TIMES[1])
		renderer.set("_idle_seconds", ANIMATION_TIMES[1])
	var second: Array[Dictionary] = Badges.layouts(board, badges)
	expect.call(first == second, "Animated-bounds mutation: " + label + " identical chip rects across idle phases and mid-bob")
	board._idle_elapsed = saved
	for renderer: Node in renderers:
		renderer.set("phase", renderers[renderer]["phase"])
		renderer.set("_idle_seconds", renderers[renderer]["idle"])
