extends Control
## Ritual silk and stitched selection previews share the soft falloff shader.

const SILK = preload("res://scripts/graftwright_silk.gdshader")
const Palette = preload("res://scripts/ui_palette.gd")
const DURATION: float = 2.15
const SEGMENTS: int = 180
# Vertex colors encode two clipping intervals in the [-5, 5] bob range.
const PREVIEW_VERTEX := """
uniform float bob = 0.0;
varying vec4 occlusion;
void vertex() {
    VERTEX.y += sin(UV.x * PI) * bob;
    occlusion = COLOR * 10.0 - vec4(5.0);
}
"""
const PREVIEW_CLIP := """
    if ((bob > occlusion.x && bob < occlusion.y) ||
        (bob > occlusion.z && bob < occlusion.w)) { discard; }
"""
static var _preview_silk: Shader
var origin := Vector2(800, 630)
var destination := Vector2(1500, 630)
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			_sync_processing()
			if preview: _update_preview()
var preview: bool = false
var occlusion_rects: Array[Rect2]
var elapsed: float = 0.0
var _ribbons: Array[MeshInstance2D]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_sync_processing)
	_sync_processing()
	if reduced_motion and not preview: return
	for strand: int in range(1 if preview else 4):
		var ribbon := MeshInstance2D.new()
		var shader_material := ShaderMaterial.new()
		shader_material.shader = _preview_shader() if preview else SILK
		shader_material.set_shader_parameter("variation", float(strand) * 1.7)
		shader_material.set_shader_parameter("duration", DURATION)
		shader_material.set_shader_parameter("preview", preview)
		shader_material.set_shader_parameter("stitch_count", maxf(origin.distance_to(destination) / 18.0, 24.0))
		ribbon.material = shader_material
		add_child(ribbon)
		_ribbons.append(ribbon)
		if preview: ribbon.mesh = _mesh(strand)
	if preview: _update_preview()

static func _preview_shader() -> Shader:
	if _preview_silk == null:
		_preview_silk = Shader.new()
		_preview_silk.code = SILK.code.replace("void fragment() {", PREVIEW_VERTEX + "\nvoid fragment() {\n" + PREVIEW_CLIP)
	return _preview_silk

func _sync_processing() -> void:
	set_process(is_visible_in_tree() and not reduced_motion)

func _update_preview() -> void:
	for ribbon: MeshInstance2D in _ribbons:
		(ribbon.material as ShaderMaterial).set_shader_parameter("bob", 0.0 if reduced_motion else sin(elapsed * 0.9) * 4.0)
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion or not is_visible_in_tree(): return
	elapsed += delta
	if preview:
		_update_preview()
		return
	for strand: int in range(_ribbons.size()):
		var ribbon: MeshInstance2D = _ribbons[strand]
		(ribbon.material as ShaderMaterial).set_shader_parameter("age", elapsed)
		ribbon.mesh = _mesh(strand)

func point(t: float, strand: int = 0) -> Vector2:
	if preview:
		var center: Vector2 = _preview_point(t)
		if not reduced_motion: center.y += sin(t * PI) * sin(elapsed * 0.9) * 4.0
		return center
	var arch: float = sin(t * PI)
	return origin.lerp(destination, t) + Vector2(sin(t * TAU + float(strand)) * arch * 15.0, -arch * (100.0 + strand * 13.0) + sin(t * TAU * 1.5 + elapsed * 2.7 + strand * 1.5) * arch * 24.0)

func _preview_point(t: float) -> Vector2:
	var needle := Vector2(1240, 164)
	var left_top := Vector2(origin.x, 200)
	var right_top := Vector2(destination.x, 200)
	if t < 0.25: return origin.lerp(left_top, t * 4.0)
	if t > 0.75: return right_top.lerp(destination, (t - 0.75) * 4.0)
	var phase: float = (t - 0.25) * 4.0 if t < 0.5 else (t - 0.5) * 4.0
	var start: Vector2 = left_top if t < 0.5 else needle
	var end: Vector2 = needle if t < 0.5 else right_top
	var control := Vector2(origin.x if t < 0.5 else destination.x, needle.y)
	return start.lerp(control, phase).lerp(control.lerp(end, phase), phase)

func _mesh(strand: int) -> ArrayMesh:
	if preview: return _preview_mesh()
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

func _preview_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i: int in range(SEGMENTS):
		var t: float = float(i) / SEGMENTS
		var next_t: float = float(i + 1) / SEGMENTS
		var start: Vector2 = _preview_point(t)
		var end: Vector2 = _preview_point(next_t)
		var mask: Color = _preview_occlusion(start, end, sin(t * PI), sin(next_t * PI))
		for sample: float in [t, next_t]:
			var center: Vector2 = _preview_point(sample)
			var tangent: Vector2 = (_preview_point(minf(sample + 0.005, 1.0)) - _preview_point(maxf(sample - 0.005, 0.0))).normalized()
			var normal := Vector2(-tangent.y, tangent.x) * 9.0
			for edge: int in range(2):
				var p: Vector2 = center + normal * (-1.0 if edge == 0 else 1.0)
				vertices.append(Vector3(p.x, p.y, 0))
				uv.append(Vector2(sample, float(edge)))
				colors.append(mask)
		var n: int = i * 4
		indices.append_array(PackedInt32Array([n, n + 1, n + 2, n + 1, n + 3, n + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _preview_occlusion(start: Vector2, end: Vector2, start_weight: float, end_weight: float) -> Color:
	# Cache the bob amplitudes that hide each segment; no layout tests during sway.
	var tangent: Vector2 = (end - start).normalized()
	var normal := Vector2(-tangent.y, tangent.x) * 9.0
	var bounds: Rect2 = Rect2(start - normal, Vector2.ZERO).expand(start + normal).expand(end - normal).expand(end + normal)
	var ranges: Array[Vector2]
	for rect: Rect2 in occlusion_rects:
		if bounds.end.x <= rect.position.x or bounds.position.x >= rect.end.x: continue
		var low: float = 5.0
		var high: float = -5.0
		for endpoint: int in range(2):
			var center: Vector2 = start if endpoint == 0 else end
			var weight: float = start_weight if endpoint == 0 else end_weight
			for edge: int in [-1, 1]:
				var y: float = center.y + normal.y * edge
				if weight <= 0.00001:
					if y > rect.position.y: low = -5.0
					if y < rect.end.y: high = 5.0
				else:
					low = minf(low, (rect.position.y - y) / weight)
					high = maxf(high, (rect.end.y - y) / weight)
		if low < high and low < 4.0 and high > -4.0:
			ranges.append(Vector2(maxf(low, -5.0), minf(high, 5.0)))
	ranges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2]
	for interval: Vector2 in ranges:
		if not merged.is_empty() and interval.x <= merged[-1].y:
			merged[-1].y = maxf(merged[-1].y, interval.y)
		else: merged.append(interval)
	assert(merged.size() <= 2, "Thread segment crosses more than two separate text bands")
	var first: Vector2 = merged[0] if not merged.is_empty() else Vector2(5, -5)
	var second: Vector2 = merged[1] if merged.size() > 1 else Vector2(5, -5)
	return Color((first.x + 5.0) / 10.0, (first.y + 5.0) / 10.0, (second.x + 5.0) / 10.0, (second.y + 5.0) / 10.0)

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
