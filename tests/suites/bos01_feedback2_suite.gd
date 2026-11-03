extends RefCounted
## Preview APIs stay pure because only accepted live transitions can switch.
const Combat = preload("res://scripts/combat_engine.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const DIALS: Dictionary = {"gust": {"tiles": 1, "direction": "toward_source"}, "wildfire": {"spread": "toward_player"}, "frostbite": {"damage": 2}, "lightning_storm": {"damage": 4, "chain": 0}, "upheaval": {"pattern": "line_between", "length": 3, "health": 3}, "shadowstep": {"blink": 3}}
const CHANGES: Dictionary = {"gust": {"direction": "turn_clockwise", "tiles": 2}, "wildfire": {"spread": "all"}, "frostbite": {"damage": 0}, "lightning_storm": {"chain": 2}, "upheaval": {"health": 4}, "shadowstep": {"blink": 2}}
const HIT: Dictionary = {"type": "melee", "range": 1, "damage": 2}
const PREFIX: Dictionary = {"type": "aoe", "range": 0, "pattern": [[0, -1]], "rotate": false, "damage": 2}
const SOURCE := Vector2i(5, 4)
const HALF_SENTENCE: String = preload("res://tests/fixtures/bos01_rule_fights.gd").HALF_HEALTH_SENTENCE

class Observer extends Combat:
	var observations: Array[Dictionary]
	var action_rules: Array[Dictionary]
	func _damage_enemy(state: Dictionary, enemy_index: int, damage: int, apply_freeze_multiplier: bool = true, bypass_defense: bool = false, apply_relic_bonus: bool = true, apply_direct_amplification: bool = true) -> Dictionary:
		var after: Dictionary = super._damage_enemy(state, enemy_index, damage, apply_freeze_multiplier, bypass_defense, apply_relic_bonus, apply_direct_amplification)
		observations.append(after.duplicate(true))
		return after
	func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup_action: Dictionary = {}, bleed_steps: Array[Dictionary] = [], action_context: Dictionary = {}) -> Dictionary:
		action_rules.append(state.get("battlefield_rule", {}).duplicate(true))
		return super._resolve_enemy_action(state, enemy_index, action, rng, followup_action, bleed_steps, action_context)

static func fixture(engine: RefCounted, rule_name: String) -> Dictionary:
	var state: Dictionary = Base.battle(engine)
	state["enemies"][0].merge({"pos": SOURCE, "hp": 26, "max_hp": 50}, true)
	var rule: Dictionary = Base.rule(rule_name, DIALS[rule_name].duplicate(true), true)
	rule["cadence"]["every"] = 3
	rule["at_half_health"] = {"cadence": {"every": 2}, "dials": CHANGES[rule_name].duplicate(true), "sentence": HALF_SENTENCE}
	Rules.install(engine, state, rule)
	return state

static func unswitched(state: Dictionary, reference: Dictionary, expect: Callable, label: String) -> void:
	var instance: Dictionary = state.get("battlefield_rule", {})
	var unchanged: bool = instance.get("dials", {}) == reference["dials"] and instance.get("cadence", {}) == reference["cadence"] and instance.get("sentence", "") == reference["sentence"] and not bool(instance.get("half_health_switched", false))
	# Source death may legitimately clear an instance on a private copy.
	if instance.is_empty() and int(state.get("enemies", [{}])[0].get("hp", 0)) <= 0: unchanged = true
	if not instance.is_empty() and reference.has("locked_direction"): unchanged = unchanged and instance.get("locked_direction") == reference["locked_direction"]
	var switches: Array = state.get("surface_events", []).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "battlefield_rule_switched")
	expect.call(unchanged and switches.is_empty(), "BOS01 F2 preview never switches: " + label)
	expect.call(not state.has("_battlefield_rule_preview"), "BOS01 F2 no transient context in snapshot: " + label)

static func run(expect: Callable) -> void:
	var engine := Observer.new()
	for rule_name: String in DIALS:
		var state: Dictionary = fixture(engine, rule_name)
		var before: Dictionary = state.duplicate(true)
		var after: Dictionary = engine.surface_preview_for_player_action(state, HIT, SOURCE)["state"]
		expect.call(after["enemies"][0]["hp"] == 24, "BOS01 F2 hover resolves the reviewer's 2-damage hit: " + rule_name)
		unswitched(after, before["battlefield_rule"], expect, "hover/" + rule_name)
		after = engine.apply_player_action(state, HIT, SOURCE)
		unswitched(after, before["battlefield_rule"], expect, "provisional_action/" + rule_name)
		var clock: Dictionary = state.duplicate(true)
		clock["battlefield_rule"]["cadence"] = {"anchor": "on_intent", "intent": "test_wait"}
		clock["battlefield_rule"]["at_half_health"]["cadence"] = {"anchor": "on_intent", "intent": "test_wait"}
		Surfaces.place(clock, SOURCE, "fire")
		engine.observations.clear()
		engine.EnemyActivationRules.forecast(engine, clock, 0)
		expect.call(not engine.observations.is_empty(), "BOS01 F2 activation forecast actually damages source: " + rule_name)
		for observed: Dictionary in engine.observations: unswitched(observed, clock["battlefield_rule"], expect, "activation/" + rule_name)
		engine.observations.clear()
		engine.current_turn_order(clock)
		expect.call(not engine.observations.is_empty(), "BOS01 F2 turn clock actually forecasts source contact: " + rule_name)
		for observed: Dictionary in engine.observations: unswitched(observed, clock["battlefield_rule"], expect, "turn_clock/" + rule_name)
		var pass_state: Dictionary = state.duplicate(true)
		Surfaces.place(pass_state, SOURCE, "fire")
		var scheduled: Dictionary = engine.finish_player_activation(pass_state)
		after = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)["state"]
		unswitched(after, before["battlefield_rule"], expect, "PASS/" + rule_name)
		var committed: Dictionary = Committed.player_action(engine, state, HIT, SOURCE)
		expect.call(bool(committed["battlefield_rule"].get("half_health_switched", false)) and committed["battlefield_rule"]["cadence"]["every"] == 2 and committed["battlefield_rule"]["sentence"] == HALF_SENTENCE, "BOS01 F2 same committed hit switches: " + rule_name)
		expect.call(state == before, "BOS01 F2 every query preserves its source input: " + rule_name)
	_hero_action_timing(engine, expect)
	_enemy_action_timing(engine, expect)
	print("BOS01 F2 ENGINE PREVIEWS: six rules, hover/targeting/activation/clock/PASS and committed action timing checked")

static func _hero_action_timing(engine: Observer, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "gust")
	state["deck"]["hand"] = ["quick_stab"]
	state["enemies"].append(Base.Fixtures.enemy(2, Vector2i(6, 5), 50))
	var actions: Array = [{"type": "aoe", "range": 0, "pattern": [[0, -1], [1, 0]], "rotate": false, "damage": 2}, HIT]
	var targets: Array[Vector2i]
	targets.append(SOURCE)
	var resolved: Dictionary = engine.apply_player_action(state, actions[0])
	resolved = engine.apply_player_action(resolved, HIT, SOURCE)
	engine.observations.clear()
	var after: Dictionary = Committed.player_card(engine, state, resolved, 0, actions, targets)
	var flags: Array = engine.observations.map(func(observed: Dictionary) -> bool: return bool(observed.get("battlefield_rule", {}).get("half_health_switched", false)))
	expect.call(flags == [false, false, true], "BOS01 F2 hero action retains old dials through all hits, then next action sees switch")
	expect.call(after["enemies"][0]["hp"] == 22 and bool(after["battlefield_rule"].get("half_health_switched", false)), "BOS01 F2 committed card accepts both selected actions")

static func _enemy_action_timing(engine: Observer, expect: Callable) -> void:
	var state: Dictionary = fixture(engine, "gust")
	state["battlefield_rule"]["at_half_health"]["cadence"]["every"] = 1
	state["enemies"][0]["bleed"] = 2
	state["enemies"][0]["intent"] = {"id": "bos01_acceptance_fixture", "time": 4, "actions": [HIT, {"type": "block", "amount": 1}]}
	engine.action_rules.clear()
	var after: Dictionary = Committed.enemy_turn(engine, state, 0)["state"]
	var flags: Array = engine.action_rules.map(func(instance: Dictionary) -> bool: return bool(instance.get("half_health_switched", false)))
	expect.call(flags == [false, true], "BOS01 F2 committed enemy action switches before its next action")
	expect.call(after["battlefield_rule"]["beats_fired"] == 1, "BOS01 F2 accepted switch cadence applies before the next beat")

static func scene_previews(scene: Control, expect: Callable) -> void:
	var engine := Observer.new()
	var original_engine: RefCounted = scene.get("_combat_engine")
	var wind_view: GDScript = preload("res://scripts/enemy_mechanics/wind_view.gd")
	var original_wind_engine: RefCounted = wind_view._engine
	scene.set("_combat_engine", engine)
	wind_view._engine = engine
	for rule_name: String in DIALS:
		var state: Dictionary = fixture(engine, rule_name)
		scene.call("_load_run_state", preload("res://tests/fixtures/bos01_rule_fights.gd").run_state(state))
		scene.call("_close_dialogue")
		var hover: Dictionary = scene.call("_surface_resolution_for_preview", state, HIT, SOURCE)
		unswitched(hover["actual"]["state"], state["battlefield_rule"], expect, "production_hover/" + rule_name)
		var actions: Array = [PREFIX, HIT]
		var card: Dictionary = scene.call("_card_preview_from_state", "bos01_review_fixture", state, actions, 0)
		expect.call(int(card.get("action_index", -1)) == 1 and card["state"]["enemies"][0]["hp"] == 24, "BOS01 F2 provisional targeting resolves its damaging prefix: " + rule_name)
		unswitched(card["state"], state["battlefield_rule"], expect, "production_targeting/" + rule_name)
		var rest: Dictionary = fixture(engine, rule_name)
		if rule_name == "gust": rest["battlefield_rule"]["dials"]["direction"] = "aimed"
		rest["wind"] = {"source_id": 1, "direction": Vector2i.UP, "push": 1, "rounds_left": 2}
		rest["enemies"][0]["intent"] = {"id": "call", "time": 4, "actions": [{"type": "call_wind", "rounds": 2, "push": 1, "_wind_direction": Vector2i.RIGHT}]}
		Surfaces.place(rest, SOURCE, "fire")
		engine.observations.clear()
		var at_rest: Dictionary = wind_view._forecast_for_state(rest)
		var reference: Dictionary = rest["battlefield_rule"].duplicate(true)
		# A pending Call already announced Right may project its own held lock;
		# it must not apply the uncommitted half-Health replacement.
		reference.erase("locked_direction")
		if rule_name == "gust":
			expect.call(not engine.observations.is_empty(), "BOS01 F2 at-rest Gust forecasts source Fire contact")
		else:
			expect.call(not engine.observations.is_empty() or not at_rest["wind"].is_empty(), "BOS01 F2 at-rest legacy wind query runs without a half-Health source hit: " + rule_name)
		for observed: Dictionary in engine.observations: unswitched(observed, reference, expect, "at_rest_wind/" + rule_name)
		unswitched(rest, rest["battlefield_rule"], expect, "at_rest_input/" + rule_name)
		if rule_name == "gust": expect.call(Rules.forecast(engine, state)["direction"] == Vector2i.UP, "BOS01 F2 Gust forecast holds Up through all production previews")
	scene.set("_combat_engine", original_engine)
	wind_view._engine = original_wind_engine
	print("BOS01 F2 PRODUCTION PREVIEWS: six rules, hover, provisional targeting and at-rest wind checked")
