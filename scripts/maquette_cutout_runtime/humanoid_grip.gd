extends RefCounted

## Optional grip constraint after independent bone/angle presentation.
const Motion = preload("motion.gd")
const Pixels = preload("pixel_presentation.gd")

static func solve(world: Dictionary, layout: Dictionary) -> void:
	for item: String in layout.get("_locked_grips", {}):
		var attachment: Dictionary = layout["held_items"][item]
		var hand: String = str(attachment["hand"])
		var grip: Vector2 = Motion.point(attachment["source_grip"])
		var angle: float = (world[item] as Transform2D).get_rotation()
		var contact: Vector2 = (world[hand] as Transform2D) * (grip - Motion.point(layout["joints"][hand]["position"]))
		world[item] = Transform2D(angle, contact - (grip - Motion.point(layout["joints"][item]["position"])).rotated(angle))

static func sprite_anchor(world: Dictionary, layout: Dictionary, item: String) -> Transform2D:
	var attachment: Dictionary = layout["held_items"][item]
	var hand: String = str(attachment["hand"])
	var grip: Vector2 = Motion.point(attachment["source_grip"])
	var anchor: Transform2D = Pixels.snapped_transform((world[hand] as Transform2D) * Transform2D(0.0, grip - Motion.point(layout["joints"][hand]["position"])))
	return Transform2D((world[item] as Transform2D).get_rotation(), anchor.origin)
