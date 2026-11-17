extends SceneTree
## Measurement only. Frozen ladder snapshots, production rooms and unchanged bot.
const Combat = preload("res://scripts/combat_engine.gd")
const Battle = preload("res://tools/run_curve_combat.gd")
const Sweep = preload("res://tools/encounter_sweep.gd")
const Store = preload("res://scripts/analytics_store.gd")
const RNG_SEED_STRIDE: int = 1000003
const STOP_FILE_NAME: String = "STOP"

func save_variant(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_var(payload)
	file.close()
	var reader := FileAccess.open(path, FileAccess.READ)
	assert(reader.get_var() == payload, "Native typed payload round trip")
	reader.close()

func fight(task_path: String, repeat: int, output_path: String) -> void:
	var task: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(task_path))
	assert(FileAccess.get_sha256(str(task["input_file"])) == str(task["input_sha256"]))
	var reader := FileAccess.open(str(task["input_file"]), FileAccess.READ)
	var payload: Dictionary = reader.get_var()
	reader.close()
	var seed_input: int = int(task["ladder_seed"]) + repeat * RNG_SEED_STRIDE
	var started: float = Time.get_unix_time_from_system()
	var initial: Dictionary = Combat.new().create_combat(seed_input, payload["layout"], payload["snapshot"])
	assert(initial == Combat.new().create_combat(seed_input, payload["layout"], payload["snapshot"]), "Production constructor determinism")
	assert(int(initial["player"]["hp"]) == int(initial["player"]["max_hp"]))
	var fought: Dictionary = Battle.fight(initial)
	var after: Dictionary = fought["state"]
	var boss_hp: Variant = null
	var enemy_end: Array[Dictionary]
	for enemy: Dictionary in after["enemies"]:
		enemy_end.append({"type": enemy["type"], "hp": enemy["hp"]})
		if str(enemy["type"]) == str(task["identity"]): boss_hp = int(enemy["hp"])
	assert(str(task["kind"]) == "combat" or boss_hp != null)
	var row: Dictionary = task.duplicate(true)
	row.erase("input_file")
	row.erase("task_file")
	for key: String in ["ladder_seed", "section", "tier", "depth", "map_seed", "room_seed"]:
		row[key] = int(task[key])
	row.merge({"repeat": repeat, "combat_seed_input": seed_input,
		"combat_rng_seed": Combat.new()._combat_seed(seed_input, payload["layout"]["coord"]),
		"policy_sha256": FileAccess.get_sha256("res://tools/encounter_bot.gd"),
		"won": fought["won"], "turns": fought["turns"], "turn_cap_reached": fought["turn_cap_reached"],
		"search_capped": fought["search_capped"], "decisions": fought["decisions"],
		"hp_before": initial["player"]["hp"], "max_hp": initial["player"]["max_hp"], "hp_after": after["player"]["hp"],
		"hp_lost": int(after.get("run_stats", {}).get("damage_received", 0)) - int(initial.get("run_stats", {}).get("damage_received", 0)),
		"boss_hp_at_hero_death": boss_hp if int(after["player"]["hp"]) <= 0 else null,
		"native_enemy_end": enemy_end, "native_battlefield_rule": after.get("battlefield_rule", {}),
		"started_unix": started, "elapsed_seconds": Time.get_unix_time_from_system() - started}, true)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_line(JSON.stringify(Store._sanitize_variant(row)))
	output.close()
	print("MEAS07_FIGHT_PASS cell=%s loadout=%d repeat=%d won=%s" % [task["cell"], task["ladder_seed"], repeat, fought["won"]])

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--native-plan"):
		preload("res://tools/meas07/native_plan.gd").make_plan(Sweep.option(args, "--directory", ""), self)
	elif args.has("--jobs"):
		var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--jobs", "")))
		var deadline: float = float(Sweep.option(args, "--deadline-unix", "0"))
		var stop_path: String = Sweep.option(args, "--jobs", "").get_base_dir().path_join(STOP_FILE_NAME)
		var completed: int = 0
		for job: Dictionary in jobs:
			if FileAccess.file_exists(stop_path): break
			if deadline > 0.0 and Time.get_unix_time_from_system() >= deadline: break
			fight(str(job["task"]), int(job["repeat"]), str(job["output"]))
			completed += 1
		print("MEAS07_BATCH_PASS fights=%d" % completed)
	else:
		fight(Sweep.option(args, "--task", ""), int(Sweep.option(args, "--repeat", "0")), Sweep.option(args, "--output", ""))
	quit()
