extends RefCounted

## Run the missing section-enemy standalone suites before the existing program
## sub-suites report the total runtime. All share the existing 900 second budget.
const SUITES: Array[String] = ["en04_enemies_test", "en05_enemies_test", "en06_enemies_test", "static_facing_test"]
const SUITE_TIMEOUT_SECONDS: int = 180
const PROGRAM_BUDGET_SECONDS: int = 900

static func run(expect: Callable, started_usec: int) -> void:
	for suite: String in SUITES:
		var remaining: int = PROGRAM_BUDGET_SECONDS - int((Time.get_ticks_usec() - started_usec) / 1000000)
		if remaining <= 0:
			expect.call(false, "Full suite exceeded its 15 minute budget before " + suite)
			return
		var output: Array
		var args: PackedStringArray = [ProjectSettings.globalize_path("res://tools/godot_task_runner.py"),
			"--project", ProjectSettings.globalize_path("res://"), "--task-id", "art-03",
			"--timeout", str(mini(remaining, SUITE_TIMEOUT_SECONDS)), "--stream", "--",
			OS.get_executable_path(), "--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/" + suite + ".gd"]
		var code: int = OS.execute("python3", args, output, true)
		for chunk: String in output: print(chunk)
		expect.call(code == 0, "Program sub-suite failed: %s (exit %d)" % [suite, code])
		print("PROGRAM SUITE %s: %s" % [suite, "PASS" if code == 0 else "FAIL"])
