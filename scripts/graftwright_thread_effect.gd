extends Control
## Ritual silk and stitched selection previews share the soft falloff shader.

const SILK = preload("res://scripts/graftwright_silk.gdshader")
const Palette = preload("res://scripts/ui_palette.gd")
const DURATION: float = 2.15
const SEGMENTS: int = 180
var origin := Vector2(800, 630)
var destination := Vector2(1500, 630)
var reduced_motion: bool = false
var preview: bool = false
var occlusion_rects: Array[Rect2]
var elapsed: float = 0.0
var _ribbons: Array[MeshInstance2D]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reduced_motion and not preview: return
	for strand: int in range(1 if preview else 4):
		var ribbon := MeshInstance2D.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SILK
		shader_material.set_shader_parameter("variation", float(strand) * 1.7)
		shader_material.set_shader_parameter("duration", DURATION)
		shader_material.set_shader_parameter("preview", preview)
		shader_material.set_shader_parameter("stitch_count", maxf(origin.distance_to(destination) / 18.0, 24.0))
		ribbon.material = shader_material
		add_child(ribbon)
		_ribbons.append(ribbon)
		if preview: ribbon.mesh = _mesh(strand)
	if preview and reduced_motion: set_process(false)

func _process(delta: float) -> void:
	elapsed += delta
	for strand: int in range(_ribbons.size()):
		var ribbon: MeshInstance2D = _ribbons[strand]
		(ribbon.material as ShaderMaterial).set_shader_parameter("age", elapsed)
		ribbon.mesh = _mesh(strand)
	if preview: queue_redraw()

func point(t: float, strand: int = 0) -> Vector2:
	if preview:
		var needle := Vector2(1240, 164)
		var left_top := Vector2(origin.x, 200)
		var right_top := Vector2(destination.x, 200)
		var center: Vector2
		if t < 0.25:
			center = origin.lerp(left_top, t * 4.0)
		elif t > 0.75:
			center = right_top.lerp(destination, (t - 0.75) * 4.0)
		else:
			var phase: float = (t - 0.25) * 4.0 if t < 0.5 else (t - 0.5) * 4.0
			var start: Vector2 = left_top if t < 0.5 else needle
			var end: Vector2 = needle if t < 0.5 else right_top
			var control := Vector2(origin.x if t < 0.5 else destination.x, needle.y)
			center = start.lerp(control, phase).lerp(control.lerp(end, phase), phase)
		if not reduced_motion: center.y += sin(t * PI) * sin(elapsed * 0.9) * 4.0
		return center
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
		var width: float = 9.0 if preview else 10.0 + sin(t * PI) * 8.0
		for edge: int in range(2):
			var p: Vector2 = center + normal * width * (-1.0 if edge == 0 else 1.0)
			vertices.append(Vector3(p.x, p.y, 0))
			uv.append(Vector2(t, float(edge)))
		if i < SEGMENTS and not (preview and segment_occluded(center, point(float(i + 1) / SEGMENTS, strand))):
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

func segment_occluded(start: Vector2, end: Vector2) -> bool:
	# Hide the full silk halo around text, including the spaces between glyphs.
	var tangent: Vector2 = (end - start).normalized()
	var normal := Vector2(-tangent.y, tangent.x) * 9.0
	var bounds: Rect2 = Rect2(start - normal, Vector2.ZERO).expand(start + normal).expand(end - normal).expand(end + normal)
	for rect: Rect2 in occlusion_rects:
		if rect.has_point(start) or rect.intersects(bounds): return true
	return false

func _draw() -> void:
	if not preview: return
	var center: Vector2 = point(0.5) + Vector2(0, -9)
	var eye: Vector2 = center + Vector2(-22, -6)
	draw_line(eye, center + Vector2(26, 7), Palette.TEXT, 2.5, true)
	draw_arc(eye, 3.0, 0.0, TAU, 16, Palette.GOLD_BRIGHT, 1.0, true)
