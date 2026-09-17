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

func apply_pose(clip_name: String, phase: float) -> void:
	var pose: Dictionary = Motion.sample_pose(clip_name, phase, layout, facing)
	_apply_sampled_pose(pose, true)

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
