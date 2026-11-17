extends "res://scripts/room_generator.gd"
## Preserve the pre-tune layout golden for unchanged RNG/placement/loot rules,
## while returning the real capped, scaled production room to every test.
var before_tier_and_cap: Dictionary = {}
func _finalize_difficulty(layout: Dictionary) -> void:
	before_tier_and_cap = layout.duplicate(true)
	super._finalize_difficulty(layout)
