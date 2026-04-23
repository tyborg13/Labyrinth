extends RefCounted
class_name RoomIconLibrary

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")

const ICON_COMBAT: String = "combat"
const ICON_START: String = "start"
const ICON_CAMPFIRE: String = "campfire"
const ICON_TREASURE: String = "treasure"
const ICON_BOSS: String = "boss"

const ROOM_TYPE_ICON_PATHS := {
	ICON_START: "res://assets/art/icons/move.png",
	ICON_COMBAT: "res://assets/art/icons/melee.png",
	ICON_CAMPFIRE: "res://assets/art/icons/burn.png",
	ICON_TREASURE: "res://assets/art/tiles/ember_cache.png",
	ICON_BOSS: "res://assets/art/icons/melee.png"
}

static func icon_id_for_room(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", ICON_COMBAT))
	if room_type == ICON_COMBAT:
		var element_id: String = str(room.get("element", ElementData.NONE))
		if ElementData.is_elemental(element_id):
			return element_id
	if ROOM_TYPE_ICON_PATHS.has(room_type):
		return room_type
	return ICON_COMBAT

static func icon_path(icon_id: String) -> String:
	var key: String = str(icon_id)
	if ElementData.is_elemental(key):
		return ElementData.icon_path(key)
	return str(ROOM_TYPE_ICON_PATHS.get(key, ""))

static func icon_texture(icon_id: String) -> Texture2D:
	var path: String = icon_path(icon_id)
	if path.is_empty():
		return null
	return AssetLoader.load_texture(path)

static func all_icon_ids() -> Array[String]:
	var ids: Array[String] = []
	for element_id: String in ElementData.all_elements():
		ids.append(element_id)
	for icon_id: String in ROOM_TYPE_ICON_PATHS.keys():
		ids.append(icon_id)
	return ids
