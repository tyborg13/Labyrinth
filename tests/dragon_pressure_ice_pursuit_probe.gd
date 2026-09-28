extends "res://tests/dragon_pressure_warning_probe.gd"

## Bounded Ice tuning proof: the live Talon pursuit gains one step while
## the separate fixed trail and the rest of the four-part cycle stay intact.
func _roster() -> Dictionary:
	return {"iskaldra":12}

func _include_grimoire() -> bool:
	return false
