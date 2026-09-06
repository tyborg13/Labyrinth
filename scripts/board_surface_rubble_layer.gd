extends Node2D

## Rubble never animates. Keep its original textured/shaded draw commands alive
## beneath its owning tile instead of rebuilding them with the elemental loop.
const SurfaceArt = preload("res://scripts/board_surface_presentation.gd")
var _width: float = -1.0
var _seed: int = -1

func configure(center: Vector2, width: float, seed: int) -> void:
	position = center
	if width == _width and seed == _seed:
		return
	_width = width
	_seed = seed
	queue_redraw()

func _draw() -> void:
	SurfaceArt._draw_rubble(self, Vector2.ZERO, _width, _seed)
