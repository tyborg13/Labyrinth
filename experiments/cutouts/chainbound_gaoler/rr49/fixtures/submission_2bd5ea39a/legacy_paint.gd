extends RefCounted

## Optional deterministic submission for exact-source rigs. Skin once in source
## space and submit vertices on the rasterizer's existing 8-bit subpixel grid.
## The GPU never repacks these weights or reconstructs a rotated sprite quad.
## Original Sprite2D nodes remain the authoritative transforms and texture/input
## paths. Their child submits the same source UVs, triangles and RGBA.
const SUBPIXEL_SCALE: float = 256.0
const CACHE_CAPACITY: int = 128
static var _vertices: Dictionary = {}

static func register_mesh(rig: Node2D, data: Dictionary, mesh_name: String) -> void:
	if not rig.layout.get("stable_source_raster", false): return
	var node: Polygon2D = rig.get_node(NodePath(mesh_name)) as Polygon2D
	var registered: Dictionary = data.duplicate()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([data["vertices"], data["weights"], rig.layout["joints"], node.polygon]))
	registered["_stable_definition"] = context.finish().hex_encode()
	node.set_meta("stable_source", registered)
	node.set_meta("stable_polygon", node.polygon)
	node.set_meta("stable_skeleton", node.skeleton)

static func restore(rig: Node2D) -> void:
	if not rig.layout.get("stable_source_raster", false): return
	for node: Node in rig.get_children():
		if node is Polygon2D and node.has_meta("stable_source"):
			node.polygon = node.get_meta("stable_polygon")
			node.skeleton = node.get_meta("stable_skeleton")
	for part: Dictionary in rig.layout["parts"]:
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node_or_null(NodePath(part["name"])) as Sprite2D
		if sprite == null or not sprite.has_node("ExactSourcePaint"): continue
		sprite.self_modulate.a = 1.0
		sprite.get_node("ExactSourcePaint").hide()

static func packed(transform: Transform2D) -> Array:
	return [transform.x.x, transform.x.y, transform.y.x, transform.y.y, transform.origin.x, transform.origin.y]

static func snap_point(x: float, y: float) -> Vector2:
	return Vector2(floorf(x * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE, floorf(y * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE)

static func skin(data: Dictionary, transforms: Dictionary, joints: Dictionary) -> PackedVector2Array:
	var key: Array = [data["_stable_definition"], transforms]
	if _vertices.has(key): return _vertices[key]
	var result := PackedVector2Array()
	for index: int in range(data["vertices"].size()):
		var source: Array = data["vertices"][index]
		var x: float = 0.0
		var y: float = 0.0
		for name: String in data["weights"]:
			var weight: float = float(data["weights"][name][index])
			if weight == 0.0: continue
			var pose: Array = transforms[name]
			var bind: Array = joints[name]["position"]
			var dx: float = float(source[0]) - float(bind[0])
			var dy: float = float(source[1]) - float(bind[1])
			x += weight * (dx * float(pose[0]) + dy * float(pose[2]) + float(pose[4]))
			y += weight * (dx * float(pose[1]) + dy * float(pose[3]) + float(pose[5]))
		result.append(snap_point(x, y))
	if _vertices.size() >= CACHE_CAPACITY: _vertices.clear()
	_vertices[key] = result
	return result

static func idle_offset(rig: Node2D, data: Dictionary) -> Vector2:
	var logical: String = str(data.get("logical_part", data.get("garment", data.get("name", ""))))
	for group: Array in rig.layout["idle_groups"].values():
		if not logical in group: continue
		# The group's first painted part names its anchor bone. All its authored
		# bones are independently checked to have this same integer translation.
		var anchor: String = ""
		for part: Dictionary in rig.layout["parts"]:
			if part["name"] == group[0]: anchor = str(part["bone"])
		var pose: Transform2D = rig.global_transform.affine_inverse() * (rig.bones[anchor] as Bone2D).global_transform
		return (pose.origin - preload("res://scripts/maquette_cutout_runtime/motion.gd").point(rig.layout["joints"][anchor]["position"])).round()
	return Vector2.ZERO

static func apply(rig: Node2D, clip: String) -> void:
	if not rig.layout.get("stable_source_raster", false): return
	rig.set_notify_transform(true)
	var source: Transform2D = rig.global_transform.affine_inverse()
	for node: Node in rig.get_children():
		if not node is Polygon2D or not node.has_meta("stable_source"): continue
		var mesh: Polygon2D = node as Polygon2D
		var data: Dictionary = node.get_meta("stable_source")
		mesh.skeleton = NodePath()
		if clip in ["rest", "idle"]:
			var offset: Vector2 = idle_offset(rig, data)
			var key: Array = [data["_stable_definition"], "idle", offset]
			if not _vertices.has(key):
				var points := PackedVector2Array()
				for point: Vector2 in node.get_meta("stable_polygon"): points.append(point + offset)
				if _vertices.size() >= CACHE_CAPACITY: _vertices.clear()
				_vertices[key] = points
			mesh.polygon = _vertices[key]
		else:
			var transforms: Dictionary = {}
			for name: String in data["weights"]:
				var bone: Bone2D = rig.cap_bones[name] if data.get("rigid_source_alignment", false) and rig.cap_bones.has(name) else rig.bones[name]
				transforms[name] = packed(source * bone.global_transform)
			mesh.polygon = skin(data, transforms, rig.layout["joints"])
	var replaced: Dictionary = {}
	for data: Dictionary in rig.layout["joint_meshes"]: replaced[data["replaces_part"]] = true
	for part: Dictionary in rig.layout["parts"]:
		if replaced.has(part["name"]): continue
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Sprite2D
		var paint: Polygon2D = sprite.get_node_or_null("ExactSourcePaint") as Polygon2D
		if paint == null:
			paint = Polygon2D.new()
			paint.name = "ExactSourcePaint"
			sprite.add_child(paint)
			paint.set_as_top_level(true)
			var triangles: Array[PackedInt32Array]
			triangles.assign([PackedInt32Array([0, 1, 2]), PackedInt32Array([0, 2, 3])])
			paint.polygons = triangles
		paint.global_transform = rig.global_transform
		paint.texture = sprite.texture
		paint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		paint.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		paint.z_as_relative = false
		paint.z_index = sprite.z_index
		var size: Vector2 = sprite.texture.get_size()
		var uv := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var pose: Array = packed(source * sprite.global_transform)
		var points := PackedVector2Array()
		for point: Vector2 in uv:
			points.append(snap_point(float(pose[0]) * float(point.x) + float(pose[2]) * float(point.y) + float(pose[4]),
				float(pose[1]) * float(point.x) + float(pose[3]) * float(point.y) + float(pose[5])))
		paint.uv = uv
		paint.polygon = points
		paint.show()
		sprite.self_modulate.a = 0.0

## Top-level quads bypass their bone transforms because their vertices already
## contain the sampled pose. They must still follow later root/ancestor changes,
## including a board-facing mutation made without another pose sample. Copy the
## root matrix directly; an inverse bone matrix would reintroduce roundoff.
static func follow_root(rig: Node2D) -> void:
	if not rig.layout.get("stable_source_raster", false): return
	for part: Dictionary in rig.layout["parts"]:
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node_or_null(NodePath(part["name"])) as Sprite2D
		if sprite == null: continue
		var paint: Polygon2D = sprite.get_node_or_null("ExactSourcePaint") as Polygon2D
		if paint != null: paint.global_transform = rig.global_transform

## Headless proof records the actual submitted buffer, never a CPU prediction.
static func geometry(rig: Node2D, selected: String = "") -> Dictionary:
	var result: Dictionary = {}
	for part: Dictionary in rig.layout["parts"]:
		var node: Node2D = rig.get_node_or_null(NodePath(part["name"])) as Node2D
		if not selected.is_empty() and part["name"] != selected: continue
		var original: Node2D = node
		if node == null:
			original = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Node2D
			node = original.get_node_or_null("ExactSourcePaint") as Node2D
		if not node is Polygon2D: continue
		var mesh: Polygon2D = node as Polygon2D
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(mesh.polygon.to_byte_array())
		result[part["name"]] = {"vertices_sha256": context.finish().hex_encode(), "count": mesh.polygon.size(),
			"skeleton_empty": mesh.skeleton.is_empty(), "visible": mesh.visible,
			"transform": packed(rig.global_transform.affine_inverse() * mesh.global_transform),
			"source_suppressed": original == mesh or is_zero_approx(original.self_modulate.a),
			"texture_matches": mesh.texture == original.get("texture")}
	return result
