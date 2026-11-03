extends RefCounted
## Offline-only CPU rasterizer. Captures the production Node rig, including
## skinned meshes, without a viewport or renderer. Never preload from scripts/.
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Shadow = preload("res://scripts/unit_shadow_cache_resource.gd")
const Assets = preload("res://scripts/asset_loader.gd")
class Raster extends RefCounted:
	var alpha := PackedFloat32Array()
	var rgba := PackedByteArray()
	func _init() -> void:
		alpha.resize(Rig.CANVAS_SIZE.x * Rig.CANVAS_SIZE.y)
		rgba.resize(alpha.size() * 4)
	func blend(x: int, y: int, value: float) -> void:
		if value == 0.0: return
		var index: int = y * Rig.CANVAS_SIZE.x + x
		if rgba[index * 4 + 3] != 0: return
		alpha[index] = value + alpha[index] * (1.0 - value)
		# BitMap quantizes float images to 8-bit alpha. Record the exact old
		# float32 threshold as we blend, avoiding a second full-canvas script
		# pass and preserving values immediately on either side of 0.08.
		if alpha[index] > Shadow.ALPHA_THRESHOLD: rgba[index * 4 + 3] = 255

static func _rasterize(jobs: Array) -> Raster:
	var raster := Raster.new()
	for job: Dictionary in jobs:
		if job.has("rect"):
			_stamp(job["image"], job["transform"], job["rect"], raster)
		else:
			var seen := PackedByteArray()
			seen.resize(raster.alpha.size())
			for triangle: PackedInt32Array in job["triangles"]:
				var points := PackedVector2Array()
				var uv := PackedVector2Array()
				for index: int in triangle:
					points.append(job["vertices"][index])
					uv.append(job["uv"][index])
				_triangle(job["image"], points, uv, raster, seen)
	return raster

static func _bitmap(raster: Raster) -> BitMap:
	var image: Image = Image.create_from_data(Rig.CANVAS_SIZE.x, Rig.CANVAS_SIZE.y, false, Image.FORMAT_RGBA8, raster.rgba)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, Shadow.ALPHA_THRESHOLD)
	return bitmap

static func _build_polygons(jobs: Array) -> Dictionary:
	var bitmap: BitMap = _bitmap(_rasterize(jobs))
	var polygons: Array[PackedVector2Array] = _polygons(bitmap, Shadow.SIMPLIFY_EPSILON)
	if polygons.is_empty(): polygons = _polygons(bitmap, Shadow.RETRY_SIMPLIFY_EPSILON)
	return {"polygons": polygons}

static func _polygons(bitmap: BitMap, epsilon: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]
	for polygon: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, Rig.CANVAS_SIZE), epsilon):
		var twice: float = 0.0
		for index: int in range(polygon.size()): twice += polygon[index].cross(polygon[(index + 1) % polygon.size()])
		if absf(twice) * 0.5 < Shadow.MIN_ALPHA_POLYGON_AREA: continue
		var logical := PackedVector2Array()
		for point: Vector2 in polygon: logical.append(point - Rig.SOURCE_OFFSET)
		result.append(logical)
	return result

static func _stamp(image: Image, transform: Transform2D, rect: Rect2, raster: Raster) -> void:
	if image == null: return
	var inverse: Transform2D = transform.affine_inverse()
	var bounds: Rect2i = _pixel_bounds(transform * rect)
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			# Alpha union is monotone. Once coverage is opaque, later paint
			# cannot change the mask; avoid its transform and texture lookup.
			if raster.rgba[(y * Rig.CANVAS_SIZE.x + x) * 4 + 3] != 0: continue
			var pixel: Vector2 = inverse * (Vector2(x, y) + Vector2.ONE * 0.5 - Rig.SOURCE_OFFSET) - rect.position
			if pixel.x < 0.0 or pixel.y < 0.0 or pixel.x >= image.get_width() or pixel.y >= image.get_height(): continue
			raster.blend(x, y, image.get_pixel(floori(pixel.x), floori(pixel.y)).a)

static func _triangle(image: Image, points: PackedVector2Array, uv: PackedVector2Array, raster: Raster, seen: PackedByteArray) -> void:
	var basis := Transform2D(points[1] - points[0], points[2] - points[0], points[0])
	if is_zero_approx(basis.determinant()): return
	var inverse: Transform2D = basis.affine_inverse()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	var pixels: Rect2i = _pixel_bounds(bounds)
	for y: int in range(pixels.position.y, pixels.end.y):
		for x: int in range(pixels.position.x, pixels.end.x):
			if raster.rgba[(y * Rig.CANVAS_SIZE.x + x) * 4 + 3] != 0: continue
			var bary: Vector2 = inverse * (Vector2(x, y) + Vector2.ONE * 0.5 - Rig.SOURCE_OFFSET)
			if bary.x < 0.0 or bary.y < 0.0 or bary.x + bary.y > 1.0: continue
			var texel: Vector2 = uv[0] + (uv[1] - uv[0]) * bary.x + (uv[2] - uv[0]) * bary.y
			if texel.x < 0.0 or texel.y < 0.0 or texel.x >= image.get_width() or texel.y >= image.get_height(): continue
			var index: int = y * Rig.CANVAS_SIZE.x + x
			if seen[index] != 0: continue
			seen[index] = 1
			raster.blend(x, y, image.get_pixel(floori(texel.x), floori(texel.y)).a)

static func _pixel_bounds(rect: Rect2) -> Rect2i:
	var start := Vector2i((rect.position + Rig.SOURCE_OFFSET).floor())
	var end := Vector2i((rect.end + Rig.SOURCE_OFFSET).ceil())
	return Rect2i(start, end - start).intersection(Rect2i(Vector2i.ZERO, Rig.CANVAS_SIZE))


static func capture(node: Node, rig: Node2D, jobs: Array[Dictionary]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible: return
	if node is Sprite2D:
		var sprite: Sprite2D = node
		if sprite.texture != null:
			jobs.append({"path": sprite.texture.get_meta("asset_source_path", ""), "image": _image(sprite.texture), "transform": rig.global_transform.affine_inverse() * sprite.global_transform, "rect": sprite.get_rect()})
	elif node is Polygon2D:
		var mesh: Polygon2D = node
		if mesh.texture != null:
			var transform: Transform2D = rig.global_transform.affine_inverse() * mesh.global_transform
			var vertices: PackedVector2Array = _skin_vertices(mesh, rig)
			for index: int in range(vertices.size()): vertices[index] = transform * vertices[index]
			jobs.append({"path": mesh.texture.get_meta("asset_source_path", ""), "image": _image(mesh.texture), "vertices": vertices, "uv": mesh.uv, "triangles": mesh.polygons})
	for child: Node in node.get_children(): capture(child, rig, jobs)

static func _skin_vertices(mesh: Polygon2D, rig: Node2D) -> PackedVector2Array:
	if mesh.get_bone_count() == 0: return mesh.polygon
	var result := PackedVector2Array()
	result.resize(mesh.polygon.size())
	for bone_index: int in range(mesh.get_bone_count()):
		var bone: Bone2D = rig.skeleton.get_node(mesh.get_bone_path(bone_index))
		var rest_position: Vector2 = rig._vector(rig.layout["joints"][str(bone.name)]["position"])
		var pose: Transform2D = rig.global_transform.affine_inverse() * bone.global_transform * Transform2D(0.0, -rest_position)
		var weights: PackedFloat32Array = mesh.get_bone_weights(bone_index)
		for index: int in range(result.size()):
			if weights[index] > 0.0: result[index] += (pose * mesh.polygon[index]) * weights[index]
	return result

static func _image(texture: Texture2D) -> Image:
	return Assets.texture_source_image(texture)
