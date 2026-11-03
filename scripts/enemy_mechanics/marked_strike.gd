extends RefCounted

# One delayed mark/strike primitive. Old action names and held fields are stable
# save/analytics aliases. Geometry and sight are authored in data/enemies.json.
# The two landing hit policies deliberately preserve their original reactions.
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["icefall_mark", "icefall_land", "lob_mark", "lob_land"]

static func is_lob(action: Dictionary) -> bool:
	return str(action.get("type", "")).begins_with("lob_")

static func _held_field(action: Dictionary) -> String:
	return "lob_tiles" if is_lob(action) else "icefall_tiles"

# Missing dials in old saves use the current authored pattern. Never replace
# a saved resolved damage/range value with a fresh scaled definition.
static func _pattern(action: Dictionary) -> Dictionary:
	if action.has("shape") and action.has("tile_filter") and action.has("ignore_line_of_sight"): return action
	var type: String = "slag_mortar" if is_lob(action) else "hoarfrost_seer"
	var id: String = "lob_slag" if is_lob(action) else "icefall"
	for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def(type)["intents"]:
		if str(intent["id"]) == id:
			var result: Dictionary = intent["actions"][0].duplicate(true)
			result.merge(action, true)
			return result
	return action

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if str(action.get("type", "")).ends_with("_land"):
		return engine._vector2i_values(enemy.get(_held_field(action), []))
	var pattern: Dictionary = _pattern(action)
	var result: Array[Vector2i]
	var hero: Vector2i = state["player"]["pos"]
	if not is_lob(action) and Paths.manhattan(hero, enemy["pos"]) > int(pattern["range"]): return result
	if not bool(pattern.get("ignore_line_of_sight", true)) and not engine.combat_line_of_sight(state, enemy["pos"], hero): return result
	var candidates: Array[Vector2i]
	match str(pattern["shape"]):
		"plus":
			for center: Vector2i in centers(engine, state, enemy):
				for delta: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
					candidates.append(center + delta)
		"line3_perpendicular":
			var delta: Vector2i = hero - Vector2i(enemy["pos"])
			# Legacy Seer rule, including shallow diagonals. Rime Oracle's
			# order transform remains in the existing surface preparation path.
			var axis: Vector2i = Vector2i(0, 1) if delta.y == 0 else Vector2i(1, 0)
			candidates.assign([hero - axis, hero, hero + axis])
	for tile: Vector2i in candidates:
		var legal: bool = Paths.is_in_bounds(state["grid"], tile)
		if str(pattern["tile_filter"]) == "passable_without_terrain":
			legal = Paths.is_passable(state["grid"], tile) and engine._terrain_index_at_tile(state, tile) < 0
		if legal and not result.has(tile): result.append(tile)
	return result

static func available(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> bool:
	var distance: int = Paths.manhattan(enemy["pos"], state["player"]["pos"])
	if intent.has("requires_hero_within") and distance > int(intent["requires_hero_within"]): return false
	for action: Dictionary in intent.get("actions", []):
		if not handles(action): continue
		if is_lob(action):
			if str(action["type"]) == "lob_mark":
				var pattern: Dictionary = _pattern(action)
				if distance < int(pattern["min_range"]) or distance > int(pattern["max_range"]): return false
				if not bool(pattern["ignore_line_of_sight"]) and not engine.combat_line_of_sight(state, enemy["pos"], state["player"]["pos"]): return false
			elif (enemy.get("lob_tiles", []) as Array).is_empty(): return false
		elif tiles(engine, state, enemy, action).is_empty(): return false
	return true

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	for action: Dictionary in intent.get("actions", []):
		if not handles(action): continue
		var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
		if disabled or (is_lob(action) and not available(engine, state, enemy, intent)): affected.clear()
		return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": engine._vector2i_values([enemy["pos"]]), "route": engine._vector2i_values([enemy["pos"]]), "destination": enemy["pos"], "projected_attack": affected, "attack_available": not affected.is_empty(), "attack_action": action, "attack_action_index": 0, "movement_action_index": -1, "target_tile": enemy.get("lob_center", state["player"]["pos"]) if is_lob(action) else state["player"]["pos"], "target_key": "player"}
	return {}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, bleed_steps: Array[Dictionary] = []) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	if str(action["type"]).ends_with("_mark"):
		if is_lob(action) and not available(engine, state, enemy, {"actions": [action]}): return state
		enemy[_held_field(action)] = tiles(engine, state, enemy, action)
		if is_lob(action):
			enemy["lob_center"] = state["player"]["pos"]
			if cross_count(state, enemy) > 1: enemy["lob_centers"] = centers(engine, state, enemy)
		return state
	return _resolve_lob_land(engine, state, index, action, bleed_steps) if is_lob(action) else _resolve_icefall_land(engine, state, index, action)

static func declare(state: Dictionary, enemy: Dictionary, intent: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if cross_count(state, enemy) <= 1: return intent
	if not (intent.get("actions", []) as Array).any(func(action: Dictionary) -> bool: return str(action.get("type", "")) == "lob_mark"): return intent
	var result: Dictionary = intent.duplicate(true)
	result["barrage_side"] = -1 if rng.randi_range(0, 1) == 0 else 1
	return result

static func cross_count(state: Dictionary, enemy: Dictionary) -> int:
	if not bool(enemy.get("is_leader", false)): return 1
	return int(preload("res://scripts/warband_combat_rules.gd").order_for_objective(state.get("objective", {})).get("lob_crosses", 1))

static func centers(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = engine._vector2i_values([state["player"]["pos"]])
	if cross_count(state, enemy) <= 1: return result
	var rng := RandomNumberGenerator.new()
	rng.state = int(state.get("rng_state", 0))
	var side: int = int(enemy.get("intent", {}).get("barrage_side", -1 if rng.randi_range(0, 1) == 0 else 1))
	var axis: Vector2i = preload("res://scripts/warband_combat_rules.gd").order_axis(engine, Vector2i(state["player"]["pos"]) - Vector2i(enemy["pos"]))
	for sign_value: int in [side, -side]:
		var tile: Vector2i = result[0] + axis * sign_value * 2
		if Paths.is_passable(state["grid"], tile) and engine._terrain_index_at_tile(state, tile) < 0:
			result.append(tile)
			break
	return result

static func damage(enemy: Dictionary, action: Dictionary, tile: Vector2i) -> int:
	return int(action["center_damage"] if tile == enemy.get("lob_center") or (enemy.get("lob_centers", []) as Array).has(tile) else action["arm_damage"])

# Presentation must use the production planner's pre-lob movement, including
# the captain's retreat. Keep tiles, stronger centres and copy on one forecast;
# tiles()/centers() remain the resolver's primitives on an already moved state.

static func aiming_forecast(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Dictionary:
	var index: int = engine._enemy_index_for_id(state, int(enemy.get("id", -1)))
	if index < 0: return {}
	var frozen: bool = int(enemy.get("freeze", 0)) > 0 or preload("res://scripts/maneuver_rules.gd").is_petrified(enemy)
	var plan: Dictionary = engine.enemy_intent_plan(state, index, enemy.get("intent", {}), frozen or bool(enemy.get("immobilize", false)), frozen or int(enemy.get("shock", 0)) > 0)
	var affected: Array[Vector2i] = engine._vector2i_values(plan.get("projected_attack", []))
	var projected: Dictionary = enemy.duplicate(true)
	projected["pos"] = plan.get("destination", enemy["pos"])
	var stronger: Array[Vector2i]
	if not affected.is_empty(): stronger = centers(engine, state, projected)
	return {"tiles": affected, "centers": stronger}

static func landing_action(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Dictionary:
	# A revealed landing already carries the resolved values used by its damage
	# preview and resolver. Preserve those rather than scaling a fresh definition.
	for action: Dictionary in enemy.get("intent", {}).get("actions", []):
		if str(action.get("type", "")) == "lob_land": return action
	return _scaled_landing_action(engine, state, enemy)

static func _scaled_landing_action(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Dictionary:
	var intents: Array = engine._scaled_enemy_intents(preload("res://scripts/game_data.gd").enemy_def("slag_mortar")["intents"], int(state.get("room_depth", 1)), state, enemy)
	return engine._intent_by_id(intents, "slag_lands")["actions"][0]

# Known moves are not necessarily the declared intent. Forecast that move on
# a private snapshot, then use the same resolved presentation as the board.
# enc-04: never format the catalog's unscaled Lob damage or a raw marking action.

static func presentation_intent(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if not (intent.get("actions", []) as Array).any(func(action: Dictionary) -> bool: return is_lob(action)): return intent
	var result: Dictionary = intent.duplicate(true)
	var preview: Dictionary = state.duplicate(true)
	var index: int = engine._enemy_index_for_id(preview, int(enemy.get("id", -1)))
	var source: Dictionary = enemy.duplicate(true) if index < 0 else preview["enemies"][index]
	var landing: Dictionary = landing_action(engine, state, source)
	var declared: Dictionary = source.get("intent", {})
	source["intent"] = intent.duplicate(true)
	if str(declared.get("id", "")) == str(intent.get("id", "")) and declared.has("barrage_side"):
		source["intent"]["barrage_side"] = declared["barrage_side"]
	for action_index: int in range(result["actions"].size()):
		var action: Dictionary = result["actions"][action_index]
		if not is_lob(action): continue
		if str(action["type"]) == "lob_land":
			for field: String in ["center_damage", "arm_damage"]: action[field] = landing[field]
			if index >= 0 and (source.get("lob_tiles", []) as Array).is_empty():
				# An unrevealed landing uses the crosses that its marking move
				# would actually place, including captain retreat and clipping.
				var intents: Array = engine._scaled_enemy_intents(preload("res://scripts/game_data.gd").enemy_def("slag_mortar")["intents"], int(state.get("room_depth", 1)), preview, source)
				source["intent"] = engine._intent_by_id(intents, "lob_slag")
				source["lob_centers"] = aiming_forecast(engine, preview, source).get("centers", [])
		result["actions"][action_index] = presentation_action(engine, preview, source, action)
	return result

static func presentation_action(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	if not is_lob(action): return action
	var result: Dictionary = action.duplicate(true)
	# HUD unit records omit held lob centres and some scaling context. Resolve
	# their actor identity against the same combat snapshot as the preview.
	var source: Dictionary = enemy
	for candidate: Dictionary in state.get("enemies", []):
		if int(candidate.get("id", -1)) == int(enemy.get("id", -2)):
			source = candidate
			break
	if str(action["type"]) == "lob_mark":
		var landing: Dictionary = _scaled_landing_action(engine, state, source)
		for field: String in ["center_damage", "arm_damage"]: result[field] = landing[field]
		result["lob_cross_count"] = (aiming_forecast(engine, state, source).get("centers", []) as Array).size()
	else:
		# Use the saved centres after marking, including a clipped barrage that
		# could only place one cross. The hero may have moved since aiming.
		result["lob_cross_count"] = maxi(1, (source.get("lob_centers", []) as Array).size())
	return result

static func _resolve_icefall_land(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
	enemy["icefall_serial"] = int(enemy.get("icefall_serial", 0)) + 1
	# One hit per actor, even if a large footprint covers several marks.
	var actors: Array[Dictionary]
	actors.append({"kind": "player", "id": -1, "unit": state["player"]})
	for unit: Dictionary in state.get("enemies", []):
		actors.append({"kind": "enemy", "id": int(unit["id"]), "unit": unit})
	for unit: Dictionary in state.get("illusions", []):
		actors.append({"kind": "illusion", "id": int(unit["id"]), "unit": unit})
	for actor: Dictionary in actors:
		var hit: bool = false
		for tile: Vector2i in Surfaces.footprint_tiles(actor["unit"]):
			if affected.has(tile): hit = true
		if not hit or int(actor["unit"].get("hp", 0)) <= 0: continue
		if str(actor["kind"]) == "enemy":
			state = engine._damage_enemy(state, engine._enemy_index_for_id(state, int(actor["id"])), int(action.get("damage", 5)), true, false, false)
		else:
			state = engine._surface_damage_actor(state, str(actor["kind"]), int(actor["id"]), int(action.get("damage", 5)), true)
		state = engine._surface_freeze_actor(state, str(actor["kind"]), int(actor["id"]), action)
	for tile: Vector2i in affected:
		state = engine._place_action_surface(state, {"type": "surface", "surface": str(action.get("surface", "ice")), "_enemy_id": int(enemy["id"])}, tile)
	state["enemies"][index].erase("icefall_tiles")
	return state

static func _resolve_lob_land(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
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
	state["enemies"][index].erase("lob_centers")
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	return _lob_animation_step(engine, before, after, index, action) if is_lob(action) else _icefall_animation_step(engine, before, after, index, action)

static func _lob_animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	if str(action["type"]) == "lob_land" and after["enemies"][index].has("lob_tiles"): return {}
	# Marking reads the committed result; landing reads the held mark before
	# resolution clears it. Playback must never forecast another captain retreat.
	var committed: Dictionary = after["enemies"][index] if str(action["type"]) == "lob_mark" else enemy
	var affected: Array[Vector2i] = engine._vector2i_values(committed.get("lob_tiles", []))
	var held_centers: Array[Vector2i]
	if not affected.is_empty(): held_centers = engine._vector2i_values(committed.get("lob_centers", [committed["lob_center"]]))
	var caption_action: Dictionary = action.duplicate(true)
	if str(action["type"]) == "lob_mark":
		var landing: Dictionary = landing_action(engine, before, enemy)
		for field: String in ["center_damage", "arm_damage"]: caption_action[field] = landing[field]
	return {"kind": "aoe" if str(action["type"]) == "lob_land" else "surface", "en04_mechanic": str(action["type"]), "action_type": str(action["type"]), "actor_key": engine._enemy_key(enemy), "actor_name": engine._enemy_display_name(enemy), "enemy_type": enemy["type"], "element": "fire", "sfx_category": "ranged", "from": enemy["pos"], "to": enemy.get("lob_center", before["player"]["pos"]), "tiles": affected, "lob_geometry": {"tiles": affected.duplicate(), "centers": held_centers, "cross_count": held_centers.size()}, "lob_action": caption_action, "target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after), "en04_state_after": after.duplicate(true)}

static func _icefall_animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	return {"kind": "aoe" if str(action["type"]) == "icefall_land" else "surface", "en02_mechanic": str(action["type"]), "action_type": str(action["type"]), "actor_key": engine._enemy_key(enemy), "actor_name": engine._enemy_display_name(enemy), "enemy_type": enemy["type"], "element": "ice", "from": enemy["pos"], "to": before["player"]["pos"], "tiles": tiles(engine, before, enemy, action), "damage": int(action.get("damage", 0)), "intent_id": enemy.get("intent", {}).get("id", ""), "target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after), "terrain_losses": engine._terrain_target_losses(before, after), "en02_state_after": after.duplicate(true)}
