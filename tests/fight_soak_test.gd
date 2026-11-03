extends "res://tools/fight_soak.gd"
## Default-suite lifetime regression: real scene, bot cards, hover and passes.
## No millisecond threshold. The parent defaults to the tier-2 earth Warband.
func _initialize() -> void:
	check_plateau = true
	# Keep hand/preview churn active for all 20 cycles, even after the fixture
	# has spent or declined its hand. Main reports keep continuous fights.
	replay_policy_cycles = true
	await super._initialize()
	if not report.is_empty():
		print("TEST RESULT: %s — earth Warband 20-round node lifetime soak" % ["PASS" if (report["errors"] as Array).is_empty() else "FAIL"])
