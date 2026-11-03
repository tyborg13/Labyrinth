extends "res://tools/encounter_measurement_bot.gd"
## Replay the actual revision-7 baseline inputs; filter standard rooms by their
## generated roster, never by substituting enemies or changing the policy.
const SlagEngine = preload("res://tools/enc03_measurement_engine.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var phase: String = Sweep.option(args, "--phase", "after")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--input", "")))
	var output: String = Sweep.option(args, "--output", "")
	assert(phase in ["before", "after"] and not output.is_empty())
	if phase == "before": Game.enemies()["slag_mortar"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/enc03_slag_before.json"))
	var policy := Policy.new()
	var engine := SlagEngine.new()
	policy.engine = engine
	var presets: Dictionary = deck_presets()
	assert(JSON.parse_string(JSON.stringify(presets)) == source["decks"], "Revision-7 baseline deck presets changed")
	assert(JSON.parse_string(JSON.stringify(defaults())) == source["defaults"], "Revision-7 policy defaults changed")
	var results: Array[Dictionary]
	var inspected: int = 0
	for record: Dictionary in source["results"]:
		var cohort: String = str(record["cohort"])
		if cohort == "warband" and record["biome"] != "fire": continue
		var map: Dictionary = Sweep.map_for_seed(int(record["seed"]), 7)
		var sample: Dictionary = {}
		for candidate: Dictionary in Sweep.samples(map, PackedStringArray([cohort])):
			var coord: Vector2i = candidate["room"]["coord"]
			if int(candidate["tier"]) == int(record["tier"]) and coord == Vector2i(int(record["coord"]["x"]), int(record["coord"]["y"])):
				sample = candidate
				break
		assert(not sample.is_empty(), "Baseline sample missing")
		var room: Dictionary = Sweep.layout(sample, map)
		inspected += 1
		if not (room["enemies"] as Array).any(func(enemy: Dictionary) -> bool: return str(enemy["type"]) == "slag_mortar"): continue
		engine.action_mix = SlagEngine.empty_mix()
		var result: Dictionary = measured_result(policy, engine, room, sample, presets, false)
		result["slag_action_mix"] = engine.action_mix.duplicate(true)
		result["slag_action_mix_version"] = 2
		result["revision7_baseline"] = record
		results.append(result)
		write_report(output, 7, cohort, presets, results)
		print("ENC03 ROOM: %s %s t%d seed%d %s HP%d turns%d %s" % [phase, cohort, record["tier"], record["seed"], result["outcome"], result["hp_lost"], result["turns"], engine.action_mix])
		var limit: int = int(Sweep.option(args, "--limit", "0"))
		if limit > 0 and results.size() >= limit: break
	print("ENC03 MEASUREMENT: PASS (%s; inspected %d baseline rooms; measured %d Slag Mortar rooms)" % [phase, inspected, results.size()])
	quit(0)
