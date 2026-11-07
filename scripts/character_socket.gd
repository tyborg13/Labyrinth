extends "res://scripts/ui_socket.gd"

# Only Character's empty sockets consolidate their sixteen still arc commands.
# Keep the shared socket's children, layout, materials and input implementation.
const EmptyDrawing = preload("res://scripts/character_socket_drawing.gd")
var _empty_arcs := preload("res://scripts/card_triangle_batch.gd").new()

func _draw() -> void:
	if _icon.texture != null:
		super._draw()
	else:
		EmptyDrawing.draw_empty(self, _empty_arcs)

class Close extends "res://scripts/ui_close_socket.gd":
	var _empty_arcs := preload("res://scripts/card_triangle_batch.gd").new()
	func _draw() -> void:
		if _icon.texture != null:
			super._draw()
		else:
			preload("res://scripts/character_socket_drawing.gd").draw_empty(self, _empty_arcs)
