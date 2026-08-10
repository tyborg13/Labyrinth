extends SceneTree

const InlineIconDescriptionSuite = preload("res://tests/suites/inline_icon_description_suite.gd")

var _failures: Array[String]


func _initialize() -> void:
	InlineIconDescriptionSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("INLINE ICON DESCRIPTION TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("INLINE ICON DESCRIPTION TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
