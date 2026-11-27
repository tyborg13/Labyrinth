extends "res://tools/run_hunt.gd"
## Collect before the hunt policy dispatches the first input of a player turn.

const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Score = preload("res://tools/fel01/board_score.gd")
const ProgressPolicy = preload("res://tools/fel01/policy.gd")
var _last_turn_by_fight: Dictionary = {}
var _best_by_fight: Dictionary = {}


func _initialize() -> void:
	hunt_health = 0
	OS.set_environment("LABYRINTH_CEL_LOOK", "all")
	super._initialize()


func _start() -> void:
	_emit("startup", {"seed": hunt_seed, "starting_health_override": hunt_health})
	_enter_scene(false)
	if finished: return
	_apply_hunt_health()
	policy = ProgressPolicy.new()
	policy.rng = rng
	policy.no_embrace = no_embrace
	while not finished:
		await process_frame
		_tick()


func _side_action() -> bool:
	# Keep the hunt's normal legal decision policy. Skip incidental menu
	# testing so scoring sees the untouched player-turn start.
	return false


func _tick() -> void:
	if not finished and not busy and is_instance_valid(scene) and settle_frames == 0:
		if not bool(scene.get("_animation_lock")) and not _sample_turn():
			finished = true
			quit(1)
			return
	super._tick()


func _sample_turn() -> bool:
	var run: Dictionary = scene.get("_run_state")
	var combat: Dictionary = scene.get("_combat_state")
	if run.get("mode") != "combat" or combat.is_empty(): return true
	if not scene.get("_combat_engine").is_player_turn(combat): return true
	if scene.call("_has_pending_combat_checkpoints"): return true
	var context: Dictionary = _context()
	var section: int = context["section"]
	var room: Vector2i = run["current_room"]
	var fight: String = "%d-%d_%d" % [section, room.x, room.y]
	var turn: int = combat.get("turn", 0)
	if _last_turn_by_fight.get(fight, -1) == turn: return true
	_last_turn_by_fight[fight] = turn
	var board: Control = scene.get("board_view")
	if (board.get("combat_state") as Dictionary).is_empty():
		printerr("FEL01: missing board at %d/%s/%d" % [hunt_seed, fight, turn])
		return false
	var row: Dictionary = Score.measure(board)
	var objective: String = str(combat.get("objective", {}).get("type", "kill_all"))
	var kind: String = context["room_kind"]
	row.merge({"seed": hunt_seed, "section": section, "fight": fight, "turn": turn,
		"room_kind": kind, "objective": objective, "kind": _fight_kind(kind, objective)})
	var previous: int = _best_by_fight.get(fight, -1)
	if int(row["score"]) > previous and not row["focus"].is_empty():
		row["targeted_card_index"] = Checkpoint.first_targeted_card(scene)
	if int(row.get("targeted_card_index", -1)) >= 0:
		var destination: String = output.path_join("candidates").path_join(fight)
		if not Checkpoint.save(scene, output, destination):
			printerr("FEL01: cannot save production checkpoint " + destination)
			return false
		_best_by_fight[fight] = int(row["score"])
		var file := FileAccess.open(destination.path_join("score.json"), FileAccess.WRITE)
		if file == null or not file.store_string(JSON.stringify(row, "\t") + "\n"): return false
	_emit("fel01_turn", row)
	return true


func _fight_kind(room_kind: String, objective: String) -> String:
	if room_kind == "boss": return "dragon"
	if room_kind == "guardian": return room_kind
	return "normal" if objective in ["", "kill_all"] and room_kind == "combat" else "objective"
