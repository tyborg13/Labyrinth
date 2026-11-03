extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Mimic = preload("res://tests/suites/fix_12_mimic_suite.gd")
const Totals = preload("res://tests/helpers/fix_12_popup_totals.gd")
# Review reproductions and test-only scheduling.
const RETALIATE_HERO := Vector2i(3, 3)
const REFLECTION_TILE := Vector2i(5, 3)
const FRIENDLY_TILE := Vector2i(4, 3)
const ILLUSION_HP: int = 20
const LETHAL_REFLECTION_HP: int = 5
const RETALIATE_AMOUNT: int = 2
const LETHAL_RETALIATE_AMOUNT: int = 100
const SECOND_REACTION_HP: int = 6
const COLLISION_LOSS: int = 2
const COLLATERAL_HP: int = 10
const MOVING_MIMIC_START := Vector2i(4, 2)
const COLLATERAL_TILE := Vector2i(3, 4)
const MIMIC_ROUTE_WALLS: Array = [Vector2i(5, 2), Vector2i(5, 3)]
const RETALIATE_PUSH: int = 1
const BEAM_COLLISION_WALL := Vector2i(1, 3)
const UNRELATED_LOSS: int = 1
const SETTLE_FRAMES: int = 8
const PLAYBACK_TIMEOUT_SECONDS: float = 20.0 # Full-state recording; same debug cap as the owner matrix.

static func cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result

static func _review_cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result

static func run(expect: Callable) -> void:
	var combat := Base.Combat.new()
	var analytics := Base.RunScene.new()
	for case: Dictionary in cases():
		for commits: bool in [false, true]:
			var before: Dictionary = case["state"]
			var original: Dictionary = before.duplicate(true)
			var phase: Dictionary = combat.resolve_enemy_turn_with_steps(before, 0, commits)
			preload("res://tests/helpers/fix_12_popup_totals.gd").check_phase(expect, before, phase, "fix-12 %s" % str(before["enemies"][0]["type"]))
			var step: Dictionary = Mimic.action(phase)
			expect.call(not step.is_empty() and not bool(step.get("cancelled", false)) and not step["tiles"].is_empty(), "%s: resolved hit survives the attacker's reaction outcome" % case["name"])
			var attack_loss: int = Base.hp_loss(step["target_losses"], "player")
			var expected_hit: int = Mimic.copied_damage(before)
			expect.call(attack_loss == expected_hit, "%s: hit payload retains the real hero loss" % case["name"])
			var self_collision: int = 0
			expect.call(Base.hp_loss(step["target_losses"], "enemy_1") == self_collision, "%s: dedicated reactions own the attacker's losses" % case["name"])
			var snapshot: Dictionary = step.get("en03_after", step.get("en06_after", {}))
			var arrival: Dictionary = step.get("move_after", before)
			expect.call(snapshot["enemies"][0]["hp"] == arrival["enemies"][0]["hp"] - self_collision, "%s: attack snapshot defers reaction injury and death" % case["name"])
			var events: Array[Dictionary] = analytics._analytics_enemy_action_events(phase, {})
			expect.call(events.any(func(event: Dictionary) -> bool: return event["payload"]["presentation_kind"] != "move" and Base.hp_loss(event["payload"]["target_losses"], "player") == expected_hit), "%s: analytics retains the landed hit" % case["name"])
			if str(case["name"]).ends_with("collateral"):
				var statuses: Array[Dictionary] = analytics._analytics_enemy_status_tick_events(phase, {})
				expect.call(statuses.any(func(event: Dictionary) -> bool: return event["payload"]["action_type"] == "retaliate" and Base.hp_loss(event["payload"].get("enemy_losses", []), "enemy_3") == COLLISION_LOSS), "Mimic reaction analytics includes realized collateral victim")
				expect.call(preload("res://scripts/retaliate_rules.gd").events_between(before, phase["state"]).any(func(event: Dictionary) -> bool: return Base.hp_loss(event.get("enemy_losses", []), "enemy_3") == COLLISION_LOSS), "Mimic append-only surface event includes realized collateral victim")
			_check_intermediates(expect, phase, step, case)
			expect.call(before == original, "Reaction payload construction preserves the caller's state")
	_test_cancelled_boundaries(expect)
	analytics.free()

static func _check_intermediates(expect: Callable, phase: Dictionary, action: Dictionary, case: Dictionary) -> void:
	var current: Dictionary = action.get("en03_after", action.get("en06_after", {}))
	for step: Dictionary in phase["steps"]:
		if not step.has("reaction_after"): continue
		var next: Dictionary = step["reaction_after"]
		for key: String in Totals.actors(current):
			var old: Dictionary = Totals.actors(current)[key]
			var new: Dictionary = Totals.actors(next).get(key, {})
			var losses: Array = (step.get("target_losses", []) as Array).duplicate()
			losses.append_array(step.get("enemy_losses", []))
			expect.call(Base.hp_loss(losses, key) == maxi(0, int(old.get("hp", 0)) - int(new.get("hp", 0))), "%s: intermediate snapshot matches only its reaction loss for %s" % [case["name"], key])
		if str(case["name"]).ends_with("collateral"):
			expect.call(Base.hp_loss(step["enemy_losses"], "enemy_3") == COLLISION_LOSS and int(next["enemies"][1]["hp"]) == COLLATERAL_HP - COLLISION_LOSS, "Mimic reaction owns realized crawler collision damage")
		current = next

static func _test_cancelled_boundaries(_expect: Callable) -> void:
	# The compound cancellation adapters retired with Tether and Mirror.
	pass

static func run_playback(tree: SceneTree, scene: Control, expect: Callable, supplied_cases: Array[Dictionary] = []) -> void:
	var combat := Base.Combat.new()
	var playback_cases: Array[Dictionary] = cases()
	if not supplied_cases.is_empty(): playback_cases = supplied_cases
	for case: Dictionary in playback_cases:
		var state: Dictionary = case["state"].duplicate(true)
		var before: Dictionary = state.duplicate(true)
		Base.Fixtures.install(scene, state)
		scene.set("_animation_lock", true)
		scene.set("feedback_phase", "beam")
		(scene.get("_intent_callouts") as RefCounted).set("_announced", {})
		for _frame: int in range(SETTLE_FRAMES): await tree.process_frame
		(scene.get("popup_submissions") as Array).clear()
		(scene.get("defeat_submissions") as Array).clear()
		(scene.get("defeat_owners") as Array).clear()
		(scene.get("applied_steps") as Array).clear()
		var phase: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false)
		var completed: Dictionary = {"done": false}
		var pacing: Node = scene.get("_combat_pacing")
		pacing.call("begin_enemies")
		_play(scene, state, phase["steps"], completed)
		var started: int = Time.get_ticks_usec()
		while not completed["done"] and float(Time.get_ticks_usec() - started) / 1000000.0 < PLAYBACK_TIMEOUT_SECONDS: await tree.process_frame
		expect.call(completed["done"], "%s: reaction playback completes" % case["name"])
		Totals.check(expect, before, phase["state"], state, scene.get("popup_submissions"), str(case["name"]))
		var actor_popups: Array = (scene.get("popup_submissions") as Array).filter(func(value: Dictionary) -> bool: return value["entry"].get("reaction_actor_key", "") == "enemy_1" and value["entry"].get("kind", "") == "damage")
		expect.call(actor_popups.all(func(value: Dictionary) -> bool: return value["phase"] in ["move", "retaliate", "illusion_retort"]), "%s: actor loss plays only on its owning move/reaction" % case["name"])
		var defeats: int = (scene.get("defeat_submissions") as Array).count("enemy_1")
		expect.call(defeats == (1 if int(phase["state"]["enemies"][0]["hp"]) <= 0 else 0), "%s: attacker death is presented exactly once" % case["name"])
		if str(case["name"]).ends_with("collateral"):
			var crawler: Array = (scene.get("popup_submissions") as Array).filter(func(value: Dictionary) -> bool: return value["entry"].get("reaction_actor_key", "") == "enemy_3" and value["entry"].get("kind", "") == "damage")
			expect.call(crawler.size() == 1 and crawler[0]["phase"] == "retaliate" and crawler[0]["entry"]["text"] == "-2", "Mimic collateral crawler popup appears once on Retaliate")
		pacing.call("end_scope")

static func _play(scene: Control, state: Dictionary, steps: Array, completed: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps", state, steps)
	completed["done"] = true
