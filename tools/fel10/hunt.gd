extends "res://tools/fel01/hunt.gd"
## Keep one scratch save and promote the first observed input prefix for each ID.

const Observer = preload("res://tools/fel10/observer.gd")
const Inputs = preload("res://tools/fel10/combat_inputs.gd")
const HuntPolicy = preload("res://tools/fel10/hunt_policy.gd")
const FIXTURE_FILES := ["run.save", "progression.json", "combat.witness"]

var _observer: Observer
var _turn_key: Array
var _context_at_start: Dictionary
var _inputs: Array[Dictionary]
var _seen: Dictionary
var _first: Dictionary
var _turns: int
var _coverage: FileAccess
var _enemy_turn: bool


func _start() -> void:
	if not OS.get_cmdline_user_args().has("--health"): hunt_health = HUNT_HEALTH
	_coverage = FileAccess.open(output.path_join("fel10-turns.jsonl"), FileAccess.WRITE)
	if _coverage == null:
		_fail("cannot open turn log")
		return
	_observer = Observer.new(self)
	RenderingServer.frame_post_draw.connect(_observe)
	policy = HuntPolicy.new()
	policy.rng = rng
	policy.no_embrace = no_embrace
	_emit("startup", {"seed": hunt_seed, "starting_health_override": hunt_health})
	_enter_scene(false)
	if finished: return
	_apply_hunt_health()
	while not finished:
		await process_frame
		_tick()


func _sample_turn() -> bool:
	var run: Dictionary = scene._run_state
	var combat: Dictionary = scene._combat_state
	if run.get("mode") != "combat" or combat.is_empty(): return true
	if not scene._combat_engine.is_player_turn(combat): return true
	if scene._has_pending_combat_checkpoints() or scene._selected_card_index >= 0: return true
	var key: Array = [run["current_room"], combat.get("turn", 0)]
	if key == _turn_key: return true
	_close_turn()
	_turn_key = key
	_context_at_start = _context()
	_context_at_start.erase("room_metadata")
	_context_at_start["turn"] = key[1]
	_turns += 1
	_inputs.clear()
	_seen.clear()
	_enemy_turn = false
	_observer.baseline(scene)
	return Checkpoint.save(scene, output, output.path_join("scratch"))


func _record(action: Dictionary) -> void:
	super._record(action)
	if scene._run_state.get("mode") != "combat" or _turn_key.is_empty(): return
	_inputs.append(Inputs.encode(scene, action))
	if action.get("kind") == "pass": _enemy_turn = true


func _observe() -> void:
	if finished or _inputs.is_empty() or not is_instance_valid(scene): return
	for id: String in _observer.sample(scene, _enemy_turn):
		if _seen.has(id): continue
		_seen[id] = true
		if _first.has(id): continue
		var turn_path: String = "turn-%06d" % _turns
		var directory: String = output.path_join("witnesses").path_join(turn_path)
		if not DirAccess.dir_exists_absolute(directory):
			if DirAccess.make_dir_recursive_absolute(directory) != OK:
				_fail("cannot create " + directory)
				return
			for name: String in FIXTURE_FILES:
				if DirAccess.copy_absolute(output.path_join("scratch").path_join(name), directory.path_join(name)) != OK:
					_fail("cannot promote " + name)
					return
		var file := FileAccess.open(directory.path_join(id + ".inputs"), FileAccess.WRITE)
		if file == null or not file.store_var(_inputs, false):
			_fail("cannot store inputs for " + id)
			return
		_first[id] = true
		var row: Dictionary = _context_at_start.duplicate()
		row.merge({"id": id, "checkpoint": turn_path, "inputs": _inputs.size(),
			"observed_at": Time.get_unix_time_from_system(), "source": _observer.observations[id]["source"]})
		_write_event("first", row)


func _close_turn() -> void:
	if not _turn_key.is_empty():
		var row: Dictionary = _context_at_start.duplicate()
		row.merge({"effects": _seen.keys(), "inputs": _inputs.size()})
		_write_event("turn", row)
	_turn_key.clear()
	_inputs.clear()


func _write_event(kind: String, data: Dictionary) -> void:
	_coverage.store_line(JSON.stringify({"event": kind, "data": data}))
	_coverage.flush()


func _finish(outcome: String) -> void:
	_close_turn()
	print("FEL10 HUNT seed=%d turns=%d effects=%d" % [hunt_seed, _turns, _first.size()])
	await super._finish(outcome)


func _fail(message: String) -> void:
	printerr("FEL10 HUNT FAIL " + message)
	finished = true
	quit(1)
