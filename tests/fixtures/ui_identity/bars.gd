extends Control

func _draw() -> void:
	SegmentedHealthBar.draw_bar(self, rect, state) # SITE_R4
	SegmentedHealthBar . draw_bar( # SITE_R4
		self,
		rect,
		state,
	)
	OtherSegmentedHealthBar.draw_bar(self, rect, state)
	OtherBar.draw_bar(self, rect, state)
