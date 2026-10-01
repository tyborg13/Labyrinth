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
const SCHUBERT_COMBAT_TRACK_ID: String = "combat.schubert_d810_movement_ii"
const OLD_CASTLE_MENU_TRACK_ID: String = "menu.mussorgsky_old_castle"
const CHOPIN_DEATH_TRACK_ID: String = "death.chopin_op35_funeral_march"
const ZEKARION_BOSS_TRACK_ID: String = "boss.zekarion"
const RELIC_ROOM_TRACK_ID: String = "room.relic"
const PRE_BATTLE_MODE: String = "pre_battle"
const LANTERNS_TRACK_ID: String = "quiet.lanterns_below"
const TURNING_KEY_TRACK_ID: String = "planning.the_turning_key"
const ASHEN_PURSUIT_TRACK_ID: String = "combat.ashen_pursuit"
const THORNS_TRACK_ID: String = "combat.thorns_in_the_dark"

# Each dragon boss has its own theme in the Thorns string-ensemble family.
# Guardians and other boss-bar enemies keep Thorns in the Dark.
const DRAGON_THEME_TRACK_IDS: Dictionary = {
	"zekarion": "boss.zekarion_raging_tempest",
	"tharokh": "boss.tharokh_worldspine",
	"vyraketh": "boss.vyraketh_cinder_crown",
	"vaeloryx": "boss.vaeloryx_hollow_gale",
	"iskaldra": "boss.iskaldra_rime_tyrant",
	"noctyrax": "boss.noctyrax_last_eclipse",
}
const DRAGON_THEME_VOLUME_DB: float = -5.5

const TRACKS: Dictionary = {
	LANTERNS_TRACK_ID: {
		"path": "res://assets/audio/music/lanterns_below_v02.ogg",
		"volume_db": -7.0,
		"loop": true
	},
	TURNING_KEY_TRACK_ID: {
		"path": "res://assets/audio/music/the_turning_key_v02.ogg",
		"volume_db": -7.0,
		"loop": true
	},
	ASHEN_PURSUIT_TRACK_ID: {
		"path": "res://assets/audio/music/ashen_pursuit_v03.ogg",
		"volume_db": -5.5,
		"loop": true
	},
	THORNS_TRACK_ID: {
		"path": "res://assets/audio/music/thorns_in_the_dark_v02.ogg",
		"volume_db": -5.5,
		"loop": true
	},
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
	SCHUBERT_COMBAT_TRACK_ID: {
		"path": "res://assets/audio/music/schubert_d810_movement_ii_driving_loop.ogg",
		"volume_db": -5.5,
		"loop": true
	},
	OLD_CASTLE_MENU_TRACK_ID: {
		"path": "res://assets/audio/music/mussorgsky_old_castle_main_menu.ogg",
		"volume_db": -6.5,
		"loop": true
	},
	CHOPIN_DEATH_TRACK_ID: {
		"path": "res://assets/audio/music/chopin_op35_funeral_march_death_loop.ogg",
		"volume_db": -7.0,
		"loop": true
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

# Planning overrides are scoped to the run scene; the main menu requests Old Castle directly.
const PLANNING_ROOMS: Array = ["blacksmith", "arcanist", "scavenger", "graftwright"]
const MODE_TRACKS: Dictionary = {
	"defeat": CHOPIN_DEATH_TRACK_ID,
	"victory": LANTERNS_TRACK_ID,
	"reward": LANTERNS_TRACK_ID,
	"treasure": LANTERNS_TRACK_ID,
	"campfire": LANTERNS_TRACK_ID,
	"escape": LANTERNS_TRACK_ID,
	"event": TURNING_KEY_TRACK_ID,
	"graftwright": TURNING_KEY_TRACK_ID,
	PRE_BATTLE_MODE: TURNING_KEY_TRACK_ID
}

static func entry_for_context(mode: String, room: Dictionary, combat_state: Dictionary = {}, planning_open: bool = false) -> Dictionary:
	var track_id: String = _track_id_for_context(mode, room, combat_state, planning_open)
	if track_id.is_empty():
		return {}
	return entry(track_id)

static func entry(track_id: String) -> Dictionary:
	if TRACKS.has(track_id):
		var result: Dictionary = (TRACKS.get(track_id, {}) as Dictionary).duplicate(true)
		result["id"] = track_id
		return result
	for dragon_id: String in DRAGON_THEME_TRACK_IDS:
		if DRAGON_THEME_TRACK_IDS[dragon_id] == track_id:
			return {
				"id": track_id,
				"path": "res://assets/audio/music/dragon_themes/%s_theme_v01.ogg" % dragon_id,
				"volume_db": DRAGON_THEME_VOLUME_DB,
				"loop": true,
			}
	return {}

static func dragon_in_fight(room: Dictionary, combat_state: Dictionary) -> String:
	var boss_id: String = str(room.get("boss_id", ""))
	if DRAGON_THEME_TRACK_IDS.has(boss_id):
		return boss_id
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			var enemy_type: String = str((enemy_var as Dictionary).get("type", ""))
			if DRAGON_THEME_TRACK_IDS.has(enemy_type):
				return enemy_type
	return ""

static func _track_id_for_context(mode: String, room: Dictionary, combat_state: Dictionary, planning_open: bool) -> String:
	# Terminal outcomes outrank a menu/map left open during the transition.
	if mode in ["defeat", "victory"]:
		return str(MODE_TRACKS[mode])
	if planning_open:
		return TURNING_KEY_TRACK_ID
	if MODE_TRACKS.has(mode):
		return str(MODE_TRACKS[mode])
	if mode == "combat":
		var dragon_id: String = dragon_in_fight(room, combat_state)
		if not dragon_id.is_empty():
			return str(DRAGON_THEME_TRACK_IDS[dragon_id])
		return THORNS_TRACK_ID if _is_intense_fight(room, combat_state) else ASHEN_PURSUIT_TRACK_ID
	if mode == "room":
		var room_type: String = str(room.get("type", ""))
		if room_type in PLANNING_ROOMS:
			return TURNING_KEY_TRACK_ID
		if room_type in ["combat", "guardian", "boss"] and not bool(room.get("cleared", false)):
			return TURNING_KEY_TRACK_ID
		return LANTERNS_TRACK_ID
	return ""

static func _is_intense_fight(room: Dictionary, combat_state: Dictionary) -> bool:
	if str(room.get("type", "")) in ["guardian", "boss"] or str(combat_state.get("room_type", "")) in ["guardian", "boss"]:
		return true
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY:
			var enemy: Dictionary = enemy_var
			if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
				return true
	return false
