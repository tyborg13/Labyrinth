extends SceneTree
## Invoke the existing keyword and text suites without the full product test program.

const SUITES := ["card_keywords", "card_keywords_w3", "tooltip_consistency",
	"glossary_coverage", "inline_icon_description", "grimoire_search"]

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for name: String in SUITES:
		var suite: GDScript = load("res://tests/suites/%s_suite.gd" % name)
		var previous: int = _failures
		await suite.run(_expect.bind(name))
		print("POL-80 %s: %d failures" % [name, _failures - previous])
	print("POL-80 FOCUSED %s (%d checks, %d failures)" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String, suite: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL %s: %s" % [suite, message])
