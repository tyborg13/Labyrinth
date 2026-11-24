extends SceneTree
## Exercise enemy delivery, committed warnings and the proposed wording's edge cases.

const Combat = preload("res://scripts/combat_engine.gd")
const Fight = preload("res://tests/suites/sta01_mechanics_suite.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const Guardians = preload("res://scripts/guardian_combat_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Scatter = preload("res://scripts/dragon_scatter_pattern.gd")
const Stalker = preload("res://scripts/enemy_mechanics/stalker.gd")

const ORIGIN := Vector2i(2, 4)
const BOSS_ORIGIN := Vector2i(4, 3)
const OPEN_TARGET := Vector2i(6, 4)
const FADE_HERO := Vector2i(4, 4)
const DIAGONAL_TARGET := Vector2i(1, 1)
const OUTSIDE_MELEE_REACH := Vector2i(2, 1)
const DIVE_HERO := Vector2i(1, 4)
const DIVE_BLOCKER := Vector2i(3, 3)
const DIVE_END := Vector2i(2, 3)
const DIVE_BLOCKER_HEALTH: int = 99
const GALE_HERO := Vector2i(2, 3)
const GALE_BLOCKER := Vector2i(3, 3)
const SCATTER_HERO := Vector2i(1, 1)
const SCATTER_WALLS = [Vector2i(1, 2), Vector2i(2, 1)]
const PROOF_WALL_TILE := "wall"

var _engine := Combat.new()
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_delivery()
	_guardian_force()
	_placement()
	_scatter()
	_gale()
	_fade()
	_brace()
	_dive()
	print("TXT41 WITNESS: %s" % ("FAIL" if _failed else "PASS"))
	quit(int(_failed))

func _expect(ok: bool, name: String, detail: Variant) -> void:
	if not ok:
		_failed = true
		push_error("%s: %s" % [name, detail])
	print("TXT41 %s: %s" % [name, detail])

func _delivery() -> void:
	var state: Dictionary = Fight.state("gloam_stalker", "slash")
	var enemy: Dictionary = state["enemies"][0]
	var strike: Dictionary = enemy["intent"]["actions"][1]
	var adjacent: bool = _engine._enemy_action_reaches_tile(state, enemy, strike, ORIGIN + Vector2i.RIGHT)
	var diagonal: bool = _engine._enemy_action_reaches_tile(state, enemy, strike, ORIGIN + DIAGONAL_TARGET)
	_expect(adjacent and not diagonal, "ADJACENT", {"adjacent": adjacent, "diagonal": diagonal})
	state = Fight.state("storm_cantor", "broken_rhythm")
	enemy = state["enemies"][0]
	strike = enemy["intent"]["actions"][1]
	var at_two: bool = _engine._enemy_action_reaches_tile(state, enemy, strike, ORIGIN + DIAGONAL_TARGET)
	var at_three: bool = _engine._enemy_action_reaches_tile(state, enemy, strike, ORIGIN + OUTSIDE_MELEE_REACH)
	_expect(at_two and not at_three, "REACH_MELLEE", {"distance_2": at_two, "distance_3": at_three})
	state = Fight.state("ashen_reaver", "hooked_sweep")
	enemy = state["enemies"][0]
	strike = enemy["intent"]["actions"][1]
	var area: Array[Vector2i] = Guardians.shape_tiles(_engine, state, ORIGIN, Vector2i.RIGHT, strike)
	var extent: int = 0
	for tile: Vector2i in area: extent = maxi(extent, tile.x - ORIGIN.x)
	_expect(area.size() > 1 and extent == int(strike["range"]), "AREA_REACH", {"tiles": area, "forward_tiles": extent})
	var hp: int = int(state["player"]["hp"])
	state["player"]["pos"] = area.front()
	var result: Dictionary = _engine._resolve_board_attack(state, strike, area.front(), "enemy", enemy["id"], {}, area)
	var lost: int = hp - int(result["player"]["hp"])
	_expect(lost == int(strike["damage"]), "AREA_DAMAGE", {"tile": area.front(), "hp_lost": lost})

func _guardian_force() -> void:
	var moves: Dictionary = {
		"ashen_reaver": "hooked_sweep", "gallows_roc": "hookwind",
		"last_lamplighter": "mourning_hook", "noctyrax": "night_coil",
	}
	for enemy_id: String in moves:
		var state: Dictionary = Fight.state(enemy_id, moves[enemy_id])
		var intent: Dictionary = Guardians.commit(_engine, state, 0, state["enemies"][0]["intent"])
		var action: Dictionary = intent["actions"][-1]
		var fixed: bool = action.has("force_direction")
		_expect(fixed == (enemy_id == "noctyrax"), "FORCE " + enemy_id,
			{"direction": action.get("declared_direction"), "force": action.get("force_direction")})
	var state: Dictionary = Fight.state("gallows_roc", "razor_pinion")
	var intent: Dictionary = Guardians.commit(_engine, state, 0, state["enemies"][0]["intent"])
	_expect(not intent["actions"][-1].has("force_direction"), "FORCE razor_pinion", "Guardian sweep has no fixed force")
	# Exercise the forward branch using an isolated mutation of the Night Coil
	# proof action. The catalog has no fixed-direction Push.
	state = Fight.state("noctyrax", "night_coil")
	intent = state["enemies"][0]["intent"]
	intent["actions"][0].erase("pull")
	intent["actions"][0]["push"] = 1
	intent = Guardians.commit(_engine, state, 0, intent)
	var synthetic: Dictionary = intent["actions"][0]
	_expect(synthetic["force_direction"] == synthetic["declared_direction"],
		"FORCE synthetic push", {"direction": synthetic["force_direction"]})

func _placement() -> void:
	var join: Dictionary = Fight.state("bell_tender", "connector")
	var join_action: Dictionary = join["enemies"][0]["intent"]["actions"][-1]
	var route: Array[Vector2i] = Guardians.connector_tiles(_engine, join, ORIGIN, OPEN_TARGET, join_action)
	var straight: bool = route.all(func(tile: Vector2i) -> bool: return tile.y == ORIGIN.y)
	_expect(not route.is_empty() and route.size() <= int(join_action["guardian_count"]) and straight, "JOIN_CHOIR", route)
	var state: Dictionary = Fight.state("storm_cantor", "lay_the_choir")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][-1]
	var neighbor: Vector2i = ORIGIN + Vector2i.RIGHT
	state["player"]["pos"] = neighbor
	var cells: Array[Vector2i] = Guardians.connector_tiles(_engine, state, ORIGIN, neighbor, action)
	var off_line: bool = cells.any(func(tile: Vector2i) -> bool: return tile.y != ORIGIN.y)
	_expect(cells.size() == int(action["guardian_count"]) and off_line, "CHOIR_FILL", cells)

func _scatter() -> void:
	var state: Dictionary = Fight.state("zekarion", "skybreak")
	var enemy: Dictionary = state["enemies"][0]
	state["player"]["pos"] = OPEN_TARGET
	var count: int = int(enemy["intent"]["actions"][0]["count"])
	var open_marks: Array[Vector2i] = Scatter.tiles(_engine, state, enemy, count)
	_expect(open_marks.has(OPEN_TARGET) and open_marks.size() <= count, "SKYBREAK_OPEN", open_marks)
	state["player"]["pos"] = SCATTER_HERO
	for tile: Vector2i in SCATTER_WALLS: state["grid"][tile.y][tile.x] = PROOF_WALL_TILE
	var boxed_marks: Array[Vector2i] = Scatter.tiles(_engine, state, enemy, count)
	_expect(not boxed_marks.has(SCATTER_HERO), "SKYBREAK_BOXED", boxed_marks)

func _gale() -> void:
	var state: Dictionary = Fight.state("vaeloryx", "hollow_gale")
	state["enemies"][0]["pos"] = BOSS_ORIGIN
	state["player"]["pos"] = GALE_HERO
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	var open_tiles: Array[Vector2i] = Guardians.shape_tiles(_engine, state, BOSS_ORIGIN, Vector2i.LEFT, action)
	state["grid"][GALE_BLOCKER.y][GALE_BLOCKER.x] = PROOF_WALL_TILE
	var blocked_tiles: Array[Vector2i] = Guardians.shape_tiles(_engine, state, BOSS_ORIGIN, Vector2i.LEFT, action)
	_expect(open_tiles.has(GALE_HERO) and not blocked_tiles.has(GALE_HERO), "HOLLOW_GALE_COVER",
		{"hero": GALE_HERO, "distance": 2, "wall": GALE_BLOCKER})

func _fade() -> void:
	var state: Dictionary = Fight.state("gloam_stalker", "fade")
	var enemy: Dictionary = state["enemies"][0]
	state["player"]["pos"] = FADE_HERO
	var hero: Vector2i = state["player"]["pos"]
	var open_tile: Vector2i = Stalker.destination(_engine, state, enemy)
	for offset: Vector2i in Paths.DIRS_4:
		var tile: Vector2i = hero + offset
		state["grid"][tile.y][tile.x] = PROOF_WALL_TILE
	var boxed: Vector2i = Stalker.destination(_engine, state, enemy)
	_expect(Paths.manhattan(open_tile, hero) == 1 and boxed == ORIGIN, "FADE_BOXED",
		{"open_destination": open_tile, "boxed_destination": boxed})

func _brace() -> void:
	var state: Dictionary = Fight.state("grave_surgeon", "field_brace")
	var enemy: Dictionary = state["enemies"][0]
	var action: Dictionary = enemy["intent"]["actions"][-1]
	var target: int = _engine._enemy_support_target_index(state, 0, action)
	_expect(target == 0, "FIELD_BRACE_SOLO", {"guarded_enemy_index": target})

func _dive() -> void:
	var state: Dictionary = Fight.state("vaeloryx", "razor_dive")
	state.erase("battlefield_rule")
	state.erase("wind")
	state["player"]["pos"] = DIVE_HERO
	state["enemies"][0]["pos"] = BOSS_ORIGIN
	# The STA-01 arena uses a 1x1 fixture enemy. Restore Vaeloryx's catalog body.
	state["enemies"][0]["footprint"] = Vector2i(2, 2)
	var intent: Dictionary = Guardians.commit(_engine, state, 0, state["enemies"][0]["intent"])
	state["enemies"][0]["intent"] = Areas.freeze(_engine, state, state["enemies"][0], intent)
	var path: Array[Vector2i] = [BOSS_ORIGIN, DIVE_BLOCKER, DIVE_END]
	intent["committed_plan"]["path"] = path
	intent["committed_plan"]["destination"] = DIVE_END
	_dive_impact(state, false)
	state["terrain"] = [{"id": "dive_blocker", "pos": DIVE_BLOCKER, "hp": DIVE_BLOCKER_HEALTH, "max_hp": DIVE_BLOCKER_HEALTH}]
	_dive_impact(state, true)

func _dive_impact(state: Dictionary, interrupted: bool) -> void:
	var plan: Dictionary = _engine.enemy_intent_plan(state, 0)
	var warning: Array = plan["projected_attack"]
	var resolved: Dictionary = _engine.resolve_enemy_turn_with_steps(state, 0)
	var steps: Array = resolved["steps"].filter(func(step: Dictionary) -> bool: return step.get("intent_id") == "razor_dive" and step.get("action_type") == "aoe")
	var impact: Array = steps[0]["tiles"] if steps.size() == 1 else []
	var same: bool = not warning.is_empty() and warning.size() == impact.size() and impact.all(func(tile: Vector2i) -> bool: return warning.has(tile))
	var outliers: Array[Vector2i]
	if interrupted:
		var enemy: Dictionary = state["enemies"][0]
		for tile: Vector2i in impact:
			if _engine._enemy_distance_to_tile(enemy, tile) > 1: outliers.append(tile)
	_expect(same and (plan["destination"] == BOSS_ORIGIN if interrupted else plan["destination"] == DIVE_END),
		"RAZOR_DIVE", {"interrupted": interrupted, "endpoint": plan["destination"], "warning": warning, "impact": impact})
	if interrupted:
		_expect(not outliers.is_empty(), "RAZOR_DIVE_OUTSIDE_PATH", outliers)
