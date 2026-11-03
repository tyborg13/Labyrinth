extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Mimic = preload("res://tests/suites/fix_12_mimic_suite.gd")
const Totals = preload("res://tests/helpers/fix_12_popup_totals.gd")
const Trace = preload("res://scripts/reaction_presentation_trace.gd")
const MatrixCases = preload("res://tests/suites/fix_14_owner_matrix_cases.gd")
# Reviewer fixtures and test-only variants, never production tuning.
const NESTED_TICK := Vector2i(3, 2)
const LETHAL_HERO_HP: int = 4
const BURST_DAMAGE: int = 4
const NESTED_REWARD_DAMAGE: int = 1
const LEGACY_RETALIATE: int = 2
const BASE_REVISION: String = "int-10"

static func _tick(state: Dictionary, tile: Vector2i) -> void:
	var id: int = 1
	for enemy: Dictionary in state["enemies"]: id = maxi(id, int(enemy["id"]) + 1)
	var tick: Dictionary = Base.Fixtures.enemy("ember_tick", id, tile)
	tick["hp"] = 1
	state["enemies"].append(tick)

static func cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result

static func run(expect: Callable) -> void:
	# Preserve ordinary Warden/Retaliate analytics after retiring both matrices.
	_legacy_analytics(expect)

static func _check_intermediates(expect: Callable, before: Dictionary, phase: Dictionary, label: String) -> void:
	var current: Dictionary = Trace.snapshot(before)
	for step: Dictionary in phase["steps"]:
		if step.has("move_after"): current = step["move_after"]
		var after: Dictionary = step.get("reaction_after", step.get("en03_after", step.get("en06_after", {})))
		if after.is_empty(): continue
		var losses: Array = (step.get("target_losses", []) as Array).duplicate(true)
		losses.append_array(step.get("enemy_losses", []))
		for key: String in Totals.actors(current):
			expect.call(Base.hp_loss(losses, key) == maxi(0, int(Totals.actors(current)[key].get("hp", 0)) - int(Totals.actors(after).get(key, {}).get("hp", 0))), "%s: ordered intermediate owns only %s HP loss" % [label, key])
		current = after

static func burst_ids(before: Dictionary, phase: Dictionary) -> Array[int]:
	var result: Array[int]
	var events: Array = phase["state"].get("death_burst_events", [])
	for index: int in range((before.get("death_burst_events", []) as Array).size(), events.size()): result.append(int(events[index]["id"]))
	return result

static func check_playback(expect: Callable, before: Dictionary, phase: Dictionary, scene: Control, label: String) -> void:
	var expected: Array[int] = burst_ids(before, phase)
	expect.call(scene.get("burst_sources") == expected, "%s: actual burst ring starts match resolution without deduplicating IDs" % label)
	expect.call(scene.get("burst_cue_starts") == expected, "%s: actual burst cue starts match resolution without deduplicating IDs" % label)
	if label.contains("arrival") or label.contains("nested"):
		print("FIX-14 FEEDBACK PLAYBACK: %s; ring starts=%s; cue starts=%s" % [label, scene.get("burst_sources"), scene.get("burst_cue_starts")])

static func _legacy_analytics(expect: Callable) -> void:
	# int-10 analytics baseline includes the approved additive payload fields.
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fix_14_legacy_analytics.json"))
	var engine := Base.Combat.new()
	var scene := Base.RunScene.new()
	for mode: String in ["ordinary", "retaliate"]:
		var state: Dictionary = Base.Fixtures.state([Base.Fixtures.enemy("warden", 1, Vector2i(4, 4), "crushing_step")], Vector2i(3, 4))
		_tick(state, Vector2i(4, 3))
		state["traps"] = [{"id": "fix_14_ordinary_fire", "pos": Vector2i(4, 3), "element": "fire", "damage": Base.TRAP_DAMAGE}]
		if mode == "retaliate": state["retaliate"] = {"amount": LEGACY_RETALIATE}
		var phase: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, false)
		var actual: Dictionary = {"actions": scene._analytics_enemy_action_events(phase, {}), "statuses": scene._analytics_enemy_status_tick_events(phase, {})}
		expect.call(JSON.stringify(actual) == str(golden[mode]), "Legacy Warden/Tick %s analytics byte-match base %s" % [mode, BASE_REVISION])
	scene.free()
