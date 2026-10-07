extends SceneTree
var _errors: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await preload("res://tests/suites/enemy_strike_trail_suite.gd").run(self,Callable(self,"_expect"))
	for error: String in _errors: push_error(error)
	print("ENEMY STRIKE TRAIL TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message): _errors.append(message)
