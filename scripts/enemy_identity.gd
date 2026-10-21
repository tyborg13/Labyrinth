extends RefCounted

const Data = preload("res://scripts/game_data.gd")

# Per-instance titles never mutate the shared enemy definition or save ids.
static func display_name(enemy: Dictionary, definition: Dictionary = {}) -> String:
	if enemy.has("display_name"): return str(enemy["display_name"])
	# Retained render/projection callers already own this definition. Reuse it
	# rather than deep-copying every intent just to read an unchanged name.
	if definition.is_empty(): definition = Data.enemy_def(str(enemy.get("type", "")))
	return str(definition.get("name", "Enemy"))

static func running_name(title: String) -> String:
	return "the " + title.substr(4) if title.begins_with("The ") else title
