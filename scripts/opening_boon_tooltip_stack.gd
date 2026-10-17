extends "res://scripts/card_focus_tooltip_stack.gd"

## Keep the shared full card glossary below the boon banner and rules.
var minimum_top: float = 0.0

func _follow_target_now() -> void:
	super._follow_target_now()
	if visible: global_position.y = maxf(global_position.y, minimum_top)
