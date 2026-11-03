extends SceneTree
## Preserve the root-suite startup context: no deferred _initialize here.
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await preload("res://tests/suites/mim01_suite.gd").run_live(self, _expect)
	preload("res://tests/suites/relic_u3_suite.gd").run(_expect)
	preload("res://tests/suites/combat_objective_suite.gd").run(_expect)
	var hud := preload("res://scripts/combat_objective_hud.gd").new()
	var state: Dictionary = {"initiative_clock": 5}
	var objective: Dictionary = {"type": "survive", "target_clock": 20, "next_reinforcement_clock": 10}
	_expect(hud._live_detail(state, objective) == "Dawn in 15 · Reinforcements in 5", "Survival HUD uses the director's compact reinforcement copy")
	objective["next_reinforcement_clock"] = 20
	_expect(hud._live_detail(state, objective) == "Dawn in 15 · Final wave deployed", "Survival HUD uses the director's compact final-wave copy")
	hud.free()
	for failure: String in failures: push_error(failure)
	print("INT11 INTEGRATION: %s (%d checks; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
