extends "res://tools/run_curve.gd"
## Recover actual Guardian/dragon entry loadouts with the unchanged ladder.
class EntryCombat:
	extends "res://scripts/combat_engine.gd"
	var inputs: Array[Dictionary]
	func begin_combat_creation(seed_value: int, layout: Dictionary, snapshot: Dictionary) -> Dictionary:
		if str(layout.get("type", "")) in ["guardian", "boss"]:
			inputs.append({"run_seed": seed_value, "layout": layout.duplicate(true), "snapshot": snapshot.duplicate(true)})
		return super.begin_combat_creation(seed_value, layout, snapshot)
class EntryLadder:
	extends "res://tools/run_curve_ladder.gd"
	func _init(combat: RefCounted) -> void:
		_combat_engine = combat
var captured := EntryCombat.new()
func new_run_engine(_ladder: bool) -> RefCounted:
	return EntryLadder.new(captured)
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args := OS.get_cmdline_user_args()
	var seed_value: int = int(Sweep.option(args, "--seed", "1"))
	var output: String = Sweep.option(args, "--output", "")
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11/ladder_card_scores.json"))
	var recovered: Dictionary = whole_run(seed_value, "best", scores, true)
	assert(bool(recovered["completed_ladder"]))
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_var({"entries": captured.inputs, "ladder": recovered})
	file.close()
	print("AREA01 LADDER CAPTURE PASS seed=%d entries=%d" % [seed_value, captured.inputs.size()])
	quit(0)
