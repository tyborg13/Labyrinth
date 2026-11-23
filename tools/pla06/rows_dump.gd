extends SceneTree
## pla-06: print each Ice/Stagger card's icon rows as plain text (token icons and
## values), for checking the row fallback and the face's number binding.

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const CARDS: Array = ["frostbolt", "icebound_chains", "rime_shard", "cold_grasp", "icicle_lance", "shatterline", "glacier_pin", "rimeplate_lock", "locket_chill", "frost_snare", "cold_shoulder", "frost_nova", "rime_hack", "shiver_shot", "rimefang", "sleet_squall", "petrify", "hush_of_winter", "white_silence", "frozen_bite", "threadbare_guard", "rite_of_hoarfrost", "hoarfrost_ward", "rime_step", "smelling_salts"]

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
