extends SceneTree

const EnemyPathfindingSuite = preload("res://tests/suites/enemy_pathfinding_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	EnemyPathfindingSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("ENEMY PATHFINDING TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	push_error("ENEMY PATHFINDING TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
