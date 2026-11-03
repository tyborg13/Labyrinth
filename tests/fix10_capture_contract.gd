extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const CAST_INTENTS: Dictionary = {
	"arc_thrall": {"tether": "arc_bolt"},
	"briar_weaver": {"thornwall": "thornwall"},
	"hoarfrost_seer": {"mark": "icefall", "land": "icefall_land"},
}

# Compare the displayed Label and renderer snapshots, not resolver metadata.
# expected_facing is independent of each harness's geometry-selection flag.
static func errors(frames: Array[Dictionary], type: String, expected_facing: String = "") -> Array[String]:
	var result: Array[String]
	var definition: Dictionary = Data.enemy_def(type)
	for stage: String in CAST_INTENTS.get(type, {}):
		var name: String = ""
		for intent: Dictionary in definition["intents"]:
			if str(intent["id"]) == str(CAST_INTENTS[type][stage]): name = str(intent["name"])
		var expected_banner: String = "%s: %s" % [definition["name"], name]
		var count: int = 0
		var banner_ok: bool = not name.is_empty()
		var facing_ok: bool = true
		for row: Dictionary in frames:
			if str(row["stage"]) != stage: continue
			count += 1
			banner_ok = banner_ok and str(row.get("banner", "")) == expected_banner and bool(row.get("banner_visible", false))
			facing_ok = facing_ok and (expected_facing.is_empty() or str(row["snapshot"]["facing"]) == expected_facing)
		if count == 0: result.append(stage + ": missing cast playback evidence")
		if not banner_ok: result.append(stage + ": authored cast banner missing during playback (expected " + expected_banner + ")")
		if not facing_ok: result.append(stage + ": expected " + expected_facing + " cast facing")
	return result
