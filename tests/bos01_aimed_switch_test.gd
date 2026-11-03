extends SceneTree
## Final-review regression: a half-Health switch to an aimed Gust keeps its held announcement.
const F = preload("res://tests/suites/bos01_feedback2_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := F.Combat.new()
	var state: Dictionary = F.fixture(engine, "gust")
	var authored: Dictionary = state["battlefield_rule"].duplicate(true)
	authored["at_half_health"] = {"dials": {"direction": "aimed"}, "sentence": "The held wind remains aimed."}
	state["battlefield_rule"] = {}
	Rules.install(engine, state, authored)
	state = Committed.player_action(engine, state, F.HIT, F.SOURCE)
	var switched: bool = bool(state["battlefield_rule"].get("half_health_switched", false))
	var problem: String = Rules.error_for(state, state["battlefield_rule"])
	var ok: bool = switched and problem.is_empty() and not (Rules.forecast(engine, state) as Variant == null)
	print("BOS01 AIMED SWITCH TEST: %s (switched=%s, error=%s)" % ["PASS" if ok else "FAIL", switched, problem])
	quit(0 if ok else 1)
