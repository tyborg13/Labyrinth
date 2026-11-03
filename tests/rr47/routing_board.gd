extends "res://scripts/combat_board_view.gd"

## Observe the production callback without issuing renderer commands headless.
var submitted_actor_keys: Array[String]

func _draw_unit_body(unit: Dictionary) -> void:
	submitted_actor_keys.append(str(unit.get("key", "")))
