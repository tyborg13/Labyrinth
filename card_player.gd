class_name CardPlayer extends Node2D

var card_pile_ui: CardPileUI
var game_master: GameMaster
var map: TileMap
var currently_selected_card: CardUI
var currently_selected_card_dropzone: CardDropzone
var pixels_per_foot = 14
var reticule: Node2D
var target: Player
var current_health: int = 20  # Starting health
var max_health: int = 20

# Called when the node enters the scene tree for the first time.
func _ready():
	reticule = Reticule.new()
	add_child(reticule)
	
	currently_selected_card = null
	currently_selected_card_dropzone = null
	card_pile_ui = get_node("../../CanvasLayer/BattleUI/Control/MyCardPileUI")
	game_master = get_parent()
	map = get_node("../../TileMap")
	card_pile_ui.connect("card_added_to_dropzone", func(dropzone, card): initiate_target_selection(dropzone,card))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if currently_selected_card != null:
		target = is_target_valid(currently_selected_card)
		queue_redraw()
		
	
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if currently_selected_card != null and target != null:
				print('we actually play the card')
				play_card(currently_selected_card, target)
				get_viewport().set_input_as_handled()
				
	
func initiate_target_selection(dropzone: CardDropzone, card: CardUI):
	currently_selected_card = card
	currently_selected_card_dropzone = dropzone
	
func take_damage(amount: int):
	current_health = max(0, current_health - amount)
	# TODO: Emit signal for UI update
	if current_health <= 0:
		# TODO: Handle player death
		pass

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	# TODO: Emit signal for UI update

func play_card(card: CardUI, target: Player):
	# Check if we can afford the health cost
	if card.card_data.health_cost > current_health:
		# TODO: Show feedback that we can't afford the cost
		return
		
	# Apply health cost
	if card.card_data.health_cost > 0:
		take_damage(card.card_data.health_cost)
	
	# Execute card effect
	match card.card_data.type:
		"attack":
			target.take_damage(card.card_data.power)
		"move":
			# TODO: Implement movement logic
			pass
		"defend":
			# TODO: Implement defense logic
			pass
	
	# Handle card burning
	if card.card_data.burn_after_use:
		card_pile_ui.remove_card_from_game(card)
	else:
		card_pile_ui.set_card_pile(card, CardPileUI.Piles.discard_pile)
	
	end_target_selection()
	
func end_target_selection():
	currently_selected_card = null
	currently_selected_card_dropzone = null
	queue_redraw()
	
func is_target_valid(card: CardUI):
	for character in game_master.all_chars:
		if character.overlaps_area(reticule) && game_master.whose_turn().global_position.distance_to(character.global_position) <= card.card_data.target_range * pixels_per_foot:
			match card.card_data.type:
				"attack":
					if character.attributes.type == "enemy":
						return character
				"move":
					# TODO: Implement movement validation
					return character
				"defend":
					if character.attributes.type == "player":
						return character
	return null
			
func _draw():
	if currently_selected_card != null:
		#var color = target != null if Color.GREEN else Color.RED
		var color
		if target == null:
			color = Color.RED
			reticule.color = Color.RED
		else: 
			color = Color.GREEN
			reticule.color = Color.GREEN
		draw_line(game_master.whose_turn().global_position, get_global_mouse_position(), color, 2)
		#draw_arc(game_master.whose_turn().global_position, get_global_mouse_position().distance_to(game_master.whose_turn().global_position) / 2, 0, PI, 10, color, 2)
	else:
		reticule.color = Color.TRANSPARENT
			
