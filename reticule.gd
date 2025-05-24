class_name Reticule extends Area2D

var collision_shape: CollisionShape2D
var color: Color

# Called when the node enters the scene tree for the first time.
func _ready():
	color = Color.RED
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	collision_shape.shape.radius = 10  # Adjust the size as needed
	add_child(collision_shape)
	queue_redraw()  # Ensure _draw() is called initially

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position = get_global_mouse_position()
	queue_redraw()  # Request a redraw to show the collision shape

# Draw the collision shape for debugging
func _draw():
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		draw_circle(Vector2.ZERO, shape.radius, color)  # Draw a semi-transparent red circle
	elif shape is RectangleShape2D:
		draw_rect(Rect2(Vector2.ZERO - shape.extents, shape.extents * 2), color, true)  # Draw a semi-transparent red rectangle
	# Add cases for other shapes if needed
