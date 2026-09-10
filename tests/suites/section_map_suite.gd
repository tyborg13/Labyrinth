extends RefCounted
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")

static func run(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var signatures: Dictionary = {}
	for seed: int in range(1, 33):
		var state: Dictionary = engine.create_new_run(seed, Progression.default_data())
		expect.call(Graph.enabled(state), "New runs use the saved section graph")
		expect.call(state == engine.create_new_run(seed, Progression.default_data()), "Graph, discoveries and boss order are deterministic")
		signatures[hash(state.get("rooms"))] = true
		for index: int in range(6):
			var info: Dictionary = Graph.section(state, index)
			var node_count: int = 0
			var landmarks: int = 0
			for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
				if int(node.get("section_index", -1)) != index: continue
				node_count += 1
				landmarks += 1 if bool(node.get("map_landmark", false)) else 0
				var coord: Vector2i = node.get("coord", Vector2i.ZERO)
				expect.call(maxi(absi(coord.x), absi(coord.y)) == int(node.get("depth", -1)), "Persistent ids preserve existing encounter depth")
				var directions: Dictionary = {}
				for link: Dictionary in node.get("connections", []):
					var target: Vector2i = link.get("coord", Graph.INVALID)
					var target_node: Dictionary = Graph.room(state, target)
					expect.call(not target_node.is_empty(), "Every route endpoint exists in the stored graph")
					var dir: Vector2i = link.get("door_dir", Vector2i.ZERO)
					expect.call(not directions.has(dir), "Each adjacent route owns a distinct physical door")
					directions[dir] = true
					for outgoing: Dictionary in target_node.get("connections", []):
						expect.call(outgoing.get("door_dir", Vector2i.ZERO) != -dir, "An onward route never occupies the incoming threshold")
					if int(target_node.get("section_index", -1)) == index:
						expect.call(int(target_node.get("map_step", -1)) == int(node.get("map_step", 0)) + 1, "Every route advances exactly one room, without shortcuts or loops")
			expect.call(node_count >= 20 and node_count <= 26, "A full section including its entry fits 20–26 independent nodes")
			expect.call(landmarks == 2, "Each section starts with exactly two landmarks")
			var outcomes: Array[Vector2i] = _path_outcomes(state, info.get("entry", Vector2i.ZERO), index, 0, 0)
			expect.call(outcomes.size() >= 8, "Each section has several consequential route combinations")
			for outcome: Vector2i in outcomes:
				expect.call(outcome.x == Graph.ROOM_COUNTS[index] and outcome.y == Graph.FIGHT_COUNTS[index], "Every route obeys the section visit and fight budget")
			expect.call(str(Graph.room(state, info.get("boss", Vector2i.ZERO)).get("boss_id", "")) == Bosses.boss_id_for_depth(seed, (index + 1) * 4), "Boss-specific map identity follows the seeded order")
		expect.call(str(Graph.section(state, 5).get("boss_id", "")) == "noctyrax", "Noctyrax remains the final section")
	expect.call(signatures.size() == 32, "Different seeds create different routes and service arrangements")
	_test_knowledge(engine, expect)
	_test_events(engine, expect)
	_test_persistence(engine, expect)
	_test_reach_exit(engine, expect)
	_test_generated_escape_transaction(engine, expect)
	_test_recovery_mapping(engine, expect)

static func _path_outcomes(state: Dictionary, coord: Vector2i, index: int, visits: int, fights: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var node: Dictionary = Graph.room(state, coord)
	if node.is_empty() or visits > 12: return result
	var type: String = str(node.get("type", ""))
	visits += 0 if type == "start" else 1
	fights += 1 if type in ["combat", "boss"] else 0
	if type == "boss":
		result.append(Vector2i(visits, fights))
		return result
	for link: Dictionary in node.get("connections", []):
		result.append_array(_path_outcomes(state, link.get("coord", Graph.INVALID), index, visits, fights))
	return result

static func _test_knowledge(engine: RunEngineScript, expect: Callable) -> void:
	var state: Dictionary = engine.create_new_run(81, Progression.default_data())
	var distances: Dictionary = Graph.descendants(state, Vector2i.ZERO)
	for coord: Vector2i in distances:
		var node: Dictionary = Graph.room(state, coord)
		var landmark: bool = bool(node.get("map_landmark", false)) or str(node.get("type", "")) == "boss"
		var hops: int = distances[coord]
		expect.call(bool(node.get("revealed", false)) == (hops <= 2 or landmark), "Identity knowledge stops at two transitions except landmarks")
		expect.call(bool(node.get("map_outline", false)) == (hops <= 3 or landmark), "Third transition gives only an outline; farther topology stays hidden")
	var branch: Vector2i = engine.available_moves(state)[0]
	var targets: Array[Vector2i] = Graph.scout_targets(state, branch)
	expect.call(not targets.is_empty(), "A fresh branch offers useful Scout coverage")
	var before_topology: Dictionary = _topology(state)
	var after: Dictionary = engine.scout_map(state, branch)
	expect.call(int(Graph.section(after, 0).get("scouts", 0)) == 1, "Scout spends exactly one use")
	for coord: Vector2i in targets: expect.call(bool(Graph.room(after, coord).get("revealed", false)), "Scout commits all previewed discoveries")
	expect.call(_topology(after) == before_topology, "Scouting never changes routes or room identities")
	expect.call(engine.scout_map(after, branch) == after, "An empty repeated Scout is a no-op")
	expect.call(engine.scout_map(after, Graph.section(after, 0).get("boss", Graph.INVALID)) == after, "A distant room cannot be used as a Scout origin")
	var combat_mode: Dictionary = after.duplicate(true)
	combat_mode["mode"] = "combat"
	expect.call(engine.move_to_room(combat_mode, branch) == combat_mode, "The map cannot bypass a live combat")
	var next_section: Dictionary = after.duplicate(true)
	next_section["current_room"] = Graph.section(after, 1).get("entry", Vector2i.ZERO)
	Graph.refresh_knowledge(next_section)
	expect.call(int(Graph.section(next_section, 1).get("scouts", 0)) == 2, "A new section has its own two uses")
	next_section["current_room"] = Vector2i.ZERO
	Graph.refresh_knowledge(next_section)
	expect.call(int(Graph.section(next_section, 0).get("scouts", 0)) == 1, "Revisiting a section never refills its Scout uses")

static func _topology(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		result[Graph.key(node.get("coord", Vector2i.ZERO))] = [node.get("type"), node.get("element"), node.get("connections")]
	return result

static func _test_events(engine: RunEngineScript, expect: Callable) -> void:
	var state: Dictionary = engine.create_new_run(82, Progression.default_data())
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(node.get("type", "")) != "event": continue
		state["current_room"] = node.get("coord", Vector2i.ZERO)
		state["mode"] = "event"
		break
	var before: int = int(state.get("held_embers", 0))
	var after: Dictionary = engine.resolve_map_event(state, "embers")
	expect.call(str(after.get("mode", "")) == "room" and int(after.get("held_embers", 0)) == before + 25, "The event grants its exact advertised Embers and releases room choice")
	expect.call(engine.resolve_map_event(after, "embers") == after, "Event rewards cannot be reclaimed")
	var survey: Dictionary = engine.resolve_map_event(state, "survey")
	expect.call(int(survey.get("held_embers", 0)) == before and str(survey.get("mode", "")) == "room", "The alternate event choice reveals routes without granting Embers")
	expect.call(_topology(survey) == _topology(state), "Events preserve revealed graph identities")

static func _test_persistence(engine: RunEngineScript, expect: Callable) -> void:
	var state: Dictionary = engine.create_new_run(83, Progression.default_data())
	state = engine.scout_map(state, engine.available_moves(state)[0])
	Progression.set_run_storage_path("user://section_map_suite.save")
	expect.call(Progression.save_run_state(state), "Section graph and knowledge save in the production format")
	var loaded: Dictionary = Progression.load_saved_run()
	expect.call(loaded == state, "All section state survives serialization")
	loaded = engine.repair_loaded_run_state(loaded)
	expect.call(_topology(loaded) == _topology(state) and loaded.get("map_sections") == state.get("map_sections"), "Load repair preserves graph, boss order and Scout budget")
	var legacy: Dictionary = engine.create_new_run(83, Progression.default_data(), false)
	expect.call(not Graph.enabled(engine.repair_loaded_run_state(legacy)), "Existing ring-map saves remain on their original topology")
	Progression.clear_saved_run()
	Progression.set_run_storage_path(Progression.DEFAULT_RUN_STORAGE_PATH)

static func _test_reach_exit(engine: RunEngineScript, expect: Callable) -> void:
	var state: Dictionary = engine.create_new_run(91, Progression.default_data())
	var checked: bool = false
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(node.get("type", "")) != "combat" or (node.get("connections", []) as Array).size() < 2: continue
		var objective: Dictionary = Objectives.build_for_room(91, node, Vector2i.RIGHT)
		# Compare authored candidate exits directly even when this seed's objective
		# roll is a different encounter; this proves every physical approach.
		var exits: Array = Objectives._eligible_exit_specs(node, Vector2i.RIGHT)
		expect.call(exits.size() == (node.get("connections", []) as Array).size(), "Every map branch has an eligible physical exit")
		checked = true
	expect.call(checked, "Reach-exit proof includes a branching combat")

static func _test_generated_escape_transaction(engine: RunEngineScript, expect: Callable) -> void:
	var state: Dictionary = engine.create_new_run(92, Progression.default_data())
	for opening: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(opening.get("type", "")) == "combat" and int(opening.get("map_step", 0)) == 1:
			opening["cleared"] = true
			opening["visited"] = true
	var found: bool = false
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if str(node.get("type", "")) != "combat" or int(node.get("map_step", 0)) <= 1: continue
		if str(Objectives.build_for_room(92, node, Vector2i.RIGHT).get("type", "")) != Objectives.REACH_EXIT: continue
		state["current_room"] = node.get("coord")
		node["visited"] = true
		Graph.refresh_knowledge(state)
		state["mode"] = "pre_battle"
		state["pre_battle_travel_dir"] = Vector2i.RIGHT
		state = engine.begin_pre_battle_combat(state)
		found = str(state.get("combat_state", {}).get("objective", {}).get("type", "")) == Objectives.REACH_EXIT
		if found: break
	expect.call(found, "Generated routes include a playable reach-exit encounter")
	if not found: return
	var combat: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	var exits: Array = (combat.get("objective", {}) as Dictionary).get("exits", [])
	expect.call(not exits.is_empty(), "Generated reach-exit encounter has physical destinations")
	if exits.is_empty(): return
	var exit: Dictionary = exits.back()
	var destination: Vector2i = exit.get("coord", Graph.INVALID)
	(combat.get("player", {}) as Dictionary)["pos"] = exit.get("target_tile", Vector2i.ZERO)
	state = engine.finish_combat(state, combat)
	expect.call(str(state.get("mode")) == "reward", "Crossing a generated door preserves the normal reward transaction")
	expect.call(engine.pending_escape(state).get("destination") == destination, "The physical door locks its matching map destination")
	state = engine.claim_card_reward(state, "")
	expect.call(str(state.get("mode")) == RunEngineScript.MODE_ESCAPE, "Reward completion cannot reopen map choice after crossing a door")
	state = engine.repair_loaded_run_state(state)
	state = engine.continue_pending_escape(state)
	expect.call(state.get("current_room") == destination and engine.pending_escape(state).is_empty(), "A resumed generated escape enters exactly the committed destination")

static func _test_recovery_mapping(engine: RunEngineScript, expect: Callable) -> void:
	var baseline: Dictionary = engine.create_new_run(51, Progression.default_data())
	var old_coord := Vector2i(2, 1)
	for node: Dictionary in (baseline.get("rooms", {}) as Dictionary).values():
		if str(node.get("type", "")) == "campfire":
			old_coord = node.get("coord")
			break
	var progression: Dictionary = Progression.prepare_for_new_run(Progression.default_data())
	progression = Progression.record_lost_embers(progression, 23, old_coord, int(progression.get("run_counter", 0)))
	progression = Progression.prepare_for_new_run(progression)
	var state: Dictionary = engine.create_new_run(51, progression)
	var target: Vector2i = state.get("map_recovery_coord", Graph.INVALID)
	expect.call(target != old_coord and not Graph.room(state, target).is_empty(), "Lost Embers map to an existing encounter rather than overwriting a service")
	expect.call(_topology(state) == _topology(baseline), "Ember recovery preserves every generated room identity and route")
	expect.call(Graph.descendants(state, Vector2i.ZERO, 100).has(target), "The recovery encounter remains reachable from the entrance")
	state["current_room"] = target
	state["mode"] = "pre_battle"
	state["pre_battle_travel_dir"] = Vector2i.RIGHT
	state = engine.begin_pre_battle_combat(state)
	var combat: Dictionary = state.get("combat_state", {})
	var drop: Dictionary = {}
	for item: Dictionary in combat.get("loot", []):
		if str(item.get("kind", "")) == "dropped_embers": drop = item
	expect.call(int(drop.get("amount", 0)) == 23, "The mapped encounter contains the exact recoverable Ember pile")
	if drop.is_empty(): return
	combat = Combat.new().apply_player_action(combat, {"type": "blink", "range": 99}, drop.get("pos", Vector2i.ZERO))
	state = engine.set_combat_state(state, combat)
	expect.call(engine.held_embers(state) == 23 and Progression.recovery_marker(state.get("progression", {})).is_empty(), "Picking up the mapped pile restores Embers exactly once")
