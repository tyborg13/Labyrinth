extends RefCounted

const Glossary = preload("res://scripts/glossary.gd")

# Protected design: spec/enemies/briar_weaver.md. No attack durability or LOS.
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall.gd")

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "grow_bramble"

static func attackable(terrain: Dictionary) -> bool:
	return str(terrain.get("kind", "")) != "bramble" and Icefall.attackable(terrain)

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var hero: Vector2i = state["player"]["pos"]
	var delta: Vector2i = hero - Vector2i(enemy["pos"])
	if delta == Vector2i.ZERO: return result
	if preload("res://scripts/warband_combat_rules.gd").order(state, enemy, "thornmother_wall"):
		return order_tiles(engine, state, enemy)
	# Cardinal front is toward the Weaver; diagonal front uses both axes, row.
	var front := hero - Vector2i(signi(delta.x), signi(delta.y))
	var axis := Vector2i(0, 1) if delta.y == 0 else Vector2i(1, 0)
	for tile: Vector2i in [front - axis, front, front + axis]:
		if Paths.is_passable(state["grid"], tile) and engine._terrain_index_at_tile(state, tile) < 0 and not Icefall.occupied(engine, state, tile): result.append(tile)
	return result

static func order_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var hero: Vector2i = state["player"]["pos"]
	var blocked: Dictionary = {}
	for terrain: Dictionary in state.get("terrain", []):
		if engine._terrain_index_at_tile(state, terrain["pos"]) >= 0: blocked[terrain["pos"]] = true
	var path: Array[Vector2i] = Paths.find_path(state["grid"], enemy["pos"], hero, blocked, true)
	if path.size() < 2: return result
	var center: Vector2i = path[mini(2, path.size() - 1)]
	var axis: Vector2i = preload("res://scripts/warband_combat_rules.gd").order_axis(engine, path[1] - path[0])
	var nearest: int = 2147483647
	var legal_center: Vector2i = center
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			var tile := Vector2i(x, y)
			if not legal_tile(engine, state, tile): continue
			var distance: int = Paths.manhattan(center, tile)
			if distance < nearest:
				nearest = distance
				legal_center = tile
	if nearest == 2147483647: return result
	for offset: int in range(-2, 3):
		var tile: Vector2i = legal_center + axis * offset
		if legal_tile(engine, state, tile): result.append(tile)
	return result

static func legal_tile(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return Paths.is_passable(state["grid"], tile) and engine._terrain_index_at_tile(state, tile) < 0 and not Icefall.occupied(engine, state, tile)

static func mend_action(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	var result: Dictionary = action.duplicate(true)
	# An ally is another living enemy; keep existing most-missing-HP tie breaks.
	if str(enemy.get("type", "")) == "briar_weaver" and str(action.get("type", "")) == "heal_ally": result["allow_self"] = false
	return result

static func effective_intent(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if str(enemy.get("type", "")) != "briar_weaver" or str(intent.get("id", "")) != "root_mend": return intent
	var index: int = engine._enemy_index_for_id(state, int(enemy["id"]))
	for action: Dictionary in intent.get("actions", []):
		if engine._enemy_support_target_index(state, index, mend_action(engine, state, enemy, action)) >= 0: return intent
	var intents: Array = engine._scaled_enemy_intents(preload("res://scripts/game_data.gd").enemy_def("briar_weaver")["intents"], int(state.get("room_depth", 1)), state, enemy)
	return engine._intent_by_id(intents, "lash_of_thorns")

static func presentation_intent(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if str(enemy.get("type", "")) != "briar_weaver" or str(intent.get("id", "")) != "root_mend": return intent
	return effective_intent(preload("res://scripts/combat_engine.gd").new(), state, enemy, intent)

static func available(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if handles(action) and tiles(engine, state, enemy).is_empty(): return false
		if str(enemy.get("type", "")) == "briar_weaver" and str(action.get("type", "")) == "heal_ally":
			if engine._enemy_support_target_index(state, engine._enemy_index_for_id(state, int(enemy["id"])), mend_action(engine, state, enemy, action)) < 0: return false
	return true

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if not handles(action): continue
		var enemy: Dictionary = state["enemies"][index]
		var affected: Array[Vector2i] = tiles(engine, state, enemy)
		if disabled: affected.clear()
		return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": engine._vector2i_values([enemy["pos"]]), "route": engine._vector2i_values([enemy["pos"]]), "destination": enemy["pos"], "projected_attack": affected, "attack_available": not affected.is_empty(), "attack_action": action, "attack_action_index": 0, "movement_action_index": -1, "target_tile": state["player"]["pos"], "target_key": "player"}
	return {}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	enemy["bramble_serial"] = int(enemy.get("bramble_serial", 0)) + 1
	for tile: Vector2i in tiles(engine, state, enemy):
		state["terrain"].append({"id": "bramble_%d_%d_%d_%d" % [int(enemy["id"]), int(enemy["bramble_serial"]), tile.x, tile.y], "kind": "bramble", "pos": tile, "rounds_left": int(action["rounds"]), "pushed_damage": int(action["pushed_damage"]), "pushed_bleed": int(action["pushed_bleed"]), "blocks_sight": false})
	return state

static func complete_turn(engine: RefCounted, state: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	state = Wind.complete_turn(engine, state, steps)
	end_turn(state, steps)
	return state

static func end_turn(state: Dictionary, steps: Array[Dictionary] = []) -> void:
	var expired: Array[Dictionary]
	var terrain: Array = state.get("terrain", [])
	for index: int in range(terrain.size() - 1, -1, -1):
		var entry: Dictionary = terrain[index]
		if str(entry.get("kind", "")) != "bramble": continue
		entry["rounds_left"] = maxi(0, int(entry.get("rounds_left", 0)) - 1)
		if int(entry["rounds_left"]) == 0:
			expired.append(entry.duplicate(true))
			terrain.remove_at(index)
	if not expired.is_empty(): steps.append({"kind": "status", "en04_mechanic": "bramble_expiry", "expired_bramble": expired, "en04_state_after": state.duplicate(true)})

static func collision(engine: RefCounted, state: Dictionary, kind: String, id: int, contact: Dictionary, direction: Vector2i, lost: int, pushing: bool) -> bool:
	for blocker: Dictionary in contact.get("blockers", []):
		if str(blocker.get("terrain_kind", "")) != "bramble": continue
		var index: int = engine._terrain_index_at_tile(state, blocker["tile"])
		if index < 0: continue
		var entry: Dictionary = state["terrain"][index]
		var damage: int = int(entry["pushed_damage"])
		engine._force_collision_damage(state, kind, id, damage)
		if int(engine._force_unit(state, kind, id).get("hp", 0)) > 0:
			var status: Dictionary = {"bleed": int(entry["pushed_bleed"])}
			if kind == "enemy": engine._apply_action_keywords_to_enemy(state, engine._enemy_index_for_id(state, id), status, contact["blocked_tile"], false)
			else: engine._apply_action_keywords_to_target(state, {"kind": kind, "id": id}, status, contact["blocked_tile"])
		Surfaces.record_event(state, {"kind": "force_collision", "actor_kind": kind, "id": id, "actor_key": engine._surface_actor_key(kind, id), "tile": contact["blocked_tile"] - direction, "blocked_tile": contact["blocked_tile"], "direction": direction, "force": "push" if pushing else "pull", "damage": damage, "target_damage": damage, "blocker_damage": 0, "total_damage": damage, "blocker_kind": "terrain", "terrain_kind": "bramble", "lost_tiles": lost, "tooltip_override": Glossary.name_for("bramble") + "\n" + Glossary.definition("bramble") + "\n%d turns left" % int(entry["rounds_left"]), "source": state.get("damage_context", {}).duplicate(true)})
		return true
	return false

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	return {"kind": "surface", "action_type": "grow_bramble", "en04_mechanic": "grow_bramble", "actor_key": engine._enemy_key(enemy), "actor_name": engine._enemy_display_name(enemy), "element": "earth", "tiles": tiles(engine, before, enemy), "from": enemy["pos"], "to": before["player"]["pos"], "en04_state_after": after.duplicate(true)}
