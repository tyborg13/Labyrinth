extends SceneTree
const Suite = preload("res://tests/suites/en06_enemies_suite.gd")
const Profile = preload("res://tests/helpers/en06_phase_profile.gd")
var _failures: Array[String]
var _checks: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Profile.start(self)
	Profile.mark("rules")
	Suite.run(Callable(self, "_expect"))
	Profile.mark("live", {"checks": _checks})
	await Suite.run_live(self, Callable(self, "_expect"))
	Profile.mark("finished", {"checks": _checks})
	for failure: String in _failures: push_error(failure)
	print("EN06 ENEMIES TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
