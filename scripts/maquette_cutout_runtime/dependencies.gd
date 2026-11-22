extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Presentation = preload("presentation.gd")
const Guardians = preload("res://scripts/guardian_library.gd")

static func placed_types(state: Dictionary) -> Dictionary:
	var types: Dictionary = {}
	for unit: Dictionary in state.get("enemies", []):
		types[str(unit.get("type", ""))] = true
	return types

## Read the encounter's real spawn declarations, including descendants of a
## non-maquette summoner. Never resolve intents or consume the encounter RNG.
static func types_for(state: Dictionary, include_other_renderers: bool = false) -> PackedStringArray:
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
		if include_other_renderers or Presentation.handles(type): result.append(type)
		var definition: Dictionary = Data.enemy_def(type)
		_collect(definition, pending)
		if include_other_renderers:
			for helper: String in definition.get("dragon_helpers", []): _add(pending, helper)
			for helper: String in Guardians.for_guardian(type).get("helpers", []): _add(pending, helper)
	return result

static func _collect(value: Variant, pending: PackedStringArray) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var child: Variant = value[key]
			if key is String and key in ["minion_type", "enemy_type"]:
				_add(pending, str(child))
			elif key is String and key in ["reinforcement_pool", "helpers", "guardian_initial_helpers"] and child is Array:
				for type: Variant in child: _add(pending, str(type))
			else:
				_collect(child, pending)
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
