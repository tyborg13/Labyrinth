extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Callouts = preload("res://scripts/intent_callouts.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")
# Constructed-state defaults, used only by tests and the director's proof.
const FIXTURE_SEED: int = 126065
const GRID_SIDE: int = 9
const HERO_TILE := Vector2i(4, 4)
const ENEMY_TILE := Vector2i(2, 4)
const FIXTURE_HP: int = 24
const FIXTURE_DAMAGE: int = 4
const FIXTURE_RANGED_RANGE: int = 6
const EXPECTED: Dictionary = {
	"out_of_range": "Out of range", "no_line_of_sight": "No line of sight",
	"no_target": "No target", "shocked": "Shocked", "frozen": "Frozen",
	"petrified": "Petrified", "immobilized": "Immobilized"
}

static func layout() -> Dictionary:
	var grid: Array
	for y: int in range(GRID_SIDE):
		var row: Array[String]
		for x: int in range(GRID_SIDE): row.append("wall" if x == 0 or y == 0 or x == GRID_SIDE - 1 or y == GRID_SIDE - 1 else "stone")
		grid.append(row)
	return {"name": "Enemy no-action proof", "coord": Vector2i(1, 0), "type": "combat", "depth": 2, "umbra_stage": "clear",
		"grid": grid, "player_start": HERO_TILE, "terrain": [], "traps": [], "loot": [], "enemies": []}

static func state_for(combat: RefCounted, reason: String) -> Dictionary:
	var state: Dictionary = combat.create_combat(FIXTURE_SEED, layout(), {"hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "deck_cards": ["brace"], "relics": [], "hand_size": 1})
	var actions: Array[Dictionary]
	actions.append({"type": "melee", "damage": FIXTURE_DAMAGE, "range": 1})
	var enemy: Dictionary = {"id": 1, "type": "crawler", "pos": ENEMY_TILE, "hp": FIXTURE_HP, "max_hp": FIXTURE_HP,
		"intent": {"id": "fb_01_test", "name": GameData.enemy_def("crawler")["intents"][0]["name"], "actions": actions}}
	if reason in ["frozen", "petrified", "immobilized"]:
		enemy["pos"] = HERO_TILE + Vector2i.LEFT
	match reason:
		"shocked", "immobilized", "move_then_out_of_range":
			actions.push_front({"type": "move_away" if reason == "immobilized" else "move_toward", "range": 1})
			if reason == "shocked": enemy["shock"] = 1
			if reason == "immobilized":
				enemy["immobilize"] = true
				actions[1] = {"type": "ranged", "damage": FIXTURE_DAMAGE, "range": FIXTURE_RANGED_RANGE}
			if reason == "move_then_out_of_range": enemy["pos"] = Vector2i(1, 4)
		"frozen": enemy["freeze"] = 1
		"petrified": enemy[Maneuver.PETRIFY_FIELD] = 1
		"no_line_of_sight":
			actions[0] = {"type": "ranged", "damage": FIXTURE_DAMAGE, "range": FIXTURE_RANGED_RANGE}
			state["grid"][4][3] = "wall"
		"no_target":
			# First attack destroys the announced decoy; the second has no target
			# it can attack, while the living hero keeps combat running.
			state["illusions"] = [{"id": 1, "pos": ENEMY_TILE + Vector2i.UP, "hp": FIXTURE_DAMAGE, "max_hp": FIXTURE_DAMAGE}]
			actions.append(actions[0].duplicate(true))
	var enemies: Array[Dictionary]
	enemies.append(enemy)
	state["enemies"] = enemies
	state["current_actor"] = {"kind": "player"}
	state["turn_queue"] = []
	return state

static func resolve(combat: RefCounted, state: Dictionary, commits: bool = false) -> Dictionary:
	return combat.resolve_enemy_turn_with_steps(state, 0, commits)

static func callout_steps(combat: RefCounted, initial: Dictionary, phase: Dictionary) -> Array[Dictionary]:
	return Callouts.new().decorate_steps(combat, initial, phase["steps"])

static func run(expect: Callable) -> void:
	var combat := Combat.new()
	var analytics := RunScene.new()
	for reason: String in EXPECTED:
		for commits: bool in [false, true]:
			var state: Dictionary = state_for(combat, reason)
			var before: Dictionary = state.duplicate(true)
			var phase: Dictionary = resolve(combat, state, commits)
			var reasons: Array[String]
			for step: Dictionary in phase["steps"]:
				if not str(step.get("no_action_reason", "")).is_empty(): reasons.append(step["no_action_reason"])
			expect.call(reasons.has(reason), "%s: resolver attaches its reason (commits=%s)" % [reason, commits])
			var decorated: Array[Dictionary] = callout_steps(combat, state, phase)
			var events: Array[Dictionary] = entries(decorated)
			expect.call(events.size() == 1 and events[0]["text"] == EXPECTED[reason], "%s: exactly one reason with exact text" % reason)
			if events.size() == 1:
				expect.call(events[0]["icon"] == Callouts.REASON_ICONS.get(reason, ""), "%s: glossary identity, or no status icon" % reason)
				if Callouts.REASON_ICONS.has(reason): expect.call(Icons.icon_texture(events[0]["icon"]) != null, "%s: existing approved icon loads" % reason)
			var telemetry: Array[Dictionary] = analytics._analytics_enemy_action_events(phase, {})
			expect.call(telemetry.any(func(event: Dictionary) -> bool: return event["payload"].get("no_action_reason") == reason and event["payload"]["target_losses"].is_empty()), "%s: additive enemy-action reason without fabricated losses" % reason)
			expect.call(state == before, "%s: resolving and decorating leave the caller's state unchanged" % reason)
			if reason == "shocked":
				expect.call(phase["state"]["enemies"][0]["pos"] != ENEMY_TILE, "Shock still allows the planned move")
				expect.call(_index(decorated, "move") < _index(decorated, "intent_callout"), "Shock reason follows movement")
			if reason == "immobilized":
				expect.call(_index(decorated, "intent_callout") < _index(decorated, "ranged") and _index(decorated, "ranged") >= 0, "Immobilized appears at start even when the attack resolves")
	var moving: Dictionary = state_for(combat, "move_then_out_of_range")
	var phase: Dictionary = resolve(combat, moving)
	var decorated: Array[Dictionary] = callout_steps(combat, moving, phase)
	expect.call(_index(decorated, "move") >= 0 and _index(decorated, "intent_callout") > _index(decorated, "move"), "Move-then-out-of-range reason follows the move")
	expect.call(entries(decorated)[0]["text"] == "Out of range", "Move-then-out-of-range text")
	var stationary: Dictionary = state_for(combat, "frozen")
	stationary["enemies"][0]["freeze"] = 0
	stationary["enemies"][0]["immobilize"] = true
	expect.call(entries(callout_steps(combat, stationary, resolve(combat, stationary))).is_empty(), "Immobilized stationary attack has no lost movement callout")
	var hidden: Dictionary = moving.duplicate(true)
	hidden["umbra"] = {"stage": "heart", "light_sources": []}
	for step: Dictionary in phase["steps"]: step["hidden_by_umbra"] = true
	expect.call(entries(callout_steps(combat, hidden, phase)).is_empty(), "Umbra-hidden reasons remain private")
	_test_legacy_groups(combat, expect)
	_test_immobilized_movement(combat, expect)
	_test_captions(combat, expect)
	_test_frames(expect)
	analytics.free()

static func _test_immobilized_movement(combat: RefCounted, expect: Callable) -> void:
	for kind: String in ["retreat", "dive"]:
		for commits: bool in [false, true]:
			var state: Dictionary
			var destination: Vector2i
			if kind == "retreat":
				# Reuse the existing screened captain fixture and its ranged intent.
				state = preload("res://tests/suites/warband_suite.gd").arena()
				state["enemies"][0]["intent"] = {"id": "hold", "name": "Hold", "time": 4, "actions": [{"type": "ranged", "damage": 3, "range": 6}]}
				destination = Vector2i(4, 1)
			else:
				state = preload("res://tests/suites/sta01_mechanics_suite.gd").state("gust_shrike", "dive")
				destination = combat.enemy_intent_plan(state, 0)["destination"]
			var origin: Vector2i = state["enemies"][0]["pos"]
			var free: Dictionary = resolve(combat, state, commits)
			expect.call(free["state"]["enemies"][0]["pos"] == destination and destination != origin, "%s regression really moves without Immobilize" % kind)
			state["enemies"][0]["immobilize"] = true
			var before: Dictionary = state.duplicate(true)
			var held: Dictionary = resolve(combat, state, commits)
			var steps: Array[Dictionary] = callout_steps(combat, state, held)
			expect.call(held["state"]["enemies"][0]["pos"] == origin, "%s regression stops with Immobilize" % kind)
			expect.call((held["steps"] as Array).any(func(step: Dictionary) -> bool: return step.get("no_action_reason", "") == "immobilized"), "%s blocked movement gets its resolver reason (commits=%s)" % [kind, commits])
			var callouts: Array[Dictionary] = entries(steps)
			expect.call(callouts.size() == 1 and callouts[0].get("text", "") == "Immobilized" and callouts[0].get("icon", "") == "immobilize", "%s blocked movement gets one Immobilized callout" % kind)
			expect.call(_index(steps, "intent_callout") >= 0 and _index(steps, "intent_callout") < _index(steps, "intent"), "%s movement restriction is shown at turn start" % kind)
			expect.call(state == before, "%s feedback leaves its input state unchanged" % kind)
			if kind == "retreat": expect.call(_index(steps, "ranged") >= 0, "Captain still attacks after its prevented retreat")
			if kind == "dive":
				# Shared Dive moves even under Shock; Shock loses only its AoE.
				# Immobilize still independently prevents that real movement.
				state["enemies"][0]["immobilize"] = false
				state["enemies"][0]["shock"] = 1
				var flying_shocked: Dictionary = resolve(combat, state, commits)
				expect.call(flying_shocked["state"]["enemies"][0]["pos"] == destination, "Shared Dive moves under Shock without Immobilize")
				state["enemies"][0]["immobilize"] = true
				var shocked: Dictionary = resolve(combat, state, commits)
				expect.call(shocked["state"]["enemies"][0]["pos"] == origin, "Shared Dive movement is prevented by Immobilize even under Shock")
				var reasons: Array[String]
				for step: Dictionary in shocked["steps"]:
					var reason: String = str(step.get("no_action_reason", ""))
					if not reason.is_empty(): reasons.append(reason)
				expect.call(reasons.count("immobilized") == 1 and reasons.count("shocked") == 1, "Shared Dive attributes its lost move to Immobilize and its lost attack to Shock exactly once")

static func _test_captions(combat: RefCounted, expect: Callable) -> void:
	for reason: String in EXPECTED:
		for commits: bool in [false, true]:
			var state: Dictionary = state_for(combat, reason)
			var phase: Dictionary = resolve(combat, state, commits)
			var raw: Array = (phase["steps"] as Array).duplicate(true)
			var decorated: Array[Dictionary] = callout_steps(combat, state, phase)
			var captions: Array[String]
			for step: Dictionary in decorated:
				if step.has("turn_caption"): captions.append(step["turn_caption"])
			if reason in ["frozen", "petrified", "shocked"]:
				expect.call(not captions.is_empty() and captions.all(func(text: String) -> bool: return text == "Tunnel Crawler: %s" % EXPECTED[reason]), "%s: status decides the caption before playback (commits=%s)" % [reason, commits])
			else:
				expect.call(captions.is_empty(), "%s: retain the existing intent caption" % reason)
			expect.call(phase["steps"] == raw, "%s: caption decoration preserves the resolver stream" % reason)
	# A Shock tick still governs the caption when the plan has no attack to lose.
	var moving: Dictionary = state_for(combat, "shocked")
	var actions: Array[Dictionary]
	actions.append(moving["enemies"][0]["intent"]["actions"][0])
	moving["enemies"][0]["intent"]["actions"] = actions
	var moving_phase: Dictionary = resolve(combat, moving)
	var moving_steps: Array[Dictionary] = callout_steps(combat, moving, moving_phase)
	expect.call(entries(moving_steps).is_empty() and moving_phase["state"]["enemies"][0]["pos"] != ENEMY_TILE, "Move-only Shock fixture moves without a lost-attack callout")
	expect.call(moving_steps.any(func(step: Dictionary) -> bool: return step.get("turn_caption", "") == "Tunnel Crawler: Shocked"), "Move-only Shock still names the turn caption")
	# A later reveal must not make a concealed start-of-turn status public.
	for reason: String in ["frozen", "petrified", "shocked"]:
		var state: Dictionary = state_for(combat, reason)
		var phase: Dictionary = resolve(combat, state)
		for step: Dictionary in phase["steps"]:
			if str(step.get("kind", "")) == "status": step["hidden_by_umbra"] = true
		var decorated: Array[Dictionary] = callout_steps(combat, state, phase)
		expect.call(not decorated.any(func(step: Dictionary) -> bool: return step.has("turn_caption")), "%s: a concealed status stays private after reveal" % reason)

static func _test_legacy_groups(combat: RefCounted, expect: Callable) -> void:
	var state: Dictionary = state_for(combat, "out_of_range")
	var other: Dictionary = state["enemies"][0].duplicate(true)
	other["id"] = 2
	other["pos"] = Vector2i(6, 4)
	state["enemies"].append(other)
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var decorated: Array[Dictionary] = callout_steps(combat, state, phase)
	var last_reason_actor: String = ""
	var actors: Array[String]
	for step: Dictionary in decorated:
		if step["kind"] == "intent" and step["actor_key"] == "enemy_2": expect.call(last_reason_actor == "enemy_1", "Legacy phase presents first reason before the second actor starts")
		if step["kind"] == "intent_callout":
			last_reason_actor = step["actor_key"]
			actors.append(last_reason_actor)
	expect.call(actors == ["enemy_1", "enemy_2"], "Legacy phase has one correctly grouped reason per actor")

static func _test_frames(expect: Callable) -> void:
	var entry: Dictionary = {"text": "Shocked", "no_action_reason": "shocked"}
	for elapsed: float in [0.0, 0.4, 0.799999, 0.8, 0.95, 1.1]:
		var normal: Dictionary = Callouts.frame(entry, elapsed, false)
		var reduced: Dictionary = Callouts.frame(entry, elapsed, true)
		expect.call(float(normal["alpha"]) == 1.0 if elapsed <= 0.8 else float(normal["alpha"]) < 1.0, "Opaque hold/fade boundary at %.6f real seconds" % elapsed)
		expect.call(reduced["motion_offset"] == Vector2.ZERO and reduced["alpha"] == normal["alpha"], "Reduced motion preserves hold/fade at %.6f" % elapsed)
	expect.call(is_zero_approx(float(Callouts.frame(entry, 1.1, false)["alpha"])), "Reason expires at 1.1 real seconds")

static func entries(steps: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for step: Dictionary in steps:
		if str(step.get("kind", "")) == "intent_callout": result.append(step)
	return result

static func _index(steps: Array, kind: String) -> int:
	for index: int in range(steps.size()):
		if str(steps[index].get("kind", "")) == kind: return index
	return -1
