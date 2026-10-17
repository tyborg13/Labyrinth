extends RefCounted

## The main Godot owns one process slot; Python schedules the other three.
## The pipe is held for the whole run so parent death cancels every child.
const PROGRAM_BUDGET_SECONDS: int = 900
const WAIT_POLL_SECONDS: float = 0.05

static func start(options: Dictionary = {}) -> Dictionary:
	var result_path: String = ProjectSettings.globalize_path("user://program-suites.json")
	var arguments: PackedStringArray = [
		ProjectSettings.globalize_path("res://tools/program_suite_runner.py"),
		"--project", ProjectSettings.globalize_path("res://"),
		"--godot", str(options.get("godot", OS.get_executable_path())),
		"--result-file", result_path, "--watch-parent-stdin",
		"--timeout", str(options.get("timeout", 180)),
		"--budget", str(options.get("budget", PROGRAM_BUDGET_SECONDS))
	]
	for suite: String in options.get("suites", []):
		arguments.append_array(["--suite", suite])
	DirAccess.remove_absolute(result_path)
	var process: Dictionary = OS.execute_with_pipe("python3", arguments)
	return {"process": process, "result_path": result_path}

static func finish(tree: SceneTree, handle: Dictionary, expect: Callable, started_usec: int) -> void:
	var process: Dictionary = handle.get("process", {})
	var pid: int = int(process.get("pid", -1))
	var result_path: String = str(handle.get("result_path", ""))
	while pid > 0 and OS.is_process_running(pid):
		await tree.create_timer(WAIT_POLL_SECONDS).timeout
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path)) if FileAccess.file_exists(result_path) else null
	if not report is Dictionary or not bool(report.get("complete", false)):
		expect.call(false, "Program sub-suite scheduler failed to produce a complete report")
		if process.has("stderr"):
			print(process["stderr"].get_as_text())
	else:
		for result: Dictionary in report["results"]:
			var suite: String = str(result["name"])
			print(FileAccess.get_file_as_string(str(result["log_path"])))
			var code: int = int(result["returncode"])
			var reason: String = " (timed out)" if bool(result.get("timed_out", false)) else ""
			expect.call(code == 0, "Program sub-suite failed: %s (exit %d)%s" % [suite, code, reason])
			print("PROGRAM SUITE %s: %s" % [suite, "PASS" if code == 0 else "FAIL"])
			print("PROGRAM SUITE RUNTIME %s: %.3f seconds" % [suite, float(result["seconds"])])
	var elapsed: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	print("FULL SUITE RUNTIME: %.3f seconds (budget 900 seconds)" % elapsed)
	expect.call(elapsed < PROGRAM_BUDGET_SECONDS, "Full suite stays under 15 minutes")
