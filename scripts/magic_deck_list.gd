extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Menu = preload("res://scripts/character_menu_view.gd")

# Both Character and Purge use this ownership projection, ordering, and rows.
static func entries(cards: Array) -> Array[Dictionary]:
	var counts: Dictionary = {}
	for value: Variant in cards:
		var id: String = str(value)
		if Data.magic_card_is_purgeable(id): counts[id] = int(counts.get(id, 0)) + 1
	var result: Array[Dictionary]
	for id: String in counts: result.append({"card_id": id, "count": counts[id]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id: String = str(a["card_id"])
		var b_id: String = str(b["card_id"])
		var a_key: String = "%s/%s/%s" % [Data.card_element(a_id), str(Data.card_def(a_id).get("name", a_id)), a_id]
		var b_key: String = "%s/%s/%s" % [Data.card_element(b_id), str(Data.card_def(b_id).get("name", b_id)), b_id]
		return a_key < b_key
	)
	return result

static func populate(host: Node, list: VBoxContainer, cards: Array, activated: Callable = Callable(), retain: bool = false) -> Dictionary:
	var tiles: Dictionary = {}
	var current: Array[Control]
	var index: int = 0
	for entry: Dictionary in entries(cards):
		var id: String = str(entry["card_id"])
		var constructor: Callable = Callable(host, "_new_magic_card_tile").bind(id, "deck", index, false, false)
		var tile: Control
		if retain:
			tile = host.get("_character_inventory_rows").take("magic/deck/" + id, [Data.card_def(id), entry["count"], host.call("_character_row_common_input")], constructor, Callable(host, "_character_row_can_retain"))
		else: tile = constructor.call()
		tile.name = "MagicDeckRow_" + id
		tile.set("magic_index", index)
		tile.set_meta("magic_copy_count", int(entry["count"]))
		tile.set_meta("purge_requested", activated)
		var strip: Control = tile.get_node("CharacterCardStrip")
		strip.setup(id, str(Data.card_def(id).get("name", id)), int(entry["count"]))
		current.append(tile)
		host.call("_place_character_row", list, tile, index)
		tiles[index] = tile
		index += 1
	host.call("_finish_character_rows", list, current)
	return tiles
