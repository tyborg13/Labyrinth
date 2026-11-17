extends "res://tools/run_curve.gd"
## Matched normal-room sanity sample from the unchanged full-health bot ladder.
const Factory = preload("res://scripts/combat_engine.gd")
const TARGET_SECTIONS: Array = [0, 2]
const MAX_SEEDS: int = 100 # Measurement fault bound, never a gameplay limit.

class CaptureCombat:
	extends "res://scripts/combat_engine.gd"
	var input: Dictionary
	func begin_combat_creation(seed_value: int, layout: Dictionary, snapshot: Dictionary) -> Dictionary:
		input = {"seed": seed_value, "layout": layout.duplicate(true), "snapshot": snapshot.duplicate(true)}
		return super.begin_combat_creation(seed_value, layout, snapshot)

class PrefixLadder:
	extends "res://tools/run_curve_ladder.gd"
	func _init(combat: RefCounted) -> void:
		_combat_engine = combat
	func move_to_room(state: Dictionary, destination: Vector2i) -> Dictionary:
		if int(room_metadata(state, destination).get("section_index", 0)) > 2:
			# Stop collection after s2; all measured fights/choices use the ladder.
			var stopped: Dictionary = state.duplicate(true)
			stopped["victory"] = true
			return stopped
		return super.move_to_room(state, destination)

var captured := CaptureCombat.new()
var counts: Dictionary = {0: 0, 2: 0}
var target: int = 24 # Each of two workers contributes half of N=48 per section.
var directory: String
var stream: FileAccess
var pending: Dictionary
var seed_value: int

func new_run_engine(_ladder: bool) -> RefCounted:
	return PrefixLadder.new(captured)

func fight_started(initial: Dictionary) -> void:
	pending = {}
	var section: int = int(captured.input["layout"].get("section_index", (int(initial["room_depth"]) - 1) / 4))
	if initial.get("room_type") != "combat" or not TARGET_SECTIONS.has(section) or int(counts[section]) >= target: return
	var path: String = directory.path_join("s%d-%02d.bin" % [section, counts[section]])
	var payload: Dictionary = captured.input
	assert(initial == Factory.new().create_combat(payload["seed"], payload["layout"], payload["snapshot"]), "Captured ladder constructor must reproduce the initial state")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(payload)
	file.close()
	pending = {"section": section, "ladder_seed": seed_value, "input": path, "input_sha256": FileAccess.get_sha256(path)}

func fight_finished(_initial: Dictionary, fought: Dictionary) -> void:
	if pending.is_empty(): return
	store(pending, fought)
	counts[pending["section"]] += 1

func store(metadata: Dictionary, fought: Dictionary) -> void:
	var record: Dictionary = metadata.duplicate(true)
	for key: String in ["won", "turns", "turn_cap_reached", "decisions", "search_capped"]: record[key] = fought[key]
	record["policy_sha256"] = FileAccess.get_sha256("res://tools/encounter_bot.gd")
	record["combat_sha256"] = FileAccess.get_sha256("res://scripts/combat_engine.gd")
	stream.store_line(JSON.stringify(record))
	stream.flush()
	print("TRP01 LADDER ROOM ", JSON.stringify(record))

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	directory = Sweep.option(args, "--output-dir", "")
	assert(not directory.is_empty())
	DirAccess.make_dir_recursive_absolute(directory)
	stream = FileAccess.open(directory.path_join("after.jsonl" if args.has("--replay") else "before.jsonl"), FileAccess.WRITE)
	if args.has("--replay"):
		var previous := FileAccess.open(directory.path_join("before.jsonl"), FileAccess.READ)
		while not previous.eof_reached():
			var line: String = previous.get_line()
			if line.is_empty(): continue
			var meta: Dictionary = JSON.parse_string(line)
			assert(FileAccess.get_sha256(meta["input"]) == meta["input_sha256"])
			var file := FileAccess.open(meta["input"], FileAccess.READ)
			var payload: Dictionary = file.get_var()
			file.close()
			var initial: Dictionary = Factory.new().create_combat(payload["seed"], payload["layout"], payload["snapshot"])
			store(meta, Battle.fight(initial))
		previous.close()
	else:
		var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--scores", "")))
		var first: int = int(Sweep.option(args, "--seed", "1"))
		for index: int in range(MAX_SEEDS):
			seed_value = first + index * 2 # Disjoint odd/even workers.
			whole_run(seed_value, "best", scores, true)
			if int(counts[0]) == target and int(counts[2]) == target: break
		assert(int(counts[0]) == target and int(counts[2]) == target, "Incomplete N=24 worker sample")
	stream.close()
	print("TRP01 LADDER WORKER: PASS (", "after matched replay" if args.has("--replay") else "before; N=24 each s0/s2", ")")
	quit(0)
