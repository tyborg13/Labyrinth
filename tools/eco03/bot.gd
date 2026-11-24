extends "res://tools/run_curve.gd"

const Route = preload("res://tools/eco03/route.gd")
const SAMPLE_SEEDS: int = 100
const RECEIPTS: String = "res://.godot/eco03"

class ArrivalEngine extends "res://tools/run_curve_ladder.gd":
	var revision: int
	var path: Array
	var arrival: Dictionary = {}

	func create_new_run(seed: int, progression: Dictionary, section_maps: bool = true, requested_depth: int = -1, prepared_graph: Dictionary = {}) -> Dictionary:
		if revision == 7:
			prepared_graph = {"seed": seed, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": revision}
			Graph.initialize(prepared_graph)
		var state: Dictionary = super.create_new_run(seed, progression, section_maps, requested_depth, prepared_graph)
		path = Route.section_routes(state, 0)["first"]["path"].duplicate()
		return state

	func available_moves(state: Dictionary) -> Array[Vector2i]:
		var moves: Array[Vector2i] = super.available_moves(state)
		if not path.is_empty() and moves.has(path.front()):
			moves.assign([path.front()])
		return moves

	func move_to_room(state: Dictionary, destination: Vector2i) -> Dictionary:
		return accept_step(super.move_to_room(state, destination), destination)

	func move_to_pre_battle(state: Dictionary, destination: Vector2i) -> Dictionary:
		var remaining: int = path.size()
		var next: Dictionary = super.move_to_pre_battle(state, destination)
		# Services already dispatched through move_to_room.
		return accept_step(next, destination) if path.size() == remaining else next

	func begin_pre_battle_combat(state: Dictionary, prepared: Dictionary = {}) -> Dictionary:
		return choose_escape_exit(super.begin_pre_battle_combat(state, prepared))

	func accept_step(next: Dictionary, destination: Vector2i) -> Dictionary:
		assert(not path.is_empty() and destination == path.front(), "Ladder follows the measured Section I route")
		assert(next["current_room"] == destination)
		path.pop_front()
		if path.is_empty():
			assert(merchant_kind_for_current_room(next) == MERCHANT_SCAVENGER)
			arrival = {"embers": held_embers(next), "section": Graph.active_section(next) + 1}
			# End at the first shop, recording its entry wallet before trades.
			next["game_over"] = true
		return choose_escape_exit(next)

	func choose_escape_exit(state: Dictionary) -> Dictionary:
		var objective: Dictionary = state.get("combat_state", {}).get("objective", {})
		if path.is_empty() or objective.get("type") != Objectives.REACH_EXIT: return state
		# The prescribed route targets a single authored exit. Keep its normal
		# seal, enemy and reward rules while excluding the other destinations.
		var chosen: Array = objective["exits"].filter(func(exit: Dictionary) -> bool: return exit["coord"] == path.front())
		assert(chosen.size() == 1, "The structural route must use one of the escape exits")
		objective["exits"] = chosen
		return state

var arrival_engine: ArrivalEngine
var measured_revision: int = Graph.LAYOUT_REVISION

func new_run_engine(_ladder: bool) -> RefCounted:
	arrival_engine = ArrivalEngine.new()
	arrival_engine.revision = measured_revision
	return arrival_engine

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var first_seed: int = int(Sweep.option(args, "--seed", "1"))
	var sample_size: int = int(Sweep.option(args, "--runs", str(SAMPLE_SEEDS)))
	var scores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECEIPTS.path_join("scores.json")))
	var receipt := FileAccess.open(RECEIPTS.path_join("bot-complete-%d.jsonl" % first_seed), FileAccess.WRITE)
	var reached: Dictionary = {"before": 0, "after": 0}
	for seed_value: int in range(first_seed, first_seed + sample_size):
		for phase: String in ["before", "after"]:
			measured_revision = 7 if phase == "before" else Graph.LAYOUT_REVISION
			var record: Dictionary = whole_run(seed_value, "best", scores, true)
			var row: Dictionary = {"phase": phase, "seed": seed_value, "revision": record["map_revision"],
				"forced_victories": record["forced_victories"], "arrival": arrival_engine.arrival}
			receipt.store_line(JSON.stringify(row))
			receipt.flush()
			reached[phase] += int(not arrival_engine.arrival.is_empty())
			print("ECO03 BOT SEED " + JSON.stringify(row))
	receipt.close()
	print("ECO03 BOT RESULT first_seed=%d seeds=%d before_reached=%d after_reached=%d" % [first_seed, sample_size, reached["before"], reached["after"]])
	quit()
