extends Camera2D

# Define the rate at which zoom changes per scroll step
var zoom_step = 0.1
# Define the maximum and minimum zoom levels
var max_zoom = 2.0
var min_zoom = 0.5

func _ready():
	# Optional: Set the initial zoom level if needed
	zoom = Vector2(1, 1)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom in
			zoom.x = max(min_zoom, zoom.x - zoom_step)
			zoom.y = max(min_zoom, zoom.y - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom out
			zoom.x = min(max_zoom, zoom.x + zoom_step)
			zoom.y = min(max_zoom, zoom.y + zoom_step)
