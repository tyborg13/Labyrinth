extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Mimic = preload("res://tests/suites/fix_12_mimic_suite.gd")
const Totals = preload("res://tests/helpers/fix_12_popup_totals.gd")
# Reviewer geometry and additional test-only fixtures; no content tuning.
const HERO_HP: int = 7
const TICK_HP: int = 1
const HERO := Vector2i(3, 3)
const THRALL := Vector2i(2, 3)
const TICK_TILES: Array = [Vector2i(1, 3), Vector2i(2, 4)]
const BEAM_TICK := Vector2i(4, 3)
const BEAM_HERO := Vector2i(3, 2)
const RETALIATE_AMOUNT: int = 2
const RETALIATE_PUSH: int = 1
const SURFACE_REWARD_DAMAGE: int = 4
const LEGACY_WARDEN := Vector2i(4, 4)
const LEGACY_HERO := Vector2i(3, 4)
const LEGACY_TICK := Vector2i(4, 3)
const LEGACY_TRAP_DAMAGE: int = 1
const SETTLE_FRAMES: int = 8
const PLAYBACK_TIMEOUT_SECONDS: float = 20.0 # Full-state boundary recording; same debug cap as the owner matrix.
const CAPTURE_CASES: Dictionary = {
	"mimic_arrival_burst": "arrival_cascade", "mimic_bleed_8": "bleed",
	"defiance_mimic_action": "defiance_mimic_action",
}

static func _tick(state: Dictionary, tile: Vector2i) -> void:
	var enemy: Dictionary = Base.Fixtures.enemy("ember_tick", state["enemies"].size() + 1, tile)
	enemy["hp"] = TICK_HP
	state["enemies"].append(enemy)

static func cases() -> Array[Dictionary]:
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
			var cascades: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return step.has("cascade"))
			var bursts: Array = cascades.filter(func(step: Dictionary) -> bool: return step["action_type"] == "death_burst")
			expect.call(not bursts.is_empty(), "%s: deferred cascade steps exist" % case["name"])
			var action: Dictionary = Mimic.action(phase)
			var current: Dictionary = action.get("en03_after", action.get("en06_after", {}))
			for step: Dictionary in phase["steps"]:
				if not step.has("reaction_after"): continue
				var after: Dictionary = step["reaction_after"]
				var losses: Array = (step.get("target_losses", []) as Array).duplicate(true)
				losses.append_array(step.get("enemy_losses", []))
				for key: String in Totals.actors(current):
					expect.call(Base.hp_loss(losses, key) == maxi(0, int(Totals.actors(current)[key].get("hp", 0)) - int(Totals.actors(after).get(key, {}).get("hp", 0))), "%s: each owning step matches its intermediate loss for %s" % [case["name"], key])
				current = after
			Totals.check_phase(expect, before, phase, str(case["name"]))
			var status_events: Array[Dictionary] = analytics._analytics_enemy_status_tick_events(phase, {})
			for step: Dictionary in bursts:
				expect.call(step["tile"] == step["cascade"]["tile"] and step["cascade"]["tiles"].size() == 8, "Cascade retains its burst source tile and existing effect geometry")
				expect.call(status_events.any(func(event: Dictionary) -> bool: return event["payload"].get("cascade", {}) == step["cascade"] and event["payload"]["target_losses"] == step["target_losses"] and event["payload"]["enemy_losses"] == step["enemy_losses"]), "Cascade analytics owns realized losses without transient snapshots")
			expect.call(before == original and combat._surface_death_trace.is_empty(), "Capture leaves caller state and engine trace scope intact")
	analytics.free()
	preload("res://tests/suites/fix_14_feedback_suite.gd").run(expect)
	preload("res://tests/suites/fix_14_bleed_suite.gd").run(expect)

static func run_playback(tree: SceneTree, scene: Control, expect: Callable, capture: Callable = Callable(), legacy_only: bool = false, supplied_cases: Array[Dictionary] = []) -> void:
	var combat := Base.Combat.new()
	var playback_cases: Array[Dictionary] = cases()
	playback_cases.append_array(preload("res://tests/suites/fix_14_feedback_suite.gd").cases())
	playback_cases.append_array(preload("res://tests/suites/fix_14_bleed_suite.gd").cases())
	if capture.is_valid():
		playback_cases.append_array(preload("res://tests/suites/fix_15_defiance_cases.gd").cases().filter(func(case: Dictionary) -> bool: return CAPTURE_CASES.has(case["name"])))
	if not supplied_cases.is_empty(): playback_cases = supplied_cases
	if legacy_only:
		playback_cases.clear()
		playback_cases.append({"name": "ordinary", "state": legacy_state()})
		playback_cases.append({"name": "retaliate", "state": legacy_state(true)})
	for case: Dictionary in playback_cases:
		if capture.is_valid() and not CAPTURE_CASES.has(case["name"]): continue
		var state: Dictionary = case["state"].duplicate(true)
		scene.set("proof_state", state)
		var before: Dictionary = state.duplicate(true)
		Base.Fixtures.install(scene, state)
		scene.set("_animation_lock", true)
		scene.set("feedback_phase", "beam")
		(scene.get("_intent_callouts") as RefCounted).set("_announced", {})
		for _frame: int in range(SETTLE_FRAMES): await tree.process_frame
		for field: String in ["popup_submissions", "defeat_submissions", "defeat_owners", "applied_steps", "burst_sources", "burst_cue_starts", "move_starts", "illusion_fades", "state_submissions"]: (scene.get(field) as Array).clear()
		var phase: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false)
		var completed: Dictionary = {"done": false}
		var pacing: Node = scene.get("_combat_pacing")
		pacing.call("begin_enemies")
		_play(scene, state, phase["steps"], completed)
		var started: int = Time.get_ticks_usec()
		var captured: Dictionary = {}
		var timeout_seconds: float = preload("res://tests/suites/fix_14_owner_matrix.gd").PLAYBACK_TIMEOUT_SECONDS if bool(case.get("matrix", false)) else PLAYBACK_TIMEOUT_SECONDS
		while not completed["done"] and float(Time.get_ticks_usec() - started) / 1000000.0 < timeout_seconds:
			if capture.is_valid(): await capture.call(scene, true, captured, CAPTURE_CASES[case["name"]])
			await tree.process_frame
		expect.call(completed["done"], "%s: cascade playback completes" % case["name"])
		if legacy_only:
			preload("res://tests/helpers/fix_14_legacy_compatibility.gd").playback(expect, state, scene, str(case["name"]))
			print("FIX-14 ORDINARY PLAYBACK: hero HP %d->%d; popups=%s; burst effect sources=%s; defeats=%s; enemy HP shown=%s resolved=%s" % [before["player"]["hp"], state["player"]["hp"], scene.get("popup_submissions"), scene.get("burst_sources"), scene.get("defeat_owners"), state["enemies"].map(func(enemy: Dictionary) -> int: return int(enemy["hp"])), phase["state"]["enemies"].map(func(enemy: Dictionary) -> int: return int(enemy["hp"]))])
			# Diagnostic only: the brief excludes ordinary mechanics' legacy
			# payloads. Report this baseline gap without blessing it as correct.
			pacing.call("end_scope")
			continue
		Totals.check(expect, before, phase["state"], state, scene.get("popup_submissions"), str(case["name"]), Totals.lifetimes(before, phase))
		for enemy: Dictionary in before["enemies"]:
			var key: String = "enemy_%d" % int(enemy["id"])
			var died: bool = int(enemy["hp"]) > 0 and int(Totals.actors(phase["state"])[key]["hp"]) <= 0
			expect.call((scene.get("defeat_submissions") as Array).count(key) == (1 if died else 0), "%s: %s defeat shown once on its owning step" % [case["name"], key])
		if bool(case.get("matrix", false)):
			preload("res://tests/suites/fix_14_owner_matrix.gd").check_playback(expect, before, phase, scene, case)
			preload("res://tests/helpers/fix_15_state_invariant.gd").check_playback(expect, before, phase, state, scene, case)
		else:
			preload("res://tests/suites/fix_14_feedback_suite.gd").check_playback(expect, before, phase, scene, str(case["name"]))
			preload("res://tests/suites/fix_14_bleed_suite.gd").check_playback(expect, before, phase, scene, str(case["name"]))
		var expected_losses: Dictionary = {}
		for step: Dictionary in phase["steps"]:
			if not step.has("cascade"): continue
			var victims: Array = (step["target_losses"] as Array).duplicate()
			victims.append_array(step["enemy_losses"])
			for loss: Dictionary in victims:
				var key: String = "%s/%s/%s" % [step["action_type"], step["cascade"]["id"], loss["key"]]
				expected_losses[key] = int(expected_losses.get(key, 0)) + int(loss["hp_loss"])
		for key: String in expected_losses:
			var total: int = 0
			for popup: Dictionary in scene.get("popup_submissions"):
				var popup_key: String = "%s/%s/%s" % [popup["phase"], popup.get("source_id", -1), popup["entry"].get("reaction_actor_key", "")]
				if popup_key == key and popup["entry"].get("kind", "") == "damage": total += str(popup["entry"]["text"]).trim_prefix("-").to_int()
			expect.call(total == expected_losses[key], "%s: popup victims belong to cascade %s" % [case["name"], key])
		if capture.is_valid(): expect.call(captured.has("revival" if str(case["name"]).begins_with("defiance_") else "attack" if case["name"] == "mimic_bleed_8" else "burst"), "Windowed probe captures a live owning popup: " + str(case["name"]))
		pacing.call("end_scope")

static func _play(scene: Control, state: Dictionary, steps: Array, completed: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps", state, steps)
	completed["done"] = true

static func legacy_state(retaliate: bool = false) -> Dictionary:
	var state: Dictionary = Base.Fixtures.state([Base.Fixtures.enemy("warden", 1, LEGACY_WARDEN, "crushing_step")], LEGACY_HERO)
	if retaliate: state["retaliate"] = {"amount": RETALIATE_AMOUNT}
	_tick(state, LEGACY_TICK)
	state["traps"] = [{"id": "fix_14_ordinary_fire", "pos": LEGACY_TICK, "element": "fire", "damage": LEGACY_TRAP_DAMAGE}]
	return state

static func legacy_check(expect: Callable) -> void:
	var combat := Base.Combat.new()
	var analytics := Base.RunScene.new()
	preload("res://tests/helpers/fix_14_legacy_compatibility.gd").nontraced_payloads(expect, combat, analytics)
	for mode: String in ["ordinary", "retaliate"]:
		preload("res://tests/helpers/fix_14_legacy_compatibility.gd").resolution(expect, combat.resolve_enemy_turn_with_steps(legacy_state(mode == "retaliate"), 0, false), analytics, mode)
	analytics.free()
	var before: Dictionary = legacy_state()
	var phase: Dictionary = combat.resolve_enemy_turn_with_steps(before, 0, false)
	var attack: Dictionary = {}
	for step: Dictionary in phase["steps"]:
		if step.get("kind", "") == "aoe": attack = step
	var real: int = int(before["player"]["hp"]) - int(phase["state"]["player"]["hp"])
	print("FIX-14 ORDINARY RESOLUTION: hero loss=%d attack payload=%d burst events=%d cascade steps=%d" % [real, Base.hp_loss(attack.get("target_losses", []), "player"), phase["state"].get("death_burst_events", []).size(), phase["steps"].filter(func(step: Dictionary) -> bool: return step.has("cascade")).size()])
	expect.call(real > 0 and phase["state"].get("death_burst_events", []).size() == 1 and not attack.has("cascade"), "Ordinary attack retains its legacy payload and one resolved burst")
