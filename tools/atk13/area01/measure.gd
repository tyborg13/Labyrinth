extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Battle = preload("res://tools/run_curve_combat.gd")
const Sweep = preload("res://tools/encounter_sweep.gd")
const Store = preload("res://scripts/analytics_store.gd")
const PROOF_INPUT_POLL_MSEC: int = 100
const PROOF_RNG_STRIDE: int = 1000003
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args := OS.get_cmdline_user_args()
	var id: String = Sweep.option(args, "--boss", "")
	var directory: String = Sweep.option(args, "--inputs", "")
	var entries: Array[Dictionary]
	var paths: Array[String]
	for seed_value: int in range(1, 10): paths.append(directory.path_join("ladder-%d.bin" % seed_value))
	if id == "storm_cantor":
		while not FileAccess.file_exists(directory.path_join("cantor_ready")):
			if FileAccess.file_exists(directory.path_join("cantor_failed")):
				push_error("Natural Cantor ladder recovery failed; see capture logs")
				quit(1)
				return
			OS.delay_msec(PROOF_INPUT_POLL_MSEC)
		for name: String in DirAccess.get_files_at(directory):
			if name.begins_with("cantor-ladder-") and name.ends_with(".bin"): paths.append(directory.path_join(name))
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		assert(file != null)
		var payload: Dictionary = file.get_var()
		file.close()
		for entry: Dictionary in payload["entries"]:
			if str(entry["layout"].get("guardian_id", entry["layout"].get("boss_id", ""))) == id: entries.append(entry)
	assert(not entries.is_empty(), "Natural ladder has no entry for " + id)
	var output := FileAccess.open(Sweep.option(args, "--output", ""), FileAccess.WRITE)
	assert(output != null)
	for sample: int in range(64):
		var entry: Dictionary = entries[sample % entries.size()]
		var repeat: int = sample / entries.size()
		var seed_value: int = int(entry["run_seed"]) + repeat * PROOF_RNG_STRIDE
		var initial: Dictionary = Combat.new().create_combat(seed_value, entry["layout"], entry["snapshot"])
		assert(int(initial["player"]["hp"]) == int(initial["player"]["max_hp"]))
		var fought: Dictionary = Battle.fight(initial)
		var row: Dictionary = {"boss": id, "sample": sample, "entry": sample % entries.size(), "natural_entries": entries.size(), "seed": seed_value, "depth": entry["layout"]["depth"], "won": fought["won"], "turns": fought["turns"], "turn_cap_reached": fought["turn_cap_reached"], "search_capped": fought["search_capped"]}
		output.store_line(JSON.stringify(Store._sanitize_variant(row)))
		output.flush()
		print("AREA01 FIGHT boss=%s sample=%d won=%s" % [id, sample, fought["won"]])
	output.close()
	print("AREA01 MEASUREMENT PASS boss=%s N=64" % id)
	quit(0)
