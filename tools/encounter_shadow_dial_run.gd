extends "res://tools/encounter_measurement_bot.gd"
## Headless meas-05 entry point. Catalog first, then paired accepted samples.
const Dials = preload("res://tools/encounter_shadow_dials.gd")
const Observer = preload("res://tools/encounter_shadow_damage_engine.gd")
const ELEMENTS: PackedStringArray = ["fire", "earth", "ice", "air", "lightning", "shadow"]

func save_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(Store._sanitize_variant(value), "\t"))
	file.close()

func catalog(first: int, count: int, output: String) -> void:
	var rows: Array[Dictionary]
	var counts: Dictionary = {}
	for tier: int in [1, 2, 3]:
		for biome: String in ELEMENTS: counts["%d/%s" % [tier, biome]] = 0
	var seed_value: int = first
	while counts.values().min() < count:
		assert(seed_value - first < Sweep.MAX_SEED_SCAN)
		var map_state: Dictionary = Sweep.map_for_seed(seed_value)
		for sample: Dictionary in Sweep.samples(map_state, PackedStringArray(["standard"])):
			var key: String = "%d/%s" % [int(sample["tier"]), sample["biome"]]
			if int(counts[key]) >= count: continue
			var room: Dictionary = Sweep.layout(sample, map_state)
			var row: Dictionary = Sweep.composition(sample, room)
			var enemy_types: Dictionary = {}
			for enemy: Dictionary in room["enemies"]: enemy_types[enemy["type"]] = int(enemy_types.get(enemy["type"], 0)) + 1
			row["enemy_counts"] = enemy_types
			row["layout_sha256"] = Sweep.digest(room)
			rows.append(row)
			counts[key] += 1
		seed_value += 1
	save_json(output, {"revision": Sweep.LATEST_REVISION, "first_seed": first, "runs_per_group": count, "last_seed": seed_value - 1, "results": rows})
	print("SHADOW DIAL CATALOG: PASS (%d rooms; %d per tier/element; seeds %d..%d)" % [rows.size(), count, first, seed_value - 1])

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = Sweep.option(args, "--output", "user://shadow_dials.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var runs: int = int(Sweep.option(args, "--runs", "200"))
	assert(runs > 0)
	if args.has("--make-catalog"):
		catalog(int(Sweep.option(args, "--seed", "1")), runs, output)
		quit()
		return
	var group: String = Sweep.option(args, "--group", "baseline")
	var tier: int = int(Sweep.option(args, "--tier", "1"))
	var biome: String = Sweep.option(args, "--biome", "shadow")
	var offset: int = int(Sweep.option(args, "--offset", "0"))
	var selection: Dictionary = JSON.parse_string(Sweep.option(args, "--selection", "{}"))
	assert(group in Dials.GROUPS and tier in [1, 2, 3] and biome in ELEMENTS and offset >= 0)
	assert(group == "baseline" or biome == "shadow")
	if group == "G": assert(not selection.get("intent", "").is_empty() and not selection.get("intent_enemy", "").is_empty())
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--catalog", "")))
	var selected: Array[Dictionary]
	for row: Dictionary in source["results"]:
		if int(row["tier"]) == tier and row["biome"] == biome: selected.append(row)
	assert(offset + runs <= selected.size())
	var presets: Dictionary = deck_presets()
	var policy := CommittedPolicy.new()
	var observer := Observer.new()
	observer.room_biome = biome
	observer.attack_reduction = Dials.damage_delta(group)
	if group == "G":
		observer.reduce_intent = selection["intent"]
		observer.reduce_enemy = selection["intent_enemy"]
	policy.engine = observer
	var results: Array[Dictionary]
	var report: Dictionary = {"revision": Sweep.LATEST_REVISION, "group": group, "tier": tier, "biome": biome, "offset": offset,
		"damage_provenance": Observer.ATTRIBUTION_VERSION,
		"runs": runs, "selection": selection, "room_dark": "on", "defaults": defaults(), "decks": presets,
		"policy_sha256": FileAccess.get_sha256("res://tools/encounter_bot.gd"), "results": results}
	if FileAccess.file_exists(output):
		var resumed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output))
		for key: String in report:
			if key != "results": assert(resumed[key] == JSON.parse_string(JSON.stringify(report[key])), "Checkpoint metadata mismatch: " + key)
		for row: Dictionary in resumed["results"]: results.append(row)
	assert(results.size() <= runs)
	for index: int in range(offset, offset + runs):
		var expected: Dictionary = selected[index]
		var map_state: Dictionary = Sweep.map_for_seed(int(expected["seed"]))
		var found: bool = false
		for sample: Dictionary in Sweep.samples(map_state, PackedStringArray(["standard"])):
			if int(sample["tier"]) != tier or sample["biome"] != biome: continue
			var coord: Vector2i = sample["room"]["coord"]
			var travel: Vector2i = sample["travel_dir"]
			assert(coord == Vector2i(int(expected["coord"]["x"]), int(expected["coord"]["y"])) and travel == Vector2i(int(expected["travel_dir"]["x"]), int(expected["travel_dir"]["y"])))
			found = true
			if index - offset < results.size():
				assert(int(results[index - offset]["seed"]) == int(expected["seed"]))
				continue
			var natural: Dictionary = Sweep.layout(sample, map_state)
			assert(Sweep.digest(natural) == expected["layout_sha256"], "Production layout changed since catalog")
			var room: Dictionary = Dials.layout(sample, map_state, group, selection) if group == "F" else Dials.prepare_room(natural, biome, group)
			var row: Dictionary = measured_result(policy, observer, room, sample, presets, false)
			row["damage"] = observer.final_observation.duplicate(true)
			row["natural_layout_sha256"] = expected["layout_sha256"]
			row["override_layout_sha256"] = Sweep.digest(room)
			var roster: Array[Dictionary]
			for enemy: Dictionary in room["enemies"]: roster.append({"id": enemy["id"], "type": enemy["type"], "hp": enemy["max_hp"]})
			row["roster"] = roster
			var damage_sum: int = 0
			for hit: Dictionary in row["damage"]["hits"]: damage_sum += int(hit["hp_lost"])
			assert(damage_sum == int(row["hp_lost"]), "Observed damage does not reconcile")
			results.append(row)
			save_json(output, report)
			print("SHADOW DIAL RUN: %s t%d %s seed %d %s turns %d hp %d" % [group, tier, biome, int(row["seed"]), row["outcome"], int(row["turns"]), int(row["hp_lost"])])
		assert(found, "Catalog sample no longer eligible")
	print("SHADOW DIAL BATCH: PASS (%s; tier %d; %s; offset %d; %d runs)" % [group, tier, biome, offset, results.size()])
	quit()
