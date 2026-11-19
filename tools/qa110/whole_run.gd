extends "res://tools/run_hunt.gd"
## The parent owns route choice and dispatch. Sample the result of each
## decision, including the last decision before a natural terminal screen.

const Audit = preload("res://tools/qa110/settled.gd")
const IDLE_FRAMES: int = 2
const SETTLE_WATCHDOG_MSEC: int = 20000

var audit := Audit.new()
var observed_decision: int = -1
var quiet_frames: int
var waiting_since: int

func _start() -> void:
	var inputs: Dictionary = {}
	for file: String in ["whole_run.gd", "settled.gd", "scene_audit.gd", "model.gd"]:
		inputs[file] = FileAccess.get_sha256("res://tools/qa110/" + file)
	_emit("qa110_driver", inputs)
	await super._start()

func _tick() -> void:
	if finished or busy or not is_instance_valid(scene): return
	if observed_decision == decision:
		super._tick()
		return
	if waiting_since == 0: waiting_since = Time.get_ticks_msec()
	var stalled: bool = Time.get_ticks_msec() - waiting_since >= SETTLE_WATCHDOG_MSEC
	var running: int = audit.running_tweens(self).size()
	if running > 0 or audit.transitions_running(scene):
		quiet_frames = 0
		if not stalled: return
	else:
		quiet_frames += 1
		if quiet_frames <= IDLE_FRAMES: return
	var context: Dictionary = _context()
	context.erase("room_metadata")
	var action: Dictionary = history.back() if not history.is_empty() else {}
	context["action"] = action.get("kind", "initial")
	if stalled:
		_emit("qa110_unsettled", context.merged({"locked": scene._animation_lock, "running_tweens": running}))
	else:
		var result: Dictionary = audit.sample(self, scene, context, output)
		_emit("qa110_sample", result)
	observed_decision = decision
	waiting_since = 0
	quiet_frames = 0
	super._tick()
