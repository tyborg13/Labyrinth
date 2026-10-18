extends Node

## Opt-in, wall-clock diagnostics; never drives the scene or its clocks.
const ENVIRONMENT_KEY: String = "LABYRINTH_EN06_PROFILE"
const SAMPLE_SECONDS: float = 10.0
static var _phase: String = "initializing"
static var _phase_started_usec: int = 0
static var _observer: Node
var _next_sample_usec: int = 0

static func start(tree: SceneTree) -> void:
	if OS.get_environment(ENVIRONMENT_KEY) != "1" or is_instance_valid(_observer): return
	_observer = load("res://tests/helpers/en06_phase_profile.gd").new()
	_observer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_observer)

static func mark(phase: String, details: Dictionary = {}) -> void:
	if OS.get_environment(ENVIRONMENT_KEY) != "1": return
	var now: int = Time.get_ticks_usec()
	print("EN06 PHASE: " + JSON.stringify({"phase": phase, "usec": now, "previous": _phase, "previous_usec": now - _phase_started_usec, "details": details}))
	_phase = phase
	_phase_started_usec = now

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if now < _next_sample_usec: return
	_next_sample_usec = now + int(SAMPLE_SECONDS * 1000000.0)
	var status: Dictionary = {"phase": _phase, "phase_usec": now - _phase_started_usec, "paused": get_tree().paused, "time_scale": Engine.time_scale}
	for child: Node in get_tree().root.get_children():
		if child.get_script() == null or not str(child.get_script().resource_path).ends_with("run_scene.gd"): continue
		status["seed"] = (child.get("_run_state") as Dictionary).get("seed", null)
		var pacing: Node = child.get("_combat_pacing")
		if pacing != null:
			# Read the stored clock: sampling must not advance it.
			status["presentation_usec"] = pacing.get("_clock_usec")
			status["scope"] = pacing.get("_scope")
			status["hit_stop"] = pacing.get("hit_stop").get("active")
	print("EN06 WAIT SAMPLE: " + JSON.stringify(status))
