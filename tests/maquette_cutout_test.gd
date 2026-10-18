extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	for type: String in ["bile_bloomer", "lightning_wisp"]:
		await preload("res://tests/maquette_cutout/runtime_suite.gd").run(self, _expect, type)
		await preload("res://tests/maquette_cutout/pixel_runtime_suite.gd").run(self, _expect, type)
	print("MAQUETTE CUTOUT: %s (%d checks, %d failures; headless logic only)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
