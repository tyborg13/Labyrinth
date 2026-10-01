extends RefCounted
class_name DragonTrophyRules

const Surface = preload("res://scripts/board_surface_rules.gd")
const Path = preload("res://scripts/path_utils.gd")
const INVALID: Vector2i = Vector2i(-999999, -999999)
const TIME_RESERVE: String = "relic_time_reserve"

# Shared data-driven hooks. They accept already-resolved effects so GameData can
# reuse the cost transform without a preload cycle or mutable preview state.
static func card_with_time_reserve(card: Dictionary, state: Dictionary, effects: Array) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	if result.is_empty(): return result
	var cost: int = maxi(1, int(result.get("time", 5)))
	var spends: Dictionary = {}
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) != "element_time_reserve" or str(card.get("element", "")) == str(effect.get("element", "")): continue
		var id: String = str(effect.get("relic_id", ""))
		var held: int = reserve(state, id, int(effect.get("capacity", 3)))
		var spent: int = mini(held, maxi(0, cost - 1))
		if spent <= 0: continue
		spends[id] = spent
		cost -= spent
	if not spends.is_empty():
		result["_time_reserve_base"] = int(result.get("time", 5))
		result["_time_reserve_spends"] = spends
		result["time"] = cost
	return result

static func reserve(state: Dictionary, relic_id: String, capacity: int = 3) -> int:
	return clampi(int((state.get(TIME_RESERVE, {}) as Dictionary).get(relic_id, 0)), 0, maxi(0, capacity))

static func finish_card_time(state: Dictionary, card: Dictionary, card_id: String, effects: Array, actual_time: int, play_context: Dictionary) -> void:
	if str(play_context.get("play_mode", "play")) != "play": return
	var balances: Dictionary = (state.get(TIME_RESERVE, {}) as Dictionary).duplicate(true)
	var flags: Dictionary = (state.get("turn_flags", {}) as Dictionary).duplicate(true)
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) != "element_time_reserve": continue
		var id: String = str(effect.get("relic_id", ""))
		var capacity: int = maxi(0, int(effect.get("capacity", 3)))
		var before: int = reserve(state, id, capacity)
		var spent: int = mini(before, int((card.get("_time_reserve_spends", {}) as Dictionary).get(id, 0))) if actual_time > 0 else 0
		var after: int = before - spent
		var gained: int = 0
		var key: String = "time_reserve:%s" % id
		if str(card.get("element", "")) == str(effect.get("element", "")) and not bool(flags.get(key, false)):
			gained = mini(maxi(0, int(effect.get("amount", 3))), capacity - after)
			after += gained
			flags[key] = true
		balances[id] = after
		if spent > 0 or gained > 0:
			Surface.record_event(state, {"kind":"relic_time_reserve", "relic_id":id, "card_id":card_id, "gained":gained, "spent":spent, "remaining":after, "card_time_paid":actual_time, "source":{"kind":"relic","actor_kind":"player","relic_id":id}})
	state[TIME_RESERVE] = balances
	state["turn_flags"] = flags

static func relay_effect(engine: RefCounted, state: Dictionary, action: Dictionary) -> Dictionary:
	if str(action.get("type", "")) != "ranged" or action.has("_enemy_id"): return {}
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) == "surface_ranged_relay": return effect
	return {}

static func route(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i, visible: Dictionary = {}) -> Dictionary:
	var origin: Vector2i = action.get("_origin_tile", (state.get("player", {}) as Dictionary).get("pos", INVALID))
	var reach: int = maxi(0, int(action.get("range", 1)))
	# `ignore_los` (Skybolt, Thunderstone) reaches any visible tile in range.
	if Path.manhattan(origin, target) <= reach and (engine.combat_line_of_sight(state, origin, target) or (bool(action.get("ignore_los", false)) and engine.is_tile_visible_to_player(state, target, visible))):
		return {"from":origin,"to":target}
	var effect: Dictionary = relay_effect(engine, state, action)
	if effect.is_empty() or not engine.is_tile_visible_to_player(state, target, visible): return {}
	var relays: Array[Vector2i] = Surface.tiles(state, str(effect.get("surface", "electrified")))
	relays.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		var da: int = Path.manhattan(origin,a) + Path.manhattan(a,target)
		var db: int = Path.manhattan(origin,b) + Path.manhattan(b,target)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x)
	)
	for relay: Vector2i in relays:
		if relay == origin or relay == target or not Surface.can_place(state, relay): continue
		if Path.manhattan(origin, relay) > reach or Path.manhattan(relay,target) > reach: continue
		if not engine.is_tile_visible_to_player(state, relay, visible): continue
		if not engine.combat_line_of_sight(state,origin,relay) or not engine.combat_line_of_sight(state,relay,target): continue
		return {"from":origin,"relay":relay,"to":target,"relic_id":effect.get("relic_id","")}
	return {}

# Every footprint square remains clickable. Select a legal visible contact tile
# for that actor, preferring any direct contact before considering one relay.
static func route_for_target(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var contacts: Array[Vector2i]
	contacts.append(target)
	var index: int = engine._enemy_index_at_tile(state,target)
	if index >= 0:
		for tile: Vector2i in engine._enemy_footprint_tiles((state.get("enemies",[]) as Array)[index]):
			if not contacts.has(tile): contacts.append(tile)
	var fallback: Dictionary = {}
	var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
	for tile: Vector2i in contacts:
		var candidate: Dictionary = route(engine,state,action,tile,visible)
		if candidate.is_empty(): continue
		if not candidate.has("relay"): return candidate
		if fallback.is_empty(): fallback = candidate
	return fallback

static func prepare_relay(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	if relay_effect(engine,state,action).is_empty(): return action
	var selected: Dictionary = route_for_target(engine,state,action,target)
	if not selected.has("relay"): return action
	var result: Dictionary = action.duplicate(true)
	result["_ranged_relay"] = selected
	result["_origin_tile"] = selected["relay"]
	Surface.record_event(state,{"kind":"relic_ranged_relay","relic_id":selected.get("relic_id",""),"from":selected["from"],"relay":selected["relay"],"target":selected["to"],"range":int(action.get("range",1)),"source":engine._surface_source(state,action)})
	return result
