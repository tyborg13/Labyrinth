extends RefCounted
## The frozen policy stays reproducible; the active adapter commits its choices.
const Frozen = preload("res://tools/encounter_bot.gd")
const Active = preload("res://tools/bot_policy.gd")
const Fixtures = preload("res://tests/suites/bos01_feedback2_suite.gd")

class Fight extends Frozen.CombatEngine:
	var initial: Dictionary
	var switched_state: Dictionary
	func create_combat(_seed_value: int, _layout: Dictionary, _run_data: Dictionary) -> Dictionary:
		if initial.is_empty(): return super.create_combat(_seed_value, _layout, _run_data)
		return initial.duplicate(true)
	func combat_outcome(state: Dictionary) -> String:
		# End this test-only fight at the accepted threshold, keeping the source
		# alive so a missing commit cannot masquerade as a successful kill.
		if bool(state.get("battlefield_rule", {}).get("half_health_switched", false)):
			switched_state = state.duplicate(true)
			return "victory"
		return super.combat_outcome(state)

static func run(expect: Callable) -> void:
	for rule_name: String in Fixtures.DIALS:
		var engine := Fight.new()
		var state: Dictionary = Fixtures.fixture(engine, rule_name)
		state["objective"] = {"type": "kill_all"}
		state["deck"]["hand"] = ["quick_stab"]
		state["player_movement_remaining"] = 0
		engine.initial = state
		var before: Dictionary = state.duplicate(true)
		var legacy := Frozen.Policy.new()
		legacy.engine = engine
		var active := Active.new()
		active.engine = engine
		var reference: Dictionary = legacy.choose(state)
		var choice: Dictionary = active.choose(state)
		var comparable: Dictionary = choice.duplicate(true)
		comparable.erase("commit")
		expect.call(not choice.is_empty() and comparable == reference, "BOS01 active bot retains frozen decisions, scores and projected state: " + rule_name)
		expect.call(state == before and engine.switched_state.is_empty(), "BOS01 bot selection never accepts a speculative branch: " + rule_name)
		var result: Dictionary = active.run_room(Fixtures.Base.Fixtures.FIXTURE_SEED, {"objective": state["objective"]}, state["deck"]["hand"])
		expect.call(result["won"] and not engine.switched_state.is_empty(), "BOS01 active bot accepts its chosen hit and switches: " + rule_name)
		expect.call(engine.switched_state.get("battlefield_rule", {}).get("sentence", "") == Fixtures.HALF_SENTENCE, "BOS01 active bot keeps the committed switch state: " + rule_name)
