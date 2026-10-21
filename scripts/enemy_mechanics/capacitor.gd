extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Snapshots = preload("res://scripts/enemy_mechanics/tether.gd")
const MAX_CHARGE: int = 3
const HOP_SECONDS: float = 0.12

static func is_capacitor(enemy: Dictionary) -> bool:
	return str(enemy.get("type", "")) == "storm_capacitor"

static func immobile(enemy: Dictionary) -> bool:
	return bool(Data.enemies().get(str(enemy.get("type", "")), {}).get("immobile", false))

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["gain_charge", "chain_discharge", "reset_charge"]

static func handles_intent(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if handles(action): return true
	return false

static func threshold(state: Dictionary, enemy: Dictionary) -> int:
	if not preload("res://scripts/warband_combat_rules.gd").order(state, enemy, "dynamo_tether"): return MAX_CHARGE
	var thralls: int = 0
	for follower: Dictionary in state.get("enemies", []):
		if str(follower.get("type", "")) == "arc_thrall" and not bool(follower.get("is_leader", false)) and int(follower.get("hp", 0)) > 0: thralls += 1
	return 2 if thralls >= 2 else MAX_CHARGE

static func effective_intent(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if not preload("res://scripts/warband_combat_rules.gd").order(state, enemy, "dynamo_tether"): return intent
	var engine := preload("res://scripts/combat_engine.gd").new()
	return choose(enemy, engine._scaled_enemy_intents(Data.enemy_def("storm_capacitor")["intents"], int(state.get("room_depth", 1)), state, enemy), state)

static func choose(enemy: Dictionary, intents: Array, state: Dictionary = {}) -> Dictionary:
	var id: String = "discharge" if int(enemy.get("charge", 0)) >= threshold(state, enemy) else "charge"
	for intent: Dictionary in intents:
		if str(intent.get("id", "")) == id: return intent.duplicate(true)
	return {}

static func grounded(engine: RefCounted, enemy: Dictionary, before_shock: int, state: Dictionary) -> void:
	if not is_capacitor(enemy) or before_shock > 0 or int(enemy.get("shock", 0)) <= 0: return
	enemy["charge"] = maxi(0, int(enemy.get("charge", 0)) - int(Data.enemy_def("storm_capacitor")["charge"]["lose_on_shock"]))
	enemy["grounded_seq"] = int(enemy.get("grounded_seq", 0)) + 1
	enemy["intent"] = choose(enemy, engine._scaled_enemy_intents(Data.enemy_def("storm_capacitor")["intents"], int(state.get("room_depth", 1)), state, enemy), state)

# Source is excluded just as it is in the existing enemy Chain resolver.
# First reach is ordinary Manhattan range; hops include the eight neighbours.
static func targets(engine: RefCounted, state: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(state.get("player", {}).get("hp", 0)) > 0:
		result.append({"kind": "player", "key": "player", "id": -1, "pos": state["player"]["pos"], "unit": state["player"]})
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and enemy["id"] != state["enemies"][index]["id"]:
			result.append({"kind": "enemy", "key": engine._enemy_key(enemy), "id": enemy["id"], "pos": enemy["pos"], "unit": enemy})
	return result

static func nearest(engine: RefCounted, state: Dictionary, index: int, origin: Vector2i, visited: Dictionary, reach: int, adjacent: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = 2147483647
	for target: Dictionary in targets(engine, state, index):
		if visited.has(target["key"]): continue
		var tile: Vector2i = engine._closest_enemy_tile_to(target["unit"], origin) if target["kind"] == "enemy" else target["pos"]
		var delta: Vector2i = tile - origin
		var distance: int = Paths.manhattan(origin, tile)
		if (maxi(absi(delta.x), absi(delta.y)) > 1 if adjacent else distance > reach): continue
		var candidate: Dictionary = target.duplicate(true)
		candidate["pos"] = tile
		if distance < best_distance or (distance == best_distance and tie_precedes(candidate, best)):
			best = candidate
			best_distance = distance
	return best

# Director feedback 1: the same precedence applies to the first hit and jumps.
static func tie_precedes(candidate: Dictionary, current: Dictionary) -> bool:
	if current.is_empty(): return true
	if (candidate["kind"] == "player") != (current["kind"] == "player"): return candidate["kind"] == "player"
	var candidate_hp: int = int(candidate["unit"]["hp"])
	var current_hp: int = int(current["unit"]["hp"])
	if candidate_hp != current_hp: return candidate_hp < current_hp
	var candidate_tile: Vector2i = candidate["pos"]
	var current_tile: Vector2i = current["pos"]
	return candidate_tile.y < current_tile.y or (candidate_tile.y == current_tile.y and candidate_tile.x < current_tile.x)

static func chain(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, resolve_hits: bool = false) -> Array[Dictionary]:
	var hits: Array[Dictionary]
	var visited: Dictionary = {}
	var origin: Vector2i = state["enemies"][index]["pos"]
	for hop: int in range(int(action.get("jumps", 3)) + 1):
		var target: Dictionary = nearest(engine, state, index, origin, visited, int(action.get("first_range", 4)), hop > 0)
		if target.is_empty(): break
		visited[target["key"]] = true
		var damage: int = maxi(0, int(action.get("damage", 6)) - hop * int(action.get("falloff", 1)))
		var before: Dictionary = state.duplicate(true)
		if resolve_hits:
			if target["kind"] == "enemy":
				state = engine._damage_enemy(state, engine._enemy_index_for_id(state, int(target["id"])), damage, true, false, false)
			else:
				state = engine._damage_actor_target(state, target, damage, false, action)
				state = preload("res://scripts/common_relic_rules.gd").blocked_attack(engine, state, int(state["enemies"][index]["id"]), maxi(0, int(before["player"]["hp"]) - int(state["player"]["hp"])), maxi(0, int(before["player"]["block"]) - int(state["player"]["block"])))
				state = preload("res://scripts/retaliate_rules.gd").after_enemy_hit(engine, state, int(state["enemies"][index]["id"]), action, target["pos"])
		var losses: Array[Dictionary] = engine._actor_target_losses(before, state)
		losses.append_array(engine._enemy_target_losses(before, state))
		hits.append({"from": origin, "to": target["pos"], "target_key": target["key"], "damage": damage, "target_losses": losses, "state": state.duplicate(true)})
		origin = target["pos"]
		if resolve_hits and (int(state["player"]["hp"]) <= 0 or int(state["enemies"][index]["hp"]) <= 0): break
	return hits

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, attack_disabled: bool) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var action: Dictionary = intent["actions"][0]
	var hits: Array[Dictionary]
	var tiles: Array[Vector2i]
	if str(action.get("type", "")) == "chain_discharge" and not attack_disabled:
		# Use the same resolver on a copy, including deaths/retaliation changing later hops.
		var prediction: Dictionary = state.duplicate(true)
		prediction["damage_context"] = {"actor_kind": "enemy", "actor_id": enemy["id"], "source_kind": "direct_attack", "player_card": false}
		hits = chain(engine, prediction, index, action, true)
		for hit: Dictionary in hits: tiles.append(hit["to"])
	var path: Array[Vector2i] = engine._vector2i_values([enemy["pos"]])
	return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": path, "route": path, "destination": enemy["pos"],
		"attack_action_index": 0, "movement_action_index": -1, "attack_action": action, "projected_attack": tiles,
		"projected_attack_target": tiles[0] if not tiles.is_empty() else engine.INVALID_TILE, "target_key": "player" if tiles.has(state["player"]["pos"]) else "", "chain_hits": hits, "attack_available": not tiles.is_empty()}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	match str(action["type"]):
		"gain_charge": state["enemies"][index]["charge"] = mini(MAX_CHARGE, int(state["enemies"][index].get("charge", 0)) + int(action["amount"]))
		"reset_charge": state["enemies"][index]["charge"] = 0
		"chain_discharge":
			state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "ranged"}, bleed_steps)
			if engine._enemy_cannot_continue_after_bleed(state, index): return state
			var hits: Array[Dictionary] = chain(engine, state, index, action, true)
			context["chain_hits"] = hits
			if not hits.is_empty(): state = hits.back()["state"].duplicate(true)
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary) -> Dictionary:
	if str(action["type"]) == "reset_charge": return {"kind": "intent_refresh", "actor_key": engine._enemy_key(after["enemies"][index]), "intent": after["enemies"][index]["intent"].duplicate(true), "en06_after": Snapshots.snapshot(after)}
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	losses.append_array(engine._enemy_target_losses(before, after))
	return {"kind": "ranged" if str(action["type"]) == "chain_discharge" else "status", "action_type": action["type"],
		"actor_key": engine._enemy_key(before["enemies"][index]), "actor_name": Data.enemy_def("storm_capacitor")["name"],
		"label": "Arc Burst" if str(action["type"]) == "chain_discharge" else "Charge", "element": "lightning", "tile": after["enemies"][index]["pos"],
		"chain_hits": context.get("chain_hits", []), "target_losses": losses, "enemy_after": after["enemies"][index].duplicate(true), "en06_after": Snapshots.snapshot(after)}

static func grounded_targets(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for enemy: Dictionary in after.get("enemies", []):
		if not is_capacitor(enemy): continue
		for previous: Dictionary in before.get("enemies", []):
			if previous["id"] == enemy["id"] and int(enemy.get("grounded_seq", 0)) > int(previous.get("grounded_seq", 0)):
				result.append({"id": enemy["id"], "tile": enemy["pos"]})
	return result
