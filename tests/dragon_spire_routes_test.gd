extends SceneTree

const Suite = preload("res://tests/suites/dragon_spire_routes_suite.gd")
var failed: int = 0
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(expect)
	print("DRAGON SPIRE ROUTES TEST: %s (%d checks)" % ["PASS" if failed == 0 else "FAIL", checks])
	quit(1 if failed else 0)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
