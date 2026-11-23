extends SceneTree
## pla-04: each Burst card's keyword panel stack (icon, body lines), for the
## approved glossary structure override.
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GameData = preload("res://scripts/game_data.gd")

func _initialize() -> void:
	var ids: PackedStringArray = OS.get_environment("PLA04_CARDS").split(",")
	for id: String in ids:
		var card: Dictionary = GameData.card_def(id)
		var leading: Array = []
		if ActionIcons.card_is_rite(card): leading.append("rite")
		var parts: PackedStringArray = PackedStringArray()
		for entry: Dictionary in ActionIcons.tooltip_entries_for_rows(ActionIcons.rows_for_card(card), leading):
			parts.append("%s:%d" % [str(entry["icon"]), str(entry["description"]).split("\n", false).size()])
		print("PANELS %s %s" % [id, " ".join(parts)])
	quit(0)
