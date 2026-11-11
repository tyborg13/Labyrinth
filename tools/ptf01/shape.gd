extends "res://tools/run_curve.gd"
## Section-I-only harness around the unchanged production run_curve policy.
const Baseline = preload("res://tools/ptf01/baseline_generator.gd")
const SHAPE_RUNS: int = 30
const SHAPE_WALL_SECONDS: int = 2400
var baseline: bool = false
class SectionRun:
	extends "res://scripts/run_engine.gd"
	func continue_dragon_reward(run_state: Dictionary) -> Dictionary:
		assert(preload("res://scripts/section_map_graph.gd").active_section(run_state) == 0)
		var stopped: Dictionary = run_state.duplicate(true)
		stopped["victory"] = true
		return stopped
func new_run_engine(_ladder: bool) -> RefCounted:
	var engine := SectionRun.new()
	if baseline: engine._room_generator = Baseline.new()
	return engine
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--scores", "")))
	var path: String = Sweep.option(args, "--output", "")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	var deadline: float = Time.get_unix_time_from_system() + SHAPE_WALL_SECONDS
	var completed: int = 0
	var first_seed: int = int(Sweep.option(args, "--seed", "1"))
	var runs: int = int(Sweep.option(args, "--runs", str(SHAPE_RUNS)))
	for seed_value: int in range(first_seed, first_seed + runs):
		for variant: String in ["old", "new"]:
			if Time.get_unix_time_from_system() >= deadline:
				print("PTF01 SHAPE BUDGET: completed=%d" % completed)
				quit(0)
				return
			baseline = variant == "old"
			var record: Dictionary = whole_run(seed_value, "best", scores)
			record["variant"] = variant
			record["section_clear"] = record["escaped"]
			record["room_reached"] = record["route"].size()
			output.store_line(JSON.stringify(record))
			output.flush()
			completed += 1
			print("PTF01 SHAPE RECORD: seed=%d variant=%s clear=%s room=%d" % [seed_value, variant, record["section_clear"], record["room_reached"]])
	output.close()
	print("PTF01 SHAPE: completed=%d" % completed)
	quit(0)
