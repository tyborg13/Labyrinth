extends Node2D

## Runtime version of the accepted pass-seven cutout. One instance per painted facing.
const RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
const Motion = preload("res://scripts/protagonist_cutout/motion.gd")
const BASE: String = "res://assets/units/protagonist_cutout"
const CANVAS_SIZE := Vector2i(512, 512)
const SOURCE_OFFSET := Vector2(128, 128)
const SOURCE_SIZE := Vector2(255, 255)

var facing: String = "front"
var layout: Dictionary = {}
var _source_data: RigData.Data
var bones: Dictionary = {}
var rest_transforms: Dictionary = {}
var load_errors: PackedStringArray = []
var skeleton: Skeleton2D
var _loaded_facing: String = ""
var _gear_base_parts: Dictionary = {}
var _gear_attachments: Array[Sprite2D] = []
var _gear_clip: String = "idle"

func _layout_path(which: String) -> String:
	return BASE.path_join(which + ".json")

func has_facing(which: String) -> bool:
	return which in ["front", "rear"] and FileAccess.file_exists(_layout_path(which))

func _resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return BASE.path_join(path)

func _vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2(float(value[0]), float(value[1]))

func _texture(path: String) -> Texture2D:
	var texture: Texture2D = preload("res://scripts/asset_loader.gd").load_texture_source_first(_resolve(path))
	if texture == null:
		load_errors.append("Missing cutout image: " + path)
	return texture

func load_rig() -> bool:
	if _loaded_facing == facing:
		return true
	load_errors.clear()
	if not has_facing(facing):
		load_errors.append("No actual cutout layout for facing: " + facing)
		return false
	var prepared: RigData.Data = RigData.load_source(_layout_path(facing))
	if not prepared.error.is_empty():
		load_errors.append(prepared.error)
		return false
	for child: Node in get_children():
		remove_child(child)
		child.free()
	bones.clear()
	rest_transforms.clear()
	_gear_base_parts.clear()
	_gear_attachments.clear()
	_source_data = prepared
	layout = prepared.layout
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	skeleton.owner = self
	var joints: Dictionary = layout.get("joints", {})
	var remaining: Array = joints.keys()
	while not remaining.is_empty():
		var progressed: bool = false
		for raw_name: Variant in remaining.duplicate():
			var bone_name: String = str(raw_name)
			var definition: Dictionary = joints[bone_name]
			var parent_value: Variant = definition.get("parent")
			var parent_name: String = "" if parent_value == null else str(parent_value)
			if not parent_name.is_empty() and not bones.has(parent_name):
				continue
			var bone := Bone2D.new()
			bone.name = bone_name
			bone.set_autocalculate_length_and_angle(false)
			bone.set_length(12.0)
			var parent_node: Node = skeleton if parent_name.is_empty() else bones[parent_name] as Node
			var origin: Vector2 = _vector(definition["position"])
			var parent_origin: Vector2 = Vector2.ZERO if parent_name.is_empty() else _vector((joints[parent_name] as Dictionary)["position"])
			bone.position = origin - parent_origin
			bone.rest = bone.transform
			parent_node.add_child(bone)
			bone.owner = self
			bones[bone_name] = bone
			rest_transforms[bone_name] = bone.transform
			remaining.erase(raw_name)
			progressed = true
		if not progressed:
			load_errors.append("Cyclic or missing bone parents: " + str(remaining))
			return false
	var use_cape_mesh: bool = layout.get("cape_mesh", {}) is Dictionary and not (layout.get("cape_mesh", {}) as Dictionary).is_empty()
	var joint_meshes: Array = layout.get("joint_meshes", [])
	var replaced_parts: Dictionary = {}
	for mesh: Dictionary in joint_meshes:
		replaced_parts[str(mesh.get("replaces_part", ""))] = true
	for raw_part: Variant in layout.get("parts", []):
		var part: Dictionary = raw_part
		if use_cape_mesh and bool(part.get("cape_segment", false)):
			continue
		if replaced_parts.has(str(part.get("name", ""))):
			continue
		var bone_name: String = str(part.get("bone", ""))
		if not bones.has(bone_name):
			load_errors.append("Unknown part bone: " + bone_name)
			continue
		var sprite := Sprite2D.new()
		sprite.name = str(part.get("name", "Part"))
		sprite.set_meta("equipment_slot", str(part.get("equipment_slot", "")))
		sprite.texture = _texture(str(part["file"]))
		sprite.centered = false
		sprite.position = _vector(part["offset"]) - _vector((joints[bone_name] as Dictionary)["position"])
		sprite.z_index = int(part.get("z_index", 0))
		sprite.z_as_relative = false
		(bones[bone_name] as Bone2D).add_child(sprite)
		sprite.owner = self
		_remember_gear_part(str(part.get("name", "")), sprite)
	if use_cape_mesh:
		_build_mesh(layout["cape_mesh"] as Dictionary, "PaintedCape", "cape")
	for mesh_index: int in range(joint_meshes.size()):
		var mesh: Dictionary = joint_meshes[mesh_index]
		_build_mesh(mesh, str(mesh.get("name", "PaintedJoint")), "joint:%d" % mesh_index)
	if not load_errors.is_empty():
		return false
	_loaded_facing = facing
	apply_pose("idle", 0.0)
	return true

func _build_mesh(data: Dictionary, mesh_name: String, source_key: String) -> void:
	# Meshes share the skeleton's source-pixel coordinate space. Parenting them
	# to a Bone2D would apply that moving transform a second time.
	var mesh := Polygon2D.new()
	mesh.name = mesh_name
	mesh.set_meta("equipment_slot", str(data.get("equipment_slot", "")))
	mesh.texture = _texture(str(data["file"]))
	mesh.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var prepared: Dictionary = _source_data.prepare_mesh(data, mesh_name, source_key)
	if prepared.has("error"):
		load_errors.append(str(prepared["error"]))
		mesh.free()
		return
	mesh.polygon = prepared["vertices"]
	mesh.uv = prepared["uvs"]
	mesh.polygons = prepared["triangles"]
	mesh.z_index = int(data.get("z_index", 3))
	mesh.z_as_relative = false
	add_child(mesh)
	mesh.owner = self
	mesh.skeleton = mesh.get_path_to(skeleton)
	for bone_name: String in prepared["weights"]:
		mesh.add_bone(skeleton.get_path_to(bones[bone_name]), prepared["weights"][bone_name])
	mesh.queue_redraw()
	_remember_gear_part(str(data.get("replaces_part", "")), mesh)

func _remember_gear_part(part_name: String, node: Node2D) -> void:
	if not part_name.is_empty():
		_gear_base_parts[part_name] = {"node": node, "texture": node.get("texture"), "position": node.position}

func apply_gear(ops: Dictionary) -> void:
	for base: Dictionary in _gear_base_parts.values():
		var node: Node2D = base["node"]
		node.set("texture", base["texture"])
		node.position = base["position"]
	for attachment: Sprite2D in _gear_attachments:
		attachment.free()
	_gear_attachments.clear()
	for op: Dictionary in ops.get("replace", []):
		var part: String = str(op.get("part", ""))
		if not _gear_base_parts.has(part):
			push_error("Unknown protagonist gear part: " + part)
			continue
		var base: Dictionary = _gear_base_parts[part]
		var node: Node2D = base["node"]
		var texture: Texture2D = _texture(str(op.get("file", "")))
		if texture == null:
			push_error("Missing protagonist gear replacement: " + str(op))
			continue
		if node is Polygon2D and texture.get_size() != (base["texture"] as Texture2D).get_size():
			push_error("Protagonist gear mesh crop size differs from base: " + part)
			continue
		node.set("texture", texture)
		if node is Sprite2D and op.has("offset"):
			var bone_name: String = str(node.get_parent().name)
			node.position = _vector(op["offset"]) - _vector(layout["joints"][bone_name]["position"])
	for op: Dictionary in ops.get("attach", []):
		var bone_name: String = str(op.get("bone", ""))
		if not bones.has(bone_name):
			push_error("Unknown protagonist gear attachment bone: " + bone_name)
			continue
		var texture: Texture2D = _texture(str(op.get("file", "")))
		if texture == null:
			push_error("Missing protagonist gear attachment: " + str(op))
			continue
		var sprite := Sprite2D.new()
		sprite.name = str(op.get("name", "GearAttachment"))
		sprite.texture = texture
		sprite.centered = false
		sprite.position = _vector(op["offset"]) - _vector(layout["joints"][bone_name]["position"])
		sprite.z_index = int(op.get("z_index", 0))
		sprite.z_as_relative = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.set_meta("gear_attachment", str(op.get("item_id", "")))
		sprite.set_meta("hide_in_clips", PackedStringArray(op.get("hide_in_clips", [])))
		# Skeleton descendants precede the later joint meshes at equal global z.
		# Thus the front dagger (48) sits below Skin_arm_l (48) and hand_l (49).
		(bones[bone_name] as Bone2D).add_child(sprite)
		_gear_attachments.append(sprite)
	_update_gear_visibility(_gear_clip)

func _update_gear_visibility(clip_name: String) -> void:
	_gear_clip = clip_name
	var crossbow_visible: bool = bones.has("weapon_l") and (bones["weapon_l"] as Bone2D).visible
	for attachment: Sprite2D in _gear_attachments:
		attachment.visible = not (crossbow_visible and (attachment.get_meta("hide_in_clips") as PackedStringArray).has(clip_name))

func apply_pose(clip_name: String, phase: float) -> void:
	var pose: Dictionary = Motion.sample_pose(clip_name, phase, layout, facing)
	_apply_sampled_pose(pose, true)
	_update_gear_visibility(clip_name)

# A sample specifies the final local transform. Resetting to rest and then
# setting position/rotation/scale/skew separately dirtied the skeleton up to five
# times per bone. Submit the same composed transform once, leaving stationary
# bones untouched. Do not quantize poses: authored animation cadence is retained.
func _apply_sampled_pose(pose: Dictionary, update_visibility: bool = false) -> void:
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		var rest: Transform2D = rest_transforms[bone_name]
		var next_transform := Transform2D(
			float(override.get("rotation", 0.0)),
			override.get("scale", Vector2.ONE),
			float(override.get("skew", 0.0)),
			override.get("position", rest.origin)
		)
		if bone.transform != next_transform:
			bone.transform = next_transform
		if update_visibility:
			bone.visible = bool(override.get("visible", true))
