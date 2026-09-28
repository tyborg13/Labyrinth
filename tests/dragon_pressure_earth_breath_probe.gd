extends "res://tests/dragon_pressure_warning_probe.gd"

## Bounded Earth tuning proof: retained spires now reach two cells during
## Breath, while Claw and Faultline preserve their different payoff rules.
func _roster() -> Dictionary:
	return {"tharokh":8}

func _grimoire_entries() -> Array[String]:
	var result: Array[String]
	result.assign(["combat:worldspines"])
	return result
