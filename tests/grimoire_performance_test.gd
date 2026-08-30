extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")

const BENCHMARK_ITERATIONS: int = 5

var _errors: Array[String] = []

func _initialize() -> void:
	var combat_state: Dictionary = _stress_combat_state()
	var run_state: Dictionary = _stress_run_state(combat_state)
	var candidates: Array[String] = GrimoireLibrary.entry_ids_for_run_state(run_state)
	_append_unique(candidates, GrimoireLibrary.entry_ids_for_combat_state(combat_state))
	var initial_unlock: Dictionary = GrimoireLibrary.unlock_entries(run_state, candidates)
	var settled_state: Dictionary = initial_unlock.get("state", {}) as Dictionary
	settled_state[GrimoireLibrary.UNREAD_KEY] = []
	var progression: Dictionary = settled_state.get("progression", {}) as Dictionary
	progression[GrimoireLibrary.UNREAD_KEY] = []
	settled_state["progression"] = progression
	var source_hash: int = hash(settled_state)

	var expected_run_candidates: Array[String] = GrimoireLibrary.entry_ids_for_run_state(settled_state)
	var expected_combat_candidates: Array[String] = GrimoireLibrary.entry_ids_for_combat_state(combat_state)
	var repeated_unlock: Dictionary = GrimoireLibrary.unlock_entries(settled_state, candidates)
	_expect((repeated_unlock.get("added", []) as Array).is_empty(), "unchanged discoveries should not report new entries")
	_expect(hash(settled_state) == source_hash, "grimoire normalization mutated its source run state")
	_expect(
		GrimoireLibrary.entry_ids_for_run_state(repeated_unlock.get("state", {}) as Dictionary) == expected_run_candidates,
		"unchanged discovery sync changed run-state candidate semantics"
	)
	_expect(GrimoireLibrary.entry_ids_for_combat_state(combat_state) == expected_combat_candidates, "combat candidate derivation is not deterministic")
	_test_public_copy_isolation()

	var results: Dictionary = {
		"schema_version": 1,
		"entry_count": GrimoireLibrary.entries().size(),
		"run_candidate_count": expected_run_candidates.size(),
		"combat_candidate_count": expected_combat_candidates.size(),
		"semantic_digest": hash({
			"sections": GrimoireLibrary.sections(),
			"entries": GrimoireLibrary.entries(),
			"run_candidates": expected_run_candidates,
			"combat_candidates": expected_combat_candidates,
			"unlocked": repeated_unlock.get("state", {}).get(GrimoireLibrary.UNLOCKED_KEY, []),
			"unread": repeated_unlock.get("state", {}).get(GrimoireLibrary.UNREAD_KEY, [])
		})
	}
	results["entries_copy_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		GrimoireLibrary.entries()
	)
	results["entry_map_copy_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		GrimoireLibrary.entry_map()
	)
	results["normalize_ids_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		GrimoireLibrary.normalize_entry_ids(candidates)
	)
	results["run_candidates_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		GrimoireLibrary.entry_ids_for_run_state(settled_state)
	)
	results["combat_candidates_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		GrimoireLibrary.entry_ids_for_combat_state(combat_state)
	)
	results["unchanged_unlock_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		GrimoireLibrary.unlock_entries(settled_state, candidates)
	)
	results["unchanged_sync_us_per_call"] = _measure_us(BENCHMARK_ITERATIONS, func() -> void:
		var sync_candidates: Array[String] = GrimoireLibrary.entry_ids_for_run_state(settled_state)
		_append_unique(sync_candidates, GrimoireLibrary.entry_ids_for_combat_state(combat_state))
		GrimoireLibrary.unlock_entries(settled_state, sync_candidates)
	)
	print("GRIMOIRE PERFORMANCE %s" % JSON.stringify(results))
	if _errors.is_empty():
		print("GRIMOIRE PERFORMANCE RESULT: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("GRIMOIRE PERFORMANCE RESULT: FAIL (%d errors)" % _errors.size())
		quit(1)

func _stress_run_state(combat_state: Dictionary) -> Dictionary:
	var card_ids: Array = GameData.cards().keys()
	var equipment_ids: Array = GameData.equipment_ids()
	var rooms: Dictionary = {
		"4,3": {
			"type": "scavenger",
			"merchant_kind": "scavenger",
			"merchant_stock": card_ids.slice(0, mini(24, card_ids.size())),
			"npcs": [{"id": "scavenger"}]
		}
	}
	return {
		"seed": 8675309,
		"current_room": Vector2i(4, 3),
		"rooms": rooms,
		"deck_cards": card_ids,
		"reward_cards": card_ids.slice(0, mini(18, card_ids.size())),
		"attuned_magic_cards": card_ids.slice(0, mini(12, card_ids.size())),
		"magic_inventory": card_ids.slice(0, mini(30, card_ids.size())),
		"item_inventory": card_ids,
		"equipped_items": card_ids.slice(0, mini(8, card_ids.size())),
		"collected_equipment": equipment_ids,
		"equipment_inventory": equipment_ids,
		"equipped_equipment": _equipped_equipment(equipment_ids),
		"pending_reward": {"cards": card_ids.slice(0, mini(6, card_ids.size()))},
		"combat_state": combat_state,
		"progression": {
			"schema_version": 1,
			"unlocked_cards": card_ids,
			GrimoireLibrary.UNLOCKED_KEY: GrimoireLibrary.default_entry_ids(),
			GrimoireLibrary.UNREAD_KEY: []
		}
	}

func _stress_combat_state() -> Dictionary:
	var enemies: Array = []
	var enemy_types: Array = GameData.enemies().keys()
	for index: int in range(enemy_types.size()):
		enemies.append({
			"id": index + 1,
			"type": str(enemy_types[index]),
			"pos": Vector2i(index % 9, index / 9),
			"hp": 10,
			"max_hp": 10
		})
	var equipment_ids: Array = GameData.equipment_ids()
	var loot: Array = []
	for index: int in range(equipment_ids.size()):
		loot.append({"kind": "equipment", "equipment_id": str(equipment_ids[index]), "pos": Vector2i(index % 9, index / 9)})
	var card_ids: Array = GameData.cards().keys()
	return {
		"traps": [{"pos": Vector2i(2, 2), "damage": 3}],
		"enemies": enemies,
		"loot": loot,
		"collected_equipment": equipment_ids,
		"deck": {
			"hand": card_ids,
			"draw": card_ids,
			"discard": card_ids,
			"burned": card_ids.slice(0, mini(12, card_ids.size())),
			"consumed": card_ids.slice(0, mini(12, card_ids.size()))
		}
	}

func _equipped_equipment(equipment_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	var slots: Array[String] = ["weapon", "offhand", "armor", "boots", "trinket"]
	for equipment_id_var: Variant in equipment_ids:
		var equipment_id: String = str(equipment_id_var)
		var slot: String = GameData.equipment_slot(equipment_id)
		if slots.has(slot) and not result.has(slot):
			result[slot] = equipment_id
	return result

func _test_public_copy_isolation() -> void:
	var canonical_entries_hash: int = hash(GrimoireLibrary.entries())
	var entries_copy: Array = GrimoireLibrary.entries()
	(entries_copy[0] as Dictionary)["title"] = "MUTATED"
	((entries_copy[0] as Dictionary).get("body", []) as Array).append("MUTATED")
	entries_copy.clear()
	_expect(hash(GrimoireLibrary.entries()) == canonical_entries_hash, "entries() leaked its cached catalog")

	var canonical_map_hash: int = hash(GrimoireLibrary.entry_map())
	var map_copy: Dictionary = GrimoireLibrary.entry_map()
	(map_copy.values()[0] as Dictionary)["title"] = "MUTATED"
	map_copy.clear()
	_expect(hash(GrimoireLibrary.entry_map()) == canonical_map_hash, "entry_map() leaked its cached definitions")

	var entry_copy: Dictionary = GrimoireLibrary.entry_def("basic:run")
	var entry_title: String = str(entry_copy.get("title", ""))
	entry_copy["title"] = "MUTATED"
	_expect(str(GrimoireLibrary.entry_def("basic:run").get("title", "")) == entry_title, "entry_def() leaked its cached definition")

	var canonical_sections_hash: int = hash(GrimoireLibrary.sections())
	var sections_copy: Array = GrimoireLibrary.sections()
	(sections_copy[0] as Dictionary)["title"] = "MUTATED"
	sections_copy.clear()
	_expect(hash(GrimoireLibrary.sections()) == canonical_sections_hash, "sections() leaked its cached definitions")

	var card_entry_ids: Array[String] = GrimoireLibrary.entry_ids_for_card_id("spark_dart")
	var canonical_card_entry_ids: Array[String] = GrimoireLibrary.entry_ids_for_card_id("spark_dart")
	card_entry_ids.clear()
	_expect(GrimoireLibrary.entry_ids_for_card_id("spark_dart") == canonical_card_entry_ids, "card candidate lookup leaked its cached array")
	var equipment_entry_ids: Array[String] = GrimoireLibrary.entry_ids_for_equipment_id("sawtooth_knife")
	var canonical_equipment_entry_ids: Array[String] = GrimoireLibrary.entry_ids_for_equipment_id("sawtooth_knife")
	equipment_entry_ids.clear()
	_expect(GrimoireLibrary.entry_ids_for_equipment_id("sawtooth_knife") == canonical_equipment_entry_ids, "equipment candidate lookup leaked its cached array")
	var enemy_entry_ids: Array[String] = GrimoireLibrary.entry_ids_for_enemy_types(["crawler"])
	var canonical_enemy_entry_ids: Array[String] = GrimoireLibrary.entry_ids_for_enemy_types(["crawler"])
	enemy_entry_ids.clear()
	_expect(GrimoireLibrary.entry_ids_for_enemy_types(["crawler"]) == canonical_enemy_entry_ids, "enemy candidate lookup leaked its cached array")

	var source_state: Dictionary = {
		"rooms": {"0,0": {"npcs": [{"id": "scavenger"}]}},
		"current_room": Vector2i.ZERO,
		"deck_cards": ["spark_dart"],
		"progression": {
			"profile_marker": {"nested": [1, 2, 3]},
			GrimoireLibrary.UNLOCKED_KEY: GrimoireLibrary.default_entry_ids(),
			GrimoireLibrary.UNREAD_KEY: []
		}
	}
	var source_state_hash: int = hash(source_state)
	var ensured_state: Dictionary = GrimoireLibrary.ensure_run_state(source_state)
	((ensured_state.get("rooms", {}) as Dictionary).get("0,0", {}) as Dictionary)["mutated"] = true
	((ensured_state.get("progression", {}) as Dictionary).get("profile_marker", {}) as Dictionary)["mutated"] = true
	_expect(hash(source_state) == source_state_hash, "ensure_run_state() leaked its deep-copied result into the source")
	var unlock_state: Dictionary = (GrimoireLibrary.unlock_entries(source_state, ["keyword:shock"]).get("state", {}) as Dictionary)
	((unlock_state.get("rooms", {}) as Dictionary).get("0,0", {}) as Dictionary)["mutated"] = true
	((unlock_state.get("progression", {}) as Dictionary).get("profile_marker", {}) as Dictionary)["mutated"] = true
	_expect(hash(source_state) == source_state_hash, "unlock_entries() leaked its deep-copied result into the source")

func _append_unique(target: Array[String], source: Array) -> void:
	for value: Variant in source:
		var entry_id: String = str(value)
		if not entry_id.is_empty() and not target.has(entry_id):
			target.append(entry_id)

func _measure_us(iterations: int, callable: Callable) -> float:
	var started_us: int = Time.get_ticks_usec()
	for _iteration: int in range(iterations):
		callable.call()
	return float(Time.get_ticks_usec() - started_us) / float(iterations)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
