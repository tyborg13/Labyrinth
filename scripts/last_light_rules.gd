extends RefCounted
## Last Light (spx-08): the existing Survive objective in a dark room with three
## braziers. Every piece is an existing primitive: Survive's clock and
## reinforcements, the Umbra sight table, permanent radius-2 brazier Light, the
## Shadowstep room rule, the Wick Shade's Snuff and Noctyrax's relight-on-step.
const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Snuff = preload("res://scripts/enemy_mechanics/snuff.gd")
const TYPE: String = "last_light"
const SHADE: String = "wick_shade"
const MAX_PLACEMENT_ATTEMPTS: int = 20
const INVALID := Vector2i(-1, -1)

static func definition() -> Dictionary:
	return Library.definition(TYPE)

static func is_room(room: Dictionary) -> bool:
	return str(room.get("type", "")) == "special" and str(room.get("special_type", "")) == TYPE

static func active(state: Dictionary) -> bool:
	return str(state.get("objective", {}).get("special_type", "")) == TYPE

# Survive cannot fail on victory: dawn always meets the goal. Defeat is ordinary.
static func objective(room: Dictionary, encounter_depth: int) -> Dictionary:
	return {"special_type": TYPE, "special_variant": room["special_variant"], "goal_met": true, Snuff.SNUFF_COUNT_KEY: 0,
		"target_clock": int((definition()["time_target_by_depth"] as Array)[encounter_depth - 1])}

static func title() -> String:
	return str(definition()["objective_title"])

static func description() -> String:
	return str(definition().get("objective_description", "ERROR_MISSING_LAST_LIGHT_DESCRIPTION"))

## The starting cast: the authored Wick Shades, then the section's attackers.
static func roster(room: Dictionary) -> Array:
	var rules: Dictionary = definition()
	var result: Array = []
	for index: int in range(int(rules["wick_shades"])): result.append(SHADE)
	result.append_array(Library.variant(TYPE, str(room["special_variant"]))["attackers"])
	return result

## The Umbra stage whose sight radius is the room's authored radius, so the dark,
## its board treatment and every Light/Truesight rule are the ordinary ones.
static func umbra_stage() -> String:
	var radius: int = int(definition()["sight_radius"])
	var table: Dictionary = load("res://scripts/combat_engine.gd").UMBRA_RADIUS_BY_STAGE
	for stage: String in table:
		if int(table[stage]) == radius: return stage
	push_error("No Umbra stage has sight radius %d" % radius)
	return ""

static func is_edge(grid: Array, tile: Vector2i) -> bool:
	return tile.x <= 1 or tile.y <= 1 or tile.y >= grid.size() - 2 or tile.x >= (grid[tile.y] as Array).size() - 2

## Empty floor at the authored Manhattan distance from the hero's start, never on
## an edge tile and reachable on foot, in the room's row-major tile order.
static func brazier_candidates(grid: Array, start: Vector2i) -> Array[Vector2i]:
	var distance: int = int(definition()["braziers"]["distance_from_start"])
	var result: Array[Vector2i]
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile := Vector2i(x, y)
			if tile == start or Paths.manhattan(tile, start) != distance or is_edge(grid, tile): continue
			if not Paths.is_passable(grid, tile) or str(grid[y][x]) == "door": continue
			if Paths.find_path(grid, start, tile).is_empty(): continue
			result.append(tile)
	return result

## The set that maximizes the smallest pairwise distance. Equal sets keep the
## lowest tile indices (the first set met in tile order). Empty if too few fit.
static func brazier_tiles(grid: Array, start: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = brazier_candidates(grid, start)
	var count: int = int(definition()["braziers"]["count"])
	var best: Array[Vector2i]
	var state: Dictionary = {"spread": -1}
	var chosen: Array[Vector2i]
	_choose(candidates, count, 0, chosen, best, state)
	return best

static func _choose(candidates: Array[Vector2i], count: int, offset: int, chosen: Array[Vector2i], best: Array[Vector2i], state: Dictionary) -> void:
	if chosen.size() == count:
		var spread: int = 2147483647
		for first: int in range(chosen.size()):
			for second: int in range(first + 1, chosen.size()): spread = mini(spread, Paths.manhattan(chosen[first], chosen[second]))
		if spread > int(state["spread"]):
			state["spread"] = spread
			best.assign(chosen)
		return
	for index: int in range(offset, candidates.size()):
		chosen.append(candidates[index])
		_choose(candidates, count, index + 1, chosen, best, state)
		chosen.pop_back()

static func configure(layout: Dictionary, braziers: Array[Vector2i]) -> void:
	layout["special_type"] = TYPE
	layout["special_variant"] = layout["objective"]["special_variant"]
	var list: Array = []
	for index: int in range(braziers.size()): list.append({"id": index + 1, "pos": braziers[index], "lit": true})
	layout["guardian_braziers"] = list
	layout[Snuff.RELIGHT_KEY] = true
	layout["umbra_stage"] = umbra_stage()
	var dispatcher: GDScript = load("res://scripts/battlefield_rules/dispatcher.gd")
	layout["battlefield_rule"] = dispatcher.instance_for(str(definition()["battlefield_instance"]))

static func lit_count(state: Dictionary) -> int:
	return Snuff.lit_braziers(state).size()

static func brazier_tooltip() -> String:
	return str(definition()["braziers"]["tooltip"])

## The Last Light bonus on top of the shared special reward: Health per brazier
## still lit at dawn, up to the authored cap. The caller caps it at max Health.
static func dawn_heal(room: Dictionary, combat_state: Dictionary) -> int:
	var bonus: Dictionary = Library.definition(str(room.get("special_type", ""))).get("bonus", {})
	if str(bonus.get("kind", "")) != "heal_per_lit_brazier": return 0
	return mini(int(bonus["max"]), int(bonus["amount"]) * lit_count(combat_state))

static func reward_line() -> String:
	return str(definition()["bonus"]["reward_line"])

## Additive combat-end analytics. Lit braziers count only at dawn (victory).
static func context(engine: RefCounted, state: Dictionary) -> Dictionary:
	if not active(state): return {}
	var dawn: bool = engine.combat_outcome(state) == "victory"
	return {"braziers_lit_at_dawn": lit_count(state) if dawn else 0, "brazier_snuffs": int(state["objective"].get(Snuff.SNUFF_COUNT_KEY, 0))}
