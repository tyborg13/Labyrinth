extends SceneTree
## Director tool: every card's focus tooltip stack (base cards), one JSON line per panel.
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

func _initialize() -> void:
	var out: Array = []
	for id_var: Variant in Data.cards().keys():
		var id: String = str(id_var)
		var card: Dictionary = Data.card_def(id)
		var leading: Array = []
		if Icons.card_is_rite(card):
			leading.append("rite")
		var entries: Array[Dictionary] = Icons.tooltip_entries_for_rows(Icons.rows_for_card(card), leading)
		for entry: Dictionary in entries:
			out.append({"card": id, "icon": str(entry.get("icon", "")), "glossary_key": str(entry.get("glossary_key", "")), "title": str(entry.get("title", "")), "text": str(entry.get("description", entry.get("tooltip", entry.get("text", ""))))})
	var path: String = OS.get_environment("DUMP_PATH")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("DUMPED %d panels" % out.size())
	quit(0)
