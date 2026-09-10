extends RefCounted
class_name RoomIconLibrary

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")

const ICON_COMBAT: String = "combat"
const ICON_START: String = "start"
const ICON_CAMPFIRE: String = "campfire"
const ICON_TREASURE: String = "treasure"
const ICON_BOSS: String = "boss"
const ICON_SCAVENGER: String = "scavenger"

const ROOM_TYPE_ICON_PATHS := {
	"start": "res://assets/art/icons/map/lantern.png",
	"combat": "res://assets/art/icons/map/fight.png",
	"campfire": "res://assets/art/icons/map/campfire.png",
	"treasure": "res://assets/art/icons/map/relic.png",
	"scavenger": "res://assets/art/icons/map/scavenger.png",
	"event": "res://assets/art/icons/map/event.png",
	"scout": "res://assets/art/icons/map/scout.png",
	"boss_tharokh": "res://assets/art/icons/map/boss_tharokh.png",
	"boss_vyraketh": "res://assets/art/icons/map/boss_vyraketh.png",
	"boss_vaeloryx": "res://assets/art/icons/map/boss_vaeloryx.png",
	"boss_iskaldra": "res://assets/art/icons/map/boss_iskaldra.png",
	"boss_zekarion": "res://assets/art/icons/map/boss_zekarion.png",
	"boss_noctyrax": "res://assets/art/icons/map/boss_noctyrax.png",
}

static func icon_id_for_room(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", ICON_COMBAT))
	if room_type in ["blacksmith", "arcanist"]:
		room_type = ICON_SCAVENGER
	if room_type == ICON_BOSS:
		return "boss_" + str(room.get("boss_id", "tharokh"))
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
