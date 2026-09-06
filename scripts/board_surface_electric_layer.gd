extends Node2D

## All eighteen authored bolts retain their feathered ribbons, antialiased hot
## cores and junction glows. Only geometry evaluation moves onto the GPU; the
## supplied board phase controls every fork, cloud and flash together.
const Art = preload("res://scripts/board_surface_presentation.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Particle = preload("res://scripts/board_surface_particle.gd")
const ELECTRIC_SHADER = preload("res://scripts/board_surface_electric.gdshader")

static var _meshes: Array[ArrayMesh]
var _width: float = -1.0
var _seed: int = -1
var _phase: float = INF
var _opacity: float = -1.0
var _tick: int = -2147483648
var _material: ShaderMaterial
var _base: Particle
var _clouds: Array[Particle]
var _junctions: Array[Particle]
var _contacts: Array[Particle]
var _anchors := PackedVector2Array()
var _endpoints := PackedVector4Array()
var _angles := PackedFloat32Array()
var _intensities := PackedFloat32Array()

func configure(center: Vector2, width: float, seed: int, phase: float, opacity: float) -> void:
	position = center
	if width != _width or seed != _seed:
		_width = width
		_seed = seed
		_build()
		_phase = INF
		_tick = -2147483648
	if phase == _phase and opacity == _opacity: return
	_phase = phase
	_opacity = opacity
	var tick: int = int(floor(phase * 0.91))
	if tick != _tick:
		_tick = tick
		_update_anchors()
	var beat: float = fposmod(phase * 0.91, 1.0)
	var sweep: float = smoothstep(0.09, 0.69, beat)
	var flash: float = smoothstep(0.57, 0.62, beat) * (1.0 - smoothstep(0.66, 0.82, beat))
	_base.set_tint(Color(0.30, 0.24, 0.92, opacity * 0.40))
	for i: int in range(5):
		_clouds[i].set_tint(Art.electric_cloud_color(phase, i, opacity))
	for i: int in range(6):
		var alpha: float = opacity * (0.37 + 0.40 * exp(-pow((float(i) / 6.0 - sweep) * 4.0, 2.0)) + flash * 0.12)
		_intensities[i] = alpha
		_angles[i * 3] = fposmod(float(_seed + i * 37) * 3.1 + phase * 0.24 * 17.0, TAU)
		_angles[i * 3 + 1] = fposmod(float(_seed + i + 102) * 3.1 + phase * 0.20 * 17.0, TAU)
		_angles[i * 3 + 2] = fposmod(float(_seed + i + 311) * 3.1 + phase * 0.19 * 17.0, TAU)
		_junctions[i].set_tint(Color(0.52, 0.54, 1.0, alpha * 0.77))
		_contacts[i].set_tint(Art.electric_contact_color(alpha, opacity))
	_material.set_shader_parameter("angles", _angles)
	_material.set_shader_parameter("intensities", _intensities)

func _update_anchors() -> void:
	for i: int in range(7):
		var x: float = lerpf(-0.35, 0.35, float(i) / 6.0)
		var y: float = (Fx._hash(_seed + i * 71 + _tick * 13) - 0.5) * 0.10
		_anchors[i] = Vector2(x, y) * _width
	for i: int in range(6):
		var a: Vector2 = _anchors[i]
		var b: Vector2 = _anchors[i + 1]
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var end: Vector2 = b + Vector2((Fx._hash(_seed + i * 11) - 0.5) * _width * 0.18, side * _width * (0.07 + Fx._hash(_seed + i * 19) * 0.07))
		var junction: Vector2 = a.lerp(b, 0.65)
		var tip: Vector2 = end.lerp(junction, 0.30) + Vector2(_width * 0.055 * side, -_width * 0.025)
		var fork: Vector2 = end.lerp(junction, 0.53)
		_endpoints[i * 3] = Vector4(a.x, a.y, b.x, b.y)
		_endpoints[i * 3 + 1] = Vector4(junction.x, junction.y, end.x, end.y)
		_endpoints[i * 3 + 2] = Vector4(fork.x, fork.y, tip.x, tip.y)
		_junctions[i].configure(b, _junctions[i].size, _junctions[i].angle, _junctions[i].tint)
		_contacts[i].configure(b, _contacts[i].size, _contacts[i].angle, _contacts[i].tint)
	_material.set_shader_parameter("endpoints", _endpoints)

func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_clouds.clear()
	_junctions.clear()
	_contacts.clear()
	_anchors.resize(7)
	_endpoints.resize(18)
	_angles.resize(18)
	_intensities.resize(6)
	Fx.prepare()
	_material = ShaderMaterial.new()
	_material.shader = ELECTRIC_SHADER
	_material.set_shader_parameter("tile_width", _width)
	_base = _sprite(Fx._light, Vector2.ZERO, Vector2(_width * 0.87, _width * 0.34), 0.0)
	for i: int in range(5):
		var angle: float = float(i) * 2.399963 + float(_seed % 7) * 0.21
		var at: Vector2 = Vector2(cos(angle), sin(angle) * 0.44) * _width * 0.23
		_clouds.append(_sprite(Fx._clouds[posmod(_seed + i, Fx._clouds.size())], at, Vector2(_width * 0.28, _width * 0.10), angle * 0.1))
	if _meshes.is_empty():
		for i: int in range(6): _meshes.append(_build_mesh(i))
	for i: int in range(6):
		var network := MeshInstance2D.new()
		network.mesh = _meshes[i]
		network.material = _material
		add_child(network)
		RenderingServer.canvas_item_set_custom_rect(network.get_canvas_item(), true, Rect2(Vector2(-_width, -_width), Vector2(_width, _width) * 2.0))
		_junctions.append(_sprite(Fx._light, Vector2.ZERO, Vector2(_width * 0.15, _width * 0.07), 0.0))
		_contacts.append(_sprite(Fx._light, Vector2.ZERO, Vector2(_width * 0.028, _width * 0.017), 0.0))

func _sprite(texture: Texture2D, at: Vector2, size: Vector2, angle: float) -> Particle:
	var sprite := Particle.new()
	sprite.texture = texture
	sprite.configure(at, size, angle, Color.WHITE)
	add_child(sprite)
	return sprite

static func _build_mesh(group: int) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Keep each authored ribbon/core submission separate. Combining overlapping
	# transparent strips into one surface changes native 4×MSAA edge blending.
	var ends := PackedInt32Array()
	for branch: int in range(3):
		var bolt: int = group * 3 + branch
		var start: int = vertices.size()
		for k: int in range(13):
			for side: int in [1, 0, -1]:
				vertices.append(Vector2(k, side))
				colors.append(Color(1.0 if side == 0 else 0.0, 0.5, 0.0, 1.0))
				uvs.append(Vector2(bolt, 0.0))
		for index: int in Art._floor_ribbon_template(13)["indices"]:
			indices.append(start + index)
		ends.append(indices.size())
		# Native antialiased polyline order: middle, left border, right border.
		# The last corner repeats its edge vertex to keep the AA diagonal intact.
		for strip: int in range(3):
			start = vertices.size()
			var sign: int = 1 if strip != 2 else -1
			for cap: int in [-1, 0, 1]:
				var first: int = 0 if cap <= 0 else 12
				var last: int = 12 if cap == 0 else first
				for k: int in range(first, last + 1):
					if cap == 1 and strip > 0:
						_append_core_vertex(vertices, colors, uvs, k, sign, bolt, 0, 0, 1.0)
						_append_core_vertex(vertices, colors, uvs, k, sign, bolt, 1, 1, 0.0)
						_append_core_vertex(vertices, colors, uvs, k, sign, bolt, 1, 0, 0.0)
					else:
						for edge: int in range(2):
							var side: int = (1 if edge == 0 else -1) if strip == 0 else sign
							var border: int = 0 if strip == 0 else edge
							var alpha: float = 1.0 if cap == 0 and border == 0 else 0.0
							_append_core_vertex(vertices, colors, uvs, k, side, bolt, cap, border, alpha)
			for index: int in range(vertices.size() - start - 2):
				indices.append(start + index)
				indices.append(start + index + 1 + index % 2)
				indices.append(start + index + 2 - index % 2)
			ends.append(indices.size())
	var arrays: Array
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	var offset: int = 0
	for end: int in ends:
		arrays[Mesh.ARRAY_INDEX] = indices.slice(offset, end)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		offset = end
	return mesh

static func _append_core_vertex(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, k: int, side: int, bolt: int, cap: int, border: int, alpha: float) -> void:
	vertices.append(Vector2(k, side))
	colors.append(Color(alpha, float(cap + 1) * 0.5, border, 1.0))
	uvs.append(Vector2(bolt, 1.0))
