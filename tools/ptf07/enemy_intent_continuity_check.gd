extends SceneTree

# Focused entry point for the main-suite enemy-tooltip continuity failures.
# Run the existing suite verbatim without starting the full test harness.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(_expect)
	print("PTF07 ENEMY CONTINUITY: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)
