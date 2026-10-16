extends "res://scripts/run_scene.gd"

## Only elapsed presentation time is controlled. Production action callbacks,
## popup clocks, clip selection and phase calculation run without overrides.
## Disk IO cannot advance this clock while a pose is being captured.
const PROOF_STEP_USEC: int = 6000
var proof_capture: Callable
var proof_elapsed_seconds: float = 0.0
var proof_completions: Dictionary = {}

class FixedClock extends "res://scripts/combat_pacing.gd":
	var fixed_usec: int = 0
	var controlled: bool = false

	func presentation_usec() -> int:
		return fixed_usec if controlled else super.presentation_usec()

func _init() -> void:
	_combat_pacing.free()
	_combat_pacing = FixedClock.new()
	_combat_pacing.install(self)

func record_action(clip: String, action: Callable) -> void:
	var clock: FixedClock = _combat_pacing
	clock.fixed_usec = clock.presentation_usec()
	clock.controlled = true
	var completion: Dictionary = {"done": false}
	_perform_action(action, completion)
	while not completion["done"]:
		await _capture_current()
		clock.fixed_usec += PROOF_STEP_USEC
		proof_elapsed_seconds += float(PROOF_STEP_USEC) / 1000000.0
		await get_tree().process_frame
	await _capture_current()
	var renderer: Node = board_view.unit_cutout_renderer({"type": "gust_shrike", "id": 1})
	if renderer != null: proof_completions[clip] = renderer.snapshot()
	clock.controlled = false

func _perform_action(action: Callable, completion: Dictionary) -> void:
	await action.call()
	completion["done"] = true

func _capture_current() -> void:
	if proof_capture.is_valid(): await proof_capture.call()
