extends RefCounted

## Hidden caps that share rigid source paint must use the source sprite's
## complete presented transform, including its final pixel-anchor correction.
static func ensure_bones(rig: Node2D, data: Dictionary) -> void:
	var replaced: Dictionary = {}
	for mesh: Dictionary in rig.layout.get("joint_meshes", []): replaced[mesh["replaces_part"]] = true
	for bone_name: String in data["weights"]:
		if replaced.has(bone_name): continue
		var source: Dictionary = {}
		for part: Dictionary in rig.layout["parts"]:
			if part["name"] == bone_name and part["bone"] == bone_name: source = part
		if source.is_empty(): continue
		var helper_name: String = "_paint_cap_" + bone_name
		if not rig.cap_bones.has(bone_name):
			var bone := Bone2D.new()
			bone.name = helper_name
			bone.set_autocalculate_length_and_angle(false)
			bone.position = preload("motion.gd").point(rig.layout["joints"][bone_name]["position"])
			bone.rest = bone.transform
			rig.skeleton.add_child(bone)
			bone.owner = rig
			rig.cap_bones[bone_name] = bone


static func apply(rig: Node2D, finals: Dictionary = {}, clip: String = "", phase_value: float = 0.0) -> void:
	for bone_name: String in rig.cap_bones:
		var source_name: String = bone_name
		var attachment: Dictionary = rig.layout.get("held_items", {}).get(bone_name, {})
		if attachment.has("cap_release_parent") and phase_value >= float(attachment.get("presentation_release_at", {}).get(clip, INF)):
			source_name = str(attachment["cap_release_parent"])
		var pose: Transform2D = rig.global_transform.affine_inverse() * (rig.bones[bone_name] as Bone2D).global_transform
		if finals.has(source_name):
			var part: Dictionary = {}
			for row: Dictionary in rig.layout["parts"]:
				if row["name"] == source_name: part = row
			var bind: Vector2 = preload("motion.gd").point(rig.layout["joints"][bone_name]["position"])
			pose = (finals[source_name] as Transform2D) * Transform2D(0.0, bind - preload("motion.gd").point(part["offset"]))
		else:
			for part: Dictionary in rig.layout["parts"]:
				if part["name"] != source_name: continue
				var sprite: Node2D = rig.bones[part["bone"]].get_node(NodePath(source_name)) as Node2D
				var bind: Vector2 = preload("motion.gd").point(rig.layout["joints"][bone_name]["position"])
				pose = rig.global_transform.affine_inverse() * sprite.global_transform * Transform2D(0.0, bind - preload("motion.gd").point(part["offset"]))
		(rig.cap_bones[bone_name] as Bone2D).global_transform = rig.global_transform * pose


static func apply_references(rig: Node2D, world: Dictionary, finals: Dictionary) -> void:
	if not rig.layout.get("painted_reference_space", false): return
	for part: Dictionary in rig.layout["parts"]:
		if not part.has("reference_source_part"): continue
		var owner_name: String = str(part["reference_source_part"])
		var source_offset: Vector2 = preload("motion.gd").point(part["reference_source_offset"])
		var final: Transform2D = (finals[owner_name] as Transform2D) * Transform2D(0.0, -source_offset)
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(part["name"]))
		sprite.transform = (world[part["bone"]] as Transform2D).affine_inverse() * final
