extends RefCounted
## Natural revision-7 rooms; sampling never substitutes encounters or rule dials.
const Sweep = preload("res://tools/encounter_sweep.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const FIRST_SEED: int = 1
const DIFFICULTY_TIER: int = 3
const DIFFICULTY_INSTANCES: Array = ["storm_cantor", "zekarion", "dynamo", "snare_lightning", "ashen_reaver", "rimejaw", "gallows_roc", "vyraketh", "iskaldra", "vaeloryx"]

static func instance_id(room: Dictionary) -> String:
	if not str(room.get("guardian_id", "")).is_empty(): return str(room["guardian_id"])
	if str(room.get("type", "")) == "boss": return str(room.get("boss_id", ""))
	var special: String = str(room.get("special_type", ""))
	if special == "warband": return str(Warband.order_for_objective(room["objective"]).get("battlefield_instance", ""))
	if special == "last_light": return "last_light"
	if special == "umbral_snare":
		var rule: Dictionary = room.get("battlefield_rule", {})
		for id: String in Rules.data()["instances"]:
			if id.begins_with("snare_") and Rules.instance_for(id) == rule: return id
		return "snare_" + str(room.get("element", ""))
	for enemy: Dictionary in room.get("enemies", []):
		if str(enemy.get("type", "")) == "gale_herald": return "gale_herald"
	return ""

static func cohort_for(id: String) -> String:
	if id in ["vyraketh", "tharokh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]: return "boss"
	if id in ["ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "craghide", "last_lamplighter"]: return "guardian"
	if id.begins_with("snare_"): return "snare"
	if id == "last_light": return "last_light"
	if id == "gale_herald": return "standard"
	return "warband"

static func samples_for(id: String, count: int, tier: int = DIFFICULTY_TIER) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for seed_value: int in range(FIRST_SEED, Sweep.MAX_SEED_SCAN):
		var map: Dictionary = Sweep.map_for_seed(seed_value, 7)
		for sample: Dictionary in Sweep.samples(map, PackedStringArray([cohort_for(id)])):
			if int(sample["tier"]) != tier: continue
			# Filter before constructing expensive rooms where the map knows identity.
			if sample["cohort"] == "guardian" and str(sample["room"].get("guardian_id", "")) != id: continue
			if sample["cohort"] == "boss" and str(sample["room"].get("boss_id", "")) != id: continue
			var room: Dictionary = Sweep.layout(sample, map)
			var found: String = instance_id(room)
			if sample["cohort"] == "boss": found = str(sample["room"].get("boss_id", ""))
			if sample["cohort"] == "guardian": found = str(sample["room"].get("guardian_id", ""))
			if sample["cohort"] == "snare": found = str(preload("res://scripts/snare_pressure_rules.gd").definition({"objective": room["objective"]}).get("battlefield_instance", ""))
			if found != id: continue
			sample["layout"] = room
			result.append(sample)
			if result.size() == count: return result
	assert(false, "Natural rule instance not found: " + id)
	return result
