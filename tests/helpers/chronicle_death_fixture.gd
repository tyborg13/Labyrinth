extends RefCounted

const RunEngine = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const FIXTURE_SEED: int = 8821

# Debug-only setup, followed by real lethal damage and the production terminal
# adapter. The damage has no enemy, intent, trap or surface identity recorded.
static func terminal_run() -> Dictionary:
	var engine := RunEngine.new()
	var run: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
	var destination: Vector2i = engine.available_moves(run)[0]
	run["rooms"][Graph.key(destination)]["type"] = "combat"
	run = engine.move_to_pre_battle(run, destination)
	run = engine.begin_pre_battle_combat(run)
	var combat: Dictionary = run["combat_state"].duplicate(true)
	combat[RunEngine.DEFIANCE_REMAINING_KEY] = 0
	combat.erase("damage_context")
	combat = engine._combat_engine._damage_player(combat, int(combat["player"]["hp"]), true, false)
	return engine.finish_combat(run, combat)
