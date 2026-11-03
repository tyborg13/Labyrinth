extends RefCounted

# Formats the concrete transaction, grouped by authored effect. This helper
# owns no RNG or state; EventRules supplies the same resolution as commitment.
const Data = preload("res://scripts/game_data.gd")

static func lines(effects: Array, groups: Array, plain: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for index: int in range(effects.size()):
		var effect: Dictionary = effects[index]
		var type: String = str(effect["type"])
		var outcomes: Array = groups[index]
		var ids: Array[String]
		var names: Array[String]
		var kind: String = type if type in ["relic", "card", "card_choice", "equipment", "item", "omen", "reforge", "lose_item"] else "transform" if type == "transform_magic" else "plain"
		var text: String = plain[index]
		for outcome: Dictionary in outcomes:
			if outcome.has("id"): ids.append(str(outcome["id"]))
			elif outcome.has("cards"):
				for id: String in outcome["cards"]: ids.append(id)
			elif outcome.has("from"):
				ids.append(str(outcome["from"]))
				if outcome.has("to"): ids.append(str(outcome["to"]))
		for id: String in ids: names.append(_name(type, id))
		if not outcomes.is_empty() and outcomes[0].has("substitution_for"):
			kind = "plain"
			text = "Gain 40 Embers."
		elif kind in ["relic", "equipment", "card", "item"]:
			text = "Gain %s." % " and ".join(names) if not names.is_empty() else "Gain nothing."
		elif kind == "card_choice":
			text = "Choose 1: %s." % _alternatives(names) if not names.is_empty() else "Gain nothing."
		elif kind == "lose_item":
			text = "Lose %s." % names[0] if not names.is_empty() else "Lose an item."
		elif kind == "reforge":
			text = "Your %s becomes %s." % [names[0], names[1]] if names.size() == 2 else "Reforge your gear."
		elif kind == "transform":
			if outcomes.size() == 1 and outcomes[0].has("to"): text = "%s becomes %s." % [names[0], names[1]]
			elif outcomes.size() > 1 and outcomes.all(func(outcome: Dictionary) -> bool: return outcome.has("to")): text = "%d spells change: hover to see." % outcomes.size()
			else: text = "Transform a spell." if outcomes.is_empty() else "Nothing changes."
		result.append({"text": text, "kind": kind, "ids": ids})
	return result

static func _name(type: String, id: String) -> String:
	var definition: Dictionary = Data.relic_def(id) if type == "relic" else Data.equipment_def(id) if type in ["equipment", "reforge"] else Data.omen_def(id) if type == "omen" else Data.card_def(id)
	return str(definition.get("name", id))

static func _alternatives(names: Array[String]) -> String:
	if names.size() < 2: return "" if names.is_empty() else names[0]
	return "%s or %s" % [", ".join(names.slice(0, names.size() - 1)), names.back()]
