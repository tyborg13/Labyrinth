extends "res://tools/run_hunt.gd"
## Check disclosed Pass numbers against the committed phase and the live board.

const Pass = preload("res://tools/qa120/pass_outcome.gd")
const MAX_LOCK_MSEC: int = 30000
const QUIET_FRAMES: int = 3
const MAX_FROZEN_PHASES: int = 100
const LOSS_FIELDS: Array[String] = ["hp", "block", "stoneskin"]
const UNKNOWN: Array[String] = ["unrevealed_before_player", "umbra_unknown_before_player",
	"terminal_unknown", "unseen_ground_crossed", "new_arrival_before_player", "forecast_limit_reached"]

var _pass: Dictionary
var _lock_started: int

func _initialize() -> void:
	super._initialize()
	Engine.max_fps = 0

func _tick() -> void:
	if is_instance_valid(scene) and not finished and not busy:
		if scene._animation_lock:
			if _lock_started == 0: _lock_started = Time.get_ticks_msec()
			if Time.get_ticks_msec() - _lock_started >= MAX_LOCK_MSEC:
				_finding("softlock", "RunScene animation lock lasted at least %d real milliseconds" % MAX_LOCK_MSEC)
				_finish("animation_lock")
				return
		else:
			_lock_started = 0
			if not _pass.is_empty(): _check_pass()
	super._tick()
	settle_frames = mini(settle_frames, QUIET_FRAMES)

func _record(action: Dictionary) -> void:
	super._record(action)
	if action.get("kind") != "pass": return
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip")
	var shown: Dictionary = chip.get_meta("pass_forecast_summary", {}) if chip != null else {}
	_pass = {"shown": shown.duplicate(true), "replay": replay_pass(scene, scene._combat_state.duplicate(true))}

static func replay_pass(host: Node, before: Dictionary) -> Dictionary:
	var phase: Dictionary = Pass.replay(host, before)
	var replay: Dictionary = {"first": phase["state"], "state": phase["state"],
		"losses": phase["losses"].duplicate(), "skipped": 0, "complete": true}
	# Pass predicts the next turn the hero can act on. Keep the first handoff
	# for the live-board check and use the full span for the forecast totals.
	while phase["outcome"].is_empty() and phase["state"].get("player_turn_restrictions", {}).get("frozen", false):
		if replay["skipped"] >= MAX_FROZEN_PHASES:
			replay["complete"] = false
			break
		phase = Pass.replay(host, phase["state"])
		replay["state"] = phase["state"]
		replay["skipped"] += 1
		for field: String in LOSS_FIELDS:
			replay["losses"][field] += int(phase["losses"][field])
	return replay

func _check_pass() -> void:
	var shown: Dictionary = _pass["shown"]
	var replay: Dictionary = _pass["replay"]
	var expected: Dictionary = replay["state"]
	var actual: Dictionary = scene._combat_state
	var disclosed: bool = not shown.is_empty() and replay["complete"]
	for flag: String in UNKNOWN:
		if shown.get(flag, false): disclosed = false
	var mismatches: Dictionary = {}
	if disclosed:
		for field: String in LOSS_FIELDS:
			var key: String = field + "_loss"
			var loss: int = int(replay["losses"][field])
			if int(shown.get(key, -1)) != loss: mismatches[key] = [shown.get(key), loss]
		var hp: int = int(shown.get("projected_hp", -1))
		if hp >= 0 and hp != int(expected["player"]["hp"]):
			mismatches["projected_hp"] = [hp, expected["player"]["hp"]]
		if int(shown.get("skipped_turns", 0)) != replay["skipped"]:
			mismatches["skipped_turns"] = [shown.get("skipped_turns", 0), replay["skipped"]]
	var replay_matches: bool = actual.is_empty() or Pass.board_state(replay["first"]) == Pass.board_state(actual)
	var context: Dictionary = _context()
	context.erase("room_metadata")
	_emit("qa127_pass", {"context": context, "disclosed": disclosed, "shown": not shown.is_empty(),
		"live_board_available": not actual.is_empty(), "replay_matches": replay_matches, "mismatches": mismatches})
	if not mismatches.is_empty() or not replay_matches:
		_finding("warning", "Pass forecast versus committed replay: %s; live board agrees: %s"
			% [str(mismatches.keys()), replay_matches])
	_pass.clear()
