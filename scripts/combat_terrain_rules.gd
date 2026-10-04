extends RefCounted
class_name CombatTerrainRules

const ForcedRelics = preload("res://scripts/forced_relic_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const INVALID := Vector2i(-1, -1)

static func is_empty_floor(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	if tile == (state.get("player", {}) as Dictionary).get("pos", INVALID) or not Paths.is_passable(state.get("grid", []), tile): return false
	if engine._occupied_actor_tiles(state).has(tile) or engine._terrain_index_at_tile(state, tile) >= 0 or engine._trap_index_at_tile(state, tile) >= 0: return false
	for object: Dictionary in state.get("guardian_braziers", []):
		if object.get("pos", INVALID) == tile: return false
	return true

# Player spells and enemy raises share one terrain identity and outcome event.
# `fields` overrides the default crag outcrop (kind, sight, destroy surface, payloads).
static func raise_outcrop(engine: RefCounted, state: Dictionary, tile: Vector2i, health: int, source: Dictionary, fields: Dictionary = {}) -> bool:
	if health <= 0 or not is_empty_floor(engine, state, tile): return false
	health += ForcedRelics.outcrop_health_bonus(engine, state, source, fields)
	Surfaces.remove(state, tile, "all", "terrain_created")
	var serial: int = int(state.get("terrain_creation_sequence", 0)) + 1
	state["terrain_creation_sequence"] = serial
	var object: Dictionary = {"id": "outcrop_%d" % serial, "kind": "crag_outcrop", "owner_kind": source.get("actor_kind", "player"), "owner_id": source.get("actor_id", -1), "pos": tile, "hp": health, "max_hp": health, "blocks_sight": true, "surface_on_destroy": "rubble"}
	object.merge(fields, true)
	if not state.has("terrain"): state["terrain"] = []
	state["terrain"].append(object)
	Surfaces.record_event(state, {"kind": "terrain_created", "tile": tile, "terrain_id": object["id"], "terrain_kind": object["kind"], "health": health, "element": "earth", "source": source.duplicate(true)})
	return true
