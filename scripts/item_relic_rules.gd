extends RefCounted

## Item relics (pool overhaul U8). Definitions feed faces, forecasts and commit.
## No GameData preload: GameData supplies its ordinary modifier recorder.
const DefenseRules = preload("res://scripts/defense_relic_rules.gd")
const VALUE_FIELDS := ["damage", "burst_damage", "pulse_damage", "line_damage", "bonus_damage", "block_per_tile"]
const AMOUNT_TYPES := ["block", "heal", "stoneskin"]

static func has_effect(effects: Array, kind: String) -> bool:
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) == kind:
			return true
	return false

static func free_item(card: Dictionary, effects: Array) -> bool:
	return bool(card.get("item", false)) and has_effect(effects, "item_no_card_play")

static func modify_card(card: Dictionary, effects: Array, record_modifier: Callable) -> Dictionary:
	if not bool(card.get("item", false)):
		return card
	var result: Dictionary = card.duplicate(true)
	for effect: Dictionary in effects:
		match str(effect.get("type", "")):
			"item_no_card_play":
				# Like Empower, this surcharge follows discounts and the Time reserve.
				result["_item_time_surcharge"] = int(result.get("_item_time_surcharge", 0)) + int(effect.get("time", 1))
				result["_item_time_surcharge_relic"] = str(effect.get("relic_id", ""))
			"item_value_multiplier":
				var actions: Array = []
				for action: Dictionary in result.get("actions", []):
					actions.append(_scale_values(action, effect, record_modifier))
				result["actions"] = actions
			"item_once_per_combat":
				if not DefenseRules.card_heals(result):
					# The physical copy leaves every draw/discard path until next combat.
					# Item Exhaust cannot be preserved or returned by non-item skills.
					result["consume_on_play"] = false
					result["burn"] = true
					result["_item_once_per_combat"] = true
					result["description"] = str(result.get("description", "")).replace("Consume.", "Exhaust.")
	return result

static func _scale_values(values: Dictionary, effect: Dictionary, record_modifier: Callable, inherited_type: String = "") -> Dictionary:
	var result: Dictionary = values.duplicate(true)
	var action_type: String = str(result.get("type", inherited_type))
	for key: String in values:
		# Metadata records original values; it must never be scaled recursively.
		if key.begins_with("_"):
			continue
		var value: Variant = values[key]
		if typeof(value) == TYPE_DICTIONARY:
			result[key] = _scale_values(value as Dictionary, effect, record_modifier, action_type)
		elif typeof(value) == TYPE_ARRAY:
			var children: Array = []
			for child: Variant in value:
				children.append(_scale_values(child as Dictionary, effect, record_modifier, action_type) if typeof(child) == TYPE_DICTIONARY else child)
			result[key] = children
		elif typeof(value) in [TYPE_INT, TYPE_FLOAT] and (VALUE_FIELDS.has(key) or (key == "amount" and AMOUNT_TYPES.has(action_type))):
			var scaled: int = ceili(float(value) * float(effect.get("numerator", 3)) / maxi(1, int(effect.get("denominator", 2))))
			result[key] = scaled
			if scaled != int(value):
				result = record_modifier.call(result, effect, key, value, scaled)
	return result
