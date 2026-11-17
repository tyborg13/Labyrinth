extends RefCounted
## Read live dials in combat; the pre-battle catalog has no installed instance yet.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Icons = preload("res://scripts/action_icon_library.gd")

static func instance_for(state: Dictionary, unit: Dictionary, intent: Dictionary) -> Dictionary:
	var instance: Dictionary = Rules.active(state)
	if instance.is_empty():
		instance = Rules.instance_for(str(unit.get("type", unit.get("id", ""))))
	elif int(instance.get("source", {}).get("id", -1)) != int(unit.get("id", -2)):
		return {}
	var cadence: Dictionary = instance.get("cadence", {})
	if str(cadence.get("anchor", "")) != "on_intent" or str(cadence.get("intent", "")) != str(intent.get("id", "")): return {}
	return instance

static func tokens(state: Dictionary, unit: Dictionary, intent: Dictionary) -> Array:
	var instance: Dictionary = instance_for(state, unit, intent)
	if str(instance.get("rule", "")) != "lightning_storm": return []
	# The installed instance owns effective dials, including the half-health merge.
	var dials: Dictionary = instance["dials"]
	var row: Array = [Icons.token_for(str(instance["rule"]))]
	row.append(Icons.token_for("lightning_strikes", int(dials["damage"])))
	if int(dials.get("chain", 0)) > 0: row.append(Icons.token_for("chain", int(dials["chain"])))
	row.append(Icons.text_token("every Electrified tile"))
	return row
