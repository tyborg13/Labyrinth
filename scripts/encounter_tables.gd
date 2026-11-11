extends RefCounted
class_name EncounterTables

## Director-authored section compositions. The cached definition is read-only;
## selection owns its expanded units and never mutates the authored table.
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const TABLE_PATH: String = "res://data/encounters.json"
const BIOMES: PackedStringArray = ["fire", "earth", "ice", "air", "lightning", "shadow"]
const ELEMENT_TOKEN: String = "$element"
const BIOME_TOKEN: String = "$biome"
const TRIM_RULE: String = "Capacity is min(max_units, tier_max_units[tier], fight_max_units[k]); fight numbers beyond the last key use its value. Expand tokens using seeded weighted groups that fit the remaining capacity; if a token cannot fit, re-roll among compositions whose smallest token expansion fits. Then drop concrete (non-token) units from the end until within capacity; never drop token units or return an empty fight."
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
	for rule: String in ["tier_max_units", "fight_max_units"]:
		_validate_caps(rules.get(rule), rule, int(rules["max_units"]), errors)
	if not errors.is_empty(): return errors
	# Depth can lower the fight-number tier. Validate every reachable (tier,
	# effective cap), including the final cap carried into all later fights.
	var pairs: Dictionary = {}
	for k: int in range(1, maxi(5, (rules["fight_max_units"] as Dictionary).size()) + 1):
		for tier: int in range(1, fight_number_tier(k) + 1):
			var cap: int = unit_cap(tier, k, table)
			pairs["%d/%d" % [tier, cap]] = {"tier": str(tier), "cap": cap}
	for pair: Dictionary in pairs.values():
		for biome: String in BIOMES:
			var elements: Array = regulars.keys()
			elements.append(ElementData.NONE)
			for element: String in elements:
				var fits: bool = false
				for entry: Dictionary in tiers[pair["tier"]]:
					if (entry["units"] as Array).has(ELEMENT_TOKEN) and not regulars.has(element): continue
					if _minimum_token_units(entry, element, biome, table) <= int(pair["cap"]): fits = true
				if not fits: errors.append("No fitting composition: tier %s/cap %d/%s/%s" % [pair["tier"], pair["cap"], biome, element])
	return errors

static func _validate_caps(value: Variant, rule: String, global_cap: int, errors: Array[String]) -> void:
	if not value is Dictionary or (value as Dictionary).is_empty():
		errors.append(rule + " must be a nonempty object")
		return
	var caps: Dictionary = value
	if rule == "tier_max_units" and caps.size() != 3:
		errors.append("tier_max_units must have tiers 1, 2 and 3")
	for key: Variant in caps:
		if typeof(key) != TYPE_STRING or not str(key).is_valid_int() or str(int(key)) != key or int(key) < 1 or int(key) > caps.size():
			errors.append(rule + " keys must be consecutive positive whole numbers starting at 1")
		var cap: Variant = caps[key]
		if typeof(cap) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(cap)) or float(cap) != floor(float(cap)) or int(cap) < 1 or int(cap) > global_cap:
			errors.append(rule + "/" + str(key) + " must be a whole number within max_units")

## k=0 is a context-free table query: use the tier ceiling. Runtime always
## supplies the room's persisted k; legacy saved rooms bypass caps in pick().
static func unit_cap(tier: int, k: int, table: Dictionary = {}) -> int:
	var definition: Dictionary = _load_table() if table.is_empty() else table
	if definition.is_empty(): return 0
	var rules: Dictionary = definition["rules"]
	var cap: int = mini(int(rules["max_units"]), int(rules["tier_max_units"][str(tier)]))
	if k > 0:
		var fight_caps: Dictionary = rules["fight_max_units"]
		cap = mini(cap, int(fight_caps[str(mini(k, fight_caps.size()))]))
	return cap

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

static func pick(tier: int, room_element: String, biome: String, history: Array, rng: RandomNumberGenerator, legacy: bool = false, k: int = 0) -> Dictionary:
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
	var candidates: Array[Dictionary] = TypedArrays.dictionaries(fresh if not fresh.is_empty() else eligible)
	var selected: Dictionary = _weighted_pick(candidates, rng)
	if legacy: return expand_entry(selected, room_element, biome, rng)
	var cap: int = unit_cap(tier, k, table)
	var expanded: Dictionary = expand_entry(selected, room_element, biome, rng, cap)
	if not expanded.is_empty(): return expanded
	# Retry only viable entries, preserving weights and the recent-history rule
	# among that viable set. Minimum means token units: concrete units can trim.
	var fitting: Array[Dictionary]
	var fitting_fresh: Array[Dictionary]
	for entry: Dictionary in eligible:
		if _minimum_token_units(entry, room_element, biome, table) > cap: continue
		fitting.append(entry)
		if not recent.has(entry["id"]): fitting_fresh.append(entry)
	assert(not fitting.is_empty(), "Validated encounter cohort needs a fitting composition")
	if fitting.is_empty(): return {}
	candidates = TypedArrays.dictionaries(fitting_fresh if not fitting_fresh.is_empty() else fitting)
	selected = _weighted_pick(candidates, rng)
	# Reserve minimum space for later tokens on retry so a weighted early group
	# cannot starve a later token and cause an unbounded retry loop.
	return expand_entry(selected, room_element, biome, rng, cap, true)

static func supports_element(entry: Dictionary, room_element: String) -> bool:
	if _load_table().is_empty(): return false
	return not (entry["units"] as Array).has(ELEMENT_TOKEN) or (room_element != ElementData.NONE and _load_table()["element_regulars"].has(room_element))

static func expand_entry(entry: Dictionary, room_element: String, biome: String, rng: RandomNumberGenerator, capacity: int = 0, reserve_tokens: bool = false) -> Dictionary:
	var table: Dictionary = _load_table()
	if table.is_empty(): return {}
	assert(supports_element(entry, room_element), "Encounter requires an elemental room")
	var expanded: Array[String]
	var from_token: Array[bool]
	var token_units: int = 0
	var max_units: int = int(table["rules"]["max_units"]) if capacity == 0 else mini(capacity, int(table["rules"]["max_units"]))
	var units: Array = entry["units"]
	for unit_index: int in range(units.size()):
		var unit: String = units[unit_index]
		var remaining: int = max_units - token_units
		if capacity > 0 and reserve_tokens:
			remaining -= _minimum_token_units({"units": units.slice(unit_index + 1)}, room_element, biome, table)
		var group: Array = []
		if unit == ELEMENT_TOKEN:
			group = table["element_regulars"][room_element]
			if capacity > 0 and group.size() > remaining: return {}
		elif unit == BIOME_TOKEN:
			var groups: Array[Dictionary]
			for candidate: Dictionary in table["biome_groups"][biome]:
				if capacity == 0 or (candidate["units"] as Array).size() <= remaining: groups.append(candidate)
			if groups.is_empty(): return {}
			group = _weighted_pick(groups, rng)["units"]
		else:
			group.append(unit)
		if unit in [ELEMENT_TOKEN, BIOME_TOKEN]: token_units += group.size()
		for expanded_unit: String in group:
			expanded.append(expanded_unit)
			from_token.append(unit == ELEMENT_TOKEN or unit == BIOME_TOKEN)
	for index: int in range(expanded.size() - 1, -1, -1):
		if expanded.size() <= max_units: break
		if not from_token[index]:
			expanded.remove_at(index)
			from_token.remove_at(index)
	assert(not expanded.is_empty(), "Encounter cannot be empty")
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

static func _minimum_token_units(entry: Dictionary, element: String, biome: String, table: Dictionary) -> int:
	var count: int = 0
	for unit: String in entry["units"]:
		if unit == ELEMENT_TOKEN:
			count += (table["element_regulars"].get(element, []) as Array).size()
		elif unit == BIOME_TOKEN:
			var smallest: int = int(table["rules"]["max_units"]) + 1
			for group: Dictionary in table["biome_groups"][biome]: smallest = mini(smallest, (group["units"] as Array).size())
			count += smallest
	return count

## Cleared nodes are the actual route, including resolved mysteries and the
## guided tutorial. Bosses and fights in other sections never advance k.
static func fight_number(state: Dictionary, room: Dictionary) -> int:
	if room.has("fight_number"): return int(room["fight_number"])
	var count: int = 1
	for previous: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if previous.get("coord") == room.get("coord"): continue
		if int(previous.get("section_index", -1)) != int(room.get("section_index", -2)): continue
		if bool(previous.get("cleared", false)) and str(previous.get("type", "")) in ["combat", "special", "guardian"]: count += 1
	return count

static func record_room_entry(state: Dictionary, room: Dictionary) -> void:
	if not room.has("section_index") or room.has("fight_number"): return
	if str(room.get("type", "")) not in ["combat", "special", "guardian"]: return
	room["fight_number"] = fight_number(state, room)

static func fight_number_tier(k: int) -> int:
	return mini(3, 1 + maxi(0, k - 1) / 2)
