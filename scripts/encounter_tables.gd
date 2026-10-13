extends RefCounted
class_name EncounterTables

## Director-authored section compositions. The cached definition is read-only;
## selection owns its expanded units and never mutates the authored table.
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const TABLE_PATH: String = "res://data/encounters.json"
const BIOMES: PackedStringArray = ["fire", "earth", "ice", "air", "lightning", "shadow"]
const ELEMENT_TOKEN: String = "$element"
const BIOME_TOKEN: String = "$biome"
const TRIM_RULE: String = "If an expansion exceeds max_units, drop concrete (non-token) units from the end of the list until it fits; never drop token units."
static var _table: Dictionary = {}
static var _load_attempted: bool = false

static func load() -> Dictionary:
	return _load_table()

## Tests install a frozen table so data-driven expectations don't move when the director adds groups.
static func install_table_for_tests(table: Dictionary) -> void:
	_load_attempted = true
	_table = _validated_table(table)

static func clear_table_cache() -> void:
	_table = {}
	_load_attempted = false

static func _load_table() -> Dictionary:
	# Cache failed loads too: one error per load, then each room uses legacy pools.
	if _load_attempted: return _table
	_load_attempted = true
	var json := JSON.new()
	var error: Error = json.parse(FileAccess.get_file_as_string(TABLE_PATH))
	if error != OK:
		push_error("Invalid encounter table JSON; using legacy pools: " + json.get_error_message())
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Invalid encounter table object; using legacy pools")
		return {}
	_table = _validated_table(json.data)
	return _table

static func _validated_table(table: Dictionary) -> Dictionary:
	var errors: Array[String] = validate(table)
	if not errors.is_empty():
		push_error("Invalid encounter table; using legacy pools: " + "; ".join(errors))
		return {}
	return table

## Pure validation is also exposed to tests, so malformed fixtures do not need
## to replace the protected production file or trigger engine assertion aborts.
static func validate(table: Dictionary) -> Array[String]:
	var errors: Array[String]
	if table.get("version") != 1: errors.append("version must be 1")
	for key: String in ["element_regulars", "biome_groups", "tiers", "rules"]:
		if typeof(table.get(key)) != TYPE_DICTIONARY: errors.append(key + " must be an object")
	if not errors.is_empty(): return errors
	var regulars: Dictionary = table["element_regulars"]
	for element: String in regulars:
		if not ElementData.is_elemental(element): errors.append("Unknown element: " + element)
		_validate_units(regulars[element], false, "element " + element, errors)
	var biomes: Dictionary = table["biome_groups"]
	for biome: String in biomes:
		if not BIOMES.has(biome): errors.append("Unknown biome: " + biome)
		_validate_entries(biomes[biome], false, "biome " + biome, errors)
	for biome: String in BIOMES:
		if not biomes.has(biome): errors.append("Missing biome: " + biome)
	var tiers: Dictionary = table["tiers"]
	var ids: Dictionary = {}
	for tier: String in tiers:
		if tier not in ["1", "2", "3"]: errors.append("Unknown tier: " + tier)
		_validate_entries(tiers[tier], true, "tier " + tier, errors, ids)
	for tier: String in ["1", "2", "3"]:
		if not tiers.has(tier): errors.append("Missing tier: " + tier)
	var rules: Dictionary = table["rules"]
	for key: String in ["max_units", "no_repeat_last"]:
		var value: Variant = rules.get(key)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) != floor(float(value)) or int(value) < (1 if key == "max_units" else 0):
			errors.append(key + " must be a whole number in range")
	if rules.get("trim_rule") != TRIM_RULE: errors.append("Unsupported trim_rule")
	if not errors.is_empty(): return errors
	# Tokens are never trimmed. Reject tables with any untrimmable expansion.
	var largest_element: int = 0
	for units: Array in regulars.values(): largest_element = maxi(largest_element, units.size())
	var largest_biome: int = 0
	for groups: Array in biomes.values():
		for group: Dictionary in groups: largest_biome = maxi(largest_biome, (group["units"] as Array).size())
	for entries: Array in tiers.values():
		for entry: Dictionary in entries:
			var token_count: int = 0
			for unit: String in entry["units"]:
				if unit == ELEMENT_TOKEN: token_count += largest_element
				elif unit == BIOME_TOKEN: token_count += largest_biome
			if token_count > int(rules["max_units"]): errors.append("Token units exceed max_units: " + str(entry["id"]))
	return errors

static func _validate_entries(value: Variant, tokens: bool, context: String, errors: Array[String], ids: Dictionary = {}) -> void:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		errors.append(context + " must have entries")
		return
	var local_ids: Dictionary = {}
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append(context + " entry must be an object")
			continue
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING or str(id).is_empty() or local_ids.has(id) or (tokens and ids.has(id)):
			errors.append(context + " has an empty or duplicate id")
		local_ids[id] = true
		if tokens: ids[id] = true
		var weight: Variant = entry.get("weight")
		if typeof(weight) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(weight)) or float(weight) <= 0.0:
			errors.append(context + " weight must be positive")
		_validate_units(entry.get("units"), tokens, context + "/" + str(id), errors)

static func _validate_units(value: Variant, tokens: bool, context: String, errors: Array[String]) -> void:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		errors.append(context + " must have units")
		return
	for unit: Variant in value:
		if typeof(unit) != TYPE_STRING or (not GameData.enemies().has(unit) and not (tokens and unit in [ELEMENT_TOKEN, BIOME_TOKEN])):
			errors.append(context + " unknown unit: " + str(unit))

static func pick(tier: int, room_element: String, biome: String, history: Array, rng: RandomNumberGenerator) -> Dictionary:
	var table: Dictionary = _load_table()
	if table.is_empty(): return {}
	assert(BIOMES.has(biome), "Unknown encounter biome: " + biome)
	assert(room_element == ElementData.NONE or ElementData.is_elemental(room_element), "Unknown room element: " + room_element)
	var eligible: Array[Dictionary]
	var fresh: Array[Dictionary]
	var recent: Array = history.slice(maxi(0, history.size() - int(table["rules"]["no_repeat_last"])))
	for entry: Dictionary in table["tiers"].get(str(tier), []):
		if not supports_element(entry, room_element): continue
		eligible.append(entry)
		if not recent.has(entry["id"]): fresh.append(entry)
	if eligible.is_empty(): return {}
	var candidates: Array[Dictionary] = fresh if not fresh.is_empty() else eligible
	var selected: Dictionary = _weighted_pick(candidates, rng)
	return expand_entry(selected, room_element, biome, rng)

static func supports_element(entry: Dictionary, room_element: String) -> bool:
	if _load_table().is_empty(): return false
	return not (entry["units"] as Array).has(ELEMENT_TOKEN) or (room_element != ElementData.NONE and _load_table()["element_regulars"].has(room_element))

static func expand_entry(entry: Dictionary, room_element: String, biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var table: Dictionary = _load_table()
	if table.is_empty(): return {}
	assert(supports_element(entry, room_element), "Encounter requires an elemental room")
	var expanded: Array[String]
	var from_token: Array[bool]
	for unit: String in entry["units"]:
		var group: Array = []
		if unit == ELEMENT_TOKEN:
			group = table["element_regulars"][room_element]
		elif unit == BIOME_TOKEN:
			var groups: Array[Dictionary]
			groups.assign(table["biome_groups"][biome])
			group = _weighted_pick(groups, rng)["units"]
		else:
			group.append(unit)
		for expanded_unit: String in group:
			expanded.append(expanded_unit)
			from_token.append(unit == ELEMENT_TOKEN or unit == BIOME_TOKEN)
	var max_units: int = int(table["rules"]["max_units"])
	for index: int in range(expanded.size() - 1, -1, -1):
		if expanded.size() <= max_units: break
		if not from_token[index]:
			expanded.remove_at(index)
			from_token.remove_at(index)
	assert(expanded.size() <= max_units, "Encounter tokens exceed max_units")
	return {"id": str(entry["id"]), "units": expanded}

static func _weighted_pick(entries: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total: float = 0.0
	for entry: Dictionary in entries: total += float(entry["weight"])
	var roll: float = rng.randf() * total
	for entry: Dictionary in entries:
		roll -= float(entry["weight"])
		if roll < 0.0: return entry
	return entries.back()
