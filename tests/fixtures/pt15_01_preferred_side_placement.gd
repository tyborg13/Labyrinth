extends RefCounted
## Reference order for feedback 2. Callers supply the owner-local sole obstacle.
const Badges = preload("res://scripts/intent_badges.gd")
const Solver = preload("res://scripts/intent_chip_placement.gd")

static func place(anchor: Vector2, badge: Dictionary, font: Font, obstacles: Array, previous: Array, bounds: Rect2, silhouettes: Array) -> Dictionary:
	var center: Vector2 = anchor + Badges.FEET_OFFSET
	var right: Rect2 = Badges.chip_rect(center, badge, font)
	var left_center := Vector2(anchor.x - Badges.FEET_OFFSET.x - (right.end.x - center.x), center.y)
	var left: Rect2 = Badges.chip_rect(left_center, badge, font)
	var owner: String = str(badge.get("key", ""))
	var prefer_left: bool = Solver.coverage(right, silhouettes, owner) - Solver.coverage(left, silhouettes, owner) > right.get_area() * Solver.SIDE_MARGIN
	for on_left: bool in [prefer_left, not prefer_left]:
		var home: Rect2 = left if on_left else right
		var occupied: Array = obstacles.duplicate()
		for chip: Dictionary in previous: occupied.append(chip["rect"])
		var home_clear: bool = not bounds.has_area() or bounds.encloses(home)
		for obstacle: Rect2 in occupied:
			if home.intersects(obstacle, false): home_clear = false
		if home_clear:
			return {"center": left_center if on_left else center, "rect": home, "placement": "lower_left" if on_left else "lower_right", "above_everything": false}
		var clear: Dictionary = Solver.find_clear(right, left, obstacles, previous, bounds, on_left, true)
		if not clear.is_empty():
			return {"center": center + (clear["rect"] as Rect2).position - right.position, "rect": clear["rect"], "placement": clear["placement"], "above_everything": false}
	return {"center": left_center if prefer_left else center, "rect": left if prefer_left else right, "placement": "lower_left" if prefer_left else "lower_right", "above_everything": true}
