extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
 preload("res://tests/suites/guardian_suite.gd").run(func(ok: bool, message: String) -> void:
  if not ok: failures.append(message))
 preload("res://tests/suites/ground_targeting_suite.gd").run(func(ok: bool, message: String) -> void:
  if not ok: failures.append(message))
 preload("res://tests/suites/combat_outcome_feedback_suite.gd").run(func(ok: bool, message: String) -> void:
  if not ok: failures.append(message))
 for message: String in failures: push_error(message)
 print("GUARDIAN CONTRACT: ","PASS" if failures.is_empty() else "FAIL", " ",failures.size())
 quit(0 if failures.is_empty() else 1)
