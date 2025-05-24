class_name GameRound extends Node

var turn_order: Array[Player]
var round_number: int
var initiative_modifier = 6
var whose_turn_index: int

# Called when the node enters the scene tree for the first time
func _ready():
	pass

func _init(players: Array[Player], round_number_: int):
	round_number = round_number_
	turn_order = calculate_turn_order(players)
	whose_turn_index = 0
	turn_order[whose_turn_index].center_camera_on_me()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func calculate_turn_order(players: Array[Player]):
	for p in players:
		p.initiative = p.attributes.speed + randi_range(0, initiative_modifier)
		
	players.sort_custom(func(a, b): return a.initiative > b.initiative)
	print(str(players))
	return players
	
func advance_turn():
	whose_turn_index += 1
	print(str(turn_order[whose_turn_index]))
	turn_order[whose_turn_index].center_camera_on_me()
	
func whose_turn():
	return turn_order[whose_turn_index]
	
func is_round_over():
	return whose_turn_index == turn_order.size() - 1
	
func _to_string():
	return "GameRound(turn_order: %s, round_number: %s, index: %s)" % [str(turn_order), str(round_number), str(whose_turn_index)]
	

	
	
	
