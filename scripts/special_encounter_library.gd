extends RefCounted
class_name SpecialEncounterLibrary

# The director's catalog is immutable. Callers receive private copies, including
# the placement test seam that exercises future types without enabling them.
const DATA_PATH: String = "res://data/special_encounters.json"
const GameData = preload("res://scripts/game_data.gd")
const Omens = preload("res://scripts/omen_rules.gd")
const PLACEMENT_SEARCH_LIMIT: int = 12000
# Reuse RoomGenerator.generate_room’s existing room RNG salt for pickup repair.
const EQUIPMENT_LOOT_SEED_SALT: int = 101
# The brief specifies four offers but only the existing first three filters.
# Retain the ordinary general fallback until the owner supplies the fourth.
const TODO_DESIGN_SPECIAL_FOURTH_CHOICE_ELEMENT_FILTER: String = ""
static var _data: Dictionary = {}

static func catalog() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) as Dictionary
	return _data.duplicate(true)

static func definition(type: String) -> Dictionary:
	return (catalog()["types"] as Dictionary).get(type, {}).duplicate(true)

static func variant(type: String, biome: String) -> Dictionary:
	return (definition(type).get("variants", {}) as Dictionary).get(biome, {}).duplicate(true)

static func enabled_types() -> Array[String]:
	return _enabled_types(catalog())

static func _enabled_types(data: Dictionary) -> Array[String]:
	var result: Array[String]
	for type: String in data["types"]:
		if bool(data["types"][type].get("enabled", false)): result.append(type)
	return result

static func display_name(room: Dictionary) -> String:
	var type: String = str(room.get("special_type", ""))
	var name: String = str(definition(type).get("name", "TODO_DESIGN_SPECIAL_NAME"))
	if type == "warband":
		return name + " · " + str(variant(type, str(room.get("special_variant", ""))).get("title", "TODO_DESIGN_CAPTAIN_TITLE"))
	return name

static func tooltip_line(room: Dictionary) -> String:
	return str(definition(str(room.get("special_type", ""))).get("tooltip_line", "TODO_DESIGN_SPECIAL_TOOLTIP"))

static func goal_met(room: Dictionary, combat: Dictionary) -> bool:
	if str(room.get("type", "")) != "special": return false
	# Warband cannot fail on victory. Future failable objectives must save this
	# explicit result; an absent result must not silently pay enhanced rewards.
	return bool((combat.get("objective", {}) as Dictionary).get("goal_met", str(room.get("special_type", "")) == "warband"))

static func starting_embers(layout: Dictionary) -> int:
	var total: int = 0
	for enemy: Dictionary in layout.get("enemies", []):
		total += int(enemy.get("reward_embers", GameData.enemy_def(str(enemy.get("type", ""))).get("reward_embers", 0)))
	return total

static func reward_embers(room: Dictionary, combat: Dictionary) -> int:
	var base: int = int(room.get("special_starting_reward_embers", 0))
	# Use the ordinary half-up Ember rounding and the combat's starting omens,
	# rather than the run's already-ticked omen list. Regular enemies have no
	# depth Ember modifier.
	var multiplied: int = int(floor(base * float(catalog()["rewards"]["ember_multiplier"]) + 0.5))
	return Omens.ember_drop(combat, multiplied)

# Revision 6 runs this AFTER the ordinary type solver. No edge, element,
# hidden mystery, Guardian, or route fight budget is changed by substitution.
static func place(layout: Dictionary, rng: RandomNumberGenerator, count: int, biome: String, data: Dictionary = {}) -> bool:
	if data.is_empty(): data = catalog()
	var types: Array[String] = _enabled_types(data)
	if types.is_empty(): return true
	var rules: Dictionary = data["placement"]
	var weights: Dictionary = rules["per_section_count_weights"]
	var total: int = 0
	for weight: int in weights.values(): total += weight
	var roll: int = rng.randi_range(1, total)
	var wanted: int = 0
	for amount: String in weights:
		roll -= int(weights[amount])
		if roll <= 0:
			wanted = mini(int(amount), types.size())
			break
	var candidates: Dictionary = {}
	for type: String in types:
		var cells: Array[Vector2i]
		for cell: Vector2i in layout["order"]:
			if _eligible(layout, cell, type, count, rules): cells.append(cell)
		candidates[type] = cells
	# Seeded Fisher-Yates avoids Array.shuffle's process-global RNG.
	_shuffle(types, rng)
	for cells: Array in candidates.values(): _shuffle(cells, rng)
	var selected: Dictionary = {}
	for target: int in range(wanted, 0, -1):
		var search: Dictionary = {"remaining": PLACEMENT_SEARCH_LIMIT}
		if _search(layout, types, candidates, rules, target, 0, selected, search): break
	# A canonical bounded repair is independent of how far the seeded search
	# got. Reducing the count only happens when legal slots cap the request.
	if selected.is_empty():
		types.sort()
		for cells: Array in candidates.values(): cells.sort()
		for target: int in range(wanted, 0, -1):
			var search: Dictionary = {"remaining": PLACEMENT_SEARCH_LIMIT}
			if _search(layout, types, candidates, rules, target, 0, selected, search): break
	if selected.is_empty(): return false
	for cell: Vector2i in selected:
		layout["nodes"][cell].merge({"type": "special", "special_type": selected[cell], "special_variant": biome}, true)
	return true

static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for offset: int in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, offset)
		var value: Variant = values[offset]
		values[offset] = values[other]
		values[other] = value

static func _eligible(layout: Dictionary, cell: Vector2i, type: String, count: int, rules: Dictionary) -> bool:
	if str(layout["nodes"][cell]["type"]) != "combat": return false
	if cell.x < int(rules["first_step"]) or cell.x > count - int(rules["last_step_from_boss"]): return false
	if (layout["children"].get(cell, []) as Array).size() < int((rules["min_outgoing_edges"] as Dictionary).get(type, 0)): return false
	for neighbor: Vector2i in layout["parents"].get(cell, []) + layout["children"].get(cell, []):
		if str(layout["nodes"][neighbor]["type"]) == "guardian": return false
	return true

static func _search(layout: Dictionary, types: Array[String], candidates: Dictionary, rules: Dictionary, target: int, offset: int, selected: Dictionary, search: Dictionary) -> bool:
	if int(search["remaining"]) <= 0: return false
	search["remaining"] = int(search["remaining"]) - 1
	if selected.size() == target: return _routes_legal(layout, selected, rules, true)
	if types.size() - offset < target - selected.size(): return false
	var type: String = types[offset]
	for cell: Vector2i in candidates[type]:
		if selected.has(cell): continue
		selected[cell] = type
		if _routes_legal(layout, selected, rules, false) and _search(layout, types, candidates, rules, target, offset + 1, selected, search): return true
		selected.erase(cell)
	return _search(layout, types, candidates, rules, target, offset + 1, selected, search)

static func _routes_legal(layout: Dictionary, selected: Dictionary, rules: Dictionary, complete: bool) -> bool:
	# Count every recombined route, rather than only the generating walks.
	# Counts saturate at the required witness count, so work stays bounded.
	var prefixes: Dictionary = {}
	var zero_routes: int = 0
	var special_routes: int = 0
	var witnesses: int = int(rules["min_routes_with_special_when_count_at_least_2"])
	for cell: Vector2i in layout["order"]:
		var parents: Array = layout["parents"].get(cell, [])
		var low: int = 999
		var high: int = 0
		var zero: int = 1 if parents.is_empty() else 0
		var hit: int = 0
		for parent: Vector2i in parents:
			var prior: Dictionary = prefixes[parent]
			low = mini(low, int(prior["low"]))
			high = maxi(high, int(prior["high"]))
			zero = mini(witnesses, zero + int(prior["zero"]))
			hit = mini(witnesses, hit + int(prior["hit"]))
		if parents.is_empty(): low = 0
		if selected.has(cell):
			low += 1
			high += 1
			hit = mini(witnesses, hit + zero)
			zero = 0
		if high > int(rules["max_per_route"]): return false
		prefixes[cell] = {"low": low, "high": high, "zero": zero, "hit": hit}
		if (layout["children"].get(cell, []) as Array).is_empty():
			zero_routes = mini(witnesses, zero_routes + zero)
			special_routes = mini(witnesses, special_routes + hit)
	return (not bool(rules["require_route_without_special"]) or zero_routes > 0) and (not complete or selected.size() < 2 or special_routes >= witnesses)
