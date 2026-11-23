extends RefCounted
## Burst (playability plan 2026-11-20, pla-04): one verb, one shape.
##
## Burst N destroys the thing named (a Fire, Ice, Rubble or Electrified tile's
## ground, an Outcrop, crate, keg or illusion), then deals N damage to every
## unit on its tile and the four tiles next to it, the hero
## included unless the source spares them. A Burst with several sources (a
## connected Electrified network, each Fire tile an area hit) unions the
## crosses: each unit is hit at most once per Burst.
##
## Every Burst shares this shape and victim set: card Bursts (CombatEngine
## _resolve_board_detonate, which owns card-hit damage, modifiers and
## Retaliate), Discharge, Terrain and illusion Bursts, powder kegs, Crownfire,
## Faultline and the enemies' death Burst. Callers own how one hit lands (a card
## hit, an enemy's death hit, an object's hit); `resolve` covers the non-card
## sources. Rules contract: spec/card_mechanics_surfaces.md "Burst".

const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")

const EVENT: String = "burst"
## The source tile and its four orthogonal neighbors.
const OFFSETS: Array = [Vector2i.UP, Vector2i.LEFT, Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
## Board memory a follow-up Burst reads: the ground and terrain as they were
## when the card's attack began, and the enemies that attack hit.
const BOARD_BEFORE_KEY: String = "_burst_board_before"
const HIT_RECORDS_KEY: String = "_burst_attack_hits"

## Tiles one source's Burst covers, inside the room's floor.
static func cross(state: Dictionary, source: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	var grid: Array = state.get("grid", []) as Array
	for offset: Vector2i in OFFSETS:
		if Paths.is_passable(grid, source + offset):
			tiles.append(source + offset)
	return tiles

## How many source crosses cover each tile (tile -> count).
static func coverage(state: Dictionary, sources: Array[Vector2i]) -> Dictionary:
	var counts: Dictionary = {}
	for source: Vector2i in sources:
		for tile: Vector2i in cross(state, source):
			counts[tile] = int(counts.get(tile, 0)) + 1
	return counts

## The union of every source's cross, sorted row-major.
static func area(state: Dictionary, sources: Array[Vector2i]) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	tiles.assign(coverage(state, sources).keys())
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.y == b.y else a.y < b.y)
	return tiles

## Every live unit (hero, illusions, enemies; footprint-aware) touching the
## area, each once. `spare_player` leaves the hero out.
static func victims(engine: RefCounted, state: Dictionary, tiles: Array[Vector2i], spare_player: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for actor: Dictionary in engine._surface_actor_records(state):
		if spare_player and str(actor["kind"]) == "player":
			continue
		if engine._surface_unit_intersects(actor["unit"] as Dictionary, tiles):
			result.append(actor.duplicate(true))
	return result

# ------------------------------------------------------------ board memory

## Remember the ground as it was before the card's first action, including
## terrain pieces, so follow-up Bursts can check their original fuel.
static func remember_board(state: Dictionary, before: Dictionary) -> void:
	var ground: Dictionary = {}
	for key: String in (before.get("surfaces", {}) as Dictionary):
		var entry: Dictionary = (before["surfaces"] as Dictionary)[key] as Dictionary
		ground[key] = {"elemental": str(entry.get("elemental", "")), "rubble": bool(entry.get("rubble", false))}
	var terrain: Dictionary = {}
	for piece_var: Variant in before.get("terrain", []):
		if typeof(piece_var) == TYPE_DICTIONARY and int((piece_var as Dictionary).get("hp", 0)) > 0:
			var piece: Dictionary = piece_var
			terrain[Surfaces.tile_key(piece.get("pos", Vector2i(-1, -1)))] = str(piece.get("kind", "wooden_box"))
	state[BOARD_BEFORE_KEY] = {"surfaces": ground, "terrain": terrain}
	state[HIT_RECORDS_KEY] = []

## Capture the struck body before damage or displacement changes occupancy.
static func remember_hit(state: Dictionary, unit: Dictionary, impact: Vector2i) -> void:
	if not state.has(BOARD_BEFORE_KEY):
		return
	var hits: Array = state.get(HIT_RECORDS_KEY, [])
	hits.append({"id": unit["id"], "impact": impact, "footprint": Surfaces.footprint_tiles(unit)})
	state[HIT_RECORDS_KEY] = hits

static func forget_board(state: Dictionary) -> void:
	state.erase(BOARD_BEFORE_KEY)
	state.erase(HIT_RECORDS_KEY)

## The board memory as a surfaces-only state BoardSurfaceRules can read, or {}.
static func board_before(state: Dictionary) -> Dictionary:
	return state.get(BOARD_BEFORE_KEY, {}) as Dictionary

static func terrain_kind_before(state: Dictionary, tile: Vector2i) -> String:
	return str(board_before(state).get("terrain", {}).get(Surfaces.tile_key(tile), ""))

## The chosen square wins if fueled. Otherwise take the first square of
## the same body that holds fuel, in footprint (row-major) order.
static func fuel_tile_for_impact(state: Dictionary, aim: Vector2i, fuel: String) -> Vector2i:
	if had_fuel(state, aim, fuel):
		return aim
	var hits: Array = state.get(HIT_RECORDS_KEY, [])
	for index: int in range(hits.size() - 1, -1, -1):
		var footprint: Array = hits[index]["footprint"]
		if footprint.has(aim):
			return _fuel_tile_in_footprint(state, footprint, aim, fuel)
	return aim

static func fuel_tiles_for_hits(state: Dictionary, fuel: String) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var seen: Dictionary = {}
	for hit: Dictionary in state.get(HIT_RECORDS_KEY, []):
		if seen.has(hit["id"]): continue
		var source: Vector2i = _fuel_tile_in_footprint(state, hit["footprint"], hit["impact"], fuel)
		if not had_fuel(state, source, fuel): continue
		seen[hit["id"]] = true
		result.append(source)
	return result

static func _fuel_tile_in_footprint(state: Dictionary, footprint: Array, impact: Vector2i, fuel: String) -> Vector2i:
	if had_fuel(state, impact, fuel):
		return impact
	for tile: Vector2i in footprint:
		if had_fuel(state, tile, fuel):
			return tile
	return impact

## A follow-up Burst's fuel test: ground the card's board had, or (without
## board memory, e.g. a standalone Burst) ground on the live board.
static func had_fuel(state: Dictionary, tile: Vector2i, fuel: String) -> bool:
	var before: Dictionary = board_before(state)
	if before.is_empty():
		return Surfaces.has_surface(state, tile, fuel)
	return Surfaces.has_surface(before, tile, fuel)

# ------------------------------------------------------------ resolution

## Non-card Bursts (kegs, the enemies' death Burst): one hit per victim through
## `hit` (Callable(state, actor, amount) -> state). Options:
##   spare_player   leave the hero out
##   event          recorded after the unit hits, before terrain and traps,
##                  with actor_keys and the Burst fields added
##   hit_terrain    terrain in the area takes the same damage (kegs chain)
##   trigger_traps  traps in the area trigger
##   tiles          a held Faultline's committed strike tiles
## Returns {"state", "tiles", "actor_keys"}.
static func resolve(engine: RefCounted, state: Dictionary, sources: Array[Vector2i], amount: int, hit: Callable, options: Dictionary = {}) -> Dictionary:
	var tiles: Array[Vector2i] = TypedArrays.vector2i(options["tiles"]) if options.has("tiles") else area(state, sources)
	var spare_player: bool = bool(options.get("spare_player", false))
	var keys: Array = []
	if amount > 0:
		for actor: Dictionary in victims(engine, state, tiles, spare_player):
			var before: Vector3i = damage_pools(engine._surface_actor(state, actor["kind"], actor["id"]))
			state = hit.call(state, actor, amount)
			if took_damage(before, engine._surface_actor(state, actor["kind"], actor["id"])):
				keys.append(str(actor.get("key", "")))
	var event: Dictionary = (options.get("event", {}) as Dictionary).duplicate(true)
	if not event.is_empty():
		event["actor_keys"] = keys.duplicate()
		event.merge(event_fields(sources, tiles, amount, spare_player))
		Surfaces.record_event(state, event)
	if amount > 0 and bool(options.get("hit_terrain", false)):
		var terrain_indices: Array[int]
		terrain_indices.assign(engine._terrain_indices_in_tiles(state, tiles))
		for index: int in terrain_indices:
			state = engine._damage_terrain(state, index, amount)
	if amount > 0 and bool(options.get("trigger_traps", false)):
		state = engine._trigger_traps_on_tiles(state, engine._trap_tiles_in_tiles(state, tiles))
	return {"state": state, "tiles": tiles, "actor_keys": keys}

static func damage_pools(unit: Dictionary) -> Vector3i:
	return Vector3i(int(unit.get("hp", 0)), int(unit.get("block", 0)), int(unit.get("stoneskin", 0)))

static func took_damage(before: Vector3i, unit: Dictionary) -> bool:
	var after: Vector3i = damage_pools(unit)
	return after.x < before.x or after.y < before.y or after.z < before.z

## The element a Burst's eruption reads as: its fuel's (Rubble earth, Ice ice,
## Electrified lightning), else Fire; a piece or illusion Burst uses its card's.
static func fx_element(action: Dictionary) -> String:
	var fuel: String = Surfaces.kind(str(action.get("_detonate_surface", action.get("detonate_surface", "fire"))))
	match fuel:
		"rubble": return "earth"
		"ice": return "ice"
		"electrified": return "lightning"
		"fire": return "fire"
	var element: String = str(action.get("element", action.get("_card_element", "none")))
	return "fire" if element in ["", "none"] else element

## Additive analytics/presentation fields every Burst event carries.
static func event_fields(sources: Array[Vector2i], tiles: Array[Vector2i], amount: int, spare_player: bool) -> Dictionary:
	return {"burst": true, "burst_shape": "cross", "burst_sources": sources.duplicate(), "burst_tiles": tiles.duplicate(), "burst_damage": amount, "spares_player": spare_player}
