extends RefCounted
## Generated rooms freeze their tier dials. Missing dials on old saves mean
## identity scaling, including all subsequent arrivals in that saved fight.
const DATA_PATH: String = "res://data/difficulty_tiers.json"
const MAX_STARTERS: int = 5
const REMOVED_ENEMY_HP_FACTOR: float = 1.2
# Tier damage bonuses are whole numbers authored in the table (director decision).
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		assert(parsed is Dictionary and int(parsed.get("version", 0)) == 1, "Invalid difficulty tiers")
		_data = parsed
	return _data

static func tier(room: Dictionary) -> String:
	match str(room.get("type", "")):
		"special": return "objective"
		"guardian": return "guardian"
		"boss": return "boss"
	return "normal"

# Pre-battle saves already own the dials, including explicit identity dials
# for old generated rooms. Rebuilding their geometry never rereads the table.
static func freeze(layout: Dictionary) -> void:
	if layout.has("difficulty_stats"): return
	layout["difficulty_tier"] = tier(layout)
	var entries: Dictionary = data()["tiers"].get(layout["difficulty_tier"], {})
	if entries.is_empty(): return
	var section: int = clampi(int((maxi(1, int(layout["depth"])) - 1) / 4), 0, 5)
	var entry: Dictionary = entries.get(str(layout.get("special_type", "")), entries["default"])
	layout["difficulty_stats"] = {"hp_percent": int(entry["hp_percent"][section]), "damage_bonus": entry["damage_bonus"][section]}

static func arrival_hp(state: Dictionary, hp: int) -> int:
	return ceili(float(hp) * int(state.get("difficulty_stats", {}).get("hp_percent", 100)) / 100.0)

static func damage_bonus(state: Dictionary) -> int:
	var value: Variant = state.get("difficulty_stats", {}).get("damage_bonus", 0)
	assert(value is int or value is float, "Invalid tier damage bonus")
	return int(value)

static func starter_count(layout: Dictionary) -> int:
	var count: int = 0
	for enemy: Dictionary in layout["enemies"]:
		if not bool(enemy.get("summoned", false)): count += 1
	return count

static func _protected(layout: Dictionary, enemy: Dictionary) -> bool:
	var type: String = str(enemy["type"])
	# Exit generation guarantees this movement-control anchor by enemy type.
	if str(layout.get("objective", {}).get("type", "")) == "reach_exit" and type == "chainbound_gaoler": return true
	return bool(enemy.get("is_leader", false)) or bool(enemy.get("snare_sealbinder", false)) or int(enemy["id"]) == int(layout.get("objective", {}).get("leader_id", -1)) or type == str(layout.get("guardian_id", "")) or type == str(layout.get("boss_id", "")) or (str(layout.get("special_type", "")) == "umbral_snare" and enemy == layout["enemies"][0])

static func finalize(layout: Dictionary) -> void:
	freeze(layout)
	var enemies: Array = layout["enemies"]
	var excess: int = maxi(0, starter_count(layout) - MAX_STARTERS)
	var removed: int = int(layout.get("encounter_trimmed_enemies", 0))
	# Authored roster order is the existing trim order; retain IDs and objective
	# bindings. Warband escorts and Snare hunters occupy the tail of that order.
	for index: int in range(enemies.size() - 1, -1, -1):
		if excess == 0: break
		var enemy: Dictionary = enemies[index]
		if bool(enemy.get("summoned", false)) or _protected(layout, enemy): continue
		enemies.remove_at(index)
		excess -= 1
		removed += 1
	assert(excess == 0, "Protected room roster exceeds the starting cap")
	layout["objective"]["initial_enemy_count"] = enemies.size()
	if str(layout.get("special_type", "")) == "umbral_snare":
		layout["objective"]["hunters_spawned"] = enemies.size() - (layout["objective"]["exits"] as Array).size()
	for enemy: Dictionary in enemies:
		if str(layout.get("special_type", "")) == "ember_hoarder" and int(enemy["id"]) == int(layout["objective"]["hoarder_id"]): continue
		var hp: int = int(enemy["max_hp"])
		if removed > 0: hp = ceili(float(hp) * pow(REMOVED_ENEMY_HP_FACTOR, removed))
		enemy["max_hp"] = arrival_hp(layout, hp)
		enemy["hp"] = enemy["max_hp"]
	# Derive the Hoarder from the already rounded, fully scaled brood, rather
	# than rounding its previous 3x Health independently.
	if str(layout.get("special_type", "")) == "ember_hoarder":
		preload("res://scripts/hoarder_room_rules.gd").configure(layout)
	# Hunted increases the Health each starter would have had in this room.
	# Preserve the completed trim, tier and derived Health rounding first.
	var hunted_compensations: int = int(layout.get("omen_enemy_hp_compensations", 0))
	if hunted_compensations > 0:
		for enemy: Dictionary in enemies:
			enemy["max_hp"] = ceili(float(enemy["max_hp"]) * pow(REMOVED_ENEMY_HP_FACTOR, hunted_compensations))
			enemy["hp"] = enemy["max_hp"]
