class_name TurnOrderWidget extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
# Function to update the turn order display
func update_turn_order(turn_order: Array[Player]):
	size_flags_vertical = Control.SIZE_FILL * .1
	# First, clear the current contents
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# Now, add new entries for each player in the turn order
	for player in turn_order:
		var player_container = VBoxContainer.new()
		player_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_container.size_flags_vertical = Control.SIZE_FILL
		add_child(player_container)

		var icon = TextureRect.new()
		player_container.add_child(icon)
		icon.texture = load(player.icon_path)
		icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		# Set stretch mode to keep the aspect ratio and center the image
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		

		#var label = Label.new()
		#label.text = player.attributes.name
		#player_container.add_child(label)
