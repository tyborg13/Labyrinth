extends "res://tools/encounter_measurement_bot.gd"
## Paired offline standard-room measurements. The only experimental setup field
## is umbra.stage; policy, engine transitions, rosters and production data stay intact.
const ELEMENTS: PackedStringArray = ["fire", "earth", "ice", "air", "lightning", "shadow"]
var room_dark: String = "on"
var measured_tier: int = 1
var first_seed: int = 1
var runs_per_group: int = 200

static func darkness_option(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with("--room-dark="): return arg.trim_prefix("--room-dark=")
	return Sweep.option(args, "--room-dark", "on")

static func prepare_room(room: Dictionary, biome: String, dark: String) -> Dictionary:
	if dark != "off" or biome != "shadow": return room
	var prepared: Dictionary = room.duplicate(true)
	var umbra: Dictionary = prepared.get("umbra", {}).duplicate(true)
	umbra["stage"] = CombatEngine.UMBRA_STAGE_CLEAR
	prepared["umbra"] = umbra
	return prepared

func write_report(output: String, revision: int, cohort: String, presets: Dictionary, results: Array[Dictionary]) -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"revision": revision, "cohort": cohort, "defaults": defaults(), "decks": presets,
		"policy_sha256": FileAccess.get_sha256("res://tools/encounter_bot.gd"),
		"room_dark": room_dark, "tier": measured_tier, "first_seed": first_seed, "runs_per_group": runs_per_group,
		"results": results}, "\t"))
	file.close()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	room_dark = darkness_option(args)
	if room_dark not in ["on", "off"]:
		push_error("--room-dark must be on or off")
		quit(1)
		return
	measured_tier = int(Sweep.option(args, "--tier", "1"))
	first_seed = int(Sweep.option(args, "--seed", "1"))
	runs_per_group = int(Sweep.option(args, "--runs", "200"))
	assert(measured_tier in [1, 2, 3] and first_seed >= 0 and runs_per_group > 0)
	var output: String = Sweep.option(args, "--output", "user://encounter_shadow.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var elements: PackedStringArray = PackedStringArray(["shadow"]) if room_dark == "off" else ELEMENTS
	var counts: Dictionary = {}
	for element: String in elements: counts[element] = 0
	var presets: Dictionary = deck_presets()
	var policy := CommittedPolicy.new()
	var measurement_engine := MeasurementEngine.new()
	var results: Array[Dictionary]
	var identities: Dictionary = {}
	var resume_path: String = Sweep.option(args, "--resume-report", "")
	if not resume_path.is_empty():
		var resumed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resume_path))
		assert(resumed["room_dark"] == room_dark and int(resumed["tier"]) == measured_tier and int(resumed["first_seed"]) == first_seed)
		assert(resumed["defaults"] == JSON.parse_string(JSON.stringify(defaults())) and resumed["decks"] == JSON.parse_string(JSON.stringify(presets)))
		for row: Dictionary in resumed["results"]:
			assert(row["biome"] in elements and int(row["tier"]) == measured_tier)
			var identity: String = "%d/%s" % [int(row["seed"]), row["biome"]]
			assert(not identities.has(identity))
			identities[identity] = true
			counts[row["biome"]] += 1
			assert(int(counts[row["biome"]]) <= runs_per_group)
			results.append(row)
	var seed_value: int = first_seed
	while counts.values().min() < runs_per_group:
		assert(seed_value - first_seed < Sweep.MAX_SEED_SCAN, "Seed scan exhausted")
		var map_state: Dictionary = Sweep.map_for_seed(seed_value, Sweep.LATEST_REVISION)
		for sample: Dictionary in Sweep.samples(map_state, PackedStringArray(["standard"])):
			var biome: String = sample["biome"]
			if int(sample["tier"]) != measured_tier or not counts.has(biome) or int(counts[biome]) >= runs_per_group: continue
			if identities.has("%d/%s" % [seed_value, biome]): continue
			var natural: Dictionary = Sweep.layout(sample, map_state)
			var room: Dictionary = prepare_room(natural, biome, room_dark)
			var result: Dictionary = measured_result(policy, measurement_engine, room, sample, presets, false)
			var enemy_types: PackedStringArray
			for enemy: Dictionary in natural["enemies"]:
				if not enemy_types.has(str(enemy["type"])): enemy_types.append(str(enemy["type"]))
			enemy_types.sort()
			result.merge({"room_dark": room_dark, "enemy_types": enemy_types})
			results.append(result)
			counts[biome] += 1
			write_report(output, Sweep.LATEST_REVISION, "standard", presets, results)
			print("SHADOW SWEEP RUN: " + JSON.stringify(result))
		seed_value += 1
	print("SHADOW SWEEP: PASS (%d runs; tier %d; room-dark=%s; %d per element)" % [results.size(), measured_tier, room_dark, runs_per_group])
	quit()
