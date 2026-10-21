extends SceneTree
const Suite = preload("res://tests/suites/special_encounter_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	if OS.get_cmdline_user_args().has("--assets-only"):
		Suite._test_names(expect)
	elif OS.get_cmdline_user_args().has("--feedback-only"):
		Suite._test_rewards_and_resume(expect)
		Suite._test_reward_floor(expect)
		Suite._test_names(expect)
		Suite._test_door_names(expect)
	else:
		Suite.run(expect)
	for failure: String in failures: push_error(failure)
	print("SPX special encounter suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
