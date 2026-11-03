extends SceneTree
## Replay the first requested tier-2 shadow losses in ascending seed order.
const Sweep = preload("res://tools/encounter_sweep.gd")
const Bot = preload("res://tools/encounter_bot.gd")
const Audit = preload("res://tools/encounter_shadow_audit.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_value: int = int(Sweep.option(args, "--seed", "1"))
	var count: int = int(Sweep.option(args, "--runs", "10"))
	var output: String = Sweep.option(args, "--output", "user://shadow_audit.json")
	assert(seed_value >= 0 and count > 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var presets: Dictionary = Bot.deck_presets()
	var results: Array[Dictionary]
	var first_seed: int = seed_value
	while results.size() < count:
		assert(seed_value - first_seed < Sweep.MAX_SEED_SCAN, "Audit seed scan exhausted")
		var map_state: Dictionary = Sweep.map_for_seed(seed_value)
		for sample: Dictionary in Sweep.samples(map_state, PackedStringArray(["standard"])):
			if sample["biome"] != "shadow" or int(sample["tier"]) != 2: continue
			var policy := Audit.new()
			print("SHADOW AUDIT BEGIN: seed %d" % seed_value)
			var result: Dictionary = policy.run_room(seed_value, Sweep.layout(sample, map_state), presets["2"])
			result["coord"] = Sweep.Store._sanitize_variant(sample["room"]["coord"])
			result["biome"] = "shadow"
			result["tier"] = 2
			policy.hand_query.free()
			if not result["won"]: results.append(result)
			var file := FileAccess.open(output, FileAccess.WRITE)
			file.store_string(JSON.stringify({"results": results, "last_seed": seed_value}, "\t"))
			file.close()
			print("SHADOW AUDIT REPLAY: PASS (seed %d; %s; %d turns)" % [seed_value, result["outcome"], result["turns"]])
		seed_value += 1
	print("SHADOW AUDIT: PASS (%d tier-2 shadow losses)" % results.size())
	quit()
