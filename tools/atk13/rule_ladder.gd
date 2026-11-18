extends "res://tools/encounter_bot.gd"
## Matched difficulty measurement; unchanged production policy v2 and tier decks.
const Cases = preload("res://tools/atk13/rule_cases.gd")
const PolicyV2 = preload("res://tools/bot_policy.gd")
const DEFAULT_RUNS: int = 64

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var id: String = Sweep.option(args, "--instance", "storm_cantor")
	var count: int = int(Sweep.option(args, "--runs", str(DEFAULT_RUNS)))
	var output: String = Sweep.option(args, "--output", "user://rule-ladder.json")
	var results: Array[Dictionary]
	if args.has("--resume") and FileAccess.file_exists(output):
		var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(output))
		assert(prior is Dictionary and prior.has("results"), "Resume checkpoint must be a complete JSON report")
		results.assign(prior["results"])
		assert(results.size() <= count)
	var prefix: int = results.size()
	var checked: int = 0
	var policy := PolicyV2.new()
	var presets: Dictionary = deck_presets()
	for sample: Dictionary in Cases.samples_for(id, count):
		if checked < prefix:
			var previous: Dictionary = results[checked]
			var coord: Vector2i = sample["room"]["coord"]
			var travel: Vector2i = sample["travel_dir"]
			var same_coord: bool = Vector2i(int(previous["coord"]["x"]), int(previous["coord"]["y"])) == coord
			var same_travel: bool = Vector2i(int(previous["travel_dir"]["x"]), int(previous["travel_dir"]["y"])) == travel
			if int(previous["seed"]) != int(sample["seed"]) or int(previous["tier"]) != int(sample["tier"]) or int(previous["section_index"]) != int(sample["section_index"]) or not same_coord or not same_travel:
				push_error("Resume prefix differs from natural sample order: " + JSON.stringify({"previous": previous, "seed": sample["seed"], "tier": sample["tier"], "section_index": sample["section_index"], "coord": Store._sanitize_variant(coord), "travel_dir": Store._sanitize_variant(travel)}))
				quit(1)
				return
			checked += 1
			continue
		var result: Dictionary = policy.run_room(int(sample["seed"]), sample["layout"], presets[str(Cases.DIFFICULTY_TIER)])
		result.merge({"instance": id, "tier": sample["tier"], "coord": Store._sanitize_variant(sample["room"]["coord"]), "travel_dir": Store._sanitize_variant(sample["travel_dir"]), "section_index": sample["section_index"]})
		results.append(result)
		write_report(output, 7, id, presets, results)
		print("AREA02 LADDER RUN: %s %d/%d" % [id, results.size(), count])
	print("AREA02 LADDER: PASS (%s; %d runs)" % [id, results.size()])
	quit()
