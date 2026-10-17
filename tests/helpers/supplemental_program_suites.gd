extends RefCounted

# Dispatch-only wrappers of existing suites are covered in-process. The audit
# rejects unique assertions and uncalled methods; lifecycle/storage tests keep
# their own task-runner process through headless_test_programs.json.
const SurfaceRelicSuite = preload("res://tests/suites/surface_relic_suite.gd")
const PROGRAM_BUDGET_SECONDS: int = 900

static func run(expect: Callable, started_usec: int) -> void:
	SurfaceRelicSuite.run(expect)
	var tool: String = ProjectSettings.globalize_path("res://tools/test_registration_audit.py")
	var output: Array
	var code: int = OS.execute("python3", PackedStringArray([tool]), output, true)
	for chunk: String in output: print(chunk)
	expect.call(code == 0, "Every headless test must be registered or explicitly quarantined; see TEST REGISTRATION AUDIT")
	var remaining: int = PROGRAM_BUDGET_SECONDS - int((Time.get_ticks_usec() - started_usec) / 1000000)
	if remaining <= 0:
		expect.call(false, "Full suite exceeded its 15 minute budget before supplemental tests")
		return
	output.clear()
	var arguments: PackedStringArray = [
		ProjectSettings.globalize_path("res://tools/godot_task_runner.py"),
		"--project", ProjectSettings.globalize_path("res://"),
		"--task-id", "qa-08", "--timeout", str(remaining), "--stream", "--",
		"python3", tool, "--run-registered", "--output-dir",
		ProjectSettings.globalize_path("user://supplemental-tests")
	]
	code = OS.execute("python3", arguments, output, true)
	for chunk: String in output: print(chunk)
	expect.call(code == 0, "Supplemental headless program tests should pass")
