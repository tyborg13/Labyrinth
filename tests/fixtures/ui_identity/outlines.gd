extends Control

func _draw() -> void:
	draw_rect(rect, accent, false) # SITE_R3
	self.draw_rect( # SITE_R3
		Rect2(Vector2(1, 2), Vector2(3, 4)),
		colour_for({"values": [1, 2, 3]}),
		false,
		1.0
	)
	canvas.draw_rect(rect, colour, false, 1.0, true) # SITE_R3
	draw_rect(rect, colour, true)
	draw_rect(rect, colour)
	draw_rect(rect, colour, filled)
	draw_rect(rect, colour, true, false)
	custom_draw_rect(rect, colour, false)

func draw_rect(rect, colour, false_value) -> void:
	pass
