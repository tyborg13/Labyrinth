extends SceneTree
const Suite = preload("res://tests/suites/special_encounter_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--special-part-0"):
		_run_seed_range(0, Suite.SEED_COUNT / Suite.SEED_PARTS, true)
		return
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	if OS.get_cmdline_user_args().has("--assets-only"):
		Suite._test_names(expect)
	elif OS.get_cmdline_user_args().has("--feedback-only"):
		Suite.PlacementRegressions.run(expect)
		Suite._test_rewards_and_resume(expect)
		Suite._test_deferred_special_rewards(expect)
		Suite._test_reward_floor(expect)
		Suite._test_names(expect)
		Suite._test_door_names(expect)
	else:
		Suite.run(expect)
	_finish()

func _run_seed_range(seed_begin: int, seed_end: int, include_cases: bool) -> void:
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	Suite.run(expect, seed_begin, seed_end, include_cases)
	_finish()

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("SPX special encounter suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
