class_name GameMaster extends Node2D

@export var player_chars: Array[Player]
@export var enemy_chars: Array[Player]
@export var ally_chars: Array[Player]
@export var neutral_chars: Array[Player]
var all_chars: Array[Player]
var this_round: GameRound
var next_round: GameRound
var all_rounds: Array[GameRound]
var turn_order_widget: TurnOrderWidget

func handle_player_turn():
	pass
	
func handle_ai_turn():
	pass

# Called when the node enters the scene tree for the first time.
func _ready():
	all_chars = player_chars + enemy_chars + ally_chars + neutral_chars
	var end_turn_button = get_node("../CanvasLayer/BattleUI/MarginContainer/End Turn")
	turn_order_widget = get_node("../CanvasLayer/BattleUI/TurnOrderWidget")
	end_turn_button.connect("pressed", func(): handle_end_turn())
	# We always want the next 2 rounds initialized
	this_round = GameRound.new(all_chars, 1)
	next_round = GameRound.new(all_chars, 2)
	all_rounds = [this_round, next_round]
	turn_order_widget.update_turn_order(this_round.turn_order.slice(this_round.whose_turn_index) + next_round.turn_order)
	
func progress_to_next_round():
	this_round = next_round
	next_round = GameRound.new(all_chars, all_rounds.size() + 1)
	all_rounds.append(next_round)
	print(str(this_round))
	print(str(next_round))
	
func handle_end_turn():
	if this_round.is_round_over():
		progress_to_next_round()
	else:
		this_round.advance_turn()
		
	turn_order_widget.update_turn_order(this_round.turn_order.slice(this_round.whose_turn_index) + next_round.turn_order)
		
func whose_turn():
	return this_round.whose_turn()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
