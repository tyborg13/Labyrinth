extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Presentation = preload("presentation.gd")

## Read the encounter's real spawn declarations, including descendants of a
## non-maquette summoner. Never resolve intents or consume the encounter RNG.
static func types_for(state: Dictionary) -> PackedStringArray:
	var pending := PackedStringArray()
	for unit: Dictionary in state.get("enemies", []):
		_add(pending, str(unit.get("type", "")))
		_collect(unit.get("intent", {}), pending)
	for field: String in ["objective", "guardian", "encounter"]:
		_collect(state.get(field, {}), pending)
	var seen: Dictionary = {}
	var result := PackedStringArray()
	while not pending.is_empty():
		var type: String = pending[0]
		pending.remove_at(0)
		if seen.has(type): continue
		seen[type] = true
		if Presentation.handles(type): result.append(type)
		_collect(Data.enemy_def(type), pending)
	return result

static func _collect(value: Variant, pending: PackedStringArray) -> void:
	if value is Dictionary:
		for key: String in value:
			if key in ["minion_type", "enemy_type"]: _add(pending, str(value[key]))
			elif key in ["reinforcement_pool", "helpers", "guardian_initial_helpers"] and value[key] is Array:
				for type: Variant in value[key]: _add(pending, str(type))
			else: _collect(value[key], pending)
	elif value is Array:
		for child: Variant in value: _collect(child, pending)

static func _add(pending: PackedStringArray, type: String) -> void:
	if not type.is_empty() and not pending.has(type) and not Data.enemy_def(type).is_empty(): pending.append(type)

static func families_for(types: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for type: String in types:
		var family: String = str(Presentation.CREATURES[type])
		if not result.has(family): result.append(family)
	return result
