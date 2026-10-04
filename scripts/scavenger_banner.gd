extends Control

const Surface = preload("res://scripts/ui_component_surface.gd")
const Signage = preload("res://scripts/scavenger_signage.gd")
# Measured on the 1100x323 raster: rings/twine occupy x=57..122 and
# x=979..1045; the outer 200px bands also contain the complete dowel ends.
const LEFT_MARGIN: float = 200.0
const RIGHT_MARGIN: float = 200.0

var texture: Texture2D

func _ready() -> void:
	texture = Surface.mipmapped_texture(Signage.BANNER_PATH)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func patch_regions() -> Array[Dictionary]:
	var regions: Array[Dictionary]
	if texture == null:
		return regions
	var source_size := Vector2(texture.get_size())
	var fit: float = size.y / source_size.y
	var left_width: float = LEFT_MARGIN * fit
	var right_width: float = RIGHT_MARGIN * fit
	regions.append({
		"source": Rect2(0.0, 0.0, LEFT_MARGIN, source_size.y),
		"destination": Rect2(0.0, 0.0, left_width, size.y),
	})
	regions.append({
		"source": Rect2(LEFT_MARGIN, 0.0, source_size.x - LEFT_MARGIN - RIGHT_MARGIN, source_size.y),
		"destination": Rect2(left_width, 0.0, size.x - left_width - right_width, size.y),
	})
	regions.append({
		"source": Rect2(source_size.x - RIGHT_MARGIN, 0.0, RIGHT_MARGIN, source_size.y),
		"destination": Rect2(size.x - right_width, 0.0, right_width, size.y),
	})
	return regions

func _draw() -> void:
	for region: Dictionary in patch_regions():
		draw_texture_rect_region(texture, region["destination"], region["source"])
