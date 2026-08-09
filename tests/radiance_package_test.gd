extends SceneTree

const RadiancePackageSuite = preload("res://tests/suites/radiance_package_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	RadiancePackageSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("RADIANCE PACKAGE TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("RADIANCE PACKAGE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
