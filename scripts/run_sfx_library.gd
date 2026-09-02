extends RefCounted
class_name RunSfxLibrary

const SettingsStore = preload("res://scripts/settings_store.gd")

const DOOR_OPEN_ID: String = "run.door_open"
const CAMPFIRE_LOOP_ID: String = "run.campfire_loop"
const REWARD_ACCEPTED_ID: String = "run.reward_accepted"
const VICTORY_RESOLUTION_ID: String = "run.victory_resolution"

const SFX: Dictionary = {
	DOOR_OPEN_ID: {
		"path": "res://assets/audio/sfx/run/door_open.wav",
		"trimmed_duration": 1.318844,
		"volume_db": -4.0,
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
		"volume_db": -6.0,
		"bus": SettingsStore.UI_SFX_BUS
	},
	VICTORY_RESOLUTION_ID: {
		"path": "res://assets/audio/sfx/run/victory_resolution.wav",
		"trimmed_duration": 5.062375,
		"volume_db": -1.0,
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
	return {}
