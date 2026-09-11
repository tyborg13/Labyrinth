extends RefCounted
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")

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
			_test_local_routes(state, index, node_count, expect)
			var outcomes: Array[Vector2i] = _path_outcomes(state, info.get("entry", Vector2i.ZERO), index, 0, 0)
			expect.call(outcomes.size() >= 6, "Each section has several consequential route combinations")
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

static func _test_local_routes(state: Dictionary, index: int, node_count: int, expect: Callable) -> void:
	var entry: Vector2i = Graph.section(state, index).get("entry")
	var boss: Vector2i = Graph.section(state, index).get("boss")
	var reachable: Dictionary = Graph.descendants(state, entry)
	expect.call(reachable.size() == node_count, "Every generated room can be reached from its section entry")
	var edges_by_step: Dictionary = {}
	var diagonal_count: int = 0
	for coord: Vector2i in reachable:
		var node: Dictionary = Graph.room(state, coord)
		if coord != boss:
			expect.call(not (node.get("connections", []) as Array).is_empty(), "Every non-boss room has a continuation")
		if coord != entry and coord != boss:
			expect.call(_can_finish_without(state, entry, coord), "Only the final boss is an unavoidable convergence")
		if str(node.get("type")) == "combat":
			expect.call(RoomIcons.icon_id_for_room(node) == "combat", "Modern door icons use the same standard-combat identity as the map")
		for link: Dictionary in node.get("connections", []):
			var target: Vector2i = link.get("coord")
			var destination: Dictionary = Graph.room(state, target)
			if coord == entry or target == boss or int(destination.get("section_index", -1)) != index: continue
			var edge := Vector2i(int(node.get("map_lane")), int(destination.get("map_lane")))
			expect.call(absi(edge.x - edge.y) <= 1, "Routes never jump between the top and bottom lanes")
			diagonal_count += 1 if edge.x != edge.y else 0
			var step: int = int(node.get("map_step"))
			for other: Vector2i in edges_by_step.get(step, []):
				expect.call((edge.x - other.x) * (edge.y - other.y) >= 0, "Branches do not cross each other between room columns")
			if not edges_by_step.has(step): edges_by_step[step] = []
			edges_by_step[step].append(edge)
	expect.call(diagonal_count >= 4, "Neighboring branches still split and rejoin instead of becoming straight tracks")

static func _can_finish_without(state: Dictionary, coord: Vector2i, excluded: Vector2i) -> bool:
	if coord == excluded: return false
	var node: Dictionary = Graph.room(state, coord)
	if str(node.get("type")) == "boss": return true
	for link: Dictionary in node.get("connections", []):
		if _can_finish_without(state, link.get("coord"), excluded): return true
	return false

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
	var options: Array[Vector2i] = Graph.scout_options(state)
	expect.call(not options.is_empty(), "The visible unknown horizon offers Scout targets")
	if options.is_empty(): return
	var target: Vector2i = options[0]
	var branch: Vector2i = engine.available_moves(state)[0]
	var before_topology: Dictionary = _topology(state)
	var before_revision: int = int(state.get("map_event_revision", 0))
	var after: Dictionary = engine.scout_map(state, target)
	expect.call(int(Graph.section(after, 0).get("scouts", 0)) == 1, "Scout spends exactly one use")
	expect.call(after.get("current_room") == state.get("current_room"), "Scouting an unknown room cannot travel")
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		var coord: Vector2i = node.get("coord")
		expect.call(bool(Graph.room(after, coord).get("revealed", false)) == (coord == target or bool(node.get("revealed", false))), "Scout reveals exactly the chosen identity")
	for link: Dictionary in Graph.room(state, target).get("connections", []):
		expect.call(bool(Graph.room(after, link.get("coord")).get("map_outline", false)), "Scout exposes its outgoing rooms as outlines")
	var event: Dictionary = (after.get("map_events", []) as Array).back()
	var payload: Dictionary = event.get("payload", {})
	expect.call(str(event.get("type")) == "map_scout_used" and str(payload.get("scope")) == "room" and payload.get("target") == target and payload.get("rooms", []) == [target], "Scout analytics name exactly the revealed room and distinguish room scope")
	expect.call(int(after.get("map_event_revision", 0)) == before_revision + 1, "A Scout appends one event without recording travel")
	expect.call(_topology(after) == before_topology, "Scouting never changes routes or room identities")
	expect.call(engine.scout_map(after, target) == after, "An already revealed Scout target is a no-op")
	expect.call(engine.scout_map(after, branch) == after, "An existing travel choice is not an unknown-room Scout target")
	expect.call(engine.scout_map(after, Graph.INVALID) == after, "Invalid Scout coordinates do not spend or emit")
	var hidden: Vector2i = Graph.INVALID
	for coord: Vector2i in distances:
		if not bool(Graph.room(state, coord).get("map_outline", false)):
			hidden = coord
			break
	expect.call(hidden != Graph.INVALID and engine.scout_map(state, hidden) == state, "Scouting cannot target undiscovered topology")
	var bypassed: Dictionary = state.duplicate(true)
	var opposite: Vector2i = engine.available_moves(state).back()
	bypassed["current_room"] = opposite
	Graph.refresh_knowledge(bypassed)
	expect.call(engine.scout_map(bypassed, target) == bypassed, "Unknown rooms on an abandoned branch cannot spend Scout")
	for mode: String in ["reward", "event", "campfire", "victory", "defeat"]:
		var blocked: Dictionary = state.duplicate(true)
		blocked["mode"] = mode
		expect.call(engine.scout_map(blocked, target) == blocked, "Scout respects the current " + mode + " transaction")
	for mode: String in ["room", "combat", "pre_battle"]:
		var permitted: Dictionary = state.duplicate(true)
		permitted["mode"] = mode
		expect.call(int(Graph.section(engine.scout_map(permitted, target), 0).get("scouts")) == 1, "Scout remains available during " + mode)
	var remaining: Array[Vector2i] = Graph.scout_options(after)
	expect.call(not remaining.is_empty(), "A second Scout can choose another visible unknown room")
	if not remaining.is_empty():
		var exhausted: Dictionary = engine.scout_map(after, remaining[0])
		expect.call(int(Graph.section(exhausted, 0).get("scouts")) == 0 and Graph.scout_options(exhausted).is_empty(), "Two room reveals exhaust the section budget")
		expect.call(engine.scout_map(exhausted, target) == exhausted, "Exhausted Scout is a no-op")
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
	state = engine.scout_map(state, Graph.scout_options(state)[0])
	Progression.set_run_storage_path("user://section_map_suite.save")
	expect.call(Progression.save_run_state(state), "Section graph and knowledge save in the production format")
	var loaded: Dictionary = Progression.load_saved_run()
	expect.call(loaded == state, "All section state survives serialization")
	loaded = engine.repair_loaded_run_state(loaded)
	expect.call(_topology(loaded) == _topology(state) and loaded.get("map_sections") == state.get("map_sections"), "Load repair preserves graph, boss order and Scout budget")
	var older_layout: Dictionary = loaded.duplicate(true)
	older_layout.erase("section_map_layout_revision")
	expect.call(_topology(engine.repair_loaded_run_state(older_layout)) == _topology(older_layout), "Previously saved section routes keep their topology without a layout revision")
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
