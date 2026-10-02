extends RefCounted

## Illusion card family (card pool overhaul wave 4, spec/card_mechanics_illusions_terrain.md).
##
## Creation options on the `illusion` action:
##   surface_ring: S        after creation, S on each empty tile next to the illusion
##   on_damaged: {...}      an enemy that damages it takes N (non-direct) and the riders
##   reflect: true          an enemy that damages it takes the same (capped) amount
##   ranged_origin: true    the hero's ranged attacks may fire from its tile
##   place: adjacent_to_enemy (+ expose_adjacent N) / ring_around_self
## Actions: illusion_swap, destroy_illusion; ranged rider also_hits_near_illusions.
## CombatEngine owns every damage, arrival and death path; this module only
## chooses tiles and routes through those engine entry points from small hooks.

const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Data = preload("res://scripts/game_data.gd")
const SurfaceRelics = preload("res://scripts/surface_relic_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")

const INVALID := Vector2i(-1, -1)
const PLACE_ADJACENT_TO_ENEMY: String = "adjacent_to_enemy"
const PLACE_RING_AROUND_SELF: String = "ring_around_self"
const RETORT_EVENT: String = "illusion_retort"
const SWAP_EVENT: String = "illusion_swapped"
const SHATTER_EVENT: String = "illusion_shattered"
const ORIGIN_EVENT: String = "illusion_ranged_origin"
const REFRACTION_TRACE: String = "refraction"
## Set on a ranged action whose origin choice is settled (player tile or one illusion).
const ORIGIN_CHECKED_KEY: String = "_illusion_origin_checked"
## Id of the ranged-origin illusion a ranged attack fires from.
const ORIGIN_ILLUSION_KEY: String = "_ranged_origin_illusion"

# ------------------------------------------------------------------ creation

static func places_adjacent_to_enemy(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "illusion" and str(action.get("place", "")) == PLACE_ADJACENT_TO_ENEMY

static func places_ring_around_self(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "illusion" and str(action.get("place", "")) == PLACE_RING_AROUND_SELF

## Persistent fields copied onto each created illusion.
static func traits_for_action(engine: RefCounted, action: Dictionary) -> Dictionary:
	var traits: Dictionary = {}
	if typeof(action.get("on_damaged", null)) == TYPE_DICTIONARY and not (action["on_damaged"] as Dictionary).is_empty():
		traits["on_damaged"] = (action["on_damaged"] as Dictionary).duplicate(true)
	if bool(action.get("reflect", false)):
		traits["reflect"] = true
	if bool(action.get("ranged_origin", false)):
		traits["ranged_origin"] = true
	if not traits.is_empty():
		traits["source_card_id"] = str(action.get("_card_id", ""))
		traits["source_name"] = engine._action_card_name(action)
	return traits

## The ordinary illusion placement rule: passable, unoccupied, not the hero, visible.
static func tile_is_free(engine: RefCounted, state: Dictionary, tile: Vector2i, occupied: Dictionary, visible_lookup: Dictionary = {}) -> bool:
	if not Paths.is_passable(state.get("grid", []), tile):
		return false
	if tile == (state.get("player", {}) as Dictionary).get("pos", INVALID) or occupied.has(tile):
		return false
	return engine.is_tile_visible_to_player(state, tile, visible_lookup)

## Free tile orthogonally adjacent to the enemy footprint nearest the hero
## (ties: lower y, then lower x). INVALID when the enemy is boxed in.
static func tile_next_to_enemy(engine: RefCounted, state: Dictionary, enemy: Dictionary, occupied: Dictionary = {}, visible_lookup: Dictionary = {}) -> Vector2i:
	if occupied.is_empty():
		occupied = engine._occupied_actor_tiles(state)
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var footprint: Array[Vector2i]
	footprint.assign(engine._enemy_footprint_tiles(enemy))
	var best: Vector2i = INVALID
	var best_distance: int = 1 << 30
	for tile: Vector2i in footprint:
		for direction: Vector2i in Paths.DIRS_4:
			var candidate: Vector2i = tile + direction
			if footprint.has(candidate) or not tile_is_free(engine, state, candidate, occupied, visible_lookup):
				continue
			var distance: int = Paths.manhattan(player_pos, candidate)
			if distance < best_distance or (distance == best_distance and (candidate.y < best.y or (candidate.y == best.y and candidate.x < best.x))):
				best = candidate
				best_distance = distance
	return best

## Mirror Feint targets: every footprint tile of a visible enemy within range
## that has a free tile next to it.
static func adjacent_enemy_targets(engine: RefCounted, state: Dictionary, action: Dictionary, player_pos: Vector2i, visible_lookup: Dictionary) -> Array[Vector2i]:
	var targets: Array[Vector2i]
	var reach: int = int(action.get("range", 0))
	var occupied: Dictionary = engine._occupied_actor_tiles(state)
	for enemy: Dictionary in engine._live_enemies(state):
		if not engine.is_enemy_visible_to_player(state, enemy, visible_lookup):
			continue
		var footprint: Array[Vector2i]
		footprint.assign(engine._enemy_footprint_tiles(enemy))
		var in_range: bool = false
		for tile: Vector2i in footprint:
			if Paths.manhattan(player_pos, tile) <= reach:
				in_range = true
				break
		if not in_range or tile_next_to_enemy(engine, state, enemy, occupied, visible_lookup) == INVALID:
			continue
		for tile: Vector2i in footprint:
			if not targets.has(tile):
				targets.append(tile)
	return targets

## Tiles a resolved `illusion` action creates illusions on, in creation order.
## Shared by resolution, hover ghosts and presentation focus.
static func placement_tiles(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	if places_ring_around_self(action):
		var occupied: Dictionary = engine._occupied_actor_tiles(state)
		var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
		for direction: Vector2i in Paths.DIRS_4:
			if tile_is_free(engine, state, player_pos + direction, occupied):
				tiles.append(player_pos + direction)
		return tiles
	if places_adjacent_to_enemy(action):
		var index: int = engine._enemy_index_at_tile(state, target)
		if index < 0:
			return tiles
		var tile: Vector2i = tile_next_to_enemy(engine, state, engine._normalized_enemy((state.get("enemies", []) as Array)[index]))
		if tile != INVALID:
			tiles.append(tile)
		return tiles
	if target.x >= 0:
		tiles.append(target)
	return tiles

static func resolve_illusion_action(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var health: int = int(action.get("health", action.get("amount", 0)))
	var traits: Dictionary = traits_for_action(engine, action)
	var enemy_index: int = engine._enemy_index_at_tile(state, target) if places_adjacent_to_enemy(action) else -1
	var created: Array[int]
	for tile: Vector2i in placement_tiles(engine, state, action, target):
		var next_id: int = int(state.get("next_illusion_id", 1))
		state = engine._create_illusion(state, tile, health, traits)
		if int(state.get("next_illusion_id", 1)) > next_id:
			created.append(next_id)
	if created.is_empty():
		return state
	var expose: int = int(action.get("expose_adjacent", 0))
	if enemy_index >= 0 and expose > 0:
		state = engine._apply_action_keywords_to_enemy(state, enemy_index, {"type": "illusion", "expose": expose, "_card_id": str(action.get("_card_id", ""))}, (state.get("player", {}) as Dictionary).get("pos", INVALID), true)
	var ring_surface: String = str(action.get("surface_ring", ""))
	if not ring_surface.is_empty():
		var source: Dictionary = engine._surface_source(state, action)
		for illusion_id: int in created:
			var illusion: Dictionary = engine._surface_actor(state, "illusion", illusion_id)
			if int(illusion.get("hp", 0)) <= 0:
				continue
			for tile: Vector2i in ring_tiles(engine, state, illusion.get("pos", INVALID)):
				Surfaces.place(state, tile, ring_surface, source)
	return state

## Empty orthogonal neighbors for surface_ring: floor that can hold ground with
## no hero, enemy, illusion or terrain on it.
static func ring_tiles(engine: RefCounted, state: Dictionary, center: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	if center == INVALID:
		return tiles
	var occupied: Dictionary = engine._occupied_actor_tiles(state)
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	for direction: Vector2i in Paths.DIRS_4:
		var tile: Vector2i = center + direction
		if tile == player_pos or occupied.has(tile) or not Surfaces.can_place(state, tile):
			continue
		tiles.append(tile)
	return tiles

## HUD badges on an illusion with a trait (tooltip names the effect).
static func illusion_badges(illusion: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary]
	var source: String = str(illusion.get("source_name", ""))
	var on_damaged: Dictionary = illusion.get("on_damaged", {}) as Dictionary if typeof(illusion.get("on_damaged", null)) == TYPE_DICTIONARY else {}
	if not on_damaged.is_empty():
		var element: String = str(on_damaged.get("element", "none"))
		var element_text: String = " %s" % element.capitalize() if element not in ["", "none"] else ""
		var text: String = "Enemies that damage this illusion take %d%s damage" % [int(on_damaged.get("damage", 0)), element_text]
		text += " and are Shocked." if int(on_damaged.get("shock", 0)) > 0 else "."
		badges.append({"icon": "shock" if int(on_damaged.get("shock", 0)) > 0 else "retaliate", "fill": Color("2c2a14"), "border": Color("f0d36a"), "icon_tint": Color.WHITE, "tooltip": _badge_tooltip(source, text)})
	if bool(illusion.get("reflect", false)):
		badges.append({"icon": "retaliate", "fill": Color("23202c"), "border": Color("b9a8f0"), "icon_tint": Color.WHITE, "tooltip": _badge_tooltip(source, "Enemies that damage this illusion take that much damage too.")})
	if bool(illusion.get("ranged_origin", false)):
		badges.append({"icon": "ranged", "fill": Color("1d2630"), "border": Color("9beeff"), "icon_tint": Color.WHITE, "tooltip": _badge_tooltip(source, "While it lives, your ranged attacks may fire from this tile.")})
	return badges

static func _badge_tooltip(source: String, text: String) -> String:
	return text if source.is_empty() else "%s\n%s" % [source, text]

# ------------------------------------------------------------------ retorts

## Called for each enemy-attack hit on an illusion before the damage lands.
## `struck` accumulates {illusion_id: {"damage", "tile"}} for this one attack.
static func note_enemy_hit(engine: RefCounted, state: Dictionary, struck: Dictionary, hit: Dictionary, hit_action: Dictionary) -> void:
	var illusion_id: int = int(hit.get("id", -1))
	var illusion: Dictionary = engine._surface_actor(state, "illusion", illusion_id)
	if int(illusion.get("hp", 0)) <= 0:
		return
	if not illusion.has("on_damaged") and not bool(illusion.get("reflect", false)):
		return
	var amount: int = engine._illusion_attack_damage(state, illusion_id, int(hit_action.get("damage", 0)), hit_action)
	if amount <= 0:
		return
	var entry: Dictionary = struck.get(illusion_id, {"damage": 0, "tile": illusion.get("pos", INVALID)}) as Dictionary
	entry["damage"] = int(entry.get("damage", 0)) + amount
	struck[illusion_id] = entry

## Once per enemy attack, inside its damage batch (next to Retaliate).
static func after_enemy_hit(engine: RefCounted, state: Dictionary, attacker_id: int, struck: Dictionary) -> Dictionary:
	var ids: Array = struck.keys()
	ids.sort()
	for id_var: Variant in ids:
		var illusion_id: int = int(id_var)
		var illusion: Dictionary = engine._surface_actor(state, "illusion", illusion_id)
		var entry: Dictionary = struck[id_var] as Dictionary
		var on_damaged: Dictionary = illusion.get("on_damaged", {}) as Dictionary if typeof(illusion.get("on_damaged", null)) == TYPE_DICTIONARY else {}
		if not on_damaged.is_empty():
			state = _retort(engine, state, attacker_id, illusion, entry, "on_damaged", int(on_damaged.get("damage", 0)), str(on_damaged.get("element", "none")), int(on_damaged.get("shock", 0)))
		if bool(illusion.get("reflect", false)):
			state = _retort(engine, state, attacker_id, illusion, entry, "reflect", int(entry.get("damage", 0)), "none", 0)
	return state

static func _retort(engine: RefCounted, state: Dictionary, attacker_id: int, illusion: Dictionary, entry: Dictionary, trait_id: String, amount: int, element: String, shock: int) -> Dictionary:
	var index: int = engine._enemy_index_for_id(state, attacker_id)
	if index < 0:
		return state
	var before: Dictionary = engine._normalized_enemy((state.get("enemies", []) as Array)[index])
	if int(before.get("hp", 0)) <= 0 or (amount <= 0 and shock <= 0):
		return state
	var previous_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = {"actor_kind": "player", "actor_id": -1, "source_kind": RETORT_EVENT, "player_card": false, "causal_owner": "player", "target_enemy_id": attacker_id, "illusion_id": int(illusion.get("id", -1)), "trait": trait_id, "element": element, "card_id": str(illusion.get("source_card_id", ""))}
	state["damage_context"] = context
	if amount > 0:
		state = engine._damage_enemy(state, index, amount, false, false)
	var illusion_tile: Vector2i = entry.get("tile", illusion.get("pos", INVALID))
	if shock > 0:
		state = engine._apply_action_keywords_to_enemy(state, index, {"type": RETORT_EVENT, "shock": shock, "element": element}, illusion_tile, true)
	var after: Dictionary = engine._surface_actor(state, "enemy", attacker_id)
	Surfaces.record_event(state, {
		"kind": RETORT_EVENT,
		"trait": trait_id,
		"enemy_id": attacker_id,
		"actor_key": engine._enemy_key(before),
		"illusion_id": int(illusion.get("id", -1)),
		"illusion_key": engine._illusion_key(illusion),
		"illusion_tile": illusion_tile,
		"source_name": str(illusion.get("source_name", "")),
		"damage": amount,
		"element": element,
		"shock": shock,
		"hp_loss": maxi(0, int(before.get("hp", 0)) - int(after.get("hp", 0))),
		"block_loss": maxi(0, int(before.get("block", 0)) - int(after.get("block", 0))),
		"stoneskin_loss": maxi(0, int(before.get("stoneskin", 0)) - int(after.get("stoneskin", 0))),
		"killed": int(after.get("hp", 0)) <= 0,
		"attacker_before": {"pos": before.get("pos", Vector2i.ZERO), "hp": int(before.get("hp", 0)), "block": int(before.get("block", 0)), "stoneskin": int(before.get("stoneskin", 0))},
		"source": context.duplicate(true)
	})
	state["damage_context"] = previous_context
	return state

static func events_between(before_state: Dictionary, after_state: Dictionary, kind: String = RETORT_EVENT) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var sequence: int = int(before_state.get("surface_event_sequence", 0))
	for event_var: Variant in after_state.get("surface_events", []):
		if typeof(event_var) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_var as Dictionary
		if int(event.get("sequence", 0)) > sequence and str(event.get("kind", "")) == kind:
			result.append(event)
	return result

## One status_damage step per retort, after the enemy's strike step, so the
## attacker's loss animates (same contract as RetaliateRules.presentation_steps).
static func presentation_steps(engine: RefCounted, before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary]
	for event: Dictionary in events_between(before_state, after_state):
		var enemy_id: int = int(event.get("enemy_id", -1))
		var after_enemy: Dictionary = engine._surface_actor(after_state, "enemy", enemy_id)
		var before_values: Dictionary = event.get("attacker_before", {}) as Dictionary
		var tile: Vector2i = after_enemy.get("pos", before_values.get("pos", Vector2i.ZERO))
		var label: String = str(event.get("source_name", ""))
		if label.is_empty():
			label = "Reflection" if str(event.get("trait", "")) == "reflect" else "Illusion"
		var hp_loss: int = int(event.get("hp_loss", 0))
		var block_loss: int = int(event.get("block_loss", 0))
		var stoneskin_loss: int = int(event.get("stoneskin_loss", 0))
		var losses: Array[Dictionary]
		if hp_loss > 0 or block_loss > 0 or stoneskin_loss > 0:
			losses.append({"key": str(event.get("actor_key", "")), "kind": "enemy", "id": enemy_id, "tile": tile, "hp_loss": hp_loss, "block_loss": block_loss, "stoneskin_loss": stoneskin_loss, "amount": hp_loss + block_loss + stoneskin_loss})
		var step: Dictionary = {
			"kind": "status_damage" if not losses.is_empty() else "status",
			"label": label,
			"text": label,
			"trigger": RETORT_EVENT,
			"action_type": RETORT_EVENT,
			"actor_key": str(event.get("actor_key", "")),
			"actor_name": str(Data.enemy_def(str(after_enemy.get("type", ""))).get("name", "Enemy")) if not after_enemy.is_empty() else "Enemy",
			"tile": tile,
			"amount": int(event.get("damage", 0)),
			"enemy_after": after_enemy.duplicate(true),
			"enemies_after": (after_state.get("enemies", []) as Array).duplicate(true),
			"player_after": (after_state.get("player", {}) as Dictionary).duplicate(true),
			"surfaces_after": (after_state.get("surfaces", {}) as Dictionary).duplicate(true),
			"illusion_retort": event.duplicate(true)
		}
		if not losses.is_empty():
			step["enemy_losses"] = losses
			step["impact_actor_keys"] = [str(event.get("actor_key", ""))]
		steps.append(step)
	return steps

# ------------------------------------------------------------------ own-illusion actions

## illusion_swap / destroy_illusion targets: tiles of your live illusions within range.
static func own_illusion_targets(engine: RefCounted, state: Dictionary, action: Dictionary, player_pos: Vector2i, visible_lookup: Dictionary) -> Array[Vector2i]:
	var targets: Array[Vector2i]
	var reach: int = int(action.get("range", 0))
	for illusion: Dictionary in engine._live_illusions(state):
		var tile: Vector2i = illusion.get("pos", INVALID)
		if Paths.manhattan(player_pos, tile) > reach or not engine.is_tile_visible_to_player(state, tile, visible_lookup):
			continue
		targets.append(tile)
	return targets

static func illusion_at(engine: RefCounted, state: Dictionary, tile: Vector2i) -> Dictionary:
	for illusion: Dictionary in engine._live_illusions(state):
		if illusion.get("pos", INVALID) == tile:
			return illusion
	return {}

## Empty Husk: hero and illusion trade tiles; both arrive. transfer_block moves
## all current Block onto the illusion as extra health (hp and max_hp).
static func resolve_swap(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var found: Dictionary = illusion_at(engine, state, target)
	if found.is_empty():
		return state
	var illusion_id: int = int(found.get("id", -1))
	var illusion: Dictionary = engine._surface_actor(state, "illusion", illusion_id)
	var player: Dictionary = state.get("player", {}) as Dictionary
	var origin: Vector2i = player.get("pos", INVALID)
	var loot_before: int = engine._unclaimed_loot_count(state)
	var transferred: int = 0
	if bool(action.get("transfer_block", false)):
		transferred = maxi(0, int(player.get("block", 0)))
		player["block"] = 0
		illusion["hp"] = int(illusion.get("hp", 0)) + transferred
		illusion["max_hp"] = maxi(1, int(illusion.get("max_hp", illusion.get("hp", 1)))) + transferred
	illusion["pos"] = origin
	player["pos"] = target
	state["player"] = player
	engine._collect_loot_at_player(state)
	Surfaces.record_event(state, {"kind": SWAP_EVENT, "illusion_id": illusion_id, "illusion_key": engine._illusion_key(illusion), "from": origin, "to": target, "block_transferred": transferred, "source": engine._surface_source(state, action)})
	state = engine.surface_actor_arrival(state, "illusion", illusion_id, target)
	state = engine.surface_actor_arrival(state, "player", -1, origin)
	state = engine._maybe_refund_loot_play(state, loot_before)
	engine._log(state, "Swapped places with an illusion.")
	return state

## Shattered Reflection: destroy the illusion (normal destruction hooks), then a
## player-card blast on its orthogonal neighbors, then Light on its tile.
static func resolve_destroy(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i, trace: Dictionary = {}) -> Dictionary:
	var found: Dictionary = illusion_at(engine, state, target)
	if found.is_empty():
		return state
	var tile: Vector2i = found.get("pos", INVALID)
	var impact: Array[Vector2i] = neighbor_tiles(state, tile)
	state = engine._damage_illusion(state, int(found.get("id", -1)), int(found.get("hp", 0)))
	Surfaces.record_event(state, {"kind": SHATTER_EVENT, "illusion_id": int(found.get("id", -1)), "tile": tile, "tiles": impact, "source": engine._surface_source(state, action)})
	var damage: int = int(action.get("damage", 0))
	if damage > 0 and not impact.is_empty():
		state = engine._resolve_board_attack(state, blast_action(action, damage), tile, "player", -1, trace, impact)
	if int(action.get("illuminate_radius", 0)) > 0:
		state = engine._create_umbra_light_source(state, tile, {"radius": int(action.get("illuminate_radius", 1)), "duration": int(action.get("illuminate_duration", 1)), "silent": true})
	return state

## Passable orthogonal neighbors of `tile`.
static func neighbor_tiles(state: Dictionary, tile: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for direction: Vector2i in Paths.DIRS_4:
		if Paths.is_passable(state.get("grid", []), tile + direction):
			tiles.append(tile + direction)
	return tiles

## Player-card blast derived from a non-attack action: an `aoe` that only hits
## enemies, never conducts, and takes no next-attack buff (the outer action is
## not an attack; an empty applied-bonus marker blocks it). Ordinary attack
## bonuses, player-state relic mods, Expose and target modifiers apply.
static func blast_action(action: Dictionary, damage: int, extra: Dictionary = {}) -> Dictionary:
	var blast: Dictionary = {"type": "aoe", "damage": damage, "range": 1, "element": str(action.get("element", "none")), "no_conduction": true, "_enemies_only": true, Tempo.APPLIED_KEY: {}}
	for key: String in ["_card_id", "_card_element", "_card_action_types", "_tempo_card_time", "_tempo_plays_spent"]:
		if action.has(key):
			blast[key] = action[key]
	for key_var: Variant in extra.keys():
		if int(extra[key_var]) != 0:
			blast[key_var] = extra[key_var]
	return blast

# ------------------------------------------------------------------ refraction

## Refraction: after the plan's hits, one extra hit on each OTHER visible enemy
## orthogonally next to any of your illusions (each enemy at most once).
static func append_refraction_hits(engine: RefCounted, state: Dictionary, plan: Dictionary) -> void:
	var hits: Array = plan.get("hits", []) as Array
	var hit_ids: Dictionary = {}
	for hit_var: Variant in hits:
		var hit: Dictionary = hit_var as Dictionary
		if str(hit.get("kind", "")) == "enemy":
			hit_ids[int(hit.get("id", -1))] = true
	var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
	var illusions: Array[Dictionary] = engine._live_illusions(state)
	illusions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	var added: bool = false
	for illusion: Dictionary in illusions:
		var origin: Vector2i = illusion.get("pos", INVALID)
		for actor: Dictionary in engine._surface_actor_records(state, "enemies"):
			var enemy_id: int = int(actor.get("id", -1))
			var unit: Dictionary = actor["unit"] as Dictionary
			if hit_ids.has(enemy_id) or not engine.is_enemy_visible_to_player(state, unit, visible):
				continue
			if not _footprint_touches(engine, unit, origin):
				continue
			hit_ids[enemy_id] = true
			var hit: Dictionary = actor.duplicate(true)
			hit["kind_trace"] = REFRACTION_TRACE
			hit["from"] = origin
			hit["to"] = unit.get("pos", INVALID)
			hits.append(hit)
			added = true
	if added:
		plan["refraction"] = true

static func _footprint_touches(engine: RefCounted, unit: Dictionary, tile: Vector2i) -> bool:
	for footprint_tile: Vector2i in engine._enemy_footprint_tiles(unit):
		if Paths.manhattan(footprint_tile, tile) == 1:
			return true
	return false

# ------------------------------------------------------------------ ranged origins

static func ranged_origin_illusions(engine: RefCounted, state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for illusion: Dictionary in engine._live_illusions(state):
		if bool(illusion.get("ranged_origin", false)):
			result.append(illusion)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	return result

## True for a hero ranged attack whose origin is still open while a
## ranged-origin illusion lives. Worldroot (remote) keeps its own origin rule.
static func uses_illusion_origins(engine: RefCounted, state: Dictionary, action: Dictionary) -> bool:
	if str(action.get("type", "")) != "ranged" or action.has("_origin_tile") or bool(action.get(ORIGIN_CHECKED_KEY, false)):
		return false
	if action.has("_enemy_id") or bool(action.get("_movement_pool", false)) or SurfaceRelics.mode_enabled(action, "remote"):
		return false
	return not ranged_origin_illusions(engine, state).is_empty()

static func _origin_candidate(action: Dictionary, illusion: Dictionary) -> Dictionary:
	var candidate: Dictionary = action.duplicate(true)
	candidate["_origin_tile"] = illusion.get("pos", INVALID)
	candidate[ORIGIN_ILLUSION_KEY] = int(illusion.get("id", -1))
	candidate[ORIGIN_CHECKED_KEY] = true
	return candidate

static func _own_origin(action: Dictionary) -> Dictionary:
	var own: Dictionary = action.duplicate(true)
	own[ORIGIN_CHECKED_KEY] = true
	return own

## Union of targets reachable (range + LOS) from the hero or any ranged-origin illusion.
static func ranged_origin_targets(engine: RefCounted, state: Dictionary, action: Dictionary, accepted_limit: int, accept_target: Callable) -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(engine.valid_targets_for_player_action(state, _own_origin(action), accepted_limit, accept_target))
	if accepted_limit > 0 and result.size() >= accepted_limit:
		return result
	for illusion: Dictionary in ranged_origin_illusions(engine, state):
		for tile: Vector2i in engine.valid_targets_for_player_action(state, _origin_candidate(action, illusion), 0, accept_target):
			if not result.has(tile):
				result.append(tile)
				if accepted_limit > 0 and result.size() >= accepted_limit:
					return result
	return result

## The origin that makes `target` legal: the hero's tile first, then illusions by id.
static func action_with_origin(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	if engine.valid_targets_for_player_action(state, _own_origin(action)).has(target):
		return action
	for illusion: Dictionary in ranged_origin_illusions(engine, state):
		var candidate: Dictionary = _origin_candidate(action, illusion)
		if engine.valid_targets_for_player_action(state, candidate).has(target):
			return candidate
	return action

static func record_ranged_origin(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> void:
	if not action.has(ORIGIN_ILLUSION_KEY):
		return
	Surfaces.record_event(state, {"kind": ORIGIN_EVENT, "illusion_id": int(action[ORIGIN_ILLUSION_KEY]), "from": action.get("_origin_tile", INVALID), "target": target, "source": engine._surface_source(state, action)})
