extends CardUIData

@export var power : int
@export var type : String  # attack, move, skill, etc.
@export var cost : int
@export var health_cost : int = 0
@export var description : String
@export var target_range : int
@export var burn_after_use : bool = false
@export var area_of_effect : int = 0  # 0 means single target
@export var move_distance : int = 0  # For movement cards

func upgrade():
	power += 2
	emit_signal("card_data_updated")

func format_description():
	var desc = description.replace("{value}", "[color=red]%s[/color]" % power)
	if health_cost > 0:
		desc += "\n[color=red]Costs %d health[/color]" % health_cost
	if burn_after_use:
		desc += "\n[color=orange]Burns after use[/color]"
	return desc
	
func _to_string():
	return "CardUIData(name: %s, power: %s, type: %s, cost: %s, health_cost: %s, description: %s, range: %s, burn: %s)" % [
		nice_name, power, type, cost, health_cost, description, target_range, burn_after_use
	]
