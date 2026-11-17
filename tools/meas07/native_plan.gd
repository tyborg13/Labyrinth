extends RefCounted
## Eight native placements per boss; standard controls are paired by loadout,
## section and tier. No boss is transplanted into another section.
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const FIRST_LADDER_SEED: int = 1
const LOADOUT_COUNT: int = 8
const DEFAULT_TRAVEL_DIR: Vector2i = Vector2i.ZERO

static func make_plan(directory: String, observer: Object) -> void:
	var tasks: Array[Dictionary]
	for ladder_seed: int in range(FIRST_LADDER_SEED, FIRST_LADDER_SEED + LOADOUT_COUNT):
		var engine := Run.new()
		var state: Dictionary = engine.create_new_run(ladder_seed, Progression.default_data(), true)
		for section: int in range(6):
			var reader := FileAccess.open(directory.path_join("entry-%d-%d.bin" % [ladder_seed, section]), FileAccess.READ)
			var entry: Dictionary = reader.get_var()
			reader.close()
			var snapshot: Dictionary = entry["snapshot"]
			var native: Dictionary = state.duplicate(true)
			for key: String in ["omens", "deck_cards", "equipped_equipment", "equipment_grafts", "equipped_items", "item_inventory", "relics", "hand_size", "heal_bonus"]:
				native[key] = snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
			native["player_hp"] = snapshot["hp"]
			native["player_max_hp"] = snapshot["max_hp"]
			native["run_stats"] = snapshot["run_stats"].duplicate(true)
			var rooms: Array[Dictionary]
			for room: Dictionary in state["rooms"].values():
				if int(room["section_index"]) == section: rooms.append(room)
			rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["map_step"]) < int(b["map_step"]) if int(a["map_step"]) != int(b["map_step"]) else float(a["map_lane"]) < float(b["map_lane"]))
			for kind: String in ["guardian", "boss"]:
				var selected: Dictionary = {}
				for room: Dictionary in rooms:
					if str(room["type"]) == kind:
						selected = room
						break
				assert(not selected.is_empty())
				var tier: int = clampi((int(selected["depth"]) - 1) % 4 + 1, 1, 3)
				var boss_id: String = str(selected["boss_id"])
				var identity: String = str(Guardians.for_boss(boss_id)["id"]) if kind == "guardian" else boss_id
				var baseline: Dictionary = {}
				for room: Dictionary in rooms:
					if str(room["type"]) == "combat" and (int(room["depth"]) - 1) % 4 + 1 == tier:
						baseline = room
						break
				assert(not baseline.is_empty(), "Native standard room at matching tier")
				for control: bool in [false, true]:
					var source: Dictionary = baseline if control else selected
					var room: Dictionary = engine.room_metadata(native, source["coord"]).duplicate(true)
					# Tier-matched production encounter-table scheduling: first
					# eligible fight number for the room's native depth band.
					room["fight_number"] = 1 + 2 * (tier - 1)
					# A tier-2/3 scheduled fight, or a later section, has
					# already completed combat. Preserve that production
					# objective context when pairing an entry loadout.
					var context: Dictionary = native.duplicate(true)
					if section > 0 or tier > 1:
						for previous: Dictionary in context["rooms"].values():
							if str(previous["type"]) == "combat" and previous["coord"] != room["coord"]:
								previous["cleared"] = true
								break
					var layout: Dictionary = engine._combat_layout_for_room(room, DEFAULT_TRAVEL_DIR, context)
					if control: assert(int(layout["encounter_tier"]) == tier)
					var cell: String = "standard_for_" + identity if control else identity
					var path: String = directory.path_join("%s-l%d.bin" % [cell, ladder_seed])
					observer.save_variant(path, {"layout": layout, "snapshot": snapshot, "room": room})
					tasks.append({"cell": cell, "kind": "combat" if control else kind, "boss_id": boss_id,
						"identity": "standard" if control else identity, "paired_boss": identity,
						"section": section, "tier": tier, "depth": room["depth"], "ladder_seed": ladder_seed,
						"map_seed": ladder_seed, "room_coord": str(room["coord"]),
						"room_seed": Rooms.new()._room_seed(ladder_seed, room["coord"], 101),
						"input_file": path, "input_sha256": FileAccess.get_sha256(path)})
	assert(tasks.size() == 192)
	var output := FileAccess.open(directory.path_join("plan.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(tasks))
	output.close()
	print("MEAS07_NATIVE_PLAN_PASS tasks=%d cells=24" % tasks.size())
