extends SceneTree
## tune-01 stat search. Regenerate production rooms; frozen loadouts and bot.
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
	# Inputs carry the original native room and unchanged loadout. Rebuild through
	# the production run path, with this job's proposed table dials installed only
	# in memory. The worktree proposal never races concurrent workers.
	var dials: Dictionary = task.get("dials", {})
	var difficulty = preload("res://scripts/difficulty_tier_rules.gd")
	difficulty._data = JSON.parse_string(FileAccess.get_file_as_string(difficulty.DATA_PATH))
	for cell: String in dials:
		var parts: PackedStringArray = cell.split(":")
		var section: int = int(parts[0])
		var kind: String = parts[1]
		var category: String = kind if kind in ["guardian", "boss"] else "objective"
		var entry: Dictionary = difficulty._data["tiers"][category][kind if category == "objective" else "default"]
		entry["hp_percent"][section] = int(dials[cell][0])
		entry["damage_bonus"][section] = int(dials[cell][1])
	var run = preload("res://scripts/run_engine.gd").new()
	var context: Dictionary = run.create_new_run(int(task["ladder_seed"]), preload("res://scripts/progression_store.gd").default_data(), true)
	var snapshot: Dictionary = payload["snapshot"]
	for key: String in ["omens", "deck_cards", "equipped_equipment", "equipment_grafts", "equipped_items", "item_inventory", "relics", "hand_size", "heal_bonus"]:
		context[key] = snapshot[key].duplicate(true) if snapshot[key] is Array or snapshot[key] is Dictionary else snapshot[key]
	context["player_hp"] = snapshot["hp"]
	context["player_max_hp"] = snapshot["max_hp"]
	context["run_stats"] = snapshot["run_stats"].duplicate(true)
	var travel: Vector2i = preload("res://tools/diff01/plan.gd").incoming_direction(context, payload["room"])
	payload["layout"] = run._combat_layout_for_room(payload["room"], travel, context)
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
	assert(not initial["enemies"].is_empty())
	var row: Dictionary = task.duplicate(true)
	row.erase("input_file")
	row.erase("task_file")
	for key: String in ["ladder_seed", "section", "tier", "depth", "map_seed", "room_seed"]:
		row[key] = int(task[key])
	var roster: Array[Dictionary]
	var summoned: int = 0
	for enemy: Dictionary in initial["enemies"]:
		if bool(enemy.get("summoned", false)): summoned += 1
		roster.append({"type": enemy["type"], "hp": enemy["hp"], "summoned": enemy.get("summoned", false)})
	row.merge({"start_count": roster.size(), "start_summoned": summoned, "start_non_summoned": roster.size() - summoned, "enemy_roster": roster, "repeat": repeat, "combat_seed_input": seed_input,
		"combat_rng_seed": Combat.new()._combat_seed(seed_input, payload["layout"]["coord"]),
		"policy_sha256": FileAccess.get_sha256("res://tools/encounter_bot.gd"),
		"goal_met": fought["won"] and bool(after.get("objective", {}).get("goal_met", true)),
		"difficulty_stats": initial.get("difficulty_stats", {}),
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
	print("TUNE01_FIGHT_PASS cell=%s loadout=%d repeat=%d won=%s" % [task["cell"], task["ladder_seed"], repeat, fought["won"]])

const SIMULATION_THREAD_PRIORITY: Thread.Priority = Thread.PRIORITY_LOW
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var worker := Thread.new()
	var started: Error = worker.start(_execute_arguments.bind(OS.get_cmdline_user_args()), SIMULATION_THREAD_PRIORITY)
	assert(started == OK, "Low-priority simulation thread starts")
	print("TUNE01_PRIORITY thread=LOW macos_qos=UTILITY start_result=%d" % started)
	worker.wait_to_finish()
	quit()

func _execute_arguments(args: PackedStringArray) -> void:
	if args.has("--native-plan"):
		preload("res://tools/diff01/plan.gd").make_plan(Sweep.option(args, "--directory", ""), self)
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
		print("TUNE01_BATCH_PASS fights=%d" % completed)
	else:
		fight(Sweep.option(args, "--task", ""), int(Sweep.option(args, "--repeat", "0")), Sweep.option(args, "--output", ""))
