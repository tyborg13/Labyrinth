extends RefCounted

const RunEngineScript = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Rules = preload("res://scripts/graftwright_rules.gd")
const Store = preload("res://scripts/progression_store.gd")

static func fixture(seed_value: int = 91526) -> Dictionary:
	var engine := RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(seed_value, Store.default_data())
	state["equipment_inventory"] = ["undertaker_plate", "boiled_leather", "iron_cleaver"]
	state["collected_equipment"] = Data.starter_equipment_ids() + state["equipment_inventory"]
	var rooms: Dictionary = state["rooms"] as Dictionary
	var count: int = 0
	var found: bool = false
	for key: String in rooms:
		var room: Dictionary = rooms[key] as Dictionary
		if str(room.get("type", "")) == "combat" and count < 3:
			room["cleared"] = true
			count += 1
		if str(room.get("type", "")) == "graftwright" and not found:
			state["current_room"] = room["coord"]
			found = true
	state["mode"] = "graftwright"
	state["rooms"] = rooms
	return engine.repair_loaded_run_state(state)

static func run(check: Callable) -> void:
	var engine := RunEngineScript.new()
	var state: Dictionary = fixture()
	check.call(Rules.completed_combats(state) == 3, "Graft fixture has three completed combats")
	var before: Array = Data.equipment_cards("undertaker_plate")
	var grafted: Dictionary = engine.graft_equipment(state, "undertaker_plate", "patched_cloak", 1, 1)
	check.call(Data.equipment_cards("undertaker_plate", grafted) == ["undertaker_stand", "shadow_step"], "Selected source replaces exactly one target card")
	check.call(Data.equipment_cards("undertaker_plate") == before, "Graft never mutates global equipment data")
	check.call(not Rules.owned(grafted).has("patched_cloak"), "Whole donor is consumed")
	check.call(grafted["equipped_equipment"]["armor"] == "undertaker_plate", "Recipient takes the equipped donor's place")
	check.call(not grafted["equipment_inventory"].has("undertaker_plate"), "Automatically equipped recipient is removed from pack")
	check.call(grafted["deck_cards"].size() == state["deck_cards"].size(), "Equal-size equipment packages preserve deck size")
	check.call(grafted["deck_cards"].has("shadow_step") and not grafted["deck_cards"].has("grave_sprint"), "Active deck contains the effective inherited package")
	check.call(grafted["collected_equipment"].has("patched_cloak"), "Consumption retains drop-exclusion history")
	check.call(Data.equipment_cards("undertaker_plate", state) == before, "Preview source state is immutable")
	check.call(not Rules.room_error(grafted).is_empty(), "One graft is available per encounter")
	check.call((grafted["map_events"] as Array).back().get("type") == "equipment_grafted", "Graft emits an additive persisted analytics event")
	var again: Dictionary = engine.graft_equipment(grafted, "undertaker_plate", "boiled_leather", 0, 1)
	check.call(again["equipment_inventory"] == grafted["equipment_inventory"] and again["equipment_grafts"] == grafted["equipment_grafts"], "Repeated activation cannot consume or grant twice")
	var reload: Dictionary = engine.repair_loaded_run_state(grafted)
	check.call(reload["deck_cards"] == grafted["deck_cards"] and not Rules.owned(reload).has("patched_cloak"), "Reload repair retains graft and never resurrects a sacrificed starter")
	var encoded: Variant = bytes_to_var(var_to_bytes(grafted))
	check.call(engine.repair_loaded_run_state(encoded as Dictionary)["equipment_grafts"] == grafted["equipment_grafts"], "Grafts survive binary save serialization")
	var swapped: Dictionary = Rules.leave(grafted)
	swapped = engine.equip_equipment(swapped, "boiled_leather")
	swapped = engine.equip_equipment(swapped, "undertaker_plate")
	check.call(swapped["deck_cards"] == grafted["deck_cards"], "Unequipping and re-equipping retains inherited card")
	for request: Array in [["undertaker_plate", "undertaker_plate", 0, 1], ["undertaker_plate", "iron_cleaver", 0, 1], ["undertaker_plate", "rimeplate_harness", 0, 1], ["undertaker_plate", "patched_cloak", -1, 1], ["undertaker_plate", "patched_cloak", 9, 1], ["undertaker_plate", "patched_cloak", 1, 9]]:
		var invalid: Dictionary = engine.graft_equipment(state, request[0], request[1], request[2], request[3])
		check.call(invalid["equipment_inventory"] == state["equipment_inventory"] and not invalid.has("equipment_grafts"), "Invalid graft is atomic: " + str(request))
	var early: Dictionary = state.duplicate(true)
	for room: Dictionary in (early["rooms"] as Dictionary).values():
		if str(room.get("type", "")) == "combat": room["cleared"] = false
	check.call(not Rules.error(early, "undertaker_plate", "patched_cloak", 1, 1).is_empty(), "Runtime rejects grafts before three completed combats")
	# Guardians replace standard fights on section routes and must satisfy the
	# same three-combat gate used when placing the Graftwright encounter.
	var guardian_route: Dictionary = state.duplicate(true)
	var replaced_combat: Dictionary = {}
	for room: Dictionary in (guardian_route["rooms"] as Dictionary).values():
		if str(room.get("type", "")) == "combat" and bool(room.get("cleared", false)):
			room["type"] = "guardian"
			replaced_combat = room
			break
	var after_guardian: Dictionary = engine.graft_equipment(guardian_route, "undertaker_plate", "patched_cloak", 1, 1)
	check.call(not Rules.owned(after_guardian).has("patched_cloak"), "Two standard combats and a defeated Guardian unlock the encountered Graftwright")
	replaced_combat["cleared"] = false
	var before_guardian: Dictionary = engine.graft_equipment(guardian_route, "undertaker_plate", "patched_cloak", 1, 1)
	check.call(Rules.owned(before_guardian).has("patched_cloak") and not before_guardian.has("equipment_grafts"), "An undefeated Guardian does not grant early graft access")
	var closed: Dictionary = Rules.leave(state)
	check.call(closed["mode"] == "room" and Rules.owned(closed) == Rules.owned(state), "Leaving without grafting consumes nothing")
	var later: Dictionary = grafted.duplicate(true)
	Graph.room(later, later["current_room"])["graft_used"] = false
	check.call(not Rules.error(later, "undertaker_plate", "boiled_leather", 0, 0).is_empty(), "A second inheritance must replace the existing inherited slot")
	var carried: Dictionary = engine.graft_equipment(later, "boiled_leather", "undertaker_plate", 1, 0)
	check.call(Data.equipment_cards("boiled_leather", carried)[0] == "shadow_step", "An inherited card can be carried to future gear")
	check.call(carried["equipment_grafts"]["boiled_leather"]["source"] == "patched_cloak", "Carried inheritance keeps its original provenance")
	check.call(not carried["equipment_grafts"].has("undertaker_plate"), "Consumed customized item loses its mutation record")
	var no_op: Dictionary = later.duplicate(true)
	no_op["equipment_grafts"]["boiled_leather"] = {"index": 0, "card_id": "shadow_step", "source": "patched_cloak"}
	check.call(not Rules.error(no_op, "undertaker_plate", "boiled_leather", 0, 1).is_empty(), "Identical-card transfer cannot waste equipment")
	var wild: Dictionary = state.duplicate(true)
	wild["equipped_equipment"]["trinket"] = "undertaker_plate"
	wild["equipment_inventory"].erase("undertaker_plate")
	var wild_grafted: Dictionary = engine.graft_equipment(wild, "undertaker_plate", "patched_cloak", 1, 1)
	check.call(wild_grafted["equipped_equipment"]["armor"] == "undertaker_plate" and wild_grafted["equipped_equipment"]["trinket"] == "", "Open Arsenal keeps the survivor in its native slot and empties the extra slot")
	check.call(not Rules.owned(engine.repair_loaded_run_state(wild_grafted)).has("patched_cloak"), "Repair never resurrects an equipped sacrifice")
	_test_integration(check, state, grafted)
	_test_map(check)

static func _test_integration(check: Callable, state: Dictionary, grafted: Dictionary) -> void:
	var engine := RunEngineScript.new()
	var destination: Vector2i = state["current_room"]
	var approach: Dictionary = state.duplicate(true)
	for room: Dictionary in (approach["rooms"] as Dictionary).values():
		for edge: Dictionary in room.get("connections", []):
			if edge["coord"] == destination:
				approach["current_room"] = room["coord"]
				room["cleared"] = true
	approach["mode"] = "room"
	var entered: Dictionary = engine.move_to_room(approach, destination)
	check.call(entered["mode"] == "graftwright" and entered["combat_state"].is_empty(), "Normal adjacent map travel opens the non-combat encounter")
	check.call(entered["current_room_layout"]["enemies"].is_empty(), "Graftwright never spawns combat enemies")
	var onward: Dictionary = engine.leave_graftwright(grafted)
	for step: int in range(8):
		if onward["mode"] == "combat": break
		match str(onward["mode"]):
			"graftwright": onward = engine.leave_graftwright(onward)
			"campfire": onward = engine.leave_campfire(onward)
			"event": onward = engine.resolve_map_event(onward, "embers")
			"treasure": onward = engine.claim_relic(onward, "")
			"pre_battle": onward = engine.begin_pre_battle_combat(onward)
		var moves: Array[Vector2i] = engine.available_moves(onward)
		if not moves.is_empty(): onward = engine.move_to_room(onward, moves[0])
	check.call(onward["mode"] == "combat", "Leaving Graftwright permits onward travel to combat")
	var deck: Dictionary = (onward.get("combat_state", {}) as Dictionary).get("deck", {}) as Dictionary
	var cards: Array = []
	for zone: String in ["draw", "hand", "discard", "burned"]: cards.append_array(deck.get(zone, []) as Array)
	var expected: Array = (grafted["deck_cards"] as Array).duplicate()
	cards.sort(); expected.sort()
	check.call(cards == expected, "Next live combat compiles the inherited deck without restoring replaced cards")
	var sale: Dictionary = engine.equip_equipment(engine.leave_graftwright(grafted), "boiled_leather")
	for room: Dictionary in (sale["rooms"] as Dictionary).values():
		if str(room.get("type", "")) == "scavenger":
			sale["current_room"] = room["coord"]
			break
	check.call(engine.merchant_sellable_ids(sale, "scavenger").has("undertaker_plate"), "Customized gear remains sellable from the pack")
	sale = engine.sell_merchant_item(sale, "scavenger", "undertaker_plate")
	check.call(not Rules.owned(sale).has("undertaker_plate") and not sale["equipment_grafts"].has("undertaker_plate"), "Selling removes the owned item and its run-only graft")
	check.call(Data.equipment_cards("undertaker_plate", sale) == Data.equipment_cards("undertaker_plate"), "A later copy starts with authored cards")
	check.call(grafted["progression"] == state["progression"], "Grafting changes no metaprogression")
	var new_run: Dictionary = engine.create_new_run(2, grafted["progression"])
	check.call(not new_run.has("equipment_grafts") and Data.equipment_cards("patched_cloak", new_run) == Data.equipment_cards("patched_cloak"), "A new run starts with authored equipment")

static func _test_map(check: Callable) -> void:
	var found: int = 0
	for seed_value: int in range(1, 65):
		var state: Dictionary = {"seed": seed_value}
		Graph.initialize(state)
		var rooms: Dictionary = state["rooms"] as Dictionary
		# Propagate the least possible count down every edge, including section
		# gates. A depth-only gate would fail with shuffled service ordering.
		var pending: Array = [{"coord": Vector2i.ZERO, "fights": 0}]
		var seen: Dictionary = {}
		while not pending.is_empty():
			var item: Dictionary = pending.pop_front()
			var coord: Vector2i = item["coord"]
			var fights: int = int(item["fights"])
			var key: String = Graph.key(coord)
			if seen.has(key) and int(seen[key]) <= fights: continue
			seen[key] = fights
			var room: Dictionary = rooms[key] as Dictionary
			var type: String = str(room.get("type", ""))
			if type == "graftwright":
				found += 1
				check.call(fights >= 3, "Every incoming route to a Graftwright has completed three combats")
			if type in ["combat", "guardian", "boss"]: fights += 1
			for edge: Dictionary in room.get("connections", []): pending.append({"coord": edge["coord"], "fights": fights})
	check.call(found > 20, "Graftwright appears across deterministic map seeds")
