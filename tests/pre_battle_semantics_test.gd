extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/pre_battle_ui_suite.gd")
var _failed: bool = false
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	for path: String in ["res://tests/pre_battle_preview_probe.gd", "res://tests/pre_battle_material_polish_probe.gd", "res://tests/pre_battle_deck_fit_probe.gd", "res://tests/pre_battle_loadout_refinement_probe.gd"]:
		var script: Script = load(path) as Script
		_expect(script != null and script.can_instantiate(), "All pre-battle probes must parse: " + path)
	Suite.run(_expect)
	print("PRE-BATTLE SEMANTICS TEST: %s" % ("FAIL" if _failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
