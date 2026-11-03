extends "res://tools/run_curve.gd"
## On-demand dragon measurement. Replays the existing ladder without changing
## it, captures production constructor inputs, then changes only combat RNG.
const CombatFactory = preload("res://scripts/combat_engine.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const RNG_SEED_STRIDE: int = 1000003
const RNG_REPEATS: int = 4

class CaptureCombat:
	extends "res://scripts/combat_engine.gd"
	var inputs: Dictionary = {}
	func begin_combat_creation(run_seed: int, layout: Dictionary, snapshot: Dictionary) -> Dictionary:
		if str(layout.get("type", "")) == "boss":
			var section: int = (int(layout["depth"]) - 1) / 4
			inputs[section] = {"run_seed": run_seed, "layout": layout.duplicate(true), "snapshot": snapshot.duplicate(true)}
		return super.begin_combat_creation(run_seed, layout, snapshot)

class CaptureLadder:
	extends "res://tools/run_curve_ladder.gd"
	func _init(combat: RefCounted) -> void:
		_combat_engine = combat

var captured := CaptureCombat.new()
var run_seed_value: int = 1
var deadline: float = 0.0
var directory: String
var results: FileAccess
var manifests: FileAccess
var started: Dictionary = {}

func new_run_engine(_ladder: bool) -> RefCounted:
	return CaptureLadder.new(captured)

func before_deadline() -> bool:
	return deadline <= 0.0 or Time.get_unix_time_from_system() < deadline

func input_path(section: int) -> String:
	return directory.path_join("input-%d.bin" % section)

func fight_started(initial: Dictionary) -> void:
	if str(initial.get("room_type", "")) != "boss": return
	var section: int = (int(initial["room_depth"]) - 1) / 4
	var payload: Dictionary = captured.inputs[section]
	var file := FileAccess.open(input_path(section), FileAccess.WRITE)
	assert(file != null)
	file.store_var(payload)
	file.close()
	# Verify native Variant serialization, including vectors and typed arrays,
	# and the exact production factory before spending time on repeats.
	var reader := FileAccess.open(input_path(section), FileAccess.READ)
	var restored: Dictionary = reader.get_var()
	reader.close()
	assert(restored == payload, "Dragon constructor input round-trip changed")
	var reproduced: Dictionary = CombatFactory.new().create_combat(int(payload["run_seed"]), payload["layout"], payload["snapshot"])
	assert(initial == reproduced, "Captured factory differs from the ladder's production factory")
	var meta: Dictionary = metadata(section, 0)
	meta["input_file"] = input_path(section)
	meta["input_sha256"] = FileAccess.get_sha256(input_path(section))
	meta["deck_ids"] = payload["snapshot"]["deck_cards"]
	meta["relics"] = payload["snapshot"]["relics"]
	meta["equipment"] = payload["snapshot"]["equipped_equipment"]
	meta["max_hp"] = payload["snapshot"]["max_hp"]
	manifests.store_line(JSON.stringify(Store._sanitize_variant(meta)))
	manifests.flush()
	started[section] = Time.get_unix_time_from_system()
	print("DRAGON_FIGHT_START ladder_seed=%d section=%d repeat=0 started_unix=%.6f eligible=%s" % [run_seed_value, section, started[section], before_deadline()])

func metadata(section: int, repeat: int) -> Dictionary:
	var payload: Dictionary = captured.inputs[section]
	var layout: Dictionary = payload["layout"]
	var id: String = str(layout["boss_id"])
	var rng_input: int = run_seed_value + repeat * RNG_SEED_STRIDE
	return {"ladder_seed": run_seed_value, "section": section, "repeat": repeat,
		"dragon_id": id, "element": Bosses.element_for_boss(id), "room_coord": str(layout["coord"]),
		"room_seed": Rooms.new()._room_seed(run_seed_value, layout["coord"], 101),
		"combat_seed_input": rng_input, "combat_rng_seed": CombatFactory.new()._combat_seed(rng_input, layout["coord"]),
		"policy_sha256": FileAccess.get_sha256("res://tools/encounter_bot.gd")}

func store_fight(initial: Dictionary, fought: Dictionary, section: int, repeat: int) -> void:
	var after: Dictionary = fought["state"]
	var row: Dictionary = metadata(section, repeat)
	row.merge({"won": fought["won"], "turn_cap_reached": fought["turn_cap_reached"], "turns": fought["turns"],
		"search_capped": fought["search_capped"], "decisions": fought["decisions"],
		"hp_before": initial["player"]["hp"], "max_hp": initial["player"]["max_hp"], "hp_after": after["player"]["hp"],
		"hp_lost": int(after.get("run_stats", {}).get("damage_received", 0)) - int(initial.get("run_stats", {}).get("damage_received", 0)),
		"native_log_tail": after.get("log", []).duplicate(true),
		"native_surface_events": after.get("surface_events", []).duplicate(true),
		"native_surface_event_sequence": after.get("surface_event_sequence", 0),
		"native_umbra": after.get("umbra", {}).duplicate(true),
		"native_braziers": after.get("guardian_braziers", []).duplicate(true),
		"native_objective": after.get("objective", {}).duplicate(true),
		"native_battlefield_rule": after.get("battlefield_rule", {}).duplicate(true)}, true)
	var enemies: Array
	for enemy: Dictionary in after.get("enemies", []):
		enemies.append({"id": enemy["id"], "type": enemy["type"], "hp": enemy["hp"], "is_leader": enemy.get("is_leader", false)})
	row["native_enemy_end"] = enemies
	results.store_line(JSON.stringify(Store._sanitize_variant(row)))
	results.flush()
	print("DRAGON_FIGHT_DONE ladder_seed=%d section=%d repeat=%d won=%s turns=%d" % [run_seed_value, section, repeat, fought["won"], fought["turns"]])

func fight_finished(initial: Dictionary, fought: Dictionary) -> void:
	if str(initial.get("room_type", "")) != "boss": return
	var section: int = (int(initial["room_depth"]) - 1) / 4
	if deadline <= 0.0 or float(started[section]) < deadline:
		store_fight(initial, fought, section, 0)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	run_seed_value = int(Sweep.option(args, "--seed", "1"))
	deadline = float(Sweep.option(args, "--deadline-unix", "0"))
	directory = Sweep.option(args, "--output-dir", "")
	DirAccess.make_dir_recursive_absolute(directory)
	results = FileAccess.open(directory.path_join("fights.jsonl"), FileAccess.WRITE)
	manifests = FileAccess.open(directory.path_join("inputs.jsonl"), FileAccess.WRITE)
	assert(results != null and manifests != null)
	if not before_deadline():
		print("DRAGON_WORKER_PASS seed=%d skipped=true" % run_seed_value)
		quit(0)
		return
	print("DRAGON_RECOVER_START seed=%d started_unix=%.6f" % [run_seed_value, Time.get_unix_time_from_system()])
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--scores", "")))
	var recovered: Dictionary = whole_run(run_seed_value, "best", scores, true)
	var run_file := FileAccess.open(directory.path_join("recovered.json"), FileAccess.WRITE)
	run_file.store_string(JSON.stringify(Store._sanitize_variant(recovered)))
	run_file.close()
	assert(captured.inputs.size() == 6 and bool(recovered["completed_ladder"]))
	print("DRAGON_RECOVER_DONE seed=%d sections=6" % run_seed_value)
	for repeat: int in range(1, RNG_REPEATS):
		for section: int in range(6):
			if not before_deadline(): break
			var payload: Dictionary = captured.inputs[section]
			var rng_input: int = run_seed_value + repeat * RNG_SEED_STRIDE
			print("DRAGON_FIGHT_START ladder_seed=%d section=%d repeat=%d started_unix=%.6f eligible=true" % [run_seed_value, section, repeat, Time.get_unix_time_from_system()])
			var initial: Dictionary = CombatFactory.new().create_combat(rng_input, payload["layout"], payload["snapshot"])
			assert(int(initial["player"]["hp"]) == int(initial["player"]["max_hp"]))
			store_fight(initial, Battle.fight(initial), section, repeat)
	results.close()
	manifests.close()
	print("DRAGON_WORKER_PASS seed=%d skipped=false" % run_seed_value)
	quit(0)
