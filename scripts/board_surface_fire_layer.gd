extends Node2D

## Retain the exact spell cloud/glow quads. Only transform/alpha and tongue
## vertices change; the original per-tongue painter order remains intact.
const Art = preload("res://scripts/board_surface_presentation.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")

class Tongue extends Node2D:
	var width: float
	var index: int
	var height_base: float
	var phase: float = INF
	var _drawn_phase: float = INF
	func configure(next_phase: float) -> void:
		if next_phase == phase: return
		phase = next_phase
		queue_redraw()
	func _draw() -> void:
		var points := PackedVector2Array()
		points.resize(9)
		var height: float = height_base * (0.9 + 0.1 * sin(phase * 3.4 + index))
		for k: int in range(9):
			var u: float = float(k) / 8.0
			var sway: float = sin(phase * 3.0 + index * 1.7 - u * 3.2) * u * width * 0.026
			points[k] = Vector2(sway, -u * height)
		Art._floor_ribbon_pair(self, points, width * 0.037, Color(1.0, 0.23, 0.018, 0.88), width * 0.019, Color(1.0, 0.77, 0.18, 0.91))
		_drawn_phase = phase

var _width: float = -1.0
var _seed: int = -1
var _phase: float = INF
var _reduced: bool = false
var _base: Sprite2D
var _pockets: Array[Dictionary]

func configure(center: Vector2, width: float, seed: int, phase: float, reduced: bool) -> void:
	position = center
	if width != _width or seed != _seed:
		_width = width
		_seed = seed
		_build()
		_phase = INF
	if phase == _phase and reduced == _reduced: return
	_phase = phase
	_reduced = reduced
	var pulse: float = 0.88 + sin(phase * 2.7) * 0.12
	_base.modulate = Color(1.0, 0.24, 0.025, 0.32 * pulse)
	for i: int in range(6):
		var pocket: Dictionary = _pockets[i]
		var at: Vector2 = pocket["at"]
		var age: float = 0.4 if reduced else fposmod(phase * 0.55 + float(i) * 0.173, 1.0)
		var opacity: float = sin(age * PI) * 0.32 + 0.10
		var lift: float = width * (0.025 + age * 0.12)
		var size: Vector2 = Vector2(width * 0.12, width * (0.10 + age * 0.13))
		_pose(pocket["puff"], at - Vector2(0, lift), size, sin(phase + i) * 0.12, Color(1.0, 0.30, 0.025, opacity))
		_pose(pocket["core"], at - Vector2(0, lift * 0.65), size * Vector2(0.53, 0.58), 0.0, Color(1.0, 0.83, 0.31, opacity * 0.94))
		(pocket["tongue"] as Tongue).configure(phase)
		if pocket.has("ember"):
			var ember_age: float = 0.5 if reduced else fposmod(phase * 0.45 + i * 0.23, 1.0)
			var ember: Vector2 = at + Vector2(sin(phase + i) * width * 0.035, -width * (0.10 + ember_age * 0.12))
			_pose(pocket["ember"], ember, Vector2(width * 0.024, width * 0.018), 0.0, Color(1.0, 0.68, 0.16, sin(ember_age * PI) * 0.72))

func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	add_child(sprite)
	return sprite

func _pose(sprite: Sprite2D, at: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	sprite.position = at
	sprite.scale = size / sprite.texture.get_size()
	sprite.rotation = angle
	sprite.modulate = tint
	sprite.visible = tint.a > 0.001 and size.x > 0.01 and size.y > 0.01

func _build() -> void:
	for item: Node in get_children():
		remove_child(item)
		item.queue_free()
	_pockets.clear()
	Fx.prepare()
	_base = _sprite(Fx._light)
	_pose(_base, Vector2.ZERO, Vector2(_width * 0.92, _width * 0.36), 0.0, Color.WHITE)
	for i: int in range(6):
		var angle: float = float(i) * 2.399963 + float(_seed) * 0.01
		var radius: float = _width * (0.10 + Fx._hash(_seed + i) * 0.22)
		var at := Vector2(cos(angle) * radius, sin(angle) * radius * 0.46)
		var pocket: Dictionary = {"at": at}
		pocket["puff"] = _sprite(Fx._clouds[posmod(_seed + i, Fx._clouds.size())])
		pocket["core"] = _sprite(Fx._clouds[posmod(_seed + i + 1, Fx._clouds.size())])
		var glow: Sprite2D = _sprite(Fx._light)
		_pose(glow, at, Vector2(_width * 0.10, _width * 0.035), 0.0, Color(1.0, 0.48, 0.08, 0.62))
		var tongue := Tongue.new()
		tongue.position = at
		tongue.width = _width
		tongue.index = i
		tongue.height_base = _width * (0.12 + Fx._hash(_seed + i + 57) * 0.065)
		add_child(tongue)
		pocket["tongue"] = tongue
		if i % 2 == 0: pocket["ember"] = _sprite(Fx._light)
		_pockets.append(pocket)
