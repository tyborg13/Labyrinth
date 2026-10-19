extends "res://scripts/combat_pacing.gd"

## Only the clock and rail tween are replaced; overlap selection and sampling
## execute the production methods, including when loaded from the Git baseline.
var now_usec: int = 0
var orders: Array[Dictionary]

func presentation_usec() -> int:
	return now_usec

func present_turn_order(before: Array, after: Array, defeated: Dictionary = {}) -> void:
	orders.append({"before": before.duplicate(true), "after": after.duplicate(true), "defeated": defeated.duplicate(true)})

func _process(_delta: float) -> void:
	pass
