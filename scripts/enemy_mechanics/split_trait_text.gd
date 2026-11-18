extends RefCounted

# Presentation only: the resolver continues to own death_spawn and its placement.
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const TraitText = preload("res://scripts/enemy_mechanics/burst_trait_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const BurstView = preload("res://scripts/enemy_mechanics/death_burst_view.gd")

static func trait_token(unit: Dictionary) -> Dictionary:
	var spawn: Dictionary = Data.enemies().get(str(unit.get("type", "")), {}).get("death_spawn", {})
	if str(spawn.get("type", "")) != "split": return {}
	var count: int = int(spawn.get("count", 0))
	var enemy_name: String = str(Data.enemies().get(str(spawn.get("enemy_type", "")), {}).get("name", ""))
	if count != 1: enemy_name += "s"
	var distance: int = maxi(1, int(spawn.get("radius", 1)))
	return Icons.icon_text_token("splits", "Splits %d" % count, "When it dies, it splits into %d %s within %d tile%s." % [count, enemy_name, distance, "" if distance == 1 else "s"])

static func append_tag(tags: Array, enemy_type: String) -> Array:
	var token: Dictionary = trait_token({"type": enemy_type})
	if not token.is_empty(): tags.append({"text": token["value"], "icon_key": "splits", "tooltip": token["tooltip"]})
	return tags

static func append_inspection(content: Control, unit: Dictionary, builder: Callable) -> void:
	var token: Dictionary = trait_token(unit)
	if token.is_empty(): return
	var row: Control = builder.call(token)
	# Keep all existing Burst node IDs intact while naming this distinct trait.
	for node: Node in row.find_children("EnemyBurstTrait*", "", true, false):
		node.name = str(node.name).replace("Burst", "Split")
	row.name = "EnemySplitTrait"
	content.add_child(row)

static func append_rows(rows: Array, unit: Dictionary, font_size: int) -> void:
	var token: Dictionary = trait_token(unit)
	if token.is_empty(): return
	rows.append([token])
	for line: String in TraitText.lines(str(token["tooltip"]), Typography.ui_font(), font_size):
		rows.append([Icons.text_token(line)])

static func badges(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var token: Dictionary = trait_token(unit)
	if int(unit.get("hp", 0)) > 0 and not token.is_empty():
		var spawn: Dictionary = Data.enemies()[str(unit["type"])]["death_spawn"]
		result.append({"status_class": "trait", "icon": "splits", "count": int(spawn["count"]), "icon_tint": Color.WHITE,
			"fill": BurstView.FIRE, "border": BurstView.FIRE, "tooltip": str(token["value"]) + "\n" + str(token["tooltip"])})
	return result
