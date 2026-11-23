extends SceneTree
## pla-04: print each Burst card's icon rows as plain text (token icons and
## values), for checking the row fallback and the face's number binding.

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const CARDS: Array = ["cinderline_tempo", "inferno_ritual", "wildfire_halo", "phoenix_cleave", "rekindle_edge", "cinder_second", "discharge", "dust_devil", "flashsteam", "frost_heave", "immolation", "magma_vent", "plasma_arc", "powder_keg", "pyroclasm", "rockburst", "shatter", "shatter_swing", "shattered_reflection", "worldbreak"]

func _initialize() -> void:
	for card_id: String in CARDS:
		var card: Dictionary = GameData.card_def(card_id)
		var rows: Array = ActionIcons.rows_for_card(card)
		print("ROWS %s" % card_id)
		for row: Variant in rows:
			var parts: PackedStringArray = PackedStringArray()
			for token: Variant in row:
				if typeof(token) != TYPE_DICTIONARY:
					continue
				var t: Dictionary = token
				parts.append("%s%s%s%s" % [str(t.get("icon", t.get("kind", ""))), ("=" + str(t.get("value"))) if t.has("value") and t.get("value") != null else "", ("[" + str(t.get("field")) + "]") if t.has("field") else "", ("{" + str(t.get("pattern")) + "}") if t.has("pattern") else ""])
			print("    | " + " · ".join(parts))
		print("    text: " + ActionIcons.plain_text_for_rows(rows).replace("\n", " / "))
	quit(0)
