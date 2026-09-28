extends SceneTree
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
var failed: bool = false
func _initialize() -> void:
	Parallel.apply_from_environment()
	Store.set_storage_path("user://hearth_profile.json")
	Store.set_run_storage_path("user://hearth_run.save")
	call_deferred("_run")
func _run() -> void:
	await preload("res://tests/suites/ember_hearth_suite.gd").run(self, _expect)
	print("TEST RESULT: %s Ember Hearth lifecycle" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
