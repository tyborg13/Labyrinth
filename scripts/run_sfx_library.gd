extends RefCounted
class_name RunSfxLibrary

const SettingsStore = preload("res://scripts/settings_store.gd")

const DOOR_OPEN_ID: String = "run.door_open"
const CAMPFIRE_LOOP_ID: String = "run.campfire_loop"
const REWARD_ACCEPTED_ID: String = "run.reward_accepted"
const VICTORY_RESOLUTION_ID: String = "run.victory_resolution"

const HEARTH_ARRIVAL_ID: String = "run.ember_hearth_arrival"
const HEARTH_FOCUS_ID: String = "run.ember_hearth_focus"
const HEARTH_SELECT_ID: String = "run.ember_hearth_select"
const HEARTH_RECOVER_ID: String = "run.ember_hearth_recover"
const HEARTH_STRENGTH_ID: String = "run.ember_hearth_strength"
const HEARTH_DEPART_ID: String = "run.ember_hearth_depart"

const MENU_OPEN_ID: String = "run.menu_page_open"
const MENU_CLOSE_ID: String = "run.menu_page_close"
const DUNGEON_AMBIENCE_ID: String = "run.dungeon_hall_ambience"
const STINGER_LEVEL_UP_ID: String = "run.stinger_level_up"
const STINGER_BOSS_DEFEATED_ID: String = "run.stinger_boss_defeated"
# Modes that sit inside the torch-lit halls get the quiet stone-hall bed. The
# campfire owns its own fire loop; terminal and menu-like modes stay dry so the
# music carries them.
const DUNGEON_AMBIENCE_MODES: Array[String] = ["room", "combat", "pre_battle", "reward", "treasure", "event"]

const SFX: Dictionary = {
	HEARTH_ARRIVAL_ID: {
		"path": "res://assets/audio/sfx/run/ember_hearth_arrival.wav",
		"trimmed_duration": 0.68,
		"volume_db": -14.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	HEARTH_FOCUS_ID: {
		"path": "res://assets/audio/sfx/run/ember_hearth_focus.wav",
		"trimmed_duration": 0.12,
		"volume_db": -17.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	HEARTH_SELECT_ID: {
		"path": "res://assets/audio/sfx/run/ember_hearth_select.wav",
		"trimmed_duration": 0.26,
		"volume_db": -12.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	HEARTH_RECOVER_ID: {
		"path": "res://assets/audio/sfx/run/ember_hearth_recover.wav",
		"trimmed_duration": 0.95,
		"volume_db": -10.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	HEARTH_STRENGTH_ID: {
		"path": "res://assets/audio/sfx/run/ember_hearth_strength.wav",
		"trimmed_duration": 0.95,
		"volume_db": -12.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	HEARTH_DEPART_ID: {
		"path": "res://assets/audio/sfx/run/ember_hearth_depart.wav",
		"trimmed_duration": 1.0,
		"volume_db": -14.0,
		"bus": SettingsStore.UI_SFX_BUS
	},

	DOOR_OPEN_ID: {
		"path": "res://assets/audio/sfx/run/door_open.wav",
		"trimmed_duration": 1.318844,
		"volume_db": -10.0,
		"bus": SettingsStore.WORLD_SFX_BUS
	},
	CAMPFIRE_LOOP_ID: {
		"path": "res://assets/audio/sfx/run/campfire_loop.wav",
		"trimmed_duration": 77.855,
		"volume_db": -4.0,
		"bus": SettingsStore.WORLD_SFX_BUS,
		"loop": true
	},
	REWARD_ACCEPTED_ID: {
		"path": "res://assets/audio/sfx/run/reward_accepted.wav",
		"trimmed_duration": 4.863220,
		"volume_db": -12.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	MENU_OPEN_ID: {
		"path": "res://assets/audio/sfx/ui/menu_page_open.wav",
		"trimmed_duration": 0.363,
		"volume_db": -6.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	MENU_CLOSE_ID: {
		"path": "res://assets/audio/sfx/ui/menu_page_close.wav",
		"trimmed_duration": 0.239,
		"volume_db": -7.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	DUNGEON_AMBIENCE_ID: {
		"path": "res://assets/audio/sfx/ui/dungeon_hall_ambience_loop.wav",
		"trimmed_duration": 48.0,
		"volume_db": -20.0,
		"bus": SettingsStore.WORLD_SFX_BUS,
		"loop": true
	},
	# Short musical stingers play as dry UI cues while the score dips beneath them.
	STINGER_LEVEL_UP_ID: {
		"path": "res://assets/audio/music/stingers/level_up_v02.ogg",
		"volume_db": -4.0,
		"bus": SettingsStore.UI_SFX_BUS,
		"pitch_variance": 0.0,
		"music_duck": true
	},
	STINGER_BOSS_DEFEATED_ID: {
		"path": "res://assets/audio/music/stingers/boss_defeated_v02.ogg",
		"volume_db": -3.0,
		"bus": SettingsStore.UI_SFX_BUS,
		"pitch_variance": 0.0,
		"music_duck": true
	},
	VICTORY_RESOLUTION_ID: {
		"path": "res://assets/audio/sfx/run/victory_resolution.wav",
		"trimmed_duration": 5.062375,
		"volume_db": -7.0,
		"bus": SettingsStore.UI_SFX_BUS
	}
}

static func entry(sfx_id: String) -> Dictionary:
	if not SFX.has(sfx_id):
		return {}
	var result: Dictionary = (SFX.get(sfx_id, {}) as Dictionary).duplicate(true)
	result["id"] = sfx_id
	return result

static func ambient_entry_for_mode(mode: String) -> Dictionary:
	if mode == "campfire":
		return entry(CAMPFIRE_LOOP_ID)
	if DUNGEON_AMBIENCE_MODES.has(mode):
		return entry(DUNGEON_AMBIENCE_ID)
	return {}
