extends RefCounted

const Pixel = preload("res://scripts/pixel_fx_layer.gd")

## Integer framebuffer cell size and nearest authored sheet index.
static func choose(tile_px: float, render_height: int, tile_widths: PackedInt32Array) -> Vector2i:
	var cell_px: int = Pixel.grid_px(render_height)
	if tile_px / cell_px > 96.0:
		cell_px = ceili(tile_px / 96.0)
	elif tile_px / cell_px < 40.0:
		cell_px = maxi(1, floori(tile_px / 40.0))
	var nearest: int = 0
	var cells: float = tile_px / cell_px
	for index: int in range(1, tile_widths.size()):
		if absf(tile_widths[index] - cells) < absf(tile_widths[nearest] - cells):
			nearest = index
	return Vector2i(cell_px, nearest)
