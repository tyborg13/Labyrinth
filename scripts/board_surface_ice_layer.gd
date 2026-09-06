extends Node2D

## Fractured translucent plates retain their shaded thickness and frost details.
## Only small reflected glints animate; the material never wobbles like liquid.
const Art = preload("res://scripts/board_surface_presentation.gd")
class Plates extends Node2D:
	var width: float
	var seed: int
	func _draw() -> void:
		Art._draw_ice_material(self, Vector2.ZERO, width, seed)
var _width: float = -1.0
var _seed: int = -1
var _phase: float = INF
var _plates: Plates
func configure(center: Vector2, width: float, seed: int, phase: float) -> void:
	position = center
	if width != _width or seed != _seed:
		_width = width
		_seed = seed
		if _plates == null:
			_plates = Plates.new()
			_plates.show_behind_parent = true
			add_child(_plates)
		_plates.width = width
		_plates.seed = seed
		_plates.queue_redraw()
		# The shimmer uses width and seed too, even when reduced motion keeps
		# the clock unchanged during a reframe or reused-tile configuration.
		_phase = INF
	if _phase == phase: return
	_phase = phase
	queue_redraw()
func _draw() -> void:
	Art._draw_ice_shimmer(self, Vector2.ZERO, _width, _phase, _seed)
