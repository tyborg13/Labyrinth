extends RefCounted
class_name MusicLibrary

const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")

const GENERIC_COMBAT_TRACK_ID: String = "combat.generic"
const FIRE_COMBAT_TRACK_ID: String = "combat.fire"
const ICE_COMBAT_TRACK_ID: String = "combat.ice"
const LIGHTNING_COMBAT_TRACK_ID: String = "combat.lightning"
const AIR_COMBAT_TRACK_ID: String = "combat.air"
const EARTH_COMBAT_TRACK_ID: String = "combat.earth"
const ZEKARION_BOSS_TRACK_ID: String = "boss.zekarion"
const RELIC_ROOM_TRACK_ID: String = "room.relic"

const TRACKS: Dictionary = {
	GENERIC_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/generic_combat.wav",
		"volume_db": -12.0
	},
	FIRE_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/fire_combat.wav",
		"volume_db": -12.0
	},
	ICE_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/ice_combat.wav",
		"volume_db": -12.0
	},
	LIGHTNING_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/lightning_combat.wav",
		"volume_db": -12.0
	},
	AIR_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/air_combat.wav",
		"volume_db": -12.0
	},
	EARTH_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/earth_combat.wav",
		"volume_db": -12.0
	},
	ZEKARION_BOSS_TRACK_ID: {
		"path": "res://assets/audio/music/zekarion_boss.wav",
		"volume_db": -12.0
	},
	RELIC_ROOM_TRACK_ID: {
		"path": "res://assets/audio/music/relic_room_loop.wav",
		"volume_db": -13.0
	}
}

const ROOM_TYPE_TRACKS: Dictionary = {
	"combat": GENERIC_COMBAT_TRACK_ID,
	"boss": GENERIC_COMBAT_TRACK_ID,
	"treasure": RELIC_ROOM_TRACK_ID,
	"blacksmith": RELIC_ROOM_TRACK_ID,
	"arcanist": RELIC_ROOM_TRACK_ID
}

const BOSS_TRACKS: Dictionary = {
	"zekarion": ZEKARION_BOSS_TRACK_ID
}

const ELEMENT_TRACKS: Dictionary = {
	ElementData.FIRE: FIRE_COMBAT_TRACK_ID,
	ElementData.ICE: ICE_COMBAT_TRACK_ID,
	ElementData.LIGHTNING: LIGHTNING_COMBAT_TRACK_ID,
	ElementData.AIR: AIR_COMBAT_TRACK_ID,
	ElementData.EARTH: EARTH_COMBAT_TRACK_ID
}
const MODE_TRACKS: Dictionary = {
	"reward": RELIC_ROOM_TRACK_ID,
	"treasure": RELIC_ROOM_TRACK_ID
}

static func entry_for_context(mode: String, room: Dictionary, combat_state: Dictionary = {}) -> Dictionary:
	var track_id: String = _track_id_for_context(mode, room, combat_state)
	if track_id.is_empty():
		return {}
	return entry(track_id)

static func entry(track_id: String) -> Dictionary:
	if not TRACKS.has(track_id):
		return {}
	var result: Dictionary = (TRACKS.get(track_id, {}) as Dictionary).duplicate(true)
	result["id"] = track_id
	return result

static func _track_id_for_context(mode: String, room: Dictionary, combat_state: Dictionary = {}) -> String:
	if MODE_TRACKS.has(mode):
		return str(MODE_TRACKS.get(mode, ""))
	if mode == "room":
		var resting_room_type: String = str(room.get("type", ""))
		if bool(room.get("cleared", false)) and resting_room_type in ["combat", "boss"]:
			return RELIC_ROOM_TRACK_ID
		var resting_element_track_id: String = _element_track_id(resting_room_type, str(room.get("element", "")))
		if not resting_element_track_id.is_empty():
			return resting_element_track_id
		if ROOM_TYPE_TRACKS.has(resting_room_type):
			return str(ROOM_TYPE_TRACKS.get(resting_room_type, ""))
		return ""
	if mode != "combat":
		return ""
	var room_type: String = str(room.get("type", combat_state.get("room_type", "")))
	var element_id: String = str(room.get("element", combat_state.get("room_element", "")))
	var boss_track_id: String = _boss_track_id(room, combat_state)
	if not boss_track_id.is_empty():
		return boss_track_id
	var element_track_id: String = _element_track_id(room_type, element_id)
	if not element_track_id.is_empty():
		return element_track_id
	return str(ROOM_TYPE_TRACKS.get(room_type, ROOM_TYPE_TRACKS.get("combat", "")))

static func _element_track_id(room_type: String, element_id: String) -> String:
	var elemental_key: String = "%s:%s" % [room_type, element_id]
	if ELEMENT_TRACKS.has(elemental_key):
		return str(ELEMENT_TRACKS.get(elemental_key, ""))
	if room_type == "combat" and ELEMENT_TRACKS.has(element_id):
		return str(ELEMENT_TRACKS.get(element_id, ""))
	return ""

static func _boss_track_id(room: Dictionary, combat_state: Dictionary) -> String:
	if str(room.get("type", combat_state.get("room_type", ""))) == "boss":
		var room_boss_id: String = str(room.get("boss_id", combat_state.get("boss_id", "")))
		if BOSS_TRACKS.has(room_boss_id):
			return str(BOSS_TRACKS.get(room_boss_id, ""))
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		var enemy_type: String = str(enemy.get("type", ""))
		if bool(GameData.enemy_def(enemy_type).get("boss_bar", false)):
			if BOSS_TRACKS.has(enemy_type):
				return str(BOSS_TRACKS.get(enemy_type, ""))
			return str(ROOM_TYPE_TRACKS.get("boss", ""))
	return ""
