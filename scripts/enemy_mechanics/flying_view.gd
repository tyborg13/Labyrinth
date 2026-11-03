extends RefCounted

const Rules = preload("res://scripts/enemy_mechanics/flying.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Data = preload("res://scripts/game_data.gd")

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if Rules.flying(unit):
		var color := Color(str(Data.enemy_def(str(unit["type"]))["accent"]))
		result.append({"status_class": "trait", "icon": "flying", "count": 0, "fill": color, "border": color, "icon_tint": Color.WHITE, "tooltip": Icons.tooltip("flying")})
	return result
