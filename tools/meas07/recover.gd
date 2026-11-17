extends "res://tools/run_curve.gd"
## Observe section-entry loadouts without altering the ladder or its choices.
var capture_directory: String
var capture_seed: int

class EntryLadder:
	extends "res://tools/run_curve_ladder.gd"
	var snapshots: Dictionary = {}
	func move_to_room(state: Dictionary, destination: Vector2i) -> Dictionary:
		var section: int = preload("res://scripts/section_map_graph.gd").active_section(state)
		if not snapshots.has(section):
			var copy: Dictionary = state.duplicate(true)
			# Call the production snapshot directly; this observation must not
			# increment the ladder's health-reset counter or mutate the run.
			copy["player_hp"] = int(copy["player_max_hp"])
			snapshots[section] = super._player_snapshot(copy)
			# Undo only the observer's counter increment.
			health_resets -= 1
		return super.move_to_room(state, destination)

var ladder := EntryLadder.new()

func new_run_engine(_ladder: bool) -> RefCounted:
	return ladder

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	capture_seed = int(Sweep.option(args, "--seed", "1"))
	capture_directory = Sweep.option(args, "--directory", "")
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sweep.option(args, "--scores", "")))
	var record: Dictionary = whole_run(capture_seed, "best", scores, true)
	assert(bool(record["completed_ladder"]) and ladder.snapshots.size() == 6)
	for section: int in range(6):
		var file := FileAccess.open(capture_directory.path_join("entry-%d-%d.bin" % [capture_seed, section]), FileAccess.WRITE)
		file.store_var({"snapshot": ladder.snapshots[section]})
		file.close()
	var output := FileAccess.open(capture_directory.path_join("ladder-%d.json" % capture_seed), FileAccess.WRITE)
	output.store_string(JSON.stringify(Store._sanitize_variant(record)))
	output.close()
	print("MEAS07_RECOVERY_PASS seed=%d sections=6" % capture_seed)
	quit()
