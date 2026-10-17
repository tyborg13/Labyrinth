extends RefCounted

# Standalone suites own their SceneTree and task-runner HOME. Run only those
# independent processes concurrently; scene-owned/in-process tests stay serial.
const MAX_PARALLEL_PROGRAMS: int = 4
const POLL_INTERVAL_MSEC: int = 10

static func run(suites: Array[String], expect: Callable, started_usec: int, suite_timeout_seconds: int, budget_seconds: int) -> void:
	var next: int = 0
	var running: Array[Dictionary]
	var results: Dictionary = {}
	while next < suites.size() or not running.is_empty():
		while next < suites.size() and running.size() < MAX_PARALLEL_PROGRAMS:
			var remaining: int = budget_seconds - int((Time.get_ticks_usec() - started_usec) / 1000000)
			if remaining <= 0:
				expect.call(false, "Full suite exceeded its 15 minute budget before " + suites[next])
				next = suites.size()
				break
			var suite: String = suites[next]
			next += 1
			var args: PackedStringArray = _arguments(suite, mini(remaining, suite_timeout_seconds))
			var worker := Thread.new()
			var error: Error = worker.start(_execute.bind(args))
			if error == OK:
				running.append({"suite": suite, "worker": worker})
			else:
				results[suite] = {"code": error, "output": ["Could not start program worker: " + suite]}
		for entry: Dictionary in running.duplicate():
			var worker: Thread = entry["worker"]
			if worker.is_alive(): continue
			results[entry["suite"]] = worker.wait_to_finish()
			running.erase(entry)
		if not running.is_empty(): OS.delay_msec(POLL_INTERVAL_MSEC)
	# Keep the existing deterministic registry order in logs and assertions.
	for suite: String in suites:
		if not results.has(suite): continue
		var result: Dictionary = results[suite]
		for chunk: String in result["output"]: print(chunk)
		var code: int = int(result["code"])
		expect.call(code == 0, "Program sub-suite failed: %s (exit %d)" % [suite, code])
		print("PROGRAM SUITE %s: %s" % [suite, "PASS" if code == 0 else "FAIL"])

static func _arguments(suite: String, timeout_seconds: int) -> PackedStringArray:
	var arguments: PackedStringArray = [
		ProjectSettings.globalize_path("res://tools/godot_task_runner.py"),
		"--project", ProjectSettings.globalize_path("res://"),
		"--task-id", "qa-01", "--timeout", str(timeout_seconds),
		"--stream", "--", OS.get_executable_path(), "--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tests/" + suite + ".gd"
	]
	if suite == "sfx_sync_harness": arguments.append_array(["--", "--assert-onsets"])
	return arguments

static func _execute(arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute("python3", arguments, output, true)
	return {"code": code, "output": output}
