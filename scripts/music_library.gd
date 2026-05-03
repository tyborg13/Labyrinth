extends RefCounted
class_name MusicLibrary

const GameData = preload("res://scripts/game_data.gd")

const GENERIC_COMBAT_TRACK_ID: String = "combat.generic"
const ZEKARION_BOSS_TRACK_ID: String = "boss.zekarion"

const TRACKS: Dictionary = {
	GENERIC_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/generic_combat.wav",
		"volume_db": -12.0
	},
	ZEKARION_BOSS_TRACK_ID: {
		"path": "res://assets/audio/music/zekarion_boss.wav",
		"volume_db": -12.0
	}
}

const ROOM_TYPE_TRACKS: Dictionary = {
	"combat": GENERIC_COMBAT_TRACK_ID,
	"boss": GENERIC_COMBAT_TRACK_ID
}

const BOSS_TRACKS: Dictionary = {
	"zekarion": ZEKARION_BOSS_TRACK_ID
}

const ELEMENT_TRACKS: Dictionary = {}
const MODE_TRACKS: Dictionary = {}

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
	if mode != "combat":
		return ""
	var room_type: String = str(room.get("type", combat_state.get("room_type", "")))
	var element_id: String = str(room.get("element", combat_state.get("room_element", "")))
	var boss_track_id: String = _boss_track_id(room, combat_state)
	if not boss_track_id.is_empty():
		return boss_track_id
	var elemental_key: String = "%s:%s" % [room_type, element_id]
	if ELEMENT_TRACKS.has(elemental_key):
		return str(ELEMENT_TRACKS.get(elemental_key, ""))
	if ELEMENT_TRACKS.has(element_id):
		return str(ELEMENT_TRACKS.get(element_id, ""))
	return str(ROOM_TYPE_TRACKS.get(room_type, ROOM_TYPE_TRACKS.get("combat", "")))

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
