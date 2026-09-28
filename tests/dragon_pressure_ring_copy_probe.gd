extends "res://tests/dragon_pressure_warning_probe.gd"

## Bounded ring-copy delta proof. Reuse the same four resolver-backed Air
## warning states; no fixture or geometry changes accompany this text repair.
const Icons = preload("res://scripts/action_icon_library.gd")

func _roster() -> Dictionary:
	return {"vaeloryx":16}

func _include_grimoire() -> bool:
	return false

func _extra_assertions() -> void:
	var ring_count: int = 0
	for boss_id: String in ROSTER:
		for intent: Dictionary in Data.enemy_def(boss_id).get("intents", []):
			for action: Dictionary in intent.get("actions", []):
				if Held.shape(action) != "ring": continue
				ring_count += 1
				var tokens: Array = Icons.tokens_for_guardian_rule(action)
				var text: String = str(tokens)
				_expect(not text.contains("Safe within"), str(intent["id"])+" does not promise safety from other attacks")
				_expect(text.contains("Ring"), str(intent["id"])+" retains explicit ring geometry")
				if action.has("range_status"):
					_expect(text.contains("Mantle fuels range") and text.contains("Break layers"), "Mantle fuel text and its counterplay tooltip are preserved")
				if str(intent["id"]) == "eye_of_storm":
					_expect(text.contains("Ring 2–5"), "Eye retains its exact 2–5 range")
	_expect(ring_count >= 3, "The ring-copy check covers the authored Ice and Air ring attacks")
