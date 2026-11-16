extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Boss = preload("res://tests/suites/dragon_boss_suite.gd")
const Scatter = preload("res://scripts/dragon_scatter_pattern.gd")
const Cycle = preload("res://scripts/dragon_combat_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
var failures: int = 0
var assertions: int = 0
func expect(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var engine := Combat.new()
	var state: Dictionary = Boss._boss_combat_state("zekarion")
	state["terrain"] = []
	state["traps"] = []
	state["enemies"].resize(1)
	var enemy: Dictionary = state["enemies"][0]
	for seed: int in range(128):
		state["fight_seed"] = seed
		state["player"]["pos"] = [Vector2i(2,1), Vector2i(1,4), Vector2i(6,1), Vector2i(7,6), Vector2i(2,2)][seed % 5]
		enemy["dragon_cycle"] = seed % 10
		var before: Dictionary = state.duplicate(true)
		var tiles: Array[Vector2i] = Scatter.tiles(engine, state, enemy, 9)
		expect(state == before, "Scatter cannot mutate state/RNG")
		expect(tiles == Scatter.tiles(engine, state, enemy, 9), "Deterministic scatter")
		expect(tiles.size() == 9 and tiles[0] == state["player"]["pos"], "Nine marks, hero first")
		for i: int in range(tiles.size()):
			expect(Surfaces.can_place(state, tiles[i]) and engine._enemy_index_at_tile(state, tiles[i]) < 0, "Legal floor")
			if i in [1, 2, 3, 4]: expect(Paths.manhattan(tiles[i], state["player"]["pos"]) in [2, 3], "Four near marks")
			for j: int in range(i): expect(Paths.manhattan(tiles[i], tiles[j]) >= 2, "Separated marks")
		var safe: int = 0
		for tile: Vector2i in Scatter._reachable(engine._all_passable_tiles(state), state["player"]["pos"]):
			if not tiles.has(tile): safe += 1
		expect(safe >= 3, "Three reachable unmarked answers")
	# Occupied floor and constricted routes are filtered without consuming RNG.
	state["terrain"] = [{"id":"test_wall", "pos":Vector2i(2,3), "hp":99}]
	var obstructed: Array[Vector2i] = Scatter.tiles(engine, state, enemy, 9)
	expect(not obstructed.has(Vector2i(2,3)), "Terrain is never marked")
	state = Boss._boss_combat_state("zekarion")
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	var order: Array = Data.enemy_def("zekarion")["cycle_order"]
	for slot: int in range(10):
		if slot > 0: engine._assign_enemy_intent(state, 0, rng)
		expect(state["enemies"][0]["intent"]["id"] == order[slot % 5], "Authored five-slot cycle")
	state = Boss._boss_combat_state("zekarion")
	state.erase("battlefield_rule")
	var marks: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"].duplicate()
	state["player"]["pos"] = Vector2i(0, 0)
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	expect(result["state"]["enemies"][0]["intent"]["id"] == "storm_claw", "Resolution advances cycle")
	for tile: Vector2i in marks: expect(Surfaces.has_surface(result["state"], tile, "electrified"), "Moved hero cannot re-aim held strikes")
	var intents: Array = Data.enemy_def("zekarion")["intents"]
	for old_slot: int in range(8):
		var saved: Dictionary = {"dragon_cycle":old_slot, "type":"zekarion", "intent":intents[old_slot % 4].duplicate(true)}
		var warning: Dictionary = saved["intent"].duplicate(true)
		Cycle._map_cycle(saved, intents, order)
		expect(saved["dragon_cycle"] == (old_slot / 4) * 5 + order.find(intents[old_slot % 4]["id"]), "Legacy cycle maps by id")
		var roundtrip: Dictionary = bytes_to_var(var_to_bytes(saved))
		Cycle._map_cycle(roundtrip, intents, order)
		expect(roundtrip == saved and saved["intent"] == warning, "Save resume is idempotent and preserves held warning")
	# A legacy combat fixes its compatibility seed once, then persists it.
	state = Boss._boss_combat_state("zekarion")
	state.erase("fight_seed")
	state["enemies"][0]["dragon_cycle"] = -1
	state["enemies"][0].erase("dragon_cycle_order")
	var legacy_rng: int = int(state["rng_state"])
	engine._assign_enemy_intent(state, 0, rng)
	expect(state["fight_seed"] == legacy_rng and state["rng_state"] == legacy_rng, "Legacy scatter seed freezes without consuming RNG")
	# No cycle_order means the original array order, including Vyraketh.
	state = Boss._boss_combat_state("vyraketh")
	for slot: int in range(8):
		if slot > 0: engine._assign_enemy_intent(state, 0, rng)
		expect(state["enemies"][0]["intent"]["id"] == Data.enemy_def("vyraketh")["intents"][slot % 4]["id"], "Legacy dragon array order unchanged")
	print("ZEK01 RULES: %s (%d assertions, %d failures)" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)
