extends Node2D

## Original painted cutouts on editable Godot bones. The inspection host owns time.
const Motion = preload("res://experiments/protagonist_2d/cutout_motion.gd")
const BASE: String = "res://experiments/protagonist_2d"
const CANVAS_SIZE := Vector2i(512, 512)
const SOURCE_OFFSET := Vector2(128, 128)
const SOURCE_SIZE := Vector2(255, 255)

var facing: String = "front"
var clip: String = "idle"
var layout: Dictionary = {}
var bones: Dictionary = {}
var rest_transforms: Dictionary = {}
var specs: Dictionary = {}
var load_errors: PackedStringArray = []
var skeleton: Skeleton2D
var animator: AnimationPlayer
var _loaded_facing: String = ""
var _frame_index: int = 0
var _elapsed: float = 0.0
var _debug_bones: bool = false
var _bone_overlay: Node2D
var _reference_cache: Dictionary = {}

func _layout_path(which: String) -> String:
	return BASE.path_join("cutout_layout.json" if which == "front" else "cutout_layout_rear.json")

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
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(_resolve(path)))
	if image == null or image.is_empty():
		load_errors.append("Missing cutout image: " + path)
		return null
	return ImageTexture.create_from_image(image)

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
	_bone_overlay = null
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
	specs = Motion.clip_specs()
	_build_animations()
	set_debug_bones(_debug_bones)
	_loaded_facing = facing
	set_clip(clip)
	return true

func _build_mesh(data: Dictionary, mesh_name: String) -> void:
	# Meshes share the skeleton's source-pixel coordinate space. Parenting them
	# to a Bone2D would apply that moving transform a second time.
	var mesh := Polygon2D.new()
	mesh.name = mesh_name
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

func _build_animations() -> void:
	animator = AnimationPlayer.new()
	animator.name = "Animations"
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animator)
	animator.owner = self
	var library := AnimationLibrary.new()
	for clip_name: String in specs:
		var specification: Dictionary = specs[clip_name]
		var frames: int = int(specification["frames"])
		var fps: float = float(specification["fps"])
		var looping: bool = bool(specification.get("loop", false))
		var animation := Animation.new()
		animation.resource_name = facing + "_" + clip_name
		animation.length = float(frames) / fps
		animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
		var tracks: Dictionary = {}
		for bone_name: String in bones:
			tracks[bone_name] = {}
			for property_name: String in ["position", "rotation", "scale"]:
				var track: int = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track, NodePath(str(get_path_to(bones[bone_name])) + ":" + property_name))
				animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
				(tracks[bone_name] as Dictionary)[property_name] = track
		for frame: int in range(frames + 1):
			var phase: float = float(frame) / float(frames) if looping else minf(1.0, float(frame) / float(frames - 1))
			var pose: Dictionary = Motion.sample_pose(clip_name, phase, layout, facing)
			for bone_name: String in bones:
				var override: Dictionary = pose.get(bone_name, {})
				var rest: Transform2D = rest_transforms[bone_name]
				var values: Dictionary = {"position": override.get("position", rest.origin), "rotation": override.get("rotation", 0.0), "scale": override.get("scale", Vector2.ONE)}
				for property_name: String in values:
					animation.track_insert_key(int((tracks[bone_name] as Dictionary)[property_name]), float(frame) / fps, values[property_name])
		library.add_animation(clip_name, animation)
	animator.add_animation_library("", library)

func set_facing(which: String) -> void:
	if which == facing and _loaded_facing == facing:
		return
	if not has_facing(which):
		push_error("Missing actual facing: " + which)
		return
	facing = which
	load_rig()

func set_clip(name_value: String) -> void:
	if not specs.has(name_value):
		return
	clip = name_value
	_elapsed = 0.0
	animator.play(clip)
	animator.pause()
	seek_frame(0)

func seek_frame(index: int) -> void:
	if animator == null or get_frame_count() <= 0:
		return
	_frame_index = posmod(index, get_frame_count())
	animator.seek(float(_frame_index) / get_fps(), true)
	if is_instance_valid(_bone_overlay):
		_bone_overlay.queue_redraw()
	queue_redraw()

func advance(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	seek_frame(int(floor(_elapsed * get_fps())))

func get_frame_count() -> int:
	return int((specs.get(clip, {}) as Dictionary).get("frames", 0))

func get_frame_index() -> int:
	return _frame_index

func get_fps() -> float:
	return float((specs.get(clip, {}) as Dictionary).get("fps", 24.0))

func get_anchor() -> Vector2:
	return (SOURCE_OFFSET + Vector2(127.5, 223.0)) / Vector2(CANVAS_SIZE)

func get_reference_texture(which: String = "") -> Texture2D:
	var key: String = facing if which.is_empty() else which
	if _reference_cache.has(key):
		return _reference_cache[key]
	if key == "front":
		_reference_cache[key] = _texture("res://assets/placeholders/units/player_reaver.png")
	elif has_facing(key):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_layout_path(key)))
		if data is Dictionary:
			_reference_cache[key] = _texture(str((data as Dictionary).get("source", "references/rear.png")))
	return _reference_cache.get(key) as Texture2D

func show_rest() -> void:
	if animator != null:
		animator.pause()
	for bone_name: String in bones:
		(bones[bone_name] as Bone2D).transform = rest_transforms[bone_name]
	queue_redraw()

func set_debug_bones(enabled: bool) -> void:
	_debug_bones = enabled
	if enabled and not is_instance_valid(_bone_overlay):
		_bone_overlay = Node2D.new()
		_bone_overlay.name = "BoneInspectionOverlay"
		_bone_overlay.z_index = 1000
		_bone_overlay.z_as_relative = false
		add_child(_bone_overlay)
		_bone_overlay.draw.connect(_draw_bone_overlay.bind(_bone_overlay))
	if is_instance_valid(_bone_overlay):
		_bone_overlay.visible = enabled
		_bone_overlay.queue_redraw()

func _draw_bone_overlay(canvas: Node2D) -> void:
	for bone_name: String in bones:
		var bone: Bone2D = bones[bone_name]
		var here: Vector2 = to_local(bone.global_position)
		if bone.get_parent() is Bone2D:
			var there: Vector2 = to_local((bone.get_parent() as Bone2D).global_position)
			canvas.draw_line(here, there, Color("ffd883"), 1.0, true)
		canvas.draw_circle(here, 2.0, Color("ff704e"))

func save_editable_scene(path: String) -> Error:
	show_rest()
	set_meta("cutout_facing", facing)
	set_meta("identity_source", str(layout.get("source", "")))
	var scene := PackedScene.new()
	var result: Error = scene.pack(self)
	if result != OK:
		return result
	return ResourceSaver.save(scene, path)
