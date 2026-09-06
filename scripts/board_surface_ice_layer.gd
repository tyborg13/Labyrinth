extends Node2D

## Ice geometry is fixed. Its original facet/crack/glint opacity changes on every
## frame, while retained native CanvasItems preserve texture, alpha and draw order.
const Art = preload("res://scripts/board_surface_presentation.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")

class Command extends Node2D:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

var _width: float = -1.0
var _seed: int = -1
var _facets: Array[Node2D]
var _cracks: Array[Node2D]
var _glint: Node2D

func configure(center: Vector2, width: float, seed: int, phase: float) -> void:
	position = center
	if width != _width or seed != _seed:
		_width = width
		_seed = seed
		_build()
	for index: int in range(_facets.size()):
		var edge: int = index / 3
		var cluster: int = index % 3
		_facets[index].modulate.a = 0.42 + 0.14 * sin(phase * 0.65 + cluster + edge)
	for index: int in range(_cracks.size()):
		_cracks[index].modulate.a = 0.48 + sin(phase * 0.6 + index) * 0.10
	_glint.modulate.a = 0.28 + sin(phase * 0.7) * 0.10

func _command(paint: Callable) -> Node2D:
	var item := Command.new()
	item.paint = paint
	add_child(item)
	return item

func _build() -> void:
	for item: Node in get_children():
		remove_child(item)
		item.queue_free()
	_facets.clear()
	_cracks.clear()
	var p := Vector2.ZERO
	var w: float = _width
	var seed: int = _seed
	var outline: PackedVector2Array = Art._diamond(p, w * 0.43, w * 0.205)
	_command(func(c: CanvasItem) -> void:
		c.draw_polygon(outline, PackedColorArray([Color(0.18, 0.53, 0.67, 0.25)]))
		Fx._glow(c, p, Vector2(w * 0.81, w * 0.30), Color(0.45, 0.83, 1.0, 0.24))
	)
	for edge: int in range(4):
		var a: Vector2 = outline[edge]
		var b: Vector2 = outline[(edge + 1) % 4]
		for cluster: int in range(3):
			var grain: int = seed + edge * 29 + cluster * 71
			var u: float = (float(cluster) + 0.3 + Fx._hash(grain) * 0.4) / 3.0
			var at: Vector2 = a.lerp(b, u).lerp(p, 0.035 + Fx._hash(grain + 1) * 0.05)
			_command(func(c: CanvasItem) -> void:
				Fx._puff(c, at, Vector2(w * 0.14, w * 0.035), (b - a).angle(), Color(0.67, 0.89, 0.98, 0.28), grain)
			)
			var radius: float = w * (0.010 + Fx._hash(grain + 2) * 0.008)
			var angle: float = -PI * 0.5 + (Fx._hash(grain + 3) - 0.5) * 0.9
			_facets.append(_command(func(c: CanvasItem) -> void:
				Fx._fragment(c, at, radius, angle, Color(0.52, 0.82, 0.94, 1.0), true)
			))
	for i: int in range(5):
		var angle: float = float(i) * 1.2566 + float(seed % 9) * 0.11
		var end: Vector2 = p + Vector2(cos(angle) * w * 0.32, sin(angle) * w * 0.15)
		var joint: Vector2 = p.lerp(end, 0.54) + Vector2(w * 0.025 * sin(angle * 3.0), 0)
		var crack := PackedVector2Array([p, joint, end])
		_command(func(c: CanvasItem) -> void:
			c.draw_polyline(crack, Color(0.24, 0.57, 0.69, 0.65), maxf(0.7, w * 0.009), true)
		)
		_cracks.append(_command(func(c: CanvasItem) -> void:
			c.draw_polyline(crack, Color(0.79, 0.96, 1.0, 1.0), maxf(0.5, w * 0.0035), true)
		))
	_glint = _command(func(c: CanvasItem) -> void:
		Fx._glow(c, p + Vector2(-w * 0.18, -w * 0.04), Vector2(w * 0.20, w * 0.035), Color(0.79, 0.96, 1.0, 1.0))
	)
