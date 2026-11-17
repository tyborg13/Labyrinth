extends RefCounted
## Native production rooms; typed archived ladder loadouts are never edited.
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/analytics_store.gd")
const LOADOUT_COUNT: int = 8
const FALLBACK_TRAVEL_DIRECTION: Vector2i = Vector2i.RIGHT

static func make_plan(directory: String, observer: Object) -> void:
	var tasks: Array[Dictionary]
	var inventory: Array[Dictionary]
	for seed: int in range(1, LOADOUT_COUNT + 1):
		var engine := Run.new()
		var state: Dictionary = engine.create_new_run(seed, Progression.default_data(), true)
		for section: int in range(6):
			var reader := FileAccess.open(directory.path_join("entry-%d-%d.bin" % [seed, section]), FileAccess.READ)
			var entry: Dictionary = reader.get_var()
			reader.close()
			var snapshot: Dictionary = entry["snapshot"]
			var context: Dictionary = state.duplicate(true)
			for key: String in ["omens", "deck_cards", "equipped_equipment", "equipment_grafts", "equipped_items", "item_inventory", "relics", "hand_size", "heal_bonus"]:
				context[key] = snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
			context["player_hp"] = snapshot["hp"]
			context["player_max_hp"] = snapshot["max_hp"]
			context["run_stats"] = snapshot["run_stats"].duplicate(true)
			var rooms: Array[Dictionary]
			for room: Dictionary in state["rooms"].values():
				if int(room.get("section_index", -1)) == section and str(room["type"]) in ["combat", "special", "guardian", "boss"]: rooms.append(room)
			rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["map_step"]) < int(b["map_step"]) if int(a["map_step"]) != int(b["map_step"]) else float(a["map_lane"]) < float(b["map_lane"]))
			var chosen: Dictionary = {}
			for source: Dictionary in rooms:
				var tier: int = clampi((int(source["depth"]) - 1) % 4 + 1, 1, 3)
				var room: Dictionary = engine.room_metadata(context, source["coord"]).duplicate(true)
				room["fight_number"] = 1 + 2 * (tier - 1)
				var travel: Vector2i = incoming_direction(state, room)
				print("DIFF01_ROOM seed=%d section=%d coord=%s kind=%s travel=%s" % [seed, section, room["coord"], room["type"], travel])
				var layout: Dictionary = engine._combat_layout_for_room(room, travel, context)
				var kind: String = str(room["type"])
				var category: String = "normal" if kind == "combat" else ("objective" if kind == "special" else kind)
				var objective_kind: String = str(layout["objective"].get("special_type", layout["objective"]["type"]))
				assert(kind != "combat" or objective_kind == "kill_all", "Current normal rooms must have the normal objective")
				var initial: Dictionary = Combat.new().create_combat(seed, layout, snapshot)
				var summoned: int = 0
				var enemy_rows: Array[Dictionary]
				for enemy: Dictionary in initial["enemies"]:
					if bool(enemy.get("summoned", false)): summoned += 1
					enemy_rows.append({"type": enemy["type"], "hp": enemy["hp"], "summoned": enemy.get("summoned", false)})
				var meta: Dictionary = {"section": section, "tier": tier, "category": category, "kind": kind,
					"objective_kind": objective_kind, "ladder_seed": seed, "depth": room["depth"],
					"room_coord": str(room["coord"]), "travel_direction": str(travel), "map_seed": seed,
					"room_seed": Rooms.new()._room_seed(seed, room["coord"], 101),
					"identity": str(layout.get("guardian_id", room.get("boss_id", "standard"))),
					"encounter_id": layout.get("encounter_id", ""), "start_count": initial["enemies"].size(),
					"start_summoned": summoned, "start_non_summoned": initial["enemies"].size() - summoned,
					"enemy_roster": enemy_rows, "umbra_depth": initial.get("umbra_depth", 0)}
				inventory.append(meta.duplicate(true))
				var selection_key: String = "normal-t%d" % tier if category == "normal" else category
				# Retain all objectives to rotate rare kinds across repeat blocks.
				if category != "objective" and chosen.has(selection_key): continue
				chosen[selection_key] = true
				var path: String = directory.path_join("input-%d.bin" % tasks.size())
				observer.save_variant(path, {"layout": layout, "snapshot": snapshot, "room": room})
				meta.merge({"input_file": path, "input_sha256": FileAccess.get_sha256(path),
					"cell": "s%d-%s" % [section, selection_key]})
				tasks.append(meta)
	for pair: Array in [["plan.json", tasks], ["inventory.json", inventory]]:
		var output := FileAccess.open(directory.path_join(pair[0]), FileAccess.WRITE)
		output.store_string(JSON.stringify(Store._sanitize_variant(pair[1])))
		output.close()
	print("DIFF01_PLAN_PASS tasks=%d rooms=%d" % [tasks.size(), inventory.size()])

static func incoming_direction(state: Dictionary, room: Dictionary) -> Vector2i:
	var incoming: Array[Dictionary]
	for previous: Dictionary in state["rooms"].values():
		for link: Dictionary in previous.get("connections", []):
			if link["coord"] == room["coord"]:
				incoming.append({"coord": str(previous["coord"]), "direction": link["door_dir"]})
	incoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["coord"] < b["coord"])
	return incoming[0]["direction"] if not incoming.is_empty() else FALLBACK_TRAVEL_DIRECTION
