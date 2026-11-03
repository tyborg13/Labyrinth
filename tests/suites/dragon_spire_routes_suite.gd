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

static func _structural_exits(state: Dictionary) -> int:
	var combat := Combat.new()
	var boss: Dictionary = state["enemies"][0]
	var blockers: Dictionary = combat._occupied_terrain_tiles(state)
	var count: int = 0
	for direction: Vector2i in Paths.DIRS_4:
		if combat._enemy_can_occupy_anchor(state, boss, boss["pos"] + direction, blockers): count += 1
	return count

static func _test_structural_exit_and_connectivity_guards(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = _entry()
	var boss: Dictionary = state["enemies"][0]
	# Explicit structural fixture: north/east closed, west/south still open.
	# Lieutenant occupancy legitimately changes production terrain candidates.
	for y: int in range(1, 8):
		for x: int in range(1, 8): state["grid"][y][x] = "stone"
	state["terrain"] = [{"kind":"crag_outcrop", "pos":Vector2i(6,3), "hp":4}, {"kind":"crag_outcrop", "pos":Vector2i(4,2), "hp":4}]
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
