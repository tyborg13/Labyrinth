extends RefCounted

# Debug-only tier: read all captain rules/names/numbers from the live catalog.
const PROOF_WARBAND_TIER: int = 1

## Production expectations only. Approved clip/pose/timing data stays intact.
const UNPLAYED_CLIPS: Dictionary = {
	# f3e3315bf introduced Hoarder with Kindle/Scurry and no melee bite.
	"ember_hoarder": {"bite": "f3e3315bf: Hoarder has Kindle/Scurry, no melee action"},
	"hollow_mimic": {
		"mirror": "1b6420d6a: Echo replaces Mirror and reuses bolt",
		# 24d28fd371 deliberately removed Block from Mimic's Recede.
		"block": "24d28fd371: Recede no longer grants Block",
	},
}

static func unplayed_for(type: String) -> Dictionary:
	return UNPLAYED_CLIPS.get(type, {}).duplicate(true)

static func data_for(type: String, authored: Dictionary) -> Dictionary:
	var result: Dictionary = authored.duplicate(true)
	if result.is_empty(): return result
	for clip: String in unplayed_for(type): result["clips"].erase(clip)
	return result

static func selector_for(type: String, clip: String, authored: String) -> String:
	# f3e3315bf: Scurry uses the unchanged Tick move clip via live path playback.
	return "scurry:move_away" if type == "ember_hoarder" and clip == "move" else authored

static func mortar_retreat_state(state: Dictionary) -> Dictionary:
	# ed0f46362 removed Brace's move_away; Warband's pre-intent retreat still walks.
	var result: Dictionary = state.duplicate(true)
	result["objective"].merge(preload("res://scripts/warband_room_rules.gd").objective({"special_variant": "fire"}, PROOF_WARBAND_TIER), true)
	result["enemies"][0]["is_leader"] = true
	return result
