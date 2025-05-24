extends Node2D

# Onready variable to hold the TileMap reference
@onready var tilemap: TileMap = get_node("../Level1Map") as TileMap

func _draw():
	var cell_size = tilemap.tile_set.tile_size
	var rect = tilemap.get_used_rect()
	var color = Color(0.8, 0.8, 0.8, 0.5)  # Light grey color, semi-transparent
	
	var points = []

	for i in range(rect.size.x + 1):
		var x = i * cell_size.x
		points.append(Vector2(x, 0))
		points.append(Vector2(x, rect.size.y * cell_size.y))

	# Create horizontal lines
	for j in range(rect.size.y + 1):
		var y = j * cell_size.y
		points.append(Vector2(0, y))
		points.append(Vector2(rect.size.x * cell_size.x, y))

	# Draw all lines at once
	draw_polyline(points, color, 1.0, true)

func _ready():
	# Ensure the grid is updated when necessary
	queue_redraw()  # Request an update to draw the grid
	#if tilemap:
		#tilemap.connect("changed", _on_TileMap_changed.bind())

func _on_TileMap_changed():
	queue_redraw()  # Redraw grid when the tilemap changes
