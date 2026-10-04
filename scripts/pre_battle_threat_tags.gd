extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")

static func build(enemy_type: String) -> Array:
	return from_intents(GameData.enemy_def(enemy_type).get("intents", []) as Array)

static func from_intents(intents: Array) -> Array:
	var tags: Array = []
	var seen: Dictionary = {}
	for intent_var: Variant in intents:
		if not intent_var is Dictionary:
			continue
		for action_var: Variant in (intent_var as Dictionary).get("actions", []):
			if not action_var is Dictionary:
				continue
			var action: Dictionary = action_var as Dictionary
			_append(tags, seen, _word(action), ActionIcons.action_icon_key(action))
			if bool(action.get("pierce", false)):
				_append(tags, seen, "Pierce", "pierce")
			if int(action.get("bleed", 0)) > 0:
				_append(tags, seen, "Bleed", "bleed")
	if tags.is_empty():
		tags.append({"text": "Inspect known moves", "icon_key": ""})
	return tags

static func summary(tags: Array) -> String:
	var words := PackedStringArray()
	for index: int in range(mini(3, tags.size())):
		words.append(str((tags[index] as Dictionary).get("text", "")))
	var result: String = " / ".join(words)
	if tags.size() > words.size():
		result += "  +%d" % (tags.size() - words.size())
	return result

static func _append(tags: Array, seen: Dictionary, word: String, icon_key: String) -> void:
	if word.is_empty() or seen.has(word):
		return
	seen[word] = true
	# Keep the word when the registry has no identity for its concept.
	tags.append({"text": word, "icon_key": icon_key if not ActionIcons.icon_path(icon_key).is_empty() else ""})

static func _word(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"melee": return "Melee"
		"ranged": return "Ranged"
		"aoe", "lightning_strikes": return "Area"
		"block", "guard_ally": return "Guard"
		"stoneskin": return "Stoneskin"
		"heal", "heal_self", "heal_ally": return "Heal"
		"move_away": return "Retreat"
		"pull": return "Pull"
		"push": return "Push"
		"summon_minions": return "Summon"
		"raise_terrain", "terrain_burst":
			return "Outcrops" if str(action.get("guardian_kind", "")) == "crag_outcrop" else "Worldspines"
		"cinder_marks", "detonate_cinders": return "Cinder Marks"
		"gale_force": return "Arena Gale"
		"frost_armor": return "Crystal Mantle"
		"umbra_eclipse": return "Eclipse"
		"split": return "Split"
	return ""
