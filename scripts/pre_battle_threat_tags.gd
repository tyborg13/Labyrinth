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
				_append(tags, seen, ActionIcons.label("pierce"), "pierce")
			if int(action.get("bleed", 0)) > 0:
				_append(tags, seen, ActionIcons.label("bleed"), "bleed")
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
	if str(action.get("type", "")) not in ["grow_bramble", "lob_mark", "lob_land", "melee", "ranged", "aoe", "lightning_strikes", "block", "guard_ally", "stoneskin", "heal", "heal_self", "heal_ally", "move_away", "pull", "push", "summon_minions", "raise_terrain", "terrain_burst", "cinder_marks", "detonate_cinders", "gale_force", "frost_armor", "umbra_eclipse", "split"]:
		return ""
	var icon_key: String = ActionIcons.action_icon_key(action)
	return ActionIcons.label(icon_key) if not icon_key.is_empty() else str(action.get("type", "")).capitalize()
