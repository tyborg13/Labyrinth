extends RefCounted

## Wave-4 family A card mechanics: surfaces, selectors and hit results.
##
## Action types: surface_adjacent_enemies, convert_surface, discharge,
## all_enemies, meteor_marks. Action riders: consume, on_result,
## frozen_splash, ignore_los, shock_all_hits, surface_follows_facing, the
## Detonate options detonate_surface / leave_surface / spare_player and the
## consume_surface per-tile reward. The combat engine calls these helpers from
## small hooks; hover previews run the same resolver on a copy, so preview and
## commit agree. Rules and UI contract: spec/card_mechanics_surfaces.md.

const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const CardKeywordRules = preload("res://scripts/card_keyword_rules.gd")

const INVALID: Vector2i = Vector2i(-999999, -999999)
const TARGETED_TYPES: Array = ["convert_surface", "discharge", "meteor_marks"]
## Types whose `surface` field is their own payload, never a trailing rider.
const OWN_SURFACE_TYPES: Array = ["surface_adjacent_enemies", "convert_surface", "meteor_marks"]
const SELECTORS: Array = ["on_fire", "chilled", "in_light", "on_electrified"]
const METEOR_STATE_KEY: String = "meteor_marks"
const METEOR_IMPACT_EVENT: String = "meteor_impact"

# ------------------------------------------------------------------ targeting

static func needs_target(action: Dictionary) -> bool:
	return str(action.get("type", "")) in TARGETED_TYPES and int(action.get("range", 0)) > 0

static func needs_orientation(engine: RefCounted, action: Dictionary) -> bool:
	return str(action.get("type", "")) == "meteor_marks" and int(action.get("range", 0)) > 0 and engine._aoe_pattern_variants(action).size() > 1

static func source_surface_for(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"convert_surface":
			return Surfaces.kind(str(action.get("surface", "ice")))
		"discharge":
			return "electrified"
	return ""

## Legal tiles for convert_surface / discharge: a visible tile holding the
## source surface within range and line of sight.
static func ground_targets(engine: RefCounted, state: Dictionary, action: Dictionary, origin: Vector2i, visible_lookup: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var surface: String = source_surface_for(action)
	if surface.is_empty():
		return result
	for tile: Vector2i in Paths.diamond_tiles(origin, int(action.get("range", 0)), state.get("grid", [])):
		if not Surfaces.has_surface(state, tile, surface):
			continue
		if not engine.is_tile_visible_to_player(state, tile, visible_lookup):
			continue
		if not engine.combat_line_of_sight(state, origin, tile):
			continue
		result.append(tile)
	return result

static func can_resolve(engine: RefCounted, state: Dictionary, action: Dictionary) -> bool:
	if str(action.get("type", "")) == "all_enemies":
		return not selected_enemy_ids(engine, state, action).is_empty()
	return true

## Post-filters the ordinary target list: a `consume.required` attack is legal
## only against enemies standing on the surface; a Detonate with an authored
## `detonate_surface` is legal only where its pattern covers that fuel.
static func filter_targets(engine: RefCounted, state: Dictionary, action: Dictionary, targets: Array[Vector2i]) -> Array[Vector2i]:
	var consume: Dictionary = consume_spec(action)
	if not consume.is_empty() and bool(consume.get("required", false)):
		var surface: String = Surfaces.kind(str(consume.get("surface", "")))
		var kept: Array[Vector2i]
		for tile: Vector2i in targets:
			var index: int = engine._enemy_index_at_tile(state, tile)
			if index < 0:
				continue
			if Surfaces.unit_on(state, engine._normalized_enemy((state.get("enemies", []) as Array)[index]), surface):
				kept.append(tile)
		return kept
	if str(action.get("type", "")) == "detonate" and action.has("detonate_surface"):
		var fuel: String = detonate_fuel(action)
		var fueled: Array[Vector2i]
		for tile: Vector2i in targets:
			for selected: Vector2i in engine._surface_action_tiles(state, action, tile):
				if Surfaces.has_surface(state, selected, fuel):
					fueled.append(tile)
					break
		return fueled
	return targets

static func filters_targets(action: Dictionary) -> bool:
	var consume: Dictionary = consume_spec(action)
	return (not consume.is_empty() and bool(consume.get("required", false))) or (str(action.get("type", "")) == "detonate" and action.has("detonate_surface"))

# ---------------------------------------------------------- surface placement

## surface_adjacent_enemies: every footprint tile of a visible enemy that is
## orthogonally adjacent to the player (plus the player's tile with include_self).
static func adjacent_enemy_tiles(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var lookup: Dictionary = {}
	var visible_lookup: Dictionary = engine.umbra_visible_tile_lookup(state)
	for enemy: Dictionary in engine._live_enemies(state):
		if not engine.is_enemy_visible_to_player(state, enemy, visible_lookup):
			continue
		for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
			if Paths.manhattan(tile, player_pos) == 1:
				lookup[tile] = true
	if bool(action.get("include_self", false)) and player_pos != INVALID:
		lookup[player_pos] = true
	return engine._sorted_tiles_from_lookup(lookup)

static func apply_surface_adjacent_enemies(engine: RefCounted, state: Dictionary, action: Dictionary) -> Dictionary:
	var surface: String = str(action.get("surface", ""))
	if surface.is_empty():
		return state
	var source: Dictionary = engine._surface_source(state, action)
	# Ordinary placement: replacements follow the board rules and Ice placed
	# under a unit does not Chill it until it enters or starts a turn there.
	for tile: Vector2i in adjacent_enemy_tiles(engine, state, action):
		Surfaces.place(state, tile, surface, source)
	return state

## surface_follows_facing: orient a melee surface_pattern along the attack
## (cardinal from the acting origin to the target); [0, 0] is the target tile
## and [1, 0] the tile behind it.
static func facing_pattern_action(engine: RefCounted, state: Dictionary, action: Dictionary, pattern_action: Dictionary, center: Vector2i) -> Dictionary:
	if not bool(action.get("surface_follows_facing", false)) or center.x < 0:
		return pattern_action
	var origin: Vector2i = action.get("_origin_tile", (state.get("player", {}) as Dictionary).get("pos", INVALID))
	var direction: Vector2i = engine._cardinal_direction(center - origin)
	if direction == Vector2i.ZERO:
		return pattern_action
	var oriented: Dictionary = pattern_action.duplicate(true)
	oriented["aim"] = "facing"
	oriented["orientation"] = direction
	return oriented

# ------------------------------------------------------------- consume riders

static func consume_spec(action: Dictionary) -> Dictionary:
	var spec: Variant = action.get("consume", null)
	if typeof(spec) != TYPE_DICTIONARY or str((spec as Dictionary).get("surface", "")).is_empty():
		return {}
	return spec as Dictionary

static func _hit_is_primary(hit: Dictionary) -> bool:
	return str(hit.get("kind_trace", "")) == "actor" and hit.get("from", INVALID) == hit.get("to", INVALID)

## Per-attack context for consume, on_result, frozen_splash and shock_all_hits.
## Empty (and every hook a no-op) unless the player's action uses one.
static func begin_attack(engine: RefCounted, state: Dictionary, action: Dictionary, impact: Array[Vector2i], actor_kind: String) -> Dictionary:
	if actor_kind != "player":
		return {}
	var consume: Dictionary = consume_spec(action)
	var result: Dictionary = action.get("on_result", {}) as Dictionary if typeof(action.get("on_result", null)) == TYPE_DICTIONARY else {}
	var splash: int = maxi(0, int(action.get("frozen_splash", 0)))
	var shock_all: bool = bool(action.get("shock_all_hits", false))
	if consume.is_empty() and result.is_empty() and splash <= 0 and not shock_all:
		return {}
	var context: Dictionary = {
		"consume": consume,
		"on_result": result,
		"frozen_splash": splash,
		"shock_all_hits": shock_all,
		"pending_rewards": [],
		"result_triggered": "",
		"consumed_tiles": [],
		"bonus_ids": {},
		"hit_snapshot": {},
		"card_id": str(action.get("_card_id", "")),
	}
	if not consume.is_empty() and str(action.get("type", "")) == "aoe":
		# An area consumes the surface on every pattern tile. Enemies that stood
		# on a consumed tile take the bonus.
		var surface: String = Surfaces.kind(str(consume.get("surface", "")))
		var tiles: Array[Vector2i]
		for tile: Vector2i in impact:
			if Surfaces.has_surface(state, tile, surface):
				tiles.append(tile)
		context["area_tiles"] = tiles
		var bonus_ids: Dictionary = {}
		for enemy: Dictionary in engine._live_enemies(state):
			if engine._surface_unit_intersects(enemy, tiles):
				bonus_ids[int(enemy.get("id", -1))] = true
		context["bonus_ids"] = bonus_ids
	return context

static func before_enemy_hit(engine: RefCounted, state: Dictionary, hit_action: Dictionary, hit: Dictionary, enemy_index: int, context: Dictionary) -> Dictionary:
	if context.is_empty():
		return hit_action
	var result: Dictionary = hit_action
	var enemy: Dictionary = engine._normalized_enemy((state.get("enemies", []) as Array)[enemy_index])
	var enemy_id: int = int(enemy.get("id", -1))
	var primary: bool = _hit_is_primary(hit)
	if bool(context.get("shock_all_hits", false)):
		result = result.duplicate(true)
		result["shock"] = maxi(1, int(result.get("shock", 0)))
	var consume: Dictionary = context.get("consume", {}) as Dictionary
	var consumed_here: Array[Vector2i]
	if not consume.is_empty():
		var bonus: bool = false
		if context.has("area_tiles"):
			bonus = (context.get("bonus_ids", {}) as Dictionary).has(enemy_id)
		elif primary or bool(consume.get("per_hit", false)):
			var surface: String = Surfaces.kind(str(consume.get("surface", "")))
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				if Surfaces.has_surface(state, tile, surface):
					consumed_here.append(tile)
			bonus = not consumed_here.is_empty()
		if bonus and int(consume.get("bonus_damage", 0)) != 0:
			result = result.duplicate(true)
			result["damage"] = int(result.get("damage", 0)) + int(consume.get("bonus_damage", 0))
			result["_consume_bonus"] = int(consume.get("bonus_damage", 0))
	context["hit_snapshot"] = {
		"id": enemy_id,
		"primary": primary,
		"frozen_before": int(enemy.get("freeze", 0)) > 0,
		"alive_before": int(enemy.get("hp", 0)) > 0,
		"footprint": engine._enemy_footprint_tiles(enemy),
		"consume_tiles": consumed_here,
	}
	return result

static func after_enemy_hit(engine: RefCounted, state: Dictionary, hit_action: Dictionary, context: Dictionary) -> Dictionary:
	if context.is_empty():
		return state
	var snapshot: Dictionary = context.get("hit_snapshot", {}) as Dictionary
	context["hit_snapshot"] = {}
	if snapshot.is_empty():
		return state
	var consume: Dictionary = context.get("consume", {}) as Dictionary
	if not consume.is_empty():
		var surface: String = Surfaces.kind(str(consume.get("surface", "")))
		var consumed: Array = context.get("consumed_tiles", []) as Array
		# The surface beneath the struck footprint (where it stood) is consumed,
		# even if a rider has since moved the enemy.
		for tile: Vector2i in engine._vector2i_values(snapshot.get("consume_tiles", [])):
			if Surfaces.has_surface(state, tile, surface):
				Surfaces.remove(state, tile, surface, "consume")
				consumed.append(tile)
		context["consumed_tiles"] = consumed
	var enemy: Dictionary = engine._surface_actor(state, "enemy", int(snapshot.get("id", -1)))
	if bool(snapshot.get("primary", false)):
		var spec: Dictionary = context.get("on_result", {}) as Dictionary
		if not spec.is_empty() and str(context.get("result_triggered", "")).is_empty():
			var when: String = str(spec.get("when", ""))
			var froze: bool = not bool(snapshot.get("frozen_before", false)) and int(enemy.get("freeze", 0)) > 0 and int(enemy.get("hp", 0)) > 0
			var killed: bool = bool(snapshot.get("alive_before", false)) and int(enemy.get("hp", 0)) <= 0
			if (when == "froze" and froze) or (when == "killed" and killed):
				context["result_triggered"] = when
				context["result_enemy_id"] = int(snapshot.get("id", -1))
				context["pending_rewards"] = (spec.get("rewards", []) as Array).duplicate(true)
		var splash: int = int(context.get("frozen_splash", 0))
		if splash > 0 and bool(snapshot.get("frozen_before", false)):
			state = _frozen_splash(engine, state, int(snapshot.get("id", -1)), engine._vector2i_values(snapshot.get("footprint", [])), splash)
	return state

## Shatter: N damage to each other enemy orthogonally adjacent to the target's
## footprint. Not a direct hit, so it is never tripled by Freeze.
static func _frozen_splash(engine: RefCounted, state: Dictionary, target_id: int, footprint: Array[Vector2i], amount: int) -> Dictionary:
	var around: Dictionary = {}
	for tile: Vector2i in footprint:
		for direction: Vector2i in Paths.DIRS_4:
			if not footprint.has(tile + direction):
				around[tile + direction] = true
	var around_tiles: Array[Vector2i] = engine._sorted_tiles_from_lookup(around)
	var hit_ids: Array[int]
	for enemy: Dictionary in engine._live_enemies(state):
		if int(enemy.get("id", -1)) != target_id and engine._surface_unit_intersects(enemy, around_tiles):
			hit_ids.append(int(enemy.get("id", -1)))
	for enemy_id: int in hit_ids:
		var index: int = engine._enemy_index_for_id(state, enemy_id)
		if index >= 0:
			state = engine._damage_enemy(state, index, amount, false, false)
	Surfaces.record_event(state, {"kind": "frozen_splash", "target_id": target_id, "enemy_ids": hit_ids, "damage": amount, "tiles": around_tiles, "source": (state.get("damage_context", {}) as Dictionary).duplicate(true)})
	return state

## After all hits, before trailing surface riders: an area consumes its pattern.
static func after_attack_hits(engine: RefCounted, state: Dictionary, context: Dictionary) -> Dictionary:
	if context.is_empty():
		return state
	var consume: Dictionary = context.get("consume", {}) as Dictionary
	if consume.is_empty():
		return state
	var surface: String = Surfaces.kind(str(consume.get("surface", "")))
	var consumed: Array = context.get("consumed_tiles", []) as Array
	for tile: Vector2i in engine._vector2i_values(context.get("area_tiles", [])):
		if Surfaces.has_surface(state, tile, surface):
			Surfaces.remove(state, tile, surface, "consume")
			consumed.append(tile)
	if not consumed.is_empty():
		Surfaces.record_event(state, {"kind": "attack_consumed_surface", "surface": surface, "tiles": engine._vector2i_values(consumed), "bonus_damage": int(consume.get("bonus_damage", 0)), "source": (state.get("damage_context", {}) as Dictionary).duplicate(true)})
	return state

## After deaths flush: on_result rewards use the ordinary reward application
## (draw reshuffles like a card draw). The normal kill card play is separate.
static func finish_attack(engine: RefCounted, state: Dictionary, context: Dictionary) -> Dictionary:
	if context.is_empty() or str(context.get("result_triggered", "")).is_empty():
		return state
	var rewards: Array = []
	for reward_var: Variant in context.get("pending_rewards", []):
		if typeof(reward_var) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = (reward_var as Dictionary).duplicate(true)
		reward["_runtime_amount"] = true
		if str(reward.get("type", "")) == "draw" and not reward.has("safe"):
			reward["safe"] = false
		rewards.append(reward)
	Surfaces.record_event(state, {"kind": "card_result_reward", "when": str(context.get("result_triggered", "")), "enemy_id": int(context.get("result_enemy_id", -1)), "rewards": rewards.duplicate(true), "source": (state.get("damage_context", {}) as Dictionary).duplicate(true)})
	var card_name: String = engine._action_card_name({"_card_id": str(context.get("card_id", ""))})
	return engine._apply_relic_rewards(state, rewards, {"source_name": card_name if not card_name.is_empty() else "Card"})

# ------------------------------------------------------------ Detonate options

static func detonate_fuel(action: Dictionary) -> String:
	return Surfaces.kind(str(action.get("_detonate_surface", action.get("detonate_surface", "fire"))))

## leave_surface: after the blast, each consumed tile and its four passable
## neighbors gain the surface (ordinary placement).
static func leave_detonate_surface(engine: RefCounted, state: Dictionary, action: Dictionary, consumed: Array[Vector2i]) -> Dictionary:
	var surface: String = str(action.get("leave_surface", ""))
	if surface.is_empty() or consumed.is_empty():
		return state
	var lookup: Dictionary = {}
	for tile: Vector2i in consumed:
		lookup[tile] = true
		for direction: Vector2i in Paths.DIRS_4:
			if Paths.is_passable(state.get("grid", []), tile + direction):
				lookup[tile + direction] = true
	var source: Dictionary = engine._surface_source(state, action)
	for tile: Vector2i in engine._sorted_tiles_from_lookup(lookup):
		Surfaces.place(state, tile, surface, source)
	return state

# ---------------------------------------------------------- convert / discharge

## Cardinally connected tiles holding `surface`, starting at `start`, over
## tiles the player can see (the same visible ground conduction uses).
static func connected_surface_tiles(engine: RefCounted, state: Dictionary, start: Vector2i, surface: String) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if not Surfaces.has_surface(state, start, surface):
		return result
	var visible_lookup: Dictionary = engine.umbra_visible_tile_lookup(state)
	var queue: Array[Vector2i]
	queue.append(start)
	var seen: Dictionary = {start: true}
	var cursor: int = 0
	while cursor < queue.size():
		var tile: Vector2i = queue[cursor]
		cursor += 1
		result.append(tile)
		for direction: Vector2i in Paths.DIRS_4:
			var next: Vector2i = tile + direction
			if seen.has(next) or not Surfaces.has_surface(state, next, surface) or not Surfaces.can_place(state, next):
				continue
			if not engine.is_tile_visible_to_player(state, next, visible_lookup):
				continue
			seen[next] = true
			queue.append(next)
	return engine._sorted_tiles_from_lookup(seen)

static func convert_surface_tiles(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var surface: String = source_surface_for(action)
	if bool(action.get("connected", false)):
		return connected_surface_tiles(engine, state, target, surface)
	var single: Array[Vector2i]
	if Surfaces.has_surface(state, target, surface):
		single.append(target)
	return single

static func apply_convert_surface(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = convert_surface_tiles(engine, state, action, target)
	if tiles.is_empty():
		return state
	var to: String = Surfaces.kind(str(action.get("to", "electrified")))
	var source: Dictionary = engine._surface_source(state, action)
	for tile: Vector2i in tiles:
		Surfaces.place(state, tile, to, source)
	var victims: Array[int] = _enemy_ids_touching(engine, state, tiles)
	Surfaces.record_event(state, {"kind": "surface_converted", "surface": to, "from_surface": source_surface_for(action), "tiles": tiles, "enemy_ids": victims, "damage": int(action.get("damage", 0)), "source": source})
	return strike_enemies(engine, state, action, victims, target)

static func discharge_area(engine: RefCounted, state: Dictionary, target: Vector2i) -> Dictionary:
	var network: Array[Vector2i] = connected_surface_tiles(engine, state, target, "electrified")
	var area: Dictionary = {}
	for tile: Vector2i in network:
		area[tile] = true
		for direction: Vector2i in Paths.DIRS_4:
			area[tile + direction] = true
	return {"network": network, "area": engine._sorted_tiles_from_lookup(area)}

static func apply_discharge(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var shape: Dictionary = discharge_area(engine, state, target)
	var network: Array[Vector2i] = engine._vector2i_values(shape.get("network", []))
	if network.is_empty():
		return state
	var area: Array[Vector2i] = engine._vector2i_values(shape.get("area", []))
	var victims: Array[int] = _enemy_ids_touching(engine, state, area)
	state = strike_enemies(engine, state, action, victims, target)
	for tile: Vector2i in network:
		Surfaces.remove(state, tile, "electrified", "discharge")
	Surfaces.record_event(state, {"kind": "surface_discharge", "surface": "electrified", "tiles": network, "area": area, "enemy_ids": victims, "damage": int(action.get("damage", 0)), "source": engine._surface_source(state, action)})
	return state

static func _enemy_ids_touching(engine: RefCounted, state: Dictionary, tiles: Array[Vector2i]) -> Array[int]:
	var ids: Array[int]
	for enemy: Dictionary in engine._live_enemies(state):
		if engine._surface_unit_intersects(enemy, tiles):
			ids.append(int(enemy.get("id", -1)))
	return ids

## One direct card hit per enemy: Expose and damage-vs-status apply, then the
## action's riders (Shock, Expose; an Ice hit Freezes a Chilled target). These
## types are not ATTACK_ACTION_TYPES, so attack relic bonuses and next-attack
## buffs never apply.
static func strike_enemies(engine: RefCounted, state: Dictionary, action: Dictionary, enemy_ids: Array[int], source_tile: Vector2i) -> Dictionary:
	if enemy_ids.is_empty():
		return state
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var hit_action: Dictionary = action.duplicate(true)
	# These are payloads, not trailing surface riders or forced movement.
	for field: String in ["surface", "surface_pattern", "push", "pull"]:
		hit_action.erase(field)
	var printed_damage: int = int(hit_action.get("damage", 0))
	for enemy_id: int in enemy_ids:
		var index: int = engine._enemy_index_for_id(state, enemy_id)
		if index < 0 or int(engine._surface_actor(state, "enemy", enemy_id).get("hp", 0)) <= 0:
			continue
		if printed_damage > 0:
			var damage: int = engine._damage_for_enemy_target(state, hit_action, index)
			state = engine._damage_enemy(state, index, damage, true, engine._action_pierces_defense(hit_action))
			if damage > 0:
				state = engine._consume_enemy_expose(state, index)
		state = engine._apply_action_keywords_to_enemy(state, index, hit_action, source_tile)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	return state

# ------------------------------------------------------------------ selectors

static func selector_matches(engine: RefCounted, state: Dictionary, selector: String, enemy: Dictionary, enemy_index: int) -> bool:
	match selector:
		"on_fire":
			return Surfaces.unit_on(state, enemy, "fire")
		"on_electrified":
			return Surfaces.unit_on(state, enemy, "electrified")
		"chilled":
			return bool(enemy.get("chilled", false)) and int(enemy.get("freeze", 0)) <= 0
		"in_light":
			return CardKeywordRules.state_condition_met(engine, state, "light", enemy_index)
	return false

## all_enemies: every living enemy the player can see (never Umbra-hidden)
## matching the selector, within `range` of the player when one is printed.
static func selected_enemy_ids(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[int]:
	var ids: Array[int]
	var selector: String = str(action.get("selector", ""))
	if not SELECTORS.has(selector):
		return ids
	var reach: int = int(action.get("range", 0))
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var visible_lookup: Dictionary = engine.umbra_visible_tile_lookup(state)
	var enemies: Array = state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		var enemy: Dictionary = engine._normalized_enemy(enemies[index] as Dictionary)
		if int(enemy.get("hp", 0)) <= 0 or not engine.is_enemy_visible_to_player(state, enemy, visible_lookup):
			continue
		if reach > 0 and engine._enemy_distance_to_tile(enemy, player_pos) > reach:
			continue
		if selector_matches(engine, state, selector, enemy, index):
			ids.append(int(enemy.get("id", -1)))
	return ids

static func apply_all_enemies(engine: RefCounted, state: Dictionary, action: Dictionary) -> Dictionary:
	# Select first, then strike: earlier hits never change who was chosen.
	var ids: Array[int] = selected_enemy_ids(engine, state, action)
	if ids.is_empty():
		return state
	Surfaces.record_event(state, {"kind": "selector_strike", "selector": str(action.get("selector", "")), "enemy_ids": ids, "damage": int(action.get("damage", 0)), "element": engine._action_element(action), "source": engine._surface_source(state, action)})
	return strike_enemies(engine, state, action, ids, (state.get("player", {}) as Dictionary).get("pos", INVALID))

# --------------------------------------------------------------- meteor marks

static func meteor_marks(state: Dictionary) -> Array:
	var marks: Variant = state.get(METEOR_STATE_KEY, [])
	return marks as Array if typeof(marks) == TYPE_ARRAY else []

static func meteor_mark_tiles(engine: RefCounted, state: Dictionary) -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for mark_var: Variant in meteor_marks(state):
		if typeof(mark_var) != TYPE_DICTIONARY:
			continue
		for tile: Vector2i in engine._vector2i_values((mark_var as Dictionary).get("tiles", [])):
			lookup[tile] = true
	return engine._sorted_tiles_from_lookup(lookup)

static func place_meteor_marks(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = engine.aoe_tiles_for_player_action(state, action, target)
	if tiles.is_empty():
		return state
	var source: Dictionary = engine._surface_source(state, action)
	var mark: Dictionary = {
		"tiles": tiles,
		"damage": maxi(0, int(action.get("damage", 0))),
		"element": engine._action_element(action),
		"surface": str(action.get("surface", "")),
		"card_id": str(action.get("_card_id", "")),
		"placed_turn": int(state.get("turn", 1)),
		"source": source,
	}
	var marks: Array = meteor_marks(state).duplicate(true)
	marks.append(mark)
	state[METEOR_STATE_KEY] = marks
	Surfaces.record_event(state, {"kind": "meteor_marked", "tiles": tiles, "damage": int(mark["damage"]), "surface": str(mark["surface"]), "source": source})
	return state

## Player turn start, after start-of-turn ground and before the draw: each mark
## deals its damage to every occupant of its tiles (enemies, the player,
## illusions, terrain), then each tile gains its surface; the marks clear.
static func resolve_meteor_marks(engine: RefCounted, state: Dictionary) -> Dictionary:
	var marks: Array = meteor_marks(state).duplicate(true)
	state.erase(METEOR_STATE_KEY)
	if marks.is_empty():
		return state
	var previous_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	for mark_var: Variant in marks:
		if typeof(mark_var) != TYPE_DICTIONARY:
			continue
		var mark: Dictionary = mark_var as Dictionary
		var tiles: Array[Vector2i] = engine._vector2i_values(mark.get("tiles", []))
		var damage: int = maxi(0, int(mark.get("damage", 0)))
		var element: String = str(mark.get("element", "fire"))
		var card_id: String = str(mark.get("card_id", ""))
		var context: Dictionary = {"actor_kind": "player", "actor_id": -1, "card_id": card_id, "action_type": "meteor_marks", "player_card": true, "source_kind": "meteor_marks", "causal_owner": "player", "element": element}
		state["damage_context"] = context
		var before: Dictionary = {
			"player": (state.get("player", {}) as Dictionary).duplicate(true),
			"enemies": (state.get("enemies", []) as Array).duplicate(true),
			"illusions": (state.get("illusions", []) as Array).duplicate(true),
			"defiance_event_revision": int(state.get("defiance_event_revision", 0)),
		}
		var hit_action: Dictionary = {"type": "meteor_marks", "damage": damage, "element": element, "_card_id": card_id}
		var victims: Array[Dictionary]
		for actor: Dictionary in engine._surface_actor_records(state, "all"):
			if engine._surface_unit_intersects(actor["unit"] as Dictionary, tiles):
				victims.append(actor)
		var victim_keys: Array[String]
		for victim: Dictionary in victims:
			victim_keys.append(str(victim.get("key", "")))
			if damage <= 0:
				continue
			if str(victim["kind"]) == "enemy":
				var index: int = engine._enemy_index_for_id(state, int(victim["id"]))
				if index < 0:
					continue
				var amount: int = engine._damage_for_enemy_target(state, hit_action, index)
				state = engine._damage_enemy(state, index, amount, true, false)
				if amount > 0:
					state = engine._consume_enemy_expose(state, index)
			else:
				state = engine._surface_damage_actor(state, str(victim["kind"]), int(victim["id"]), damage, true)
		state = engine._damage_terrain_indices(state, engine._terrain_indices_in_tiles(state, tiles), damage)
		var losses: Array[Dictionary] = engine._enemy_target_losses(before, state)
		losses.append_array(engine._actor_target_losses(before, state))
		Surfaces.record_event(state, {"kind": METEOR_IMPACT_EVENT, "tiles": tiles, "damage": damage, "element": element, "surface": str(mark.get("surface", "")), "victims": victim_keys, "losses": losses, "source": context.duplicate(true)})
		var surface: String = str(mark.get("surface", ""))
		if not surface.is_empty():
			var source: Dictionary = (mark.get("source", context) as Dictionary).duplicate(true)
			for tile: Vector2i in tiles:
				Surfaces.place(state, tile, surface, source)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	state["damage_context"] = previous_context
	return state

## Presentation for the player-turn-start impacts: one status_damage step per
## resolved mark, carrying losses for floating text (like a Retaliate step).
static func turn_start_presentation_steps(engine: RefCounted, before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary]
	if meteor_marks(before_state).is_empty():
		return steps
	var after_sequence_floor: int = int(before_state.get("surface_event_sequence", 0))
	for event_var: Variant in after_state.get("surface_events", []):
		if typeof(event_var) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_var as Dictionary
		if int(event.get("sequence", 0)) <= after_sequence_floor or str(event.get("kind", "")) != METEOR_IMPACT_EVENT:
			continue
		var tiles: Array[Vector2i] = engine._vector2i_values(event.get("tiles", []))
		var losses: Array = (event.get("losses", []) as Array).duplicate(true)
		var impact_keys: Array[String]
		for loss_var: Variant in losses:
			if typeof(loss_var) == TYPE_DICTIONARY:
				impact_keys.append(str((loss_var as Dictionary).get("key", "")))
		steps.append({
			"kind": "status_damage",
			"label": "Impact",
			"text": "Meteorfall",
			"trigger": "meteor_marks",
			"action_type": "meteor_marks",
			"actor_key": "player",
			"actor_name": "Meteorfall",
			"tile": tiles[0] if not tiles.is_empty() else INVALID,
			"focus_tiles": tiles,
			"focus_actor_keys": impact_keys,
			"element": str(event.get("element", "fire")),
			"amount": int(event.get("damage", 0)),
			"enemy_losses": losses,
			"impact_actor_keys": impact_keys,
			"enemies_after": (after_state.get("enemies", []) as Array).duplicate(true),
			"player_after": (after_state.get("player", {}) as Dictionary).duplicate(true),
			"meteor_impact": event.duplicate(true)
		})
	return steps

# --------------------------------------------------------- consume_surface

## consume_surface rewards with `per_tile: true` scale by the tiles removed,
## capped at `max`.
static func scaled_consume_reward(reward: Dictionary, consumed_count: int) -> Dictionary:
	if not bool(reward.get("per_tile", false)):
		return reward
	var scaled: Dictionary = reward.duplicate(true)
	var amount: int = int(reward.get("amount", 0)) * maxi(0, consumed_count)
	if reward.has("max"):
		amount = mini(amount, maxi(0, int(reward.get("max", 0))))
	scaled["amount"] = amount
	scaled.erase("per_tile")
	scaled.erase("max")
	return scaled
