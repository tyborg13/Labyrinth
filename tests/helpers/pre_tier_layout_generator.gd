extends "res://scripts/room_generator.gd"
## Preserve the pre-tune layout golden for unchanged RNG/placement/loot rules,
## while returning the real capped, scaled production room to every test.
var before_tier_and_cap: Dictionary = {}
func _finalize_difficulty(layout: Dictionary) -> void:
	before_tier_and_cap = layout.duplicate(true)
	super._finalize_difficulty(layout)

func legacy_layout_digest() -> String:
	var layout: Dictionary = before_tier_and_cap.duplicate(true)
	var objective: Dictionary = layout["objective"]
	if objective["type"] == "kill_all":
		# txt-20 changes just this sentence (R11). Require the live copy before
		# comparing every other byte with the historical placement golden.
		if objective.get("description") != "Defeat each enemy.": return ""
		objective["description"] = "Defeat every enemy."
	return var_to_bytes(layout).hex_encode().sha256_text()
