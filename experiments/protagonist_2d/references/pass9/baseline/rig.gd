extends Node2D

## Runtime version of the accepted pass-seven cutout. One instance per painted facing.
const Motion = preload("res://experiments/protagonist_2d/references/pass9/baseline/motion.gd")
const BASE: String = "res://experiments/protagonist_2d/references/pass9/baseline"
const CANVAS_SIZE := Vector2i(512, 512)
const SOURCE_OFFSET := Vector2(128, 128)
const SOURCE_SIZE := Vector2(255, 255)

var facing: String = "front"
var layout: Dictionary = {}
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
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_layout_path(facing)))
	if not parsed is Dictionary:
		load_errors.append("Invalid cutout layout: " + _layout_path(facing))
		return false
	for child: Node in get_children():
		remove_child(child)
		child.free()
	bones.clear()
	rest_transforms.clear()
	layout = parsed as Dictionary
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
		_build_mesh(layout["cape_mesh"] as Dictionary, "PaintedCape")
	for mesh: Dictionary in joint_meshes:
		_build_mesh(mesh, str(mesh.get("name", "PaintedJoint")))
	if not load_errors.is_empty():
		return false
	_loaded_facing = facing
	apply_pose("idle", 0.0)
	return true

func _build_mesh(data: Dictionary, mesh_name: String) -> void:
	# Meshes share the skeleton's source-pixel coordinate space. Parenting them
	# to a Bone2D would apply that moving transform a second time.
	var mesh := Polygon2D.new()
	mesh.name = mesh_name
	mesh.set_meta("equipment_slot", str(data.get("equipment_slot", "")))
	mesh.texture = _texture(str(data["file"]))
	mesh.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point: Variant in data["vertices"]:
		vertices.append(_vector(point))
	for point: Variant in data["uvs"]:
		uvs.append(_vector(point))
	if vertices.size() != uvs.size():
		load_errors.append(mesh_name + ": vertex/UV count differs")
		mesh.free()
		return
	mesh.polygon = vertices
	mesh.uv = uvs
	var triangles: Array = []
	for triangle: Variant in data["triangles"]:
		if triangle.size() != 3:
			load_errors.append(mesh_name + ": a mesh face must contain three indices")
			mesh.free()
			return
		for index: int in triangle:
			if index < 0 or index >= vertices.size():
				load_errors.append(mesh_name + ": triangle index outside vertex array")
				mesh.free()
				return
		triangles.append(PackedInt32Array(triangle))
	mesh.polygons = triangles
	mesh.z_index = int(data.get("z_index", 3))
	mesh.z_as_relative = false
	add_child(mesh)
	mesh.owner = self
	mesh.skeleton = mesh.get_path_to(skeleton)
	var weights: Dictionary = data["weights"]
	var totals := PackedFloat32Array()
	totals.resize(vertices.size())
	for bone_name: String in weights:
		var influence := PackedFloat32Array(weights[bone_name])
		if influence.size() != vertices.size() or not bones.has(bone_name):
			load_errors.append(mesh_name + ": invalid skin weights for " + bone_name)
			continue
		for index: int in range(influence.size()):
			if not is_finite(influence[index]) or influence[index] < 0.0:
				load_errors.append(mesh_name + ": invalid influence for " + bone_name)
				return
			totals[index] += influence[index]
		mesh.add_bone(skeleton.get_path_to(bones[bone_name]), influence)
	for total: float in totals:
		if absf(total - 1.0) > 0.001:
			load_errors.append(mesh_name + ": vertex weights do not sum to one")
			return
	mesh.queue_redraw()

func apply_pose(clip_name: String, phase: float) -> void:
	var pose: Dictionary = Motion.sample_pose(clip_name, phase, layout, facing)
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var override: Dictionary = pose.get(bone_name, {})
		bone.transform = rest_transforms[bone_name]
		bone.position = override.get("position", bone.position)
		bone.rotation = float(override.get("rotation", 0.0))
		bone.scale = override.get("scale", Vector2.ONE)
		bone.skew = float(override.get("skew", 0.0))
