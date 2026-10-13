extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Data = preload("res://scripts/game_data.gd")

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "tether_beam"

static func action_for(intent: Dictionary) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if handles(action): return action
	return {}

# A beam ignores intervening actors, but never impassable floor or terrain.
static func beam_tiles(engine: RefCounted, state: Dictionary, start: Vector2i, end: Vector2i, limit: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	var distance: int = Paths.manhattan(start, end)
	if distance < 1 or distance > limit or (start.x != end.x and start.y != end.y): return tiles
	var direction := Vector2i(signi(end.x - start.x), signi(end.y - start.y))
	for offset: int in range(1, distance):
		var tile: Vector2i = start + direction * offset
		if not Paths.is_passable(state.get("grid", []), tile) or engine._terrain_index_at_tile(state, tile) >= 0:
			tiles.clear()
			return tiles
		tiles.append(tile)
	return tiles

static func aligned(engine: RefCounted, state: Dictionary, start: Vector2i, end: Vector2i, limit: int) -> bool:
	return (Paths.manhattan(start, end) == 1 and Paths.manhattan(start, end) <= limit) or not beam_tiles(engine, state, start, end, limit).is_empty()

static func choose(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, movement_disabled: bool = false) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var start: Vector2i = enemy["pos"]
	var hero: Vector2i = state["player"]["pos"]
	var limit: int = int(action.get("max_length", 6))
	var partners: Array[Dictionary]
	for other: Dictionary in state.get("enemies", []):
		if int(other.get("hp", 0)) > 0 and other.get("id") != enemy.get("id") and str(other.get("type", "")) == str(action.get("partner", "arc_thrall")):
			partners.append(other)
	partners.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	# Existing alignment wins: the authored move is only for an unaligned pair.
	for partner: Dictionary in partners:
		if aligned(engine, state, start, partner["pos"], limit):
			return {"partner_id": partner["id"], "path": engine._vector2i_values([start]), "destination": start}
	var best: Dictionary = {}
	var best_hero: bool = false
	var records: Array[Dictionary] = engine._enemy_actual_path_records(state, enemy, 0 if movement_disabled else int(action.get("align_move", 3)))
	for record: Dictionary in records:
		var destination: Vector2i = record["tile"]
		for partner: Dictionary in partners:
			if not aligned(engine, state, destination, partner["pos"], limit): continue
			var contains_hero: bool = beam_tiles(engine, state, destination, partner["pos"], limit).has(hero)
			if best.is_empty() or (contains_hero and not best_hero) or (contains_hero == best_hero and int(record["steps"]) < int(best["steps"])):
				best = {"partner_id": partner["id"], "path": record["path"], "destination": destination, "steps": record["steps"]}
				best_hero = contains_hero
	return best

static func available(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary) -> bool:
	var action: Dictionary = action_for(intent)
	return action.is_empty() or not choose(engine, state, index, action).is_empty()

static func commit(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var action: Dictionary = action_for(intent)
	if action.is_empty(): return intent
	var index: int = engine._enemy_index_for_id(state, int(enemy.get("id", -1)))
	if index < 0: return intent
	var result: Dictionary = intent.duplicate(true)
	result["tether_plan"] = choose(engine, state, index, action)
	return result

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, movement_disabled: bool = false, attack_disabled: bool = false) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var action: Dictionary = action_for(intent)
	var held: Dictionary = intent.get("tether_plan", {}) if intent.has("tether_plan") else choose(engine, state, index, action, movement_disabled)
	var start: Vector2i = enemy["pos"]
	var path: Array[Vector2i] = engine._vector2i_values(held.get("path", [start]))
	if path.is_empty() or path[0] != start or movement_disabled: path = engine._vector2i_values([start])
	# A newly occupied approach cannot be walked through during preview or commit.
	var safe_path: Array[Vector2i] = engine._vector2i_values([start])
	var blockers: Dictionary = engine._enemy_path_blockers(state, enemy, true, false)
	for tile: Vector2i in path.slice(1):
		if not engine._enemy_can_occupy_anchor(state, enemy, tile, blockers): break
		safe_path.append(tile)
	var destination: Vector2i = safe_path.back()
	var partner_index: int = engine._enemy_index_for_id(state, int(held.get("partner_id", -1)))
	var tiles: Array[Vector2i]
	var partner_pos: Vector2i = engine.INVALID_TILE
	var cancelled: bool = true
	if partner_index >= 0 and int(state["enemies"][partner_index].get("hp", 0)) > 0:
		partner_pos = state["enemies"][partner_index]["pos"]
		cancelled = not aligned(engine, state, destination, partner_pos, int(action.get("max_length", 6)))
		if not cancelled and not attack_disabled: tiles = beam_tiles(engine, state, destination, partner_pos, int(action.get("max_length", 6)))
	if cancelled: safe_path = engine._vector2i_values([start]); destination = start
	return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": safe_path, "route": safe_path, "destination": destination,
		"movement_action_index": 0, "attack_action_index": 0, "attack_action": action, "target": {}, "target_key": "", "target_tile": engine.INVALID_TILE,
		"projected_attack_target": partner_pos, "projected_attack": tiles, "attack_available": not cancelled and not attack_disabled,
		"partner_id": int(held.get("partner_id", -1)), "cancelled": cancelled, "movement_disabled": movement_disabled, "attack_disabled": attack_disabled}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var current: Dictionary = plan(engine, state, index, state["enemies"][index]["intent"], bool(context.get("movement_disabled", false)), bool(context.get("attack_disabled", false)))
	context["tether_plan"] = current
	if bool(current["cancelled"]): return state
	var path: Array[Vector2i] = engine._vector2i_values(current["path"])
	if path.size() > 1:
		state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "move_toward"}, bleed_steps)
		if engine._enemy_cannot_continue_after_bleed(state, index): return state
		state = engine._move_enemy_along_planned_path(state, index, path, context, int(action.get("align_move", 3)))
		context["move_state"] = state.duplicate(true)
	if bool(current.get("attack_disabled", false)) or int(state["enemies"][index].get("hp", 0)) <= 0: return state
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "ranged"}, bleed_steps)
	if engine._enemy_cannot_continue_after_bleed(state, index): return state
	var partner_index: int = engine._enemy_index_for_id(state, int(current["partner_id"]))
	if partner_index < 0 or int(state["enemies"][partner_index].get("hp", 0)) <= 0: return state
	var origin: Vector2i = state["enemies"][index]["pos"]
	var tiles: Array[Vector2i] = beam_tiles(engine, state, origin, state["enemies"][partner_index]["pos"], int(action.get("max_length", 6)))
	context["resolved_tiles"] = tiles
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": state["enemies"][index]["id"], "source_kind": "direct_attack", "player_card": false}
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var hero_before: Dictionary = state["player"].duplicate(true)
	var struck_player: bool = false
	var struck_illusions: Dictionary = {}
	for actor: Dictionary in engine._surface_actor_records(state):
		if not engine._surface_unit_intersects(actor["unit"], tiles): continue
		if str(actor["kind"]) == "enemy":
			var target_index: int = engine._enemy_index_for_id(state, int(actor["id"]))
			state = engine._damage_enemy(state, target_index, int(action["damage"]), true, false, false)
			state = engine._apply_action_keywords_to_enemy(state, target_index, action, origin, false)
		else:
			if str(actor["kind"]) == "player": struck_player = true
			elif str(actor["kind"]) == "illusion": preload("res://scripts/illusion_card_rules.gd").note_enemy_hit(engine, state, struck_illusions, actor, action)
			state = engine._damage_actor_target(state, actor, int(action["damage"]), false, action)
			state = engine._apply_action_keywords_to_target(state, actor, action, origin)
	if struck_player:
		state = preload("res://scripts/common_relic_rules.gd").blocked_attack(engine, state, int(state["enemies"][index]["id"]), maxi(0, int(hero_before["hp"]) - int(state["player"]["hp"])), maxi(0, int(hero_before["block"]) - int(state["player"]["block"])))
		var hit_action: Dictionary = action.duplicate(true)
		hit_action["_origin_tile"] = origin
		state = preload("res://scripts/retaliate_rules.gd").after_enemy_hit(engine, state, int(state["enemies"][index]["id"]), hit_action, hero_before["pos"])
	if not struck_illusions.is_empty(): state = preload("res://scripts/illusion_card_rules.gd").after_enemy_hit(engine, state, int(state["enemies"][index]["id"]), struck_illusions)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch: state = engine._flush_surface_deaths(state)
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary) -> Dictionary:
	var plan_value: Dictionary = context.get("tether_plan", plan(engine, before, index, before["enemies"][index]["intent"]))
	var cancelled: bool = bool(plan_value.get("cancelled", true)) or bool(plan_value.get("attack_disabled", false)) or int(after["enemies"][index].get("hp", 0)) <= 0
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	losses.append_array(engine._enemy_target_losses(before, after))
	var step: Dictionary = {"kind": "aoe", "action_type": "tether_beam", "element": "lightning", "actor_key": engine._enemy_key(before["enemies"][index]),
		"actor_name": Data.enemy_def("arc_thrall")["name"], "from": after["enemies"][index]["pos"], "to": plan_value.get("projected_attack_target", engine.INVALID_TILE),
		"tiles": context.get("resolved_tiles", []), "target_losses": losses, "impact_actor_keys": engine._target_loss_keys(losses),
		"cancelled": cancelled, "label": "Cancelled" if cancelled else "Tether",
		"en03_after": snapshot(after)}
	if context.has("move_state"):
		step["move_step"] = engine._enemy_action_step_base(before, context["move_state"], index, {"type": "move_toward"}, context)
		step["move_after"] = snapshot(context["move_state"])
	return step

static func snapshot(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["player", "enemies", "surfaces", "traps", "terrain", "loot"]:
		if state.has(key): result[key] = state[key].duplicate(true)
	return result
