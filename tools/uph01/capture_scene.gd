extends "res://scripts/run_scene.gd"

## Debug-only deterministic clock. Production animation/render methods run intact.
const STEP_SECONDS: float = 1.0 / 300.0
class ProofClock extends "res://scripts/combat_pacing.gd":
	var controlled: bool = false
	var now: int = 0
	func presentation_usec() -> int:
		return now if controlled else super.presentation_usec()

var proof_sample: Callable
var recording: bool = false
var proof_seconds: float = 0.0

func _init() -> void:
	_combat_pacing.free()
	_combat_pacing = ProofClock.new()
	_combat_pacing.install(self)

func record(action: Callable) -> void:
	var clock: ProofClock = _combat_pacing
	clock.now = clock.presentation_usec()
	var origin: int = clock.now
	var initial_seconds: float = proof_seconds
	var tick: int = 0
	clock.controlled = true
	recording = true
	var completion: Dictionary = {"done": false}
	_perform(action, completion)
	while not completion["done"]:
		if proof_sample.is_valid(): await proof_sample.call()
		tick += 1
		clock.now = origin + roundi(float(tick) * STEP_SECONDS * 1000000.0)
		proof_seconds = initial_seconds + float(tick) * STEP_SECONDS
		await get_tree().process_frame
	if proof_sample.is_valid(): await proof_sample.call()
	recording = false
	clock.controlled = false

func _perform(action: Callable, completion: Dictionary) -> void:
	await action.call()
	completion["done"] = true
