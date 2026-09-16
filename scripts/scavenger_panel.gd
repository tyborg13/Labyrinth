extends PanelContainer
const Materials = preload("res://scripts/scavenger_materials.gd")
var surface: String = "dialogue"
func _ready() -> void:
	resized.connect(queue_redraw)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
func _draw() -> void:
	Materials.paint(self, surface, Rect2(Vector2.ZERO, size))
