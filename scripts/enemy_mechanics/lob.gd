extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["lob_mark", "lob_land"]

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if str(action.get("type", "")) == "lob_land": return engine._vector2i_values(enemy.get("lob_tiles", []))
	var result: Array[Vector2i]
	var hero: Vector2i = state["player"]["pos"]
	for delta: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var tile: Vector2i = hero + delta
		if tile.y >= 0 and tile.y < state["grid"].size() and tile.x >= 0 and tile.x < state["grid"][tile.y].size(): result.append(tile)
	return result

static func available(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> bool:
	var distance: int = Paths.manhattan(enemy["pos"], state["player"]["pos"])
	if intent.has("requires_hero_within") and distance > int(intent["requires_hero_within"]): return false
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) == "lob_mark" and (distance < int(action["min_range"]) or distance > int(action["max_range"])): return false
		if str(action.get("type", "")) == "lob_land" and (enemy.get("lob_tiles", []) as Array).is_empty(): return false
	return true

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if not handles(action): continue
		var enemy: Dictionary = state["enemies"][index]
		var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
		if disabled or not available(engine, state, enemy, intent): affected.clear()
		return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": engine._vector2i_values([enemy["pos"]]), "route": engine._vector2i_values([enemy["pos"]]), "destination": enemy["pos"], "projected_attack": affected, "attack_available": not affected.is_empty(), "attack_action": action, "attack_action_index": 0, "movement_action_index": -1, "target_tile": enemy.get("lob_center", state["player"]["pos"]), "target_key": "player"}
	return {}

static func damage(enemy: Dictionary, action: Dictionary, tile: Vector2i) -> int:
	return int(action["center_damage"] if tile == enemy.get("lob_center") else action["arm_damage"])

static func landing_action(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Dictionary:
	var intents: Array = engine._scaled_enemy_intents(preload("res://scripts/game_data.gd").enemy_def("slag_mortar")["intents"], int(state.get("room_depth", 1)), state, enemy)
	return engine._intent_by_id(intents, "slag_lands")["actions"][0]

static func presentation_action(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	if str(action.get("type", "")) != "lob_mark": return action
	var result: Dictionary = action.duplicate(true)
	var landing: Dictionary = landing_action(engine, state, enemy)
	for field: String in ["center_damage", "arm_damage"]: result[field] = landing[field]
	return result

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, bleed_steps: Array[Dictionary] = []) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	if str(action["type"]) == "lob_mark":
		if not available(engine, state, enemy, {"actions": [action]}): return state
		enemy["lob_center"] = state["player"]["pos"]
		enemy["lob_tiles"] = tiles(engine, state, enemy, action)
		return state
	if (enemy.get("lob_tiles", []) as Array).is_empty(): return state
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, action, bleed_steps)
	if engine._enemy_cannot_continue_after_bleed(state, index): return state
	var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var hero_before: Dictionary = state["player"].duplicate(true)
	var struck_hero: bool = false
	var struck_illusions: Dictionary = {}
	for actor: Dictionary in engine._surface_actor_records(state):
		var amount: int = 0
		for tile: Vector2i in Surfaces.footprint_tiles(actor["unit"]):
			if affected.has(tile): amount = maxi(amount, damage(enemy, action, tile))
		if amount <= 0: continue
		var hit: Dictionary = action.duplicate(true)
		hit["damage"] = amount
		if str(actor["kind"]) == "enemy":
			state = engine._damage_enemy(state, engine._enemy_index_for_id(state, int(actor["id"])), amount, true, false, false)
		else:
			if str(actor["kind"]) == "player": struck_hero = true
			else: preload("res://scripts/illusion_card_rules.gd").note_enemy_hit(engine, state, struck_illusions, actor, hit)
			state = engine._damage_actor_target(state, actor, amount, false, hit)
	# Reuse blocked-attack, retaliate and illusion-hit rules without card bonuses.
	if struck_hero:
		state = preload("res://scripts/common_relic_rules.gd").blocked_attack(engine, state, int(enemy["id"]), maxi(0, int(hero_before["hp"]) - int(state["player"]["hp"])), maxi(0, int(hero_before["block"]) - int(state["player"]["block"])))
		var hit: Dictionary = action.duplicate(true)
		hit["_origin_tile"] = enemy["pos"]
		state = preload("res://scripts/retaliate_rules.gd").after_enemy_hit(engine, state, int(enemy["id"]), hit, hero_before["pos"])
	if not struck_illusions.is_empty(): state = preload("res://scripts/illusion_card_rules.gd").after_enemy_hit(engine, state, int(enemy["id"]), struck_illusions)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch: state = engine._flush_surface_deaths(state)
	for tile: Vector2i in affected:
		Surfaces.place(state, tile, str(action["surface"]), {"actor_kind": "enemy", "actor_id": enemy["id"], "source_kind": "lob_land", "player_card": false})
	state["enemies"][index].erase("lob_tiles")
	state["enemies"][index].erase("lob_center")
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	if str(action["type"]) == "lob_land" and after["enemies"][index].has("lob_tiles"): return {}
	return {"kind": "aoe" if str(action["type"]) == "lob_land" else "surface", "en04_mechanic": str(action["type"]), "action_type": str(action["type"]), "actor_key": engine._enemy_key(enemy), "actor_name": engine._enemy_display_name(enemy), "enemy_type": enemy["type"], "element": "fire", "sfx_category": "ranged", "from": enemy["pos"], "to": enemy.get("lob_center", before["player"]["pos"]), "tiles": tiles(engine, before, enemy, action), "target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after), "en04_state_after": after.duplicate(true)}
