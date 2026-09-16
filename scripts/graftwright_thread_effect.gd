extends Control
## Continuous silk ribbons with soft shader falloff; no bead/dot particles.

const SILK = preload("res://scripts/graftwright_silk.gdshader")
const DURATION: float = 2.15
const SEGMENTS: int = 180
var origin := Vector2(800, 630)
var destination := Vector2(1500, 630)
var reduced_motion: bool = false
var elapsed: float = 0.0
var _ribbons: Array[MeshInstance2D]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reduced_motion: return
	for strand: int in range(4):
		var ribbon := MeshInstance2D.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SILK
		shader_material.set_shader_parameter("variation", float(strand) * 1.7)
		shader_material.set_shader_parameter("duration", DURATION)
		ribbon.material = shader_material
		add_child(ribbon)
		_ribbons.append(ribbon)

func _process(delta: float) -> void:
	elapsed += delta
	for strand: int in range(_ribbons.size()):
		var ribbon: MeshInstance2D = _ribbons[strand]
		(ribbon.material as ShaderMaterial).set_shader_parameter("age", elapsed)
		ribbon.mesh = _mesh(strand)

func point(t: float, strand: int = 0) -> Vector2:
	var arch: float = sin(t * PI)
	return origin.lerp(destination, t) + Vector2(sin(t * TAU + float(strand)) * arch * 15.0, -arch * (100.0 + strand * 13.0) + sin(t * TAU * 1.5 + elapsed * 2.7 + strand * 1.5) * arch * 24.0)

func _mesh(strand: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for i: int in range(SEGMENTS + 1):
		var t: float = float(i) / SEGMENTS
		var center: Vector2 = point(t, strand)
		var tangent: Vector2 = (point(minf(t + 0.005, 1.0), strand) - point(maxf(t - 0.005, 0.0), strand)).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var width: float = 10.0 + sin(t * PI) * 8.0
		for edge: int in range(2):
			var p: Vector2 = center + normal * width * (-1.0 if edge == 0 else 1.0)
			vertices.append(Vector3(p.x, p.y, 0))
			uv.append(Vector2(t, float(edge)))
		if i < SEGMENTS:
			var n: int = i * 2
			indices.append_array(PackedInt32Array([n, n + 1, n + 2, n + 1, n + 3, n + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
