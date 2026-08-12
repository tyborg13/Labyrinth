extends RefCounted

const AttackSfxLibrary = preload("res://scripts/attack_sfx_library.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

const EXPECTED_PATHS: Dictionary = {
	"fire": "res://assets/audio/sfx/elemental/fire_attack.wav",
	"earth": "res://assets/audio/sfx/elemental/earth_attack.wav",
	"air": "res://assets/audio/sfx/elemental/air_attack.wav",
	"lightning": "res://assets/audio/sfx/elemental/lightning_attack.wav",
	"ice": "res://assets/audio/sfx/elemental/ice_attack.wav"
}

static func run(expect: Callable) -> void:
	for element_id: String in EXPECTED_PATHS:
		var player_entry: Dictionary = AttackSfxLibrary.entry_for_player_action(
			{"element": element_id},
			{"type": "ranged", "range": 6, "_card_element": element_id}
		)
		expect.call(str(player_entry.get("path", "")) == str(EXPECTED_PATHS[element_id]), "%s ranged attacks should use their selected elemental sound" % element_id.capitalize())
		expect.call(FileAccess.file_exists(str(player_entry.get("path", ""))), "%s elemental sound asset should exist" % element_id.capitalize())
		expect.call(AssetLoader.load_audio_stream(str(player_entry.get("path", ""))) != null, "%s elemental sound should load as a playable audio stream" % element_id.capitalize())
		var trap_entry: Dictionary = AttackSfxLibrary.entry_for_trap({"element": element_id})
		expect.call(str(trap_entry.get("path", "")) == str(EXPECTED_PATHS[element_id]), "%s traps should use the same selected elemental sound" % element_id.capitalize())

	var generic_entry: Dictionary = AttackSfxLibrary.entry_for_player_action({}, {"type": "ranged", "range": 5})
	expect.call(str(generic_entry.get("id", "")) == AttackSfxLibrary.RANGED_SFX_ID, "Non-elemental ranged attacks should retain the bow sound")
	var melee_entry: Dictionary = AttackSfxLibrary.entry_for_player_action({"element": "fire"}, {"type": "melee", "range": 1, "_card_element": "fire"})
	expect.call(str(melee_entry.get("id", "")) == AttackSfxLibrary.MELEE_SFX_ID, "Elemental melee attacks should retain their melee sound until they receive matching authored VFX")
	var distinct_traps: Array[Dictionary] = AttackSfxLibrary.entries_for_traps([
		{"element": "fire"},
		{"element": "fire"},
		{"element": "ice"}
	])
	expect.call(distinct_traps.size() == 2, "A simultaneous same-element trap chain should not layer duplicate copies of one sound")
