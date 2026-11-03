extends RefCounted

const Facing = preload("res://scripts/hero_facing_state.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const BaseCombat = preload("res://scripts/combat_engine.gd")
const Playback = preload("res://tests/fixtures/hero_facing_run_scene.gd")
const Movement = preload("res://tests/suites/player_movement_suite.gd")
const Undo = preload("res://tests/suites/movement_undo_suite.gd")
const Grub = preload("res://tests/suites/en01_enemies_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const RIGHT: Dictionary = {"facing": "front", "mirrored": true}

static func run(tree: SceneTree, case_name: String) -> int:
	Undo.prepare_storage()
	tree.root.size = Vector2i(1920, 1080)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Playback)
	tree.root.add_child(scene)
	await Undo.settle(tree)
	var errors: Array[String]
	var check: Callable = func(ok: bool, message: String) -> void:
		if not ok: errors.append(message)
	match case_name:
		"undo": await _undo(tree, scene, check)
		"trap": await _trap(scene, check)
		"erupt": await _erupt(scene, check)
		_: check.call(false, "Unknown review case: " + case_name)
	scene.queue_free()
	await tree.process_frame
	for error: String in errors: push_error(error)
	print("HERO FACING REVIEW %s: %s (%d failures)" % [case_name, "PASS" if errors.is_empty() else "FAIL", errors.size()])
	return 0 if errors.is_empty() else 1

static func _shown(scene: Node) -> Dictionary:
	var value: Dictionary = scene.get("board_view").protagonist_animation_snapshot()
	return {"facing": value["facing"], "mirrored": value["mirrored"]}

static func _install(scene: Node, state: Dictionary, mode: String) -> Dictionary:
	scene.get("_settings")["hero_facing"] = mode
	return Undo.install(scene, state)

static func _undo(tree: SceneTree, scene: Node, check: Callable) -> void:
	for mode: String in ["persist", "snap"]:
		for initial: Dictionary in [Facing.FRONT, RIGHT, {"facing": "rear", "mirrored": false}, {"facing": "rear", "mirrored": true}]:
			if mode == "snap" and initial != Facing.FRONT: continue
			var state: Dictionary = Movement._state(Combat.new())
			state[Facing.KEY] = initial.duplicate()
			state = _install(scene, state, mode)
			await Undo.settle_hand_layout(tree, scene)
			check.call(state["player"]["pos"] == Vector2i(2, 4), "Undo fixture starts at (2,4)")
			await Undo.walk(scene, Vector2i(3, 4))
			await Undo.settle_hand_layout(tree, scene)
			var button: Button = scene.get("_movement_undo_button")
			check.call(button.visible and button.undo_available(), "%s offers Undo despite a facing change: %s" % [mode, initial])
			if not button.undo_available(): continue
			scene.proof_label = "undo_restore"
			scene.proof_frames.clear()
			await button.request_undo()
			check.call(scene.get("_combat_state") == state, "Undo restores every pre-move state field")
			check.call(scene.get("_run_state")["combat_state"][Facing.KEY] == initial, "Undo restores facing in run state")
			check.call(Store.load_saved_run()["combat_state"][Facing.KEY] == initial, "Undo persists pre-move facing")
			check.call(_shown(scene) == initial, "Undo immediately renders pre-move front/rear and mirror")
			check.call(scene.proof_frames.is_empty(), "Undo submits no turn-animation frames")
			scene.proof_label = ""

static func _trap_result(engine: RefCounted, before: Dictionary, direct: bool) -> Dictionary:
	if not direct: return engine.resolve_enemy_turn_with_steps(before, 0)
	# The normal planner prefers the eight-damage trap. Also exercise a shot
	# committed to the player: production board impact hits him then the trap.
	var context: Dictionary = {"action_index": 0, "attack_action_index": 0, "target_key": "player"}
	var action: Dictionary = before["enemies"][0]["intent"]["actions"][0]
	var bleed: Array[Dictionary]
	var after: Dictionary = engine._resolve_enemy_action(before.duplicate(true), 0, action, null, {}, bleed, context)
	var result: Dictionary = {"state": after, "steps": [engine._enemy_action_step(before, after, 0, action, context)]}
	if engine is Combat and engine.persist_hero_facing: Facing.enemy_result(before, result)
	return result

static func _trap(scene: Node, check: Callable) -> void:
	for mode: String in ["persist", "snap"]:
		for direct: bool in [false, true]:
			var before: Dictionary = Movement._state(Combat.new())
			before["player"]["pos"] = Vector2i(3, 3)
			before["enemies"][0]["pos"] = Vector2i(5, 3)
			before["enemies"][0]["intent"] = {"id": "review_shot", "name": "Shot", "time": 5, "actions": [{"type": "ranged", "range": 5, "damage": 1}]}
			before["traps"] = [{"pos": Vector2i(3, 3), "element": "fire", "damage": 8}]
			before[Facing.KEY] = Facing.FRONT.duplicate()
			before = _install(scene, before, mode)
			var result: Dictionary = _trap_result(scene.get("_combat_engine"), before, direct)
			check.call(int(before["player"]["hp"]) - int(result["state"]["player"]["hp"]) == (9 if direct else 8), "Production ranged fixture resolves direct plus trap, or trap only")
			check.call(result["state"]["traps"].is_empty(), "Ranged attack actually triggers the Fire trap")
			var expected: Dictionary = RIGHT if mode == "persist" and direct else Facing.FRONT
			check.call(result["state"][Facing.KEY] == expected, "Only a direct enemy hit changes saved facing")
			if mode == "persist":
				for step: Dictionary in result["steps"]:
					if step.get("kind", "") != "ranged": continue
					var hits: Array = step.get("direct_player_hits", [])
					check.call(hits.size() == (1 if direct else 0), "Ranged provenance excludes the trap's eight damage")
					if not hits.is_empty(): check.call(hits[0]["damage"] == 1 and hits[0]["source_tile"] == Vector2i(5, 3), "Direct provenance binds the one-damage shot to its attacker")
			if mode == "snap": check.call(result == _trap_result(BaseCombat.new(), before, direct), "Snap trap resolution matches the base resolver")
			await _animate(scene, before, result, expected, direct, check)

static func _erupt(scene: Node, check: Callable) -> void:
	for mode: String in ["persist", "snap"]:
		for pushed_only: bool in [false, true]:
			var engine: RefCounted = scene.get("_combat_engine")
			var before: Dictionary = BaseCombat.new().resolve_enemy_turn_with_steps(Grub.fixture(["burrow_grub", "crawler"]), 0)["state"]
			before["enemies"][0]["display_name"] = "Review Grub"
			if pushed_only:
				before["player"]["pos"] = Vector2i(5, 4)
			else:
				for tile: Vector2i in [Vector2i(5, 4), Vector2i(4, 5), Vector2i(3, 4), Vector2i(4, 3)]: before["grid"][tile.y][tile.x] = "wall"
				before["enemies"][1]["pos"] = Vector2i(6, 3)
			before[Facing.KEY] = Facing.FRONT.duplicate()
			before = _install(scene, before, mode)
			var result: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0)
			check.call(int(before["player"]["hp"]) - int(result["state"]["player"]["hp"]) == (0 if pushed_only else 6), "Erupt fixture resolves direct six damage or displacement only")
			if pushed_only: check.call(result["state"]["player"]["pos"] != before["player"]["pos"], "Displacement-only Erupt actually pushes the hero")
			else: check.call(result["state"]["enemies"][0]["pos"] == Vector2i(6, 4), "Surrounded mark surfaces at (6,4)")
			var expected: Dictionary = RIGHT if mode == "persist" and not pushed_only else Facing.FRONT
			check.call(result["state"][Facing.KEY] == expected, "Erupt faces the surfaced source; its push never turns")
			for step: Dictionary in result["steps"]:
				if step.get("kind", "") != "erupt": continue
				check.call(step.get("actor_name") == "Review Grub", "Erupt source metadata preserves the existing per-instance caption")
				var hits: Array = step.get("direct_player_hits", [])
				check.call(hits.size() == (0 if pushed_only else 1), "Production Erupt metadata separates the central hit from neighboring pushes")
				check.call(step.get("source_actor_key") == step["actor_key"] and step.get("source_tile") == result["state"]["enemies"][0]["pos"], "Erupt metadata identifies the surfaced actor and tile")
				if not hits.is_empty(): check.call(hits[0]["damage"] == 6 and hits[0]["source_tile"] == Vector2i(6, 4), "Surrounded Erupt records its direct six-damage source")
			if mode == "snap": check.call(result == BaseCombat.new().resolve_enemy_turn_with_steps(before, 0), "Snap Erupt resolution matches the base resolver")
			await _animate(scene, before, result, expected, not pushed_only, check)

static func _animate(scene: Node, before: Dictionary, result: Dictionary, expected: Dictionary, direct: bool, check: Callable) -> void:
	scene.get("_settings")["reduced_motion"] = false
	scene.proof_label = "review"
	scene.proof_observations.clear()
	await scene.call("_animate_enemy_phase_steps", before.duplicate(true), result["steps"])
	check.call(_shown(scene) == expected, "Displayed facing settles to saved facing")
	var impacted: bool = false
	for observation: Dictionary in scene.proof_observations:
		impacted = impacted or int(observation["hp"]) < int(before["player"]["hp"])
		var wanted: Dictionary = expected if impacted and direct else Facing.FRONT
		check.call({"facing": observation["facing"], "mirrored": observation["mirrored"]} == wanted, "Facing changes exactly at direct impact, never on flight, trap or push")
	if direct: check.call(impacted, "Direct-hit animation submits the actual HP-loss boundary")
	scene.proof_label = ""
