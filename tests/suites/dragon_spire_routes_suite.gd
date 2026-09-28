extends RefCounted

# Regression: production room/entry/held warning plus ordinary moves.
# The separate guard cases below deliberately alter blockers, not the main path.
const Combat = preload("res://scripts/combat_engine.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Rules = preload("res://scripts/dragon_combat_rules.gd")
const Committed = preload("res://scripts/guardian_combat_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const SEED: int = 20260928

static func run(expect: Callable) -> void:
	_test_entry_advance_keeps_held_spires(expect)
	_test_occupied_mark_still_denies_only_that_spire(expect)
	_test_structural_exit_and_connectivity_guards(expect)

static func _entry() -> Dictionary:
	var room: Dictionary = Rooms.new().generate_room(SEED, {
		"coord":Vector2i(8, 0), "depth":8, "type":"boss", "boss_id":"tharokh",
		"element":"earth", "connections":[]
	}, Vector2i.RIGHT)
	return Combat.new().create_combat(SEED, room, {
		"hp":24, "max_hp":24, "deck_cards":["quick_stab", "dull_bolt"],
		"relics":[], "hand_size":2, "cards_per_turn":2, "draw_per_turn":0
	})

static func _raise(state: Dictionary, expect: Callable) -> Dictionary:
	for action: Dictionary in state["enemies"][0]["intent"]["actions"]:
		if str(action.get("type", "")) == "raise_terrain": return action.duplicate(true)
	expect.call(false, "Actual opening contains Stonewake raise action")
	return {}

static func _structural_exits(state: Dictionary) -> int:
	var combat := Combat.new()
	var boss: Dictionary = state["enemies"][0]
	var blockers: Dictionary = combat._occupied_terrain_tiles(state)
	var count: int = 0
	for direction: Vector2i in Paths.DIRS_4:
		if combat._enemy_can_occupy_anchor(state, boss, boss["pos"] + direction, blockers): count += 1
	return count

static func _same_tiles(first: Array, second: Array) -> bool:
	if first.size() != second.size(): return false
	for tile: Variant in first:
		if not second.has(tile): return false
	return true

static func _test_entry_advance_keeps_held_spires(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _entry()
	var boss: Dictionary = state["enemies"][0]
	var held: Array = _raise(state, expect).get("declared_tiles", []).duplicate()
	print("SPIRE ROUTE ENTRY: player=", state["player"]["pos"], " boss=", boss["pos"], " held=", held)
	expect.call(boss["type"] == "tharokh" and boss["pos"] == Vector2i(4, 3) and boss["footprint"] == Vector2i(2, 2), "Regression retains the generated Tharokh body")
	expect.call(state["player"]["pos"] == Vector2i(1, 4), "Regression starts at the actual western entrance")
	for tile: Vector2i in [Vector2i(6,4), Vector2i(6,3), Vector2i(6,5), Vector2i(5,5)]:
		expect.call(combat._terrain_index_at_tile(state, tile) >= 0, "Generated crate remains at %s" % tile)
	expect.call(_structural_exits(state) == 2, "Generated crates leave north and west structural body exits")
	expect.call(held.size() == 4 and not held.has(Vector2i(3, 4)), "Entrance warning holds four marks away from the advance endpoint")
	for tile: Vector2i in [Vector2i(2, 4), Vector2i(3, 4)]:
		expect.call(combat.player_movement_targets(state).has(tile), "Ordinary advance is legal: %s" % tile)
		state = combat.apply_player_movement(state, tile)
		expect.call(state["player"]["pos"] == tile, "Ordinary advance reaches %s without teleporting" % tile)
	expect.call(combat.player_movement_remaining(state) == 0, "Approach spends the ordinary two-move allowance")
	expect.call(_same_tiles(held, _raise(state, expect).get("declared_tiles", [])), "Approach does not redeclare the held spire marks")
	var live_exits: int = 0
	var live_blockers: Dictionary = combat._enemy_path_blockers(state, state["enemies"][0], true, false)
	for direction: Vector2i in Paths.DIRS_4:
		if combat._enemy_can_occupy_anchor(state, state["enemies"][0], boss["pos"] + direction, live_blockers): live_exits += 1
	expect.call(live_exits == 1, "Player temporarily occupies the west exit that triggered the original defect")
	# Pass through the production queue; do not move the body, replace terrain,
	# inflate defense or reassign the intent to manufacture the resolution.
	for activation: int in range(3):
		if str(state["enemies"][0]["intent"]["id"]) != "stonewake": break
		state = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(state))["state"]
	expect.call(str(state["enemies"][0]["intent"]["id"]) == "worldspine_claw", "Real queue resolves Stonewake then declares Claw")
	print("SPIRE ROUTE RESOLVED: player=", state["player"]["pos"], " spires=", combat._dragon_spire_tiles(state), " clock=", state.get("initiative_clock", -1))
	expect.call(_same_tiles(combat._dragon_spire_tiles(state), held), "Advancing next to the body must not cancel any unoccupied held spire")
	expect.call(_structural_exits(state) >= 2, "Resolved field retains two whole-body structural exits")

static func _test_occupied_mark_still_denies_only_that_spire(expect: Callable) -> void:
	var combat := Combat.new()
	for occupant: String in ["player", "illusion"]:
		var state: Dictionary = _entry()
		var action: Dictionary = _raise(state, expect)
		var held: Array = action.get("declared_tiles", []).duplicate()
		if held.is_empty():
			expect.call(false, "Occupied-mark fixture has declared spires")
			continue
		var denied: Vector2i = held[0]
		if occupant == "player": state["player"]["pos"] = denied
		else: state["illusions"] = [{"id":990, "pos":denied, "hp":1, "max_hp":1}]
		state = combat._enemy_raise_dragon_spires(state, 0, action)
		var expected: Array = held.duplicate()
		expected.erase(denied)
		expect.call(combat._terrain_index_at_tile(state, denied) < 0, "%s on a held mark still prevents occupied-tile placement" % occupant)
		expect.call(_same_tiles(combat._dragon_spire_tiles(state), expected), "Only the occupied %s mark is denied" % occupant)

static func _test_structural_exit_and_connectivity_guards(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _entry()
	var boss: Dictionary = state["enemies"][0]
	var west_exit := Vector2i(3, 3)
	expect.call(Committed.preserves_routes(combat, state, west_exit), "West blocker preserves single-cell floor connectivity")
	expect.call(not Rules.spire_preserves_routes(combat, state, boss, west_exit), "A true second structural exit loss is still rejected for the entire 2x2 footprint")
	# Single-cell bottleneck far from the body: body exits alone are insufficient.
	state["terrain"] = []
	for y: int in range(1, 8):
		for x: int in range(1, 8): state["grid"][y][x] = "stone"
	for y: int in range(1, 8):
		if y != 4: state["grid"][y][2] = "wall"
	expect.call(_structural_exits(state) >= 2, "Connectivity guard fixture leaves multiple body exits")
	expect.call(not Rules.spire_preserves_routes(combat, state, boss, Vector2i(2,4)), "Spire cannot sever the floor component even with multiple body exits")
