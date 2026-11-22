extends Node2D
## Minimal geometry for the live canvas command and vertex formats. Witnesses
## are connected only in the focused check and run at command submission.

const BOX := Rect2(2, 2, 20, 20)
const POINTS := [Vector2(2, 2), Vector2(22, 2), Vector2(22, 22), Vector2(2, 22)]
const TRIANGLE := [Vector2(2, 2), Vector2(22, 2), Vector2(2, 22)]
const UVS := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
const QUAD_INDICES := [0, 1, 2, 2, 3, 0]
const TRIANGLE_INDICES := [0, 1, 2]
const NINE_PATCH_MARGIN := 2
const BEVEL_LINE_WIDTH := 1.0

var shape: String
var texture: Texture2D
var witness: Callable
var mesh: ArrayMesh
var motes: MultiMesh
var style: StyleBoxTexture

static func build(next_shape: String, sample_texture: Texture2D, draw_witness: Callable) -> Node2D:
	var sample := new()
	sample.shape = next_shape
	sample.texture = sample_texture
	sample.witness = draw_witness
	match next_shape:
		"clip":
			sample.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			var sprite := Sprite2D.new()
			sprite.texture = sample_texture
			sprite.centered = false
			sample.add_child(sprite)
			if draw_witness.is_valid():
				sprite.draw.connect(func() -> void: draw_witness.call("texture_rect", {"textured": sprite.texture != null}))
		"mesh_color":
			sample.mesh = _mesh(false, true)
		"mesh_uv":
			sample.mesh = _mesh(true, true)
		"motes":
			# CPUParticles2D submits a 2D MultiMesh with colour, custom data,
			# and an indexed position/colour/UV quad. The constructor uses RNG.
			sample.motes = MultiMesh.new()
			sample.motes.transform_format = MultiMesh.TRANSFORM_2D
			sample.motes.use_colors = true
			sample.motes.use_custom_data = true
			sample.motes.mesh = _mesh(true, false)
			sample.motes.instance_count = 1
			sample.motes.set_instance_transform_2d(0, Transform2D.IDENTITY)
			sample.motes.set_instance_color(0, Color.WHITE)
		"stylebox":
			sample.style = StyleBoxTexture.new()
			sample.style.texture = sample_texture
			sample.style.set_texture_margin_all(NINE_PATCH_MARGIN)
	return sample

static func _mesh(with_uv: bool, position_3d: bool) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(POINTS)
	if position_3d:
		var vertices := PackedVector3Array()
		for point: Vector2 in POINTS: vertices.append(Vector3(point.x, point.y, 0.0))
		arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(QUAD_INDICES)
	if with_uv: arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(UVS)
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func electric(layer: GDScript, draw_witness: Callable) -> MeshInstance2D:
	var item := MeshInstance2D.new()
	item.mesh = layer._build_mesh(0)
	item.position = BOX.get_center()
	var material := ShaderMaterial.new()
	material.shader = layer.ELECTRIC_SHADER
	var endpoints := PackedVector4Array()
	endpoints.resize(18)
	endpoints.fill(Vector4(-4, -3, 4, 3))
	material.set_shader_parameter("endpoints", endpoints)
	material.set_shader_parameter("tile_width", BOX.size.x)
	item.material = material
	witness_mesh(item, draw_witness)
	return item

static func witness_mesh(item: MeshInstance2D, draw_witness: Callable) -> void:
	if draw_witness.is_valid():
		item.draw.connect(func() -> void: draw_witness.call("mesh", _mesh_shape(item.mesh, item.texture)))

static func _mesh_shape(value: ArrayMesh, sampled: Texture2D) -> Dictionary:
	var format: int = value.surface_get_format(0)
	return {"uv": bool(format & Mesh.ARRAY_FORMAT_TEX_UV), "color": bool(format & Mesh.ARRAY_FORMAT_COLOR),
		"indexed": bool(format & Mesh.ARRAY_FORMAT_INDEX), "position_2d": bool(format & Mesh.ARRAY_FLAG_USE_2D_VERTICES),
		"textured": sampled != null, "primitive": value.surface_get_primitive_type(0)}

func _draw() -> void:
	var points := PackedVector2Array(POINTS)
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	match shape:
		"polygon_uv":
			_polygon(points, colours, PackedVector2Array(UVS), texture)
		"polygon_uv_solid":
			_polygon(points, PackedColorArray([Color.WHITE]), PackedVector2Array(UVS), texture)
		"polygon_color":
			_polygon(points, colours)
		"polygon_solid", "clip":
			_solid_polygon(points)
		"route":
			_line(points, 2.0, true)
			_solid_polygon(points)
		"floor_shade":
			_solid_polygon(points)
			_polygon(points, colours)
			# draw_line submits canvas primitives, unlike the widened polyline.
			draw_line(points[0], points[1], Color.WHITE, BEVEL_LINE_WIDTH, true)
			_record("line", {"antialias": true, "vertices": 4, "uv": false})
			_line(points, 2.0, true)
		"stroke":
			_line(points, 3.0, false)
			_rect()
		"primitive":
			var vertices := PackedVector2Array(TRIANGLE)
			var vertex_colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
			var uv := PackedVector2Array()
			draw_primitive(vertices, vertex_colours, uv)
			_record("primitive", {"vertices": vertices.size(), "uv": not uv.is_empty(), "textured": false})
		"triangles":
			var vertices := PackedVector2Array(TRIANGLE)
			var vertex_colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(TRIANGLE_INDICES), vertices, vertex_colours)
			_record("triangle_array", {"uv": false, "textured": false, "indexed": true})
		"mesh_color", "mesh_uv":
			var sampled: Texture2D = texture if shape == "mesh_uv" else null
			draw_mesh(mesh, sampled)
			if witness.is_valid(): _record("mesh", _mesh_shape(mesh, sampled))
		"motes":
			draw_multimesh(motes, texture)
			if witness.is_valid():
				var format := _mesh_shape(motes.mesh, texture)
				format.merge({"instance_2d": motes.transform_format == MultiMesh.TRANSFORM_2D,
					"instance_color": motes.use_colors, "instance_custom": motes.use_custom_data})
				_record("multimesh", format)
		"stylebox":
			draw_style_box(style, BOX)
			_record("nine_patch", {"textured": style.texture != null, "has_margins": style.get_texture_margin(SIDE_LEFT) > 0})
		"rect":
			_rect()
		"texture_rect":
			draw_texture_rect(texture, BOX, false)
			_record("texture_rect", {"textured": texture != null})

func _line(points: PackedVector2Array, width: float, antialias: bool) -> void:
	draw_polyline(points, Color.WHITE, width, antialias)
	_record("polyline", {"antialias": antialias, "wide": width > 0.0, "uv": false})

func _rect() -> void:
	draw_rect(BOX, Color.WHITE)
	_record("rect", {"textured": false})

func _solid_polygon(points: PackedVector2Array) -> void:
	RenderingServer.canvas_item_add_polygon(get_canvas_item(), points, PackedColorArray([Color.WHITE]))
	_record("polygon", {"uv": false, "textured": false, "per_vertex_color": false, "clip": clip_children != CLIP_CHILDREN_DISABLED})

func _polygon(points: PackedVector2Array, colours: PackedColorArray, uv: PackedVector2Array = PackedVector2Array(), sampled: Texture2D = null) -> void:
	draw_polygon(points, colours, uv, sampled)
	_record("polygon", {"uv": not uv.is_empty(), "textured": sampled != null, "per_vertex_color": colours.size() == points.size(), "clip": false})

func _record(command: String, format: Dictionary) -> void:
	if witness.is_valid(): witness.call(command, format)
