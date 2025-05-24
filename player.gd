class_name Player extends Area2D

var click_pos
var card_clicked
var card_dropped
@export var speed = 200 # How fast the player will move (pixels/sec).
@export var icon_path = ""
var tile_size = 32
var screen_size # Size of the game window.
var health_bar: ProgressBar

var camera: Camera2D
var game_master: GameMaster

var key_dir_inputs = {"right": Vector2.RIGHT,
					  "left": Vector2.LEFT,
					  "up": Vector2.UP,
					  "down": Vector2.DOWN}
					
# Character stats
@export var attributes: CharacterAttributes
var initiative
var current_health: int

# Called when the node enters the scene tree for the first time.
func _ready():
	camera = get_node("../Player/ZoomingCamera2D")
	game_master = get_node("../../GameMaster")
	print(str(camera))
	card_clicked = Time.get_ticks_msec()
	card_dropped = Time.get_ticks_msec()
	var card_pile_ui = get_node("/root/Level1/CanvasLayer/BattleUI/Control/MyCardPileUI")
	card_pile_ui.connect("card_clicked", func(_c): card_clicked = Time.get_ticks_msec())
	card_pile_ui.connect("card_dropped", func(_c): card_dropped = Time.get_ticks_msec())
	screen_size = get_viewport_rect().size
	click_pos = position
	current_health = attributes.health
	
	#Initialize health bar (TODO: use a TextureProgressBar to make pretty)
	health_bar = $ProgressBar
	health_bar.min_value = 0
	health_bar.max_value = attributes.health
	health_bar.value = current_health

	# Create and set the theme
	var theme = Theme.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.5, 0.0)  # Green background for health bar
	theme.set_stylebox("fg", "ProgressBar", style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.5, 0.0, 0.0)  # Red background for empty part
	theme.set_stylebox("bg", "ProgressBar", bg_style)

	health_bar.theme = theme
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if attributes.type == "player":
		perform_mouse_based_movement(delta)
		perform_keyboard_based_movement(delta)
	else:
		handle_ai_turn()
		
func center_camera_on_me():
	camera.reparent(self, false)
	camera.position = Vector2.ZERO
	
func take_damage(amount):
	current_health -= amount
	current_health = max(current_health, 0)  # Ensure health doesn't go below 0
	health_bar.value = current_health
	print("current_health = " + str(current_health) + ", max health = " + str(attributes.health))
	
func handle_ai_turn():
	$AnimatedSprite2D.animation = "idle"
	$AnimatedSprite2D.play()
	
func decide_walk_animation(click_x, pos_x, click_y, pos_y):
	if abs(click_x - pos_x) > abs(click_y - pos_y):
		if click_x > pos_x:
			$AnimatedSprite2D.animation = "walk_right"
		else:
			$AnimatedSprite2D.animation = "walk_left"
	else:
		if click_y > pos_y:
			$AnimatedSprite2D.animation = "walk_down"
		else:
			$AnimatedSprite2D.animation = "walk_up"
			
		
func perform_mouse_based_movement(delta):
	var mouse_clicked = false

	if Input.is_action_pressed("mouse_based_movement") && !(card_clicked > card_dropped):
		click_pos = get_global_mouse_position()
		mouse_clicked = true
		
	move_to_new_position(position, click_pos, mouse_clicked, delta)
	
		
func perform_keyboard_based_movement(delta):
	var key_pressed = false
	
	for dir in key_dir_inputs.keys():
		if Input.is_action_pressed(dir):
			click_pos = position + (key_dir_inputs[dir] * tile_size)
			key_pressed = true
			
	move_to_new_position(position, click_pos, key_pressed, delta)
			 

func move_to_new_position(curr_pos, new_pos, movement_input, delta):
	var velocity = Vector2.ZERO # The player's movement vector.
	if new_pos.y > curr_pos.y:
		velocity.y += 1
		if movement_input:
			decide_walk_animation(new_pos.x, position.x, new_pos.y, position.y)
	if new_pos.y < curr_pos.y:
		velocity.y -= 1
		if movement_input:
			decide_walk_animation(new_pos.x, position.x, new_pos.y, position.y)
	if new_pos.x > curr_pos.x:
		velocity.x += 1
		if movement_input:
			decide_walk_animation(new_pos.x, position.x, new_pos.y, position.y)
	if new_pos.x < curr_pos.x:
		velocity.x -= 1
		if movement_input:
			decide_walk_animation(new_pos.x, position.x, new_pos.y, position.y)
			
	if position.distance_to(click_pos) < 3:
		velocity.x = 0
		velocity.y = 0

	if velocity.y == 0 && velocity.x == 0:
		$AnimatedSprite2D.animation = "idle"
		
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		
	position += velocity * delta
	
	$AnimatedSprite2D.play()
	
