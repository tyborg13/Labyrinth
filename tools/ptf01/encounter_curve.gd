extends SceneTree
## 300 seeded uniformly random legal routes per section, shared by old/new.
## Noncombat choices/combat outcomes are bypassed; this measures authored rooms,
## not clear rates. Production graph, mystery resolution, rosters and HP factory.
const Run = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tables = preload("res://scripts/encounter_tables.gd")
const Old = preload("res://tools/ptf01/baseline_generator.gd")
const SEEDS: int = 300
const TESTER_SEEDS: int = 20
const ROUTE_SEED_SALT: int = 5101
const DEFAULT_OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-01/encounter_curve.json"
func sample(layout: Dictionary) -> Dictionary:
	var hp: int = 0
	var units: Array[String]
	for enemy: Dictionary in layout["enemies"]:
		hp += int(enemy["hp"])
		units.append(str(enemy["type"]))
	return {"units": units, "count": units.size(), "hp": hp, "encounter_id": layout.get("encounter_id", ""), "tier": layout.get("encounter_tier", 0)}
func _initialize() -> void:
	var output_path: String = preload("res://tools/encounter_sweep.gd").option(OS.get_cmdline_user_args(), "--output", DEFAULT_OUTPUT)
	var engine := Run.new()
	var baseline := Run.new()
	baseline._room_generator = Old.new()
	var records: Array[Dictionary]
	for seed_value: int in range(1, SEEDS + 1):
		var initial: Dictionary = engine.create_new_run(seed_value, Progression.default_data(), true)
		for section_index: int in range(3):
			var state: Dictionary = initial.duplicate(true)
			var entry: Vector2i = Graph.section(state, section_index)["entry"]
			state["current_room"] = entry
			var current: Dictionary = Graph.room(state, entry)
			current["visited"] = true
			current["cleared"] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value * ROUTE_SEED_SALT + section_index
			var old_history: Array = []
			var new_history: Array = []
			while str(current["type"]) != "boss":
				# Same legality predicate as available_moves; room completion is
				# synthetic here, all exits revealed by the proof only.
				for connection: Dictionary in current["connections"]:
					Graph.room(state, connection["coord"])["revealed"] = true
				var moves: Array[Vector2i] = engine.available_moves(state)
				assert(not moves.is_empty())
				var destination: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
				var travel_dir := Vector2i.ZERO
				for connection: Dictionary in current["connections"]:
					if connection["coord"] == destination: travel_dir = connection.get("door_dir", Vector2i.ZERO)
				current["sealed"] = true
				current = Graph.room(state, destination)
				Graph.resolve_mystery(state, current)
				Tables.record_room_entry(state, current)
				current["visited"] = true
				state["current_room"] = destination
				var kind: String = str(current["type"])
				if kind in ["combat", "special", "guardian"]:
					var record: Dictionary = {"seed": seed_value, "section": section_index + 1, "k": current["fight_number"], "step": current["step"] if current.has("step") else current.get("map_step", -1), "kind": kind, "coord": str(destination)}
					for variant: String in ["old", "new"]:
						state["encounter_history"] = old_history if variant == "old" else new_history
						var layout: Dictionary = baseline._combat_layout_for_room(current, travel_dir, state) if variant == "old" else engine._combat_layout_for_room(current, travel_dir, state)
						record[variant] = sample(layout)
						if layout.has("encounter_id"):
							if variant == "old": old_history.append(layout["encounter_id"])
							else: new_history.append(layout["encounter_id"])
						if kind == "combat":
							assert(record[variant]["count"] > 0)
							if variant == "new": assert(record[variant]["count"] <= Tables.unit_cap(int(record[variant]["tier"]), int(current["fight_number"])))
					records.append(record)
				current["cleared"] = true
		if seed_value % 50 == 0: print("PTF01 CURVE seeds=", seed_value)
	var cases: Array[Dictionary]
	for seed_value: int in range(1, TESTER_SEEDS + 1):
		var state: Dictionary = engine.create_new_run(seed_value, Progression.default_data(), true)
		for shape: Dictionary in [{"k": 2, "step": 4, "depth": 2}, {"k": 3, "step": 7, "depth": 3}]:
			# Controlled reproduction of the tester's k/depth/step. Choose the
			# first generated node at that step as its immutable coord/element.
			var fixture: Dictionary = {}
			for node: Dictionary in state["rooms"].values():
				if int(node.get("section_index", -1)) == 0 and int(node.get("map_step", -1)) == int(shape["step"]):
					fixture = node.duplicate(true)
					break
			assert(not fixture.is_empty(), "Tester step exists")
			fixture.merge({"type": "combat", "npcs": [], "depth": shape["depth"], "fight_number": shape["k"]}, true)
			var layout: Dictionary = engine._combat_layout_for_room(fixture, Vector2i.ZERO, state)
			cases.append({"seed": seed_value, "k": shape["k"], "step": shape["step"], "element": fixture["element"], "biome": layout["biome"], "new": sample(layout)})
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"records": records, "tester_cases": cases}, "\t"))
	file.close()
	print("PTF01 CURVE: PASS seeds=%d sections=3 records=%d tester_cases=%d output=%s" % [SEEDS, records.size(), cases.size(), output_path])
	quit(0)
