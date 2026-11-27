extends RefCounted

const Fixture = preload("res://tools/tut02/run_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const DESTINATION := Vector2i(2, 1)
const INVALID_TILE := Vector2i(-1, -1)

static func map_start(progression: Dictionary) -> Dictionary:
	var run := Run.new()
	var state: Dictionary = run.create_new_run(Fixture.SEED, progression)
	# The tut-02 bootstrap resolves the preceding rooms before the take starts.
	for destination: Vector2i in Fixture.FIRST_UMBRA_ROUTE:
		if state["mode"] != "room" or not run.available_moves(state).has(destination):
			return {}
		if destination == DESTINATION:
			return state
		state = Fixture._advance(run, Fixture._travel(run, state, destination))
	return {}

static func empty_tile(state: Dictionary, combat: RefCounted, accept: Callable) -> Vector2i:
	var grid: Array = state["grid"]
	var taken: Dictionary = combat.call("_occupied_actor_tiles", state)
	taken[state["player"]["pos"]] = true
	for key: String in ["loot", "traps"]:
		for item: Dictionary in state.get(key, []):
			taken[item.get("pos", INVALID_TILE)] = true
	var lit: Dictionary = combat.call("umbra_visible_tile_lookup", state)
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var tile := Vector2i(x, y)
			if lit.has(tile) and not taken.has(tile) and PathUtils.is_passable(grid, tile) and accept.call(tile):
				return tile
	return INVALID_TILE

static func adjacent_move(state: Dictionary, combat: RefCounted) -> Vector2i:
	var hero: Vector2i = state["player"]["pos"]
	var occupied: Dictionary = combat.call("_occupied_actor_tiles", state)
	var plan: Dictionary = combat.call("movement_plan_for_player_action", state, combat.call("player_movement_action", state))
	for tile: Vector2i in combat.call("player_movement_targets", state):
		if PathUtils.manhattan(hero, tile) != 1 or occupied.has(tile):
			continue
		var path: Array = combat.call("path_from_player_movement_plan", plan, tile)
		if path == [hero, tile]:
			return tile
	return INVALID_TILE
