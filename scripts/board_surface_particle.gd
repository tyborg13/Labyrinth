extends MeshInstance2D

## Exact retained procedural particle quad, shared by persistent materials.
## Uniform updates keep the native mesh command resident; they need no redraw.
const PARTICLE_SHADER = preload("res://scripts/board_surface_particle.gdshader")
static var _quad: ArrayMesh
var _material: ShaderMaterial

var at: Vector2
var size: Vector2
var angle: float
var tint: Color

func _init() -> void:
	if _quad == null:
		var arrays: Array
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([3, 0, 1, 1, 2, 3])
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = _quad
	_material = ShaderMaterial.new()
	_material.shader = PARTICLE_SHADER
	material = _material

func configure(next_at: Vector2, next_size: Vector2, next_angle: float, next_tint: Color) -> void:
	if at == next_at and size == next_size and angle == next_angle and tint == next_tint: return
	var geometry_changed: bool = at != next_at or size != next_size or angle != next_angle
	at = next_at
	size = next_size
	angle = next_angle
	tint = next_tint
	if geometry_changed:
		# Same operation order as the immediate procedural quad, with its
		# exact corners uploaded rather than approximated by shader rotation.
		var x := Vector2(cos(angle), sin(angle)) * size.x * 0.5
		var y := Vector2(-sin(angle), cos(angle)) * size.y * 0.5
		var corners := PackedVector2Array([at - x - y, at + x - y, at + x + y, at - x + y])
		_material.set_shader_parameter("corners", corners)
		var bounds := Rect2(corners[0], Vector2.ZERO)
		for point: Vector2 in corners: bounds = bounds.expand(point)
		RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, bounds)
	_material.set_shader_parameter("particle_tint", tint)
func set_tint(next_tint: Color) -> void:
	if tint == next_tint: return
	tint = next_tint
	_material.set_shader_parameter("particle_tint", tint)
