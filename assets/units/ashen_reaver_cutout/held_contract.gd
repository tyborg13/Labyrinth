extends RefCounted

## Preserve rr-48's approved held-item contracts at the Reaver adapter boundary.
## Sampling, gait, root travel and ordinary presentation stay shared.
const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const Grip = preload("res://scripts/maquette_cutout_runtime/humanoid_grip.gd")
const Drop = preload("held_drop.gd")
const Paint = preload("weapon_paint.gd")

static func world_transforms(data: Dictionary, clip: String, phase: float, layout: Dictionary, facing: String, released: bool = true, follow_held: bool = true) -> Dictionary:
	var world: Dictionary = Humanoid.world_transforms(data, clip, phase, layout, facing, released, follow_held)
	var attachment: Dictionary = layout["held_items"]["falchion"]
	var release: float = float(data.get("view_release_at", {}).get(facing, {}).get(clip, data["clips"][clip].get("release_at", {})).get("falchion", INF))
	if phase >= release: return world
	var follow: Dictionary = data["clips"][clip].get("held_follow", {})
	if not follow_held or follow.get("item", "") != "falchion": return world
	var pose: Transform2D = world["falchion"]
	var angle: float = pose.get_rotation()
	if attachment.get("follow_zero_at_end", false) and phase >= 1.0: angle = 0.0
	if attachment.has("follow_limit_deg"):
		var limit: float = deg_to_rad(float(attachment["follow_limit_deg"]))
		angle = clampf(angle, -limit, limit)
	var hand: String = str(attachment["hand"])
	var grip: Vector2 = Motion.point(attachment["source_grip"])
	var contact: Vector2 = (world[hand] as Transform2D) * (grip - Motion.point(layout["joints"][hand]["position"]))
	world["falchion"] = Transform2D(angle, contact - (grip - Motion.point(layout["joints"]["falchion"]["position"])).rotated(angle))
	return world

static func authored(rig: Node2D, clip: String, phase: float) -> void:
	Paint.apply(rig, clip, phase, true)
	rig.layout.erase("_locked_grips")
	rig.layout.erase("_painted_floor_pose")
	var data: Dictionary = Motion.data_for(rig.layout)
	if not data["clips"].has(clip): return
	var world: Dictionary = world_transforms(data, clip, phase, rig.layout, rig.facing)
	var hand: String = str(rig.layout["held_items"]["falchion"]["hand"])
	(rig.bones["falchion"] as Bone2D).transform = (world[hand] as Transform2D).affine_inverse() * (world["falchion"] as Transform2D)
	var release: float = float(data.get("view_release_at", {}).get(rig.facing, {}).get(clip, data["clips"][clip].get("release_at", {})).get("falchion", INF))
	if phase < release:
		rig.layout["_locked_grips"] = {"falchion": true}
	else:
		var drop: Dictionary = data["view_held_drops"][rig.facing][clip]["falchion"]
		rig.layout["_painted_floor_pose"] = {"landed": phase >= float(drop["land"]), "transform": world["falchion"]}

static func presented(rig: Node2D, clip: String, phase: float) -> void:
	Paint.apply(rig, clip, phase)
	var source: Transform2D = rig.global_transform.affine_inverse()
	var world: Dictionary = {}
	for name: String in rig.bones: world[name] = source * (rig.bones[name] as Bone2D).global_transform
	Grip.solve(world, rig.layout)
	var landed: bool = Drop.presented(world, rig.layout, clip, "falchion")
	var hand: String = str(rig.layout["held_items"]["falchion"]["hand"])
	var pose: Transform2D = world["falchion"]
	(rig.bones["falchion"] as Bone2D).transform = (world[hand] as Transform2D).affine_inverse() * pose
	var locked: bool = rig.layout.get("_locked_grips", {}).has("falchion")
	var travel: Vector2 = Pixels.movement_offset(rig.layout, clip)
	for part: Dictionary in rig.layout["parts"]:
		if part["bone"] != "falchion": continue
		var active: Dictionary = Paint.part_at(part, clip, phase)
		var reference: Vector2 = Motion.point(part.get("presentation_anchor", part["offset"]))
		var anchor: Transform2D = pose * Transform2D(0.0, reference - Motion.point(rig.layout["joints"]["falchion"]["position"]))
		if locked: anchor = Grip.sprite_anchor(world, rig.layout, "falchion")
		elif not landed: anchor = Pixels.snapped_transform(anchor, NAN, travel)
		var final: Transform2D = anchor * Transform2D(0.0, Motion.point(active["offset"]) - reference)
		(rig.bones["falchion"].get_node(NodePath(part["name"])) as Sprite2D).transform = pose.affine_inverse() * final
