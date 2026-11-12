extends "res://tools/inspection_fixture.gd"

## Production roster/positions/intents, selected from a real Section I route.
const SEED_START: int = 7262026
const SEED_ATTEMPTS: int = 256
const ROUTE_STEP_LIMIT: int = 32
const OVERLAP_PASS_LIMIT: int = 2
const BOSS_PASS_LIMIT: int = 4
const MAX_HERO_OVERLAP_DISTANCE: int = 3
const CASES_PATH: String = "/private/tmp/labyrinth_codex/rd-04/feedback2/cases.json"
const Graph = preload("res://scripts/section_map_graph.gd")
const Tables = preload("res://scripts/encounter_tables.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
static var _visibility_engine := CombatEngine.new()

func _build_run_state(scenario: String, progression: Dictionary) -> Dictionary:
	var state: Dictionary = super._build_run_state(scenario, progression)
	if scenario != "dragon": return state
	for activation in range(BOSS_PASS_LIMIT):
		var battle: Dictionary = state.get("combat_state", {})
		if open_unit_count(battle) >= 3: return state
		if _combat_engine.combat_outcome(battle) != "": break
		battle = _combat_engine.advance_to_next_player_turn_with_steps(_combat_engine.finish_player_activation(battle))["state"]
		state = _run_engine.set_combat_state(state, battle)
	_fail("Real boss arena did not retain three open units including the hero")
	quit(1)
	return {}

func _build_combat_run(progression: Dictionary) -> Dictionary:
	for seed_offset in range(SEED_ATTEMPTS):
		var seed: int = SEED_START + seed_offset
		var initial: Dictionary = _apply_loadout(_run_engine.create_new_run(seed, progression))
		if seed_offset == 0: print("RD04 SCOUT initial ", initial.get("mode"), " moves=", _run_engine.available_moves(initial))
		for source: Dictionary in initial.get("rooms", {}).values():
			if int(source.get("section_index", -1)) != 0 or str(source.get("type", "")) != "combat": continue
			var coord: Vector2i = source["coord"]
			var state: Dictionary = _walk_to(initial, coord)
			if str(state.get("mode", "")) != "combat":
				if seed_offset < 2: print("RD04 SCOUT skipped ", coord, " mode=", state.get("mode"))
				continue
			var room: Dictionary = Graph.room(state, coord)
			var battle: Dictionary = state["combat_state"]
			for activation in range(OVERLAP_PASS_LIMIT):
				if not overlap_tiles(battle).is_empty() and open_unit_count(battle) >= 3: break
				if _combat_engine.combat_outcome(battle) != "": break
				battle = _combat_engine.advance_to_next_player_turn_with_steps(_combat_engine.finish_player_activation(battle))["state"]
			if _combat_engine.combat_outcome(battle) != "": continue
			state = _run_engine.set_combat_state(state, battle)
			var enemies: Array = battle.get("enemies", [])
			if seed_offset < 2: print("RD04 SCOUT room ", coord, " depth=", room.get("depth"), " k=", room.get("fight_number"), " n=", enemies.size(), " open=", open_unit_count(battle))
			var living: Array = enemies.filter(func(e: Dictionary) -> bool: return int(e.get("hp", 0)) > 0)
			if living.size() < 4 or living.size() > 5: continue
			var ordinary: bool = true
			for enemy: Dictionary in enemies:
				if bool(GameData.enemy_property(str(enemy["type"]), "boss_bar", false)): ordinary = false
			if not ordinary or open_unit_count(battle) < 3: continue
			var overlap: Array[Vector2i] = overlap_tiles(battle)
			if overlap.is_empty() or overlap.size() > 2: continue
			_options["seed"] = seed
			var cases: Dictionary = {"seed": seed, "overlap_room": str(coord), "fight_number": room["fight_number"], "overlap_tiles": overlap, "open_units": open_unit_count(battle)}
			for depth: int in [4, 8, 12, 16, 20]:
				var id: String = Bosses.boss_id_for_depth(seed, depth)
				if id in ["zekarion", "vyraketh"]: cases[id + "_depth"] = depth
			DirAccess.make_dir_recursive_absolute(CASES_PATH.get_base_dir())
			var file := FileAccess.open(CASES_PATH, FileAccess.WRITE)
			file.store_string(JSON.stringify(cases, "\t"))
			print("RD04 NATURAL FIXTURE: ", JSON.stringify(cases), " roster=", enemies.map(func(e: Dictionary) -> String: return str(e["type"])))
			return state
	print("RD04 SCOUT: no matching route within seed budget")
	_fail("No natural Section I fight met overlap/open-space criteria within the named search budget")
	quit(1)
	return {}

func _walk_to(initial: Dictionary, target: Vector2i) -> Dictionary:
	var state: Dictionary = initial.duplicate(true)
	for step in range(ROUTE_STEP_LIMIT):
		var current: Vector2i = state.get("current_room", Vector2i.ZERO)
		if current == target:
			if str(state.get("mode", "")) == "pre_battle": state = _run_engine.begin_pre_battle_combat(state)
			return state
		var next := Vector2i(-999, -999)
		for candidate: Vector2i in _run_engine.available_moves(state):
			if candidate == target or Graph.descendants(state, candidate).has(target):
				next = candidate
				break
		if next.x == -999: return {}
		state = _run_engine.move_to_room(state, next)
		if next != target: state = _resolve_route_room(state)
	return {}

func overlap_tiles(battle: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var counts: Dictionary = {}
	for threat: Dictionary in Badges.build(_combat_engine, battle, battle).get("threats", []):
		for tile: Vector2i in threat.get("tiles", []): counts[tile] = int(counts.get(tile, 0)) + 1
	for tile: Vector2i in counts:
		if int(counts[tile]) != 2 or _occupied(battle, tile): continue
		var hero: Vector2i = battle["player"]["pos"]
		if absi(tile.x - hero.x) + absi(tile.y - hero.y) <= MAX_HERO_OVERLAP_DISTANCE: result.append(tile)
	return result

static func _occupied(state: Dictionary, tile: Vector2i) -> bool:
	if state.get("player", {}).get("pos") == tile: return true
	for enemy: Dictionary in state.get("enemies", []):
		var origin: Vector2i = enemy["pos"]
		var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
		if Rect2i(origin, footprint).has_point(tile): return true
	return false

static func open_unit_count(state: Dictionary) -> int:
	if int(state.get("player", {}).get("hp", 0)) <= 0: return 0
	var units: Array = [state.get("player", {})]
	units.append_array(state.get("enemies", []))
	var open: int = 0
	for unit: Dictionary in units:
		if int(unit.get("hp", 0)) <= 0: continue
		if unit != state.get("player", {}) and not _visibility_engine.is_enemy_visible_to_player(state, unit): continue
		var blocked: bool = false
		var origin: Vector2i = unit.get("pos", Vector2i(-1, -1))
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var front: Vector2i = origin + offset
			var grid: Array = state.get("grid", [])
			if front.y >= 0 and front.y < grid.size() and front.x >= 0 and front.x < (grid[front.y] as Array).size():
				if str(grid[front.y][front.x]) in ["pillar", "column", "wall"]: blocked = true
			for prop: Dictionary in state.get("terrain", []):
				if prop.get("pos") == front and int(prop.get("hp", 0)) > 0: blocked = true
		if blocked and unit == state.get("player", {}): return 0
		if not blocked: open += 1
	return open
