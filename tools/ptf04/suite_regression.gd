extends SceneTree

var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://scripts/progression_store.gd").set_storage_path("user://ptf04_regression_profile.json")
	preload("res://scripts/progression_store.gd").set_run_storage_path("user://ptf04_regression_run.save")
	_run.call_deferred()

func _run() -> void:
	var enemy: bool = OS.get_cmdline_user_args().has("--enemy-intent")
	if enemy:
		preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(_expect)
	else:
		preload("res://tests/suites/tooltip_consistency_suite.gd").run(_expect)
	for failure: String in failures: push_error(failure)
	print("PTF04 %s: %d failures (%d checks)" % ["ENEMY INTENT" if enemy else "TOOLTIP CONSISTENCY", failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
