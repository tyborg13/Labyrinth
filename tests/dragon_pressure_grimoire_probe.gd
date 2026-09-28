extends "res://tests/dragon_pressure_warning_probe.gd"
## Copy-only delta: production Grimoire pages for the updated pressure rules.
func _roster() -> Dictionary:
	return {}

func _grimoire_entries() -> Array[String]:
	var result: Array[String]
	result.assign([
		"enemy:zekarion", "combat:worldspines", "combat:cinder_marks",
		"combat:hollow_gale", "combat:crystal_armor", "enemy:tharokh",
		"enemy:vyraketh", "enemy:vaeloryx", "enemy:iskaldra"
	])
	return result
