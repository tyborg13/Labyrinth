extends RefCounted

## Preserve rr-52's approved held-item contracts at the Lamplighter adapter boundary.
## Sampling, gait, root travel and ordinary presentation stay shared.
const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const Grip = preload("res://scripts/maquette_cutout_runtime/humanoid_grip.gd")
const Drop = preload("held_drop.gd")

static func world_transforms(data: Dictionary, clip: String, phase: float, layout: Dictionary, facing: String, released: bool = true, follow_held: bool = true) -> Dictionary:
	var world: Dictionary = Humanoid.world_transforms(data, clip, phase, layout, facing, released, follow_held)
	var attachment: Dictionary = layout["held_items"]["lantern"]
	var release: float = float(data.get("view_release_at", {}).get(facing, {}).get(clip, data["clips"][clip].get("release_at", {})).get("lantern", INF))
	if phase >= release: return world
	var follow: Dictionary = data["clips"][clip].get("held_follow", {})
	if not follow_held or follow.get("item", "") != "lantern": return world
	var pose: Transform2D = world["lantern"]
	var angle: float = pose.get_rotation()
	if attachment.get("follow_zero_at_end", false) and phase >= 1.0: angle = 0.0
	if attachment.has("follow_limit_deg"):
		var limit: float = deg_to_rad(float(attachment["follow_limit_deg"]))
		angle = clampf(angle, -limit, limit)
	var hand: String = str(attachment["hand"])
	var grip: Vector2 = Motion.point(attachment["source_grip"])
	var contact: Vector2 = (world[hand] as Transform2D) * (grip - Motion.point(layout["joints"][hand]["position"]))
	world["lantern"] = Transform2D(angle, contact - (grip - Motion.point(layout["joints"]["lantern"]["position"])).rotated(angle))
	return world

static func authored(rig: Node2D, clip: String, phase: float) -> void:
	rig.layout.erase("_locked_grips")
	rig.layout.erase("_painted_floor_pose")
	var data: Dictionary = Motion.data_for(rig.layout)
	if not data["clips"].has(clip): return
	var world: Dictionary = world_transforms(data, clip, phase, rig.layout, rig.facing)
	var hand: String = str(rig.layout["held_items"]["lantern"]["hand"])
	(rig.bones["lantern"] as Bone2D).transform = (world[hand] as Transform2D).affine_inverse() * (world["lantern"] as Transform2D)
	var release: float = float(data.get("view_release_at", {}).get(rig.facing, {}).get(clip, data["clips"][clip].get("release_at", {})).get("lantern", INF))
	if phase < release:
		rig.layout["_locked_grips"] = {"lantern": true}
	else:
		var drop: Dictionary = data["view_held_drops"][rig.facing][clip]["lantern"]
		rig.layout["_painted_floor_pose"] = {"landed": phase >= float(drop["land"]), "transform": world["lantern"]}

static func presented(rig: Node2D, clip: String) -> void:
	var source: Transform2D = rig.global_transform.affine_inverse()
	var world: Dictionary = {}
	for name: String in rig.bones: world[name] = source * (rig.bones[name] as Bone2D).global_transform
	Grip.solve(world, rig.layout)
	var landed: bool = Drop.presented(world, rig.layout, clip, "lantern")
	var hand: String = str(rig.layout["held_items"]["lantern"]["hand"])
	var pose: Transform2D = world["lantern"]
	(rig.bones["lantern"] as Bone2D).transform = (world[hand] as Transform2D).affine_inverse() * pose
	var locked: bool = rig.layout.get("_locked_grips", {}).has("lantern")
	var travel: Vector2 = Pixels.movement_offset(rig.layout, clip)
	for part: Dictionary in rig.layout["parts"]:
		if part["bone"] != "lantern": continue
		var reference: Vector2 = Motion.point(part.get("presentation_anchor", part["offset"]))
		var anchor: Transform2D = pose * Transform2D(0.0, reference - Motion.point(rig.layout["joints"]["lantern"]["position"]))
		# Read the already presented fist. Re-snapping a reconstructed Bone2D
		# contact can cross a half-pixel tie after global/local float roundoff
		# (rear Snuff with the corrected projection), separating the ring by 1 px.
		if locked: anchor = Transform2D(pose.get_rotation(), _presented_grip(rig, source, hand))
		elif not landed: anchor = Pixels.snapped_transform(anchor, NAN, travel)
		var final: Transform2D = anchor * Transform2D(0.0, Motion.point(part["offset"]) - reference)
		(rig.bones["lantern"].get_node(NodePath(part["name"])) as Sprite2D).transform = pose.affine_inverse() * final

static func _presented_grip(rig: Node2D, source: Transform2D, hand: String) -> Vector2:
	var grip: Vector2 = Motion.point(rig.layout["held_items"]["lantern"]["source_grip"])
	var sprite: Sprite2D = rig.bones[hand].get_node(NodePath(hand)) as Sprite2D
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] == hand:
			return (source * sprite.global_transform) * (grip - Motion.point(part["offset"]))
	assert(false, "Lamplighter held hand must have its presented paint part")
	return Vector2.ZERO
