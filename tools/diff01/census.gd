extends SceneTree
## Cheap count-only sensitivity census, including hidden mystery combats.
const Plan = preload("res://tools/diff01/plan.gd")
const Prefixes = preload("res://tools/diff01/prefixes.gd")
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Store = preload("res://scripts/analytics_store.gd")
const Sweep = preload("res://tools/encounter_sweep.gd")
const LATE_FIGHT_NUMBER: int = 6

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = Sweep.option(args, "--directory", "")
	var file := FileAccess.open(Sweep.option(args, "--output", ""), FileAccess.WRITE)
	var count: int = 0
	for seed: int in range(1, Plan.LOADOUT_COUNT + 1):
		var engine := Run.new()
		var state: Dictionary = engine.create_new_run(seed, Progression.default_data(), true)
		var prefixes: Dictionary = Prefixes.cases(state)
		for source: Dictionary in state["rooms"].values():
			var room_kind: String = str(source["type"])
			var mystery: bool = room_kind == "mystery" and str(source.get("mystery_type", "")) == "combat"
			if room_kind not in ["combat", "special", "guardian", "boss"] and not mystery: continue
			var section: int = int(source["section_index"])
			var reader := FileAccess.open(directory.path_join("entry-%d-%d.bin" % [seed, section]), FileAccess.READ)
			var entry: Dictionary = reader.get_var()
			reader.close()
			var context: Dictionary = state.duplicate(true)
			var snapshot: Dictionary = entry["snapshot"]
			for key: String in ["omens", "deck_cards", "equipped_equipment", "equipment_grafts", "equipped_items", "item_inventory", "relics", "hand_size", "heal_bonus"]:
				context[key] = snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
			context["player_hp"] = snapshot["hp"]
			context["player_max_hp"] = snapshot["max_hp"]
			context["run_stats"] = snapshot["run_stats"].duplicate(true)
			var tier: int = clampi((int(source["depth"]) - 1) % 4 + 1, 1, 3)
			var room: Dictionary = engine.room_metadata(context, source["coord"]).duplicate(true)
			if mystery:
				preload("res://scripts/section_map_graph.gd").resolve_mystery(context, room)
				room_kind = "combat"
			var scenarios: Array[Dictionary]
			scenarios.append({"scenario": "first_eligible", "fight_number": 1 + 2 * (tier - 1), "travel": Plan.incoming_direction(state, source)})
			scenarios.append({"scenario": "late_k6", "fight_number": LATE_FIGHT_NUMBER, "travel": Plan.incoming_direction(state, source)})
			scenarios.append_array(prefixes[str(source["coord"])])
			for scenario_case: Dictionary in scenarios:
				var scenario: String = str(scenario_case["scenario"])
				room["fight_number"] = int(scenario_case["fight_number"])
				print("DIFF01_CENSUS_CASE seed=%d section=%d coord=%s kind=%s scenario=%s k=%d travel=%s" % [seed, section, room["coord"], room_kind, scenario, room["fight_number"], scenario_case["travel"]])
				var layout: Dictionary = engine._combat_layout_for_room(room, scenario_case["travel"], context)
				var summoned: int = 0
				var roster: Array[String]
				for enemy: Dictionary in layout["enemies"]:
					roster.append(str(enemy["type"]))
					if bool(enemy.get("summoned", false)): summoned += 1
				var row: Dictionary = {"ladder_seed": seed, "section": section, "tier": tier, "scenario": scenario,
					"category": "normal" if room_kind == "combat" else ("objective" if room_kind == "special" else room_kind),
					"objective_kind": layout["objective"].get("special_type", layout["objective"]["type"]),
					"room_coord": str(room["coord"]), "mystery": mystery, "fight_number": room["fight_number"],
					"effective_encounter_tier": layout.get("encounter_tier", tier), "travel_direction": str(scenario_case["travel"]), "encounter_id": layout.get("encounter_id", ""), "roster": roster, "start_count": roster.size(),
					"start_summoned": summoned, "start_non_summoned": roster.size() - summoned}
				file.store_line(JSON.stringify(Store._sanitize_variant(row)))
				count += 1
	file.close()
	print("DIFF01_CENSUS_PASS rows=%d" % count)
	quit()
