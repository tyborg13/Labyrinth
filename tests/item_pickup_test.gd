extends SceneTree

const ItemPickupSuite = preload("res://tests/suites/item_pickup_suite.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	ItemPickupSuite.run(_expect)
	for failure: String in _failures:
		push_error(failure)
	print("ITEM PICKUP TEST: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
