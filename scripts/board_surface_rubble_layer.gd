extends Node2D

## Rubble never animates. Keep its original textured/shaded draw commands alive
## beneath its owning tile instead of rebuilding them with the elemental loop.
## Separate floor/chunk canvases let retained Ice sit between them.
const SurfaceArt = preload("res://scripts/board_surface_presentation.gd")
var _width: float = -1.0
var _seed: int = -1
var floor_only: bool = false
var chunks_only: bool = false

func configure(center: Vector2, width: float, seed: int, only_chunks: bool = false) -> void:
	position = center
	if width == _width and seed == _seed and only_chunks == chunks_only:
		return
	_width = width
	_seed = seed
	chunks_only = only_chunks
	queue_redraw()

func _draw() -> void:
	# The perf-09 oracle pairs this layer's default combined mode with frozen
	# surface art. Resolve the new split entry points only in their new modes.
	var art_script: Script = SurfaceArt
	if floor_only: art_script.call("_draw_rubble_floor", self, Vector2.ZERO, _width, _seed)
	elif chunks_only: art_script.call("_draw_rubble_chunks", self, Vector2.ZERO, _width, _seed)
	else: SurfaceArt._draw_rubble(self, Vector2.ZERO, _width, _seed)
