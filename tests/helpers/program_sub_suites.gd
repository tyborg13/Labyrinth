extends RefCounted

# These runners own a SceneTree, singleton storage paths and, in several cases,
# a dummy-renderer clock. Separate task-runner processes preserve that isolation
# and execute their complete standalone coverage, rather than just pure rules.
const SUITES: Array[String] = [
	"combat_feel_test", # Includes combat_pacing_regression_suite.
	"event_view_test", "event_rules_test", "biome_test", "health_ghost_test",
	"movement_undo_test", "threats_at_rest_test", "encounter_tables_test",
	"run_score_test", "sfx_bank_test", "sfx_sync_bank_test", "sfx_sync_harness", "section_map_v2_test",
	"en01_enemies_test", "en02_enemies_test", "en03_enemies_test",
	"magic_deck_input_test",
	"run_end_recap_tests", "main_menu_resume_test"
]
const SUITE_TIMEOUT_SECONDS: int = 180
const PROGRAM_BUDGET_SECONDS: int = 900

static func run(expect: Callable, full_suite_started_usec: int) -> void:
	for suite: String in SUITES:
		var remaining: int = PROGRAM_BUDGET_SECONDS - int((Time.get_ticks_usec() - full_suite_started_usec) / 1000000)
		if remaining <= 0:
			expect.call(false, "Full suite exceeded its 15 minute budget before " + suite)
			return
		var output: Array = []
		var arguments: PackedStringArray = [
			ProjectSettings.globalize_path("res://tools/godot_task_runner.py"),
			"--project", ProjectSettings.globalize_path("res://"),
			"--task-id", "qa-01", "--timeout", str(mini(remaining, SUITE_TIMEOUT_SECONDS)),
			"--stream", "--", OS.get_executable_path(), "--headless", "--path",
			ProjectSettings.globalize_path("res://"), "--script", "res://tests/" + suite + ".gd"
		]
		if suite == "sfx_sync_harness": arguments.append_array(["--", "--assert-onsets"])
		var code: int = OS.execute("python3", arguments, output, true)
		for chunk: String in output: print(chunk)
		expect.call(code == 0, "Program sub-suite failed: %s (exit %d)" % [suite, code])
		print("PROGRAM SUITE %s: %s" % [suite, "PASS" if code == 0 else "FAIL"])
	var elapsed: float = float(Time.get_ticks_usec() - full_suite_started_usec) / 1000000.0
	print("FULL SUITE RUNTIME: %.3f seconds (budget 900 seconds)" % elapsed)
	expect.call(elapsed < PROGRAM_BUDGET_SECONDS, "Full suite stays under 15 minutes")
