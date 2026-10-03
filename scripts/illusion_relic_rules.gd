extends RefCounted

## Relic pool overhaul U6. All selection is by reusable effect type.
## Preview, commit and animation use these same resolvers; saved pending echoes
## belong to the card, while the turn flag prevents a second card claiming them.
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Cards = preload("res://scripts/illusion_card_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const INVALID := Vector2i(-1, -1)
const PENDING := "illusion_relic_pending_echo"
const USED := "illusion_relic_attack_used"
const TRADE_SEARCH := "_movement_trade_search"

static func effect(engine: RefCounted, state: Dictionary, type: String) -> Dictionary:
	for entry: Dictionary in engine._relic_effects(state):
		if str(entry.get("type", "")) == type:
			return entry
	return {}

static func after_destroy(engine: RefCounted, state: Dictionary, illusion: Dictionary, cause: Dictionary) -> Dictionary:
	var previous: Dictionary = cause.duplicate(true)
	var blast: Dictionary = effect(engine, state, "illusion_death_damage")
	if not blast.is_empty():
		state["damage_context"] = {"actor_kind": "player", "source_kind": "illusion_relic_shatter", "player_card": false, "causal_owner": "player", "relic_id": blast.get("relic_id", ""), "illusion_id": illusion.get("id", -1)}
		for enemy: Dictionary in engine._live_enemies(state):
			if Cards._footprint_touches(engine, enemy, illusion.get("pos", INVALID)):
				state = engine._damage_enemy(state, engine._enemy_index_for_id(state, int(enemy["id"])), Data.fixed_point_amount(int(blast.get("damage", 0))), false)
	var retort: Dictionary = effect(engine, state, "illusion_enemy_destroy_status")
	if not retort.is_empty() and str(cause.get("actor_kind", "")) == "enemy" and str(cause.get("source_kind", "")) == "direct_attack":
		var id: int = int(cause.get("actor_id", -1))
		var index: int = engine._enemy_index_for_id(state, id)
		if index >= 0 and int(engine._surface_actor(state, "enemy", id).get("hp", 0)) > 0:
			state["damage_context"] = previous
			engine._apply_stagger_to_enemy(state, id, int(retort.get("stagger", 0)))
			state = engine._apply_action_keywords_to_enemy(state, index, {"type": "illusion_relic", "expose": Data.fixed_point_amount(int(retort.get("expose", 0)))}, illusion.get("pos", INVALID), true)
	state["damage_context"] = previous
	return state

# ------------------------------------------------------------------ Glassway
static func can_trade(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return not effect(engine, state, "movement_illusion_exchange").is_empty() and not Cards.illusion_at(engine, state, tile).is_empty()

## Open all owned illusion endpoints, but never expand through them. The base
## search still applies straight-line and U7 movement rules. A trade enters only
## its landing tile, so a second search prices the endpoints by their cheapest
## route: hazards, pickups and Light refunds on the way do not count.
static func movement_navigation(engine: RefCounted, state: Dictionary, action: Dictionary, player: Dictionary, budget: int, occupied: Dictionary, minimum: bool, stop: Callable = Callable()) -> Dictionary:
	if effect(engine, state, "movement_illusion_exchange").is_empty():
		return engine._base_player_move_navigation(state, action, player, budget, occupied, minimum, stop)
	var endpoints: Dictionary = {}
	for illusion: Dictionary in engine._live_illusions(state):
		var tile: Vector2i = illusion.get("pos", INVALID)
		if engine.is_tile_visible_to_player(state, tile): endpoints[tile] = true
	if endpoints.is_empty():
		return engine._base_player_move_navigation(state, action, player, budget, occupied, minimum, stop)
	var navigation_state: Dictionary = state.duplicate(false)
	navigation_state["_movement_allowed_endpoints"] = endpoints
	var navigation: Dictionary = engine._base_player_move_navigation(navigation_state, action, player, budget, occupied, minimum, stop)
	var trade_state: Dictionary = navigation_state.duplicate(false)
	trade_state[TRADE_SEARCH] = true
	var trades: Dictionary = engine._base_player_move_navigation(trade_state, action, player, budget, occupied, minimum, stop)
	var paths: Dictionary = (navigation.get("paths", {}) as Dictionary).duplicate()
	var costs: Dictionary = (navigation.get("costs", {}) as Dictionary).duplicate()
	var trade_paths: Dictionary = trades.get("paths", {}) as Dictionary
	var trade_costs: Dictionary = trades.get("costs", {}) as Dictionary
	for tile: Vector2i in endpoints:
		if trade_paths.has(tile):
			paths[tile] = trade_paths[tile]
			costs[tile] = trade_costs.get(tile, 0)
		else:
			paths.erase(tile)
			costs.erase(tile)
	var result: Dictionary = navigation.duplicate(false)
	result["paths"] = paths
	result["costs"] = costs
	return result

## Both positions change before contact (the same convention as Empty Husk).
## The illusion arrives first; the caller then resolves normal hero arrival.
static func trade_before_arrival(engine: RefCounted, state: Dictionary, tile: Vector2i, origin: Vector2i) -> Dictionary:
	if not can_trade(engine, state, tile): return state
	var found: Dictionary = Cards.illusion_at(engine, state, tile)
	var id: int = int(found["id"])
	engine._surface_actor(state, "illusion", id)["pos"] = origin
	(state["player"] as Dictionary)["pos"] = tile
	Surface.record_event(state, {"kind": Cards.SWAP_EVENT, "illusion_id": id, "illusion_key": engine._illusion_key(found), "from": origin, "to": tile, "block_transferred": 0, "source": (state.get("damage_context", {}) as Dictionary).duplicate(true)})
	return engine.surface_actor_arrival(state, "illusion", id, tile)

# ------------------------------------------------------------------ Hollow Puppet
static func puppet_action(engine: RefCounted, state: Dictionary, action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["melee", "ranged", "push", "pull"] and engine._forced_movement_amount(action) > 0 and not effect(engine, state, "force_owned_illusion").is_empty() and not action.has("_enemy_id")

static func puppet_targets(engine: RefCounted, state: Dictionary, action: Dictionary, origin: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i]
	if not puppet_action(engine, state, action): return targets
	var reach: int = int(action.get("range", 1))
	for illusion: Dictionary in engine._live_illusions(state):
		var tile: Vector2i = illusion.get("pos", INVALID)
		if Paths.manhattan(origin, tile) > reach or not engine.is_tile_visible_to_player(state, tile): continue
		if str(action.get("type", "")) != "melee" and reach > 1 and not bool(action.get("ignore_los", false)) and not engine.combat_line_of_sight(state, origin, tile): continue
		var amount: int = engine._forced_movement_amount(action)
		var pushing: bool = engine._forced_movement_pushes(action)
		var sources: Dictionary = engine._force_source_tiles(state, origin)
		var direction: Vector2i = engine._resolved_force_direction(state, "illusion", int(illusion["id"]), action, origin, pushing, amount, sources)
		var level: Vector2i = engine._force_level_stop_direction(illusion, tile, direction, sources, pushing)
		var contact: Dictionary = engine._force_step_contact(state, "illusion", int(illusion["id"]), illusion, tile + direction, sources, pushing, level)
		if direction != Vector2i.ZERO and not bool(contact.get("source", false)): targets.append(tile)
	return targets

static func resolve_puppet(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var illusion: Dictionary = Cards.illusion_at(engine, state, target)
	var origin: Vector2i = action.get("_origin_tile", state["player"]["pos"])
	var sources: Dictionary = engine._force_source_tiles(state, origin)
	var pushing: bool = engine._forced_movement_pushes(action)
	var amount: int = engine._forced_movement_amount(action)
	var direction: Vector2i = engine._resolved_force_direction(state, "illusion", int(illusion["id"]), action, origin, pushing, amount, sources)
	return engine._force_move_actor(state, "illusion", int(illusion["id"]), direction, amount, sources, pushing)

static func puppet_collision(engine: RefCounted, state: Dictionary, kind: String, id: int, contact: Dictionary, direction: Vector2i, lost: int, pushing: bool) -> bool:
	if kind != "illusion" or effect(engine, state, "force_owned_illusion").is_empty(): return false
	var cause: Dictionary = state.get("damage_context", {}) as Dictionary
	if str(cause.get("actor_kind", "")) != "player" or str(cause.get("source_kind", "")) in ["trap", "surface_fire"]: return false
	var enemy_blocker: Dictionary = {}
	for blocker: Dictionary in contact.get("blockers", []):
		if str(blocker.get("kind", "")) == "enemy": enemy_blocker = blocker; break
	if enemy_blocker.is_empty(): return false
	var illusion: Dictionary = engine._surface_actor(state, "illusion", id).duplicate(true)
	var health: int = int(illusion.get("hp", 0))
	var batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var context: Dictionary = cause.duplicate(true)
	context["source_kind"] = "illusion_force_shatter"
	state["damage_context"] = context
	engine._damage_illusion(state, id, health)
	engine._damage_enemy(state, engine._enemy_index_for_id(state, int(enemy_blocker["id"])), health, false, false, false)
	var blocker: Dictionary = enemy_blocker.duplicate(true)
	blocker["damage"] = health
	Surface.record_event(state, {"kind": "force_collision", "tile": contact.get("blocked_tile", INVALID) - direction, "anchor": illusion.get("pos", INVALID), "blocked_tile": contact.get("blocked_tile", INVALID), "direction": direction, "force": "push" if pushing else "pull", "actor_kind": kind, "id": id, "actor_key": engine._illusion_key(illusion), "lost_tiles": lost, "damage": health, "target_damage": 0, "blocker_kind": "enemy", "blocker_key": blocker.get("key", ""), "blocker_damage": health, "blockers": [blocker], "total_damage": health, "source": cause.duplicate(true)})
	state["damage_context"] = cause
	state["_surface_damage_batch"] = batch
	if not batch: engine._flush_surface_deaths(state)
	return true

# ------------------------------------------------------------------ Copper-Shod
static func owned_outcrop(terrain: Dictionary) -> bool:
	return int(terrain.get("hp", 0)) > 0 and str(terrain.get("owner_kind", "")) == "player" and str(terrain.get("kind", "")) in ["crag_outcrop", "worldspine", "powder_keg"]

static func virtual_conductor(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	if not Cards.illusion_at(engine, state, tile).is_empty(): return true
	for terrain: Dictionary in state.get("terrain", []):
		if owned_outcrop(terrain) and terrain.get("pos", INVALID) == tile: return true
	return false

static func copper_active(engine: RefCounted, state: Dictionary, action: Dictionary, actor_kind: String) -> bool:
	return actor_kind == "player" and engine._action_element(action) == "lightning" and not effect(engine, state, "lightning_owned_construct_relays").is_empty()

## Geometry-only copy: virtual Electrified never repaints or consumes real ground.
## Opening outcrop can_place is limited to conduction; sight remains unchanged.
static func conduction_state(engine: RefCounted, state: Dictionary, action: Dictionary, actor_kind: String) -> Dictionary:
	if not copper_active(engine, state, action, actor_kind): return state
	var copy: Dictionary = state.duplicate(false)
	copy["surfaces"] = (state.get("surfaces", {}) as Dictionary).duplicate(true)
	copy["terrain"] = (state.get("terrain", []) as Array).duplicate(true)
	var tiles: Array[Vector2i]
	for terrain: Dictionary in copy["terrain"]:
		if owned_outcrop(terrain):
			tiles.append(terrain.get("pos", INVALID))
			terrain["hp"] = 0 # allows cardinal conduction across its occupied tile
	for illusion: Dictionary in engine._live_illusions(state): tiles.append(illusion.get("pos", INVALID))
	for tile: Vector2i in tiles:
		var ground: Dictionary = Surface.surface_at(copy, tile).duplicate(true)
		ground["elemental"] = "electrified"
		copy["surfaces"][Surface.tile_key(tile)] = ground
	return copy

# ------------------------------------------------------------------ Mirror Triptych
static func note_attack(engine: RefCounted, state: Dictionary, action: Dictionary) -> void:
	if bool(action.get("_illusion_echo", false)) or str(action.get("_card_id", "")).is_empty(): return
	if str(action.get("type", "")) not in engine.ATTACK_ACTION_TYPES or preload("res://scripts/tempo_rules.gd").is_forced_movement_only(action): return
	var flags: Dictionary = state.get("turn_flags", {}) as Dictionary
	if bool(flags.get(USED, false)): return
	flags[USED] = true
	state["turn_flags"] = flags
	if effect(engine, state, "first_attack_illusion_echo").is_empty(): return
	var echo: Dictionary = {}
	# Only the attack geometry, damage, defense piercing and forces repeat.
	for key: String in ["type", "range", "pattern", "rotate", "chain", "push", "pull", "amount", "pierce", "element", "ignore_los", "force_direction", "_detonate_surface", "_card_element", "_card_id"]:
		if action.has(key): echo[key] = action[key]
	echo["damage"] = engine.final_damage_for_player_action(state, action)
	echo["_illusion_echo"] = true
	echo["_surface_resolved"] = true
	state[PENDING] = echo

static func echo_choices(engine: RefCounted, state: Dictionary) -> Array[Dictionary]:
	var choices: Array[Dictionary]
	if not state.has(PENDING): return choices
	var hero: Vector2i = state["player"]["pos"]
	var illusions: Array[Dictionary] = engine._live_illusions(state)
	illusions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = Paths.manhattan(hero, a["pos"])
		var db: int = Paths.manhattan(hero, b["pos"])
		return int(a["id"]) < int(b["id"]) if da == db else da < db)
	var cap: int = int(effect(engine, state, "first_attack_illusion_echo").get("limit", 3))
	for illusion: Dictionary in illusions:
		if choices.size() >= cap: break
		var action: Dictionary = (state[PENDING] as Dictionary).duplicate(true)
		action["_origin_tile"] = illusion["pos"]
		action[Cards.ORIGIN_CHECKED_KEY] = true
		var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
		var impacts: Dictionary = {}
		for target: Vector2i in targets: impacts[target] = echo_impact(engine, state, action, target)
		var best: Vector2i = INVALID
		var distance: int = 1 << 30
		var best_id: int = 1 << 30
		for enemy: Dictionary in engine._live_enemies(state):
			if not engine.is_enemy_visible_to_player(state, enemy): continue
			var enemy_distance: int = 1 << 30
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				enemy_distance = mini(enemy_distance, Paths.manhattan(illusion["pos"], tile))
			if enemy_distance > distance or (enemy_distance == distance and int(enemy["id"]) >= best_id): continue
			var candidate: Vector2i = INVALID
			var target_distance: int = 1 << 30
			for target: Vector2i in targets:
				if not engine._surface_unit_intersects(enemy, impacts[target]): continue
				var gap: int = Paths.manhattan(illusion["pos"], target)
				if gap < target_distance or (gap == target_distance and (target.y < candidate.y or (target.y == candidate.y and target.x < candidate.x))):
					candidate = target; target_distance = gap
			if candidate != INVALID:
				best = candidate; distance = enemy_distance; best_id = int(enemy["id"])
		if best != INVALID: choices.append({"illusion_id": illusion["id"], "from": illusion["pos"], "target": best, "action": action})
	return choices

## Damage footprint of a legal echo, including areas that reach beyond the
## targeting range. Detonate needs real fuel but its echo neither consumes it
## nor creates ground: only the enemy damage footprint repeats.
static func echo_impact(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	if str(action.get("type", "")) == "aoe": return engine._best_aoe_tiles_for_target(state, action, target, false)
	if str(action.get("type", "")) == "detonate":
		var fuel: String = preload("res://scripts/surface_card_rules.gd").detonate_fuel(action)
		var selected: Array[Vector2i] = engine._surface_action_tiles(state, action, target, action.get("_origin_tile", INVALID))
		if preload("res://scripts/guardian_relic_rules.gd").amount(state, "connected_detonate") > 0 and fuel == "fire":
			var seeds: Array[Vector2i] = selected.duplicate()
			for seed: Vector2i in seeds:
				for tile: Vector2i in preload("res://scripts/guardian_relic_rules.gd").fire_component(state, seed):
					if not selected.has(tile): selected.append(tile)
		for tile: Vector2i in selected:
			if not Surface.has_surface(state, tile, fuel): continue
			if not tiles.has(tile): tiles.append(tile)
			for neighbor: Vector2i in Cards.neighbor_tiles(state, tile):
				if not tiles.has(neighbor): tiles.append(neighbor)
		return tiles
	tiles.append(target)
	return tiles

## Resolve after all actions, choosing again after each echo's damage/movement.
## A no-target illusion does not spend health; only actual echoes count to cap.
static func finish_echoes(engine: RefCounted, state: Dictionary, trace: Dictionary = {}) -> Dictionary:
	var spent: Dictionary = {}
	var cap: int = int(effect(engine, state, "first_attack_illusion_echo").get("limit", 3))
	while state.has(PENDING) and spent.size() < cap:
		var choice: Dictionary = {}
		for candidate: Dictionary in echo_choices(engine, state):
			if not spent.has(candidate["illusion_id"]): choice = candidate; break
		if choice.is_empty(): break
		var id: int = int(choice["illusion_id"])
		spent[id] = true
		var before: Dictionary = state.duplicate(true) if trace.has("echoes") else {}
		var attack_trace: Dictionary = {"chain_hits": []} if trace.has("echoes") else {}
		state = resolve_echo(engine, state, choice, attack_trace)
		if trace.has("echoes"):
			(trace["echoes"] as Array).append({"before": before, "state": state.duplicate(true), "choice": choice, "chain_hits": attack_trace["chain_hits"]})
	state.erase(PENDING)
	return state

static func direct_amount(engine: RefCounted, state: Dictionary, enemy: Dictionary, amount: int) -> int:
	if amount <= 0: return 0
	if int(enemy.get("freeze", 0)) > 0: amount *= Surface.FROZEN_MULTIPLIER
	elif bool(enemy.get("chilled", false)): amount += Data.fixed_point_amount(Surface.CHILLED_BONUS)
	return amount + preload("res://scripts/forced_relic_rules.gd").damage_bonus(engine, state, enemy, amount)

static func half(amount: int) -> int:
	return floori(float(amount) / float(2 * Data.FIXED_POINT_SCALE)) * Data.FIXED_POINT_SCALE

static func resolve_echo(engine: RefCounted, state: Dictionary, choice: Dictionary, trace: Dictionary = {}) -> Dictionary:
	var action: Dictionary = (choice["action"] as Dictionary).duplicate(true)
	action["_enemies_only"] = true
	var previous: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = engine._surface_source(state, action)
	context["source_kind"] = "illusion_echo"
	context["illusion_id"] = choice["illusion_id"]
	state["damage_context"] = context
	if str(action.get("type", "")) == "detonate":
		var impact: Array[Vector2i] = echo_impact(engine, state, action, choice["target"])
		action["type"] = "aoe"
		action["no_conduction"] = true
		state = engine._resolve_board_attack(state, action, choice["target"], "player", -1, trace, impact)
	else:
		state = engine._resolve_board_attack(state, action, choice["target"], "player", -1, trace)
	Surface.record_event(state, {"kind": "illusion_echo", "illusion_id": choice["illusion_id"], "from": choice["from"], "target": choice["target"], "source": context})
	state = engine._damage_illusion(state, int(choice["illusion_id"]), Data.fixed_point_amount(1))
	state["damage_context"] = previous
	return state

static func echo_forces(action: Dictionary) -> Dictionary:
	var forces: Dictionary = {"type": action["type"], "amount": action.get("amount", 0)}
	for key: String in ["push", "pull", "force_direction"]:
		if action.has(key): forces[key] = action[key]
	return forces

# ------------------------------------------------------------------ Storm Crown
static func rebound(engine: RefCounted, state: Dictionary, action: Dictionary, route: Array, trace: Array, capture: bool) -> Dictionary:
	if int(action.get("chain", 0)) <= 0 or effect(engine, state, "chain_rebound").is_empty(): return state
	var previous: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = previous.duplicate(true)
	context["source_kind"] = "chain_rebound"
	state["damage_context"] = context
	# Reverse every route segment, including empty relays, without another plan.
	var at: Vector2i = (route[-1] as Dictionary).get("to", INVALID) if not route.is_empty() else INVALID
	for i: int in range(route.size() - 1, -1, -1):
		var hit: Dictionary = route[i]
		var beat: Dictionary = {"kind": "rebound", "from": at, "to": hit.get("to", INVALID)}
		at = hit.get("to", INVALID)
		if hit.has("enemy_id"):
			var index: int = engine._enemy_index_for_id(state, int(hit["enemy_id"]))
			if index >= 0 and int(engine._surface_actor(state, "enemy", int(hit["enemy_id"])).get("hp", 0)) > 0:
				state = engine._damage_enemy(state, index, half(int(hit.get("damage", 0))), false, false, false)
			beat["enemy_id"] = hit["enemy_id"]
		if bool(hit.get("hidden_direct", false)): continue
		if capture: beat["state"] = state.duplicate(true)
		trace.append(beat)
	state["damage_context"] = previous
	return state
