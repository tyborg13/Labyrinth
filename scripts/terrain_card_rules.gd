extends RefCounted

## Terrain card family (card pool overhaul wave 4, spec/card_mechanics_illusions_terrain.md).
##
##   burst_terrain        destroy a live terrain piece, blast its neighbors (Rockburst) or,
##                        with owned_outcrop_only, the line beyond it (Worldbreak)
##   outcrop kind powder_keg   3-HP keg; destroyed by anything it bursts on its tile and
##                        neighbors (actors and terrain, chain-reacting)
##   outcrop kind worldspine   spires around a target; each player turn start pulses
##                        every enemy next to at least one of them
## CombatEngine owns the terrain array, damage and deaths; these helpers are
## called from small hooks in its outcrop, terrain-damage and turn-start paths.

const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const IllusionCardRules = preload("res://scripts/illusion_card_rules.gd")
const GuardianRules = preload("res://scripts/guardian_combat_rules.gd")

const INVALID := Vector2i(-1, -1)
const KEG_KIND: String = "powder_keg"
const WORLDSPINE_KIND: String = "worldspine"
const OUTCROP_KIND: String = "crag_outcrop"
const KEG_EVENT: String = "powder_keg_burst"
const PULSE_EVENT: String = "worldspine_pulse"
const BURST_EVENT: String = "terrain_shattered"
## Player-raised kinds Worldbreak may break.
const OWNED_OUTCROP_KINDS: Array = [OUTCROP_KIND, WORLDSPINE_KIND]

# ------------------------------------------------------------------ outcrop kinds

## Extra fields merged into a raised object for a non-default `kind`.
static func raise_fields(action: Dictionary) -> Dictionary:
	match str(action.get("kind", "")):
		KEG_KIND:
			return {"kind": KEG_KIND, "blocks_sight": false, "surface_on_destroy": "", "burst_damage": maxi(0, int(action.get("burst_damage", 0)))}
		WORLDSPINE_KIND:
			# Tharokh's spires: they block movement, not sight, and pulse.
			return {"kind": WORLDSPINE_KIND, "blocks_sight": false, "surface_on_destroy": "rubble", "pulse_damage": maxi(0, int(action.get("pulse_damage", 0)))}
	return {}

static func is_around_target(action: Dictionary) -> bool:
	return bool(action.get("around_target", false))

## around_target: the pattern offsets around the chosen center, unrotated.
static func around_target_tiles(state: Dictionary, action: Dictionary, center: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	if not Paths.is_passable(state.get("grid", []), center):
		return tiles
	for offset_var: Variant in action.get("pattern", []):
		if typeof(offset_var) != TYPE_ARRAY or (offset_var as Array).size() < 2:
			continue
		var tile: Vector2i = center + Vector2i(int((offset_var as Array)[0]), int((offset_var as Array)[1]))
		if tile != center and not tiles.has(tile):
			tiles.append(tile)
	return tiles

## A cage may seal its center only when the center is not a chokepoint: its open
## neighbors stay connected without it (or it is a dead end). Otherwise the
## ordinary per-tile route check keeps the center open.
static func center_may_seal(engine: RefCounted, state: Dictionary, center: Vector2i) -> bool:
	var open_neighbors: int = 0
	for direction: Vector2i in Paths.DIRS_4:
		var tile: Vector2i = center + direction
		if Paths.is_passable(state.get("grid", []), tile) and engine._terrain_index_at_tile(state, tile) < 0:
			open_neighbors += 1
	return open_neighbors <= 1 or GuardianRules.preserves_routes(engine, state, center)

# ------------------------------------------------------------------ powder keg

## Called by CombatEngine._damage_terrain when a piece reaches 0 HP.
static func after_terrain_destroyed(engine: RefCounted, state: Dictionary, terrain: Dictionary) -> Dictionary:
	if str(terrain.get("kind", "")) != KEG_KIND:
		return state
	return explode_keg(engine, state, terrain)

static func keg_blast_tiles(state: Dictionary, center: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	tiles.append(center)
	tiles.append_array(IllusionCardRules.neighbor_tiles(state, center))
	return tiles

## Burst N on the keg tile and its neighbors: every actor (hero, illusions,
## enemies; footprint-aware) and every terrain piece, so kegs chain. Non-direct.
## A hero-placed keg is player-credited (causal_owner player); card plays for
## kills follow the triggering context's player_card, like any other damage.
static func explode_keg(engine: RefCounted, state: Dictionary, keg: Dictionary) -> Dictionary:
	var center: Vector2i = keg.get("pos", INVALID)
	var amount: int = maxi(0, int(keg.get("burst_damage", 0)))
	if center == INVALID or amount <= 0:
		return state
	var tiles: Array[Vector2i] = keg_blast_tiles(state, center)
	var previous_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = previous_context.duplicate(true)
	context["source_kind"] = KEG_EVENT
	context["terrain_id"] = str(keg.get("id", ""))
	if str(keg.get("owner_kind", "")) == "player":
		context["causal_owner"] = "player"
	state["damage_context"] = context
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var hit_keys: Array = []
	for actor: Dictionary in engine._surface_actor_records(state):
		if not engine._surface_unit_intersects(actor["unit"] as Dictionary, tiles):
			continue
		hit_keys.append(str(actor.get("key", "")))
		state = engine._surface_damage_actor(state, str(actor["kind"]), int(actor["id"]), amount, false)
	Surfaces.record_event(state, {"kind": KEG_EVENT, "tile": center, "tiles": tiles, "damage": amount, "terrain_id": str(keg.get("id", "")), "owner_kind": str(keg.get("owner_kind", "")), "actor_keys": hit_keys, "source": context.duplicate(true)})
	# Remaining terrain on the blast takes the same damage; another keg bursts in turn.
	var terrain_indices: Array[int]
	terrain_indices.assign(engine._terrain_indices_in_tiles(state, tiles))
	for index: int in terrain_indices:
		state = engine._damage_terrain(state, index, amount)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	state["damage_context"] = previous_context
	return state

# ------------------------------------------------------------------ worldspines

static func player_worldspines(engine: RefCounted, state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for terrain: Dictionary in engine._live_terrain(state):
		if str(terrain.get("kind", "")) == WORLDSPINE_KIND and str(terrain.get("owner_kind", "")) == "player":
			result.append(terrain)
	return result

## Pulse forecast: {enemy_id: damage}. An enemy next to several spines takes the
## largest pulse once.
static func pulse_targets(engine: RefCounted, state: Dictionary) -> Dictionary:
	var damage_by_enemy: Dictionary = {}
	var spines: Array[Dictionary] = player_worldspines(engine, state)
	if spines.is_empty():
		return damage_by_enemy
	for enemy: Dictionary in engine._live_enemies(state):
		var footprint: Array[Vector2i]
		footprint.assign(engine._enemy_footprint_tiles(enemy))
		for spine: Dictionary in spines:
			var spine_tile: Vector2i = spine.get("pos", INVALID)
			for tile: Vector2i in footprint:
				if Paths.manhattan(tile, spine_tile) == 1:
					var enemy_id: int = int(enemy.get("id", -1))
					damage_by_enemy[enemy_id] = maxi(int(damage_by_enemy.get(enemy_id, 0)), int(spine.get("pulse_damage", 0)))
					break
	return damage_by_enemy

## Player turn start, after Rites: one player-credited, non-direct pulse.
static func apply_player_turn_start(engine: RefCounted, state: Dictionary) -> Dictionary:
	var targets: Dictionary = pulse_targets(engine, state)
	if targets.is_empty():
		return state
	var previous_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = {"actor_kind": "player", "actor_id": -1, "source_kind": PULSE_EVENT, "player_card": false, "causal_owner": "player", "element": "earth"}
	state["damage_context"] = context
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var ids: Array = targets.keys()
	ids.sort()
	var hit_ids: Array[int]
	for id_var: Variant in ids:
		var amount: int = int(targets[id_var])
		if amount <= 0:
			continue
		hit_ids.append(int(id_var))
		state = engine._surface_damage_actor(state, "enemy", int(id_var), amount, false)
	var spine_tiles: Array[Vector2i]
	for spine: Dictionary in player_worldspines(engine, state):
		spine_tiles.append(spine.get("pos", INVALID))
	Surfaces.record_event(state, {"kind": PULSE_EVENT, "tiles": spine_tiles, "enemy_ids": hit_ids, "damage_by_enemy": targets.duplicate(true), "source": context.duplicate(true)})
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	state["damage_context"] = previous_context
	return state

# ------------------------------------------------------------------ burst_terrain

static func is_owned_outcrop(terrain: Dictionary) -> bool:
	return str(terrain.get("owner_kind", "")) == "player" and OWNED_OUTCROP_KINDS.has(str(terrain.get("kind", "")))

## Live terrain within range and sight (the target itself never blocks).
static func burst_targets(engine: RefCounted, state: Dictionary, action: Dictionary, player_pos: Vector2i, visible_lookup: Dictionary) -> Array[Vector2i]:
	var targets: Array[Vector2i]
	var reach: int = int(action.get("range", 1))
	var owned_only: bool = bool(action.get("owned_outcrop_only", false))
	for terrain: Dictionary in engine._live_terrain(state):
		var tile: Vector2i = terrain.get("pos", INVALID)
		if tile == player_pos or Paths.manhattan(player_pos, tile) > reach:
			continue
		if owned_only and not is_owned_outcrop(terrain):
			continue
		if not engine.is_tile_visible_to_player(state, tile, visible_lookup) or not engine.combat_line_of_sight(state, player_pos, tile):
			continue
		if not targets.has(tile):
			targets.append(tile)
	return targets

## Tiles the blast hits: the four neighbors, or (Worldbreak) the line of
## `line_length` tiles beyond the target, away from the hero, stopping at walls.
static func burst_impact_tiles(state: Dictionary, action: Dictionary, target: Vector2i) -> Array[Vector2i]:
	if not bool(action.get("owned_outcrop_only", false)) or int(action.get("line_length", 0)) <= 0:
		return IllusionCardRules.neighbor_tiles(state, target)
	var tiles: Array[Vector2i]
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var direction: Vector2i = _cardinal(target - player_pos)
	if direction == Vector2i.ZERO:
		return tiles
	for step: int in range(1, int(action.get("line_length", 3)) + 1):
		var tile: Vector2i = target + direction * step
		if not Paths.is_passable(state.get("grid", []), tile):
			break
		tiles.append(tile)
	return tiles

static func burst_damage(action: Dictionary) -> int:
	return int(action.get("line_damage", 0)) if bool(action.get("owned_outcrop_only", false)) and action.has("line_damage") else int(action.get("damage", 0))

## The derived blast attack (shared by resolution and the hand's damage chip).
static func burst_blast_action(action: Dictionary) -> Dictionary:
	return IllusionCardRules.blast_action(action, burst_damage(action), {"stagger": int(action.get("stagger", 0))})

static func resolve_burst(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i, trace: Dictionary = {}) -> Dictionary:
	var index: int = engine._terrain_index_at_tile(state, target)
	if index < 0:
		return state
	var terrain: Dictionary = engine._normalized_terrain((state.get("terrain", []) as Array)[index])
	var impact: Array[Vector2i] = burst_impact_tiles(state, action, target)
	state = engine._damage_terrain(state, index, int(terrain.get("hp", 0)))
	Surfaces.record_event(state, {"kind": BURST_EVENT, "tile": target, "tiles": impact, "terrain_id": str(terrain.get("id", "")), "terrain_kind": str(terrain.get("kind", "")), "source": engine._surface_source(state, action)})
	if burst_damage(action) > 0 and not impact.is_empty():
		state = engine._resolve_board_attack(state, burst_blast_action(action), target, "player", -1, trace, impact)
	engine._log(state, "The terrain bursts.")
	return state

static func _cardinal(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(1 if delta.x > 0 else -1, 0)
	return Vector2i(0, 1 if delta.y > 0 else -1)
