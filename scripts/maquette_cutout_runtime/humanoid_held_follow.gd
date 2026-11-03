extends RefCounted

## A held item shares the presented hand's grip, rather than independently
## snapping its crop origin. The opt-in ends exactly at the authored release.
static func present_grips(rig: Node2D, world: Dictionary, finals: Dictionary, clip: String, phase_value: float) -> void:
	var data: Dictionary = preload("motion.gd").data_for(rig.layout)
	var release: Dictionary = data.get("view_release_at", {}).get(rig.facing, {}).get(clip, data.get("clips", {}).get(clip, {}).get("release_at", {}))
	for item: String in rig.layout.get("held_items", {}):
		var attachment: Dictionary = rig.layout["held_items"][item]
		if not attachment.has("presentation_grip_part"): continue
		if phase_value >= float(release.get(item, INF)): continue
		var hand_name: String = str(attachment["presentation_grip_part"])
		var grip: Vector2 = preload("motion.gd").point(attachment["source_grip"])
		var item_part: Dictionary = {}
		var hand_part: Dictionary = {}
		for part: Dictionary in rig.layout["parts"]:
			if part["name"] == item: item_part = part
			if part["name"] == hand_name: hand_part = part
		var hand: Transform2D = finals[hand_name]
		var final: Transform2D = finals[item]
		var target: Vector2 = hand * (grip - preload("motion.gd").point(hand_part["offset"]))
		final.origin = target - final.basis_xform(grip - preload("motion.gd").point(item_part["offset"]))
		var bone: Bone2D = rig.bones[item_part["bone"]]
		var sprite: Sprite2D = bone.get_node(NodePath(item))
		sprite.transform = (world[item_part["bone"]] as Transform2D).affine_inverse() * final
		finals[item] = final

## Presented sprite offsets must not leak into the next raw diagnostic pose.
## This is opt-in with the generated channel; unrelated rigs keep their path.
static func reset_authored_sprites(rig: Node2D, data: Dictionary) -> void:
	var items: Dictionary = {}
	for definition: Dictionary in data.get("clips", {}).values():
		if definition.has("held_follow"): items[str(definition["held_follow"]["item"])] = true
	for part: Dictionary in rig.layout["parts"]:
		if not items.has(str(part["bone"])): continue
		var node: Node = rig.bones[part["bone"]].get_node_or_null(NodePath(part["name"]))
		if node is Sprite2D:
			var point: Vector2 = preload("motion.gd").point(part["offset"])
			var bind: Vector2 = preload("motion.gd").point(rig.layout["joints"][part["bone"]]["position"])
			(node as Sprite2D).transform = Transform2D(0.0, point - bind)

## Optional body frame: exclude body travel/lean from the painted grip swing.
static func body_displacement(world: Dictionary, joints: Dictionary, attachment: Dictionary, hand: String, forward: Vector2) -> float:
	var point: Vector2 = preload("motion.gd").point(joints[hand]["position"] if attachment.get("follow_hand_joint", false) else attachment.get("source_grip", joints[hand]["position"]))
	var hand_bind: Vector2 = preload("motion.gd").point(joints[hand]["position"])
	var reference: String = str(attachment.get("follow_reference_bone", "torso"))
	var torso_bind: Vector2 = preload("motion.gd").point(joints[reference]["position"])
	var grip: Vector2 = (world[hand] as Transform2D) * (point - hand_bind)
	var local: Vector2 = (world[reference] as Transform2D).affine_inverse() * grip
	return (local - (point - torso_bind)).dot(forward)
