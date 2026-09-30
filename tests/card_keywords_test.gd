extends SceneTree

const CardKeywordsSuite = preload("res://tests/suites/card_keywords_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	CardKeywordsSuite.run(Callable(self, "_expect"))
	await CardKeywordsSuite.run_live(self, Callable(self, "_expect"))
	if _failures.is_empty():
		print("CARD KEYWORDS TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CARD KEYWORDS TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
