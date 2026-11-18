extends SceneTree
## Check that final first-Call receipt additions are unused by the frozen ladder.
const Cases = preload("res://tools/atk13/rule_cases.gd")
const Game = preload("res://scripts/game_data.gd")
const PROOF_RUNS: int = 64
const PROOF_ROSTER_TIMEOUT_SECONDS: int = 600
var checked: Dictionary
var rosters: Dictionary
var problems: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var fights: int = 0
	var maps: Dictionary = {}
	for id: String in Cases.DIFFICULTY_INSTANCES:
		var types: Dictionary = {}
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/private/tmp/labyrinth_codex/area-02/ladder/before/%s.json" % id))
		assert(source["results"].size() == PROOF_RUNS)
		for record: Dictionary in source["results"]:
			var seed_value: int = int(record["seed"])
			if not maps.has(seed_value): maps[seed_value] = Cases.Sweep.map_for_seed(seed_value, 7)
			var map: Dictionary = maps[seed_value]
			var coord := Vector2i(int(record["coord"]["x"]), int(record["coord"]["y"]))
			var travel := Vector2i(int(record["travel_dir"]["x"]), int(record["travel_dir"]["y"]))
			var sample: Dictionary = {"seed": seed_value, "revision": 7, "tier": record["tier"], "cohort": Cases.cohort_for(id), "room": preload("res://scripts/section_map_graph.gd").room(map, coord), "travel_dir": travel}
			var layout: Dictionary = Cases.Sweep.layout(sample, map)
			for enemy: Dictionary in layout.get("enemies", []):
				types[str(enemy["type"])] = true
				_check_type(str(enemy["type"]))
			fights += 1
		print("AREA02 ROSTER CELL: %s (64 rooms)" % id)
		rosters[id] = types.keys()
	var output: String = "/private/tmp/labyrinth_codex/area-02/ladder-provenance.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fights": fights, "rosters": rosters, "checked_types_and_summons": checked.keys(), "problems": problems}, "\t")); file.close()
	for problem: String in problems: print("FAIL: " + problem)
	print("AREA02 LADDER PROVENANCE: %s (%d natural rosters; no Call the Wind)" % ["PASS" if problems.is_empty() else "FAIL", fights])
	quit(0 if problems.is_empty() else 1)

func _check_type(id: String) -> void:
	if checked.has(id): return
	checked[id] = true
	for intent: Dictionary in Game.enemy_def(id).get("intents", []):
		for action: Dictionary in intent.get("actions", []):
			if str(action.get("type", "")) == "call_wind": problems.append("Frozen ladder contains Call the Wind: " + id)
			if action.has("minion_type"): _check_type(str(action["minion_type"]))
